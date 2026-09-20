//
//  AccountSyncStore.swift
//  Kairumo
//
//  帳號式同步的本機那一半（G-04 / G-05，ADR-0011）。
//
//  # 這個類別不做同步
//
//  它只做兩件事：把「使用者做了什麼」記成同步得動的事件，以及把合併結果讀出來。
//  真正的上傳下載是 provider 的事（`padnote-sync`），還要等 G-01 的 OAuth。
//  先把記錄做對是有意義的 —— **記錄漏掉的東西，之後接上雲端也補不回來**。
//  最典型的是刪除：沒有留下墓碑的話，等雲端接上，另一台裝置會把已經刪掉的
//  筆記本原封不動傳回來。
//
//  # 為什麼與 NotebookStore 分開
//
//  `NotebookStore` 是**內容**的真相來源（頁面、筆跡、附件）。這裡記的是
//  **中繼資料與意圖**（誰改了名字、誰刪了什麼、什麼時候）。把兩者混在一起的話，
//  每次存檔都要重算整棵樹的時戳，而且分不出「使用者改名」與「從檔案讀回來」。
//

import Foundation

@MainActor
public final class AccountSyncStore: ObservableObject {

    public static let shared = AccountSyncStore()

    /// 筆記本與資料夾索引（`notebooks/index.json` 的內容）。
    @Published public private(set) var indexJSON: String = ""
    /// 跨裝置設定（`settings/global.json` 的內容）。
    @Published public private(set) var settingsJSON: String = ""

    /// 這台裝置的 id。**每次安裝一個，重裝就是新裝置**（ADR-0011）。
    ///
    /// 用它在時戳平手時決勝，所以必須穩定；存進 UserDefaults 就夠 ——
    /// 它不是機密，也不需要跨安裝存活。
    public let deviceId: String

    private let indexKey = "kairumo.sync.index.v1"
    private let settingsKey = "kairumo.sync.settings.v1"
    private let deviceKey = "kairumo.sync.deviceId.v1"

    private init() {
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: deviceKey) {
            deviceId = existing
        } else {
            let fresh = UUID().uuidString
            defaults.set(fresh, forKey: deviceKey)
            deviceId = fresh
        }
        indexJSON = defaults.string(forKey: indexKey) ?? ""
        settingsJSON = defaults.string(forKey: settingsKey) ?? ""
    }

    // MARK: - 筆記本與資料夾（G-05）

    /// 記下一個筆記本或資料夾的目前狀態（新增、改名、搬移都走這裡）。
    ///
    /// 改名與搬移**不能**靠「刪掉舊的再加一個」表示 —— 那在合併時與真正的
    /// 刪除完全一樣，另一台裝置會把它當成已刪除。
    public func record(
        id: String,
        title: String,
        parentId: String?,
        isFolder: Bool
    ) {
        let item = FfiLibraryItem(
            id: id,
            isFolder: isFolder,
            title: title,
            parentId: parentId ?? "",
            lamport: nextLamport(),
            device: deviceId,
            deleted: false
        )
        setIndex(syncUpsertItem(indexJson: indexJSON, item: item))
    }

    /// 記下刪除。留**墓碑**，不是把它從索引裡拿掉。
    public func recordDeletion(id: String) {
        setIndex(
            syncDeleteItem(
                indexJson: indexJSON,
                itemId: id,
                lamport: nextLamport(),
                deviceId: deviceId
            )
        )
    }

    private var isDeletedCache = [String: Bool]()
    private var lastIndexJSONForCache: String = ""

    /// 這個 id 是不是已經被（可能是另一台裝置）刪除了。
    ///
    /// 從雲端合併回來之後，本機要據此把對應的筆記本收掉。
    /// 索引裡沒看過的一律回 false —— 「沒看過」不是「被刪了」，
    /// 混在一起的話，剛同步過來的新筆記本會被當成已刪除而收掉。
    public func isDeleted(id: String) -> Bool {
        if indexJSON != lastIndexJSONForCache {
            isDeletedCache.removeAll(keepingCapacity: true)
            lastIndexJSONForCache = indexJSON
        }
        if let cached = isDeletedCache[id] { return cached }
        let result = syncIsDeleted(indexJson: indexJSON, itemId: id)
        isDeletedCache[id] = result
        return result
    }

    /// 某個資料夾底下還活著的項目。`parentId` 傳 nil 表示根目錄。
    public func children(of parentId: String?) -> [FfiLibraryItem] {
        syncChildrenOf(indexJson: indexJSON, parentId: parentId ?? "")
    }

    /// 把一個資料夾搬進去會不會形成環。**動手之前**問 ——
    /// 搬進自己的子孫裡，那棵子樹會從樹上斷開，救不回來。
    public func wouldCreateCycle(itemId: String, newParentId: String?) -> Bool {
        syncWouldCreateCycle(
            indexJson: indexJSON,
            itemId: itemId,
            newParentId: newParentId ?? ""
        )
    }

    /// 合併另一台裝置（或雲端）的索引。
    public func mergeIndex(_ remoteJSON: String) {
        setIndex(syncMergeIndex(mineJson: indexJSON, theirsJson: remoteJSON))
    }

    // MARK: - 跨裝置設定（G-04）

    /// 目前的介面語言。沒設過時回 nil，由平台自己決定預設。
    public var syncedLanguage: String? {
        let value = syncGetSetting(settingsJson: settingsJSON, field: .locale)
        return value.isEmpty ? nil : value
    }

    public func setSyncedLanguage(_ tag: String) {
        setSettings(
            syncSetSetting(
                settingsJson: settingsJSON,
                field: .locale,
                value: tag,
                lamport: nextLamport(),
                deviceId: deviceId
            )
        )
    }

    public var syncedToolbarJSON: String? {
        let value = syncGetSetting(settingsJson: settingsJSON, field: .toolbarJson)
        return value.isEmpty ? nil : value
    }

    public func setSyncedToolbarJSON(_ json: String) {
        setSettings(
            syncSetSetting(
                settingsJson: settingsJSON,
                field: .toolbarJson,
                value: json,
                lamport: nextLamport(),
                deviceId: deviceId
            )
        )
    }

    /// 合併另一台裝置（或雲端）的設定。
    public func mergeSettings(_ remoteJSON: String) {
        setSettings(syncMergeSettings(mineJson: settingsJSON, theirsJson: remoteJSON))
    }

    // MARK: - 內部

    /// 下一個時戳。**由核心從文件本身推導**，不是自己維護一個計數器 ——
    /// 計數器遲早會有一次忘了在合併之後往前跳，於是這台裝置寫出去的每一筆
    /// 都比對方舊，永遠推不上去。
    ///
    /// 索引與設定共用同一條時間線：取兩邊的較大值，才不會出現
    /// 「改完設定再改名，名字的時戳反而比較小」。
    private func nextLamport() -> UInt64 {
        max(syncNextLamport(json: indexJSON), syncNextLamport(json: settingsJSON))
    }

    private func setIndex(_ json: String) {
        indexJSON = json
        UserDefaults.standard.set(json, forKey: indexKey)
    }

    private func setSettings(_ json: String) {
        settingsJSON = json
        UserDefaults.standard.set(json, forKey: settingsKey)
    }
}
