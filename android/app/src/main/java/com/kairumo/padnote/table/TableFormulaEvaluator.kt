package com.kairumo.padnote.table

import java.text.DecimalFormat

/**
 * 專業文字智庫 / 試算表輕量級公式解譯器（Android 端）。
 *
 * 與 Apple 端 `TableFormulaEvaluator.swift` 保持相同規格與演算法：
 * 支援 `=SUM`, `=AVG`, `=AVERAGE`, `=COUNT`, `=MAX`, `=MIN` 與單一儲存格參照（如 `=A1`）。
 */
object TableFormulaEvaluator {

    private val decimalFormat = DecimalFormat("#.##")

    /**
     * 若內容是以 "=" 開頭的公式，進行計算並回傳格式化結果；否則原樣回傳。
     */
    fun evaluateCell(
        content: String,
        allCells: List<String>,
        rows: Int,
        cols: Int
    ): String {
        val trimmed = content.trim()
        if (!trimmed.startsWith("=") || trimmed.length <= 1) {
            return content
        }

        val expr = trimmed.substring(1).trim().uppercase()

        // 1. 函式匹配：SUM, AVERAGE / AVG, COUNT, MAX, MIN
        matchFunction(expr, "SUM")?.let { match ->
            val values = extractRangeValues(match, allCells, rows, cols)
            val sum = values.sum()
            return formatNumber(sum)
        }

        (matchFunction(expr, "AVERAGE") ?: matchFunction(expr, "AVG"))?.let { match ->
            val values = extractRangeValues(match, allCells, rows, cols)
            if (values.isEmpty()) return "0"
            val avg = values.sum() / values.size
            return formatNumber(avg)
        }

        matchFunction(expr, "COUNT")?.let { match ->
            val values = extractRangeValues(match, allCells, rows, cols)
            return values.size.toString()
        }

        matchFunction(expr, "MAX")?.let { match ->
            val values = extractRangeValues(match, allCells, rows, cols)
            val maxVal = values.maxOrNull() ?: return "0"
            return formatNumber(maxVal)
        }

        matchFunction(expr, "MIN")?.let { match ->
            val values = extractRangeValues(match, allCells, rows, cols)
            val minVal = values.minOrNull() ?: return "0"
            return formatNumber(minVal)
        }

        // 2. 單一儲存格參照（如 =A1）
        resolveSingleCell(expr, allCells, rows, cols)?.let { singleVal ->
            return singleVal
        }

        return content
    }

    private fun matchFunction(expr: String, name: String): String? {
        if (expr.startsWith("$name(") && expr.endsWith(")")) {
            return expr.substring(name.length + 1, expr.length - 1)
        }
        return null
    }

    /**
     * 提取如 "A1:B3" 或 "A1,B2" 的所有數值
     */
    private fun extractRangeValues(
        rangeStr: String,
        allCells: List<String>,
        rows: Int,
        cols: Int
    ): List<Double> {
        val results = mutableListOf<Double>()
        val parts = rangeStr.split(",").map { it.trim() }

        for (part in parts) {
            if (part.contains(":")) {
                val rangeParts = part.split(":").map { it.trim() }
                if (rangeParts.size == 2) {
                    val start = parseCellCoord(rangeParts[0])
                    val end = parseCellCoord(rangeParts[1])
                    if (start != null && end != null) {
                        val minR = minOf(start.first, end.first)
                        val maxR = maxOf(start.first, end.first)
                        val minC = minOf(start.second, end.second)
                        val maxC = maxOf(start.second, end.second)

                        for (r in minR..maxR) {
                            for (c in minC..maxC) {
                                if (r in 0 until rows && c in 0 until cols) {
                                    val idx = r * cols + c
                                    if (idx < allCells.size) {
                                        val text = allCells[idx].trim()
                                        text.toDoubleOrNull()?.let { results.add(it) }
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                parseCellCoord(part)?.let { (r, c) ->
                    if (r in 0 until rows && c in 0 until cols) {
                        val idx = r * cols + c
                        if (idx < allCells.size) {
                            val text = allCells[idx].trim()
                            text.toDoubleOrNull()?.let { results.add(it) }
                        }
                    }
                }
            }
        }
        return results
    }

    /**
     * 解析座標，如 "A1" -> Pair(0, 0), "B3" -> Pair(2, 1)
     * 回傳 Pair(row, col)
     */
    private fun parseCellCoord(coord: String): Pair<Int, Int>? {
        val trimmed = coord.trim().uppercase()
        if (trimmed.isEmpty()) return null

        var colLetters = ""
        var rowDigits = ""

        for (ch in trimmed) {
            if (ch in 'A'..'Z') {
                colLetters += ch
            } else if (ch in '0'..'9') {
                rowDigits += ch
            }
        }

        if (colLetters.isEmpty() || rowDigits.isEmpty()) return null

        var col = 0
        for (ch in colLetters) {
            col = col * 26 + (ch - 'A' + 1)
        }
        col -= 1

        val rowNum = rowDigits.toIntOrNull() ?: return null
        val row = rowNum - 1

        return if (row >= 0 && col >= 0) Pair(row, col) else null
    }

    private fun resolveSingleCell(
        ref: String,
        allCells: List<String>,
        rows: Int,
        cols: Int
    ): String? {
        val coord = parseCellCoord(ref) ?: return null
        val (r, c) = coord
        if (r in 0 until rows && c in 0 until cols) {
            val idx = r * cols + c
            if (idx < allCells.size) {
                return allCells[idx]
            }
        }
        return null
    }

    private fun formatNumber(valDouble: Double): String {
        return if (valDouble == kotlin.math.floor(valDouble) && !valDouble.isInfinite()) {
            valDouble.toLong().toString()
        } else {
            decimalFormat.format(valDouble)
        }
    }
}
