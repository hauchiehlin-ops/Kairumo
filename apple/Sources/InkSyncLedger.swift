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
//  - **擦除是追加的墓碑**，用 `ProInkLedger` 記著並**永遠留著**（每次匯出都整個重寫自己的筆畫檔，
//    少寫一筆墓碑，別台下載到新檔就讓那一筆復活）。自己的筆畫連 `Add` 一起寫，檔案才不會變小。
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

    /// `pkGen` 的鍵。
    static func genKey(_ key: String, _ n: Int) -> String { "\(key)#\(n)" }
}

/// 一頁 PencilKit 筆畫的匯出計畫。
struct PKInkPlan {
    /// 這一頁自己的筆畫的套件身分，與 `ownNow.strokes` 一一對應。
    var ids: [String]
    /// 套用計畫之後的帳本欄位。
    var pkRetiredOwn: [ProInkLedger.PKRetired]
    var foreignTombstones: [String]
    var pkGen: [String: Int]
    /// 這一頁別台筆畫被擦掉的（要從別台基準線拿掉）。
    var erasedForeign: [PKStroke]
}

enum PKInkSync {

    /// 算這一頁的計畫（純函式；寫檔由呼叫端在匯出成功之後做）。
    ///
    /// - Parameters:
    ///   - ownNow: 這一頁現在自己的筆畫（工作副本 − 別台基準線）。
    ///   - prevOwn: 上一次匯出寫出的自己的筆畫；`nil` = 從來沒用新方式匯出過（升級前），不推論任何擦除。
    ///   - current: 工作副本整份。
    ///   - others: 別台的基準線（上次匯入時 合併 − 自己）。
    ///   - resolveForeign: 在套件裡依內容指紋找別台筆畫的核心 id：(指紋, 需要幾個, 要排除的 id) → id 們。
    static func plan(
        ledger: ProInkLedger,
        ownNow: PKDrawing,
        prevOwn: PKDrawing?,
        current: PKDrawing,
        others: PKDrawing,
        resolveForeign: (_ key: String, _ count: Int, _ excluding: Set<String>) -> [String]
    ) -> PKInkPlan {
        var gen = ledger.pkGen
        var retired = ledger.pkRetiredOwn

        // ① 自己擦掉的：上次匯出有、現在沒有。同一個指紋少了幾筆，就是「第幾筆」從最後面算起的那幾個。
        if let prevOwn {
            let gone = StrokeDelta.removed(in: ownNow, since: prevOwn)
            var byKey: [String: [PKStroke]] = [:]
            for stroke in gone { byKey[StrokeDelta.Identity(stroke).key, default: []].append(stroke) }
            let prevCounts = counts(prevOwn), nowCounts = counts(ownNow)
            for (key, strokes) in byKey {
                let before = prevCounts[key] ?? strokes.count
                let after = nowCounts[key] ?? 0
                guard before > after else { continue }
                for (offset, stroke) in strokes.enumerated() where after + offset < before {
                    let n = after + offset
                    let g = gen[PKStrokeId.genKey(key, n)] ?? 0
                    let id = PKStrokeId.make(key: key, n: n, gen: g)
                    if !retired.contains(where: { $0.id == id }) {
                        retired.append(.init(id: id, drawing: PKDrawing(strokes: [stroke]).dataRepresentation()))
                    }
                    gen[PKStrokeId.genKey(key, n)] = g + 1
                }
            }
        }

        // ② 現在自己的筆畫的身分。
        var seen: [String: Int] = [:]
        var ids: [String] = []
        ids.reserveCapacity(ownNow.strokes.count)
        for stroke in ownNow.strokes {
            let key = StrokeDelta.Identity(stroke).key
            let n = seen[key, default: 0]
            seen[key] = n + 1
            ids.append(PKStrokeId.make(key: key, n: n, gen: gen[PKStrokeId.genKey(key, n)] ?? 0))
        }

        // ③ 這台擦掉的別台筆畫：基準線有、現在的工作副本沒有。
        var tombstones = ledger.foreignTombstones
        let erasedForeign = StrokeDelta.removed(in: current, since: others)
        if !erasedForeign.isEmpty {
            var byKey: [String: Int] = [:]
            for stroke in erasedForeign { byKey[StrokeDelta.Identity(stroke).key, default: 0] += 1 }
            let exclude = Set(ids).union(retired.map(\.id)).union(tombstones)
            for (key, count) in byKey {
                for id in resolveForeign(key, count, exclude) where !tombstones.contains(id) {
                    tombstones.append(id)
                }
            }
        }
        return PKInkPlan(
            ids: ids, pkRetiredOwn: retired, foreignTombstones: tombstones, pkGen: gen,
            erasedForeign: erasedForeign)
    }

    private static func counts(_ drawing: PKDrawing) -> [String: Int] {
        var out: [String: Int] = [:]
        for stroke in drawing.strokes { out[StrokeDelta.Identity(stroke).key, default: 0] += 1 }
        return out
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
