//
//  StorageSweeper.swift
//  Kairumo
//
//  自動清理 App 自己留下的暫存與過時資料，讓使用者的本機容量不會無端變大。
//
//  # 與 `StorageJanitor` 的分工
//
//  `StorageJanitor` 清「文件庫裡沒有東西指到的附件與筆跡」（每天一次，要很保守）。
//  這裡清的是**本來就該消失**的東西：
//
//  1. **暫存目錄（`tmp`）。** 同步的匯入／匯出暫存（`import-…`、`pull-…`、`kairumo-staging-…`、
//     `kairumo-foreign-…`）、分享用的匯出檔（`share_…`、`.pdf`、`.padnote`、`.zip`）、備份的暫存、
//     自檢與測試的暫存檔 —— 每一個都在用完時自己刪，但「用到一半被系統收掉、當機、使用者中途取消」
//     時就留在原地。iOS 只在儲存空間吃緊、而且 App 沒在跑的時候才會清 `tmp`，所以實際上會一直長。
//     啟動時（此刻沒有任何上一輪的流程在用它們）清掉超過一小時的。
//  2. **過期的模型下載殘檔。** 續傳用的 `*.partial` 放了兩週沒人接著下，就是放棄了
//     （一個模型殘檔可以有幾百 MB）。
//  3. **回收桶期滿。** `purgeExpiredTrash` 原本只在「同步跑完一輪之後」呼叫 ——
//     從不同步的使用者，刪掉的筆記本永遠不會離開回收桶，連同它的整個套件（含錄音）。
//
//  # 為什麼這麼保守
//
//  只動 `tmp`（本來就是可丟棄的）與模型根目錄裡我們自己命名的 `.partial`；
//  文件庫裡的東西一律不碰（那是 `StorageJanitor` 的事，規則更嚴）。

import Foundation

enum StorageSweeper {

    /// `tmp` 裡的東西要多舊才清。
    static let tempMinAge: TimeInterval = 3600
    /// 模型續傳殘檔要多舊才算放棄。
    static let partialMinAge: TimeInterval = 14 * 24 * 3600

    struct Plan: Sendable, Equatable {
        var items: [URL] = []
        var bytes: Int64 = 0
    }

    struct Report: Sendable {
        var tempFiles = 0
        var tempBytes: Int64 = 0
        var partialFiles = 0
        var partialBytes: Int64 = 0
        var trashPurged = 0
        var totalBytes: Int64 { tempBytes + partialBytes }
    }

    // MARK: 規劃（純函式，測試直接餵暫存目錄）

    /// 目錄底下第一層、修改時間早於 `now - minAge` 的項目（檔案或資料夾；資料夾連內容一起算大小）。
    /// `matching` 讓呼叫端限定檔名（模型殘檔只認 `.partial`）。
    nonisolated static func plan(
        in directory: URL, minAge: TimeInterval, now: Date = Date(),
        matching: (String) -> Bool = { _ in true }
    ) -> Plan {
        let fm = FileManager.default
        guard let names = try? fm.contentsOfDirectory(atPath: directory.path) else { return Plan() }
        var plan = Plan()
        for name in names where matching(name) {
            let url = directory.appending(path: name)
            guard let modified = newestModification(of: url), now.timeIntervalSince(modified) >= minAge
            else { continue }
            plan.items.append(url)
            plan.bytes += size(of: url)
        }
        return plan
    }

    /// 一個項目「最近一次被動過」的時間：資料夾要看裡面最新的檔案，
    /// 否則一個還在寫入的暫存資料夾（資料夾本身的時間沒變）會被誤當成舊的。
    private nonisolated static func newestModification(of url: URL) -> Date? {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.contentModificationDateKey, .isDirectoryKey]
        guard let values = try? url.resourceValues(forKeys: Set(keys)) else { return nil }
        var newest = values.contentModificationDate
        if values.isDirectory == true, let walker = fm.enumerator(at: url, includingPropertiesForKeys: keys) {
            for case let child as URL in walker {
                if let d = (try? child.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate,
                   d > (newest ?? .distantPast) {
                    newest = d
                }
            }
        }
        return newest
    }

    nonisolated static func size(of url: URL) -> Int64 {
        let fm = FileManager.default
        var total: Int64 = 0
        let keys: Set<URLResourceKey> = [.fileSizeKey, .isDirectoryKey]
        if (try? url.resourceValues(forKeys: keys))?.isDirectory == true {
            if let walker = fm.enumerator(at: url, includingPropertiesForKeys: Array(keys)) {
                for case let child as URL in walker {
                    total += Int64((try? child.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
                }
            }
        } else {
            total = Int64((try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
        }
        return total
    }

    @discardableResult
    nonisolated static func execute(_ plan: Plan) -> (count: Int, bytes: Int64) {
        var count = 0
        var bytes: Int64 = 0
        for url in plan.items {
            let s = size(of: url)
            if (try? FileManager.default.removeItem(at: url)) != nil {
                count += 1
                bytes += s
            }
        }
        return (count, bytes)
    }

    // MARK: 執行

    /// 清暫存與過期殘檔（背景執行緒可呼叫）。
    nonisolated static func sweepDisposables(
        tempDirectory: URL = FileManager.default.temporaryDirectory,
        modelsRoot: URL?, now: Date = Date()
    ) -> Report {
        var report = Report()
        let temp = execute(plan(in: tempDirectory, minAge: tempMinAge, now: now))
        report.tempFiles = temp.count
        report.tempBytes = temp.bytes
        if let modelsRoot {
            let partial = execute(plan(in: modelsRoot, minAge: partialMinAge, now: now) { $0.hasSuffix(".partial") })
            report.partialFiles = partial.count
            report.partialBytes = partial.bytes
        }
        return report
    }

    /// 啟動時的完整清理：暫存 + 殘檔（背景）+ 回收桶期滿（主執行緒，因為動的是 @MainActor 的筆記清單）。
    @MainActor
    static func sweepAtLaunch(store: NotebookStore) async -> Report {
        let modelsRoot = ModelDownloadManager.shared.modelsRoot
        var report = await Task.detached(priority: .background) {
            sweepDisposables(modelsRoot: modelsRoot)
        }.value
        report.trashPurged = store.purgeExpiredTrash()
        // 同步帳本：丟掉舊版留下的、不再需要的資料（見 `InkLedgerJanitor`）。
        let drawings = store.syncDrawingsDirectory
        _ = await Task.detached(priority: .background) { InkLedgerJanitor.compact(drawingsDirectory: drawings) }.value
        if report.totalBytes > 0 || report.trashPurged > 0 {
            let mb = String(format: "%.1f", Double(report.totalBytes) / 1_048_576)
            StartupLogger.logKey(
                "log_sweep_apple", report.tempFiles, report.partialFiles, mb, report.trashPurged)
        }
        return report
    }

    // MARK: 用量（給診斷面板）

    struct Usage: Sendable {
        var library: Int64 = 0
        var temp: Int64 = 0
        var caches: Int64 = 0
        var models: Int64 = 0
        var total: Int64 { library + temp + caches + models }
    }

    nonisolated static func usage(library: URL, modelsRoot: URL?) -> Usage {
        let fm = FileManager.default
        var u = Usage()
        u.library = size(of: library)
        u.temp = size(of: fm.temporaryDirectory)
        if let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask).first {
            u.caches = size(of: caches)
        }
        if let modelsRoot { u.models = size(of: modelsRoot) }
        return u
    }
}
