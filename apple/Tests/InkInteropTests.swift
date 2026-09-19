//
//  InkInteropTests.swift
//  KairumoTests
//
//  PKDrawing ⇄ 核心筆畫格式的往返比對（工作包 WP4 的驗收依據）。
//
//  為什麼要有這個測試 target：轉換器只能寫在 Apple 端（只有 PencilKit 解析得了
//  PKDrawing），那麼它對不對也只能在 Apple 端證明。用眼睛看畫面「差不多一樣」
//  抓不到座標偏移半個點、或壓感整段飽和這種錯 —— 那正是使用者最後會抱怨
//  「Android 打開變了樣」的原因。
//

import XCTest
import PencilKit
@testable import Kairumo

final class InkInteropTests: XCTestCase {

    // MARK: - 測試資料

    /// 造一筆有壓感變化、有傾斜、有時間差的筆畫。
    ///
    /// 數值刻意取不規則的小數：整數與 0 很容易讓「欄位接錯位置」蒙混過關。
    private func sampleStroke(
        inkType: PKInk.InkType = .pen,
        color: UIColor = UIColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1.0)
    ) -> PKStroke {
        let specs: [(CGPoint, CGFloat, TimeInterval, CGFloat, CGFloat)] = [
            // 位置, 寬度, 時間位移, 方位, 仰角
            (CGPoint(x: 12.5, y: 300.25), 8.0, 0.0, 1.5, .pi / 2),
            (CGPoint(x: 13.75, y: 301.5), 5.0, 0.008, 1.75, 1.2),
            (CGPoint(x: 60.0, y: 280.125), 2.8, 0.016, 4.5, 0.6),
            (CGPoint(x: 61.5, y: 279.0), 8.0, 0.024, 0.25, 1.4)
        ]
        let points = specs.map { spec in
            PKStrokePoint(
                location: spec.0,
                timeOffset: spec.2,
                size: CGSize(width: spec.1, height: spec.1),
                opacity: 1,
                force: 1,
                azimuth: spec.3,
                altitude: spec.4
            )
        }
        let path = PKStrokePath(controlPoints: points, creationDate: Date(timeIntervalSince1970: 0))
        return PKStroke(ink: PKInk(inkType, color: color), path: path)
    }

    // MARK: - 寬度 ⇄ 壓感

    func testWidthAndPressureAreExactInverses() {
        // 這條對應若寫反，同一筆畫在 Android 會偏細 —— 而且在 iPad 上完全看不出來。
        let base: Float = 10
        for pressure in stride(from: Float(0), through: 1, by: 0.05) {
            let w = InkInterop.width(forPressure: pressure, baseWidth: base, tool: .fountainPen)
            let back = InkInterop.pressure(forWidth: w, baseWidth: base)
            XCTAssertEqual(back, pressure, accuracy: 1e-5, "壓感 \(pressure) 沒有原樣回來")
        }
    }

    func testPressureIsIgnoredForConstantWidthTools() {
        // 與核心 Tool::is_pressure_sensitive() 一致：原子筆與螢光筆固定寬度。
        for tool in [ToolKind.ballPoint, .highlighter] {
            XCTAssertEqual(InkInterop.width(forPressure: 0, baseWidth: 7, tool: tool), 7)
            XCTAssertEqual(InkInterop.width(forPressure: 1, baseWidth: 7, tool: tool), 7)
        }
    }

    func testZeroBaseWidthDoesNotProduceNaN() {
        // 空筆畫或退化資料不該把整份筆記轉成 NaN 座標。
        let p = InkInterop.pressure(forWidth: 3, baseWidth: 0)
        XCTAssertFalse(p.isNaN)
    }

    // MARK: - 顏色

    func testColorRoundTripsThroughEightBitRgba() {
        let original = UIColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 0.5)
        let bytes = InkInterop.rgba(from: original)
        XCTAssertEqual(Array(bytes), [51, 102, 153, 128])

        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        InkInterop.color(fromRGBA: bytes).getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(Float(r), 0.2, accuracy: 0.004)
        XCTAssertEqual(Float(g), 0.4, accuracy: 0.004)
        XCTAssertEqual(Float(b), 0.6, accuracy: 0.004)
        XCTAssertEqual(Float(a), 0.5, accuracy: 0.004)
    }

    func testShortColorDataDoesNotCrash() {
        // FFI 邊界回來的資料不可信 —— 少於 4 個位元組要補滿而不是當掉。
        XCTAssertNotNil(InkInterop.color(fromRGBA: Data([1, 2])))
    }

    // MARK: - PKDrawing → 核心

    func testDraftKeepsEveryControlPoint() {
        let stroke = sampleStroke()
        let draft = InkInterop.draft(from: stroke)
        XCTAssertEqual(draft.points.count, stroke.path.count, "控制點不能在轉換時被重新取樣")
    }

    func testDraftAppliesStrokeTransform() {
        // PKStroke 的 transform 若沒套上，套索搬移過的筆畫在 Android 會回到原位。
        let moved = PKStroke(
            ink: sampleStroke().ink,
            path: sampleStroke().path,
            transform: CGAffineTransform(translationX: 100, y: -40)
        )
        let draft = InkInterop.draft(from: moved)
        XCTAssertEqual(draft.points[0].x, 112.5, accuracy: 1e-4)
        XCTAssertEqual(draft.points[0].y, 260.25, accuracy: 1e-4)
    }

    func testTiltIsTheComplementOfAltitude() {
        // altitude 是「與螢幕的夾角」，tilt 是「偏離垂直的角度」。
        // 直接對接的話，筆越立起來核心會以為越躺平。
        let draft = InkInterop.draft(from: sampleStroke())
        // 容差 1e-4 而非 1e-5：PKStrokePoint 存回來的 altitude 本身就有量化誤差
        // （寫入 0.6 讀回 0.60001…）。這是 PencilKit 的儲存精度，不是轉換誤差 ——
        // 把容差收到比它還小，測試會紅在一個我們不能也不該修的地方。
        XCTAssertEqual(draft.points[0].tilt, 0, accuracy: 1e-4, "垂直握筆的 tilt 應為 0")
        XCTAssertEqual(draft.points[2].tilt, Float.pi / 2 - 0.6, accuracy: 1e-4)
    }

    func testTimeDeltasAreMicrosecondsBetweenPoints() {
        let draft = InkInterop.draft(from: sampleStroke())
        XCTAssertEqual(draft.points[0].dtUs, 0, "第一點沒有前一點，時間差必須是 0")
        XCTAssertEqual(draft.points[1].dtUs, 8_000)
    }

    func testLongPauseIsClampedToFormatLimit() {
        // 格式規格 §5.4 的 dt 是 u16 微秒。停筆三秒不該讓數值繞回去變成很小的值。
        let points = [
            PKStrokePoint(location: .zero, timeOffset: 0, size: CGSize(width: 4, height: 4),
                          opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2),
            PKStrokePoint(location: CGPoint(x: 1, y: 1), timeOffset: 3.0,
                          size: CGSize(width: 4, height: 4),
                          opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        ]
        let stroke = PKStroke(
            ink: PKInk(.pen, color: .black),
            path: PKStrokePath(controlPoints: points, creationDate: Date(timeIntervalSince1970: 0))
        )
        XCTAssertEqual(InkInterop.draft(from: stroke).points[1].dtUs, 65_535)
    }

    func testToolMappingCoversEveryCoreTool() {
        XCTAssertEqual(InkInterop.toolKind(for: .pen), .fountainPen)
        XCTAssertEqual(InkInterop.toolKind(for: .pencil), .pencil)
        XCTAssertEqual(InkInterop.toolKind(for: .marker), .marker)
    }

    // MARK: - 核心 → PKDrawing

    func testStrokeRebuiltFromCoreMatchesTheOriginalGeometry() {
        let original = sampleStroke()
        let draft = InkInterop.draft(from: original)

        // 模擬「核心把它存起來又讀回來」：欄位一一對應，id 與時間戳由核心產生。
        let full = FullStroke(
            id: "00000000-0000-7000-8000-000000000001",
            startedAtUs: 0,
            tool: draft.tool,
            colorRgba: draft.colorRgba,
            baseWidth: draft.baseWidth,
            points: draft.points
        )
        let rebuilt = InkInterop.stroke(from: full)

        XCTAssertEqual(rebuilt.path.count, original.path.count)
        for i in 0..<original.path.count {
            let o = original.path[i], r = rebuilt.path[i]
            XCTAssertEqual(r.location.x, o.location.x, accuracy: 1e-4, "第 \(i) 點 x")
            XCTAssertEqual(r.location.y, o.location.y, accuracy: 1e-4, "第 \(i) 點 y")
            XCTAssertEqual(r.size.width, o.size.width, accuracy: 1e-3, "第 \(i) 點寬度")
            XCTAssertEqual(r.altitude, o.altitude, accuracy: 1e-4, "第 \(i) 點仰角")
            XCTAssertEqual(r.timeOffset, o.timeOffset, accuracy: 1e-4, "第 \(i) 點時間位移")
        }
    }

    func testDrawingRoundTripKeepsStrokeCountAndOrder() {
        let drawing = PKDrawing(strokes: [
            sampleStroke(inkType: .pen, color: .red),
            sampleStroke(inkType: .marker, color: .green),
            sampleStroke(inkType: .pencil, color: .blue)
        ])
        let drafts = InkInterop.drafts(from: drawing)
        XCTAssertEqual(drafts.count, 3)

        let fulls = drafts.enumerated().map { index, d in
            FullStroke(
                id: "00000000-0000-7000-8000-00000000000\(index)",
                startedAtUs: 0,
                tool: d.tool,
                colorRgba: d.colorRgba,
                baseWidth: d.baseWidth,
                points: d.points
            )
        }
        let rebuilt = InkInterop.drawing(from: fulls)
        XCTAssertEqual(rebuilt.strokes.count, 3, "筆畫數與順序就是驗收條件本身")
        XCTAssertEqual(InkInterop.rgba(from: rebuilt.strokes[1].ink.color),
                       InkInterop.rgba(from: drawing.strokes[1].ink.color))
    }

    func testEmptyDrawingProducesNoDrafts() {
        XCTAssertTrue(InkInterop.drafts(from: PKDrawing()).isEmpty)
    }
}
