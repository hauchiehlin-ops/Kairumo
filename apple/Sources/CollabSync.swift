//
//  CollabSync.swift
//  Kairumo
//
//  即時協同的合併規則（設計見 `docs/plans/realtime-collaboration.md`）。
//
//  # 為什麼重寫
//
//  原本的協同是「收到就套用、以到達順序為準」，而且每一筆的時鐘都是 1：
//  兩人同時改同一個物件，兩台最後各自留著對方的版本，**永久不一致**；
//  筆跡以整頁取代，兩人同時畫，彼此的筆畫互相蓋掉。
//
//  這裡的每一條規則都**可交換、可結合、冪等**：同一組操作不論以什麼順序、
//  重複幾次套用，結果都相同 —— 那是「所有人最後看到同一份內容」的唯一保證。
//
//  # 線上格式 = 套件格式（協定 3，設計 §8）
//
//  欄位不是 Apple 的記憶體結構，而是兩個平台匯出 `.padnote` 時本來就互通的那一套：
//  核心的區塊／頁面 id、外觀 JSON（`TextBoxAppearance`、`ImageAppearance`…）、樣式信封。
//  Android 端（`collab/CollabSync.kt`）讀寫同一組欄位。
//

import CryptoKit
import Foundation
import PencilKit

/// 操作的時戳：Lamport 時鐘 + 使用者 id。全序：先比時鐘，相同再比 id。
///
/// 若 B 修改之前已經看過 A 的修改，B 的時鐘一定比較大 —— 「後改的贏」符合因果；
/// 真正同時（彼此都沒看過）時由 id 決定，所有人算出同一個結果。
struct LamportStamp: Comparable, Hashable {
    let lamport: UInt64
    let user: String

    static let zero = LamportStamp(lamport: 0, user: "")
    /// 整份狀態裡「沒有時戳」（加入房間時就有）的欄位，在要狀態的一方以這個時戳寫入：
    /// 勝過自己的起點（`zero`），輸給任何一次真正的修改 —— 房間裡的內容優先於剛加入者
    /// 可能過期的那一份（設計 §7）。與 Android 端 `ROOM_BASE` 相同。
    static let roomBase = LamportStamp(lamport: 0, user: "~base")

    static func < (a: LamportStamp, b: LamportStamp) -> Bool {
        a.lamport != b.lamport ? a.lamport < b.lamport : a.user < b.user
    }
}

/// 一個物件（或頁面、頁面層級設定）的欄位修改。`fields` 是 JSON 值。
struct ObjectPatch {
    let type: String
    let id: String
    var fields: [String: Any]

    var key: String { "\(type):\(id)" }

    /// 特殊欄位：刪除。也是欄位，所以刪除與修改走同一套比較。
    static let deletedField = "#deleted"

    var payload: [String: Any] { ["type": type, "id": id, "fields": fields] }

    init(type: String, id: String, fields: [String: Any]) {
        self.type = type
        self.id = id
        self.fields = fields
    }

    init?(payload: [String: Any]) {
        guard let type = payload["type"] as? String, let id = payload["id"] as? String,
              let fields = payload["fields"] as? [String: Any] else { return nil }
        self.init(type: type, id: id, fields: fields)
    }
}

/// 整份狀態裡的一個物件：欄位依寫入時戳分組（設計 §7）。JSON 與 Android 端 `SnapshotEntry` 相同。
struct SnapshotEntry {
    let type: String
    let id: String
    var groups: [(stamp: LamportStamp, fields: [String: Any])]

    var key: String { "\(type):\(id)" }

    var json: [String: Any] {
        ["type": type, "id": id,
         "g": groups.map { ["l": $0.stamp.lamport, "u": $0.stamp.user, "f": $0.fields] as [String: Any] }]
    }

    init(type: String, id: String, groups: [(stamp: LamportStamp, fields: [String: Any])]) {
        self.type = type
        self.id = id
        self.groups = groups
    }

    init?(json: [String: Any]) {
        guard let type = json["type"] as? String, let id = json["id"] as? String,
              let list = json["g"] as? [[String: Any]] else { return nil }
        self.type = type
        self.id = id
        self.groups = list.compactMap { g in
            guard let fields = g["f"] as? [String: Any] else { return nil }
            let lamport = (g["l"] as? NSNumber)?.uint64Value ?? 0
            return (LamportStamp(lamport: lamport, user: (g["u"] as? String) ?? ""), fields)
        }
    }
}

/// 一次本機寫回要送出的東西。
struct CollabOutgoing {
    var patches: [ObjectPatch] = []
    /// 文字方塊的內容變了：`(方塊 id, 舊文字, 新文字)`。內容不走欄位 LWW，改由字元 CRDT 送（設計 §8.3）。
    var textEdits: [(id: String, old: String, new: String)] = []

    var isEmpty: Bool { patches.isEmpty && textEdits.isEmpty }
}

/// 畫布物件的欄位層級「最後寫入者勝」。
///
/// `shadow` 是「大家應該都有的那一份」：每個物件最後一次同步過的完整欄位。
/// 本機的修改與它比對，差異就是要送出的欄位；收到的修改先併進它，再整份寫回筆記本 ——
/// 所以只帶了幾個欄位的修改，也能還原出完整的物件。
final class CollabObjectSync {

    private(set) var shadow: [String: [String: Any]] = [:]
    private(set) var stamps: [String: [String: LamportStamp]] = [:]
    /// 每一頁的排序鍵（設計 §8.4）。
    private(set) var pagePositions: [String: String] = [:]
    /// 物件 id → 堆疊順序的排序鍵（設計 §8.7）。與頁面的排序鍵同一套分數索引。
    private(set) var zPositions: [String: String] = [:]
    /// 頁面還沒出現的物件（別人先送了物件、頁面的新增還沒到）：等頁面出現再寫回。
    private(set) var deferredKeys: Set<String> = []
    /// 正在套用別人的修改：這段期間的寫回不送出（否則會把對方的修改當成自己的再廣播一次）。
    var isApplyingRemote = false
    /// 本機的編碼器**產生過**的欄位（依型別）。
    ///
    /// 欄位不見了有兩種意思：使用者清掉了（例如拿掉邊框色），或那是**另一個平台才有**的欄位
    /// （Apple 的 `materialType`，Android 的編碼器根本不會寫）。前者要送「刪除這個欄位」，
    /// 後者絕對不能送 —— 否則每一次修改都會把別台的資料抹掉。分辨的方法：本機寫過的才算本機的。
    private var localKeys: [String: Set<String>] = [:]

    private func learnLocalKeys(_ maps: [String: CollabCanonical.Entry]) {
        for (_, entry) in maps { localKeys[entry.type, default: []].formUnion(entry.dict.keys) }
    }

    private func isLocalKey(_ field: String, type: String) -> Bool {
        localKeys[type]?.contains(field) == true
    }

    /// 隨新圖片一起送的檔案內容（不是物件的欄位，套用前會拿掉）。
    static let blobField = "#blob"
    /// 逐字格式的錨點（設計 §8.3；不是物件的欄位，套用前會拿掉）。
    static let anchorField = "#ra"
    /// 這一版編碼得出來的型別（`CollabCanonical.maps`）。
    static let knownTypes: Set<String> = [
        "page", "text", "image", "table", "shape", "connection",
        "link", "model3d", "audio", "pin", "tape", "sticky",
    ]

    /// 只在新增時有效的欄位：文字方塊的內容之後走字元 CRDT（`text_ops`）。
    static let createOnlyFields: [String: Set<String>] = ["text": ["text"]]

    // MARK: 基準

    /// 以這份內容為「大家都有的」起點（開啟筆記本、加入房間時）。不送出任何東西。
    func reset(to doc: NotebookDocument) {
        shadow = [:]
        stamps = [:]
        deferredKeys = []
        let ids = doc.pageIds ?? []
        pagePositions = Dictionary(uniqueKeysWithValues: zip(ids, FractionalIndex.initialKeys(ids.count)))
        // 同樣的順序算出同樣的鍵：兩台以同一份筆記開始時，每個物件的排序鍵也相同。
        zPositions = [:]
        for order in CollabCanonical.objectOrders(of: doc).values {
            for (id, key) in zip(order, FractionalIndex.initialKeys(order.count)) { zPositions[id] = key }
        }
        let maps = CollabCanonical.maps(of: doc, pagePositions: pagePositions, zPositions: zPositions)
        learnLocalKeys(maps)
        for (key, entry) in maps {
            var dict = entry.dict
            dict[ObjectPatch.deletedField] = false
            shadow[key] = dict
        }
    }

    // MARK: 送出

    /// 本機的內容與上次同步的差異：每個有變的物件一筆修改，只帶變了的欄位。
    /// 呼叫之後這些修改即視為已同步（由呼叫端以 `stamp` 送出）。
    func outgoing(for doc: NotebookDocument, stamp: LamportStamp) -> CollabOutgoing {
        reconcilePagePositions(order: doc.pageIds ?? [])
        reconcileZ(CollabCanonical.objectOrders(of: doc))
        var result = CollabOutgoing()
        let current = CollabCanonical.maps(of: doc, pagePositions: pagePositions, zPositions: zPositions)
        learnLocalKeys(current)
        for (key, entry) in current {
            let known = shadow[key] ?? [:]
            let isNew = (known[ObjectPatch.deletedField] as? Bool) != false
            var changed: [String: Any] = [:]
            if isNew { changed[ObjectPatch.deletedField] = false }
            let createOnly = Self.createOnlyFields[entry.type] ?? []
            for (field, value) in entry.dict where !Self.equal(known[field], value) {
                if !isNew && createOnly.contains(field) {
                    if entry.type == "text", field == "text" {
                        result.textEdits.append((entry.id, (known[field] as? String) ?? "", (value as? String) ?? ""))
                    }
                    // 不走欄位 LWW，但 shadow 要跟上（之後刪除再復原時，新增帶的是最新內容）。
                    var updated = shadow[key] ?? [:]
                    updated[field] = value
                    shadow[key] = updated
                    continue
                }
                changed[field] = value
            }
            for field in known.keys where field != ObjectPatch.deletedField && entry.dict[field] == nil
                && isLocalKey(field, type: entry.type) {
                changed[field] = NSNull()
            }
            guard !changed.isEmpty else { continue }
            result.patches.append(ObjectPatch(type: entry.type, id: entry.id, fields: changed))
        }
        for (key, known) in shadow where current[key] == nil && (known[ObjectPatch.deletedField] as? Bool) == false {
            let parts = key.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2, parts[0] != "meta" else { continue }
            // 還在等頁面（或兩端形狀）的物件、這一版畫不出來的型別：本機沒有不代表被刪除。
            guard !deferredKeys.contains(key), Self.knownTypes.contains(parts[0]) else { continue }
            result.patches.append(ObjectPatch(type: parts[0], id: parts[1], fields: [ObjectPatch.deletedField: true]))
        }
        for patch in result.patches { merge(patch, stamp: stamp) }
        return result
    }

    /// 本機的頁序變了（新增、刪除、搬動）：只替**順序對不上**的頁換排序鍵，其他頁不動 ——
    /// 換掉所有頁的鍵等於宣稱「我把每一頁都搬了」，會蓋掉別人同時的搬動。
    private func reconcilePagePositions(order: [String]) {
        Self.reconcileKeys(order: order, keys: &pagePositions)
    }

    /// 本機的堆疊順序變了：同樣只替順序對不上的物件換鍵；不在任何順序裡的物件拿掉它的鍵。
    private func reconcileZ(_ orders: [String: [String]]) {
        var listed: Set<String> = []
        for order in orders.values {
            Self.reconcileKeys(order: order, keys: &zPositions)
            listed.formUnion(order)
        }
        zPositions = zPositions.filter { listed.contains($0.key) }
    }

    /// 依本機的順序補排序鍵：順序對的沿用，對不上的在前後兩個鍵之間取一個新的。
    static func reconcileKeys(order: [String], keys: inout [String: String]) {
        var previous = ""
        for (index, id) in order.enumerated() {
            if let key = keys[id], key > previous {
                previous = key
                continue
            }
            // 往後找第一個鍵比 previous 大的，新鍵插在兩者之間。
            let snapshot = keys
            let upper = order[(index + 1)...].lazy.compactMap { snapshot[$0] }.first { $0 > previous }
            let key = FractionalIndex.between(previous, upper)
            keys[id] = key
            previous = key
        }
    }

    /// 依合併狀態算出每一頁的堆疊順序、「在筆跡下方」與「鎖定在畫布上」名單（頁面 id → 正規 id；已刪除的不算）。
    func desiredStacking() -> (orders: [String: [String]], under: [String: [String]], locked: [String: [String]]) {
        var ordered: [String: [(String, String)]] = [:]
        var under: [String: [String]] = [:]
        var locked: [String: [String]] = [:]
        for (key, dict) in shadow where (dict[ObjectPatch.deletedField] as? Bool) == false {
            guard let page = dict["page"] as? String else { continue }
            let id = String(key.split(separator: ":", maxSplits: 1).last ?? "")
            if let z = dict["z"] as? String { ordered[page, default: []].append((z, id)) }
            if (dict["under"] as? Bool) == true { under[page, default: []].append(id) }
            if (dict["locked"] as? Bool) == true { locked[page, default: []].append(id) }
        }
        return (ordered.mapValues { $0.sorted { $0.0 != $1.0 ? $0.0 < $1.0 : $0.1 < $1.1 }.map(\.1) },
                under.mapValues { $0.sorted() },
                locked.mapValues { $0.sorted() })
    }

    // MARK: 收到

    /// 套用一筆別人的修改：只有時戳比本機新的欄位會寫入。回傳筆記本有沒有變。
    @discardableResult
    func apply(_ patch: ObjectPatch, stamp: LamportStamp, to doc: inout NotebookDocument) -> Bool {
        var fields = patch.fields
        let known = shadow[patch.key]
        let exists = (known?[ObjectPatch.deletedField] as? Bool) == false
        if exists {
            // 已經存在的物件，只在新增時有效的欄位不採用（內容走字元 CRDT）。
            for field in Self.createOnlyFields[patch.type] ?? [] { fields.removeValue(forKey: field) }
        }
        guard merge(ObjectPatch(type: patch.type, id: patch.id, fields: fields), stamp: stamp) else { return false }
        if patch.type == "page", let pos = shadow[patch.key]?["pos"] as? String { pagePositions[patch.id] = pos }
        if fields.keys.contains("z") {
            if let z = shadow[patch.key]?["z"] as? String { zPositions[patch.id] = z } else { zPositions.removeValue(forKey: patch.id) }
        }
        writeBack(key: patch.key, type: patch.type, id: patch.id, into: &doc)
        return true
    }

    // MARK: 整份狀態（設計 §7：加入房間、補發不完整）

    /// 合併狀態的完整內容：每個物件依時戳分組的欄位（含已刪除的墓碑）。
    func snapshot() -> [SnapshotEntry] {
        shadow.map { key, dict in
            let fieldStamps = stamps[key] ?? [:]
            var groups: [LamportStamp: [String: Any]] = [:]
            for (field, value) in dict { groups[fieldStamps[field] ?? .zero, default: [:]][field] = value }
            let parts = key.split(separator: ":", maxSplits: 1).map(String.init)
            return SnapshotEntry(type: parts.first ?? "", id: parts.count > 1 ? parts[1] : "",
                                 groups: groups.map { ($0.key, $0.value) })
        }
    }

    /// 套用別人給的整份狀態（只有要狀態的那一方套用）。
    ///
    /// 沒有時戳的欄位以 `LamportStamp.roomBase` 寫入：房間裡的內容優先於自己可能過期的起點，
    /// 但輸給任何一次真正的修改。兩邊都有、內容不同的文字方塊回傳在 `textOverrides` ——
    /// 文字內容走字元 CRDT，由呼叫端以房間的全文為新基準重建（設計 §8.3 的退路）。
    func applySnapshot(_ entries: [SnapshotEntry], to doc: inout NotebookDocument)
        -> (changed: Bool, textOverrides: [(id: String, text: String)]) {
        var changed = false
        var overrides: [(id: String, text: String)] = []
        for entry in entries {
            for group in entry.groups {
                let stamp = group.stamp.lamport == 0 ? LamportStamp.roomBase : group.stamp
                if apply(ObjectPatch(type: entry.type, id: entry.id, fields: group.fields), stamp: stamp, to: &doc) {
                    changed = true
                }
            }
            if entry.type == "text",
               let theirs = entry.groups.lazy.compactMap({ $0.fields["text"] as? String }).first,
               let known = shadow[entry.key], (known[ObjectPatch.deletedField] as? Bool) == false,
               let mine = known["text"] as? String, mine != theirs {
                overrides.append((entry.id, theirs))
            }
        }
        return (changed, overrides)
    }

    /// 合併狀態裡還在的物件（`type:id`）。
    var liveKeys: Set<String> {
        Set(shadow.filter { ($0.value[ObjectPatch.deletedField] as? Bool) == false }.keys)
    }

    /// 忘掉這些物件：下一次送出會把它們當成新的整個送出去。
    /// 加入房間時「只有自己有」的物件以此補給房間（設計 §7）。
    func forget(_ keys: some Collection<String>) {
        for key in keys {
            shadow.removeValue(forKey: key)
            stamps.removeValue(forKey: key)
            deferredKeys.remove(key)
        }
    }

    /// 欄位逐一比時戳，新的才寫進 shadow。回傳有沒有任何欄位被採用。
    @discardableResult
    private func merge(_ patch: ObjectPatch, stamp: LamportStamp) -> Bool {
        var dict = shadow[patch.key] ?? [:]
        var fieldStamps = stamps[patch.key] ?? [:]
        var accepted = false
        for (field, value) in patch.fields {
            let current = fieldStamps[field] ?? .zero
            guard current < stamp else { continue }
            fieldStamps[field] = stamp
            if value is NSNull { dict.removeValue(forKey: field) } else { dict[field] = value }
            accepted = true
        }
        shadow[patch.key] = dict
        stamps[patch.key] = fieldStamps
        return accepted
    }

    private func writeBack(key: String, type: String, id: String, into doc: inout NotebookDocument) {
        let dict = shadow[key] ?? [:]
        let deleted = (dict[ObjectPatch.deletedField] as? Bool) == true
        if CollabCanonical.write(type: type, id: id, fields: dict, deleted: deleted, into: &doc) {
            deferredKeys.remove(key)
        } else {
            deferredKeys.insert(key)
        }
    }

    /// 頁面補上之後，把等著那一頁的物件寫回。
    func retryDeferred(into doc: inout NotebookDocument) {
        for key in deferredKeys {
            let parts = key.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            writeBack(key: key, type: parts[0], id: parts[1], into: &doc)
        }
    }

    /// 依合併結果，頁面應有的順序（未刪除的頁依 `(pos, id)`）。
    func desiredPageOrder() -> [String] {
        shadow.compactMap { key, dict -> (String, String)? in
            guard key.hasPrefix("page:"), (dict[ObjectPatch.deletedField] as? Bool) != true,
                  let pos = dict["pos"] as? String else { return nil }
            return (String(key.dropFirst(5)), pos)
        }
        .sorted { $0.1 != $1.1 ? $0.1 < $1.1 : $0.0 < $1.0 }
        .map(\.0)
    }

    /// 寫回筆記本之後，以實際的編碼更新 shadow（時戳不動）。
    ///
    /// 解碼再編碼不保證與收到的欄位逐字相同（例如省略的預設值）；不更新的話，
    /// 下一次本機修改會把這些欄位當成「我改的」，以較新的時戳再送一次，蓋掉別人的值。
    func refreshShadow(from doc: NotebookDocument) {
        let current = CollabCanonical.maps(of: doc, pagePositions: pagePositions, zPositions: zPositions)
        for (key, entry) in current {
            var dict = shadow[key] ?? [:]
            for (field, value) in entry.dict { dict[field] = value }
            for field in dict.keys where field != ObjectPatch.deletedField && entry.dict[field] == nil {
                // 本機寫不回來的欄位（另一個平台才有的）照樣保留，轉送時不能抹掉別人的資料。
                if isLocalKey(field, type: entry.type) { dict.removeValue(forKey: field) }
            }
            dict[ObjectPatch.deletedField] = false
            shadow[key] = dict
        }
        for (key, known) in shadow where current[key] == nil && (known[ObjectPatch.deletedField] as? Bool) == false {
            if key.hasPrefix("meta:") || deferredKeys.contains(key) { continue }
            if !Self.knownTypes.contains(String(key.prefix { $0 != ":" })) { continue }
            var dict = known
            dict[ObjectPatch.deletedField] = true
            shadow[key] = dict
        }
    }

    // MARK: 復原

    /// 復原要還原的欄位裡，**別人在我之後改過的**保留別人的值（設計 §6）。
    ///
    /// 回傳有沒有任何欄位因此被保留（呼叫端用來提示「已被他人修改的部分沒有復原」）。
    @discardableResult
    func protectRemoteEdits(target: inout NotebookDocument, current: NotebookDocument, me: String) -> Bool {
        let targetMaps = CollabCanonical.maps(of: target, pagePositions: pagePositions, zPositions: zPositions)
        let currentMaps = CollabCanonical.maps(of: current, pagePositions: pagePositions, zPositions: zPositions)
        var protected = false
        var keep: [String: (type: String, id: String, dict: [String: Any])] = [:]
        var keepDeleted: [(type: String, id: String)] = []
        for key in Set(targetMaps.keys).union(currentMaps.keys) where !key.hasPrefix("page:") {
            let fieldStamps = stamps[key] ?? [:]
            let mine: (String) -> Bool = { field in
                guard let stamp = fieldStamps[field] else { return true }
                return stamp.user == me || stamp.user.isEmpty
            }
            switch (targetMaps[key], currentMaps[key]) {
            case let (b?, n?):
                var merged = b.dict
                for field in Set(b.dict.keys).union(n.dict.keys)
                where !Self.equal(b.dict[field], n.dict[field]) && !mine(field) {
                    merged[field] = n.dict[field]
                    protected = true
                }
                keep[key] = (b.type, b.id, merged)
            case (nil, let n?):
                // 復原要刪掉的物件，別人之後改過 → 留著它。
                if !mine(ObjectPatch.deletedField) || n.dict.keys.contains(where: { !mine($0) }) {
                    keep[key] = n
                    protected = true
                }
            case (let b?, nil):
                // 復原要放回的物件，別人之後刪掉了 → 尊重別人的刪除。
                if !mine(ObjectPatch.deletedField) {
                    keepDeleted.append((b.type, b.id))
                    protected = true
                }
            case (nil, nil):
                break
            }
        }
        guard protected else { return false }
        for (_, entry) in keep {
            _ = CollabCanonical.write(type: entry.type, id: entry.id, fields: entry.dict, deleted: false, into: &target)
        }
        for entry in keepDeleted {
            _ = CollabCanonical.write(type: entry.type, id: entry.id, fields: [:], deleted: true, into: &target)
        }
        return true
    }

    // MARK: 比較

    static func equal(_ a: Any?, _ b: Any?) -> Bool {
        switch (a, b) {
        case (nil, nil): return true
        case (nil, _), (_, nil): return false
        case let (x?, y?): return (x as AnyObject).isEqual(y)
        }
    }
}

// MARK: - 正規格式的編解碼（Apple 的物件 ↔ 線上欄位）

/// Apple 的筆記本 ↔ 協定 3 的欄位（設計 §8.2）。
///
/// 每一種型別用的都是匯出 `.padnote` 時那一套編解碼器 —— Android 讀寫同一組鍵，
/// 不會出現「iPad 上改的顏色到 Android 變成別的鍵」。
enum CollabCanonical {

    typealias Entry = (type: String, id: String, dict: [String: Any])

    static func canonicalId(_ localId: String) -> String { NotebookPackageBridge.stableBlockId(localId) }

    /// 圖片內容的雜湊（= 核心的 blob id，兩平台相同）。讀檔一次之後記住。
    // profile-scope: profile 檔名 → 雜湊；不同設定檔可能有同名的不同圖檔，切換時清掉（ProfileManager.defaultExtraResets）
    nonisolated(unsafe) private static var blobHashes: [String: String] = [:]
    private static let blobLock = NSLock()

    /// 圖片檔所在的資料夾（編輯器在開始協同時設定；`NotebookStore` 的屬性只能在主執行緒讀）。
    // profile-scope: profile 每次開始協同都由編輯器重設成目前設定檔的資料夾；切換時一併清掉
    nonisolated(unsafe) static var attachmentsDirectory: URL?

    static func blobHash(fileName: String) -> String? {
        blobLock.lock(); defer { blobLock.unlock() }
        if let cached = blobHashes[fileName] { return cached }
        guard let url = attachmentsDirectory?.appending(path: fileName) else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        blobHashes[fileName] = hash
        return hash
    }

    /// 切換設定檔：上一位使用者的圖檔雜湊與資料夾不能留給下一位。
    static func resetForProfileSwitch() {
        blobLock.lock(); defer { blobLock.unlock() }
        blobHashes = [:]
        attachmentsDirectory = nil
    }

    static func rememberBlob(fileName: String, hash: String) {
        blobLock.lock(); defer { blobLock.unlock() }
        blobHashes[fileName] = hash
    }

    // MARK: 編碼

    static func maps(of doc: NotebookDocument, pagePositions: [String: String],
                     zPositions: [String: String] = [:]) -> [String: Entry] {
        let pageIds = doc.pageIds ?? []
        func page(_ index: Int) -> String? { index >= 0 && index < pageIds.count ? pageIds[index] : nil }
        var out: [String: Entry] = [:]
        let under = Set((doc.underInkObjectIdsByPage ?? [:]).values.flatMap { $0.map(canonicalId) })
        let locked = Set((doc.lockedObjectIdsByPage ?? [:]).values.flatMap { $0.map(canonicalId) })
        func add(_ type: String, _ localId: String, _ dict: [String: Any]) {
            let id = canonicalId(localId)
            var full = dict
            // 堆疊順序與「在筆跡下方」是每個物件自己的欄位：兩人同時調不同物件的層級，兩邊都留下（設計 §8.7）。
            full["under"] = under.contains(id)
            // 「鎖定在畫布上」比照辦理：鎖定 / 解除各是那個物件自己的一個欄位。
            full["locked"] = locked.contains(id)
            if let z = zPositions[id] { full["z"] = z }
            out["\(type):\(id)"] = (type, id, full)
        }

        for item in doc.textAttachments ?? [] {
            guard let p = page(item.pageIndex) else { continue }
            var dict = CollabJSON.flatten(CollabJSON.object(TextBoxAppearance.encode(item)), prefix: "a.")
            dict["page"] = p; dict["x"] = Double(item.x); dict["y"] = Double(item.y); dict["text"] = item.text
            add("text", item.id, dict)
        }
        for item in doc.attachments ?? [] {
            guard let p = page(item.pageIndex) else { continue }
            var dict = CollabJSON.flatten(CollabJSON.object(ImageAppearance.encode(item)), prefix: "a.")
            dict["page"] = p; dict["x"] = Double(item.x); dict["y"] = Double(item.y)
            if let hash = blobHash(fileName: item.fileName) { dict["blob"] = hash }
            add("image", item.id, dict)
        }
        for item in doc.tableAttachments ?? [] {
            guard let p = page(item.pageIndex) else { continue }
            var dict = CollabJSON.flatten(CollabJSON.object(TableAppearance.encode(item)), prefix: "a.")
            dict.removeValue(forKey: "a.table.id")
            dict["page"] = p
            add("table", item.id, dict)
        }
        for shape in doc.shapeAttachments ?? [] {
            guard let p = page(shape.pageIndex) else { continue }
            var style = CollabJSON.encodable(ShapeStyleMeta(from: shape))
            style.removeValue(forKey: "id")
            var dict = CollabJSON.flatten(style, prefix: "s.")
            dict["page"] = p
            dict["x"] = Double(shape.x); dict["y"] = Double(shape.y)
            dict["width"] = Double(shape.width); dict["height"] = Double(shape.height)
            dict["rotation"] = shape.canvasRotation
            add("shape", shape.id, dict)
        }
        for link in doc.connectionAttachments ?? [] {
            guard let p = page(link.pageIndex) else { continue }
            var style = CollabJSON.encodable(ConnectionStyleMeta(from: link))
            style.removeValue(forKey: "id")
            var dict = CollabJSON.flatten(style, prefix: "s.")
            dict["page"] = p
            dict["from"] = canonicalId(link.fromShapeId)
            dict["to"] = canonicalId(link.toShapeId)
            add("connection", link.id, dict)
        }
        func payload<T: Encodable & PageIndexed>(_ type: String, _ items: [T]?, id: (T) -> String) {
            for item in items ?? [] {
                guard let p = page(item.pageIndex) else { continue }
                var json = CollabJSON.encodable(item)
                json.removeValue(forKey: "id")
                json.removeValue(forKey: "pageIndex")
                var dict = CollabJSON.flatten(json, prefix: "p.")
                dict["page"] = p
                add(type, id(item), dict)
            }
        }
        payload("link", doc.linkAttachments) { $0.id }
        payload("model3d", doc.model3DAttachments) { $0.id }
        payload("audio", doc.audioAttachments) { $0.id }
        payload("pin", doc.commentPins) { $0.id }
        payload("tape", doc.tapeAttachments) { $0.id }
        payload("sticky", doc.stickyAnchors) { $0.id }

        for (index, id) in pageIds.enumerated() {
            var dict: [String: Any] = [:]
            if let pos = pagePositions[id] { dict["pos"] = pos }
            dict["paper"] = doc.paperId(forPage: index)
            out["page:\(id)"] = ("page", id, dict)
        }

        // 頁面層級的設定。堆疊順序與「在筆跡下方」已改成每個物件的欄位（協定 4）。
        var meta: [String: Any] = [:]
        for (key, value) in doc.checkedGuideItems ?? [:] { meta["checked:\(key)"] = value }
        out["meta:notebook"] = ("meta", "notebook", meta)
        return out
    }

    // MARK: 寫回

    /// 把一個物件的完整欄位寫回筆記本。回傳 false = 它所在的頁還不存在，晚點再試。
    static func write(type: String, id: String, fields: [String: Any], deleted: Bool,
                      into doc: inout NotebookDocument) -> Bool {
        let pageIds = doc.pageIds ?? []
        if type == "page" {
            if !deleted, let index = pageIds.firstIndex(of: id), let paper = fields["paper"] as? String {
                doc.padPagePaperIds(to: max(doc.pageCount, index + 1))
                if index < (doc.pagePaperIds?.count ?? 0) { doc.pagePaperIds?[index] = paper }
            }
            return true // 頁面的新增、刪除、搬動由編輯器依 `desiredPageOrder` 調整
        }
        if type == "meta" {
            writeMeta(fields, into: &doc)
            return true
        }
        var pageIndex = 0
        if !deleted {
            guard let page = fields["page"] as? String, let index = pageIds.firstIndex(of: page) else { return false }
            pageIndex = index
        }
        func number(_ key: String) -> CGFloat? { (fields[key] as? NSNumber).map { CGFloat($0.doubleValue) } }

        switch type {
        case "text":
            var list = doc.textAttachments ?? []
            let index = list.firstIndex { canonicalId($0.id) == id }
            if deleted { if let index { list.remove(at: index) }; doc.textAttachments = list; return true }
            var item = index.map { list[$0] }
                ?? NoteTextAttachment(id: id, pageIndex: pageIndex, text: (fields["text"] as? String) ?? "",
                                      backgroundColorHex: "clear", hasBorder: false)
            TextBoxAppearance.apply(CollabJSON.string(CollabJSON.unflatten(fields, prefix: "a.")), to: &item)
            item.pageIndex = pageIndex
            if let v = number("x") { item.x = v }
            if let v = number("y") { item.y = v }
            if let index { list[index] = item } else { list.append(item) }
            doc.textAttachments = list

        case "image":
            var list = doc.attachments ?? []
            let index = list.firstIndex { canonicalId($0.id) == id }
            if deleted { if let index { list.remove(at: index) }; doc.attachments = list; return true }
            let appearance = CollabJSON.unflatten(fields, prefix: "a.")
            let fileName = ((appearance["image"] as? [String: Any])?["fileName"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                ?? "\((fields["blob"] as? String) ?? id).png"
            var item = index.map { list[$0] } ?? NoteImageAttachment(id: id, fileName: fileName, pageIndex: pageIndex)
            ImageAppearance.apply(CollabJSON.string(appearance), to: &item)
            item.pageIndex = pageIndex
            if let v = number("x") { item.x = v }
            if let v = number("y") { item.y = v }
            if let index { list[index] = item } else { list.append(item) }
            doc.attachments = list

        case "table":
            var list = doc.tableAttachments ?? []
            let index = list.firstIndex { canonicalId($0.id) == id }
            if deleted { if let index { list.remove(at: index) }; doc.tableAttachments = list; return true }
            var item = index.map { list[$0] } ?? NoteTableAttachment(id: id, pageIndex: pageIndex)
            let appearance = CollabJSON.unflatten(fields, prefix: "a.")
            TableAppearance.apply(CollabJSON.string(appearance), to: &item)
            if let table = appearance["table"] as? [String: Any] {
                if let rows = (table["rows"] as? NSNumber)?.intValue { item.rows = rows }
                if let cols = (table["cols"] as? NSNumber)?.intValue { item.cols = cols }
                if let cells = table["cells"] as? [String] { item.cells = cells }
                if let header = table["headerRow"] as? Bool { item.headerRow = header }
            }
            item.pageIndex = pageIndex
            if let index { list[index] = item } else { list.append(item) }
            doc.tableAttachments = list

        case "shape":
            var list = doc.shapeAttachments ?? []
            let index = list.firstIndex { canonicalId($0.id) == id }
            if deleted {
                if let index { list.remove(at: index) }
                doc.shapeAttachments = list
                return true
            }
            var item = index.map { list[$0] } ?? NoteShapeAttachment(id: id, pageIndex: pageIndex)
            if let style = CollabJSON.decodable(ShapeStyleMeta.self, CollabJSON.unflatten(fields, prefix: "s.")) {
                style.apply(to: &item)
                item.groupId = style.groupId
            }
            item.pageIndex = pageIndex
            if let v = number("x") { item.x = v }
            if let v = number("y") { item.y = v }
            if let v = number("width") { item.width = v }
            if let v = number("height") { item.height = v }
            if let v = fields["rotation"] as? NSNumber { item.canvasRotation = v.doubleValue }
            if let index { list[index] = item } else { list.append(item) }
            doc.shapeAttachments = list

        case "connection":
            var list = doc.connectionAttachments ?? []
            let index = list.firstIndex { canonicalId($0.id) == id }
            if deleted { if let index { list.remove(at: index) }; doc.connectionAttachments = list; return true }
            let shapes = doc.shapeAttachments ?? []
            guard let fromId = (fields["from"] as? String).flatMap({ c in shapes.first { canonicalId($0.id) == c }?.id }),
                  let toId = (fields["to"] as? String).flatMap({ c in shapes.first { canonicalId($0.id) == c }?.id })
            else { return false } // 兩端的形狀還沒到
            var item = index.map { list[$0] }
                ?? NoteConnectionAttachment(id: id, pageIndex: pageIndex, fromShapeId: fromId, toShapeId: toId)
            item.fromShapeId = fromId
            item.toShapeId = toId
            if let style = CollabJSON.decodable(ConnectionStyleMeta.self, CollabJSON.unflatten(fields, prefix: "s.")) {
                style.apply(to: &item)
            }
            item.pageIndex = pageIndex
            if let index { list[index] = item } else { list.append(item) }
            doc.connectionAttachments = list

        case "link": return writePayload(\.linkAttachments, id: id, fields: fields, deleted: deleted, pageIndex: pageIndex, into: &doc)
        case "model3d": return writePayload(\.model3DAttachments, id: id, fields: fields, deleted: deleted, pageIndex: pageIndex, into: &doc)
        case "audio": return writePayload(\.audioAttachments, id: id, fields: fields, deleted: deleted, pageIndex: pageIndex, into: &doc)
        case "pin": return writePayload(\.commentPins, id: id, fields: fields, deleted: deleted, pageIndex: pageIndex, into: &doc)
        case "tape": return writePayload(\.tapeAttachments, id: id, fields: fields, deleted: deleted, pageIndex: pageIndex, into: &doc)
        case "sticky": return writePayload(\.stickyAnchors, id: id, fields: fields, deleted: deleted, pageIndex: pageIndex, into: &doc)
        default:
            break // 認不得的型別：留在合併狀態裡，不顯示（設計 §8.2）
        }
        return true
    }

    private static func writePayload<T: Codable & Identifiable>(
        _ keyPath: WritableKeyPath<NotebookDocument, [T]?>, id: String, fields: [String: Any],
        deleted: Bool, pageIndex: Int, into doc: inout NotebookDocument
    ) -> Bool where T.ID == String {
        var list = doc[keyPath: keyPath] ?? []
        let index = list.firstIndex { canonicalId($0.id) == id }
        if deleted {
            if let index { list.remove(at: index) }
            doc[keyPath: keyPath] = list
            return true
        }
        var json = CollabJSON.unflatten(fields, prefix: "p.")
        json["id"] = index.map { list[$0].id } ?? id
        json["pageIndex"] = pageIndex
        guard let item = CollabJSON.decodable(T.self, json) else { return false }
        if let index { list[index] = item } else { list.append(item) }
        doc[keyPath: keyPath] = list
        return true
    }

    private static func writeMeta(_ fields: [String: Any], into doc: inout NotebookDocument) {
        var checked: [String: Bool] = [:]
        for (key, value) in fields where key.hasPrefix("checked:") {
            if let flag = value as? Bool { checked[String(key.dropFirst(8))] = flag }
        }
        doc.checkedGuideItems = checked.isEmpty ? nil : checked
    }

    /// 每一頁的堆疊順序（頁面 id → 由後到前的正規 id）。只列使用者排過的物件。
    static func objectOrders(of doc: NotebookDocument) -> [String: [String]] {
        let pageIds = doc.pageIds ?? []
        var out: [String: [String]] = [:]
        for (pageKey, ids) in doc.objectOrderByPage ?? [:] {
            guard let index = Int(pageKey), index >= 0, index < pageIds.count else { continue }
            out[pageIds[index]] = ids.map(canonicalId)
        }
        return out
    }

    /// 寫回合併後的堆疊順序、「在筆跡下方」與「鎖定在畫布上」名單（頁面 id → 正規 id）。
    static func writeStacking(orders: [String: [String]], under: [String: [String]], locked: [String: [String]],
                              into doc: inout NotebookDocument) {
        let pageIds = doc.pageIds ?? []
        // 正規 id → 本機 id（Apple 的附件 id 可能是大寫 UUID）。
        var local: [String: String] = [:]
        func index<T: Identifiable>(_ items: [T]?) where T.ID == String {
            for item in items ?? [] { local[canonicalId(item.id)] = item.id }
        }
        index(doc.attachments); index(doc.textAttachments); index(doc.tableAttachments)
        index(doc.shapeAttachments); index(doc.connectionAttachments); index(doc.linkAttachments)
        index(doc.model3DAttachments); index(doc.audioAttachments); index(doc.commentPins)
        func byIndex(_ lists: [String: [String]]) -> [String: [String]]? {
            var out: [String: [String]] = [:]
            for (page, ids) in lists where !ids.isEmpty {
                guard let i = pageIds.firstIndex(of: page) else { continue }
                out[String(i)] = ids.map { local[$0] ?? $0 }
            }
            return out.isEmpty ? nil : out
        }
        let order = byIndex(orders)
        let underInk = byIndex(under)
        if doc.objectOrderByPage != order { doc.objectOrderByPage = order }
        if doc.underInkObjectIdsByPage != underInk { doc.underInkObjectIdsByPage = underInk }
        // 鎖定名單在檔案裡是排序過的 id（`NotebookDocument.setLockedObjectIds`）。
        let lockedIds = byIndex(locked).map { $0.mapValues { $0.sorted() } }
        if doc.lockedObjectIdsByPage != lockedIds { doc.lockedObjectIdsByPage = lockedIds }
    }
}

// MARK: - 筆跡

/// 每一頁已經同步過的筆畫，以及線上 id 與本機筆畫的對應（設計 §8.1）。
///
/// 本機畫的筆畫，線上 id 就是它的內容雜湊；別台送來的筆畫保留對方給的 id ——
/// 之後本機擦掉它時送的是那個 id，對方才找得到是哪一筆。參考型別：編輯器以 `@State` 持有、不訂閱。
final class CollabInkLedger {
    /// 頁面 id → 已同步的線上筆畫 id。
    var known: [String: Set<String>] = [:]
    private var wireForLocal: [String: String] = [:]
    private var localForWire: [String: String] = [:]

    func wireId(for stroke: PKStroke) -> String {
        let local = CollabInk.strokeId(stroke)
        return wireForLocal[local] ?? local
    }

    func remember(wire: String, local: String) {
        wireForLocal[local] = wire
        localForWire[wire] = local
    }

    func localId(forWire wire: String) -> String { localForWire[wire] ?? wire }

    /// 這次協同期間加入、擦掉的筆畫（頁面 → 線上 id）。整份狀態只帶這些 —— 之前就有的兩邊都有。
    private(set) var sessionAdded: [String: Set<String>] = [:]
    private(set) var sessionRemoved: [String: Set<String>] = [:]

    func added(page: String, wires: some Sequence<String>) {
        let set = Set(wires)
        sessionAdded[page, default: []].formUnion(set)
        sessionRemoved[page]?.subtract(set)
    }

    func removed(page: String, wires: some Sequence<String>) {
        let set = Set(wires)
        sessionRemoved[page, default: []].formUnion(set)
        sessionAdded[page]?.subtract(set)
    }

    func reset() {
        known = [:]
        wireForLocal = [:]
        localForWire = [:]
        sessionAdded = [:]
        sessionRemoved = [:]
    }
}

/// 筆跡的逐筆增刪（設計 §4.3）。
///
/// 每一筆以**內容**算出穩定的 id：兩台各自算出的 id 相同，移除才對得到同一筆。
/// 用點的數值而不是 `dataRepresentation()` 的雜湊 —— 那份編碼在解碼後再編碼不保證逐位元相同。
enum CollabInk {

    static func strokeId(_ stroke: PKStroke) -> String {
        var text = "\(stroke.ink.inkType.rawValue)|"
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        stroke.ink.color.getRed(&r, green: &g, blue: &b, alpha: &a)
        text += String(format: "%.3f,%.3f,%.3f,%.3f|", r, g, b, a)
        let t = stroke.transform
        text += String(format: "%.3f,%.3f,%.3f,%.3f,%.3f,%.3f|", t.a, t.b, t.c, t.d, t.tx, t.ty)
        text += "\(stroke.path.count)|"
        for point in stroke.path {
            text += String(format: "%.2f,%.2f,%.3f,%.2f,%.2f;",
                           point.location.x, point.location.y, point.timeOffset,
                           point.size.width, point.force)
        }
        let digest = SHA256.hash(data: Data(text.utf8))
        return digest.prefix(12).map { String(format: "%02x", $0) }.joined()
    }

    static func ids(of drawing: PKDrawing) -> [String] { drawing.strokes.map(strokeId) }

    /// 套用加入：已經有的（同 id）不重複加。
    static func adding(_ strokes: [PKStroke], to drawing: PKDrawing) -> PKDrawing {
        let existing = Set(ids(of: drawing))
        let fresh = strokes.filter { !existing.contains(strokeId($0)) }
        guard !fresh.isEmpty else { return drawing }
        return PKDrawing(strokes: drawing.strokes + fresh)
    }

    /// 套用移除：只移除這幾個 id，別人同時畫的不受影響。
    static func removing(_ removed: Set<String>, from drawing: PKDrawing) -> PKDrawing {
        let kept = drawing.strokes.filter { !removed.contains(strokeId($0)) }
        return kept.count == drawing.strokes.count ? drawing : PKDrawing(strokes: kept)
    }
}

// MARK: - 文字內容的 CRDT

/// 每個文字方塊一份 `CollabText`（設計 §8.3）。參考型別：編輯器以 `@State` 持有、不訂閱。
final class CollabTextHub {
    private var replicas: [String: CollabText] = [:]

    /// 這個方塊的 CRDT；第一次用到時以 `base`（大家共同的那份文字）建立。
    func replica(for id: String, base: String, site: String) -> CollabText {
        if let existing = replicas[id] { return existing }
        let created = CollabText(base: base, site: site)
        replicas[id] = created
        return created
    }

    func existing(_ id: String) -> CollabText? { replicas[id] }

    /// 兩邊的基準對不上：以收到的全文為新基準重建（設計 §8.3 的退路）。
    func rebase(_ id: String, text: String, site: String) {
        replicas[id] = CollabText(base: text, site: site)
    }

    func reset() { replicas = [:] }
}

// MARK: - 整份狀態的往來

/// 一次「要整份狀態」的進度，以及已經有人回覆過的請求（設計 §7）。
/// 參考型別：編輯器以 `@State` 持有、不訂閱。與 Android 端 `AndroidCollabController` 的同名欄位相同。
final class CollabStateSync {
    /// 這台正在等的請求。
    private(set) var pendingRequest: String?
    var receivedParts: Set<Int> = []
    var snapshotKeys: Set<String> = []
    /// 上一次要狀態的時間：加入時要過一次，緊接著的「補發不完整」就不必再要。
    private(set) var lastRequest = Date.distantPast
    /// 已經有人回覆的請求：排在後面的人就不必再回（同一份狀態送好幾份只是浪費頻寬）。
    private var answered: [String] = []

    /// 整份狀態每段的大約上限（位元組）。一則訊息太大，中繼與手機的連線都吃不消。
    static let partBytes = 400_000
    /// 回覆時排名每多一位多等的秒數（排在前面的人若是舊版、不會回，後面的人照樣補上）。
    static let answerStagger = 0.7

    func begin() -> String {
        let req = UUID().uuidString
        pendingRequest = req
        receivedParts = []
        snapshotKeys = []
        lastRequest = Date()
        return req
    }

    func finish() { pendingRequest = nil }

    func remember(_ req: String) {
        guard !answered.contains(req) else { return }
        answered.append(req)
        if answered.count > 64 { answered.removeFirst() }
    }

    func wasAnswered(_ req: String) -> Bool { answered.contains(req) }

    func reset() {
        pendingRequest = nil
        receivedParts = []
        snapshotKeys = []
    }
}

// MARK: - 與檔案同步的協調

/// 正在即時協同的筆記：檔案同步**不匯入**它們（照常匯出、上傳）。
///
/// 匯入會用套件的合併結果換掉工作副本，編輯器接著重讀、把協同影子重設成匯入後的樣子 ——
/// 這台從此與房間分歧，而且影子以為那些差異「大家都有」，不會再送出。房間裡的內容本來就是即時的，
/// 檔案同步帶來的（不在房間裡的裝置寫的）等離開房間再匯入、合併一次。
enum CollabImportHold {
    private nonisolated static let lock = NSLock()
    private nonisolated(unsafe) static var held: Set<String> = []
    private nonisolated(unsafe) static var deferred: Set<String> = []

    nonisolated static func hold(_ notebookId: String) {
        _ = lock.withLock { held.insert(notebookId.lowercased()) }
    }

    /// 離開房間。回傳協同期間有沒有略過匯入（有的話呼叫端要補一次匯入）。
    @discardableResult
    nonisolated static func release(_ notebookId: String) -> Bool {
        let id = notebookId.lowercased()
        return lock.withLock {
            held.remove(id)
            return deferred.remove(id) != nil
        }
    }

    nonisolated static func isHeld(_ notebookId: String) -> Bool {
        lock.withLock { held.contains(notebookId.lowercased()) }
    }

    /// 同步要匯入這一本時問一下：在協同中就記下「欠一次匯入」並回 `true`（呼叫端略過匯入）。
    nonisolated static func deferIfHeld(_ notebookId: String) -> Bool {
        let id = notebookId.lowercased()
        return lock.withLock {
            guard held.contains(id) else { return false }
            deferred.insert(id)
            return true
        }
    }
}
