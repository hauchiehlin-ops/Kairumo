//
//  ChartSpec.swift
//  Kairumo
//
//  圖表的資料模型 —— 與核心 `padnote-chart` 的 `ChartSpec` 一對一對應。
//
//  # 為什麼要有這份 Swift 鏡射
//
//  版面計算在核心（兩個平台才會算出同一張圖），但**編輯**發生在這裡：
//  使用者改一個欄位，介面要立刻重畫。把規格以 Codable 留在 Swift，
//  SwiftUI 的 `@State` 就能直接綁到每一個欄位；要重畫時再序列化成 JSON
//  交給核心。
//
//  這份 JSON 也是**存進筆記檔**的東西（走 `setBlockAppearance` 與
//  `NoteImageAttachment.chartSpecJSON`）。存規格不是存圖片，所以圖表
//  隨時都能重新編修 —— 存成圖片的話，那張圖就是最終產物，資料再也回不來。
//
//  ⚠️ 欄位名稱必須與 Rust 的 `#[serde(rename_all = "camelCase")]` 完全一致，
//  Android 的 `ChartSpec.kt` 也是同一組名稱。改這裡就要三邊一起改。
//

import Foundation

/// 圖表類型。`rawValue` 即 JSON 值，必須與 Rust 的 `ChartKind` 一致。
public enum ChartKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case bar
    case stackedBar
    case horizontalBar
    case line
    case smoothLine
    case area
    case stackedArea
    case pie
    case doughnut
    case scatter
    case radar

    public var id: String { rawValue }

    /// 這種圖有沒有直角座標軸 —— 沒有的話，軸的設定欄位就不該出現在介面上。
    public var hasAxes: Bool {
        switch self {
        case .pie, .doughnut, .radar: return false
        default: return true
        }
    }

    /// 這種圖只畫第一個資料數列。介面要據此提示使用者，而不是讓他納悶
    /// 為什麼第二欄的數字沒有出現。
    public var usesSingleSeries: Bool { self == .pie || self == .doughnut }

    public var iconName: String {
        switch self {
        case .bar: return "chart.bar.fill"
        case .stackedBar: return "chart.bar.doc.horizontal"
        case .horizontalBar: return "chart.bar.xaxis"
        case .line: return "chart.line.uptrend.xyaxis"
        case .smoothLine: return "point.topleft.down.curvedto.point.bottomright.up"
        case .area: return "chart.line.flattrend.xyaxis"
        case .stackedArea: return "square.stack.3d.down.right"
        case .pie: return "chart.pie.fill"
        case .doughnut: return "circle.circle"
        case .scatter: return "chart.dots.scatter"
        case .radar: return "hexagon"
        }
    }

    /// 在地化鍵。字串表在六個語系裡都有。
    public var localizationKey: String { "chart_kind_\(rawValue)" }
}

public enum ChartLegendPosition: String, Codable, CaseIterable, Identifiable, Sendable {
    case none, top, bottom, right
    public var id: String { rawValue }
    public var localizationKey: String { "chart_legend_\(rawValue)" }
}

public enum ChartLabelPosition: String, Codable, CaseIterable, Identifiable, Sendable {
    case none, outside, inside, center
    public var id: String { rawValue }
    public var localizationKey: String { "chart_labels_\(rawValue)" }
}

/// 一個座標軸的設定。
public struct ChartAxisSpec: Codable, Hashable, Sendable {
    public var title: String = ""
    public var showLine: Bool = true
    public var showTicks: Bool = true
    public var showLabels: Bool = true
    public var showGrid: Bool = false
    /// 固定最小值。`nil` 代表由資料決定。
    public var min: Double?
    public var max: Double?
    /// 固定刻度間距。`nil` 代表由核心挑一個「好看的數字」。
    public var step: Double?

    public init() {}

    /// 舊檔或別的平台寫的檔可能缺欄位 —— 缺的一律回到預設值，不是解碼失敗。
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        showLine = try c.decodeIfPresent(Bool.self, forKey: .showLine) ?? true
        showTicks = try c.decodeIfPresent(Bool.self, forKey: .showTicks) ?? true
        showLabels = try c.decodeIfPresent(Bool.self, forKey: .showLabels) ?? true
        showGrid = try c.decodeIfPresent(Bool.self, forKey: .showGrid) ?? false
        min = try c.decodeIfPresent(Double.self, forKey: .min)
        max = try c.decodeIfPresent(Double.self, forKey: .max)
        step = try c.decodeIfPresent(Double.self, forKey: .step)
    }
}

/// 一個資料數列 —— 試算表裡的一欄。
public struct ChartSeries: Codable, Hashable, Identifiable, Sendable {
    /// 只存在於本機，不寫進 JSON。表格重新排序時 SwiftUI 靠它認欄位。
    public var id: UUID = UUID()
    public var name: String = ""
    public var values: [Double] = []
    /// `#RRGGBB`。空字串代表用核心的預設色盤依序取色。
    public var colorHex: String = ""

    private enum CodingKeys: String, CodingKey { case name, values, colorHex }

    public init(name: String = "", values: [Double] = [], colorHex: String = "") {
        self.name = name
        self.values = values
        self.colorHex = colorHex
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        values = try c.decodeIfPresent([Double].self, forKey: .values) ?? []
        colorHex = try c.decodeIfPresent(String.self, forKey: .colorHex) ?? ""
        id = UUID()
    }
}

/// 一張圖表的完整設定。
public struct ChartSpec: Codable, Hashable, Sendable {
    public var kind: ChartKind = .bar
    public var title: String = ""
    /// 類別名稱 —— 試算表裡的第一欄。
    public var categories: [String] = []
    public var series: [ChartSeries] = []

    public var legend: ChartLegendPosition = .bottom
    public var dataLabels: ChartLabelPosition = .none
    public var labelDecimals: UInt32 = 0

    public var xAxis: ChartAxisSpec = ChartAxisSpec()
    public var yAxis: ChartAxisSpec = {
        var axis = ChartAxisSpec()
        axis.showGrid = true
        return axis
    }()

    /// 長條佔類別寬度的比例。Excel 的「類別間距」反過來講同一件事。
    public var barWidthRatio: Double = 0.7
    /// 環圈的內徑比例。
    public var doughnutHoleRatio: Double = 0.55

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = try c.decodeIfPresent(ChartKind.self, forKey: .kind) ?? .bar
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        categories = try c.decodeIfPresent([String].self, forKey: .categories) ?? []
        series = try c.decodeIfPresent([ChartSeries].self, forKey: .series) ?? []
        legend = try c.decodeIfPresent(ChartLegendPosition.self, forKey: .legend) ?? .bottom
        dataLabels = try c.decodeIfPresent(ChartLabelPosition.self, forKey: .dataLabels) ?? .none
        labelDecimals = try c.decodeIfPresent(UInt32.self, forKey: .labelDecimals) ?? 0
        xAxis = try c.decodeIfPresent(ChartAxisSpec.self, forKey: .xAxis) ?? ChartAxisSpec()
        yAxis = try c.decodeIfPresent(ChartAxisSpec.self, forKey: .yAxis) ?? {
            var axis = ChartAxisSpec(); axis.showGrid = true; return axis
        }()
        barWidthRatio = try c.decodeIfPresent(Double.self, forKey: .barWidthRatio) ?? 0.7
        doughnutHoleRatio = try c.decodeIfPresent(Double.self, forKey: .doughnutHoleRatio) ?? 0.55
    }

    // MARK: - JSON

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        // 欄位順序固定，同一份規格才會得到同一份位元組 —— 否則每次存檔
        // 都會產生一筆「內容有變」的操作，同步時看起來像使用者改了東西。
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    public func encodedJSON() -> String {
        (try? Self.encoder.encode(self)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }

    /// 從 JSON 讀回一份設定。讀不懂時回 `nil`，呼叫端決定要不要退回成圖片。
    public static func decode(from json: String) -> ChartSpec? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(ChartSpec.self, from: data)
    }

    /// 核心給的預設設定 —— 新插入的圖表要馬上看得到東西。
    public static func makeDefault() -> ChartSpec {
        decode(from: chartDefaultSpecJson()) ?? ChartSpec()
    }

    // MARK: - 編輯

    /// 表格的列數：類別數與最長數列取大的那個。
    ///
    /// 取大而不是取小：使用者多打了一列數字卻沒補類別名稱時，那列不該消失
    /// （核心會用序號補上類別名）。
    public var rowCount: Int {
        Swift.max(categories.count, series.map(\.values.count).max() ?? 0)
    }

    /// 讀寫第 `series` 欄、第 `row` 列的數字。超出範圍時補 0 而不是崩潰。
    public func value(series seriesIndex: Int, row: Int) -> Double {
        guard series.indices.contains(seriesIndex),
              series[seriesIndex].values.indices.contains(row) else { return 0 }
        return series[seriesIndex].values[row]
    }

    public mutating func setValue(_ value: Double, series seriesIndex: Int, row: Int) {
        guard series.indices.contains(seriesIndex) else { return }
        while series[seriesIndex].values.count <= row {
            series[seriesIndex].values.append(0)
        }
        series[seriesIndex].values[row] = value
    }

    public func category(_ index: Int) -> String {
        categories.indices.contains(index) ? categories[index] : ""
    }

    public mutating func setCategory(_ name: String, at index: Int) {
        while categories.count <= index { categories.append("") }
        categories[index] = name
    }

    /// 在表格末尾加一列。每一欄都要補一格，否則欄與欄會對不齊。
    public mutating func addRow() {
        let row = rowCount
        categories.append("")
        for index in series.indices {
            while series[index].values.count < row { series[index].values.append(0) }
            series[index].values.append(0)
        }
    }

    public mutating func removeRow(_ row: Int) {
        // 最後一列不能刪：沒有資料的圖表畫不出來，畫布會忽然變空白。
        guard rowCount > 1 else { return }
        if categories.indices.contains(row) { categories.remove(at: row) }
        for index in series.indices where series[index].values.indices.contains(row) {
            series[index].values.remove(at: row)
        }
    }

    public mutating func addSeries() {
        var new = ChartSeries(name: "", values: Array(repeating: 0, count: Swift.max(1, rowCount)))
        new.colorHex = chartPaletteColor(index: UInt32(series.count % Int(chartPaletteCount())))
        series.append(new)
    }

    public mutating func removeSeries(_ index: Int) {
        guard series.count > 1, series.indices.contains(index) else { return }
        series.remove(at: index)
    }

    /// 第 `index` 欄實際會被畫成什麼顏色 —— 取色器要顯示的就是這個。
    public func effectiveColorHex(_ index: Int) -> String {
        let explicit = series.indices.contains(index) ? series[index].colorHex : ""
        return explicit.isEmpty ? chartPaletteColor(index: UInt32(index)) : explicit
    }

    /// 能不能畫。核心說了算 —— 判斷條件抄第二份就會跟核心不一致。
    public var isDrawable: Bool { chartSpecIsDrawable(specJson: encodedJSON()) }
}

// MARK: - 區塊外觀

/// 圖片區塊的外觀 JSON（`.padnote` 套件裡的 `SetBlockAppearance`）。
///
/// 刻意包一層 `{"object":"chart","chart":{…}}` 而不是把規格直接寫進去：
/// 圖片區塊日後還會有別的外觀資訊（邊框、濾鏡），沒有這個標記的話，讀的人
/// 只能靠猜 JSON 的形狀來判斷這是不是一張圖表。
///
/// Android 的 `ChartAppearance.kt` 用同一組鍵。
public enum ChartAppearance {
    static let objectKey = "object"
    static let objectValue = "chart"
    static let chartKey = "chart"

    /// 把規格包成區塊外觀。
    public static func encode(_ spec: ChartSpec) -> String {
        let inner = spec.encodedJSON()
        return "{\"\(objectKey)\":\"\(objectValue)\",\"\(chartKey)\":\(inner)}"
    }

    /// 從區塊外觀讀回規格。不是圖表時回 `nil`。
    public static func decode(_ json: String) -> ChartSpec? {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              object[objectKey] as? String == objectValue,
              let chart = object[chartKey],
              let chartData = try? JSONSerialization.data(withJSONObject: chart)
        else { return nil }
        return try? JSONDecoder().decode(ChartSpec.self, from: chartData)
    }
}

/// 正在重新編修的那張圖表。
///
/// `sheet(item:)` 需要一個 `Identifiable` 的值；只帶 id 的話，開啟工作表時
/// 還要回頭到筆記裡撈規格，而那時候附件可能已經被刪掉了。
public struct ChartEditTarget: Identifiable, Hashable, Sendable {
    public let id: String
    public let spec: ChartSpec

    public init(id: String, spec: ChartSpec) {
        self.id = id
        self.spec = spec
    }
}
