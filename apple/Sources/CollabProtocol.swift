//
//  CollabProtocol.swift
//  Kairumo
//
//  即時協同協定 3 的共用積木（設計見 `docs/plans/realtime-collaboration.md` §8）。
//
//  這裡的每一個演算法 Android 端都有**逐行對應**的實作（`collab/CollabProtocol.kt`），
//  兩邊用同一組測試向量驗證 —— 算法有一點點不同，兩台就會算出不同的字序、不同的頁序，
//  而那種不一致不會報錯，只會讓兩個人看到不同的筆記。
//

import CryptoKit
import Foundation
import PencilKit

// MARK: - 文字 CRDT（RGA）

/// 一個文字方塊的字元層級 CRDT（設計 §8.3）。
///
/// 每個字（UTF-16 碼元）有全域唯一的 id `"<n>@<site>"`；插入是「插在某個 id 之後」，
/// 刪除只做墓碑。兩個人同時在同一個方塊打字，兩邊的字都會留下、而且順序一致。
final class CollabText {

    struct Op: Equatable {
        enum Kind: String { case insert = "i", delete = "d" }
        let kind: Kind
        let id: String
        /// 插入：插在這個 id 之後；空字串 = 插在最前面。
        let after: String
        /// 插入的字（一個 UTF-16 碼元）。
        let unit: UInt16

        static func insert(id: String, after: String, unit: UInt16) -> Op {
            Op(kind: .insert, id: id, after: after, unit: unit)
        }

        static func delete(id: String) -> Op {
            Op(kind: .delete, id: id, after: "", unit: 0)
        }

        var json: [String: Any] {
            switch kind {
            case .insert:
                return ["o": "i", "id": id, "after": after, "c": String(utf16CodeUnits: [unit], count: 1)]
            case .delete:
                return ["o": "d", "id": id]
            }
        }

        init?(json: [String: Any]) {
            guard let o = json["o"] as? String, let id = json["id"] as? String else { return nil }
            if o == "i" {
                guard let c = json["c"] as? String, let unit = c.utf16.first else { return nil }
                self.init(kind: .insert, id: id, after: (json["after"] as? String) ?? "", unit: unit)
            } else if o == "d" {
                self.init(kind: .delete, id: id, after: "", unit: 0)
            } else {
                return nil
            }
        }

        private init(kind: Kind, id: String, after: String, unit: UInt16) {
            self.kind = kind
            self.id = id
            self.after = after
            self.unit = unit
        }
    }

    private struct Element {
        let id: String
        let unit: UInt16
        var deleted: Bool
    }

    let site: String
    /// 基準文字的雜湊（設計 §8.3）。兩邊基準不同時不能逐字合併。
    let baseHash: String
    private var elements: [Element]
    private var positions: [String: Int] = [:]
    private var counter: Int = 0
    /// 還找不到錨點的操作（漏收或亂序）。之後每套用一個操作都會重試。
    private var pending: [Op] = []

    init(base: String, site: String) {
        self.site = site
        self.baseHash = Self.hash(base)
        elements = Array(base.utf16).enumerated().map { Element(id: "0@#\($0.offset)", unit: $0.element, deleted: false) }
        reindex()
    }

    static func hash(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    /// 目前看得到的文字。
    var text: String {
        let units = elements.filter { !$0.deleted }.map(\.unit)
        return String(utf16CodeUnits: units, count: units.count)
    }

    var hasPending: Bool { !pending.isEmpty }

    // MARK: 本機修改

    /// 本機的文字從 `old` 變成 `new`：產生對應的操作（並已套用到自己身上）。
    ///
    /// 以共同開頭與結尾找出變動的那一段：中間被刪掉的字逐一墓碑、新打的字逐一插入，
    /// 新字一個接一個串在前一個之後（整段一次插入，不會被別人同時打的字插進中間）。
    func localEdit(from old: String, to new: String) -> [Op] {
        let a = Array(old.utf16), b = Array(new.utf16)
        var prefix = 0
        while prefix < a.count, prefix < b.count, a[prefix] == b[prefix] { prefix += 1 }
        var suffix = 0
        while suffix < a.count - prefix, suffix < b.count - prefix,
              a[a.count - 1 - suffix] == b[b.count - 1 - suffix] { suffix += 1 }

        let visible = visibleIds()
        // 本機的文字應該等於 CRDT 的文字；不等時（例如還有未解的遠端操作）以可見範圍夾住。
        let deleteRange = prefix..<max(prefix, min(visible.count, a.count - suffix))
        var ops: [Op] = []
        for index in deleteRange { ops.append(.delete(id: visible[index])) }
        var anchor = prefix > 0 && prefix - 1 < visible.count ? visible[prefix - 1] : ""
        for unit in b[prefix..<(b.count - suffix)] {
            counter += 1
            let id = "\(counter)@\(site)"
            ops.append(.insert(id: id, after: anchor, unit: unit))
            anchor = id
        }
        for op in ops { _ = apply(op) }
        return ops
    }

    // MARK: 遠端修改

    /// 套用一個操作。錨點還沒出現的先暫存，之後自動補上。回傳有沒有改變文字。
    @discardableResult
    func apply(_ op: Op) -> Bool {
        guard applyOne(op) else {
            if !pending.contains(op) { pending.append(op) }
            return false
        }
        // 錨點出現了，暫存的可能可以套了。
        var progressed = true
        while progressed {
            progressed = false
            for (index, waiting) in pending.enumerated() where applyOne(waiting) {
                pending.remove(at: index)
                progressed = true
                break
            }
        }
        return true
    }

    private func applyOne(_ op: Op) -> Bool {
        switch op.kind {
        case .delete:
            guard let index = positions[op.id] else { return false }
            elements[index].deleted = true
            return true
        case .insert:
            if positions[op.id] != nil { return true } // 重複收到：冪等
            var index: Int
            if op.after.isEmpty {
                index = 0
            } else {
                guard let anchor = positions[op.after] else { return false }
                index = anchor + 1
            }
            // RGA：同一個錨點後面已經有比較新的插入（id 較大）時，越過它們 ——
            // 它們的後代 id 一定更大，所以一直越過到第一個比自己小的為止。
            while index < elements.count, Self.precedes(elements[index].id, op.id) { index += 1 }
            elements.insert(Element(id: op.id, unit: op.unit, deleted: false), at: index)
            if let n = Self.counter(of: op.id) { counter = max(counter, n) }
            reindex()
            return true
        }
    }

    /// `a` 排在 `b` 前面（較新）：先比計數，相同再比 site。基準字的計數是 0，永遠不會越過。
    static func precedes(_ a: String, _ b: String) -> Bool {
        let ca = counter(of: a) ?? 0, cb = counter(of: b) ?? 0
        if ca != cb { return ca > cb }
        return site(of: a) > site(of: b)
    }

    static func counter(of id: String) -> Int? {
        guard let at = id.firstIndex(of: "@") else { return nil }
        return Int(id[id.startIndex..<at])
    }

    static func site(of id: String) -> String {
        guard let at = id.firstIndex(of: "@") else { return "" }
        return String(id[id.index(after: at)...])
    }

    private func visibleIds() -> [String] { elements.filter { !$0.deleted }.map(\.id) }

    /// 目前第 `index` 個看得見的字的 id（格式錨點用，設計 §8.3）。
    func id(at index: Int) -> String? {
        let ids = visibleIds()
        return index >= 0 && index < ids.count ? ids[index] : nil
    }

    /// 某個 id 現在是第幾個看得見的字。那個字被刪了：`forward` 取它後面第一個看得見的字，
    /// 否則取前面那一個。不認得這個 id（操作還沒到）回 nil。與 Android 端 `visibleIndexOf` 相同。
    func visibleIndex(of id: String, forward: Bool) -> Int? {
        guard let position = positions[id] else { return nil }
        let before = elements[..<position].filter { !$0.deleted }.count
        if !elements[position].deleted { return before }
        if forward {
            return elements[(position + 1)...].contains { !$0.deleted } ? before : nil
        }
        return before > 0 ? before - 1 : nil
    }

    private func reindex() {
        positions = [:]
        for (index, element) in elements.enumerated() { positions[element.id] = index }
    }
}

// MARK: - 分數索引（頁面順序）

/// 字典序排序鍵（設計 §8.4）。兩個鍵之間永遠插得進新的鍵，所以搬頁不必改動其他頁。
///
/// 演算法與 rocicorp/fractional-indexing 的 `midpoint` 相同（只用小數部分）。
/// 逐字格式的區段以「字的 id」標出頭尾，而不是位置（設計 §8.3）。
///
/// 位置會隨同時打字而偏移（對方在前面插了三個字，送來的「第 10–15 字粗體」就粗錯了字）；
/// id 不會。送出時把每段的頭尾換成 id，收到後以自己的 CRDT 換回現在的位置。與 Android 端 `CollabRunAnchors` 相同。
enum CollabRunAnchors {
    /// 每段 `(start, length)` → `[第一個字的 id, 最後一個字的 id]`；找不到的是 `["", ""]`。
    static func anchors(_ runs: [(start: Int, length: Int)], in text: CollabText) -> [[String]] {
        runs.map { run in
            guard run.length > 0, let first = text.id(at: run.start),
                  let last = text.id(at: run.start + run.length - 1) else { return ["", ""] }
            return [first, last]
        }
    }

    /// 錨點 → 現在的 `(start, length)`。認不得、或整段的字都被刪了的回 nil（沿用送來的位置）。
    static func resolve(_ anchors: [[String]], in text: CollabText) -> [(start: Int, length: Int)?] {
        anchors.map { pair in
            guard pair.count == 2, !pair[0].isEmpty, !pair[1].isEmpty,
                  let start = text.visibleIndex(of: pair[0], forward: true),
                  let end = text.visibleIndex(of: pair[1], forward: false), end >= start else { return nil }
            return (start, end - start + 1)
        }
    }
}

enum FractionalIndex {
    static let digits = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")

    /// `a` 與 `b` 之間的鍵（`a` 空字串 = 最前面、`b` nil = 最後面）。要求 `a < b`。
    static func between(_ a: String, _ b: String?) -> String {
        midpoint(Array(a), b.map(Array.init))
    }

    private static func midpoint(_ a: [Character], _ b: [Character]?) -> String {
        if let b {
            var n = 0
            while n < b.count, (n < a.count ? a[n] : "0") == b[n] { n += 1 }
            if n > 0 {
                return String(b[0..<n]) + midpoint(Array(a.dropFirst(min(n, a.count))), Array(b.dropFirst(n)))
            }
        }
        let digitA = a.first.flatMap { digits.firstIndex(of: $0) } ?? 0
        let digitB = b.flatMap { $0.first }.flatMap { digits.firstIndex(of: $0) } ?? digits.count
        if digitB - digitA > 1 {
            return String(digits[(digitA + digitB + 1) / 2])
        }
        if let b, b.count > 1 { return String(b[0]) }
        return String(digits[digitA]) + midpoint(Array(a.dropFirst()), nil)
    }

    /// `count` 頁的初始排序鍵：兩台以同樣的頁序開始時算出同一組鍵。
    static func initialKeys(_ count: Int) -> [String] {
        var keys: [String] = []
        var last = ""
        for _ in 0..<count {
            last = between(last, nil)
            keys.append(last)
        }
        return keys
    }
}

// MARK: - 巢狀 JSON 攤平

/// 外觀 JSON 攤平成「點號路徑 → 值」，讓欄位層級的 LWW 也能合併巢狀的樣式
/// （例如圖片的 `{image: {width: …}}` → `a.image.width`）。陣列是葉子，不往下拆。
enum CollabJSON {

    static func flatten(_ json: [String: Any], prefix: String) -> [String: Any] {
        var out: [String: Any] = [:]
        for (key, value) in json {
            let path = prefix + key
            if let nested = value as? [String: Any], !nested.isEmpty {
                for (k, v) in flatten(nested, prefix: path + ".") { out[k] = v }
            } else {
                out[path] = value
            }
        }
        return out
    }

    static func unflatten(_ fields: [String: Any], prefix: String) -> [String: Any] {
        var root: [String: Any] = [:]
        for (key, value) in fields where key.hasPrefix(prefix) {
            let parts = key.dropFirst(prefix.count).split(separator: ".").map(String.init)
            guard !parts.isEmpty else { continue }
            root = insert(value, at: parts[...], into: root)
        }
        return root
    }

    private static func insert(_ value: Any, at path: ArraySlice<String>, into dict: [String: Any]) -> [String: Any] {
        var dict = dict
        guard let head = path.first else { return dict }
        if path.count == 1 {
            dict[head] = value
        } else {
            dict[head] = insert(value, at: path.dropFirst(), into: (dict[head] as? [String: Any]) ?? [:])
        }
        return dict
    }

    static func object(_ text: String) -> [String: Any] {
        guard let data = text.data(using: .utf8),
              let map = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return [:] }
        return map
    }

    static func string(_ object: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let text = String(data: data, encoding: .utf8) else { return "{}" }
        return text
    }

    static func encodable<T: Encodable>(_ value: T) -> [String: Any] {
        guard let data = try? JSONEncoder().encode(value),
              let map = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return [:] }
        return map
    }

    static func decodable<T: Decodable>(_ type: T.Type, _ map: [String: Any]) -> T? {
        guard let data = try? JSONSerialization.data(withJSONObject: map) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

// MARK: - 筆畫的線上格式

/// 筆畫以核心的格式傳（設計 §8.2）：工具、RGBA、寬度、每點 7 個數字攤平。
enum CollabStroke {

    /// 收到的筆畫在套件裡要用的 id：送出者附的核心 id（`cid`），沒有的話線上 id 本身是 UUID 就用它
    /// （Android 的線上 id 就是核心 id）。都不是（舊版 Apple 的內容雜湊）回 `nil`，照內容算。
    static func coreId(_ json: [String: Any]) -> String? {
        CollabInkIds.usable(json["cid"] as? String) ?? CollabInkIds.usable(json["id"] as? String)
    }

    /// - Parameter coreId: 這一筆在送出者套件裡的 id。收到的人照它寫進自己的套件（設計 §8.1）。
    static func encode(_ stroke: PKStroke, id: String, coreId: String? = nil) -> [String: Any] {
        let draft = InkInterop.draft(from: stroke)
        var points: [Double] = []
        points.reserveCapacity(draft.points.count * 7)
        for p in draft.points {
            points += [Double(p.x), Double(p.y), Double(p.pressure), Double(p.tilt),
                       Double(p.azimuth), Double(p.dtUs), Double(p.roll)]
        }
        var json: [String: Any] = [
            "id": id,
            "tool": toolName(draft.tool),
            "rgba": "#" + draft.colorRgba.map { String(format: "%02X", $0) }.joined(),
            "width": Double(draft.baseWidth),
            "points": points
        ]
        if let coreId { json["cid"] = coreId }
        return json
    }

    static func decode(_ json: [String: Any]) -> (id: String, stroke: PKStroke)? {
        guard let id = json["id"] as? String,
              let toolRaw = json["tool"] as? String, let tool = tool(named: toolRaw),
              let rgbaHex = json["rgba"] as? String,
              let width = (json["width"] as? NSNumber)?.floatValue,
              let flat = json["points"] as? [NSNumber], flat.count >= 7 else { return nil }
        var points: [StrokePoint] = []
        var i = 0
        while i + 6 < flat.count {
            points.append(StrokePoint(
                x: flat[i].floatValue, y: flat[i + 1].floatValue, pressure: flat[i + 2].floatValue,
                tilt: flat[i + 3].floatValue, azimuth: flat[i + 4].floatValue,
                dtUs: UInt32(max(0, flat[i + 5].doubleValue)), roll: flat[i + 6].floatValue))
            i += 7
        }
        let full = FullStroke(
            id: id, startedAtUs: 0, tool: tool, colorRgba: rgba(rgbaHex), baseWidth: width,
            points: points, layer: 0, lineType: 0)
        return (id, InkInterop.stroke(from: full))
    }

    private static func rgba(_ hex: String) -> Data {
        let clean = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var bytes: [UInt8] = []
        var index = clean.startIndex
        while index < clean.endIndex, let next = clean.index(index, offsetBy: 2, limitedBy: clean.endIndex) {
            bytes.append(UInt8(clean[index..<next], radix: 16) ?? 0)
            index = next
        }
        while bytes.count < 4 { bytes.append(255) }
        return Data(bytes.prefix(4))
    }

    /// 工具的線上名稱：Android 端 `ToolKind.name.lowercase()`（`fountain_pen`…），兩邊同一張表。
    static let toolNames: [(ToolKind, String)] = [
        (.fountainPen, "fountain_pen"), (.ballPoint, "ball_point"), (.highlighter, "highlighter"),
        (.pencil, "pencil"), (.brush, "brush"), (.marker, "marker"), (.watercolor, "watercolor"),
        (.fineliner, "fineliner"), (.charcoal, "charcoal"), (.crayon, "crayon"),
        (.airbrush, "airbrush"), (.oilPaint, "oil_paint"), (.calligraphy, "calligraphy"),
    ]

    static func toolName(_ tool: ToolKind) -> String {
        toolNames.first { $0.0 == tool }?.1 ?? "fountain_pen"
    }

    static func tool(named name: String) -> ToolKind? {
        toolNames.first { $0.1 == name.lowercased() }?.0
    }
}
