//
//  NotebookPlainText.swift
//  Kairumo
//
//  把一則筆記攤成純文字（工作項 S-20）。
//
//  # 為什麼不是直接餵 markdown 匯出
//
//  匯出的 markdown 帶著版面：頁碼、圖片佔位、表格的管線符號。那些對模型
//  是雜訊 —— 一份滿是 `| --- | --- |` 的輸入，摘要會開始講表格的欄位。
//
//  # 為什麼來源要與搜尋一致
//
//  這裡取的五種內容與首頁搜尋比對的**完全一樣**（標題、手寫辨識、文字方塊、
//  表格逐格、形狀標籤）。不一致的話會出現一個很難解釋的狀況：使用者搜得到
//  某句話，但摘要說筆記裡沒有提到它。
//

import Foundation

extension NotebookDocument {

    /// 這則筆記的純文字。給摘要與待辦抽取用。
    ///
    /// `@MainActor`：`displayTitle()` 是主執行緒隔離的。呼叫端本來就在畫面上
    /// 按按鈕，文字取出來之後才丟去背景跑模型。
    ///
    /// 空白與只有空格的段落會被丟掉 —— 模型會把一整排空行當成章節分隔，
    /// 然後為每一段「章節」各寫一句摘要。
    @MainActor
    func plainText() -> String {
        var parts: [String] = [displayTitle()]

        // 手寫辨識的結果。**放在打字內容前面**：手寫多半是主體，
        // 而文字方塊常常只是標註。
        if let recognized = recognizedText {
            // 字典的順序不固定，排過才穩 —— 不排的話同一則筆記每次跑出來的
            // 摘要都不一樣，而使用者會以為模型在亂講。
            parts.append(contentsOf: recognized.keys.sorted().compactMap { recognized[$0] })
        }

        parts.append(contentsOf: (textAttachments ?? []).map(\.text))

        // 表格逐格。加上換行而不是接成一長串：接起來的話「姓名 王小明 電話」
        // 會被讀成一句話。
        for table in tableAttachments ?? [] {
            parts.append(table.cells.joined(separator: "\n"))
        }

        parts.append(contentsOf: (shapeAttachments ?? []).map(\.label))

        return
            parts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }
}
