//
//  NoteShape.swift
//  Kairumo
//
//  畫布上的形狀與流程圖。
//
//  # 這一層不算幾何
//
//  外框、錨點、連接線的路徑、箭頭全部來自核心的 `shapeOutline` /
//  `connectionPath` / `connectionArrowHead`。那些 FFI 從 S-52 就開出來了，
//  但**兩個平台都沒有呼叫點** —— 建了用不到等於沒建。
//
//  幾何放在核心的理由與圖表、表格相同：ISO 5807 的流程圖符號有明確的比例
//  （判斷菱形的頂點位置、資料平行四邊形的斜度），各平台各畫一份的話，
//  同一張流程圖在兩台裝置上會長得不一樣。
//

import SwiftUI

/// 畫布上的一個形狀。
public struct NoteShapeAttachment: Identifiable, Codable, Hashable {
    public let id: String
    /// 繞自身中心的旋轉角度（度，順時針）。
    ///
    /// **必須是 Optional** —— 舊檔沒有這個鍵，非 Optional 會讓整份筆記
    /// 解碼失敗（見 `ObjectFrameStyled.canvasRotation` 的說明）。
    public var rotationDegrees: Double?
    public var canvasRotation: Double {
        get { rotationDegrees ?? 0 }
        set { rotationDegrees = newValue }
    }
    public var pageIndex: Int
    /// `FfiShapeKind` 的名稱，例如 `"process"`、`"decision"`。
    ///
    /// 存字串而不是列舉序號：序號會隨核心新增種類而位移，
    /// 那會讓舊筆記裡的「判斷」變成「資料」。
    public var kindName: String
    public var x: CGFloat
    public var y: CGFloat
    public var width: CGFloat
    public var height: CGFloat
    public var cornerRadius: CGFloat
    public var label: String
    public var strokeColorHex: String?
    /// `"clear"` 為透明。
    public var fillColorHex: String?
    public var lineWidth: CGFloat
    /// 所屬群組的 id。`nil` 代表這個形狀在最上層。
    ///
    /// 群組是核心物件樹裡真正的節點（`Group`），不是平台自己畫出來的框 ——
    /// 所以它跨得過平台：在一台裝置上群組起來，另一台打開仍然是一組。
    public var groupId: String?

    // MARK: - 進階樣式
    //
    // 全部是 Optional：舊檔沒有這些鍵，非 Optional 會讓整份筆記解碼失敗。
    // `nil` 一律代表「與以前一樣」，所以升級上來的流程圖外觀完全不變。

    /// 線條樣式：`"solid"`（預設）、`"dashed"`、`"dotted"`。
    public var dashStyle: String?
    /// 形狀內文字大小。`nil` 為 14。
    public var fontSize: CGFloat?
    /// 文字顏色。`nil` 沿用前景色。
    public var textColorHex: String?
    public var isBold: Bool?
    public var isItalic: Bool?
    /// 整個形狀的不透明度（0.1–1）。`nil` 為 1。
    public var opacity: Double?

    public init(
        id: String = UUID().uuidString,
        pageIndex: Int = 0,
        kindName: String = "process",
        x: CGFloat = 80,
        y: CGFloat = 140,
        // 插入尺寸刻意保守。太大的話，使用者拿到的第一件事是縮小它 ——
        // 而縮小把手是這一版才有的。小了可以拉大，大了擋住底下的內容。
        width: CGFloat = 120,
        height: CGFloat = 60,
        cornerRadius: CGFloat = 8,
        label: String = "",
        strokeColorHex: String? = nil,
        fillColorHex: String? = nil,
        lineWidth: CGFloat = 2,
        groupId: String? = nil
    ) {
        self.id = id
        self.pageIndex = pageIndex
        self.kindName = kindName
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
        self.label = label
        self.strokeColorHex = strokeColorHex
        self.fillColorHex = fillColorHex
        self.lineWidth = lineWidth
        self.groupId = groupId
    }

    /// 核心認得的形狀種類。名稱對不上時退回「處理」方框 —— 那是最無害的選擇，
    /// 使用者至少看得到一個方塊，而不是一片空白。
    public var kind: FfiShapeKind {
        NoteShapeAttachment.kind(named: kindName) ?? .process
    }

    public static func kind(named name: String) -> FfiShapeKind? {
        allShapeKinds().first { String(describing: $0).lowercased() == name.lowercased() }
    }

    public static func name(of kind: FfiShapeKind) -> String {
        String(describing: kind).lowercased()
    }

    /// 核心算出來的外框頂點（畫布座標）。
    public func outline(segments: UInt32 = 48) -> [CGPoint] {
        shapeOutline(
            shape: FfiShape(
                kind: kind,
                bounds: FfiRect(
                    minX: Float(x), minY: Float(y),
                    maxX: Float(x + width), maxY: Float(y + height)
                ),
                cornerRadius: Float(cornerRadius),
                rotationDegrees: 0
            ),
            segments: segments
        ).map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) }
    }

    /// 這個形狀在 ISO 5807 裡代表什麼（流程圖符號才有）。
    public var semantic: String? { shapeSemantic(kind: kind) }

    /// 這種形狀能不能放字。連接線與箭頭不能。
    public var acceptsText: Bool { shapeAcceptsText(kind: kind) }

    /// 線狀形狀（線／箭頭／雙箭頭）。路徑不能收尾，也沒有可填色的內部。
    public var isLinear: Bool { shapeIsLinear(kind: kind) }

    /// 兩端的箭頭三角形（畫布座標）。非線狀形狀回傳空陣列。
    ///
    /// 箭頭大小跟著線寬走：兩點的粗線配一個小三角形會看不出是箭頭。
    public func arrowHeads() -> [[CGPoint]] {
        guard isLinear else { return [] }
        let heads = shapeArrowHeads(
            shape: FfiShape(
                kind: kind,
                bounds: FfiRect(
                    minX: Float(x), minY: Float(y),
                    maxX: Float(x + width), maxY: Float(y + height)
                ),
                cornerRadius: Float(cornerRadius),
                rotationDegrees: 0
            ),
            size: Float(max(10, lineWidth * 5))
        )
        return [heads.start, heads.end]
            .filter { $0.count >= 3 }
            .map { $0.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) } }
    }
}

/// 兩個形狀之間的連接線。
public struct NoteConnectionAttachment: Identifiable, Codable, Hashable {
    public let id: String
    public var pageIndex: Int
    public var fromShapeId: String
    public var toShapeId: String
    public var label: String
    public var colorHex: String?
    public var lineWidth: CGFloat
    /// 所屬群組的 id。`nil` 代表這個形狀在最上層。
    ///
    /// 群組是核心物件樹裡真正的節點（`Group`），不是平台自己畫出來的框 ——
    /// 所以它跨得過平台：在一台裝置上群組起來，另一台打開仍然是一組。
    public var groupId: String?

    // MARK: - 進階樣式（全部 Optional，`nil` ＝ 與以前一樣）

    /// 出線／入線的連接點：`"top"`、`"right"`、`"bottom"`、`"left"`。
    /// `nil` 由核心依兩個形狀的相對位置自動挑（`connectionBetween`）。
    public var fromAnchor: String?
    public var toAnchor: String?
    /// 走線：`"straight"` 或 `"orthogonal"`（直角折線，核心的預設）。
    public var route: String?
    /// 兩端的端點樣式：`"none"`、`"arrow"`、`"hollow"`、`"circle"`、`"diamond"`。
    /// 起點預設 `none`、終點預設 `arrow`（與核心 `Connection::default` 相同）。
    public var startCap: String?
    public var endCap: String?
    public var dashStyle: String?

    public init(
        id: String = UUID().uuidString,
        pageIndex: Int = 0,
        fromShapeId: String,
        toShapeId: String,
        label: String = "",
        colorHex: String? = nil,
        lineWidth: CGFloat = 2,
        groupId: String? = nil
    ) {
        self.id = id
        self.pageIndex = pageIndex
        self.fromShapeId = fromShapeId
        self.toShapeId = toShapeId
        self.label = label
        self.colorHex = colorHex
        self.lineWidth = lineWidth
        self.groupId = groupId
    }
}

// MARK: - 樣式列舉（字串存檔，名稱就是持久化的值）

/// 線條樣式。
public enum ShapeDash: String, CaseIterable, Identifiable {
    case solid, dashed, dotted
    public var id: String { rawValue }

    public var labelKey: String { "dash_\(rawValue)" }

    /// 虛線樣式要隨線寬縮放，細線配粗虛線段會看不出是虛線。
    public func pattern(lineWidth: CGFloat) -> [CGFloat] {
        let w = max(1, lineWidth)
        switch self {
        case .solid: return []
        case .dashed: return [w * 4, w * 3]
        case .dotted: return [w * 0.1, w * 2.2]
        }
    }

    public func strokeStyle(lineWidth: CGFloat) -> StrokeStyle {
        StrokeStyle(lineWidth: lineWidth, lineCap: self == .dotted ? .round : .butt,
                    lineJoin: .round, dash: pattern(lineWidth: lineWidth))
    }

    public static func named(_ raw: String?) -> ShapeDash { raw.flatMap(ShapeDash.init(rawValue:)) ?? .solid }
}

/// 連接點。
public enum ShapeAnchorName: String, CaseIterable, Identifiable {
    case top, right, bottom, left
    public var id: String { rawValue }
    public var labelKey: String { "anchor_\(rawValue)" }

    var ffi: FfiAnchor {
        switch self {
        case .top: return .top
        case .right: return .right
        case .bottom: return .bottom
        case .left: return .left
        }
    }
}

/// 連接線的走線。
public enum ConnectionRouteName: String, CaseIterable, Identifiable {
    case straight, orthogonal
    public var id: String { rawValue }
    public var labelKey: String { self == .straight ? "route_straight" : "route_elbow" }
    var ffi: FfiRouteStyle { self == .straight ? .straight : .orthogonal }
}

/// 連接線端點。
public enum ConnectionCapName: String, CaseIterable, Identifiable {
    case none, arrow, hollow, circle, diamond
    public var id: String { rawValue }
    public var labelKey: String {
        switch self {
        case .none: return "cap_none"
        case .arrow: return "cap_arrow"
        case .hollow: return "cap_hollow"
        case .circle: return "cap_circle"
        case .diamond: return "cap_diamond"
        }
    }
}

extension NoteConnectionAttachment {
    public var dash: ShapeDash { ShapeDash.named(dashStyle) }
    public var routeName: ConnectionRouteName? { route.flatMap(ConnectionRouteName.init(rawValue:)) }
    public var startCapName: ConnectionCapName { startCap.flatMap(ConnectionCapName.init(rawValue:)) ?? .none }
    public var endCapName: ConnectionCapName { endCap.flatMap(ConnectionCapName.init(rawValue:)) ?? .arrow }

    /// 反轉方向：兩端的形狀、連接點、端點樣式一起對調。
    public mutating func reverse() {
        swap(&fromShapeId, &toShapeId)
        swap(&fromAnchor, &toAnchor)
        swap(&startCap, &endCap)
        // 兩端都沒設定時，預設是「終點有箭頭」—— 對調之後箭頭要跟著到新的終點，
        // 光是交換兩個 nil 會讓箭頭留在原本那一端。
        if startCap == nil && endCap == nil { startCap = "arrow"; endCap = "none" }
    }
}

extension NoteShapeAttachment {
    public var dash: ShapeDash { ShapeDash.named(dashStyle) }

    /// 形狀中心（畫布座標）。
    public var center: CGPoint { CGPoint(x: x + width / 2, y: y + height / 2) }

    /// 線狀形狀的兩個端點（畫布座標，已套用旋轉）。
    ///
    /// 核心的輪廓是 bounds 的對角線（左上 → 右下），旋轉由平台套用。
    public var lineEndpoints: (start: CGPoint, end: CGPoint) {
        let c = center
        func rot(_ p: CGPoint) -> CGPoint {
            ShapeFrameMath.rotate(p, about: c, degrees: canvasRotation)
        }
        return (rot(CGPoint(x: x, y: y)), rot(CGPoint(x: x + width, y: y + height)))
    }

    /// 四個連接點的畫布座標（已套用旋轉）。
    public func anchorPoint(_ anchor: ShapeAnchorName) -> CGPoint {
        let p = shapeAnchorPoint(shape: ShapeGeometry.ffiShape(self), anchor: anchor.ffi)
        return CGPoint(x: CGFloat(p.x), y: CGFloat(p.y))
    }
}

// MARK: - 與核心連接線物件的對映
//
// 核心的連接線物件帶著連接點、走線與兩端樣式，跟著套件走到別的裝置。
// 顏色、粗細、虛實核心沒有欄位，仍是這個平台自己的外觀資料。

extension ConnectionCapName {
    var ffi: FfiEndCap {
        switch self {
        case .none: return .none
        case .arrow: return .arrow
        case .hollow: return .hollowArrow
        case .circle: return .circle
        case .diamond: return .diamond
        }
    }

    init(_ ffi: FfiEndCap) {
        switch ffi {
        case .none: self = .none
        case .arrow: self = .arrow
        case .hollowArrow: self = .hollow
        case .circle: self = .circle
        case .diamond: self = .diamond
        }
    }
}

extension NoteConnectionAttachment {

    struct CoreFields {
        var fromAnchor: FfiAnchor
        var toAnchor: FfiAnchor
        var route: FfiRouteStyle
        var startCap: FfiEndCap
        var endCap: FfiEndCap
    }

    /// 寫進核心的欄位。
    ///
    /// `Center` 是「自動」的記號 —— 舊版一律寫 `Center/Center/Straight/None/Arrow`
    /// 而讀回時忽略，所以這個組合在檔案裡等於「沒有自訂」。
    /// 明確選了直線、卻沒指定連接點的線，會被解讀成那個舊組合而變回直角折線；
    /// 為了不讓它悄悄變樣，這種情況把自動算出來的連接點一併寫進去。
    func coreFields(from: NoteShapeAttachment?, to: NoteShapeAttachment?) -> CoreFields {
        var fromAnchorFfi: FfiAnchor = fromAnchor.flatMap(ShapeAnchorName.init(rawValue:))?.ffi ?? .center
        var toAnchorFfi: FfiAnchor = toAnchor.flatMap(ShapeAnchorName.init(rawValue:))?.ffi ?? .center
        let route = routeName ?? .orthogonal
        let start = startCapName, end = endCapName

        let looksLikeLegacy = fromAnchorFfi == .center && toAnchorFfi == .center
            && route == .straight && start == .none && end == .arrow
        if looksLikeLegacy, let from, let to {
            let auto = connectionBetween(
                from: ShapeGeometry.ffiShape(from), to: ShapeGeometry.ffiShape(to))
            fromAnchorFfi = auto.fromAnchor
            toAnchorFfi = auto.toAnchor
        }
        return CoreFields(
            fromAnchor: fromAnchorFfi, toAnchor: toAnchorFfi, route: route.ffi,
            startCap: start.ffi, endCap: end.ffi)
    }

    /// 從核心讀回的欄位套上來。舊版寫的那組固定值代表「沒有自訂」，維持 `nil`。
    mutating func apply(core: FfiConnectionObject) {
        let legacy = core.fromAnchor == .center && core.toAnchor == .center
            && core.route == .straight && core.startCap == .none && core.endCap == .arrow
        guard !legacy else { return }

        func anchorName(_ a: FfiAnchor) -> String? {
            switch a {
            case .top: return "top"
            case .right: return "right"
            case .bottom: return "bottom"
            case .left: return "left"
            case .center: return nil
            }
        }
        fromAnchor = anchorName(core.fromAnchor)
        toAnchor = anchorName(core.toAnchor)
        // 預設值存成 `nil`，保持檔案乾淨，也讓「預設」之後若改變仍能跟著走。
        route = core.route == .straight ? "straight" : nil
        let start = ConnectionCapName(core.startCap), end = ConnectionCapName(core.endCap)
        startCap = start == .none ? nil : start.rawValue
        endCap = end == .arrow ? nil : end.rawValue
    }
}

// MARK: - 跨裝置同步的樣式（筆記本中繼資料裡的 `shapeStyles`／`connectionStyles`）
//
// 核心的形狀物件只有種類、外框、圓角與文字，**而且建立之後沒有「修改」的 API**；
// 顏色、粗細、虛實、字級、連接線的連接點與端點樣式，核心完全沒有欄位。
// 這些以前只活在 Apple 自己的筆記檔裡 —— 同步一輪就被匯入的版本洗掉，
// 在 Android 上更是一開始就沒有。
//
// 做法與 `NotebookMeta` 其他欄位相同：以物件 id 為鍵、整包放進中繼資料，
// 兩個平台讀寫同一組鍵名。位置、大小、旋轉則走核心的物件變換（見 `NotebookPackageBridge`）。
//
// ⚠️ 這份 JSON 會寫進 `.padnote`：只能加欄位、不能改名，每個欄位都是 Optional。

struct ShapeStyleMeta: Codable, Hashable {
    /// 這份樣式屬於哪個物件（核心物件 id，小寫）。逐物件信封（`ObjectEnvelope`）用它對回形狀。
    var id: String?
    var kind: String?
    var label: String?
    var cornerRadius: Double?
    var stroke: String?
    var fill: String?
    var lineWidth: Double?
    var dash: String?
    var fontSize: Double?
    var textColor: String?
    var bold: Bool?
    var italic: Bool?
    var opacity: Double?
    var groupId: String?

    init(from shape: NoteShapeAttachment) {
        id = NotebookPackageBridge.stableBlockId(shape.id)
        kind = shape.kindName
        label = shape.label
        cornerRadius = Double(shape.cornerRadius)
        stroke = shape.strokeColorHex
        fill = shape.fillColorHex
        lineWidth = Double(shape.lineWidth)
        dash = shape.dashStyle
        fontSize = shape.fontSize.map(Double.init)
        textColor = shape.textColorHex
        bold = shape.isBold
        italic = shape.isItalic
        opacity = shape.opacity
        groupId = shape.groupId
    }

    func apply(to shape: inout NoteShapeAttachment) {
        if let kind { shape.kindName = kind }
        if let label { shape.label = label }
        if let cornerRadius { shape.cornerRadius = CGFloat(cornerRadius) }
        shape.strokeColorHex = stroke
        shape.fillColorHex = fill
        if let lineWidth { shape.lineWidth = CGFloat(lineWidth) }
        shape.dashStyle = dash
        shape.fontSize = fontSize.map { CGFloat($0) }
        shape.textColorHex = textColor
        shape.isBold = bold
        shape.isItalic = italic
        shape.opacity = opacity
        // 群組以核心的 Group 節點為準，不從這裡覆蓋。
    }
}

struct ConnectionStyleMeta: Codable, Hashable {
    var id: String?
    var fromAnchor: String?
    var toAnchor: String?
    var route: String?
    var startCap: String?
    var endCap: String?
    var label: String?
    var color: String?
    var lineWidth: Double?
    var dash: String?

    init(from connection: NoteConnectionAttachment) {
        id = NotebookPackageBridge.stableBlockId(connection.id)
        fromAnchor = connection.fromAnchor
        toAnchor = connection.toAnchor
        route = connection.route
        startCap = connection.startCap
        endCap = connection.endCap
        label = connection.label
        color = connection.colorHex
        lineWidth = Double(connection.lineWidth)
        dash = connection.dashStyle
    }

    func apply(to connection: inout NoteConnectionAttachment) {
        connection.fromAnchor = fromAnchor
        connection.toAnchor = toAnchor
        connection.route = route
        connection.startCap = startCap
        connection.endCap = endCap
        if let label { connection.label = label }
        connection.colorHex = color
        if let lineWidth { connection.lineWidth = CGFloat(lineWidth) }
        connection.dashStyle = dash
    }
}

// MARK: - 匯入時保留本機樣式

extension NoteShapeAttachment {
    /// 把本機的**外觀**欄位補到從套件讀回來的版本上（只補空的）。
    ///
    /// 新版寫的套件會帶 `shapeStyles`（見 `ShapeStyleMeta`），匯入時已經套好了；
    /// 這一步只為**舊版寫的套件**而存在 —— 它們沒有樣式，整份取代之後每同步一輪，
    /// 使用者設好的顏色、粗細、虛線、字級就被洗成預設。
    /// 只補空的欄位，所以別台裝置改過的樣式不會被本機的舊值蓋回去。
    /// 幾何（位置、大小、旋轉）以套件為準，那才是跨裝置共享的。
    mutating func adoptStyle(from local: NoteShapeAttachment) {
        strokeColorHex = strokeColorHex ?? local.strokeColorHex
        fillColorHex = fillColorHex ?? local.fillColorHex
        if lineWidth == 2 { lineWidth = local.lineWidth }
        dashStyle = dashStyle ?? local.dashStyle
        fontSize = fontSize ?? local.fontSize
        textColorHex = textColorHex ?? local.textColorHex
        isBold = isBold ?? local.isBold
        isItalic = isItalic ?? local.isItalic
        opacity = opacity ?? local.opacity
    }
}

extension NoteConnectionAttachment {
    /// 同上，連接線的顏色、粗細、虛實。
    mutating func adoptStyle(from local: NoteConnectionAttachment) {
        colorHex = colorHex ?? local.colorHex
        if lineWidth == 2 { lineWidth = local.lineWidth }
        dashStyle = dashStyle ?? local.dashStyle
    }
}

// MARK: - 縮放與旋轉的算術（純函式，單元測試釘住）

/// 八個縮放把手。`(sx, sy)` 是把手在本地座標軸上的方向：-1 左／上、1 右／下、0 不動。
public enum ShapeHandle: CaseIterable, Identifiable {
    case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left
    public var id: Self { self }

    public var sx: CGFloat {
        switch self {
        case .topLeft, .left, .bottomLeft: return -1
        case .top, .bottom: return 0
        case .topRight, .right, .bottomRight: return 1
        }
    }
    public var sy: CGFloat {
        switch self {
        case .topLeft, .top, .topRight: return -1
        case .left, .right: return 0
        case .bottomLeft, .bottom, .bottomRight: return 1
        }
    }
    public var isCorner: Bool { sx != 0 && sy != 0 }
}

public enum ShapeFrameMath {
    /// 形狀的最小邊長。再小就抓不到把手了。
    public static let minSide: CGFloat = 16

    public static func rotate(_ p: CGPoint, about c: CGPoint, degrees: Double) -> CGPoint {
        guard abs(degrees.truncatingRemainder(dividingBy: 360)) > 1e-9 else { return p }
        let r = degrees * .pi / 180
        let (s, co) = (CGFloat(sin(r)), CGFloat(cos(r)))
        let dx = p.x - c.x, dy = p.y - c.y
        return CGPoint(x: c.x + dx * co - dy * s, y: c.y + dx * s + dy * co)
    }

    /// 拖曳一個縮放把手之後的新外框。
    ///
    /// 位移是**畫布座標**，要先換到形狀自己的（旋轉前的）座標軸；
    /// 而且「對面那條邊／角不動」要在畫布上成立 —— 轉過 30° 的方塊，
    /// 拖右邊時左邊必須釘在原位，所以中心要沿著旋轉後的軸平移。
    public static func resized(
        _ frame: CGRect, rotation degrees: Double,
        handle: ShapeHandle, translation t: CGSize,
        keepAspect: Bool = false
    ) -> CGRect {
        let r = degrees * .pi / 180
        let (s, c) = (CGFloat(sin(r)), CGFloat(cos(r)))
        // 反向旋轉：畫布位移 → 本地位移。
        let lx = t.width * c + t.height * s
        let ly = -t.width * s + t.height * c

        var w = max(minSide, frame.width + handle.sx * lx)
        var h = max(minSide, frame.height + handle.sy * ly)
        if keepAspect && handle.isCorner && frame.width > 0 && frame.height > 0 {
            // 以變化比例較大的那一軸為準，等比縮放。
            let ratio = frame.width / frame.height
            if abs(w - frame.width) / frame.width >= abs(h - frame.height) / frame.height {
                h = max(minSide, w / ratio); w = h * ratio
            } else {
                w = max(minSide, h * ratio); h = w / ratio
            }
        }
        let dw = w - frame.width, dh = h - frame.height
        let lcx = handle.sx * dw / 2, lcy = handle.sy * dh / 2
        let cx = frame.midX + lcx * c - lcy * s
        let cy = frame.midY + lcx * s + lcy * c
        return CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h)
    }

    /// 由兩個端點算出線狀形狀的外框與旋轉角。
    ///
    /// 核心的線是 bounds 的對角線，旋轉繞中心。要讓任意方向的線都能存進
    /// 「外框＋旋轉」兩個既有欄位：外框取一個很扁的矩形（高 `thickness`），
    /// 旋轉角補掉對角線與水平的那一點夾角。端點因此完全自由，
    /// 不需要新增任何欄位，舊檔與另一個平台也讀得懂。
    public static func lineFrame(
        from a: CGPoint, to b: CGPoint, thickness: CGFloat = 2
    ) -> (frame: CGRect, rotation: Double) {
        let dx = b.x - a.x, dy = b.y - a.y
        let length = max(thickness + 1, hypot(dx, dy))
        let w = sqrt(max(1, length * length - thickness * thickness))
        let diagonal = atan2(thickness, w)
        let phi = atan2(dy, dx)
        var degrees = (phi - diagonal) * 180 / .pi
        degrees = degrees.truncatingRemainder(dividingBy: 360)
        if degrees < 0 { degrees += 360 }
        let center = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        return (CGRect(x: center.x - w / 2, y: center.y - thickness / 2, width: w, height: thickness), degrees)
    }

    /// 吸附到 `step` 度的倍數（容差內才吸）。
    public static func snapped(degrees: Double, step: Double = 15, tolerance: Double = 4) -> Double {
        let nearest = (degrees / step).rounded() * step
        return abs(degrees - nearest) <= tolerance ? nearest : degrees
    }
}

/// 連接線的幾何。
///
/// 路徑與箭頭都由核心算 —— 錨點要落在形狀的邊界上，而邊界是形狀種類決定的
/// （菱形的邊與方框的邊完全不同）。平台自己抓一個「大概的邊」，線就會穿進
/// 形狀裡或浮在外面。
public enum ShapeGeometry {

    /// 一個端點裝飾的幾何。
    public struct Cap {
        public let kind: ConnectionCapName
        /// 三角形／菱形的頂點。圓點為空。
        public let points: [CGPoint]
        public let center: CGPoint
        public let radius: CGFloat
    }

    public struct Connection {
        public let path: [CGPoint]
        /// 終點的箭頭三角形（舊欄位；等同 `endCap` 為 arrow 時的 `points`）。
        public let arrowHead: [CGPoint]
        public let startCap: Cap?
        public let endCap: Cap?

        /// 路徑的視覺中點（標籤放這裡）。
        public var midpoint: CGPoint {
            guard path.count >= 2 else { return path.first ?? .zero }
            // 依弧長找中點，不是取中間那個頂點 —— 直角折線的三段長度差很多。
            var total: CGFloat = 0
            for i in 1..<path.count { total += hypot(path[i].x - path[i-1].x, path[i].y - path[i-1].y) }
            var remaining = total / 2
            for i in 1..<path.count {
                let seg = hypot(path[i].x - path[i-1].x, path[i].y - path[i-1].y)
                if remaining <= seg, seg > 0 {
                    let t = remaining / seg
                    return CGPoint(x: path[i-1].x + (path[i].x - path[i-1].x) * t,
                                   y: path[i-1].y + (path[i].y - path[i-1].y) * t)
                }
                remaining -= seg
            }
            return path[path.count - 1]
        }
    }

    public static func connection(
        _ item: NoteConnectionAttachment,
        from: NoteShapeAttachment,
        to: NoteShapeAttachment
    ) -> Connection? {
        let fromShape = ffiShape(from)
        let toShape = ffiShape(to)
        var spec = connectionBetween(from: fromShape, to: toShape)
        if let a = item.fromAnchor.flatMap(ShapeAnchorName.init(rawValue:)) { spec.fromAnchor = a.ffi }
        if let a = item.toAnchor.flatMap(ShapeAnchorName.init(rawValue:)) { spec.toAnchor = a.ffi }
        if let r = item.routeName { spec.route = r.ffi }
        let path = connectionPath(conn: spec, from: fromShape, to: toShape)
            .map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) }
        guard path.count >= 2 else { return nil }

        let size = max(12, item.lineWidth * 4.5)
        let startCap = cap(item.startCapName, tip: path[0], from: path[1], size: size)
        let endCap = cap(item.endCapName, tip: path[path.count - 1], from: path[path.count - 2], size: size)
        return Connection(
            path: path,
            arrowHead: item.endCapName == .arrow ? (endCap?.points ?? []) : [],
            startCap: startCap, endCap: endCap)
    }

    private static func cap(_ kind: ConnectionCapName, tip: CGPoint, from: CGPoint, size: CGFloat) -> Cap? {
        guard kind != .none else { return nil }
        let dx = tip.x - from.x, dy = tip.y - from.y
        let len = hypot(dx, dy)
        guard len > 0.001 else { return nil }
        let ux = dx / len, uy = dy / len   // 朝向端點
        switch kind {
        case .none:
            return nil
        case .arrow, .hollow:
            let pts = connectionArrowHead(
                tip: FfiPoint(x: Float(tip.x), y: Float(tip.y)),
                from: FfiPoint(x: Float(from.x), y: Float(from.y)),
                size: Float(size)
            ).map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) }
            return Cap(kind: kind, points: pts, center: tip, radius: 0)
        case .circle:
            let r = size * 0.38
            return Cap(kind: kind, points: [], center: CGPoint(x: tip.x - ux * r, y: tip.y - uy * r), radius: r)
        case .diamond:
            let half = size * 0.5
            let mid = CGPoint(x: tip.x - ux * half, y: tip.y - uy * half)
            let px = -uy * size * 0.32, py = ux * size * 0.32
            return Cap(kind: kind, points: [
                tip,
                CGPoint(x: mid.x + px, y: mid.y + py),
                CGPoint(x: tip.x - ux * size, y: tip.y - uy * size),
                CGPoint(x: mid.x - px, y: mid.y - py)
            ], center: mid, radius: 0)
        }
    }

    static func ffiShape(_ item: NoteShapeAttachment) -> FfiShape {
        FfiShape(
            kind: item.kind,
            bounds: FfiRect(
                minX: Float(item.x), minY: Float(item.y),
                maxX: Float(item.x + item.width), maxY: Float(item.y + item.height)
            ),
            cornerRadius: Float(item.cornerRadius),
            // 核心據此把連接點與輪廓轉到旋轉後的位置 ——
            // 不帶過去的話，線會接在圖形外面的空氣中。
            rotationDegrees: Float(item.canvasRotation)
        )
    }
}
