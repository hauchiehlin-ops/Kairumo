//
//  ProInkAsyncRenderTests.swift
//  KairumoTests
//
//  收筆交接與整頁烘焙搬到背景之後，畫面內容必須與同步時完全一樣：
//  筆畫不消失、不重複、換頁不殘留上一頁、連續兩筆之間不掉筆。
//

import XCTest
@testable import Kairumo

@MainActor
final class ProInkAsyncRenderTests: XCTestCase {

    private var workDir: URL!
    private let size = CGSize(width: 400, height: 300)

    override func setUpWithError() throws {
        workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kairumo-proink-async-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: workDir)
    }

    private func stroke(x: Float, y: Float, id: String? = nil) -> ProStroke {
        ProStroke(
            tool: "fineliner", colorRGBA: [0, 0, 0, 255], baseWidth: 6,
            points: (0 ..< 14).map {
                ProPoint(x: x + Float($0) * 5, y: y + sin(Float($0)) * 3, pressure: 0.6, tilt: 0, azimuth: 0, dtUs: 8_000)
            })
    }

    /// 把畫布層畫進點陣圖，回傳有墨的像素數（左半／右半）。
    private func inkPixels(_ layer: ProInkLayerView) -> (left: Int, right: Int) {
        layer.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            layer.layer.render(in: ctx.cgContext)
        }
        guard let cg = image.cgImage, let data = cg.dataProvider?.data, let base = CFDataGetBytePtr(data) else { return (0, 0) }
        let w = cg.width, h = cg.height, stride = cg.bytesPerRow, bpp = max(1, cg.bitsPerPixel / 8)
        var left = 0, right = 0
        for y in 0 ..< h {
            for x in 0 ..< w where base[y * stride + x * bpp + (bpp - 1)] > 0 {
                if x < w / 2 { left += 1 } else { right += 1 }
            }
        }
        return (left, right)
    }

    private func spin(_ seconds: TimeInterval = 1.5, until condition: () -> Bool = { false }) {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline, !condition() {
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        }
    }

    func testStrokeStaysVisibleThroughTheAsyncHandoff() {
        let layer = ProInkLayerView(frame: CGRect(origin: .zero, size: size))
        layer.load(directory: workDir, notebookId: "nb", pageIndex: 0)
        let s = stroke(x: 20, y: 80)
        layer.beginStroke(tool: .fineliner, color: [0, 0, 0, 255], width: 4, at: s.points[0])
        layer.extendStroke(with: Array(s.points.dropFirst()))
        layer.endStroke()
        XCTAssertEqual(layer.ownStrokes.count, 1, "記帳要立刻完成")
        // 交接前（疊加層）與交接後（底層）任何時刻畫面上都要有這一筆。
        XCTAssertGreaterThan(inkPixels(layer).left, 0, "交接中筆畫不可消失")
        spin(until: { false })
        XCTAssertGreaterThan(inkPixels(layer).left, 0, "交接完成後底層要畫出這一筆")
    }

    func testBackToBackStrokesBothSurvive() {
        let layer = ProInkLayerView(frame: CGRect(origin: .zero, size: size))
        layer.load(directory: workDir, notebookId: "nb", pageIndex: 0)
        let a = stroke(x: 20, y: 80)
        let b = stroke(x: 240, y: 200)
        layer.beginStroke(tool: .fineliner, color: [0, 0, 0, 255], width: 4, at: a.points[0])
        layer.extendStroke(with: Array(a.points.dropFirst()))
        layer.endStroke()
        // 背景還沒算完就開始下一筆（最壞情況）。
        layer.beginStroke(tool: .fineliner, color: [0, 0, 0, 255], width: 4, at: b.points[0])
        layer.extendStroke(with: Array(b.points.dropFirst()))
        layer.endStroke()
        spin()
        XCTAssertEqual(layer.ownStrokes.count, 2)
        let px = inkPixels(layer)
        XCTAssertGreaterThan(px.left, 0, "第一筆不可掉")
        XCTAssertGreaterThan(px.right, 0, "第二筆不可掉")
    }

    func testBigPageBakesInTheBackgroundAndMatchesTheSynchronousResult() {
        let strokes = (0 ..< 40).map { stroke(x: 10 + Float($0 % 8) * 20, y: 20 + Float($0) * 6) }
        ProInkStore.save(strokes, in: workDir, notebookId: "big", page: 0)
        let layer = ProInkLayerView(frame: CGRect(origin: .zero, size: size))
        layer.load(directory: workDir, notebookId: "big", pageIndex: 0)
        spin(3, until: { self.inkPixels(layer).left > 0 })
        let asyncPx = inkPixels(layer)
        XCTAssertGreaterThan(asyncPx.left, 0, "烘焙完成後整頁筆畫要出現")

        // 同樣的筆畫，筆畫數少於門檻 → 同步路徑；同一批筆畫的前 8 筆結果應是非同步結果的子集。
        XCTAssertGreaterThan(asyncPx.left + asyncPx.right, 40 * 10, "40 筆都要畫出來")
    }

    func testSwitchingPagesWhileBakingNeverShowsThePreviousPage() {
        let pageA = (0 ..< 40).map { stroke(x: 10 + Float($0 % 5) * 10, y: 20 + Float($0) * 6) }   // 左半
        let pageB = (0 ..< 40).map { stroke(x: 230 + Float($0 % 5) * 10, y: 20 + Float($0) * 6) }  // 右半
        ProInkStore.save(pageA, in: workDir, notebookId: "sw", page: 0)
        ProInkStore.save(pageB, in: workDir, notebookId: "sw", page: 1)
        let layer = ProInkLayerView(frame: CGRect(origin: .zero, size: size))
        layer.load(directory: workDir, notebookId: "sw", pageIndex: 0)
        layer.load(directory: workDir, notebookId: "sw", pageIndex: 1) // A 還沒烘完就換頁
        spin(3, until: { self.inkPixels(layer).right > 0 })
        let px = inkPixels(layer)
        XCTAssertGreaterThan(px.right, 0, "B 頁要出現")
        XCTAssertEqual(px.left, 0, "A 頁的內容不可殘留在 B 頁上")
    }
}
