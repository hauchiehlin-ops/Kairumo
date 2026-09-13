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
        deviceId: UInt32
    ) throws -> ExportSummary {
        let pageCount = max(document.pageCount, drawings.count)
        guard pageCount > 0 else { throw BridgeError.noPages }

        let session: PadnoteSession
        do {
            session = try PadnoteSession.create(
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
            var pageIds: [String] = []
            if let first = try session.firstPageId() { pageIds.append(first) }
            let style = pageStyle(for: document.template)
            while pageIds.count < pageCount {
                pageIds.append(try session.addPage(style: style))
            }

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
                    // 這張圖如果是數字製圖，設定要一起過去 —— 只帶點陣圖的話，
                    // 在 Android 上打開會是一張改不動的圖片。
                    if let spec = image.chartSpec {
                        try session.setBlockAppearance(
                            blockId: blockId, json: ChartAppearance.encode(spec))
                    }
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
