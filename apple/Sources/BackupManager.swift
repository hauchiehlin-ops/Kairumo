//
//  BackupManager.swift
//  Kairumo
//
//  個人資料備份與一鍵復原。
//
//  # 備份裡有什麼
//
//  整個 Documents 目錄 —— 筆記本清單、資料夾結構、每一頁的手繪、圖片附件、
//  錄音檔、里程碑快照、已轉換的 `.padnote` 套件 —— 再加上 App 自己的設定
//  （語言、根資料夾名稱、裝置識別碼…）。目標是「換一台裝置或重裝之後，
//  一鍵回到原樣」。
//
//  # 容器格式在核心
//
//  iPad 上做的備份換到 Android 也要開得起來。兩個平台各寫一份格式的話，
//  那件事第一天就不成立。這裡只負責「哪些東西要進去」與「使用者按了什麼」。
//
//  # 復原之前一定先備份現況
//
//  使用者按下復原時，手上那份資料就要被覆蓋了。萬一備份檔本身有問題，
//  沒有安全網的話他會同時失去兩份。
//

import Foundation

enum BackupManager {

    static let fileExtension = "kairumobackup"

    /// 要一起備份的 App 設定。
    ///
    /// 只挑我們自己的鍵（`kairumo.` 開頭）。整包 UserDefaults 倒出來會夾帶
    /// 系統與其他框架的東西，還原時寫回去可能造成很難追的行為。
    static func currentSettings() -> String {
        let all = UserDefaults.standard.dictionaryRepresentation()
        var ours: [String: String] = [:]
        for (key, value) in all where key.hasPrefix("kairumo.") {
            // 只帶字串與數字。二進位（例如 security-scoped bookmark）換一台
            // 裝置就失效了，帶過去只會讓使用者以為同步資料夾還在。
            switch value {
            case let s as String: ours[key] = s
            case let n as NSNumber: ours[key] = n.stringValue
            default: continue
            }
        }
        return (try? JSONEncoder().encode(ours))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }

    /// 把設定寫回去。
    static func applySettings(_ json: String) {
        guard let data = json.data(using: .utf8),
              let map = try? JSONDecoder().decode([String: String].self, from: data) else { return }
        for (key, value) in map where key.hasPrefix("kairumo.") {
            UserDefaults.standard.set(value, forKey: key)
        }
    }

    // MARK: - 建立

    /// 建立備份檔，回傳它的位置。
    ///
    /// 檔名帶日期時間**與一段亂碼**。
    ///
    /// 只帶到秒的話，同一秒內建立的兩份備份會用同一個檔名而互相覆蓋 ——
    /// 而「復原前先備份現況」正好就發生在使用者按下復原的同一秒，
    /// 結果是安全備份把**要復原的那一份**蓋掉。測試抓到的就是這個。
    static func createBackup(
        documentsDirectory: URL,
        appVersion: String = AppVersion.marketing,
        date: Date = Date(),
        label: String = ""
    ) throws -> (url: URL, info: BackupInfo) {
        let stamp = ISO8601DateFormatter().string(from: date)
            .replacingOccurrences(of: ":", with: "-")
        let unique = UUID().uuidString.prefix(6)
        let suffix = label.isEmpty ? "" : "-\(label)"
        // 放在 tmp：備份檔不該再被下一次備份包進去，也不該佔用使用者的
        // 文件空間直到他決定要放哪裡。
        let out = FileManager.default.temporaryDirectory
            .appending(path: "Kairumo-\(stamp)\(suffix)-\(unique).\(fileExtension)")

        // 完整寫出模組名：同名的靜態方法會蓋掉核心那個自由函式。
        let info = try Kairumo.createBackup(
            sourceDir: documentsDirectory.path,
            outPath: out.path,
            appVersion: appVersion,
            settingsJson: currentSettings(),
            nowUnixMs: UInt64(date.timeIntervalSince1970 * 1000)
        )
        return (out, info)
    }

    // MARK: - 檢視

    static func inspect(_ url: URL) throws -> BackupInfo {
        try Kairumo.inspectBackup(path: url.path)
    }

    // MARK: - 復原

    struct RestoreOutcome {
        var restored: Int
        var corrupted: [String]
        /// 復原前自動做的那份「現況備份」。出事時從這裡回得去。
        var safetyBackup: URL?
    }

    /// 一鍵復原。
    ///
    /// 復原**之前**先把現況備份起來 —— 使用者按下去的那一刻，手上的資料
    /// 就要被覆蓋了；萬一備份檔本身有問題，沒有安全網他會同時失去兩份。
    static func restore(
        from url: URL,
        into documentsDirectory: URL,
        appVersion: String = AppVersion.marketing
    ) throws -> RestoreOutcome {
        // 標上 safety：使用者在一堆備份檔裡要分得出哪一份是自動留的。
        let safety = try? createBackup(
            documentsDirectory: documentsDirectory,
            appVersion: appVersion,
            label: "safety"
        ).url

        let report = try Kairumo.restoreBackup(path: url.path, destDir: documentsDirectory.path)
        applySettings(report.settingsJson)

        return RestoreOutcome(
            restored: report.restored.count,
            corrupted: report.corrupted,
            safetyBackup: safety
        )
    }
}
