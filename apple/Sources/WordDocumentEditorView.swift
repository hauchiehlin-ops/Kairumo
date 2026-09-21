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

/// Word / Google Docs 樣式的專屬文書排版工具列
public struct WordToolbarView: View {
    @ObservedObject var localizationManager = LocalizationManager.shared
    @Binding var activeText: NoteTextAttachment
    let canUndo: Bool
    let canRedo: Bool
    let onUndo: () -> Void
    let onRedo: () -> Void
    let onInsertTable: (Int, Int) -> Void
    let onInsertImage: () -> Void
    var onInsertDrawingBlock: (() -> Void)? = nil
    let onInsertLink: () -> Void
    let onInsertDivider: () -> Void
    let onInsertTodo: () -> Void
    let onInsertBullet: () -> Void
    let onInsertNumbered: () -> Void
    let onClearFormat: () -> Void
    let onCommitChange: () -> Void

    private let textColors = ["#000000", "#4A5568", "#2B6CB0", "#C53030", "#2F855A", "#DD6B20", "#6B46C1"]
    private let highlightColors = ["clear", "#FEFCBF", "#C6F6D5", "#BEE3F8", "#FED7E2", "#E9D8FD"]

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                // 1. 復原 / 重做組
                HStack(spacing: 2) {
                    Button(action: onUndo) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canUndo)
                    .opacity(canUndo ? 1.0 : 0.4)
                    .accessibilityLabel(localizationManager.localized("undo"))

                    Button(action: onRedo) {
                        Image(systemName: "arrow.uturn.forward")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canRedo)
                    .opacity(canRedo ? 1.0 : 0.4)
                    .accessibilityLabel(localizationManager.localized("redo"))
                }
                .padding(2)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(6)

                Divider().frame(height: 20)

                // 2. 樣式階層選單（內文、標題 1、標題 2、標題 3）
                Menu {
                    Button(action: { setHeading(level: 0) }) {
                        Label(localizationManager.localized("normal_text"), systemImage: "text.alignleft")
                    }
                    Button(action: { setHeading(level: 1) }) {
                        Label(localizationManager.localized("heading_1"), systemImage: "character.size.larger")
                    }
                    Button(action: { setHeading(level: 2) }) {
                        Label(localizationManager.localized("heading_2"), systemImage: "character.size")
                    }
                    Button(action: { setHeading(level: 3) }) {
                        Label(localizationManager.localized("heading_3"), systemImage: "character.size.smaller")
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(currentHeadingTitle)
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9))
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 28)
                    .background(Color.secondary.opacity(0.12))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)

                // 3. 字型系列選單
                Menu {
                    Button(localizationManager.localized("font_system_default")) { setFontFamily(nil) }
                    Button(localizationManager.localized("font_serif")) { setFontFamily("Georgia") }
                    Button(localizationManager.localized("font_mono")) { setFontFamily("Courier New") }
                    Button(localizationManager.localized("font_rounded")) { setFontFamily("Arial Rounded MT Bold") }
                } label: {
                    HStack(spacing: 4) {
                        Text(currentFontDisplayName)
                            .font(.system(size: 12))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9))
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 28)
                    .background(Color.secondary.opacity(0.12))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)

                // 4. 字級微調 ( - / 數值 / + )
                HStack(spacing: 2) {
                    Button {
                        stepFontSize(delta: -1)
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 10, weight: .bold))
                            .frame(width: 24, height: 26)
                    }
                    .buttonStyle(.plain)

                    Text("\(Int(activeText.fontSize))")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .frame(width: 24)

                    Button {
                        stepFontSize(delta: 1)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                            .frame(width: 24, height: 26)
                    }
                    .buttonStyle(.plain)
                }
                .padding(2)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(6)

                Divider().frame(height: 20)

                // 5. 字元修飾 (B / I / U / S)
                HStack(spacing: 2) {
                    toggleButton(icon: "bold", isActive: activeText.isBold) {
                        activeText.isBold.toggle()
                        onCommitChange()
                    }
                    toggleButton(icon: "italic", isActive: activeText.isItalic) {
                        activeText.isItalic.toggle()
                        onCommitChange()
                    }
                    toggleButton(icon: "underline", isActive: activeText.isUnderline) {
                        activeText.isUnderline.toggle()
                        onCommitChange()
                    }
                    toggleButton(icon: "strikethrough", isActive: activeText.isStrikethrough) {
                        activeText.isStrikethrough.toggle()
                        onCommitChange()
                    }
                }
                .padding(2)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(6)

                // 6. 字色與醒目標示
                HStack(spacing: 4) {
                    // 字色 A
                    Menu {
                        ForEach(textColors, id: \.self) { hex in
                            Button {
                                activeText.textColorHex = hex
                                onCommitChange()
                            } label: {
                                HStack {
                                    Circle().fill(Color(hex: hex) ?? .black).frame(width: 12, height: 12)
                                    Text(hex)
                                }
                            }
                        }
                    } label: {
                        VStack(spacing: 1) {
                            Text("A")
                                .font(.system(size: 12, weight: .bold))
                            Rectangle()
                                .fill(Color(hex: activeText.textColorHex) ?? .primary)
                                .frame(width: 14, height: 3)
                        }
                        .frame(width: 28, height: 28)
                        .background(Color.secondary.opacity(0.08))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)

                    // 螢光筆標記
                    Menu {
                        Button(localizationManager.localized("no_highlight")) {
                            activeText.backgroundColorHex = "clear"
                            onCommitChange()
                        }
                        ForEach(highlightColors.filter { $0 != "clear" }, id: \.self) { hex in
                            Button {
                                activeText.backgroundColorHex = hex
                                onCommitChange()
                            } label: {
                                HStack {
                                    RoundedRectangle(cornerRadius: 3).fill(Color(hex: hex) ?? .yellow).frame(width: 14, height: 14)
                                    Text(localizationManager.localized("wd_highlight_color"))
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "highlighter")
                            .font(.system(size: 12))
                            .foregroundColor(activeText.backgroundColorHex != "clear" ? Color.orange : .primary)
                            .frame(width: 28, height: 28)
                            .background(Color.secondary.opacity(0.08))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }

                Divider().frame(height: 20)

                // 7. 對齊方式
                HStack(spacing: 2) {
                    alignButton(icon: "text.alignleft", value: "left")
                    alignButton(icon: "text.aligncenter", value: "center")
                    alignButton(icon: "text.alignright", value: "right")
                }
                .padding(2)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(6)

                // 8. 清單工具
                HStack(spacing: 2) {
                    Button(action: onInsertBullet) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 12))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(localizationManager.localized("bullet_list"))
                    .help(localizationManager.localized("bullet_list"))

                    Button(action: onInsertNumbered) {
                        Image(systemName: "list.number")
                            .font(.system(size: 12))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(localizationManager.localized("numbered_list"))
                    .help(localizationManager.localized("numbered_list"))

                    Button(action: onInsertTodo) {
                        Image(systemName: "checklist")
                            .font(.system(size: 12))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(localizationManager.localized("todo_list"))
                    .help(localizationManager.localized("todo_list"))
                }
                .padding(2)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(6)

                Divider().frame(height: 20)

                // 9. 物件插入組（表格、圖片、連結、分隔線）
                HStack(spacing: 4) {
                    // 插入表格
                    Menu {
                        ForEach([2, 3, 4, 5], id: \.self) { r in
                            ForEach([2, 3, 4, 5], id: \.self) { c in
                                Button(String(format: localizationManager.localized("table_rows_cols"), "\(r)", "\(c)")) {
                                    onInsertTable(r, c)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "tablecells")
                                .font(.system(size: 12))
                            Text(localizationManager.localized("table"))
                                .font(.system(size: 11))
                        }
                        .padding(.horizontal, 7)
                        .frame(height: 28)
                        .background(Color.secondary.opacity(0.12))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)

                    // 插入圖片
                    Button(action: onInsertImage) {
                        HStack(spacing: 3) {
                            Image(systemName: "photo")
                                .font(.system(size: 12))
                            Text(localizationManager.localized("image"))
                                .font(.system(size: 11))
                        }
                        .padding(.horizontal, 7)
                        .frame(height: 28)
                        .background(Color.secondary.opacity(0.12))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)

                    // 插入手繪區塊
                    if let onDraw = onInsertDrawingBlock {
                        Button(action: onDraw) {
                            HStack(spacing: 3) {
                                Image(systemName: "pencil.and.outline")
                                    .font(.system(size: 12))
                                Text(localizationManager.localized("wd_ink_block"))
                                    .font(.system(size: 11))
                            }
                            .padding(.horizontal, 7)
                            .frame(height: 28)
                            .background(Color.accentColor.opacity(0.15))
                            .foregroundColor(.accentColor)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(localizationManager.localized("wd_ink_block"))
                        .help(localizationManager.localized("wd_insert_inline_canvas"))
                    }

                    // 插入連結
                    Button(action: onInsertLink) {
                        Image(systemName: "link")
                            .font(.system(size: 12))
                            .frame(width: 28, height: 28)
                            .background(Color.secondary.opacity(0.12))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(localizationManager.localized("insert_link"))

                    // 插入水平分隔線
                    Button(action: onInsertDivider) {
                        Image(systemName: "divide")
                            .font(.system(size: 12))
                            .frame(width: 28, height: 28)
                            .background(Color.secondary.opacity(0.12))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(localizationManager.localized("wd_insert_divider"))
                    .help(localizationManager.localized("wd_insert_divider"))
                }

                Divider().frame(height: 20)

                // 10. 清除格式
                Button(action: onClearFormat) {
                    Image(systemName: "clear")
                        .font(.system(size: 12))
                        .frame(width: 28, height: 28)
                        .background(Color.secondary.opacity(0.08))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(localizationManager.localized("wd_clear_format"))
                .help(localizationManager.localized("wd_clear_format"))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
        }
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
    }

    private func toggleButton(icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .frame(width: 26, height: 26)
                .background(isActive ? Color.accentColor.opacity(0.25) : Color.clear)
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }

    private func alignButton(icon: String, value: String) -> some View {
        Button {
            activeText.alignmentRaw = value
            onCommitChange()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 12))
                .frame(width: 26, height: 26)
                .background(activeText.alignmentRaw == value ? Color.accentColor.opacity(0.25) : Color.clear)
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }

    private var currentHeadingTitle: String {
        if activeText.fontSize >= 26 {
            return localizationManager.localized("heading_1")
        } else if activeText.fontSize >= 20 {
            return localizationManager.localized("heading_2")
        } else if activeText.fontSize >= 17 {
            return localizationManager.localized("heading_3")
        } else {
            return localizationManager.localized("normal_text")
        }
    }

    private var currentFontDisplayName: String {
        guard let family = activeText.fontFamily, !family.isEmpty else {
            return localizationManager.localized("font_system")
        }
        if family.contains("Georgia") { return localizationManager.localized("font_serif") }
        if family.contains("Courier") { return localizationManager.localized("font_mono") }
        if family.contains("Rounded") { return localizationManager.localized("font_rounded") }
        return family
    }

    private func setHeading(level: Int) {
        switch level {
        case 1:
            activeText.fontSize = 26
            activeText.isBold = true
        case 2:
            activeText.fontSize = 20
            activeText.isBold = true
        case 3:
            activeText.fontSize = 17
            activeText.isBold = true
        default:
            activeText.fontSize = 15
            activeText.isBold = false
        }
        onCommitChange()
    }

    private func setFontFamily(_ family: String?) {
        activeText.fontFamily = family
        onCommitChange()
    }

    private func stepFontSize(delta: CGFloat) {
        let current = activeText.fontSize
        activeText.fontSize = max(10, min(72, current + delta))
        onCommitChange()
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

    @FocusState private var isDocumentBodyFocused: Bool
    @ObservedObject var localizationManager = LocalizationManager.shared

    public init(
        notebook: Binding<NotebookDocument>,
        pageIndex: Int,
        activeTextDraft: Binding<NoteTextAttachment>,
        activeInlineInkBlockId: Binding<String?>? = nil,
        onCommit: @escaping () -> Void,
        onInsertTable: @escaping () -> Void,
        onInsertImage: @escaping () -> Void
    ) {
        self._notebook = notebook
        self.pageIndex = pageIndex
        self._activeTextDraft = activeTextDraft
        self._activeInlineInkBlockId = activeInlineInkBlockId ?? .constant(nil)
        self.onCommit = onCommit
        self.onInsertTable = onInsertTable
        self.onInsertImage = onInsertImage
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
