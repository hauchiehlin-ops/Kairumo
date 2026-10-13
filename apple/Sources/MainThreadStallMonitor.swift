//
//  MainThreadStallMonitor.swift
//  Kairumo
//
//  主執行緒卡頓記錄。
//
//  為什麼需要：畫面卡住但沒有當機（iPad 上開啟範例筆記本後工具列點不動），系統不會產生任何當機報告，
//  使用者只能說「卡住了」。這個監看器在背景每 0.25 秒問主執行緒一聲，主執行緒超過 1.5 秒沒回應，
//  恢復之後就在「診斷 → 啟動日誌」留一筆：卡了幾秒、卡之前最後一件事是什麼。
//  它只記錄，不改變任何行為；日誌可以用診斷頁的「匯出」帶走。
//
//  「卡之前最後一件事」來自 `breadcrumb(_:)`：重要動作（開筆記本、切換工具…）各記一筆。

import Foundation

final class MainThreadStallMonitor: @unchecked Sendable {
    // profile-scope: device 診斷用，整台裝置共用
    static let shared = MainThreadStallMonitor()

    /// 超過這麼久沒回應才算卡頓。
    private let threshold: TimeInterval = 1.5
    private let lock = NSLock()
    private var lastPong = ProcessInfo.processInfo.systemUptime
    private var lastCrumb = "—"
    private var timer: DispatchSourceTimer?
    private var stallStarted: TimeInterval?

    /// 記下最近一件事（任何執行緒都可以呼叫）。
    func breadcrumb(_ text: String) {
        lock.lock(); lastCrumb = text; lock.unlock()
    }

    func start() {
        guard timer == nil else { return }
        let source = DispatchSource.makeTimerSource(queue: DispatchQueue(label: "kairumo.stall-monitor", qos: .utility))
        source.schedule(deadline: .now() + 1, repeating: 0.25)
        source.setEventHandler { [weak self] in self?.tick() }
        source.resume()
        timer = source
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        lock.lock()
        let silent = now - lastPong
        let started = stallStarted
        lock.unlock()

        if silent > threshold, started == nil {
            lock.lock(); stallStarted = lastPong; lock.unlock()
        }
        // 主執行緒回應了（或還沒回應）：每一輪都丟一個 pong 請求。
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let back = ProcessInfo.processInfo.systemUptime
            self.lock.lock()
            let began = self.stallStarted
            let crumb = self.lastCrumb
            self.stallStarted = nil
            self.lastPong = back
            self.lock.unlock()
            if let began {
                let seconds = back - began
                StartupLogger.logKey("log_main_stall", String(format: "%.1f", seconds), crumb)
            }
        }
    }
}
