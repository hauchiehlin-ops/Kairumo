//
//  FeatureHint.swift
//  Kairumo
//
//  功能的操作提示（首次使用時出現一次）。
//
//  # 為什麼需要
//
//  使用者的回報是「這幾個功能無法實際操作，或者說不知道該怎麼操作」。
//  查下去，**四個都有實作，而且都能用** —— 它們共同的問題是按下去之後
//  進入某種「模式」，而真正要做的事是**下一個動作**（圖釘要再點畫面、
//  草圖修飾要先有筆跡…）。畫面上沒有任何地方講，所以看起來就是「按了沒反應」。
//
//  # 「不再顯示」存在本機
//
//  這是介面偏好，不是內容 —— 存進同步的設定就要動格式，而那件事有相容性
//  代價（見 H-OPLOG-COMPAT）。代價與收益不成比例。
//

import SwiftUI

#if canImport(PadnoteCore)
import PadnoteCore
#endif

/// 哪些提示已經被關掉。
@MainActor
public enum FeatureHintStore {

    private static let key = "kairumo.hints.dismissed.v1"

    public static func isDismissed(_ id: String) -> Bool {
        dismissed().contains(id)
    }

    public static func dismiss(_ id: String) {
        var all = dismissed()
        all.insert(id)
        UserDefaults.standard.set(Array(all), forKey: key)
    }

    /// 全部重新顯示。設定頁要有這個 —— 關掉之後就再也找不回來的說明，
    /// 對後來才需要它的人等於不存在。
    public static func resetAll() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    private static func dismissed() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }
}

/// 一則提示的內容與「不再顯示」的開關。
@MainActor
public struct FeatureHintView: View {

    let hint: FfiFeatureHint
    let onClose: () -> Void

    @ObservedObject private var localizationManager = LocalizationManager.shared
    @State private var dontShowAgain = false

    private func L(_ key: String) -> String { localizationManager.localized(key) }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L(hint.titleKey))
                .font(.headline)
                .accessibilityIdentifier("hint.title")
            Text(L(hint.bodyKey))
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("hint.body")

            Toggle(isOn: $dontShowAgain) {
                Text(L("hint_dont_show_again")).font(.footnote)
            }
            .accessibilityIdentifier("hint.dont_show_again")

            HStack {
                Spacer()
                Button(L("hint_got_it")) {
                    if dontShowAgain { FeatureHintStore.dismiss(hint.id) }
                    onClose()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("hint.got_it")
            }
        }
        .padding(18)
        // 寬度上限：不設的話，長句在 Mac 上會拉成一行橫跨整個視窗，
        // 而那種一行八十個字的說明沒有人讀得下去。
        .frame(maxWidth: 360)
    }
}

public extension View {
    /// 第一次用到某個功能時，跳一則講「接下來要做什麼」的提示。
    ///
    /// - Parameters:
    ///   - id: 核心 `feature_hints()` 給的穩定 id。兩端用同一組 ——
    ///     鍵不一樣的話，使用者在一台裝置上關掉的提示會在另一台冒出來。
    ///   - trigger: 這個功能剛被啟動了嗎。由 `false` 變 `true` 時才跳。
    @MainActor
    func featureHint(_ id: String, trigger: Bool) -> some View {
        modifier(FeatureHintModifier(id: id, trigger: trigger))
    }
}

@MainActor
private struct FeatureHintModifier: ViewModifier {
    let id: String
    let trigger: Bool

    @State private var showing = false
    @State private var hint: FfiFeatureHint?

    func body(content: Content) -> some View {
        content
            .onChange(of: trigger) { newValue in
                // 只在「剛被打開」的那一刻跳。每次重繪都跳的話，
                // 使用者會在放圖釘的途中被彈窗打斷。
                guard newValue, !FeatureHintStore.isDismissed(id) else { return }
                hint = featureHint(id: id)
                showing = hint != nil
            }
            .popover(isPresented: $showing) {
                if let hint {
                    FeatureHintView(hint: hint) { showing = false }
                        .presentationCompactAdaptationIfAvailable()
                }
            }
    }
}

private extension View {
    /// iPhone 上 popover 預設會變成整頁的表單 —— 一則兩行的提示佔滿整個
    /// 螢幕太重了，而且會把使用者正要點的那個畫面蓋掉。
    @ViewBuilder
    func presentationCompactAdaptationIfAvailable() -> some View {
        if #available(iOS 16.4, macOS 13.3, *) {
            self.presentationCompactAdaptation(.popover)
        } else {
            self
        }
    }
}
