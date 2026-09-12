//
//  ChartStudioView.swift
//  Kairumo
//
//  數字表列視覺化製圖中樞
//  支援長條圖 (Bar Chart)、折線走勢圖 (Line Chart)、圓餅比例圖 (Pie Chart)
//  支援範例數據載入、自訂表格增減與高解析度圖表插入筆記畫布
//

import SwiftUI

public enum ChartType: String, CaseIterable, Identifiable {
    case bar = "長條圖"
    case line = "折線圖"
    case pie = "圓餅圖"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .bar: return "chart.bar.fill"
        case .line: return "chart.line.uptrend.xyaxis"
        case .pie: return "chart.pie.fill"
        }
    }
}

public struct ChartDataEntry: Identifiable, Hashable {
    public let id = UUID()
    public var label: String
    public var value: Double

    public init(label: String, value: Double) {
        self.label = label
        self.value = value
    }
}

public struct ChartStudioView: View {
    var onInsertChart: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var localizationManager = LocalizationManager.shared

    @State private var chartTitle: String = "數據分析圖表"
    @State private var selectedChartType: ChartType = .bar
    @State private var entries: [ChartDataEntry] = [
        ChartDataEntry(label: "一月", value: 150),
        ChartDataEntry(label: "二月", value: 280),
        ChartDataEntry(label: "三月", value: 210),
        ChartDataEntry(label: "四月", value: 360),
        ChartDataEntry(label: "五月", value: 310)
    ]

    private let chartColors: [Color] = [
        .blue, .purple, .teal, .orange, .pink, .green, .indigo, .red
    ]

    public init(onInsertChart: @escaping (UIImage) -> Void) {
        self.onInsertChart = onInsertChart
    }

    public var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                // 左側：數據編輯區
                VStack(spacing: 12) {
                    TextField(localizationManager.localized("chart_title"), text: $chartTitle)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)

                    Picker("圖表類型", selection: $selectedChartType) {
                        ForEach(ChartType.allCases) { type in
                            Label(type.rawValue, systemImage: type.iconName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    HStack {
                        Text("數據列表")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("新增項目") {
                            entries.append(ChartDataEntry(label: "項目 \(entries.count + 1)", value: Double.random(in: 50...300).rounded()))
                        }
                        .font(.caption)

                        Button(localizationManager.localized("sample_data")) {
                            loadSamplePreset()
                        }
                        .font(.caption)
                    }
                    .padding(.horizontal)

                    List {
                        ForEach($entries) { $entry in
                            HStack {
                                TextField("標籤", text: $entry.label)
                                    .frame(maxWidth: 90)
                                    .textFieldStyle(.roundedBorder)

                                TextField("數值", value: $entry.value, format: .number)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.roundedBorder)

                                Button {
                                    if entries.count > 1 {
                                        entries.removeAll { $0.id == entry.id }
                                    }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
                .frame(width: 320)
                .background(Color(uiColor: .secondarySystemGroupedBackground))

                Divider()

                // 右側：即時圖表預覽
                VStack(spacing: 16) {
                    Text("圖表即時預覽")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(uiColor: .systemBackground))
                            .shadow(color: Color.black.opacity(0.08), radius: 8, y: 4)

                        chartPreviewContent
                            .padding(24)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(20)

                    Button {
                        if let img = renderChartToImage() {
                            onInsertChart(img)
                            dismiss()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text(localizationManager.localized("insert_chart"))
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 20)
                }
                .background(Color(uiColor: .systemGroupedBackground))
            }
            .navigationTitle(localizationManager.localized("chart_studio"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizationManager.localized("cancel")) {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 780, minHeight: 520)
    }

    // MARK: - 圖表預覽畫布
    @ViewBuilder
    private var chartPreviewContent: some View {
        VStack(spacing: 16) {
            Text(chartTitle)
                .font(.title2)
                .fontWeight(.bold)

            switch selectedChartType {
            case .bar:
                barChartView
            case .line:
                lineChartView
            case .pie:
                pieChartView
            }
        }
    }

    // 1. 長條圖
    private var barChartView: some View {
        let maxVal = max(1, entries.map { $0.value }.max() ?? 1)

        return GeometryReader { proxy in
            let availableHeight = proxy.size.height - 40
            HStack(alignment: .bottom, spacing: 14) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    let h = CGFloat(entry.value / maxVal) * availableHeight
                    let color = chartColors[index % chartColors.count]

                    VStack(spacing: 4) {
                        Text("\(Int(entry.value))")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)

                        RoundedRectangle(cornerRadius: 6)
                            .fill(color)
                            .frame(height: max(6, h))

                        Text(entry.label)
                            .font(.caption2)
                            .lineLimit(1)
                            .frame(maxWidth: 50)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // 2. 折線圖
    private var lineChartView: some View {
        let maxVal = max(1, entries.map { $0.value }.max() ?? 1)

        return GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height - 40
            let count = max(1, entries.count)
            let stepX = count > 1 ? w / CGFloat(count - 1) : w / 2

            ZStack {
                // 背景網格橫線
                VStack(spacing: h / 4) {
                    ForEach(0..<5) { _ in
                        Divider()
                    }
                }

                // 折線路徑
                Path { path in
                    for (i, entry) in entries.enumerated() {
                        let x = count == 1 ? w / 2 : CGFloat(i) * stepX
                        let y = h - CGFloat(entry.value / maxVal) * (h - 20)
                        if i == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                // 數據節點圓點
                ForEach(Array(entries.enumerated()), id: \.element.id) { i, entry in
                    let x = count == 1 ? w / 2 : CGFloat(i) * stepX
                    let y = h - CGFloat(entry.value / maxVal) * (h - 20)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(Color.accentColor, lineWidth: 2))
                        .position(x: x, y: y)
                }
            }
        }
    }

    // 3. 圓餅圖
    private var pieChartView: some View {
        let total = max(1, entries.map { max(0, $0.value) }.reduce(0, +))

        return GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let radius = size * 0.4

            ZStack {
                ForEach(pieSlices(total: total), id: \.id) { slice in
                    Path { path in
                        path.move(to: center)
                        path.addArc(
                            center: center,
                            radius: radius,
                            startAngle: slice.startAngle,
                            endAngle: slice.endAngle,
                            clockwise: false
                        )
                        path.closeSubpath()
                    }
                    .fill(slice.color)
                }

                // 環形中空美化
                Circle()
                    .fill(Color(uiColor: .systemBackground))
                    .frame(width: radius * 0.9, height: radius * 0.9)
            }
        }
    }

    private struct PieSlice: Identifiable {
        let id = UUID()
        let startAngle: Angle
        let endAngle: Angle
        let color: Color
    }

    private func pieSlices(total: Double) -> [PieSlice] {
        var current = Angle(degrees: -90)
        var slices: [PieSlice] = []

        for (i, entry) in entries.enumerated() {
            let deg = (max(0, entry.value) / total) * 360.0
            let next = current + Angle(degrees: deg)
            slices.append(PieSlice(startAngle: current, endAngle: next, color: chartColors[i % chartColors.count]))
            current = next
        }
        return slices
    }

    private func loadSamplePreset() {
        self.chartTitle = "2026 季度收支報表"
        self.entries = [
            ChartDataEntry(label: "第一季", value: 420),
            ChartDataEntry(label: "第二季", value: 650),
            ChartDataEntry(label: "第三季", value: 580),
            ChartDataEntry(label: "第四季", value: 890)
        ]
    }

    /// 將圖表視圖渲染為高解析度 UIImage
    @MainActor
    private func renderChartToImage() -> UIImage? {
        let renderer = ImageRenderer(content:
            VStack(spacing: 12) {
                Text(chartTitle)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                switch selectedChartType {
                case .bar:
                    barChartView
                case .line:
                    lineChartView
                case .pie:
                    pieChartView
                }
            }
            .padding(20)
            .frame(width: 480, height: 320)
            .background(Color.white)
        )
        renderer.scale = 2.0
        return renderer.uiImage
    }
}
