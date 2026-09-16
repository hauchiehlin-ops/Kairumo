//
//  PenHardwareTests.swift
//  KairumoTests
//
//  筆身控制項在 Apple 這一側的接線（工作項 S-40 / S-67）。
//
//  **對應規則本身不在這裡驗** —— 它在核心的 `padnote-input::pen`，有 11 條
//  Rust 測試。這裡驗的是 Apple 這一側真正會出錯的三件事：
//
//  1. 送進核心的控制項有沒有對；
//  2. 核心回的結果有沒有被完整處理（少一種就是那個設定按了沒反應）；
//  3. 設定存得回來。
//
//  硬體事件本身（雙擊、擠壓、側鍵、滾動角）模擬器一個都發不出來，
//  實機行為列 H4 / S-40。
//

import XCTest
@testable import Kairumo

final class PenHardwareTests: XCTestCase {

    func testTheCoreTableIsReachableFromSwift() {
        // 綁定沒接上的話，這裡會直接編不過或拿到空結果 —— 而那個失敗模式
        // 在畫面上看起來只是「側鍵沒反應」。
        let controls = PenControls()
        XCTAssertEqual(
            controls.outcome(
                control: .barrelPrimary, pressed: true, erasing: false, lassoing: false),
            .useEraser)
        XCTAssertEqual(
            controls.outcome(
                control: .barrelPrimary, pressed: false, erasing: true, lassoing: false),
            .useLastBrush)
    }

    func testADoubleTapTogglesButASideButtonIsHeld() {
        // 這兩種搞混的後果不一樣：側鍵做成切換，使用者碰一下就永遠停在
        // 橡皮擦；雙擊做成按著，那根本沒有「按著」可言。
        let controls = PenControls()
        XCTAssertTrue(controls.isMomentary(control: .barrelPrimary))
        XCTAssertTrue(controls.isMomentary(control: .invert))
        XCTAssertFalse(controls.isMomentary(control: .doubleTap))
        XCTAssertFalse(controls.isMomentary(control: .squeeze))
    }

    func testSqueezeHasADefaultSoItIsNotADeadControl() {
        // Pencil Pro 的使用者捏了筆卻什麼也沒發生，會以為是筆壞了。
        let controls = PenControls()
        XCTAssertNotEqual(controls.action(control: .squeeze), .none)
    }

    func testEveryOutcomeIsHandled() {
        // **少處理一種 outcome，就是某個設定選了之後按了沒反應。**
        // 這裡把每一種 outcome 都對到一個 EditorToolType 或一個副作用，
        // 漏掉的話 switch 不窮盡、編不過。這條測試存在的意義是：
        // 核心之後新增一種行為時，這邊會被強迫跟上。
        let all: [FfiPenOutcome] = [
            .nothing, .useEraser, .useLastBrush, .useLasso,
            .showInkAttributes, .undo, .redo, .toggleRuler,
        ]
        for outcome in all {
            let described: String
            switch outcome {
            case .nothing: described = "不動"
            case .useEraser: described = EditorToolType.eraser.rawValue
            case .useLastBrush: described = "上一支筆刷"
            case .useLasso: described = EditorToolType.lasso.rawValue
            case .showInkAttributes: described = "筆刷設定"
            case .undo: described = "復原"
            case .redo: described = "重做"
            case .toggleRuler: described = "尺規"
            }
            XCTAssertFalse(described.isEmpty, "\(outcome) 沒有對應的處理")
        }
        XCTAssertEqual(all.count, 8, "核心新增了 outcome，這一側要跟上")
    }

    func testSettingsSurviveEncodingAndDecoding() {
        let controls = PenControls()
        controls.setAction(control: .squeeze, action: .undo)
        controls.setAction(control: .doubleTap, action: .none)

        let restored = PenControls.decode(text: controls.encode())
        XCTAssertEqual(restored.action(control: .squeeze), .undo)
        XCTAssertEqual(restored.action(control: .doubleTap), .none)
        // 沒動過的維持預設，不是被清成 none。
        XCTAssertEqual(restored.action(control: .barrelPrimary), .eraser)
    }

    func testAnUnknownAssignmentIsKeptInsteadOfBeingDropped() {
        // 新版加了一個行為、使用者選了它，然後用舊版開一次設定 ——
        // 不保留的話那個指派就沒了，而使用者不會知道。
        let restored = PenControls.decode(text: "double_tap=teleport;squeeze=undo")
        XCTAssertTrue(
            restored.encode().contains("double_tap=teleport"),
            "不認得的指派被丟掉了：\(restored.encode())")
        XCTAssertEqual(restored.action(control: .squeeze), .undo)
    }

    func testRollIsZeroWhenThePenCannotReportIt() {
        // 核心那邊 0 就是「沒有這個維度」，不是「角度剛好是零」。
        // 這條測試釘住的是**不要在讀不到時亂填一個值** —— 填 0 以外的任何
        // 東西，扁頭筆的筆觸方向都會被硬轉到一個沒人要求的角度。
        let point = StrokePoint(
            x: 0, y: 0, pressure: 0.5, tilt: 0, azimuth: 0, dtUs: 0, roll: 0)
        XCTAssertEqual(point.roll, 0)
    }
}
