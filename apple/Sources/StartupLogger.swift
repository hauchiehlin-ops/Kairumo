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
        public let message: String
        public let thread: String
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

        let entry = LogEntry(message: "[\(elapsed)] \(message)", thread: threadName)

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
