//
//  PenHardware.swift
//  Kairumo
//
//  觸控筆硬體：雙擊、擠壓、側鍵、滾動角、懸停與觸覺回饋
//  （工作項 S-40 / S-67 / H4）。
//
//  # 規則不在這裡
//
//  「按下去要發生什麼」整張表在核心的 `padnote-input::pen`，兩個平台共用。
//  這個檔案只做三件事：
//
//  1. 把系統的硬體事件轉成核心認得的 `FfiPenControl`；
//  2. 把核心回的 `FfiPenOutcome` 換成這個 App 的工具；
//  3. 存／讀使用者改過的對應表。
//
//  原本這裡有一份自己的對應規則（`PencilDoubleTap`），Android 那邊有另一份
//  （`StylusButton.kt`）。同一支筆在兩台裝置上行為不同是遲早的事，所以那兩份
//  都被核心那一張表取代了。
//
//  # 哪些要實機才驗得到
//
//  雙擊與擠壓要實體筆（二代以上／Pro），側鍵要能送出按鍵位元的筆，
//  滾動角要 Pencil Pro。模擬器一個都發不出來。所以這裡刻意把**能在沒有
//  硬體時驗的東西**（對應規則、outcome → 工具的轉換、設定存讀）都留在
//  可測的位置，剩下的列 H4 / S-40。
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// 使用者改過的筆身對應表。存 `UserDefaults`，跟著備份走。
@MainActor
final class PenHardwareSettings: ObservableObject {

    static let shared = PenHardwareSettings()

    private static let key = "kairumo.pen.controls.v1"

    /// 核心那一份表。**唯一的來源** —— 這邊不另外快取一份 Swift 的副本，
    /// 兩份狀態一定會有一個先改到。
    let controls: PenControls

    private init() {
        let saved = UserDefaults.standard.string(forKey: Self.key)
        controls = saved.map { PenControls.decode(text: $0) } ?? PenControls()
    }

    func action(for control: FfiPenControl) -> FfiPenAction {
        controls.action(control: control)
    }

    func setAction(_ action: FfiPenAction, for control: FfiPenControl) {
        controls.setAction(control: control, action: action)
        UserDefaults.standard.set(controls.encode(), forKey: Self.key)
        objectWillChange.send()
    }

    /// 這個控制項是「按著」還是「切換」。設定畫面用它決定怎麼說明。
    func isMomentary(_ control: FfiPenControl) -> Bool {
        controls.isMomentary(control: control)
    }
}

/// 把 `UIPencilInteraction` 的事件轉成核心的控制項。
///
/// 寫成獨立的 delegate 物件而不是塞進畫布的 `Coordinator`：新舊兩套 delegate
/// 方法（iOS 17.5 換過一次）加上擠壓，擺在一起會讓那個已經很長的類別更難讀，
/// 而且這一段跟畫布的其他職責沒有任何共用狀態。
final class PencilInteractionForwarder: NSObject, UIPencilInteractionDelegate {

    /// 筆上發生了一個動作。切換型的控制項 `pressed` 一律是 true。
    var onControl: ((FfiPenControl, Bool) -> Void)?

    // MARK: 雙擊

    /// iOS 17.5 起的方法。
    @available(iOS 17.5, *)
    func pencilInteraction(
        _ interaction: UIPencilInteraction,
        didReceiveTap tap: UIPencilInteraction.Tap
    ) {
        onControl?(.doubleTap, true)
    }

    /// iOS 17.5 之前的方法。兩個都要留 —— 系統只會呼叫其中一個，
    /// 而部署目標低於 17.5 的裝置上只有這一個存在。
    @available(iOS, deprecated: 17.5)
    func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
        onControl?(.doubleTap, true)
    }

    // MARK: 擠壓（Pencil Pro）

    /// **只認 `.ended`。**
    ///
    /// 擠壓會依序送出 began → changed → ended。每一個都回報的話，使用者捏一下
    /// 就會切好幾次工具 —— 而且中途鬆手（`.cancelled`）本來就不該算數。
    @available(iOS 17.5, *)
    func pencilInteraction(
        _ interaction: UIPencilInteraction,
        didReceiveSqueeze squeeze: UIPencilInteraction.Squeeze
    ) {
        guard squeeze.phase == .ended else { return }
        onControl?(.squeeze, true)
    }
}

/// 觸覺回饋。
///
/// # 為什麼不是每個動作都震
///
/// 筆身的動作是**看不見的**：使用者捏一下筆，畫面上只有工具列的一格換了
/// 顏色，而他當下正看著筆尖。一下短回饋讓他知道「剛剛那下有收到」，
/// 不必抬頭確認。
///
/// 但**畫線本身不能有回饋** —— 寫一個字震幾十下，那不是回饋是干擾。
/// 所以這裡只在筆身控制項真的改變了什麼的時候才叫。
@MainActor
enum PenHaptics {

    /// 筆身動作生效了。
    ///
    /// 用 `UICanvasFeedbackGenerator` 而不是 `UIImpactFeedbackGenerator`：
    /// 前者是系統為「畫布上的操作」設計的，力度與時長已經調過，而且在不支援
    /// 觸覺的裝置上會自己安靜地什麼也不做。
    static func penControlFired(in view: UIView?) {
        #if os(iOS)
        guard #available(iOS 17.5, *), let view else { return }
        let generator = UICanvasFeedbackGenerator(view: view)
        generator.alignmentOccurred(at: view.center)
        #endif
    }
}

#if canImport(UIKit)
extension UITouch {
    /// 筆桿沿自身軸線的旋轉角，0–2π。**回報不出來時是 0。**
    ///
    /// 只有 Pencil Pro 有。`rollAngle` 是 iOS 17.5 才有的屬性，低於它的系統
    /// 與其他筆一律當成 0 —— 核心那邊 0 就是「沒有這個維度」，不是「角度剛好
    /// 是零」，扁頭筆的筆觸角度會退回只看傾角。
    var kairumoRollAngle: CGFloat {
        if #available(iOS 17.5, *) {
            return rollAngle
        }
        return 0
    }
}
#endif
import SwiftUI

struct AdvancedPenSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var settings = PenHardwareSettings.shared

    private let controls: [(FfiPenControl, String)] = [
        (.doubleTap, "pen_double_tap"),
        (.squeeze, "pen_squeeze")
    ]
    
    private let actions: [(FfiPenAction, String)] = [
        (.none, "pen_action_none"),
        (.eraser, "pen_action_eraser"),
        (.lastBrush, "pen_action_lastBrush"),
        (.inkAttributes, "pen_action_inkAttributes"),
        (.lasso, "pen_action_lasso"),
        (.undo, "pen_action_undo"),
        (.redo, "pen_action_redo"),
        (.ruler, "pen_action_ruler")
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(LocalizationManager.shared.localized("pen_pressure_apple_note"))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text(LocalizationManager.shared.localized("pen_controls_title"))) {
                    ForEach(controls, id: \.0.hashValue) { control, labelKey in
                        Picker(LocalizationManager.shared.localized(labelKey), selection: Binding(
                            get: { settings.action(for: control) },
                            set: { settings.setAction($0, for: control) }
                        )) {
                            ForEach(actions, id: \.0.hashValue) { action, actionLabelKey in
                                Text(LocalizationManager.shared.localized(actionLabelKey)).tag(action)
                            }
                        }
                    }
                }
            }
            .navigationTitle(LocalizationManager.shared.localized("pen_settings_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizationManager.shared.localized("done")) { dismiss() }
                }
            }
        }
    }
}
