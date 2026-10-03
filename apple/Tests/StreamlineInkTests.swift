import XCTest

@testable import Kairumo

/// 筆跡流線防抖（Streamline）與筆尾動態出鋒（Taper）整合測試。
@MainActor
final class StreamlineInkTests: XCTestCase {

    func testStreamlineSmoothPointsViaSwiftBridge() {
        let input: [StrokePoint] = [
            StrokePoint(x: 0, y: 0, pressure: 0.8, tilt: 0, azimuth: 0, dtUs: 0, roll: 0),
            StrokePoint(x: 10, y: 3, pressure: 0.8, tilt: 0, azimuth: 0, dtUs: 10, roll: 0),
            StrokePoint(x: 20, y: -3, pressure: 0.8, tilt: 0, azimuth: 0, dtUs: 20, roll: 0),
            StrokePoint(x: 30, y: 2, pressure: 0.8, tilt: 0, azimuth: 0, dtUs: 30, roll: 0),
            StrokePoint(x: 40, y: 0, pressure: 0.8, tilt: 0, azimuth: 0, dtUs: 40, roll: 0),
        ]

        let smoothed = streamlineSmoothPoints(points: input, amount: 0.4, gamma: 1.0, taper: 0.25)
        XCTAssertEqual(smoothed.count, input.count, "輸出點數必須與輸入點數嚴格一致")

        // 驗證首點與末點座標貼合
        XCTAssertEqual(smoothed.first?.x, 0)
        XCTAssertEqual(smoothed.last?.x, 40)

        // 驗證出鋒：最後一點的壓感必須衰減
        let lastPressure = smoothed.last?.pressure ?? 1.0
        XCTAssertLessThan(lastPressure, 0.3, "揮筆收尾時末點壓感必須漸縮出鋒")
    }

    func testEmptyOrSinglePointHandledSafely() {
        let empty = streamlineSmoothPoints(points: [], amount: 0.5, gamma: 1.0, taper: 0.2)
        XCTAssertTrue(empty.isEmpty)

        let single = [StrokePoint(x: 5, y: 5, pressure: 0.5, tilt: 0, azimuth: 0, dtUs: 0, roll: 0)]
        let smoothedSingle = streamlineSmoothPoints(points: single, amount: 0.5, gamma: 1.0, taper: 0.2)
        XCTAssertEqual(smoothedSingle.count, 1)
    }

    func testSmartFillAtClosedPolygonViaSwiftSession() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let session = try PadnoteSession.create(path: tempDir.path, title: "填色測試", nowUnixMs: 1000, deviceId: 1)
        let pageId = session.pageIdAt(index: 0)!

        // 畫一個閉合正方形
        let half: Float = 30
        let cx: Float = 100
        let cy: Float = 100
        func pt(_ x: Float, _ y: Float) -> StrokePoint {
            StrokePoint(x: x, y: y, pressure: 0.5, tilt: 0, azimuth: 0, dtUs: 10, roll: 0)
        }
        let black = Data([0, 0, 0, 255])
        _ = try session.addStroke(pageId: pageId, tool: .fineliner, colorRgba: black, baseWidth: 3, points: [pt(cx - half, cy - half), pt(cx + half, cy - half)])
        _ = try session.addStroke(pageId: pageId, tool: .fineliner, colorRgba: black, baseWidth: 3, points: [pt(cx + half, cy - half), pt(cx + half, cy + half)])
        _ = try session.addStroke(pageId: pageId, tool: .fineliner, colorRgba: black, baseWidth: 3, points: [pt(cx + half, cy + half), pt(cx - half, cy + half)])
        _ = try session.addStroke(pageId: pageId, tool: .fineliner, colorRgba: black, baseWidth: 3, points: [pt(cx - half, cy + half), pt(cx - half, cy - half)])

        // 在中心填色
        let colorData = Data([0, 120, 255, 180])
        let filledId = try session.smartFillAt(pageId: pageId, seedX: cx, seedY: cy, colorRgba: colorData)
        XCTAssertNotNil(filledId, "閉合多邊形中心應成功偵測並填色")

        // 驗證總筆畫數由 4 增加為 5
        let visible = try session.visibleStrokes(pageId: pageId)
        XCTAssertEqual(visible.count, 5)

        // 在外側未封閉處填色應回傳 nil
        let leak = try session.smartFillAt(pageId: pageId, seedX: 500, seedY: 500, colorRgba: colorData)
        XCTAssertNil(leak, "未封閉處填色應安全返回 nil")
    }
}
