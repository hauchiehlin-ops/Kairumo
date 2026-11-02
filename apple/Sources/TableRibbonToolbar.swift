//
//  TableRibbonToolbar.swift
//  Kairumo
//
//  仿 Word「表格設計」與「表格版面配置」頂部工具列（Ribbon Toolbars）
//  提供：列與欄操作、九宮格對齊、樣式庫、網底、框線、合併與分割全功能快捷控制
//

import SwiftUI

public struct TableRibbonToolbar: View {
    @Binding var table: NoteTableAttachment
    @Binding var showProperties: Bool
    let onDelete: () -> Void
    let onCommit: () -> Void

    @ObservedObject private var localizationManager = LocalizationManager.shared

    private enum RibbonTab: Hashable {
        case design, layout
    }
    @State private var activeTab: RibbonTab = .layout

    public init(
        table: Binding<NoteTableAttachment>,
        showProperties: Binding<Bool>,
        onDelete: @escaping () -> Void,
        onCommit: @escaping () -> Void
    ) {
        self._table = table
        self._showProperties = showProperties
        self.onDelete = onDelete
        self.onCommit = onCommit
    }

    private func l(_ key: String) -> String { localizationManager.localized(key) }

    public var body: some View {
        VStack(spacing: 4) {
            // 頂部分頁切換按鈕
            HStack(spacing: 8) {
                tabButton(title: l("table_layout"), tab: .layout, icon: "tablecells")
                tabButton(title: l("table_design"), tab: .design, icon: "paintpalette")

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
        HStack(spacing: 12) {
            // 列與欄增刪
            ribbonGroup(label: l("table_tab_row") + " & " + l("table_tab_column")) {
                HStack(spacing: 4) {
                    actionIconBtn(icon: "arrow.up.to.line", tooltip: "table_insert_row_above") {
                        table.insertRow(at: 0)
                        onCommit()
                    }
                    actionIconBtn(icon: "arrow.down.to.line", tooltip: "table_insert_row_below") {
                        table.insertRow(at: table.rows)
                        onCommit()
                    }
                    actionIconBtn(icon: "arrow.left.to.line", tooltip: "table_insert_col_left") {
                        table.insertColumn(at: 0)
                        onCommit()
                    }
                    actionIconBtn(icon: "arrow.right.to.line", tooltip: "table_insert_col_right") {
                        table.insertColumn(at: table.cols)
                        onCommit()
                    }
                    Divider().frame(height: 20)
                    actionIconBtn(icon: "minus.square", tooltip: "table_delete_row", isDestructive: true) {
                        if table.rows > 1 {
                            table.deleteRow(at: table.rows - 1)
                            onCommit()
                        }
                    }
                    actionIconBtn(icon: "rectangle.portrait.slash", tooltip: "table_delete_column", isDestructive: true) {
                        if table.cols > 1 {
                            table.deleteColumn(at: table.cols - 1)
                            onCommit()
                        }
                    }
                    actionIconBtn(icon: "trash", tooltip: "delete", isDestructive: true) {
                        onDelete()
                    }
                }
            }

            Divider().frame(height: 32)

            // 合併與分割
            ribbonGroup(label: l("table_merge_selection")) {
                HStack(spacing: 4) {
                    actionIconBtn(icon: "rectangle.compress.vertical", tooltip: "table_merge_selection") {
                        table.mergeRange(rows: 0...min(1, table.rows - 1), cols: 0...min(1, table.cols - 1))
                        onCommit()
                    }
                    actionIconBtn(icon: "rectangle.split.2x1", tooltip: "table_unmerge") {
                        table.unmerge(row: 0, col: 0)
                        onCommit()
                    }
                }
            }

            Divider().frame(height: 32)

            // 儲存格大小調整
            ribbonGroup(label: l("table_section_size")) {
                HStack(spacing: 4) {
                    actionIconBtn(icon: "distribute.vertical", tooltip: "table_distribute_rows") {
                        table.distributeRows()
                        onCommit()
                    }
                    actionIconBtn(icon: "distribute.horizontal", tooltip: "table_distribute_cols") {
                        table.distributeColumns()
                        onCommit()
                    }
                    actionIconBtn(icon: "arrow.up.left.and.arrow.down.right", tooltip: "table_autofit") {
                        table.autoFitSizes()
                        onCommit()
                    }
                }
            }

            Divider().frame(height: 32)

            // 九宮格對齊方式矩陣（對標圖 2 的 3x3 對齊按鈕）
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
        Button {
            table.updateStyle(rows: 0...(table.rows - 1), cols: 0...(table.cols - 1)) {
                $0.hAlign = (h == .left ? nil : h)
                $0.vAlign = v
            }
            onCommit()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
                .frame(width: 18, height: 13)
                .background(Color(uiColor: .systemBackground))
                .cornerRadius(2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(l(key))
        .help(l(key))
    }

    // MARK: - 表格設計工具（對標圖 3）

    private var designControls: some View {
        HStack(spacing: 12) {
            // 表格樣式選項
            ribbonGroup(label: l("table_design")) {
                HStack(spacing: 8) {
                    toggleTag(label: l("table_header_row"), isOn: $table.headerRow)
                    toggleTag(label: l("table_banded_rows"), isOn: Binding(
                        get: { table.bandedRows ?? true },
                        set: { table.bandedRows = $0; onCommit() }
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

            // 網底與框線
            ribbonGroup(label: l("table_shading") + " & " + l("table_borders")) {
                HStack(spacing: 8) {
                    ColorPicker("", selection: Binding(
                        get: { table.headerBackgroundHex.flatMap(Color.init(hex:)) ?? Color(hex: "#E9EEFC")! },
                        set: { table.headerBackgroundHex = $0.toHex(); onCommit() }
                    ))
                    .labelsHidden()

                    Menu {
                        Button(l("table_border_all")) { table.borderMode = .all; onCommit() }
                        Button(l("table_border_outer")) { table.borderMode = .outer; onCommit() }
                        Button(l("table_border_inner")) { table.borderMode = .inner; onCommit() }
                        Button(l("table_border_horizontal")) { table.borderMode = .horizontal; onCommit() }
                        Button(l("table_border_none")) { table.borderMode = TableBorderMode.none; onCommit() }
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
                }
            }
        }
    }

    private func styleGalleryBtn(name: String, headerHex: String, textHex: String? = nil, fillHex: String? = nil) -> some View {
        Button {
            table.headerBackgroundHex = headerHex
            table.headerRow = true
            table.bandedRows = true
            if let th = textHex {
                table.updateStyle(rows: 0...0, cols: 0...(table.cols - 1)) { $0.textColorHex = th }
            }
            onCommit()
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

    private func actionIconBtn(icon: String, tooltip: String, isDestructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(isDestructive ? .red : .primary)
                .frame(width: 24, height: 24)
                .background(Color(uiColor: .systemBackground))
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(l(tooltip))
        .help(l(tooltip))
    }

    private func toggleTag(label: String, isOn: Binding<Bool>) -> some View {
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
        .help(label)
    }
}
