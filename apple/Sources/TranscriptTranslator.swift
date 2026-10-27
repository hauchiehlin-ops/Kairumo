import Foundation
import SwiftUI
import Translation

/// 逐字稿的「轉出文字語言」處理。
///
/// # 規則（核心決定，兩個平台一樣）
///
/// - 音訊語言與轉出語言的主語言相同（含 `zh-Hant` ↔ `zh-Hans`）：**不翻譯**，
///   沿用原本的轉錄結果，只做簡繁字體轉換（`localize_transcript_script`）；
/// - 主語言不同：辨識完的每一句再交給系統的 Translation 框架。
///
/// # 為什麼是系統的 Translation 框架
///
/// 在裝置上執行、免費、不需要後台，語言包由系統管理（跨 App 共用）。
/// 但**背景**取得翻譯 session（`TranslationSession(installedSource:target:)`）要 iOS／Mac Catalyst 26；
/// 更早的系統只能在 SwiftUI 畫面裡經 `.translationTask` 拿到，錄音中的背景轉錄用不了。
/// 所以 26 以下不提供翻譯，設定裡也不顯示「轉出文字語言」。
enum TranscriptTranslation {

    /// 這台裝置能不能翻譯逐字稿。
    static var isSupported: Bool {
        if #available(iOS 26.0, macCatalyst 26.0, *) { return true }
        return false
    }

    /// 把辨識結果轉成轉出文字語言。
    ///
    /// **翻譯失敗時回傳原文**（再做字體轉換）與錯誤 —— 轉出來的文字不能因為語言包沒下載就整段消失。
    static func finalize(_ texts: [String], source: String, output: String) async -> (texts: [String], error: Error?) {
        let target = transcriptOutputLanguage(source: source, output: output)
        guard transcriptNeedsTranslation(source: source, output: output) else {
            return (texts.map { localizeTranscriptScript(text: $0, uiLanguage: target) }, nil)
        }
        guard #available(iOS 26.0, macCatalyst 26.0, *) else {
            return (texts.map { localizeTranscriptScript(text: $0, uiLanguage: source) }, TranslationUnavailable())
        }
        do {
            let translated = try await TranscriptTranslator.shared.translate(texts, from: source, to: target)
            // 翻譯引擎的中文輸出不一定是使用者要的字體（例如譯成「中文」卻給簡體）。
            return (translated.map { localizeTranscriptScript(text: $0, uiLanguage: target) }, nil)
        } catch {
            StartupLogger.logKey("log_transcript_translate_fail", error.localizedDescription)
            return (texts.map { localizeTranscriptScript(text: $0, uiLanguage: source) }, error)
        }
    }

    /// App 的語言標籤 → Translation 框架的語言。
    ///
    /// 框架的清單用的是 `zh_CN`／`zh_TW`（地區），不是 `zh-Hans`／`zh-Hant`（字體）。
    static func language(for tag: String) -> Locale.Language {
        switch tag {
        case "zh-Hant": return Locale.Language(identifier: "zh-TW")
        case "zh-Hans": return Locale.Language(identifier: "zh-CN")
        default: return Locale.Language(identifier: tag)
        }
    }

    /// 長文切成適合翻譯的片段：先按換行，過長的段落再按句尾標點切。
    ///
    /// 整份逐字稿一次送進去，失敗就全部失敗、也看不到進度；一句一句送又太慢。
    static func chunks(of text: String, maxLength: Int = 400) -> [String] {
        var out: [String] = []
        for paragraph in text.components(separatedBy: "\n") {
            let trimmed = paragraph.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            guard trimmed.count > maxLength else {
                out.append(trimmed)
                continue
            }
            var current = ""
            for ch in trimmed {
                current.append(ch)
                if "。！？.!?".contains(ch), current.count >= maxLength / 2 {
                    out.append(current.trimmingCharacters(in: .whitespaces))
                    current = ""
                } else if current.count >= maxLength {
                    out.append(current)
                    current = ""
                }
            }
            let rest = current.trimmingCharacters(in: .whitespaces)
            if !rest.isEmpty { out.append(rest) }
        }
        return out
    }

    struct TranslationUnavailable: LocalizedError {
        var errorDescription: String? { L10n.t("hw_asr_translate_unsupported_os") }
    }
}

/// 系統翻譯 session 的持有者。同一組語言重複使用同一個 session（建立 session 要載入語言模型）。
@available(iOS 26.0, macCatalyst 26.0, *)
actor TranscriptTranslator {
    // profile-scope: device 只快取系統翻譯 session（語言模型），不含任何使用者資料
    static let shared = TranscriptTranslator()

    private var session: TranslationSession?
    private var pair: String = ""

    /// 依序翻譯；空白的項目原樣回傳。語言包沒有安裝時丟錯（由呼叫端保留原文）。
    func translate(_ texts: [String], from source: String, to target: String) async throws -> [String] {
        let key = "\(source)→\(target)"
        if session == nil || pair != key {
            session = TranslationSession(
                installedSource: TranscriptTranslation.language(for: source),
                target: TranscriptTranslation.language(for: target)
            )
            pair = key
        }
        guard let session else { return texts }

        let requests = texts.enumerated()
            .filter { !$0.element.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { TranslationSession.Request(sourceText: $0.element, clientIdentifier: String($0.offset)) }
        guard !requests.isEmpty else { return texts }

        do {
            let responses = try await session.translations(from: requests)
            var out = texts
            for response in responses {
                if let id = response.clientIdentifier, let index = Int(id), out.indices.contains(index) {
                    out[index] = response.targetText
                }
            }
            return out
        } catch {
            // 失敗過的 session 不再重用（例如語言包剛被刪掉）；下一次重新建立。
            self.session = nil
            pair = ""
            throw error
        }
    }
}

/// 設定裡「轉出文字語言」下方的語言包狀態與下載按鈕。
@available(iOS 26.0, macCatalyst 26.0, *)
struct TranslationPackRow: View {
    let source: String
    let output: String
    @ObservedObject private var localizationManager = LocalizationManager.shared

    @State private var status: LanguageAvailability.Status?
    @State private var request: TranslationSession.Configuration?
    @State private var errorText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                switch status {
                case .installed:
                    Label(localizationManager.localized("hw_asr_translate_pack_ready"), systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                case .supported where request != nil:
                    ProgressView()
                    Text(localizationManager.localized("hw_asr_translate_pack_downloading"))
                case .supported:
                    Button {
                        // 換一個 configuration 就會觸發 `.translationTask`，由系統跳出下載確認。
                        request = TranslationSession.Configuration(
                            source: TranscriptTranslation.language(for: source),
                            target: TranscriptTranslation.language(for: output)
                        )
                    } label: {
                        Label(localizationManager.localized("hw_asr_translate_pack_download"), systemImage: "arrow.down.circle")
                    }
                case .unsupported:
                    Label(localizationManager.localized("hw_asr_translate_pack_unsupported"), systemImage: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                default:
                    ProgressView()
                }
                Spacer()
            }
            .font(.footnote)
            if let errorText {
                Text(errorText).font(.caption).foregroundColor(.red)
            }
        }
        .task(id: "\(source)→\(output)") { await refresh() }
        .translationTask(request) { session in
            do {
                try await session.prepareTranslation()
                errorText = nil
            } catch {
                errorText = error.localizedDescription
            }
            await refresh()
            request = nil
        }
    }

    private func refresh() async {
        status = await LanguageAvailability().status(
            from: TranscriptTranslation.language(for: source),
            to: TranscriptTranslation.language(for: output)
        )
    }
}
