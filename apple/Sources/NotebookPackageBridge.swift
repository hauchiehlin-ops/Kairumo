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
            case .coreRejected(let detail):
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
                pageIds.append(try session.addPage(style: style))
            }

            // 筆記本層級的中繼資料（樣板、資料夾、圖釘、連結卡片、3D、頁面 id）。
            // 核心沒有這些概念，不另外寫進去的話，在另一台裝置上整批消失。
            var meta = NotebookMeta(from: document)
            meta.pageIds = pageIds
            try session.setNotebookMeta(json: meta.encodedJSON())

            for (index, pageId) in pageIds.enumerated() {
                // 頁面高度是內容的一部分：使用者向下延長過的頁面若沒寫進去，
                // 另一個平台會看到一頁被截短的筆記。
                try session.setPageSize(
                    pageId: pageId,
                    width: Float(PageThumbnailRenderer.minPageWidth),
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
                        pageId: pageId, content: text.text, style: .body)
                    try session.setBlockPosition(
                        blockId: blockId, x: Float(text.x), y: Float(text.y))
                    // 顏色、邊框、段落也要跨過去。只帶文字與位置的話，
                    // 使用者在另一個平台打開會看到一個白底無行距的方框。
                    try session.setBlockAppearance(
                        blockId: blockId, json: TextBoxAppearance.encode(text))
                    summary.textBlockCount += 1
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
                        width: Float(model.width), height: Float(model.height))
                    try session.setBlockPosition(
                        blockId: blockId, x: Float(model.x), y: Float(model.y))
                    // 標記成衍生圖片：它的真身在筆記本中繼資料裡，匯入時要跳過
                    // 這一張，否則同一個模型會變成兩份。
                    try session.setBlockAppearance(
                        blockId: blockId,
                        json: ImageAppearance.encodeDerived(
                            objectKind: "model3d", fileName: "\(model.id).png"))
                    summary.imageCount += 1
                }

                for link in document.linkAttachments?.filter({ $0.pageIndex == index }) ?? [] {
                    guard let png = PageThumbnailRenderer.renderObjectImage(link)?.pngData()
                    else { continue }
                    let blob = try session.putBlob(bytes: png)
                    let blockId = try session.addImage(
                        pageId: pageId, blob: blob,
                        width: Float(link.width), height: Float(max(60, link.height)))
                    try session.setBlockPosition(
                        blockId: blockId, x: Float(link.x), y: Float(link.y))
                    try session.setBlockAppearance(
                        blockId: blockId,
                        json: ImageAppearance.encodeDerived(
                            objectKind: "link", fileName: "\(link.id).png"))
                    summary.imageCount += 1
                }

                for image in document.attachments?.filter({ $0.pageIndex == index }) ?? [] {
                    // 讀不到某張圖不該讓整本筆記匯不出去 —— 缺一張圖，
                    // 跟整份匯出失敗，對使用者是完全不同等級的損失。
                    guard let bytes = imageData[image.fileName] else { continue }
                    let blob = try session.putBlob(bytes: bytes)
                    let blockId = try session.addImage(
                        pageId: pageId, blob: blob,
                        width: Float(image.width), height: Float(image.height))
                    try session.setBlockPosition(
                        blockId: blockId, x: Float(image.x), y: Float(image.y))
                    // 圓角、邊框、陰影、濾鏡、旋轉，以及「這是不是一張圖表」。
                    // 只帶點陣圖的話，在另一台裝置上會變成一張沒有樣式的方形照片，
                    // 而且圖表會改不動。
                    try session.setBlockAppearance(
                        blockId: blockId, json: ImageAppearance.encode(image))
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
            .appendingPathComponent("pdf-\(UUID().uuidString).padnote")
        defer { try? FileManager.default.removeItem(at: staging) }

        try export(
            document: document, drawings: drawings, imageData: imageData,
            to: staging, deviceId: deviceId)

        let session = try PadnoteSession.openExisting(path: staging.path, deviceId: deviceId)
        return try session.exportPdf()
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
                to: destination, deviceId: deviceId, pageIds: pageIds)
        }

        let staging = fm.temporaryDirectory
            .appendingPathComponent("kairumo-staging-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: staging) }
        let fresh = staging.appendingPathComponent(destination.lastPathComponent)

        let summary = try export(
            document: document, drawings: drawings, imageData: imageData,
            to: fresh, deviceId: deviceId, pageIds: pageIds)

        let suffix = deviceSuffix(deviceId)
        // 1. 先清掉這台裝置舊的 oplog 與筆畫檔 —— 不清的話新舊會疊加。
        for relative in relativeFiles(in: destination) where relative.contains(suffix) {
            try? fm.removeItem(at: destination.appendingPathComponent(relative))
        }
        // 2. 再把新的搬過去。blob 與 manifest 缺的才補，不覆蓋既有的。
        for relative in relativeFiles(in: fresh) {
            let src = fresh.appendingPathComponent(relative)
            let dst = destination.appendingPathComponent(relative)
            let isOwn = relative.contains(suffix)
            if !isOwn && fm.fileExists(atPath: dst.path) { continue }
            try? fm.createDirectory(
                at: dst.deletingLastPathComponent(), withIntermediateDirectories: true)
            let bytes = try Data(contentsOf: src)
            try bytes.write(to: dst, options: .atomic)
        }
        return summary
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
        var out: [String] = []
        for case let url as URL in walker {
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true
            else { continue }
            out.append(url.path.replacingOccurrences(of: root.path + "/", with: ""))
        }
        return out
    }

    // MARK: - 匯入

    /// 從套件讀回一本可以繼續編輯的筆記。
    ///
    /// # 為什麼需要它
    ///
    /// 沒有這一支，同步就是**單向**的：檔案下載得到，卻變不回一本筆記。
    /// 使用者在 A 裝置寫、B 裝置打開什麼也沒有 —— 而那正是他要的那件事。
    ///
    /// - Returns: 文件本身、每一頁的手繪內容，以及圖片附件的檔名 → 位元組
    ///   （呼叫端負責把它們存進自己的附件目錄）。
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
        var imageData: [String: Data] = [:]

        for (index, pageId) in pageIds.enumerated() {
            drawings.append(InkInterop.drawing(from: try session.visibleStrokeDetails(pageId: pageId)))

            for blockId in try session.textBlockIds(pageId: pageId) {
                var item = NoteTextAttachment(pageIndex: index, text: "")
                item.text = (try session.blockText(blockId: blockId)) ?? ""
                if let position = try session.blockPosition(blockId: blockId), position.count >= 2 {
                    item.x = CGFloat(position[0])
                    item.y = CGFloat(position[1])
                }
                if let appearance = try session.blockAppearance(blockId: blockId) {
                    TextBoxAppearance.apply(appearance, to: &item)
                }
                texts.append(item)
            }

            for blockId in try session.imageBlockIds(pageId: pageId) {
                let appearance = try session.blockAppearance(blockId: blockId)
                // 連結卡片與 3D 模型在套件裡是算繪出來的圖片，真身在中繼資料裡。
                // 不跳過的話，同一個物件會變成兩份，而且每同步一趟就再多一份。
                if ImageAppearance.isDerived(appearance) { continue }

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
                   let bytes = try? session.blobBytes(blobId: blob) {
                    imageData[item.fileName] = Data(bytes)
                }
                images.append(item)
            }
        }

        var document = NotebookDocument(
            id: documentId ?? path.deletingPathExtension().lastPathComponent,
            title: session.title(),
            pageCount: pageIds.count,
            template: .blank
        )
        document.textAttachments = texts.isEmpty ? nil : texts
        document.attachments = images.isEmpty ? nil : images

        // 中繼資料最後套：樣板、資料夾、圖釘、連結卡片、3D 模型都在裡面。
        // 讀不懂時保留預設值，筆畫與文字仍然回得來。
        if let json = session.notebookMeta(), let meta = NotebookMeta.decode(from: json) {
            meta.apply(to: &document)
        }

        // 頁面 id 一律以**檔案裡實際的那批**為準，不是中繼資料寫的那批 ——
        // 中繼資料可能是別台裝置寫的舊版本。下次匯出要沿用這批。
        return ImportedNotebook(
            document: document, drawings: drawings, imageData: imageData, pageIds: pageIds)
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
        if let first = try session.firstPageId() { ids.append(first) }
        for index in 1..<max(Int(session.pageCount()), 1) {
            if let id = try session.pageIdAt(index: UInt32(index)) { ids.append(id) }
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

    static func pageStyle(for template: NoteTemplate) -> PageStyle {
        switch template {
        case .blank, .moodboardMatrix, .goldenRatio, .orthographic3View,
             .userJourneyFlow, .mobileWireframe:
            return .blank
        case .lined:
            return .lined
        case .grid, .blueprintMetric, .isometricGrid, .webResponsiveGrid:
            return .grid
        case .dotGridFine:
            return .dotted
        case .cornell:
            return .cornell
        }
    }
}
