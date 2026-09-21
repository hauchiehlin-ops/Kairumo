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

    private static let indexKey = "kairumo.sync.index.v1"
    private let indexKey = AccountSyncStore.indexKey
    private let settingsKey = "kairumo.sync.settings.v1"
    private let deviceKey = "kairumo.sync.deviceId.v1"

    /// 索引 JSON 的**非隔離**快照。
    ///
    /// `indexJSON` 是 `@MainActor` 的發布狀態，背景執行緒讀不到它 ——
    /// 而讀套件、算縮圖這些事本來就不該在主執行緒做。
    /// 落盤的那一份永遠與記憶體同步（`setIndex` 兩個一起寫），
    /// 所以從 UserDefaults 讀是安全的。
    public nonisolated static func indexJSONSnapshot() -> String {
        UserDefaults.standard.string(forKey: indexKey) ?? ""
    }

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

    /// 目前索引裡所有已刪除的 id。
    ///
    /// 同步套件檔案時用它擋掉殘留的 `.padnote` 目錄。核心 FFI 已經負責
    /// 合併與判斷單一 id；這裡只做一個保守 JSON 掃描，失敗時回空集合，
    /// 避免診斷或同步流程因索引格式異常而中斷。
    public var deletedNotebookIds: Set<String> {
        guard let data = indexJSON.data(using: .utf8),
              let index = try? JSONDecoder().decode(DecodedLibraryIndex.self, from: data)
        else { return [] }
        return Set(index.items.compactMap { key, item in
            item.deleted == true ? (item.id ?? key) : nil
        })
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

    // MARK: - 雲端快照（P1）

    /// 雲端內容的本機快照（`RemoteIndex` 的 JSON）。
    ///
    /// # 為什麼不放 UserDefaults
    ///
    /// 它會長到幾百 KB（每個雲端檔案一筆）。UserDefaults 是每次啟動整份
    /// 讀進記憶體的 plist，塞大東西進去會拖慢冷啟動。
    ///
    /// # 為什麼要綁帳號
    ///
    /// 快照裡有 Drive 的變更游標與 file id。換一個 Google 帳號之後那些
    /// 全部失效，而失效的游標不會報錯 —— 它只會回一堆對不上的變更，
    /// 症狀是「同步成功，但什麼也沒發生」。
    public func remoteIndexJSON(account: String) -> String {
        (try? String(contentsOf: remoteIndexURL(account: account), encoding: .utf8)) ?? ""
    }

    public func saveRemoteIndexJSON(_ json: String, account: String) {
        let url = remoteIndexURL(account: account)
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? json.write(to: url, atomically: true, encoding: .utf8)
    }

    /// 快照壞掉或帳號換了就丟掉。下一輪會自己重建 —— 那是唯一的慢路徑，
    /// 而且自我修復。
    public func discardRemoteIndex(account: String) {
        try? FileManager.default.removeItem(at: remoteIndexURL(account: account))
    }

    private func remoteIndexURL(account: String) -> URL {
        let safe = account.isEmpty
            ? "default"
            : account.lowercased().map { $0.isLetter || $0.isNumber ? String($0) : "-" }.joined()
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Kairumo/sync", isDirectory: true)
        return base.appendingPathComponent("remote-index-\(safe).json")
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

    private struct DecodedLibraryIndex: Decodable {
        var items: [String: DecodedLibraryItem]
    }

    private struct DecodedLibraryItem: Decodable {
        var id: String?
        var deleted: Bool?
    }
}
