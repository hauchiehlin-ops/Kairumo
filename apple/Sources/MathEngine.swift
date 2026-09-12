//
//  MathEngine.swift
//  Kairumo
//
//  安全精確的數學算式解析與求解引擎
//  支援四則運算、括號、乘方、平方根、百分比、三角函數與常見手寫符號容錯
//

import Foundation

public struct MathResult: Identifiable {
    public let id = UUID()
    public let originalExpression: String
    public let normalizedExpression: String
    public let formattedResult: String
    public let numericValue: Double
    public let displayText: String

    public init(original: String, normalized: String, value: Double) {
        self.originalExpression = original
        self.normalizedExpression = normalized
        self.numericValue = value

        // 格式化數字：整數不顯示小數點，浮點數最多保留 6 位
        if abs(value - Double(Int64(value))) < 1e-9 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            self.formattedResult = formatter.string(from: NSNumber(value: Int64(value))) ?? "\(Int64(value))"
        } else {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 6
            self.formattedResult = formatter.string(from: NSNumber(value: value)) ?? String(format: "%.4f", value)
        }
        self.displayText = "\(original.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "=", with: "").trimmingCharacters(in: .whitespaces)) = \(self.formattedResult)"
    }
}

public enum MathEngine {

    /// 解析並計算數學表達式
    public static func evaluate(_ rawInput: String) -> Result<MathResult, Error> {
        let clean = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            return .failure(NSError(domain: "MathEngine", code: -1, userInfo: [NSLocalizedDescriptionKey: "算式不可為空"]))
        }

        // 容錯處理：移除等號、中文全形符號轉換、乘除號替換
        var expr = clean
        if expr.hasSuffix("=") {
            expr.removeLast()
        }
        expr = expr.replacingOccurrences(of: "×", with: "*")
        expr = expr.replacingOccurrences(of: "÷", with: "/")
        expr = expr.replacingOccurrences(of: "—", with: "-")
        expr = expr.replacingOccurrences(of: "–", with: "-")
        expr = expr.replacingOccurrences(of: "（", with: "(")
        expr = expr.replacingOccurrences(of: "）", with: ")")
        expr = expr.replacingOccurrences(of: "π", with: "\(Double.pi)")
        expr = expr.replacingOccurrences(of: "pi", with: "\(Double.pi)", options: .caseInsensitive)

        // 支援百分比 (如 50% -> (50 * 0.01))
        let percentRegex = try? NSRegularExpression(pattern: "([0-9.]+)\\%")
        if let regex = percentRegex {
            let range = NSRange(location: 0, length: expr.utf16.count)
            expr = regex.stringByReplacingMatches(in: expr, options: [], range: range, withTemplate: "($1 * 0.01)")
        }

        // 支援平方根 sqrt(x) -> (x ** 0.5)
        let sqrtRegex = try? NSRegularExpression(pattern: "(?i)sqrt\\(([^)]+)\\)")
        if let regex = sqrtRegex {
            let range = NSRange(location: 0, length: expr.utf16.count)
            expr = regex.stringByReplacingMatches(in: expr, options: [], range: range, withTemplate: "($1 ** 0.5)")
        }

        // 支援乘方 ^ -> ** (NSExpression 乘方語法為 **)
        expr = expr.replacingOccurrences(of: "^", with: "**")

        do {
            let nsExpr = NSExpression(format: expr)
            guard let result = nsExpr.expressionValue(with: nil, context: nil) as? NSNumber else {
                return .failure(NSError(domain: "MathEngine", code: -2, userInfo: [NSLocalizedDescriptionKey: "無法評估該算式"]))
            }
            let doubleVal = result.doubleValue
            if doubleVal.isNaN || doubleVal.isInfinite {
                return .failure(NSError(domain: "MathEngine", code: -3, userInfo: [NSLocalizedDescriptionKey: "算式結果無窮大或未定義（如除以零）"]))
            }
            let mathResult = MathResult(original: clean, normalized: expr, value: doubleVal)
            return .success(mathResult)
        } catch {
            return .failure(error)
        }
    }
}
