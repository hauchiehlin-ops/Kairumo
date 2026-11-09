//
//  EditorInkAndStorage.swift
//  Kairumo
//
//  筆跡儲存、延遲落盤與核心排程、復原重做、專業筆刷與手繪格式轉換
//

import SwiftUI
import PencilKit

// MARK: - 筆跡儲存與核心落盤擴充

extension NotebookEditorView {
    // MARK: - 儲存、延伸與套索編輯核心
    /// 這一頁第一次載入時的狀態（只記一次）：筆畫、專業筆畫與已擦除名單。
    /// 第一次載入一定早於這頁的任何編輯，所以它就是「初始狀態」。
    func captureInitialPageState(page: Int, drawing: PKDrawing) {
        // 調整過頁面結構之後頁碼不再是原本的頁碼；所有頁的初始狀態在那之前已經整批記好了。
        guard pageOrigins == nil else { return }
        let pid = (notebook.pageIds != nil && page < (notebook.pageIds?.count ?? 0)) ? notebook.pageIds?[page] : nil
        if activeInkStore.initialSnapshot(for: page, pageId: pid) == nil {
            activeInkStore.recordInitialSnapshot(drawing, for: page, pageId: pid)
        }
        if initialPageInk[page] == nil {
            let dir = store.drawingsDirectory
            initialPageInk[page] = InitialPageInk(
                own: ProInkStore.load(in: dir, notebookId: notebook.id, page: page),
                foreign: ProInkStore.load(in: dir, notebookId: notebook.id, page: page, foreign: true),
                suppressed: ProInkStore.loadSuppressed(in: dir, notebookId: notebook.id, page: page),
                erasedPencilKit: ErasedInkLedger.load(
                    in: store.syncBaselineDirectory, notebookId: notebook.id, page: page))
        }
    }

    /// 把所有頁面還原成第一次載入時的樣子（架構審視 P1：由 PageInkStore 統一回復全本快照）。
    func restoreInitialPages() {
        let dir = store.drawingsDirectory
        let baselineDir = store.syncBaselineDirectory
        activeInkStore.revertAllPagesToInitialSnapshot(notebook: notebook)
        let count = max(1, notebook.pageCount)
        for page in 0..<count {
            let pid = (notebook.pageIds != nil && page < (notebook.pageIds?.count ?? 0)) ? notebook.pageIds?[page] : nil
            guard let initial = activeInkStore.initialSnapshot(for: page, pageId: pid) else { continue }
            // 這一頁現在的筆畫 → 被還原拿掉的要記進「已擦除」名單，不然同步會把雲端的舊檔帶回來。
            let now = store.loadDrawing(notebookId: notebook.id, pageIndex: page)
            let state = initialPageInk[page]
            var erased = ErasedInkLedger.load(in: baselineDir, notebookId: notebook.id, page: page)
            erased.formUnion(StrokeDelta.removed(in: initial, since: now).map { StrokeDelta.Identity($0).key })
            erased.subtract(initial.strokes.map { StrokeDelta.Identity($0).key })
            ErasedInkLedger.save(erased, in: baselineDir, notebookId: notebook.id, page: page)

            store.saveDrawing(notebookId: notebook.id, pageIndex: page, drawing: initial)
            activeInkStore.setCoreBaseline(initial, for: page, pageId: pid)
            if let state {
                ProInkStore.save(state.own, in: dir, notebookId: notebook.id, page: page)
                ProInkStore.save(state.foreign, in: dir, notebookId: notebook.id, page: page, foreign: true)
                ProInkStore.saveSuppressed(state.suppressed, in: dir, notebookId: notebook.id, page: page)
            }
        }
        activeInkStore.clearAllPendingCoreFlush()
    }

    func loadCurrentPage() {
        if let updated = store.notebooks.first(where: { $0.id == notebook.id }) {
            self.notebook = updated
        }
        // 這一本用的是哪一種紙。畫布、分頁、縮圖與匯出都讀這個值 ——
        // 忘了設的話，換到另一本不同規格的筆記時會沿用上一本的尺寸。
        PageGeometry.use(format: notebook.pageFormatId)
        let pid = (notebook.pageIds != nil && currentPageIndex < (notebook.pageIds?.count ?? 0)) ? notebook.pageIds?[currentPageIndex] : nil
        let loaded = activeInkStore.drawing(for: currentPageIndex, pageId: pid)
        if !activeInkStore.isPendingCoreFlush(for: currentPageIndex, pageId: pid) { inkDiskBaselines[currentPageIndex] = loaded }
        self.currentDrawing = loaded
        if pageDisplayMode == .single {
            if let canvas = canvasView as? AdaptiveCanvasView {
                canvas.resetInitialRefreshFlag()
                canvas.initialLoadedStrokeCount = loaded.strokes.count
                canvas.forceDisplayRefresh(with: loaded)
                if ProcessInfo.processInfo.environment["KAIRUMO_UITEST"] == "1" {
                    canvas.accessibilityValue = CanvasRepresentable.testReadout(canvas)
                }
            }
        }
        captureInitialPageState(page: currentPageIndex, drawing: loaded)
        self.lastStrokeCount = loaded.strokes.count
        self.currentPageHeight = notebook.height(forPage: currentPageIndex)
        self.lasso.clear()
        configureLassoCallbacks(forPage: currentPageIndex)
        sanitizeUnderInkObjects()
        self.originalSketchBackup = nil
        self.refinedSketchCache = nil
        // 相鄰頁的筆跡先在背景解碼好：下一次換頁不必在主執行緒讀檔。
        PagePrefetcher.prefetch(
            pages: PagePrefetcher.neighbors(of: currentPageIndex, pageCount: notebook.pageCount),
            notebookId: notebook.id, store: store)
    }

    /// 把對方傳來的筆跡落到本機。
    ///
    /// # 為什麼不是「有畫布才做」
    ///
    /// 這裡原本整段包在 `if let canvas = canvasView` 裡：畫布還沒建立的那
    /// 一瞬間（剛進編輯器、剛換頁、連續模式下那一頁還沒捲到），對方的筆畫
    /// **連存都不會存** —— 訊息收到了、解密成功了、然後靜靜地被丟掉。
    /// 實機上看到的就是「兩台都顯示已連線，畫下去對面什麼都沒有」，
    /// 而且完全沒有任何錯誤可查。
    ///
    /// 落盤與畫面是兩件事：先無條件落盤，畫布有沒有在都不影響資料。
    func applyRemoteDrawing(page: Int, remote: PKDrawing, replace: Bool) {
        let isCurrent = (page == currentPageIndex)
        let pid = (notebook.pageIds != nil && page < (notebook.pageIds?.count ?? 0)) ? notebook.pageIds?[page] : nil
        // 不在畫布上的頁以記憶體副本為底（它才含這台還沒落盤的筆畫），不是磁碟。
        let base: PKDrawing = isCurrent
            ? (canvasView?.drawing ?? currentDrawing)
            : activeInkStore.drawing(for: page, pageId: pid)
        let merged = replace ? remote : base.appending(remote)

        // 落盤交給背景的筆跡佇列（與 `flushPendingCoreInk` 同一條、同一個順序）：
        // 協同時每收到一筆就在主執行緒序列化＋寫檔，頁面筆畫一多，對方的每一筆都要多卡幾十毫秒才出現。
        let drawingURL = store.drawingsDirectory.appending(path: "\(notebook.id)_p\(page).drawing")
        NotebookStore.primeDrawingCache(merged, for: drawingURL)
        nonisolated(unsafe) let toWrite = merged
        Self.coreInkQueue.async { NotebookStore.writeDrawing(toWrite, to: drawingURL) }
        // 記憶體副本（縮圖、換頁、連續模式讀的那一份）也要換，否則它停在對方畫之前的樣子。
        activeInkStore.adoptSavedDrawing(merged, for: page, pageId: pid)
        guard isCurrent else { return }

        isApplyingRemoteUpdate = true
        currentDrawing = merged
        canvasView?.drawing = merged
        if let adaptive = canvasView as? AdaptiveCanvasView {
            adaptive.forceDisplayRefresh(with: merged)
        }
        lastStrokeCount = merged.strokes.count
        DispatchQueue.main.async {
            isApplyingRemoteUpdate = false
        }
    }

    /// 自繪筆畫的動作即時送給房間（`InkEventSink.proObservers`）。
    func broadcastProInk(page: Int, removedIds: [String], added: [ProStroke]) {
        guard isCollaborating else { return }
        ensureCollabPageIds()
        guard let pageId = liveInkPageId(page) else { return }
        if !added.isEmpty {
            collaborationManager.broadcastOplog(kind: "ink_add", payload: [
                "proto": Self.collabProto, "page": pageId,
                "strokes": added.map(CollabStroke.encode(pro:)),
            ])
        }
        if !removedIds.isEmpty {
            collaborationManager.broadcastOplog(kind: "ink_remove", payload: [
                "proto": Self.collabProto, "page": pageId, "ids": removedIds.map { $0.lowercased() },
            ])
        }
    }

    /// 掛上（或拿掉）自繪筆畫與書寫中預覽的協同出口。
    func installProInkCollab(_ on: Bool) {
        let key = notebook.id.lowercased()
        if on {
            InkEventSink.proObservers[key] = { page, removed, added in
                broadcastProInk(page: page, removedIds: removed, added: added)
            }
            LiveInkSender.shared.install { notebookId, page in
                guard notebookId.lowercased() == notebook.id.lowercased(), isCollaborating else { return nil }
                return liveInkPageId(page)
            }
        } else {
            InkEventSink.proObservers.removeValue(forKey: key)
            LiveInkSender.shared.uninstall()
        }
    }

    /// 嘗試在指定頁碼開始或續約線上協同編輯。
    /// 若目前有其他協作者／房主正在「不同頁」進行編輯，則攔截本次編輯、顯示提示並將畫布跳轉至對方所在頁面，回傳 `false`。
    @discardableResult
    func requestCollabPageEditPermission(forPage page: Int) -> Bool {
        guard isCollaborating else { return true }
        ensureCollabPageIds()
        guard let pageId = liveInkPageId(page) else { return true }
        return collaborationManager.tryBeginLocalPageEdit(pageId: pageId) == nil
    }

    /// 將畫布（無論單頁固定模式或連續頁面模式）同步跳轉至指定的協同頁面 ID。
    func jumpToCollabPage(pageId: String, forceScroll: Bool = false) {
        guard isCollaborating else { return }
        ensureCollabPageIds()
        let canonical = NotebookPackageBridge.stableBlockId(pageId)
        guard let targetPage = notebook.pageIds?.firstIndex(where: {
            NotebookPackageBridge.stableBlockId($0) == canonical
        }) else { return }
        if pageDisplayMode == .continuous {
            let needsPageChange = currentPageIndex != targetPage
            if needsPageChange {
                focusContinuousPage(targetPage)
            }
            if needsPageChange || forceScroll {
                continuousScrollRequest += 1
            }
        } else if currentPageIndex != targetPage {
            switchToPage(targetPage)
        }
    }

    func renewCollabInlineTextLeaseIfNeeded() {
        guard isCollaborating,
              let editingId = inlineEditingTextId ?? suspendedInlineTextId else { return }
        let pageIdx = notebook.textAttachments?.first(where: { $0.id == editingId })?.pageIndex ?? currentPageIndex
        if let pid = liveInkPageId(pageIdx) {
            collaborationManager.renewLocalPageEdit(pageId: pid)
        }
    }

    func handleCollabPageEditPreempted(_ winner: PageEditLease) {
        guard isCollaborating else { return }
        ProInkCollab.cancelActiveStrokes(notebookId: notebook.id)
        (canvasView as? AdaptiveCanvasView)?.cancelInFlightStrokesForNavigation()
        (continuousCanvases.activeCanvas as? AdaptiveCanvasView)?.cancelInFlightStrokesForNavigation()
        for page in 0..<max(1, notebook.pageCount) {
            (continuousCanvases[page] as? AdaptiveCanvasView)?.cancelInFlightStrokesForNavigation()
        }
        inlineEditingTextId = nil
        suspendedInlineTextId = nil
        editingTextId = nil
        showCanvasNotice(collaborationManager.formatPageEditWaitNotice(for: winner))
    }

    func handleCollabInlineEditingChanged(_ newId: String?) {
        guard isCollaborating else { return }
        if let id = newId {
            let pageIdx = notebook.textAttachments?.first(where: { $0.id == id })?.pageIndex ?? currentPageIndex
            if !requestCollabPageEditPermission(forPage: pageIdx) {
                if let emptyItem = notebook.textAttachments?.first(where: { $0.id == id }),
                   emptyItem.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    notebook.textAttachments?.removeAll { $0.id == id }
                    commitNotebook()
                }
                inlineEditingTextId = nil
                suspendedInlineTextId = nil
            }
        } else if suspendedInlineTextId == nil {
            collaborationManager.endLocalPageEdit(immediate: true)
        }
    }

    private var collabPageLeaseEventSink: some View {
        Color.clear
            .onReceive(Timer.publish(every: CollaborationManager.pageEditRenewInterval, on: .main, in: .common).autoconnect()) { _ in
                renewCollabInlineTextLeaseIfNeeded()
            }
            .onReceive(collaborationManager.pageJumpRequested) { req in
                guard isCollaborating else { return }
                jumpToCollabPage(pageId: req.pageId, forceScroll: req.forceScroll)
            }
            .onReceive(collaborationManager.pageEditBlocked) { blocker in
                guard isCollaborating else { return }
                showCanvasNotice(collaborationManager.formatPageEditWaitNotice(for: blocker))
            }
            .onReceive(collaborationManager.pageEditPreempted) { winner in
                handleCollabPageEditPreempted(winner)
            }
            .onChange(of: inlineEditingTextId) { newId in
                handleCollabInlineEditingChanged(newId)
            }
    }

    /// 協同事件：租約搶輸、換房間、舊版參與者。
    var collabEventSink: AnyView {
        AnyView(ZStack {
            collabPageLeaseEventSink
            Color.clear
                .onAppear {
                    installProInkCollab(true)
                    collaborationManager.stateDepositor = { await depositCollabState() }
                }
                .onDisappear {
                    installProInkCollab(false)
                    collaborationManager.stateDepositor = nil
                }
                // 雲端中繼：定期把整份狀態寄存在房間裡（房主不在線也能加入、離線的人回來補得到）。
                // 房間裡只由一個人寄存（`shouldDepositState`），省中繼的寫入額度。
                .onReceive(Timer.publish(every: CollaborationManager.depositCheckInterval, on: .main, in: .common).autoconnect()) { _ in
                    guard isCollaborating, collaborationManager.shouldDepositState else { return }
                    Task { @MainActor in await depositCollabState() }
                }
                .onReceive(collaborationManager.leaseLost) { lost in
                // 兩人同時選了同一個物件、對方勝出：本機放手（設計 §5.3）。
                if activeSelectedObjectId == lost.id { activeSelectedObjectId = nil }
                if inlineEditingTextId == lost.id { inlineEditingTextId = nil }
                if editingTextId == lost.id { editingTextId = nil }
                selectedObjectIds.remove(lost.id)
                collaborationManager.broadcastSelection(selectedId: nil)
                showCanvasNotice(String(format: localizationManager.localized("collab_object_locked"), lost.holder))
            }
            .onChange(of: collaborationManager.currentRoomId) { _ in
                // 進入（或換）房間：以目前的內容為大家共同的起點。斷線重連不算 ——
                // 那段期間的本機修改還要送出去。
                ensureCollabPageIds()
                collabSync.reset(to: notebook)
                collabInkLedger.reset()
                collabTextHub.reset()
                collabStateSync.reset()
                // 已有的筆畫算「大家都有」—— 否則第一次在某一頁下筆，整頁舊筆畫會被當成新的再送一次，
                // 而對方（尤其是 Android，筆畫 id 不同）會多出一份。
                for (index, id) in (notebook.pageIds ?? []).enumerated() {
                    collabInkLedger.known[id] = Set(CollabInk.ids(of: drawingForCollab(page: index)))
                }
                // 這台的檔案可能比房間裡的舊：向房間裡的人要整份狀態（設計 §7）。只有自己就不必。
                if !collaborationManager.currentRoomId.isEmpty, !collaborationManager.peers.isEmpty {
                    requestCollabState()
                }
            }
            .onChange(of: isCollaborating) { collaborating in
                if collaborating { CollabImportHold.hold(notebook.id) } else { endCollabImportHold() }
            }
            .onReceive(collaborationManager.stateSyncNeeded) { _ in
                // 中繼補不回漏掉的那一段：向其他成員要整份狀態（剛要過就不重複）。
                if Date().timeIntervalSince(collabStateSync.lastRequest) > 5 { requestCollabState() }
            }
            .onChange(of: collaborationManager.outdatedPeerIds) { ids in
                guard !ids.isEmpty else { return }
                showCanvasNotice(localizationManager.localized("collab_peer_outdated"))
            }
        })
    }

    /// 套用別人的物件修改（欄位層級 LWW，設計 §4.1）。
    func applyRemotePatches(_ patches: [ObjectPatch], stamp: LamportStamp) {
        guard !patches.isEmpty else { return }
        ensureCollabPageIds()
        var doc = notebook
        var changed = false
        var pagesChanged = false
        var anchored: [(id: String, anchors: [[String]])] = []
        for var patch in patches {
            if let b64 = patch.fields.removeValue(forKey: CollabObjectSync.blobField) as? String {
                storeIncomingBlob(b64, fileName: (patch.fields["a.image.fileName"] as? String)
                    ?? (collabSync.shadow[patch.key]?["a.image.fileName"] as? String),
                    hash: patch.fields["blob"] as? String, fallbackId: patch.id)
            }
            if let anchors = patch.fields.removeValue(forKey: CollabObjectSync.anchorField) as? [[String]],
               patch.type == "text", patch.fields["a.runs"] != nil {
                anchored.append((patch.id, anchors))
            }
            if collabSync.apply(patch, stamp: stamp, to: &doc) {
                changed = true
                if patch.type == "page" { pagesChanged = true }
            }
        }
        guard changed else { return }
        collabSync.isApplyingRemote = true
        notebook = doc
        if pagesChanged {
            store.updateNotebook(notebook)
            reconcilePagesWithCollab()
        }
        var withDeferred = notebook
        collabSync.retryDeferred(into: &withDeferred)
        let stacking = collabSync.desiredStacking()
        CollabCanonical.writeStacking(orders: stacking.orders, under: stacking.under, locked: stacking.locked, into: &withDeferred)
        for item in anchored { resolveRunAnchors(id: item.id, anchors: item.anchors, in: &withDeferred) }
        notebook = withDeferred
        // 寫回後的編碼要成為新的同步基準，否則下一次本機修改會把這些欄位當成「我改的」再送一次。
        // 還沒補上的頁不算被刪（頁面結構調整是非同步的）。
        collabSync.refreshShadow(from: notebook, keepMissingPages: true)
        commitNotebook()
        collabSync.isApplyingRemote = false
        refreshAllThumbnails()
        // 對方刪掉的物件，本機的選取與編輯狀態要清掉。
        let alive = CanvasObjectState(notebook).allObjectIds
        if let id = inlineEditingTextId, !alive.contains(id) { inlineEditingTextId = nil }
        if let id = editingTextId, !alive.contains(id) { editingTextId = nil }
        if let id = activeSelectedObjectId, !alive.contains(id) { activeSelectedObjectId = nil }
        selectedObjectIds = selectedObjectIds.filter { alive.contains($0) }
    }

    /// 收到新圖片的位元組：存成檔案（已經有就不動），記下它的雜湊。
    func storeIncomingBlob(_ b64: String, fileName: String?, hash: String?, fallbackId: String) {
        guard let data = Data(base64Encoded: b64) else { return }
        let name = fileName.flatMap { $0.isEmpty ? nil : $0 } ?? "\(hash ?? fallbackId).png"
        let url = store.attachmentsDirectory.appending(path: name)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? data.write(to: url, options: .atomic)
        }
        if let hash { CollabCanonical.rememberBlob(fileName: name, hash: hash) }
        _ = store.loadAttachmentImage(fileName: name)
    }

    /// 別人送來的逐字格式：以字的 id 換回這邊現在的位置（設計 §8.3）。
    func resolveRunAnchors(id: String, anchors: [[String]], in doc: inout NotebookDocument) {
        guard let index = doc.textAttachments?.firstIndex(where: { CollabCanonical.canonicalId($0.id) == id }),
              var item = doc.textAttachments?[index], let runs = item.runs, runs.count == anchors.count else { return }
        let replica = collabTextHub.replica(for: id, base: item.text, site: collaborationManager.currentUserId)
        guard replica.text == item.text else { return }
        let resolved = CollabRunAnchors.resolve(anchors, in: replica)
        var adjusted = runs
        for (i, span) in resolved.enumerated() {
            if let span { adjusted[i].start = span.start; adjusted[i].length = span.length }
        }
        guard adjusted != runs else { return }
        item.runs = adjusted
        doc.textAttachments?[index] = item
    }

    /// 這一頁（協同頁面 id）沒有任何筆畫、也沒有任何物件。
    func isEmptyCollabPage(_ pageId: String) -> Bool {
        guard let index = notebook.pageIds?.firstIndex(of: pageId) else { return false }
        let dir = store.drawingsDirectory
        if !ProInkStore.load(in: dir, notebookId: notebook.id, page: index).isEmpty { return false }
        if !ProInkStore.load(in: dir, notebookId: notebook.id, page: index, foreign: true).isEmpty { return false }
        if !drawingForCollab(page: index).strokes.isEmpty { return false }
        return !collabSync.shadow.values.contains {
            ($0["page"] as? String) == pageId && ($0[ObjectPatch.deletedField] as? Bool) == false
        }
    }

    /// 依合併後的頁序調整本機的頁面：補上缺的、刪掉被刪的、搬到對的位置（設計 §8.4）。
    ///
    /// **非同步**（`changePageStructure` 先等背景的筆跡寫入落盤）。所以：
    /// - 頁序在**真正調整時**才算 —— 以前在排定時就算好，兩段整份狀態各排一次，後一次拿的是過時的頁序，
    ///   把前一次剛補上的頁又刪掉；
    /// - 調整期間本機的修改先不送（`CollabObjectSync.pageReconcilePending`）：筆記本裡暫時沒有那幾頁，
    ///   送出的話等於宣告「那幾頁被刪了」，房主的頁會被刪到只剩一頁；
    /// - 補上頁之後，等著那幾頁的物件與筆畫才寫進去。
    func reconcilePagesWithCollab() {
        guard !collabSync.desiredPageOrder().isEmpty else { return }
        func reload() {
            if let updated = store.notebooks.first(where: { $0.id == notebook.id }) { notebook = updated }
        }
        let sync = collabSync
        sync.pageReconcilePending += 1
        sync.pageReconcileSince = Date()
        // 與本機的頁面操作同一條路：等背景寫入落盤、頁碼暫存照頁面 id 重新對齊、畫布重載。
        changePageStructure {
            defer { finishCollabPageReconcile(sync) }
            // 換了房間（`reset`）：這次調整已經不屬於現在的合併狀態。
            guard sync === collabSync else { return nil }
            let desired = collabSync.desiredPageOrder().map(CollabCanonical.canonicalPageId)
            guard !desired.isEmpty else { return nil }
            var current = (notebook.pageIds ?? []).map(CollabCanonical.canonicalPageId)
            let wanted = Set(desired)
            let focusedId = currentPageIndex < current.count ? current[currentPageIndex] : nil
            var landing = currentPageIndex

            // Step 1: 先補上缺少的頁面（補齊後 notebook.pageCount > 1，後續才能安全刪除多餘的初始空白頁）
            for (target, id) in desired.enumerated()
                where !current.contains(where: { $0.caseInsensitiveCompare(id) == .orderedSame }) {
                let paper = (collabSync.shadow["page:\(id)"] ?? collabSync.shadow["page:\(id.uppercased())"])?["paper"] as? String
                _ = store.insertPage(notebookId: notebook.id, afterIndex: min(target, current.count) - 1,
                                     paperId: paper, pageId: id)
                reload()
                current = (notebook.pageIds ?? []).map(CollabCanonical.canonicalPageId)
            }

            // Step 2: 刪除不在 wanted 名單中的頁面（包括剛進房時預先建立的單頁空白頁）
            for (index, id) in current.enumerated().reversed()
                where !wanted.contains(where: { $0.caseInsensitiveCompare(id) == .orderedSame }) && notebook.pageCount > 1 {
                landing = store.deletePage(notebookId: notebook.id, pageIndex: index, currentIndex: landing)
                reload()
                current = (notebook.pageIds ?? []).map(CollabCanonical.canonicalPageId)
            }

            // Step 3: 依 desired 順序重新排列頁面
            for (target, id) in desired.enumerated() {
                guard let from = current.firstIndex(where: { $0.caseInsensitiveCompare(id) == .orderedSame }),
                      from != target, target < current.count else { continue }
                _ = store.movePage(notebookId: notebook.id, from: from, to: target)
                reload()
                current = (notebook.pageIds ?? []).map(CollabCanonical.canonicalPageId)
            }
            settleCollabPagesAdded()
            // 停在同一頁的內容上（照頁面 id 找）；那一頁被刪掉了才退回刪除後的頁碼。
            return focusedId.flatMap { f in current.firstIndex(where: { $0.caseInsensitiveCompare(f) == .orderedSame }) } ?? landing
        }
    }

    /// 頁面補上之後：等著那幾頁的物件寫回、擱著的筆畫寫進那幾頁的「別台筆畫」檔（畫面上的圖層隨後由
    /// `changePageStructure` 從磁碟重讀）。都是別人的內容，不送出。
    private func settleCollabPagesAdded() {
        ensureCollabPageIds()
        collabSync.isApplyingRemote = true
        var doc = notebook
        collabSync.retryDeferred(into: &doc)
        let stacking = collabSync.desiredStacking()
        CollabCanonical.writeStacking(orders: stacking.orders, under: stacking.under, locked: stacking.locked, into: &doc)
        notebook = doc
        collabSync.refreshShadow(from: notebook, keepMissingPages: true)
        store.updateNotebook(notebook)
        collabSync.isApplyingRemote = false
        let ids = (notebook.pageIds ?? []).map(CollabCanonical.canonicalPageId)
        for (page, ink) in collabSync.pendingInk {
            let canonical = CollabCanonical.canonicalPageId(page)
            guard let index = ids.firstIndex(where: { $0.caseInsensitiveCompare(canonical) == .orderedSame }) else { continue }
            collabSync.pendingInk.removeValue(forKey: page)
            // 直接寫檔，不經畫面上的圖層：此刻圖層的頁碼還是調整前的（稍後統一重讀）。
            ProInkCollab.applyRemoteOnDisk(directory: store.drawingsDirectory, notebookId: notebook.id, page: index,
                                           added: ink.added, removedIds: ink.removed)
        }
        ProInkCollab.reloadLayers(notebookId: notebook.id)
        refreshAllThumbnails()
    }

    /// 一次頁面結構調整做完（或放棄）。全部做完時，調整期間擱著的本機修改送出去。
    private func finishCollabPageReconcile(_ sync: CollabObjectSync) {
        sync.pageReconcilePending = max(0, sync.pageReconcilePending - 1)
        guard sync === collabSync, sync.pageReconcilePending == 0, sync.publishAfterReconcile else { return }
        sync.publishAfterReconcile = false
        DispatchQueue.main.async { publishCollabChanges() }
    }

    /// 別人的筆畫落在這台還沒有的頁：那一頁在合併結果裡（等著補上）就先擱著，否則丟掉。
    func holdCollabInkIfPending(page: String, added: [ProStroke], removed: Set<String>) {
        let canonical = CollabCanonical.canonicalPageId(page)
        guard !added.isEmpty || !removed.isEmpty,
              collabSync.desiredPageOrder().contains(where: { $0.caseInsensitiveCompare(canonical) == .orderedSame }) else { return }
        collabSync.holdInk(page: canonical, added: added, removed: removed)
    }

    /// 套用別人在同一個文字方塊打的字（設計 §8.3）。
    func applyRemoteTextOps(_ payload: [String: Any]) {
        guard let id = payload["id"] as? String,
              let list = payload["ops"] as? [[String: Any]],
              let fullText = payload["text"] as? String,
              let index = notebook.textAttachments?.firstIndex(where: { CollabCanonical.canonicalId($0.id) == id })
        else { return }
        let me = collaborationManager.currentUserId
        let current = notebook.textAttachments?[index].text ?? ""
        let base = (collabSync.shadow["text:\(id)"]?["text"] as? String) ?? current
        let replica = collabTextHub.replica(for: id, base: base, site: me)
        var newText: String
        if let theirBase = payload["base"] as? String, theirBase != replica.baseHash, replica.text == base {
            // 兩邊的基準對不上（協同開始前就不一致）：以對方的全文為準並重建基準 —— 結果仍一致。
            collabTextHub.rebase(id, text: fullText, site: me)
            newText = fullText
        } else {
            for json in list { if let op = CollabText.Op(json: json) { replica.apply(op) } }
            newText = replica.text
        }
        guard newText != current else { return }
        collabSync.isApplyingRemote = true
        replaceCollabText(at: index, with: newText, in: &notebook)
        collabSync.refreshShadow(from: notebook)
        commitNotebook()
        collabSync.isApplyingRemote = false
        refreshAllThumbnails()
    }

    /// 把某個方塊的內容換成別人的（格式區段跟著平移、方塊長高），不送出。
    func replaceCollabText(at index: Int, with newText: String, in doc: inout NotebookDocument) {
        guard var item = doc.textAttachments?[index], item.text != newText else { return }
        let old = item.text
        item.text = newText
        RichText.adjustRuns(of: &item, from: old)
        item.height = max(item.height, RichText.boxHeight(for: item))
        doc.textAttachments?[index] = item
    }

    /// 別人擦掉的筆畫：只移除這幾筆，別人同時畫的不受影響。
    func applyRemoteInkRemove(pageId: String, wires: [String]) {
        guard let pageIdx = notebook.pageIds?.firstIndex(of: pageId), !wires.isEmpty else { return }
        let base = drawingForCollab(page: pageIdx)
        let locals = Set(wires.map(collabInkLedger.localId(forWire:)))
        let merged = CollabInk.removing(locals, from: base)
        collabInkLedger.known[pageId, default: []].subtract(wires)
        collabInkLedger.removed(page: pageId, wires: wires)
        nonisolated(unsafe) let gone = base.strokes.filter { locals.contains(CollabInk.strokeId($0)) }
        let directory = store.syncBaselineDirectory, nid = notebook.id
        Self.coreInkQueue.async {
            CollabInkPersistence.remoteRemoved(gone, in: directory, notebookId: nid, page: pageIdx)
        }
        if merged.strokes.count != base.strokes.count {
            applyRemoteDrawing(page: pageIdx, remote: merged, replace: true)
        }
    }

    // MARK: 整份狀態（設計 §7）

    /// 向房間要整份狀態（加入房間、或中繼的暫存已經補不回漏掉的那一段）。
    /// 附上自己已有的圖片：回覆的人只需帶我沒有的圖檔。
    func requestCollabState() {
        guard isCollaborating else { return }
        let req = collabStateSync.begin()
        let blobs = Set(collabSync.shadow.values.compactMap { $0["blob"] as? String })
        collaborationManager.broadcastOplog(kind: "state_request", payload: [
            "proto": Self.collabProto, "req": req, "blobs": Array(blobs)
        ])
    }

    /// 回覆一份整份狀態給 `to`，分段送。
    func answerCollabState(req: String, to: String, blobs: Set<String>) {
        collabStateSync.remember(req)
        saveCurrentPageDrawing()
        ensureCollabPageIds()
        collabSync.refreshShadow(from: notebook, keepMissingPages: true)
        ProInkStore.flushPendingWrites()
        Task { @MainActor in
            let items = await collectCollabState(blobs: blobs)
            sendCollabStateParts(items, req: req, to: to)
        }
    }

    /// 把這本目前的整份狀態寄存到雲端中繼（`state_store`，中繼不轉送，新加入的人補發時先拿到它）。
    /// 內容與回覆 `state_request` 同一個格式、同樣端對端加密；信封上帶明文的 `snap`／`part`／`parts`／`seq`。
    func depositCollabState() async {
        guard isCollaborating, collaborationManager.isOnCloudRelay else { return }
        collaborationManager.noteStateDeposited()
        saveCurrentPageDrawing()
        ensureCollabPageIds()
        collabSync.refreshShadow(from: notebook, keepMissingPages: true)
        ProInkStore.flushPendingWrites()
        let items = await collectCollabState(blobs: [])
        guard isCollaborating else { return }
        let snap = UUID().uuidString.lowercased()
        let seq = collaborationManager.relaySeq
        sendCollabStateParts(items, req: "store", to: "*", kind: "state_store") { index, count in
            ["snap": snap, "part": index, "parts": count, "seq": seq]
        }
    }

    /// 整份狀態的內容：物件（含我方要補給對方的圖檔）與每一頁的全部筆畫。逐頁讀檔在背景做。
    private func collectCollabState(blobs: Set<String>) async -> [(ink: Bool, json: [String: Any])] {
        ensureCollabPageIds()
        collabSync.refreshShadow(from: notebook, keepMissingPages: true)
        var items: [(ink: Bool, json: [String: Any])] = []
        for entry in collabSync.snapshot() {
            var json = entry.json
            if entry.type == "image",
               let hash = entry.groups.lazy.compactMap({ $0.fields["blob"] as? String }).first, !blobs.contains(hash),
               let fileName = collabSync.shadow[entry.key]?["a.image.fileName"] as? String, !fileName.isEmpty,
               let data = try? Data(contentsOf: store.attachmentsDirectory.appending(path: fileName)) {
                json["b64"] = data.base64EncodedString()
            }
            items.append((false, json))
        }
        // 筆跡：**每一頁的全部自繪筆畫**（自己的與別台的）都帶上，加上這次協同期間擦掉的。
        // 收到的一方以筆畫 id 去重，已經有的不會多出一份。逐頁讀檔在背景做。
        let pageIds = NotebookPackageBridge.resolvedPageIds(for: notebook, packagesDirectory: store.syncPackagesDirectory)
        let removedByPage = collabInkLedger.sessionRemoved
        let directory = store.drawingsDirectory, nid = notebook.id
        let activePage = currentPageIndex
        let liveStrokes = (canvasView as? AdaptiveCanvasView)?.proLayer?.ownStrokes ?? []
        nonisolated(unsafe) let objectItems = items
        let task = Task.detached(priority: .userInitiated) { () -> [(ink: Bool, json: [String: Any])] in
            var all = objectItems
            for (index, page) in pageIds.enumerated() {
                let canonicalPage = CollabCanonical.canonicalPageId(page)
                var strokes = ProInkStore.load(in: directory, notebookId: nid, page: index)
                    + ProInkStore.load(in: directory, notebookId: nid, page: index, foreign: true)
                if index == activePage && !liveStrokes.isEmpty {
                    let knownIds = Set(strokes.map(\.packageId))
                    let uncommitted = liveStrokes.filter { !knownIds.contains($0.packageId) }
                    strokes.append(contentsOf: uncommitted)
                }
                let removed = Array(removedByPage[canonicalPage] ?? removedByPage[page] ?? [])
                guard !strokes.isEmpty || !removed.isEmpty else { continue }
                all.append((true, ["page": canonicalPage, "strokes": strokes.map(CollabStroke.encode(pro:)),
                                   "removed": removed]))
            }
            return all
        }
        nonisolated(unsafe) let ready = await task.value
        return ready
    }

    /// 把整份狀態切段送出（每段約 `CollabStateSync.partBytes`）。
    private func sendCollabStateParts(
        _ items: [(ink: Bool, json: [String: Any])], req: String, to: String, kind: String = "state_snapshot",
        envelope: (Int, Int) -> [String: Any] = { _, _ in [:] }
    ) {
        guard isCollaborating else { return }
        func size(_ json: [String: Any]) -> Int { (try? JSONSerialization.data(withJSONObject: json))?.count ?? 0 }
        var parts: [(objects: [[String: Any]], ink: [[String: Any]])] = [([], [])]
        var bytes = 0
        for item in items {
            let length = size(item.json)
            if bytes > 0, bytes + length > CollabStateSync.partBytes {
                parts.append(([], []))
                bytes = 0
            }
            if item.ink { parts[parts.count - 1].ink.append(item.json) } else { parts[parts.count - 1].objects.append(item.json) }
            bytes += length
        }
        for (index, part) in parts.enumerated() {
            let delay = Double(index) * 0.03
            let extra = envelope(index, parts.count)
            var payload: [String: Any] = [
                "proto": Self.collabProto, "req": req, "to": to, "part": index, "parts": parts.count,
                "objects": part.objects, "ink": part.ink
            ]
            if let snap = extra["snap"] { payload["snap"] = snap }
            let collabMgr = collaborationManager
            if delay == 0 {
                collabMgr.broadcastOplog(kind: kind, payload: payload, envelope: extra)
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    collabMgr.broadcastOplog(kind: kind, payload: payload, envelope: extra)
                }
            }
        }
    }

    /// 收到整份狀態的一段。全部收齊後，「只有自己有」的物件補給房間。
    ///
    /// `stored`：中繼寄存的那一份（`state_store`，補發時給剛進房的人）。不是回覆我的請求，
    /// 以它自己的 `snap` 計段；套用規則相同（房間的內容優先於自己可能過期的起點）。
    func applyCollabStateSnapshot(_ payload: [String: Any], stored: Bool = false) {
        guard let part = (payload["part"] as? NSNumber)?.intValue else { return }
        if stored {
            guard let snap = payload["snap"] as? String,
                  collabStateSync.acceptStored(snap: snap, part: part) else { return }
        } else {
            let req = (payload["req"] as? String) ?? ""
            collabStateSync.remember(req)
            let to = (payload["to"] as? String) ?? ""
            let toMe = to.isEmpty || to == "*" || to.caseInsensitiveCompare(collaborationManager.currentUserId) == .orderedSame
            guard (req == collabStateSync.pendingRequest || collabStateSync.wasRequested(req)),
                  toMe,
                  collabStateSync.receivedParts.insert(part).inserted else { return }
        }
        let parts = (payload["parts"] as? NSNumber)?.intValue ?? 1
        ensureCollabPageIds()
        var entries: [SnapshotEntry] = []
        for json in (payload["objects"] as? [[String: Any]]) ?? [] {
            guard let entry = SnapshotEntry(json: json) else { continue }
            if let b64 = json["b64"] as? String {
                let fields = entry.groups.reduce(into: [String: Any]()) { $0.merge($1.fields) { a, _ in a } }
                storeIncomingBlob(b64, fileName: fields["a.image.fileName"] as? String,
                                  hash: fields["blob"] as? String, fallbackId: entry.id)
            }
            entries.append(entry)
        }
        if stored {
            collabStateSync.storedKeys.formUnion(entries.map(\.key))
        } else {
            collabStateSync.snapshotKeys.formUnion(entries.map(\.key))
        }
        let me = collaborationManager.currentUserId
        collabSync.isApplyingRemote = true
        var doc = notebook
        let result = collabSync.applySnapshot(entries, to: &doc)
        notebook = doc
        if entries.contains(where: { $0.type == "page" }) {
            store.updateNotebook(notebook)
            reconcilePagesWithCollab()
        }
        var withDeferred = notebook
        collabSync.retryDeferred(into: &withDeferred)
        let stacking = collabSync.desiredStacking()
        CollabCanonical.writeStacking(orders: stacking.orders, under: stacking.under, locked: stacking.locked, into: &withDeferred)
        for override in result.textOverrides {
            collabTextHub.rebase(override.id, text: override.text, site: me)
            if let index = withDeferred.textAttachments?.firstIndex(where: { CollabCanonical.canonicalId($0.id) == override.id }) {
                replaceCollabText(at: index, with: override.text, in: &withDeferred)
            }
        }
        notebook = withDeferred
        collabSync.refreshShadow(from: notebook, keepMissingPages: true)
        commitNotebook()
        collabSync.isApplyingRemote = false
        for pageInk in (payload["ink"] as? [[String: Any]]) ?? [] {
            guard let rawPage = pageInk["page"] as? String else { continue }
            let page = CollabCanonical.canonicalPageId(rawPage)
            // 筆畫放進自繪引擎（與即時的 `ink_add` 同一條路，見 `applyRemoteOplog`）。
            let pageIdx = notebook.pageIds?.firstIndex(where: { $0.caseInsensitiveCompare(page) == .orderedSame })
            let strokes = ((pageInk["strokes"] as? [[String: Any]]) ?? []).compactMap(CollabStroke.decodePro)
            let removed = (pageInk["removed"] as? [String]) ?? []
            guard let pageIdx else {
                // 這一頁還在等頁面結構調整補上：筆畫先擱著（以前直接丟掉，第 2、3 頁一片空白）。
                holdCollabInkIfPending(page: page, added: strokes, removed: Set(removed.map { $0.lowercased() }))
                continue
            }
            if !strokes.isEmpty || !removed.isEmpty {
                ProInkCollab.applyRemote(directory: store.drawingsDirectory, notebookId: notebook.id, page: pageIdx,
                                         added: strokes, removedIds: Set(removed.map { $0.lowercased() }))
            }
            if !removed.isEmpty { applyRemoteInkRemove(pageId: page, wires: removed) }
        }
        refreshAllThumbnails()
        if stored {
            guard collabStateSync.storedParts.count >= parts else { return }
        } else {
            guard collabStateSync.receivedParts.count >= parts else { return }
            collabStateSync.finish()
        }
        // 「房間裡有的」以兩份整份狀態的聯集判斷：寄存的那一份可能比較舊，只拿它比，
        // 房主之後才加的物件與空白頁會被當成「只有自己有」—— 物件以舊值再送一次、空白頁被刪掉。
        let snapshotKeys = Set(collabStateSync.storedKeys.union(collabStateSync.snapshotKeys).map { key -> String in
            key.hasPrefix("page:") ? "page:\(CollabCanonical.canonicalPageId(String(key.dropFirst(5))))" : key
        })
        let localOnly = collabSync.liveKeys.filter { key in
            let canonicalKey = key.hasPrefix("page:") ? "page:\(CollabCanonical.canonicalPageId(String(key.dropFirst(5))))" : key
            return !snapshotKeys.contains(canonicalKey) && !key.hasPrefix("meta:")
        }
        guard !localOnly.isEmpty else { return }
        let emptyPages = localOnly.filter { $0.hasPrefix("page:") && isEmptyCollabPage(String($0.dropFirst(5))) }
        if !emptyPages.isEmpty {
            collabSync.markDeleted(emptyPages)
            reconcilePagesWithCollab()
        }
        let keep = localOnly.subtracting(emptyPages)
        guard !keep.isEmpty else { return }
        collabSync.forget(keep)
        publishCollabChanges()
    }

    /// 協同套用筆跡時的基準：目前頁取畫面上的，其他頁取存檔的。
    func drawingForCollab(page: Int) -> PKDrawing {
        page == currentPageIndex
            ? (canvasView?.drawing ?? currentDrawing)
            : store.loadDrawing(notebookId: notebook.id, pageIndex: page)
    }

    /// 處理協同遠端廣播操作（CRDT Oplog 合併）
    /// 別台送來的變更不算這台使用者的動作：不登記復原（否則按復原會把別人的修改退掉）。
    func handleRemoteOplog(_ event: RemoteOplogEvent) {
        objectHistory.withoutRecording { applyRemoteOplog(event) }
    }

    func applyRemoteOplog(_ event: RemoteOplogEvent) {
        switch event.kind {
        case "obj_patch":
            guard let list = event.payload["patches"] as? [[String: Any]] else { return }
            applyRemotePatches(list.compactMap(ObjectPatch.init(payload:)),
                               stamp: LamportStamp(lamport: event.lamport, user: event.userId))

        case "ink_add":
            // 所有筆刷都由自繪引擎畫（ADR-0015 階段 5）：別人的筆畫也放進自繪引擎的「別台筆畫」，
            // 與自己的筆畫同一套算繪。以前放進 PencilKit 圖層，同一筆在這台看起來又細又淡、
            // 與送出那台不一樣。
            guard let rawPageId = event.payload["page"] as? String,
                  let list = event.payload["strokes"] as? [[String: Any]] else { return }
            let pageId = CollabCanonical.canonicalPageId(rawPageId)
            let strokes = list.compactMap(CollabStroke.decodePro)
            guard !strokes.isEmpty else { return }
            guard let pageIdx = notebook.pageIds?.firstIndex(where: { $0.caseInsensitiveCompare(pageId) == .orderedSame }) else {
                holdCollabInkIfPending(page: pageId, added: strokes, removed: [])
                return
            }
            ProInkCollab.applyRemote(directory: store.drawingsDirectory, notebookId: notebook.id, page: pageIdx,
                                     added: strokes, removedIds: [])
            ThumbnailPipeline.shared.markDirty(notebookId: notebook.id, pageIndex: pageIdx)
            thumbnailRevision += 1

        case "ink_remove":
            guard let rawPageId = event.payload["page"] as? String,
                  let ids = event.payload["ids"] as? [String] else { return }
            let pageId = CollabCanonical.canonicalPageId(rawPageId)
            if let pageIdx = notebook.pageIds?.firstIndex(where: { $0.caseInsensitiveCompare(pageId) == .orderedSame }) {
                ProInkCollab.applyRemote(directory: store.drawingsDirectory, notebookId: notebook.id, page: pageIdx,
                                         added: [], removedIds: Set(ids.map { $0.lowercased() }))
                ThumbnailPipeline.shared.markDirty(notebookId: notebook.id, pageIndex: pageIdx)
                thumbnailRevision += 1
            }
            // 舊版留在 PencilKit 圖層裡的筆畫照舊處理。
            applyRemoteInkRemove(pageId: pageId, wires: ids)

        case "state_request":
            guard let req = event.payload["req"] as? String else { return }
            // 排名：除了請求者以外，依使用者 id 排序。第一名立刻回，其餘的人依序多等一下。
            let everyone = (collaborationManager.peers.map(\.userId) + [collaborationManager.currentUserId])
                .filter { $0 != event.userId }.sorted()
            let rank = everyone.firstIndex(of: collaborationManager.currentUserId) ?? 0
            let blobs = Set((event.payload["blobs"] as? [String]) ?? [])
            let requester = event.userId
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(rank) * CollabStateSync.answerStagger) {
                guard isCollaborating, !collabStateSync.wasAnswered(req) else { return }
                answerCollabState(req: req, to: requester, blobs: blobs)
            }

        case "state_snapshot":
            applyCollabStateSnapshot(event.payload)

        case "state_store":
            // 中繼寄存的整份狀態（只在補發時給剛進房的人；中繼不轉送）。
            applyCollabStateSnapshot(event.payload, stored: true)

        case "text_ops":
            applyRemoteTextOps(event.payload)

        case "stroke_delta", "drawing_replace":
            // 舊版送來的筆跡：一律當成「加入缺少的筆畫」，**不刪任何東西** ——
            // 舊的整頁取代會把本機同時畫的筆畫蓋掉。
            guard let pageIdx = event.payload["page_index"] as? Int,
                  let b64 = event.payload["drawing_base64"] as? String,
                  let data = Data(base64Encoded: b64),
                  let remoteDrawing = try? PKDrawing(data: data) else { return }
            let base = drawingForCollab(page: pageIdx)
            let merged = CollabInk.adding(remoteDrawing.strokes, to: base)
            if merged.strokes.count != base.strokes.count {
                applyRemoteDrawing(page: pageIdx, remote: merged, replace: true)
            }

        case "attachment_delete":
            // 舊版的刪除：當成一筆帶時鐘的刪除修改，與新版走同一套合併。
            guard let attId = event.payload["id"] as? String,
                  let attType = event.payload["attachment_type"] as? String else { return }
            applyRemotePatches([ObjectPatch(type: attType, id: attId, fields: [ObjectPatch.deletedField: true])],
                               stamp: LamportStamp(lamport: event.lamport, user: event.userId))

        case "attachment_upsert":
            // 舊版的整個物件：當成「所有欄位」的修改，以它的時鐘參與合併。
            guard let attType = event.payload["attachment_type"] as? String,
                  var itemDict = event.payload["item"] as? [String: Any],
                  let itemId = itemDict["id"] as? String else { return }
            if let b64 = itemDict.removeValue(forKey: "image_base64") as? String {
                itemDict[CollabObjectSync.blobField] = b64
            }
            itemDict[ObjectPatch.deletedField] = false
            applyRemotePatches([ObjectPatch(type: attType, id: itemId, fields: itemDict)],
                               stamp: LamportStamp(lamport: event.lamport, user: event.userId))

        case "comment_upsert":
            guard let pinDict = event.payload["pin"] as? [String: Any],
                  let jsonData = try? JSONSerialization.data(withJSONObject: pinDict),
                  let pin = try? JSONDecoder().decode(NoteCommentPin.self, from: jsonData) else { return }

            if let idx = notebook.commentPins?.firstIndex(where: { $0.id == pin.id }) {
                notebook.commentPins?[idx] = pin
            } else {
                if notebook.commentPins == nil { notebook.commentPins = [] }
                notebook.commentPins?.append(pin)
            }
            commitNotebook()

        case "comment_resolve":
            guard let pinId = event.payload["pin_id"] as? String,
                  let isResolved = event.payload["is_resolved"] as? Bool else { return }

            if let idx = notebook.commentPins?.firstIndex(where: { $0.id == pinId }) {
                notebook.commentPins?[idx].isResolved = isResolved
                commitNotebook()
            }

        case "comment_delete":
            guard let pinId = event.payload["pin_id"] as? String else { return }
            notebook.commentPins?.removeAll { $0.id == pinId }
            if selectedCommentPinId == pinId {
                selectedCommentPinId = nil
            }
            commitNotebook()

        default:
            break
        }
    }

    func broadcastCommentPinUpsert(_ pin: NoteCommentPin) {
        guard let data = try? JSONEncoder().encode(pin),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        collaborationManager.broadcastCommentUpsert(pinDict: dict)
    }

    func addCommentReply(pinId: String, text: String) {
        let msg = NoteCommentMessage(
            authorId: collaborationManager.currentUserId,
            authorName: AccountManager.shared.profile.displayName,
            authorColor: collaborationManager.myColorHex,
            text: text
        )
        if let idx = notebook.commentPins?.firstIndex(where: { $0.id == pinId }) {
            notebook.commentPins?[idx].messages.append(msg)
            commitNotebook()
            if let pin = notebook.commentPins?[idx] {
                broadcastCommentPinUpsert(pin)
            }
        }
    }

    func toggleCommentResolve(pinId: String) {
        if let idx = notebook.commentPins?.firstIndex(where: { $0.id == pinId }) {
            notebook.commentPins?[idx].isResolved.toggle()
            let state = notebook.commentPins?[idx].isResolved ?? false
            commitNotebook()
            collaborationManager.broadcastCommentResolve(pinId: pinId, isResolved: state)
        }
    }

    /// 刪除討論串中的單一則留言。
    /// 只剩最後一則時不刪 —— 沒有任何訊息的圖釘在畫布上等於一個看不出用途的點，
    /// 要整個移除請用圖釘上的垃圾桶。
    func deleteCommentMessage(pinId: String, messageId: String) {
        guard let idx = notebook.commentPins?.firstIndex(where: { $0.id == pinId }),
              let count = notebook.commentPins?[idx].messages.count,
              count > 1 else { return }
        notebook.commentPins?[idx].messages.removeAll { $0.id == messageId }
        commitNotebook()
        if let pin = notebook.commentPins?[idx] {
            broadcastCommentPinUpsert(pin)
        }
    }

    func deleteCommentPin(pinId: String) {
        notebook.commentPins?.removeAll { $0.id == pinId }
        commitNotebook()
        selectedCommentPinId = nil
        collaborationManager.broadcastCommentDelete(pinId: pinId)
        collaborationManager.broadcastSelection(selectedId: nil)
    }

    /// 使用者明確開始了一個新動作（開始編輯、刪除、拖曳…）：下一個變更另起一步，
    /// 不跟前一個連續變動合併。
    func recordTextUndoState() {
        objectHistory.breakCoalescing()
    }

    /// 全域復原用的 manager：畫布的（與 PencilKit、專業筆畫共用）。
    var historyUndoManager: UndoManager {
        canvasView?.undoManager ?? fallbackUndoManager
    }

    /// 編輯器寫回筆記本的唯一入口：先讓物件復原紀錄比對這一次的變更，再存檔。
    func commitNotebook() {
        objectHistory.record(notebook, manager: historyUndoManager) { state in
            applyHistoryState(state)
        }
        store.updateNotebook(notebook)
        publishCollabChanges()
        thumbnailRevision += 1
    }

    /// 本機的物件修改即時送給協同的每一個人（設計 §2.1）。
    ///
    /// **所有修改都經過這裡**（`commitNotebook` 與復原／重做），所以框選搬移、圖層、核取方塊、
    /// 紙張、復原…不會再有「這一種忘了廣播」。一次寫回的所有變動放在同一個操作裡，對方一次套用。
    func publishCollabChanges() {
        guard isCollaborating, !collabSync.isApplyingRemote else { return }
        // 頁面結構調整中：筆記本暫時少了等著補上的頁，這時比對會送出「那幾頁被刪了」。調整完再送。
        // 調整卡住（例如筆記被關掉）超過幾秒就不再等，免得之後的修改永遠送不出去。
        if collabSync.pageReconcilePending > 0 {
            if Date().timeIntervalSince(collabSync.pageReconcileSince) < CollabObjectSync.reconcileWaitLimit {
                collabSync.publishAfterReconcile = true
                return
            }
            collabSync.pageReconcilePending = 0
        }
        ensureCollabPageIds()
        let me = collaborationManager.currentUserId
        let lamport = collaborationManager.nextLamport()
        let outgoing = collabSync.outgoing(for: notebook, stamp: LamportStamp(lamport: lamport, user: me))
        guard !outgoing.isEmpty else { return }

        // 文字內容先送：對方先有了新的字，後面帶格式錨點的修改才認得那些字的 id（設計 §8.3）。
        for edit in outgoing.textEdits {
            let replica = collabTextHub.replica(for: edit.id, base: edit.old, site: me)
            let ops = replica.localEdit(from: edit.old, to: edit.new)
            guard !ops.isEmpty else { continue }
            if let pageIdx = notebook.textAttachments?.first(where: { CollabCanonical.canonicalId($0.id) == edit.id })?.pageIndex,
               let pid = liveInkPageId(pageIdx) {
                collaborationManager.renewLocalPageEdit(pageId: pid)
            }
            collaborationManager.broadcastOplog(kind: "text_ops", payload: [
                "proto": Self.collabProto, "id": edit.id, "base": replica.baseHash, "text": edit.new,
                "ops": ops.map(\.json)
            ])
        }
        if !outgoing.patches.isEmpty {
            var patches = outgoing.patches
            for index in patches.indices where patches[index].type == "text" {
                if let anchors = runAnchors(for: patches[index]) { patches[index].fields[CollabObjectSync.anchorField] = anchors }
            }
            for index in patches.indices where (patches[index].fields[ObjectPatch.deletedField] as? Bool) == false {
                // 新的圖片要連檔案一起送，否則對方只收到一個空框。
                if patches[index].type == "image",
                   let fileName = collabSync.shadow[patches[index].key]?["a.image.fileName"] as? String,
                   let data = try? Data(contentsOf: store.attachmentsDirectory.appending(path: fileName)) {
                    patches[index].fields[CollabObjectSync.blobField] = data.base64EncodedString()
                }
            }
            collaborationManager.broadcastOplog(
                kind: "obj_patch", payload: ["proto": Self.collabProto, "patches": patches.map(\.payload)], lamport: lamport)
            // 新增（或複製出來）的頁面：上面已有的筆畫也要送，否則對方只看到一張空白頁。
            for patch in patches where patch.type == "page"
                && (patch.fields[ObjectPatch.deletedField] as? Bool) == false {
                if let index = notebook.pageIds?.firstIndex(of: patch.id) {
                    broadcastDrawingChange(page: index, drawing: drawingForCollab(page: index))
                }
            }
        }
    }

    /// 協定版本（設計 §8）。4：堆疊順序是物件欄位、格式錨點、整份狀態。
    static let collabProto = 4

    /// 這次修改帶了逐字格式：把每段的頭尾換成字的 id（設計 §8.3）。
    func runAnchors(for patch: ObjectPatch) -> [[String]]? {
        guard let runs = patch.fields["a.runs"] as? [[String: Any]],
              let text = collabSync.shadow[patch.key]?["text"] as? String else { return nil }
        let replica = collabTextHub.replica(for: patch.id, base: text, site: collaborationManager.currentUserId)
        guard replica.text == text else { return nil }
        let spans = runs.map { ((($0["start"] as? NSNumber)?.intValue) ?? 0, (($0["length"] as? NSNumber)?.intValue) ?? 0) }
        return CollabRunAnchors.anchors(spans.map { (start: $0.0, length: $0.1) }, in: replica)
    }

    /// 協同要以頁面 id 指稱頁面（設計 §8.1）：還沒有的話沿用套件裡的那一批。
    func ensureCollabPageIds() {
        CollabCanonical.attachmentsDirectory = store.attachmentsDirectory
        let ids = NotebookPackageBridge.resolvedPageIds(for: notebook, packagesDirectory: store.syncPackagesDirectory)
        guard notebook.pageIds != ids else { return }
        notebook.pageIds = ids
        store.updateNotebook(notebook)
    }

    /// 套上復原／重做的物件狀態。筆跡不動（它由 PencilKit 自己復原）。
    func applyHistoryState(_ state: CanvasObjectState) {
        var doc = notebook
        state.apply(to: &doc)
        // 協同中：別人在我之後改過的欄位保留別人的值（設計 §6）。復原只退自己的動作。
        if isCollaborating,
           collabSync.protectRemoteEdits(target: &doc, current: notebook, me: collaborationManager.currentUserId) {
            objectHistory.reset(to: doc)
            showCanvasNotice(localizationManager.localized("collab_undo_partial"))
        }
        notebook = doc
        store.updateNotebook(notebook)
        publishCollabChanges()
        refreshAllThumbnails()
        thumbnailRevision += 1
        // 指向已經不存在的物件的選取與編輯狀態要清掉，否則工具列對著一個空殼。
        let alive = state.allObjectIds
        if let id = inlineEditingTextId, !alive.contains(id) { inlineEditingTextId = nil }
        if let id = editingTextId, !alive.contains(id) { editingTextId = nil }
        if let id = activeSelectedObjectId, !alive.contains(id) { activeSelectedObjectId = nil }
        if let id = textFormatTargetId, !alive.contains(id) { endTextFormatSession() }
        selectedObjectIds = selectedObjectIds.filter { alive.contains($0) }
        selectedShapeIds = selectedShapeIds.filter { alive.contains($0) }
    }

    /// 復原：筆跡、專業筆畫、物件的任何操作，照發生順序退一步。
    func performUndo() { stepHistory(undo: true) }

    /// 重做（協同時只重做自己的操作）。
    func performRedo() { stepHistory(undo: false) }

    /// 退一步／進一步，**跳過沒有效果的項目**。
    ///
    /// 堆疊裡會有空的或已經失效的項目：作廢物件紀錄後留下的空群組、程式替換筆畫後
    /// PencilKit 指向不存在筆畫的那一項。照實執行的話使用者按一次復原什麼都沒發生，
    /// 以為功能壞了。所以一直退到畫面真的有變（物件、筆跡或專業筆畫）為止。
    func stepHistory(undo: Bool) {
        let manager = historyUndoManager
        for _ in 0..<12 {
            guard undo ? manager.canUndo : manager.canRedo else {
                CanvasDiag.log(undo ? "復原：沒有可復原的項目" : "重做：沒有可重做的項目")
                return
            }
            let canvas = canvasView as? AdaptiveCanvasView
            let drawingBefore = canvasView?.drawing
            let proBefore = canvas?.proLayer?.ownStrokes.map(\.id)
            let appliedBefore = objectHistory.appliedCount
            var proChanged = false
            let token = NotificationCenter.default.addObserver(
                forName: AppCommand.proInkDidChange, object: nil, queue: nil) { _ in proChanged = true }
            if undo { manager.undo() } else { manager.redo() }
            NotificationCenter.default.removeObserver(token)

            if objectHistory.appliedCount != appliedBefore {
                CanvasDiag.log(undo ? "復原：物件" : "重做：物件")
                return
            }
            if canvasView?.drawing != drawingBefore || proChanged
                || canvas?.proLayer?.ownStrokes.map(\.id) != proBefore {
                CanvasDiag.log(undo ? "復原：筆畫" : "重做：筆畫")
                return
            }
            CanvasDiag.log(undo ? "復原：略過一個沒有效果的項目" : "重做：略過一個沒有效果的項目")
        }
    }

    /// 接住拖進畫布的圖片（工作項 S-68）。
    ///
    /// 回傳值是**同步**的「我要不要接這一批」—— 圖片是非同步載進來的，
    /// 等載完再回答的話系統早就把拖放取消掉了。所以這裡看的是「有沒有
    /// 任何一個來源給得出圖」，真正的插入在回呼裡做。
    func acceptImageDrop(
        _ providers: [NSItemProvider], at location: CGPoint, page: Int
    ) -> Bool {
        guard providers.contains(where: { $0.canLoadObject(ofClass: UIImage.self) }) else {
            return false
        }
        ImageDropLoader.firstImage(from: providers) { image in
            guard let image else { return }
            insertImageAttachment(image, at: location, page: page)
            // 插進來之後切到打字模式：手寫模式下物件不吃觸控，使用者剛拖
            // 進來的圖會拖不動，看起來像插壞了。Android 端也是這樣做。
            transitionToMode(.type)
        }
        return true
    }

    /// 拖放時的落點提示。
    @ViewBuilder
    func canvasDropHighlight(_ targeted: Bool) -> some View {
        if targeted {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [8, 6]))
                    .background(Color.accentColor.opacity(0.08))

                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.down.fill")
                    Text(L("multi_window_drop_hint"))
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Color.accentColor)
                .cornerRadius(20)
                .shadow(radius: 6)
            }
            .allowsHitTesting(false)
        }
    }

    /// 筆身上的動作（雙擊、擠壓、側鍵、反向筆頭）發生了。
    ///
    /// **規則不在這裡。** 「這個動作要做什麼」整張表在核心
    /// （`padnote-input::pen`），與 Android 共用同一份 —— 各寫一套的話，
    /// 同一支筆在兩台裝置上行為會不同。這裡只負責把核心回的結果換成
    /// 這個 App 的工具。
    ///
    /// 打字模式下不理會：那時候畫布根本不收筆畫，換工具只會讓使用者切回
    /// 手寫時發現筆莫名其妙變了。
    func applyPenControl(_ control: FfiPenControl, pressed: Bool) {
        guard isCanvasInkActive else { return }

        let settings = PenHardwareSettings.shared
        // 按著的控制項（側鍵、反向筆頭）放開時，只還原**我們自己切過去的
        // 那一次**。使用者自己在工具列上選了橡皮擦、然後碰了一下側鍵，
        // 放開時把他的橡皮擦換掉是錯的。
        if settings.isMomentary(control) {
            if pressed {
                penHeldTool = selectedTool
            } else if penHeldTool == nil {
                return
            }
        }

        let outcome = settings.controls.outcome(
            control: control,
            pressed: pressed,
            erasing: selectedTool == .eraser,
            lassoing: selectedTool == .lasso)

        switch outcome {
        case .nothing:
            return
        case .useEraser:
            applyEditorTool(.eraser)
        case .useLastBrush:
            // 放開時回到按下去之前那支，而不是「最後用過的筆刷」——
            // 兩者通常一樣，但使用者若在按著側鍵的期間又換過筆，
            // 他要的是回到他剛剛選的那一支。
            applyEditorTool(penHeldTool ?? lastBrushTool)
        case .useLasso:
            applyEditorTool(.lasso)
        case .showInkAttributes:
            showProColorPicker = true
        case .undo:
            performUndo()
        case .redo:
            performRedo()
        case .toggleRuler:
            isRulerActive.toggle()
        }

        if settings.isMomentary(control) && !pressed {
            penHeldTool = nil
        }
        // 筆身的動作是看不見的 —— 使用者當下正看著筆尖，一下短回饋讓他
        // 知道剛剛那下有收到，不必抬頭確認工具列。
        PenHaptics.penControlFired(in: canvasView)
    }

    /// 筆跡動過了。去抖動之後把筆記標記成剛改過並落盤。
    ///
    /// 1.2 秒與同步排程器的去抖動（1.5 秒）刻意錯開：先把本機狀態定下來，
    /// 再讓同步那一輪去看已經穩定的內容。反過來的話，同步會拿到寫到一半的
    /// 那個瞬間，然後下一輪再傳一次。
    func noteInkEdited() {
        inkTouchWork?.cancel()
        let work = DispatchWorkItem {
            // `updateNotebook` 自己會蓋上現在的時間，並在 `persistData()`
            // 裡通知自動同步。這裡不碰 `AccountSyncStore` —— 內容改動不是
            // 中繼資料改動，把時戳往前推會讓這台裝置永遠贏過另一台對同一本
            // 筆記的改名，而那次改名其實比較晚。
            commitNotebook()
            thumbnailRevision += 1
        }
        inkTouchWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: work)
    }

    func corePackageURL() -> URL {
        store.corePackagesDirectory.appending(path: "\(notebook.id.lowercased()).padnote")
    }

    /// 取得指定頁面的手寫筆跡（統一自 PageInkStore 讀取，單一真相）
    /// 縮圖要算繪時才取筆跡的閉包。沒載入過的頁取筆跡要讀檔解碼，不能在 `body` 裡做。
    func pageDrawingProvider(_ page: Int) -> () -> PKDrawing {
        let ink = activeInkStore
        let pid = (notebook.pageIds != nil && page < (notebook.pageIds?.count ?? 0)) ? notebook.pageIds?[page] : nil
        return { ink.drawing(for: page, pageId: pid) }
    }

    func drawingForPage(_ page: Int) -> PKDrawing {
        let pid = (notebook.pageIds != nil && page < (notebook.pageIds?.count ?? 0)) ? notebook.pageIds?[page] : nil
        return activeInkStore.drawing(for: page, pageId: pid)
    }

    /// 這一頁的畫布**上一刻真正顯示**的筆跡（畫布與綁定上次講好的那一份）。這一頁沒有畫布就是 `nil`。
    func shownDrawing(page: Int) -> PKDrawing? {
        let canvas: PKCanvasView?
        if pageDisplayMode == .single {
            canvas = page == currentPageIndex && canvasShowsCurrentPage ? canvasView : nil
        } else {
            canvas = continuousCanvases[page]
        }
        return (canvas?.delegate as? CanvasRepresentable.Coordinator)?.lastSyncedDrawing
    }

    func refreshAllThumbnails() {
        PageThumbnailRenderer.invalidateAll()
        for idx in 0..<notebook.pageCount {
            ThumbnailPipeline.shared.markDirty(notebookId: notebook.id, pageIndex: idx)
        }
        thumbnailRevision += 1
    }

    func inkRevisionForPage(_ page: Int) -> Int {
        let pid = (notebook.pageIds != nil && page < (notebook.pageIds?.count ?? 0)) ? notebook.pageIds?[page] : nil
        let pkRev = activeInkStore.revision(for: page, pageId: pid)
        let proRev = ProInkStore.revision(in: store.drawingsDirectory, notebookId: notebook.id, page: page)
        return pkRev &* 31 &+ proRev
    }

    func recordDrawingEdit(page: Int, drawing: PKDrawing) {
        if notebook.isReadOnlySample && !hasWarnedSampleReadOnly {
            hasWarnedSampleReadOnly = true
            showSampleReadOnlyAlert = true
        }
        if page == currentPageIndex {
            currentDrawing = drawing
        }
        let pid = (notebook.pageIds != nil && page < (notebook.pageIds?.count ?? 0)) ? notebook.pageIds?[page] : nil
        // 編輯器自己的動作（套索、跨頁搬移…）也在當下寫成事件（ADR-0015 I2）。來自畫布的編輯已經由畫布寫過
        // （那時畫布的「上一刻顯示」已更新成這一份，這裡比對不出擦除，不會重複）。
        if let shown = shownDrawing(page: page), let sink = InkEventSink.sink(for: notebook.id) {
            sink.editorEdited(
                page: page, before: activeInkStore.drawing(for: page, pageId: pid), after: drawing, shown: shown)
        }
        activeInkStore.updateDrawing(drawing, for: page, pageId: pid)
        activeInkStore.markPendingCoreFlush(for: page, pageId: pid)
        continuousCanvases.setCachedDrawing(drawing, forPage: page)
        scheduleCoreInkFlush()
        noteInkEdited()
    }

    /// 落筆之後多久把增量寫進套件。
    ///
    /// 原本是 1.2 秒，那是「另一台看得到」之前**必經的第一段** —— 再加上同步排程器
    /// 的去抖動，一筆畫要兩秒多之後才開始往外送。這一步只是把增量追加進套件
    /// （一個小檔案的 append）與寫 `.drawing`，並不昂貴；真正昂貴的
    /// `updateNotebook()`（寫 `notebooks.json`、整棵畫面重算）仍由 `noteInkEdited()`
    /// 的 1.2 秒去抖動負責，沒有動。
    ///
    /// 純去抖動有個缺點：一直不停手就一直不寫。所以有上限 ——
    /// 這一批待寫的筆畫最早的那一筆起算，超過 `inkFlushMaxHold` 就不再等。
    private static let inkFlushDelay: TimeInterval = 0.4
    private static let inkFlushMaxHold: TimeInterval = 1.5

    func scheduleCoreInkFlush() {
        coreInkWork?.cancel()
        let now = Date()
        let firstPending = coreInkFirstPendingAt ?? now
        coreInkFirstPendingAt = firstPending
        let remainingHold = Self.inkFlushMaxHold - now.timeIntervalSince(firstPending)
        let delay = max(0, min(Self.inkFlushDelay, remainingHold))
        let work = DispatchWorkItem {
            flushPendingCoreInk()
        }
        coreInkWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    /// 把筆跡增量寫進核心套件的**背景序列佇列**。同一個套件的寫入必須排隊（順序就是筆畫的順序）。
    static let coreInkQueue = DispatchQueue(label: "kairumo.editor.core-ink", qos: .utility)

    /// 等背景佇列把已排進去的寫入做完，再在主執行緒上做 `work`。**不阻塞主執行緒。**
    /// 佇列是序列的，所以排在它後面就保證前面的寫入都完成了。
    func afterCoreInkWrites(_ work: @escaping @MainActor () -> Void) {
        Self.coreInkQueue.async {
            Task { @MainActor in work() }
        }
    }

    /// 同上，另外先等專業筆畫排隊中的寫入落盤（`ProInkStore.saveDeferred` 去抖動 1.2 秒）。
    ///
    /// 頁面結構變動（搬頁、插入、刪除）要用這一支：排隊中的寫入記的是**舊頁碼的檔名**，
    /// 逐頁檔案改名之後才寫下去的話，剛畫的那幾筆會蓋到換到那個頁碼上的另一頁。
    func afterAllInkWrites(_ work: @escaping @MainActor () -> Void) {
        Self.coreInkQueue.async {
            ProInkStore.flushPendingWrites()
            Task { @MainActor in work() }
        }
    }

    /// 進背景時讓寫入佇列做完：向系統要背景時間，佇列空了就交還。主執行緒不等。
    func finishCoreInkInBackground() {
        #if os(iOS)
        final class TaskBox: @unchecked Sendable { var id = UIBackgroundTaskIdentifier.invalid }
        let box = TaskBox()
        func end() {
            guard box.id != .invalid else { return }
            UIApplication.shared.endBackgroundTask(box.id)
            box.id = .invalid
        }
        box.id = UIApplication.shared.beginBackgroundTask(withName: "kairumo.core-ink") { end() }
        Self.coreInkQueue.async {
            // 專業筆畫的存檔也在背景排隊（見 `ProInkStore.saveDeferred`）：一併等它寫完。
            ProInkStore.flushPendingWrites()
            Task { @MainActor in end() }
        }
        #endif
    }

    /// 把待寫的筆跡存起來，並把「新增的筆畫」追加進核心套件。
    ///
    /// 套件寫入與 `.drawing` 序列化／落盤都在背景序列佇列執行。它們要開檔、重播、序列化並寫好幾個檔，
    /// 在檔案系統慢的裝置上（例如文件庫放在 iCloud 資料夾的 iPad）一次可以卡主執行緒十幾秒 —— 使用者看到的是換畫筆之後
    /// 整條工具列點不動。卡頓記錄的堆疊樣本與存檔標記就是停在這一步。
    ///
    /// 基準先**樂觀地**設成這一版：後面再來的存檔是跟這一版比。背景佇列是序列的，所以第一個工作
    /// （從套件讀基準）一定先於第二個。寫入失敗的在主執行緒補回待寫名單、把基準清掉，下一輪從套件重算。
    func flushPendingCoreInk() {
        MainThreadStallMonitor.shared.breadcrumb("flushPendingCoreInk(\(notebook.id.prefix(8)))")
        coreInkWork?.cancel()
        coreInkWork = nil
        coreInkFirstPendingAt = nil
        let rawJobs = activeInkStore.pendingCoreFlushJobs(notebook: notebook)
        activeInkStore.clearAllPendingCoreFlush()
        guard !rawJobs.isEmpty else { return }

        var jobs: [CoreInkFlush.Job] = []
        for item in rawJobs {
            MainThreadStallMonitor.shared.breadcrumb("flush p\(item.pageIndex) saveDrawing (\(item.drawing.strokes.count) strokes)")
            let drawingURL = store.drawingsDirectory.appending(path: "\(notebook.id)_p\(item.pageIndex).drawing")
            // 僅先更新記憶體快取，實際序列化與磁碟寫入統一交由背景 coreInkQueue 的 CoreInkFlush.apply 執行，
            // 避免切換模式或落筆存檔時在主執行緒上同步阻塞。
            NotebookStore.primeDrawingCache(item.drawing, for: drawingURL)
            continuousCanvases.setCachedDrawing(item.drawing, forPage: item.pageIndex)
            jobs.append(CoreInkFlush.Job(
                page: item.pageIndex, drawing: item.drawing, drawingFileURL: drawingURL,
                cachedBaseline: item.cachedBaseline))
            activeInkStore.setCoreBaseline(item.drawing, for: item.pageIndex, pageId: item.pageId)
            inkDiskBaselines[item.pageIndex] = item.drawing
        }

        let document = notebook
        let package = corePackageURL()
        let baselineDirectory = store.syncBaselineDirectory
        let deviceId = NotebookMigration.deviceId
        nonisolated(unsafe) let jobsCopy = jobs
        Self.coreInkQueue.async {
            let failed = CoreInkFlush.apply(
                jobsCopy, document: document, package: package,
                baselineDirectory: baselineDirectory, deviceId: deviceId)
            nonisolated(unsafe) let failedCopy = failed
            DispatchQueue.main.async {
                // 保留下一輪再試；不要因為核心套件暫時寫不進去而丟掉 Apple 端的即時 `.drawing` 自動存檔。
                for item in failedCopy {
                    let pid = (document.pageIds != nil && item.page < (document.pageIds?.count ?? 0)) ? document.pageIds?[item.page] : nil
                    activeInkStore.markPendingCoreFlush(for: item.page, pageId: pid)
                    activeInkStore.clearCoreBaseline(for: item.page, pageId: pid)
                }
                // 增量寫進套件**之後**才通知焦點通道 —— 先通知的話，它可能推到還沒寫完的檔案。
                FocusSyncController.shared.noteLocalEdit()
            }
        }
    }

    func saveCurrentPageDrawing() {
        guard inkFrozenNotebookId != notebook.id else { return }
        // 明確存檔就把待辦的去抖動取消掉 —— 留著的話 1.2 秒後會再寫一次
        // 一模一樣的內容。
        inkTouchWork?.cancel()
        inkTouchWork = nil
        if pageDisplayMode == .continuous {
            let hadPendingInk = activeInkStore.hasPendingCoreFlush
            flushPendingCoreInk()
            // 沒有待寫的墨跡、文件也跟 store 裡一樣，就不要「碰」這本筆記。
            // 每次碰都會把修改時間往前推並通知同步「本機有編輯」，於是只是切換模式、
            // 點縮圖跳頁，同步就匯出重建一次套件、下載、再觸發編輯器重載 ——
            // 同步日誌裡那串首尾相接、每一輪都「匯出 1 本、下載 4」的迴圈就是這樣來的。
            if !hadPendingInk && !proInkDirty && store.notebookMatchesStored(notebook) { return }
            let hadInkChange = hadPendingInk || proInkDirty
            proInkDirty = false
            notebook.lastModifiedDate = Date()
            commitNotebook()
            if hadInkChange {
                thumbnailRevision += 1
            }
            return
        }
        // 模式切換會立即觸發 SwiftUI 更新；`@Binding` 的最後一次回寫有可能還
        // 排在同一個 run loop 後面。此時若拿 `currentDrawing` 存檔並回灌 UI，
        // 會把畫布上剛完成的多筆筆跡換成較舊的快照，看起來像切到打字模式後
        // 大部分筆跡消失。可見的 PKCanvasView 才是切換瞬間的權威快照。
        // 但只在它顯示的就是這一頁時：剛換頁那一瞬間畫布還是上一頁，拿它存會把上一頁的字存進這一頁。
        if canvasShowsCurrentPage, let liveDrawing = canvasView?.drawing, liveDrawing != currentDrawing {
            currentDrawing = liveDrawing
        }
        // 筆跡沒變就不重寫：模式切換、點物件前後都會呼叫這裡，而序列化＋寫檔＋推進核心是整頁的成本。
        let pid = (notebook.pageIds != nil && currentPageIndex < (notebook.pageIds?.count ?? 0)) ? notebook.pageIds?[currentPageIndex] : nil
        let unchanged = activeInkStore.isUnchanged(for: currentPageIndex, pageId: pid, drawing: currentDrawing)
        if !unchanged {
            activeInkStore.updateDrawing(currentDrawing, for: currentPageIndex, pageId: pid)
            // 透過 activeInkStore + flushPendingCoreInk 先更新記憶體快取並排入 coreInkQueue 背景寫檔，
            // 不在主執行緒重複執行同步 store.saveDrawing，消除切換「手繪／打字」模式時的卡頓。
            activeInkStore.markPendingCoreFlush(for: currentPageIndex, pageId: pid)
            flushPendingCoreInk()
        }
        // 同上：筆跡沒變、文件也與 store 一致就不碰。
        if unchanged && !proInkDirty && store.notebookMatchesStored(notebook) { return }
        let hadInkChange = !unchanged || proInkDirty
        proInkDirty = false
        notebook.lastModifiedDate = Date()
        commitNotebook()
        if hadInkChange {
            thumbnailRevision += 1
        }
    }

    /// 內容寫到頁尾時，確保後面有一頁可以接下去。
    ///
    /// 只在目前是最後一頁時才新增 —— 否則在中間的頁面寫到底，會憑空多出
    /// 一堆空白頁。
    // orphan-ok: 書寫到頁尾不自動長出空白頁，保留定義相容
    func ensureNextPageExists() {
        // 使用者反映書寫到頁尾不應自動長出空白頁；新增頁面由使用者於工具列或側欄明確點擊「+」新增。
    }

    /// 套索以畫布上**看得到的那一份**為準。`currentDrawing` 是經 delegate 回寫的副本，
    /// 剛落下的筆畫、別的路徑換過的筆跡可能還沒寫回來；拿舊副本算出的選取索引
    /// 對不到畫面上的筆畫 —— 有的拖得動、有的拖不動。
    func syncDrawingFromCanvas() {
        let targetCanvas = (pageDisplayMode == .continuous ? continuousCanvases[currentPageIndex] : nil)
            ?? continuousCanvases.activeCanvas
            ?? canvasView
        // 連續模式剛換焦點頁時 `canvasView` 可能還是上一頁的畫布（非同步才換過來），不能拿它當這一頁。
        if let coordinator = targetCanvas?.delegate as? CanvasRepresentable.Coordinator,
           let page = coordinator.parent.proInk?.pageIndex, page != currentPageIndex {
            return
        }
        if let live = targetCanvas?.drawing, live != currentDrawing {
            currentDrawing = live
        }
    }

    /// 把套索改過的筆跡換上目前的畫布（不經 delegate，見 `showEditedDrawing`）。
    func showLassoEdit(_ newDrawing: PKDrawing) {
        updateCanvasDrawing(forPage: currentPageIndex, drawing: newDrawing)
    }

    /// 更新特定頁面的畫布視圖筆跡（相容 AdaptiveCanvasView 與標準 PKCanvasView）
    func updateCanvasDrawing(forPage page: Int, drawing: PKDrawing) {
        if page == currentPageIndex {
            currentDrawing = drawing
        }
        continuousCanvases.setCachedDrawing(drawing, forPage: page)
        let targetCanvas = (pageDisplayMode == .continuous ? continuousCanvases[page] : nil)
            ?? (page == currentPageIndex ? (continuousCanvases.activeCanvas ?? canvasView) : nil)
        if let adaptive = targetCanvas as? AdaptiveCanvasView {
            adaptive.showEditedDrawing(drawing)
        } else {
            targetCanvas?.drawing = drawing
        }
    }

    /// 綁定套索與當前頁面之專業筆畫層（`ProInkLayerView`）及畫布插入物件（貼紙、形狀、圖片、文字方塊等），
    /// 使套索圈選與拖曳能同時選取並移動 PencilKit 筆畫、專業筆畫與未鎖定的頁面物件。
    func configureLassoCallbacks(forPage page: Int) {
        let registry = continuousCanvases
        let isContinuous = (pageDisplayMode == .continuous)
        lasso.proHost = {
            let target = (isContinuous ? registry[page] : nil) ?? registry.activeCanvas ?? canvasView
            return (target as? AdaptiveCanvasView)?.proLayer
        }
        lasso.objectCandidates = {
            marqueeCandidates(forPage: page).map { (id: $0.id, frame: $0.frame) }
        }
        lasso.onMoveObjects = { ids, delta in
            guard !ids.isEmpty, delta != .zero else { return }
            for id in ids {
                if let frame = frameOfObject(id: id) {
                    moveObject(id: id, to: CGPoint(x: frame.minX + delta.width, y: frame.minY + delta.height))
                }
            }
            if isContinuous {
                continuousObjectGeneration += 1
            }
        }
        lasso.onCommitMoveObjects = { ids in
            guard !ids.isEmpty else { return }
            commitNotebook()
            if isContinuous {
                continuousObjectGeneration += 1
            }
            refreshAllThumbnails()
            thumbnailRevision += 1
        }
        lasso.onDeleteObjects = { ids in
            guard !ids.isEmpty else { return }
            deleteObjects(ids: ids)
            if isContinuous {
                continuousObjectGeneration += 1
            }
            refreshAllThumbnails()
            thumbnailRevision += 1
        }
        lasso.onCopyObjects = { ids in
            guard !ids.isEmpty else { return }
            objectClipboard = ids.compactMap(clipboardObject(forId:))
            isPlacingPasteObject = false
        }
        lasso.onCutObjects = { ids in
            guard !ids.isEmpty else { return }
            objectClipboard = ids.compactMap(clipboardObject(forId:))
            isPlacingPasteObject = false
            deleteObjects(ids: ids)
            if isContinuous {
                continuousObjectGeneration += 1
            }
            refreshAllThumbnails()
            thumbnailRevision += 1
        }
        lasso.onDuplicateObjects = { ids in
            let copies = ids.compactMap(clipboardObject(forId:))
            guard !copies.isEmpty else { return [] }
            paste(copies, onPage: page, at: nil)
            if isContinuous {
                continuousObjectGeneration += 1
            }
            return selectedObjectIds
        }
        lasso.onPasteObjects = {
            guard !objectClipboard.isEmpty else { return [] }
            paste(objectClipboard, onPage: page, at: nil)
            if isContinuous {
                continuousObjectGeneration += 1
            }
            return selectedObjectIds
        }
    }

    /// 跨頁套索搬移之復原/重做登記
    func registerLassoCrossPageUndo(
        fromPage: Int, fromBefore: PKDrawing, fromAfter: PKDrawing,
        targetPage: Int, targetBefore: PKDrawing, targetAfter: PKDrawing
    ) {
        let pidFrom = (notebook.pageIds != nil && fromPage < (notebook.pageIds?.count ?? 0)) ? notebook.pageIds?[fromPage] : nil
        let pidTarget = (notebook.pageIds != nil && targetPage < (notebook.pageIds?.count ?? 0)) ? notebook.pageIds?[targetPage] : nil
        activeInkStore.registerCrossPageUndo(
            fromPageIndex: fromPage, fromPageId: pidFrom, fromBefore: fromBefore, fromAfter: fromAfter,
            targetPageIndex: targetPage, targetPageId: pidTarget, targetBefore: targetBefore, targetAfter: targetAfter,
            manager: historyUndoManager
        ) { fIdx, fDraw, tIdx, tDraw in
            // 當下就換上畫布，不可延到下一輪：`stepHistory` 在 `undo()` 一回來就比對畫面，
            // 沒變的話會當成失效項、再多退一步 —— 把搬移之前畫的那一筆也一起退掉，
            // 接著延後的這一段又把含那一筆的舊筆跡蓋回去，那一筆從此復原不掉。
            self.updateCanvasDrawing(forPage: fIdx, drawing: fDraw)
            self.broadcastDrawingChange(page: fIdx, drawing: fDraw)
            self.updateCanvasDrawing(forPage: tIdx, drawing: tDraw)
            self.broadcastDrawingChange(page: tIdx, drawing: tDraw)
            self.focusContinuousPage(fIdx)
            self.lasso.clear()
            self.commitNotebook()
            refreshAllThumbnails()
        }
    }

    /// 同頁套索動作（搬移、刪除、剪下、再製、貼上）之復原/重做登記
    func registerLassoSamePageUndo(page: Int, before: PKDrawing, after: PKDrawing) {
        guard before != after else { return }
        let pid = (notebook.pageIds != nil && page < (notebook.pageIds?.count ?? 0)) ? notebook.pageIds?[page] : nil
        activeInkStore.registerSamePageUndo(
            pageIndex: page, pageId: pid, before: before, after: after,
            manager: historyUndoManager
        ) { pIdx, d in
            // 同上：當下套用，`stepHistory` 才看得到這一步的效果。
            self.updateCanvasDrawing(forPage: pIdx, drawing: d)
            self.broadcastDrawingChange(page: pIdx, drawing: d)
            self.lasso.clear()
            self.commitNotebook()
            refreshAllThumbnails()
        }
    }

    func applyLassoResult(_ newDrawing: PKDrawing) {
        let before = currentDrawing
        let page = currentPageIndex
        showLassoEdit(newDrawing)
        recordDrawingEdit(page: page, drawing: newDrawing)
        broadcastDrawingChange(page: page, drawing: newDrawing)
        saveCurrentPageDrawing()
        registerLassoSamePageUndo(page: page, before: before, after: newDrawing)
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }

    func deleteSelectedStrokes() {
        syncDrawingFromCanvas()
        guard lasso.hasSelection else {
            showCanvasNotice(localizationManager.localized("lasso_active_hint"))
            return
        }
        guard let updated = lasso.deleteSelected(from: currentDrawing) else { return }
        applyLassoResult(updated)
    }

    func cutSelectedStrokes() {
        syncDrawingFromCanvas()
        guard lasso.hasSelection else {
            showCanvasNotice(localizationManager.localized("lasso_active_hint"))
            return
        }
        guard let updated = lasso.cutSelected(from: currentDrawing) else { return }
        applyLassoResult(updated)
    }

    // MARK: - 框選的筆跡（插入 › 框選）
    //
    // 框選原本只選物件；筆跡（套索才選得到）在打字模式下完全碰不到 —— 工具列顯示「已選 3 個」，
    // 卻只有物件被搬走、筆跡留在原地。這裡把筆跡併進框選：選取與動作都走套索既有的端口
    // （`LassoSelection` ＋ `applyLassoResult`），筆畫變動當下寫成 InkLog 事件（I2）、刪除寫墓碑（I3），
    // 不另開一條寫入路徑。

    /// 框選目前選到的總數（物件＋筆跡）。
    var marqueeSelectionCount: Int { selectedObjectIds.count + lasso.strokeSelectionCount }

    func marqueeSelectStrokes(in rect: CGRect, additive: Bool) {
        syncDrawingFromCanvas()
        lasso.selectStrokes(in: rect, drawing: currentDrawing, additive: additive)
    }

    func marqueeSelectAll() {
        selectedObjectIds = Set(marqueeCandidates.map(\.id))
        syncDrawingFromCanvas()
        lasso.selectAllStrokes(in: currentDrawing)
    }

    func marqueeDeselectAll() {
        selectedObjectIds = []
        lasso.clear()
    }

    /// 整組拖曳中：筆跡**即時**跟著手指走（與套索拖曳一樣只更新畫面，不寫事件）；
    /// 放手時 `marqueeMoveSelection` 才寫一次 InkLog 事件與一個復原步驟。
    func marqueeDragInk(to total: CGSize) {
        guard lasso.strokeSelectionCount > 0 else { return }
        if marqueeInkDragBase == nil {
            syncDrawingFromCanvas()
            marqueeInkDragBase = currentDrawing
            marqueeInkApplied = .zero
        }
        let step = CGSize(width: total.width - marqueeInkApplied.width,
                          height: total.height - marqueeInkApplied.height)
        guard step != .zero else { return }
        if let updated = lasso.moveSelected(in: currentDrawing, by: step) {
            showLassoEdit(updated)
        }
        marqueeInkApplied = total
    }

    /// 整組拖曳放手：物件與筆跡一起位移。
    func marqueeMoveSelection(by delta: CGSize) {
        moveSelection(by: delta)
        if let before = marqueeInkDragBase {
            // 拖曳中已即時搬好畫面；這裡把「拖曳前 → 現在」寫成一次編輯（I2）、一個復原步驟。
            marqueeInkDragBase = nil
            marqueeInkApplied = .zero
            lasso.proHost()?.endMove()
            let page = currentPageIndex
            recordDrawingEdit(page: page, drawing: currentDrawing)
            broadcastDrawingChange(page: page, drawing: currentDrawing)
            saveCurrentPageDrawing()
            if currentDrawing != before {
                registerLassoSamePageUndo(page: page, before: before, after: currentDrawing)
            }
            return
        }
        guard lasso.strokeSelectionCount > 0, delta != .zero else { return }
        syncDrawingFromCanvas()
        if let updated = lasso.moveStrokesForMarquee(in: currentDrawing, by: delta) {
            applyLassoResult(updated)
        }
    }

    func marqueeCopy() {
        if selectedObjectIds.isEmpty {
            // 只複製了筆跡：上一次留下的物件剪貼簿不能跟著貼出來。
            objectClipboard = []
        } else {
            copySelection()
        }
        syncDrawingFromCanvas()
        // 沒選筆跡時這一步會把筆跡剪貼簿清空 —— 同理，只複製物件就不要貼出舊筆跡。
        lasso.copySelected(from: currentDrawing)
        if selectedObjectIds.isEmpty && lasso.strokeSelectionCount > 0 {
            showCanvasNotice(localizationManager.localized("copy_selected_hint"))
        }
    }

    func marqueeCut() {
        if selectedObjectIds.isEmpty { objectClipboard = [] } else { cutSelection() }
        syncDrawingFromCanvas()
        if lasso.strokeSelectionCount > 0, let updated = lasso.cutSelected(from: currentDrawing) {
            applyLassoResult(updated)
        } else {
            lasso.copySelected(from: currentDrawing)   // 清掉舊的筆跡剪貼簿
        }
    }

    var marqueeCanPaste: Bool {
        !objectClipboard.isEmpty || lasso.canPaste || getClipboardImage() != nil
    }

    func marqueePaste() {
        let strokesOnly = objectClipboard.isEmpty && lasso.canPaste
        // 只有筆跡時不走 `pasteClipboard()`：它在物件剪貼簿為空時會改貼系統剪貼簿的圖片。
        if !strokesOnly { pasteClipboard() }
        if lasso.canPaste {
            syncDrawingFromCanvas()
            if let updated = lasso.paste(into: currentDrawing) { applyLassoResult(updated) }
        }
    }

    /// 放置模式下有東西可放（物件，或框選開始的放置帶著的筆跡）。
    var hasPlaceableClipboard: Bool {
        !objectClipboard.isEmpty || (placingIncludesInk && lasso.canPaste)
    }

    /// 框選工具列的「點選位置貼上」：物件與筆跡都在剪貼簿時一起放。
    func beginMarqueePlacement() {
        placingIncludesInk = lasso.canPaste
        isPlacingPasteObject = hasPlaceableClipboard
    }

    /// 放置模式下點了某頁某處：物件與（框選帶來的）筆跡以**整組**的聯集外框中心對齊點下去的位置，
    /// 彼此的相對位置不變。筆跡走套索的貼上端口（當下寫 InkLog 事件，I2）。
    func placeClipboard(at target: CGPoint, onPage page: Int) {
        let objectFrames = objectClipboard.map(\.frame)
        var union: CGRect? = objectFrames.first.map { first in objectFrames.dropFirst().reduce(first) { $0.union($1) } }
        let objectUnion = union
        let ink = placingIncludesInk && lasso.canPaste ? lasso.clipboardBounds : nil
        if let ink { union = union.map { $0.union(ink) } ?? ink }
        defer {
            isPlacingPasteObject = false
            placingIncludesInk = false
        }
        guard let union else { return }
        let delta = CGSize(width: target.x - union.midX, height: target.y - union.midY)
        if let objectUnion {
            paste(objectClipboard, onPage: page,
                  at: CGPoint(x: objectUnion.midX + delta.width, y: objectUnion.midY + delta.height))
        }
        if ink != nil {
            syncDrawingFromCanvas()
            if let updated = lasso.paste(into: currentDrawing, offset: delta) { applyLassoResult(updated) }
        }
    }

    func marqueeDuplicate() {
        if !selectedObjectIds.isEmpty { duplicateSelection() }
        guard lasso.strokeSelectionCount > 0 else { return }
        syncDrawingFromCanvas()
        if let updated = lasso.duplicateSelected(in: currentDrawing) { applyLassoResult(updated) }
    }

    func marqueeDelete() {
        if !selectedObjectIds.isEmpty { deleteSelection() }
        guard lasso.strokeSelectionCount > 0 else { return }
        syncDrawingFromCanvas()
        if let updated = lasso.deleteSelected(from: currentDrawing) { applyLassoResult(updated) }
    }

    // MARK: - 🌟 次世代專業筆刷與手寫轉換 (CSP 防抖、對稱尺規、套索 OCR 轉文字)
    func recognizeHandwritingToTextBox() {
        // 與刪除／剪下一樣先以畫布上看得到的那一份為準：選取索引是對著它算的。
        syncDrawingFromCanvas()
        let fullDrawing = currentDrawing
        let hasSelection = lasso.hasSelection
        let pkStrokes = hasSelection ? lasso.extractSelectedStrokes(from: fullDrawing) : fullDrawing.strokes
        // 專業筆刷（炭筆、蠟筆、書法筆…）寫的字不在 PKDrawing 裡；轉成 PencilKit 筆畫一起送辨識。
        let proStrokes = hasSelection ? lasso.extractSelectedProStrokes() : []
        let selectedStrokes = pkStrokes + proStrokes.compactMap(Self.recognitionStroke(from:))
        guard !selectedStrokes.isEmpty else {
            showCanvasNotice(localizationManager.localized("lasso_recognize_select_first"))
            return
        }
        
        // 計算筆跡包圍盒與平均色彩（原地轉化：沿用位置、寬度、筆色）
        var strokeBounds: CGRect = .null
        var strokeColorHex: String = "#000000"
        for stroke in pkStrokes {
            strokeBounds = strokeBounds.union(stroke.renderBounds)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            if stroke.ink.color.getRed(&r, green: &g, blue: &b, alpha: &a) {
                strokeColorHex = String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
            }
        }
        for stroke in proStrokes {
            strokeBounds = strokeBounds.union(stroke.bounds)
            let c = stroke.colorRGBA
            if c.count >= 3 {
                strokeColorHex = String(format: "#%02X%02X%02X", Int(c[0]), Int(c[1]), Int(c[2]))
            }
        }
        if strokeBounds.isNull || !strokeBounds.width.isFinite || !strokeBounds.height.isFinite {
            strokeBounds = CGRect(x: 160, y: 200, width: 340, height: 140)
        }
        
        let language = localizationManager.currentLanguage.rawValue
        showCanvasNotice(localizationManager.localized("recognizing"))

        Task { @MainActor in
            switch await HandwritingRecognizer.recognize(strokes: selectedStrokes, languageTag: language) {
            case .success(let recognizedText):
                let trimmed = recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    showCanvasNotice(localizationManager.localized("lasso_recognize_none"))
                    return
                }
                
                // 原地取代：產生對準原筆劃位置之 NoteTextAttachment
                let pad: CGFloat = 8
                let draft = NoteTextAttachment(
                    id: UUID().uuidString,
                    pageIndex: currentPageIndex,
                    text: trimmed,
                    fontSize: max(16, min(32, strokeBounds.height * 0.7)),
                    textColorHex: strokeColorHex,
                    backgroundColorHex: "#FFFFFF",
                    hasBorder: false,
                    x: max(PageGeometry.printableInset, strokeBounds.minX - pad),
                    y: max(PageGeometry.printableInset, strokeBounds.minY - pad),
                    width: max(120, strokeBounds.width + pad * 2),
                    height: max(44, strokeBounds.height + pad * 2)
                )
                
                if notebook.textAttachments == nil { notebook.textAttachments = [] }
                notebook.textAttachments?.append(draft)
                
                // 清除選中的筆劃（若有套索選取則只刪被選筆劃，否則清空整頁）
                // 辨識是非同步的：等待期間選取可能已被清掉，這時只保留原筆跡，絕不能退回「清空整頁」。
                if hasSelection {
                    if let updated = lasso.deleteSelected(from: currentDrawing) {
                        applyLassoResult(updated)
                    }
                } else {
                    currentDrawing = PKDrawing()
                    canvasView?.drawing = PKDrawing()
                    saveCurrentPageDrawing()
                }
                
                transitionToMode(.type)
                inlineEditingTextId = draft.id
                editingTextId = nil
                commitNotebook()
                refreshAllThumbnails()
                showCanvasNotice(localizationManager.localized("lasso_recognize_done"))
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                #endif
            case .failure(let failure):
                // 說出真正的原因（語言不支援、系統沒有辨識能力…）—— 「辨識失敗」幫不了使用者。
                let detail: String
                switch failure {
                case .unsupported(let d), .noModel(let d), .recognitionFailed(let d): detail = d
                }
                showCanvasNotice(localizationManager.localized("err_hwr_failed")
                    .replacingOccurrences(of: "%@", with: detail))
            }
        }
    }

    /// 專業筆畫只取路徑給辨識用（辨識只看形狀，不看筆刷質感）。少於兩點的不算一筆。
    private static func recognitionStroke(from pro: ProStroke) -> PKStroke? {
        guard pro.points.count >= 2 else { return nil }
        let width = CGFloat(max(1, pro.baseWidth))
        let points = pro.points.map { p in
            PKStrokePoint(
                location: CGPoint(x: CGFloat(p.x), y: CGFloat(p.y)),
                timeOffset: 0,
                size: CGSize(width: width, height: width),
                opacity: 1,
                force: CGFloat(max(0.1, p.pressure)),
                azimuth: 0,
                altitude: .pi / 2
            )
        }
        return PKStroke(
            ink: PKInk(.pen, color: .black),
            path: PKStrokePath(controlPoints: points, creationDate: Date()))
    }


}
