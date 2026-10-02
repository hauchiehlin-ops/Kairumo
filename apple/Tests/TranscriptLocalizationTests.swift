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

    func testTraditionalInterfaceTurnsSimplifiedTranscriptIntoTraditional() {
        let saved = LocalizationManager.shared.currentLanguage
        defer { LocalizationManager.shared.currentLanguage = saved }

        LocalizationManager.shared.currentLanguage = .zhHant
        XCTAssertEqual(AudioTranscriber.localizedScript("线性代数的语音识别"), "線性代數的語音識別")

        LocalizationManager.shared.currentLanguage = .zhHans
        XCTAssertEqual(
            AudioTranscriber.localizedScript("线性代数的语音识别"), "线性代数的语音识别",
            "簡體介面不該被轉成繁體")
    }
}
