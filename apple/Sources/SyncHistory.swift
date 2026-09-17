//
//  SyncHistory.swift
//  Kairumo
//
//  「上次什麼時候同步的」—— 兩條同步路徑各記一次。
//

import Foundation

/// 上次同步的時間。
///
/// # 為什麼需要它
///
/// 同步頁原本只有「已登入 / 尚未登入」。按下「立即同步」之後畫面上沒有
/// 任何東西改變 —— 使用者無法分辨「同步成功了」與「按鈕沒反應」。
/// 而這兩者需要的下一步完全不同。
///
/// 存 `UserDefaults`：它是一個顯示用的時間戳，不是資料。掉了最壞的情況
/// 是顯示「尚未同步過」，不影響任何一份筆記。
enum SyncHistory {
    private static let googleKey = "kairumo.sync.lastGoogleAt"
    private static let folderKey = "kairumo.sync.lastFolderAt"

    static func markGoogleSynced(at date: Date = Date()) {
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: googleKey)
    }

    static func markFolderSynced(at date: Date = Date()) {
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: folderKey)
    }

    static func lastGoogleSync() -> Date? { date(forKey: googleKey) }
    static func lastFolderSync() -> Date? { date(forKey: folderKey) }

    static func lastGoogleSyncDescription(none: String) -> String {
        describe(lastGoogleSync(), none: none)
    }

    static func lastFolderSyncDescription(none: String) -> String {
        describe(lastFolderSync(), none: none)
    }

    private static func date(forKey key: String) -> Date? {
        let raw = UserDefaults.standard.double(forKey: key)
        return raw > 0 ? Date(timeIntervalSince1970: raw) : nil
    }

    /// 用相對時間（「3 分鐘前」）而不是絕對時間。
    ///
    /// 使用者在這一頁要回答的問題是「剛才那次到底有沒有成功」，
    /// 而不是「那是幾點幾分」。相對時間直接回答了前者。
    private static func describe(_ date: Date?, none: String) -> String {
        guard let date else { return none }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
