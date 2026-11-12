//
//  ProInkEraseAndReleaseTests.swift
//  KairumoTests
//
//  橡皮擦只局部重畫、捲出畫面的頁釋放算繪快取 —— 畫面必須與整頁重建的結果一致。
//

import XCTest
@testable import Kairumo

@MainActor
final class ProInkEraseAndReleaseTests: XCTestCase {

    private var workDir: URL!
    private let size = CGSize(width: 400, height: 300)

    override func setUpWithError() throws {
        workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kairumo-erase-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
        PerfProbe.shared.reset()
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: workDir) }

    private func strokes() -> [ProStroke] {
        // 彼此重疊的橫線與斜線，擦掉中間一筆時周圍的筆畫必須原樣留著。
        (0 ..< 30).map { i in
            ProStroke(tool: "fineliner", colorRGBA: [0, 0, 0, 255], baseWidth: 8,
                      points: (0 ..< 16).map { k in
                          ProPoint(x: 20 + Float(k) * 20, y: 20 + Float(i) * 8 + Float(k) * Float(i % 3), pressure: 0.7, tilt: 0, azimuth: 0, dtUs: 8_000)
                      })
        }
    }

    private func image(_ layer: ProInkLayerView) -> [UInt8] {
        layer.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let img = UIGraphicsImageRenderer(size: size, format: format).image { ctx in layer.layer.render(in: ctx.cgContext) }
        guard let cg = img.cgImage, let data = cg.dataProvider?.data, let base = CFDataGetBytePtr(data) else { return [] }
        return Array(UnsafeBufferPointer(start: base, count: cg.bytesPerRow * cg.height))
    }

    private func spin(_ s: TimeInterval = 1.2) {
        let end = Date().addingTimeInterval(s)
        while Date() < end { RunLoop.current.run(until: Date().addingTimeInterval(0.02)) }
    }

    private func makeLayer(_ nb: String, _ list: [ProStroke]) -> ProInkLayerView {
        ProInkStore.save(list, in: workDir, notebookId: nb, page: 0)
        let layer = ProInkLayerView(frame: CGRect(origin: .zero, size: size))
        layer.load(directory: workDir, notebookId: nb, pageIndex: 0)
        _ = image(layer)   // 第一次繪製才會啟動背景烘焙（沒有視窗就沒有顯示週期）
        spin()
        _ = image(layer)   // 烘焙完成的結果在下一次繪製前採用
        return layer
    }

    func testErasingOneStrokePatchesLocallyAndMatchesAFullRebuild() {
        let all = strokes()
        let layer = makeLayer("e1", all)
        _ = image(layer) // 確保已經畫過一次，快取外框
        PerfProbe.shared.reset()

        let victim = all[15]
        let path = victim.points.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) }
        XCTAssertGreaterThan(layer.erase(along: path, radius: 2), 0)
        let patched = image(layer)
        XCTAssertGreaterThanOrEqual(PerfProbe.shared.counter(.backingPatch), 1, "擦除要走局部重畫")
        XCTAssertEqual(PerfProbe.shared.counter(.backingFullRebuild), 0, "不可整頁重建")

        // 與「剩下的筆畫整頁重新畫」逐像素比對。
        let remaining = layer.ownStrokes
        let fresh = makeLayer("e1b", remaining)
        let rebuilt = image(fresh)
        XCTAssertEqual(patched.count, rebuilt.count)
        var diff = 0
        for i in 0 ..< min(patched.count, rebuilt.count) where abs(Int(patched[i]) - Int(rebuilt[i])) > 2 { diff += 1 }
        XCTAssertEqual(diff, 0, "局部重畫的結果必須與整頁重建一致（差異像素 \(diff)）")
    }

    func testUndoingTheEraseAlsoPatchesAndRestoresTheSameImage() {
        let all = strokes()
        let layer = makeLayer("e2", all)
        let before = image(layer)
        let manager = UndoManager()
        manager.groupsByEvent = false
        layer.undoManagerProvider = { manager }
        let victim = all[10]
        let path = victim.points.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) }
        manager.beginUndoGrouping()
        XCTAssertGreaterThan(layer.erase(along: path, radius: 2), 0)
        manager.endUndoGrouping()
        _ = image(layer)
        manager.undo()
        let restored = image(layer)
        var diff = 0
        for i in 0 ..< min(before.count, restored.count) where abs(Int(before[i]) - Int(restored[i])) > 2 { diff += 1 }
        XCTAssertEqual(diff, 0, "復原擦除之後畫面要與擦除前一致（差異像素 \(diff)）")
    }

    func testReleasedPageComesBackIdentically() {
        let layer = makeLayer("e3", strokes())
        let before = image(layer)
        layer.releaseRenderResources()
        layer.resumeRendering()
        _ = image(layer)   // 回到畫面的第一次繪製會啟動背景重烘
        spin()
        let after = image(layer)
        var diff = 0
        for i in 0 ..< min(before.count, after.count) where abs(Int(before[i]) - Int(after[i])) > 2 { diff += 1 }
        XCTAssertEqual(diff, 0, "釋放算繪資源再回來，畫面要一樣（差異像素 \(diff)）")
    }

    func testMovingStrokesWithLassoUpdatesCanvasBackingAndMatchesFullRebuild() {
        let all = strokes()
        let layer = makeLayer("m1", all)
        let before = image(layer)
        let manager = UndoManager()
        manager.groupsByEvent = false
        layer.undoManagerProvider = { manager }
        PerfProbe.shared.reset()

        let victim = all[12]
        manager.beginUndoGrouping()
        layer.move(ids: [victim.id], by: CGSize(width: 24, height: 18))
        _ = image(layer)   // 拖曳途中即時局部重繪
        layer.move(ids: [victim.id], by: CGSize(width: 16, height: 14))
        layer.endMove()
        manager.endUndoGrouping()

        let movedImage = image(layer)
        XCTAssertGreaterThanOrEqual(PerfProbe.shared.counter(.backingPatch), 1, "套索搬移應觸發增量底圖局部重畫")
        XCTAssertEqual(PerfProbe.shared.counter(.backingFullRebuild), 0, "套索搬移單筆不可觸發整頁重建")

        var changeFromBefore = 0
        for i in 0 ..< min(before.count, movedImage.count) where abs(Int(before[i]) - Int(movedImage[i])) > 2 {
            changeFromBefore += 1
        }
        XCTAssertGreaterThan(changeFromBefore, 50, "套索搬移後畫布像素必須隨筆跡同步移動，不可停在原位不動")

        let fresh = makeLayer("m1b", layer.ownStrokes)
        let rebuilt = image(fresh)
        var diff = 0
        for i in 0 ..< min(movedImage.count, rebuilt.count) where abs(Int(movedImage[i]) - Int(rebuilt[i])) > 2 {
            diff += 1
        }
        XCTAssertEqual(diff, 0, "套索搬移後的畫布底圖必須與整頁重繪完全一致（差異像素 \(diff)）")

        manager.undo()
        let undone = image(layer)
        var undoDiff = 0
        for i in 0 ..< min(before.count, undone.count) where abs(Int(before[i]) - Int(undone[i])) > 2 {
            undoDiff += 1
        }
        XCTAssertEqual(undoDiff, 0, "復原套索搬移後畫布應回到原貌（差異像素 \(undoDiff)）")
    }
}
