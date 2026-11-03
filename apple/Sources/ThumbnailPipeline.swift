//
//  ThumbnailPipeline.swift
//  Kairumo
//
//  側欄縮圖的非同步算繪管線（stale-while-revalidate）。
//
//  # 為什麼
//
//  縮圖原本在 SwiftUI `body` 裡同步算：每張卡片都要先拿整頁 `PKDrawing`（沒載入過的頁同步讀檔解碼），
//  快取沒命中就當場 `UIGraphicsImageRenderer` 整頁算繪（PencilKit 全頁取圖＋專業筆刷 FFI＋全部物件）。
//  筆記超過幾頁、每頁都寫滿時，切到預覽頁、換頁、每次落筆之後，所有可見卡片會在同一個 run loop
//  裡一起算 —— 主執行緒被占滿，筆尖與點擊都得等。
//
//  # 做法
//
//  - `body` 只做便宜的事：算輕量快取鍵、查表。命中就用；沒命中就先給「上一張舊圖」（沒有就給純色底），
//    並把這一頁排進佇列。**body 永遠不會算繪、不會讀檔。**
//  - 佇列一次只處理一張，每張之間讓出 run loop；選取的那一頁與離它近的頁優先。
//  - 使用者正在書寫或兩指導覽時整個暫停，停手後才繼續（筆跡永遠優先於縮圖）。
//  - 算完只通知那一頁的卡片（`ThumbnailSlot`），不會讓整排卡片一起重算。
//

import SwiftUI
import UIKit
import PencilKit

/// 一頁縮圖的更新通知。卡片觀察自己這一頁的 slot，其他頁完成時不會被牽連。
@MainActor
final class ThumbnailSlot: ObservableObject {
    @Published fileprivate(set) var version = 0
}

@MainActor
final class ThumbnailPipeline {
    // profile-scope: device 縮圖快取以筆記本 id 為鍵，內容不跨筆記本
    static let shared = ThumbnailPipeline()

    struct Request {
        let notebook: NotebookDocument
        let pageIndex: Int
        let store: NotebookStore
        let canvasWidth: CGFloat
        let inkRevision: Int
        /// 要算繪時才取（可能是同步讀檔），所以是閉包。
        let drawing: () -> PKDrawing
        /// 越小越先算。
        let priority: Int
    }

    private struct Job {
        let key: String
        let request: Request
    }

    private let done = NSCache<NSString, UIImage>()
    private let stale = NSCache<NSString, UIImage>()
    private var slots: [String: ThumbnailSlot] = [:]
    private var pending: [String: Job] = [:]
    private var pumping = false
    private var placeholders: [UIUserInterfaceStyle: UIImage] = [:]

    private func pageKey(_ notebookId: String, _ page: Int) -> String { "\(notebookId)|\(page)" }

    func slot(notebookId: String, pageIndex: Int) -> ThumbnailSlot {
        let k = pageKey(notebookId, pageIndex)
        if let s = slots[k] { return s }
        let s = ThumbnailSlot()
        slots[k] = s
        return s
    }

    /// 清空（換筆記本、回前景）。
    func invalidateAll() {
        done.removeAllObjects()
        stale.removeAllObjects()
        pending.removeAll()
        PageThumbnailRenderer.invalidateAll()
    }

    /// 取這一頁現在該顯示的縮圖。**立即回傳**；需要重畫的會排進佇列。
    func image(for request: Request) -> UIImage {
        let key = PageThumbnailRenderer.lightweightKey(
            notebook: request.notebook, pageIndex: request.pageIndex,
            store: request.store, inkRevision: request.inkRevision)
        if let hit = done.object(forKey: key as NSString) { return hit }
        let pk = pageKey(request.notebook.id, request.pageIndex)
        if pending[pk]?.key != key {
            pending[pk] = Job(key: key, request: request)
            pump()
        }
        return stale.object(forKey: pk as NSString) ?? placeholder()
    }

    private func placeholder() -> UIImage {
        let style = UITraitCollection.current.userInterfaceStyle
        if let p = placeholders[style] { return p }
        let img = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { ctx in
            UIColor.systemBackground.resolvedColor(with: UITraitCollection.current).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
        placeholders[style] = img
        return img
    }

    private func pump(after delay: TimeInterval = 0) {
        guard !pumping else { return }
        pumping = true
        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.step() }
        } else {
            DispatchQueue.main.async { [weak self] in self?.step() }
        }
    }

    private func step() {
        // 筆跡永遠優先：正在寫、剛停手、兩指導覽中都不算。
        if CanvasTouchState.isActivelyInking(cooldownSeconds: 0.35) || CanvasTouchState.isCanvasNavigating {
            pumping = false
            if !pending.isEmpty { pump(after: 0.12) }
            return
        }
        guard let (pk, job) = pending.min(by: { $0.value.request.priority < $1.value.request.priority }) else {
            pumping = false
            return
        }
        pending[pk] = nil
        let r = job.request
        let image = PageThumbnailRenderer.render(
            notebook: r.notebook, pageIndex: r.pageIndex, drawing: r.drawing(), store: r.store,
            canvasWidth: r.canvasWidth, inkRevision: r.inkRevision, deferRecomputation: false)
        done.setObject(image, forKey: job.key as NSString)
        stale.setObject(image, forKey: pk as NSString)
        slots[pk]?.version += 1
        pumping = false
        if !pending.isEmpty { pump() }
    }
}
