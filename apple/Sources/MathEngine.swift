//
//  MathEngine.swift
//  Kairumo
//
//  算式求值。
//
//  # 這一層現在只做格式，不做計算
//
//  求值走核心的 `mathEvaluate` —— 原本是 `NSExpression`，那有兩個問題：
//
//  1. 它是 Foundation 專屬的，Android 沒有對應品。兩邊各寫一份的結果是同一條
//     算式可能算出不同答案，而使用者是把它當計算機在用的。
//  2. **它對錯誤輸入會丟出 Objective-C 例外，Swift 攔不到** —— 使用者打錯一個
//     字，整個 App 直接當掉。
//

import Foundation

public struct MathResult: Identifiable {
    public let id = UUID()
    public let originalExpression: String
    public let normalizedExpression: String
    public let formattedResult: String
    public let numericValue: Double
    public let displayText: String

    public init(original: String, normalized: String, value: Double, formatted: String) {
        self.originalExpression = original
        self.normalizedExpression = normalized
        self.numericValue = value
        self.formattedResult = formatted
        let clean = original
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)
        self.displayText = "\(clean) = \(formatted)"
    }
}

/// 求值失敗。`localizationKey` 是要顯示給使用者看的訊息鍵。
public struct MathError: LocalizedError {
    public let localizationKey: String
    public var errorDescription: String? {
        // localizedUnsafe：錯誤訊息會在非主執行緒組成，而字串表是唯讀的
        // 靜態資料，從哪個執行緒讀都一樣（與 NotebookMigration 的 L() 同理）。
        LocalizationManager.shared.localizedUnsafe(localizationKey)
    }
}

public enum MathEngine {

    /// 求值。看不懂就回錯誤，不會當掉。
    public static func evaluate(_ rawInput: String) -> Result<MathResult, Error> {
        let outcome = mathEvaluate(expression: rawInput)
        guard outcome.ok else {
            return .failure(MathError(
                localizationKey: outcome.errorKey.isEmpty
                    ? "math_error_bad_expression"
                    : outcome.errorKey))
        }
        return .success(MathResult(
            original: rawInput,
            normalized: outcome.normalized,
            value: outcome.value,
            formatted: outcome.formatted
        ))
    }
}
