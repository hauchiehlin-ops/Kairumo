//
//  StrokeDelta.swift
//  Kairumo
//
//  算出「這台裝置自己新增了哪些筆畫」。
//
//  # 為什麼需要它
//
//  同步時，這台裝置手上的筆記是**合併後**的內容：自己寫的，加上從別台裝置
//  下載下來的。把整份寫回自己的檔案，等於把對方的筆畫複製一份掛在自己名下 ——
//  下一次合併就會看到兩份，再下一次四份。使用者看到的是筆跡愈來愈粗、
//  愈來愈黑，因為同一條線被重複畫了好幾遍。
//
//  所以匯出前要先扣掉「上次從檔案讀回來的那些」。基準線就是匯入當下的樣子。
//
//  ⚠️ 已知限制：這個做法追蹤的是**新增**。在這台裝置上擦掉一筆從別台裝置來的
//  筆畫，擦除不會傳出去（核心有 `erase_stroke` 的墓碑機制，但這條路還沒接）。
//  對使用者的影響是「刪除不同步」，不是資料損毀 —— 下次同步那筆會再出現。
//

import Foundation
import PencilKit

enum StrokeDelta {

    /// 一筆畫的身分。
    ///
    /// 用幾何與顏色當身分，而不是物件位址：筆畫跨過檔案再回來時已經是新的
    /// 物件了，比位址永遠不會相等。
    ///
    /// 座標量化到 0.01 點再比：寫檔時壓縮過的浮點數讀回來會差最後一兩位
    /// （格式規格 §5.4），不量化的話每一筆都會被當成「新的」，
    /// 於是每次同步都把整份重寫一遍 —— 正是要避免的那件事。
    struct Identity: Hashable {
        let pointCount: Int
        let firstX: Int
        let firstY: Int
        let lastX: Int
        let lastY: Int
        let color: [Int]

        init(_ stroke: PKStroke) {
            let path = stroke.path
            pointCount = path.count
            let first = path.count > 0 ? path[0].location : .zero
            let last = path.count > 0 ? path[path.count - 1].location : .zero
            firstX = Identity.quantize(first.x)
            firstY = Identity.quantize(first.y)
            lastX = Identity.quantize(last.x)
            lastY = Identity.quantize(last.y)
            color = InkInterop.rgba(from: stroke.ink.color).map { Int($0) }
        }

        private static func quantize(_ value: CGFloat) -> Int {
            Int((value * 100).rounded())
        }
    }

    /// `current` 裡不在 `baseline` 的筆畫。
    ///
    /// 兩筆畫的身分相同時視為同一筆 —— 同一個位置、同樣長度、同樣顏色的兩筆，
    /// 對使用者來說本來就是同一條線。
    static func added(in current: PKDrawing, since baseline: PKDrawing) -> [PKStroke] {
        guard !baseline.strokes.isEmpty else { return current.strokes }
        var remaining: [Identity: Int] = [:]
        for stroke in baseline.strokes {
            remaining[Identity(stroke), default: 0] += 1
        }

        var out: [PKStroke] = []
        for stroke in current.strokes {
            let identity = Identity(stroke)
            if let count = remaining[identity], count > 0 {
                // 基準線裡有同一筆，扣掉一份 —— 用計數而不是集合，
                // 使用者真的畫了兩條重疊的線時，第二條仍然算新增。
                remaining[identity] = count - 1
            } else {
                out.append(stroke)
            }
        }
        return out
    }
}
