//
//  ChartStudioView.swift
//  Kairumo
//
//  數字製圖 —— 表格編輯、圖表類型、格式設定，以及即時預覽。
//
//  # 為什麼不是直接產生一張圖
//
//  這個介面編輯的是 [`ChartSpec`]，插入畫布時**規格與點陣圖一起交出去**：
//  點陣圖負責顯示與列印，規格負責讓使用者之後還改得動。只交點陣圖的話，
//  圖一旦插進去，裡面的數字就再也拿不回來了。
//
//  預覽走 `ChartPreview`，而它與插入時的點陣化用同一支繪製函式，也用同一個
//  核心版面引擎 —— 預覽與成品不會有落差，Android 算出來的也是同一張圖。
//

import SwiftUI

public struct ChartStudioView: View {

    /// 交出去的東西：規格（讓它之後改得動）與點陣圖（讓它顯示得出來）。
    public typealias Commit = (_ spec: ChartSpec, _ image: UIImage) -> Void

    private enum Inspector: String, CaseIterable, Identifiable {
        case data, type, format
        var id: String { rawValue }
        var localizationKey: String { "chart_tab_\(rawValue)" }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @State private var spec: ChartSpec
    @State private var inspector: Inspector = .data
    private let isEditingExisting: Bool
    private let onCommit: Commit

    /// 插入一張新圖表。
    public init(onCommit: @escaping Commit) {
        _spec = State(initialValue: ChartSpec.makeDefault())
        self.isEditingExisting = false
        self.onCommit = onCommit
    }

    /// 重新編修畫布上既有的圖表。
    ///
    /// 這個建構子就是「可重新編修」的入口：帶著原本的規格進來，使用者看到的
    /// 是自己當初輸入的數字，不是一張改不動的圖。
    public init(editing spec: ChartSpec, onCommit: @escaping Commit) {
        _spec = State(initialValue: spec)
        self.isEditingExisting = true
        self.onCommit = onCommit
    }

    public var body: some View {
        NavigationStack {
            // iPad / Mac 併排，iPhone 上下疊。
            //
            // 用 size class 而不是 `ViewThatFits`：預覽本來就會撐滿可用寬度，
            // `ViewThatFits` 會判定併排「放得下」而選它 —— 在 iPhone 上就變成
            // 一條被擠扁的檢閱器。
            Group {
                if horizontalSizeClass == .compact {
                    VStack(spacing: 0) {
                        preview.frame(height: 240)
                        Divider()
                        inspectorPane
                    }
                } else {
                    HStack(spacing: 0) {
                        preview
                        Divider()
                        inspectorPane.frame(width: 340)
                    }
                }
            }
            .navigationTitle(localizationManager.localized("chart_studio"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizationManager.localized("cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localizationManager.localized(isEditingExisting ? "chart_update" : "chart_insert")) {
                        commit()
                    }
                    // 畫不出來的規格插進去只會得到一塊空白。
                    .disabled(!spec.isDrawable)
                }
            }
        }
    }

    private func commit() {
        // 點陣圖的尺寸與插入畫布後的顯示尺寸同比例，插進去才不會被拉伸。
        guard let image = ChartRenderer.image(spec: spec, size: CGSize(width: 420, height: 300))
        else { return }
        onCommit(spec, image)
        dismiss()
    }

    // MARK: - 預覽

    private var preview: some View {
        ChartPreview(spec: spec)
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .secondarySystemBackground))
    }

    // MARK: - 檢閱器

    private var inspectorPane: some View {
        VStack(spacing: 0) {
            Picker("", selection: $inspector) {
                ForEach(Inspector.allCases) { tab in
                    Text(localizationManager.localized(tab.localizationKey)).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(12)

            Divider()

            switch inspector {
            case .data: dataSheet
            case .type: typeGallery
            case .format: formatPanel
            }
        }
    }

    // MARK: - 資料（試算表）

    private var dataSheet: some View {
        VStack(spacing: 0) {
            if spec.kind.usesSingleSeries && spec.series.count > 1 {
                // 說出來，使用者才不會納悶第二欄的數字為什麼沒有出現。
                Label(
                    localizationManager.localized("chart_single_series_hint"),
                    systemImage: "info.circle"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.top, 8)
            }

            ScrollView([.horizontal, .vertical]) {
                Grid(alignment: .leading, horizontalSpacing: 6, verticalSpacing: 4) {
                    GridRow {
                        Text(localizationManager.localized("chart_category_column"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 92, alignment: .leading)
                        ForEach(Array(spec.series.enumerated()), id: \.element.id) { index, _ in
                            seriesHeader(index)
                        }
                        Color.clear.frame(width: 24, height: 1)
                    }

                    ForEach(0..<spec.rowCount, id: \.self) { row in
                        GridRow {
                            TextField(
                                "\(row + 1)",
                                text: Binding(
                                    get: { spec.category(row) },
                                    set: { spec.setCategory($0, at: row) }
                                )
                            )
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 92)

                            ForEach(Array(spec.series.enumerated()), id: \.element.id) { index, _ in
                                numberCell(series: index, row: row)
                            }

                            Button {
                                spec.removeRow(row)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                            .disabled(spec.rowCount <= 1)
                            .accessibilityLabel(localizationManager.localized("chart_delete_row"))
                        }
                    }
                }
                .padding(12)
            }

            Divider()
            HStack {
                Button {
                    spec.addRow()
                } label: {
                    Label(localizationManager.localized("chart_add_row"), systemImage: "plus")
                }
                Spacer()
                Button {
                    spec.addSeries()
                } label: {
                    Label(localizationManager.localized("chart_add_series"), systemImage: "plus.square.on.square")
                }
            }
            .font(.footnote)
            .padding(12)
        }
    }

    private func seriesHeader(_ index: Int) -> some View {
        VStack(spacing: 3) {
            TextField(
                "\(localizationManager.localized("chart_series_name")) \(index + 1)",
                text: Binding(
                    get: { spec.series.indices.contains(index) ? spec.series[index].name : "" },
                    set: { if spec.series.indices.contains(index) { spec.series[index].name = $0 } }
                )
            )
            .textFieldStyle(.roundedBorder)
            .font(.caption)

            HStack(spacing: 4) {
                ColorPicker(
                    "",
                    selection: Binding(
                        get: { Color(hex: spec.effectiveColorHex(index)) ?? .blue },
                        set: { newColor in
                            guard spec.series.indices.contains(index),
                                  let hex = newColor.toHex() else { return }
                            spec.series[index].colorHex = hex
                        }
                    ),
                    supportsOpacity: false
                )
                .labelsHidden()
                .frame(width: 22, height: 22)

                Button {
                    spec.removeSeries(index)
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .disabled(spec.series.count <= 1)
                .accessibilityLabel(localizationManager.localized("chart_delete_series"))
            }
        }
        .frame(width: 104)
    }

    private func numberCell(series index: Int, row: Int) -> some View {
        TextField(
            "0",
            value: Binding(
                get: { spec.value(series: index, row: row) },
                set: { spec.setValue($0, series: index, row: row) }
            ),
            format: .number
        )
        .textFieldStyle(.roundedBorder)
        .multilineTextAlignment(.trailing)
        .frame(width: 104)
        #if !os(macOS)
        .keyboardType(.numbersAndPunctuation)
        #endif
    }

    // MARK: - 類型

    private var typeGallery: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 10) {
                ForEach(ChartKind.allCases) { kind in
                    Button {
                        spec.kind = kind
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: kind.iconName)
                                .font(.title2)
                            Text(localizationManager.localized(kind.localizationKey))
                                .font(.caption2)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, minHeight: 68)
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(spec.kind == kind
                                      ? Color.accentColor.opacity(0.18)
                                      : Color(uiColor: .secondarySystemBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(spec.kind == kind ? Color.accentColor : .clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
        }
    }

    // MARK: - 格式

    private var formatPanel: some View {
        Form {
            Section {
                TextField(localizationManager.localized("chart_title"), text: $spec.title)
            }

            if spec.kind.hasAxes {
                Section(localizationManager.localized("chart_section_axes")) {
                    TextField(localizationManager.localized("chart_x_axis_title"), text: $spec.xAxis.title)
                    TextField(localizationManager.localized("chart_y_axis_title"), text: $spec.yAxis.title)
                    Toggle(localizationManager.localized("chart_show_grid"), isOn: $spec.yAxis.showGrid)
                    Toggle(localizationManager.localized("chart_show_axis_labels"), isOn: $spec.yAxis.showLabels)
                    optionalNumberField("chart_axis_min", value: $spec.yAxis.min)
                    optionalNumberField("chart_axis_max", value: $spec.yAxis.max)
                    optionalNumberField("chart_axis_step", value: $spec.yAxis.step)
                }
            }

            Section(localizationManager.localized("chart_section_legend")) {
                Picker(localizationManager.localized("chart_legend_position"), selection: $spec.legend) {
                    ForEach(ChartLegendPosition.allCases) { position in
                        Text(localizationManager.localized(position.localizationKey)).tag(position)
                    }
                }
                Picker(localizationManager.localized("chart_data_labels"), selection: $spec.dataLabels) {
                    ForEach(ChartLabelPosition.allCases) { position in
                        Text(localizationManager.localized(position.localizationKey)).tag(position)
                    }
                }
                if spec.dataLabels != .none {
                    Stepper(
                        "\(localizationManager.localized("chart_label_decimals"))　\(spec.labelDecimals)",
                        value: Binding(
                            get: { Int(spec.labelDecimals) },
                            set: { spec.labelDecimals = UInt32(max(0, min(4, $0))) }
                        ),
                        in: 0...4
                    )
                }
            }

            Section(localizationManager.localized("chart_section_style")) {
                if spec.kind == .bar || spec.kind == .stackedBar || spec.kind == .horizontalBar {
                    VStack(alignment: .leading) {
                        Text(localizationManager.localized("chart_bar_width"))
                        Slider(value: $spec.barWidthRatio, in: 0.2...1.0)
                    }
                }
                if spec.kind == .doughnut {
                    VStack(alignment: .leading) {
                        Text(localizationManager.localized("chart_doughnut_hole"))
                        Slider(value: $spec.doughnutHoleRatio, in: 0.0...0.85)
                    }
                }
            }
        }
    }

    /// 「自動 / 指定」的數值欄位。
    ///
    /// 空字串代表交給核心決定，不是 0 —— 把留空當成 0 的話，使用者清掉欄位
    /// 就會意外把軸釘死在零。
    private func optionalNumberField(_ key: String, value: Binding<Double?>) -> some View {
        TextField(
            localizationManager.localized(key),
            text: Binding(
                get: { value.wrappedValue.map { String(format: "%g", $0) } ?? "" },
                set: { text in
                    let trimmed = text.trimmingCharacters(in: .whitespaces)
                    value.wrappedValue = trimmed.isEmpty ? nil : Double(trimmed)
                }
            )
        )
        .multilineTextAlignment(.trailing)
        #if !os(macOS)
        .keyboardType(.numbersAndPunctuation)
        #endif
    }
}
