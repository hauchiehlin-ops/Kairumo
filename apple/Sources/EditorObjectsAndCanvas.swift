//
//  EditorObjectsAndCanvas.swift
//  Kairumo
//
//  編輯器物件、形狀、連接線、框選與批次剪貼簿操作
//

import SwiftUI
import PencilKit
import UniformTypeIdentifiers

// MARK: - 物件與畫布操作擴充

extension NotebookEditorView {
    // MARK: - 附件管理核心
    /// 把一張圖插到頁面上。
    ///
    /// - Parameters:
    ///   - at: 拖放的落點（頁面座標）。`nil` 表示從選單插入 —— 沿用固定位置。
    ///   - page: 落在哪一頁。連續模式下拖到哪一頁就是哪一頁，`nil` 用焦點頁。
    func insertImageAttachment(
        _ image: UIImage,
        chartSpecJSON: String? = nil,
        mathFormula: String? = nil,
        at dropPoint: CGPoint? = nil,
        page: Int? = nil
    ) {
        guard let fileName = store.saveAttachmentImage(image) else { return }
        let aspect = image.size.width / max(1, image.size.height)
        let placed = dropPoint.map {
            ImageDropPlacement.frame(
                dropPoint: $0,
                imageSize: image.size,
                pageSize: CGSize(width: PageGeometry.width, height: PageGeometry.height))
        }
        let w: CGFloat = placed?.width ?? 280
        let h: CGFloat = placed?.height ?? max(80, 280 / aspect)
        let newAttachment = NoteImageAttachment(
            fileName: fileName,
            pageIndex: page ?? currentPageIndex,
            x: placed?.minX ?? 80,
            y: placed?.minY ?? 120,
            width: w,
            height: h,
            rotationDegrees: 0,
            cornerRadius: 8,
            hasShadow: true,
            hasBorder: false,
            filterStyle: .original,
            chartSpecJSON: chartSpecJSON,
            mathFormula: mathFormula
        )
        if notebook.attachments == nil {
            notebook.attachments = []
        }
        notebook.attachments?.append(newAttachment)
        commitNotebook()
        // 不再附上 `image_base64`：這個廣播已經停用（`CollaborationManager.broadcastAttachmentUpsert`
        // 是空的），而那一次 `pngData()` 是在主執行緒上把整張圖再編碼一次 —— 插一頁大 PDF 時
        // 實測佔了按下確定之後一半的卡頓。協作送圖走 `publishCollabChanges` 讀檔案那條路。
        if let dict = (try? JSONSerialization.jsonObject(with: JSONEncoder().encode(newAttachment))) as? [String: Any] {
            collaborationManager.broadcastAttachmentUpsert(type: "image", itemDict: dict)
        }
    }

    /// 整份 PDF 匯入完成：每一頁 PDF 成為一頁筆記內頁。
    ///
    /// 從目前這一頁後面開始插；目前這一頁完全空白（剛建好的筆記）的話，第一頁就放在它上面，
    /// 不留一張多餘的白紙。所有頁面一次插入（`insertPages`）、一次寫回。
    func insertPdfPagesAsNotebookPages(_ pages: [PdfImportedPage], skipped: Int) {
        guard !pages.isEmpty else {
            showNoticeToast(name: localizationManager.localized("pdf_render_failed"), icon: "exclamationmark.triangle.fill")
            return
        }
        saveCurrentPageDrawing()
        let notebookId = notebook.id
        let anchor = currentPageIndex
        let reuseCurrent = store.isBlankPage(notebook, index: anchor)
        let firstPage = reuseCurrent ? anchor : anchor + 1
        let extra = reuseCurrent ? pages.count - 1 : pages.count
        let paperId = notebook.paperId(forPage: anchor)
        let notice = skipped > 0
            ? String(format: localizationManager.localized("pdf_import_partial"), "\(pages.count)", "\(skipped)")
            : String(format: localizationManager.localized("pdf_import_done"), "\(pages.count)")
        if extra > 0 {
            let insertIndex = anchor + 1
            changePageStructure(pageMap: { $0 >= insertIndex ? $0 + extra : $0 }) {
                store.insertPages(notebookId: notebookId, afterIndex: anchor, count: extra, paperId: paperId)
                store.placePdfPages(notebookId: notebookId, pages: pages, firstPage: firstPage)
                return firstPage
            }
        } else {
            store.placePdfPages(notebookId: notebookId, pages: pages, firstPage: firstPage)
            if let updated = store.notebooks.first(where: { $0.id == notebookId }) { notebook = updated }
            objectHistory.record(notebook, manager: historyUndoManager) { state in applyHistoryState(state) }
            continuousObjectGeneration += 1
        }
        PageThumbnailRenderer.invalidateAll()
        // 匯入 PDF 是為了在上面寫字：停在手寫模式。PDF 頁面是鎖定的底稿，不需要切到打字模式去拖它
        // （插入一般圖片時才切，見 `acceptImageDrop`）。
        transitionToMode(.draw)
        showNoticeToast(name: notice, icon: "checkmark.circle.fill")
    }

    /// 從系統剪貼簿讀取圖片（含螢幕截圖、剪下／拷貝的圖片、或是剪貼簿裡的原始圖檔資料）。
    func getClipboardImage() -> UIImage? {
        if let image = UIPasteboard.general.image {
            return image
        }
        if let images = UIPasteboard.general.images, let first = images.first {
            return first
        }
        let supportedTypes = [
            "public.png",
            "public.jpeg",
            "public.tiff",
            "com.compuserve.gif",
            "public.image"
        ]
        for type in supportedTypes {
            if let data = UIPasteboard.general.data(forPasteboardType: type),
               let image = UIImage(data: data) {
                return image
            }
        }
        return nil
    }

    /// 貼上螢幕截圖或剪貼簿中的圖片到目前畫布。
    @discardableResult
    func pasteScreenshotOrClipboardImage() -> Bool {
        if let image = getClipboardImage() {
            insertImageAttachment(image)
            showNoticeToast(name: localizationManager.localized("screenshot_pasted"), icon: "checkmark.circle.fill")
            return true
        } else {
            showNoticeToast(name: localizationManager.localized("clipboard_no_image"), icon: "exclamationmark.triangle.fill")
            return false
        }
    }

    func showNoticeToast(name: String, icon: String) {
        withAnimation(.easeInOut(duration: 0.15)) {
            activeToolToast = (name: name, icon: icon)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.15)) {
                if self.activeToolToast?.name == name {
                    self.activeToolToast = nil
                }
            }
        }
    }

    /// 「匯入文件」：把檔案解析成原生物件，合併進**這本筆記**的目前頁面。
    ///
    /// 解析在暫存套件裡由核心做（見 `DocumentImport`）；這裡負責合併：
    /// 超出頁高的內容接到後面新插入的頁面，不覆蓋既有頁面。失敗一律給提示 ——
    /// 舊版只 `print`，使用者看到的是「點了沒反應」。
    func importDocumentOutcome(_ outcome: FileImport.Outcome) {
        if outcome.fileExtension == "pptx" {
            importErrorKey = "import_unsupported_type"
            return
        }
        let url = store.importedFileURL(fileName: outcome.storedName)
        let imported: NotebookPackageBridge.ImportedNotebook
        do {
            imported = try DocumentImport.parse(fileURL: url, title: outcome.displayName)
        } catch DocumentImport.Failure.empty {
            importErrorKey = "import_empty_file"
            return
        } catch {
            importErrorKey = "import_failed_read"
            return
        }

        let base = currentPageIndex
        let doc = imported.document

        // 區塊依 id（UUIDv7 ＝ 建立順序）排回文件順序，再由上往下排版 ——
        // 核心建立區塊時沒有給位置，全部會落在同一點疊成一團。
        enum Piece { case text(Int), table(Int), image(Int) }
        var texts = doc.textAttachments ?? []
        var tables = doc.tableAttachments ?? []
        var images = doc.attachments ?? []
        var pieces: [(id: String, piece: Piece)] = []
        for (i, t) in texts.enumerated() { pieces.append((t.id, .text(i))) }
        for (i, t) in tables.enumerated() { pieces.append((t.id, .table(i))) }
        for (i, t) in images.enumerated() { pieces.append((t.id, .image(i))) }
        // 依建立時間（UUIDv7 前 48 位元的毫秒時間戳）排回文件順序。**不能比整個 id** ——
        // 同一毫秒內產生的 id 後面是隨機位元，字串順序跟建立順序無關。同一毫秒（匯入時
        // 一股腦建出來，常態）維持各自在核心裡原本的順序。
        pieces = pieces.enumerated().sorted { lhs, rhs in
            let l = DocumentImport.timestampKey(lhs.element.id), r = DocumentImport.timestampKey(rhs.element.id)
            return l != r ? l < r : lhs.offset < rhs.offset
        }.map(\.element)

        let contentWidth = PageGeometry.width - PageGeometry.printableInset * 2
        let heights: [CGFloat] = pieces.map { entry in
            switch entry.piece {
            case .text(let i):
                texts[i].width = contentWidth
                texts[i].x = PageGeometry.printableInset
                let h = DocumentImport.estimatedHeight(
                    text: texts[i].text, fontSize: texts[i].fontSize, width: contentWidth)
                texts[i].height = h
                return h
            case .table(let i):
                tables[i].x = PageGeometry.printableInset
                return tables[i].height
            case .image(let i):
                // 圖片寬度不超過內容區；等比縮小。
                if images[i].width > contentWidth {
                    let scale = contentWidth / images[i].width
                    images[i].width = contentWidth
                    images[i].height *= scale
                }
                images[i].x = PageGeometry.printableInset
                return images[i].height
            }
        }
        let placements = DocumentImport.flow(heights: heights)
        var maxOffset = 0
        for (entry, place) in zip(pieces, placements) {
            maxOffset = max(maxOffset, place.pageOffset)
            switch entry.piece {
            case .text(let i): texts[i].y = place.y; texts[i].pageIndex = place.pageOffset
            case .table(let i): tables[i].y = place.y; tables[i].pageIndex = place.pageOffset
            case .image(let i): images[i].y = place.y; images[i].pageIndex = place.pageOffset
            }
        }
        // 新頁插在目前這一頁後面：走頁面結構變動的共用流程（等背景寫入落盤、頁碼暫存與畫布跟著對齊）。
        let insertedPages = maxOffset
        changePageStructure(pageMap: { $0 > base ? $0 + insertedPages : $0 }) {
            for k in 0..<maxOffset {
                _ = store.insertPage(
                    notebookId: notebook.id, afterIndex: base + k,
                    paperId: notebook.paperId(forPage: base))
            }
            if maxOffset > 0, let updated = store.notebooks.first(where: { $0.id == notebook.id }) {
                notebook = updated
            }

            // id 沿用暫存套件給的：每次匯入都是全新的暫存套件，所以同一個檔案
            // 匯入兩次得到的是兩份獨立的物件，不會撞 id。
            for var item in texts {
                item.pageIndex = base + item.pageIndex
                notebook.textAttachments = (notebook.textAttachments ?? []) + [item]
            }
            for var item in tables {
                item.pageIndex = base + item.pageIndex
                notebook.tableAttachments = (notebook.tableAttachments ?? []) + [item]
            }
            for var item in images {
                guard let bytes = imported.imageData[item.fileName],
                      let saved = store.saveImportedFile(data: bytes, extension: "png") else { continue }
                item.fileName = saved
                item.pageIndex = base + item.pageIndex
                notebook.attachments = (notebook.attachments ?? []) + [item]
            }
            commitNotebook()
            PageThumbnailRenderer.invalidateAll()
            showCanvasNotice(localizationManager.localized("import_document_done"))
            return base
        }
    }

    /// 把一段既有的錄音插到目前這一頁。
    ///
    /// 位置逐張往右下錯開。全部疊在同一點的話，插第二張時使用者會以為沒插進去。
    /// 匯入的音訊檔變成一張跟自己錄的完全一樣的卡片。
    ///
    /// **它會被登記成一段真正的錄音**（`addRecording`），而不是另一種
    /// 只在這一頁存在的附件。理由是使用者接下來會做的每一件事 ——
    /// 播放、在「最近錄音」找它、讓它跟著筆記本同步到另一台裝置 ——
    /// 走的都是錄音那條路；自成一格的話，那些全部要再實作一次，
    /// 而漏掉的那一項會變成「這張卡片按了沒反應」。
    func insertImportedAudio(_ outcome: FileImport.Outcome) {
        // 長度走核心算（S-42）。各平台問各自的系統 API 的話，
        // 同一個檔案在兩台裝置上會顯示不同的秒數。
        let url = store.recordingFileURL(fileName: outcome.storedName, notebookId: nil)
        let seconds = (try? Data(contentsOf: url)).map {
            Int(audioDurationSeconds(bytes: $0))
        } ?? 0
        let rec = store.addRecording(
            title: outcome.displayName,
            durationSeconds: seconds,
            fileName: outcome.storedName,
            linkedNotebookId: notebook.id
        )
        insertAudioAttachment(rec)
    }

    func insertAudioAttachment(_ recording: AudioRecordingRecord) {
        let existing = (notebook.audioAttachments ?? []).filter { $0.pageIndex == currentPageIndex }.count
        let offset = CGFloat(existing % 6) * 18
        let attachment = NoteAudioAttachment(
            pageIndex: currentPageIndex,
            recordingId: recording.id,
            fileName: recording.fileName,
            title: recording.title,
            durationSeconds: recording.durationSeconds,
            x: 80 + offset,
            y: 120 + offset
        )
        if notebook.audioAttachments == nil {
            notebook.audioAttachments = []
        }
        notebook.audioAttachments?.append(attachment)
        // 這本筆記從此「有錄音」—— 首頁的錄音篩選要看得到它。
        notebook.hasRecording = true
        commitNotebook()
    }

    /// 用新算出來的圖表取代原本那一張。
    ///
    /// 位置、尺寸、邊框、濾鏡全部原地保留 —— 使用者只是改了裡面的數字，
    /// 圖不該跳回預設大小、跑回左上角。
    func replaceChartAttachment(id: String, spec: ChartSpec, image: UIImage) {
        guard let index = notebook.attachments?.firstIndex(where: { $0.id == id }),
              let fileName = store.saveAttachmentImage(image) else { return }
        notebook.attachments?[index].fileName = fileName
        notebook.attachments?[index].chartSpecJSON = spec.encodedJSON()
        commitNotebook()
        editingChartAttachmentId = nil
    }

    /// 用新算出來的算式卡片取代原本那一張。
    /// 若轉成文字方塊（image == nil），則從附件移除卡片。
    func replaceMathAttachment(id: String, formula: String, image: UIImage?) {
        guard let index = notebook.attachments?.firstIndex(where: { $0.id == id }) else {
            editingMathAttachmentId = nil
            return
        }
        if let image = image, let fileName = store.saveAttachmentImage(image) {
            notebook.attachments?[index].fileName = fileName
            notebook.attachments?[index].mathFormula = formula
        } else {
            // 使用者選擇轉插入為可編輯文字方塊
            notebook.attachments?.remove(at: index)
        }
        commitNotebook()
        editingMathAttachmentId = nil
    }

    /// 目前這一頁的形狀，依堆疊順序。
    var pageShapes: [NoteShapeAttachment] {
        (notebook.shapeAttachments ?? []).filter { $0.pageIndex == currentPageIndex }
    }

    // MARK: - 形狀與連接線的編修

    /// 刪除一個形狀，連著它的線一起走。
    ///
    /// 留著的話會指向一個不存在的形狀，畫面上是一條從空氣連出來的線。
    func deleteShape(_ id: String) {
        notebook.shapeAttachments?.removeAll { $0.id == id }
        notebook.connectionAttachments?.removeAll { $0.fromShapeId == id || $0.toShapeId == id }
        selectedShapeIds.remove(id)
        if editingShapeId == id { editingShapeId = nil }
        commitNotebook()
        PageThumbnailRenderer.invalidateAll()
    }

    func deleteConnection(_ id: String) {
        notebook.connectionAttachments?.removeAll { $0.id == id }
        if selectedConnectionId == id { selectedConnectionId = nil }
        if editingConnectionId == id { editingConnectionId = nil }
        commitNotebook()
        PageThumbnailRenderer.invalidateAll()
    }

    func duplicateShape(_ id: String) {
        guard var copy = notebook.shapeAttachments?.first(where: { $0.id == id }) else { return }
        var fresh = NoteShapeAttachment(
            pageIndex: copy.pageIndex, kindName: copy.kindName,
            x: copy.x + 24, y: copy.y + 24, width: copy.width, height: copy.height,
            cornerRadius: copy.cornerRadius, label: copy.label,
            strokeColorHex: copy.strokeColorHex, fillColorHex: copy.fillColorHex,
            lineWidth: copy.lineWidth)
        copy.groupId = nil
        fresh.rotationDegrees = copy.rotationDegrees
        fresh.dashStyle = copy.dashStyle; fresh.fontSize = copy.fontSize
        fresh.textColorHex = copy.textColorHex; fresh.isBold = copy.isBold
        fresh.isItalic = copy.isItalic; fresh.opacity = copy.opacity
        notebook.shapeAttachments = (notebook.shapeAttachments ?? []) + [fresh]
        commitNotebook()
        PageThumbnailRenderer.invalidateAll()
        selectedShapeIds = [fresh.id]
        editingShapeId = fresh.id
    }

    func connectionBinding(for id: String) -> Binding<NoteConnectionAttachment> {
        let normId = id.lowercased()
        return Binding(
            get: {
                notebook.connectionAttachments?.first(where: { $0.id.lowercased() == normId })
                    ?? NoteConnectionAttachment(id: id, fromShapeId: "", toShapeId: "")
            },
            set: { updated in
                guard let index = notebook.connectionAttachments?
                    .firstIndex(where: { $0.id.lowercased() == normId }) else { return }
                notebook.connectionAttachments?[index] = updated
                commitNotebook()
                PageThumbnailRenderer.invalidateAll()
            }
        )
    }

    /// 從形狀的連接點拉線。拖曳中畫預覽，放開時連到底下的形狀。
    func handleConnectDrag(
        from sourceId: String, anchor: ShapeAnchorName,
        start: CGPoint, current: CGPoint, finished: Bool
    ) {
        guard let source = notebook.shapeAttachments?.first(where: { $0.id == sourceId }) else { return }
        guard finished else {
            connectionDraft = (source.pageIndex, start, current)
            return
        }
        connectionDraft = nil

        // 放開的位置在哪個形狀上。越晚畫的越在上面，所以從後往前找。
        let pageShapes = (notebook.shapeAttachments ?? []).filter {
            $0.pageIndex == source.pageIndex && $0.id != sourceId && !$0.isLinear
        }
        let target = pageShapes.reversed().first { candidate in
            // 轉過的形狀：把點轉回形狀自己的座標軸再判斷，才不會在轉 45° 的方塊邊角誤判。
            let local = ShapeFrameMath.rotate(current, about: candidate.center, degrees: -candidate.canvasRotation)
            return CGRect(x: candidate.x, y: candidate.y, width: candidate.width, height: candidate.height)
                .insetBy(dx: -6, dy: -6).contains(local)
        }
        guard let target else { return }
        // 入線位置：目標形狀上離放開點最近的連接點。
        let toAnchor = ShapeAnchorName.allCases.min {
            let a = target.anchorPoint($0), b = target.anchorPoint($1)
            return hypot(a.x - current.x, a.y - current.y) < hypot(b.x - current.x, b.y - current.y)
        } ?? .top

        var connection = NoteConnectionAttachment(
            pageIndex: source.pageIndex, fromShapeId: sourceId, toShapeId: target.id)
        connection.fromAnchor = anchor.rawValue
        connection.toAnchor = toAnchor.rawValue
        notebook.connectionAttachments = (notebook.connectionAttachments ?? []) + [connection]
        commitNotebook()
        PageThumbnailRenderer.invalidateAll()
        selectedShapeIds = []
        selectedConnectionId = connection.id
        if let data = try? JSONEncoder().encode(connection),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            collaborationManager.broadcastAttachmentUpsert(type: "connection", itemDict: dict)
        }
    }


    /// 對齊目前選取的物件。
    ///
    /// 幾何交給核心；這裡只負責「哪個 id 是哪個附件」與把新座標寫回去。
    /// id 由圖層面板給 —— 它才是多選發生的地方。
    /// 七種型別各有自己的陣列，所以搬移得逐型別處理 —— 但**順序必須與
    /// 傳給核心的矩形順序一致**，錯位的話每個物件會搬到別人的位置。
    func alignSelectedObjects(_ mode: FfiAlignMode, ids: [String]) {
        guard ids.count >= 2 else { return }

        // 收集矩形，順序即 ids 的順序。
        var rects: [CGRect] = []
        for id in ids {
            guard let rect = frameOfObject(id: id) else { return }
            rects.append(rect)
        }

        let origins = ObjectAlignment.aligned(rects: rects, mode: mode)
        guard origins.count == ids.count else { return }
        // 鎖定在畫布上的物件留在原地，只當對齊的基準。
        let locked = notebook.allLockedObjectIds
        for (id, origin) in zip(ids, origins) where !locked.contains(id.lowercased()) {
            moveObject(id: id, to: origin)
        }
        commitNotebook()
    }

    /// 某個物件目前的版面框（頁面座標）。
    func frameOfObject(id: String) -> CGRect? {
        let norm = id.lowercased()
        if let i = notebook.attachments?.first(where: { $0.id.lowercased() == norm }) {
            return CGRect(x: i.x, y: i.y, width: i.width, height: i.height)
        }
        if let i = notebook.shapeAttachments?.first(where: { $0.id.lowercased() == norm }) {
            return CGRect(x: i.x, y: i.y, width: i.width, height: i.height)
        }
        if let i = notebook.tableAttachments?.first(where: { $0.id.lowercased() == norm }) {
            return CGRect(x: i.x, y: i.y, width: i.width, height: i.height)
        }
        if let i = notebook.textAttachments?.first(where: { $0.id.lowercased() == norm }) {
            return CGRect(x: i.x, y: i.y, width: i.width, height: i.height)
        }
        if let i = notebook.linkAttachments?.first(where: { $0.id.lowercased() == norm }) {
            return CGRect(x: i.x, y: i.y, width: i.width, height: i.height)
        }
        if let i = notebook.model3DAttachments?.first(where: { $0.id.lowercased() == norm }) {
            return CGRect(x: i.x, y: i.y, width: i.width, height: i.height)
        }
        if let i = notebook.audioAttachments?.first(where: { $0.id.lowercased() == norm }) {
            return CGRect(x: i.x, y: i.y, width: i.width, height: i.height)
        }
        return nil
    }

    /// 把某個物件的左上角搬到指定座標（並夾回可列印區域，S-85）。
    func moveObject(id: String, to rawOrigin: CGPoint) {
        let size = frameOfObject(id: id)?.size ?? .zero
        let page = PageGeometry.size
        let inset = Float(PageGeometry.printableInset)
        let clamped = clampToPrintable(
            rect: FfiRect(
                minX: Float(rawOrigin.x), minY: Float(rawOrigin.y),
                maxX: Float(rawOrigin.x + size.width), maxY: Float(rawOrigin.y + size.height)),
            pageWidth: Float(page.width), pageHeight: Float(page.height), inset: inset)
        let origin = CGPoint(x: CGFloat(clamped.minX), y: CGFloat(clamped.minY))
        let norm = id.lowercased()

        if let index = notebook.attachments?.firstIndex(where: { $0.id.lowercased() == norm }) {
            notebook.attachments?[index].x = origin.x
            notebook.attachments?[index].y = origin.y
            return
        }
        if let index = notebook.shapeAttachments?.firstIndex(where: { $0.id.lowercased() == norm }) {
            notebook.shapeAttachments?[index].x = origin.x
            notebook.shapeAttachments?[index].y = origin.y
            return
        }
        if let index = notebook.tableAttachments?.firstIndex(where: { $0.id.lowercased() == norm }) {
            notebook.tableAttachments?[index].x = origin.x
            notebook.tableAttachments?[index].y = origin.y
            return
        }
        if let index = notebook.textAttachments?.firstIndex(where: { $0.id.lowercased() == norm }) {
            notebook.textAttachments?[index].x = origin.x
            notebook.textAttachments?[index].y = origin.y
            return
        }
        if let index = notebook.linkAttachments?.firstIndex(where: { $0.id.lowercased() == norm }) {
            notebook.linkAttachments?[index].x = origin.x
            notebook.linkAttachments?[index].y = origin.y
            return
        }
        if let index = notebook.model3DAttachments?.firstIndex(where: { $0.id.lowercased() == norm }) {
            notebook.model3DAttachments?[index].x = origin.x
            notebook.model3DAttachments?[index].y = origin.y
            return
        }
        if let index = notebook.audioAttachments?.firstIndex(where: { $0.id.lowercased() == norm }) {
            notebook.audioAttachments?[index].x = origin.x
            notebook.audioAttachments?[index].y = origin.y
        }
    }

    // MARK: - 框選

    /// 這一頁上每一個物件的位置與大小，給框選判定用。依堆疊順序由下到上排，
    /// 點選時才拿得到最上面那一個。
    var marqueeCandidates: [MarqueeHit] {
        marqueeCandidates(forPage: currentPageIndex)
    }

    func marqueeCandidates(forPage page: Int) -> [MarqueeHit] {
        let stacking = ObjectStacking.Lookup(order: notebook.objectOrder(forPage: page))
        let lockedIds = notebook.allLockedObjectIds
        return stackableObjects(forPage: page).compactMap { object -> MarqueeHit? in
            // 別人正在編輯的物件不能被框選帶著一起搬、一起刪（設計 §5.2）。
            // 鎖定在畫布上的物件也不框：框選帶著它一起搬，就不叫鎖定了。
            guard collaborationManager.leaseHolder(for: object.id) == nil,
                  !lockedIds.contains(object.id),
                  let frame = frameOfObject(id: object.id) else { return nil }
            return MarqueeHit(id: object.id, kind: object.kind, frame: frame)
        }
        .sorted { stacking.zIndex(for: $0.id, kind: $0.kind) < stacking.zIndex(for: $1.id, kind: $1.kind) }
    }

    /// 框選層：拉框、顯示選取外框、整組拖曳（支援單頁模式與連續頁面模式）。
    func marqueeLayer(forPage page: Int) -> some View {
        let candidates = marqueeCandidates(forPage: page)
        let selectionBounds = ObjectMarquee.bounds(of: selectedObjectIds, among: candidates)
        return ZStack(alignment: .topLeading) {
            // 這一層要吃掉觸控 —— 框選模式下畫布不捲、物件不動，
            // 只剩框選這一件事（見 ObjectMarquee 開頭的說明）。
            Color.black.opacity(0.001)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 2,
                                coordinateSpace: .named(CanvasCoordinateSpace.name))
                        .onChanged { value in
                            if pageDisplayMode == .continuous { focusContinuousPage(page) }
                            if let bounds = selectionBounds,
                               bounds.contains(value.startLocation) {
                                // 從選取範圍裡面開始拖＝搬整組。
                                groupDragOffset = value.translation
                            } else {
                                if marqueeStart == nil { marqueeStart = value.startLocation }
                                marqueeCurrent = value.location
                            }
                        }
                        .onEnded { value in
                            if groupDragOffset != .zero {
                                moveSelection(by: groupDragOffset)
                                groupDragOffset = .zero
                            } else if let start = marqueeStart {
                                let rect = ObjectMarquee.rect(from: start, to: value.location)
                                selectedObjectIds = ObjectMarquee.combined(
                                    selectedObjectIds,
                                    with: ObjectMarquee.hits(in: rect, among: candidates),
                                    additive: marqueeAdditive)
                            }
                            marqueeStart = nil
                            marqueeCurrent = nil
                        }
                )
                // 點物件＝選它（連續框選時切換加入／移除）；點空白＝取消選取（連續框選時保留）。
                .simultaneousGesture(
                    SpatialTapGesture(coordinateSpace: .named(CanvasCoordinateSpace.name))
                        .onEnded { value in
                            if pageDisplayMode == .continuous { focusContinuousPage(page) }
                            selectedObjectIds = ObjectMarquee.tapped(
                                ObjectMarquee.topmostHit(at: value.location, among: candidates),
                                existing: selectedObjectIds,
                                additive: marqueeAdditive)
                        }
                )

            // 每個被選中的物件畫一個外框。只畫一個大框的話，
            // 使用者看不出「到底選到了哪幾個」。
            ForEach(candidates.filter { selectedObjectIds.contains($0.id) }, id: \.id) { hit in
                Rectangle()
                    .stroke(Color.accentColor, lineWidth: 1.5)
                    .frame(width: hit.frame.width, height: hit.frame.height)
                    .offset(x: hit.frame.minX + groupDragOffset.width,
                            y: hit.frame.minY + groupDragOffset.height)
                    .allowsHitTesting(false)
            }

            // 拉框中的橡皮筋
            if page == currentPageIndex, let start = marqueeStart, let current = marqueeCurrent {
                let rect = ObjectMarquee.rect(from: start, to: current)
                Rectangle()
                    .fill(Color.accentColor.opacity(0.10))
                    .overlay(Rectangle().stroke(Color.accentColor, style: StrokeStyle(
                        lineWidth: 1, dash: [4, 3])))
                    .frame(width: rect.width, height: rect.height)
                    .offset(x: rect.minX, y: rect.minY)
                    .allowsHitTesting(false)
            }
        }
    }

    /// 進入／離開框選。
    ///
    /// # 框選選的是「物件」，不是筆跡
    ///
    /// 圖片、貼紙、文字方塊、表格、圖形、錄音卡片…這些是物件，框選一次可以整組
    /// 搬、複製、刪除。手寫的筆跡不是物件，要選它們用**套索**（手寫模式的筆具列）。
    /// 兩者分工：物件用框選、筆跡用套索。
    ///
    /// 手寫模式下物件本來就不吃觸控，框了也動不了，所以進入時自動切到打字模式
    /// （Android 一直是這樣做）。進入時說明怎麼操作，否則使用者面對一個空的選取列，
    /// 不知道下一步是什麼。
    func setMarqueeActive(_ on: Bool) {
        isMarqueeActive = on
        if on {
            transitionToMode(.type)
            showCanvasNotice(localizationManager.localized("marquee_hint"))
        } else {
            selectedObjectIds = []
            marqueeAdditive = false
        }
    }

    /// 框選模式的工具列。掛在畫布外面（工具列那一層），不隨畫布捲動 ——
    /// 跟著捲的話，選了下半頁的東西就得捲回去才按得到刪除。
    var marqueeToolbar: some View {
        HStack(spacing: 10) {
            Image(systemName: "square.dashed.inset.filled")
                .foregroundColor(.accentColor)
            if selectedObjectIds.isEmpty && isCompactEditorWidth {
                // 手機寬度不放說明句：它會把整排按鈕擠到畫面外（進入框選時已用浮動提示說過一次）。
                EmptyView()
            } else if selectedObjectIds.isEmpty {
                // 還沒選到東西時，顯示「怎麼選」而不是「已選 0 個」。
                Text(localizationManager.localized("marquee_hint"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            } else {
                Text(localizationManager.localized("marquee_selected")
                    .replacingOccurrences(of: "%@", with: "\(selectedObjectIds.count)"))
                    .font(.caption)
                    .monospacedDigit()
            }

            Divider().frame(height: 18)

            // 連續框選：一框一框累積，或點物件逐一加入／移除。
            Button {
                marqueeAdditive.toggle()
                if marqueeAdditive { showCanvasNotice(localizationManager.localized("marquee_continuous_hint")) }
            } label: {
                Label(localizationManager.localized("marquee_continuous"),
                      systemImage: marqueeAdditive ? "plus.square.fill.on.square.fill" : "plus.square.on.square")
            }
            .foregroundColor(marqueeAdditive ? .accentColor : .primary)
            .accessibilityIdentifier("editor.marquee.continuous")
            .accessibilityLabel(localizationManager.localized("marquee_continuous"))
            .accessibilityAddTraits(marqueeAdditive ? .isSelected : [])
            .help(localizationManager.localized("marquee_continuous_hint"))

            // 全選：這一頁所有物件一次選起來。
            Button {
                selectedObjectIds = Set(marqueeCandidates.map(\.id))
            } label: {
                Label(localizationManager.localized("select_all"), systemImage: "checkmark.square")
            }
            .disabled(marqueeCandidates.isEmpty)
            .accessibilityIdentifier("editor.marquee.select_all")

            Button {
                selectedObjectIds = []
            } label: {
                Label(localizationManager.localized("deselect_all"), systemImage: "square")
            }
            .disabled(selectedObjectIds.isEmpty)
            .accessibilityIdentifier("editor.marquee.deselect_all")

            Divider().frame(height: 18)

            Button {
                cutSelection()
            } label: {
                Label(localizationManager.localized("action_cut"), systemImage: "scissors")
            }
            .disabled(selectedObjectIds.isEmpty)
            .accessibilityIdentifier("editor.marquee.cut")

            Button {
                copySelection()
            } label: {
                Label(localizationManager.localized("action_copy"), systemImage: "doc.on.doc")
            }
            .disabled(selectedObjectIds.isEmpty)

            Button {
                pasteClipboard()
            } label: {
                Label(localizationManager.localized("action_paste"), systemImage: "doc.on.clipboard")
            }
            .disabled(objectClipboard.isEmpty && getClipboardImage() == nil)

            Button {
                isPlacingPasteObject = true
            } label: {
                Label(localizationManager.localized("paste_at_location"), systemImage: "hand.point.up.left.fill")
            }
            .disabled(objectClipboard.isEmpty)
            .accessibilityIdentifier("editor.marquee.paste_at_location")

            Button {
                duplicateSelection()
            } label: {
                Label(localizationManager.localized("action_duplicate"), systemImage: "plus.square.on.square")
            }
            .disabled(selectedObjectIds.isEmpty)

            Button(role: .destructive) {
                deleteSelection()
            } label: {
                Label(localizationManager.localized("action_delete"), systemImage: "trash")
            }
            .disabled(selectedObjectIds.isEmpty)

            Divider().frame(height: 18)

            Button {
                setMarqueeActive(false)
            } label: {
                Label(localizationManager.localized("done"), systemImage: "checkmark")
            }
        }
        .font(.caption)
        // 手機寬度只放圖示（名稱仍是無障礙標籤），一排放得下全部的動作。
        .labelStyle(MarqueeLabelStyle(compact: isCompactEditorWidth))
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
    }

    // MARK: - 框選與單一物件剪貼簿批次操作

    @ViewBuilder
    var editorKeyboardShortcuts: some View {
        Group {
            Button("") {
                if !effectiveSelectedObjectIds.isEmpty && inlineEditingTextId == nil {
                    deleteSelection()
                } else {
                    deleteSelectedStrokes()
                }
            }
            .keyboardShortcut(.delete, modifiers: [])

            Button("") {
                if !effectiveSelectedObjectIds.isEmpty && inlineEditingTextId == nil {
                    deleteSelection()
                } else {
                    deleteSelectedStrokes()
                }
            }
            .keyboardShortcut(.deleteForward, modifiers: [])

            Button("") {
                guard inlineEditingTextId == nil else { return }
                if selectedTool == .lasso && lasso.hasSelection {
                    cutSelectedStrokes()
                } else if !effectiveSelectedObjectIds.isEmpty {
                    cutSelection()
                }
            }
            .keyboardShortcut("x", modifiers: .command)

            Button("") {
                guard inlineEditingTextId == nil else { return }
                if selectedTool == .lasso && lasso.hasSelection {
                    copySelectedStrokes()
                } else if !effectiveSelectedObjectIds.isEmpty {
                    copySelection()
                }
            }
            .keyboardShortcut("c", modifiers: .command)

            Button("") {
                pasteClipboard()
            }
            .keyboardShortcut("v", modifiers: .command)
        }
        .opacity(0)
        .allowsHitTesting(false)
    }

    /// 目前被選取的物件 ID 集合（涵蓋框選、多選形狀、單點選取或開啟屬性面板的物件）。
    var effectiveSelectedObjectIds: Set<String> {
        if !selectedObjectIds.isEmpty { return selectedObjectIds }
        if !selectedShapeIds.isEmpty { return selectedShapeIds }
        if let active = activeSelectedObjectId { return [active] }
        if let table = editingTable { return [table.id] }
        if let shapeId = editingShapeId { return [shapeId] }
        if let attId = editingAttachmentId { return [attId] }
        if let textId = editingTextId { return [textId] }
        return []
    }

    /// 供所有物件右鍵／長按選單與屬性面板使用的剪下、複製、建立副本動作。
    var objectClipboardActions: ObjectClipboardActions {
        ObjectClipboardActions(
            cut: { id in cutObject(id: id) },
            copy: { id in copyObject(id: id) },
            duplicate: { id in duplicateObject(id: id) }
        )
    }

    func moveSelection(by delta: CGSize) {
        guard !selectedObjectIds.isEmpty, delta != .zero else { return }
        for id in selectedObjectIds {
            guard let frame = frameOfObject(id: id) else { continue }
            moveObject(id: id, to: CGPoint(x: frame.minX + delta.width,
                                           y: frame.minY + delta.height))
        }
        commitNotebook()
        continuousObjectGeneration += 1
    }

    func copySelection() {
        let ids = effectiveSelectedObjectIds
        guard !ids.isEmpty else { return }
        objectClipboard = ids.compactMap(clipboardObject(forId:))
        isPlacingPasteObject = false
        showCanvasNotice(localizationManager.localized("object_copied_hint"))
    }

    func cutSelection() {
        let ids = effectiveSelectedObjectIds
        guard !ids.isEmpty else { return }
        objectClipboard = ids.compactMap(clipboardObject(forId:))
        isPlacingPasteObject = false
        deleteObjects(ids: ids)
        showCanvasNotice(localizationManager.localized("object_cut_hint"))
    }

    func copyObject(id: String) {
        if selectedObjectIds.contains(id) && selectedObjectIds.count > 1 {
            copySelection()
            return
        }
        guard let obj = clipboardObject(forId: id) else { return }
        objectClipboard = [obj]
        isPlacingPasteObject = false
        showCanvasNotice(localizationManager.localized("object_copied_hint"))
    }

    func cutObject(id: String) {
        if selectedObjectIds.contains(id) && selectedObjectIds.count > 1 {
            cutSelection()
            return
        }
        guard let obj = clipboardObject(forId: id) else { return }
        objectClipboard = [obj]
        isPlacingPasteObject = false
        deleteObjects(ids: [id])
        showCanvasNotice(localizationManager.localized("object_cut_hint"))
    }

    func duplicateObject(id: String) {
        if selectedObjectIds.contains(id) && selectedObjectIds.count > 1 {
            duplicateSelection()
            return
        }
        guard let obj = clipboardObject(forId: id) else { return }
        let targetPage = pageOfObject(id) ?? currentPageIndex
        paste([obj], onPage: targetPage, at: nil)
    }

    func duplicateSelection() {
        let ids = effectiveSelectedObjectIds
        let copies = ids.compactMap(clipboardObject(forId:))
        paste(copies, onPage: currentPageIndex, at: nil)
    }

    func pasteClipboard() {
        if selectedTool == .lasso && lasso.canPaste {
            pasteStrokes()
        } else if !objectClipboard.isEmpty {
            paste(objectClipboard, onPage: currentPageIndex, at: nil)
        } else if let image = getClipboardImage() {
            insertImageAttachment(image)
            showNoticeToast(name: localizationManager.localized("screenshot_pasted"), icon: "checkmark.circle.fill")
        }
    }

    /// 貼上一組物件到指定頁面與指定座標（`targetPoint == nil` 為預設偏移貼上，有值則將物件中心對齊該座標）。
    /// **每一個都給新的 id** —— 沿用原 id 的話，兩份物件會共用同一筆資料，拖其中一個另一個也會跟著動。
    func paste(
        _ objects: [ClipboardObject],
        onPage targetPage: Int? = nil,
        at targetPoint: CGPoint? = nil
    ) {
        guard !objects.isEmpty else { return }
        let page = targetPage ?? currentPageIndex
        let instantiated = ObjectMarquee.pasted(objects, onPage: page, at: targetPoint)
        var pastedIds: Set<String> = []
        var singleShapeId: String? = nil
        var singleNonShapeId: String? = nil

        for object in instantiated {
            switch object {
            case .image(let copy):
                notebook.attachments = (notebook.attachments ?? []) + [copy]
                pastedIds.insert(copy.id)
                singleNonShapeId = copy.id
                if let data = try? JSONEncoder().encode(copy),
                   let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    collaborationManager.broadcastAttachmentUpsert(type: "image", itemDict: dict)
                }
            case .text(let copy):
                notebook.textAttachments = (notebook.textAttachments ?? []) + [copy]
                pastedIds.insert(copy.id)
                singleNonShapeId = copy.id
                if let data = try? JSONEncoder().encode(copy),
                   let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    collaborationManager.broadcastAttachmentUpsert(type: "text", itemDict: dict)
                }
            case .table(let copy):
                notebook.tableAttachments = (notebook.tableAttachments ?? []) + [copy]
                pastedIds.insert(copy.id)
                singleNonShapeId = copy.id
                if let data = try? JSONEncoder().encode(copy),
                   let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    collaborationManager.broadcastAttachmentUpsert(type: "table", itemDict: dict)
                }
            case .shape(let copy):
                notebook.shapeAttachments = (notebook.shapeAttachments ?? []) + [copy]
                pastedIds.insert(copy.id)
                singleShapeId = copy.id
                if let data = try? JSONEncoder().encode(copy),
                   let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    collaborationManager.broadcastAttachmentUpsert(type: "shape", itemDict: dict)
                }
            case .link(let copy):
                notebook.linkAttachments = (notebook.linkAttachments ?? []) + [copy]
                pastedIds.insert(copy.id)
                singleNonShapeId = copy.id
            case .model3D(let copy):
                notebook.model3DAttachments = (notebook.model3DAttachments ?? []) + [copy]
                pastedIds.insert(copy.id)
                singleNonShapeId = copy.id
                if let data = try? JSONEncoder().encode(copy),
                   let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    collaborationManager.broadcastAttachmentUpsert(type: "3d", itemDict: dict)
                }
            case .audio(let copy):
                notebook.audioAttachments = (notebook.audioAttachments ?? []) + [copy]
                pastedIds.insert(copy.id)
                singleNonShapeId = copy.id
            }
        }

        if pageDisplayMode == .continuous {
            focusContinuousPage(page)
        } else {
            switchToPage(page)
        }
        commitNotebook()
        continuousObjectGeneration += 1
        thumbnailRevision += 1

        // 貼上之後選取新的那一份，接著就能直接再拖一次（手繪與打字模式下皆生效）。
        selectedObjectIds = pastedIds
        if pastedIds.count == 1 {
            if let sid = singleShapeId {
                selectedShapeIds = [sid]
                activeSelectedObjectId = nil
            } else if let oid = singleNonShapeId {
                selectedShapeIds = []
                activeSelectedObjectId = oid
            }
        }
    }

    func deleteSelection() {
        let ids = effectiveSelectedObjectIds
        guard !ids.isEmpty else { return }
        deleteObjects(ids: ids)
    }

    func deleteObjects(ids: Set<String>) {
        guard !ids.isEmpty else { return }
        for id in ids {
            if (notebook.attachments ?? []).contains(where: { $0.id == id }) {
                collaborationManager.broadcastAttachmentDelete(id: id, type: "image")
            }
            if (notebook.textAttachments ?? []).contains(where: { $0.id == id }) {
                collaborationManager.broadcastAttachmentDelete(id: id, type: "text")
            }
            if (notebook.model3DAttachments ?? []).contains(where: { $0.id == id }) {
                collaborationManager.broadcastAttachmentDelete(id: id, type: "3d")
            }
            if (notebook.tableAttachments ?? []).contains(where: { $0.id == id }) {
                collaborationManager.broadcastAttachmentDelete(id: id, type: "table")
            }
        }
        notebook.attachments?.removeAll { ids.contains($0.id) }
        notebook.textAttachments?.removeAll { ids.contains($0.id) }
        notebook.tableAttachments?.removeAll { ids.contains($0.id) }
        notebook.linkAttachments?.removeAll { ids.contains($0.id) }
        notebook.model3DAttachments?.removeAll { ids.contains($0.id) }
        notebook.audioAttachments?.removeAll { ids.contains($0.id) }
        notebook.commentPins?.removeAll { ids.contains($0.id) }
        // 形狀連同它的連接線一起刪 —— 只刪形狀的話，線會留在畫布上，
        // 兩端各指著一個不存在的東西。
        notebook.shapeAttachments?.removeAll { ids.contains($0.id) }
        notebook.connectionAttachments?.removeAll {
            ids.contains($0.fromShapeId) || ids.contains($0.toShapeId)
        }
        selectedObjectIds.subtract(ids)
        selectedShapeIds.subtract(ids)
        if let active = activeSelectedObjectId, ids.contains(active) { activeSelectedObjectId = nil }
        if let editing = editingAttachmentId, ids.contains(editing) { editingAttachmentId = nil }
        if let editing = editingTextId, ids.contains(editing) { editingTextId = nil }
        if let editing = inlineEditingTextId, ids.contains(editing) { inlineEditingTextId = nil }
        if let editing = editingShapeId, ids.contains(editing) { editingShapeId = nil }
        if let editing = editingTable?.id, ids.contains(editing) { editingTable = nil }
        commitNotebook()
        continuousObjectGeneration += 1
        thumbnailRevision += 1
    }

    func clipboardObject(forId id: String) -> ClipboardObject? {
        if let item = notebook.attachments?.first(where: { $0.id == id }) { return .image(item) }
        if let item = notebook.textAttachments?.first(where: { $0.id == id }) { return .text(item) }
        if let item = notebook.tableAttachments?.first(where: { $0.id == id }) { return .table(item) }
        if let item = notebook.shapeAttachments?.first(where: { $0.id == id }) { return .shape(item) }
        if let item = notebook.linkAttachments?.first(where: { $0.id == id }) { return .link(item) }
        if let item = notebook.model3DAttachments?.first(where: { $0.id == id }) { return .model3D(item) }
        if let item = notebook.audioAttachments?.first(where: { $0.id == id }) { return .audio(item) }
        return nil
    }

    /// 目前模式的徽章：這個模式下筆會不會畫線、物件拖不拖得動。
    /// 讓模式徽章亮起，並排程淡出。
    func flashModeBadge() {
        modeBadgeToken += 1
        let token = modeBadgeToken
        modeBadgeVisible = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            // 這段期間又切過模式的話，token 對不上，就讓後來那一次決定。
            if token == modeBadgeToken { modeBadgeVisible = false }
        }
    }

    var modeBadge: some View {
        let isDraw = editorMode == .draw
        return HStack(spacing: 7) {
            Image(systemName: isDraw ? "pencil.tip" : "keyboard.fill")
                .font(.caption)
                .foregroundColor(isDraw ? .orange : .accentColor)
            VStack(alignment: .leading, spacing: 1) {
                Text(localizationManager.localized(isDraw ? "mode_draw_badge" : "mode_type_badge"))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Text(localizationManager.localized(isDraw ? "mode_draw_hint" : "mode_type_hint"))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .frame(maxWidth: 330, alignment: .leading)
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke((isDraw ? Color.orange : Color.accentColor).opacity(0.35), lineWidth: 1)
        )
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.12), radius: 5, y: 2)
        // 徽章是狀態顯示，不是按鈕 —— 吃掉觸控的話，它蓋住的那塊畫布
        // 就寫不了字，而使用者看不出是被什麼擋住的。
        .allowsHitTesting(false)
    }

    /// 文字編修、圖片編修、圖層三張浮動面板。
    ///
    /// **掛在 `canvasWorkArea`（兩種頁面模式共用的那一層），而且層級最高。**
    ///
    /// 這三張面板原本各自藏在畫布內部的 ZStack 裡，沒有 zIndex：
    /// - 手寫模式下 PencilKit 畫布（zIndex 2）蓋在它上面，點關閉鈕變成在
    ///   畫布上畫了一筆；
    /// - 打字模式下全頁的文字輸入層（zIndex 2）與物件層（zIndex 3）也在它上面；
    /// - 連續頁面模式根本不會走到那一段程式，編輯鈕按了完全沒有反應。
    /// 症狀分別是「編輯視窗出現了卻關不掉」與「編輯鈕沒作用」。
    @ViewBuilder
    var objectEditPanels: some View {
        ZStack(alignment: .topTrailing) {
        // 🌟 文字編修浮動面板
        //
        // 以前是 modal sheet，蓋住整個畫布 —— 要調一個文字方塊的排版，
        // 卻看不到那個文字方塊。與圖片美化面板同樣的問題、同樣的解法：
        // 浮在畫布上、標題列可以拖到一旁，改動直接反映在物件上。
        if let id = editingTextId {
            FloatingPanel(
                title: localizationManager.localized("text_studio"),
                onClose: { editingTextId = nil }
            ) {
                VStack(spacing: 10) {
                    ObjectOrderBar(id: id)
                    WordTextStudioView(
                        attachment: wholeBoxBinding(forTextId: id),
                        presentation: .inlinePanel
                    ) { updated in
                        if let idx = notebook.textAttachments?.firstIndex(where: { $0.id == id }) {
                            notebook.textAttachments?[idx] = updated
                            commitNotebook()
                        }
                    }
                }
            }
            .padding(.top, 24)
            .padding(.trailing, 24)
            .transition(.scale(scale: 0.95).combined(with: .opacity))
        }

        // 🌟 圖片美化浮動面板
        //
        // 以前是 modal sheet，蓋住整個畫布 —— 調濾鏡時看不到自己在調
        // 什麼。改成浮在畫布上、標題列可拖到一旁的面板：控制項與圖片
        // 同時在畫面上，改動直接反映在物件上。
        if let id = editingAttachmentId {
            FloatingPanel(
                title: localizationManager.localized("image_beautify"),
                onClose: { editingAttachmentId = nil }
            ) {
                VStack(spacing: 10) {
                    ObjectOrderBar(id: id)
                    // 這張圖如果是數字製圖，先給重新編修的入口 ——
                    // 濾鏡與邊框改不了圖表裡的數字。
                    if let spec = notebook.attachments?
                        .first(where: { $0.id == id })?.chartSpec {
                        Button {
                            editingChartAttachmentId = ChartEditTarget(id: id, spec: spec)
                        } label: {
                            Label(localizationManager.localized("chart_edit"),
                                  systemImage: "chart.bar.xaxis")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }

                    // 這張圖如果是算式卡片，提供回到計算機重新求值的入口
                    if let formula = notebook.attachments?
                        .first(where: { $0.id == id })?.mathFormula {
                        Button {
                            editingMathAttachmentId = MathEditTarget(id: id, formula: formula)
                        } label: {
                            Label(localizationManager.localized("math_calc"),
                                  systemImage: "function")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }

                    ImageEditControls(
                        attachment: binding(for: id),
                        onDone: { editingAttachmentId = nil },
                        onDelete: {
                            notebook.attachments?.removeAll { $0.id == id }
                            commitNotebook()
                            editingAttachmentId = nil
                        }
                    )
                }
            }
        }


        // 形狀編修面板。與圖片、文字同一套 —— 浮在畫布上，改動即時反映在物件上。
        if let id = editingShapeId,
           notebook.shapeAttachments?.contains(where: { $0.id == id }) == true {
            FloatingPanel(
                title: localizationManager.localized("shape_edit"),
                onClose: { editingShapeId = nil }
            ) {
                ShapeEditPanel(
                    shape: shapeBinding(for: id),
                    onDuplicate: { duplicateShape(id) },
                    onDelete: { deleteShape(id) }
                )
            }
            .padding(.top, 24)
            .padding(.trailing, 24)
            .transition(.scale(scale: 0.95).combined(with: .opacity))
        }

        if let id = editingConnectionId,
           notebook.connectionAttachments?.contains(where: { $0.id == id }) == true {
            FloatingPanel(
                title: localizationManager.localized("connection_edit"),
                onClose: { editingConnectionId = nil }
            ) {
                ConnectionEditPanel(
                    connection: connectionBinding(for: id),
                    onDelete: { deleteConnection(id) }
                )
            }
            .padding(.top, 24)
            .padding(.trailing, 24)
            .transition(.scale(scale: 0.95).combined(with: .opacity))
        }

        if showLayerPanel {
            FloatingPanel(
                title: localizationManager.localized("layers_panel"),
                onClose: { showLayerPanel = false }
            ) {
                VStack(spacing: 10) {
                    // 跨型別的堆疊：圖片、文字、表格、圖表、3D、連結、
                    // 形狀全部在同一份順序裡。使用者要的「圖層上下排序」
                    // 指的是這個 —— 底下那個只認形狀。
                    CanvasStackPanel(
                        objects: pageStackableObjects,
                        order: Binding(
                            get: {
                                ObjectStacking.normalized(
                                    objects: pageStackableObjects,
                                    order: notebook.objectOrder(forPage: currentPageIndex)
                                )
                            },
                            set: { updated in
                                // **只寫這一頁。** 整個欄位覆蓋掉的話，在第 2 頁
                                // 調一次順序，第 1 頁的順序就被清光了 ——
                                // 那是 v3.8.0 (32) 已經出貨的 bug。
                                notebook.setObjectOrder(updated, forPage: currentPageIndex)
                                commitNotebook()
                            }
                        ),
                        selection: $selectedShapeIds,
                        onAlign: { mode, ids in alignSelectedObjects(mode, ids: ids) }
                    )

                    // 形狀的群組操作留在原本的面板 —— 群組是形狀專屬的
                    // 概念（連接線要接得住），其餘型別沒有這回事。
                    if !pageShapes.isEmpty {
                        Divider()
                        ObjectLayerPanel(
                            shapes: Binding(
                                get: { pageShapes },
                                set: { updated in replacePageShapes(with: updated) }
                            ),
                            selection: $selectedShapeIds,
                            groupingOnly: true
                        )
                    }
                }
            }
            .padding(.top, 24)
            .padding(.trailing, 24)
            .transition(.scale(scale: 0.95).combined(with: .opacity))
        }


        }
        .environment(\.objectReorder, { id, op in reorderObject(id, op) })
        .environment(\.objectLock, objectLockActions)
        .environment(\.objectClipboard, objectClipboardActions)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .zIndex(10_000)
    }

    /// 物件所在的頁面。找不到（已刪除）回傳 nil。
    func pageOfObject(_ id: String) -> Int? {
        let norm = id.lowercased()
        if let v = notebook.attachments?.first(where: { $0.id.lowercased() == norm }) { return v.pageIndex }
        if let v = notebook.shapeAttachments?.first(where: { $0.id.lowercased() == norm }) { return v.pageIndex }
        if let v = notebook.tableAttachments?.first(where: { $0.id.lowercased() == norm }) { return v.pageIndex }
        if let v = notebook.textAttachments?.first(where: { $0.id.lowercased() == norm }) { return v.pageIndex }
        if let v = notebook.linkAttachments?.first(where: { $0.id.lowercased() == norm }) { return v.pageIndex }
        if let v = notebook.model3DAttachments?.first(where: { $0.id.lowercased() == norm }) { return v.pageIndex }
        if let v = notebook.audioAttachments?.first(where: { $0.id.lowercased() == norm }) { return v.pageIndex }
        if let v = notebook.commentPins?.first(where: { $0.id.lowercased() == norm }) { return v.pageIndex }
        return nil
    }

    /// 物件選單、編輯面板、圖層面板共用的「鎖定在畫布上」。
    var objectLockActions: ObjectLockActions {
        ObjectLockActions(
            isLocked: { id in notebook.allLockedObjectIds.contains(id.lowercased()) },
            setLocked: { id, locked in setObjectLocked(id, locked) })
    }

    /// 這張圖是不是「底稿」：鎖定、在筆跡下方、而且撐滿頁寬或頁高（匯入的 PDF 頁面就是這樣放的）。
    ///
    /// 打字模式點底稿是要在上面打字，不是選取那張整頁的圖；要編修它先從圖層面板解除鎖定。
    /// 其餘鎖定的圖片照常點得到、選得起來（鎖定只鎖位置）。
    func isLockedBackdrop(_ id: String, page: Int) -> Bool {
        guard notebook.allLockedObjectIds.contains(id.lowercased()),
              notebook.underInkObjectIds(forPage: page).contains(id),
              let image = notebook.attachments?.first(where: { $0.id == id }) else { return false }
        return image.width >= PageGeometry.width * 0.9 || image.height >= PageGeometry.height * 0.9
    }

    /// 點在哪一個鎖定物件上（最上層的那一個）。沒有回 nil。
    func lockedObjectHit(at point: CGPoint, page: Int) -> String? {
        let locked = notebook.allLockedObjectIds
        guard !locked.isEmpty else { return nil }
        let stacking = ObjectStacking.Lookup(order: notebook.objectOrder(forPage: page))
        return stackableObjects(forPage: page)
            .filter { locked.contains($0.id.lowercased()) }
            .sorted { stacking.zIndex(for: $0.id, kind: $0.kind) > stacking.zIndex(for: $1.id, kind: $1.kind) }
            // 放寬 20pt：角落的鎖頭露在物件外面，點鎖頭也要算點到它。
            .first { frameOfObject(id: $0.id)?.insetBy(dx: -20, dy: -20).contains(point) == true }?
            .id
    }

    /// 每個鎖定物件右上角的鎖頭（頁面座標，依物件的實際外框放）。不分模式都畫：
    /// 看得到的鎖定物件，一定要看得出它鎖住了、也知道從哪裡解。
    /// 手寫模式下物件層不吃觸控，手指點鎖頭會落到畫布上，由 `handleCanvasDirectTap` 接住（同樣給解鎖鈕）。
    @ViewBuilder
    func lockedObjectBadges(forPage page: Int) -> some View {
        let locked = notebook.allLockedObjectIds
        if !locked.isEmpty {
            ForEach(stackableObjects(forPage: page).filter { locked.contains($0.id.lowercased()) }, id: \.id) { object in
                if let frame = frameOfObject(id: object.id) {
                    LockedObjectBadge {
                        lockPromptId = (lockPromptId?.caseInsensitiveCompare(object.id) == .orderedSame) ? nil : object.id
                    }
                    .position(x: frame.maxX, y: frame.minY)
                    .zIndex(9_700)
                }
            }
        }
    }

    /// 鎖定物件上方的「解除鎖定」鈕（頁面座標，畫在物件層裡）。
    @ViewBuilder
    func lockedObjectPrompt(forPage page: Int) -> some View {
        if let id = lockPromptId, pageOfObject(id) == page,
           notebook.allLockedObjectIds.contains(id.lowercased()), let frame = frameOfObject(id: id) {
            Button {
                setObjectLocked(id, false)
                lockPromptId = nil
            } label: {
                Label(localizationManager.localized("object_unlock"), systemImage: "lock.open.fill")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.orange))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("object.unlock.prompt")
            .position(x: frame.midX, y: max(16, frame.minY - 20))
            .zIndex(9_800)
        }
    }

    /// 鎖定／解除鎖定一個物件。
    ///
    /// 鎖定只鎖位置：選取與編輯面板都留著，內容照樣能改；搬移、縮放、旋轉的把手由物件自己
    /// 依 `canvasObjectLocked` 收起來。唯一要收的是框選 —— 框選帶著它整組搬，就不叫鎖定了。
    func setObjectLocked(_ id: String, _ locked: Bool) {
        let normId = id.lowercased()
        guard notebook.allLockedObjectIds.contains(normId) != locked else { return }
        if locked {
            guard let page = pageOfObject(normId) else { return }
            notebook.setLockedObjectIds(notebook.lockedObjectIds(forPage: page).union([normId]), forPage: page)
        } else {
            // 解除時每一頁都拿掉：頁面搬移過的話，它記在哪個頁次鍵底下不一定是現在這一頁。
            for key in (notebook.lockedObjectIdsByPage ?? [:]).keys {
                guard let page = Int(key) else { continue }
                notebook.setLockedObjectIds(notebook.lockedObjectIds(forPage: page).subtracting([normId]), forPage: page)
            }
        }
        if locked {
            selectedObjectIds.remove(id)
            selectedObjectIds.remove(normId)
        }
        if lockPromptId?.lowercased() == normId { lockPromptId = nil }
        commitNotebook()
        // 只重建物件層：重建畫布會整頁白一下，寫到一半的筆畫也會不見。
        continuousObjectGeneration += 1
    }

    /// 調整單一物件的層級（選單、編輯面板共用，支援移至筆跡下方/上方）。
    func reorderObject(_ id: String, _ op: ObjectReorderOp) {
        guard let page = pageOfObject(id) else { return }
        switch op {
        case .sendBelowInk:
            if !notebook.underInkObjectIds(forPage: page).contains(id) {
                notebook.moveObjects([id], to: .belowInk, forPage: page)
                commitNotebook()
                PageThumbnailRenderer.invalidateAll()
            }
        case .bringAboveInk:
            if notebook.underInkObjectIds(forPage: page).contains(id) {
                notebook.moveObjects([id], to: .aboveInk, forPage: page)
                commitNotebook()
                PageThumbnailRenderer.invalidateAll()
            }
        case .toFront:
            if notebook.underInkObjectIds(forPage: page).contains(id) {
                notebook.moveObjects([id], to: .aboveInk, forPage: page)
            }
            let order = ObjectStacking.normalized(
                objects: stackableObjects(forPage: page),
                order: notebook.objectOrder(forPage: page))
            notebook.setObjectOrder(op.apply(id, to: order), forPage: page)
            commitNotebook()
            PageThumbnailRenderer.invalidateAll()
        case .toBack:
            if !notebook.underInkObjectIds(forPage: page).contains(id) {
                notebook.moveObjects([id], to: .belowInk, forPage: page)
            }
            let order = ObjectStacking.normalized(
                objects: stackableObjects(forPage: page),
                order: notebook.objectOrder(forPage: page))
            notebook.setObjectOrder(op.apply(id, to: order), forPage: page)
            commitNotebook()
            PageThumbnailRenderer.invalidateAll()
        default:
            let order = ObjectStacking.normalized(
                objects: stackableObjects(forPage: page),
                order: notebook.objectOrder(forPage: page))
            notebook.setObjectOrder(op.apply(id, to: order), forPage: page)
            commitNotebook()
            PageThumbnailRenderer.invalidateAll()
        }
        continuousObjectGeneration += 1
        thumbnailRevision += 1
    }

    /// 這本筆記上所有物件的 id（不含連接線）。用來偵測「新插入了什麼」。
    var allObjectIds: [String] {
        var ids: [String] = []
        ids += (notebook.attachments ?? []).map(\.id)
        ids += (notebook.shapeAttachments ?? []).map(\.id)
        ids += (notebook.tableAttachments ?? []).map(\.id)
        ids += (notebook.textAttachments ?? []).map(\.id)
        ids += (notebook.linkAttachments ?? []).map(\.id)
        ids += (notebook.model3DAttachments ?? []).map(\.id)
        ids += (notebook.audioAttachments ?? []).map(\.id)
        return ids
    }

    /// **新插入的物件一律放在最上層。**
    ///
    /// 沒有明確順序的物件，疊放次序由「型別的預設層級」決定 —— 圖片永遠
    /// 在文字、表格之下，於是新貼的圖片被舊的文字蓋住，看起來像沒插進去。
    /// 這裡掛在「物件數量變了」這一個點上，而不是改每一個插入路徑：
    /// 本機插入、匯入、範本、協同遠端寫入全部會經過同一處，不會漏。
    func placeNewObjectsOnTop() {
        let ids = allObjectIds
        defer { knownObjectIds = Set(ids) }
        guard let known = knownObjectIds else { return }
        let fresh = ids.filter { !known.contains($0) }
        guard !fresh.isEmpty else { return }

        var byPage: [Int: [String]] = [:]
        for id in fresh {
            if let page = pageOfObject(id) { byPage[page, default: []].append(id) }
        }
        for (page, newIds) in byPage {
            let newSet = Set(newIds)
            let existing = stackableObjects(forPage: page).filter { !newSet.contains($0.id) }
            var order = ObjectStacking.normalized(
                objects: existing, order: notebook.objectOrder(forPage: page))
            order += newIds   // 到達順序＝插入順序
            notebook.setObjectOrder(order, forPage: page)
        }
        commitNotebook()

        // 手寫模式下物件不吃觸控：剛插進來的東西會拖不動、選不起來，看起來像插壞了
        // （使用者回報「形狀無法編輯」「圖片的編輯鈕沒有作用」的一個原因）。
        // 本機插入就切到打字模式，與 Android 同一條規則；遠端協同寫進來的不切，
        // 別人插東西不該把我的筆搶走。
        if editorMode == .draw && !isApplyingRemoteUpdate && !isCollaborating {
            transitionToMode(.type)
        }
    }

    /// 這一頁上所有可堆疊的物件，跨七種型別收成同一份清單。
    ///
    /// 名字取得出來就用內容（文字方塊取內文、形狀取標籤），取不出來就用型別名
    /// —— 面板上一整排「未命名」的話，使用者分不出哪一列是哪一個。
    var pageStackableObjects: [StackableObject] {
        stackableObjects(forPage: currentPageIndex)
    }

    /// 指定頁面上的所有可堆疊物件。連續模式下每一頁各有自己的順序，
    /// 不能只認焦點頁。
    func stackableObjects(forPage page: Int) -> [StackableObject] {
        let unnamed = localizationManager.localized("layer_unnamed")
        func title(_ raw: String, _ fallbackKey: String) -> String {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return localizationManager.localized(fallbackKey) }
            return String(trimmed.prefix(24))
        }

        var result: [StackableObject] = []
        for item in (notebook.attachments ?? []) where item.pageIndex == page {
            result.append(.init(id: item.id, kind: .image,
                                title: localizationManager.localized("layer_kind_image")))
        }
        for item in (notebook.shapeAttachments ?? []) where item.pageIndex == page {
            result.append(.init(id: item.id, kind: .shape,
                                title: title(item.label, "layer_kind_shape")))
        }
        for item in (notebook.tableAttachments ?? []) where item.pageIndex == page {
            result.append(.init(id: item.id, kind: .table,
                                title: localizationManager.localized("layer_kind_table")))
        }
        for item in (notebook.textAttachments ?? []) where item.pageIndex == page {
            result.append(.init(id: item.id, kind: .text,
                                title: title(item.text, "layer_kind_text")))
        }
        for item in (notebook.linkAttachments ?? []) where item.pageIndex == page {
            result.append(.init(id: item.id, kind: .link,
                                title: title(item.title.isEmpty ? item.urlString : item.title, "layer_kind_link")))
        }
        for item in (notebook.model3DAttachments ?? []) where item.pageIndex == page {
            result.append(.init(id: item.id, kind: .model3D,
                                title: localizationManager.localized("layer_kind_model3d")))
        }
        for item in (notebook.audioAttachments ?? []) where item.pageIndex == page {
            result.append(.init(id: item.id, kind: .audio,
                                title: title(item.title, "layer_kind_audio")))
        }
        for pin in (notebook.commentPins ?? []) where pin.pageIndex == page {
            result.append(.init(id: pin.id, kind: .pin,
                                title: localizationManager.localized("layer_kind_pin")))
        }
        _ = unnamed
        return result
    }

    /// 換掉這一頁的形狀，其餘頁面原封不動。
    ///
    /// 陣列順序就是堆疊順序，所以整段換掉是必要的 —— 只改個別元素的話，
    /// 圖層面板調的順序不會反映到畫布上。
    func replacePageShapes(with updated: [NoteShapeAttachment]) {
        var others = (notebook.shapeAttachments ?? []).filter { $0.pageIndex != currentPageIndex }
        others.append(contentsOf: updated)
        notebook.shapeAttachments = others
        commitNotebook()
    }

    func toggleShapeSelection(_ id: String) {
        // 選到群組裡的一個就整組選起來 —— 那正是群組的意義。
        // 形狀被選取時，其他種類的物件一律退出編輯狀態（畫布上同時最多一個待編輯物件）。
        activeSelectedObjectId = nil
        if inlineEditingTextId != nil { inlineEditingTextId = nil }
        let mates = ObjectLayerOps.groupMates(of: id, in: pageShapes)
        if mates.isSubset(of: selectedShapeIds) {
            selectedShapeIds.subtract(mates)
        } else {
            selectedShapeIds = mates
        }
    }

    /// 選取單一物件（圖片、文字、表格、連結、錄音、3D）。
    /// 先前被選取的物件（包括形狀、連接線、就地編輯中的文字）自動退出編輯狀態。
    func selectSingleObject(_ id: String, keepInlineText: Bool = false) {
        activeSelectedObjectId = id
        selectedShapeIds = []
        selectedConnectionId = nil
        selectedObjectIds = []
        if !keepInlineText, inlineEditingTextId != nil, inlineEditingTextId != id {
            inlineEditingTextId = nil
        }
        collaborationManager.broadcastSelection(selectedId: id)
    }

    /// 拖曳一個形狀時，同一組的其他成員要跟著走。
    ///
    /// 不跟的話，群組起來的流程圖一拖就散開了。
    func moveShapeGroup(_ id: String, by delta: CGSize) {
        guard var all = notebook.shapeAttachments,
              let page = all.first(where: { $0.id == id })?.pageIndex else { return }
        // 同組成員以**這個形狀所在的頁**來找：連續模式下它不一定在焦點頁上。
        let mates = ObjectLayerOps.groupMates(of: id, in: all.filter { $0.pageIndex == page })
        // 同組裡有鎖定在畫布上的形狀：整組都不動（只搬一半會把群組拆散）。
        let locked = notebook.allLockedObjectIds
        guard !mates.contains(where: { locked.contains($0.lowercased()) }) else {
            finishPageCrossing(ids: [], to: nil)
            return
        }
        for index in all.indices where mates.contains(all[index].id) {
            all[index].x += delta.width
            all[index].y += delta.height
        }
        // 連續模式：整組的中心拖到別頁就整組換頁。連到組外形狀的連接線會被拆到兩頁上，
        // 那種組合留在本頁（連接線只畫得出同一頁的兩端）。
        var crossedTo: Int?
        let frames = all.filter { mates.contains($0.id) }.map { CGRect(x: $0.x, y: $0.y, width: $0.width, height: $0.height) }
        let links = (notebook.connectionAttachments ?? []).filter { mates.contains($0.fromShapeId) || mates.contains($0.toShapeId) }
        if let union = frames.dropFirst().reduce(frames.first, { $0?.union($1) }),
           links.allSatisfy({ mates.contains($0.fromShapeId) && mates.contains($0.toShapeId) }),
           let landing = crossingLanding(for: union, page: page) {
            for index in all.indices where mates.contains(all[index].id) {
                all[index].x += landing.offset.width
                all[index].y += landing.offset.height
                all[index].pageIndex = landing.page
            }
            if var connections = notebook.connectionAttachments {
                for index in connections.indices
                where mates.contains(connections[index].fromShapeId) {
                    connections[index].pageIndex = landing.page
                }
                notebook.connectionAttachments = connections
            }
            crossedTo = landing.page
        } else if let union = frames.dropFirst().reduce(frames.first, { $0?.union($1) }) {
            // 留在本頁：與其他物件一樣推回可列印範圍（S-85）。原本形狀拖出頁外就留在頁外，
            // 畫面與縮圖上都看不到、也點不到。
            let landed = PrintableArea.clampOrigin(
                x: union.minX, y: union.minY, width: union.width, height: union.height)
            for index in all.indices where mates.contains(all[index].id) {
                all[index].x += landed.x - union.minX
                all[index].y += landed.y - union.minY
            }
        }
        notebook.shapeAttachments = all
        commitNotebook()
        finishPageCrossing(ids: crossedTo == nil ? [] : Array(mates), to: crossedTo)
    }

    func shapeBinding(for id: String) -> Binding<NoteShapeAttachment> {
        let normId = id.lowercased()
        return Binding(
            get: {
                notebook.shapeAttachments?.first(where: { $0.id.lowercased() == normId })
                    ?? NoteShapeAttachment(id: id)
            },
            set: { updated in
                guard let index = notebook.shapeAttachments?
                    .firstIndex(where: { $0.id.lowercased() == normId }) else { return }
                notebook.shapeAttachments?[index] = updated
                commitNotebook()
            }
        )
    }

    func moveTable(_ id: String, by delta: CGSize) {
        guard hypot(delta.width, delta.height) >= 1 else {
            finishPageCrossing(ids: [], to: nil)
            return
        }
        let normId = id.lowercased()
        guard var all = notebook.tableAttachments,
              let index = all.firstIndex(where: { $0.id.lowercased() == normId }) else { return }
        let previous = all[index]
        all[index].x += delta.width
        all[index].y += delta.height
        // 連續模式：拖到別頁就換頁。表格裡寫了字的不換 —— 筆跡屬於頁面，跟不過去，
        // 表格換頁而字留在原頁，等於把內容拆散。
        if let frame = frameOfObject(id: id),
           let landing = crossingLanding(
               for: frame.offsetBy(dx: delta.width, dy: delta.height), page: previous.pageIndex),
           !drawingForPage(previous.pageIndex).strokes.contains(where: previous.containsStroke) {
            all[index].x += landing.offset.width
            all[index].y += landing.offset.height
            all[index].pageIndex = landing.page
            notebook.tableAttachments = all
            commitNotebook()
            finishPageCrossing(ids: [id], to: landing.page)
            return
        }
        // 留在本頁：與其他物件一樣推回可列印範圍（S-85）。原本表格拖出頁外就留在頁外，看不到也點不到。
        var applied = delta
        if let frame = frameOfObject(id: id) {
            let moved = frame.offsetBy(dx: delta.width, dy: delta.height)
            let landed = PrintableArea.clampOrigin(
                x: moved.minX, y: moved.minY, width: moved.width, height: moved.height)
            all[index].x += landed.x - moved.minX
            all[index].y += landed.y - moved.minY
            applied = CGSize(width: all[index].x - previous.x, height: all[index].y - previous.y)
        }
        notebook.tableAttachments = all
        commitNotebook()
        finishPageCrossing(ids: [], to: nil)

        moveStrokesInsideTable(previous, by: applied)
    }

    func tableBinding(for id: String) -> Binding<NoteTableAttachment> {
        let normId = id.lowercased()
        return Binding(
            get: {
                notebook.tableAttachments?.first(where: { $0.id.lowercased() == normId })
                    ?? NoteTableAttachment(id: id)
            },
            set: { updated in
                guard let index = notebook.tableAttachments?
                    .firstIndex(where: { $0.id.lowercased() == normId }) else { return }
                let previous = notebook.tableAttachments![index]
                notebook.tableAttachments?[index] = updated
                commitNotebook()

                let dx = updated.x - previous.x
                let dy = updated.y - previous.y
                if hypot(dx, dy) >= 1 {
                    moveStrokesInsideTable(previous, by: CGSize(width: dx, height: dy))
                }
            }
        )
    }

    func moveStrokesInsideTable(_ table: NoteTableAttachment, by delta: CGSize) {
        guard hypot(delta.width, delta.height) >= 0.5 else { return }
        let page = table.pageIndex

        // 1. 標準 PencilKit 筆跡（PKDrawing）
        let drawing = (pageDisplayMode == .single && page == currentPageIndex && canvasView != nil)
            ? (canvasView?.drawing ?? currentDrawing)
            : drawingForPage(page)

        let result = table.offsetContainedStrokes(in: drawing, by: delta)
        if result.movedCount > 0 {
            let updatedDrawing = result.drawing
            if page == currentPageIndex {
                currentDrawing = updatedDrawing
                if let canvas = canvasView {
                    canvas.drawing = updatedDrawing
                    if let adaptive = canvas as? AdaptiveCanvasView {
                        adaptive.initialLoadedStrokeCount = updatedDrawing.strokes.count
                        adaptive.forceDisplayRefresh(with: updatedDrawing)
                    }
                }
            }
            store.saveDrawing(notebookId: notebook.id, pageIndex: page, drawing: updatedDrawing)
            recordDrawingEdit(page: page, drawing: updatedDrawing)
            broadcastDrawingChange(page: page, drawing: updatedDrawing)
            PageThumbnailRenderer.invalidateAll()
            if pageDisplayMode == .continuous {
                // 筆跡已經寫進磁碟：讓那一頁合併重讀，不重建畫布。基準設成搬動前的那一份 ——
                // 畫面上的就是它，合併結果才會整份換成搬過的，不會把舊位置當成「這台剛寫的」留下來。
                inkDiskBaselines[page] = drawing
                continuousInkReloadGeneration += 1
                continuousObjectGeneration += 1
            }
        }

        // 2. 專業製圖筆畫（ProInk）
        if page == currentPageIndex, let proLayer = (canvasView as? AdaptiveCanvasView)?.proLayer {
            let layout = table.layout()
            let tableWidth = max(table.width, CGFloat(layout.width))
            let tableHeight = max(table.height, CGFloat(layout.height))
            let tableRect = CGRect(x: table.x, y: table.y, width: tableWidth, height: tableHeight)
            let hitRect = tableRect.insetBy(dx: -4, dy: -4)

            var proIdsToMove = Set<String>()
            for s in proLayer.ownStrokes {
                let b = s.bounds
                let mid = CGPoint(x: b.midX, y: b.midY)
                let intersection = tableRect.intersection(b)
                let isInside = tableRect.contains(b)
                    || hitRect.contains(mid)
                    || (!intersection.isNull && (intersection.width * intersection.height) >= (b.width * b.height * 0.4))
                    || (hitRect.contains(b.origin) && !intersection.isNull && intersection.width > 2 && intersection.height > 2)
                if isInside {
                    proIdsToMove.insert(s.id)
                }
            }
            if !proIdsToMove.isEmpty {
                proLayer.move(ids: proIdsToMove, by: delta)
                proLayer.endMove()
            }
        }
    }

    func binding(for id: String) -> Binding<NoteImageAttachment> {
        let norm = id.lowercased()
        return Binding(
            get: {
                notebook.attachments?.first(where: { $0.id.lowercased() == norm }) ?? NoteImageAttachment(fileName: "")
            },
            set: { updated in
                if let idx = notebook.attachments?.firstIndex(where: { $0.id.lowercased() == norm }) {
                    notebook.attachments?[idx] = updated
                    commitNotebook()
                }
            }
        )
    }

    /// - Parameter hint: 呼叫端已經知道的位置（`ForEach` 走到第幾個）。
    ///   對得上就直接用，O(1)；對不上（陣列在兩次算繪之間變動了）才退回線性搜尋。
    ///
    /// **不能每次都線性搜尋。** `Binding(get:set:)` 建立時就會先呼叫一次 `get`，
    /// 一頁有 m 個文字方塊、全本有 n 個，一次算繪就是 m×n 次 UUID 字串比對，
    /// 而 SwiftUI 一次更新會重算好幾輪。主執行緒因此卡住超過十秒，看門狗
    /// （`0x8BADF00D`）在背景把 App 殺掉 —— 崩潰報告的主執行緒堆疊停在
    /// 這個閉包裡的 `_stringCompareInternal`。
    func binding(forTextId id: String, hint: Int? = nil) -> Binding<NoteTextAttachment> {
        let norm = id.lowercased()
        func index(in items: [NoteTextAttachment]?) -> Int? {
            guard let items else { return nil }
            if let hint, items.indices.contains(hint), items[hint].id.lowercased() == norm { return hint }
            return items.firstIndex(where: { $0.id.lowercased() == norm })
        }
        return Binding(
            get: {
                index(in: notebook.textAttachments).map { notebook.textAttachments![$0] }
                    ?? NoteTextAttachment()
            },
            set: { updated in
                if let idx = index(in: notebook.textAttachments) {
                    notebook.textAttachments?[idx] = updated
                    commitNotebook()
                }
            }
        )
    }

    /// 排版面板用：面板改的是**整個方塊**。改了字級、顏色這類方塊層級的值時，
    /// 逐字格式裡同一項的覆寫要一起拿掉，否則有覆寫的那幾個字看起來「改不動」；
    /// 面板裡直接改文字時，區段跟著移動。
    func wholeBoxBinding(forTextId id: String) -> Binding<NoteTextAttachment> {
        let base = binding(forTextId: id)
        return Binding(
            get: { base.wrappedValue },
            set: { updated in
                let old = base.wrappedValue
                var next = updated
                if next.runs != nil, next.runs == old.runs {
                    if next.text != old.text { RichText.adjustRunsLineByLine(of: &next, from: old.text) }
                    var edit = TextCharStyle()
                    if next.isBold != old.isBold { edit.bold = next.isBold }
                    if next.isItalic != old.isItalic { edit.italic = next.isItalic }
                    if next.isUnderline != old.isUnderline { edit.underline = next.isUnderline }
                    if next.isStrikethrough != old.isStrikethrough { edit.strikethrough = next.isStrikethrough }
                    if next.fontSize != old.fontSize { edit.fontSize = next.fontSize }
                    if next.fontFamily != old.fontFamily { edit.fontFamily = next.fontFamily ?? "" }
                    if next.textColorHex != old.textColorHex { edit.textColorHex = next.textColorHex }
                    if !edit.isEmpty { RichText.applyToWholeBox(edit, to: &next) }
                }
                base.wrappedValue = next
            }
        )
    }

    func binding(forLinkId id: String) -> Binding<NoteLinkAttachment> {
        let norm = id.lowercased()
        return Binding(
            get: {
                notebook.linkAttachments?.first(where: { $0.id.lowercased() == norm }) ?? NoteLinkAttachment(urlString: "")
            },
            set: { updated in
                if let idx = notebook.linkAttachments?.firstIndex(where: { $0.id.lowercased() == norm }) {
                    notebook.linkAttachments?[idx] = updated
                    commitNotebook()
                }
            }
        )
    }

    func binding(forAudioId id: String) -> Binding<NoteAudioAttachment> {
        let norm = id.lowercased()
        return Binding(
            get: {
                notebook.audioAttachments?.first(where: { $0.id.lowercased() == norm })
                    ?? NoteAudioAttachment(fileName: "")
            },
            set: { updated in
                if let idx = notebook.audioAttachments?.firstIndex(where: { $0.id.lowercased() == norm }) {
                    notebook.audioAttachments?[idx] = updated
                    commitNotebook()
                }
            }
        )
    }

    func binding(forModel3DId id: String) -> Binding<Note3DAttachment> {
        let norm = id.lowercased()
        return Binding(
            get: {
                notebook.model3DAttachments?.first(where: { $0.id.lowercased() == norm }) ?? Note3DAttachment()
            },
            set: { updated in
                if let idx = notebook.model3DAttachments?.firstIndex(where: { $0.id.lowercased() == norm }) {
                    notebook.model3DAttachments?[idx] = updated
                    commitNotebook()
                }
            }
        )
    }

}
