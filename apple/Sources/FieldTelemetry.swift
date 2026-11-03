//
//  FieldTelemetry.swift
//  Kairumo
//
//  真實使用者的裝置表現（即時響應架構 · 原則 8）。
//
//  為什麼：開發者手上的裝置只是一個樣本。系統（MetricKit）會每天彙總這台裝置上
//  App 的卡頓（hang）、滑動 hitch 比例、啟動時間，交給 App。這裡把它**留在本機**
//  （os 日誌＋一份文字摘要，診斷頁匯出時帶走），**不上傳任何東西**，也不含筆記內容。
//  使用者願意回報時，這份摘要就是「他的裝置、他的系統版本」上的真實數字。
//

import Foundation
import MetricKit
import os

final class FieldTelemetry: NSObject, MXMetricManagerSubscriber, @unchecked Sendable {
    // profile-scope: device 系統彙總的效能指標，不含使用者資料
    static let shared = FieldTelemetry()

    private let log = Logger(subsystem: "com.kairumo", category: "field")
    private let lock = NSLock()
    private var started = false
    private var summaries: [String] = []

    func start() {
        lock.lock(); defer { lock.unlock() }
        guard !started else { return }
        started = true
        MXMetricManager.shared.add(self)
    }

    /// 最近幾次系統彙總的摘要（最新在後）。
    var recentSummaries: [String] {
        lock.lock(); defer { lock.unlock() }
        return summaries
    }

    private func append(_ line: String) {
        lock.lock()
        summaries.append(line)
        if summaries.count > 20 { summaries.removeFirst() }
        lock.unlock()
        log.notice("\(line, privacy: .public)")
    }

    func didReceive(_ payloads: [MXMetricPayload]) {
        for p in payloads {
            var parts: [String] = ["metrics \(p.timeStampBegin.formatted(date: .numeric, time: .omitted))"]
            if let hitch = p.animationMetrics?.scrollHitchTimeRatio {
                parts.append(String(format: "scrollHitch %.1f ms/s", hitch.value))
            }
            if let hang = p.applicationResponsivenessMetrics?.histogrammedApplicationHangTime {
                var total = 0
                for bucket in hang.bucketEnumerator { total += (bucket as? MXHistogramBucket<UnitDuration>)?.bucketCount ?? 0 }
                parts.append("hangs \(total)")
            }
            if let launch = p.applicationLaunchMetrics?.histogrammedTimeToFirstDraw {
                var total = 0
                for bucket in launch.bucketEnumerator { total += (bucket as? MXHistogramBucket<UnitDuration>)?.bucketCount ?? 0 }
                parts.append("launches \(total)")
            }
            append(parts.joined(separator: " · "))
        }
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for p in payloads {
            let hangs = p.hangDiagnostics?.count ?? 0
            let cpu = p.cpuExceptionDiagnostics?.count ?? 0
            append("diagnostics hangs \(hangs) · cpuExceptions \(cpu)")
        }
    }
}
