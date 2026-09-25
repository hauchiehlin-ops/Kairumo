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
        pageIds knownPageIds: [String]? = nil
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
            // 有已知的頁面 id 就照用 —— 頁面身分要跟著筆記走，不是跟著某一次
            // 匯出走，否則兩台裝置的頁永遠不會收斂。
            for id in (knownPageIds ?? []).prefix(pageCount) {
                try session.addPageWithId(pageId: id, style: style)
                pageIds.append(id)
            }
            while pageIds.count < pageCount {
                try pageIds.append(session.addPage(style: style))
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

                for text in document.textAttachments?.filter({ $0.pageIndex == index }) ?? [] {
                    let blockId = try session.addText(
                        pageId: pageId, content: text.text, style: .body
                    )
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
                    let blockId = try session.insertTable(
                        pageId: pageId,
                        rows: UInt32(table.rows),
                        cols: UInt32(table.cols),
                        cells: table.cells,
                        headerRow: table.headerRow
                    )
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

                // 3D 模型與連結卡片：核心的文件模型沒有這兩種型別，直接跳過的話
                // 匯出的 PDF 就會少掉它們。算繪成圖片帶進去 —— 使用者看到的
                // 是同一個東西，只是在 PDF 裡它是一張圖而不是可轉的模型。
                for model in document.model3DAttachments?.filter({ $0.pageIndex == index }) ?? [] {
                    guard let png = PageThumbnailRenderer.renderObjectImage(model)?.pngData()
                    else { continue }
                    let blob = try session.putBlob(bytes: png)
                    let blockId = try session.addImage(
                        pageId: pageId, blob: blob,
                        width: Float(model.width), height: Float(model.height)
                    )
                    try session.setBlockPosition(
                        blockId: blockId, x: Float(model.x), y: Float(model.y)
                    )
                    // 標記成衍生圖片：它的真身在筆記本中繼資料裡，匯入時要跳過
                    // 這一張，否則同一個模型會變成兩份。
                    try session.setBlockAppearance(
                        blockId: blockId,
                        json: ImageAppearance.encodeDerived(
                            objectKind: "model3d", fileName: "\(model.id).png"
                        )
                    )
                    summary.imageCount += 1
                }

                for link in document.linkAttachments?.filter({ $0.pageIndex == index }) ?? [] {
                    guard let png = PageThumbnailRenderer.renderObjectImage(link)?.pngData()
                    else { continue }
                    let blob = try session.putBlob(bytes: png)
                    let blockId = try session.addImage(
                        pageId: pageId, blob: blob,
                        width: Float(link.width), height: Float(max(60, link.height))
                    )
                    try session.setBlockPosition(
                        blockId: blockId, x: Float(link.x), y: Float(link.y)
                    )
                    try session.setBlockAppearance(
                        blockId: blockId,
                        json: ImageAppearance.encodeDerived(
                            objectKind: "link", fileName: "\(link.id).png"
                        )
                    )
                    summary.imageCount += 1
                }

                for audio in document.audioAttachments?.filter({ $0.pageIndex == index }) ?? [] {
                    guard let png = PageThumbnailRenderer.renderObjectImage(audio)?.pngData()
                    else { continue }
                    let blob = try session.putBlob(bytes: png)
                    let blockId = try session.addImage(
                        pageId: pageId, blob: blob,
                        width: Float(audio.width), height: Float(audio.height)
                    )
                    try session.setBlockPosition(
                        blockId: blockId, x: Float(audio.x), y: Float(audio.y)
                    )
                    try session.setBlockAppearance(
                        blockId: blockId,
                        json: ImageAppearance.encodeDerived(
                            objectKind: "audio", fileName: "\(audio.id).png"
                        )
                    )
                    summary.imageCount += 1
                }

                // 形狀與連接線寫成**核心的原生物件**，不是平台自己另存的 JSON。
                //
                // 差別在於：原生物件跨得過平台 —— Android 讀的是同一組物件。
                // 存在筆記檔的 JSON 裡只有這個平台看得懂，同一張流程圖傳過去
                // 會整個消失，而且不會有任何錯誤訊息。
                var shapeObjectIds: [String: String] = [:]
                for shape in document.shapeAttachments?.filter({ $0.pageIndex == index }) ?? [] {
                    let objectId = try session.insertShape(
                        pageId: pageId,
                        kind: shape.kind,
                        minX: Float(shape.x), minY: Float(shape.y),
                        maxX: Float(shape.x + shape.width), maxY: Float(shape.y + shape.height),
                        cornerRadius: Float(shape.cornerRadius),
                        text: shape.label
                    )
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
                    guard objectIds.count > 1 else { continue }
                    _ = try? session.groupObjects(pageId: pageId, objectIds: objectIds)
                }

                for link in document.connectionAttachments?.filter({ $0.pageIndex == index }) ?? [] {
                    // 兩端都要找得到對應的核心物件。找不到就跳過這一條 ——
                    // 寫進去的話會是一條指向不存在物件的線。
                    guard let from = shapeObjectIds[link.fromShapeId],
                          let to = shapeObjectIds[link.toShapeId] else { continue }
                    _ = try session.insertConnection(
                        pageId: pageId,
                        fromObjectId: from, toObjectId: to,
                        fromAnchor: .center, toAnchor: .center,
                        route: .straight,
                        startCap: .none, endCap: .arrow,
                        label: link.label
                    )
                    summary.connectionCount += 1
                }

                for image in document.attachments?.filter({ $0.pageIndex == index }) ?? [] {
                    // 讀不到某張圖不該讓整本筆記匯不出去 —— 缺一張圖，
                    // 跟整份匯出失敗，對使用者是完全不同等級的損失。
                    guard let bytes = imageData[image.fileName] else { continue }
                    let blob = try session.putBlob(bytes: bytes)
                    let blockId = try session.addImage(
                        pageId: pageId, blob: blob,
                        width: Float(image.width), height: Float(image.height)
                    )
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
    /// Goodnotes / Notability / PDF Expert 打開後可以直接繼續改那些筆畫。
    ///
    /// 而且 Android 走的是同一支匯出器 —— 兩個平台匯出的 PDF 結構相同，
    /// 不是各寫一個「差不多」的產生器。
    static func exportPdf(
        document: NotebookDocument,
        drawings: [PKDrawing],
        imageData: [String: Data] = [:],
        deviceId: UInt32
    ) throws -> Data {
        // 用一個暫存套件當中繼。它在匯出完就沒有用了。
        let staging = FileManager.default.temporaryDirectory
            .appending(path: "pdf-\(UUID().uuidString).padnote")
        defer { try? FileManager.default.removeItem(at: staging) }

        try export(
            document: document, drawings: drawings, imageData: imageData,
            to: staging, deviceId: deviceId
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
        pageIds knownPageIds: [String]? = nil
    ) throws -> ExportSummary {
        let fm = FileManager.default
        // 已知的頁面 id 優先用呼叫端給的；沒給就沿用套件裡現有的那批 ——
        // 換一批新 id 等於把同一頁分裂成兩頁。
        let pageIds = knownPageIds ?? existingPageIds(in: destination, deviceId: deviceId)

        // 目的地還不存在時就是一般的匯出，沒有別人的東西要保護。
        guard fm.fileExists(atPath: destination.path) else {
            return try export(
                document: document, drawings: drawings, imageData: imageData,
                to: destination, deviceId: deviceId, pageIds: pageIds
            )
        }

        let staging = fm.temporaryDirectory
            .appending(path: "kairumo-staging-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? fm.removeItem(at: staging) }
        let fresh = staging.appending(path: destination.lastPathComponent)

        let summary = try export(
            document: document, drawings: drawings, imageData: imageData,
            to: fresh, deviceId: deviceId, pageIds: pageIds
        )

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
        return summary
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

        for (index, pageId) in pageIds.enumerated() {
            try drawings.append(InkInterop.drawing(from: session.visibleStrokeDetails(pageId: pageId)))

            for blockId in try session.textBlockIds(pageId: pageId) {
                var item = NoteTextAttachment(pageIndex: index, text: "")
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
                    continue
                }

                var item = NoteImageAttachment(fileName: "", pageIndex: index)
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
                    // 位移走的是變換，不改寫形狀的原始邊界（ADR-0010）——
                    // 不套上去的話，搬動過的形狀會跳回原位。
                    let transform = (try? session.objectTransform(
                        pageId: pageId, objectId: object.id
                    )) ?? []
                    let dx = transform.count >= 6 ? CGFloat(transform[4]) : 0
                    let dy = transform.count >= 6 ? CGFloat(transform[5]) : 0
                    shapes.append(
                        NoteShapeAttachment(
                            id: object.id,
                            pageIndex: index,
                            kindName: NoteShapeAttachment.name(of: core.kind),
                            x: CGFloat(core.minX) + dx,
                            y: CGFloat(core.minY) + dy,
                            width: CGFloat(core.maxX - core.minX),
                            height: CGFloat(core.maxY - core.minY),
                            cornerRadius: CGFloat(core.cornerRadius),
                            label: core.text,
                            groupId: entry.groupId
                        )
                    )
                case .connection:
                    guard let core = try session.connectionObject(
                        pageId: pageId, objectId: object.id
                    ) else { continue }
                    connections.append(
                        NoteConnectionAttachment(
                            id: object.id,
                            pageIndex: index,
                            fromShapeId: core.fromObjectId,
                            toShapeId: core.toObjectId,
                            label: core.label
                        )
                    )
                default:
                    continue
                }
            }
        }

        let targetId = documentId ?? path.deletingPathExtension().lastPathComponent
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
        if let json = session.notebookMeta(), let meta = NotebookMeta.decode(from: json) {
            meta.apply(to: &document)
        }
        // 中繼資料套完之後再放回形狀：形狀的事實來源是**核心的物件樹**，
        // 不是中繼資料。兩邊都帶的話會變成兩份。
        document.shapeAttachments = shapes.isEmpty ? nil : shapes
        document.connectionAttachments = connections.isEmpty ? nil : connections

        // 頁面 id 一律以**檔案裡實際的那批**為準，不是中繼資料寫的那批 ——
        // 中繼資料可能是別台裝置寫的舊版本。下次匯出要沿用這批。
        return ImportedNotebook(
            document: document, drawings: drawings, imageData: imageData, pageIds: pageIds
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
    }

    // MARK: - 私有

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
