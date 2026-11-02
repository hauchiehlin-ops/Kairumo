//
//  TablePropertiesSheet.swift
//  Kairumo
//
//  仿 Word「表格內容」屬性視窗（Table Properties dialog）
//  提供：表格、列、欄、儲存格、替代文字完整五大分頁與細部排版設定
//

import SwiftUI

public struct TablePropertiesSheet: View {
    @Binding var table: NoteTableAttachment
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

    // 單位換算：1 公分 ≈ 28.3465 點 (pt)
    private let ptPerCm: CGFloat = 28.3465

    private enum MeasureUnit: String, CaseIterable, Identifiable {
        case cm, pt
        var id: String { rawValue }
    }
    @State private var unit: MeasureUnit = .cm

    public init(table: Binding<NoteTableAttachment>, onCommit: @escaping (NoteTableAttachment) -> Void) {
        self._table = table
        self.onCommit = onCommit
        self._workingTable = State(initialValue: table.wrappedValue)
    }

    private func l(_ key: String) -> String { localizationManager.localized(key) }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 頂部分頁選擇器（對標圖 1 的 表格／列／欄／儲存格／替代文字）
                Picker("", selection: $selectedTab) {
                    Text(l("word_table_label")).tag(PropertyTab.table)
                    Text(l("table_tab_row")).tag(PropertyTab.row)
                    Text(l("table_tab_column")).tag(PropertyTab.column)
                    Text(l("table_tab_cell")).tag(PropertyTab.cell)
                    Text(l("table_tab_alt_text")).tag(PropertyTab.altText)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(uiColor: .secondarySystemBackground))

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        switch selectedTab {
                        case .table:
                            tableTabContent
                        case .row:
                            rowTabContent
                        case .column:
                            columnTabContent
                        case .cell:
                            cellTabContent
                        case .altText:
                            altTextTabContent
                        }
                    }
                    .padding(20)
                }

                Divider()

                // 底部確定與取消按鈕
                HStack {
                    Button(l("table_borders_and_shading")) {
                        // 快速切換或提示框線設定
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)

                    Spacer()

                    Button(l("cancel")) {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)

                    Button(l("confirm")) {
                        table = workingTable
                        onCommit(workingTable)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(uiColor: .secondarySystemBackground))
            }
            .navigationTitle(l("table_properties"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l("cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(l("confirm")) {
                        table = workingTable
                        onCommit(workingTable)
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 520, minHeight: 460)
    }

    // MARK: - 分頁一：表格（對標圖 1）

    private var tableTabContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            // 大小
            GroupBox(label: Text(l("table_section_size")).font(.headline)) {
                HStack(spacing: 16) {
                    Text(l("table_preferred_width"))
                    Spacer()

                    let displayWidth = unit == .cm ? workingTable.width / ptPerCm : workingTable.width
                    TextField("", value: Binding(
                        get: { Double(round(displayWidth * 100) / 100) },
                        set: { workingTable.width = CGFloat(unit == .cm ? $0 * Double(ptPerCm) : $0) }
                    ), format: .number.precision(.fractionLength(2)))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)

                    Picker("", selection: $unit) {
                        Text(l("table_unit_cm")).tag(MeasureUnit.cm)
                        Text(l("table_unit_pt")).tag(MeasureUnit.pt)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)
                }
                .padding(.vertical, 4)
            }

            // 對齊方式（靠左、置中、靠右）
            GroupBox(label: Text(l("table_section_align")).font(.headline)) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 24) {
                        alignmentButton(titleKey: "table_align_left", raw: "left", iconName: "align.horizontal.left")
                        alignmentButton(titleKey: "table_align_center", raw: "center", iconName: "align.horizontal.center")
                        alignmentButton(titleKey: "table_align_right", raw: "right", iconName: "align.horizontal.right")

                        Spacer()

                        HStack(spacing: 6) {
                            Text(l("table_indent_left"))
                            let indent = (workingTable.indentLeft ?? 0) / (unit == .cm ? ptPerCm : 1)
                            TextField("", value: Binding(
                                get: { Double(round(indent * 100) / 100) },
                                set: { workingTable.indentLeft = CGFloat(unit == .cm ? $0 * Double(ptPerCm) : $0) }
                            ), format: .number.precision(.fractionLength(2)))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 70)
                            Text(unit == .cm ? l("table_unit_cm") : l("table_unit_pt"))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            // 文繞圖
            GroupBox(label: Text(l("table_text_wrapping")).font(.headline)) {
                HStack(spacing: 32) {
                    wrappingButton(titleKey: "table_wrap_none", raw: "none", iconName: "doc.text")
                    wrappingButton(titleKey: "table_wrap_around", raw: "around", iconName: "text.and.command.macwindow")

                    Spacer()

                    Button(l("table_position_btn")) {}
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(workingTable.textWrappingRaw != "around")
                }
                .padding(.vertical, 4)
            }

            // 框線與選項
            HStack(spacing: 12) {
                Button(l("table_borders_and_shading")) {
                    selectedTab = .cell
                }
                .buttonStyle(.bordered)

                Button(l("table_options")) {
                    selectedTab = .row
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func alignmentButton(titleKey: String, raw: String, iconName: String) -> some View {
        let isSelected = (workingTable.alignmentRaw ?? "left") == raw
        return Button {
            workingTable.alignmentRaw = raw
        } label: {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(isSelected ? Color.accentColor : Color.secondary.opacity(0.4), lineWidth: isSelected ? 2 : 1)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isSelected ? Color.accentColor.opacity(0.12) : Color(uiColor: .systemBackground))
                    )
                    .frame(width: 64, height: 50)
                    .overlay(
                        Image(systemName: iconName)
                            .font(.system(size: 22))
                            .foregroundColor(isSelected ? .accentColor : .primary)
                    )
                Text(l(titleKey))
                    .font(.caption)
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func wrappingButton(titleKey: String, raw: String, iconName: String) -> some View {
        let isSelected = (workingTable.textWrappingRaw ?? "none") == raw
        return Button {
            workingTable.textWrappingRaw = raw
        } label: {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(isSelected ? Color.accentColor : Color.secondary.opacity(0.4), lineWidth: isSelected ? 2 : 1)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isSelected ? Color.accentColor.opacity(0.12) : Color(uiColor: .systemBackground))
                    )
                    .frame(width: 64, height: 50)
                    .overlay(
                        Image(systemName: iconName)
                            .font(.system(size: 22))
                            .foregroundColor(isSelected ? .accentColor : .primary)
                    )
                Text(l(titleKey))
                    .font(.caption)
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - 分頁二：列

    private var rowTabContent: some View {
        let r = min(max(0, activeRowIndex), workingTable.rows - 1)
        let layout = workingTable.resolvedLayout()
        let currentH = layout.rowHeights[min(r, layout.rowHeights.count - 1)]
        let displayH = unit == .cm ? currentH / ptPerCm : currentH

        return VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("\(l("table_tab_row")) \(r + 1) / \(workingTable.rows)")
                    .font(.headline)
                Spacer()
                Button(action: { if activeRowIndex > 0 { activeRowIndex -= 1 } }) {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(.bordered)
                .disabled(activeRowIndex <= 0)

                Button(action: { if activeRowIndex < workingTable.rows - 1 { activeRowIndex += 1 } }) {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(.bordered)
                .disabled(activeRowIndex >= workingTable.rows - 1)
            }

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
                        .frame(width: 90)

                        Text(unit == .cm ? l("table_unit_cm") : l("table_unit_pt"))
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 12) {
                        Button(l("table_distribute_rows")) {
                            workingTable.distributeRows()
                        }
                        .buttonStyle(.bordered)

                        Button(l("table_size_auto")) {
                            workingTable.setRowHeight(nil, at: r)
                        }
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
            HStack {
                Text("\(l("table_tab_column")) \(c + 1) / \(workingTable.cols)")
                    .font(.headline)
                Spacer()
                Button(action: { if activeColIndex > 0 { activeColIndex -= 1 } }) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.bordered)
                .disabled(activeColIndex <= 0)

                Button(action: { if activeColIndex < workingTable.cols - 1 { activeColIndex += 1 } }) {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.bordered)
                .disabled(activeColIndex >= workingTable.cols - 1)
            }

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
                        .frame(width: 90)

                        Text(unit == .cm ? l("table_unit_cm") : l("table_unit_pt"))
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 12) {
                        Button(l("table_distribute_cols")) {
                            workingTable.distributeColumns()
                        }
                        .buttonStyle(.bordered)

                        Button(l("table_size_auto")) {
                            workingTable.setColumnWidth(nil, at: c)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - 分頁四：儲存格

    private var cellTabContent: some View {
        let style = workingTable.style(row: activeRowIndex, col: activeColIndex)
        return VStack(alignment: .leading, spacing: 18) {
            GroupBox(label: Text(l("table_section_align")).font(.headline)) {
                VStack(alignment: .leading, spacing: 14) {
                    Text(l("table_align_v"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack(spacing: 24) {
                        cellVAlignButton(titleKey: "table_align_top", vAlign: .top, iconName: "arrow.up.to.line")
                        cellVAlignButton(titleKey: "table_align_middle", vAlign: .middle, iconName: "equal")
                        cellVAlignButton(titleKey: "table_align_bottom", vAlign: .bottom, iconName: "arrow.down.to.line")
                    }

                    Divider()

                    Text(l("table_align_h"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack(spacing: 24) {
                        cellHAlignButton(titleKey: "table_align_left", hAlign: .left, iconName: "text.alignleft")
                        cellHAlignButton(titleKey: "table_align_center", hAlign: .center, iconName: "text.aligncenter")
                        cellHAlignButton(titleKey: "table_align_right", hAlign: .right, iconName: "text.alignright")
                    }
                }
                .padding(.vertical, 4)
            }

            GroupBox(label: Text(l("table_borders")).font(.headline)) {
                VStack(alignment: .leading, spacing: 12) {
                    Picker(l("table_borders"), selection: Binding(
                        get: { workingTable.borderMode ?? .all },
                        set: { workingTable.borderMode = ($0 == .all ? nil : $0) }
                    )) {
                        Text(l("table_border_all")).tag(TableBorderMode.all)
                        Text(l("table_border_outer")).tag(TableBorderMode.outer)
                        Text(l("table_border_inner")).tag(TableBorderMode.inner)
                        Text(l("table_border_horizontal")).tag(TableBorderMode.horizontal)
                        Text(l("table_border_none")).tag(TableBorderMode.none)
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        Text(l("table_border_width"))
                        Spacer()
                        Stepper("\(Int((workingTable.borderWidth ?? 1.0) * 10) / 10) pt", value: Binding(
                            get: { Double(workingTable.borderWidth ?? 1.0) },
                            set: { workingTable.borderWidth = CGFloat($0) }
                        ), in: 0.5...6.0, step: 0.5)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func cellVAlignButton(titleKey: String, vAlign: TableVAlign, iconName: String) -> some View {
        let isSelected = (workingTable.style(row: activeRowIndex, col: activeColIndex).vAlign ?? .bottom) == vAlign
        return Button {
            workingTable.updateStyle(rows: 0...(workingTable.rows - 1), cols: 0...(workingTable.cols - 1)) {
                $0.vAlign = vAlign
            }
        } label: {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(isSelected ? Color.accentColor : Color.secondary.opacity(0.4), lineWidth: isSelected ? 2 : 1)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isSelected ? Color.accentColor.opacity(0.12) : Color(uiColor: .systemBackground))
                    )
                    .frame(width: 64, height: 44)
                    .overlay(
                        Image(systemName: iconName)
                            .font(.system(size: 18))
                            .foregroundColor(isSelected ? .accentColor : .primary)
                    )
                Text(l(titleKey))
                    .font(.caption)
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func cellHAlignButton(titleKey: String, hAlign: TableHAlign, iconName: String) -> some View {
        let isSelected = (workingTable.style(row: activeRowIndex, col: activeColIndex).hAlign ?? .left) == hAlign
        return Button {
            workingTable.updateStyle(rows: 0...(workingTable.rows - 1), cols: 0...(workingTable.cols - 1)) {
                $0.hAlign = (hAlign == .left ? nil : hAlign)
            }
        } label: {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(isSelected ? Color.accentColor : Color.secondary.opacity(0.4), lineWidth: isSelected ? 2 : 1)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isSelected ? Color.accentColor.opacity(0.12) : Color(uiColor: .systemBackground))
                    )
                    .frame(width: 64, height: 44)
                    .overlay(
                        Image(systemName: iconName)
                            .font(.system(size: 18))
                            .foregroundColor(isSelected ? .accentColor : .primary)
                    )
                Text(l(titleKey))
                    .font(.caption)
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - 分頁五：替代文字

    private var altTextTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(l("table_title_text"))
                .font(.headline)
            TextField("", text: Binding(
                get: { workingTable.altTitle ?? "" },
                set: { workingTable.altTitle = $0.isEmpty ? nil : $0 }
            ))
            .textFieldStyle(.roundedBorder)

            Text(l("table_description_text"))
                .font(.headline)
            TextEditor(text: Binding(
                get: { workingTable.altDescription ?? "" },
                set: { workingTable.altDescription = $0.isEmpty ? nil : $0 }
            ))
            .frame(height: 120)
            .padding(4)
            .background(Color(uiColor: .systemBackground))
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3), lineWidth: 1))
        }
    }
}
