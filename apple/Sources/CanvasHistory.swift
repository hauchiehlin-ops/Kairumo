//
//  CanvasHistory.swift
//  Kairumo
//
//  畫布上所有物件操作的復原／重做。
//
//  # 為什麼需要它
//
//  原本復原只認兩件事：PencilKit 的筆跡，和一份只記文字方塊的堆疊。搬一張圖、
//  刪一個表格、改一個形狀的顏色、調整圖層順序 —— 按復原都沒有反應。
//
//  # 為什麼掛在同一個 `UndoManager`，不自己維護一份時間軸
//
//  筆跡（PencilKit）與專業筆畫（`ProInk`）早就登記在畫布的 `undoManager` 上，而且有一整套
//  處理失效項的細節（見 `dropDeadUndoEntries`）。另外做一條時間軸再跟它對齊順序，
//  兩邊遲早會錯開。物件的變更登記在**同一個** manager 上，一次 `undo()` 就自然照
//  發生的先後順序退回 —— 先畫一筆、再搬一張圖、再畫一筆，復原三次就是反過來三步。
//
//  # 怎麼抓到變更
//
//  編輯器每次寫回筆記本都走 `commitNotebook()`，這裡拿這一次的物件狀態跟上一次比：
//  不同就登記「回到上一次」。連續的小變動（打字、拖滑桿）同一個物件在短時間內
//  只算一步，否則打一句話要按幾十次復原。
//

import Foundation

/// 筆記本裡「畫布物件」的那一部分。**不含筆跡**（`pagesData`）——筆跡由 PencilKit 自己復原。
struct CanvasObjectState: Equatable {
    var attachments: [NoteImageAttachment]?
    var textAttachments: [NoteTextAttachment]?
    var linkAttachments: [NoteLinkAttachment]?
    var model3DAttachments: [Note3DAttachment]?
    var commentPins: [NoteCommentPin]?
    var shapeAttachments: [NoteShapeAttachment]?
    var connectionAttachments: [NoteConnectionAttachment]?
    var tableAttachments: [NoteTableAttachment]?
    var audioAttachments: [NoteAudioAttachment]?
    var tapeAttachments: [NoteTapeAttachment]?
    var stickyAnchors: [StickyAnnotationAnchor]?
    var checkedGuideItems: [String: Bool]?
    var pagePaperIds: [String]?
    var guidePaletteId: String?
    var objectOrderByPage: [String: [String]]?
    var objectOrder: [String]?
    var underInkObjectIdsByPage: [String: [String]]?
    var lockedObjectIdsByPage: [String: [String]]?

    init(_ doc: NotebookDocument) {
        attachments = doc.attachments
        textAttachments = doc.textAttachments
        linkAttachments = doc.linkAttachments
        model3DAttachments = doc.model3DAttachments
        commentPins = doc.commentPins
        shapeAttachments = doc.shapeAttachments
        connectionAttachments = doc.connectionAttachments
        tableAttachments = doc.tableAttachments
        audioAttachments = doc.audioAttachments
        tapeAttachments = doc.tapeAttachments
        stickyAnchors = doc.stickyAnchors
        checkedGuideItems = doc.checkedGuideItems
        pagePaperIds = doc.pagePaperIds
        guidePaletteId = doc.guidePaletteId
        objectOrderByPage = doc.objectOrderByPage
        objectOrder = doc.objectOrder
        underInkObjectIdsByPage = doc.underInkObjectIdsByPage
        lockedObjectIdsByPage = doc.lockedObjectIdsByPage
    }

    func apply(to doc: inout NotebookDocument) {
        doc.attachments = attachments
        doc.textAttachments = textAttachments
        doc.linkAttachments = linkAttachments
        doc.model3DAttachments = model3DAttachments
        doc.commentPins = commentPins
        doc.shapeAttachments = shapeAttachments
        doc.connectionAttachments = connectionAttachments
        doc.tableAttachments = tableAttachments
        doc.audioAttachments = audioAttachments
        doc.tapeAttachments = tapeAttachments
        doc.stickyAnchors = stickyAnchors
        doc.checkedGuideItems = checkedGuideItems
        doc.pagePaperIds = pagePaperIds
        doc.guidePaletteId = guidePaletteId
        doc.objectOrderByPage = objectOrderByPage
        doc.objectOrder = objectOrder
        doc.underInkObjectIdsByPage = underInkObjectIdsByPage
        doc.lockedObjectIdsByPage = lockedObjectIdsByPage
    }

    /// 這一次動到了哪些物件（新增、刪除或內容改變）。用來判斷「同一個東西的連續小變動」。
    /// 物件以外的欄位（圖層順序、紙張、勾選）變了，回一個代表那個欄位的名稱。
    func changedKeys(comparedTo other: CanvasObjectState) -> Set<String> {
        var keys: Set<String> = []
        func diff<T: Identifiable & Equatable>(_ a: [T]?, _ b: [T]?) where T.ID == String {
            let left = Dictionary((a ?? []).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            let right = Dictionary((b ?? []).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            for (id, value) in left where right[id] != value { keys.insert(id) }
            for id in right.keys where left[id] == nil { keys.insert(id) }
        }
        diff(attachments, other.attachments)
        diff(textAttachments, other.textAttachments)
        diff(linkAttachments, other.linkAttachments)
        diff(model3DAttachments, other.model3DAttachments)
        diff(commentPins, other.commentPins)
        diff(shapeAttachments, other.shapeAttachments)
        diff(connectionAttachments, other.connectionAttachments)
        diff(tableAttachments, other.tableAttachments)
        diff(audioAttachments, other.audioAttachments)
        diff(tapeAttachments, other.tapeAttachments)
        diff(stickyAnchors, other.stickyAnchors)
        if checkedGuideItems != other.checkedGuideItems { keys.insert("#checkedGuideItems") }
        if pagePaperIds != other.pagePaperIds || guidePaletteId != other.guidePaletteId { keys.insert("#paper") }
        if objectOrderByPage != other.objectOrderByPage || objectOrder != other.objectOrder
            || underInkObjectIdsByPage != other.underInkObjectIdsByPage { keys.insert("#order") }
        if lockedObjectIdsByPage != other.lockedObjectIdsByPage { keys.insert("#locked") }
        return keys
    }

    /// 所有物件的 id（復原之後拿來清掉指向已不存在物件的選取狀態）。
    var allObjectIds: Set<String> {
        var ids: Set<String> = []
        (attachments ?? []).forEach { ids.insert($0.id) }
        (textAttachments ?? []).forEach { ids.insert($0.id) }
        (linkAttachments ?? []).forEach { ids.insert($0.id) }
        (model3DAttachments ?? []).forEach { ids.insert($0.id) }
        (commentPins ?? []).forEach { ids.insert($0.id) }
        (shapeAttachments ?? []).forEach { ids.insert($0.id) }
        (connectionAttachments ?? []).forEach { ids.insert($0.id) }
        (tableAttachments ?? []).forEach { ids.insert($0.id) }
        (audioAttachments ?? []).forEach { ids.insert($0.id) }
        (tapeAttachments ?? []).forEach { ids.insert($0.id) }
        return ids
    }
}

/// 物件操作的復原紀錄。每個編輯器一份；登記在畫布的 `undoManager` 上（見檔頭說明）。
final class CanvasObjectHistory {

    /// 登記項目的名稱。PencilKit 的失效項清理靠它分辨「這一項是物件，不是筆畫」。
    static let actionName = "kairumo.canvas.objects"

    /// 連續變動合併成一步的時間窗。
    static let coalescingWindow: TimeInterval = 1.5

    private var baseline: CanvasObjectState?
    private var baselinePageCount = 0
    private var lastRegistration = Date.distantPast
    private var lastChangedKeys: Set<String> = []
    private var coalescingBroken = true
    /// 正在套用復原／重做，或正在套用別台送來的變更：只更新基準，不登記。
    private var suppressDepth = 0
    /// 套用過幾次復原／重做。編輯器用它判斷「這一次 `undo()` 真的退了一步物件」。
    private(set) var appliedCount = 0

    /// 以目前的內容為基準重新開始（開啟筆記本、或內容被整份換掉時）。
    func reset(to doc: NotebookDocument) {
        baseline = CanvasObjectState(doc)
        baselinePageCount = doc.pageCount
        coalescingBroken = true
    }

    /// 下一次變更一定另起一步：使用者明確開始了一個新動作（開始編輯、按下刪除），
    /// 或是**中間插進了別的復原項**（畫了一筆）。
    ///
    /// 不能靠 `undoActionName` 判斷「堆疊頂端是不是自己的」：UIKit 每個事件都會開一個
    /// 復原群組，群組開著的時候問到的是那個空群組的名稱，永遠對不上 —— 連續打字就
    /// 一個字一步。所以由編輯器在筆跡變動時明確通知。
    func breakCoalescing() {
        coalescingBroken = true
    }

    /// 在 `body` 執行期間的變更不登記（別台送來的同步、整份重新載入）。
    func withoutRecording(_ body: () -> Void) {
        suppressDepth += 1
        body()
        suppressDepth -= 1
    }

    /// 頁面被新增、刪除、搬動：舊的物件紀錄裡的頁次已經對不上，全部作廢。
    /// 留著的話，復原一個搬圖的動作會把圖搬回已經不存在、或已經換了內容的那一頁。
    ///
    /// `removeAllActions(withTarget:)` 會留下空的復原群組（按一次復原什麼都沒發生）——
    /// 編輯器的復原會跳過沒有效果的那一步（見 `NotebookEditorView.stepHistory`）。
    func pageStructureChanged(_ doc: NotebookDocument, manager: UndoManager?) {
        manager?.removeAllActions(withTarget: self)
        reset(to: doc)
    }

    /// 編輯器寫回筆記本時呼叫：物件跟上一次不同就登記一步。
    func record(_ doc: NotebookDocument, manager: UndoManager?, restore: @escaping (CanvasObjectState) -> Void) {
        let state = CanvasObjectState(doc)
        guard let before = baseline else {
            reset(to: doc)
            return
        }
        if doc.pageCount != baselinePageCount {
            pageStructureChanged(doc, manager: manager)
            return
        }
        guard state != before else { return }
        baseline = state
        guard suppressDepth == 0, let manager, !manager.isUndoing, !manager.isRedoing else { return }

        let changed = state.changedKeys(comparedTo: before)
        let now = Date()
        let mergesIntoLast = !coalescingBroken
            && changed == lastChangedKeys
            && now.timeIntervalSince(lastRegistration) < Self.coalescingWindow
            && manager.canUndo
        if !mergesIntoLast {
            register(back: before, manager: manager, restore: restore)
        }
        lastRegistration = now
        lastChangedKeys = changed
        coalescingBroken = false
    }

    private func register(back target: CanvasObjectState, manager: UndoManager, restore: @escaping (CanvasObjectState) -> Void) {
        manager.registerUndo(withTarget: self) { history in
            history.perform(back: target, manager: manager, restore: restore)
        }
        manager.setActionName(Self.actionName)
    }

    /// 復原（或重做）：套上目標狀態，並登記反方向的一步。
    private func perform(back target: CanvasObjectState, manager: UndoManager, restore: @escaping (CanvasObjectState) -> Void) {
        guard let current = baseline else { return }
        // 基準先設、再套用：套用時若有欄位被保留（協同中別人之後改過的，見 CollabObjectSync），
        // `restore` 會以實際結果重設基準 —— 順序反過來的話會被這裡蓋回去，下一次比對就多出一步。
        baseline = target
        suppressDepth += 1
        restore(target)
        suppressDepth -= 1
        appliedCount += 1
        coalescingBroken = true
        register(back: current, manager: manager, restore: restore)
    }
}
