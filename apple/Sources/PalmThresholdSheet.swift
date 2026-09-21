//
//  PalmThresholdSheet.swift
//  Kairumo
//
//  掌拒門檻的調整介面（工作項 S-101）。
//
//  # 為什麼以前沒有
//
//  判定邏輯一直都在核心的 `InkArbiter`，Apple 與 Android 也都接了 ——
//  缺的只是「讓使用者調」。沒有它的後果是：握筆姿勢比較特別、或者螢幕
//  特別大的人，手掌一放上去就是一道線，而他完全沒有辦法處理。
//
//  # 為什麼一定要有「恢復預設」
//
//  門檻調錯會讓筆**完全畫不出來**（半徑調太低，連筆尖都被當成手掌）。
//  那個狀態下使用者沒有辦法用畫布本身把它救回來 —— 所以恢復預設不是
//  貼心功能，是這個設定能不能開放的前提。
//

import SwiftUI

/// 門檻存在**這台裝置**上，不進同步。
///
/// 理由與核心的 `DeviceSettings` 一致：握筆姿勢、螢幕大小、觸控取樣率
/// 因裝置而異，把 iPhone 上調鬆的值同步到 iPad，iPad 的掌拒就形同虛設。
enum PalmThresholdStore {
    private static let radiusKey = "palmRadiusDp"
    private static let retractKey = "palmRetractMs"

    /// `nil` 表示使用者沒有自訂過，跟著核心的預設走。
    static var radius: Float? {
        UserDefaults.standard.object(forKey: radiusKey) as? Float
    }

    static var retractMs: UInt32? {
        (UserDefaults.standard.object(forKey: retractKey) as? NSNumber)?.uint32Value
    }

    static var isCustomised: Bool { radius != nil }

    static func save(radius: Float, retractMs: UInt32) {
        UserDefaults.standard.set(radius, forKey: radiusKey)
        UserDefaults.standard.set(NSNumber(value: retractMs), forKey: retractKey)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: radiusKey)
        UserDefaults.standard.removeObject(forKey: retractKey)
    }
}

struct PalmThresholdSheet: View {
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss

    /// 套用之後呼叫，讓畫布上的仲裁器立刻吃到新值。
    let onApply: () -> Void

    private let limits = palmThresholdLimits()
    @State private var radius: Double = 0
    @State private var retractMs: Double = 0

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent(localizationManager.localized("palm_threshold_radius")) {
                        Text("\(Int(radius.rounded())) dp")
                    }
                    Slider(
                        value: $radius,
                        in: Double(limits.minRadiusDp)...Double(limits.maxRadiusDp))
                } footer: {
                    Text(localizationManager.localized("palm_threshold_hint"))
                }

                Section {
                    LabeledContent(localizationManager.localized("palm_threshold_retract")) {
                        Text("\(Int(retractMs.rounded())) ms")
                    }
                    Slider(
                        value: $retractMs,
                        in: Double(limits.minRetractMs)...Double(limits.maxRetractMs))
                } footer: {
                    Text(localizationManager.localized("palm_threshold_retract_hint"))
                }

                Section {
                    Button(localizationManager.localized("palm_threshold_reset"), role: .destructive) {
                        PalmThresholdStore.clear()
                        onApply()
                        dismiss()
                    }
                }
            }
            .navigationTitle(localizationManager.localized("palm_rejection_settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizationManager.localized("cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localizationManager.localized("confirm")) {
                        // 夾制走核心 —— 滑桿的兩端本來就在範圍內，但值也可能
                        // 來自舊版寫下的偏好設定，那些沒有經過任何檢查。
                        PalmThresholdStore.save(
                            radius: palmRadiusClamped(dp: Float(radius)),
                            retractMs: palmRetractMsClamped(ms: UInt32(retractMs.rounded())))
                        onApply()
                        dismiss()
                    }
                }
            }
            .onAppear {
                radius = Double(PalmThresholdStore.radius ?? limits.defaultRadiusDp)
                retractMs = Double(PalmThresholdStore.retractMs ?? limits.defaultRetractMs)
            }
        }
    }
}
