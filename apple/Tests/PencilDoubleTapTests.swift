//
//  PencilDoubleTapTests.swift
//  KairumoTests
//
//  Apple Pencil 雙擊筆桿的對應規則（工作項 S-67）。
//
//  **雙擊事件本身在這裡驗不到** —— 它要實體 Apple Pencil 二代以上才發得
//  出來，模擬器沒有這個事件，滑鼠也模擬不了（實機行為列 H4）。能驗的是
//  「收到雙擊之後要做什麼」那張對應表，而那正是會寫錯的地方：切過去容易，
//  切回來要切到哪支筆才是真正的判斷。
//

import UIKit
import XCTest
@testable import Kairumo

final class PencilDoubleTapTests: XCTestCase {

    func testIgnoreDoesNothing() {
        // 使用者在系統設定裡把雙擊關掉了。App 不能自作主張還是換工具 ——
        // 那個設定存在的意義就是「我不要這個手勢」。
        XCTAssertEqual(
            PencilDoubleTap.outcome(action: .ignore, current: .pen, lastBrush: .pen),
            .none)
    }

    func testSwitchEraserGoesToEraser() {
        XCTAssertEqual(
            PencilDoubleTap.outcome(action: .switchEraser, current: .brush, lastBrush: .brush),
            .tool(.eraser))
    }

    func testSwitchEraserComesBackToTheLastBrushNotTheDefaultPen() {
        // 再敲一次要回到**他剛才在用的筆**。回到預設的鋼筆的話，
        // 用水彩筆的人每擦一次就得重選一次筆。
        XCTAssertEqual(
            PencilDoubleTap.outcome(action: .switchEraser, current: .eraser, lastBrush: .watercolor),
            .tool(.watercolor))
    }

    func testSwitchPreviousAlwaysReturnsToTheBrush() {
        XCTAssertEqual(
            PencilDoubleTap.outcome(action: .switchPrevious, current: .eraser, lastBrush: .marker),
            .tool(.marker))
        XCTAssertEqual(
            PencilDoubleTap.outcome(action: .switchPrevious, current: .lasso, lastBrush: .marker),
            .tool(.marker))
    }

    func testPaletteActionsOpenTheInkPanel() {
        XCTAssertEqual(
            PencilDoubleTap.outcome(action: .showColorPalette, current: .pen, lastBrush: .pen),
            .showInkAttributes)
        XCTAssertEqual(
            PencilDoubleTap.outcome(action: .showInkAttributes, current: .pen, lastBrush: .pen),
            .showInkAttributes)
    }

    func testANonBrushLastToolNeverMakesTheSwitchANoOp() {
        // 呼叫端理論上不會這樣傳，但真的傳了的話，「切回上一支筆」不能
        // 變成「切回橡皮擦」—— 那會讓雙擊看起來完全沒反應。
        for stale in [EditorToolType.eraser, .lasso] {
            let outcome = PencilDoubleTap.outcome(
                action: .switchEraser, current: .eraser, lastBrush: stale)
            XCTAssertEqual(outcome, .tool(.pen), "lastBrush = \(stale) 時切回了 \(outcome)")
        }
    }

    func testEveryBrushCanBeReturnedTo() {
        // 新增一支筆卻忘了讓它進 `isBrush`，症狀是「用那支筆時雙擊擦完
        // 回不去」。這裡把九個工具全跑一次，讓那種遺漏在這邊就被擋下。
        for tool in EditorToolType.allCases where tool.isBrush {
            XCTAssertEqual(
                PencilDoubleTap.outcome(action: .switchPrevious, current: .eraser, lastBrush: tool),
                .tool(tool),
                "\(tool) 切不回去")
        }
    }
}
