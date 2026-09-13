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
            case .coreRejected(let detail): return "核心拒絕了這份資料：\(detail)"
            case .noPages: return "這本筆記沒有任何頁面"
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
                    summary.textBlockCount += 1
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
