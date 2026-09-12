//
//  WordTextStudioView.swift
//  Kairumo
//
//  Word 級文字段落、格式、版面配置與特殊元件（符號/標點/數學/羅馬）編修中樞
//

import SwiftUI

public struct WordTextStudioView: View {
    @Binding var attachment: NoteTextAttachment
    var onSave: (NoteTextAttachment) -> Void
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var localizationManager = LocalizationManager.shared

    @State private var selectedSymbolCategory: Int = 0

    // 四大特殊元件庫
    private let specialSymbols = [
        "★", "☆", "✓", "✗", "▲", "▼", "◆", "◇",
        "●", "○", "→", "←", "↑", "↓", "⇄", "⇒",
        "※", "§", "¶", "©", "®", "™", "℃", "℉", "♥", "♦"
    ]

    private let punctuationMarks = [
        "「", "」", "『", "』", "《", "》", "〈", "〉",
        "【", "】", "〔", "〕", "——", "……", "～", "·",
        "；", "：", "？！", "“", "”", "‘", "’"
    ]

    private let mathSymbols = [
        "±", "×", "÷", "≠", "≈", "≤", "≥", "∑",
        "∏", "√", "∫", "∂", "∞", "∈", "∉", "⊂",
        "⊆", "∪", "∩", "α", "β", "γ", "θ", "λ",
        "π", "σ", "ω", "Δ", "Ω", "°"
    ]

    private let romanNumerals = [
        "Ⅰ", "Ⅱ", "Ⅲ", "Ⅳ", "Ⅴ", "Ⅵ", "Ⅶ", "Ⅷ", "Ⅸ", "Ⅹ", "Ⅺ", "Ⅻ",
        "ⅰ", "ⅱ", "ⅲ", "ⅳ", "ⅴ", "ⅵ", "ⅶ", "ⅷ", "ⅸ", "ⅹ"
    ]

    // 便簽底色選項
    private let cardBackgroundOptions: [(name: String, hex: String, color: Color)] = [
        ("純白卡片", "#FFFFFF", .white),
        ("便利貼黃", "#FFF9C4", Color(red: 1.0, green: 0.976, blue: 0.769)),
        ("清爽薄荷", "#E8F5E9", Color(red: 0.91, green: 0.96, blue: 0.91)),
        ("櫻花暖粉", "#FCE4EC", Color(red: 0.99, green: 0.89, blue: 0.93)),
        ("商務淡藍", "#E1F5FE", Color(red: 0.88, green: 0.96, blue: 0.99)),
        ("簡約淡灰", "#F5F5F5", Color(red: 0.96, green: 0.96, blue: 0.96)),
        ("透明畫布", "clear", .clear)
    ]

    // 常用字級
    private let fontSizes: [CGFloat] = [12, 14, 16, 18, 20, 24, 28, 36, 48]

    public init(attachment: Binding<NoteTextAttachment>, onSave: @escaping (NoteTextAttachment) -> Void) {
        self._attachment = attachment
        self.onSave = onSave
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 1. 🌟 Word 級格式與段落工具列 (Word Toolbar)
                wordFormatToolbar
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))

                Divider()

                // 2. 🌟 特殊元件快速插入列 (特殊符號、標點、數學、羅馬符號)
                specialElementsBar
                    .padding(.vertical, 8)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground))

                Divider()

                // 3. 🌟 主文字輸入與即時排版預覽區
                textEditorArea
                    .padding(16)
                    .background(Color(uiColor: .systemGroupedBackground))

                Divider()

                // 4. 底色與邊框版面配置列
                cardStyleBar
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
            }
            .navigationTitle(localizationManager.localized("word_studio"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizationManager.localized("cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localizationManager.localized("confirm")) {
                        onSave(attachment)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .frame(minWidth: 540, minHeight: 600)
    }

    // MARK: - 1. Word 格式工具列
    private var wordFormatToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // 字級大小選單
                Menu {
                    ForEach(fontSizes, id: \.self) { sz in
                        Button("\(Int(sz)) pt") {
                            attachment.fontSize = sz
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("\(Int(attachment.fontSize)) pt")
                            .font(.system(size: 13, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.secondary.opacity(0.12))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)

                Divider().frame(height: 20)

                // 粗體 B
                Button {
                    attachment.isBold.toggle()
                } label: {
                    Text("B")
                        .font(.system(size: 15, weight: .black))
                        .frame(width: 28, height: 28)
                        .foregroundColor(attachment.isBold ? .white : .primary)
                        .background(attachment.isBold ? Color.accentColor : Color.secondary.opacity(0.12))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)

                // 斜體 I
                Button {
                    attachment.isItalic.toggle()
                } label: {
                    Text("I")
                        .font(.system(size: 15, weight: .bold))
                        .italic()
                        .frame(width: 28, height: 28)
                        .foregroundColor(attachment.isItalic ? .white : .primary)
                        .background(attachment.isItalic ? Color.accentColor : Color.secondary.opacity(0.12))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)

                // 底線 U
                Button {
                    attachment.isUnderline.toggle()
                } label: {
                    Text("U")
                        .font(.system(size: 15, weight: .bold))
                        .underline()
                        .frame(width: 28, height: 28)
                        .foregroundColor(attachment.isUnderline ? .white : .primary)
                        .background(attachment.isUnderline ? Color.accentColor : Color.secondary.opacity(0.12))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)

                // 刪除線 S
                Button {
                    attachment.isStrikethrough.toggle()
                } label: {
                    Text("S")
                        .font(.system(size: 15, weight: .bold))
                        .strikethrough()
                        .frame(width: 28, height: 28)
                        .foregroundColor(attachment.isStrikethrough ? .white : .primary)
                        .background(attachment.isStrikethrough ? Color.accentColor : Color.secondary.opacity(0.12))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)

                Divider().frame(height: 20)

                // 段落對齊群組
                HStack(spacing: 2) {
                    alignmentButton(icon: "text.alignleft", alignKey: "left")
                    alignmentButton(icon: "text.aligncenter", alignKey: "center")
                    alignmentButton(icon: "text.alignright", alignKey: "right")
                    alignmentButton(icon: "text.justify", alignKey: "justified")
                }

                Divider().frame(height: 20)

                // 快速清單按鈕
                Button {
                    insertListPrefix("• ")
                } label: {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 13))
                        .padding(6)
                        .background(Color.secondary.opacity(0.12))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help(localizationManager.localized("bullet_list"))

                Button {
                    insertListPrefix("1. ")
                } label: {
                    Image(systemName: "list.number")
                        .font(.system(size: 13))
                        .padding(6)
                        .background(Color.secondary.opacity(0.12))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help(localizationManager.localized("numbered_list"))

                // 字體顏色選擇
                ColorPicker("", selection: Binding(
                    get: { Color(hex: attachment.textColorHex) ?? .primary },
                    set: { attachment.textColorHex = $0.toHex() ?? "#000000" }
                ))
                .labelsHidden()
                .frame(width: 28, height: 28)
            }
        }
    }

    private func alignmentButton(icon: String, alignKey: String) -> some View {
        Button {
            attachment.alignmentRaw = alignKey
        } label: {
            Image(systemName: icon)
                .font(.system(size: 13))
                .frame(width: 28, height: 28)
                .foregroundColor(attachment.alignmentRaw == alignKey ? .white : .primary)
                .background(attachment.alignmentRaw == alignKey ? Color.accentColor : Color.secondary.opacity(0.12))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 2. 特殊元件列
    private var specialElementsBar: some View {
        VStack(spacing: 6) {
            HStack {
                Picker("", selection: $selectedSymbolCategory) {
                    Text(localizationManager.localized("special_symbols")).tag(0)
                    Text(localizationManager.localized("punctuation_marks")).tag(1)
                    Text(localizationManager.localized("math_symbols")).tag(2)
                    Text(localizationManager.localized("roman_numerals")).tag(3)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 420)

                Spacer()
            }
            .padding(.horizontal)

            // 符號流覽捲軸
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    let currentList: [String] = {
                        switch selectedSymbolCategory {
                        case 0: return specialSymbols
                        case 1: return punctuationMarks
                        case 2: return mathSymbols
                        default: return romanNumerals
                        }
                    }()

                    ForEach(currentList, id: \.self) { symbol in
                        Button {
                            insertSymbol(symbol)
                        } label: {
                            Text(symbol)
                                .font(.system(size: 16, weight: .medium, design: .serif))
                                .frame(minWidth: 32, minHeight: 32)
                                .foregroundColor(.primary)
                                .background(Color(uiColor: .systemBackground))
                                .cornerRadius(6)
                                .shadow(color: Color.black.opacity(0.06), radius: 2, y: 1)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - 3. 文字輸入區域
    private var textEditorArea: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: attachment.cornerRadius)
                .fill(resolveCardBackground(attachment.backgroundColorHex))
                .shadow(color: Color.black.opacity(0.08), radius: 6, y: 3)
                .overlay(
                    RoundedRectangle(cornerRadius: attachment.cornerRadius)
                        .stroke(attachment.hasBorder ? Color.secondary.opacity(0.3) : Color.clear, lineWidth: 1)
                )

            TextEditor(text: $attachment.text)
                .font(.system(size: attachment.fontSize, weight: attachment.isBold ? .bold : .regular))
                .italic(attachment.isItalic)
                .foregroundColor(Color(hex: attachment.textColorHex) ?? .primary)
                .multilineTextAlignment(resolveTextAlignment(attachment.alignmentRaw))
                .padding(16)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
        }
        .frame(minHeight: 220)
    }

    // MARK: - 4. 版面配置與底色樣式列
    private var cardStyleBar: some View {
        HStack(spacing: 16) {
            Text(localizationManager.localized("card_style"))
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)

            // 底色選項
            HStack(spacing: 8) {
                ForEach(cardBackgroundOptions, id: \.hex) { opt in
                    Button {
                        attachment.backgroundColorHex = opt.hex
                    } label: {
                        ZStack {
                            Circle()
                                .fill(opt.color)
                                .frame(width: 22, height: 22)
                                .overlay(
                                    Circle()
                                        .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
                                )

                            if attachment.backgroundColorHex == opt.hex {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .help(opt.name)
                }
            }

            Spacer()

            // 邊框開關
            Toggle("邊框", isOn: $attachment.hasBorder)
                .toggleStyle(.switch)
                .font(.caption)
                .labelsHidden()

            Text("邊框")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // 輔助函式
    private func insertSymbol(_ symbol: String) {
        attachment.text.append(symbol)
    }

    private func insertListPrefix(_ prefix: String) {
        if !attachment.text.isEmpty && !attachment.text.hasSuffix("\n") {
            attachment.text.append("\n" + prefix)
        } else {
            attachment.text.append(prefix)
        }
    }

    private func resolveCardBackground(_ hex: String) -> Color {
        if hex == "clear" { return .clear }
        return Color(hex: hex) ?? .white
    }

    private func resolveTextAlignment(_ raw: String) -> TextAlignment {
        switch raw {
        case "center": return .center
        case "right": return .trailing
        default: return .leading
        }
    }
}

// MARK: - Color Hex 擴展
extension Color {
    init?(hex: String) {
        var cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanHex.hasPrefix("#") {
            cleanHex.removeFirst()
        }
        guard cleanHex.count == 6, let intVal = UInt64(cleanHex, radix: 16) else {
            return nil
        }
        let r = Double((intVal >> 16) & 0xFF) / 255.0
        let g = Double((intVal >> 8) & 0xFF) / 255.0
        let b = Double(intVal & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }

    func toHex() -> String? {
        let uic = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard uic.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
