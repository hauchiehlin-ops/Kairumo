import XCTest

@testable import Kairumo

/// 語音轉文字的字體與語系。
///
/// 回報是「介面是繁體中文，轉出來的文字卻是簡體」。原因有兩層：Whisper 的中文輸出
/// 多半是簡體；而 `SFSpeechRecognizer` 不認 `zh-Hant`（那是文字腳本標籤，不是地區），
/// 傳進去得到 nil 然後退回系統預設語言。
@MainActor
final class TranscriptLocalizationTests: XCTestCase {

    func testSpeechRecognizerGetsARegionLocaleNotAScriptTag() {
        XCTAssertEqual(AudioTranscriber.speechLocale(forUILanguage: "zh-Hant").identifier, "zh-TW")
        XCTAssertEqual(AudioTranscriber.speechLocale(forUILanguage: "zh-Hans").identifier, "zh-CN")
        XCTAssertEqual(AudioTranscriber.speechLocale(forUILanguage: "ja").identifier, "ja")
    }

    func testOutputLanguageDecidesTheScript() {
        // 轉出文字語言（預設＝音訊語言＝介面語言）決定字體，規則在核心。
        let simplified = "线性代数的语音识别"
        let traditional = "線性代數的語音識別"
        XCTAssertEqual(localizeTranscriptScript(text: simplified, uiLanguage: "zh-Hant"), traditional)
        XCTAssertEqual(localizeTranscriptScript(text: traditional, uiLanguage: "zh-Hans"), simplified)
        XCTAssertEqual(localizeTranscriptScript(text: simplified, uiLanguage: "zh-Hans"), simplified)
    }

    func testSameLanguageNeverGoesThroughTranslation() {
        XCTAssertFalse(transcriptNeedsTranslation(source: "zh-Hant", output: ""))
        XCTAssertFalse(transcriptNeedsTranslation(source: "zh-Hant", output: "zh-Hans"))
        XCTAssertTrue(transcriptNeedsTranslation(source: "zh-Hant", output: "en"))
    }

    func testTranslationLanguagesUseRegionsForChinese() {
        XCTAssertEqual(TranscriptTranslation.language(for: "zh-Hant").maximalIdentifier,
                       Locale.Language(identifier: "zh-TW").maximalIdentifier)
        XCTAssertEqual(TranscriptTranslation.language(for: "en").languageCode?.identifier, "en")
    }

    func testLongTranscriptIsSplitIntoSentenceChunksWithoutLosingText() {
        let sentence = "這是一個用來測試切段的句子。"
        let text = String(repeating: sentence, count: 80) + "\n\n第二段"
        let chunks = TranscriptTranslation.chunks(of: text, maxLength: 100)
        XCTAssertTrue(chunks.allSatisfy { $0.count <= 100 })
        XCTAssertEqual(chunks.last, "第二段")
        XCTAssertEqual(chunks.joined(), text.replacingOccurrences(of: "\n", with: ""))
    }
}
