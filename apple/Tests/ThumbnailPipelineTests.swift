//
//  ThumbnailPipelineTests.swift
//  KairumoTests
//
//  側欄縮圖管線：`body` 路徑不能算繪、不能讀檔（即時響應的前提），
//  但最後一定要得到正確的最新縮圖，且版本一變就要重畫。
//

import PencilKit
import XCTest
@testable import Kairumo

@MainActor
final class ThumbnailPipelineTests: XCTestCase {

    private var dir: URL!
    private var store: NotebookStore!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("thumb-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        store = NotebookStore(testDocumentsRoot: dir)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func request(_ doc: NotebookDocument, page: Int = 0, revision: Int, loaded: @escaping () -> Void = {}) -> ThumbnailPipeline.Request {
        ThumbnailPipeline.Request(
            notebook: doc, pageIndex: page, store: store, canvasWidth: 800,
            inkRevision: revision, drawing: { loaded(); return PKDrawing() }, priority: page)
    }

    func testImageReturnsImmediatelyWithoutLoadingTheDrawing() {
        let doc = NotebookDocument(title: "t", pageCount: 3)
        var loads = 0
        _ = ThumbnailPipeline.shared.image(for: request(doc, revision: 1) { loads += 1 })
        XCTAssertEqual(loads, 0, "body 路徑不可取筆跡（會讀檔解碼）")
    }

    func testRendersLaterAndNotifiesOnlyThatPageSlot() async throws {
        let doc = NotebookDocument(title: "t", pageCount: 3)
        let slot0 = ThumbnailPipeline.shared.slot(notebookId: doc.id, pageIndex: 0)
        let slot1 = ThumbnailPipeline.shared.slot(notebookId: doc.id, pageIndex: 1)
        let v0 = slot0.version, v1 = slot1.version
        var loads = 0
        _ = ThumbnailPipeline.shared.image(for: request(doc, page: 0, revision: 7) { loads += 1 })
        try await Task.sleep(nanoseconds: 800_000_000)
        XCTAssertEqual(loads, 1)
        XCTAssertGreaterThan(slot0.version, v0)
        XCTAssertEqual(slot1.version, v1, "別頁的卡片不該被牽連")
        // 之後同版本命中，不再載入。
        _ = ThumbnailPipeline.shared.image(for: request(doc, page: 0, revision: 7) { loads += 1 })
        XCTAssertEqual(loads, 1)
    }

    func testNewRevisionRendersAgainAndKeepsStaleImageMeanwhile() async throws {
        let doc = NotebookDocument(title: "t", pageCount: 1)
        _ = ThumbnailPipeline.shared.image(for: request(doc, revision: 1))
        try await Task.sleep(nanoseconds: 800_000_000)
        let first = ThumbnailPipeline.shared.image(for: request(doc, revision: 1))
        var loads = 0
        let during = ThumbnailPipeline.shared.image(for: request(doc, revision: 2) { loads += 1 })
        XCTAssertTrue(during === first, "新版本還沒算好時先顯示舊圖，不閃白")
        XCTAssertEqual(loads, 0)
        try await Task.sleep(nanoseconds: 800_000_000)
        XCTAssertEqual(loads, 1)
    }

    func testInvalidateAllForcesRedraw() async throws {
        let doc = NotebookDocument(title: "t", pageCount: 1)
        _ = ThumbnailPipeline.shared.image(for: request(doc, revision: 3))
        try await Task.sleep(nanoseconds: 800_000_000)
        PageThumbnailRenderer.invalidateAll()
        var loads = 0
        _ = ThumbnailPipeline.shared.image(for: request(doc, revision: 3) { loads += 1 })
        try await Task.sleep(nanoseconds: 800_000_000)
        XCTAssertEqual(loads, 1, "全面失效後同版本也要重畫")
    }

    // MARK: - I4：圖片外觀進縮圖快取鍵

    func testImageFilterChangeChangesThumbnailKey() {
        var doc = NotebookDocument(title: "t", pageCount: 1)
        doc.attachments = [NoteImageAttachment(fileName: "a.png", pageIndex: 0)]
        let before = PageThumbnailRenderer.lightweightKey(notebook: doc, pageIndex: 0, store: store, inkRevision: 1)
        doc.attachments?[0].filterStyle = .vintage
        let after = PageThumbnailRenderer.lightweightKey(notebook: doc, pageIndex: 0, store: store, inkRevision: 1)
        XCTAssertNotEqual(before, after, "換了風格濾鏡，側欄縮圖必須重畫（畫布與縮圖同源，I4）")
    }

    // MARK: - 即點即開：圖多的頁，縮圖合成時主執行緒的成本

    /// 量測（印出改善前後的數字）：一頁 12 張 1600×1200 照片級圖片、其中一半套了風格濾鏡。
    /// 改善前：主執行緒合成縮圖時逐張讀檔＋解碼＋逐像素套濾鏡（`loadAttachmentImage` ＋ `ImageEffects.apply`）。
    /// 改善後：背景工作先預載＋解碼＋濾鏡（`imageMemory.prefetch`／`makeFiltered`），主執行緒只貼圖。
    func testImageHeavyPageMainThreadCostBeforeAndAfter() throws {
        let count = 12
        var names: [String] = []
        let size = CGSize(width: 1600, height: 1200)
        for i in 0..<count {
            let img = UIGraphicsImageRenderer(size: size, format: { let f = UIGraphicsImageRendererFormat(); f.scale = 1; return f }()).image { ctx in
                // 照片級（不可壓縮的）內容：PNG 解碼成本接近真實照片。
                var rng = SystemRandomNumberGenerator()
                for y in stride(from: 0, to: Int(size.height), by: 8) {
                    for x in stride(from: 0, to: Int(size.width), by: 8) {
                        UIColor(red: .random(in: 0...1, using: &rng), green: .random(in: 0...1, using: &rng),
                                blue: .random(in: 0...1, using: &rng), alpha: 1).setFill()
                        ctx.fill(CGRect(x: x, y: y, width: 8, height: 8))
                    }
                }
                _ = i
            }
            let name = try XCTUnwrap(store.saveAttachmentImage(img))
            names.append(name)
        }
        let filters: [ImageFilterStyle] = names.indices.map { $0 % 2 == 0 ? .vintage : .original }

        func renderOnce() {
            for (name, filter) in zip(names, filters) {
                let base = store.cachedAttachmentImage(fileName: name) ?? store.loadAttachmentImage(fileName: name)!
                let key = ImageEffects.filteredCacheKey(fileName: name, filter: filter)
                let shown = filter == .original ? base
                    : (ImageEffects.cachedFiltered(key: key) ?? ImageEffects.apply(filter: filter, material: nil, to: base))
                // 畫進一張縮圖大小的畫布（強制解碼，與合成縮圖時相同）。
                _ = UIGraphicsImageRenderer(size: CGSize(width: 160, height: 120)).image { _ in
                    shown.draw(in: CGRect(x: 0, y: 0, width: 160, height: 120))
                }
            }
        }

        // 改善前：冷快取，全部在主執行緒。
        store.imageMemory.removeAll()
        let before = Date()
        renderOnce()
        let beforeMs = Date().timeIntervalSince(before) * 1000

        // 改善後：同一批圖在背景預載＋濾鏡（量主執行緒以外的時間），主執行緒只貼圖。
        store.imageMemory.removeAll()
        let directory = store.attachmentsDirectory
        let memory = store.imageMemory
        let bgStart = Date()
        let done = expectation(description: "prefetch")
        DispatchQueue.global(qos: .userInitiated).async {
            memory.prefetch(names, directory: directory)
            for (name, filter) in zip(names, filters) where filter != .original {
                let key = ImageEffects.filteredCacheKey(fileName: name, filter: filter)
                if let base = memory.image(for: name) { _ = ImageEffects.makeFiltered(base, filter: filter, key: key) }
            }
            done.fulfill()
        }
        wait(for: [done], timeout: 120)
        let bgMs = Date().timeIntervalSince(bgStart) * 1000
        let loadsBefore = PerfProbe.shared.counter(.mainThreadAttachmentLoad)
        let after = Date()
        renderOnce()
        let afterMs = Date().timeIntervalSince(after) * 1000
        XCTAssertEqual(PerfProbe.shared.counter(.mainThreadAttachmentLoad), loadsBefore, "預載之後主執行緒不該再讀檔")

        print(String(format: "OPEN-PERF image-heavy page (%d imgs 1600x1200, %d filtered): main thread before %.1f ms → after %.1f ms (background prefetch %.1f ms)",
                     count, filters.filter { $0 != .original }.count, beforeMs, afterMs, bgMs))
        XCTAssertLessThan(afterMs, beforeMs, "主執行緒成本必須下降")
    }
}

