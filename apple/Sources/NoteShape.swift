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

    public init(
        id: String = UUID().uuidString,
        pageIndex: Int = 0,
        kindName: String = "process",
        x: CGFloat = 80,
        y: CGFloat = 140,
        width: CGFloat = 160,
        height: CGFloat = 80,
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
                cornerRadius: Float(cornerRadius)
            ),
            segments: segments
        ).map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) }
    }

    /// 這個形狀在 ISO 5807 裡代表什麼（流程圖符號才有）。
    public var semantic: String? { shapeSemantic(kind: kind) }

    /// 這種形狀能不能放字。連接線與箭頭不能。
    public var acceptsText: Bool { shapeAcceptsText(kind: kind) }
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
    }
}

/// 連接線的幾何。
///
/// 路徑與箭頭都由核心算 —— 錨點要落在形狀的邊界上，而邊界是形狀種類決定的
/// （菱形的邊與方框的邊完全不同）。平台自己抓一個「大概的邊」，線就會穿進
/// 形狀裡或浮在外面。
public enum ShapeGeometry {

    public struct Connection {
        public let path: [CGPoint]
        public let arrowHead: [CGPoint]
    }

    public static func connection(
        _ item: NoteConnectionAttachment,
        from: NoteShapeAttachment,
        to: NoteShapeAttachment
    ) -> Connection? {
        let fromShape = ffiShape(from)
        let toShape = ffiShape(to)
        let spec = connectionBetween(from: fromShape, to: toShape)
        let path = connectionPath(conn: spec, from: fromShape, to: toShape)
            .map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) }
        guard path.count >= 2 else { return nil }

        let head = connectionArrowHead(
            tip: FfiPoint(x: Float(path[path.count - 1].x), y: Float(path[path.count - 1].y)),
            from: FfiPoint(x: Float(path[path.count - 2].x), y: Float(path[path.count - 2].y)),
            size: 12
        ).map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) }

        return Connection(path: path, arrowHead: head)
    }

    private static func ffiShape(_ item: NoteShapeAttachment) -> FfiShape {
        FfiShape(
            kind: item.kind,
            bounds: FfiRect(
                minX: Float(item.x), minY: Float(item.y),
                maxX: Float(item.x + item.width), maxY: Float(item.y + item.height)
            ),
            cornerRadius: Float(item.cornerRadius)
        )
    }
}
