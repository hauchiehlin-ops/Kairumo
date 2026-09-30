//
//  FakeDriveHook.swift
//  Kairumo
//
//  多裝置測試用的掛勾：把 Google Drive 換成本機的假伺服器
//  （`scripts/fake-drive-server.py`）。
//
//  # 為什麼需要它
//
//  模擬器上登入不了 Google，所以「A 刪除 → B 確認 → 期滿後雲端清除」「A 更名 →
//  B 有沒有跟著改」這類**要兩個真正在跑的 App** 才驗證得了的行為，一直只能等實機。
//  核心的傳輸層（`FfiDriveHttp`）本來就是平台實作的，所以只要在測試模式下把
//  `https://www.googleapis.com` 換成本機伺服器、並假裝已登入，兩個模擬器上
//  真實的 App 與真實的同步碼就能共用同一份「雲端」。
//
//  # 只在設了環境變數時生效
//
//  `KAIRUMO_FAKE_DRIVE=http://127.0.0.1:8765`。沒設就完全不動 —— iOS 的正式版沒有
//  辦法設定環境變數。與 `KAIRUMO_UITEST_*` 是同一種做法。
//

import Foundation

enum FakeDrive {
    /// 假伺服器的位址。沒設定（正式版）就是 nil。
    static let baseURL: String? = {
        guard let value = ProcessInfo.processInfo.environment["KAIRUMO_FAKE_DRIVE"],
              !value.isEmpty
        else { return nil }
        return value.hasSuffix("/") ? String(value.dropLast()) : value
    }()

    static var isEnabled: Bool { baseURL != nil }

    /// 假的權杖與帳號。**所有用這個掛勾的裝置要用同一個帳號** —— 帳號決定
    /// 雲端快照與工作階段的快取鍵，也代表「同一個使用者的多台裝置」。
    static let accessToken = "fake-drive-token"
    static let accountEmail = "fake-drive@kairumo.test"

    private static let realHost = "https://www.googleapis.com"

    /// 把真的 Drive 網址換成假伺服器的；沒啟用或不是 Drive 網址就原樣回傳。
    static func rewrite(_ url: String) -> String {
        guard let base = baseURL, url.hasPrefix(realHost) else { return url }
        return base + url.dropFirst(realHost.count)
    }
}
