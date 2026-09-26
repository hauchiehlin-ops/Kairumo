//
//  TableStudioView.swift
//  Kairumo
//
//  表格的插入與編修。
//
//  核心從 M0 就有完整的表格操作，但一直沒有介面可以碰到它們 ——
//  這一層把它們接出來。版面仍然由核心算（`NoteTableAttachment.layout()`），
//  所以同一張表在 Android 上長得一樣。
//

import SwiftUI

/// 畫布上的表格。
///
/// 格線與文字都照核心算好的位置畫 —— 這一層**不做任何排版**，
/// 自己再斷一次行的話，兩個平台的表格高度就會不一樣。
public struct NoteTableView: View {
    @Binding var table: NoteTableAttachment
    var isSelected: Bool
    var onEdit: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    public var body: some View {
        let layout = table.layout()
        ZStack(alignment: .topLeading) {
            // 表頭底色先畫，才會在格線與文字下面。
            ForEach(Array(layout.cells.enumerated()), id: \.offset) { _, cell in
                if cell.isHeader {
                    Rectangle()
                        .fill(headerBackground)
                        .frame(width: cell.width, height: cell.height)
                        .offset(x: cell.x, y: cell.y)
                }
            }

            Canvas { context, _ in
                var path = Path()
                for rule in layout.rules {
                    path.move(to: CGPoint(x: rule.x1, y: rule.y1))
                    path.addLine(to: CGPoint(x: rule.x2, y: rule.y2))
                }
                context.stroke(path, with: .color(ruleColor), lineWidth: 1)
            }
            .frame(width: CGFloat(layout.width), height: CGFloat(layout.height))

            ForEach(Array(layout.cells.enumerated()), id: \.offset) { _, cell in
                let rawText = table.cell(row: Int(cell.row), col: Int(cell.col))
                let displayText = TableFormulaEvaluator.evaluateCell(
                    content: rawText,
                    allCells: table.cells,
                    rows: table.rows,
                    cols: table.cols
                )
                Text(displayText.isEmpty ? cell.lines.joined(separator: "\n") : displayText)
                    .font(.system(size: table.fontSize, weight: cell.isHeader ? .semibold : .regular))
                    .frame(width: cell.width - 12, alignment: .leading)
                    .padding(6)
                    .offset(x: cell.x, y: cell.y)
            }
        }
        .frame(width: CGFloat(layout.width), height: CGFloat(layout.height), alignment: .topLeading)
        .overlay(
            Rectangle()
                .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 1.5)
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: onEdit)
    }

    private var ruleColor: Color {
        table.ruleColorHex.flatMap(Color.init(hex:)) ?? Color.primary.opacity(0.35)
    }

    private var headerBackground: Color {
        guard let hex = table.headerBackgroundHex else {
            return Color.primary.opacity(0.06)
        }
        // "clear" 是哨符不是顏色 —— 走顏色轉換會變成黑色。
        return hex == "clear" ? .clear : (Color(hex: hex) ?? Color.primary.opacity(0.06))
    }
}

/// 表格編修面板。
public struct TableStudioView: View {

    public typealias Commit = (NoteTableAttachment) -> Void

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @State private var table: NoteTableAttachment
    @State private var selectedRow: Int = 0
    @State private var selectedCol: Int = 0
    private let isEditingExisting: Bool
    private let onCommit: Commit

    public init(onCommit: @escaping Commit) {
        _table = State(initialValue: NoteTableAttachment())
        self.isEditingExisting = false
        self.onCommit = onCommit
    }

    public init(editing table: NoteTableAttachment, onCommit: @escaping Commit) {
        _table = State(initialValue: table)
        self.isEditingExisting = true
        self.onCommit = onCommit
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView([.horizontal, .vertical]) {
                    VStack(alignment: .leading, spacing: 14) {
                        preview
                        Divider()
                        grid
                    }
                    .padding(12)
                }
                Divider()
                controls
            }
            .navigationTitle(localizationManager.localized("table_studio"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizationManager.localized("cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localizationManager.localized(
                        isEditingExisting ? "table_update" : "table_insert")
                    ) {
                        onCommit(table)
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - 即時預覽

    /// 這張表插進畫布之後的樣子。
    ///
    /// 沒有它的話，欄寬、字級、合併與表頭底色都要「插進去才知道」——
    /// 而那時候面板已經關了，要改只能再打開一次。預覽與畫布走的是**同一個**
    /// `NoteTableView`，所以看到的就是會得到的。
    private var preview: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(localizationManager.localized("table_preview"))
                .font(.caption2)
                .foregroundColor(.secondary)
            NoteTableView(table: $table, isSelected: false, onEdit: {})
                // 預覽不接受點擊 —— 這裡點兩下會再開一層同樣的面板。
                .allowsHitTesting(false)
                .padding(8)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(8)
        }
    }

    // MARK: - 格子

    /// 可編輯的儲存格。
    ///
    /// **刻意不用 `Grid`。** `Grid` 在 Mac Catalyst 上放進雙向 `ScrollView`
    /// 時會塌成一格：使用者看到的是一個文字框，其餘的行列完全不見 ——
    /// 而控制列（合併、刪除欄列）仍然是正常的，所以看起來像「表格壞了」。
    /// VStack + HStack 在兩個平台上的行為一致。
    // internal（而不是 private）是為了讓測試能單獨把它算繪出來量尺寸 ——
    // 整個面板包在 `NavigationStack` 裡，`ImageRenderer` 對它回 nil。
    var grid: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(0..<table.rows, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(0..<table.cols, id: \.self) { col in
                        if table.isCovered(row: row, col: col) {
                            // 被合併蓋住的格子不給編輯 —— 它的內容不會被顯示，
                            // 讓人輸入等於讓人把字打進看不見的地方。
                            Color.clear.frame(width: 120, height: 34)
                        } else {
                            cellField(row: row, col: col)
                        }
                    }
                }
            }
        }
    }

    private func cellField(row: Int, col: Int) -> some View {
        TextField(
            "",
            text: Binding(
                get: { table.cell(row: row, col: col) },
                set: { table.setCell($0, row: row, col: col) }
            )
        )
        .textFieldStyle(.roundedBorder)
        .font(.system(size: 13, weight: row == 0 && table.headerRow ? .semibold : .regular))
        .frame(width: 120)
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(
                    row == selectedRow && col == selectedCol ? Color.accentColor : .clear,
                    lineWidth: 1.5)
        )
        .onTapGesture {
            selectedRow = row
            selectedCol = col
        }
    }

    // MARK: - 控制項

    private var controls: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(localizationManager.localized("table_header_row"), isOn: $table.headerRow)

                HStack {
                    Button {
                        table.insertRow(at: selectedRow + 1)
                    } label: {
                        Label(localizationManager.localized("table_add_row"), systemImage: "plus")
                    }
                    Spacer()
                    Button(role: .destructive) {
                        table.deleteRow(at: selectedRow)
                        selectedRow = min(selectedRow, table.rows - 1)
                    } label: {
                        Label(localizationManager.localized("table_delete_row"), systemImage: "minus")
                    }
                    .disabled(table.rows <= 1)
                }

                HStack {
                    Button {
                        table.insertColumn(at: selectedCol + 1)
                    } label: {
                        Label(localizationManager.localized("table_add_column"), systemImage: "plus")
                    }
                    Spacer()
                    Button(role: .destructive) {
                        table.deleteColumn(at: selectedCol)
                        selectedCol = min(selectedCol, table.cols - 1)
                    } label: {
                        Label(localizationManager.localized("table_delete_column"), systemImage: "minus")
                    }
                    .disabled(table.cols <= 1)
                }

                Divider()

                ViewThatFits(in: .horizontal) {
                    HStack {
                        Button {
                            table.merge(row: selectedRow, col: selectedCol, rowSpan: 1, colSpan: 2)
                        } label: {
                            Label(localizationManager.localized("table_merge_right"),
                                  systemImage: "arrow.right.to.line")
                        }
                        .disabled(selectedCol + 1 >= table.cols)

                        Spacer()

                        Button {
                            table.merge(row: selectedRow, col: selectedCol, rowSpan: 2, colSpan: 1)
                        } label: {
                            Label(localizationManager.localized("table_merge_down"),
                                  systemImage: "arrow.down.to.line")
                        }
                        .disabled(selectedRow + 1 >= table.rows)

                        Spacer()

                        Button {
                            table.unmerge(row: selectedRow, col: selectedCol)
                        } label: {
                            Label(localizationManager.localized("table_unmerge"),
                                  systemImage: "rectangle.split.2x1")
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Button {
                            table.merge(row: selectedRow, col: selectedCol, rowSpan: 1, colSpan: 2)
                        } label: {
                            Label(localizationManager.localized("table_merge_right"),
                                  systemImage: "arrow.right.to.line")
                        }
                        .disabled(selectedCol + 1 >= table.cols)

                        Button {
                            table.merge(row: selectedRow, col: selectedCol, rowSpan: 2, colSpan: 1)
                        } label: {
                            Label(localizationManager.localized("table_merge_down"),
                                  systemImage: "arrow.down.to.line")
                        }
                        .disabled(selectedRow + 1 >= table.rows)

                        Button {
                            table.unmerge(row: selectedRow, col: selectedCol)
                        } label: {
                            Label(localizationManager.localized("table_unmerge"),
                                  systemImage: "rectangle.split.2x1")
                        }
                    }
                }

                Divider()

                VStack(alignment: .leading) {
                    Text(localizationManager.localized("table_width"))
                    Slider(value: $table.width, in: 200...760)
                }
                VStack(alignment: .leading) {
                    Text(localizationManager.localized("table_font_size"))
                    Slider(value: $table.fontSize, in: 10...24, step: 1)
                }
            }
            .font(.footnote)
            .padding(12)
        }
        .frame(maxHeight: 280)
    }
}

/// 畫布上的表格物件：可拖曳、可點兩下編修、可刪除。
///
/// 拖曳走 `CanvasCoordinateSpace` 與 `dragOffset`，與文字方塊、圖片同一套 ——
/// 各寫一套的話，同一個畫布上不同物件的拖曳手感會不一樣，而使用者說不出
/// 哪裡怪，只覺得「這個東西怪怪的」。
struct TableAttachmentItemView: View {
    @Binding var table: NoteTableAttachment
    let onEdit: () -> Void
    let onDelete: () -> Void

    @ObservedObject private var localizationManager = LocalizationManager.shared
    @State private var dragOffset: CGSize = .zero
    @State private var isSelected: Bool = false
    @State private var isDragging: Bool = false

    var body: some View {
        let layout = table.layout()
        let currentX = table.x + dragOffset.width
        let currentY = table.y + dragOffset.height

        NoteTableView(table: $table, isSelected: isSelected, onEdit: onEdit)
            .shadow(color: isDragging ? .clear : Color.black.opacity(0.08), radius: 6, y: 3)
            .gesture(
                DragGesture(minimumDistance: 5, coordinateSpace: .named(CanvasCoordinateSpace.name))
                    .onChanged { value in
                        isDragging = true
                        isSelected = true
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        if hypot(value.translation.width, value.translation.height) < 4 {
                            isSelected.toggle()
                        } else {
                            table.x += dragOffset.width
                            table.y += dragOffset.height
                        }
                        dragOffset = .zero
                        isDragging = false
                    }
            )
            // 表格本體跟著轉；把手掛在旋轉**外面**的 overlay ——
            // 包進去的話拖曳算出的角度會疊加自身旋轉，表格會失控加速。
            .rotationEffect(.degrees(table.canvasRotation))
            .overlay {
                if isSelected {
                    // 尺寸取實際版面框：表格高度由列數與內容決定，
                    // 模型裡沒有可信的 height 可用。
                    GeometryReader { geo in
                        ObjectRotationHandle(degrees: $table.canvasRotation, size: geo.size)
                    }
                }
            }
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    HStack(spacing: 6) {
                        Button(action: onEdit) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(5)
                                .background(Color.blue)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(localizationManager.localized("edit"))

                        Button(role: .destructive, action: onDelete) {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(5)
                                .background(Color.red)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(localizationManager.localized("action_delete"))
                    }
                    .offset(x: 10, y: -10)
                }
            }
            .position(
                x: currentX + CGFloat(layout.width) / 2,
                y: currentY + CGFloat(layout.height) / 2
            )
            .animation(nil, value: dragOffset)
    }
}
