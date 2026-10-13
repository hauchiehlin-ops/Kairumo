//
//  ProfileContext.swift
//  Kairumo
//
//  「現在是哪個設定檔」，以及它的資料該放在哪裡。
//
//  # 為什麼是一個全域、執行緒安全的東西
//
//  偏好設定、檔案位置、Keychain 帳號、`deviceId` 這些全部要依「現在的設定檔」決定，而它們被
//  背景執行緒、同步、匯出、BGTask 到處呼叫 —— 不能要求每個呼叫端先跳回主執行緒。
//  所以這裡只存一個受鎖保護的 id，其餘全部由它算出來。
//
//  # 預設設定檔 = 升級前的那一份，完全不變
//
//  - 偏好設定：鍵名**原樣**（沒有任何前綴）
//  - Keychain：帳號名**原樣**
//  - 檔案：照舊走 `DocumentStorageLocation`（使用者可能自己選過位置）
//  - `deviceId`：同一個鍵
//
//  只有其他設定檔才會加前綴／放到 `Profiles/<id>/`。既有使用者升級後沒有任何資料被搬動或改名。

import Foundation

public enum ProfileContext {
    /// 目前使用中的設定檔 id，存在**裝置共用**的偏好設定裡（不屬於任何設定檔）。
    static let activeKey = "kairumo.profiles.activeId"

    private static let lock = NSLock()
    private static var storedActiveId: String = {
        UserDefaults.standard.string(forKey: activeKey) ?? ProfileRecord.defaultId
    }()

    // MARK: - 目前是哪一個

    public static var activeId: String {
        lock.lock(); defer { lock.unlock() }
        return storedActiveId
    }

    public static var isDefault: Bool { activeId == ProfileRecord.defaultId }

    /// 切換使用中的設定檔。**只有 `ProfileSwitcher` 該呼叫它** —— 它負責先收尾、再切、再重新載入。
    static func setActive(_ id: String) {
        lock.lock()
        storedActiveId = id
        lock.unlock()
        UserDefaults.standard.set(id, forKey: activeKey)
    }

    // MARK: - 檔案

    private static func baseURL(_ directory: FileManager.SearchPathDirectory) -> URL {
        FileManager.default.urls(for: directory, in: .userDomainMask)[0]
            .appending(path: "Kairumo", directoryHint: .isDirectory)
            .appending(path: "Profiles", directoryHint: .isDirectory)
    }

    /// 這個設定檔的資料根目錄。**預設設定檔回 `nil`** —— 它走 `DocumentStorageLocation`
    /// （使用者可能搬過位置），不是我們決定的。
    public static func documentsRoot(for id: String) -> URL? {
        guard id != ProfileRecord.defaultId else { return nil }
        return baseURL(.applicationSupportDirectory)
            .appending(path: id, directoryHint: .isDirectory)
            .appending(path: "Documents", directoryHint: .isDirectory)
    }

    public static var activeDocumentsRoot: URL? { documentsRoot(for: activeId) }

    /// 快取（縮圖、預覽）。**一定要分開**：範例筆記的 id 在每個設定檔都一樣，
    /// 共用快取的話 B 會看到 A 畫過的縮圖。預設設定檔維持原位置。
    public static func cachesRoot(for id: String) -> URL? {
        guard id != ProfileRecord.defaultId else { return nil }
        return baseURL(.cachesDirectory).appending(path: id, directoryHint: .isDirectory)
    }

    public static var activeCachesRoot: URL? { cachesRoot(for: activeId) }

    /// 這個設定檔所有磁碟上的東西（刪除設定檔時用）。預設設定檔不在其中 ——
    /// 它的資料根目錄是使用者的，刪除時另外處理。
    public static func ownedDirectories(for id: String) -> [URL] {
        guard id != ProfileRecord.defaultId else { return [] }
        return [
            baseURL(.applicationSupportDirectory).appending(path: id, directoryHint: .isDirectory),
            baseURL(.cachesDirectory).appending(path: id, directoryHint: .isDirectory),
        ]
    }

    // MARK: - Keychain

    /// Keychain 的帳號名。預設設定檔**原樣**，其他加上設定檔 id。
    public static func scopedAccount(_ base: String, for id: String = activeId) -> String {
        id == ProfileRecord.defaultId ? base : "\(base).\(id)"
    }

    // MARK: - 偏好設定的鍵

    /// 套用設定檔前綴後的偏好鍵。給 `@AppStorage` 用（它只吃字串鍵，吃不下 `ProfileDefaults`）：
    /// `@AppStorage(ProfileContext.scopedKey("某個鍵"))`。預設設定檔沒有前綴，鍵名原樣。
    /// 鍵是在 View 建立時解析的 —— 切換設定檔會整棵重建（見 `ProfileSwitcher`），新的 View 就拿到新的鍵。
    public static func scopedKey(_ key: String, for id: String = activeId) -> String {
        prefix(for: id) + key
    }

    static func prefix(for id: String) -> String {
        id == ProfileRecord.defaultId ? "" : "kairumo.pf.\(id)::"
    }
}

/// 依設定檔分開的偏好設定。**取代程式裡原本直接用的 `UserDefaults.standard`。**
///
/// 不用 `UserDefaults(suiteName:)`：suite 在 macOS 上會碰到 App Group 的檢查（甚至跳出
/// 「想存取其他 App 資料」的詢問），而且刪除設定檔時要清一整個 plist。
/// 這裡改成在同一個標準網域裡加**前綴**：預設設定檔沒有前綴（鍵名與升級前完全相同），
/// 其他設定檔是 `kairumo.pf.<id>::<鍵>`。刪除時掃前綴即可。
///
/// 只實作程式裡真的用到的那幾個方法 —— 多一個方法就多一個可能漏掉前綴的出口。
public struct ProfileDefaults: Sendable {
    public let profileId: String
    private let prefix: String

    public init(profileId: String) {
        self.profileId = profileId
        self.prefix = ProfileContext.prefix(for: profileId)
    }

    /// 目前使用中的設定檔的偏好設定。**每次呼叫都重新解析** —— 不要把它存起來跨越切換。
    public static var current: ProfileDefaults { ProfileDefaults(profileId: ProfileContext.activeId) }

    /// 整台裝置共用的偏好設定（不屬於任何設定檔）：例如模型下載、工具提示延遲、設定檔名單本身。
    /// 用這個要有理由 —— 預設是 `current`。
    public static var device: UserDefaults { .standard }

    private var store: UserDefaults { .standard }
    private func key(_ key: String) -> String { prefix + key }

    public func object(forKey defaultName: String) -> Any? { store.object(forKey: key(defaultName)) }
    public func string(forKey defaultName: String) -> String? { store.string(forKey: key(defaultName)) }
    public func data(forKey defaultName: String) -> Data? { store.data(forKey: key(defaultName)) }
    public func array(forKey defaultName: String) -> [Any]? { store.array(forKey: key(defaultName)) }
    public func stringArray(forKey defaultName: String) -> [String]? { store.stringArray(forKey: key(defaultName)) }
    public func bool(forKey defaultName: String) -> Bool { store.bool(forKey: key(defaultName)) }
    public func double(forKey defaultName: String) -> Double { store.double(forKey: key(defaultName)) }
    public func float(forKey defaultName: String) -> Float { store.float(forKey: key(defaultName)) }
    public func integer(forKey defaultName: String) -> Int { store.integer(forKey: key(defaultName)) }

    public func set(_ value: Any?, forKey defaultName: String) { store.set(value, forKey: key(defaultName)) }
    public func removeObject(forKey defaultName: String) { store.removeObject(forKey: key(defaultName)) }
    public func synchronize() { _ = store.synchronize() }

    /// 這個設定檔的所有偏好（**鍵名去掉前綴**）。備份用。
    public func dictionaryRepresentation() -> [String: Any] {
        let all = store.dictionaryRepresentation()
        if prefix.isEmpty {
            // 預設設定檔：排除其他設定檔的鍵與裝置共用的鍵，只留自己的。
            return all.filter { !$0.key.hasPrefix(ProfileDefaults.anyProfilePrefix) && !ProfileDefaults.isDeviceKey($0.key) }
        }
        var out: [String: Any] = [:]
        for (name, value) in all where name.hasPrefix(prefix) {
            out[String(name.dropFirst(prefix.count))] = value
        }
        return out
    }

    /// 刪除這個設定檔的**全部**偏好。只用在刪除設定檔；預設設定檔不走這裡（沒有前綴可掃）。
    public static func removeAll(forProfile id: String) {
        let prefix = ProfileContext.prefix(for: id)
        guard !prefix.isEmpty else { return }
        for name in UserDefaults.standard.dictionaryRepresentation().keys where name.hasPrefix(prefix) {
            UserDefaults.standard.removeObject(forKey: name)
        }
    }

    // MARK: - 辨認

    static let anyProfilePrefix = "kairumo.pf."

    /// 裝置共用的鍵：不能被當成預設設定檔的資料備份或清除。
    static func isDeviceKey(_ name: String) -> Bool {
        name == ProfileContext.activeKey || name.hasPrefix("kairumo.profiles.")
    }
}
