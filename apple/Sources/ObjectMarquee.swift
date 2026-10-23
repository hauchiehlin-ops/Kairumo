//
//  ObjectMarquee.swift
//  Kairumo
//
//  畫布物件的框選：拉一個框，把框裡的東西整組搬、刪、複製、貼上。
//
//  # 為什麼要有它
//
//  在此之前，畫布上的物件只能**一個一個**碰：拖一個、刪一個。排好的一組
//  圖文要整組往下移 20pt，就得重複做七次，而且每次都會差一點點。
//  套索（`PKLassoTool`）只認手繪筆畫，碰不到任何物件。
//
//  # 為什麼是一個明確的模式，不是「在空白處拖曳就框選」
//
//  打字模式下，拖曳已經有兩個意思：拖物件＝搬它，拖空白＝捲動畫布。
//  再疊一個「拖空白＝框選」上去，三者會互相搶 —— 而搶輸的那一次，
//  使用者看到的是「我明明在拖，畫面卻在捲」。所以框選是使用者**按下去
//  才進入**的模式，進入後畫布不捲、物件不動，只剩下框選這一件事。
//

import CoreGraphics
import Foundation

/// 被框選的一個物件（跨型別的共同視角）。
struct MarqueeHit: Hashable {
    let id: String
    let kind: StackableObject.Kind
    let frame: CGRect
}

/// 剪貼簿上的一個物件。
///
/// 存**整個結構**而不是 id：複製完把原件刪掉，貼上時仍然要貼得出來。
/// 存 id 的話，那份剪貼簿在原件消失的瞬間就變成空的。
enum ClipboardObject: Equatable {
    case image(NoteImageAttachment)
    case text(NoteTextAttachment)
    case table(NoteTableAttachment)
    case shape(NoteShapeAttachment)
    case link(NoteLinkAttachment)
    case model3D(Note3DAttachment)
    case audio(NoteAudioAttachment)

    /// 這個物件在原頁面的版面框（左上角 `x, y` 與 `width, height`）。
    var frame: CGRect {
        switch self {
        case .image(let item):
            return CGRect(x: item.x, y: item.y, width: item.width, height: item.height)
        case .text(let item):
            return CGRect(x: item.x, y: item.y, width: item.width, height: item.height)
        case .table(let item):
            return CGRect(x: item.x, y: item.y, width: item.width, height: item.height)
        case .shape(let item):
            return CGRect(x: item.x, y: item.y, width: item.width, height: item.height)
        case .link(let item):
            return CGRect(x: item.x, y: item.y, width: item.width, height: item.height)
        case .model3D(let item):
            return CGRect(x: item.x, y: item.y, width: item.width, height: item.height)
        case .audio(let item):
            return CGRect(x: item.x, y: item.y, width: item.width, height: item.height)
        }
    }

    var id: String {
        switch self {
        case .image(let item): return item.id
        case .text(let item): return item.id
        case .table(let item): return item.id
        case .shape(let item): return item.id
        case .link(let item): return item.id
        case .model3D(let item): return item.id
        case .audio(let item): return item.id
        }
    }

    /// 產生一份貼在指定頁面與左上角座標的新物件（換上全新 `id`，並完整保留所有樣式與內容欄位）。
    func instantiated(onPage pageIndex: Int, at origin: CGPoint) -> ClipboardObject {
        switch self {
        case .image(let item):
            let copy = NoteImageAttachment(
                fileName: item.fileName,
                pageIndex: pageIndex,
                x: origin.x,
                y: origin.y,
                width: item.width,
                height: item.height,
                rotationDegrees: item.rotationDegrees,
                cornerRadius: item.cornerRadius,
                hasShadow: item.hasShadow,
                hasBorder: item.hasBorder,
                filterStyle: item.filterStyle,
                materialType: item.materialType,
                borderColorHex: item.borderColorHex,
                borderWidth: item.borderWidth,
                backgroundColorHex: item.backgroundColorHex,
                chartSpecJSON: item.chartSpecJSON,
                mathFormula: item.mathFormula
            )
            return .image(copy)
        case .text(let item):
            var copy = NoteTextAttachment(
                pageIndex: pageIndex,
                text: item.text,
                fontSize: item.fontSize,
                isBold: item.isBold,
                isItalic: item.isItalic,
                isUnderline: item.isUnderline,
                isStrikethrough: item.isStrikethrough,
                alignmentRaw: item.alignmentRaw,
                textColorHex: item.textColorHex,
                backgroundColorHex: item.backgroundColorHex ?? "#FFFFFF",
                hasBorder: item.hasBorder,
                cornerRadius: item.cornerRadius,
                borderColorHex: item.borderColorHex,
                borderWidth: item.borderWidth,
                x: origin.x,
                y: origin.y,
                width: item.width,
                height: item.height,
                lineSpacing: item.lineSpacing,
                paragraphSpacing: item.paragraphSpacing,
                firstLineIndent: item.firstLineIndent,
                paragraphIndent: item.paragraphIndent
            )
            copy.rotationDegrees = item.rotationDegrees
            copy.fontFamily = item.fontFamily
            copy.runs = item.runs
            return .text(copy)
        case .table(let item):
            var copy = NoteTableAttachment(
                pageIndex: pageIndex,
                x: origin.x,
                y: origin.y,
                width: item.width,
                rows: item.rows,
                cols: item.cols,
                cells: item.cells,
                headerRow: item.headerRow,
                mergedCells: item.mergedCells,
                fontSize: item.fontSize,
                ruleColorHex: item.ruleColorHex,
                headerBackgroundHex: item.headerBackgroundHex
            )
            copy.rotationDegrees = item.rotationDegrees
            return .table(copy)
        case .shape(let item):
            var copy = NoteShapeAttachment(
                pageIndex: pageIndex,
                kindName: item.kindName,
                x: origin.x,
                y: origin.y,
                width: item.width,
                height: item.height,
                cornerRadius: item.cornerRadius,
                label: item.label,
                strokeColorHex: item.strokeColorHex,
                fillColorHex: item.fillColorHex,
                lineWidth: item.lineWidth,
                groupId: nil
            )
            copy.rotationDegrees = item.rotationDegrees
            copy.dashStyle = item.dashStyle
            copy.fontSize = item.fontSize
            copy.textColorHex = item.textColorHex
            copy.isBold = item.isBold
            copy.isItalic = item.isItalic
            copy.opacity = item.opacity
            return .shape(copy)
        case .link(let item):
            var copy = NoteLinkAttachment(
                pageIndex: pageIndex,
                urlString: item.urlString,
                title: item.title,
                descriptionText: item.descriptionText,
                siteName: item.siteName,
                x: origin.x,
                y: origin.y,
                width: item.width,
                height: item.height,
                hasBorder: item.hasBorder,
                borderColorHex: item.borderColorHex,
                borderWidth: item.borderWidth,
                backgroundColorHex: item.backgroundColorHex,
                cornerRadius: item.cornerRadius
            )
            copy.rotationDegrees = item.rotationDegrees
            return .link(copy)
        case .model3D(let item):
            var copy = Note3DAttachment(
                pageIndex: pageIndex,
                title: item.title,
                modelTypeRaw: item.modelTypeRaw,
                materialType: item.materialType,
                rotationX: item.rotationX,
                rotationY: item.rotationY,
                rotationZ: item.rotationZ,
                scale: item.scale,
                x: origin.x,
                y: origin.y,
                width: item.width,
                height: item.height,
                hasBorder: item.hasBorder,
                borderColorHex: item.borderColorHex,
                borderWidth: item.borderWidth,
                backgroundColorHex: item.backgroundColorHex,
                cornerRadius: item.cornerRadius,
                importedFileName: item.importedFileName,
                importedDisplayName: item.importedDisplayName
            )
            copy.rotationDegrees = item.rotationDegrees
            return .model3D(copy)
        case .audio(let item):
            let copy = NoteAudioAttachment(
                pageIndex: pageIndex,
                recordingId: item.recordingId,
                fileName: item.fileName,
                title: item.title,
                durationSeconds: item.durationSeconds,
                x: origin.x,
                y: origin.y,
                width: item.width,
                height: item.height,
                rotationDegrees: item.rotationDegrees,
                hasBorder: item.hasBorder,
                cornerRadius: item.cornerRadius,
                borderColorHex: item.borderColorHex,
                borderWidth: item.borderWidth,
                backgroundColorHex: item.backgroundColorHex
            )
            return .audio(copy)
        }
    }
}

enum ObjectMarquee {

    /// 兩個角落拉出來的矩形。往左上拉也要成立 —— 只寫
    /// `width: end.x - start.x` 的話，反向拖曳會得到負寬度，什麼都選不到。
    static func rect(from start: CGPoint, to end: CGPoint) -> CGRect {
        CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
    }

    /// 框到的物件。
    ///
    /// 用**相交**而不是「完全包住」：使用者要框一排並排的卡片時，
    /// 很少會把框拉得比那一排還大，通常只是掃過去。要求完全包住的話，
    /// 十次有九次會什麼都沒選到。
    static func hits(in rect: CGRect, among candidates: [MarqueeHit]) -> Set<String> {
        guard rect.width > 2, rect.height > 2 else { return [] }
        return Set(candidates.filter { $0.frame.intersects(rect) }.map(\.id))
    }

    /// 選取範圍的外框。工具列要掛在它旁邊。
    static func bounds(of ids: Set<String>, among candidates: [MarqueeHit]) -> CGRect? {
        let frames = candidates.filter { ids.contains($0.id) }.map(\.frame)
        guard let first = frames.first else { return nil }
        return frames.dropFirst().reduce(first) { $0.union($1) }
    }

    /// 這一次拉框之後的選取。
    ///
    /// **連續框選**（`additive`）：新框到的加進原本的選取，不取代 —— 散在頁面各處的
    /// 物件可以一框一框地累積起來，不必一次框到全部（那常常會連帶框到不想要的東西）。
    static func combined(_ existing: Set<String>, with hits: Set<String>, additive: Bool) -> Set<String> {
        additive ? existing.union(hits) : hits
    }

    /// 點一下選取的結果。
    ///
    /// 點到物件：連續框選時切換它在不在選取裡（點錯了再點一次就拿掉）；一般模式只選它。
    /// 點到空白：一般模式取消選取；連續框選時保留 —— 累積了半天的選取不能因為手滑點到空白就沒了。
    static func tapped(_ id: String?, existing: Set<String>, additive: Bool) -> Set<String> {
        guard let id else { return additive ? existing : [] }
        guard additive else { return [id] }
        var next = existing
        if next.contains(id) { next.remove(id) } else { next.insert(id) }
        return next
    }

    /// 點的位置上最上層的物件。候選依堆疊順序（由下到上）排列，所以從後面找。
    static func topmostHit(at point: CGPoint, among candidates: [MarqueeHit]) -> String? {
        candidates.last(where: { $0.frame.contains(point) })?.id
    }

    /// 貼上時的位移。
    ///
    /// 貼在原位的話，使用者會以為沒貼成功 —— 畫面上完全沒有變化，
    /// 而新的那一份剛好蓋在舊的上面。
    static let pasteOffset = CGSize(width: 24, height: 24)

    /// 計算貼上一組物件時，每個物件在目標頁面上的新左上角座標（已夾回可列印範圍）。
    ///
    /// - `targetPoint == nil`：依原位置加上 `pasteOffset (24, 24)`。
    /// - `targetPoint != nil`：以整組物件的聯集外框中心對齊 `targetPoint`，保留多物件之間的相對位置，
    ///   單一物件時即中心對齊使用者點選的座標。
    static func pasteOrigins(frames: [CGRect], targetPoint: CGPoint? = nil) -> [CGPoint] {
        guard let first = frames.first else { return [] }
        let dx: CGFloat
        let dy: CGFloat
        if let target = targetPoint {
            let unionBounds = frames.dropFirst().reduce(first) { $0.union($1) }
            dx = target.x - unionBounds.midX
            dy = target.y - unionBounds.midY
        } else {
            dx = pasteOffset.width
            dy = pasteOffset.height
        }
        return frames.map { frame in
            PrintableArea.clampOrigin(
                x: frame.minX + dx,
                y: frame.minY + dy,
                width: frame.width,
                height: frame.height
            )
        }
    }

    /// 將剪貼簿物件實例化到目標頁面與目標位置（`targetPoint == nil` 為預設偏移貼上，有值則對齊該座標）。
    static func pasted(
        _ objects: [ClipboardObject],
        onPage pageIndex: Int,
        at targetPoint: CGPoint? = nil
    ) -> [ClipboardObject] {
        let origins = pasteOrigins(frames: objects.map(\.frame), targetPoint: targetPoint)
        return zip(objects, origins).map { object, origin in
            object.instantiated(onPage: pageIndex, at: origin)
        }
    }
}
