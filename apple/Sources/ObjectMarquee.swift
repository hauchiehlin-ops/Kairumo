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
enum ClipboardObject {
    case image(NoteImageAttachment)
    case text(NoteTextAttachment)
    case table(NoteTableAttachment)
    case shape(NoteShapeAttachment)
    case link(NoteLinkAttachment)
    case model3D(Note3DAttachment)
    case audio(NoteAudioAttachment)
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

    /// 貼上時的位移。
    ///
    /// 貼在原位的話，使用者會以為沒貼成功 —— 畫面上完全沒有變化，
    /// 而新的那一份剛好蓋在舊的上面。
    static let pasteOffset = CGSize(width: 24, height: 24)
}
