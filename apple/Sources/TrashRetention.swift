//
//  TrashRetention.swift
//  Kairumo
//
//  回收桶的保留期限設定。設計見 docs/plans/expiry-purge.md。
//
//  # 這裡只存「使用者選了什麼」，不算任何東西
//
//  「還剩幾天」「是否期滿」「哪些可以清」**全部由核心算**（`padnote-sync` 的
//  `retention`）。平台只負責把「現在幾點」與這個天數傳進去 —— 兩個平台各算一份的話，
//  同一本筆記本在 iPad 上顯示還剩 3 天、在 Android 上卻已經被清掉。
//

import Foundation

public enum TrashRetention {

    /// UserDefaults 的鍵。Android 端用同一個名字的偏好（`trash_retention_days`）。
    public static let defaultsKey = "kairumo.trash.retentionDays"

    /// 預設 30 天。與核心的 `DEFAULT_RETENTION_DAYS` 一致。
    public static let defaultDays: UInt32 = 30

    /// 設定頁給使用者選的值。`0` = 永不自動清除。
    public static let choices: [UInt32] = [7, 30, 90, 0]

    /// 目前的保留天數。`0` = 永不自動清除（回收桶仍可手動清空）。
    ///
    /// 沒設過、或存了不在選項裡的怪值，一律回預設 —— 不要因為壞掉的偏好
    /// 變成「永不」（不清）或「1 天」（一下就清）。
    public static var days: UInt32 {
        get {
            guard let stored = UserDefaults.standard.object(forKey: defaultsKey) as? Int,
                  stored >= 0,
                  choices.contains(UInt32(stored))
            else { return defaultDays }
            return UInt32(stored)
        }
        set {
            UserDefaults.standard.set(Int(newValue), forKey: defaultsKey)
        }
    }

    /// 現在的 Unix 秒。**所有傳進核心的「現在」都從這裡來**，測試才有單一個地方可以換。
    public static func nowUnixSeconds() -> UInt64 {
        UInt64(max(0, Date().timeIntervalSince1970))
    }
}
