//
//  RuledWritingTests.swift
//  KairumoTests
//
//  文字模式「隨點即書」的幾何：基準線坐在格線上、一行一行對著格線寫、方塊跟著內容長高。
//  這些全是算術，所以每個數字都釘住 —— 這件事壞過兩次，兩次都是「差幾點」。
//

import XCTest
@testable import Kairumo

final class RuledWritingTests: XCTestCase {

    private func band(y: Float, step: Float, count: UInt32, vertical: Bool = false) -> FfiTextureBand {
        FfiTextureBand(
            kind: .line, x: 40, y: y, w: vertical ? 0 : 700, h: vertical ? 700 : 0,
            stepX: 0, stepY: step, count: count, step2X: 0, step2Y: 0, count2: 1,
            weight: 0.5, tone: .light)
    }

    private func guide(y: Float) -> FfiGuide {
        FfiGuide(kind: .line, x: 40, y: y, w: 700, h: 0, tone: .muted, weight: 1,
                 textKey: "", size: 0, align: 0)
    }

    /// 28 點一條、從 y=100 開始的橫線紙。
    private var lined: [CGFloat] {
        RuledWriting.horizontalRules(guides: [], bands: [band(y: 100, step: 28, count: 30)])
    }

    // MARK: 找格線

    func testRulesComeFromTheTextureEvenWhenTheGuidesAreNotEmpty() {
        // 橫線紙常有一條表頭分隔線，導引線因此不是空的。原本只有「導引線是空的才看底紋」，
        // 底紋那幾十條橫線全被忽略 —— 附近沒有線可以吸附。
        let rules = RuledWriting.horizontalRules(
            guides: [guide(y: 60)], bands: [band(y: 100, step: 28, count: 5)])
        XCTAssertEqual(rules, [60, 100, 128, 156, 184, 212])
    }

    func testVerticalLinesAreNotRules() {
        let rules = RuledWriting.horizontalRules(
            guides: [], bands: [band(y: 100, step: 28, count: 5, vertical: true)])
        XCTAssertTrue(rules.isEmpty)
    }

    func testDuplicateRulesCollapse() {
        let rules = RuledWriting.horizontalRules(
            guides: [guide(y: 100)], bands: [band(y: 100.2, step: 28, count: 3)])
        XCTAssertEqual(rules.count, 3)
    }

    func testTheStepIsTheMedianGap() {
        XCTAssertEqual(RuledWriting.step(of: lined), 28)
        // 一條表頭線離得遠，不能把間距拉走。
        XCTAssertEqual(RuledWriting.step(of: [20] + lined), 28)
        XCTAssertNil(RuledWriting.step(of: [100, 400]), "只有兩條線不是橫線紙")
        XCTAssertNil(RuledWriting.step(of: [100, 300, 500, 700]), "間距 200 是版面分隔，不是讓人寫字的行")
    }

    // MARK: 擺放

    func testTheBaselineSitsOnTheRule() throws {
        let p = try XCTUnwrap(RuledWriting.placement(tapY: 140, rules: lined, fontSize: 16, minTop: 40))
        let bottom = p.top + RuledWriting.textBottomOffset(fontSize: p.fontSize)
        XCTAssertEqual(bottom, p.rule, accuracy: 0.01, "第一行文字貼著格線上方，以格線為底")
    }

    func testEverySecondLineLandsOnTheNextRule() throws {
        let p = try XCTUnwrap(RuledWriting.placement(tapY: 140, rules: lined, fontSize: 16, minTop: 40))
        // 行高 + 行距 = 格線間距 ⇒ 第二行基準線 = 第一行 + 間距。
        XCTAssertEqual(RuledWriting.lineHeight(fontSize: p.fontSize) + p.lineSpacing, p.step, accuracy: 0.01)
        XCTAssertEqual(p.step, 28)
    }

    func testTappingBetweenTwoRulesWritesOnTheLowerOne() throws {
        // 規則在 100、128、156…；點在 110（128 上方的空白）→ 寫在 128。
        let p = try XCTUnwrap(RuledWriting.placement(tapY: 110, rules: lined, fontSize: 16, minTop: 0))
        XCTAssertEqual(p.rule, 128)
    }

    func testTappingJustBelowARuleStillMeansThatRule() throws {
        // 點在 128 線下一點點（不到間距的 30%）→ 還是 128，不是跳到 156。
        let p = try XCTUnwrap(RuledWriting.placement(tapY: 132, rules: lined, fontSize: 16, minTop: 0))
        XCTAssertEqual(p.rule, 128)
        let far = try XCTUnwrap(RuledWriting.placement(tapY: 140, rules: lined, fontSize: 16, minTop: 0))
        XCTAssertEqual(far.rule, 156)
    }

    func testTheBoxNeverStartsAboveThePrintableArea() throws {
        let p = try XCTUnwrap(RuledWriting.placement(tapY: 90, rules: lined, fontSize: 16, minTop: 80))
        XCTAssertGreaterThanOrEqual(p.top, 80, "第一條格線太靠上時要換到下一條，不能讓方塊跑出可用範圍")
        let bottom = p.top + RuledWriting.textBottomOffset(fontSize: p.fontSize)
        XCTAssertEqual(bottom, p.rule, accuracy: 0.01)
    }

    func testTheFontShrinksWhenARowCannotHoldIt() throws {
        let tight = RuledWriting.horizontalRules(guides: [], bands: [band(y: 100, step: 16, count: 30)])
        let p = try XCTUnwrap(RuledWriting.placement(tapY: 140, rules: tight, fontSize: 24, minTop: 0))
        XCTAssertLessThan(p.fontSize, 24)
        XCTAssertLessThanOrEqual(RuledWriting.lineHeight(fontSize: p.fontSize), p.step)
    }

    func testBlankPaperHasNoRuledPlacementAndFallsBackToFreePlacement() {
        XCTAssertNil(RuledWriting.placement(tapY: 200, rules: [], fontSize: 16, minTop: 0))
        let free = RuledWriting.freePlacement(tapY: 300, fontSize: 16, minTop: 0)
        let center = free.top + RuledWriting.padding + RuledWriting.lineHeight(fontSize: 16) / 2
        XCTAssertEqual(center, 300, accuracy: 0.01, "點的位置就是第一行文字的垂直中心")
        XCTAssertEqual(free.lineSpacing, 0)
    }

    // MARK: 高度

    func testPaddingNeverShrinksSoTheFirstLineCannotSlideOffTheRule() {
        // TextBoxMetrics 在小方塊上會縮內距，方塊一長大內距就跳回 14 —— 文字會往下掉 8 點。
        XCTAssertEqual(RuledWriting.padding, 14)
        XCTAssertEqual(
            TextBoxMetrics.padding(width: 300, height: RuledWriting.fullPaddingHeight),
            RuledWriting.padding)
        XCTAssertGreaterThanOrEqual(
            RuledWriting.boxHeight(text: "", width: 300, fontSize: 16, bold: false, lineSpacing: 0),
            RuledWriting.fullPaddingHeight)
    }

    func testTheBoxGrowsWithTheContent() {
        let one = RuledWriting.boxHeight(text: "一行", width: 300, fontSize: 16, bold: false, lineSpacing: 9)
        let many = RuledWriting.boxHeight(
            text: String(repeating: "很長的一段文字，", count: 40), width: 300, fontSize: 16,
            bold: false, lineSpacing: 9)
        XCTAssertGreaterThan(many, one + 28 * 3, "文字換行之後方塊要長高，不然後面的字被裁掉")
    }

    func testATrailingNewlineCountsBecauseTheCaretIsOnTheNextLine() {
        let without = RuledWriting.boxHeight(text: "a", width: 300, fontSize: 16, bold: false, lineSpacing: 9)
        let with = RuledWriting.boxHeight(text: "a\n", width: 300, fontSize: 16, bold: false, lineSpacing: 9)
        XCTAssertGreaterThan(with, without)
    }
}
