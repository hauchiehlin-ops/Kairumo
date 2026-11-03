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
}
