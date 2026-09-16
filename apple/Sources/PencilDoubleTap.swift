//
//  PencilDoubleTap.swift
//  Kairumo
//
//  Apple Pencil 二代／Pro 的**雙擊筆桿**（工作項 S-67）。
//
//  # 為什麼要照系統設定走，而不是自己寫死成「切橡皮擦」
//
//  雙擊要做什麼是**系統層級的偏好**（設定 → Apple Pencil），不是每個 App
//  各自決定的。使用者可能已經把它設成「顯示調色盤」或「關閉」，一個 App
//  自作主張把它當成橡皮擦開關，會變成「同一個動作在每個 App 裡意思都不同」。
//
//  所以這裡讀 `UIPencilInteraction.preferredTapAction`，照它的意思做：
//
//  | 系統設定 | 這裡的行為 |
//  |---|---|
//  | 切換橡皮擦 | 目前是橡皮擦就切回**上一支筆**，否則切成橡皮擦 |
//  | 切換上一個工具 | 一律切回上一支筆 |
//  | 顯示調色盤／顯示墨水屬性 | 打開筆刷設定面板 |
//  | 關閉 | 什麼也不做 |
//
//  「切回上一支筆」記的是**最後用過的筆刷**而不是「前一個工具」：後者在
//  連按兩次之後會在橡皮擦與套索之間跳，使用者按第二次想回到的是他的筆。
//
//  # Android 端
//
//  Android **沒有**雙擊筆桿這個事件 —— 那是 Apple Pencil 的硬體特性。
//  對應的原生手勢是**筆桿側鍵**（`BUTTON_STYLUS_PRIMARY`，S Pen 與多數
//  主動式觸控筆都有）。行為那一段是同一份規則（見 `ink/StylusButton.kt`）：
//  切成橡皮擦、放開切回最後用過的筆刷。硬體事件不同，但「切到哪去、
//  再切回哪裡」兩邊一致。
//
//  雙擊事件本身要有**實體 Apple Pencil 二代以上**才發得出來（模擬器沒有
//  這個事件，滑鼠也模擬不了），所以下面的規則表用單元測試驗，實機行為
//  列在 H4。
//

import UIKit

/// 雙擊筆桿之後要發生的事。
enum PencilTapOutcome: Equatable {
    /// 什麼也不做（使用者把雙擊關掉了，或是不認得的設定值）。
    case none
    /// 換成這個工具。
    case tool(EditorToolType)
    /// 打開筆刷設定（粗細與顏色）。
    case showInkAttributes
}

enum PencilDoubleTap {

    /// 系統設定 + 目前狀態 → 要做什麼。
    ///
    /// - Parameters:
    ///   - action: `UIPencilInteraction.preferredTapAction`。
    ///   - current: 目前選中的工具。
    ///   - lastBrush: 最後用過的**筆刷**（不會是橡皮擦或套索）。
    static func outcome(
        action: UIPencilPreferredAction,
        current: EditorToolType,
        lastBrush: EditorToolType
    ) -> PencilTapOutcome {
        // 防呆：呼叫端理論上不會把橡皮擦當成「最後用過的筆刷」傳進來，
        // 但真的發生的話，切換會變成原地不動 —— 退回預設的筆。
        let brush = lastBrush.isBrush ? lastBrush : .pen

        switch action {
        case .ignore:
            return .none
        case .switchEraser:
            return .tool(current == .eraser ? brush : .eraser)
        case .switchPrevious:
            return .tool(brush)
        case .showColorPalette, .showInkAttributes:
            return .showInkAttributes
        @unknown default:
            // 未來新增的設定值：什麼也不做，而不是猜一個。猜錯的話使用者
            // 會在寫字寫到一半突然換掉工具，而且找不到原因。
            return .none
        }
    }
}

/// 把 `UIPencilInteraction` 掛上畫布，並把敲擊轉成一個回呼。
///
/// 寫成獨立的 delegate 物件而不是塞進 `CanvasRepresentable.Coordinator`：
/// 新舊兩套 delegate 方法（iOS 17.5 換過一次）擺在一起會讓那個已經很長的
/// 類別更難讀，而且這一段跟畫布的其他職責沒有任何共用狀態。
final class PencilTapForwarder: NSObject, UIPencilInteractionDelegate {

    /// 雙擊發生了。參數是當下的系統偏好 —— 對應規則見 `PencilDoubleTap`。
    var onTap: ((UIPencilPreferredAction) -> Void)?

    /// iOS 17.5 起的新方法。
    @available(iOS 17.5, *)
    func pencilInteraction(
        _ interaction: UIPencilInteraction,
        didReceiveTap tap: UIPencilInteraction.Tap
    ) {
        onTap?(UIPencilInteraction.preferredTapAction)
    }

    /// iOS 17.5 之前的方法。兩個都要留 —— 系統只會呼叫其中一個，
    /// 而部署目標低於 17.5 的裝置上只有這一個存在。
    @available(iOS, deprecated: 17.5)
    func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
        onTap?(UIPencilInteraction.preferredTapAction)
    }
}
