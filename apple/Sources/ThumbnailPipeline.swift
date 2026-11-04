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
//  - 最貴的墨跡點陣化（整頁 PencilKit 取圖＋專業筆刷筆點）在背景做，主執行緒只疊紙張與物件。
//    剛開啟筆記本時一整排縮圖同時排隊 —— 墨跡也在主執行緒畫的話，主執行緒被連續佔住，
//    點縮圖換頁要等到全部畫完才順。
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
    /// 每次全面失效或搬頁加一。背景畫到一半時頁碼可能已經對不上，回來時世代不同就丟掉。
    private var epoch = 0
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
        epoch += 1
        PageThumbnailRenderer.invalidateAll()
    }

    /// 頁面結構變了（搬頁、插入、複製、刪除）：`map(舊頁碼)` = 新頁碼，`nil` 是刪掉的頁。
    ///
    /// 快取鍵是頁碼加上版本號，而沒動過的頁版本號都是 0 —— 不處理的話，搬頁之後同一個頁碼
    /// 算出同一個鍵，側欄沿用搬動前那一頁的圖，與畫布整個錯開。這裡讓全部重算（世代 +1），
    /// 過渡用的舊圖跟著搬到新頁碼，重算完成前顯示的也是對的那一頁。
    func pagesRemapped(notebookId: String, countBefore: Int, _ map: (Int) -> Int?) {
        var moved: [(Int, UIImage)] = []
        for page in 0..<max(0, countBefore) {
            let pk = pageKey(notebookId, page)
            if let image = stale.object(forKey: pk as NSString), let to = map(page) { moved.append((to, image)) }
            stale.removeObject(forKey: pk as NSString)
            pending[pk] = nil
        }
        for (page, image) in moved {
            stale.setObject(image, forKey: pageKey(notebookId, page) as NSString)
        }
        done.removeAllObjects()
        epoch += 1
        PageThumbnailRenderer.invalidateAll()
        for (key, slot) in slots where key.hasPrefix("\(notebookId)|") { slot.version += 1 }
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
            PagePrefetcher.prefetch(pages: [request.pageIndex], notebookId: request.notebook.id,
                                    store: request.store, priority: .visible)
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
        let scale = 0.4 * FrameGovernor.shared.thumbnailScaleFactor
        // 主執行緒只取輸入（記憶體裡的筆跡、已排序的專業筆畫），點陣化交給背景。
        let input = InkInput(
            drawing: r.drawing(),
            pro: PageThumbnailRenderer.proStrokes(notebook: r.notebook, pageIndex: r.pageIndex, store: r.store),
            pageSize: CGSize(width: PageGeometry.width, height: PageGeometry.height),
            size: PageThumbnailRenderer.previewSize,
            scale: scale,
            dark: UITraitCollection.current.userInterfaceStyle == .dark)
        let startedEpoch = epoch
        // 這一頁的圖片（含圖表）與風格濾鏡也在背景先解好：原本 `finish` 在主執行緒合成時逐張
        // 讀檔＋解碼＋逐像素套濾鏡，圖多的大筆記本一開啟，側欄一整排縮圖就把主執行緒佔滿。
        let images = (r.notebook.attachments ?? [])
            .filter { $0.pageIndex == r.pageIndex }
            .map { ImagePrefetch(fileName: $0.fileName, filter: $0.filterStyle) }
        let memory = r.store.imageMemory
        let directory = r.store.attachmentsDirectory
        BackgroundScheduler.shared.submit(.visible) {
            memory.prefetch(images.map(\.fileName), directory: directory)
            for item in images where item.filter != .original {
                let key = ImageEffects.filteredCacheKey(fileName: item.fileName, filter: item.filter)
                if ImageEffects.cachedFiltered(key: key) == nil, let base = memory.image(for: item.fileName) {
                    _ = ImageEffects.makeFiltered(base, filter: item.filter, key: key)
                }
            }
            let ink = UncheckedBox(PageThumbnailRenderer.rasterizeInk(
                drawing: input.drawing, pro: input.pro, pageSize: input.pageSize,
                size: input.size, scale: input.scale, dark: input.dark))
            DispatchQueue.main.async { [weak self] in
                self?.finish(job: job, pk: pk, drawing: input.drawing, scale: scale,
                             ink: ink.value, startedEpoch: startedEpoch)
            }
        }
    }

    private func finish(job: Job, pk: String, drawing: PKDrawing, scale: CGFloat, ink: UIImage, startedEpoch: Int) {
        // 背景畫的期間搬了頁或全面失效：這張圖可能屬於別的頁碼，丟掉，佇列裡已經有新的工作。
        if startedEpoch == epoch {
            let r = job.request
            let image = PageThumbnailRenderer.render(
                notebook: r.notebook, pageIndex: r.pageIndex, drawing: drawing, store: r.store,
                canvasWidth: r.canvasWidth, inkRevision: r.inkRevision,
                scale: scale, deferRecomputation: false, inkLayer: ink)
            done.setObject(image, forKey: job.key as NSString)
            stale.setObject(image, forKey: pk as NSString)
            slots[pk]?.version += 1
        }
        pumping = false
        if !pending.isEmpty { pump(after: FrameGovernor.shared.thumbnailGap) }
    }
}

/// 縮圖背景工作要預載的一張圖。
private struct ImagePrefetch: @unchecked Sendable {
    let fileName: String
    let filter: ImageFilterStyle
}

/// 送到背景點陣化的輸入。都是值型別，送出後主執行緒不再改動。
private struct InkInput: @unchecked Sendable {
    let drawing: PKDrawing
    let pro: [ProStroke]
    let pageSize: CGSize
    let size: CGSize
    let scale: CGFloat
    let dark: Bool
}

/// 背景畫好的圖帶回主執行緒。`UIImage` 建好後不可變。
private struct UncheckedBox<T>: @unchecked Sendable {
    let value: T
    init(_ value: T) { self.value = value }
}
