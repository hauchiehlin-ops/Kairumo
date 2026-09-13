//
//  AppVersion.swift
//  Kairumo
//
//  版本字串與 Mac 視窗標題的單一來源。
//

import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// App 版本資訊。各處原本各自從 `infoDictionary` 撈、還各自寫了不同的
/// 硬編碼 fallback（1.2.0 / 1.4.0 / 1.0.0），版本一升級就對不起來。
public enum AppVersion {
    /// 行銷版本號（CFBundleShortVersionString），例如 `2.0.0`
    public static var marketing: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    /// 建置號（CFBundleVersion）
    public static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }

    /// Mac 視窗標題列顯示的字串
    public static var windowTitle: String { "Kairumo v\(marketing)" }
}

/// 視窗標題的維持器。
///
/// 為什麼不是設一次就好：原本在 `onAppear` 裡 `DispatchQueue.main.async` 設一次，
/// 但那個時間點 `connectedScenes` 可能還是空的（視窗場景尚未接上），
/// 設定就靜靜地掉了 —— 標題退回 App 名稱「Kairumo」，看不到版本號。
/// SwiftUI 的 `navigationTitle` 之後也可能覆蓋掉 scene.title。
///
/// 所以改成：場景還沒出現就短暫重試，並在場景／視窗／App 重新啟用時再確認一次。
/// 只有在目前標題不同時才寫入，不會造成閃爍。
///
/// **不要再加上 `#if targetEnvironment(macCatalyst)`。** 踩過的坑：使用者在 Mac 上
/// 跑的其實是 TestFlight 的 **iOS 版**（Apple Silicon 的「Designed for iPad」），
/// 那個二進位的 `targetEnvironment(macCatalyst)` 是 false —— 整段程式根本沒被編進去，
/// 所以標題永遠停在 App 名稱。iOS 上設定 `UIWindowScene.title` 沒有副作用，
/// 在 Mac 上跑的 iOS App 也會反映到視窗標題列。
public enum MacWindowTitle {
    private static var desiredTitle: String = AppVersion.windowTitle
    private static var observersInstalled = false
    private static var keeperTimer: Timer?

    /// 設定（並持續維持）Mac 視窗標題。
    @MainActor
    public static func apply(_ title: String = AppVersion.windowTitle) {
        desiredTitle = title
        installObserversIfNeeded()
        assign(retriesLeft: 8)
    }

    @MainActor
    private static func assign(retriesLeft: Int) {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }

        guard !scenes.isEmpty else {
            // 場景還沒接上。直接放棄的話標題就永遠是 App 名稱，所以短暫重試。
            guard retriesLeft > 0 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                Task { @MainActor in assign(retriesLeft: retriesLeft - 1) }
            }
            return
        }

        for scene in scenes where scene.title != desiredTitle {
            scene.title = desiredTitle
        }
    }

    @MainActor
    private static func installObserversIfNeeded() {
        guard !observersInstalled else { return }
        observersInstalled = true

        // 後備守門員：SwiftUI 在自己的更新時機會重設 scene.title
        // （例如 fullScreenCover 推上來、navigationTitle 重算），
        // 那些時機沒有對應的通知可以掛。這個計時器只在「目前值與預期不同」
        // 時才寫入，所以既不會閃爍，也不會做多餘的工作。
        keeperTimer?.invalidate()
        keeperTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in assign(retriesLeft: 0) }
        }

        let names: [Notification.Name] = [
            UIScene.didActivateNotification,
            UIApplication.didBecomeActiveNotification,
            UIWindow.didBecomeKeyNotification
        ]
        for name in names {
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in
                Task { @MainActor in assign(retriesLeft: 0) }
            }
        }
    }
}

/// 型別邊界工具。
///
/// SwiftUI 會把每個 `.sheet` / `.fullScreenCover` 內容的完整型別編進外層 view 的
/// mangled 型別名稱裡。累積起來，`NotebookEditorView.Body` 的型別名稱長達 89,768 字元，
/// 裝置端（主執行緒只有 1MB 堆疊）在 `swift_getTypeByMangledName` 解析時會遞迴爆堆疊
/// —— 模擬器的堆疊是 8MB，所以只在實機上當掉。
/// 用它把內容包成 AnyView，外層型別裡就只剩 "AnyView"。
func erasedView<V: View>(@ViewBuilder _ content: () -> V) -> AnyView {
    AnyView(content())
}
