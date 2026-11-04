//
//  TableRibbonToolbar.swift
//  Kairumo
//
//  仿 Word「表格設計」與「表格版面配置」頂部工具列（Ribbon Toolbars）
//  提供：列與欄操作、九宮格對齊、樣式庫、網底、框線、合併與分割全功能快捷控制
//

import SwiftUI

public struct TableRibbonToolbar: View {
    /// 寫回這個 binding 就是一次完整的提交（存檔、縮圖失效、協作廣播都在編輯器那一端）。
    @Binding var table: NoteTableAttachment
    @Binding var showProperties: Bool
    let onDelete: () -> Void

    @ObservedObject private var localizationManager = LocalizationManager.shared
    /// 畫布上最後點進去的儲存格；插入列欄、刪除、合併、對齊都以它為準。
    @ObservedObject private var focus = TableCellFocus.shared

    private enum RibbonTab: Hashable {
        case design, layout
    }
    @State private var activeTab: RibbonTab = .layout

    public init(
        table: Binding<NoteTableAttachment>,
        showProperties: Binding<Bool>,
        onDelete: @escaping () -> Void
    ) {
        self._table = table
        self._showProperties = showProperties
        self.onDelete = onDelete
    }

    private func l(_ key: String) -> String { localizationManager.localized(key) }

    /// 一次動作只寫回一次（多步驟修改不會觸發多次存檔與廣播）。
    private func edit(_ change: (inout NoteTableAttachment) -> Void) {
        var next = table
        change(&next)
        guard next != table else { return }
        table = next
    }

    /// 目前儲存格（沒點過任何格子時為 nil）。
    private var focusedCell: TableCellCoordinate? { focus.cell(in: table) }

    /// 目前儲存格所在的範圍（合併區為整片）；沒有焦點時是整張表。
    private var focusedRange: (rows: ClosedRange<Int>, cols: ClosedRange<Int>) {
        guard let cell = focusedCell else { return (0...(table.rows - 1), 0...(table.cols - 1)) }
        return table.cellRange(row: cell.row, col: cell.col)
    }

    public var body: some View {
        VStack(spacing: 4) {
            // 頂部分頁切換按鈕
            HStack(spacing: 8) {
                tabButton(title: l("table_layout"), tab: .layout, icon: "tablecells")
                tabButton(title: l("table_design"), tab: .design, icon: "paintpalette")

                if let cell = focusedCell {
                    Text(l("table_cell_position")
                        .replacingFirst("%1@", with: "\(cell.row + 1)")
                        .replacingFirst("%2@", with: "\(cell.col + 1)"))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .accessibilityIdentifier("table.ribbon.focus")
                }

                Spacer()

                Button {
                    showProperties = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 11, weight: .semibold))
                        Text(l("table_properties"))
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.12))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("table.ribbon.properties")
            }
            .padding(.horizontal, 12)

            Divider()

            // 工具列主體
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    switch activeTab {
                    case .layout:
                        layoutControls
                    case .design:
                        designControls
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }
        }
        .frame(height: 78)
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.96))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(uiColor: .separator), lineWidth: 0.5))
    }

    private func tabButton(title: String, tab: RibbonTab, icon: String) -> some View {
        let isSelected = activeTab == tab
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                activeTab = tab
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: isSelected ? .bold : .regular))
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .bold : .regular))
            }
            .foregroundColor(isSelected ? .accentColor : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isSelected ? Color(uiColor: .systemBackground) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .help(title)
    }

    // MARK: - 表格版面配置工具（對標圖 2）

    private var layoutControls: some View {
        let range = focusedRange
        let cell = focusedCell
        let span = cell.flatMap { table.span(containing: $0.row, col: $0.col) }
        let canMergeRight = cell.map { _ in range.cols.upperBound + 1 < table.cols } ?? false
        let canMergeDown = cell.map { _ in range.rows.upperBound + 1 < table.rows } ?? false
        return HStack(spacing: 12) {
            // 列與欄增刪：以目前儲存格為準（沒點過格子時插在表格頭尾、刪最後一列／欄）。
            ribbonGroup(label: l("table_tab_row") + " & " + l("table_tab_column")) {
                HStack(spacing: 4) {
                    actionIconBtn(icon: "arrow.up.to.line", tooltip: "table_insert_row_above", id: "insert_row_above") {
                        let at = cell == nil ? 0 : range.rows.lowerBound
                        edit { $0.insertRow(at: at) }
                        if let cell { focus.focus(tableId: table.id, cell: TableCellCoordinate(row: cell.row + 1, col: cell.col)) }
                    }
                    actionIconBtn(icon: "arrow.down.to.line", tooltip: "table_insert_row_below", id: "insert_row_below") {
                        let at = cell == nil ? table.rows : range.rows.upperBound + 1
                        edit { $0.insertRow(at: at) }
                    }
                    actionIconBtn(icon: "arrow.left.to.line", tooltip: "table_insert_col_left", id: "insert_col_left") {
                        let at = cell == nil ? 0 : range.cols.lowerBound
                        edit { $0.insertColumn(at: at) }
                        if let cell { focus.focus(tableId: table.id, cell: TableCellCoordinate(row: cell.row, col: cell.col + 1)) }
                    }
                    actionIconBtn(icon: "arrow.right.to.line", tooltip: "table_insert_col_right", id: "insert_col_right") {
                        let at = cell == nil ? table.cols : range.cols.upperBound + 1
                        edit { $0.insertColumn(at: at) }
                    }
                    Divider().frame(height: 20)
                    actionIconBtn(icon: "minus.square", tooltip: "table_delete_row", id: "delete_row", isDestructive: true) {
                        let at = cell?.row ?? (table.rows - 1)
                        edit { $0.deleteRow(at: at) }
                    }
                    .disabled(table.rows <= 1)
                    actionIconBtn(icon: "rectangle.portrait.slash", tooltip: "table_delete_column", id: "delete_column", isDestructive: true) {
                        let at = cell?.col ?? (table.cols - 1)
                        edit { $0.deleteColumn(at: at) }
                    }
                    .disabled(table.cols <= 1)
                    actionIconBtn(icon: "trash", tooltip: "delete", id: "delete_table", isDestructive: true) {
                        onDelete()
                    }
                }
            }

            Divider().frame(height: 32)

            // 合併與分割：目前儲存格（或它所在的合併區）向右／向下擴一格；分割拆掉它所在的合併區。
            ribbonGroup(label: l("table_merge_selection")) {
                HStack(spacing: 4) {
                    actionIconBtn(icon: "arrow.right.square", tooltip: "table_merge_right", id: "merge_right") {
                        guard let cell else { return }
                        edit { $0.mergeRight(row: cell.row, col: cell.col) }
                    }
                    .disabled(!canMergeRight)
                    actionIconBtn(icon: "arrow.down.square", tooltip: "table_merge_down", id: "merge_down") {
                        guard let cell else { return }
                        edit { $0.mergeDown(row: cell.row, col: cell.col) }
                    }
                    .disabled(!canMergeDown)
                    actionIconBtn(icon: "rectangle.split.2x1", tooltip: "table_split_cell", id: "split") {
                        guard let cell else { return }
                        edit { $0.splitCell(row: cell.row, col: cell.col) }
                    }
                    .disabled(span == nil)
                }
            }

            Divider().frame(height: 32)

            // 儲存格大小調整
            ribbonGroup(label: l("table_section_size")) {
                HStack(spacing: 4) {
                    actionIconBtn(icon: "distribute.vertical", tooltip: "table_distribute_rows", id: "distribute_rows") {
                        edit { $0.distributeRows() }
                    }
                    actionIconBtn(icon: "distribute.horizontal", tooltip: "table_distribute_cols", id: "distribute_cols") {
                        edit { $0.distributeColumns() }
                    }
                    actionIconBtn(icon: "arrow.up.left.and.arrow.down.right", tooltip: "table_autofit", id: "autofit") {
                        edit { $0.autoFitSizes() }
                    }
                }
            }

            Divider().frame(height: 32)

            // 九宮格對齊：套用到目前儲存格（沒點過格子時整張表）。
            ribbonGroup(label: l("table_section_align")) {
                VStack(spacing: 2) {
                    HStack(spacing: 2) {
                        nineAlignBtn(h: .left, v: .top, icon: "arrow.up.left", key: "table_align_9_top_left")
                        nineAlignBtn(h: .center, v: .top, icon: "arrow.up", key: "table_align_9_top_center")
                        nineAlignBtn(h: .right, v: .top, icon: "arrow.up.right", key: "table_align_9_top_right")
                    }
                    HStack(spacing: 2) {
                        nineAlignBtn(h: .left, v: .middle, icon: "arrow.left", key: "table_align_9_middle_left")
                        nineAlignBtn(h: .center, v: .middle, icon: "dot.circle", key: "table_align_9_middle_center")
                        nineAlignBtn(h: .right, v: .middle, icon: "arrow.right", key: "table_align_9_middle_right")
                    }
                    HStack(spacing: 2) {
                        nineAlignBtn(h: .left, v: .bottom, icon: "arrow.down.left", key: "table_align_9_bottom_left")
                        nineAlignBtn(h: .center, v: .bottom, icon: "arrow.down", key: "table_align_9_bottom_center")
                        nineAlignBtn(h: .right, v: .bottom, icon: "arrow.down.right", key: "table_align_9_bottom_right")
                    }
                }
            }
        }
    }

    private func nineAlignBtn(h: TableHAlign, v: TableVAlign, icon: String, key: String) -> some View {
        let probe = focusedCell.map { table.style(row: $0.row, col: $0.col) }
        let isCurrent = probe.map { ($0.hAlign ?? .left) == h && ($0.vAlign ?? .top) == v } ?? false
        return Button {
            let range = focusedRange
            edit {
                $0.updateStyle(rows: range.rows, cols: range.cols) {
                    $0.hAlign = (h == .left ? nil : h)
                    $0.vAlign = v
                }
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(isCurrent ? .white : .primary)
                .frame(width: 18, height: 13)
                .background(isCurrent ? Color.accentColor : Color(uiColor: .systemBackground))
                .cornerRadius(2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(l(key))
        .accessibilityIdentifier("table.ribbon.\(key)")
        .help(l(key))
    }

    // MARK: - 表格設計工具（對標圖 3）

    private var designControls: some View {
        HStack(spacing: 12) {
            // 表格樣式選項
            ribbonGroup(label: l("table_design")) {
                HStack(spacing: 8) {
                    toggleTag(label: l("table_header_row"), id: "header_row", isOn: Binding(
                        get: { table.headerRow },
                        set: { on in edit { $0.headerRow = on } }
                    ))
                    // 預設值與畫布一致（沒設定＝沒有斑馬紋）。原本預設顯示「已勾選」，畫布卻沒有。
                    toggleTag(label: l("table_banded_rows"), id: "banded_rows", isOn: Binding(
                        get: { table.bandedRows ?? false },
                        set: { on in edit { $0.bandedRows = on ? true : nil } }
                    ))
                    toggleTag(label: l("table_banded_cols"), id: "banded_cols", isOn: Binding(
                        get: { table.bandedCols ?? false },
                        set: { on in edit { $0.bandedCols = on ? true : nil } }
                    ))
                }
            }

            Divider().frame(height: 32)

            // 表格樣式庫（Gallery）
            ribbonGroup(label: l("table_styles_gallery")) {
                HStack(spacing: 6) {
                    styleGalleryBtn(name: l("table_style_simple"), headerHex: "#E9EEFC", fillHex: nil)
                    styleGalleryBtn(name: l("table_style_business_blue"), headerHex: "#2B579A", textHex: "#FFFFFF", fillHex: "#F2F7FF")
                    styleGalleryBtn(name: l("table_style_slate_gray"), headerHex: "#4A5568", textHex: "#FFFFFF", fillHex: "#F7FAFC")
                    styleGalleryBtn(name: l("table_style_fresh_green"), headerHex: "#2E7D32", textHex: "#FFFFFF", fillHex: "#F1F8E9")
                    styleGalleryBtn(name: l("table_style_warm_orange"), headerHex: "#E65100", textHex: "#FFFFFF", fillHex: "#FFF8E1")
                }
            }

            Divider().frame(height: 32)

            // 網底（目前儲存格；沒點過格子時為表頭底色）與框線
            ribbonGroup(label: l("table_shading") + " & " + l("table_borders")) {
                HStack(spacing: 8) {
                    ColorPicker("", selection: Binding(
                        get: { shadingColor },
                        set: { color in applyShading(color.toHex()) }
                    ))
                    .labelsHidden()
                    .accessibilityLabel(l("table_shading"))
                    .accessibilityIdentifier("table.ribbon.shading")

                    Menu {
                        Button(l("table_border_all")) { edit { $0.borderMode = nil } }
                        Button(l("table_border_outer")) { edit { $0.borderMode = .outer } }
                        Button(l("table_border_inner")) { edit { $0.borderMode = .inner } }
                        Button(l("table_border_horizontal")) { edit { $0.borderMode = .horizontal } }
                        Button(l("table_border_none")) { edit { $0.borderMode = TableBorderMode.none } }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "rectangle.grid.2x2")
                            Image(systemName: "chevron.down").font(.system(size: 8))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Color(uiColor: .systemBackground))
                        .cornerRadius(4)
                    }
                    .accessibilityLabel(l("table_borders"))
                    .accessibilityIdentifier("table.ribbon.borders")
                }
            }
        }
    }

    private var shadingColor: Color {
        if let cell = focusedCell, let hex = table.style(row: cell.row, col: cell.col).fillHex, hex != "clear" {
            return Color(hex: hex) ?? .clear
        }
        if focusedCell == nil, let hex = table.headerBackgroundHex, hex != "clear" {
            return Color(hex: hex) ?? Color(hex: "#E9EEFC")!
        }
        return focusedCell == nil ? Color(hex: "#E9EEFC")! : .clear
    }

    private func applyShading(_ hex: String?) {
        guard let hex else { return }
        if focusedCell != nil {
            let range = focusedRange
            edit { $0.updateStyle(rows: range.rows, cols: range.cols) { $0.fillHex = hex } }
        } else {
            edit { $0.headerBackgroundHex = hex }
        }
    }

    private func styleGalleryBtn(name: String, headerHex: String, textHex: String? = nil, fillHex: String? = nil) -> some View {
        Button {
            edit { t in
                t.headerBackgroundHex = headerHex
                t.headerRow = true
                t.bandedRows = true
                let lastCol = t.cols - 1
                t.updateStyle(rows: 0...0, cols: 0...lastCol) { $0.textColorHex = textHex }
                // 樣式卡下半的淺底色就是內容列的網底（隔列套用，與帶狀列一致）。
                if t.rows > 1 {
                    for r in 1..<t.rows {
                        t.updateStyle(rows: r...r, cols: 0...lastCol) {
                            $0.fillHex = (fillHex != nil && r % 2 == 1) ? fillHex : nil
                        }
                    }
                }
            }
        } label: {
            VStack(spacing: 1) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: headerHex) ?? .blue)
                    .frame(width: 32, height: 10)
                RoundedRectangle(cornerRadius: 2)
                    .fill(fillHex.flatMap(Color.init(hex:)) ?? Color.secondary.opacity(0.1))
                    .frame(width: 32, height: 12)
            }
            .padding(2)
            .background(Color(uiColor: .systemBackground))
            .cornerRadius(4)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(uiColor: .separator), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .help(name)
    }

    private func ribbonGroup<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 2) {
            content()
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
    }

    private func actionIconBtn(icon: String, tooltip: String, id: String, isDestructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(isDestructive ? .red : .primary)
                .frame(width: 24, height: 24)
                .background(Color(uiColor: .systemBackground))
                .cornerRadius(4)
        }
        .buttonStyle(RibbonIconButtonStyle())
        .accessibilityLabel(l(tooltip))
        .accessibilityIdentifier("table.ribbon.\(id)")
        .help(l(tooltip))
    }

    private func toggleTag(label: String, id: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isOn.wrappedValue ? "checkmark.square.fill" : "square")
                    .foregroundColor(isOn.wrappedValue ? .accentColor : .secondary)
                Text(label)
                    .font(.system(size: 11))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color(uiColor: .systemBackground))
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier("table.ribbon.\(id)")
        .help(label)
    }
}

/// 停用時看得出來是停用的（`.plain` 不會把自訂前景色變淡，使用者會以為按了沒反應）。
private struct RibbonIconButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(isEnabled ? (configuration.isPressed ? 0.6 : 1) : 0.3)
    }
}
