//
//  MainThreadStallMonitor.swift
//  Kairumo
//
//  主執行緒卡頓記錄。
//
//  為什麼需要：畫面卡住但沒有當機（iPad 上開啟範例筆記本後工具列點不動），系統不會產生任何當機報告，
//  使用者只能說「卡住了」。這個監看器在背景每 0.25 秒問主執行緒一聲，主執行緒超過 1.5 秒沒回應，
//  恢復之後就在「診斷 → 啟動日誌」留一筆：卡了幾秒、卡之前最後一件事是什麼。
//  卡住期間還會**對主執行緒取堆疊樣本**（見 `StackSampler`）：一筆只有時間的記錄只能說「卡了」，
//  堆疊才說得出「卡在哪個函式」。
//  它只記錄，不改變任何行為；日誌可以用診斷頁的「匯出」帶走。
//
//  「卡之前最後一件事」來自 `breadcrumb(_:)`：重要動作（開筆記本、切換工具…）各記一筆。

import Darwin
import Foundation

/// 在另一條執行緒上取主執行緒的堆疊。
///
/// 做法：對主執行緒送 `SIGUSR2`，處理常式裡只呼叫 `backtrace()`，把位址寫進預先配置好的緩衝區。
/// 不在訊號處理常式裡配置記憶體、不格式化字串；符號化留到事後（用同一個建置的 dSYM，
/// 位址 − 模組基底 = 檔案內偏移，與當機報告的 imageOffset 是同一回事）。
enum StackSampler {
    private static let capacity = 64
    // profile-scope: device 診斷用的堆疊緩衝區，整台裝置共用
    nonisolated(unsafe) fileprivate static var buffer = UnsafeMutablePointer<UnsafeMutableRawPointer?>.allocate(capacity: capacity)
    // profile-scope: device 診斷用，整台裝置共用
    nonisolated(unsafe) fileprivate static var count: Int32 = 0
    // profile-scope: device 診斷用（主執行緒的身分），整台裝置共用
    nonisolated(unsafe) private static var mainThread: pthread_t?

    /// 在主執行緒上呼叫一次（安裝處理常式、記下主執行緒）。
    static func install() {
        guard mainThread == nil else { return }
        mainThread = pthread_self()
        // 先呼叫一次：`backtrace()` 第一次會載入 unwinder，那一步可能配置記憶體，不能留到訊號處理常式裡。
        var warm = [UnsafeMutableRawPointer?](repeating: nil, count: 8)
        _ = backtrace(&warm, 8)
        signal(SIGUSR2) { _ in
            StackSampler.count = backtrace(StackSampler.buffer, Int32(StackSampler.capacity))
        }
    }

    /// 請主執行緒交出目前的堆疊，回傳（未滑動前的）位址。主執行緒卡在不可中斷的系統呼叫裡時可能是空的。
    static func sample() -> [UInt] {
        guard let thread = mainThread else { return [] }
        count = 0
        guard pthread_kill(thread, SIGUSR2) == 0 else { return [] }
        usleep(60_000) // 給處理常式一點時間（主執行緒卡在忙碌迴圈裡，會很快回應）
        let n = Int(count)
        return (0..<min(n, capacity)).compactMap { buffer[$0].map { UInt(bitPattern: $0) } }
    }

    /// 主程式模組在記憶體裡的載入位址。
    static var imageBase: UInt {
        UInt(bitPattern: _dyld_get_image_header(0))
    }
}

final class MainThreadStallMonitor: @unchecked Sendable {
    // profile-scope: device 診斷用，整台裝置共用
    static let shared = MainThreadStallMonitor()

    /// 超過這麼久沒回應才算卡頓。
    private let threshold: TimeInterval = 1.5
    /// 卡頓期間，每隔多久再取一次堆疊樣本。
    private let sampleInterval: TimeInterval = 4
    /// 一次卡頓最多留幾個樣本（日誌不要被洗掉）。
    private let maxSamples = 3
    private let lock = NSLock()
    private var lastPong = ProcessInfo.processInfo.systemUptime
    private var lastCrumb = "—"
    private var timer: DispatchSourceTimer?
    private var stallStarted: TimeInterval?
    private var samples: [[UInt]] = []
    private var lastSampleAt: TimeInterval = 0

    /// 記下最近一件事（任何執行緒都可以呼叫）。
    func breadcrumb(_ text: String) {
        lock.lock(); lastCrumb = text; lock.unlock()
    }

    /// 在**主執行緒**上呼叫（要記下主執行緒的身分）。
    func start() {
        guard timer == nil else { return }
        StackSampler.install()
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
        if silent > threshold, stallStarted == nil { stallStarted = lastPong }
        let stalled = stallStarted != nil
        let dueForSample = stalled && samples.count < maxSamples && now - lastSampleAt >= sampleInterval
        if dueForSample { lastSampleAt = now }
        lock.unlock()

        // 卡住中：在鎖外取堆疊（會睡 60 ms）。
        if dueForSample {
            let frames = StackSampler.sample()
            if !frames.isEmpty {
                lock.lock(); samples.append(frames); lock.unlock()
            }
        }

        // 每一輪都丟一個 pong 請求；主執行緒恢復之後第一個會把這次卡頓記下來。
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let back = ProcessInfo.processInfo.systemUptime
            self.lock.lock()
            let began = self.stallStarted
            let crumb = self.lastCrumb
            let captured = self.samples
            self.stallStarted = nil
            self.samples = []
            self.lastSampleAt = 0
            self.lastPong = back
            self.lock.unlock()
            if let began {
                StartupLogger.logKey("log_main_stall", String(format: "%.1f", back - began), crumb)
                let base = StackSampler.imageBase
                for frames in captured {
                    // 位址 − 基底 = 這個模組檔案內的偏移；只留落在主程式模組附近的框架以外的也無妨，全部記下。
                    let offsets = frames.prefix(24).map { String(format: "0x%lx", Int($0) - Int(base)) }
                    StartupLogger.logKey("log_main_stall_stack", String(format: "0x%lx", Int(base)), offsets.joined(separator: " "))
                }
            }
        }
    }
}
