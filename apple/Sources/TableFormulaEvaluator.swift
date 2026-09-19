//
//  TableFormulaEvaluator.swift
//  Kairumo
//
//  專業文字智庫 / 試算表輕量級公式解譯器（支援 =SUM, =AVG, =COUNT, =MAX, =MIN, 基礎四則運算）
//

import Foundation

public struct TableFormulaEvaluator {

    /// 若內容是以 "=" 開頭的公式，進行計算並回傳格式化結果；否則原樣回傳。
    public static func evaluateCell(
        content: String,
        allCells: [String],
        rows: Int,
        cols: Int
    ) -> String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("="), trimmed.count > 1 else {
            return content
        }

        let expr = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        // 1. 函式匹配：SUM, AVERAGE / AVG, COUNT, MAX, MIN
        if let match = matchFunction(expr: expr, name: "SUM") {
            let values = extractRangeValues(rangeStr: match, allCells: allCells, rows: rows, cols: cols)
            let sum = values.reduce(0.0, +)
            return formatNumber(sum)
        } else if let match = matchFunction(expr: expr, name: "AVERAGE") ?? matchFunction(expr: expr, name: "AVG") {
            let values = extractRangeValues(rangeStr: match, allCells: allCells, rows: rows, cols: cols)
            guard !values.isEmpty else { return "0" }
            let avg = values.reduce(0.0, +) / Double(values.count)
            return formatNumber(avg)
        } else if let match = matchFunction(expr: expr, name: "COUNT") {
            let values = extractRangeValues(rangeStr: match, allCells: allCells, rows: rows, cols: cols)
            return "\(values.count)"
        } else if let match = matchFunction(expr: expr, name: "MAX") {
            let values = extractRangeValues(rangeStr: match, allCells: allCells, rows: rows, cols: cols)
            guard let maxVal = values.max() else { return "0" }
            return formatNumber(maxVal)
        } else if let match = matchFunction(expr: expr, name: "MIN") {
            let values = extractRangeValues(rangeStr: match, allCells: allCells, rows: rows, cols: cols)
            guard let minVal = values.min() else { return "0" }
            return formatNumber(minVal)
        }

        // 2. 單一儲存格參照（如 =A1）
        if let singleVal = resolveSingleCell(ref: expr, allCells: allCells, rows: rows, cols: cols) {
            return singleVal
        }

        return content
    }

    private static func matchFunction(expr: String, name: String) -> String? {
        if expr.hasPrefix("\(name)(") && expr.hasSuffix(")") {
            let start = expr.index(expr.startIndex, offsetBy: name.count + 1)
            let end = expr.index(before: expr.endIndex)
            return String(expr[start..<end])
        }
        return nil
    }

    /// 提取如 "A1:B3" 或 "A1,B2" 的所有數值
    private static func extractRangeValues(
        rangeStr: String,
        allCells: [String],
        rows: Int,
        cols: Int
    ) -> [Double] {
        var results: [Double] = []
        let parts = rangeStr.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }

        for part in parts {
            if part.contains(":") {
                let rangeParts = part.split(separator: ":").map { String($0).trimmingCharacters(in: .whitespaces) }
                if rangeParts.count == 2,
                   let start = parseCellCoord(rangeParts[0]),
                   let end = parseCellCoord(rangeParts[1]) {
                    let minR = min(start.row, end.row)
                    let maxR = max(start.row, end.row)
                    let minC = min(start.col, end.col)
                    let maxC = max(start.col, end.col)

                    for r in minR...maxR {
                        for c in minC...maxC {
                            if r < rows && c < cols {
                                let idx = r * cols + c
                                if idx < allCells.count {
                                    let text = allCells[idx].trimmingCharacters(in: .whitespacesAndNewlines)
                                    if let num = Double(text) {
                                        results.append(num)
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                if let coord = parseCellCoord(part), coord.row < rows && coord.col < cols {
                    let idx = coord.row * cols + coord.col
                    if idx < allCells.count {
                        let text = allCells[idx].trimmingCharacters(in: .whitespacesAndNewlines)
                        if let num = Double(text) {
                            results.append(num)
                        }
                    }
                }
            }
        }
        return results
    }

    private static func resolveSingleCell(
        ref: String,
        allCells: [String],
        rows: Int,
        cols: Int
    ) -> String? {
        guard let coord = parseCellCoord(ref), coord.row < rows, coord.col < cols else {
            return nil
        }
        let idx = coord.row * cols + coord.col
        return idx < allCells.count ? allCells[idx] : nil
    }

    /// 解析如 "A1" -> (row: 0, col: 0), "B3" -> (row: 2, col: 1)
    private static func parseCellCoord(_ str: String) -> (row: Int, col: Int)? {
        let upper = str.uppercased().trimmingCharacters(in: .whitespaces)
        guard let firstChar = upper.first, firstChar.isLetter else { return nil }
        let col = Int(firstChar.asciiValue! - Character("A").asciiValue!)
        let rowStr = String(upper.dropFirst())
        guard let row = Int(rowStr), row > 0 else { return nil }
        return (row: row - 1, col: col)
    }

    private static func formatNumber(_ val: Double) -> String {
        if val.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(val))"
        } else {
            return String(format: "%.2f", val)
        }
    }
}
