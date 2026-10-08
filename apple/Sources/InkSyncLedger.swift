//
//  InkSyncLedger.swift
//  Kairumo
//
//  PencilKit 筆畫的「穩定身分」與擦除同步。
//
//  # 問題
//
//  `PKStroke` 沒有 id。同步每次匯出都重建自己的筆畫檔、核心每次發新 id，所以
//  ① 別台對某一筆寫的墓碑（`Remove(id)`）隨下一次匯出落空，那一筆又冒出來；
//  ② 這台擦掉別台的筆畫，只能在本機隱藏（`ErasedInkLedger`），別台與原作者那台永遠看得到。
//
//  # 做法
//
//  - **身分由內容算出來**：`id = UUID(SHA-256(內容指紋 | 第幾筆 | 世代))`。同一條線每次匯出都得到同一個 id，
//    不必存任何 id；內容指紋沿用 `StrokeDelta.Identity`（座標量化到 0.01，經過核心來回也不變）。
//    「第幾筆」處理完全相同的兩筆；「世代」處理擦掉又復原 —— 已上傳的墓碑撤不掉，復原的那一筆要換新 id。
//  - **自己擦掉的筆畫不必寫墓碑**：自己的筆畫檔是整個被別台換掉的，新檔裡沒有那一筆就是沒有了；
//    只要新檔比舊檔**大**（核心 `pad_ink_to` 補位），別台就會下載。所以帳本不必留被擦掉的資料。
//  - **別台的筆畫**才需要墓碑（那一筆的 `Add` 在別台的檔案裡，改不了，只能追加 `Remove`）。墓碑只有 id，
//    而且**自動清理**：指向的 id 在套件裡已經沒有任何 `Add`（原作者重寫了檔案、我們也下載到了）就丟掉。
//  - **擦掉別台的筆畫**：墓碑要指向它的核心 id，而本機的 PKDrawing 沒有。匯出時到套件裡依內容指紋找出來。
//  - 偵測「擦了什麼」全在**匯出當下**用三份快照比對（上次匯出的自己 / 這次的自己 / 別台的基準線），
//    不需要在編輯器的每個入口掛鉤。
//

import CryptoKit
import Foundation
import PencilKit

enum PKStrokeId {
    /// 一筆 PencilKit 筆畫在套件裡的身分（小寫 UUID 字串）。
    static func make(key: String, n: Int, gen: Int) -> String {
        let digest = SHA256.hash(data: Data("kairumo.pk|\(key)|\(n)|\(gen)".utf8))
        var b = Array(digest.prefix(16))
        b[6] = (b[6] & 0x0F) | 0x50   // version 5
        b[8] = (b[8] & 0x3F) | 0x80   // variant
        let uuid = UUID(uuid: (b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7],
                               b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]))
        return uuid.uuidString.lowercased()
    }
}

/// 一頁 PencilKit 筆畫的匯出計畫。
struct PKInkPlan {
    /// 這一頁自己的筆畫的套件身分，與 `ownNow.strokes` 一一對應。
    var ids: [String]
    /// 套用計畫之後別台筆畫的墓碑 id（已清掉不必要的）。
    var foreignTombstones: [String]
    /// 這一頁別台筆畫被擦掉的（要從別台基準線拿掉）。
    var erasedForeign: [PKStroke]
    /// 自己擦掉了筆畫：這一頁的筆畫檔要**變大**才會被傳出去。
    var grow: Bool
}

enum PKInkSync {

    /// 算這一頁的計畫（純函式；寫檔由呼叫端在匯出成功之後做）。
    ///
    /// - Parameters:
    ///   - ownNow: 這一頁現在自己的筆畫（工作副本 − 別台基準線）。
    ///   - prevOwn: 上一次匯出寫出的自己的筆畫；`nil` = 從來沒用新方式匯出過（升級前），不推論任何擦除。
    ///   - current: 工作副本整份。
    ///   - others: 別台的基準線（上次匯入時 合併 − 自己）。
    ///   - addedIds: 套件裡這一頁所有出現過 `Add` 的筆畫 id；`nil` = 讀不到，不清理。
    ///   - resolveForeign: 在套件裡依內容指紋找別台筆畫的核心 id：(指紋, 需要幾個, 要排除的 id) → id 們。
    static func plan(
        ledger: ProInkLedger,
        ownNow: PKDrawing,
        prevOwn: PKDrawing?,
        current: PKDrawing,
        others: PKDrawing,
        addedIds: Set<String>? = nil,
        resolveForeign: (_ key: String, _ count: Int, _ excluding: Set<String>) -> [String]
    ) -> PKInkPlan {
        // ① 自己擦掉了東西嗎：上次匯出有、現在沒有。
        let grow = prevOwn.map { !StrokeDelta.removed(in: ownNow, since: $0).isEmpty } ?? false

        // ② 現在自己的筆畫的身分。
        var seen: [String: Int] = [:]
        var ids: [String] = []
        ids.reserveCapacity(ownNow.strokes.count)
        for stroke in ownNow.strokes {
            let key = StrokeDelta.Identity(stroke).key
            let n = seen[key, default: 0]
            seen[key] = n + 1
            ids.append(PKStrokeId.make(key: key, n: n, gen: 0))
        }

        // ③ 清掉不必要的墓碑：它指向的 id 在套件裡已經沒有任何 Add 了，沒有東西可擦。
        var tombstones = ledger.foreignTombstones
        if let addedIds { tombstones = tombstones.filter { addedIds.contains($0) } }

        // ④ 這台擦掉的別台筆畫：基準線有、現在的工作副本沒有。
        let erasedForeign = StrokeDelta.removed(in: current, since: others)
        if !erasedForeign.isEmpty {
            var byKey: [String: Int] = [:]
            for stroke in erasedForeign { byKey[StrokeDelta.Identity(stroke).key, default: 0] += 1 }
            let exclude = Set(ids).union(tombstones)
            for (key, count) in byKey {
                for id in resolveForeign(key, count, exclude) where !tombstones.contains(id) {
                    tombstones.append(id)
                }
            }
        }
        return PKInkPlan(ids: ids, foreignTombstones: tombstones, erasedForeign: erasedForeign, grow: grow)
    }

}

/// 匯出當下的套件內容（只讀）：依內容指紋找別台筆畫的核心 id。每頁最多讀一次。
final class PackageInkResolver {
    private let session: PadnoteSession?
    private let pageIds: [String]
    private var cache: [Int: [FullStroke]] = [:]

    init(package: URL, deviceId: UInt32) {
        let session = FileManager.default.fileExists(atPath: package.path)
            ? (try? PadnoteSession.openExisting(path: package.path, deviceId: deviceId)) : nil
        self.session = session
        var ids: [String] = []
        if let session, let first = try? session.firstPageId() {
            ids.append(first)
            for index in 1 ..< max(Int(session.pageCount()), 1) {
                if let id = try? session.pageIdAt(index: UInt32(index)) { ids.append(id) }
            }
        }
        self.pageIds = ids
    }

    private func details(page: Int) -> [FullStroke] {
        if let cached = cache[page] { return cached }
        var out: [FullStroke] = []
        if let session, page < pageIds.count {
            out = (try? session.visibleStrokeDetails(pageId: pageIds[page])) ?? []
        }
        cache[page] = out
        return out
    }

    /// PencilKit 筆畫：內容指紋 == `key` 的、可見的核心筆畫 id（排除 `excluding`），最多 `count` 個。
    func pencilKitIds(page: Int, key: String, count: Int, excluding: Set<String>) -> [String] {
        var out: [String] = []
        for full in details(page: page) where !brushIsCustom(tool: full.tool) {
            let id = full.id.lowercased()
            guard !excluding.contains(id) else { continue }
            if StrokeDelta.Identity(InkInterop.stroke(from: full)).key == key {
                out.append(id)
                if out.count >= count { break }
            }
        }
        return out
    }

    /// 專業筆畫：核心 id 是否還在、以及依內容指紋找到的 id。
    func proIds(page: Int, contentKey: String, excluding: Set<String>) -> [String] {
        details(page: page).compactMap { full -> String? in
            guard brushIsCustom(tool: full.tool), let pro = ProStroke(from: full) else { return nil }
            let id = full.id.lowercased()
            return pro.contentKey == contentKey && !excluding.contains(id) ? id : nil
        }
    }

    /// 套件裡這一頁所有出現過 `Add` 的筆畫 id（含已被擦掉的）。`nil` = 讀不到。
    func addedIds(page: Int) -> Set<String>? {
        guard let session, page < pageIds.count,
              let ids = try? session.addedStrokeIds(pageId: pageIds[page])
        else { return nil }
        return Set(ids.map { $0.lowercased() })
    }

    func hasStroke(page: Int, id: String) -> Bool {
        details(page: page).contains { $0.id.lowercased() == id }
    }
}

enum PKInkSnapshotStore {
    private nonisolated static func url(_ directory: URL, _ notebookId: String, _ page: Int) -> URL {
        directory.appending(path: "\(notebookId)_p\(page).own-exported.drawing")
    }

    /// 上一次匯出寫出的、自己的 PencilKit 筆畫。`nil` = 沒有（升級前、或這一頁從來沒匯出過）。
    nonisolated static func load(in directory: URL, notebookId: String, page: Int) -> PKDrawing? {
        guard let data = try? Data(contentsOf: url(directory, notebookId, page)) else { return nil }
        return try? PKDrawing(data: data)
    }

    nonisolated static func save(_ drawing: PKDrawing, in directory: URL, notebookId: String, page: Int) {
        try? drawing.dataRepresentation().write(to: url(directory, notebookId, page), options: .atomic)
    }
}

/// 同步帳本的清理：自動規則 + 使用者自己動手的選項。
///
/// # 自動規則（使用者什麼都不用做）
/// 1. **自己的筆畫的退休記錄用完即丟**：匯出成功就刪（見 `exportOne`）。舊版把被擦掉的筆畫整筆資料永遠留著，
///    啟動時由 `compact` 一次清掉。
/// 2. **別台筆畫的墓碑只留到沒用為止**：匯出時發現它指向的 id 在套件裡已經沒有任何 `Add`
///    （原作者重寫了檔案、我們也下載到了），就丟掉。
/// 3. 墓碑只存 id（幾十個位元組），不存筆畫資料。
///
/// # 手動選項（診斷面板 → 儲存空間）
/// - 「整理同步記錄」：現在就跑一次 1。安全，不會改變任何畫面。
/// - 「清除擦除記錄」：最差情況的出路。**別台已經被這台擦掉的筆畫可能重新出現**（墓碑沒了），要使用者確認。
enum InkLedgerJanitor {
    struct Report: Sendable {
        var files = 0
        var bytesFreed: Int64 = 0
    }

    private nonisolated static func ledgerFiles(in directory: URL) -> [(url: URL, notebookId: String, page: Int)] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return names.compactMap { name in
            guard name.hasSuffix(".proink-ledger.json"),
                  let range = name.range(of: "_p", options: .backwards),
                  let page = Int(name[range.upperBound...].prefix { $0.isNumber })
            else { return nil }
            return (directory.appending(path: name), String(name[..<range.lowerBound]), page)
        }
    }

    /// `URL.resourceValues` 會快取同一個 URL 物件的結果，量「清理前後」會量到一樣的數字。
    private nonisolated static func size(_ url: URL) -> Int64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes?[.size] as? NSNumber)?.int64Value ?? 0
    }

    /// 同步記錄佔的空間：帳本、被擦掉的別台筆畫指紋、被擦掉的 PencilKit 筆畫指紋。
    nonisolated static func usage(drawingsDirectory: URL, baselineDirectory: URL) -> Int64 {
        let fm = FileManager.default
        func total(_ dir: URL, suffixes: [String]) -> Int64 {
            ((try? fm.contentsOfDirectory(atPath: dir.path)) ?? [])
                .filter { name in suffixes.contains { name.hasSuffix($0) } }
                .reduce(0) { $0 + size(dir.appending(path: $1)) }
        }
        return total(drawingsDirectory, suffixes: [".proink-ledger.json", ".proink-suppressed.json"])
            + total(baselineDirectory, suffixes: [".erased-ink.json"])
    }

    /// 丟掉舊版留下的資料：自己的筆畫的退休記錄（連整筆資料）、PencilKit 的退休筆畫與世代表。
    @discardableResult
    nonisolated static func compact(drawingsDirectory: URL) -> Report {
        var report = Report()
        for file in ledgerFiles(in: drawingsDirectory) {
            let before = size(file.url)
            ProInkStore.updateLedger(in: drawingsDirectory, notebookId: file.notebookId, page: file.page) { ledger in
                ledger.retired.removeAll { $0.stroke != nil && $0.exported }
                ledger.pkRetiredOwn = []
                ledger.pkGen = [:]
            }
            let after = size(file.url)
            if after < before {
                report.files += 1
                report.bytesFreed += before - after
            }
        }
        return report
    }

    /// 最差情況的出路：清掉所有「這台擦掉了別台的筆畫」的記錄。別台的筆畫之後可能重新出現。
    @discardableResult
    nonisolated static func clearEraseHistory(drawingsDirectory: URL, baselineDirectory: URL) -> Report {
        var report = Report()
        let fm = FileManager.default
        for file in ledgerFiles(in: drawingsDirectory) {
            let before = size(file.url)
            ProInkStore.updateLedger(in: drawingsDirectory, notebookId: file.notebookId, page: file.page) { ledger in
                ledger.retired.removeAll { $0.stroke == nil }
                ledger.foreignTombstones = []
                ledger.pkRetiredOwn = []
                ledger.pkGen = [:]
            }
            report.bytesFreed += max(0, before - size(file.url))
            report.files += 1
        }
        for (dir, suffix) in [(drawingsDirectory, ".proink-suppressed.json"), (baselineDirectory, ".erased-ink.json")] {
            for name in (try? fm.contentsOfDirectory(atPath: dir.path)) ?? [] where name.hasSuffix(suffix) {
                let url = dir.appending(path: name)
                let bytes = size(url)
                if (try? fm.removeItem(at: url)) != nil {
                    report.bytesFreed += bytes
                    report.files += 1
                }
            }
        }
        return report
    }
}
