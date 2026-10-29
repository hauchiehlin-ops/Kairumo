//
//  EditorTextAndAnnotations.swift
//  Kairumo
//
//  文字排版、文字方塊編輯、動態流式錨定系統 (Fluid Sticky Annotations) 與手寫筆記筆劃關聯
//

import SwiftUI
import PencilKit

// MARK: - 文字與動態流式錨定擴充

extension NotebookEditorView {
    // MARK: - 🌟 文字與手寫動態流式錨定系統 (Fluid Sticky Annotations)
    func moveAnchoredStrokes(forTextId textId: String, delta: CGSize) {
        guard let anchors = notebook.stickyAnchors, !anchors.isEmpty else { return }
        let matched = anchors.filter { $0.targetId == textId && $0.pageIndex == currentPageIndex }
        guard !matched.isEmpty else { return }

        let drawing = currentDrawing
        var strokes = drawing.strokes
        var modified = false

        for anchor in matched {
            if let indices = anchor.strokeIndices {
                for idx in indices where strokes.indices.contains(idx) {
                    var copy = strokes[idx]
                    copy.transform = copy.transform.translatedBy(x: delta.width, y: delta.height)
                    strokes[idx] = copy
                    modified = true
                }
            }
        }

        if modified {
            let newDrawing = PKDrawing(strokes: strokes)
            self.currentDrawing = newDrawing
            self.canvasView?.drawing = newDrawing
            self.saveCurrentPageDrawing()
            for i in 0..<(notebook.stickyAnchors?.count ?? 0) {
                if notebook.stickyAnchors?[i].targetId == textId {
                    notebook.stickyAnchors?[i].anchorOriginX += Float(delta.width)
                    notebook.stickyAnchors?[i].anchorOriginY += Float(delta.height)
                }
            }
            commitNotebook()
        }
    }

    func anchorSelectedStrokesToNearestText() {
        let drawing = currentDrawing
        guard !drawing.strokes.isEmpty else {
            showCanvasNotice("目前頁面沒有手寫筆劃可供錨定")
            return
        }

        let pageTexts = (notebook.textAttachments ?? []).filter { $0.pageIndex == currentPageIndex }
        guard !pageTexts.isEmpty else {
            showCanvasNotice("頁面上尚無文字方塊。請先新增文字方塊並使手寫筆劃相鄰，即可建立動態連動錨定")
            return
        }

        let candidateIndices = lasso.hasSelection ? Array(lasso.selected) : Array(drawing.strokes.indices)
        for target in pageTexts {
            let textRect = CGRect(x: target.x, y: target.y, width: target.width, height: target.height)
            var matchedIndices: [Int] = []
            for idx in candidateIndices where drawing.strokes.indices.contains(idx) {
                let stroke = drawing.strokes[idx]
                if textRect.intersects(stroke.renderBounds) {
                    matchedIndices.append(idx)
                }
            }
            if !matchedIndices.isEmpty {
                let anchor = StickyAnnotationAnchor(
                    pageIndex: currentPageIndex,
                    targetId: target.id,
                    strokeIndices: matchedIndices,
                    anchorOriginX: Float(target.x),
                    anchorOriginY: Float(target.y)
                )
                if notebook.stickyAnchors == nil { notebook.stickyAnchors = [] }
                notebook.stickyAnchors?.removeAll { $0.targetId == target.id }
                notebook.stickyAnchors?.append(anchor)
                commitNotebook()
                lasso.clear()
                showCanvasNotice("手寫筆劃已成功錨定至文字方塊！移動該文字方塊時，筆跡將隨之連動")
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                #endif
                return
            }
        }
        if let firstText = pageTexts.first {
            anchorOverlappingInkToText(textItem: firstText)
        } else {
            showCanvasNotice("未找到與所選筆劃相鄰的文字方塊；請圈選與文字方塊相重疊或相鄰的筆劃")
        }
    }

    func anchorOverlappingInkToText(textItem: NoteTextAttachment) {
        let drawing = currentDrawing
        guard !drawing.strokes.isEmpty else { return }
        let textRect = CGRect(x: textItem.x, y: textItem.y, width: textItem.width, height: textItem.height)

        var matchedIndices: [Int] = []
        for (idx, stroke) in drawing.strokes.enumerated() {
            if textRect.intersects(stroke.renderBounds) {
                matchedIndices.append(idx)
            }
        }

        guard !matchedIndices.isEmpty else {
            showCanvasNotice("未找到與所選筆劃相鄰的文字方塊；請圈選與文字方塊相重疊或相鄰的筆劃")
            return
        }
        let anchor = StickyAnnotationAnchor(
            pageIndex: currentPageIndex,
            targetId: textItem.id,
            strokeIndices: matchedIndices,
            anchorOriginX: Float(textItem.x),
            anchorOriginY: Float(textItem.y)
        )
        if notebook.stickyAnchors == nil { notebook.stickyAnchors = [] }
        notebook.stickyAnchors?.removeAll { $0.targetId == textItem.id }
        notebook.stickyAnchors?.append(anchor)
        commitNotebook()
        showCanvasNotice("手寫筆劃已成功錨定至文字方塊！移動該文字方塊時，筆跡將隨之連動")
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }

    /// 自動判定新落筆跡是否與既有文字方塊高度重疊（> 40%），若是則自動關聯錨定（工作項 F4 v1）
    func autoAnchorNewStrokesToOverlappingText(drawing: PKDrawing) {
        let pageTexts = (notebook.textAttachments ?? []).filter { $0.pageIndex == currentPageIndex }
        guard !pageTexts.isEmpty else { return }

        var updatedAnchors = notebook.stickyAnchors ?? []
        var hasChanges = false

        for textItem in pageTexts {
            let textRect = CGRect(x: textItem.x, y: textItem.y, width: textItem.width, height: textItem.height)
            var matchedIndices: [Int] = []
            
            for (idx, stroke) in drawing.strokes.enumerated() {
                let strokeBounds = stroke.renderBounds
                if textRect.intersects(strokeBounds) {
                    let intersection = textRect.intersection(strokeBounds)
                    let strokeArea = max(1.0, strokeBounds.width * strokeBounds.height)
                    let intersectArea = intersection.width * intersection.height
                    // 重疊面積或相交比例足夠視為對文字之圈註／劃線／旁註
                    if intersectArea / strokeArea > 0.3 || textRect.contains(strokeBounds) {
                        matchedIndices.append(idx)
                    }
                }
            }

            if !matchedIndices.isEmpty {
                let anchor = StickyAnnotationAnchor(
                    pageIndex: currentPageIndex,
                    targetId: textItem.id,
                    strokeIndices: matchedIndices,
                    anchorOriginX: Float(textItem.x),
                    anchorOriginY: Float(textItem.y)
                )
                updatedAnchors.removeAll { $0.targetId == textItem.id && $0.pageIndex == currentPageIndex }
                updatedAnchors.append(anchor)
                hasChanges = true
            }
        }

        if hasChanges {
            notebook.stickyAnchors = updatedAnchors
            commitNotebook()
        }
    }

    func applyStabilizer(to drawing: PKDrawing) -> PKDrawing {
        guard strokeStabilizer > 0.05, let lastStroke = drawing.strokes.last else {
            return drawing
        }
        var ffiPoints: [FfiPoint] = []
        for i in 0..<lastStroke.path.count {
            let p = lastStroke.path[i]
            ffiPoints.append(FfiPoint(x: Float(p.location.x), y: Float(p.location.y)))
        }
        let refined = sketchRefineStroke(points: ffiPoints, intensity: Float(strokeStabilizer))
        guard refined.points.count == lastStroke.path.count else {
            return drawing
        }
        var newStrokePoints: [PKStrokePoint] = []
        for i in 0..<lastStroke.path.count {
            let orig = lastStroke.path[i]
            let newLoc = CGPoint(x: CGFloat(refined.points[i].x), y: CGFloat(refined.points[i].y))
            let pt = PKStrokePoint(
                location: newLoc,
                timeOffset: orig.timeOffset,
                size: orig.size,
                opacity: orig.opacity,
                force: orig.force,
                azimuth: orig.azimuth,
                altitude: orig.altitude
            )
            newStrokePoints.append(pt)
        }
        let newPath = PKStrokePath(controlPoints: newStrokePoints, creationDate: lastStroke.path.creationDate)
        let newStroke = PKStroke(ink: lastStroke.ink, path: newPath, transform: lastStroke.transform, mask: lastStroke.mask)
        var allStrokes = Array(drawing.strokes.dropLast())
        allStrokes.append(newStroke)
        return PKDrawing(strokes: allStrokes)
    }

    func applySymmetry(to drawing: PKDrawing, axisX: CGFloat = 400) -> PKDrawing {
        guard isSymmetryActive, let lastStroke = drawing.strokes.last else {
            return drawing
        }
        var mirroredPoints: [PKStrokePoint] = []
        for i in 0..<lastStroke.path.count {
            let orig = lastStroke.path[i]
            let mirroredX = 2 * axisX - orig.location.x
            let pt = PKStrokePoint(
                location: CGPoint(x: mirroredX, y: orig.location.y),
                timeOffset: orig.timeOffset,
                size: orig.size,
                opacity: orig.opacity,
                force: orig.force,
                azimuth: -orig.azimuth,
                altitude: orig.altitude
            )
            mirroredPoints.append(pt)
        }
        let mirroredPath = PKStrokePath(controlPoints: mirroredPoints, creationDate: Date())
        let mirroredStroke = PKStroke(ink: lastStroke.ink, path: mirroredPath, transform: lastStroke.transform, mask: lastStroke.mask)
        var allStrokes = drawing.strokes
        allStrokes.append(mirroredStroke)
        return PKDrawing(strokes: allStrokes)
    }

    /// 貼上剪貼簿中的筆劃。
    func pasteStrokes() {
        syncDrawingFromCanvas()
        guard lasso.canPaste else {
            showCanvasNotice(localizationManager.localized("lasso_active_hint"))
            return
        }
        guard let updated = lasso.paste(into: currentDrawing) else { return }
        applyLassoResult(updated)
    }

    /// 就地複製選取的筆劃並稍微偏移（不經過剪貼簿）—— 這就是「再製」與「複製」的差別：
    /// 「複製」把東西放進剪貼簿等你貼上，「再製」直接在旁邊多一份。
    func duplicateSelectedStrokes() {
        syncDrawingFromCanvas()
        guard lasso.hasSelection else {
            showCanvasNotice(localizationManager.localized("lasso_active_hint"))
            return
        }
        guard let updated = lasso.duplicateSelected(in: currentDrawing) else { return }
        applyLassoResult(updated)
    }

    func saveSelectedAsSticker() {
        guard lasso.hasSelection else {
            showCanvasNotice(localizationManager.localized("lasso_active_hint"))
            return
        }
        let extractedStrokes = lasso.extractSelectedStrokes(from: currentDrawing)
        guard !extractedStrokes.isEmpty else { return }
        
        let tempDrawing = PKDrawing(strokes: extractedStrokes)
        let bounds = tempDrawing.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }
        
        // 筆畫座標正規化至正數象限（預留 16pt 邊距），防止 PKDrawing.image 負值邊界造成算繪空白或截斷
        let padding: CGFloat = 16
        let transform = CGAffineTransform(translationX: -bounds.minX + padding, y: -bounds.minY + padding)
        let normalizedStrokes = extractedStrokes.map {
            PKStroke(ink: $0.ink, path: $0.path, transform: $0.transform.concatenating(transform), mask: $0.mask)
        }
        let stickerDrawing = PKDrawing(strokes: normalizedStrokes)
        StickerManager.shared.saveSticker(stickerDrawing)
        
        lasso.clear()
        applyEditorTool(previousTool ?? lastBrushTool)
        showCanvasNotice("已儲存為貼紙！可於頂端「插入 > 貼紙 > 我的貼紙」中選用")
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }

    /// 把確認放置的貼紙變成**頁面上的物件**，不是烘進筆跡。
    ///
    /// # 為什麼不再烘成筆跡
    ///
    /// 原本確認之後貼紙被拆成一堆 `PKStroke` 混進手寫內容，於是它跟隨手寫的字
    /// 沒有任何分別：點它沒有反應、沒有把手、沒有刪除鈕，只有切到套索再精準
    /// 圈住才搬得動 —— 而使用者根本不知道要這麼做，回報的就是「確認後就無法
    /// 移動、編輯或刪除」。
    ///
    /// 現在貼紙以透明底圖片物件進頁面，跟圖片同一套：點選出把手、拖曳搬移、
    /// 縮放、旋轉、刪除、調圖層、框選、同步與匯出全部現成。放置時選的大小與
    /// 角度原樣帶過去。
    func insertStickerObject(_ placement: PendingStickerPlacement) {
        let b = placement.drawing.bounds
        guard b.width > 0, b.height > 0 else { return }
        // 與 `StickerRenderView` 同一個規則：在 (寬 × 縮放, 高 × 縮放) 的框裡等比置中。
        let boxW = max(50, placement.size.width) * max(0.2, min(5, placement.scale))
        let boxH = max(50, placement.size.height) * max(0.2, min(5, placement.scale))
        let fit = min(boxW / b.width, boxH / b.height)
        let size = CGSize(width: b.width * fit, height: b.height * fit)

        // 3 倍像素：貼紙是向量，但存成圖片後放大會糊，預留縮放的餘裕。
        let image = placement.drawing.image(from: b, scale: 3 * max(1, fit))
        guard let fileName = store.saveAttachmentImage(image) else { return }

        // 連續模式下若將貼圖放置浮層拖曳至其他頁面確認，自動換算落點頁碼與頁內座標（S-85）。
        let rawX = placement.center.x - size.width / 2
        let rawY = placement.center.y - size.height / 2
        let crossing = (pageDisplayMode == .continuous) ? pageCrossing(for: currentPageIndex) : nil
        let landed = PrintableArea.land(
            x: rawX, y: rawY, width: size.width, height: size.height, crossing: crossing)
        let finalPage = landed.page ?? currentPageIndex
        let finalX = landed.origin.x
        let finalY = landed.origin.y

        let attachment = NoteImageAttachment(
            fileName: fileName,
            pageIndex: finalPage,
            x: finalX,
            y: finalY,
            width: size.width,
            height: size.height,
            rotationDegrees: placement.rotationDegrees,
            cornerRadius: 0,
            hasShadow: false,
            hasBorder: false,
            filterStyle: .original,
            chartSpecJSON: nil
        )
        if notebook.attachments == nil { notebook.attachments = [] }
        notebook.attachments?.append(attachment)
        commitNotebook()
        if finalPage != currentPageIndex {
            finishPageCrossing(ids: [attachment.id], to: finalPage)
        }
        if var dict = (try? JSONSerialization.jsonObject(with: JSONEncoder().encode(attachment))) as? [String: Any] {
            if let imgData = image.pngData() {
                dict["image_base64"] = imgData.base64EncodedString()
            }
            collaborationManager.broadcastAttachmentUpsert(type: "image", itemDict: dict)
        }
        PageThumbnailRenderer.invalidateAll()
    }

    func copySelectedStrokes() {
        syncDrawingFromCanvas()
        guard lasso.hasSelection else {
            showCanvasNotice(localizationManager.localized("lasso_active_hint"))
            return
        }
        lasso.copySelected(from: currentDrawing)
        showCanvasNotice(localizationManager.localized("copy_selected_hint"))
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    func stopAndSaveRecording() {
        if let result = audioManager.stopRecording() {
            let fileName = result.url.lastPathComponent
            notebook.hasRecording = true
            notebook.recordingAudioPath = fileName
            commitNotebook()
            let rec = store.addRecording(
                title: NotebookStore.defaultRecordingTitle(),
                durationSeconds: AudioRecorderManager.displaySeconds(of: result.url, fallback: result.duration),
                fileName: fileName,
                linkedNotebookId: notebook.id
            )
            insertAudioAttachment(rec)
        }
    }

    /// 每一頁完整算繪成一張圖，再組成 PDF。
    ///
    /// 舊版寫死 612×792（信紙尺寸）並且只畫 `PKDrawing` —— 但畫布座標是
    /// 「視圖寬度 × 頁面高度」，通常遠大於這個框，所以只截到左上角一小塊，
    /// 匯出檔看起來就是空白；文字方塊、圖片、3D、圖釘也全都沒畫進去。
    /// 把某一頁算繪成圖（與縮圖、PNG 匯出是同一份繪圖程式碼）。
    func composedPageImage(_ index: Int, scale: CGFloat) -> UIImage {
        PageThumbnailRenderer.renderFullPage(
            notebook: notebook,
            pageIndex: index,
            drawing: drawingForPage(index),
            store: store,
            canvasWidth: max(canvasContentWidth, PageThumbnailRenderer.minPageWidth),
            scale: scale
        )
    }

    /// 匯出 PDF（也是列印走的路）。
    ///
    /// # 為什麼是點陣而不是核心的向量匯出
    ///
    /// 「所見即所得」是底線。核心的向量匯出器把每一筆畫成**等寬折線**：PencilKit 的壓感粗細、鉛筆與麥克筆的
    /// 紋理、螢光筆的疊色、專業筆刷的筆點全都不見；圖片的濾鏡與材質、物件的堆疊順序、形狀、圖表、連結卡片也不在它
    /// 的文件模型裡。結果是「畫布上是一個樣子，PDF 是另一個樣子」。
    /// 這裡每一頁用**縮圖與 PNG 匯出同一份繪圖程式碼**算繪，三者逐像素一致。
    /// 代價：PDF 裡的文字不能選取、筆畫不是可編輯的標註 —— 要向量與標註請用 `.padnote` 或「製圖輸出（SVG／DXF）」。
    func buildNotebookPdf(scale: CGFloat = 2.0) -> Data {
        saveCurrentPageDrawing()
        return buildRasterPdf(scale: scale)
    }

    /// 逐頁算繪、逐頁寫進 PDF：不先把所有頁面的點陣圖都留在記憶體裡（頁數多的筆記本會吃掉幾百 MB）。
    func buildRasterPdf(scale: CGFloat = 2.0) -> Data {
        let count = max(1, notebook.pageCount)
        let first = composedPageImage(0, scale: scale)
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: first.size))
        return renderer.pdfData { context in
            for i in 0..<count {
                // 圖的大小就是頁面大小（點），每一頁用自己的尺寸開頁（頁面高度可以不同）。
                let image = i == 0 ? first : composedPageImage(i, scale: scale)
                context.beginPage(withBounds: CGRect(origin: .zero, size: image.size), pageInfo: [:])
                image.draw(in: CGRect(origin: .zero, size: image.size))
            }
        }
    }

    func exportAsPdf() {
        self.exportPdfData = buildNotebookPdf()
        self.exportFileExtension = "pdf"
        // 先給預覽（S-100）。分享面板由預覽上的「匯出」再叫出來 ——
        // 使用者要確認的是「版面對不對」，而那件事只有看到結果才答得出來。
        self.showExportPreview = true
    }

    func printCurrentNotebook() {
        let pdfData = buildNotebookPdf()

        let printController = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.outputType = .general
        printInfo.jobName = notebook.title
        printController.printInfo = printInfo
        printController.printingItem = pdfData
        if UIDevice.current.userInterfaceIdiom == .pad {
            let targetView = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }?.rootViewController?.view
            if let view = targetView {
                let rect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
                printController.present(from: rect, in: view, animated: true, completionHandler: nil)
            } else {
                printController.present(animated: true, completionHandler: nil)
            }
        } else {
            printController.present(animated: true, completionHandler: nil)
        }
    }

    func exportAsPngImage() {
        saveCurrentPageDrawing()
        let img = composedPageImage(currentPageIndex, scale: 2.0)
        if let pngData = img.pngData() {
            self.exportPdfData = pngData
            self.exportFileExtension = "png"
            self.showExportPreview = true
        }
    }

    /// 把整本筆記打包成 `.padnote`，然後開**儲存對話框**。
    ///
    /// 與 `shareNotebookFile()` 只差在最後開哪一個面板 —— 打包那一段一模
    /// 一樣，所以共用，不要再抄一份（抄漏的那一次會是「存出來的檔案少了
    /// 圖片」，而那要等使用者在另一台裝置打開才發現）。
    func saveNotebookFile() {
        shareNotebookFile(asSaveDialog: true)
    }

    func shareNotebookFile(asSaveDialog: Bool = false) {
        saveCurrentPageDrawing()
        let tempDir = FileManager.default.temporaryDirectory.appending(path: "share_\(UUID().uuidString)")
        let pkgDir = tempDir.appending(path: "\(notebook.id).padnote")
        let zipUrl = tempDir.appending(path: "\(notebook.displayTitle()).padnote")

        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            var drawings: [PKDrawing] = []
            for p in 0..<notebook.pageCount {
                drawings.append(store.loadDrawing(notebookId: notebook.id, pageIndex: p))
            }
            var imageMap: [String: Data] = [:]
            for att in notebook.attachments ?? [] {
                let fileUrl = store.attachmentsDirectory.appending(path: att.fileName)
                if let data = try? Data(contentsOf: fileUrl) {
                    imageMap[att.fileName] = data
                }
            }
            // 專業筆刷與製圖線不在 PKDrawing 裡：原本分享出去的 `.padnote` **完全沒有它們** ——
            // 在別台打開，畫的三視圖整個不見。自己的與別台同步來的都要帶，**隱藏的圖層也要**
            // （隱藏只是這台的顯示設定，不是刪除；收到的人打開圖層面板可以打開）。
            let dir = store.drawingsDirectory
            let pro = (0..<max(notebook.pageCount, 1)).map { page in
                ProInkStore.load(in: dir, notebookId: notebook.id, page: page, foreign: true)
                    + ProInkStore.load(in: dir, notebookId: notebook.id, page: page)
            }
            try NotebookPackageBridge.export(
                document: notebook,
                drawings: drawings,
                imageData: imageMap,
                to: pkgDir,
                deviceId: 0x4150,
                proStrokes: pro
            )
            try archiveNotebook(packageDir: pkgDir.path, outFile: zipUrl.path)
            let zipData = try Data(contentsOf: zipUrl)
            self.exportPdfData = zipData
            self.exportFileExtension = "padnote"
            if asSaveDialog {
                self.showSaveDialog = true
            } else {
                self.showShareSheet = true
            }
            try? FileManager.default.removeItem(at: tempDir)
        } catch {
            print("[ShareNotebook] Failed to package notebook: \(error)")
            exportAsPdf()
        }
    }

    func addNewPage() {
        let paperId = notebook.paperId(forPage: currentPageIndex)
        changePageStructure(pageMap: { $0 }) {
            store.addPage(notebookId: notebook.id, paperId: paperId)
        }
    }

    /// 在某一頁後面插入新的一頁。
    ///
    /// `paperId` 為 nil 時沿用整本的樣板；指定時這一頁自己用那一種
    /// （見 `NotebookDocument.pagePaperIds`）。
    func insertPageAfter(_ index: Int, paperId: String? = nil) {
        let insertIndex = min(max(0, index + 1), max(1, notebook.pageCount))
        changePageStructure(pageMap: { $0 >= insertIndex ? $0 + 1 : $0 }) {
            store.insertPage(notebookId: notebook.id, afterIndex: index, paperId: paperId)
        }
        if let paperId, let paper = NoteTemplate(paperId: paperId) {
            showCanvasNotice(localizationManager.localized(paper.localizationKey))
        }
    }

    func duplicatePage(at index: Int) {
        changePageStructure(pageMap: { $0 > index ? $0 + 1 : $0 }) {
            store.duplicatePage(notebookId: notebook.id, pageIndex: index)
        }
    }

    func deletePage(at index: Int) {
        guard notebook.pageCount > 1 else { return }
        // 原本刪除前不存檔：目前這一頁剛寫的字還在記憶體裡，稍後的去抖動存檔把它寫到
        // 刪除前的頁碼 —— 也就是現在的下一頁。
        changePageStructure(pageMap: { page in
            page == index ? nil : (page > index ? page - 1 : page)
        }) {
            guard notebook.pageCount > 1 else { return nil }
            return store.deletePage(notebookId: notebook.id, pageIndex: index, currentIndex: currentPageIndex)
        }
    }

    func switchToNotebook(_ target: NotebookDocument) {
        guard target.id != notebook.id else { return }
        // 由外層換掉 Binding 指向的索引；這裡自己寫會覆蓋掉目前這則筆記。
        requestLeave { onRequestSwitch?(target) }
    }

    /// 離開這本筆記（回首頁或切換到另一本）。
    ///
    /// 範例且內容真的有改：先問使用者要存檔（保留在此範例）、另存可編輯副本，還是放棄修改；
    /// 沒改或不是範例：直接離開（範例的暫存跟著收掉）。
    func requestLeave(_ leave: @escaping () -> Void) {
        saveCurrentPageDrawing()
        let id = notebook.id
        guard store.hasSampleSession(id) else { leave(); return }
        // 筆跡在背景佇列寫入：等寫完再比對，最後一筆才算得進去。
        afterCoreInkWrites {
            if ProcessInfo.processInfo.environment["KAIRUMO_UITEST"] == "1" {
                store.finishSampleSession(id, choice: .keep)
                leave()
            } else if store.sampleSessionHasChanges(id) {
                afterSampleLeave = leave
                showSampleLeaveDialog = true
            } else {
                store.finishSampleSession(id, choice: .keep)
                leave()
            }
        }
    }

    /// 唯讀範例提示的「複製一份來編輯」：剛寫的那筆跟著帶進副本，範例放回原樣，編輯器換到副本。
    ///
    /// 不能直接 `notebook = copy`：那會經由宿主的綁定把範例那一格覆寫成副本，
    /// 宿主還在找範例的 id、找不到就什麼都不畫 —— 整個畫面空白、也沒有返回鍵。
    func duplicateSampleToEdit() {
        saveCurrentPageDrawing()
        let id = notebook.id
        afterCoreInkWrites {
            if store.hasSampleSession(id) { inkFrozenNotebookId = id }
            let copy = store.hasSampleSession(id)
                ? store.finishSampleSession(id, choice: .saveCopy)
                : store.duplicateNotebook(id: id)
            guard let copy else { return }
            onRequestSwitch?(copy)
            showNoticeToast(name: localizationManager.localized("done"), icon: "checkmark.circle.fill")
        }
    }

    func finishSampleLeave(_ choice: SampleLeaveChoice) {
        if choice != .keep { inkFrozenNotebookId = notebook.id }
        store.finishSampleSession(notebook.id, choice: choice)
        let leave = afterSampleLeave
        afterSampleLeave = nil
        leave?()
    }

    /// 頁面規格選單。
    ///
    /// # 為什麼它在工具列上，而不是收進設定
    ///
    /// 規格同時決定三件事：畫布多大、分頁在哪裡斷、匯出的 PDF 多大。
    /// 它是**編輯當下**會想改的東西（「這份要印成 A5」），不是設定一次
    /// 就不動的偏好。收進設定的話，使用者要先離開筆記才改得到。
    var pageFormatMenu: some View {
        Menu {
            ForEach(pageFormats(), id: \.id) { format in
                Button {
                    applyPageFormat(format.id)
                } label: {
                    HStack {
                        Text(localizationManager.localized(format.titleKey))
                        if (notebook.pageFormatId ?? defaultPageFormatId()) == format.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            Divider()
            // 大尺寸頁取代無限畫布：任意寬高（300–6000）。
            Button {
                showCustomPageSize = true
            } label: {
                HStack {
                    Text(localizationManager.localized("page_format_custom"))
                    if isCustomPageFormat(id: notebook.pageFormatId ?? defaultPageFormatId()) {
                        Image(systemName: "checkmark")
                    }
                }
            }
            .accessibilityIdentifier("page_format.custom")
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: EditorToolbarMetrics.icon))
                Text(pageFormatTitle)
                    .font(.system(size: EditorToolbarMetrics.label))
            }
            .foregroundColor(.accentColor)
            .padding(.horizontal, 4)
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizationManager.localized("page_format"))
        .help(localizationManager.localized("page_format_desc"))
        .sheet(isPresented: $showCustomPageSize) {
            CustomPageSizeSheet(initial: PageGeometry.size) { applyPageFormat($0) }
        }
    }

    /// 這一頁上所有手繪線的點：專業筆刷（含製圖線）加上 PencilKit 的筆畫。
    func solidSketchPolylines() -> [[CGPoint]] {
        var all = (canvasView as? AdaptiveCanvasView)?.proLayer?.sketchPolylines ?? []
        if let drawing = canvasView?.drawing {
            for stroke in drawing.strokes {
                all.append(stroke.path.interpolatedPoints(by: .distance(3)).map(\.location))
            }
        }
        return all
    }

    /// 把立體輔助排好的圖紙插進目前這一頁：放在**目前看得到的範圍正中央**（不是固定貼頂，
    /// 那樣會壓在既有的圖上），整組一次復原。插入後直接用套索選住它，使用者拖一下就能搬。
    func insertSolidSheet(_ sheet: FfiSolidSheet) {
        guard let canvas = canvasView as? AdaptiveCanvasView, let layer = canvas.proLayer else { return }
        let page = PageGeometry.size
        let w = CGFloat(sheet.width), h = CGFloat(sheet.height)
        let center = layer.convert(CGPoint(x: canvas.bounds.midX, y: canvas.bounds.midY), from: canvas)
        let origin = CGPoint(
            x: min(max(0, center.x - w / 2), max(0, page.width - w)),
            y: min(max(0, center.y - h / 2), max(0, page.height - h)))
        let made = layer.insertDrafted(sheet.strokes, origin: origin)
        showCanvasNotice(localizationManager.localized("solid_place_hint"))
        guard !made.isEmpty else { return }
        applyEditorTool(.lasso)
        // 換工具會清掉舊的選取；等下一個 runloop 再選，選取框才不會被清掉。
        let ids = Set(made.map(\.id))
        let box = made.map(\.bounds).reduce(CGRect.null) { $0.union($1) }
        DispatchQueue.main.async { lasso.select(proStrokeIds: ids, around: box) }
    }

    /// 把一組製圖符號放在目前看得到的範圍正中央（同 `insertSolidSheet`：整組一次復原、插入後套索選住）。
    func insertDraftKit(_ kit: FfiDraftKit) {
        guard let canvas = canvasView as? AdaptiveCanvasView, let layer = canvas.proLayer else { return }
        let pts = kit.strokes.flatMap(\.points)
        guard let minX = pts.map(\.x).min(), let maxX = pts.map(\.x).max(),
              let minY = pts.map(\.y).min(), let maxY = pts.map(\.y).max() else { return }
        let page = PageGeometry.size
        let w = CGFloat(maxX - minX), h = CGFloat(maxY - minY)
        let center = layer.convert(CGPoint(x: canvas.bounds.midX, y: canvas.bounds.midY), from: canvas)
        // 讓符號的包圍盒中心落在視野中央，再夾回頁面裡。
        let left = min(max(0, center.x - w / 2), max(0, page.width - w))
        let top = min(max(0, center.y - h / 2), max(0, page.height - h))
        let origin = CGPoint(x: left - CGFloat(minX), y: top - CGFloat(minY))
        let made = layer.insertDrafted(kit.strokes, origin: origin)
        showCanvasNotice(localizationManager.localized("draft_symbol_placed"))
        guard !made.isEmpty else { return }
        applyEditorTool(.lasso)
        let ids = Set(made.map(\.id))
        let box = made.map(\.bounds).reduce(CGRect.null) { $0.union($1) }
        DispatchQueue.main.async { lasso.select(proStrokeIds: ids, around: box) }
    }

    /// 匯出本頁的製圖線（SVG 或 DXF，毫米）：隱藏的圖層不輸出；寫進暫存資料夾再交給分享表。
    func exportDrafting(format: String) {
        guard let canvas = canvasView as? AdaptiveCanvasView, let layer = canvas.proLayer else { return }
        let drafting = DraftingState.shared
        let strokes: [FfiExportStroke] = layer.allStrokes.compactMap { s in
            guard s.points.count >= 2,
                  s.layerId == 0 || !drafting.isHidden(layer: s.layerId, notebookId: layer.notebookId)
            else { return nil }
            let c = s.colorRGBA
            let hex = c.count >= 3 ? String(format: "#%02X%02X%02X", c[0], c[1], c[2]) : "#111827"
            return FfiExportStroke(
                points: s.points.map { FfiPoint(x: $0.x, y: $0.y) }, layer: s.layerId, lineType: s.lineTypeId,
                width: s.baseWidth, colorHex: hex)
        }
        guard !strokes.isEmpty else {
            showCanvasNotice(localizationManager.localized("draft_export_empty"))
            return
        }
        let size = PageGeometry.size
        let text = format == "dxf"
            ? draftExportDxf(strokes: strokes, pageWidth: Float(size.width), pageHeight: Float(size.height))
            : draftExportSvg(strokes: strokes, pageWidth: Float(size.width), pageHeight: Float(size.height))
        let url = FileManager.default.temporaryDirectory
            .appending(path: "padnote-page-\(currentPageIndex + 1).\(format)")
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            showCanvasNotice(localizationManager.localized("draft_export_failed"))
            return
        }
        // 工具箱剛關：在下一輪 runloop 開啟分享表，確保前一個 sheet 已經解除。
        DispatchQueue.main.async { draftExportShare = SharedFile(url: url) }
    }

    /// 開始一題練習：把題目線放進目前這一頁（頁面大小由核心依它排版）。
    func startPractice(kind: String) {
        guard let canvas = canvasView as? AdaptiveCanvasView, let layer = canvas.proLayer else { return }
        applyEditorTool(.drafting)
        PracticeSession.shared.start(kind: kind, layer: layer, pageSize: PageGeometry.size)
    }

    /// 矩形陣列：套用在套索選的那批線上（一次復原）。
    func applyRectArray(rows: Int, cols: Int, dxMm: Double, dyMm: Double) {
        guard let canvas = canvasView as? AdaptiveCanvasView, let layer = canvas.proLayer else { return }
        DraftingState.shared.editSelection = lasso.proIds
        guard !lasso.proIds.isEmpty else {
            showCanvasNotice(localizationManager.localized("draft_edit_need_selection"))
            return
        }
        DraftEditController.shared.applyRectArray(rows: rows, cols: cols, dxMm: dxMm, dyMm: dyMm, layer: layer)
    }

    /// 把量角器讀到的角度畫成一條線（從圓心到外緣），一次復原。
    func markProtractorReading() {
        guard let canvas = canvasView as? AdaptiveCanvasView, let layer = canvas.proLayer else { return }
        let drafting = DraftingState.shared
        guard let (a, b) = drafting.instrument?.readingRay else { return }
        let pen = drafting.activePen
        let stroke = FfiSheetStroke(
            points: [FfiPoint(x: Float(a.x), y: Float(a.y)), FfiPoint(x: Float(b.x), y: Float(b.y))],
            layer: drafting.activeLayerId, lineType: drafting.activeLineType, width: pen.width, colorHex: pen.colorHex)
        guard !drafting.isLocked(layer: stroke.layer, notebookId: layer.notebookId) else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }
        drafting.ensureVisible(layer: stroke.layer, notebookId: layer.notebookId)
        layer.insertDrafted([stroke], origin: .zero)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// 目前視野的正中央（頁面座標）。
    func draftViewportCenter() -> CGPoint {
        guard let canvas = canvasView as? AdaptiveCanvasView, let layer = canvas.proLayer else {
            return CGPoint(x: PageGeometry.size.width / 2, y: PageGeometry.size.height / 2)
        }
        return layer.convert(CGPoint(x: canvas.bounds.midX, y: canvas.bounds.midY), from: canvas)
    }

    /// 這一頁的紙張規格有沒有標準圖框（A4／A3／A2，直式或橫式）。
    var frameSupportedForCurrentPage: Bool {
        draftSheetFrame(paperId: notebook.pageFormatId ?? defaultPageFormatId(), scaleText: "", thirdAngle: true, titleBlock: false) != nil
    }

    /// 插入圖框與標題欄：框線是製圖筆畫（粗框、細格），欄位名稱是文字方塊（跟著介面語言）。
    func insertDraftFrame(thirdAngle: Bool) {
        guard let canvas = canvasView as? AdaptiveCanvasView, let layer = canvas.proLayer else { return }
        let drafting = DraftingState.shared
        guard let kit = draftSheetFrame(
            paperId: notebook.pageFormatId ?? defaultPageFormatId(),
            scaleText: drafting.scaleLabel(notebookId: notebook.id),
            thirdAngle: thirdAngle, titleBlock: true)
        else {
            showCanvasNotice(localizationManager.localized("draft_frame_unsupported"))
            return
        }
        layer.insertDrafted(kit.strokes, origin: .zero)
        var added = notebook.textAttachments ?? []
        for label in kit.texts {
            added.append(NoteTextAttachment(
                pageIndex: currentPageIndex, text: localizationManager.localized(label.key),
                fontSize: CGFloat(label.fontSize), isBold: label.bold, alignmentRaw: "left",
                textColorHex: label.colorHex, backgroundColorHex: "clear", hasBorder: false,
                x: CGFloat(label.x), y: CGFloat(label.y), width: CGFloat(label.width),
                height: CGFloat(label.fontSize) * 1.6 + 6))
        }
        notebook.textAttachments = added
        showCanvasNotice(localizationManager.localized("draft_frame_inserted"))
    }

    /// 工具列上顯示的規格名稱。自訂的直接顯示尺寸（「2000×1500」）。
    var pageFormatTitle: String {
        let id = notebook.pageFormatId ?? defaultPageFormatId()
        let format = pageFormat(id: id)
        if isCustomPageFormat(id: id) {
            return "\(Int(format.width))×\(Int(format.height))"
        }
        return localizationManager.localized(format.titleKey)
    }

    /// 版面配色。
    ///
    /// # 為什麼是整本一個
    ///
    /// 每一頁各挑一個顏色不是「豐富」，是雜亂 —— 翻頁時整份筆記在閃。
    /// 一本筆記一個調子，而那個調子是使用者選的。
    var guidePaletteMenu: some View {
        let current = notebook.guidePaletteId ?? guidePalettes().first?.id ?? "graphite"
        return Menu {
            ForEach(guidePalettes(), id: \.id) { palette in
                Button {
                    applyGuidePalette(palette.id)
                } label: {
                    HStack {
                        Text(localizationManager.localized(palette.nameKey))
                        if current == palette.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                // 直接畫出那個顏色。名字旁邊放一個色點，比只寫「靛藍」清楚 ——
                // 使用者要挑的是顏色，不是詞。
                Circle()
                    .fill(Color(uiColor: UIColor(hexString: guidePalette(id: current).accentHex) ?? .systemIndigo))
                    .frame(width: EditorToolbarMetrics.icon - 4, height: EditorToolbarMetrics.icon - 4)
                Text(localizationManager.localized(guidePalette(id: current).nameKey))
                    .font(.system(size: EditorToolbarMetrics.label))
            }
            .foregroundColor(.accentColor)
            .padding(.horizontal, 4)
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizationManager.localized("guide_palette"))
        .help(localizationManager.localized("guide_palette_desc"))
    }

    func applyGuidePalette(_ id: String) {
        guard notebook.guidePaletteId != id else { return }
        notebook.guidePaletteId = id
        commitNotebook()
        // 縮圖的快取鍵含配色，所以側欄會跟著換 —— 但畫布要自己重畫一次。
        PageThumbnailRenderer.invalidateAll()
        showCanvasNotice(localizationManager.localized(guidePalette(id: id).nameKey))
    }

    /// 換一種紙。
    ///
    /// 換完之後**既有的內容要跟著進來**：A4 直式換成 A5 之後，原本靠右
    /// 那一欄的東西會落在新頁面外面 —— 畫布上看得到、匯出時整欄不見。
    /// 所以一併把每個物件夾回新的可列印範圍，並講清楚發生了什麼事。
    func applyPageFormat(_ id: String) {
        guard notebook.pageFormatId != id else { return }
        notebook.pageFormatId = id
        PageGeometry.use(format: id)
        clampAttachmentsIntoPage()
        commitNotebook()
        showCanvasNotice(localizationManager.localized("page_format_change_warning"))
    }

    /// 把所有附件夾回目前頁面的可列印範圍。
    func clampAttachmentsIntoPage() {
        let page = PageGeometry.size
        let inset = Float(PageGeometry.printableInset)

        func fit(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
            let clamped = clampToPrintable(
                rect: FfiRect(
                    minX: Float(x), minY: Float(y),
                    maxX: Float(x + w), maxY: Float(y + h)),
                pageWidth: Float(page.width), pageHeight: Float(page.height), inset: inset)
            return CGRect(
                x: CGFloat(clamped.minX), y: CGFloat(clamped.minY),
                width: CGFloat(clamped.maxX - clamped.minX),
                height: CGFloat(clamped.maxY - clamped.minY))
        }

        notebook.attachments = notebook.attachments?.map { item in
            var moved = item
            let r = fit(item.x, item.y, item.width, item.height)
            moved.x = r.minX; moved.y = r.minY
            moved.width = r.width; moved.height = r.height
            return moved
        }
        notebook.textAttachments = notebook.textAttachments?.map { item in
            var moved = item
            let r = fit(item.x, item.y, item.width, item.height)
            moved.x = r.minX; moved.y = r.minY
            moved.width = r.width; moved.height = r.height
            return moved
        }
        notebook.tableAttachments = notebook.tableAttachments?.map { item in
            var moved = item
            let r = fit(item.x, item.y, item.width, 0)
            moved.x = r.minX; moved.y = r.minY
            return moved
        }
        notebook.shapeAttachments = notebook.shapeAttachments?.map { item in
            var moved = item
            let r = fit(item.x, item.y, item.width, item.height)
            moved.x = r.minX; moved.y = r.minY
            return moved
        }
    }

    /// 把落在可列印範圍**之外**的筆畫收回。
    ///
    /// # 為什麼是「完全在外面才收回」
    ///
    /// 界線判斷分三種答案（見核心 `is_within_printable` / `is_outside_printable`）：
    /// 整個在裡面、整個在外面、跨在界線上。三種要分開處理：
    ///
    /// - **整個在外面** → 收回。那一筆印不出來也匯不出去，留著只會讓使用者
    ///   以為它存在，等到列印那天才發現不見了。
    /// - **跨在界線上** → 留著，但提醒一次。寫到一半被整筆吃掉比溢出更難用，
    ///   而且那一筆大半還看得見。
    ///
    /// 要改成「碰到界線就擋」的話，把下面的 `isOutside` 換成 `!isWithin` 即可。
    func enforcePrintableArea(_ drawing: PKDrawing) -> PKDrawing {
        guard drawing.strokes.count > lastStrokeCount else { return drawing }

        let page = PageGeometry.size
        let inset = Float(PageGeometry.printableInset)
        var kept: [PKStroke] = []
        var rejected = false
        var straddled = false

        for (index, stroke) in drawing.strokes.enumerated() {
            // 只檢查這一次新加的那幾筆 —— 既有的筆畫可能是別的裝置或別的
            // 頁面尺寸下寫的，回頭去刪它們等於幫使用者做了他沒要求的決定。
            guard index >= lastStrokeCount else {
                kept.append(stroke)
                continue
            }
            let bounds = stroke.renderBounds
            let rect = FfiRect(
                minX: Float(bounds.minX), minY: Float(bounds.minY),
                maxX: Float(bounds.maxX), maxY: Float(bounds.maxY))
            if isOutsidePrintable(
                rect: rect, pageWidth: Float(page.width),
                pageHeight: Float(page.height), inset: inset) {
                rejected = true
                continue
            }
            if !isWithinPrintable(
                rect: rect, pageWidth: Float(page.width),
                pageHeight: Float(page.height), inset: inset) {
                straddled = true
            }
            kept.append(stroke)
        }

        if rejected {
            showCanvasNotice(localizationManager.localized("outside_printable_rejected"))
            return PKDrawing(strokes: kept)
        }
        if straddled {
            showCanvasNotice(localizationManager.localized("outside_printable_clamped"))
        }
        return drawing
    }

    /// 在畫布上顯示一則提示，幾秒後自己淡掉。
    func showCanvasNotice(_ text: String) {
        canvasNoticeToken += 1
        let token = canvasNoticeToken
        withAnimation(.easeInOut(duration: 0.2)) { canvasNotice = text }
        let duration: Double = ProcessInfo.processInfo.environment["KAIRUMO_UITEST"] == "1" ? 10.0 : 3.5
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            guard canvasNoticeToken == token else { return }
            withAnimation(.easeInOut(duration: 0.3)) { canvasNotice = nil }
        }
    }

    /// 自動清理重複 ID 與未完成的幽靈空白文字方塊
    func sanitizeTextAttachments() {
        guard let attachments = notebook.textAttachments, !attachments.isEmpty else { return }
        var seenIds = Set<String>()
        var cleaned: [NoteTextAttachment] = []
        for item in attachments {
            if seenIds.contains(item.id) {
                // 重複 ID：若已存入的是空的但目前這筆有內容，以有內容的替換
                if !item.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    if let existingIdx = cleaned.firstIndex(where: { $0.id == item.id }),
                       cleaned[existingIdx].text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        cleaned[existingIdx] = item
                    }
                }
                continue
            }
            // 清理幽靈空方塊（若文字為空且非當前正在輸入的項目，自動清除）
            if item.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && item.id != inlineEditingTextId {
                continue
            }
            seenIds.insert(item.id)
            cleaned.append(item)
        }
        if cleaned.count != attachments.count {
            notebook.textAttachments = cleaned
            commitNotebook()
            PageThumbnailRenderer.invalidateAll()
        }
    }

    /// 自動自癒示範筆記《Kairumo(功能範例)》：將背景大卡片移至筆跡下方圖層，使筆跡可見且不干擾手繪與打字。
    func sanitizeUnderInkObjects() {
        let isShowcase = notebook.id.caseInsensitiveCompare("seed-feature-showcase-v1") == .orderedSame || notebook.titleKey == "seed_feature_showcase_title"
        if isShowcase {
            if notebook.explicitUnderInkObjectIds(forPage: 1).isEmpty {
                for p in 0..<notebook.pageCount {
                    let bgCardIds = (notebook.shapeAttachments ?? []).filter {
                        $0.pageIndex == p && $0.kindName == "rectangle" && $0.label.isEmpty
                    }.map(\.id)
                    notebook.setUnderInkObjectIds(Set(bgCardIds), forPage: p)
                }
                commitNotebook()
                PageThumbnailRenderer.invalidateAll()
            }
        }
    }

    /// 打字工具列要套用格式的那一個方塊。
    ///
    /// **不再退回「這一頁第一個方塊」。** 那個退路讓工具列在焦點一閃而過時
    /// 改到不相干的方塊（例如頁首標題被加上「1. ☐」）。沒有目標就回 nil，
    /// 由呼叫端決定（工具列改的是 `pendingTypingStyle`）。
    var activeTextAttachment: NoteTextAttachment? {
        func find(_ id: String) -> NoteTextAttachment? {
            notebook.textAttachments?.first(where: { $0.id == id })
        }
        if let id = inlineEditingTextId { return find(id) }
        if let id = editingTextId { return find(id) }
        if let id = activeSelectedObjectId {
            // 選中的是圖片、表格等非文字物件：文字工具列沒有目標。
            return find(id)
        }
        if !selectedShapeIds.isEmpty || !selectedObjectIds.isEmpty { return nil }
        if let id = textFormatTargetId, let match = find(id), match.pageIndex == currentPageIndex {
            return match
        }
        return nil
    }

    /// 使用者主動換了目標（點畫布、換頁、換模式）：格式化工作階段結束。
    func endTextFormatSession() {
        textFormatTargetId = nil
        suspendedInlineTextId = nil
    }

    /// 打字工具列的每一個格式變更都走這裡：記復原點、調整高度、存檔、廣播，
    /// 再把游標還給剛剛在打字的方塊 —— 跟 Word 一樣，按完粗體可以直接接著打。
    /// 工具列這一次要改哪裡：選取的字、游標處、或整個方塊（見 `TextFormatScope`）。
    func textFormatScope(for target: NoteTextAttachment) -> TextFormatScope {
        let tracker = textSelectionTracker
        guard tracker.textId == target.id,
              inlineEditingTextId == target.id || suspendedInlineTextId == target.id else { return .wholeBox }
        let length = RichText.utf16Length(target.text)
        let location = min(max(0, tracker.range.location), length)
        let range = NSRange(location: location, length: min(max(0, tracker.range.length), length - location))
        if range.length > 0 {
            // 全選等於整個方塊：改方塊層級的值，之後在結尾接著打的字也會是這個格式。
            return range.length == length ? .wholeBox : .selection(range)
        }
        if let word = RichText.wordRange(around: location, in: target.text) { return .selection(word) }
        return .caret(location)
    }

    /// 工具列顯示的格式：有選取時是選取文字的格式（Word 的按鈕狀態跟著選取走），
    /// 只有游標時是游標處的格式，否則是方塊層級的格式。
    func toolbarDisplayedText() -> NoteTextAttachment {
        guard let target = activeTextAttachment else { return pendingTypingStyle }
        let resolved: ResolvedCharStyle
        switch textFormatScope(for: target) {
        case .wholeBox:
            return target
        case .selection(let range):
            resolved = RichText.resolvedStyle(at: range, in: target)
        case .caret(let location):
            let caret = textSelectionTracker.caretStyle
            if let caret, caret.textId == target.id, caret.location == location {
                resolved = RichText.resolve(caret.style, over: RichText.base(of: target))
            } else {
                resolved = RichText.resolvedStyle(at: NSRange(location: location, length: 0), in: target)
            }
        }
        var shown = target
        shown.isBold = resolved.bold
        shown.isItalic = resolved.italic
        shown.isUnderline = resolved.underline
        shown.isStrikethrough = resolved.strikethrough
        shown.fontSize = resolved.fontSize
        shown.fontFamily = resolved.fontFamily
        shown.textColorHex = resolved.textColorHex
        return shown
    }

    /// 工具列改了哪些字元格式（與它看到的值比較）。
    func charStyleChange(from shown: NoteTextAttachment, to updated: NoteTextAttachment) -> TextCharStyle {
        var edit = TextCharStyle()
        if shown.isBold != updated.isBold { edit.bold = updated.isBold }
        if shown.isItalic != updated.isItalic { edit.italic = updated.isItalic }
        if shown.isUnderline != updated.isUnderline { edit.underline = updated.isUnderline }
        if shown.isStrikethrough != updated.isStrikethrough { edit.strikethrough = updated.isStrikethrough }
        if abs(shown.fontSize - updated.fontSize) > 0.001 { edit.fontSize = updated.fontSize }
        if shown.fontFamily != updated.fontFamily { edit.fontFamily = updated.fontFamily ?? "" }
        if shown.textColorHex != updated.textColorHex { edit.textColorHex = updated.textColorHex }
        return edit
    }

    /// 打字工具列的每一個格式變更都走這裡：決定套用範圍、記復原點、調整高度、存檔、廣播，
    /// 再把游標還給剛剛在打字的方塊 —— 跟 Word 一樣，按完粗體可以直接接著打。
    func applyToolbarTextChange(_ updated: NoteTextAttachment) {
        guard let target = activeTextAttachment, target.id == updated.id,
              notebook.textAttachments?.contains(where: { $0.id == target.id }) == true else {
            var style = updated
            style.text = ""
            pendingTypingStyle = style
            return
        }
        let edit = charStyleChange(from: toolbarDisplayedText(), to: updated)

        // 段落層級的欄位（對齊、縮排、行距、文字內容…）直接沿用工具列的值；
        // 字元層級的欄位先還原成方塊原本的值，再依範圍套用這一次的變更。
        var next = updated
        next.isBold = target.isBold
        next.isItalic = target.isItalic
        next.isUnderline = target.isUnderline
        next.isStrikethrough = target.isStrikethrough
        next.fontSize = target.fontSize
        next.fontFamily = target.fontFamily
        next.textColorHex = target.textColorHex
        next.runs = target.runs
        if next.text != target.text {
            RichText.adjustRunsLineByLine(of: &next, from: target.text)
        }
        if !edit.isEmpty {
            switch textFormatScope(for: target) {
            case .wholeBox:
                RichText.applyToWholeBox(edit, to: &next)
            case .selection(let range):
                RichText.apply(edit, range: range, to: &next)
            case .caret(let location):
                // 只有游標：不改現有的字，改接下來要打的字（Word 的行為）。
                var caret = textSelectionTracker.caretStyle
                if caret?.textId != target.id || caret?.location != location {
                    caret = CaretStyle(textId: target.id, location: location, style: TextCharStyle())
                }
                if var caret {
                    caret.style = caret.style.overlaid(with: edit)
                    textSelectionTracker.setCaretStyle(caret)
                }
            }
        }
        commitToolbarText(next)
    }

    /// 把工具列算好的結果寫回筆記本。
    func commitToolbarText(_ candidate: NoteTextAttachment) {
        guard let idx = notebook.textAttachments?.firstIndex(where: { $0.id == candidate.id }) else { return }
        guard notebook.textAttachments?[idx] != candidate else {
            resumeInlineEditingAfterToolbar(candidate.id)
            return
        }
        recordTextUndoState()
        var next = candidate
        next.height = max(next.height, RichText.boxHeight(for: next))
        notebook.textAttachments?[idx] = next
        textFormatTargetId = next.id
        commitNotebook()
        PageThumbnailRenderer.invalidateAll()
        if let data = try? JSONEncoder().encode(next),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            collaborationManager.broadcastAttachmentUpsert(type: "text", itemDict: dict)
        }
        resumeInlineEditingAfterToolbar(next.id)
    }

    /// 工具列醒目提示按鈕目前代表的顏色。
    func toolbarHighlightHex() -> String? {
        guard let target = activeTextAttachment else { return nil }
        switch textFormatScope(for: target) {
        case .selection(let range):
            return RichText.resolvedStyle(at: range, in: target).highlightHex
        case .caret(let location):
            if let caret = textSelectionTracker.caretStyle, caret.textId == target.id, caret.location == location {
                return caret.style.highlightHex == "clear" ? nil : caret.style.highlightHex
            }
            return RichText.resolvedStyle(at: NSRange(location: location, length: 0), in: target).highlightHex
        case .wholeBox:
            // 整個方塊都是同一個醒目提示色時才算「有」。
            let runs = RichText.normalized(target) ?? []
            let length = RichText.utf16Length(target.text)
            if runs.count == 1, runs[0].start == 0, runs[0].length == length { return runs[0].style.highlightHex }
            return nil
        }
    }

    /// Word 的文字醒目提示：套在字上（字的背景），不是整個方塊的底色。
    func applyToolbarHighlight(_ hex: String) {
        guard let target = activeTextAttachment else { return }
        var next = target
        let edit = TextCharStyle(highlightHex: hex)
        switch textFormatScope(for: target) {
        case .wholeBox:
            RichText.applyToWholeBox(edit, to: &next)
        case .selection(let range):
            RichText.apply(edit, range: range, to: &next)
        case .caret(let location):
            var caret = textSelectionTracker.caretStyle
            if caret?.textId != target.id || caret?.location != location {
                caret = CaretStyle(textId: target.id, location: location, style: TextCharStyle())
            }
            if var caret {
                caret.style = caret.style.overlaid(with: edit)
                textSelectionTracker.setCaretStyle(caret)
            }
        }
        commitToolbarText(next)
    }

    /// Word 的「清除所有格式設定」：有選取時只清選取的字；否則整個方塊回到內文樣式。
    /// 段落設定（對齊、行距、縮排）一律回到預設。文字內容不動。
    func clearToolbarFormatting() {
        guard let target = activeTextAttachment else {
            pendingTypingStyle = NoteTextAttachment(
                id: pendingTypingStyle.id, text: "", backgroundColorHex: "clear", hasBorder: false)
            return
        }
        var next = target
        next.alignmentRaw = "left"
        next.lineSpacing = nil
        next.paragraphIndent = nil
        switch textFormatScope(for: target) {
        case .selection(let range):
            RichText.clearOverrides(in: range, of: &next)
        case .caret:
            textSelectionTracker.clear(textId: target.id)
            next.runs = target.runs
        case .wholeBox:
            next.fontSize = 15
            next.fontFamily = nil
            next.isBold = false
            next.isItalic = false
            next.isUnderline = false
            next.isStrikethrough = false
            next.textColorHex = "#000000"
            next.runs = nil
        }
        commitToolbarText(next)
    }

    /// Word 格式快捷鍵（見 `TextFormatCommand`）。只在打字工具列出現時作用，
    /// 手繪時按 ⌘B 不該偷偷改掉某個文字方塊。
    func handleTextFormatCommand(_ command: TextFormatCommand) {
        guard effectiveToolbarMode == .type else { return }
        var next = toolbarDisplayedText()
        switch command {
        case .bold: next.isBold.toggle()
        case .italic: next.isItalic.toggle()
        case .underline: next.isUnderline.toggle()
        case .strikethrough: next.isStrikethrough.toggle()
        case .growFont: next.fontSize = min(400, next.fontSize + 1)
        case .shrinkFont: next.fontSize = max(1, next.fontSize - 1)
        case .alignLeft: next.alignmentRaw = "left"
        case .alignRight: next.alignmentRaw = "right"
        case .bulletList:
            guard activeTextAttachment != nil else {
                insertQuickTextSnippet("• ")
                return
            }
            next.text = WordListKind.bullet.toggle(in: next.text)
        }
        applyToolbarTextChange(next)
    }

    /// 焦點是被工具列借走的：把就地編輯還回去，鍵盤／游標回到原方塊。
    func resumeInlineEditingAfterToolbar(_ id: String) {
        guard suspendedInlineTextId == id else { return }
        // 等選單／按鈕的事件跑完再要焦點，否則 UIKit 會在收選單時又把它收走。
        DispatchQueue.main.async {
            guard suspendedInlineTextId == id, inlineEditingTextId == nil,
                  notebook.textAttachments?.contains(where: { $0.id == id }) == true else { return }
            suspendedInlineTextId = nil
            // 新的編輯器把游標（或選取範圍）放回原處，而不是跳到最後。
            textSelectionTracker.restoreSelectionOnNextBegin = true
            inlineEditingTextId = id
        }
    }

    var isCurrentTextBold: Bool {
        activeTextAttachment?.isBold ?? false
    }

    var isCurrentTextItalic: Bool {
        activeTextAttachment?.isItalic ?? false
    }

    var isCurrentTextUnderline: Bool {
        activeTextAttachment?.isUnderline ?? false
    }

    var currentTextAlignment: String {
        activeTextAttachment?.alignmentRaw ?? "left"
    }

    func ensureActiveTextAttachment() -> (id: String, index: Int) {
        if let id = activeTextAttachment?.id,
           let index = notebook.textAttachments?.firstIndex(where: { $0.id == id }) {
            return (id, index)
        }
        let draft = insertTextBox(at: CGPoint(x: PageGeometry.printableInset, y: 200))
        let idx = (notebook.textAttachments?.firstIndex(where: { $0.id == draft.id })) ?? 0
        return (draft.id, idx)
    }

    func toggleActiveTextBold() {
        let target = ensureActiveTextAttachment()
        guard let items = notebook.textAttachments, items.indices.contains(target.index) else { return }
        recordTextUndoState()
        notebook.textAttachments?[target.index].isBold.toggle()
        commitNotebook()
        PageThumbnailRenderer.invalidateAll()
    }

    func toggleActiveTextItalic() {
        let target = ensureActiveTextAttachment()
        guard let items = notebook.textAttachments, items.indices.contains(target.index) else { return }
        recordTextUndoState()
        notebook.textAttachments?[target.index].isItalic.toggle()
        commitNotebook()
        PageThumbnailRenderer.invalidateAll()
    }

    func toggleActiveTextUnderline() {
        let target = ensureActiveTextAttachment()
        guard let items = notebook.textAttachments, items.indices.contains(target.index) else { return }
        recordTextUndoState()
        notebook.textAttachments?[target.index].isUnderline.toggle()
        commitNotebook()
        PageThumbnailRenderer.invalidateAll()
    }

    func setActiveTextAlignment(_ align: String) {
        let target = ensureActiveTextAttachment()
        guard let items = notebook.textAttachments, items.indices.contains(target.index) else { return }
        recordTextUndoState()
        notebook.textAttachments?[target.index].alignmentRaw = align
        commitNotebook()
        PageThumbnailRenderer.invalidateAll()
    }

    func changeActiveTextFontSize(delta: CGFloat) {
        let target = ensureActiveTextAttachment()
        guard let items = notebook.textAttachments, items.indices.contains(target.index) else { return }
        recordTextUndoState()
        let current = notebook.textAttachments?[target.index].fontSize ?? 16
        notebook.textAttachments?[target.index].fontSize = max(10, min(72, current + delta))
        commitNotebook()
        PageThumbnailRenderer.invalidateAll()
    }

    func setActiveTextColor(_ hex: String) {
        let target = ensureActiveTextAttachment()
        guard let items = notebook.textAttachments, items.indices.contains(target.index) else { return }
        recordTextUndoState()
        notebook.textAttachments?[target.index].textColorHex = hex
        commitNotebook()
        PageThumbnailRenderer.invalidateAll()
    }

    func bringActiveObjectForward() {
        let order = ObjectStacking.normalized(objects: pageStackableObjects, order: notebook.objectOrder(forPage: currentPageIndex))
        let targetId = inlineEditingTextId ?? editingTextId ?? selectedShapeIds.first ?? selectedObjectIds.first ?? (notebook.textAttachments?.last(where: { $0.pageIndex == currentPageIndex })?.id)
        guard let id = targetId else { return }
        let newOrder = ObjectStacking.bringForward([id], in: order)
        notebook.setObjectOrder(newOrder, forPage: currentPageIndex)
        commitNotebook()
    }

    func sendActiveObjectBackward() {
        let order = ObjectStacking.normalized(objects: pageStackableObjects, order: notebook.objectOrder(forPage: currentPageIndex))
        let targetId = inlineEditingTextId ?? editingTextId ?? selectedShapeIds.first ?? selectedObjectIds.first ?? (notebook.textAttachments?.last(where: { $0.pageIndex == currentPageIndex })?.id)
        guard let id = targetId else { return }
        let newOrder = ObjectStacking.sendBackward([id], in: order)
        notebook.setObjectOrder(newOrder, forPage: currentPageIndex)
        commitNotebook()
    }

    func findObjectAt(location: CGPoint, page: Int) -> (id: String, kind: String)? {
        let order = notebook.objectOrder(forPage: page)
        let stacking = ObjectStacking.Lookup(order: order)

        var candidates: [(id: String, kind: String, z: Double, rect: CGRect)] = []
        if let items = notebook.attachments {
            for item in items where item.pageIndex == page {
                let rect = CGRect(x: item.x, y: item.y, width: item.width, height: item.height).insetBy(dx: -4, dy: -4)
                candidates.append((item.id, "image", stacking.zIndex(for: item.id, kind: .image), rect))
            }
        }
        if let items = notebook.shapeAttachments {
            for item in items where item.pageIndex == page {
                let rect = CGRect(x: item.x, y: item.y, width: item.width, height: item.height).insetBy(dx: -4, dy: -4)
                candidates.append((item.id, "shape", stacking.zIndex(for: item.id, kind: .shape), rect))
            }
        }
        if let items = notebook.tableAttachments {
            for item in items where item.pageIndex == page {
                let layout = item.layout()
                let rect = CGRect(x: item.x, y: item.y, width: CGFloat(layout.width), height: CGFloat(layout.height)).insetBy(dx: -4, dy: -4)
                candidates.append((item.id, "table", stacking.zIndex(for: item.id, kind: .table), rect))
            }
        }
        if let items = notebook.audioAttachments {
            for item in items where item.pageIndex == page {
                let rect = CGRect(x: item.x, y: item.y, width: item.width, height: item.height).insetBy(dx: -4, dy: -4)
                candidates.append((item.id, "audio", stacking.zIndex(for: item.id, kind: .audio), rect))
            }
        }
        if let items = notebook.linkAttachments {
            for item in items where item.pageIndex == page {
                let rect = CGRect(x: item.x, y: item.y, width: item.width, height: item.height).insetBy(dx: -4, dy: -4)
                candidates.append((item.id, "link", stacking.zIndex(for: item.id, kind: .link), rect))
            }
        }
        if let items = notebook.model3DAttachments {
            for item in items where item.pageIndex == page {
                let rect = CGRect(x: item.x, y: item.y, width: item.width, height: item.height).insetBy(dx: -4, dy: -4)
                candidates.append((item.id, "3d", stacking.zIndex(for: item.id, kind: .model3D), rect))
            }
        }
        let hit = candidates.filter { $0.rect.contains(location) }.sorted(by: { $0.z > $1.z })
        if let first = hit.first {
            return (first.id, first.kind)
        }
        return nil
    }

    func rectContainsPoint(_ baseRect: CGRect, rotation: Double, touchPadding: CGFloat, point: CGPoint) -> Bool {
        let touchRect = baseRect.insetBy(dx: -touchPadding, dy: -touchPadding)
        if abs(rotation) < 0.1 {
            return touchRect.contains(point)
        }
        let center = CGPoint(x: baseRect.midX, y: baseRect.midY)
        let rad = -rotation * .pi / 180.0
        let dx = point.x - center.x
        let dy = point.y - center.y
        let unrotated = CGPoint(
            x: center.x + CGFloat(Double(dx) * cos(rad) - Double(dy) * sin(rad)),
            y: center.y + CGFloat(Double(dx) * sin(rad) + Double(dy) * cos(rad))
        )
        return touchRect.contains(unrotated)
    }

    /// 智慧穿透判定：當觸控點落在筆跡下方的物件時，決定是否讓畫布返回 nil 使得觸控能直達下層物件
    // unused-param-ok: 依 UIKit hitTest(_:with:) 簽章保留 event 參數供擴充使用，穿透邏輯以座標與物件狀態裁決
    func isUnderInkPointPassThrough(point: CGPoint, page: Int, event: UIEvent? = nil) -> Bool {
        // 手寫模式下，若沒有任何物件處於選取或編輯狀態，所有觸控一律留在畫布上（O(1) 快速返回，避免每次 hitTest 配置集合與掃描附件陣列）。
        if editorMode == .draw,
           activeSelectedObjectId == nil,
           selectedObjectIds.isEmpty,
           selectedShapeIds.isEmpty,
           inlineEditingTextId == nil,
           editingTextId == nil {
            return false
        }
        // 鎖定的物件不接觸控：落在它上面的筆照樣畫在畫布上，不穿透下去。
        let underInkSet = notebook.underInkObjectIds(forPage: page)
            .subtracting(notebook.allLockedObjectIds)
        guard !underInkSet.isEmpty else { return false }

        var hitSelected = false
        var hitUnselected = false

        let checkHit: (CGRect, Double, Bool) -> Void = { baseRect, rot, isSel in
            let padding: CGFloat = isSel ? 48 : 8
            if rectContainsPoint(baseRect, rotation: rot, touchPadding: padding, point: point) {
                if isSel {
                    hitSelected = true
                } else {
                    hitUnselected = true
                }
            }
        }

        if let items = notebook.attachments {
            for item in items where item.pageIndex == page && underInkSet.contains(item.id) {
                let isSel = (activeSelectedObjectId == item.id || selectedObjectIds.contains(item.id))
                checkHit(CGRect(x: item.x, y: item.y, width: item.width, height: item.height), item.canvasRotation, isSel)
            }
        }
        if let items = notebook.textAttachments {
            for item in items where item.pageIndex == page && underInkSet.contains(item.id) {
                let isSel = (activeSelectedObjectId == item.id || selectedObjectIds.contains(item.id) || inlineEditingTextId == item.id || editingTextId == item.id)
                checkHit(CGRect(x: item.x, y: item.y, width: item.width, height: item.height), item.canvasRotation, isSel)
            }
        }
        if let items = notebook.shapeAttachments {
            for item in items where item.pageIndex == page && underInkSet.contains(item.id) {
                let isSel = (selectedShapeIds.contains(item.id) || activeSelectedObjectId == item.id || selectedObjectIds.contains(item.id))
                checkHit(CGRect(x: item.x, y: item.y, width: item.width, height: item.height), item.canvasRotation, isSel)
            }
        }
        if let items = notebook.tableAttachments {
            for item in items where item.pageIndex == page && underInkSet.contains(item.id) {
                let isSel = (activeSelectedObjectId == item.id || selectedObjectIds.contains(item.id))
                let layout = item.layout()
                checkHit(CGRect(x: item.x, y: item.y, width: CGFloat(layout.width), height: CGFloat(layout.height)), 0, isSel)
            }
        }
        if let items = notebook.linkAttachments {
            for item in items where item.pageIndex == page && underInkSet.contains(item.id) {
                let isSel = (activeSelectedObjectId == item.id || selectedObjectIds.contains(item.id))
                checkHit(CGRect(x: item.x, y: item.y, width: item.width, height: item.height), 0, isSel)
            }
        }
        if let items = notebook.audioAttachments {
            for item in items where item.pageIndex == page && underInkSet.contains(item.id) {
                let isSel = (activeSelectedObjectId == item.id || selectedObjectIds.contains(item.id))
                checkHit(CGRect(x: item.x, y: item.y, width: item.width, height: item.height), 0, isSel)
            }
        }
        if let items = notebook.model3DAttachments {
            for item in items where item.pageIndex == page && underInkSet.contains(item.id) {
                let isSel = (activeSelectedObjectId == item.id || selectedObjectIds.contains(item.id))
                checkHit(CGRect(x: item.x, y: item.y, width: item.width, height: item.height), 0, isSel)
            }
        }

        if hitSelected {
            // 已選取的筆跡下方物件：優先穿透，以操作控制把手、旋轉、縮放與拖曳
            return true
        }

        if hitUnselected {
            // 未選取的筆跡下方物件：
            // 打字模式下穿透以利點選；手繪模式下不穿透，由畫布接收以順暢在其上方繪圖
            return editorMode == .type
        }

        return false
    }

    func isLocationInsideAnyObject(at location: CGPoint, page: Int) -> Bool {
        if findObjectAt(location: location, page: page) != nil { return true }
        if let items = notebook.tapeAttachments {
            for item in items where item.pageIndex == page {
                if item.rect.insetBy(dx: -4, dy: -4).contains(location) {
                    return true
                }
            }
        }
        return false
    }

    /// 🌟 全自動意圖感知：Apple Pencil 碰到畫布時自動切換至手繪模式，並收回未輸入完成的空白文字框
    func handlePencilTouchBegan() {
        // 手繪區塊已經取得墨跡輸入權，不要再把頂層文件模式改成 `.draw`。
        if editorMode != .draw && !isInlineInkEditing {
            pencilModeSwitchAt = Date()
            // 不加動畫：筆尖已經在紙上，0.2 秒的過場期間整個編輯器在重排，第一筆會卡在那段時間裡。
            transitionToMode(.draw, animated: false)
        }
        if let activeId = inlineEditingTextId {
            if let activeItem = notebook.textAttachments?.first(where: { $0.id == activeId }),
               activeItem.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                notebook.textAttachments?.removeAll { $0.id == activeId }
                commitNotebook()
                PageThumbnailRenderer.invalidateAll()
            }
            inlineEditingTextId = nil
        }
    }

    /// 拿掉「手指輕點」留下的那個小點。
    ///
    /// 只動**最後一筆**，而且必須同時符合：夠小（近乎一個點）、就落在點擊位置、
    /// 剛剛才畫下（不會誤刪使用者真正寫的東西）。
    func removeTapDotStroke(near location: CGPoint) {
        guard let last = currentDrawing.strokes.last else { return }
        let bounds = last.renderBounds
        let isDot = bounds.width < 10 && bounds.height < 10
        let isHere = abs(bounds.midX - location.x) < 16 && abs(bounds.midY - location.y) < 16
        let isFresh = Date().timeIntervalSince(last.path.creationDate) < 2
        guard isDot, isHere, isFresh else { return }
        var strokes = currentDrawing.strokes
        strokes.removeLast()
        currentDrawing = PKDrawing(strokes: strokes)
    }


}
