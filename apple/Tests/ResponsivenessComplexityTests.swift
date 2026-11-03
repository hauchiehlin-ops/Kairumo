//
//  ResponsivenessComplexityTests.swift
//  KairumoTests
//
//  「即時響應」的裝置無關守門：不量毫秒，量**次數**與**成長**。
//  某個互動在主執行緒上不該發生的事（讀檔、同步算繪）一次都不能發生，
//  而且 10 頁與 200 頁的筆記本結果必須一樣 —— 成本不得隨筆記大小成長。
//

import PencilKit
import XCTest
@testable import Kairumo

@MainActor
final class ResponsivenessComplexityTests: XCTestCase {

    private var dir: URL!
    private var store: NotebookStore!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("resp-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        store = NotebookStore(testDocumentsRoot: dir)
        PerfProbe.shared.reset()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func denseDrawing(strokes n: Int) -> PKDrawing {
        var list: [PKStroke] = []
        for i in 0..<n {
            var pts: [PKStrokePoint] = []
            for k in 0..<20 {
                let x: Double = Double(i % 40) * 12.0 + Double(k) * 2.0
                let y: Double = Double(i) * 0.9
                pts.append(PKStrokePoint(location: CGPoint(x: x, y: y), timeOffset: Double(k) * 0.01,
                                         size: CGSize(width: 3, height: 3), opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2))
            }
            list.append(PKStroke(ink: PKInk(.pen, color: .black),
                                 path: PKStrokePath(controlPoints: pts, creationDate: Date(timeIntervalSince1970: 0))))
        }
        return PKDrawing(strokes: list)
    }

    /// 側欄「可見的那幾張卡片」在 `body` 裡做的事。
    private func bodyPass(pages: Int, visible: Int = 8) {
        let doc = NotebookDocument(title: "big", pageCount: pages)
        for p in 0..<min(visible, pages) {
            let req = ThumbnailPipeline.Request(
                notebook: doc, pageIndex: p, store: store, canvasWidth: 800,
                inkRevision: 1, drawing: { PKDrawing() }, priority: p)
            _ = ThumbnailPipeline.shared.image(for: req)
        }
    }

    func testSidebarBodyPathDoesNoDiskLoadOrComposeAndDoesNotGrowWithPages() {
        for pages in [10, 200] {
            PerfProbe.shared.reset()
            bodyPass(pages: pages)
            XCTAssertEqual(PerfProbe.shared.counter(.mainThreadDrawingLoad), 0, "\(pages) 頁：body 不可讀檔解碼")
            XCTAssertEqual(PerfProbe.shared.counter(.thumbnailComposeOnMain), 0, "\(pages) 頁：body 不可同步算繪")
        }
    }

    func testPrefetchPrimesTheSharedCacheWithTheSavedContent() throws {
        let nb = "nb-prefetch"
        let drawing = denseDrawing(strokes: 300)
        store.saveDrawing(notebookId: nb, pageIndex: 3, drawing: drawing)
        let url = store.drawingsDirectory.appending(path: "\(nb)_p3.drawing")
        // 等背景寫檔完成後再預取。
        let deadline = Date().addingTimeInterval(5)
        while !FileManager.default.fileExists(atPath: url.path), Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        NotebookStore.prefetchDrawing(at: url)
        XCTAssertEqual(store.loadDrawing(notebookId: nb, pageIndex: 3).strokes.count, 300)
    }

    func testNeighborsAreBoundedAndExcludeTheCurrentPage() {
        XCTAssertEqual(Set(PagePrefetcher.neighbors(of: 5, pageCount: 200)), [3, 4, 6, 7])
        XCTAssertEqual(Set(PagePrefetcher.neighbors(of: 0, pageCount: 200)), [1, 2])
        XCTAssertEqual(Set(PagePrefetcher.neighbors(of: 9, pageCount: 10)), [7, 8])
        XCTAssertTrue(PagePrefetcher.neighbors(of: 0, pageCount: 1).isEmpty)
        XCTAssertLessThanOrEqual(PagePrefetcher.neighbors(of: 100, pageCount: 200).count, 4, "預取量與筆記本大小無關")
    }

    // MARK: 排程器

    func testLowPriorityWorkWaitsWhileInkIsBusyButInteractiveDoesNot() {
        let scheduler = BackgroundScheduler()
        let busy = LockedFlag(true)
        scheduler.inkBusy = { busy.value }
        scheduler.retryInterval = 0.02
        let low = expectation(description: "prefetch ran after ink stopped")
        let hi = expectation(description: "interactive ran while busy")
        let ranLowWhileBusy = LockedFlag(false)
        scheduler.submit(.prefetch) { if busy.value { ranLowWhileBusy.value = true }; low.fulfill() }
        scheduler.submit(.interactive) { hi.fulfill() }
        wait(for: [hi], timeout: 2)
        Thread.sleep(forTimeInterval: 0.15)
        busy.value = false
        wait(for: [low], timeout: 2)
        XCTAssertFalse(ranLowWhileBusy.value, "書寫中預取必須暫停")
    }

    func testSameKeyIsNotQueuedTwiceWhileInFlight() {
        let scheduler = BackgroundScheduler()
        scheduler.inkBusy = { false }
        let count = LockedCounter()
        let gate = DispatchSemaphore(value: 0)
        let done = expectation(description: "done")
        scheduler.submit(.prefetch, key: "k") { gate.wait(); count.increment(); done.fulfill() }
        scheduler.submit(.prefetch, key: "k") { count.increment() }
        gate.signal()
        wait(for: [done], timeout: 2)
        Thread.sleep(forTimeInterval: 0.1)
        XCTAssertEqual(count.value, 1)
    }
}

private final class LockedFlag: @unchecked Sendable {
    private let lock = NSLock(); private var v: Bool
    init(_ v: Bool) { self.v = v }
    var value: Bool { get { lock.lock(); defer { lock.unlock() }; return v } set { lock.lock(); v = newValue; lock.unlock() } }
}
private final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock(); private var n = 0
    func increment() { lock.lock(); n += 1; lock.unlock() }
    var value: Int { lock.lock(); defer { lock.unlock() }; return n }
}
