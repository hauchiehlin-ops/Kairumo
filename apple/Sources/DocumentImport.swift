//
//  DocumentImport.swift
//  Kairumo
//
//  「匯入文件」：把 Markdown／JSON／Word／Excel 變成**目前這本筆記上**
//  看得到、改得動的原生物件（文字方塊、表格、圖片）。
//
//  # 原本為什麼「點了沒反應」
//
//  舊版 `NotebookStore.importDocument` 有三個互相掩護的問題：
//
//  1. 傳給核心的是 `outcome.storedName`（只有檔名），核心要讀的卻是完整路徑 ——
//     讀不到檔，`catch` 只 `print` 一行，使用者什麼都看不到。
//  2. 就算讀得到，也是寫進磁碟上的**核心套件**，再用套件覆蓋 store 裡的筆記；
//     而編輯器持有的是自己的 `notebook` 副本，從來不會從 store 重讀，
//     下一次存檔就把匯入的內容蓋回去。
//  3. Markdown 與 JSON 走的是「新增頁面」那條 API，連頁面都不在目前這一頁。
//
//  # 現在的作法
//
//  在**暫存套件**裡讓核心解析（`importEmbedded` 會把 docx／xlsx／md／json
//  展開成原生區塊），讀回來之後由編輯器把物件合併進自己的 `notebook`，
//  超出頁高的部分接到後面新插入的頁面。核心解析、平台合併，兩邊分工與
//  協同、同步那一條路相同；Android 端 `DocumentImport.kt` 走同一個流程。
//

import Foundation

@MainActor
enum DocumentImport {

    enum Failure: Error {
        case unreadable
        case empty
    }

    /// 解析檔案。回傳的物件座標是核心排版出來的（由上往下堆疊）。
    static func parse(fileURL: URL, title: String) throws -> NotebookPackageBridge.ImportedNotebook {
        let fm = FileManager.default
        let scratch = fm.temporaryDirectory
            .appending(path: "doc-import-\(UUID().uuidString).padnote", directoryHint: .isDirectory)
        defer { try? fm.removeItem(at: scratch) }

        let device = NotebookMigration.deviceId
        let session = try PadnoteSession.createEmpty(
            path: scratch.path,
            title: title,
            nowUnixMs: UInt64(max(0, Date().timeIntervalSince1970 * 1000)),
            deviceId: device)
        let pageId = try session.addPage(style: NotebookPackageBridge.pageStyle(for: .blank))
        // **完整路徑**。核心自己讀檔，給檔名的話會在它的工作目錄底下找而失敗。
        _ = try session.importEmbedded(pageId: pageId, path: fileURL.path)

        let imported = try NotebookPackageBridge.importDocument(
            fromPackageAt: scratch, deviceId: device, documentId: UUID().uuidString)
        let doc = imported.document
        let isEmpty = (doc.textAttachments ?? []).isEmpty
            && (doc.tableAttachments ?? []).isEmpty
            && (doc.attachments ?? []).isEmpty
        if isEmpty { throw Failure.empty }
        return imported
    }

    // MARK: - 版面

    /// UUIDv7 前 48 位元（十二個十六進位字元）：毫秒時間戳。
    nonisolated static func timestampKey(_ id: String) -> String {
        String(id.replacingOccurrences(of: "-", with: "").lowercased().prefix(12))
    }

    /// 一個物件排好之後的位置。`pageOffset` 是相對於匯入起點頁的頁數。
    struct Placement: Equatable {
        var pageOffset: Int
        var y: CGFloat
    }

    /// 文字方塊預估的高度。
    ///
    /// 核心建立區塊時**沒有給位置**（每一塊都落在預設座標，疊成一團）。
    /// 要由上往下排，就得先知道每一塊多高；真正的斷行在算繪時才發生，
    /// 所以這裡用字寬估：ASCII 約 0.55 個字級、其餘（中日韓）約 1 個字級。
    /// 估多一點比估少好 —— 少估會讓下一塊壓在上面，多估只是空白。
    nonisolated static func estimatedHeight(text: String, fontSize: CGFloat, width: CGFloat) -> CGFloat {
        let usable = max(40, width - 16)
        var lines = 0
        for paragraph in text.split(separator: "\n", omittingEmptySubsequences: false) {
            var run: CGFloat = 0
            for ch in paragraph {
                run += ch.isASCII ? fontSize * 0.55 : fontSize
            }
            lines += max(1, Int((run / usable).rounded(.up)))
        }
        return CGFloat(lines) * fontSize * 1.4 + 18
    }

    /// 把一串高度由上往下排進一頁頁的可用範圍。超出頁底的接到下一頁。
    ///
    /// 單一物件比一頁還高的話，獨佔一頁（不能無限往下一頁推）。
    nonisolated static func flow(heights: [CGFloat], gap: CGFloat = 12) -> [Placement] {
        let top = PageGeometry.printableInset
        let bottom = PageGeometry.height - PageGeometry.printableInset
        var page = 0
        var y = top
        var result: [Placement] = []
        for h in heights {
            if y > top && y + h > bottom {
                page += 1
                y = top
            }
            result.append(Placement(pageOffset: page, y: y))
            y += h + gap
        }
        return result
    }
}
