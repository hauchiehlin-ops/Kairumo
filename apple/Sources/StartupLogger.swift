//
//  StartupLogger.swift
//  Kairumo
//
//  啟動與首頁載入效能診斷日誌
//

import Foundation
import Combine

public final class StartupLogger: ObservableObject, @unchecked Sendable {
    public static let shared = StartupLogger()

    public struct LogEntry: Identifiable, Sendable {
        public let id = UUID()
        public let timestamp = Date()
        /// 診斷日誌的訊息。有 `key` 時，顯示才查字串表 —— 存的是鍵與參數，不是翻好的字，
        /// 所以切換語言之後，已經在清單裡的舊紀錄也會跟著換。
        public let elapsed: String
        public let rawMessage: String
        public let key: String?
        public let args: [String]
        public let thread: String

        public var message: String {
            let body = key.map { L10n.format($0, args) } ?? rawMessage
            return "[\(elapsed)] \(body)"
        }
    }

    private let lock = NSLock()
    private var storage: [LogEntry] = []
    private static let startTime = Date()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    @Published public private(set) var entries: [LogEntry] = []

    private init() {}

    public static func log(_ message: String) {
        let now = Date()
        let elapsed = String(format: "+%.3fs", now.timeIntervalSince(startTime))
        let timeStr = timeFormatter.string(from: now)
        let threadName = Thread.isMainThread ? "Main" : "Bg"
        let fullMessage = "[\(timeStr)] [\(elapsed)] [\(threadName)] \(message)"
        
        print("⏱️ \(fullMessage)")

        append(LogEntry(elapsed: elapsed, rawMessage: message, key: nil, args: [], thread: threadName))
    }

    /// 以字串表的鍵記一筆日誌。使用者看得到診斷頁，所以訊息要跟著介面語言走。
    public static func logKey(_ key: String, _ args: any CustomStringConvertible...) {
        let now = Date()
        let elapsed = String(format: "+%.3fs", now.timeIntervalSince(startTime))
        let threadName = Thread.isMainThread ? "Main" : "Bg"
        let values = args.map { "\($0)" }
        print("⏱️ [\(timeFormatter.string(from: now))] [\(elapsed)] [\(threadName)] \(key) \(values)")
        append(LogEntry(elapsed: elapsed, rawMessage: key, key: key, args: values, thread: threadName))
    }

    private static func append(_ entry: LogEntry) {
        DispatchQueue.main.async {
            shared.lock.lock()
            shared.storage.append(entry)
            if shared.storage.count > 200 {
                shared.storage.removeFirst(shared.storage.count - 200)
            }
            let copy = shared.storage
            shared.lock.unlock()
            shared.entries = copy
        }
    }

    public func clear() {
        lock.lock()
        storage.removeAll()
        lock.unlock()
        entries.removeAll()
    }
}
