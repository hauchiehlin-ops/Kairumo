//
//  WordDocumentEditorView.swift
//  Kairumo
//
//  仿照 Office Word / Google 文件的文書處理模式編輯介面。
//  具備標準功能列（樣式、字型、字級、修飾、色彩、對齊、清單、表格、圖片等），
//  以及標準紙張流式編輯區。
//

import SwiftUI
import PhotosUI

struct TablePresetOption: Identifiable {
    let rows: Int
    let cols: Int
    var id: String { "\(rows)x\(cols)" }
}

private let presetTableOptions: [TablePresetOption] = [
    TablePresetOption(rows: 2, cols: 2),
    TablePresetOption(rows: 2, cols: 3),
    TablePresetOption(rows: 2, cols: 4),
    TablePresetOption(rows: 2, cols: 5),
    TablePresetOption(rows: 3, cols: 2),
    TablePresetOption(rows: 3, cols: 3),
    TablePresetOption(rows: 3, cols: 4),
    TablePresetOption(rows: 3, cols: 5),
    TablePresetOption(rows: 4, cols: 2),
    TablePresetOption(rows: 4, cols: 3),
    TablePresetOption(rows: 4, cols: 4),
    TablePresetOption(rows: 4, cols: 5),
    TablePresetOption(rows: 5, cols: 2),
    TablePresetOption(rows: 5, cols: 3),
    TablePresetOption(rows: 5, cols: 4),
    TablePresetOption(rows: 5, cols: 5),
]

// MARK: - Word 色盤

/// 色盤上的一格：顏色加上使用者看得懂的名稱（滑過或語音朗讀時顯示）。
struct WordPaletteColor: Identifiable, Hashable {
    let hex: String
    let name: String
    var id: String { hex + name }
}

/// 與 Office Word 相同的色彩清單。
///
/// 之前的下拉選單只列出色碼（字色）或六個一模一樣的「螢光色」字樣（醒目提示），
/// 而且 iOS 的系統選單根本不會畫出自訂的色塊 —— 使用者完全看不出每一項是什麼顏色。
/// 現在改成 Word 的色盤：佈景主題色彩（含深淺變化）、標準色彩，每一格都是真正的色塊。
enum WordPalette {
    /// Office 佈景主題的十個基準色（Word「佈景主題色彩」第一列）。
    static let themeBase: [(hex: String, key: String)] = [
        ("#FFFFFF", "wd_c_white"), ("#000000", "wd_c_black"), ("#E7E6E6", "wd_c_tan"),
        ("#44546A", "wd_c_blue_gray"), ("#4472C4", "wd_c_blue"), ("#ED7D31", "wd_c_orange"),
        ("#A5A5A5", "wd_c_gray"), ("#FFC000", "wd_c_gold"), ("#5B9BD5", "wd_c_sky_blue"),
        ("#70AD47", "wd_c_green"),
    ]
    /// Word「標準色彩」那一列。
    static let standard: [(hex: String, key: String)] = [
        ("#C00000", "wd_c_dark_red"), ("#FF0000", "wd_c_red"), ("#FFC000", "wd_c_orange"),
        ("#FFFF00", "wd_c_yellow"), ("#92D050", "wd_c_light_green"), ("#00B050", "wd_c_green"),
        ("#00B0F0", "wd_c_light_blue"), ("#0070C0", "wd_c_blue"), ("#002060", "wd_c_dark_blue"),
        ("#7030A0", "wd_c_purple"),
    ]
    /// Word「文字醒目提示色彩」的十五色（同樣的排列：5 欄 × 3 列）。
    static let highlight: [(hex: String, key: String)] = [
        ("#FFFF00", "wd_c_yellow"), ("#00FF00", "wd_c_bright_green"), ("#00FFFF", "wd_c_turquoise"),
        ("#FF00FF", "wd_c_pink"), ("#0000FF", "wd_c_blue"),
        ("#FF0000", "wd_c_red"), ("#000080", "wd_c_dark_blue"), ("#008080", "wd_c_teal"),
        ("#008000", "wd_c_green"), ("#800080", "wd_c_violet"),
        ("#800000", "wd_c_dark_red"), ("#808000", "wd_c_dark_yellow"), ("#808080", "wd_c_gray_50"),
        ("#C0C0C0", "wd_c_gray_25"), ("#000000", "wd_c_black"),
    ]

    /// 佈景主題色彩的六列：基準色，再來是較淺 80/60/40%、較深 25/50%。
    /// 白色只能變深、黑色只能變淺 —— 與 Word 相同。
    static func themeGrid(_ l: (String) -> String) -> [[WordPaletteColor]] {
        func mix(_ hex: String, toward target: Double, amount: Double) -> String {
            let v = UInt64(hex.dropFirst(), radix: 16) ?? 0
            let comps = [Double((v >> 16) & 0xFF), Double((v >> 8) & 0xFF), Double(v & 0xFF)]
            let out = comps.map { Int(($0 + (target - $0) * amount).rounded()) }
            return String(format: "#%02X%02X%02X", out[0], out[1], out[2])
        }
        let lighter = [0.8, 0.6, 0.4]
        let darker = [0.25, 0.5]
        var rows: [[WordPaletteColor]] = [themeBase.map { WordPaletteColor(hex: $0.hex, name: l($0.key)) }]
        for step in 0..<5 {
            rows.append(themeBase.map { base -> WordPaletteColor in
                let name = l(base.key)
                if base.hex == "#FFFFFF" {
                    let pct = [0.05, 0.15, 0.25, 0.35, 0.5][step]
                    return WordPaletteColor(hex: mix(base.hex, toward: 0, amount: pct),
                                            name: String(format: l("wd_tint_darker"), name, "\(Int(pct * 100))%"))
                }
                if base.hex == "#000000" {
                    let pct = [0.5, 0.35, 0.25, 0.15, 0.05][step]
                    return WordPaletteColor(hex: mix(base.hex, toward: 255, amount: pct),
                                            name: String(format: l("wd_tint_lighter"), name, "\(Int(pct * 100))%"))
                }
                if step < 3 {
                    let pct = lighter[step]
                    return WordPaletteColor(hex: mix(base.hex, toward: 255, amount: pct),
                                            name: String(format: l("wd_tint_lighter"), name, "\(Int(pct * 100))%"))
                }
                let pct = darker[step - 3]
                return WordPaletteColor(hex: mix(base.hex, toward: 0, amount: pct),
                                        name: String(format: l("wd_tint_darker"), name, "\(Int(pct * 100))%"))
            })
        }
        return rows
    }

    /// 最近使用的顏色：以逗號串起來存在設定檔範圍的偏好裡，最多十個。
    static func pushRecent(_ hex: String, into raw: inout String) {
        var list = raw.split(separator: ",").map(String.init).filter { $0.caseInsensitiveCompare(hex) != .orderedSame }
        list.insert(hex.uppercased(), at: 0)
        raw = list.prefix(10).joined(separator: ",")
    }
}

/// 一格色塊。選中的那一格加框；名稱掛在 `.help`（Mac 滑過即顯示）與無障礙標籤上。
private struct WordSwatch: View {
    let color: WordPaletteColor
    let isSelected: Bool
    var size: CGFloat = 20
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(hex: color.hex) ?? .clear)
                .frame(width: size, height: size)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Color.secondary.opacity(0.35), lineWidth: 0.5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                        .padding(-2)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(color.name)
        .accessibilityLabel(color.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Word「字型色彩」下拉色盤。
private struct WordFontColorPalette: View {
    @ObservedObject var localizationManager = LocalizationManager.shared
    let currentHex: String
    let recentRaw: String
    let onPick: (String) -> Void

    private func l(_ key: String) -> String { localizationManager.localized(key) }

    private func isCurrent(_ hex: String) -> Bool { currentHex.caseInsensitiveCompare(hex) == .orderedSame }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                onPick("#000000")
            } label: {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.black).frame(width: 20, height: 20)
                    Text(l("wd_color_automatic")).font(.system(size: 13))
                    Spacer()
                    if isCurrent("#000000") { Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)) }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text(l("wd_theme_colors")).font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
            VStack(spacing: 2) {
                ForEach(Array(WordPalette.themeGrid(l).enumerated()), id: \.offset) { rowIndex, row in
                    HStack(spacing: 4) {
                        ForEach(row) { c in
                            WordSwatch(color: c, isSelected: isCurrent(c.hex)) { onPick(c.hex) }
                        }
                    }
                    if rowIndex == 0 { Spacer().frame(height: 4) }
                }
            }

            Text(l("wd_standard_colors")).font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
            HStack(spacing: 4) {
                ForEach(WordPalette.standard, id: \.hex) { item in
                    let c = WordPaletteColor(hex: item.hex, name: l(item.key))
                    WordSwatch(color: c, isSelected: isCurrent(c.hex)) { onPick(c.hex) }
                }
            }

            let recent = recentRaw.split(separator: ",").map(String.init)
            if !recent.isEmpty {
                Text(l("recent_colors")).font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
                HStack(spacing: 4) {
                    ForEach(recent, id: \.self) { hex in
                        WordSwatch(color: WordPaletteColor(hex: hex, name: hex), isSelected: isCurrent(hex)) { onPick(hex) }
                    }
                }
            }

            Divider()
            ColorPicker(selection: Binding(
                get: { Color(hex: currentHex) ?? .black },
                set: { if let hex = $0.toHex() { onPick(hex) } }
            ), supportsOpacity: false) {
                Text(l("wd_more_colors")).font(.system(size: 13))
            }
        }
        .padding(12)
        .frame(width: 252)
    }
}

/// Word「文字醒目提示色彩」下拉色盤：十五色 + 無色彩。
private struct WordHighlightPalette: View {
    @ObservedObject var localizationManager = LocalizationManager.shared
    let currentHex: String?
    let onPick: (String) -> Void

    private func l(_ key: String) -> String { localizationManager.localized(key) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(l("wd_text_highlight")).font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(26), spacing: 6), count: 5), spacing: 6) {
                ForEach(WordPalette.highlight, id: \.hex) { item in
                    let c = WordPaletteColor(hex: item.hex, name: l(item.key))
                    WordSwatch(color: c,
                               isSelected: (currentHex ?? "").caseInsensitiveCompare(c.hex) == .orderedSame,
                               size: 24) { onPick(c.hex) }
                }
            }
            Divider()
            Button {
                onPick("clear")
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "nosign").font(.system(size: 13))
                    Text(l("no_highlight")).font(.system(size: 13))
                    Spacer()
                    if currentHex == nil || currentHex == "clear" {
                        Image(systemName: "checkmark").font(.system(size: 11, weight: .bold))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(width: 176)
    }
}

private extension View {
    /// iPhone 上也維持小浮窗（預設會變成整張 sheet，色盤被拉得很怪）。
    @ViewBuilder
    func wordPopoverAdaptation() -> some View {
        if #available(iOS 16.4, *) {
            self.presentationCompactAdaptation(.popover)
        } else {
            self
        }
    }
}

/// Word 的字級清單（字級方塊的下拉、以及「放大／縮小字型」逐級跳動的依據）。
let wordFontSizes: [CGFloat] = [8, 9, 10, 10.5, 11, 12, 14, 16, 18, 20, 22, 24, 26, 28, 36, 48, 72]

/// Word「放大字型」：跳到清單裡下一個較大的字級；超過 72 之後每次 +10。
func wordGrowFontSize(_ size: CGFloat) -> CGFloat {
    if let next = wordFontSizes.first(where: { $0 > size + 0.01 }) { return next }
    return min(400, (size / 10).rounded(.down) * 10 + 10)
}

/// Word「縮小字型」：跳到清單裡上一個較小的字級；最小 1。
func wordShrinkFontSize(_ size: CGFloat) -> CGFloat {
    if size > 72 + 0.01 { return max(72, (size / 10).rounded(.up) * 10 - 10) }
    if let prev = wordFontSizes.last(where: { $0 < size - 0.01 }) { return prev }
    return max(1, size - 1)
}

/// 清單樣式。一個文字方塊就是使用者的「選取範圍」，所以清單套用在方塊的每一段。
enum WordListKind {
    case bullet, numbered, checklist

    /// 既有段落開頭的清單符號（含後面的空白）。
    static func existingMarker(in line: Substring) -> Substring.Index? {
        for marker in ["• ", "☐ ", "☑ ", "☒ "] where line.hasPrefix(marker) {
            return line.index(line.startIndex, offsetBy: marker.count)
        }
        // 「1. 」「12. 」—— 最多三位數，「2024. 年度回顧」的年份不是清單編號。
        var idx = line.startIndex
        var digits = 0
        while idx < line.endIndex, line[idx].isASCII, line[idx].isNumber {
            idx = line.index(after: idx)
            digits += 1
        }
        if (1...3).contains(digits), idx < line.endIndex, line[idx] == "." {
            let afterDot = line.index(after: idx)
            if afterDot < line.endIndex, line[afterDot] == " " { return line.index(after: afterDot) }
        }
        return nil
    }

    func matches(_ line: Substring) -> Bool {
        switch self {
        case .bullet: return line.hasPrefix("• ")
        case .checklist: return line.hasPrefix("☐ ") || line.hasPrefix("☑ ") || line.hasPrefix("☒ ")
        case .numbered:
            guard let end = Self.existingMarker(in: line) else { return false }
            return line[line.startIndex..<end].first?.isNumber == true
        }
    }

    /// Word 的清單按鈕是開關：整個方塊都已是這種清單 → 移除；否則每一段都套上
    /// （原本是別種清單的，換成這一種）。空白段落不加符號。
    func toggle(in text: String) -> String {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        let content = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        if text.isEmpty { return marker(number: 1) }
        let allApplied = !content.isEmpty && content.allSatisfy { matches($0) }
        var number = 0
        return lines.map { line -> String in
            let body = Self.existingMarker(in: line).map { line[$0...] } ?? line
            if allApplied || line.trimmingCharacters(in: .whitespaces).isEmpty { return String(body) }
            number += 1
            return marker(number: number) + body
        }.joined(separator: "\n")
    }

    private func marker(number: Int) -> String {
        switch self {
        case .bullet: return "• "
        case .numbered: return "\(number). "
        case .checklist: return "☐ "
        }
    }
}

/// Word / Google Docs 樣式的專屬文書排版工具列
///
/// 每一個控制項都只改 `activeText` —— 存檔、復原點、自動加高與把游標還給方塊，
/// 一律由 `NotebookEditorView.applyToolbarTextChange` 統一處理，不會有哪個按鈕漏掉。
public struct WordToolbarView: View {
    @ObservedObject var localizationManager = LocalizationManager.shared
    @Binding var activeText: NoteTextAttachment
    /// 有沒有真正的文字方塊可以套用。沒有時，設定會留給下一個新增的方塊。
    var hasTarget: Bool = true
    /// 就地編輯的選取範圍。訂閱它，按鈕狀態才會跟著選取的字變（選到粗體字，B 就亮）。
    @ObservedObject var selection: TextSelectionTracker
    /// 醒目提示是套在字上的（Word 的行為），不是方塊的底色 —— 所以另走一條路。
    let currentHighlightHex: () -> String?
    let onHighlight: (String) -> Void
    /// 清除格式：有選取時只清選取的字，由編輯器決定範圍。
    let onClearFormatting: () -> Void
    let canUndo: Bool
    let canRedo: Bool
    let onUndo: () -> Void
    let onRedo: () -> Void
    let onInsertTable: (Int, Int) -> Void
    let onInsertImage: () -> Void
    var onInsertImageFile: (() -> Void)? = nil
    var onPasteClipboardImage: (() -> Void)? = nil
    var onInsertDrawingBlock: (() -> Void)? = nil
    let onInsertLink: () -> Void
    let onInsertDivider: () -> Void
    /// 沒有目標方塊時按清單：開一個新方塊並放入第一個清單符號。
    let onInsertSnippet: (String) -> Void
    var onAddTextBox: (() -> Void)? = nil
    var isSnapToGrid: Bool? = nil
    var onToggleSnapToGrid: (() -> Void)? = nil
    var isUnderInk: Bool? = nil
    var onReorder: ((ObjectReorderOp) -> Void)? = nil

    @State private var showFontColorPalette = false
    @State private var showHighlightPalette = false
    @AppStorage(ProfileContext.scopedKey("kairumo.word.lastFontColor")) private var lastFontColorHex: String = "#C00000"
    @AppStorage(ProfileContext.scopedKey("kairumo.word.lastHighlight")) private var lastHighlightHex: String = "#FFFF00"
    @AppStorage(ProfileContext.scopedKey("kairumo.word.recentFontColors")) private var recentFontColorsRaw: String = ""

    /// 常用字型（Word 的「佈景主題字型」+ 中文常用）。只列出這台裝置真的裝了的。
    private static let featuredFamilies: [String] = [
        "PingFang TC", "Heiti TC", "Songti TC", "Kaiti TC", "BiauKai",
        "Helvetica Neue", "Arial", "Times New Roman", "Georgia", "Verdana",
        "Courier New", "Menlo", "Arial Rounded MT Bold", "Avenir Next",
    ]
    private static let installedFamilies: [String] = UIFont.familyNames.sorted()
    private static let availableFeatured: [String] = featuredFamilies.filter { installedFamilies.contains($0) }

    private func l(_ key: String) -> String { localizationManager.localized(key) }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                // 0. 新增文字方塊與格線吸附快捷入口
                if let onAddTextBox = onAddTextBox {
                    Button(action: onAddTextBox) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.bubble")
                                .font(.system(size: 13, weight: .semibold))
                            Text(l("add_text_box"))
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 9)
                        .frame(height: 28)
                        .background(Color.accentColor)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(l("add_text_box"))
                    .accessibilityIdentifier("editor.text.add_box")

                    Divider().frame(height: 20)
                }

                if let isSnap = isSnapToGrid, let onToggleSnap = onToggleSnapToGrid {
                    Button(action: onToggleSnap) {
                        HStack(spacing: 4) {
                            Image(systemName: "rectangle.split.3x3")
                                .font(.system(size: 12))
                            Text(l("snap_to_grid"))
                                .font(.system(size: 11))
                        }
                        .foregroundColor(isSnap ? .accentColor : .secondary)
                        .padding(.horizontal, 7)
                        .frame(height: 28)
                        .background(isSnap ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(l("snap_to_grid"))
                    .accessibilityIdentifier("editor.text.snap_to_grid")
                    Divider().frame(height: 20)
                }

                if !hasTarget {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .help(l("wd_no_text_target"))
                        .accessibilityLabel(l("wd_no_text_target"))
                }

                // 1. 樣式（內文、標題 1、標題 2、標題 3）
                Menu {
                    styleMenuItem(level: 0, key: "normal_text", icon: "text.alignleft")
                    styleMenuItem(level: 1, key: "heading_1", icon: "character.size.larger")
                    styleMenuItem(level: 2, key: "heading_2", icon: "character.size")
                    styleMenuItem(level: 3, key: "heading_3", icon: "character.size.smaller")
                } label: {
                    dropdownLabel(currentHeadingTitle, weight: .medium)
                }
                .buttonStyle(.plain)

                // 2. 字型
                Menu {
                    Button { activeText.fontFamily = nil } label: {
                        checkedLabel(l("font_system_default"), activeText.fontFamily == nil || activeText.fontFamily?.isEmpty == true)
                    }
                    Divider()
                    ForEach(Self.availableFeatured, id: \.self) { family in
                        Button { activeText.fontFamily = family } label: {
                            checkedLabel(family, activeText.fontFamily == family)
                        }
                    }
                    Divider()
                    Menu(l("wd_all_fonts")) {
                        ForEach(Self.installedFamilies, id: \.self) { family in
                            Button { activeText.fontFamily = family } label: {
                                checkedLabel(family, activeText.fontFamily == family)
                            }
                        }
                    }
                } label: {
                    dropdownLabel(currentFontDisplayName, weight: .regular)
                        .frame(maxWidth: 150)
                }
                .buttonStyle(.plain)
                .help(l("wd_font_family"))
                .accessibilityLabel(l("wd_font_family"))

                // 3. 字級：縮小 / 字級下拉 / 放大（與 Word 相同，逐級跳動）
                HStack(spacing: 2) {
                    Button {
                        activeText.fontSize = wordShrinkFontSize(activeText.fontSize)
                    } label: {
                        Image(systemName: "textformat.size.smaller")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(l("wd_shrink_font"))
                    .accessibilityLabel(l("wd_shrink_font"))

                    Menu {
                        ForEach(wordFontSizes, id: \.self) { size in
                            Button { activeText.fontSize = size } label: {
                                checkedLabel(formatSize(size), abs(activeText.fontSize - size) < 0.01)
                            }
                        }
                    } label: {
                        HStack(spacing: 2) {
                            Text(formatSize(activeText.fontSize))
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .frame(minWidth: 26)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .bold))
                        }
                        .padding(.horizontal, 4)
                        .frame(height: 28)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(l("font_size"))
                    .accessibilityLabel(l("font_size"))

                    Button {
                        activeText.fontSize = wordGrowFontSize(activeText.fontSize)
                    } label: {
                        Image(systemName: "textformat.size.larger")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(l("wd_grow_font"))
                    .accessibilityLabel(l("wd_grow_font"))
                }
                .padding(2)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(6)

                Divider().frame(height: 20)

                // 4. 字元修飾 (B / I / U / S)
                HStack(spacing: 2) {
                    toggleButton(icon: "bold", key: "font_bold", isActive: activeText.isBold) {
                        activeText.isBold.toggle()
                    }
                    toggleButton(icon: "italic", key: "font_italic", isActive: activeText.isItalic) {
                        activeText.isItalic.toggle()
                    }
                    toggleButton(icon: "underline", key: "text_underline", isActive: activeText.isUnderline) {
                        activeText.isUnderline.toggle()
                    }
                    toggleButton(icon: "strikethrough", key: "text_strikethrough", isActive: activeText.isStrikethrough) {
                        activeText.isStrikethrough.toggle()
                    }
                }
                .padding(2)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(6)

                // 5. 字型色彩、醒目提示（Word 的分割按鈕：左半套用上次的顏色，右半開色盤）
                splitColorButton(
                    accessibilityKey: "wd_font_color",
                    applyLast: { applyFontColor(lastFontColorHex) },
                    openPalette: { showFontColorPalette = true },
                    icon: {
                        VStack(spacing: 1) {
                            Text("A").font(.system(size: 13, weight: .bold))
                            Rectangle()
                                .fill(Color(hex: lastFontColorHex) ?? .red)
                                .frame(width: 16, height: 4)
                        }
                    }
                )
                .popover(isPresented: $showFontColorPalette) {
                    WordFontColorPalette(currentHex: activeText.textColorHex, recentRaw: recentFontColorsRaw) { hex in
                        applyFontColor(hex)
                        showFontColorPalette = false
                    }
                    .wordPopoverAdaptation()
                }

                splitColorButton(
                    accessibilityKey: "wd_text_highlight",
                    applyLast: { applyHighlight(lastHighlightHex) },
                    openPalette: { showHighlightPalette = true },
                    icon: {
                        VStack(spacing: 1) {
                            Image(systemName: "highlighter").font(.system(size: 12, weight: .semibold))
                            Rectangle()
                                .fill(Color(hex: lastHighlightHex) ?? .yellow)
                                .frame(width: 16, height: 4)
                        }
                    }
                )
                .popover(isPresented: $showHighlightPalette) {
                    WordHighlightPalette(currentHex: currentHighlightHex()) { hex in
                        applyHighlight(hex)
                        showHighlightPalette = false
                    }
                    .wordPopoverAdaptation()
                }

                Divider().frame(height: 20)

                // 6. 段落：對齊、縮排、行距
                HStack(spacing: 2) {
                    alignButton(icon: "text.alignleft", value: "left", key: "align_left")
                    alignButton(icon: "text.aligncenter", value: "center", key: "wd_align_center")
                    alignButton(icon: "text.alignright", value: "right", key: "align_right")
                }
                .padding(2)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(6)

                HStack(spacing: 2) {
                    iconButton("decrease.indent", key: "wd_decrease_indent") {
                        let next = max(0, (activeText.paragraphIndent ?? 0) - Self.indentStep)
                        activeText.paragraphIndent = next > 0 ? next : nil
                    }
                    .disabled((activeText.paragraphIndent ?? 0) <= 0)
                    iconButton("increase.indent", key: "wd_increase_indent") {
                        let limit = max(0, activeText.width - 60)
                        activeText.paragraphIndent = min(limit, (activeText.paragraphIndent ?? 0) + Self.indentStep)
                    }

                    Menu {
                        ForEach(Self.lineSpacingOptions, id: \.self) { multiple in
                            Button { setLineSpacing(multiple: multiple) } label: {
                                checkedLabel(String(format: "%.2g", multiple).replacingOccurrences(of: "1.1", with: "1.15"),
                                             abs(currentLineSpacingMultiple - multiple) < 0.02)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.and.down.text.horizontal")
                            .font(.system(size: 12))
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(l("wd_line_spacing"))
                    .accessibilityLabel(l("wd_line_spacing"))
                }
                .padding(2)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(6)

                // 7. 清單（開關：再按一次取消）
                HStack(spacing: 2) {
                    listButton(.bullet, icon: "list.bullet", key: "bullet_list", snippet: "• ")
                    listButton(.numbered, icon: "list.number", key: "numbered_list", snippet: "1. ")
                    listButton(.checklist, icon: "checklist", key: "todo_list", snippet: "☐ ")
                }
                .padding(2)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(6)

                Divider().frame(height: 20)

                // 8. 物件插入組（表格、圖片、連結、分隔線）
                HStack(spacing: 4) {
                    Menu {
                        ForEach(presetTableOptions) { opt in
                            Button(String(format: l("table_rows_cols"), "\(opt.rows)", "\(opt.cols)")) {
                                onInsertTable(opt.rows, opt.cols)
                            }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "tablecells")
                                .font(.system(size: 12))
                            Text(l("table"))
                                .font(.system(size: 11))
                        }
                        .padding(.horizontal, 7)
                        .frame(height: 28)
                        .background(Color.secondary.opacity(0.12))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)

                    if onInsertImageFile != nil || onPasteClipboardImage != nil {
                        Menu {
                            Button(action: onInsertImage) {
                                Label(l("import_from_photos"), systemImage: "photo.on.rectangle")
                            }
                            if let onFile = onInsertImageFile {
                                Button(action: onFile) {
                                    Label(l("import_from_files"), systemImage: "folder")
                                }
                            }
                            if let onPaste = onPasteClipboardImage {
                                Button(action: onPaste) {
                                    Label(l("paste_screenshot"), systemImage: "doc.on.clipboard")
                                }
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "photo")
                                    .font(.system(size: 12))
                                Text(l("image"))
                                    .font(.system(size: 11))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 8))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 7)
                            .frame(height: 28)
                            .background(Color.secondary.opacity(0.12))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button(action: onInsertImage) {
                            HStack(spacing: 3) {
                                Image(systemName: "photo")
                                    .font(.system(size: 12))
                                Text(l("image"))
                                    .font(.system(size: 11))
                            }
                            .padding(.horizontal, 7)
                            .frame(height: 28)
                            .background(Color.secondary.opacity(0.12))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }

                    if let onDraw = onInsertDrawingBlock {
                        Button(action: onDraw) {
                            HStack(spacing: 3) {
                                Image(systemName: "pencil.and.outline")
                                    .font(.system(size: 12))
                                Text(l("wd_ink_block"))
                                    .font(.system(size: 11))
                            }
                            .padding(.horizontal, 7)
                            .frame(height: 28)
                            .background(Color.accentColor.opacity(0.15))
                            .foregroundColor(.accentColor)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(l("wd_ink_block"))
                        .help(l("wd_insert_inline_canvas"))
                    }

                    Button(action: onInsertLink) {
                        Image(systemName: "link")
                            .font(.system(size: 12))
                            .frame(width: 28, height: 28)
                            .background(Color.secondary.opacity(0.12))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(l("insert_link"))
                    .help(l("insert_link"))

                    Button(action: onInsertDivider) {
                        Image(systemName: "divide")
                            .font(.system(size: 12))
                            .frame(width: 28, height: 28)
                            .background(Color.secondary.opacity(0.12))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(l("wd_insert_divider"))
                    .help(l("wd_insert_divider_desc"))
                }

                Divider().frame(height: 20)

                // 9. 清除所有格式設定（Word：回到「內文」樣式，文字內容不動）
                Button(action: clearFormatting) {
                    Image(systemName: "eraser")
                        .font(.system(size: 12))
                        .frame(width: 28, height: 28)
                        .background(Color.secondary.opacity(0.08))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(l("wd_clear_format"))
                .help(l("wd_clear_format"))

                // 10. 圖層順序與筆跡上下層級切換
                if let onReorder = onReorder, hasTarget {
                    let under = isUnderInk ?? false
                    Divider().frame(height: 20)

                    Menu {
                        Button {
                            onReorder(.bringAboveInk)
                        } label: {
                            Label(l("layer_bring_above_ink"), systemImage: "square.2.layers.3d.top.filled")
                        }
                        Button {
                            onReorder(.sendBelowInk)
                        } label: {
                            Label(l("layer_send_below_ink"), systemImage: "square.2.layers.3d.bottom.filled")
                        }
                        Divider()
                        Button {
                            onReorder(.toFront)
                        } label: {
                            Label(l("layer_bring_front"), systemImage: "arrow.up.to.line")
                        }
                        Button {
                            onReorder(.toBack)
                        } label: {
                            Label(l("layer_send_back"), systemImage: "arrow.down.to.line")
                        }
                        Button {
                            onReorder(.forward)
                        } label: {
                            Label(l("layer_bring_forward"), systemImage: "arrow.up")
                        }
                        Button {
                            onReorder(.backward)
                        } label: {
                            Label(l("layer_send_backward"), systemImage: "arrow.down")
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: under ? "square.2.layers.3d.bottom.filled" : "square.2.layers.3d.top.filled")
                                .font(.system(size: 12))
                            Text(l(under ? "layer_send_below_ink" : "layer_bring_above_ink"))
                                .font(.system(size: 11, weight: .medium))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .padding(.horizontal, 7)
                        .frame(height: 28)
                        .background(under ? Color.orange.opacity(0.18) : Color.purple.opacity(0.15))
                        .foregroundColor(under ? .orange : .purple)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(l("layers_panel"))
                    .help(l("layers_panel"))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
        }
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
    }

    // MARK: - 元件

    private func dropdownLabel(_ title: String, weight: Font.Weight) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: weight))
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.system(size: 9))
        }
        .padding(.horizontal, 8)
        .frame(height: 28)
        .background(Color.secondary.opacity(0.12))
        .cornerRadius(6)
        .contentShape(Rectangle())
    }

    /// 系統選單項目：目前的值打勾（Word 的下拉也是這樣標示）。
    @ViewBuilder
    private func checkedLabel(_ title: String, _ checked: Bool) -> some View {
        if checked {
            Label(title, systemImage: "checkmark")
        } else {
            Text(title)
        }
    }

    private func styleMenuItem(level: Int, key: String, icon: String) -> some View {
        Button { setHeading(level: level) } label: {
            Label(l(key), systemImage: currentHeadingLevel == level ? "checkmark" : icon)
        }
    }

    private func toggleButton(icon: String, key: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: isActive ? .bold : .medium))
                .foregroundColor(isActive ? .accentColor : .primary)
                .frame(width: 30, height: 30)
                .background(isActive ? Color.accentColor.opacity(0.18) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isActive ? Color.accentColor : Color.clear, lineWidth: 1)
                )
                .cornerRadius(6)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(l(key))
        .accessibilityLabel(l(key))
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private func iconButton(_ icon: String, key: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(l(key))
        .accessibilityLabel(l(key))
    }

    private func alignButton(icon: String, value: String, key: String) -> some View {
        let isActive = activeText.alignmentRaw == value
        return Button {
            activeText.alignmentRaw = value
        } label: {
            Image(systemName: icon)
                .font(.system(size: 13, weight: isActive ? .bold : .medium))
                .foregroundColor(isActive ? .accentColor : .primary)
                .frame(width: 30, height: 30)
                .background(isActive ? Color.accentColor.opacity(0.18) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isActive ? Color.accentColor : Color.clear, lineWidth: 1)
                )
                .cornerRadius(6)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(l(key))
        .accessibilityLabel(l(key))
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private func listButton(_ kind: WordListKind, icon: String, key: String, snippet: String) -> some View {
        let lines = activeText.text.split(separator: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let isActive = hasTarget && !lines.isEmpty && lines.allSatisfy { kind.matches($0) }
        return Button {
            if hasTarget {
                activeText.text = kind.toggle(in: activeText.text)
            } else {
                onInsertSnippet(snippet)
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 12, weight: isActive ? .bold : .regular))
                .foregroundColor(isActive ? .accentColor : .primary)
                .frame(width: 28, height: 28)
                .background(isActive ? Color.accentColor.opacity(0.18) : Color.clear)
                .cornerRadius(6)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(l(key))
        .accessibilityLabel(l(key))
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    /// Word 的分割色彩按鈕：左邊直接套用上次選的顏色，右邊的箭頭打開色盤。
    private func splitColorButton<Icon: View>(
        accessibilityKey: String,
        applyLast: @escaping () -> Void,
        openPalette: @escaping () -> Void,
        @ViewBuilder icon: () -> Icon
    ) -> some View {
        HStack(spacing: 0) {
            Button(action: applyLast) {
                icon()
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(l(accessibilityKey))
            .accessibilityLabel(l(accessibilityKey))

            Button(action: openPalette) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .frame(width: 16, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(l(accessibilityKey))
            .accessibilityLabel(l(accessibilityKey))
        }
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(6)
    }

    // MARK: - 動作

    private func applyFontColor(_ hex: String) {
        activeText.textColorHex = hex
        if hex != "#000000" {
            lastFontColorHex = hex
            WordPalette.pushRecent(hex, into: &recentFontColorsRaw)
        }
    }

    private func applyHighlight(_ hex: String) {
        onHighlight(hex)
        if hex != "clear" { lastHighlightHex = hex }
    }

    /// 縮排一階的寬度（約兩個中文字）。
    private static let indentStep: CGFloat = 24
    /// Word 的行距選項（倍數）。
    private static let lineSpacingOptions: [CGFloat] = [1.0, 1.15, 1.5, 2.0, 2.5, 3.0]

    /// 一行的自然高度約為字級 × 1.2；`lineSpacing` 存的是**額外**的點數。
    private var currentLineSpacingMultiple: CGFloat {
        let base = activeText.fontSize * 1.2
        return 1 + (activeText.lineSpacing ?? 0) / max(base, 1)
    }

    private func setLineSpacing(multiple: CGFloat) {
        let extra = activeText.fontSize * 1.2 * (multiple - 1)
        activeText.lineSpacing = extra > 0.01 ? extra : nil
    }

    private func clearFormatting() {
        onClearFormatting()
    }

    private func formatSize(_ size: CGFloat) -> String {
        size.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(size))" : String(format: "%.1f", size)
    }

    private var currentHeadingLevel: Int {
        guard activeText.isBold else { return 0 }
        switch activeText.fontSize {
        case 26: return 1
        case 20: return 2
        case 17: return 3
        default: return -1
        }
    }

    private var currentHeadingTitle: String {
        switch currentHeadingLevel {
        case 1: return l("heading_1")
        case 2: return l("heading_2")
        case 3: return l("heading_3")
        default: return l("normal_text")
        }
    }

    private var currentFontDisplayName: String {
        guard let family = activeText.fontFamily, !family.isEmpty else {
            return l("font_system")
        }
        return family
    }

    private func setHeading(level: Int) {
        var next = activeText
        switch level {
        case 1:
            next.fontSize = 26
            next.isBold = true
        case 2:
            next.fontSize = 20
            next.isBold = true
        case 3:
            next.fontSize = 17
            next.isBold = true
        default:
            next.fontSize = 15
            next.isBold = false
        }
        activeText = next
    }
}

/// 仿 Google Docs / Office Word 的標準居中文件紙張編輯器
public struct WordDocumentEditorView: View {
    @Binding var notebook: NotebookDocument
    let pageIndex: Int
    @Binding var activeTextDraft: NoteTextAttachment
    @Binding var activeInlineInkBlockId: String?
    let onCommit: () -> Void
    let onInsertTable: () -> Void
    let onInsertImage: () -> Void
    var onInsertImageFile: (() -> Void)? = nil
    var onPasteClipboardImage: (() -> Void)? = nil

    @FocusState private var isDocumentBodyFocused: Bool
    @ObservedObject var localizationManager = LocalizationManager.shared

    public init(
        notebook: Binding<NotebookDocument>,
        pageIndex: Int,
        activeTextDraft: Binding<NoteTextAttachment>,
        activeInlineInkBlockId: Binding<String?>? = nil,
        onCommit: @escaping () -> Void,
        onInsertTable: @escaping () -> Void,
        onInsertImage: @escaping () -> Void,
        onInsertImageFile: (() -> Void)? = nil,
        onPasteClipboardImage: (() -> Void)? = nil
    ) {
        self._notebook = notebook
        self.pageIndex = pageIndex
        self._activeTextDraft = activeTextDraft
        self._activeInlineInkBlockId = activeInlineInkBlockId ?? .constant(nil)
        self.onCommit = onCommit
        self.onInsertTable = onInsertTable
        self.onInsertImage = onInsertImage
        self.onInsertImageFile = onInsertImageFile
        self.onPasteClipboardImage = onPasteClipboardImage
    }

    // 取得當前頁面的主要文字物件（若無則自動在點擊時建立）
    private var pageMainTextBinding: Binding<NoteTextAttachment> {
        Binding(
            get: {
                if let existing = notebook.textAttachments?.first(where: { $0.pageIndex == pageIndex }) {
                    return existing
                }
                return activeTextDraft
            },
            set: { updated in
                if notebook.textAttachments == nil { notebook.textAttachments = [] }
                if let idx = notebook.textAttachments?.firstIndex(where: { $0.id == updated.id }) {
                    notebook.textAttachments?[idx] = updated
                } else {
                    notebook.textAttachments?.append(updated)
                }
                activeTextDraft = updated
                onCommit()
            }
        )
    }

    public var body: some View {
        ScrollView([.vertical, .horizontal], showsIndicators: true) {
            VStack(spacing: 24) {
                // 居中的 A4 標準文件卡片（如同 Google 文件或 Word 頁面配置模式）
                VStack(alignment: .leading, spacing: 16) {
                    // 文件主要流式文字輸入區域
                    documentBodyTextEditor

                    // 嵌入本頁面的局部手繪畫布塊（若有啟用或已繪製）
                    if activeInlineInkBlockId != nil || (notebook.recognizedText?[String(pageIndex)] != nil) {
                        documentEmbeddedDrawingBlock
                    }

                    // 嵌入本頁面的表格物件
                    ForEach(notebook.tableAttachments ?? []) { table in
                        if table.pageIndex == pageIndex {
                            documentEmbeddedTableView(table)
                        }
                    }

                    // 嵌入本頁面的圖片物件
                    ForEach(notebook.attachments ?? []) { img in
                        if img.pageIndex == pageIndex {
                            documentEmbeddedImageView(img)
                        }
                    }

                    Spacer(minLength: 160)
                }
                .padding(.horizontal, 48)
                .padding(.vertical, 56)
                .frame(width: 760) // 標準 A4 寬度（約 760-800pt）
                .frame(minHeight: 1040)
                .background(Color.white)
                .cornerRadius(4)
                .shadow(color: Color.black.opacity(0.12), radius: 10, y: 5)
                .padding(.vertical, 24)
                .onTapGesture {
                    isDocumentBodyFocused = true
                }
            }
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    @ViewBuilder
    private var documentBodyTextEditor: some View {
        ZStack(alignment: .topLeading) {
            if pageMainTextBinding.wrappedValue.text.isEmpty {
                Text(localizationManager.localized("text_placeholder"))
                    .font(resolveFont(for: pageMainTextBinding.wrappedValue))
                    .foregroundColor(Color.secondary.opacity(0.45))
                    .padding(.top, 8)
                    .allowsHitTesting(false)
            }

            TextEditor(text: pageMainTextBinding.text)
                .font(resolveFont(for: pageMainTextBinding.wrappedValue))
                .foregroundColor(Color(hex: pageMainTextBinding.wrappedValue.textColorHex) ?? .primary)
                .multilineTextAlignment(resolveMultilineAlignment(pageMainTextBinding.wrappedValue.alignmentRaw))
                .lineSpacing(pageMainTextBinding.wrappedValue.lineSpacing ?? 4)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .frame(minHeight: 240)
                .focused($isDocumentBodyFocused)
                .onChange(of: pageMainTextBinding.wrappedValue.text) { _ in
                    activeTextDraft = pageMainTextBinding.wrappedValue
                    onCommit()
                }
        }
    }

    @ViewBuilder
    private var documentEmbeddedDrawingBlock: some View {
        let isFocused = (activeInlineInkBlockId == "page-\(pageIndex)-ink")
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "pencil.and.outline")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 13))
                Text(localizationManager.localized("wd_inline_canvas"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                if isFocused {
                    Text("• " + localizationManager.localized("wd_editing_ink_mode"))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.accentColor)
                }
                Spacer()
                Button(role: .destructive) {
                    withAnimation {
                        activeInlineInkBlockId = nil
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)

            // 局部繪圖卡片
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(uiColor: .tertiarySystemGroupedBackground).opacity(0.6))
                    .frame(height: 280)

                VStack(spacing: 8) {
                    Image(systemName: "hand.draw")
                        .font(.system(size: 28))
                        .foregroundColor(.accentColor.opacity(0.8))
                    Text(localizationManager.localized("wd_tap_to_draw"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: 280)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isFocused ? Color.accentColor : Color.secondary.opacity(0.25), lineWidth: isFocused ? 2 : 1)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation {
                    activeInlineInkBlockId = "page-\(pageIndex)-ink"
                }
            }
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func documentEmbeddedTableView(_ table: NoteTableAttachment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "tablecells")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 13))
                Text(localizationManager.localized("table"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Button(role: .destructive) {
                    notebook.tableAttachments?.removeAll { $0.id == table.id }
                    onCommit()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)

            // 內嵌直接展示與編輯之表格
            VStack(spacing: 0) {
                ForEach(0..<Int(table.rows), id: \.self) { r in
                    HStack(spacing: 0) {
                        ForEach(0..<Int(table.cols), id: \.self) { c in
                            let index = r * Int(table.cols) + c
                            let cellText = (index < table.cells.count) ? table.cells[index] : ""
                            let isHeader = (r == 0 && table.headerRow)

                            TextField("", text: Binding(
                                get: { cellText },
                                set: { newVal in
                                    if let tIdx = notebook.tableAttachments?.firstIndex(where: { $0.id == table.id }) {
                                        var cells = notebook.tableAttachments?[tIdx].cells ?? []
                                        while cells.count <= index { cells.append("") }
                                        cells[index] = newVal
                                        notebook.tableAttachments?[tIdx].cells = cells
                                        onCommit()
                                    }
                                }
                            ))
                            .font(.system(size: table.fontSize, weight: isHeader ? .bold : .regular))
                            .padding(8)
                            .background(isHeader ? Color.secondary.opacity(0.12) : Color.clear)
                            .border(Color.secondary.opacity(0.25), width: 0.5)
                        }
                    }
                }
            }
            .background(Color.white)
            .cornerRadius(4)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.3), lineWidth: 1))
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func documentEmbeddedImageView(_ img: NoteImageAttachment) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let uiImg = NotebookStore.shared.loadAttachmentImage(fileName: img.fileName) {
                Image(uiImage: uiImg)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: min(img.width, 640))
                    .cornerRadius(6)
                    .shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
            }
        }
        .padding(.vertical, 8)
    }

    private func resolveFont(for item: NoteTextAttachment) -> Font {
        let size = item.fontSize > 0 ? item.fontSize : 15
        let weight: Font.Weight = item.isBold ? .bold : .regular
        let design: Font.Design
        if let family = item.fontFamily {
            if family.contains("Georgia") { design = .serif }
            else if family.contains("Courier") { design = .monospaced }
            else if family.contains("Rounded") { design = .rounded }
            else { design = .default }
        } else {
            design = .default
        }
        return .system(size: size, weight: weight, design: design)
    }

    private func resolveMultilineAlignment(_ raw: String) -> TextAlignment {
        switch raw {
        case "center": return .center
        case "right": return .trailing
        default: return .leading
        }
    }
}
