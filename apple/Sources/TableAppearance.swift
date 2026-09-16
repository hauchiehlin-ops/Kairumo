//
//  TableAppearance.swift
//  Kairumo
//
//  表格外觀的跨平台編碼（`format-spec.md` §6.2）。
//
//  # 為什麼需要它
//
//  在此之前，`NotebookPackageBridge` **完全沒有處理表格** —— 一個字都沒有。
//  於是 Apple 端使用者畫的表格：
//
//  - 匯出 `.padnote` 時整張消失
//  - 匯出 PDF／PNG、列印時整張消失（那條路要先寫進核心）
//  - 同步到 Android 打開時整張消失
//
//  而畫面上還在，因為它活在 Apple 自己的 JSON 裡。使用者不會發現東西掉了，
//  直到他在另一台裝置上打開 —— 那時已經來不及了。
//
//  Android 端一直都有寫進核心（`TableStore.persist` 走 `insert_table`），
//  所以這不是「兩邊都還沒做」，是**只有 Apple 漏了**。
//
//  鍵名與 Android 的 `TableAppearance` / `NoteTable.encodedJson()` 逐字相同。
//  改這裡之前先確認那邊要不要一起改。
//

import Foundation

enum TableAppearance {

    private static let objectKey = "object"
    private static let objectValue = "table"
    private static let tableKey = "table"

    /// 把表格外觀編成 JSON。
    ///
    /// `nil` 的欄位**不寫進去**：接收端才分得出「沒設定」與「設成透明」。
    static func encode(_ item: NoteTableAttachment) -> String {
        var table: [String: Any] = [
            "id": item.id,
            "x": item.x,
            "y": item.y,
            "width": item.width,
            "rows": item.rows,
            "cols": item.cols,
            "cells": item.cells,
            "headerRow": item.headerRow,
            "fontSize": item.fontSize,
            "mergedCells": item.mergedCells.map {
                ["row": $0.row, "col": $0.col, "rowSpan": $0.rowSpan, "colSpan": $0.colSpan]
            }
        ]
        if let value = item.rotationDegrees { table["rotationDegrees"] = value }
        if let value = item.ruleColorHex { table["ruleColorHex"] = value }
        if let value = item.headerBackgroundHex { table["headerBackgroundHex"] = value }

        let wrapper: [String: Any] = [objectKey: objectValue, tableKey: table]
        guard let data = try? JSONSerialization.data(withJSONObject: wrapper, options: [.sortedKeys]),
              let text = String(data: data, encoding: .utf8)
        else { return "{}" }
        return text
    }

    /// 從 JSON 還原表格外觀。認不得的內容回 `nil`。
    ///
    /// 儲存格內容不從這裡取 —— 它的權威來源是核心的表格區塊本身
    /// （`session.table(id)`）。這裡只帶核心不認得的**外觀**欄位。
    /// 兩邊都取的話，兩人同時編輯時會互相覆蓋。
    static func apply(_ json: String, to item: inout NoteTableAttachment) {
        guard let data = json.data(using: .utf8),
              let wrapper = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              wrapper[objectKey] as? String == objectValue,
              let map = wrapper[tableKey] as? [String: Any]
        else { return }

        if let value = map["x"] as? Double { item.x = CGFloat(value) }
        if let value = map["y"] as? Double { item.y = CGFloat(value) }
        if let value = map["width"] as? Double { item.width = CGFloat(value) }
        if let value = map["fontSize"] as? Double { item.fontSize = CGFloat(value) }
        if let value = map["rotationDegrees"] as? Double { item.rotationDegrees = value }
        if let value = map["ruleColorHex"] as? String { item.ruleColorHex = value }
        if let value = map["headerBackgroundHex"] as? String { item.headerBackgroundHex = value }
        if let spans = map["mergedCells"] as? [[String: Any]] {
            item.mergedCells = spans.compactMap { span in
                guard let row = span["row"] as? Int, let col = span["col"] as? Int,
                      let rowSpan = span["rowSpan"] as? Int, let colSpan = span["colSpan"] as? Int
                else { return nil }
                return NoteTableSpan(row: row, col: col, rowSpan: rowSpan, colSpan: colSpan)
            }
        }
    }
}
