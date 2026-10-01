//
//  StorageJanitor.swift
//  Kairumo
//
//  清掉 App 自己留下、再也沒有東西指到的檔案。
//
//  # 為什麼會有垃圾
//
//  - **附件圖片**（`Attachments/att_<uuid>.png`）：刪掉圖片物件、替換圖表（每次都存一張新的）、
//    取消插入，舊檔都沒有刪 —— 刪了就沒辦法復原。實機上一個 App 因此累積了幾百 MB。
//  - **頁面筆跡**（`Drawings/<筆記本>_p<N>.drawing`、`.proink*.json`，以及 `SyncBaseline/` 裡的對應檔）：
//    刪頁、整本永久刪除、頁數被修正之後，超出頁數的檔案留在原地。
//
//  # 為什麼要這麼保守
//
//  這裡刪的是使用者的資料夾。寧可留著一個沒用的檔案，也不能刪掉一個有用的：
//
//  1. **只動自己認得的檔名**（`att_<uuid>.png`、`<id>_p<N>.drawing`…），其他一律不碰
//     （`imp_*` 匯入檔、錄音、套件都不管）。
//  2. **檔案要夠舊**才算（附件 3 天、筆跡 1 天）：復原、匯入進行中、另一台裝置剛傳來還沒套用的，
//     都來得及先被引用。
//  3. **回收桶裡的筆記本也算「有在用」**：還原之後圖片要在。
//  4. **筆記本清單看起來不對勁就整個不做**（空的、同步索引裡有但本機沒有）：載入失敗時
//     「所有檔案都沒人引用」會把全部資料當垃圾。
//  5. **超出頁數的筆跡只刪空的**；有內容的留著 —— 頁數若是被錯誤地存小了，那是使用者看不到、
//     但還在的資料。

import Foundation
import PencilKit

enum StorageJanitor {

    /// 附件圖片要多舊才算垃圾。
    static let attachmentMinAge: TimeInterval = 3 * 24 * 3600
    /// 頁面筆跡要多舊才算垃圾。
    static let drawingMinAge: TimeInterval = 24 * 3600

    struct NotebookInfo: Sendable {
        let id: String
        let pageCount: Int
    }

    struct Plan: Sendable {
        var files: [URL] = []
        var bytes: Int64 = 0
        /// 留著、但看起來不該有的（超出頁數卻有內容的筆跡）。只記錄，不刪。
        var keptSuspicious: [URL] = []

        mutating func add(_ url: URL, size: Int64) {
            files.append(url)
            bytes += size
        }
    }

    // MARK: 檔名

    /// `att_<UUID>.png`。
    nonisolated static func isAttachmentImageName(_ name: String) -> Bool {
        guard name.hasPrefix("att_"), name.hasSuffix(".png") else { return false }
        let id = name.dropFirst(4).dropLast(4)
        return UUID(uuidString: String(id)) != nil
    }

    struct PageFile: Equatable {
        let notebookId: String
        let page: Int
    }

    /// `<筆記本 id>_p<N>.drawing` 或 `.proink.json` / `.proink-foreign.json`。
    nonisolated static func pageFile(named name: String) -> PageFile? {
        for suffix in [".drawing", ".proink.json", ".proink-foreign.json"] where name.hasSuffix(suffix) {
            let stem = String(name.dropLast(suffix.count))
            guard let range = stem.range(of: "_p", options: .backwards),
                  let page = Int(stem[range.upperBound...]), page >= 0
            else { return nil }
            let id = String(stem[..<range.lowerBound])
            guard !id.isEmpty else { return nil }
            return PageFile(notebookId: id, page: page)
        }
        return nil
    }

    // MARK: 規劃

    /// 找出該清的檔案。**不刪任何東西。**
    ///
    /// - Parameters:
    ///   - notebooks: 本機所有筆記本（含回收桶）。
    ///   - protectedIds: 還有別處記得的筆記本 id（同步索引）。這些的筆跡不當成孤兒。
    ///   - referencedAttachments: 被任何筆記本引用的附件檔名。
    nonisolated static func plan(
        attachmentsDirectory: URL,
        pageDirectories: [URL],
        notebooks: [NotebookInfo],
        protectedIds: Set<String>,
        referencedAttachments: Set<String>,
        now: Date = Date()
    ) -> Plan {
        var plan = Plan()
        let fm = FileManager.default

        // 4. 筆記本清單不對勁就整個不做。
        guard !notebooks.isEmpty else { return plan }

        // 附件圖片
        for url in files(in: attachmentsDirectory) where isAttachmentImageName(url.lastPathComponent) {
            guard !referencedAttachments.contains(url.lastPathComponent),
                  let info = info(of: url), now.timeIntervalSince(info.modified) >= attachmentMinAge
            else { continue }
            plan.add(url, size: info.size)
        }

        // 頁面筆跡
        let known = Dictionary(
            notebooks.map { ($0.id.lowercased(), $0.pageCount) }, uniquingKeysWith: { first, _ in first })
        let protected = Set(protectedIds.map { $0.lowercased() })
        for directory in pageDirectories {
            for url in files(in: directory) {
                guard let page = pageFile(named: url.lastPathComponent),
                      let info = info(of: url), now.timeIntervalSince(info.modified) >= drawingMinAge
                else { continue }
                let id = page.notebookId.lowercased()
                if let pages = known[id] {
                    // 筆記本在、頁還在：不動。
                    guard page.page >= max(pages, 1) else { continue }
                    // 超出頁數：只刪空的。
                    if isEmptyPageFile(url) {
                        plan.add(url, size: info.size)
                    } else {
                        plan.keptSuspicious.append(url)
                    }
                } else if protected.contains(id) {
                    continue // 同步索引還記得它，本機只是還沒載入。
                } else {
                    // 整本已經不存在（永久刪除）：筆跡沒有任何地方會再讀到它。
                    plan.add(url, size: info.size)
                }
            }
        }
        _ = fm
        return plan
    }

    /// 刪除。回傳實際刪掉的 (數量, 位元組)。刪不掉的略過。
    @discardableResult
    nonisolated static func execute(_ plan: Plan) -> (count: Int, bytes: Int64) {
        var count = 0
        var bytes: Int64 = 0
        for url in plan.files {
            let size = info(of: url)?.size ?? 0
            do {
                try FileManager.default.removeItem(at: url)
                count += 1
                bytes += size
            } catch {
                continue
            }
        }
        return (count, bytes)
    }

    // MARK: 私有

    private nonisolated static func files(in directory: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles])) ?? []
    }

    private nonisolated static func info(of url: URL) -> (size: Int64, modified: Date)? {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]),
              let modified = values.contentModificationDate else { return nil }
        return (Int64(values.fileSize ?? 0), modified)
    }

    /// 這個頁面檔是不是空的。讀不懂的一律當成「不是空的」。
    nonisolated static func isEmptyPageFile(_ url: URL) -> Bool {
        guard let data = try? Data(contentsOf: url) else { return false }
        if url.lastPathComponent.hasSuffix(".drawing") {
            guard let drawing = try? PKDrawing(data: data) else { return false }
            return drawing.strokes.isEmpty
        }
        guard let strokes = try? JSONDecoder().decode([ProStroke].self, from: data) else { return false }
        return strokes.isEmpty
    }
}
