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
    /// 目前分頁。原本所有控制項擠在同一個 520pt 寬的面板裡，
    /// 段落列與卡片列是**沒有捲軸的單列 HStack** —— 超出寬度的控制項
    /// 不是縮小，是直接被裁掉，使用者根本不知道那些功能存在。
    @State private var activeTab: Int = 0

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

    /// 自訂底色的暫存狀態。見 `backgroundSwatches` 裡的說明。
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
            tabPicker
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 8)

            Divider()

            // 容器是 FloatingPanel 的 width: 340 / maxHeight: 420。
            // 內容不可以自己訂寬度 —— 寫死比容器寬的值，超出的部分會被**往左
            // 裁掉**，標籤只剩後半段（實測看到「Alignment」變成「ment」）。
            ScrollView {
                activeTabContent
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity)
        .onChange(of: attachment) { updated in
            // 浮動面板沒有「確認」按鈕 —— 改了就算數，畫布上同步看得到。
            onSave(updated)
        }
    }

    /// 分頁切換。四類設定各自成頁，任何一頁都塞得進面板寬度。
    private var tabPicker: some View {
        Picker("", selection: $activeTab) {
            Text(localizationManager.localized("text_tab_font")).tag(0)
            Text(localizationManager.localized("paragraph_style")).tag(1)
            Text(localizationManager.localized("text_tab_style")).tag(2)
            Text(localizationManager.localized("text_tab_symbols")).tag(3)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    @ViewBuilder
    private var activeTabContent: some View {
        switch activeTab {
        case 0: fontTab
        case 1: paragraphTab
        case 2: styleTab
        default: symbolsTab
        }
    }

    // MARK: - 分頁一：字體

    private var fontTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                fontSizeMenu
                Divider().frame(height: 22)
                styleToggle("B", isOn: attachment.isBold, weight: .black) { attachment.isBold.toggle() }
                styleToggle("I", isOn: attachment.isItalic, italic: true) { attachment.isItalic.toggle() }
                styleToggle("U", isOn: attachment.isUnderline, underline: true) { attachment.isUnderline.toggle() }
                styleToggle("S", isOn: attachment.isStrikethrough, strikethrough: true) { attachment.isStrikethrough.toggle() }
                Spacer()
            }

            labeledRow(localizationManager.localized("alignment")) {
                HStack(spacing: 4) {
                    alignmentButton(icon: "text.alignleft", alignKey: "left")
                    alignmentButton(icon: "text.aligncenter", alignKey: "center")
                    alignmentButton(icon: "text.alignright", alignKey: "right")
                    alignmentButton(icon: "text.justify", alignKey: "justified")

                    Divider().frame(height: 20).padding(.horizontal, 4)

                    iconButton("list.bullet", help: "bullet_list") { insertListPrefix("• ") }
                    iconButton("list.number", help: "numbered_list") { insertListPrefix("1. ") }
                    Spacer()
                }
            }

            labeledRow(localizationManager.localized("text_color")) {
                ColorPicker("", selection: Binding(
                    get: { Color(hex: attachment.textColorHex) ?? .primary },
                    set: { attachment.textColorHex = $0.toHex() ?? "#000000" }
                ))
                .labelsHidden()
                .frame(width: 28, height: 28)
                Spacer()
            }
        }
    }

    private var fontSizeMenu: some View {
        Menu {
            ForEach(fontSizes, id: \.self) { sz in
                Button("\(Int(sz)) pt") { attachment.fontSize = sz }
            }
        } label: {
            HStack(spacing: 4) {
                Text("\(Int(attachment.fontSize)) pt")
                    .font(.system(size: 13, weight: .medium))
                Image(systemName: "chevron.down").font(.system(size: 10))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.12))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    private func styleToggle(
        _ label: String,
        isOn: Bool,
        weight: Font.Weight = .bold,
        italic: Bool = false,
        underline: Bool = false,
        strikethrough: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 15, weight: weight))
                .italic(italic)
                .underline(underline)
                .strikethrough(strikethrough)
                .frame(width: 30, height: 30)
                .foregroundColor(isOn ? .white : .primary)
                .background(isOn ? Color.accentColor : Color.secondary.opacity(0.12))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .hoverHighlight()
    }

    private func iconButton(_ icon: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .frame(width: 28, height: 28)
                .background(Color.secondary.opacity(0.12))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .hoverHighlight()
        .help(localizationManager.localized(help))
    }

    // MARK: - 分頁二：段落

    /// 四個間距控制項排成兩欄。
    ///
    /// 原本是一列四個並排，在 520pt 裡放不下 —— 而且那一列**沒有捲軸**，
    /// 排在後面的「首行」與「縮排」直接看不到。
    private var paragraphTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            spacingGrid
        }
    }

    private var spacingGrid: some View {
        let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            stepperControl(
                label: localizationManager.localized("line_spacing"),
                value: Binding(get: { attachment.lineSpacing ?? 0 },
                               set: { attachment.lineSpacing = $0 }),
                range: 0...24, step: 2)
            stepperControl(
                label: localizationManager.localized("paragraph_spacing"),
                value: Binding(get: { attachment.paragraphSpacing ?? 0 },
                               set: { attachment.paragraphSpacing = $0 }),
                range: 0...40, step: 4)
            stepperControl(
                label: localizationManager.localized("first_line_indent"),
                value: Binding(get: { attachment.firstLineIndent ?? 0 },
                               set: { attachment.firstLineIndent = $0 }),
                range: 0...64, step: 8)
            stepperControl(
                label: localizationManager.localized("paragraph_indent"),
                value: Binding(get: { attachment.paragraphIndent ?? 0 },
                               set: { attachment.paragraphIndent = $0 }),
                range: 0...64, step: 8)
        }
    }

    // MARK: - 分頁三：樣式（底色、邊框、圓角、寬度、旋轉）

    private var styleTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            labeledRow(localizationManager.localized("card_style")) {
                backgroundSwatches
            }

            Divider()

            // 邊框開關。畫布上那顆沒有標示的浮動小圓鈕已移除 ——
            // 同一個值有兩個入口，而其中一個看不出自己在改什麼。
            Toggle(isOn: $attachment.hasBorder) {
                Text(localizationManager.localized("border_style")).font(.callout)
            }
            .toggleStyle(.switch)

            if attachment.hasBorder {
                borderColorRow
                borderWidthRow
            }

            Divider()

            labeledRow(localizationManager.localized("corner_style")) {
                HStack(spacing: 10) {
                    ForEach([0.0, 8.0, 18.0], id: \.self) { r in
                        Button {
                            attachment.cornerRadius = CGFloat(r)
                        } label: {
                            RoundedRectangle(cornerRadius: CGFloat(r) / 2)
                                .stroke(attachment.cornerRadius == CGFloat(r) ? Color.accentColor : Color.secondary.opacity(0.5),
                                        lineWidth: attachment.cornerRadius == CGFloat(r) ? 2 : 1)
                                .frame(width: 34, height: 22)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
            }

            labeledRow(localizationManager.localized("box_width")) {
                HStack(spacing: 8) {
                    Slider(value: $attachment.width, in: 160...900, step: 10)
                    Text("\(Int(attachment.width))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 34, alignment: .trailing)
                }
            }

            Divider()

            labeledRow(localizationManager.localized("image_rotate")) {
                VStack(alignment: .leading, spacing: 6) {
                    ObjectRotationDial(degrees: $attachment.canvasRotation)
                    Text(localizationManager.localized("rotation_free_hint"))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var backgroundSwatches: some View {
        // 換行排列。原本是一列七個色票加上自訂色票器，配上右邊的邊框開關
        // 就超出面板寬度，最後幾個顏色被裁掉。
        let columns = [GridItem(.adaptive(minimum: 30), spacing: 8)]
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(cardBackgroundOptions, id: \.hex) { opt in
                Button {
                    attachment.backgroundColorHex = opt.hex
                } label: {
                    ZStack {
                        Circle()
                            .fill(opt.color)
                            .frame(width: 24, height: 24)
                            .overlay(Circle().stroke(Color.secondary.opacity(0.4), lineWidth: 1))
                        // 透明畫成一條斜線。不畫的話它跟白色長得一模一樣。
                        if opt.hex == "clear" {
                            Path { path in
                                path.move(to: CGPoint(x: 4, y: 20))
                                path.addLine(to: CGPoint(x: 20, y: 4))
                            }
                            .stroke(Color.red.opacity(0.7), lineWidth: 1.5)
                            .frame(width: 24, height: 24)
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

            // 自訂底色。綁自己的狀態、只在真的變動時寫回 ——
            // 綁衍生值的話 `toHex()` 會丟掉 alpha，剛選的「透明」立刻被覆蓋成 #000000。
            ColorPicker("", selection: $customBackground)
                .labelsHidden()
                .frame(width: 26)
                .help(localizationManager.localized("custom_color"))
                .onChange(of: customBackground) { newValue in
                    guard let hex = newValue.toHex() else { return }
                    attachment.backgroundColorHex = hex
                }
        }
    }

    private var borderColorRow: some View {
        labeledRow(localizationManager.localized("border_color")) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 28), spacing: 8)],
                      alignment: .leading, spacing: 8) {
                ForEach(borderColorOptions, id: \.self) { hex in
                    Button {
                        attachment.borderColorHex = hex
                    } label: {
                        Circle()
                            .fill(Color(hex: hex) ?? .gray)
                            .frame(width: 22, height: 22)
                            .overlay(
                                Circle().stroke(
                                    (attachment.borderColorHex ?? "#8E8E93") == hex ? Color.accentColor : Color.secondary.opacity(0.3),
                                    lineWidth: (attachment.borderColorHex ?? "#8E8E93") == hex ? 2.5 : 1)
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
            }
        }
    }

    private var borderWidthRow: some View {
        labeledRow(localizationManager.localized("border_width")) {
            HStack(spacing: 8) {
                ForEach([1.0, 2.0, 3.5], id: \.self) { w in
                    Button {
                        attachment.borderWidth = CGFloat(w)
                    } label: {
                        RoundedRectangle(cornerRadius: 2)
                            .fill((attachment.borderWidth ?? 1.5) == CGFloat(w) ? Color.accentColor : Color.secondary.opacity(0.5))
                            .frame(width: 30, height: CGFloat(w) + 1)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 6)
                            .background((attachment.borderWidth ?? 1.5) == CGFloat(w) ? Color.accentColor.opacity(0.12) : Color.clear)
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
        }
    }

    // MARK: - 分頁四：符號

    /// 符號改用會換行的格線。
    ///
    /// 原本是橫向捲軸：捲軸在觸控上還能用，但在 macOS 上沒有可見的捲軸提示，
    /// 使用者看到的就是「只有八個符號」。
    private var symbolsTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("", selection: $selectedSymbolCategory) {
                Text(localizationManager.localized("special_symbols")).tag(0)
                Text(localizationManager.localized("punctuation_marks")).tag(1)
                Text(localizationManager.localized("math_symbols")).tag(2)
                Text(localizationManager.localized("roman_numerals")).tag(3)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            let columns = [GridItem(.adaptive(minimum: 36), spacing: 6)]
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(currentSymbolList, id: \.self) { symbol in
                    Button {
                        insertSymbol(symbol)
                    } label: {
                        Text(symbol)
                            .font(.system(size: 16, weight: .medium, design: .serif))
                            .frame(minWidth: 34, minHeight: 34)
                            .foregroundColor(.primary)
                            .background(Color.secondary.opacity(0.10))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var currentSymbolList: [String] {
        switch selectedSymbolCategory {
        case 0: return specialSymbols
        case 1: return punctuationMarks
        case 2: return mathSymbols
        default: return romanNumerals
        }
    }

    // MARK: - 版面小工具

    /// 「標題在上、控制項在下」的一組。橫向擺不下就換行，不會被裁掉。
    @ViewBuilder
    private func labeledRow<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            content()
        }
    }

    private var sheetContent: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 建立新方塊時畫布上還沒有東西可看，所以 sheet 版保留預覽區。
                textEditorArea
                    .padding(16)
                    .background(Color(uiColor: .systemGroupedBackground))

                Divider()

                // 控制項與浮動面板共用同一組分頁 —— 兩種呈現各寫一套版面的話，
                // 改了其中一邊，另一邊就少一個功能。
                tabPicker
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))

                Divider()

                ScrollView {
                    activeTabContent
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
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
        .hoverHighlight()
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
