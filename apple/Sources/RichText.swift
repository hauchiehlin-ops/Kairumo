//
//  RichText.swift
//  Kairumo
//
//  文字方塊的逐字格式（`format-spec.md` §6.2 的 `runs`）。
//
//  # 為什麼需要它
//
//  方塊層級的粗體、字級、顏色一次只能改整個方塊 —— 使用者在 Word 裡習慣的是
//  「選幾個字、按粗體」，在這裡做不到。逐字格式以「區段」（run）存放：每一段
//  只記**與方塊預設不同**的屬性，沒寫的屬性一律沿用方塊層級的值。
//
//  # 位置單位是 UTF-16
//
//  `start` / `length` 以 UTF-16 碼元計。Apple 的 `NSRange` 與 Android 的
//  Kotlin 字串索引都是這個單位 —— 用字元（grapheme）數的話，表情符號與某些
//  泰文字會讓兩個平台算出不同的位置，格式就套錯字。
//

import Foundation
import SwiftUI
import UIKit

// MARK: - 模型

/// 一段文字的格式覆寫。`nil` = 沿用方塊層級的值。
public struct TextCharStyle: Codable, Hashable {
    public var bold: Bool?
    public var italic: Bool?
    public var underline: Bool?
    public var strikethrough: Bool?
    public var fontSize: CGFloat?
    public var fontFamily: String?
    public var textColorHex: String?
    /// 文字醒目提示（字的背景色）。方塊層級沒有這一項，所以沒有「沿用」的問題。
    public var highlightHex: String?

    public init(
        bold: Bool? = nil, italic: Bool? = nil, underline: Bool? = nil, strikethrough: Bool? = nil,
        fontSize: CGFloat? = nil, fontFamily: String? = nil, textColorHex: String? = nil,
        highlightHex: String? = nil
    ) {
        self.bold = bold
        self.italic = italic
        self.underline = underline
        self.strikethrough = strikethrough
        self.fontSize = fontSize
        self.fontFamily = fontFamily
        self.textColorHex = textColorHex
        self.highlightHex = highlightHex
    }

    public var isEmpty: Bool { self == TextCharStyle() }

    /// 把 `other` 有寫的欄位疊上來。
    func overlaid(with other: TextCharStyle) -> TextCharStyle {
        var out = self
        if let v = other.bold { out.bold = v }
        if let v = other.italic { out.italic = v }
        if let v = other.underline { out.underline = v }
        if let v = other.strikethrough { out.strikethrough = v }
        if let v = other.fontSize { out.fontSize = v }
        if let v = other.fontFamily { out.fontFamily = v }
        if let v = other.textColorHex { out.textColorHex = v }
        if let v = other.highlightHex { out.highlightHex = v }
        return out
    }
}

/// 一段有覆寫格式的文字。鍵名與 Android 的 `TextStyleRun` 相同（扁平，不巢狀）。
public struct TextStyleRun: Codable, Hashable {
    public var start: Int
    public var length: Int
    public var style: TextCharStyle

    public init(start: Int, length: Int, style: TextCharStyle) {
        self.start = start
        self.length = length
        self.style = style
    }

    private enum CodingKeys: String, CodingKey {
        case start, length, bold, italic, underline, strikethrough, fontSize, fontFamily, textColorHex, highlightHex
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        start = try c.decode(Int.self, forKey: .start)
        length = try c.decode(Int.self, forKey: .length)
        style = TextCharStyle(
            bold: try c.decodeIfPresent(Bool.self, forKey: .bold),
            italic: try c.decodeIfPresent(Bool.self, forKey: .italic),
            underline: try c.decodeIfPresent(Bool.self, forKey: .underline),
            strikethrough: try c.decodeIfPresent(Bool.self, forKey: .strikethrough),
            fontSize: try c.decodeIfPresent(CGFloat.self, forKey: .fontSize),
            fontFamily: try c.decodeIfPresent(String.self, forKey: .fontFamily),
            textColorHex: try c.decodeIfPresent(String.self, forKey: .textColorHex),
            highlightHex: try c.decodeIfPresent(String.self, forKey: .highlightHex))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(start, forKey: .start)
        try c.encode(length, forKey: .length)
        try c.encodeIfPresent(style.bold, forKey: .bold)
        try c.encodeIfPresent(style.italic, forKey: .italic)
        try c.encodeIfPresent(style.underline, forKey: .underline)
        try c.encodeIfPresent(style.strikethrough, forKey: .strikethrough)
        try c.encodeIfPresent(style.fontSize, forKey: .fontSize)
        try c.encodeIfPresent(style.fontFamily, forKey: .fontFamily)
        try c.encodeIfPresent(style.textColorHex, forKey: .textColorHex)
        try c.encodeIfPresent(style.highlightHex, forKey: .highlightHex)
    }

    /// 外觀 JSON 用的字典（`TextBoxAppearance`）。
    var jsonObject: [String: Any] {
        var json: [String: Any] = ["start": start, "length": length]
        if let v = style.bold { json["bold"] = v }
        if let v = style.italic { json["italic"] = v }
        if let v = style.underline { json["underline"] = v }
        if let v = style.strikethrough { json["strikethrough"] = v }
        if let v = style.fontSize { json["fontSize"] = v }
        if let v = style.fontFamily { json["fontFamily"] = v }
        if let v = style.textColorHex { json["textColorHex"] = v }
        if let v = style.highlightHex { json["highlightHex"] = v }
        return json
    }

    init?(jsonObject map: [String: Any]) {
        guard let start = (map["start"] as? NSNumber)?.intValue,
              let length = (map["length"] as? NSNumber)?.intValue else { return nil }
        self.start = start
        self.length = length
        style = TextCharStyle(
            bold: map["bold"] as? Bool,
            italic: map["italic"] as? Bool,
            underline: map["underline"] as? Bool,
            strikethrough: map["strikethrough"] as? Bool,
            fontSize: (map["fontSize"] as? NSNumber).map { CGFloat($0.doubleValue) },
            fontFamily: map["fontFamily"] as? String,
            textColorHex: map["textColorHex"] as? String,
            highlightHex: map["highlightHex"] as? String)
    }
}

/// 某個字實際呈現的格式（方塊預設 + 覆寫）。
public struct ResolvedCharStyle: Hashable {
    public var bold: Bool
    public var italic: Bool
    public var underline: Bool
    public var strikethrough: Bool
    public var fontSize: CGFloat
    public var fontFamily: String?
    public var textColorHex: String
    public var highlightHex: String?
}

// MARK: - 區段運算（純資料，不碰 UIKit）

enum RichText {

    /// 方塊層級的格式（當作每個字的底）。
    static func base(of item: NoteTextAttachment) -> ResolvedCharStyle {
        ResolvedCharStyle(
            bold: item.isBold, italic: item.isItalic, underline: item.isUnderline,
            strikethrough: item.isStrikethrough, fontSize: item.fontSize,
            fontFamily: (item.fontFamily?.isEmpty ?? true) ? nil : item.fontFamily,
            textColorHex: item.textColorHex, highlightHex: nil)
    }

    static func resolve(_ style: TextCharStyle, over base: ResolvedCharStyle) -> ResolvedCharStyle {
        var out = base
        if let v = style.bold { out.bold = v }
        if let v = style.italic { out.italic = v }
        if let v = style.underline { out.underline = v }
        if let v = style.strikethrough { out.strikethrough = v }
        if let v = style.fontSize { out.fontSize = v }
        if let v = style.fontFamily { out.fontFamily = v.isEmpty ? nil : v }
        if let v = style.textColorHex { out.textColorHex = v }
        if let v = style.highlightHex { out.highlightHex = v == "clear" ? nil : v }
        return out
    }

    /// 把與方塊預設相同的覆寫拿掉 —— 存下來的區段才會是最少的。
    static func pruned(_ style: TextCharStyle, base: ResolvedCharStyle) -> TextCharStyle {
        var out = style
        if out.bold == base.bold { out.bold = nil }
        if out.italic == base.italic { out.italic = nil }
        if out.underline == base.underline { out.underline = nil }
        if out.strikethrough == base.strikethrough { out.strikethrough = nil }
        if let v = out.fontSize, abs(v - base.fontSize) < 0.01 { out.fontSize = nil }
        if let v = out.fontFamily, (v.isEmpty ? nil : v) == base.fontFamily { out.fontFamily = nil }
        if let v = out.textColorHex, v.caseInsensitiveCompare(base.textColorHex) == .orderedSame { out.textColorHex = nil }
        if out.highlightHex == "clear" { out.highlightHex = nil }
        return out
    }

    /// 每個 UTF-16 碼元一格的覆寫表。區段重疊時後面的蓋前面的。
    static func expand(_ runs: [TextStyleRun]?, length: Int) -> [TextCharStyle] {
        var cells = Array(repeating: TextCharStyle(), count: max(0, length))
        for run in runs ?? [] {
            let lower = max(0, run.start)
            let upper = min(length, run.start + max(0, run.length))
            guard lower < upper else { continue }
            for i in lower..<upper { cells[i] = cells[i].overlaid(with: run.style) }
        }
        return cells
    }

    /// 覆寫表壓回區段：相鄰且相同的合併，沒有覆寫的不存。
    static func compress(_ cells: [TextCharStyle], base: ResolvedCharStyle) -> [TextStyleRun]? {
        var runs: [TextStyleRun] = []
        var i = 0
        while i < cells.count {
            let style = pruned(cells[i], base: base)
            var j = i + 1
            while j < cells.count, pruned(cells[j], base: base) == style { j += 1 }
            if !style.isEmpty { runs.append(TextStyleRun(start: i, length: j - i, style: style)) }
            i = j
        }
        return runs.isEmpty ? nil : runs
    }

    static func utf16Length(_ text: String) -> Int { (text as NSString).length }

    /// 夾到文字長度內並重新整理。別的平台（或舊版）改了文字卻沒改區段時，
    /// 區段可能超出範圍 —— 夾掉而不是讓它當掉或套錯位置以外的字。
    static func normalized(_ item: NoteTextAttachment) -> [TextStyleRun]? {
        guard let runs = item.runs, !runs.isEmpty else { return nil }
        let length = utf16Length(item.text)
        return compress(expand(runs, length: length), base: base(of: item))
    }

    /// 在 `range` 套用覆寫。`highlightHex == "clear"` 表示移除醒目提示。
    static func apply(_ edit: TextCharStyle, range: NSRange, to item: inout NoteTextAttachment) {
        let length = utf16Length(item.text)
        var cells = expand(item.runs, length: length)
        let lower = max(0, min(length, range.location))
        let upper = max(lower, min(length, range.location + range.length))
        for i in lower..<upper {
            cells[i] = cells[i].overlaid(with: edit)
            if edit.highlightHex == "clear" { cells[i].highlightHex = nil }
        }
        item.runs = compress(cells, base: base(of: item))
    }

    /// 整個方塊套用：方塊層級的值改掉，區段裡同一項的覆寫一併拿掉（否則改了看不到）。
    /// 醒目提示沒有方塊層級的值，改成套在全部文字上。
    static func applyToWholeBox(_ edit: TextCharStyle, to item: inout NoteTextAttachment) {
        if let v = edit.bold { item.isBold = v }
        if let v = edit.italic { item.isItalic = v }
        if let v = edit.underline { item.isUnderline = v }
        if let v = edit.strikethrough { item.isStrikethrough = v }
        if let v = edit.fontSize { item.fontSize = v }
        if let v = edit.fontFamily { item.fontFamily = v.isEmpty ? nil : v }
        if let v = edit.textColorHex { item.textColorHex = v }
        let length = utf16Length(item.text)
        var cells = expand(item.runs, length: length)
        for i in cells.indices {
            if edit.bold != nil { cells[i].bold = nil }
            if edit.italic != nil { cells[i].italic = nil }
            if edit.underline != nil { cells[i].underline = nil }
            if edit.strikethrough != nil { cells[i].strikethrough = nil }
            if edit.fontSize != nil { cells[i].fontSize = nil }
            if edit.fontFamily != nil { cells[i].fontFamily = nil }
            if edit.textColorHex != nil { cells[i].textColorHex = nil }
            if let v = edit.highlightHex { cells[i].highlightHex = v == "clear" ? nil : v }
        }
        item.runs = compress(cells, base: base(of: item))
    }

    /// 選取範圍的格式（以範圍第一個字為準，與 Word 工具列顯示的方式相同）；
    /// 範圍是空的（只有游標）時看游標前一個字。
    static func resolvedStyle(at range: NSRange, in item: NoteTextAttachment) -> ResolvedCharStyle {
        let length = utf16Length(item.text)
        let base = base(of: item)
        guard length > 0 else { return base }
        let index = range.length > 0 ? range.location : range.location - 1
        guard index >= 0, index < length else { return base }
        let cells = expand(item.runs, length: length)
        return resolve(cells[index], over: base)
    }

    /// 替換一段文字並讓區段跟著移動。新插入的字沿用前一個字的格式
    /// （與 Word 在段落中間打字的行為相同；開頭插入則沿用後一個字）。
    static func replaceCharacters(in range: NSRange, with string: String, in item: inout NoteTextAttachment) {
        let ns = item.text as NSString
        let lower = max(0, min(ns.length, range.location))
        let upper = max(lower, min(ns.length, range.location + range.length))
        let safe = NSRange(location: lower, length: upper - lower)
        var cells = expand(item.runs, length: ns.length)
        let inheritIndex = lower > 0 ? lower - 1 : (upper < cells.count ? upper : nil)
        let inherited = inheritIndex.map { cells[$0] } ?? TextCharStyle()
        let insertedLength = utf16Length(string)
        cells.replaceSubrange(lower..<upper, with: Array(repeating: inherited, count: insertedLength))
        item.text = ns.replacingCharacters(in: safe, with: string)
        item.runs = compress(cells, base: base(of: item))
    }

    /// 文字從 `old` 變成 `new`（不知道中間怎麼變的）時調整區段：
    /// 找出共同的開頭與結尾，中間那段視為一次替換。
    static func adjustRuns(of item: inout NoteTextAttachment, from old: String) {
        guard item.runs != nil else { return }
        let a = Array(old.utf16)
        let b = Array(item.text.utf16)
        var prefix = 0
        while prefix < a.count, prefix < b.count, a[prefix] == b[prefix] { prefix += 1 }
        var suffix = 0
        while suffix < a.count - prefix, suffix < b.count - prefix,
              a[a.count - 1 - suffix] == b[b.count - 1 - suffix] { suffix += 1 }
        let inserted = String(utf16CodeUnits: Array(b[prefix..<(b.count - suffix)]), count: b.count - suffix - prefix)
        var probe = item
        probe.text = old
        replaceCharacters(in: NSRange(location: prefix, length: a.count - suffix - prefix), with: inserted, in: &probe)
        item.runs = probe.runs
    }
}

// MARK: - 呈現

extension RichText {

    /// 把附加在字上的格式帶進 `NSAttributedString`，讓 UITextView 打字時自動延續
    /// （`typingAttributes` 會一起帶著這個鍵），存檔時再原樣讀回 —— 不必從字型反推。
    static let styleKey = NSAttributedString.Key("kairumo.charStyle")

    final class StyleBox: NSObject {
        let style: TextCharStyle
        init(_ style: TextCharStyle) { self.style = style }
        override func isEqual(_ object: Any?) -> Bool { (object as? StyleBox)?.style == style }
        override var hash: Int { style.hashValue }
    }

    static func uiFont(_ style: ResolvedCharStyle) -> UIFont {
        var traits: UIFontDescriptor.SymbolicTraits = []
        if style.bold { traits.insert(.traitBold) }
        if style.italic { traits.insert(.traitItalic) }
        let base: UIFont
        if let family = style.fontFamily, family.lowercased() != "system" {
            let descriptor = UIFontDescriptor(fontAttributes: [.family: family])
            base = UIFont(descriptor: descriptor, size: style.fontSize)
        } else {
            base = UIFont.systemFont(ofSize: style.fontSize)
        }
        guard !traits.isEmpty,
              let descriptor = base.fontDescriptor.withSymbolicTraits(base.fontDescriptor.symbolicTraits.union(traits))
        else { return base }
        return UIFont(descriptor: descriptor, size: style.fontSize)
    }

    static func paragraphStyle(for item: NoteTextAttachment) -> NSMutableParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        switch item.alignmentRaw {
        case "center": paragraph.alignment = .center
        case "right": paragraph.alignment = .right
        case "justified": paragraph.alignment = .justified
        default: paragraph.alignment = .left
        }
        paragraph.lineBreakMode = .byWordWrapping
        if let value = item.lineSpacing { paragraph.lineSpacing = value }
        if let value = item.paragraphSpacing { paragraph.paragraphSpacing = value }
        if let value = item.firstLineIndent { paragraph.firstLineHeadIndent = value }
        if let value = item.paragraphIndent {
            paragraph.headIndent = value
            if item.firstLineIndent == nil { paragraph.firstLineHeadIndent = value }
        }
        return paragraph
    }

    static func attributes(
        _ resolved: ResolvedCharStyle, override: TextCharStyle, paragraph: NSParagraphStyle
    ) -> [NSAttributedString.Key: Any] {
        var attrs: [NSAttributedString.Key: Any] = [
            .font: uiFont(resolved),
            .foregroundColor: UIColor(hexString: resolved.textColorHex) ?? .label,
            .paragraphStyle: paragraph,
            styleKey: StyleBox(override)
        ]
        if resolved.underline { attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue }
        if resolved.strikethrough { attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
        if let hex = resolved.highlightHex, let color = UIColor(hexString: hex) {
            attrs[.backgroundColor] = color
        }
        return attrs
    }

    /// 畫布編輯器、縮圖與匯出共用的排版結果。三條路用同一份，換行位置才會一致。
    static func attributedString(for item: NoteTextAttachment) -> NSAttributedString {
        let base = base(of: item)
        let paragraph = paragraphStyle(for: item)
        let text = item.text
        let length = utf16Length(text)
        guard let runs = item.runs, !runs.isEmpty, length > 0 else {
            return NSAttributedString(string: text, attributes: attributes(base, override: TextCharStyle(), paragraph: paragraph))
        }
        let out = NSMutableAttributedString(string: text)
        let cells = expand(runs, length: length)
        var i = 0
        while i < length {
            var j = i + 1
            while j < length, cells[j] == cells[i] { j += 1 }
            out.setAttributes(
                attributes(resolve(cells[i], over: base), override: cells[i], paragraph: paragraph),
                range: NSRange(location: i, length: j - i))
            i = j
        }
        return out
    }

    /// 打字時游標處的屬性（方塊預設 + 覆寫）。
    static func typingAttributes(for item: NoteTextAttachment, override: TextCharStyle) -> [NSAttributedString.Key: Any] {
        attributes(resolve(override, over: base(of: item)), override: override, paragraph: paragraphStyle(for: item))
    }

    /// 從 UITextView 讀回區段。
    static func runs(from attributed: NSAttributedString, item: NoteTextAttachment) -> [TextStyleRun]? {
        let length = attributed.length
        guard length > 0 else { return nil }
        var cells = Array(repeating: TextCharStyle(), count: length)
        attributed.enumerateAttribute(styleKey, in: NSRange(location: 0, length: length)) { value, range, _ in
            guard let box = value as? StyleBox else { return }
            for i in range.location..<(range.location + range.length) { cells[i] = box.style }
        }
        return compress(cells, base: base(of: item))
    }

    /// 內容需要的方塊高度（含上下內距）。有逐字格式時，最大的那一行字決定行高，
    /// 單一字級的估算會把大字截掉。
    static func boxHeight(for item: NoteTextAttachment) -> CGFloat {
        guard let runs = item.runs, !runs.isEmpty else {
            return RuledWriting.boxHeight(
                text: item.text.isEmpty ? " " : item.text, width: item.width,
                fontSize: item.fontSize, bold: item.isBold, lineSpacing: item.lineSpacing ?? 0)
        }
        let padding = RuledWriting.padding
        let measured = attributedString(for: item).boundingRect(
            with: CGSize(width: max(1, item.width - 2 * padding), height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        let trailing = item.text.hasSuffix("\n") ? uiFont(base(of: item)).lineHeight : 0
        return max(RuledWriting.fullPaddingHeight, ceil(measured.height + trailing) + 2 * padding)
    }

    /// SwiftUI 顯示用。每一段都把屬性寫滿，不依賴外層 `.font` 等修飾（那些只套在沒寫屬性的字上）。
    static func swiftUIText(for item: NoteTextAttachment) -> AttributedString {
        let base = base(of: item)
        let text = item.text as NSString
        let cells = expand(item.runs, length: text.length)
        var out = AttributedString()
        var i = 0
        while i < text.length {
            var j = i + 1
            while j < text.length, cells[j] == cells[i] { j += 1 }
            let style = resolve(cells[i], over: base)
            var piece = AttributedString(text.substring(with: NSRange(location: i, length: j - i)))
            piece.font = swiftUIFont(style)
            piece.foregroundColor = Color(hex: style.textColorHex) ?? .primary
            if style.underline { piece.underlineStyle = .single }
            if style.strikethrough { piece.strikethroughStyle = .single }
            if let hex = style.highlightHex, let color = Color(hex: hex) { piece.backgroundColor = color }
            out.append(piece)
            i = j
        }
        return out
    }

    static func swiftUIFont(_ style: ResolvedCharStyle) -> Font {
        var font: Font
        if let family = style.fontFamily, family.lowercased() != "system" {
            font = Font.custom(family, size: style.fontSize)
            if style.bold { font = font.bold() }
        } else {
            font = Font.system(size: style.fontSize, weight: style.bold ? .bold : .regular)
        }
        if style.italic { font = font.italic() }
        return font
    }
}

// MARK: - 選取範圍

/// 工具列要套用格式的範圍。
enum TextFormatScope: Equatable {
    /// 有選取文字：只改選到的字（Word 的行為）。
    case selection(NSRange)
    /// 只有游標、而且不在字中間：改的是「接下來打的字」。
    case caret(Int)
    /// 方塊被選取但沒有在打字：整個方塊。
    case wholeBox
}

/// 游標處待套用的格式：沒有選取時按粗體，之後打出來的字才是粗體。
struct CaretStyle: Equatable {
    let textId: String
    let location: Int
    var style: TextCharStyle
}

/// 就地編輯中的選取範圍。
///
/// **編輯器本身不訂閱它**（以 `@State` 持有參考，不是 `@StateObject`）：游標每動一下
/// 都會發布，整個筆記本畫面跟著重算會很卡。只有工具列訂閱，用來顯示選取文字的格式。
final class TextSelectionTracker: ObservableObject {
    @Published private(set) var textId: String?
    @Published private(set) var range = NSRange(location: 0, length: 0)
    @Published private(set) var caretStyle: CaretStyle?
    /// 就地編輯被工具列打斷後重新開始時，把游標放回原處（而不是放到最後）。
    var restoreSelectionOnNextBegin = false
    /// 目前掛著的編輯器（套用游標格式時直接改它的 typingAttributes）。
    weak var textView: UITextView?
    /// 產生某個方塊游標處屬性的方法（由編輯器提供，需要完整的方塊資料）。
    var typingAttributesProvider: ((String, TextCharStyle) -> [NSAttributedString.Key: Any]?)?

    func update(textId: String, range: NSRange) {
        if self.textId != textId || self.range != range {
            self.textId = textId
            self.range = range
        }
        // 游標移到別處（不是剛好停在原位）：之前的游標格式失效。
        if let caret = caretStyle, caret.textId != textId || range.length > 0 || range.location != caret.location {
            caretStyle = nil
        }
    }

    func setCaretStyle(_ caret: CaretStyle) {
        caretStyle = caret
        applyCaretStyleIfPossible()
    }

    func applyCaretStyleIfPossible() {
        guard let caret = caretStyle, let tv = textView, textId == caret.textId,
              tv.selectedRange.length == 0, tv.selectedRange.location == caret.location,
              let attrs = typingAttributesProvider?(caret.textId, caret.style) else { return }
        tv.typingAttributes = attrs
    }

    func clear(textId: String) {
        guard self.textId == textId else { return }
        caretStyle = nil
    }
}

extension RichText {

    /// 游標落在一個詞的中間時，那個詞的範圍（Word：游標在詞中按粗體 = 整個詞變粗）。
    /// 落在詞的邊界、空白或行尾時回 nil —— 那時改的是接下來要打的字。
    static func wordRange(around location: Int, in text: String) -> NSRange? {
        let ns = text as NSString
        guard location > 0, location < ns.length else { return nil }
        var found: NSRange?
        ns.enumerateSubstrings(in: NSRange(location: 0, length: ns.length), options: [.byWords, .substringNotRequired]) { _, range, _, stop in
            if range.location < location && location < range.location + range.length {
                found = range
                stop.pointee = true
            } else if range.location >= location {
                stop.pointee = true
            }
        }
        return found
    }

    /// 把範圍內的覆寫全部拿掉（Word 的「清除格式設定」只作用在選取範圍）。
    static func clearOverrides(in range: NSRange, of item: inout NoteTextAttachment) {
        let length = utf16Length(item.text)
        var cells = expand(item.runs, length: length)
        let lower = max(0, min(length, range.location))
        let upper = max(lower, min(length, range.location + range.length))
        for i in lower..<upper { cells[i] = TextCharStyle() }
        item.runs = compress(cells, base: base(of: item))
    }

    /// 文字變了，區段跟著調整。行數沒變時逐行比對 —— 清單開關在每一行開頭加減符號，
    /// 整段當成一次替換的話，中間各行的粗體、顏色會全部被洗掉。
    static func adjustRunsLineByLine(of item: inout NoteTextAttachment, from old: String) {
        guard item.runs != nil, old != item.text else { return }
        let oldLines = old.components(separatedBy: "\n")
        let newLines = item.text.components(separatedBy: "\n")
        guard oldLines.count == newLines.count else {
            adjustRuns(of: &item, from: old)
            return
        }
        var probe = item
        probe.text = old
        // 從最後一行往前改，前面各行的位置才不會被後面的修改影響。
        var starts: [Int] = []
        var offset = 0
        for line in oldLines {
            starts.append(offset)
            offset += utf16Length(line) + 1
        }
        for index in stride(from: oldLines.count - 1, through: 0, by: -1) where oldLines[index] != newLines[index] {
            let a = Array(oldLines[index].utf16)
            let b = Array(newLines[index].utf16)
            var prefix = 0
            while prefix < a.count, prefix < b.count, a[prefix] == b[prefix] { prefix += 1 }
            var suffix = 0
            while suffix < a.count - prefix, suffix < b.count - prefix,
                  a[a.count - 1 - suffix] == b[b.count - 1 - suffix] { suffix += 1 }
            let inserted = String(utf16CodeUnits: Array(b[prefix..<(b.count - suffix)]), count: b.count - suffix - prefix)
            replaceCharacters(
                in: NSRange(location: starts[index] + prefix, length: a.count - suffix - prefix),
                with: inserted, in: &probe)
        }
        item.runs = probe.runs
    }
}

// MARK: - 就地編輯器

/// 打字的復原另外放。
///
/// `UITextView` 預設用視窗的 `undoManager` —— 也就是畫布、PencilKit 與物件復原共用的那一個。
/// 打字會一個字一個字登記進去，與 `CanvasObjectHistory` 記下的文字變更重複，而且會插在筆畫中間：
/// 按工具列的復原可能退掉的是半個字。文字內容的復原由物件紀錄負責（連續打字合併成一步）。
final class InlineTextView: UITextView {
    private let typingUndoManager = UndoManager()
    override var undoManager: UndoManager? { typingUndoManager }
}

/// 文字方塊的就地編輯器（`UITextView`）。
///
/// 原本是 `TextField(axis: .vertical)` —— 它拿不到選取範圍，也顯示不了逐字格式，
/// 所以工具列只能改整個方塊。這裡的屬性字串與縮圖、匯出走同一份 `RichText` 排版。
///
/// 內距全部歸零（`textContainerInset`、`lineFragmentPadding`）：編輯中的字與
/// 編輯後的 `Text` 要完全重疊，橫線紙上的基準線才對得齊。
struct RichTextEditorView: UIViewRepresentable {
    @Binding var item: NoteTextAttachment
    @Binding var isFocused: Bool
    var tracker: TextSelectionTracker?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let tv = InlineTextView()
        tv.backgroundColor = .clear
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.isScrollEnabled = false
        tv.allowsEditingTextAttributes = false
        tv.delegate = context.coordinator
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tv.accessibilityIdentifier = "editor.text.inline_editor"
        context.coordinator.render(item, into: tv)
        context.coordinator.attach(tv)
        if tracker?.restoreSelectionOnNextBegin == true, let tracker, tracker.textId == item.id {
            let length = (tv.text as NSString).length
            let r = tracker.range
            let location = min(max(0, r.location), length)
            tv.selectedRange = NSRange(location: location, length: min(r.length, length - location))
            tracker.restoreSelectionOnNextBegin = false
        } else {
            tv.selectedRange = NSRange(location: (tv.text as NSString).length, length: 0)
        }
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        context.coordinator.parent = self
        // 輸入法組字中（注音、拼音、日文）絕對不能重設內容 —— 會把還沒選字的組字打斷。
        if tv.markedTextRange == nil, context.coordinator.lastRendered != item {
            context.coordinator.render(item, into: tv)
        }
        if isFocused && !tv.isFirstResponder {
            DispatchQueue.main.async {
                guard self.isFocused, tv.window != nil, !tv.isFirstResponder else { return }
                tv.becomeFirstResponder()
                self.tracker?.textView = tv
                self.tracker?.applyCaretStyleIfPossible()
            }
        } else if !isFocused && tv.isFirstResponder {
            DispatchQueue.main.async { if !self.isFocused { tv.resignFirstResponder() } }
        }
    }

    @available(iOS 16.0, *)
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? uiView.bounds.width
        guard width > 0, width.isFinite else { return nil }
        let fitted = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: max(20, ceil(fitted.height)))
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: RichTextEditorView
        var lastRendered: NoteTextAttachment?

        init(_ parent: RichTextEditorView) { self.parent = parent }

        /// 讓選取追蹤器能替這個方塊算出游標處的屬性（需要方塊的完整資料）。
        func attach(_ tv: UITextView) {
            guard let tracker = parent.tracker else { return }
            tracker.textView = tv
            tracker.typingAttributesProvider = { [weak self] id, style in
                guard let item = self?.parent.item, item.id == id else { return nil }
                return RichText.typingAttributes(for: item, override: style)
            }
        }

        func render(_ item: NoteTextAttachment, into tv: UITextView) {
            var selection = tv.selectedRange
            // 別人同時在這個方塊打字（設計 §8.3）：變動發生在游標前面時，游標跟著移動，
            // 否則別人每打一個字，自己的游標就往回跳一格。
            let old = tv.text ?? ""
            if old != item.text, tv.isFirstResponder {
                let a = Array(old.utf16), b = Array(item.text.utf16)
                var prefix = 0
                while prefix < a.count, prefix < b.count, a[prefix] == b[prefix] { prefix += 1 }
                if prefix < selection.location {
                    selection.location = max(prefix, selection.location + (b.count - a.count))
                }
            }
            tv.attributedText = RichText.attributedString(for: item)
            let length = (tv.text as NSString).length
            let location = min(selection.location, length)
            tv.selectedRange = NSRange(location: location, length: min(selection.length, length - location))
            if length == 0 || location == 0 {
                tv.typingAttributes = RichText.typingAttributes(for: item, override: TextCharStyle())
            }
            lastRendered = item
            parent.tracker?.applyCaretStyleIfPossible()
        }

        // orphan-ok: UITextViewDelegate 回呼，由 UIKit 呼叫
        func textViewDidChange(_ tv: UITextView) {
            var next = parent.item
            next.text = tv.text
            next.runs = RichText.runs(from: tv.attributedText, item: next)
            lastRendered = next
            if next != parent.item { parent.item = next }
        }

        // orphan-ok: UITextViewDelegate 回呼，由 UIKit 呼叫
        func textViewDidChangeSelection(_ tv: UITextView) {
            parent.tracker?.update(textId: parent.item.id, range: tv.selectedRange)
        }

        // orphan-ok: UITextViewDelegate 回呼，由 UIKit 呼叫
        func textViewDidBeginEditing(_ tv: UITextView) {
            attach(tv)
            parent.tracker?.update(textId: parent.item.id, range: tv.selectedRange)
            if !parent.isFocused { parent.isFocused = true }
        }

        // orphan-ok: UITextViewDelegate 回呼，由 UIKit 呼叫
        // unused-param-ok: 委派方法的簽名固定；結束編輯只需要同步焦點狀態
        func textViewDidEndEditing(_ tv: UITextView) {
            if parent.isFocused { parent.isFocused = false }
        }
    }
}
