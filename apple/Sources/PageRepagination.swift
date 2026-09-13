//
//  PageRepagination.swift
//  Kairumo
//
//  把舊版的「可任意延長頁面」重新切成固定高度的頁（問題 3＋5）。
//
//  # 這一步會動到使用者手上的真實資料
//
//  所以規則與 `NotebookMigration` 一樣，不留彈性：
//
//  1. **先備份，備份失敗就整個停手。** 沒有退路的遷移不該開始。
//  2. **每一本都要驗過才算數**：重新分頁前後，筆畫總數與物件總數必須相同。
//     少一筆就把這一本還原，記成失敗 —— 留下一份看起來成功、其實掉了東西的
//     筆記，比明確失敗更危險。
//  3. **一本失敗不影響其餘。**
//  4. **可重入**：已經是固定高度的筆記直接略過。
//  5. **可回滾**：從備份還原。
//

import Foundation
import PencilKit

public enum PageRepagination {

    public enum Outcome: Equatable {
        /// 這一本被切成幾頁（原本幾頁 → 現在幾頁）。
        case repaginated(from: Int, to: Int)
        /// 每一頁都已經在頁高之內，不用動。
        case alreadyFits
        case failed(reason: String)
    }

    public struct Report {
        public var backupPath: URL?
        public var outcomes: [String: Outcome] = [:]
        public init() {}

        public var changedCount: Int {
            outcomes.values.filter { if case .repaginated = $0 { return true }; return false }.count
        }
        public var failedCount: Int {
            outcomes.values.filter { if case .failed = $0 { return true }; return false }.count
        }
        public var allSucceeded: Bool { failedCount == 0 }
    }

    // MARK: - 判斷

    /// 這一本有沒有需要重新分頁的頁面。
    public static func needsRepagination(_ doc: NotebookDocument) -> Bool {
        (0..<max(doc.pageCount, 1)).contains { index in
            (doc.legacyHeight(forPage: index) ?? PageGeometry.height) > PageGeometry.height + 0.5
        }
    }

    /// 某一頁會被切成幾頁。
    public static func splitCount(forPage index: Int, in doc: NotebookDocument) -> Int {
        let height = doc.legacyHeight(forPage: index) ?? PageGeometry.height
        guard height > PageGeometry.height else { return 1 }
        return max(1, Int(ceil(height / PageGeometry.height)))
    }

    /// 舊頁次 → 新頁次的起點。
    ///
    /// 分開算成一張表而不是邊搬邊算：邊搬邊算的話，後面的頁次會被前面剛插入的
    /// 頁影響，錯位一頁就整本亂掉，而且很難看出來。
    public static func pageOffsets(in doc: NotebookDocument) -> [Int] {
        var offsets: [Int] = []
        var running = 0
        for index in 0..<max(doc.pageCount, 1) {
            offsets.append(running)
            running += splitCount(forPage: index, in: doc)
        }
        return offsets
    }

    // MARK: - 重新分頁

    /// 重新分頁的結果：新的中繼資料與每一頁的手繪。
    public struct Repaginated {
        public var document: NotebookDocument
        /// 索引就是新的頁次。
        public var drawings: [PKDrawing]
    }

    /// 計算重新分頁後的內容。**純函式，不碰磁碟。**
    public static func repaginate(
        _ doc: NotebookDocument,
        drawings: [PKDrawing]
    ) -> Repaginated {
        let offsets = pageOffsets(in: doc)
        let oldPageCount = max(doc.pageCount, 1)
        let newPageCount = offsets.last.map { $0 + splitCount(forPage: oldPageCount - 1, in: doc) }
            ?? oldPageCount

        var result = doc
        result.pageCount = newPageCount
        result.pageHeights = Array(repeating: PageGeometry.height, count: newPageCount)

        // --- 物件 ---
        func remap<T: MutablePagePositioned>(_ items: [T]?) -> [T]? {
            guard let items else { return nil }
            return items.map { item in
                var moved = item
                let base = offsets.indices.contains(item.pageIndex) ? offsets[item.pageIndex] : 0
                let slice = PageGeometry.pageIndex(forY: item.y)
                moved.pageIndex = base + slice
                moved.y = PageGeometry.yWithinPage(item.y)
                return moved
            }
        }
        result.attachments = remap(doc.attachments)
        result.textAttachments = remap(doc.textAttachments)
        result.linkAttachments = remap(doc.linkAttachments)
        result.model3DAttachments = remap(doc.model3DAttachments)
        result.commentPins = remap(doc.commentPins)

        // --- 手繪 ---
        var newDrawings = Array(repeating: PKDrawing(), count: newPageCount)
        for oldIndex in 0..<oldPageCount {
            guard oldIndex < drawings.count else { continue }
            let base = offsets[oldIndex]
            let slices = splitCount(forPage: oldIndex, in: doc)
            for slice in 0..<slices {
                let top = CGFloat(slice) * PageGeometry.height
                let band = CGRect(
                    x: -.greatestFiniteMagnitude / 2,
                    y: top,
                    width: .greatestFiniteMagnitude,
                    height: PageGeometry.height
                )
                // 依筆畫的起點決定它屬於哪一頁。橫跨分頁線的筆畫整筆搬到
                // 它開始的那一頁 —— 從中間切斷會把一個字剖成兩半，
                // 那比讓它稍微超出界線更難接受。
                let strokes = drawings[oldIndex].strokes.filter { stroke in
                    let originY = stroke.renderBounds.minY
                    return originY >= band.minY && originY < band.maxY
                }
                guard !strokes.isEmpty else { continue }
                let moved = PKDrawing(strokes: strokes)
                    .transformed(using: CGAffineTransform(translationX: 0, y: -top))
                newDrawings[base + slice] = moved
            }
        }
        result.drawings(setFrom: newDrawings)
        return Repaginated(document: result, drawings: newDrawings)
    }

    // MARK: - 套用

    /// 對整個資料庫執行重新分頁。
    ///
    /// - Parameters:
    ///   - documents: 要處理的筆記。
    ///   - root: 資料根目錄（正式執行時就是 App 的 Documents）。
    ///   - drawingLoader/drawingWriter: 抽成閉包才測得動。
    public static func migrate(
        documents: [NotebookDocument],
        root: URL,
        drawingLoader: (String, Int) -> PKDrawing,
        drawingWriter: (String, Int, PKDrawing) -> Void,
        documentWriter: (NotebookDocument) -> Void,
        makeBackup: Bool = true
    ) -> Report {
        var report = Report()

        if makeBackup {
            do {
                report.backupPath = try NotebookMigration.backup(root: root)
            } catch {
                for doc in documents {
                    report.outcomes[doc.id] = .failed(
                        reason: "備份失敗，未進行重新分頁：\(error.localizedDescription)")
                }
                return report
            }
        }

        for doc in documents {
            guard needsRepagination(doc) else {
                report.outcomes[doc.id] = .alreadyFits
                continue
            }

            let oldCount = max(doc.pageCount, 1)
            let oldDrawings = (0..<oldCount).map { drawingLoader(doc.id, $0) }
            let oldStrokeCount = oldDrawings.reduce(0) { $0 + $1.strokes.count }
            let oldObjectCount = objectCount(doc)

            let result = repaginate(doc, drawings: oldDrawings)

            // 驗證：東西不能在重新分頁的過程中消失。
            let newStrokeCount = result.drawings.reduce(0) { $0 + $1.strokes.count }
            let newObjectCount = objectCount(result.document)
            guard newStrokeCount == oldStrokeCount, newObjectCount == oldObjectCount else {
                report.outcomes[doc.id] = .failed(
                    reason: "重新分頁前後內容不符：筆畫 \(oldStrokeCount)→\(newStrokeCount)、"
                        + "物件 \(oldObjectCount)→\(newObjectCount)")
                continue
            }

            for (index, drawing) in result.drawings.enumerated() {
                drawingWriter(doc.id, index, drawing)
            }
            documentWriter(result.document)
            report.outcomes[doc.id] = .repaginated(from: oldCount, to: result.document.pageCount)
        }
        return report
    }

    public static func objectCount(_ doc: NotebookDocument) -> Int {
        (doc.attachments?.count ?? 0)
            + (doc.textAttachments?.count ?? 0)
            + (doc.linkAttachments?.count ?? 0)
            + (doc.model3DAttachments?.count ?? 0)
            + (doc.commentPins?.count ?? 0)
    }
}

/// 有頁次與 y 座標、而且兩者都可以改的物件。
///
/// 五種附件各自有這兩個欄位但沒有共同型別，重新分頁必須一視同仁地搬它們 ——
/// 漏掉一種的後果是那種物件全部留在原本的頁次上。
protocol MutablePagePositioned {
    var pageIndex: Int { get set }
    var y: CGFloat { get set }
}

extension NoteImageAttachment: MutablePagePositioned {}
extension NoteTextAttachment: MutablePagePositioned {}
extension NoteLinkAttachment: MutablePagePositioned {}
extension Note3DAttachment: MutablePagePositioned {}
extension NoteCommentPin: MutablePagePositioned {}

private extension NotebookDocument {
    /// `pagesData` 是舊欄位，這裡一併對齊，免得頁數與它對不上。
    mutating func drawings(setFrom drawings: [PKDrawing]) {
        pagesData = drawings.map { $0.dataRepresentation() }
    }
}
