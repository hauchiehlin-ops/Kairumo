//
//  NotebookPackageBridge.swift
//  Kairumo
//
//  `NotebookDocument` ⇄ 核心 `.padnote` 套件（工作包 WP4）。
//
//  # 這一層在做什麼
//
//  Apple 版的筆記目前存成 JSON（中繼資料、文字方塊、圖片位置）加上一堆
//  `.drawing` 檔（PencilKit 的手繪二進位）。那個格式只有 Apple 平台看得懂。
//  這裡把同一份內容寫成核心的 `.padnote` 套件 —— Android 讀的就是它。
//
//  # 為什麼是「另外寫一份」而不是直接換掉儲存層
//
//  硬前提是不影響現有 iOS / iPadOS / macOS 已經穩定的功能。匯出是一條**新增**
//  的路徑：既有的讀寫一行都沒改，使用者手上的資料也不會被動到。等這條路徑
//  在兩個平台上都驗過，才輪到談儲存層的正式遷移（含備份與回滾）。
//

import CryptoKit
import Foundation
import PencilKit
import UIKit

enum NotebookPackageBridge {
    /// 匯出時遇到的問題。刻意逐項分開 —— 「匯出失敗」四個字幫不了使用者。
    enum BridgeError: LocalizedError {
        case coreRejected(String)
        case noPages

        var errorDescription: String? {
            switch self {
            case let .coreRejected(detail):
                return LocalizationManager.shared.localizedUnsafe("err_core_not_ready") + "：\(detail)"
            case .noPages:
                return LocalizationManager.shared.localizedUnsafe("err_no_pages")
            }
        }
    }

    /// 匯出的結果摘要，供測試與 UI 顯示「帶出去了什麼」。
    struct ExportSummary {
        var pageCount: Int
        var strokeCount: Int
        var textBlockCount: Int
        var imageCount: Int
        /// 寫進核心表格區塊的表格數。
        var tableCount: Int = 0
        /// 寫進核心物件樹的形狀數。
        var shapeCount: Int = 0
        /// 寫進核心物件樹的連接線數。
        var connectionCount: Int = 0
    }

    // MARK: - 匯出

    /// 把一本筆記寫成 `.padnote` 套件。
    ///
    /// - Parameters:
    ///   - document: 要匯出的筆記。
    ///   - drawings: 每一頁的手繪內容，索引與頁次相同。
    ///   - imageData: 圖片附件的檔名 → 位元組。取不到的附件會被略過而不是讓整份匯出失敗。
    ///   - destination: 套件目錄的位置。
    ///   - deviceId: 這台裝置穩定不變的識別碼 —— 它會進 oplog 檔名，保證兩台裝置不寫同一個檔。
    @discardableResult
    static func export(
        document: NotebookDocument,
        drawings: [PKDrawing],
        imageData: [String: Data] = [:],
        to destination: URL,
        deviceId: UInt32,
        pageIds knownPageIds: [String]? = nil,
        skipBlockIds: Set<String> = [],
        proStrokes: [[ProStroke]] = [],
        proLedgers: [ProInkLedger] = [],
        recordingTitles: [String: String] = [:]
    ) throws -> ExportSummary {
        let pageCount = max(document.pageCount, drawings.count)
        guard pageCount > 0 else { throw BridgeError.noPages }

        let session: PadnoteSession
        do {
            // 沒有自動產生的第一頁 —— 頁面全部由下面明確建立。
            //
            // 讓核心先給一頁、再把多的移掉，在多裝置合併時**不保證互相抵銷**：
            // 兩台裝置各自的 Add/Remove 交錯之後會留下一頁空白，而且每同步一趟
            // 再多一頁。不產生它，就沒有需要抵銷的東西。
            session = try PadnoteSession.createEmpty(
                path: destination.path,
                title: document.title,
                nowUnixMs: UInt64(document.createdAt.timeIntervalSince1970 * 1000),
                deviceId: deviceId
            )
        } catch {
            throw BridgeError.coreRejected(String(describing: error))
        }

        var summary = ExportSummary(pageCount: pageCount, strokeCount: 0,
                                    textBlockCount: 0, imageCount: 0)

        do {
            // 建立筆記本時核心已經給了第一頁，其餘的才要補。
            //
            // 有已知的頁面 id 就照用 —— 頁面身分要跟著筆記走，不是跟著某一次
            // 匯出走，否則兩台裝置的頁永遠不會收斂。
            let style = pageStyle(for: document.template)
            var pageIds: [String] = []
            let isInbox = document.id.caseInsensitiveCompare(recordingInboxNotebookId()) == .orderedSame
            if isInbox {
                let fixedInboxPageId = "a0d10000-0000-4000-8000-000000000002"
                try session.addPageWithId(pageId: fixedInboxPageId, style: style)
                pageIds.append(fixedInboxPageId)
            } else {
                // 有已知的頁面 id 就照用 —— 頁面身分要跟著筆記走，不是跟著某一次
                // 匯出走，否則兩台裝置的頁永遠不會收斂。
                for id in (knownPageIds ?? []).prefix(pageCount) {
                    try session.addPageWithId(pageId: id, style: style)
                    pageIds.append(id)
                }
                while pageIds.count < pageCount {
                    try pageIds.append(session.addPage(style: style))
                }
            }

            // 筆記本層級的中繼資料（樣板、資料夾、圖釘、連結卡片、3D、頁面 id）。
            // 核心沒有這些概念，不另外寫進去的話，在另一台裝置上整批消失。
            var meta = NotebookMeta(from: document)
            meta.pageIds = pageIds
            try session.setNotebookMeta(json: meta.encodedJSON())

            for (index, pageId) in pageIds.enumerated() {
                // 頁面高度是內容的一部分：使用者向下延長過的頁面若沒寫進去，
                // 另一個平台會看到一頁被截短的筆記。
                // 寬度取**這一本自己的**規格，不是 `PageGeometry.width`。
                //
                // 後者是「目前螢幕上那一本」的頁寬（`PageGeometry.currentSize`，
                // 由編輯器在開啟筆記時設定）。同步一次要匯出幾十本，其中只有
                // 一本在螢幕上 —— 用那個值等於把作用中筆記的頁寬寫進所有其他
                // 筆記，規格不同的那些在另一台裝置上就會變形。
                //
                // 順便解開了一個死結：`PageGeometry.width` 走
                // `MainActor.assumeIsolated`，在背景執行緒上直接 trap，
                // 匯出因此搬不出主執行緒。`document.pageSize` 走的是純函式
                // `PageGeometry.size(forFormat:)`，哪個執行緒都成立。
                try session.setPageSize(
                    pageId: pageId,
                    width: Float(document.pageSize.width),
                    height: Float(document.height(forPage: index))
                )

                if index < drawings.count {
                    for draft in InkInterop.drafts(from: drawings[index]) {
                        _ = try session.addStroke(
                            pageId: pageId,
                            tool: draft.tool,
                            colorRgba: draft.colorRgba,
                            baseWidth: draft.baseWidth,
                            points: draft.points
                        )
                        summary.strokeCount += 1
                    }
                }
                // 專業筆刷（自繪引擎）的筆畫：核心把它們當一般筆畫存，只是筆刷種類不同。
                if index < proStrokes.count {
                    for pro in proStrokes[index] {
                        guard let kind = ProInk.kind(named: pro.tool) else { continue }
                        try addPro(pro, kind: kind, to: session, page: pageId)
                        summary.strokeCount += 1
                    }
                }
                // 墓碑：被擦掉、搬動或改了圖層的筆畫。自己的筆畫連 `Add` 一起寫 ——
                // 同步只傳**變大**的檔案，只寫 `Remove` 的話檔案會比雲端那份小，墓碑永遠傳不出去。
                if index < proLedgers.count {
                    for retired in proLedgers[index].retired {
                        if let old = retired.stroke, let kind = ProInk.kind(named: old.tool) {
                            var again = old
                            again.coreId = retired.coreId
                            try addPro(again, kind: kind, to: session, page: pageId)
                        }
                        try session.eraseStroke(pageId: pageId, strokeId: retired.coreId)
                    }
                }

                for text in document.textAttachments?.filter({ $0.pageIndex == index }) ?? [] {
                    // **用附件自己的穩定 id 新增，而且別台已經寫過的不重寫。**
                    // 以前每次都讓核心發新 id，匯入又把別台的方塊讀進來，下一次匯出全部再寫一遍 ——
                    // 兩台裝置來回之後數量依費氏數列增生（見 docs/plans/object-identity.md）。
                    let blockId = stableBlockId(text.id)
                    if skipBlockIds.contains(blockId) { continue }
                    guard try session.addTextWithId(
                        pageId: pageId, blockId: blockId, content: text.text, style: .body
                    ) else { continue }
                    try session.setBlockPosition(
                        blockId: blockId, x: Float(text.x), y: Float(text.y)
                    )
                    // 顏色、邊框、段落也要跨過去。只帶文字與位置的話，
                    // 使用者在另一個平台打開會看到一個白底無行距的方框。
                    try session.setBlockAppearance(
                        blockId: blockId, json: TextBoxAppearance.encode(text)
                    )
                    summary.textBlockCount += 1
                }

                // 表格。**這一段以前完全不存在** —— Apple 端畫的表格因此從來
                // 沒有進過 `.padnote`：匯出、列印、同步到 Android 全都是整張
                // 消失，而畫面上還在（它活在 Apple 自己的 JSON 裡），
                // 所以使用者不會發現，直到在另一台裝置上打開。
                // Android 端一直都有寫（`TableStore.persist`），只有這裡漏了。
                for table in document.tableAttachments?.filter({ $0.pageIndex == index }) ?? [] {
                    let blockId = stableBlockId(table.id)
                    if skipBlockIds.contains(blockId) { continue }
                    guard try session.insertTableWithId(
                        pageId: pageId,
                        blockId: blockId,
                        rows: UInt32(table.rows),
                        cols: UInt32(table.cols),
                        cells: table.cells,
                        headerRow: table.headerRow
                    ) else { continue }
                    try session.setBlockPosition(
                        blockId: blockId, x: Float(table.x), y: Float(table.y)
                    )
                    try session.setBlockAppearance(
                        blockId: blockId, json: TableAppearance.encode(table)
                    )
                    for span in table.mergedCells {
                        try? session.mergeTableCells(
                            blockId: blockId,
                            row: UInt32(span.row), col: UInt32(span.col),
                            rowSpan: UInt32(span.rowSpan), colSpan: UInt32(span.colSpan)
                        )
                    }
                    summary.tableCount += 1
                }

                // 核心的文件模型沒有連結卡片、3D 模型、錄音卡片、討論圖釘、紙膠帶、便利貼錨點這幾種型別。
                // 每個物件寫成**一個衍生圖片區塊**，真身（payload）放在區塊外觀裡 ——
                // 這樣它們跟文字框、表格一樣逐物件合併，不會被中繼資料那一份「最後寫入者贏」的
                // JSON 整包蓋掉（見 ObjectEnvelope.swift）。圖片本身只是 PDF 匯出看得到它們的後備圖。
                func writeEnvelope<T: Encodable>(
                    kind: String, id: String, payload: T, png: Data?,
                    x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat
                ) throws {
                    let blockId = stableBlockId(id)
                    if skipBlockIds.contains(blockId) { return }
                    let blob = try session.putBlob(bytes: png ?? ObjectEnvelope.transparentPNG)
                    guard try session.addImageWithId(
                        pageId: pageId, blockId: blockId, blob: blob,
                        width: Float(max(width, 1)), height: Float(max(height, 1))
                    ) else { return }
                    try session.setBlockPosition(blockId: blockId, x: Float(x), y: Float(y))
                    try session.setBlockAppearance(
                        blockId: blockId,
                        json: ObjectEnvelope.encode(kind: kind, fileName: "\(id).png", payload: payload)
                    )
                    summary.imageCount += 1
                }
                for model in document.model3DAttachments?.filter({ $0.pageIndex == index }) ?? [] {
                    try writeEnvelope(
                        kind: "model3d", id: model.id, payload: model,
                        png: PageThumbnailRenderer.renderObjectImage(model)?.pngData(),
                        x: model.x, y: model.y, width: model.width, height: model.height)
                }
                for link in document.linkAttachments?.filter({ $0.pageIndex == index }) ?? [] {
                    try writeEnvelope(
                        kind: "link", id: link.id, payload: link,
                        png: PageThumbnailRenderer.renderObjectImage(link)?.pngData(),
                        x: link.x, y: link.y, width: link.width, height: link.height)
                }
                for audio in document.audioAttachments?.filter({ $0.pageIndex == index }) ?? [] {
                    try writeEnvelope(
                        kind: "audio", id: audio.id, payload: audio,
                        png: PageThumbnailRenderer.renderObjectImage(audio)?.pngData(),
                        x: audio.x, y: audio.y, width: audio.width, height: audio.height)
                }
                for pin in document.commentPins?.filter({ $0.pageIndex == index }) ?? [] {
                    try writeEnvelope(
                        kind: "pin", id: pin.id, payload: pin, png: nil,
                        x: pin.x, y: pin.y, width: 1, height: 1)
                }
                for tape in document.tapeAttachments?.filter({ $0.pageIndex == index }) ?? [] {
                    try writeEnvelope(
                        kind: "tape", id: tape.id, payload: tape,
                        png: PageThumbnailRenderer.renderObjectImage(tape)?.pngData(),
                        x: tape.rect.minX, y: tape.rect.minY,
                        width: tape.rect.width, height: tape.rect.height)
                }
                for anchor in document.stickyAnchors?.filter({ $0.pageIndex == index }) ?? [] {
                    try writeEnvelope(
                        kind: "sticky", id: anchor.id, payload: anchor, png: nil,
                        x: CGFloat(anchor.anchorOriginX), y: CGFloat(anchor.anchorOriginY),
                        width: 1, height: 1)
                }
                if index == 0 {
                    // 錄音的名字（見 `RecordingTitle`）。掛在第一頁，每段錄音一個區塊，逐個合併。
                    for (fileName, title) in recordingTitles.sorted(by: { $0.key < $1.key }) {
                        try writeEnvelope(
                            kind: "rectitle", id: recordingTitleBlockId(fileName),
                            payload: RecordingTitle(fileName: fileName, title: title), png: nil,
                            x: 0, y: 0, width: 1, height: 1)
                    }
                }

                // 形狀與連接線寫成**核心的原生物件**，不是平台自己另存的 JSON。
                //
                // 差別在於：原生物件跨得過平台 —— Android 讀的是同一組物件。
                // 存在筆記檔的 JSON 裡只有這個平台看得懂，同一張流程圖傳過去
                // 會整個消失，而且不會有任何錯誤訊息。
                var shapeObjectIds: [String: String] = [:]
                // 別台寫的形狀不重寫（見上面文字方塊的說明）；記下來，群組與連接線碰到它們就略過 ——
                // 這份套件裡沒有那個物件，寫下去會是一條指向不存在物件的線。
                var foreignShapeIds = Set<String>()
                for shape in document.shapeAttachments?.filter({ $0.pageIndex == index }) ?? [] {
                    let objectId = stableBlockId(shape.id)
                    if skipBlockIds.contains(objectId) {
                        foreignShapeIds.insert(shape.id)
                        continue
                    }
                    guard try session.insertShapeWithId(
                        pageId: pageId,
                        objectId: objectId,
                        kind: shape.kind,
                        minX: Float(shape.x), minY: Float(shape.y),
                        maxX: Float(shape.x + shape.width), maxY: Float(shape.y + shape.height),
                        cornerRadius: Float(shape.cornerRadius),
                        text: shape.label
                    ) else { continue }
                    // 旋轉走核心的物件變換（繞中心旋轉），不另開欄位 ——
                    // 線狀形狀的方向就是靠它：一條斜線在檔案裡是「扁外框 ＋ 旋轉」，
                    // 沒帶旋轉的話，另一台裝置上它會變成外框的對角線。
                    if abs(shape.canvasRotation.truncatingRemainder(dividingBy: 360)) > 0.01 {
                        _ = try? session.rotateObject(
                            objectId: objectId,
                            radians: Float(shape.canvasRotation * .pi / 180),
                            cx: Float(shape.x + shape.width / 2),
                            cy: Float(shape.y + shape.height / 2))
                    }
                    shapeObjectIds[shape.id] = objectId
                    summary.shapeCount += 1
                }

                // 群組：把同一組的形狀收成核心的 Group 節點。
                //
                // 群組是物件樹裡真正的節點，不是平台自己畫出來的框 ——
                // 所以它跨得過平台：在一台裝置上群組起來，另一台打開仍然是一組。
                let groups = Dictionary(
                    grouping: document.shapeAttachments?
                        .filter { $0.pageIndex == index && $0.groupId != nil } ?? [],
                    by: { $0.groupId! }
                )
                for (_, members) in groups where members.count > 1 {
                    let objectIds = members.compactMap { shapeObjectIds[$0.id] }
                    guard objectIds.count > 1, objectIds.count == members.count else { continue }
                    _ = try? session.groupObjects(pageId: pageId, objectIds: objectIds)
                }

                for link in document.connectionAttachments?.filter({ $0.pageIndex == index }) ?? [] {
                    // 兩端都要找得到對應的核心物件。找不到就跳過這一條 ——
                    // 寫進去的話會是一條指向不存在物件的線。
                    guard let from = shapeObjectIds[link.fromShapeId],
                          let to = shapeObjectIds[link.toShapeId] else { continue }
                    let connectionId = stableBlockId(link.id)
                    if skipBlockIds.contains(connectionId) { continue }
                    let fields = link.coreFields(
                        from: document.shapeAttachments?.first { $0.id == link.fromShapeId },
                        to: document.shapeAttachments?.first { $0.id == link.toShapeId })
                    _ = try session.insertConnectionWithId(
                        pageId: pageId,
                        objectId: connectionId,
                        fromObjectId: from, toObjectId: to,
                        fromAnchor: fields.fromAnchor, toAnchor: fields.toAnchor,
                        route: fields.route,
                        startCap: fields.startCap, endCap: fields.endCap,
                        label: link.label
                    )
                    summary.connectionCount += 1
                }

                // 形狀與連接線的樣式：一個物件一個信封（核心的形狀物件建立後不能改，也沒有顏色欄位）。
                for shape in document.shapeAttachments?.filter({ $0.pageIndex == index }) ?? []
                where shapeObjectIds[shape.id] != nil {
                    try writeEnvelope(
                        kind: "shapestyle", id: "style:" + stableBlockId(shape.id), payload: ShapeStyleMeta(from: shape),
                        png: nil, x: shape.x, y: shape.y, width: 1, height: 1)
                }
                for link in document.connectionAttachments?.filter({ $0.pageIndex == index }) ?? []
                where shapeObjectIds[link.fromShapeId] != nil && shapeObjectIds[link.toShapeId] != nil {
                    try writeEnvelope(
                        kind: "connstyle", id: "style:" + stableBlockId(link.id), payload: ConnectionStyleMeta(from: link),
                        png: nil, x: 0, y: 0, width: 1, height: 1)
                }

                for image in document.attachments?.filter({ $0.pageIndex == index }) ?? [] {
                    // 讀不到某張圖不該讓整本筆記匯不出去 —— 缺一張圖，
                    // 跟整份匯出失敗，對使用者是完全不同等級的損失。
                    guard let bytes = imageData[image.fileName] else { continue }
                    let blockId = stableBlockId(image.id)
                    if skipBlockIds.contains(blockId) { continue }
                    let blob = try session.putBlob(bytes: bytes)
                    guard try session.addImageWithId(
                        pageId: pageId, blockId: blockId, blob: blob,
                        width: Float(image.width), height: Float(image.height)
                    ) else { continue }
                    try session.setBlockPosition(
                        blockId: blockId, x: Float(image.x), y: Float(image.y)
                    )
                    // 圓角、邊框、陰影、濾鏡、旋轉，以及「這是不是一張圖表」。
                    // 只帶點陣圖的話，在另一台裝置上會變成一張沒有樣式的方形照片，
                    // 而且圖表會改不動。
                    try session.setBlockAppearance(
                        blockId: blockId, json: ImageAppearance.encode(image)
                    )
                    summary.imageCount += 1
                }
            }
        } catch let error as BridgeError {
            throw error
        } catch {
            throw BridgeError.coreRejected(String(describing: error))
        }

        return summary
    }

    // MARK: - 匯出 PDF（可再編輯的標註）

    /// 匯出成帶有 `/Ink` 標註的 PDF。
    ///
    /// # 為什麼繞一圈走核心
    ///
    /// App 原本的 PDF 匯出是把整頁算繪成點陣圖再塞進 PDF —— 在別的 App 裡
    /// 開得起來、可以在上面加註，但**我們的筆畫不是可編輯的物件**。
    /// 核心的匯出器同時輸出向量筆畫與標準 `/Subtype /Ink` 標註，
    /// 各主流 PDF 閱讀器與筆記軟體打開後可以直接繼續改那些筆畫。
    ///
    /// 而且 Android 走的是同一支匯出器 —— 兩個平台匯出的 PDF 結構相同，
    /// 不是各寫一個「差不多」的產生器。
    static func exportPdf(
        document: NotebookDocument,
        drawings: [PKDrawing],
        imageData: [String: Data] = [:],
        deviceId: UInt32,
        proStrokes: [[ProStroke]] = []
    ) throws -> Data {
        // 用一個暫存套件當中繼。它在匯出完就沒有用了。
        let staging = FileManager.default.temporaryDirectory
            .appending(path: "pdf-\(UUID().uuidString).padnote")
        defer { try? FileManager.default.removeItem(at: staging) }

        try export(
            document: document, drawings: drawings, imageData: imageData,
            to: staging, deviceId: deviceId, proStrokes: proStrokes
        )

        let session = try PadnoteSession.openExisting(path: staging.path, deviceId: deviceId)
        // **把版面一起畫進去**（S-90）。
        //
        // 底紋只有六種，而使用者看到的版面有三十幾種 —— 康乃爾的三區、
        // 四象限的十字、週計畫的七欄都來自 `page_guides`。在此之前匯出的
        // PDF 完全沒有它們：畫布上是一張康乃爾，匯出來是一張空白紙。
        //
        // 顏色與文字核心拿不到（配色是使用者選的、語系鍵住在兩端共用的
        // 字串表裡），所以這裡一起交過去。
        let paperIds = (0 ..< max(document.pageCount, 1)).map { document.paperId(forPage: $0) }
        return try session.exportPdfWithLayout(
            paperIds: paperIds,
            paletteId: document.guidePaletteId ?? "",
            labels: LocalizationManager.shared.guideLabelsUnsafe(),
            // 轉錄區塊的標記要跟著介面語言（S-54c）。核心原本完全不知道
            // 語言，於是寫死 `[Audio]`；再之前寫死的是 `[語音]`，而那更糟
            // —— 匯出的 PDF 是要給別人看的文件。
            localeTag: LocalizationManager.shared.currentLanguageTagUnsafe()
        )
    }

    // MARK: - 讀回（驗證用）

    /// 把 `.padnote` 套件的每一頁手繪還原成 `PKDrawing`。
    ///
    /// 這條路徑的用途是**比對**：匯出後立刻讀回來跟原稿比，才知道有沒有掉東西。
    /// 目前不接進畫布 —— 儲存層還沒遷移，接進去等於偷偷換掉使用者的資料來源。
    static func drawings(fromPackageAt path: URL, deviceId: UInt32) throws -> [PKDrawing] {
        let session = try PadnoteSession.openExisting(path: path.path, deviceId: deviceId)
        var result: [PKDrawing] = []
        for pageId in try pageIds(of: session) {
            let strokes = try session.visibleStrokeDetails(pageId: pageId)
            result.append(InkInterop.drawing(from: strokes))
        }
        return result
    }

    /// 套件內每一頁的高度（點）。
    static func pageHeights(fromPackageAt path: URL, deviceId: UInt32) throws -> [CGFloat] {
        let session = try PadnoteSession.openExisting(path: path.path, deviceId: deviceId)
        return try pageIds(of: session).map { pageId in
            let size = try session.pageSize(pageId: pageId)
            return CGFloat(size?.last ?? 0)
        }
    }

    /// 套件裡每一張圖表的設定與位置，依頁次。
    ///
    /// # 為什麼讀回來這件事需要自己的出口
    ///
    /// 匯出時圖表寫成「圖片區塊 + 圖表設定外觀」。少了這一支，設定就是**單向**的：
    /// 寫得進 `.padnote`，在另一台裝置上卻找不回來 —— 使用者看到一張改不動的圖，
    /// 而他的數字好端端地躺在檔案裡。
    ///
    /// 只認得外觀帶著圖表標記的圖片區塊，一般的圖片照樣是圖片。
    static func charts(fromPackageAt path: URL, deviceId: UInt32) throws -> [ImportedChart] {
        let session = try PadnoteSession.openExisting(path: path.path, deviceId: deviceId)
        var result: [ImportedChart] = []
        for (index, pageId) in try pageIds(of: session).enumerated() {
            for blockId in try session.imageBlockIds(pageId: pageId) {
                guard let json = try session.blockAppearance(blockId: blockId),
                      let spec = ChartAppearance.decode(json) else { continue }
                let position = try session.blockPosition(blockId: blockId) ?? [0, 0]
                let size = try session.imageBlockSize(blockId: blockId) ?? [420, 300]
                result.append(
                    ImportedChart(
                        id: blockId, pageIndex: index, spec: spec,
                        x: CGFloat(position.first ?? 0), y: CGFloat(position.last ?? 0),
                        width: CGFloat(size.first ?? 420), height: CGFloat(size.last ?? 300)
                    )
                )
            }
        }
        return result
    }

    // MARK: - 匯出（保留其他裝置寫的東西）

    /// 把筆記寫進套件，但**不動別台裝置寫的檔案**。
    ///
    /// # 為什麼不能直接重匯出
    ///
    /// `export(...)` 是從零建一個套件：它會先把目的地整個刪掉。單機轉檔沒問題，
    /// 但同步之後那個目錄裡已經有**另一台裝置下載下來的 oplog 與筆畫檔** ——
    /// 刪掉等於把對方的編輯洗掉，而且雙方都不會收到任何錯誤，只是內容悄悄不見。
    ///
    /// 架構上本來就有一條保證：`doc/ops/<lamport>-<device>.oplog` 與
    /// `ink/<page>-<device>.strokes` 的檔名帶著寫入者的 device id，**一個檔案
    /// 只有一個寫者**。所以這裡只做一件事：把屬於這台裝置的檔案換掉，
    /// 其餘原樣留著。blob 是內容定址的，補上去不會覆蓋到任何東西。
    @discardableResult
    static func exportPreservingOtherDevices(
        document: NotebookDocument,
        drawings: [PKDrawing],
        imageData: [String: Data] = [:],
        to destination: URL,
        deviceId: UInt32,
        pageIds knownPageIds: [String]? = nil,
        proStrokes: [[ProStroke]] = [],
        proLedgers: [ProInkLedger] = [],
        recordingTitles: [String: String] = [:]
    ) throws -> ExportSummary {
        let fm = FileManager.default
        // 已知的頁面 id 優先用呼叫端給的；沒給就沿用套件裡現有的那批 ——
        // 換一批新 id 等於把同一頁分裂成兩頁。
        let pageIds = knownPageIds ?? existingPageIds(in: destination, deviceId: deviceId)

        // 目的地還不存在時就是一般的匯出，沒有別人的東西要保護。
        guard fm.fileExists(atPath: destination.path) else {
            return try export(
                document: document, drawings: drawings, imageData: imageData,
                to: destination, deviceId: deviceId, pageIds: pageIds,
                proStrokes: proStrokes, proLedgers: proLedgers, recordingTitles: recordingTitles
            )
        }

        let staging = fm.temporaryDirectory
            .appending(path: "kairumo-staging-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? fm.removeItem(at: staging) }
        let fresh = staging.appending(path: destination.lastPathComponent)

        // **先看別台裝置已經寫了哪些方塊／物件。**
        //
        // 這台的舊 oplog 下面會被整批換掉，所以「別台的檔案裡有、這台工作副本也有」的那些，
        // 就是別台寫的 —— 匯出時不重寫（重寫會讓文字內容變兩份、物件數量依費氏數列增生）。
        // 讀不到就中止這次匯出：照舊寫的話會把別台的內容再複製一份，比這本筆記這一輪不同步更糟。
        guard let foreign = foreignBlocks(in: destination, deviceId: deviceId) else {
            throw BridgeError.coreRejected(L10n.t("bridge_err_read_other"))
        }

        let summary = try export(
            document: document, drawings: drawings, imageData: imageData,
            to: fresh, deviceId: deviceId, pageIds: pageIds,
            skipBlockIds: foreign.ids, proStrokes: proStrokes, proLedgers: proLedgers,
            recordingTitles: recordingTitles
        )

        // **把錄音當下由核心直接寫的操作搬過去。** 重建只含平台文件模型有的東西（文字、圖片、筆畫…），
        // 錄音區段與轉錄詞不在裡面 —— 下面把舊的 oplog 整批換掉之後，它們就永遠消失了：
        // 錄音卡片沒有時間軸、無法播放，「語音轉文字」只剩空的文字方框。
        do {
            _ = try carryOverRecordingOps(
                oldPackagePath: destination.path, newPackagePath: fresh.path, deviceId: deviceId)
        } catch {
            throw BridgeError.coreRejected(L10n.f("bridge_err_keep_audio", "\(error)"))
        }

        let suffix = deviceSuffix(deviceId)
        var deletedDocOps = [String]()
        // 1. 先清掉這台裝置舊的 oplog 與筆畫檔 —— 不清的話新舊會疊加。
        for relative in relativeFiles(in: destination) where relative.contains(suffix) {
            if relative.hasPrefix("doc/ops/") {
                deletedDocOps.append(URL(fileURLWithPath: relative).lastPathComponent)
            }
            try? fm.removeItem(at: destination.appending(path: relative))
        }
        if !deletedDocOps.isEmpty {
            let tombstonePath = destination.appending(path: "doc/ops/compaction.tombstones")
            let existing = (try? String(contentsOf: tombstonePath)) ?? ""
            let newLines = deletedDocOps.joined(separator: "\n") + "\n"
            try? (existing + newLines).write(to: tombstonePath, atomically: true, encoding: .utf8)
        }
        // 2. 再把新的搬過去。blob 與 manifest 缺的才補，不覆蓋既有的。
        for relative in relativeFiles(in: fresh) {
            let src = fresh.appending(path: relative)
            let dst = destination.appending(path: relative)
            let isOwn = relative.contains(suffix) || relative == "manifest.json"
            if !isOwn && fm.fileExists(atPath: dst.path) {
                continue
            }
            try? fm.createDirectory(
                at: dst.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            let bytes = try Data(contentsOf: src)
            try bytes.write(to: dst, options: .atomic)
        }
        // 3. 墓碑只該記「舊的、而且沒有被重新寫出來」的名字。
        //
        // 上面第 1 步把這台舊的 oplog 全刪了、記成墓碑；第 2 步又寫出新的 ——
        // 名字常常一模一樣（lamport 從頭數）。不處理的話，墓碑裡躺著**現行檔案**的名字，
        // 下一輪同步就照墓碑把雲端上剛上傳的現行檔案刪掉（實測：建立筆記本後第二次啟動，
        // 雲端那本被刪光，另一台收不到）。核心那邊也有護欄，這裡是從源頭不寫錯。
        if !deletedDocOps.isEmpty {
            let tombstonePath = destination.appending(path: "doc/ops/compaction.tombstones")
            let liveOps = Set(
                (try? fm.contentsOfDirectory(atPath: destination.appending(path: "doc/ops").path)) ?? []
            )
            let remaining = ((try? String(contentsOf: tombstonePath)) ?? "")
                .split(separator: "\n")
                .map { String($0).trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty && !liveOps.contains($0) }
            if remaining.isEmpty {
                try? fm.removeItem(at: tombstonePath)
            } else {
                try? (remaining.joined(separator: "\n") + "\n")
                    .write(to: tombstonePath, atomically: true, encoding: .utf8)
            }
        }
        // 4. 別台寫的方塊，這台搬動過、改過外觀的話，把**差異**寫出去（只有位置與外觀；
        //    文字內容的跨裝置編輯目前不支援，見 docs/plans/object-identity.md）。
        //    失敗不影響這次匯出 —— 下一輪會再試。
        try? applyForeignEdits(
            document: document, foreign: foreign, to: destination, deviceId: deviceId,
            recordingTitles: recordingTitles)
        // 5. 使用者刪掉的、別台裝置寫的物件：把「刪除」寫成這台的操作。
        try? applyForeignDeletions(
            document: document, foreign: foreign, to: destination, deviceId: deviceId)
        return summary
    }

    /// 文件裡所有物件在核心的區塊／物件 id（小寫）。
    static func objectBlockIds(of d: NotebookDocument) -> Set<String> {
        var out = Set<String>()
        func add<T: Identifiable>(_ items: [T]?) where T.ID == String {
            for item in items ?? [] { out.insert(stableBlockId(item.id)) }
        }
        add(d.attachments); add(d.textAttachments); add(d.tableAttachments); add(d.shapeAttachments)
        add(d.connectionAttachments); add(d.linkAttachments); add(d.model3DAttachments)
        add(d.audioAttachments); add(d.commentPins); add(d.tapeAttachments); add(d.stickyAnchors)
        return out
    }

    /// 刪除要寫成操作的理由，與為什麼要兩份名單：
    ///
    /// 這台重匯出時只會重建**自己的** oplog；一個物件的「新增」若寫在別台的檔案裡（別台建立的，
    /// 或別台壓實時把這台的新增併進它自己的檔案），這台把它從文件刪掉之後，重建的結果裡只是
    /// 「沒有這個物件」—— 別台的檔案照樣有，下一輪匯入又把它帶回來（使用者回報：刪掉錄音卡片
    /// 「秒出現」）。要讓刪除生效，必須在自己的 oplog 寫一筆 `removeBlock`。
    ///
    /// - `known`：上次同步（匯出／匯入）結束時，使用者在畫面上看得到的物件。**只有這些**才可能是
    ///   「使用者刪的」；套件裡有、但使用者還沒看過的（剛下載、尚未匯入），不能當成刪除。
    /// - `pending`：已經決定要刪、而別台的檔案裡還有的。這台的 oplog 每次匯出都整批重建，
    ///   上一次寫的 `removeBlock` 會被一起洗掉，所以要每次重發，直到別台的檔案不再有它為止。
    private static func applyForeignDeletions(
        document: NotebookDocument, foreign: ForeignBlocks, to destination: URL, deviceId: UInt32
    ) throws {
        let key = document.id.lowercased()
        let current = objectBlockIds(of: document)
        let known = SyncKnownObjects.known(key)
        var pending = SyncKnownObjects.pending(key)
        pending.formUnion(known.intersection(foreign.ids).subtracting(current))
        pending.subtract(current)            // 使用者又加回來了（還原）
        pending.formIntersection(foreign.ids) // 別台已經沒有它了，不用再發
        SyncKnownObjects.setPending(pending, key)
        SyncKnownObjects.setKnown(current.union(known.subtracting(foreign.ids)), key)
        guard !pending.isEmpty else { return }
        let session = try PadnoteSession.openExisting(path: destination.path, deviceId: deviceId)
        for id in pending {
            try? session.removeBlock(blockId: id)
            try? session.removeObject(objectId: id)
        }
    }

    /// 從套件讀回來的信封物件（見 ObjectEnvelope.swift）。
    struct EnvelopeObjects {
        var links: [NoteLinkAttachment] = []
        var models: [Note3DAttachment] = []
        var audios: [NoteAudioAttachment] = []
        var pins: [NoteCommentPin] = []
        var tapes: [NoteTapeAttachment] = []
        var stickies: [StickyAnnotationAnchor] = []
        /// 形狀與連接線的樣式，以物件 id（小寫）為鍵。
        var shapeStyles: [String: ShapeStyleMeta] = [:]
        var connectionStyles: [String: ConnectionStyleMeta] = [:]
        /// 檔名（小寫）→ 名字。
        var recordingTitles: [String: String] = [:]
    }

    /// 解開一個衍生圖片區塊的 payload。**頁次以區塊實際所在的頁為準**，不是 payload 寫的 ——
    /// 頁面被搬動過的話 payload 裡的頁次是舊的。
    private static func collectEnvelope(
        _ appearance: String?, pageIndex: Int, into out: inout EnvelopeObjects
    ) {
        switch ObjectEnvelope.kind(of: appearance) {
        case "link":
            if var item = ObjectEnvelope.decode(NoteLinkAttachment.self, kind: "link", from: appearance) {
                item.pageIndex = pageIndex; out.links.append(item)
            }
        case "model3d":
            if var item = ObjectEnvelope.decode(Note3DAttachment.self, kind: "model3d", from: appearance) {
                item.pageIndex = pageIndex; out.models.append(item)
            }
        case "audio":
            if var item = ObjectEnvelope.decode(NoteAudioAttachment.self, kind: "audio", from: appearance) {
                item.pageIndex = pageIndex; out.audios.append(item)
            }
        case "pin":
            if var item = ObjectEnvelope.decode(NoteCommentPin.self, kind: "pin", from: appearance) {
                item.pageIndex = pageIndex; out.pins.append(item)
            }
        case "tape":
            if var item = ObjectEnvelope.decode(NoteTapeAttachment.self, kind: "tape", from: appearance) {
                item.pageIndex = pageIndex; out.tapes.append(item)
            }
        case "sticky":
            if var item = ObjectEnvelope.decode(StickyAnnotationAnchor.self, kind: "sticky", from: appearance) {
                item.pageIndex = pageIndex; out.stickies.append(item)
            }
        case "shapestyle":
            if let item = ObjectEnvelope.decode(ShapeStyleMeta.self, kind: "shapestyle", from: appearance),
               let id = item.id { out.shapeStyles[id.lowercased()] = item }
        case "connstyle":
            if let item = ObjectEnvelope.decode(ConnectionStyleMeta.self, kind: "connstyle", from: appearance),
               let id = item.id { out.connectionStyles[id.lowercased()] = item }
        case "rectitle":
            if let item = ObjectEnvelope.decode(RecordingTitle.self, kind: "rectitle", from: appearance) {
                out.recordingTitles[item.fileName.lowercased()] = item.title
            }
        default:
            break
        }
    }

    /// 別台裝置寫在套件裡的方塊與物件：id、位置、外觀。
    struct ForeignBlocks {
        var ids = Set<String>()
        var positions: [String: CGPoint] = [:]
        var appearances: [String: String] = [:]
    }

    /// 讀出**別台裝置**寫的方塊與物件。
    ///
    /// 做法：把套件裡不屬於這台裝置的 oplog 連同 manifest 複製到暫存目錄，在那裡開一個
    /// 工作階段 —— 合併出來的文件就只有別台的內容，這台自己的不會混進來。
    /// 讀不到回 `nil`（例如 manifest 壞了）；沒有別台的檔案就回空集合。
    nonisolated static func foreignBlocks(in destination: URL, deviceId: UInt32) -> ForeignBlocks? {
        let fm = FileManager.default
        let opsDirectory = destination.appending(path: "doc/ops", directoryHint: .isDirectory)
        let suffix = deviceSuffix(deviceId)
        let names = (try? fm.contentsOfDirectory(atPath: opsDirectory.path)) ?? []
        let others = names.filter { $0.hasSuffix(".oplog") && !$0.contains(suffix) }
        guard !others.isEmpty else { return ForeignBlocks() }

        let root = fm.temporaryDirectory
            .appending(path: "kairumo-foreign-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? fm.removeItem(at: root) }
        let scratch = root.appending(path: "foreign.padnote", directoryHint: .isDirectory)
        do {
            try fm.createDirectory(
                at: scratch.appending(path: "doc/ops", directoryHint: .isDirectory),
                withIntermediateDirectories: true)
            try fm.copyItem(
                at: destination.appending(path: "manifest.json"),
                to: scratch.appending(path: "manifest.json"))
            for name in others {
                try fm.copyItem(
                    at: opsDirectory.appending(path: name),
                    to: scratch.appending(path: "doc/ops/\(name)"))
            }
            let session = try PadnoteSession.openExisting(path: scratch.path, deviceId: deviceId)
            var result = ForeignBlocks()
            for pageId in try pageIds(of: session) {
                var blockIds = try session.textBlockIds(pageId: pageId)
                blockIds += try session.tableBlockIds(pageId: pageId)
                blockIds += try session.imageBlockIds(pageId: pageId)
                for blockId in blockIds {
                    let id = blockId.lowercased()
                    result.ids.insert(id)
                    if let position = try session.blockPosition(blockId: blockId), position.count >= 2 {
                        result.positions[id] = CGPoint(x: CGFloat(position[0]), y: CGFloat(position[1]))
                    }
                    if let appearance = try session.blockAppearance(blockId: blockId) {
                        result.appearances[id] = appearance
                    }
                }
                // 形狀、連接線與群組：物件樹（成員要往下遞迴）。
                var pending = try session.rootObjects(pageId: pageId)
                while let object = pending.first {
                    pending.removeFirst()
                    result.ids.insert(object.id.lowercased())
                    for memberId in object.members {
                        if let member = try session.objectNode(pageId: pageId, objectId: memberId) {
                            pending.append(member)
                        }
                    }
                }
            }
            return result
        } catch {
            return nil
        }
    }

    /// 別台寫的方塊，這台搬過或改過外觀的，把差異寫成這台的操作。
    ///
    /// 只比**語意**：外觀先套到副本上再一起編碼，格式或欄位順序不同不算不同 —— 否則每次匯出
    /// 都會多寫一批操作，而別台下一輪又下載它們。
    private static func applyForeignEdits(
        document: NotebookDocument, foreign: ForeignBlocks, to destination: URL, deviceId: UInt32,
        recordingTitles: [String: String] = [:]
    ) throws {
        struct Edit {
            var id: String
            var position: CGPoint?
            var appearance: String?
        }
        func moved(_ id: String, x: CGFloat, y: CGFloat) -> CGPoint? {
            guard let old = foreign.positions[id] else { return CGPoint(x: x, y: y) }
            return abs(old.x - x) > 0.5 || abs(old.y - y) > 0.5 ? CGPoint(x: x, y: y) : nil
        }
        var edits: [Edit] = []

        for text in document.textAttachments ?? [] {
            let id = stableBlockId(text.id)
            guard foreign.ids.contains(id) else { continue }
            var probe = text
            if let old = foreign.appearances[id] { TextBoxAppearance.apply(old, to: &probe) }
            let now = TextBoxAppearance.encode(text)
            let changed = TextBoxAppearance.encode(probe) != now
            let position = moved(id, x: text.x, y: text.y)
            if position != nil || changed {
                edits.append(Edit(id: id, position: position, appearance: changed ? now : nil))
            }
        }
        for table in document.tableAttachments ?? [] {
            let id = stableBlockId(table.id)
            guard foreign.ids.contains(id) else { continue }
            var probe = table
            if let old = foreign.appearances[id] { TableAppearance.apply(old, to: &probe) }
            let now = TableAppearance.encode(table)
            let changed = TableAppearance.encode(probe) != now
            let position = moved(id, x: table.x, y: table.y)
            if position != nil || changed {
                edits.append(Edit(id: id, position: position, appearance: changed ? now : nil))
            }
        }
        for image in document.attachments ?? [] {
            let id = stableBlockId(image.id)
            guard foreign.ids.contains(id) else { continue }
            var probe = image
            if let old = foreign.appearances[id] { ImageAppearance.apply(old, to: &probe) }
            let now = ImageAppearance.encode(image)
            let changed = ImageAppearance.encode(probe) != now
            let position = moved(id, x: image.x, y: image.y)
            if position != nil || changed {
                edits.append(Edit(id: id, position: position, appearance: changed ? now : nil))
            }
        }
        // 信封物件：內容（含位置）跟別台寫的不同，就把整個 payload 重寫成這台的外觀操作。
        // 只比 payload 的正規化字串，欄位順序或格式不同不算不同。
        func envelope<T: Encodable>(
            kind: String, id rawId: String, payload: T, x: CGFloat, y: CGFloat
        ) {
            let id = stableBlockId(rawId)
            guard foreign.ids.contains(id),
                  let now = ObjectEnvelope.canonicalPayload(payload),
                  ObjectEnvelope.canonicalPayload(of: foreign.appearances[id]) != now
            else { return }
            edits.append(Edit(
                id: id, position: CGPoint(x: x, y: y),
                appearance: ObjectEnvelope.encode(kind: kind, fileName: "\(rawId).png", payload: payload)))
        }
        for item in document.linkAttachments ?? [] {
            envelope(kind: "link", id: item.id, payload: item, x: item.x, y: item.y)
        }
        for item in document.model3DAttachments ?? [] {
            envelope(kind: "model3d", id: item.id, payload: item, x: item.x, y: item.y)
        }
        for item in document.audioAttachments ?? [] {
            envelope(kind: "audio", id: item.id, payload: item, x: item.x, y: item.y)
        }
        for item in document.commentPins ?? [] {
            envelope(kind: "pin", id: item.id, payload: item, x: item.x, y: item.y)
        }
        for item in document.tapeAttachments ?? [] {
            envelope(kind: "tape", id: item.id, payload: item, x: item.rect.minX, y: item.rect.minY)
        }
        for item in document.stickyAnchors ?? [] {
            envelope(kind: "sticky", id: item.id, payload: item,
                     x: CGFloat(item.anchorOriginX), y: CGFloat(item.anchorOriginY))
        }
        for item in document.shapeAttachments ?? [] {
            envelope(kind: "shapestyle", id: "style:" + stableBlockId(item.id), payload: ShapeStyleMeta(from: item),
                     x: item.x, y: item.y)
        }
        for item in document.connectionAttachments ?? [] {
            envelope(kind: "connstyle", id: "style:" + stableBlockId(item.id), payload: ConnectionStyleMeta(from: item),
                     x: 0, y: 0)
        }
        for (fileName, title) in recordingTitles {
            envelope(
                kind: "rectitle", id: recordingTitleBlockId(fileName),
                payload: RecordingTitle(fileName: fileName, title: title), x: 0, y: 0)
        }
        guard !edits.isEmpty else { return }

        let session = try PadnoteSession.openExisting(path: destination.path, deviceId: deviceId)
        for edit in edits {
            if let position = edit.position {
                try session.setBlockPosition(
                    blockId: edit.id, x: Float(position.x), y: Float(position.y))
            }
            if let appearance = edit.appearance {
                try session.setBlockAppearance(blockId: edit.id, json: appearance)
            }
        }
    }

    /// 把某一頁「新增加的」筆畫追加進核心套件。
    ///
    /// 編輯器的即時自動儲存原本只寫 `Drawings/*.drawing`，那是 Apple 端自己的
    /// 快取；Android、同步與 `.padnote` 套件都看不到。整本匯出可以重建套件，
    /// 但停筆後的自動儲存不能每次重建整本，否則一頁寫字會把所有附件都重寫。
    /// 這裡只做 append-only 的 ink log，和核心儲存格式一致。
    static func appendInkDelta(
        document: NotebookDocument,
        pageIndex: Int,
        strokes: [PKStroke],
        to destination: URL,
        deviceId: UInt32
    ) throws {
        guard !strokes.isEmpty else { return }

        let session: PadnoteSession
        if FileManager.default.fileExists(atPath: destination.path) {
            session = try PadnoteSession.openExisting(path: destination.path, deviceId: deviceId)
        } else {
            try FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            session = try PadnoteSession.createEmpty(
                path: destination.path,
                title: document.title,
                nowUnixMs: UInt64(document.createdAt.timeIntervalSince1970 * 1000),
                deviceId: deviceId
            )
        }

        let style = pageStyle(for: document.template)
        while Int(session.pageCount()) <= pageIndex {
            _ = try session.addPage(style: style)
        }

        let ids = try pageIds(of: session)
        guard pageIndex < ids.count else { throw BridgeError.noPages }
        let pageId = ids[pageIndex]
        try session.setPageSize(
            pageId: pageId,
            width: Float(document.pageSize.width),
            height: Float(document.height(forPage: pageIndex))
        )

        var meta = NotebookMeta(from: document)
        meta.pageIds = ids
        try session.setNotebookMeta(json: meta.encodedJSON())

        for stroke in strokes {
            let draft = InkInterop.draft(from: stroke)
            _ = try session.addStroke(
                pageId: pageId,
                tool: draft.tool,
                colorRgba: draft.colorRgba,
                baseWidth: draft.baseWidth,
                points: draft.points
            )
        }
    }

    /// 套件裡現有的頁面 id，依頁次。開不起來時回 `nil`。
    private static func existingPageIds(in package: URL, deviceId: UInt32) -> [String]? {
        let pkgName = package.deletingPathExtension().lastPathComponent
        if pkgName.caseInsensitiveCompare(recordingInboxNotebookId()) == .orderedSame {
            return ["a0d10000-0000-4000-8000-000000000002"]
        }
        guard FileManager.default.fileExists(atPath: package.path),
              let session = try? PadnoteSession.openExisting(path: package.path, deviceId: deviceId),
              let ids = try? pageIds(of: session), !ids.isEmpty
        else { return nil }
        return ids
    }

    /// 檔名裡代表這台裝置的那一段（`format-spec.md` §2）。
    static func deviceSuffix(_ deviceId: UInt32) -> String {
        String(format: "-%08x", deviceId)
    }

    /// 依 `key` 去掉重複，保留第一個、維持原順序。
    static func collapseDuplicates<T>(_ items: [T], key: (T) -> String) -> [T] {
        var seen = Set<String>()
        return items.filter { seen.insert(key($0)).inserted }
    }

    /// 錄音名字區塊的 id：由檔名決定，每台裝置、每次匯出都一樣。
    static func recordingTitleBlockId(_ fileName: String) -> String {
        "rectitle:\(fileName.lowercased())"
    }

    /// 附件 id → 核心的區塊／物件 id（小寫 UUID 字串）。
    ///
    /// 附件的 id 本來就是 UUID 字串的話原樣（轉小寫）用；不是的（舊資料、測試）就用它的
    /// SHA-256 前 16 位元組決定性地做一個 —— 同一個附件在每一台裝置、每一次匯出都得到同一個 id，
    /// 這是「重複匯出是冪等的」的前提。
    static func stableBlockId(_ raw: String) -> String {
        if let uuid = UUID(uuidString: raw) { return uuid.uuidString.lowercased() }
        var bytes = Array(SHA256.hash(data: Data(raw.utf8)).prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50 // 版本 5 樣式
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        let uuid = UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        ))
        return uuid.uuidString.lowercased()
    }

    /// 套件目錄下所有檔案的相對路徑。
    ///
    /// 一定要**遞迴**：真正的內容在 `doc/ops/` 與 `ink/` 底下。
    private static func relativeFiles(in root: URL) -> [String] {
        let fm = FileManager.default
        guard let walker = fm.enumerator(
            at: root, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]
        ) else { return [] }
        let baseStandardized = root.resolvingSymlinksInPath().standardizedFileURL.path
        let prefix = baseStandardized.hasSuffix("/") ? baseStandardized : baseStandardized + "/"
        var out: [String] = []
        for case let url as URL in walker {
            let resolved = url.resolvingSymlinksInPath().standardizedFileURL
            guard (try? resolved.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true
            else { continue }
            out.append(resolved.path.replacingOccurrences(of: prefix, with: ""))
        }
        return out
    }

    // MARK: - 匯入

    /// 從套件讀回一本可以繼續編輯的筆記。
    ///
    /// # 為什麼需要它
    ///
    /// 只有這個函式會把核心裡的**手繪筆畫、文字區塊與中繼資料**還原成
    /// App 看得懂的 `NotebookDocument`。
    static func importDocument(
        fromPackageAt path: URL,
        deviceId: UInt32,
        documentId: String? = nil
    ) throws -> ImportedNotebook {
        let session: PadnoteSession
        do {
            session = try PadnoteSession.openExisting(path: path.path, deviceId: deviceId)
        } catch {
            throw BridgeError.coreRejected(String(describing: error))
        }

        let pageIds = try pageIds(of: session)
        guard !pageIds.isEmpty else { throw BridgeError.noPages }

        var drawings: [PKDrawing] = []
        var texts: [NoteTextAttachment] = []
        var images: [NoteImageAttachment] = []
        var tables: [NoteTableAttachment] = []
        var imageData: [String: Data] = [:]
        var envelopes = EnvelopeObjects()
        var proStrokes: [[ProStroke]] = []
        var removedProStrokeIds: [Set<String>] = []

        for (index, pageId) in pageIds.enumerated() {
            // 專業筆刷（自繪引擎）的筆畫不能變成 PKStroke —— PencilKit 畫不出來，
            // 轉了也只會變成一條普通的線。另外收起來，由專業筆畫層自己畫。
            let details = try session.visibleStrokeDetails(pageId: pageId)
            drawings.append(InkInterop.drawing(from: details.filter { !brushIsCustom(tool: $0.tool) }))
            proStrokes.append(details.filter { brushIsCustom(tool: $0.tool) }.compactMap(ProStroke.init(from:)))
            removedProStrokeIds.append(Set(try session.removedStrokeIds(pageId: pageId).map { $0.lowercased() }))

            for blockId in try session.textBlockIds(pageId: pageId) {
                // 附件 id 就是核心的區塊 id：同一個方塊在每一台裝置、每一次匯入都是同一個 id，
                // 下次匯出才認得出「這個別台已經寫過了」。
                var item = NoteTextAttachment(id: blockId, pageIndex: index, text: "")
                item.text = try (session.blockText(blockId: blockId)) ?? ""
                if let position = try session.blockPosition(blockId: blockId), position.count >= 2 {
                    item.x = CGFloat(position[0])
                    item.y = CGFloat(position[1])
                }
                if let appearance = try session.blockAppearance(blockId: blockId) {
                    TextBoxAppearance.apply(appearance, to: &item)
                }
                texts.append(item)
            }

            for blockId in try session.tableBlockIds(pageId: pageId) {
                guard let core = try session.table(blockId: blockId) else { continue }
                // 內容一律以**核心的表格區塊**為準：那是別的裝置真正寫進去的
                // 東西，外觀裡的那份可能是舊的。與 Android 的 `TableStore.load`
                // 同一個判斷。
                var item = NoteTableAttachment(
                    id: blockId,
                    pageIndex: index,
                    rows: Int(core.rows),
                    cols: Int(core.cols),
                    cells: core.cells,
                    headerRow: core.headerRow
                )
                if let appearance = try session.blockAppearance(blockId: blockId) {
                    TableAppearance.apply(appearance, to: &item)
                }
                if let position = try session.blockPosition(blockId: blockId),
                   position.count >= 2
                {
                    item.x = CGFloat(position[0])
                    item.y = CGFloat(position[1])
                }
                item.mergedCells = core.mergedCells.compactMap { span in
                    guard span.count >= 4 else { return nil }
                    return NoteTableSpan(
                        row: Int(span[0]), col: Int(span[1]),
                        rowSpan: Int(span[2]), colSpan: Int(span[3])
                    )
                }
                tables.append(item)
            }

            for blockId in try session.imageBlockIds(pageId: pageId) {
                let appearance = try session.blockAppearance(blockId: blockId)
                // 連結卡片與 3D 模型在套件裡是算繪出來的圖片，真身在中繼資料裡。
                // 不跳過的話，同一個物件會變成兩份，而且每同步一趟就再多一份。
                if ImageAppearance.isDerived(appearance) {
                    collectEnvelope(appearance, pageIndex: index, into: &envelopes)
                    continue
                }

                var item = NoteImageAttachment(id: blockId, fileName: "", pageIndex: index)
                if let position = try session.blockPosition(blockId: blockId), position.count >= 2 {
                    item.x = CGFloat(position[0])
                    item.y = CGFloat(position[1])
                }
                if let size = try session.imageBlockSize(blockId: blockId), size.count >= 2 {
                    item.width = CGFloat(size[0])
                    item.height = CGFloat(size[1])
                }
                if let appearance {
                    ImageAppearance.apply(appearance, to: &item)
                }
                // 檔名沿用原本那個：每次同步都換一組新檔名的話，比對與去重就失效了。
                item.fileName = appearance.flatMap(ImageAppearance.fileName(in:))
                    ?? "\(blockId).png"

                // 位元組拿不到就跳過這張圖，而不是讓整本筆記匯不進來 ——
                // 缺一張圖，跟整本打不開，對使用者是完全不同等級的損失。
                if let blob = (try? session.blockBlobId(blockId: blockId)) ?? nil,
                   let bytes = try? session.blobBytes(blobId: blob)
                {
                    imageData[item.fileName] = Data(bytes)
                }
                images.append(item)
            }
        }

        // **舊資料的重複方塊收斂成一份。** 在有穩定 id 之前，每次匯出都會把別台的方塊再寫一遍，
        // 套件裡因此有「內容、位置、外觀完全相同」的一堆方塊。同一頁上完全相同的只留第一個；
        // 留下哪一個不重要，因為兩邊匯入時都用同一個順序挑。
        texts = collapseDuplicates(texts) {
            "\($0.pageIndex)|\($0.text)|\(Int($0.x.rounded()))|\(Int($0.y.rounded()))|\(TextBoxAppearance.encode($0))"
        }
        tables = collapseDuplicates(tables) {
            "\($0.pageIndex)|\($0.cells.joined(separator: "\u{1F}"))|\(Int($0.x.rounded()))|\(Int($0.y.rounded()))"
        }
        images = collapseDuplicates(images) {
            "\($0.pageIndex)|\($0.fileName)|\(Int($0.x.rounded()))|\(Int($0.y.rounded()))|\(Int($0.width.rounded()))|\(Int($0.height.rounded()))"
        }

        // 形狀與連接線從核心的物件樹讀回來。
        //
        // 物件 id 是核心給的，與這台裝置原本的 id 無關 —— 連接線必須用
        // **物件 id** 去對，用舊的 id 會連到不存在的形狀上。
        var shapes: [NoteShapeAttachment] = []
        var connections: [NoteConnectionAttachment] = []
        for (index, pageId) in pageIds.enumerated() {
            // 群組之後，成員就**不是根物件**了 —— 只看根層的話，整組形狀會
            // 從畫面上消失，而檔案裡其實好端端地存在。所以要往下遞迴。
            var pending: [(object: FfiObject, groupId: String?)] =
                try session.rootObjects(pageId: pageId).map { ($0, nil) }

            while let entry = pending.first {
                pending.removeFirst()
                let object = entry.object
                switch object.kind {
                case .group:
                    // 群組本身不畫，它的成員才畫。成員記下自己屬於哪一組，
                    // 下次匯出才重組得回來。
                    for memberId in object.members {
                        guard let member = try session.objectNode(
                            pageId: pageId, objectId: memberId
                        ) else { continue }
                        pending.append((member, object.id))
                    }
                case .shape:
                    guard let core = try session.shapeObject(
                        pageId: pageId, objectId: object.id
                    ) else { continue }
                    // 位移與旋轉走的是變換，不改寫形狀的原始邊界（ADR-0010）——
                    // 不套上去的話，搬動過的形狀會跳回原位、轉過的形狀會轉回正的。
                    // 取**中心**經過變換後的位置當新的中心：純平移時等於原本的
                    // `minX + dx`，有旋轉時也成立（繞中心旋轉不改變中心）。
                    let transform = (try? session.objectTransform(
                        pageId: pageId, objectId: object.id
                    )) ?? []
                    let w = CGFloat(core.maxX - core.minX)
                    let h = CGFloat(core.maxY - core.minY)
                    var originX = CGFloat(core.minX)
                    var originY = CGFloat(core.minY)
                    var rotation: Double?
                    var width = w, height = h
                    if transform.count >= 6 {
                        let cx0 = CGFloat(core.minX + core.maxX) / 2
                        let cy0 = CGFloat(core.minY + core.maxY) / 2
                        let nx = CGFloat(transform[0]) * cx0 + CGFloat(transform[2]) * cy0 + CGFloat(transform[4])
                        let ny = CGFloat(transform[1]) * cx0 + CGFloat(transform[3]) * cy0 + CGFloat(transform[5])
                        // 縮放：線性部分是「先縮放、再旋轉」，兩軸的縮放量是各自那一欄的長度。
                        // 別台裝置縮放過形狀時，大小就是靠它回來的。
                        let sx = CGFloat(hypot(transform[0], transform[1]))
                        let sy = CGFloat(hypot(transform[2], transform[3]))
                        if sx > 0.001, sy > 0.001 {
                            width = w * sx
                            height = h * sy
                        }
                        originX = nx - width / 2
                        originY = ny - height / 2
                        var degrees = Double(atan2(transform[1], transform[0])) * 180 / .pi
                        if degrees < 0 { degrees += 360 }
                        // 浮點誤差：轉了又轉回來會剩下 1e-5 度，不要當成「有旋轉」存下來。
                        if degrees > 0.01 && degrees < 359.99 { rotation = degrees }
                    }
                    var imported = NoteShapeAttachment(
                        id: object.id,
                        pageIndex: index,
                        kindName: NoteShapeAttachment.name(of: core.kind),
                        x: originX,
                        y: originY,
                        width: width,
                        height: height,
                        cornerRadius: CGFloat(core.cornerRadius),
                        label: core.text,
                        groupId: entry.groupId
                    )
                    imported.rotationDegrees = rotation
                    shapes.append(imported)
                case .connection:
                    guard let core = try session.connectionObject(
                        pageId: pageId, objectId: object.id
                    ) else { continue }
                    var imported = NoteConnectionAttachment(
                        id: object.id,
                        pageIndex: index,
                        fromShapeId: core.fromObjectId,
                        toShapeId: core.toObjectId,
                        label: core.label
                    )
                    imported.apply(core: core)
                    connections.append(imported)
                default:
                    continue
                }
            }
        }

        let targetId = documentId ?? path.deletingPathExtension().lastPathComponent
        let pathFilename = path.deletingPathExtension().lastPathComponent
        var initialTitle = session.title()
        // 這個函式是 nonisolated 的（讀套件不該在主執行緒做），
        // 所以走非隔離的快照而不是 @MainActor 的發布狀態。
        let storeItems = syncLiveNotebooks(indexJson: AccountSyncStore.indexJSONSnapshot())
        if let syncItem = storeItems.first(where: { $0.id.caseInsensitiveCompare(targetId) == .orderedSame }),
           !syncItem.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            initialTitle = syncItem.title
        }

        var document = NotebookDocument(
            id: targetId,
            title: initialTitle,
            pageCount: pageIds.count,
            template: .blank
        )
        document.textAttachments = texts.isEmpty ? nil : texts
        document.tableAttachments = tables.isEmpty ? nil : tables
        document.attachments = images.isEmpty ? nil : images
        document.shapeAttachments = shapes.isEmpty ? nil : shapes
        document.connectionAttachments = connections.isEmpty ? nil : connections

        // 中繼資料最後套：樣板、資料夾、圖釘、連結卡片、3D 模型都在裡面。
        // 讀不懂時保留預設值，筆畫與文字仍然回得來。
        var envelopeAuthoritative = false
        if let json = session.notebookMeta(), let meta = NotebookMeta.decode(from: json) {
            meta.apply(to: &document)
            envelopeAuthoritative = meta.objectEnvelopes == 1
            // 形狀與連接線的樣式（核心的物件模型沒有這些欄位）。
            if let styles = meta.shapeStyles {
                for i in shapes.indices {
                    styles[shapes[i].id.lowercased()]?.apply(to: &shapes[i])
                }
            }
            if let styles = meta.connectionStyles {
                for i in connections.indices {
                    styles[connections[i].id.lowercased()]?.apply(to: &connections[i])
                }
            }
        }

        // 形狀與連接線的樣式：逐物件信封為準（覆蓋在舊版中繼資料那份之上）。
        for i in shapes.indices {
            envelopes.shapeStyles[shapes[i].id.lowercased()]?.apply(to: &shapes[i])
        }
        for i in connections.indices {
            envelopes.connectionStyles[connections[i].id.lowercased()]?.apply(to: &connections[i])
        }

        // 信封（逐物件）為準，中繼資料清單裡信封沒有的才補上 —— Android 與舊版只寫清單。
        document.linkAttachments = ObjectEnvelope.merged(
            envelopes: envelopes.links, legacy: envelopeAuthoritative ? nil : document.linkAttachments)
        document.model3DAttachments = ObjectEnvelope.merged(
            envelopes: envelopes.models, legacy: envelopeAuthoritative ? nil : document.model3DAttachments)
        document.audioAttachments = ObjectEnvelope.merged(
            envelopes: envelopes.audios, legacy: envelopeAuthoritative ? nil : document.audioAttachments)
        document.commentPins = ObjectEnvelope.merged(
            envelopes: envelopes.pins, legacy: envelopeAuthoritative ? nil : document.commentPins)
        document.stickyAnchors = ObjectEnvelope.merged(
            envelopes: envelopes.stickies, legacy: envelopeAuthoritative ? nil : document.stickyAnchors)
        document.tapeAttachments = ObjectEnvelope.merged(
            envelopes: envelopes.tapes, legacy: envelopeAuthoritative ? nil : document.tapeAttachments)

        // 確保來自同步索引庫的權威標題不會被舊中繼資料沖掉；
        // 若標題仍為預設空白/未命名，且匯入檔名並非 UUID 亦非預設 notebook，則沿用檔名
        if let syncItem = storeItems.first(where: { $0.id.caseInsensitiveCompare(targetId) == .orderedSame }),
           !syncItem.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            document.title = syncItem.title
        } else if (document.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || document.title == "未命名筆記" || document.title == "Untitled Note" || document.title == "无标题笔记") &&
                  UUID(uuidString: pathFilename) == nil && !pathFilename.isEmpty && pathFilename != "notebook" {
            document.title = pathFilename
        }
        // 中繼資料套完之後再放回形狀：形狀的事實來源是**核心的物件樹**，
        // 不是中繼資料。兩邊都帶的話會變成兩份。
        document.shapeAttachments = shapes.isEmpty ? nil : shapes
        document.connectionAttachments = connections.isEmpty ? nil : connections

        if document.id.caseInsensitiveCompare(recordingInboxNotebookId()) == .orderedSame {
            document.pageCount = 1
        }

        // 頁面 id 一律以**檔案裡實際的那批**為準，不是中繼資料寫的那批 ——
        // 中繼資料可能是別台裝置寫的舊版本。下次匯出要沿用這批。
        return ImportedNotebook(
            document: document, drawings: drawings, imageData: imageData, pageIds: pageIds,
            proStrokes: proStrokes, removedProStrokeIds: removedProStrokeIds,
            recordingTitles: envelopes.recordingTitles
        )
    }

    /// 從套件讀回來的一本筆記。
    struct ImportedNotebook {
        let document: NotebookDocument
        /// 每一頁的手繪內容，索引與頁次相同。
        let drawings: [PKDrawing]
        /// 圖片附件的檔名 → 位元組。
        let imageData: [String: Data]
        /// 這本筆記在核心裡的頁面 id，依頁次。下次匯出要沿用它。
        let pageIds: [String]
        /// 每一頁的專業筆刷筆畫（自繪引擎），索引與頁次相同。包含這台自己的與別台的。
        var proStrokes: [[ProStroke]] = []
        /// 每一頁被擦掉（有墓碑）的筆畫 id，小寫。匯入時用它認出「自己的這一筆被別台擦掉／改掉了」。
        var removedProStrokeIds: [Set<String>] = []
        /// 檔名（小寫）→ 錄音的名字。
        var recordingTitles: [String: String] = [:]
    }

    // MARK: - 私有

    /// 寫一筆專業筆畫，**用它的套件身分當核心的筆畫 id**。
    ///
    /// 每次匯出若都由核心發新 id，同一條線在兩次匯出之間就是兩個身分，別台對它寫的墓碑
    /// （擦掉、改圖層）隨下一次匯出落空，線又冒出來。身分不是合法 UUID（不該發生）時退回舊做法。
    private static func addPro(
        _ pro: ProStroke, kind: ToolKind, to session: PadnoteSession, page pageId: String
    ) throws {
        // 圖層與線型跟著筆畫走（核心的 ink 擴充區塊），別台裝置才畫得出同樣的圖。
        if UUID(uuidString: pro.packageId) != nil {
            try session.addStrokeDraftedWithId(
                pageId: pageId,
                strokeId: pro.packageId,
                tool: kind,
                colorRgba: Data(pro.colorRGBA),
                baseWidth: pro.baseWidth,
                points: ProInk.strokePoints(pro.points),
                layer: pro.layerId,
                lineType: pro.lineTypeId
            )
        } else {
            _ = try session.addStrokeDrafted(
                pageId: pageId,
                tool: kind,
                colorRgba: Data(pro.colorRGBA),
                baseWidth: pro.baseWidth,
                points: ProInk.strokePoints(pro.points),
                layer: pro.layerId,
                lineType: pro.lineTypeId
            )
        }
    }

    /// 依頁次取出頁面 id。
    ///
    /// 核心的 FFI 只給得到第一頁的 id 與總頁數，所以這裡逐頁問 —— 不要自己
    /// 猜 id 的產生規則，那是內部實作，改了就悄悄壞掉。
    private static func pageIds(of session: PadnoteSession) throws -> [String] {
        var ids: [String] = []
        if let first = try session.firstPageId() {
            ids.append(first)
        }
        for index in 1 ..< max(Int(session.pageCount()), 1) {
            if let id = try session.pageIdAt(index: UInt32(index)) {
                ids.append(id)
            }
        }
        return ids
    }

    /// 從套件讀回來的一張圖表。
    struct ImportedChart: Hashable {
        let id: String
        let pageIndex: Int
        let spec: ChartSpec
        let x: CGFloat
        let y: CGFloat
        let width: CGFloat
        let height: CGFloat
    }

    /// 這張紙的底紋。**來源是核心的目錄**（`NoteTemplate.pageStyle`）。
    ///
    /// 原本這裡是一份手寫的對照表，於是核心的紙張從十三種長到三十三種時，
    /// 新的那二十種全部落在「switch 不完整」的編譯錯誤上 —— 那還算幸運的，
    /// 真正危險的是有人順手補一個 `default: .blank`：新紙的底紋會靜靜消失。
    static func pageStyle(for template: NoteTemplate) -> PageStyle {
        template.pageStyle
    }
}


/// 每本筆記「使用者看得到的物件 id」與「待刪的別台物件 id」，見
/// `NotebookPackageBridge.applyForeignDeletions`。存在 UserDefaults：量小、不需要跟著筆記同步
/// （同步的是刪除這個**操作**，不是這份名單）。
enum SyncKnownObjects {
    private static func key(_ kind: String, _ notebook: String) -> String {
        "kairumo.sync.\(kind).\(notebook.lowercased())"
    }

    static func known(_ notebook: String) -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: key("known", notebook)) ?? [])
    }

    static func setKnown(_ ids: Set<String>, _ notebook: String) {
        UserDefaults.standard.set(Array(ids), forKey: key("known", notebook))
    }

    static func pending(_ notebook: String) -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: key("pending", notebook)) ?? [])
    }

    static func setPending(_ ids: Set<String>, _ notebook: String) {
        UserDefaults.standard.set(Array(ids), forKey: key("pending", notebook))
    }

    /// 匯入完成後：使用者現在看得到的就是合併後的文件。
    static func recordVisible(_ document: NotebookDocument) {
        setKnown(NotebookPackageBridge.objectBlockIds(of: document), document.id)
    }
}
