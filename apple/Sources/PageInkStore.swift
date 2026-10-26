//
//  PageInkStore.swift
//  Kairumo
//
//  筆跡單一擁有者（架構審視 P1）。
//  徹底解決多份副本互相覆蓋、時序差造成內容消失的問題。
//

import SwiftUI
import PencilKit
import Combine

/// 管理單一筆記本中各頁面的筆跡實例（Single Source of Truth）。
///
/// 設計原則：
/// 1. 每頁在記憶體中只有**唯一權威副本**，不隨視圖拆裝而重新建立。
/// 2. 採用穩定的 pageId（若尚無則為降級 key）作為唯一索引鍵，分頁增刪重排不發生序號錯位。
/// 3. 單頁模式、連續模式、縮圖預覽、匯出等各模組**全面統一讀取此 Store**。
/// 4. 開啟筆記時，整本筆記所有頁面一次性建立初始快照，保證「一鍵恢復初始狀態」能精確且完整恢復全本。
@MainActor
public final class PageInkStore: ObservableObject {
    public let notebookId: String
    private unowned let store: NotebookStore

    /// 記憶體中各頁面的權威 PKDrawing（key: pageKey）
    private var inMemoryDrawings: [String: PKDrawing] = [:]

    /// 整本筆記剛載入時的初始快照（供「一鍵恢復初始狀態」使用）
    private var initialSnapshots: [String: PKDrawing] = [:]

    /// 各頁面目前是否已被編輯且尚未落盤
    private var dirtyPages: Set<String> = []

    /// 防止空白畫布意外覆蓋磁碟上既有筆跡的安全閥
    private var knownDiskStrokeCounts: [String: Int] = [:]

    /// 已經寫進核心 .padnote 的筆跡基準線（key: pageKey，架構審視 P1 單一擁有者）
    private var coreBaselines: [String: PKDrawing] = [:]

    /// 待寫入核心套件的頁面 Key 集合
    private var pendingCoreFlushKeys: Set<String> = []

    // profile-scope: profile 記憶體中開啟過的筆記本筆跡快取；切換時由 purgeAll 清空
    private static var activeStores: [String: PageInkStore] = [:]

    public static func store(for notebook: NotebookDocument, store: NotebookStore) -> PageInkStore {
        if let existing = activeStores[notebook.id] {
            return existing
        }
        let created = PageInkStore(notebookId: notebook.id, store: store)
        created.primeAllPages(notebook: notebook)
        activeStores[notebook.id] = created
        return created
    }

    public static func purge(notebookId: String) {
        activeStores.removeValue(forKey: notebookId)
    }

    public static func purgeAll() {
        activeStores.removeAll()
    }

    public init(notebookId: String, store: NotebookStore) {
        self.notebookId = notebookId
        self.store = store
    }

    /// 產生頁面的唯一 Key。優先使用 notebookDocument 的 pageId，若無則依 index 產生穩定識別碼。
    public func key(for pageIndex: Int, pageId: String? = nil) -> String {
        if let pageId, !pageId.isEmpty {
            return pageId.lowercased()
        }
        return "\(notebookId)_p\(pageIndex)"
    }

    /// 取得某一頁的筆跡。
    /// 若記憶體中已有快取，直接回傳；若無則自磁碟讀取並載入快取。
    public func drawing(for pageIndex: Int, pageId: String? = nil) -> PKDrawing {
        let k = key(for: pageIndex, pageId: pageId)
        if let cached = inMemoryDrawings[k] {
            return cached
        }
        let diskDrawing = store.loadDrawing(notebookId: notebookId, pageIndex: pageIndex)
        inMemoryDrawings[k] = diskDrawing
        knownDiskStrokeCounts[k] = diskDrawing.strokes.count
        if initialSnapshots[k] == nil {
            initialSnapshots[k] = diskDrawing
        }
        return diskDrawing
    }

    /// 更新某一頁的筆跡（落筆、擦除、套索搬移等）。
    public func updateDrawing(_ newDrawing: PKDrawing, for pageIndex: Int, pageId: String? = nil, allowBlank: Bool = false) {
        let k = key(for: pageIndex, pageId: pageId)

        // 安全守衛：如果磁碟/快取原本有筆畫（例如 5 筆），但傳入的是 0 筆空畫布，
        // 且此時畫布剛完成初始化或被視圖重用，絕不允許空白悄悄抹除內容。
        let currentCount = inMemoryDrawings[k]?.strokes.count ?? knownDiskStrokeCounts[k] ?? 0
        if !allowBlank && currentCount > 0 && newDrawing.strokes.isEmpty {
            #if DEBUG
            print("[PageInkStore] Guarded against blank drawing overwriting \(currentCount) strokes for \(k)")
            #endif
            return
        }

        inMemoryDrawings[k] = newDrawing
        dirtyPages.insert(k)
    }

    /// 強制覆蓋某一頁（明確的清空或全選刪除）。
    public func forceSetDrawing(_ newDrawing: PKDrawing, for pageIndex: Int, pageId: String? = nil) {
        updateDrawing(newDrawing, for: pageIndex, pageId: pageId, allowBlank: true)
    }

    /// 初始化時建立整本筆記本的初始狀態快照。
    public func primeAllPages(notebook: NotebookDocument) {
        let count = max(1, notebook.pageCount)
        for idx in 0..<count {
            let pid = (notebook.pageIds != nil && idx < (notebook.pageIds?.count ?? 0)) ? notebook.pageIds?[idx] : nil
            let k = key(for: idx, pageId: pid)
            if inMemoryDrawings[k] == nil {
                let d = store.loadDrawing(notebookId: notebookId, pageIndex: idx)
                inMemoryDrawings[k] = d
                knownDiskStrokeCounts[k] = d.strokes.count
            }
            if initialSnapshots[k] == nil {
                initialSnapshots[k] = inMemoryDrawings[k]
            }
        }
    }

    /// 一鍵恢復初始狀態：將所有頁面回滾到 primeAllPages 記錄的初始快照。
    public func revertAllPagesToInitialSnapshot(notebook: NotebookDocument) {
        let count = max(1, notebook.pageCount)
        for idx in 0..<count {
            let pid = (notebook.pageIds != nil && idx < (notebook.pageIds?.count ?? 0)) ? notebook.pageIds?[idx] : nil
            let k = key(for: idx, pageId: pid)
            if let initial = initialSnapshots[k] {
                inMemoryDrawings[k] = initial
                dirtyPages.insert(k)
                store.saveDrawing(notebookId: notebookId, pageIndex: idx, drawing: initial)
            }
        }
    }

    /// 取得某一頁的初始快照。
    public func initialSnapshot(for pageIndex: Int, pageId: String? = nil) -> PKDrawing? {
        let k = key(for: pageIndex, pageId: pageId)
        return initialSnapshots[k]
    }

    /// 將所有髒頁落盤。
    public func flushDirtyPages(notebook: NotebookDocument) {
        guard !dirtyPages.isEmpty else { return }
        let pagesToFlush = dirtyPages
        dirtyPages.removeAll()

        let count = max(1, notebook.pageCount)
        for idx in 0..<count {
            let pid = (notebook.pageIds != nil && idx < (notebook.pageIds?.count ?? 0)) ? notebook.pageIds?[idx] : nil
            let k = key(for: idx, pageId: pid)
            if pagesToFlush.contains(k), let drawing = inMemoryDrawings[k] {
                store.saveDrawing(notebookId: notebookId, pageIndex: idx, drawing: drawing)
                knownDiskStrokeCounts[k] = drawing.strokes.count
            }
        }
    }

    // MARK: - 核心套件寫入與基準線管理（取代舊有的 coreInkBaselines 與 pendingCoreInk）

    // orphan-ok: 供除錯與測試檢視指定頁面之核心基準線筆跡
    public func coreBaseline(for pageIndex: Int, pageId: String? = nil) -> PKDrawing? {
        let k = key(for: pageIndex, pageId: pageId)
        return coreBaselines[k]
    }

    public func setCoreBaseline(_ drawing: PKDrawing, for pageIndex: Int, pageId: String? = nil) {
        let k = key(for: pageIndex, pageId: pageId)
        coreBaselines[k] = drawing
    }

    public func clearCoreBaseline(for pageIndex: Int, pageId: String? = nil) {
        let k = key(for: pageIndex, pageId: pageId)
        coreBaselines.removeValue(forKey: k)
    }

    public func clearAllCoreBaselines() {
        coreBaselines.removeAll()
    }

    public func markPendingCoreFlush(for pageIndex: Int, pageId: String? = nil) {
        let k = key(for: pageIndex, pageId: pageId)
        pendingCoreFlushKeys.insert(k)
    }

    public func clearPendingCoreFlush(for pageIndex: Int, pageId: String? = nil) {
        let k = key(for: pageIndex, pageId: pageId)
        pendingCoreFlushKeys.remove(k)
    }

    public func clearAllPendingCoreFlush() {
        pendingCoreFlushKeys.removeAll()
    }

    public var hasPendingCoreFlush: Bool {
        return !pendingCoreFlushKeys.isEmpty
    }

    public func isPendingCoreFlush(for pageIndex: Int, pageId: String? = nil) -> Bool {
        let k = key(for: pageIndex, pageId: pageId)
        return pendingCoreFlushKeys.contains(k)
    }

    /// 取得所有等待寫入核心套件的 (pageIndex, pageId, drawing, cachedBaseline) 任務清單
    public func pendingCoreFlushJobs(notebook: NotebookDocument) -> [(pageIndex: Int, pageId: String?, drawing: PKDrawing, cachedBaseline: PKDrawing?)] {
        guard !pendingCoreFlushKeys.isEmpty else { return [] }
        var jobs: [(pageIndex: Int, pageId: String?, drawing: PKDrawing, cachedBaseline: PKDrawing?)] = []
        let count = max(1, notebook.pageCount)
        for idx in 0..<count {
            let pid = (notebook.pageIds != nil && idx < (notebook.pageIds?.count ?? 0)) ? notebook.pageIds?[idx] : nil
            let k = key(for: idx, pageId: pid)
            if pendingCoreFlushKeys.contains(k), let d = inMemoryDrawings[k] {
                jobs.append((pageIndex: idx, pageId: pid, drawing: d, cachedBaseline: coreBaselines[k]))
            }
        }
        return jobs
    }

    /// 檢查某頁筆跡是否相較已儲存快取無變更（取代舊有的 lastPersistedInk 副本）
    public func isUnchanged(for pageIndex: Int, pageId: String? = nil, drawing: PKDrawing) -> Bool {
        let k = key(for: pageIndex, pageId: pageId)
        guard let cached = inMemoryDrawings[k] else { return false }
        return cached == drawing && !dirtyPages.contains(k) && !pendingCoreFlushKeys.contains(k)
    }
}
