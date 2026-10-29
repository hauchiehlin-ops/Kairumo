//
//  EditorInteractiveTemplates.swift
//  Kairumo
//
//  特殊樣板智慧互動引導線（核取方塊 Checkbox、選項狀態、康乃爾筆記與引導格線互動）
//

import SwiftUI
import PencilKit

// MARK: - 特殊樣板與智慧引導線擴充

extension NotebookEditorView {
    // MARK: - 特殊樣板智慧互動引導線（核取方塊 Checkbox、選項狀態與進度管控）

    struct GuideCheckboxItem: Identifiable {
        let id: String
        let key: String
        let guide: FfiGuide
        let page: Int
    }

    func interactiveGuideCheckboxes(forPage page: Int) -> [GuideCheckboxItem] {
        let paper = notebook.paperId(forPage: page)
        let guides = pageGuides(
            paperId: paper,
            width: Float(PageGeometry.width),
            height: Float(PageGeometry.height)
        )
        return guides.filter { $0.kind == .checkbox }.map { g in
            let gx = CGFloat(g.x), gy = CGFloat(g.y)
            let key = "\(page)_\(Int(round(gx)))_\(Int(round(gy)))"
            return GuideCheckboxItem(id: key, key: key, guide: g, page: page)
        }
    }

    func hitTestGuideCheckbox(at location: CGPoint, page: Int) -> (guide: FfiGuide, key: String)? {
        let items = interactiveGuideCheckboxes(forPage: page)
        for item in items {
            let gx = CGFloat(item.guide.x), gy = CGFloat(item.guide.y)
            let gw = CGFloat(item.guide.w), gh = CGFloat(item.guide.h)
            // 擴展點擊範圍（約 34x34pt），手指與觸控筆皆能精準觸發
            let hitRect = CGRect(x: gx, y: gy, width: gw, height: gh).insetBy(dx: -12, dy: -10)
            if hitRect.contains(location) {
                return (item.guide, item.key)
            }
        }
        return nil
    }

    func toggleGuideCheckbox(key: String) {
        if notebook.checkedGuideItems == nil {
            notebook.checkedGuideItems = [:]
        }
        let current = notebook.checkedGuideItems?[key] ?? false
        notebook.checkedGuideItems?[key] = !current
        commitNotebook()
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        #endif
        PageThumbnailRenderer.invalidateAll()
    }

    func toggleRowStrikethrough(y: CGFloat, page: Int) {
        guard let texts = notebook.textAttachments, !texts.isEmpty else { return }
        recordTextUndoState()
        var updated = texts
        for i in 0 ..< updated.count where updated[i].pageIndex == page && abs(updated[i].y - y) < 30 {
            updated[i].isStrikethrough.toggle()
        }
        notebook.textAttachments = updated
        commitNotebook()
        PageThumbnailRenderer.invalidateAll()
    }

    func clearRowText(y: CGFloat, page: Int) {
        guard let texts = notebook.textAttachments, !texts.isEmpty else { return }
        recordTextUndoState()
        notebook.textAttachments?.removeAll { $0.pageIndex == page && abs($0.y - y) < 30 }
        commitNotebook()
        PageThumbnailRenderer.invalidateAll()
    }

    func resetPageCheckboxes(page: Int) {
        guard var checked = notebook.checkedGuideItems, !checked.isEmpty else { return }
        let prefix = "\(page)_"
        for key in checked.keys where key.hasPrefix(prefix) {
            checked[key] = false
        }
        notebook.checkedGuideItems = checked
        commitNotebook()
        PageThumbnailRenderer.invalidateAll()
    }

    /// 🌟 方案 A+B：手指或游標在畫布上的單擊事件
    func handleCanvasDirectTap(at location: CGPoint, page: Int? = nil) {
        if Date().timeIntervalSince(lastPastePlacementAt) < 0.35 {
            removeTapDotStroke(near: location)
            return
        }
        endTextFormatSession()
        let targetPage = page ?? currentPageIndex
        switchToPage(targetPage)

        if isPlacingPasteObject && !objectClipboard.isEmpty {
            lastPastePlacementAt = Date()
            removeTapDotStroke(near: location)
            paste(objectClipboard, onPage: targetPage, at: location)
            isPlacingPasteObject = false
            return
        }

        // 🌟 優先檢查是否點擊在特殊樣板引導線互動元件上（例如核取方塊 Checkbox）
        if let (_, key) = hitTestGuideCheckbox(at: location, page: targetPage) {
            removeTapDotStroke(near: location)
            toggleGuideCheckbox(key: key)
            return
        }

        if editorMode == .type {
            handleCanvasTapInTypeMode(at: location, page: targetPage)
        } else {
            // 手寫模式下手指點到鎖定的物件（或它角落的鎖頭）：手寫模式下物件層不吃觸控、
            // 解鎖鈕按不到，所以切到打字模式再給解鎖鈕（與放置貼紙同一個做法）。
            // 切到打字模式之後物件本身也能點選、編輯（鎖定只鎖位置）。
            if let lockedId = lockedObjectHit(at: location, page: targetPage) {
                removeTapDotStroke(near: location)
                transitionToMode(.type)
                lockPromptId = lockedId
                return
            }

            // 手寫模式下單擊：優先檢查是否點擊在既有文字方塊範圍內
            if let existing = notebook.textAttachments?.first(where: { item in
                item.pageIndex == targetPage &&
                CGRect(x: item.x, y: item.y, width: item.width, height: item.height).insetBy(dx: -12, dy: -12).contains(location)
            }) {
                // 單擊與 PencilKit 的繪圖手勢同時辨識（見 `Coordinator.gestureRecognizer`），
                // 手指輕點會被畫成一個小點。這一下是「點文字方塊」，不是落筆 ——
                // 把那個點拿掉，否則每次點方塊紙上都多一顆墨點。
                removeTapDotStroke(near: location)
                withAnimation(.easeInOut(duration: 0.15)) {
                    // 全自動意圖感知：手指點擊文字方塊，立即進入行內聚焦編輯並展開 Word 級文字工具列
                    inlineEditingTextId = existing.id
                    editingTextId = nil
                    activeSelectedObjectId = existing.id
                }
                return
            }

            // 手指輕點到文字以外的物件（圖片、形狀、表格、錄音卡…）：使用者要的是「選它」。
            // 手寫模式下手指點中物件，精準選中物件並顯示把手，同時維持手繪工具列就緒，不強迫進入打字模式。
            if let (hitId, hitKind) = findObjectAt(location: location, page: targetPage) {
                removeTapDotStroke(near: location)
                withAnimation(.easeInOut(duration: 0.15)) {
                    inlineEditingTextId = nil
                    if hitKind == "shape" {
                        selectedShapeIds = [hitId]
                        activeSelectedObjectId = nil
                    } else {
                        selectedShapeIds = []
                        activeSelectedObjectId = hitId
                    }
                    selectedConnectionId = nil
                    selectedObjectIds = [hitId]
                    collaborationManager.broadcastSelection(selectedId: hitId)
                }
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
                return
            }

            // 手寫模式下單擊畫布空白處：清空所有選取狀態
            activeSelectedObjectId = nil
            selectedShapeIds = []
            selectedConnectionId = nil
            selectedObjectIds = []
            collaborationManager.broadcastSelection(selectedId: nil)

            if let activeId = inlineEditingTextId {
                if let activeItem = notebook.textAttachments?.first(where: { $0.id == activeId }),
                   activeItem.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    notebook.textAttachments?.removeAll { $0.id == activeId }
                    commitNotebook()
                    PageThumbnailRenderer.invalidateAll()
                    watchdog.notifyEmptyTextBoxDismissedQuickly(isStylusActive: true) {
                        transitionToMode(.draw)
                    }
                }
                inlineEditingTextId = nil
            }
        }
    }

    /// 🌟 方案 A+B：手指或游標在畫布上的雙擊事件（手繪或打字模式下皆可直接建立並聚焦文字方塊）
    func handleCanvasDirectDoubleTap(at location: CGPoint, page: Int? = nil) {
        endTextFormatSession()
        let targetPage = page ?? currentPageIndex
        switchToPage(targetPage)
        if hitTestGuideCheckbox(at: location, page: targetPage) != nil { return }
        if isLocationInsideAnyObject(at: location, page: targetPage) { return }
        // 若先前有空白文字方塊先清理
        if let activeId = inlineEditingTextId,
           let activeItem = notebook.textAttachments?.first(where: { $0.id == activeId }),
           activeItem.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            notebook.textAttachments?.removeAll { $0.id == activeId }
            commitNotebook()
            if activeSelectedObjectId == activeId {
                activeSelectedObjectId = nil
            }
            PageThumbnailRenderer.invalidateAll()
        }
        let draft = insertTextBox(at: location, page: targetPage, tapToWrite: true)
        transitionToMode(.type)
        activeSelectedObjectId = nil
        inlineEditingTextId = draft.id
        editingTextId = nil
        selectedShapeIds = []
        selectedConnectionId = nil
        selectedObjectIds = []
    }

    func handleCanvasTapInTypeMode(at location: CGPoint, page: Int? = nil) {
        endTextFormatSession()
        let targetPage = page ?? currentPageIndex
        switchToPage(targetPage)

        // 0. 特殊頁面智慧引導線元件（核取方塊 Checkbox 等）點擊判定
        if let (_, key) = hitTestGuideCheckbox(at: location, page: targetPage) {
            toggleGuideCheckbox(key: key)
            return
        }
        // 0b. 點到鎖定物件**外圍**（角落的鎖頭露在物件外面）：在它上方給「解除鎖定」鈕。
        // 點在物件本身上照常往下走 —— 鎖定只鎖位置，選取、就地編輯文字都和沒鎖一樣。
        if let lockedId = lockedObjectHit(at: location, page: targetPage),
           frameOfObject(id: lockedId)?.contains(location) != true {
            lockPromptId = (lockPromptId == lockedId) ? nil : lockedId
            return
        }
        lockPromptId = nil

        // 1. 若先前有就地編輯但未打任何字的空方塊，先自動清理
        if let activeId = inlineEditingTextId,
           let activeItem = notebook.textAttachments?.first(where: { $0.id == activeId }),
           activeItem.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            notebook.textAttachments?.removeAll { $0.id == activeId }
            commitNotebook()
            inlineEditingTextId = nil
            if activeSelectedObjectId == activeId {
                activeSelectedObjectId = nil
            }
            PageThumbnailRenderer.invalidateAll()
            watchdog.notifyEmptyTextBoxDismissedQuickly(isStylusActive: true) {
                transitionToMode(.draw)
            }
        }

        // 2. 檢查是否點擊在既有文字範圍內
        if let existing = notebook.textAttachments?.first(where: { item in
            item.pageIndex == targetPage &&
            CGRect(x: item.x, y: item.y, width: item.width, height: item.height).insetBy(dx: -12, dy: -12).contains(location)
        }) {
            // 直接就地聚焦編輯既有文字，退出其他物件選取
            activeSelectedObjectId = existing.id
            inlineEditingTextId = existing.id
            editingTextId = nil
            selectedShapeIds = []
            selectedConnectionId = nil
            selectedObjectIds = []
            collaborationManager.broadcastSelection(selectedId: existing.id)
            return
        }

        // 3. 若點擊在其他畫布物件（圖片、表格、形狀、錄音卡片、3D等）上，選取該物件並展開操作把手
        //
        // 例外：底稿（見 `isLockedBackdrop`）點它是要在上面打字，不是選取那張整頁的圖。
        if let (hitId, hitKind) = findObjectAt(location: location, page: targetPage),
           !(hitKind == "image" && isLockedBackdrop(hitId, page: targetPage)) {
            inlineEditingTextId = nil
            if hitKind == "shape" {
                selectedShapeIds = [hitId]
                activeSelectedObjectId = nil
            } else {
                selectedShapeIds = []
                activeSelectedObjectId = hitId
            }
            selectedConnectionId = nil
            selectedObjectIds = [hitId]
            collaborationManager.broadcastSelection(selectedId: hitId)
            return
        }

        // 4. 點擊空白處：在打字模式下，點擊空白處即為「隨點即書」
        // 先清理所有先前的物件選取與就地編輯焦點
        activeSelectedObjectId = nil
        selectedShapeIds = []
        selectedConnectionId = nil
        selectedObjectIds = []
        inlineEditingTextId = nil
        editingTextId = nil
        collaborationManager.broadcastSelection(selectedId: nil)

        // 立即在手指點擊處啟動隨點隨打（隨點即書）
        let draft = insertTextBox(at: location, page: targetPage, tapToWrite: true)
        // 隨點即書為純文字輸入游標，不啟用物件選取態（保持 activeSelectedObjectId = nil），
        // 避免渲染出選取藍框與縮放/旋轉把手（使用戶誤以為是「新增文字方塊」按鈕產生的物件）
        activeSelectedObjectId = nil
        inlineEditingTextId = draft.id
        editingTextId = nil
    }

    /// 打字模式下 Apple Pencil 輕點：移除可能產生的微小墨點，並轉由文字模式點擊處理（即點即書或聚焦文字/物件）
    func handlePencilTapInTypeMode(at location: CGPoint, page: Int? = nil) {
        let targetPage = page ?? currentPageIndex
        switchToPage(targetPage)
        removeTapDotStroke(near: location)
        handleCanvasTapInTypeMode(at: location, page: targetPage)
    }


    /// 這一頁所有水平格線的 y（導引線與底紋都算，見 `RuledWriting.horizontalRules`）。
    func pageHorizontalRules(page: Int? = nil) -> [CGFloat] {
        let paperId = notebook.paperId(forPage: page ?? currentPageIndex)
        let guides = pageGuides(
            paperId: paperId,
            width: Float(PageGeometry.width),
            height: Float(PageGeometry.height)
        )
        let bands = pageTexture(
            paperId: paperId,
            style: NoteTemplate(paperId: paperId)?.pageStyle ?? .blank,
            width: Float(PageGeometry.width),
            height: Float(PageGeometry.height)
        )
        return RuledWriting.horizontalRules(guides: guides, bands: bands)
    }

    /// 拖曳文字方塊時的吸附：讓第一行底部坐在最近的格線上（文字貼著格線上方、格線為底，絕不穿透重疊）。
    func snapYToGuideLine(at y: CGFloat, page: Int? = nil) -> CGFloat {
        let rules = pageHorizontalRules(page: page)
        let fontSize: CGFloat = activeTextAttachment?.fontSize ?? 16
        let offset = RuledWriting.textBottomOffset(fontSize: fontSize)

        let targetBottom = y + offset
        if let nearest = rules.min(by: { abs($0 - targetBottom) < abs($1 - targetBottom) }), abs(nearest - targetBottom) < 50 {
            return max(PageGeometry.printableInset, nearest - offset)
        }
        // 沒有格線或離得遠：吸附至 20pt 步進網格。
        let step: CGFloat = 20.0
        return round(y / step) * step
    }

    /// - Parameter tapToWrite: 文字模式「隨點即書」。文字從點的地方開始；橫線紙上基準線坐在格線上，
    ///   一行一行對著格線寫；沒有框線、透明底，方塊會跟著內容長高。
    ///   `false` 是工具列「新增文字方塊」那一顆：有框線的獨立方塊。
    func insertTextBox(
        at location: CGPoint, page: Int? = nil, openStudio: Bool = false, tapToWrite: Bool = false
    ) -> NoteTextAttachment {
        let targetPage = page ?? currentPageIndex
        var targetX = location.x
        var targetY = location.y
        var tapPlacement: RuledWriting.Placement?
        // 新方塊沿用目前方塊的樣式；沒有目前方塊時，沿用使用者在工具列預先選好的樣式。
        let inheritedStyle = activeTextAttachment ?? pendingTypingStyle
        if tapToWrite {
            let baseSize: CGFloat = inheritedStyle.fontSize
            let minTop = PageGeometry.printableRect.minY
            if snapToGrid,
               let ruled = RuledWriting.placement(
                   tapY: location.y, rules: pageHorizontalRules(page: targetPage),
                   fontSize: baseSize, minTop: minTop) {
                tapPlacement = ruled
            } else {
                tapPlacement = RuledWriting.freePlacement(tapY: location.y, fontSize: baseSize, minTop: minTop)
            }
            targetY = tapPlacement?.top ?? targetY
            // 文字從點的地方開始：方塊左緣 = 點 − 內距。
            targetX = location.x - RuledWriting.padding
        } else if snapToGrid {
            let step: CGFloat = 20.0
            targetX = round(targetX / step) * step
            targetY = snapYToGuideLine(at: location.y)
        }
        let printable = PageGeometry.printableRect
        var startX = max(printable.minX, targetX)
        if tapToWrite {
            // 隨點即書：若點擊處過於靠右，留出合理輸入起點，避免文字方塊超出可視區域
            startX = min(startX, printable.maxX - 60)
        }
        let midX = PageGeometry.width / 2
        // 若在左右分欄或四象限結構的左半部，文字寬度以中線為界；否則延伸至右側可列印邊界
        let availWidth: CGFloat
        // 以中線為界只在左半邊還有像樣的寬度時才成立：點在中線左邊一點點時，
        // 界線會把方塊壓到幾十點寬，打一個英文字就折成兩行。
        if startX < midX - 30 && printable.maxX > midX && midX - startX - 12 >= 200 {
            availWidth = max(tapToWrite ? 60 : 180, midX - startX - 12)
        } else {
            availWidth = max(tapToWrite ? 60 : 180, printable.maxX - startX)
        }
        let tapHeight = RuledWriting.boxHeight(
            text: "", width: availWidth, fontSize: tapPlacement?.fontSize ?? inheritedStyle.fontSize, bold: inheritedStyle.isBold,
            lineSpacing: tapPlacement?.lineSpacing ?? 0)
        var draft = NoteTextAttachment(
            id: UUID().uuidString,
            pageIndex: targetPage,
            text: "",
            fontSize: tapPlacement?.fontSize ?? inheritedStyle.fontSize,
            isBold: inheritedStyle.isBold,
            isItalic: inheritedStyle.isItalic,
            isUnderline: inheritedStyle.isUnderline,
            isStrikethrough: inheritedStyle.isStrikethrough,
            alignmentRaw: inheritedStyle.alignmentRaw,
            textColorHex: inheritedStyle.textColorHex,
            backgroundColorHex: "clear",
            hasBorder: !tapToWrite,
            x: startX,
            y: tapToWrite
                ? max(printable.minY - RuledWriting.padding, min(targetY, printable.maxY - tapHeight))
                : max(printable.minY, min(targetY, printable.maxY - 40)),
            width: availWidth,
            height: tapToWrite ? tapHeight : 40
        )
        draft.fontFamily = inheritedStyle.fontFamily
        if let placement = tapPlacement, placement.lineSpacing > 0 {
            draft.lineSpacing = placement.lineSpacing
        }
        recordTextUndoState()
        if notebook.textAttachments == nil {
            notebook.textAttachments = []
        }
        notebook.textAttachments?.append(draft)
        var order = ObjectStacking.normalized(objects: pageStackableObjects, order: notebook.objectOrder(forPage: targetPage))
        order = ObjectStacking.bringToFront([draft.id], in: order)
        notebook.setObjectOrder(order, forPage: targetPage)

        commitNotebook()
        PageThumbnailRenderer.invalidateAll()
        if let data = try? JSONEncoder().encode(draft),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            collaborationManager.broadcastAttachmentUpsert(type: "text", itemDict: dict)
        }
        inlineEditingTextId = draft.id
        lastAddedTextId = draft.id
        if openStudio {
            editingTextId = draft.id
        } else {
            editingTextId = nil
        }
        return draft
    }

    /// 符號分類的語系鍵。與 Android 的 `categoryKey` 同一組。
    func symbolCategoryKey(_ category: FfiSymbolCategory) -> String {
        switch category {
        case .special: return "special_symbols"
        case .punctuation: return "punctuation_symbols"
        case .math: return "math_symbols"
        case .roman: return "roman_symbols"
        }
    }

    func insertQuickTextSnippet(_ text: String, onNewLine: Bool = false) {
        // 跟格式按鈕同一個目標（焦點被工具列借走時也找得到），不會插到別的方塊。
        if var target = activeTextAttachment {
            if onNewLine, !target.text.isEmpty, !target.text.hasSuffix("\n") {
                target.text.append("\n")
            }
            target.text.append(text)
            if onNewLine { target.text.append("\n") }
            applyToolbarTextChange(target)
            return
        }
        let style = pendingTypingStyle
        let newBox = NoteTextAttachment(
            pageIndex: currentPageIndex,
            text: text,
            fontSize: style.fontSize,
            isBold: style.isBold,
            isItalic: style.isItalic,
            isUnderline: style.isUnderline,
            isStrikethrough: style.isStrikethrough,
            alignmentRaw: style.alignmentRaw,
            textColorHex: style.textColorHex,
            hasBorder: true,
            x: PageGeometry.printableInset,
            y: 200,
            width: 260,
            height: 64
        )
        if notebook.textAttachments == nil {
            notebook.textAttachments = []
        }
        notebook.textAttachments?.append(newBox)
        inlineEditingTextId = newBox.id
        editingTextId = newBox.id
        commitNotebook()
        PageThumbnailRenderer.invalidateAll()
    }

    /// 將算式以可編輯的文字方塊插入畫布（使用者可隨意修改、縮放、變更字型顏色及刪除）
    func insertFormulaText(_ text: String) {
        let printable = PageGeometry.printableRect
        let availWidth: CGFloat = min(360, printable.width - 40)
        let fontSize: CGFloat = 18
        let calculatedHeight = max(52, RuledWriting.boxHeight(
            text: text,
            width: availWidth,
            fontSize: fontSize,
            bold: false,
            lineSpacing: 0
        ))
        let targetX = printable.minX + 24
        let targetY = max(printable.minY + 20, min(180, printable.maxY - calculatedHeight - 20))

        let mathBox = NoteTextAttachment(
            id: UUID().uuidString,
            pageIndex: currentPageIndex,
            text: text,
            fontSize: fontSize,
            isBold: false,
            textColorHex: "#000000",
            backgroundColorHex: "#F8F9FA",
            hasBorder: true,
            cornerRadius: 10,
            x: targetX,
            y: targetY,
            width: availWidth,
            height: calculatedHeight
        )

        if notebook.textAttachments == nil {
            notebook.textAttachments = []
        }
        notebook.textAttachments?.append(mathBox)

        var order = ObjectStacking.normalized(objects: pageStackableObjects, order: notebook.objectOrder(forPage: currentPageIndex))
        order = ObjectStacking.bringToFront([mathBox.id], in: order)
        notebook.setObjectOrder(order, forPage: currentPageIndex)

        commitNotebook()
        PageThumbnailRenderer.invalidateAll()
        if let data = try? JSONEncoder().encode(mathBox),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            collaborationManager.broadcastAttachmentUpsert(type: "text", itemDict: dict)
        }
        transitionToMode(.type)
        DispatchQueue.main.async {
            inlineEditingTextId = mathBox.id
            editingTextId = mathBox.id
        }
    }

    /// 將語音辨識/轉錄出的文字稿作為「隨點即書」自然排版文字插入在錄音卡片周遭，
    /// 無框線、無預設灰底，高度隨內容自動伸縮，並切換至打字模式進入就地編輯以供後續編修。
    func insertTranscriptText(_ text: String, for audio: NoteAudioAttachment) {
        let printable = PageGeometry.printableRect
        let startX = max(printable.minX, audio.x)
        let midX = PageGeometry.width / 2
        let availWidth: CGFloat
        if startX < midX - 30 && printable.maxX > midX {
            availWidth = max(180, midX - startX - 12)
        } else {
            availWidth = max(180, printable.maxX - startX)
        }

        let baseFontSize: CGFloat = activeTextAttachment?.fontSize ?? 16
        let calculatedHeight = RuledWriting.boxHeight(
            text: text,
            width: availWidth,
            fontSize: baseFontSize,
            bold: false,
            lineSpacing: 0
        )
        let targetY = max(printable.minY, min(audio.y + audio.height + 16, printable.maxY - calculatedHeight))
        let existingId = audio.transcriptTextId
        let existingIndex = notebook.textAttachments?.firstIndex(where: { $0.id == existingId })

        let transcriptBox: NoteTextAttachment
        if let idx = existingIndex, var existing = notebook.textAttachments?[idx] {
            existing.text = text
            existing.height = RuledWriting.boxHeight(
                text: text,
                width: existing.width,
                fontSize: existing.fontSize,
                bold: existing.isBold,
                lineSpacing: existing.lineSpacing ?? 0
            )
            notebook.textAttachments?[idx] = existing
            transcriptBox = existing
        } else {
            let newBox = NoteTextAttachment(
                id: existingId ?? UUID().uuidString,
                pageIndex: audio.pageIndex,
                text: text,
                fontSize: baseFontSize,
                isBold: false,
                textColorHex: activeTextAttachment?.textColorHex ?? "#000000",
                backgroundColorHex: "clear",
                hasBorder: false,
                x: startX,
                y: targetY,
                width: availWidth,
                height: calculatedHeight
            )
            if notebook.textAttachments == nil {
                notebook.textAttachments = []
            }
            notebook.textAttachments?.append(newBox)
            if let aIdx = notebook.audioAttachments?.firstIndex(where: { $0.id == audio.id }) {
                notebook.audioAttachments?[aIdx].transcriptTextId = newBox.id
            }
            transcriptBox = newBox
        }

        var order = ObjectStacking.normalized(objects: pageStackableObjects, order: notebook.objectOrder(forPage: audio.pageIndex))
        order = ObjectStacking.bringToFront([transcriptBox.id], in: order)
        notebook.setObjectOrder(order, forPage: audio.pageIndex)

        // 確保轉錄文字預設位於筆跡上方（前景層）
        if notebook.underInkObjectIds(forPage: audio.pageIndex).contains(transcriptBox.id) {
            notebook.moveObjects([transcriptBox.id], to: .aboveInk, forPage: audio.pageIndex)
        }

        commitNotebook()
        PageThumbnailRenderer.invalidateAll()
        if let data = try? JSONEncoder().encode(transcriptBox),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            collaborationManager.broadcastAttachmentUpsert(type: "text", itemDict: dict)
        }
        transitionToMode(.type)
        activeSelectedObjectId = transcriptBox.id
        selectedObjectIds = [transcriptBox.id]
        // 文字框先進入視圖樹，再要求就地編輯。和同一個動畫 transaction 一起
        // 設定時，FocusState 偶爾會早於 TextField 建立，鍵盤便時有時無。
        DispatchQueue.main.async {
            inlineEditingTextId = transcriptBox.id
        }
    }

    func formatTime(seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%02d:%02d", m, s)
    }


}
