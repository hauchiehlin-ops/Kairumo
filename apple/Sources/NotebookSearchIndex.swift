//
//  NotebookSearchIndex.swift
//  Kairumo
//
//  用核心的索引搜尋筆記內容（C：補上 Apple 端搜不到的那一半）。
//
//  # 原本搜不到什麼
//
//  首頁的搜尋是對著**記憶體裡的附件**比對：標題、文字方塊、表格、形狀標籤、
//  手寫辨識結果。那已經涵蓋了使用者打進去的字，但**搜不到**：
//
//  - 錄音的轉錄文字
//  - 匯入的 PDF 內容
//  - OCR 出來的文字
//
//  而那三樣正是「我記得我錄過／掃描過這件事」時最需要搜到的東西。
//
//  核心一直都有這個能力（`session.search`，CJK bigram 索引，五種來源全涵蓋），
//  Android 早就接上了（`library/NotebookSearch.kt`）。這個檔案是 Apple 端的
//  對應物 —— **刻意照著同一組規則**（兩個字才查、照 query 快取、
//  開不起來的那一本略過），兩邊的搜尋結果才會一樣。
//
//  # 為什麼是非同步
//
//  核心的 `search` 掛在 session 上，所以要**逐本開套件**去問。
//  在 `filteredNotebooks` 那個計算屬性裡同步做的話，使用者每打一個字
//  就會把整個筆記庫重開一遍，畫面直接卡住。
//

import Foundation

/// 用核心索引找出「哪幾本筆記裡有這個字」。
@MainActor
public final class NotebookSearchIndex: ObservableObject {

    public static let shared = NotebookSearchIndex()

    /// 查詢字數下限。
    ///
    /// bigram 索引本來就需要兩個字，而單字查詢會命中幾乎所有東西 ——
    /// 那不是搜尋，是列全部。**與 Android 的 `MIN_QUERY_LENGTH` 相同。**
    public static let minQueryLength = 2

    /// 每本最多看幾筆。只要知道「這一本有沒有」，不需要全部拿回來。
    private static let perNotebookLimit: UInt32 = 5

    /// 目前這個查詢命中的筆記本 id。
    @Published public private(set) var hits: Set<String> = []
    /// 對應 `hits` 的查詢字串。畫面用它判斷結果是不是還在算。
    @Published public private(set) var query: String = ""

    private var cache: [String: Set<String>] = [:]
    private var task: Task<Void, Never>?

    private init() {}

    /// 搜尋字串變了。**會去抖動**：使用者還在打字時每一個字都掃一遍
    /// 筆記庫，只是白費電。
    public func update(query raw: String, notebooks: [NotebookDocument], deviceId: UInt32) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        task?.cancel()

        guard trimmed.count >= Self.minQueryLength else {
            hits = []
            query = trimmed
            return
        }
        if let cached = cache[trimmed] {
            hits = cached
            query = trimmed
            return
        }

        let packages = notebooks.map { doc -> (String, String) in
            (doc.id, NotebookStore.shared.corePackagesDirectory
                .appendingPathComponent("\(doc.id.lowercased()).padnote").path)
        }
        task = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            if Task.isCancelled { return }
            let found = await Task.detached(priority: .userInitiated) { () -> Set<String> in
                var out: Set<String> = []
                for (id, path) in packages {
                    if Task.isCancelled { return out }
                    // 一本開不起來就跳過。往外丟的話，一本壞掉的筆記
                    // 會害得其他所有筆記都搜不到。
                    guard let session = try? PadnoteSession.openExisting(
                        path: path, deviceId: deviceId) else { continue }
                    let results = session.search(query: trimmed, limit: Self.perNotebookLimit)
                    if !results.isEmpty { out.insert(id) }
                }
                return out
            }.value
            if Task.isCancelled { return }
            self.cache[trimmed] = found
            // 快取只是省掉重打同一個字的成本，不需要無限長。
            if self.cache.count > 32 {
                self.cache.removeAll(keepingCapacity: true)
                self.cache[trimmed] = found
            }
            self.hits = found
            self.query = trimmed
        }
    }

    /// 這本筆記有沒有被核心索引命中。
    public func contains(_ notebookId: String) -> Bool {
        hits.contains(notebookId)
    }
}
