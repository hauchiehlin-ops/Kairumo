import Foundation

/// 非畫面程式（同步、錄音、匯出）組使用者看得到的訊息時用的查表與格式化。
///
/// 畫面程式用 `localizationManager.localized(_:)`。背景執行緒與靜態函式碰不到那個
/// `@MainActor` 物件，所以這裡走 `LocalizationManager.localizedString` 的快照 ——
/// 讀到舊值的最壞後果只是一句訊息用了上一個語言。
///
/// **訊息一律走這裡，不要在程式裡寫死任何語言的字。** 切換語言之後，其他語言的使用者看到的
/// 就是那一句寫死的話（歷史上同步狀態、錄音錯誤都這樣漏過）。
public enum L10n {
    /// 查字串表。
    public static func t(_ key: String) -> String {
        LocalizationManager.localizedString(key)
    }

    /// 查字串表並代入參數：`%1@`、`%2@`… 依編號取代；沒有編號的 `%@` 依序取代。
    public static func f(_ key: String, _ args: any CustomStringConvertible...) -> String {
        var text = t(key)
        let values = args.map { "\($0)" }
        for (index, value) in values.enumerated() {
            let numbered = "%\(index + 1)@"
            if text.contains(numbered) {
                text = text.replacingOccurrences(of: numbered, with: value)
            } else if let range = text.range(of: "%@") {
                text.replaceSubrange(range, with: value)
            }
        }
        return text
    }
}

extension L10n {
    /// 錄音清單上的轉錄狀態。存檔的是當時寫下的字（舊版是中文），顯示時才換成目前語言。
    public static func transcriptionStatus(_ stored: String) -> String {
        switch stored {
        case "已完成", "Done": return t("transcription_done")
        case "轉錄就緒": return t("transcription_ready")
        default: return stored
        }
    }
}

extension L10n {
    /// 核心（Rust）丟出來的錯誤訊息是**中文**（開發語言）。其他語言的使用者看到一串看不懂的中文
    /// 沒有任何幫助，所以非中文介面改顯示通用訊息（細節仍在日誌裡）。
    ///
    /// 只用在「確定是核心產生的字串」上。Swift 這邊組的訊息本來就已經在地化，不要經過這裡
    /// （日文也有漢字，看漢字判斷會誤殺）。
    public static func coreText(_ message: String) -> String {
        let lang = LocalizationManager.snapshotLanguage
        if lang == .zhHant || lang == .zhHans { return message }
        let hasCJK = message.unicodeScalars.contains { (0x3400...0x9FFF).contains($0.value) }
        return hasCJK ? t("error_generic") : message
    }

    /// 使用者看得到的錯誤文字：核心的錯誤（UniFFI 產生的 `Ffi*` 型別）走 `coreText`，
    /// 其餘（系統、Swift 端已在地化的）原樣。
    public static func errorText(_ error: Error) -> String {
        let raw = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        return String(describing: type(of: error)).hasPrefix("Ffi") ? coreText(raw) : raw
    }
}

/// 同步訊息的「這是錯誤」標記。
///
/// 畫面要依訊息決定顯示紅色與否。原本是看訊息裡有沒有「失敗」「錯誤」「逾時」這幾個**中文詞** ——
/// 訊息一翻成別的語言就再也不會變紅。現在由產生訊息的地方明說它是錯誤（前綴一個固定的符號），
/// 畫面只認符號，與語言無關。
enum SyncText {
    static let errorMark = "⚠️ "

    /// 把一則訊息標成錯誤。
    static func error(_ message: String) -> String {
        message.hasPrefix(errorMark) ? message : errorMark + message
    }

    static func isError(_ message: String?) -> Bool {
        message?.hasPrefix(errorMark) ?? false
    }
}
