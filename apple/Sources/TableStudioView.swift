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
public struct TableCellCoordinate: Equatable, Hashable, Sendable {
    public var row: Int
    public var col: Int
    public init(row: Int, col: Int) {
        self.row = row
        self.col = col
    }
}

/// 畫布上「目前的儲存格」。
///
/// 表格編修工具列（`TableRibbonToolbar`）與「表格內容」面板的插入列欄、刪除、合併／分割、
/// 九宮格對齊都以它為準。沒有它的時候，工具列只能對第 0 列或最後一列動手 ——
/// 「上方插入列」永遠插在表格最上面、「合併」永遠合併左上角四格。
///
/// 只記最後一次**點進去**的儲存格；離開編輯（換到下一格以外）不清掉，
/// 使用者點完儲存格再去按工具列時，焦點還在。
@MainActor
final class TableCellFocus: ObservableObject {
    // profile-scope: device 只記當下畫面上點中的儲存格座標（表格 id 比對不到就無效），不含使用者資料
    static let shared = TableCellFocus()

    @Published private(set) var tableId: String?
    @Published private(set) var cell: TableCellCoordinate?

    func focus(tableId: String, cell: TableCellCoordinate) {
        if self.tableId != tableId { self.tableId = tableId }
        if self.cell != cell { self.cell = cell }
    }

    /// 這張表目前的儲存格，夾回表格範圍內（刪列欄之後不會指到不存在的格子）。
    func cell(in table: NoteTableAttachment) -> TableCellCoordinate? {
        guard tableId == table.id, let cell else { return nil }
        return TableCellCoordinate(
            row: min(max(0, cell.row), table.rows - 1),
            col: min(max(0, cell.col), table.cols - 1))
    }
}

public struct NoteTableView: View {
    @Binding var table: NoteTableAttachment
    var isSelected: Bool
    var onEdit: () -> Void
    var isInlineEditable: Bool
    @Binding var editingCell: TableCellCoordinate?

    @Environment(\.colorScheme) private var colorScheme

    public init(
        table: Binding<NoteTableAttachment>,
        isSelected: Bool,
        onEdit: @escaping () -> Void,
        isInlineEditable: Bool = false,
        editingCell: Binding<TableCellCoordinate?> = .constant(nil)
    ) {
        self._table = table
        self.isSelected = isSelected
        self.onEdit = onEdit
        self.isInlineEditable = isInlineEditable
        self._editingCell = editingCell
    }

    public var body: some View {
        let layout = table.resolvedLayout()
        ZStack(alignment: .topLeading) {
            // 底色先畫，才會在格線與文字下面：表頭底色 → 逐格底色（可蓋掉表頭色）。
            ForEach(Array(layout.cells.enumerated()), id: \.offset) { _, cell in
                if let fill = cellFill(cell) {
                    Rectangle()
                        .fill(fill)
                        .frame(width: cell.width, height: cell.height)
                        .offset(x: cell.x, y: cell.y)
                }
            }

            Canvas { context, _ in
                var path = Path()
                for rule in layout.rules {
                    path.move(to: rule.0)
                    path.addLine(to: rule.1)
                }
                let lineWidth = table.resolvedBorderWidth
                context.stroke(
                    path, with: .color(ruleColor),
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        dash: table.resolvedBorderStyle.dashPattern(lineWidth: lineWidth)))
            }
            .frame(width: layout.width, height: layout.height)

            ForEach(Array(layout.cells.enumerated()), id: \.offset) { _, cell in
                let r = cell.row
                let c = cell.col
                let isEditingThis = isInlineEditable && editingCell == TableCellCoordinate(row: r, col: c)

                if isEditingThis {
                    NoteTableInlineEditor(
                        text: Binding(
                            get: { table.cell(row: r, col: c) },
                            set: { table.setCell($0, row: r, col: c) }
                        ),
                        font: cell.style.resolvedFont(baseSize: table.fontSize, isHeader: cell.isHeader),
                        alignment: cell.style.hAlign ?? .left,
                        vAlign: cell.style.vAlign ?? .top,
                        width: cell.width,
                        height: cell.height,
                        x: cell.x,
                        y: cell.y,
                        onSubmit: {
                            let nextCol = c + 1
                            if nextCol < table.cols {
                                editingCell = TableCellCoordinate(row: r, col: nextCol)
                            } else {
                                let nextRow = r + 1
                                if nextRow < table.rows {
                                    editingCell = TableCellCoordinate(row: nextRow, col: 0)
                                } else {
                                    editingCell = nil
                                }
                            }
                        }
                    )
                } else {
                    TableCellText(cell: cell)
                        // 點擊範圍是**整格**，不是文字那一行：原本空白格只有上緣 12pt 點得到，
                        // 打字模式下點表格其他地方沒有任何反應（選不起來、不出工具列、進不了儲存格）。
                        .contentShape(Rectangle())
                        .offset(x: cell.x, y: cell.y)
                        .onTapGesture {
                            editingCell = TableCellCoordinate(row: r, col: c)
                        }
                }
            }
        }
        .frame(width: layout.width, height: layout.height, alignment: .topLeading)
        .overlay(
            Rectangle()
                .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 1.5)
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: onEdit)
        // 「表格內容 › 替代文字」落地：VoiceOver 念的是使用者寫的標題與描述。
        .accessibilityElement(children: .contain)
        .accessibilityLabel(table.altTitle ?? "")
        .accessibilityHint(table.altDescription ?? "")
    }

    /// 與縮圖同一個判斷（`fillRole`），畫布與預覽才同源（I4）。
    private func cellFill(_ cell: ResolvedTableCell) -> Color? {
        switch table.fillRole(row: cell.row, col: cell.col, isHeader: cell.isHeader) {
        case .own: return cell.style.resolvedFill
        case .header: return headerBackground
        case .bandedRow: return Color.primary.opacity(0.04)
        case .bandedColumn: return Color.primary.opacity(0.025)
        case nil: return nil
        }
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

/// 一格的文字：字體、顏色、水平／垂直對齊、方向與換行。
private struct TableCellText: View {
    let cell: ResolvedTableCell

    /// 水平／垂直對齊換成 SwiftUI 的三種對齊值。
    private static func alignments(_ style: NoteTableCellStyle) -> (text: TextAlignment, frame: Alignment) {
        let horizontal: HorizontalAlignment
        let text: TextAlignment
        switch style.hAlign ?? .left {
        case .left: horizontal = .leading; text = .leading
        case .center: horizontal = .center; text = .center
        case .right: horizontal = .trailing; text = .trailing
        }
        let vertical: VerticalAlignment
        switch style.vAlign ?? .top {
        case .top: vertical = .top
        case .middle: vertical = .center
        case .bottom: vertical = .bottom
        }
        return (text, Alignment(horizontal: horizontal, vertical: vertical))
    }

    var body: some View {
        let style = cell.style
        let rotation = style.textRotation ?? 0
        let inset = NoteTableAttachment.cellInset
        let rotated = rotation != 0
        let boxW = max(1, (rotated ? cell.height : cell.width) - inset * 2)
        let boxH = max(1, (rotated ? cell.width : cell.height) - inset * 2)
        let font = style.resolvedFont(baseSize: cell.fontSize, isHeader: cell.isHeader)
        let wrap = style.wrap ?? true

        let alignment = Self.alignments(style)

        Text(cell.text)
            .font(Font(font as CTFont))
            .underline(style.underline == true)
            .strikethrough(style.strikethrough == true)
            .foregroundColor(style.resolvedTextColor ?? .primary)
            .multilineTextAlignment(alignment.text)
            .fixedSize(horizontal: !wrap, vertical: false)
            .frame(width: boxW, height: boxH, alignment: alignment.frame)
            .clipped()
            .rotationEffect(.degrees(Double(rotation)))
            .frame(width: cell.width, height: cell.height)
    }
}

private struct NoteTableInlineEditor: View {
    @Binding var text: String
    let font: UIFont
    let alignment: TableHAlign
    var vAlign: TableVAlign = .bottom
    let width: CGFloat
    let height: CGFloat
    let x: CGFloat
    let y: CGFloat
    let onSubmit: () -> Void

    @FocusState private var isFieldFocused: Bool

    var body: some View {
        let fieldH = min(height - 4, font.lineHeight + 6)
        let offsetY: CGFloat = switch vAlign {
        case .top: y + 2
        case .middle: y + max(2, (height - fieldH) / 2)
        case .bottom: y + max(2, height - fieldH - 2)
        }
        return TextField("", text: $text)
            .focused($isFieldFocused)
            .textFieldStyle(.plain)
            .font(Font(font as CTFont))
            .multilineTextAlignment(textAlignment)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(Color(uiColor: .systemBackground).opacity(0.96))
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.accentColor, lineWidth: 2)
            )
            .frame(width: max(20, width - 6), height: fieldH, alignment: .leading)
            .offset(x: x + 3, y: offsetY)
            .onSubmit(onSubmit)
            .onAppear {
                isFieldFocused = true
            }
    }

    private var textAlignment: TextAlignment {
        switch alignment {
        case .left: return .leading
        case .center: return .center
        case .right: return .trailing
        }
    }
}

/// 表格編修面板。
///
/// 版面仿 Office：上（寬螢幕時在左）是**整張表的即時預覽**，縮放到看得到全貌，
/// 可以直接點、拖出儲存格範圍；下（右）是三個分頁 —— 內容、格式（字體／對齊／方向／換行）、
/// 表格（列欄、合併、欄寬列高、框線）。所有格式都作用在選取的範圍上。
public struct TableStudioView: View {

    public typealias Commit = (NoteTableAttachment) -> Void

    private enum Tab: Hashable { case content, format, table }

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @State private var table: NoteTableAttachment
    /// 選取範圍的兩個對角。單一儲存格時兩者相同。
    @State private var anchor = TableCellCoordinate(row: 0, col: 0)
    @State private var extent = TableCellCoordinate(row: 0, col: 0)
    @State private var tab: Tab = .content
    @FocusState private var activeCellKey: String?
    @State private var isCompactColumns: Bool = false
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
            GeometryReader { geo in
                if geo.size.width >= 820 {
                    HStack(spacing: 0) {
                        previewPane
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        Divider()
                        inspector
                            .frame(width: min(440, geo.size.width * 0.42))
                    }
                } else {
                    VStack(spacing: 0) {
                        previewPane
                            .frame(height: max(180, geo.size.height * 0.40))
                        Divider()
                        inspector
                    }
                }
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

    // MARK: - 選取範圍

    private var selRows: ClosedRange<Int> {
        let lo = max(0, min(anchor.row, extent.row))
        let hi = min(table.rows - 1, max(anchor.row, extent.row))
        return lo...max(lo, hi)
    }

    private var selCols: ClosedRange<Int> {
        let lo = max(0, min(anchor.col, extent.col))
        let hi = min(table.cols - 1, max(anchor.col, extent.col))
        return lo...max(lo, hi)
    }

    private var isSingleCell: Bool { selRows.count == 1 && selCols.count == 1 }

    private func select(_ cell: TableCellCoordinate) {
        anchor = cell
        extent = cell
    }

    private func clampSelection() {
        anchor = TableCellCoordinate(
            row: min(max(0, anchor.row), table.rows - 1), col: min(max(0, anchor.col), table.cols - 1))
        extent = TableCellCoordinate(
            row: min(max(0, extent.row), table.rows - 1), col: min(max(0, extent.col), table.cols - 1))
    }

    private var selectionLabel: String {
        let first = "\(columnLabel(for: selRows.isEmpty ? 0 : selCols.lowerBound))\(selRows.lowerBound + 1)"
        if isSingleCell { return first }
        return "\(first):\(columnLabel(for: selCols.upperBound))\(selRows.upperBound + 1)"
    }

    /// 選取範圍左上角那一格的格式 —— 面板上的開關與數值都讀它。
    private var currentStyle: NoteTableCellStyle {
        table.style(row: selRows.lowerBound, col: selCols.lowerBound)
    }

    private func applyStyle(_ change: (inout NoteTableCellStyle) -> Void) {
        table.updateStyle(rows: selRows, cols: selCols, change)
    }

    private func columnLabel(for col: Int) -> String {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        return col < alphabet.count ? String(alphabet[col]) : "\(col + 1)"
    }

    // MARK: - 預覽（整張表）

    /// 這張表插進畫布之後的樣子，**縮放到看得到全貌**，不用捲動。
    ///
    /// 預覽與畫布走的是**同一個** `NoteTableView`，所以看到的就是會得到的。
    /// 在預覽上點一下選一格、拖曳選一個範圍。
    private var previewPane: some View {
        let layout = table.resolvedLayout()
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(localizationManager.localized("table_preview"))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(table.rows) × \(table.cols)  ·  \(selectionLabel)")
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(.secondary)
            }
            GeometryReader { geo in
                let availW = max(1, geo.size.width - 24)
                let availH = max(1, geo.size.height - 24)
                let scale = min(1, availW / max(1, layout.width), availH / max(1, layout.height))
                let selected = layout.rect(rows: selRows, cols: selCols)
                ZStack {
                    Color(uiColor: .secondarySystemGroupedBackground)
                    NoteTableView(table: $table, isSelected: false, onEdit: {})
                        .allowsHitTesting(false)
                        .overlay(alignment: .topLeading) {
                            Rectangle()
                                .fill(Color.accentColor.opacity(0.12))
                                .overlay(
                                    Rectangle().strokeBorder(Color.accentColor, lineWidth: 2 / max(scale, 0.2)))
                                .frame(width: selected.width, height: selected.height)
                                .offset(x: selected.minX, y: selected.minY)
                                .allowsHitTesting(false)
                        }
                        .frame(width: layout.width, height: layout.height)
                        .scaleEffect(scale, anchor: .center)
                        .frame(width: layout.width * scale, height: layout.height * scale)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let start = CGPoint(x: value.startLocation.x / scale, y: value.startLocation.y / scale)
                                    let now = CGPoint(x: value.location.x / scale, y: value.location.y / scale)
                                    guard let first = layout.cellCoordinate(at: start) else { return }
                                    anchor = first
                                    extent = layout.cellCoordinate(at: now) ?? first
                                }
                        )
                }
                .cornerRadius(8)
                .overlay(alignment: .bottomTrailing) {
                    if scale < 0.999 {
                        Text("\(Int(scale * 100))%")
                            .font(.caption2.monospacedDigit())
                            .padding(4)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(12)
    }

    // MARK: - 檢視器（三個分頁）

    private var inspector: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                Text(localizationManager.localized("table_tab_content")).tag(Tab.content)
                Text(localizationManager.localized("table_tab_format")).tag(Tab.format)
                Text(localizationManager.localized("table_tab_table")).tag(Tab.table)
            }
            .pickerStyle(.segmented)
            .padding(12)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    switch tab {
                    case .content: contentTab
                    case .format: formatTab
                    case .table: tableTab
                    }
                }
                .font(.footnote)
                .padding(14)
            }
        }
    }

    // MARK: 分頁一：內容

    private var cellWidth: CGFloat {
        if isCompactColumns { return 82 }
        return table.cols >= 6 ? 96 : 120
    }

    private var contentTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(localizationManager.localized("table_cell_content"))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                if table.cols >= 4 {
                    Button {
                        withAnimation { isCompactColumns.toggle() }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isCompactColumns ? "arrow.left.and.right" : "arrow.right.and.line.vertical.and.arrow.left")
                            Text(localizationManager.localized(isCompactColumns ? "table_col_width_standard" : "table_col_width_compact"))
                        }
                        .font(.caption2)
                    }
                    .buttonStyle(.bordered)
                }
            }
            if table.cols > 4 {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.left.and.right")
                        .font(.caption2)
                    Text(localizationManager.localized("table_horizontal_scroll_hint"))
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }
            ScrollView(.horizontal, showsIndicators: true) {
                grid
                    .padding(.vertical, 4)
            }
        }
    }

    /// 可編輯的儲存格。
    var grid: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 欄位標籤 (A, B, C...)：點一下選整欄。
            HStack(spacing: 4) {
                Text("")
                    .frame(width: 28, height: 20)
                ForEach(0..<table.cols, id: \.self) { col in
                    Button {
                        anchor = TableCellCoordinate(row: 0, col: col)
                        extent = TableCellCoordinate(row: table.rows - 1, col: col)
                    } label: {
                        Text(columnLabel(for: col))
                            .font(.caption2.bold())
                            .foregroundColor(selCols.contains(col) ? .accentColor : .secondary)
                            .frame(width: cellWidth, height: 20)
                            .background(Color.secondary.opacity(0.08))
                            .cornerRadius(3)
                    }
                    .buttonStyle(.plain)
                }
            }

            ForEach(0..<table.rows, id: \.self) { row in
                HStack(spacing: 4) {
                    // 列號：點一下選整列。
                    Button {
                        anchor = TableCellCoordinate(row: row, col: 0)
                        extent = TableCellCoordinate(row: row, col: table.cols - 1)
                    } label: {
                        Text("\(row + 1)")
                            .font(.caption2.bold())
                            .foregroundColor(selRows.contains(row) ? .accentColor : .secondary)
                            .frame(width: 28)
                    }
                    .buttonStyle(.plain)
                    ForEach(0..<table.cols, id: \.self) { col in
                        if table.isCovered(row: row, col: col) {
                            // 被合併蓋住的格子不給編輯 —— 它的內容不會被顯示，
                            // 讓人輸入等於讓人把字打進看不見的地方。
                            Color.clear.frame(width: cellWidth, height: 34)
                        } else {
                            cellField(row: row, col: col)
                        }
                    }
                }
            }
        }
    }

    private func cellField(row: Int, col: Int) -> some View {
        let cellKey = "\(row),\(col)"
        let inSelection = selRows.contains(row) && selCols.contains(col)
        return TextField(
            "",
            text: Binding(
                get: { table.cell(row: row, col: col) },
                set: { table.setCell($0, row: row, col: col) }
            )
        )
        .focused($activeCellKey, equals: cellKey)
        .textFieldStyle(.roundedBorder)
        .font(.system(size: 13, weight: row == 0 && table.headerRow ? .semibold : .regular))
        .frame(width: cellWidth)
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(inSelection ? Color.accentColor : .clear, lineWidth: 1.5)
                .allowsHitTesting(false)
        )
        .onChange(of: activeCellKey) { key in
            if key == cellKey {
                select(TableCellCoordinate(row: row, col: col))
            }
        }
    }

    // MARK: 分頁二：格式

    private var formatTab: some View {
        let style = currentStyle
        let isHeaderCell = table.headerRow && selRows.lowerBound == 0
        return VStack(alignment: .leading, spacing: 14) {
            selectionBar

            sectionTitle("table_section_font")
            HStack(spacing: 8) {
                toggleButton("bold", "table_text_bold", style.bold ?? isHeaderCell) {
                    let next = !(style.bold ?? isHeaderCell)
                    applyStyle { $0.bold = next }
                }
                toggleButton("italic", "table_text_italic", style.italic == true) {
                    let next = !(style.italic == true)
                    applyStyle { $0.italic = next ? true : nil }
                }
                toggleButton("underline", "table_text_underline", style.underline == true) {
                    let next = !(style.underline == true)
                    applyStyle { $0.underline = next ? true : nil }
                }
                toggleButton("strikethrough", "table_text_strike", style.strikethrough == true) {
                    let next = !(style.strikethrough == true)
                    applyStyle { $0.strikethrough = next ? true : nil }
                }
            }
            Stepper(
                value: Binding(
                    get: { Double(style.fontSize ?? table.fontSize) },
                    set: { value in applyStyle { $0.fontSize = CGFloat(value) } }
                ), in: 8...48, step: 1
            ) {
                HStack {
                    Text(localizationManager.localized("table_cell_font_size"))
                    Text("\(Int(style.fontSize ?? table.fontSize))")
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                }
            }
            colorRow(
                "table_text_color", hex: style.textColorHex, fallback: .primary,
                set: { hex in applyStyle { $0.textColorHex = hex } })
            colorRow(
                "table_fill_color", hex: style.fillHex == "clear" ? nil : style.fillHex, fallback: .clear,
                set: { hex in applyStyle { $0.fillHex = hex } })

            Divider()
            sectionTitle("table_section_align")
            labeledPicker(
                "table_align_h",
                selection: Binding(
                    get: { style.hAlign ?? .left },
                    set: { value in applyStyle { $0.hAlign = value == .left ? nil : value } })
            ) {
                Text(localizationManager.localized("table_align_left")).tag(TableHAlign.left)
                Text(localizationManager.localized("table_align_center")).tag(TableHAlign.center)
                Text(localizationManager.localized("table_align_right")).tag(TableHAlign.right)
            }
            labeledPicker(
                "table_align_v",
                selection: Binding(
                    get: { style.vAlign ?? .top },
                    set: { value in applyStyle { $0.vAlign = value == .top ? nil : value } })
            ) {
                Text(localizationManager.localized("table_align_top")).tag(TableVAlign.top)
                Text(localizationManager.localized("table_align_middle")).tag(TableVAlign.middle)
                Text(localizationManager.localized("table_align_bottom")).tag(TableVAlign.bottom)
            }
            labeledPicker(
                "table_text_direction",
                selection: Binding(
                    get: { style.textRotation ?? 0 },
                    set: { value in applyStyle { $0.textRotation = value == 0 ? nil : value } })
            ) {
                Text(localizationManager.localized("table_dir_horizontal")).tag(0)
                Text(localizationManager.localized("table_dir_rotate_cw")).tag(90)
                Text(localizationManager.localized("table_dir_rotate_ccw")).tag(270)
            }
            Toggle(
                localizationManager.localized("table_wrap"),
                isOn: Binding(
                    get: { style.wrap ?? true },
                    set: { value in applyStyle { $0.wrap = value ? nil : false } }))

            Divider()
            Button(role: .destructive) {
                table.clearStyles(rows: selRows, cols: selCols)
            } label: {
                Label(localizationManager.localized("table_clear_format"), systemImage: "eraser")
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: 分頁三：表格

    private var tableTab: some View {
        let layout = table.resolvedLayout()
        return VStack(alignment: .leading, spacing: 14) {
            selectionBar

            sectionTitle("table_section_structure")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach([(2, 2), (3, 3), (4, 4), (5, 3), (3, 5), (6, 4)], id: \.0) { r, c in
                        Button("\(r) × \(c)") {
                            table.resizeGrid(newRows: r, newCols: c)
                            clampSelection()
                        }
                        .buttonStyle(.bordered)
                        .tint(table.rows == r && table.cols == c ? Color.accentColor : Color.secondary)
                    }
                }
            }
            HStack {
                Stepper(value: Binding(
                    get: { table.rows },
                    set: { table.resizeGrid(newRows: $0, newCols: table.cols); clampSelection() }
                ), in: 1...40) {
                    Text("\(table.rows) \(localizationManager.localized("table_add_row"))")
                }
                Stepper(value: Binding(
                    get: { table.cols },
                    set: { table.resizeGrid(newRows: table.rows, newCols: $0); clampSelection() }
                ), in: 1...16) {
                    Text("\(table.cols) \(localizationManager.localized("table_add_column"))")
                }
            }
            Toggle(localizationManager.localized("table_header_row"), isOn: $table.headerRow)

            wrapRow {
                Button { table.insertRow(at: selRows.lowerBound) } label: {
                    Label(localizationManager.localized("table_insert_row_above"), systemImage: "arrow.up.to.line")
                }
                Button { table.insertRow(at: selRows.upperBound + 1) } label: {
                    Label(localizationManager.localized("table_insert_row_below"), systemImage: "arrow.down.to.line")
                }
                Button(role: .destructive) {
                    for r in selRows.reversed() { table.deleteRow(at: r) }
                    clampSelection()
                } label: {
                    Label(localizationManager.localized("table_delete_row"), systemImage: "minus")
                }
                .disabled(selRows.count >= table.rows)
            }
            wrapRow {
                Button { table.insertColumn(at: selCols.lowerBound) } label: {
                    Label(localizationManager.localized("table_insert_col_left"), systemImage: "arrow.left.to.line")
                }
                Button { table.insertColumn(at: selCols.upperBound + 1) } label: {
                    Label(localizationManager.localized("table_insert_col_right"), systemImage: "arrow.right.to.line")
                }
                Button(role: .destructive) {
                    for c in selCols.reversed() { table.deleteColumn(at: c) }
                    clampSelection()
                } label: {
                    Label(localizationManager.localized("table_delete_column"), systemImage: "minus")
                }
                .disabled(selCols.count >= table.cols)
            }
            wrapRow {
                Button {
                    table.mergeRange(rows: selRows, cols: selCols)
                    select(TableCellCoordinate(row: selRows.lowerBound, col: selCols.lowerBound))
                } label: {
                    Label(localizationManager.localized("table_merge_selection"), systemImage: "rectangle.compress.vertical")
                }
                .disabled(isSingleCell)
                Button {
                    table.unmerge(row: selRows.lowerBound, col: selCols.lowerBound)
                } label: {
                    Label(localizationManager.localized("table_unmerge"), systemImage: "rectangle.split.2x1")
                }
            }

            Divider()
            sectionTitle("table_section_size")
            Stepper(
                value: Binding(
                    get: { Double(layout.columnWidths[min(selCols.lowerBound, layout.columnWidths.count - 1)]) },
                    set: { value in for c in selCols { table.setColumnWidth(value, at: c) } }
                ), in: 24...600, step: 4
            ) {
                sizeLabel("table_col_width", value: layout.columnWidths[min(selCols.lowerBound, layout.columnWidths.count - 1)],
                          isAuto: (table.columnWidthOverrides?[safe: selCols.lowerBound] ?? 0) <= 0)
            }
            Stepper(
                value: Binding(
                    get: { Double(layout.rowHeights[min(selRows.lowerBound, layout.rowHeights.count - 1)]) },
                    set: { value in for r in selRows { table.setRowHeight(value, at: r) } }
                ), in: 16...400, step: 4
            ) {
                sizeLabel("table_row_height", value: layout.rowHeights[min(selRows.lowerBound, layout.rowHeights.count - 1)],
                          isAuto: (table.rowHeightOverrides?[safe: selRows.lowerBound] ?? 0) <= 0)
            }
            wrapRow {
                Button {
                    for c in selCols { table.setColumnWidth(nil, at: c) }
                    for r in selRows { table.setRowHeight(nil, at: r) }
                } label: {
                    Label(localizationManager.localized("table_size_auto"), systemImage: "arrow.up.left.and.arrow.down.right")
                }
                Button { table.distributeColumns() } label: {
                    Label(localizationManager.localized("table_distribute_cols"), systemImage: "distribute.horizontal")
                }
                Button { table.distributeRows() } label: {
                    Label(localizationManager.localized("table_distribute_rows"), systemImage: "distribute.vertical")
                }
                Button { table.autoFitSizes() } label: {
                    Label(localizationManager.localized("table_autofit"), systemImage: "arrow.counterclockwise")
                }
            }
            VStack(alignment: .leading) {
                Text(localizationManager.localized("table_width"))
                Slider(value: $table.width, in: 120...760)
            }
            VStack(alignment: .leading) {
                Text(localizationManager.localized("table_font_size"))
                Slider(value: $table.fontSize, in: 10...24, step: 1)
            }

            Divider()
            sectionTitle("table_borders")
            labeledPicker(
                "table_borders",
                selection: Binding(
                    get: { table.borderMode ?? .all },
                    set: { table.borderMode = $0 == .all ? nil : $0 })
            ) {
                Text(localizationManager.localized("table_border_all")).tag(TableBorderMode.all)
                Text(localizationManager.localized("table_border_outer")).tag(TableBorderMode.outer)
                Text(localizationManager.localized("table_border_inner")).tag(TableBorderMode.inner)
                Text(localizationManager.localized("table_border_horizontal")).tag(TableBorderMode.horizontal)
                Text(localizationManager.localized("table_border_none")).tag(TableBorderMode.none)
            }
            colorRow(
                "table_rule_color", hex: table.ruleColorHex, fallback: .gray,
                set: { table.ruleColorHex = $0 })
            colorRow(
                "table_header_fill", hex: table.headerBackgroundHex == "clear" ? nil : table.headerBackgroundHex,
                fallback: Color.primary.opacity(0.06),
                set: { table.headerBackgroundHex = $0 })
        }
    }

    // MARK: 小元件

    /// 目前選了哪些格，加上選整列、整欄、全選。
    private var selectionBar: some View {
        HStack(spacing: 8) {
            Text("\(localizationManager.localized("table_selection")) \(selectionLabel)")
                .font(.caption.weight(.semibold))
            Spacer()
            Button(localizationManager.localized("table_select_row")) {
                anchor = TableCellCoordinate(row: selRows.lowerBound, col: 0)
                extent = TableCellCoordinate(row: selRows.upperBound, col: table.cols - 1)
            }
            Button(localizationManager.localized("table_select_col")) {
                anchor = TableCellCoordinate(row: 0, col: selCols.lowerBound)
                extent = TableCellCoordinate(row: table.rows - 1, col: selCols.upperBound)
            }
            Button(localizationManager.localized("table_select_all")) {
                anchor = TableCellCoordinate(row: 0, col: 0)
                extent = TableCellCoordinate(row: table.rows - 1, col: table.cols - 1)
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private func sectionTitle(_ key: String) -> some View {
        Text(localizationManager.localized(key))
            .font(.caption.weight(.semibold))
            .foregroundColor(.secondary)
    }

    private func toggleButton(
        _ symbol: String, _ labelKey: String, _ isOn: Bool, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 34)
                .background(isOn ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.10))
                .foregroundColor(isOn ? .accentColor : .primary)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizationManager.localized(labelKey))
        .help(localizationManager.localized(labelKey))
    }

    private func labeledPicker<T: Hashable, Content: View>(
        _ key: String, selection: Binding<T>, @ViewBuilder _ content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(localizationManager.localized(key))
                .foregroundColor(.secondary)
            Picker("", selection: selection) { content() }
                .pickerStyle(.segmented)
                .labelsHidden()
        }
    }

    /// 顏色選取＋還原預設。`hex == nil` 表示沿用預設。
    private func colorRow(
        _ key: String, hex: String?, fallback: Color, set: @escaping (String?) -> Void
    ) -> some View {
        HStack {
            ColorPicker(
                localizationManager.localized(key),
                selection: Binding(
                    get: { hex.flatMap(Color.init(hex:)) ?? fallback },
                    set: { set($0.toHex()) }),
                supportsOpacity: false)
            Button(localizationManager.localized("table_reset_color")) { set(nil) }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(hex == nil)
        }
    }

    private func sizeLabel(_ key: String, value: CGFloat, isAuto: Bool) -> some View {
        HStack(spacing: 6) {
            Text(localizationManager.localized(key))
            Text("\(Int(value.rounded()))")
                .monospacedDigit()
                .foregroundColor(.secondary)
            if isAuto {
                Text(localizationManager.localized("table_auto"))
                    .font(.caption2)
                    .padding(.horizontal, 5)
                    .background(Color.secondary.opacity(0.15))
                    .cornerRadius(4)
            }
        }
    }

    /// 一排按鈕，放不下就換行（面板寬度由視窗決定，不能假設一定放得下）。
    private func wrapRow<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { content() }
            VStack(alignment: .leading, spacing: 8) { content() }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

/// 畫布上的表格物件：可拖曳、可點兩下編修、可刪除。
///
/// 拖曳走 `CanvasCoordinateSpace` 與 `dragOffset`，與文字方塊、圖片同一套 ——
/// 各寫一套的話，同一個畫布上不同物件的拖曳手感會不一樣，而使用者說不出
/// 哪裡怪，只覺得「這個東西怪怪的」。
struct TableAttachmentItemView: View {
    @Binding var table: NoteTableAttachment
    /// 選取狀態由編輯器統一管理（畫布上同時最多一個待編輯物件）。
    var isSelected: Bool = false
    var onSelect: (() -> Void)? = nil
    var onMove: ((CGSize) -> Void)? = nil
    /// 拖右下角把手縮放到新外框（欄寬、列高等比例跟著縮放）。
    var onResize: ((CGSize) -> Void)? = nil
    let onEdit: () -> Void
    var onProperties: (() -> Void)? = nil
    let onDelete: () -> Void

    @ObservedObject private var localizationManager = LocalizationManager.shared
    @Environment(\.pageCrossing) private var pageCrossing
    @Environment(\.objectLock) private var lock
    /// 鎖定在畫布上：不能搬移、旋轉，儲存格與編修面板照常（見 `canvasLocked`）。
    @Environment(\.canvasObjectLocked) private var isCanvasLocked
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging: Bool = false
    @State private var editingCell: TableCellCoordinate? = nil
    /// 縮放把手拖曳中的位移（表格本地座標，已扣掉旋轉）。
    @State private var resizeDelta: CGSize = .zero

    var body: some View {
        let layout = table.resolvedLayout()
        let resizeScaleX = layout.width > 0 ? max(0.2, (layout.width + resizeDelta.width) / layout.width) : 1
        let resizeScaleY = layout.height > 0 ? max(0.2, (layout.height + resizeDelta.height) / layout.height) : 1
        let currentX = table.x + dragOffset.width
        let currentY = table.y + dragOffset.height

        NoteTableView(
            table: $table,
            isSelected: isSelected,
            onEdit: { (onProperties ?? onEdit)() },
            isInlineEditable: isSelected,
            editingCell: Binding(
                get: { editingCell },
                set: { newValue in
                    if let newValue {
                        onSelect?()
                        TableCellFocus.shared.focus(tableId: table.id, cell: newValue)
                    }
                    editingCell = newValue
                })
        )
            // 縮放把手拖曳中：先用便宜的縮放效果預覽，放手才重算版面（不在每一格都跑核心排版）。
            .scaleEffect(x: resizeScaleX, y: resizeScaleY, anchor: .topLeading)
            .onChange(of: isSelected) { selected in
                // 失去焦點就退出儲存格編輯。
                if !selected { editingCell = nil }
            }
            // 工具列插入列欄會把焦點儲存格往後推：正在編輯的格子跟著走，
            // 否則游標留在新插入的空白格裡，使用者接著打的字落到錯的格子。
            .onReceive(TableCellFocus.shared.$cell) { focused in
                guard editingCell != nil, TableCellFocus.shared.tableId == table.id,
                      let focused, focused != editingCell else { return }
                editingCell = focused
            }
            .shadow(color: isDragging ? .clear : Color.black.opacity(0.08), radius: 6, y: 3)
            .highPriorityGesture(
                (!isSelected || editingCell != nil || isCanvasLocked || !CanvasTouchState.canDragObject) ? nil :
                DragGesture(minimumDistance: 4, coordinateSpace: .named(CanvasCoordinateSpace.name))
                    .onChanged { value in
                        guard CanvasTouchState.canDragObject else {
                            if isDragging {
                                dragOffset = .zero
                                isDragging = false
                                pageCrossing?.ended(nil, nil)
                            }
                            return
                        }
                        if editingCell != nil && hypot(value.translation.width, value.translation.height) > 8 {
                            editingCell = nil
                        }
                        if editingCell == nil {
                            if !isDragging { pageCrossing?.began() }
                            isDragging = true
                            dragOffset = value.translation
                        }
                    }
                    .onEnded { value in
                        guard CanvasTouchState.canDragObject else {
                            dragOffset = .zero
                            isDragging = false
                            pageCrossing?.ended(nil, nil)
                            return
                        }
                        if editingCell == nil {
                            if hypot(value.translation.width, value.translation.height) < 3 {
                                pageCrossing?.ended(nil, nil)
                            } else {
                                // 換不換頁由編輯器決定，它會結束這次拖曳。
                                if let onMove = onMove {
                                    onMove(dragOffset)
                                } else {
                                    var updated = table
                                    updated.x += dragOffset.width
                                    updated.y += dragOffset.height
                                    table = updated
                                }
                            }
                            onSelect?()
                            dragOffset = .zero
                            isDragging = false
                        }
                    }
            )
            .overlay(alignment: .top) {
                if isSelected {
                    HStack(spacing: 8) {
                        if !isCanvasLocked {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                                .font(.system(size: 11, weight: .semibold))
                            Text(localizationManager.localized("drag_to_move"))
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(12)
                        .contentShape(Rectangle())
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 2, coordinateSpace: .named(CanvasCoordinateSpace.name))
                                .onChanged { value in
                                    if !isDragging { pageCrossing?.began() }
                                    isDragging = true
                                    dragOffset = value.translation
                                }
                                .onEnded { value in
                                    if hypot(value.translation.width, value.translation.height) < 2 {
                                        pageCrossing?.ended(nil, nil)
                                    }
                                    if hypot(value.translation.width, value.translation.height) >= 2 {
                                        if let onMove = onMove {
                                            onMove(dragOffset)
                                        } else {
                                            var updated = table
                                            updated.x += dragOffset.width
                                            updated.y += dragOffset.height
                                            table = updated
                                        }
                                    }
                                    onSelect?()
                                    dragOffset = .zero
                                    isDragging = false
                                }
                        )
                        }

                        // 鎖定／解除鎖定就放在選取列上。表格一點就進入儲存格編輯，
                        // Mac 上右鍵落在儲存格的文字框裡只會出現系統的剪下／貼上選單，
                        // 物件選單打不開 —— 那時唯一的鎖定入口就是這一顆。
                        if let lock {
                            let locked = lock.isLocked(table.id)
                            let key = locked ? "object_unlock" : "object_lock"
                            Button {
                                lock.setLocked(table.id, !locked)
                            } label: {
                                Image(systemName: locked ? "lock.fill" : "lock.open")
                                    .font(.system(size: 11, weight: .semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background((locked ? Color.orange : Color.secondary).opacity(0.15))
                                    .foregroundColor(locked ? .orange : .primary)
                                    .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                            .help(localizationManager.localized(key))
                            .accessibilityLabel(localizationManager.localized(key))
                            .accessibilityIdentifier("table.lock")
                        }

                        // 「編修」只留右上角那顆（與圖片、形狀同一個位置），這裡不再重複一顆。
                    }
                    .padding(3)
                    .background(
                        Capsule()
                            .fill(Color(uiColor: .systemBackground))
                            .shadow(color: Color.black.opacity(0.16), radius: 6, y: 2)
                    )
                    .offset(y: -38)
                }
            }
            // 右下角縮放把手：跟著表格一起轉（放在 rotationEffect 之前），
            // 拖曳位移再反轉回表格本地座標，旋轉過的表格往「它自己的右下」拉才對。
            .overlay(alignment: .bottomTrailing) {
                if isSelected && !isCanvasLocked && onResize != nil {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.accentColor))
                        .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                        .contentShape(Rectangle().inset(by: -10))
                        .offset(x: 11 + resizeDelta.width, y: 11 + resizeDelta.height)
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 1, coordinateSpace: .named(CanvasCoordinateSpace.name))
                                .onChanged { value in
                                    editingCell = nil
                                    resizeDelta = Self.localDelta(value.translation, rotation: table.canvasRotation)
                                }
                                .onEnded { value in
                                    let d = Self.localDelta(value.translation, rotation: table.canvasRotation)
                                    resizeDelta = .zero
                                    guard hypot(d.width, d.height) >= 2 else { return }
                                    onResize?(CGSize(width: layout.width + d.width, height: layout.height + d.height))
                                }
                        )
                        .accessibilityLabel(localizationManager.localized("table_resize_handle"))
                        .accessibilityIdentifier("table.resize")
                }
            }
            // 表格本體跟著轉；把手掛在旋轉**外面**的 overlay ——
            // 包進去的話拖曳算出的角度會疊加自身旋轉，表格會失控加速。
            .rotationEffect(.degrees(table.canvasRotation))
            .contextMenu {
                ObjectOrderMenu(id: table.id)
                Divider()
                Button(role: .destructive, action: onDelete) {
                    Label(localizationManager.localized("delete"), systemImage: "trash")
                }
            }
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
                        Button(action: { (onProperties ?? onEdit)() }) {
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
                        .accessibilityIdentifier("action.delete")
                    }
                    .offset(x: 10, y: -10)
                }
            }
            .objectProbe("table")
            .position(
                x: currentX + layout.width / 2,
                y: currentY + layout.height / 2
            )
            .animation(nil, value: dragOffset)
            .animation(nil, value: resizeDelta)
    }

    /// 畫布座標的拖曳位移 → 表格本地座標（扣掉表格自身的旋轉）。
    static func localDelta(_ translation: CGSize, rotation degrees: Double) -> CGSize {
        let rad = -degrees * .pi / 180
        let c = CGFloat(cos(rad)), s = CGFloat(sin(rad))
        return CGSize(
            width: translation.width * c - translation.height * s,
            height: translation.width * s + translation.height * c)
    }
}
