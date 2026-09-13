//
//  BrushCursorTests.swift
//  KairumoTests
//
//  筆頭游標與拖曳式筆寬。
//
//  重點是**游標顯示的粗細要跟實際畫出來的一致** —— 不一致的話這個功能
//  就從「先看得見」變成「誤導」。
//

import XCTest
@testable import Kairumo

final class BrushCursorTests: XCTestCase {

    func testEveryDrawingToolHasATip() {
        // 少一個工具就會在選它的時候跳回箭頭 —— 使用者會以為自己沒選到。
        for tool in EditorToolType.allCases where tool != .lasso {
            XCTAssertNotNil(BrushCursor.path(for: tool, strokeWidth: 8),
                            "\(tool.rawValue) 沒有筆頭")
        }
    }

    func testLassoKeepsTheSystemPointer() {
        // 十字準心是系統既有的語彙，自己畫一個只會更難認。
        XCTAssertNil(BrushCursor.path(for: .lasso, strokeWidth: 8))
    }

    func testTheTipGrowsWithTheStrokeWidth() {
        // 這是整個功能的重點：拖筆寬時游標要同步變化。
        let thin = BrushCursor.tipDiameter(for: .pen, strokeWidth: 2)
        let thick = BrushCursor.tipDiameter(for: .pen, strokeWidth: 20)
        XCTAssertGreaterThan(thick, thin)
    }

    func testTheTipNeverDisappearsAtTinyWidths() {
        // 1pt 的筆頭在螢幕上小到看不見，使用者會以為游標壞了。
        XCTAssertGreaterThanOrEqual(BrushCursor.tipDiameter(for: .ballpoint, strokeWidth: 1), 8)
    }

    func testTheTipNeverCoversWhatYouAreAboutToDraw() {
        // 太大的游標會擋住自己要畫（或正要擦）的地方。
        XCTAssertLessThanOrEqual(
            BrushCursor.tipDiameter(for: .highlighter, strokeWidth: 100),
            BrushCursor.maxSide)
    }

    func testTipScalesMatchWhatIsFedToPencilKit() {
        // 游標顯示的粗細若跟實際畫出來的不一樣，這個功能就變成誤導。
        // 這幾個倍率必須與 `applyTool` 裡餵給 PKInkingTool 的一致。
        XCTAssertEqual(BrushCursor.tipScale(for: .ballpoint), 0.65, accuracy: 0.001)
        XCTAssertEqual(BrushCursor.tipScale(for: .pen), 1.1, accuracy: 0.001)
        XCTAssertEqual(BrushCursor.tipScale(for: .brush), 2.2, accuracy: 0.001)
        XCTAssertEqual(BrushCursor.tipScale(for: .marker), 2.8, accuracy: 0.001)
        XCTAssertEqual(BrushCursor.tipScale(for: .highlighter), 3.8, accuracy: 0.001)
    }

    func testTheHighlighterTipIsWiderThanTheBallpointAtTheSameWidth() {
        // 兩種筆頭在同一個筆寬下必須看得出差別，否則換筆刷等於沒有回饋。
        XCTAssertGreaterThan(
            BrushCursor.tipDiameter(for: .highlighter, strokeWidth: 4),
            BrushCursor.tipDiameter(for: .ballpoint, strokeWidth: 4))
    }

    // MARK: - 滑桿

    func testTheSliderRangeCoversTheDotPresets() {
        // 四個點點是 2 / 4 / 8 / 14。滑桿的範圍沒涵蓋它們的話，
        // 先點點再拉滑桿會讓數值莫名跳走。
        for preset in [2.0, 4.0, 8.0, 14.0] {
            XCTAssertTrue(StrokeWidthSlider.range.contains(CGFloat(preset)))
        }
    }

    func testTheSliderUpperBoundIsUsable() {
        // 上限太高的話滑桿的精度會整個被吃掉 —— 常用的 2–14 會擠在最左邊一小段。
        XCTAssertLessThanOrEqual(StrokeWidthSlider.range.upperBound, 40)
        XCTAssertGreaterThanOrEqual(StrokeWidthSlider.range.upperBound, 20)
    }

    func testThePreviewIsCappedSoTheToolbarDoesNotGrow() {
        let slider = StrokeWidthSlider(width: .constant(30), tool: .highlighter, color: .black)
        XCTAssertLessThanOrEqual(slider.previewDiameter, StrokeWidthSlider.previewCap)
    }

    func testThePreviewTracksTheWidth() {
        let thin = StrokeWidthSlider(width: .constant(2), tool: .pen, color: .black)
        let thick = StrokeWidthSlider(width: .constant(12), tool: .pen, color: .black)
        XCTAssertGreaterThan(thick.previewDiameter, thin.previewDiameter)
    }
}
