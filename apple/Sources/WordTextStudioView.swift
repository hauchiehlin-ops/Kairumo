//
//  WordTextStudioView.swift
//  Kairumo
//
//  Word 級文字段落、格式、版面配置與特殊元件（符號/標點/數學/羅馬）編修中樞
//

import SwiftUI

public struct WordTextStudioView: View {

    /// 這個面板怎麼被呈現。
    ///
    /// `sheet` 是建立新文字方塊時用的 —— 那時畫布上還沒有東西可看，蓋住沒關係。
    /// `inlinePanel` 是編輯既有方塊時用的：面板浮在畫布上，**不能蓋住正在改的
    /// 那個方塊**，所以不要 NavigationStack、不要取消／確認按鈕（改動即時生效）。
    public enum Presentation {
        case sheet
        case inlinePanel
    }

    @Binding var attachment: NoteTextAttachment
    var presentation: Presentation = .sheet
    var onSave: (NoteTextAttachment) -> Void
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var localizationManager = LocalizationManager.shared

    @FocusState private var isEditorFocused: Bool
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

    /// 自訂底色的暫存狀態。見 `cardStyleBar` 裡的說明。
    @State private var customBackground: Color = .white

    // 常用字級
    private let fontSizes: [CGFloat] = [12, 14, 16, 18, 20, 24, 28, 36, 48]

    public init(
        attachment: Binding<NoteTextAttachment>,
        presentation: Presentation = .sheet,
        onSave: @escaping (NoteTextAttachment) -> Void
    ) {
        self._attachment = attachment
        self.presentation = presentation
        self.onSave = onSave
    }

    public var body: some View {
        switch presentation {
        case .inlinePanel: panelContent
        case .sheet: sheetContent
        }
    }

    /// 浮動面板版：沒有導覽列，改動即時生效。
    ///
    /// 預覽區也拿掉了 —— 正在改的那個文字方塊就在畫布上，面板裡再放一份
    /// 預覽只是佔位置，而且兩份看起來不一樣的時候使用者不知道該信哪一個。
    private var panelContent: some View {
        VStack(spacing: 0) {
            wordFormatToolbar
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            Divider()

            specialElementsBar
                .padding(.vertical, 8)

            Divider()

            paragraphBar
            cardStyleBar

            borderStyleBar
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
        }
        .frame(width: 520)
        .onChange(of: attachment) { updated in
            // 浮動面板沒有「確認」按鈕 —— 改了就算數，畫布上同步看得到。
            onSave(updated)
        }
    }

    private var sheetContent: some View {
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
                paragraphBar
                cardStyleBar

                borderStyleBar
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
                .focused($isEditorFocused)
                .font(.system(size: attachment.fontSize, weight: attachment.isBold ? .bold : .regular))
                .italic(attachment.isItalic)
                .foregroundColor(Color(hex: attachment.textColorHex) ?? .primary)
                .multilineTextAlignment(resolveTextAlignment(attachment.alignmentRaw))
                .padding(16)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        isEditorFocused = true
                    }
                }
        }
        .frame(minHeight: 220)
    }

    // MARK: - 4. 版面配置與底色樣式列
    /// 段落設定。
    ///
    /// 原本只有對齊與清單 —— 那是「字」的設定，不是「段落」的設定。
    /// 行距與縮排才是讓一段文字看起來像文件而不是一團字的東西。
    private var paragraphBar: some View {
        HStack(spacing: 14) {
            Text(localizationManager.localized("paragraph_style"))
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)

            stepperControl(
                label: localizationManager.localized("line_spacing"),
                value: Binding(
                    get: { attachment.lineSpacing ?? 0 },
                    set: { attachment.lineSpacing = $0 }
                ),
                range: 0...24, step: 2)

            stepperControl(
                label: localizationManager.localized("paragraph_spacing"),
                value: Binding(
                    get: { attachment.paragraphSpacing ?? 0 },
                    set: { attachment.paragraphSpacing = $0 }
                ),
                range: 0...40, step: 4)

            stepperControl(
                label: localizationManager.localized("first_line_indent"),
                value: Binding(
                    get: { attachment.firstLineIndent ?? 0 },
                    set: { attachment.firstLineIndent = $0 }
                ),
                range: 0...64, step: 8)

            stepperControl(
                label: localizationManager.localized("paragraph_indent"),
                value: Binding(
                    get: { attachment.paragraphIndent ?? 0 },
                    set: { attachment.paragraphIndent = $0 }
                ),
                range: 0...64, step: 8)

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
    }

    /// 一個「標籤 + 減 / 數值 / 加」的小控制項。
    ///
    /// 用按鈕而不是滑桿：這些值的合理範圍很小（行距 0–24pt），滑桿在這種
    /// 範圍下很難精準，而且看不到目前是多少。
    private func stepperControl(
        label: String,
        value: Binding<CGFloat>,
        range: ClosedRange<CGFloat>,
        step: CGFloat
    ) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Button {
                value.wrappedValue = max(range.lowerBound, value.wrappedValue - step)
            } label: {
                Image(systemName: "minus").font(.system(size: 10, weight: .bold))
            }
            .buttonStyle(.plain)
            .disabled(value.wrappedValue <= range.lowerBound)

            Text("\(Int(value.wrappedValue))")
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 22)
                .monospacedDigit()

            Button {
                value.wrappedValue = min(range.upperBound, value.wrappedValue + step)
            } label: {
                Image(systemName: "plus").font(.system(size: 10, weight: .bold))
            }
            .buttonStyle(.plain)
            .disabled(value.wrappedValue >= range.upperBound)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(8)
    }

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
                            // 透明畫成一條斜線。不畫的話它跟白色長得一模一樣，
                            // 使用者根本認不出哪一個是透明。
                            if opt.hex == "clear" {
                                Path { path in
                                    path.move(to: CGPoint(x: 4, y: 18))
                                    path.addLine(to: CGPoint(x: 18, y: 4))
                                }
                                .stroke(Color.red.opacity(0.7), lineWidth: 1.5)
                                .frame(width: 22, height: 22)
                            }

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

            // 自訂底色（預設色之外想用什麼都可以）
            // 自訂底色。
            //
            // 原本綁的是**衍生值**（從 hex 算出 Color，再寫回 hex）。SwiftUI 的
            // ColorPicker 會在互動時把值寫回去，而 `toHex()` 丟掉 alpha ——
            // 於是使用者剛選的「透明」會立刻被覆蓋成 #000000。
            // 改成自己的狀態、只在真的變動時寫回，「透明」才留得住。
            ColorPicker("", selection: $customBackground)
                .labelsHidden()
                .frame(width: 26)
                .help(localizationManager.localized("custom_color"))
                .onChange(of: customBackground) { newValue in
                    guard let hex = newValue.toHex() else { return }
                    attachment.backgroundColorHex = hex
                }

            Spacer()

            // 邊框開關
            Toggle(isOn: $attachment.hasBorder) {
                Text(localizationManager.localized("border_style"))
            }
            .toggleStyle(.switch)
            .font(.caption)
            .fixedSize()
        }
    }

    /// 邊框樣式：顏色、粗細、圓角、方塊寬度
    private var borderStyleBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            if attachment.hasBorder {
                HStack(spacing: 12) {
                    Text(localizationManager.localized("border_color"))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ForEach(borderColorOptions, id: \.self) { hex in
                        Button {
                            attachment.borderColorHex = hex
                        } label: {
                            Circle()
                                .fill(Color(hex: hex) ?? .gray)
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Circle().stroke(
                                        (attachment.borderColorHex ?? "#8E8E93") == hex ? Color.accentColor : Color.secondary.opacity(0.3),
                                        lineWidth: (attachment.borderColorHex ?? "#8E8E93") == hex ? 2.5 : 1
                                    )
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    ColorPicker("", selection: Binding(
                        get: { Color(hex: attachment.borderColorHex ?? "#8E8E93") ?? .gray },
                        set: { attachment.borderColorHex = $0.toHex() ?? "#8E8E93" }
                    ))
                    .labelsHidden()
                    .frame(width: 26)

                    Divider().frame(height: 18)

                    ForEach([1.0, 2.0, 3.5], id: \.self) { w in
                        Button {
                            attachment.borderWidth = CGFloat(w)
                        } label: {
                            RoundedRectangle(cornerRadius: 2)
                                .fill((attachment.borderWidth ?? 1.5) == CGFloat(w) ? Color.accentColor : Color.secondary.opacity(0.5))
                                .frame(width: 26, height: CGFloat(w) + 1)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 4)
                                .background((attachment.borderWidth ?? 1.5) == CGFloat(w) ? Color.accentColor.opacity(0.12) : Color.clear)
                                .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()
                }
            }

            HStack(spacing: 12) {
                Text(localizationManager.localized("corner_style"))
                    .font(.caption)
                    .foregroundColor(.secondary)

                ForEach([0.0, 8.0, 18.0], id: \.self) { r in
                    Button {
                        attachment.cornerRadius = CGFloat(r)
                    } label: {
                        RoundedRectangle(cornerRadius: CGFloat(r) / 2)
                            .stroke(attachment.cornerRadius == CGFloat(r) ? Color.accentColor : Color.secondary.opacity(0.5),
                                    lineWidth: attachment.cornerRadius == CGFloat(r) ? 2 : 1)
                            .frame(width: 30, height: 20)
                    }
                    .buttonStyle(.plain)
                }

                Divider().frame(height: 18)

                Text(localizationManager.localized("box_width"))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Slider(value: $attachment.width, in: 160...900, step: 10)
                    .frame(maxWidth: 220)

                Text("\(Int(attachment.width))")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
    }

    private let borderColorOptions: [String] = ["#8E8E93", "#000000", "#0A84FF", "#34C759", "#FF9500", "#FF3B30"]

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

    /// 解析方框底色。`nil` 是舊檔沒有這個欄位（回落成白色），
    /// `"clear"` 是使用者選了透明 —— 兩者不一樣，不能混為一談。
    private func resolveCardBackground(_ hex: String?) -> Color {
        guard let hex else { return .white }
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
