//
//  RecordingAdvice.swift
//  Kairumo
//
//  停止錄音後的一次性「錄音品質提示」（docs/plans/recording-quality.md）。
//

import Foundation
import UIKit

/// 停止錄音後，依核心的 `FfiRecordingQuality.adviceKey` 顯示一次性提示。
///
/// # 為什麼走 UIKit 而不是 SwiftUI 的 `.alert`
///
/// 停止錄音的地方有三處：編輯器（在 `fullScreenCover` 裡）、首頁快速錄音
/// （一個 sheet，按下停止的同時就 `dismiss()`）。掛在任何一個 view 上的
/// `.alert` 都會在另一條路徑看不到 —— sheet 關掉時它的 alert 一起消失，
/// 掛在首頁的又被 cover 擋住。從最上層的 view controller 呈現才每條路都看得到。
///
/// # 判斷邏輯在核心
///
/// 什麼算「太小聲／破音／太吵」由核心的 `QualityMeter` 決定，Android 用同一個。
/// 這裡只負責「key 非空就顯示」。
@MainActor
enum RecordingAdvice {
    /// 允許的 key。核心回傳不認得的值時不顯示 —— 顯示一串原始 key 比不顯示更糟。
    nonisolated static let knownKeys: Set<String> = [
        "recording_advice_quiet", "recording_advice_clipping", "recording_advice_noisy",
    ]

    /// 從品質報告取出要顯示的 key；不需要提示時回 `nil`。
    nonisolated static func adviceKey(from quality: FfiRecordingQuality?) -> String? {
        adviceKey(raw: quality?.adviceKey)
    }

    nonisolated static func adviceKey(raw: String?) -> String? {
        guard let raw, knownKeys.contains(raw) else { return nil }
        return raw
    }

    /// 給 UI 測試的無障礙識別碼。
    static let accessibilityId = "recording-advice"

    /// 呈現提示。延遲一下：快速錄音的 sheet 此刻正要被 `dismiss()`，
    /// 立刻呈現會掛在那個即將消失的 sheet 上，跟著一起被收掉。
    static func present(key: String) {
        Task { @MainActor in
            for _ in 0..<10 {
                try? await Task.sleep(nanoseconds: 350_000_000)
                if let top = topViewController(), !top.isBeingDismissed {
                    show(key: key, on: top)
                    return
                }
            }
            StartupLogger.logKey("log_advice_no_view", key)
        }
    }

    private static func show(key: String, on presenter: UIViewController) {
        let l10n = LocalizationManager.shared
        let alert = UIAlertController(
            title: l10n.localized("recording_advice_title"),
            message: l10n.localized(key),
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: l10n.localized("confirm"), style: .default))
        alert.view.accessibilityIdentifier = accessibilityId
        presenter.present(alert, animated: true)
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var top = scene?.windows.first(where: \.isKeyWindow)?.rootViewController
            ?? scene?.windows.first?.rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }
}
