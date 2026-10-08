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
//  ✅ **專業筆畫（製圖線、專業筆刷）已經接上了**：用穩定的筆畫 id 寫出、擦掉／搬動／改圖層寫成追加的
//  墓碑，原作者那台匯入時依墓碑拿掉自己的那一筆（見 `ProInkLedger`、`ProInkLayerView.reconcileLedger`）。
//  上面這個限制現在只剩 **PencilKit 筆畫**：它們沒有穩定的 id，仍走本檔的指紋與「已擦除」名單。
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

        /// 可以存檔的字串身分（「已擦除」名單用）。
        var key: String {
            "\(pointCount)|\(firstX),\(firstY)|\(lastX),\(lastY)|\(color.map(String.init).joined(separator: ","))"
        }
    }

    /// `baseline` 裡有、`current` 已經沒有的筆畫 —— 使用者擦掉（或復原掉）的。
    static func removed(in current: PKDrawing, since baseline: PKDrawing) -> [PKStroke] {
        added(in: baseline, since: current)
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


/// 使用者在這台擦掉的 PencilKit 筆畫的身分，每頁一份。
///
/// # 為什麼需要
///
/// 匯出時這台舊的筆畫檔會被整批換掉，但同步是看**檔案大小**的：雲端那份較大的舊檔會被
/// 下載回來，已經擦掉的筆畫就「復活」了（使用者看到的是橡皮擦擦不乾淨、過一陣子又回來）。
/// 格式是只追加的，要讓「刪除」成為可同步的資料得動核心；在那之前，本機先記住自己擦過什麼，
/// 匯入時把它們濾掉。重新畫出同一條線（或復原擦除）會把它從名單拿掉。
enum ErasedInkLedger {
    private nonisolated static func url(_ directory: URL, _ notebookId: String, _ page: Int) -> URL {
        directory.appending(path: "\(notebookId)_p\(page).erased-ink.json")
    }

    nonisolated static func load(in directory: URL, notebookId: String, page: Int) -> Set<String> {
        guard let data = try? Data(contentsOf: url(directory, notebookId, page)),
              let keys = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return Set(keys)
    }

    nonisolated static func save(_ keys: Set<String>, in directory: URL, notebookId: String, page: Int) {
        let file = url(directory, notebookId, page)
        if keys.isEmpty {
            try? FileManager.default.removeItem(at: file)
            return
        }
        guard let data = try? JSONEncoder().encode(keys.sorted()) else { return }
        try? data.write(to: file, options: .atomic)
    }

    /// 這次編輯擦掉與重新加入的筆畫，更新名單。沒有變動就不寫檔。
    nonisolated static func record(
        removed: [PKStroke], added: [PKStroke], in directory: URL, notebookId: String, page: Int
    ) {
        guard !removed.isEmpty || !added.isEmpty else { return }
        var keys = load(in: directory, notebookId: notebookId, page: page)
        let before = keys
        keys.formUnion(removed.map { StrokeDelta.Identity($0).key })
        keys.subtract(added.map { StrokeDelta.Identity($0).key })
        if keys != before { save(keys, in: directory, notebookId: notebookId, page: page) }
    }

    /// 把名單上的筆畫從一份（同步合併回來的）圖濾掉。
    nonisolated static func filtered(_ drawing: PKDrawing, erased: Set<String>) -> PKDrawing {
        guard !erased.isEmpty else { return drawing }
        let kept = drawing.strokes.filter { !erased.contains(StrokeDelta.Identity($0).key) }
        return kept.count == drawing.strokes.count ? drawing : PKDrawing(strokes: kept)
    }
}
