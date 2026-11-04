//
//  TablePropertiesSheet.swift
//  Kairumo
//
//  仿 Word「表格內容」屬性視窗（Table Properties dialog）
//  提供：表格、列、欄、儲存格、替代文字五大分頁，以及「框線及網底…」「選項…」兩個子面板。
//
//  # 每一顆按鈕都要有東西接著
//
//  這個面板原本有幾顆按鈕是「有窗口、沒接線」：
//  - 「框線及網底…」出現兩次：表格分頁那顆只是跳到儲存格分頁，底部那顆是空的 `{}`。
//  - 「位置…」是空的 `{}`；「文繞圖」寫進模型但沒有任何地方讀它（自由畫布上沒有文字流可繞）。
//  - 「選項…」只是跳到列分頁。
//  - 分頁標籤「表格 (%1@ × %2@)」沒有代入列數與欄數，畫面上直接印出 `%1@`。
//  - 儲存格分頁的對齊按鈕改的是**整張表**，不是那一格。
//  現在：框線及網底與選項各是一個真的子面板；文繞圖與位置拿掉；對齊只改目前儲存格。
//  所有修改都先改 `workingTable`，按「確認」才寫回，「取消」整批放棄（含子面板）。
//

import SwiftUI

public struct TablePropertiesSheet: View {
    let onCommit: (NoteTableAttachment) -> Void

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var localizationManager = LocalizationManager.shared

    private enum PropertyTab: Hashable {
        case table, row, column, cell, altText
    }

    @State private var selectedTab: PropertyTab = .table
    @State private var workingTable: NoteTableAttachment
    @State private var activeRowIndex: Int = 0
    @State private var activeColIndex: Int = 0
    @State private var showBordersShading = false
    @State private var showOptions = false

    // 單位換算：1 公分 ≈ 28.3465 點 (pt)
    private let ptPerCm: CGFloat = 28.3465

    private enum MeasureUnit: String, CaseIterable, Identifiable {
        case cm, pt
        var id: String { rawValue }
    }
    @State private var unit: MeasureUnit = .cm

    public init(table: NoteTableAttachment, onCommit: @escaping (NoteTableAttachment) -> Void) {
        self.onCommit = onCommit
        self._workingTable = State(initialValue: table)
    }

    private func l(_ key: String) -> String { localizationManager.localized(key) }

    /// 「表格 (3 × 4)」—— 列數與欄數要代進去，否則畫面上直接印出 `%1@`。
    static func tableTabLabel(_ template: String, rows: Int, cols: Int) -> String {
        template
            .replacingFirst("%1@", with: "\(rows)")
            .replacingFirst("%2@", with: "\(cols)")
    }

    private var unitLabel: String { unit == .cm ? l("table_unit_cm") : l("table_unit_pt") }

    private func commit() {
        // 只走 `onCommit` 一次：同時寫 binding 會讓編輯器存檔與協作廣播各跑兩次。
        onCommit(workingTable)
        dismiss()
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    Text(Self.tableTabLabel(l("word_table_label"), rows: workingTable.rows, cols: workingTable.cols))
                        .tag(PropertyTab.table)
                    Text(l("table_tab_row")).tag(PropertyTab.row)
                    Text(l("table_tab_column")).tag(PropertyTab.column)
                    Text(l("table_tab_cell")).tag(PropertyTab.cell)
                    Text(l("table_tab_alt_text")).tag(PropertyTab.altText)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(uiColor: .secondarySystemBackground))
                .accessibilityIdentifier("table.props.tabs")

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        switch selectedTab {
                        case .table: tableTabContent
                        case .row: rowTabContent
                        case .column: columnTabContent
                        case .cell: cellTabContent
                        case .altText: altTextTabContent
                        }
                    }
                    .padding(20)
                }
                // 底部原本還有一排「框線及網底… / 取消 / 確認」：與表格分頁的按鈕、
                // 導覽列的取消／確認各重複一次。只留導覽列那一組。
            }
            .navigationTitle(l("table_properties"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l("cancel")) { dismiss() }
                        .accessibilityIdentifier("table.props.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(l("confirm")) { commit() }
                        .accessibilityIdentifier("table.props.confirm")
                }
            }
            .onAppear {
                // 從畫布上最後點進去的那一格開始（列、欄、儲存格分頁、框線及網底都以它為準）。
                if let focused = TableCellFocus.shared.cell(in: workingTable) {
                    activeRowIndex = focused.row
                    activeColIndex = focused.col
                }
            }
            .sheet(isPresented: $showBordersShading) {
                TableBordersShadingSheet(
                    table: $workingTable, row: activeRowIndex, col: activeColIndex)
            }
            .sheet(isPresented: $showOptions) {
                TableOptionsSheet(table: $workingTable)
            }
        }
    }

    // MARK: - 分頁一：表格

    private var tableTabContent: some View {
        let layout = workingTable.resolvedLayout()
        return VStack(alignment: .leading, spacing: 18) {
            GroupBox(label: Text(l("table_section_size")).font(.headline)) {
                HStack(spacing: 16) {
                    Text(l("table_preferred_width"))
                    Spacer()
                    let displayWidth = unit == .cm ? layout.width / ptPerCm : layout.width
                    TextField("", value: Binding(
                        get: { Double(round(displayWidth * 100) / 100) },
                        set: { workingTable.setPreferredWidth(CGFloat(unit == .cm ? $0 * Double(ptPerCm) : $0)) }
                    ), format: .number.precision(.fractionLength(2)))
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
                    .frame(width: 90)
                    .accessibilityIdentifier("table.props.width")

                    Picker("", selection: $unit) {
                        Text(l("table_unit_cm")).tag(MeasureUnit.cm)
                        Text(l("table_unit_pt")).tag(MeasureUnit.pt)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)
                }
                .padding(.vertical, 4)
            }

            // 對齊：按「確認」時以頁寬換算成表格左緣（見 `NoteTableAttachment.alignedX`）。
            GroupBox(label: Text(l("table_section_align")).font(.headline)) {
                HStack(spacing: 24) {
                    choiceButton(titleKey: "table_align_left", iconName: "align.horizontal.left",
                                 isSelected: (workingTable.alignmentRaw ?? "left") == "left") {
                        workingTable.alignmentRaw = "left"
                    }
                    choiceButton(titleKey: "table_align_center", iconName: "align.horizontal.center",
                                 isSelected: workingTable.alignmentRaw == "center") {
                        workingTable.alignmentRaw = "center"
                    }
                    choiceButton(titleKey: "table_align_right", iconName: "align.horizontal.right",
                                 isSelected: workingTable.alignmentRaw == "right") {
                        workingTable.alignmentRaw = "right"
                    }

                    Spacer()

                    // 「從左邊縮排」只對靠左有意義（Word 也是）。
                    HStack(spacing: 6) {
                        Text(l("table_indent_left"))
                        let indent = (workingTable.indentLeft ?? 0) / (unit == .cm ? ptPerCm : 1)
                        TextField("", value: Binding(
                            get: { Double(round(indent * 100) / 100) },
                            set: {
                                workingTable.indentLeft = max(0, CGFloat(unit == .cm ? $0 * Double(ptPerCm) : $0))
                                workingTable.alignmentRaw = "left"
                            }
                        ), format: .number.precision(.fractionLength(2)))
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.decimalPad)
                        .frame(width: 70)
                        .accessibilityIdentifier("table.props.indent")
                        Text(unitLabel).foregroundColor(.secondary)
                    }
                    .disabled((workingTable.alignmentRaw ?? "left") != "left")
                }
                .padding(.vertical, 4)
            }

            HStack(spacing: 12) {
                Button(l("table_borders_and_shading")) { showBordersShading = true }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("table.props.borders")
                Button(l("table_options")) { showOptions = true }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("table.props.options")
            }
        }
    }

    private func choiceButton(
        titleKey: String, iconName: String, isSelected: Bool, height: CGFloat = 50,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(isSelected ? Color.accentColor : Color.secondary.opacity(0.4), lineWidth: isSelected ? 2 : 1)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isSelected ? Color.accentColor.opacity(0.12) : Color(uiColor: .systemBackground))
                    )
                    .frame(width: 64, height: height)
                    .overlay(
                        Image(systemName: iconName)
                            .font(.system(size: 20))
                            .foregroundColor(isSelected ? .accentColor : .primary)
                    )
                Text(l(titleKey))
                    .font(.caption)
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(l(titleKey))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - 分頁二：列

    private func rowNavigator() -> some View {
        let r = min(max(0, activeRowIndex), workingTable.rows - 1)
        return HStack {
            Text("\(l("table_tab_row")) \(r + 1) / \(workingTable.rows)")
                .font(.headline)
            Spacer()
            Button(action: { activeRowIndex = max(0, r - 1) }) { Image(systemName: "chevron.up") }
                .buttonStyle(.bordered)
                .disabled(r <= 0)
            Button(action: { activeRowIndex = min(workingTable.rows - 1, r + 1) }) { Image(systemName: "chevron.down") }
                .buttonStyle(.bordered)
                .disabled(r >= workingTable.rows - 1)
        }
    }

    private func columnNavigator() -> some View {
        let c = min(max(0, activeColIndex), workingTable.cols - 1)
        return HStack {
            Text("\(l("table_tab_column")) \(c + 1) / \(workingTable.cols)")
                .font(.headline)
            Spacer()
            Button(action: { activeColIndex = max(0, c - 1) }) { Image(systemName: "chevron.left") }
                .buttonStyle(.bordered)
                .disabled(c <= 0)
            Button(action: { activeColIndex = min(workingTable.cols - 1, c + 1) }) { Image(systemName: "chevron.right") }
                .buttonStyle(.bordered)
                .disabled(c >= workingTable.cols - 1)
        }
    }

    private var rowTabContent: some View {
        let r = min(max(0, activeRowIndex), workingTable.rows - 1)
        let layout = workingTable.resolvedLayout()
        let currentH = layout.rowHeights[min(r, layout.rowHeights.count - 1)]
        let displayH = unit == .cm ? currentH / ptPerCm : currentH

        return VStack(alignment: .leading, spacing: 18) {
            rowNavigator()

            GroupBox(label: Text(l("table_row_height")).font(.headline)) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(l("table_row_height"))
                        Spacer()
                        TextField("", value: Binding(
                            get: { Double(round(displayH * 100) / 100) },
                            set: { workingTable.setRowHeight(Double(unit == .cm ? $0 * Double(ptPerCm) : $0), at: r) }
                        ), format: .number.precision(.fractionLength(2)))
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.decimalPad)
                        .frame(width: 90)
                        .accessibilityIdentifier("table.props.row_height")
                        Text(unitLabel).foregroundColor(.secondary)
                    }

                    HStack(spacing: 12) {
                        Button(l("table_distribute_rows")) { workingTable.distributeRows() }
                            .buttonStyle(.bordered)
                        Button(l("table_size_auto")) { workingTable.setRowHeight(nil, at: r) }
                            .buttonStyle(.bordered)
                    }
                }
                .padding(.vertical, 4)
            }

            Toggle(l("table_header_row"), isOn: $workingTable.headerRow)
        }
    }

    // MARK: - 分頁三：欄

    private var columnTabContent: some View {
        let c = min(max(0, activeColIndex), workingTable.cols - 1)
        let layout = workingTable.resolvedLayout()
        let currentW = layout.columnWidths[min(c, layout.columnWidths.count - 1)]
        let displayW = unit == .cm ? currentW / ptPerCm : currentW

        return VStack(alignment: .leading, spacing: 18) {
            columnNavigator()

            GroupBox(label: Text(l("table_col_width")).font(.headline)) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(l("table_col_width"))
                        Spacer()
                        TextField("", value: Binding(
                            get: { Double(round(displayW * 100) / 100) },
                            set: { workingTable.setColumnWidth(Double(unit == .cm ? $0 * Double(ptPerCm) : $0), at: c) }
                        ), format: .number.precision(.fractionLength(2)))
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.decimalPad)
                        .frame(width: 90)
                        .accessibilityIdentifier("table.props.col_width")
                        Text(unitLabel).foregroundColor(.secondary)
                    }

                    HStack(spacing: 12) {
                        Button(l("table_distribute_cols")) { workingTable.distributeColumns() }
                            .buttonStyle(.bordered)
                        Button(l("table_size_auto")) { workingTable.setColumnWidth(nil, at: c) }
                            .buttonStyle(.bordered)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - 分頁四：儲存格

    private var cellTabContent: some View {
        let range = workingTable.cellRange(row: activeRowIndex, col: activeColIndex)
        let style = workingTable.style(row: range.rows.lowerBound, col: range.cols.lowerBound)
        func apply(_ change: @escaping (inout NoteTableCellStyle) -> Void) {
            workingTable.updateStyle(rows: range.rows, cols: range.cols, change)
        }
        return VStack(alignment: .leading, spacing: 18) {
            // 改的是**這一格**（合併區則整片），不是整張表。
            Text(l("table_cell_position")
                .replacingFirst("%1@", with: "\(range.rows.lowerBound + 1)")
                .replacingFirst("%2@", with: "\(range.cols.lowerBound + 1)"))
                .font(.headline)
            rowNavigator()
            columnNavigator()

            GroupBox(label: Text(l("table_section_align")).font(.headline)) {
                VStack(alignment: .leading, spacing: 14) {
                    Text(l("table_align_v")).font(.subheadline).foregroundColor(.secondary)
                    HStack(spacing: 24) {
                        ForEach([(TableVAlign.top, "table_align_top", "arrow.up.to.line"),
                                 (.middle, "table_align_middle", "equal"),
                                 (.bottom, "table_align_bottom", "arrow.down.to.line")], id: \.1) { v, key, icon in
                            choiceButton(titleKey: key, iconName: icon,
                                         isSelected: (style.vAlign ?? .top) == v, height: 44) {
                                apply { $0.vAlign = (v == .top ? nil : v) }
                            }
                        }
                    }

                    Divider()

                    Text(l("table_align_h")).font(.subheadline).foregroundColor(.secondary)
                    HStack(spacing: 24) {
                        ForEach([(TableHAlign.left, "table_align_left", "text.alignleft"),
                                 (.center, "table_align_center", "text.aligncenter"),
                                 (.right, "table_align_right", "text.alignright")], id: \.1) { h, key, icon in
                            choiceButton(titleKey: key, iconName: icon,
                                         isSelected: (style.hAlign ?? .left) == h, height: 44) {
                                apply { $0.hAlign = (h == .left ? nil : h) }
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - 分頁五：替代文字（畫布上的 VoiceOver 標籤與提示）

    private var altTextTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(l("table_title_text")).font(.headline)
            TextField("", text: Binding(
                get: { workingTable.altTitle ?? "" },
                set: { workingTable.altTitle = $0.isEmpty ? nil : $0 }
            ))
            .textFieldStyle(.roundedBorder)
            .accessibilityIdentifier("table.props.alt_title")

            Text(l("table_description_text")).font(.headline)
            TextEditor(text: Binding(
                get: { workingTable.altDescription ?? "" },
                set: { workingTable.altDescription = $0.isEmpty ? nil : $0 }
            ))
            .frame(height: 120)
            .padding(4)
            .background(Color(uiColor: .systemBackground))
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3), lineWidth: 1))
            .accessibilityIdentifier("table.props.alt_description")
        }
    }
}

// MARK: - 框線及網底

/// 「框線及網底…」子面板：框線範圍、樣式、粗細、顏色，以及網底（目前儲存格或整張表）與表頭底色。
/// 直接改呼叫端的 `workingTable`；整批要不要寫回由「表格內容」的確認／取消決定。
struct TableBordersShadingSheet: View {
    @Binding var table: NoteTableAttachment
    let row: Int
    let col: Int

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var localizationManager = LocalizationManager.shared

    enum ShadingTarget: Hashable { case cell, table }
    @State private var shadingTarget: ShadingTarget = .cell

    private func l(_ key: String) -> String { localizationManager.localized(key) }

    private var cellRange: (rows: ClosedRange<Int>, cols: ClosedRange<Int>) {
        table.cellRange(row: row, col: col)
    }

    private var shadingRange: (rows: ClosedRange<Int>, cols: ClosedRange<Int>) {
        shadingTarget == .cell ? cellRange : (0...(table.rows - 1), 0...(table.cols - 1))
    }

    private var currentShadingHex: String? {
        table.style(row: shadingRange.rows.lowerBound, col: shadingRange.cols.lowerBound).fillHex
    }

    private func setShading(_ hex: String?) {
        let range = shadingRange
        table.updateStyle(rows: range.rows, cols: range.cols) { $0.fillHex = hex }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(l("table_preview")) {
                    TableMiniPreview(table: table)
                        .frame(maxWidth: .infinity)
                        .frame(height: 140)
                }

                Section(l("table_borders")) {
                    Picker(l("table_borders"), selection: Binding(
                        get: { table.borderMode ?? .all },
                        set: { table.borderMode = ($0 == .all ? nil : $0) }
                    )) {
                        Text(l("table_border_all")).tag(TableBorderMode.all)
                        Text(l("table_border_outer")).tag(TableBorderMode.outer)
                        Text(l("table_border_inner")).tag(TableBorderMode.inner)
                        Text(l("table_border_horizontal")).tag(TableBorderMode.horizontal)
                        Text(l("table_border_none")).tag(TableBorderMode.none)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("table.borders.mode")

                    Picker(l("table_border_style"), selection: Binding(
                        get: { table.resolvedBorderStyle },
                        set: { table.borderStyleRaw = ($0 == .solid ? nil : $0.rawValue) }
                    )) {
                        Text(l("table_border_solid")).tag(TableBorderStyle.solid)
                        Text(l("table_border_dashed")).tag(TableBorderStyle.dashed)
                        Text(l("table_border_dotted")).tag(TableBorderStyle.dotted)
                    }
                    .accessibilityIdentifier("table.borders.style")

                    Stepper(value: Binding(
                        get: { Double(table.resolvedBorderWidth) },
                        set: { table.borderWidth = ($0 == 1 ? nil : CGFloat($0)) }
                    ), in: 0.5...6.0, step: 0.5) {
                        HStack {
                            Text(l("table_border_width"))
                            Spacer()
                            Text("\(String(format: "%.1f", Double(table.resolvedBorderWidth))) \(l("table_unit_pt"))")
                                .foregroundColor(.secondary)
                        }
                    }
                    .accessibilityIdentifier("table.borders.width")

                    HStack {
                        ColorPicker(l("table_rule_color"), selection: Binding(
                            get: { table.ruleColorHex.flatMap(Color.init(hex:)) ?? Color.primary.opacity(0.35) },
                            set: { table.ruleColorHex = $0.toHex() }
                        ))
                        Button(l("table_reset_color")) { table.ruleColorHex = nil }
                            .buttonStyle(.borderless)
                            .disabled(table.ruleColorHex == nil)
                    }
                    .accessibilityIdentifier("table.borders.color")
                }

                Section(l("table_shading")) {
                    Picker(l("table_apply_to"), selection: $shadingTarget) {
                        Text(l("table_apply_cell")).tag(ShadingTarget.cell)
                        Text(l("table_apply_table")).tag(ShadingTarget.table)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("table.shading.target")

                    HStack {
                        ColorPicker(l("table_fill_color"), selection: Binding(
                            get: {
                                guard let hex = currentShadingHex, hex != "clear" else { return Color.clear }
                                return Color(hex: hex) ?? .clear
                            },
                            set: { setShading($0.toHex()) }
                        ))
                        Button(l("table_no_color")) { setShading(nil) }
                            .buttonStyle(.borderless)
                            .disabled(currentShadingHex == nil)
                    }
                    .accessibilityIdentifier("table.shading.color")

                    HStack {
                        ColorPicker(l("table_header_fill"), selection: Binding(
                            get: {
                                guard let hex = table.headerBackgroundHex, hex != "clear" else { return Color.clear }
                                return Color(hex: hex) ?? .clear
                            },
                            set: { table.headerBackgroundHex = $0.toHex() }
                        ))
                        Button(l("table_no_color")) { table.headerBackgroundHex = "clear" }
                            .buttonStyle(.borderless)
                            .disabled(table.headerBackgroundHex == "clear")
                    }
                    .disabled(!table.headerRow)
                    .accessibilityIdentifier("table.shading.header")
                }
            }
            // 按鈕字樣帶「…」（表示會開新視窗），視窗本身的標題不帶。
            .navigationTitle(l("table_borders_and_shading")
                .trimmingCharacters(in: CharacterSet(charactersIn: ".…")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(l("done")) { dismiss() }
                        .accessibilityIdentifier("table.borders.done")
                }
            }
        }
    }
}

// MARK: - 選項

/// 「選項…」子面板：表格樣式選項（表頭、帶狀列／欄）與文字大小。
struct TableOptionsSheet: View {
    @Binding var table: NoteTableAttachment

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var localizationManager = LocalizationManager.shared

    private func l(_ key: String) -> String { localizationManager.localized(key) }

    var body: some View {
        NavigationStack {
            Form {
                Section(l("table_preview")) {
                    TableMiniPreview(table: table)
                        .frame(maxWidth: .infinity)
                        .frame(height: 140)
                }
                Section {
                    Toggle(l("table_header_row"), isOn: $table.headerRow)
                    Toggle(l("table_banded_rows"), isOn: Binding(
                        get: { table.bandedRows ?? false },
                        set: { table.bandedRows = $0 ? true : nil }
                    ))
                    .accessibilityIdentifier("table.options.banded_rows")
                    Toggle(l("table_banded_cols"), isOn: Binding(
                        get: { table.bandedCols ?? false },
                        set: { table.bandedCols = $0 ? true : nil }
                    ))
                    .accessibilityIdentifier("table.options.banded_cols")
                    Stepper(value: $table.fontSize, in: 8...36, step: 1) {
                        HStack {
                            Text(l("table_font_size"))
                            Spacer()
                            Text("\(Int(table.fontSize)) \(l("table_unit_pt"))").foregroundColor(.secondary)
                        }
                    }
                    .accessibilityIdentifier("table.options.font_size")
                }
            }
            .navigationTitle(l("table_options_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(l("done")) { dismiss() }
                        .accessibilityIdentifier("table.options.done")
                }
            }
        }
    }
}

/// 子面板裡的即時預覽：與畫布同一份算繪（`NoteTableView`），等比例縮到可用寬度。
private struct TableMiniPreview: View {
    let table: NoteTableAttachment

    var body: some View {
        GeometryReader { geo in
            let layout = table.resolvedLayout()
            let s = min(1, geo.size.width / max(1, layout.width), geo.size.height / max(1, layout.height))
            NoteTableView(table: .constant(table), isSelected: false, onEdit: {})
                .allowsHitTesting(false)
                .scaleEffect(s, anchor: .topLeading)
                .frame(width: layout.width * s, height: layout.height * s, alignment: .topLeading)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
