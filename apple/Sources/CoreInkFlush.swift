//
//  CoreInkFlush.swift
//  Kairumo
//
//  編輯器把筆跡增量寫進核心套件的那一段（在背景序列佇列上跑）。
//  獨立成純函式是為了**測得到**：這一段原本埋在編輯器的 View 裡，只有把 App 跑起來才驗得了，
//  而它做錯的後果是筆畫重複或漏掉。

import Foundation
import PencilKit

enum CoreInkFlush {
    struct Job {
        let page: Int
        let drawing: PKDrawing
        let drawingFileURL: URL
        /// 編輯器記著的「套件裡這一頁目前的樣子」。`nil` = 還不知道，要從套件讀。
        let cachedBaseline: PKDrawing?
    }

    /// 依序處理每一頁：算出「這一版比基準多了哪些筆畫」、記下擦掉的、把新增的追加進套件。
    /// 回傳寫入失敗的頁（呼叫端要補回待寫名單）。
    static func apply(
        _ jobs: [Job], document: NotebookDocument, package: URL,
        baselineDirectory: URL, deviceId: UInt32
    ) -> [(page: Int, drawing: PKDrawing)] {
        var failed: [(page: Int, drawing: PKDrawing)] = []
        for job in jobs {
            NotebookStore.writeDrawing(job.drawing, to: job.drawingFileURL)
            let baseline: PKDrawing
            if let cached = job.cachedBaseline {
                baseline = cached
            } else if let packaged = try? NotebookPackageBridge.drawing(
                fromPackageAt: package, deviceId: deviceId, document: document, pageIndex: job.page) {
                baseline = packaged
            } else {
                baseline = PKDrawing()
            }
            let added = StrokeDelta.added(in: job.drawing, since: baseline)
            // 擦掉的筆畫記下來，匯入時濾掉（不然同步會把雲端的舊檔下載回來、筆畫復活）。
            //
            // **只跟編輯器自己記的基準比。** 從套件讀出來的基準含有剛同步進來、畫面還沒合併的別台筆畫，
            // 拿它比會把那些筆畫當成「這台擦掉的」：記進名單之後這台永遠看不到它們，
            // 下一次匯出還替它們寫墓碑，別台也跟著消失（使用者回報：四台裝置的筆跡各不相同）。
            let removed = job.cachedBaseline.map { StrokeDelta.removed(in: job.drawing, since: $0) } ?? []
            ErasedInkLedger.record(
                removed: removed, added: added,
                in: baselineDirectory, notebookId: document.id, page: job.page)
            guard !added.isEmpty else { continue }
            do {
                try NotebookPackageBridge.appendInkDelta(
                    document: document, pageIndex: job.page, strokes: added,
                    to: package, deviceId: deviceId)
            } catch {
                failed.append((job.page, job.drawing))
                print("[InkAutosave] Failed to append ink to package: \(error)")
            }
        }
        return failed
    }
}
