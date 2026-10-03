import XCTest

@testable import Kairumo

/// 停止錄音後的品質提示（`RecordingAdvice`）。
///
/// 判斷在核心；這裡只驗證 App 端「key 非空才顯示、不認得的 key 不顯示、
/// 每個 key 六語都有字串」。
@MainActor
final class RecordingAdviceTests: XCTestCase {

    func testOnlyKnownNonEmptyKeysAreShown() {
        XCTAssertNil(RecordingAdvice.adviceKey(raw: nil))
        XCTAssertNil(RecordingAdvice.adviceKey(raw: ""), "Good／TooShort 給空字串，不該提示")
        XCTAssertNil(RecordingAdvice.adviceKey(raw: "recording_advice_unknown"))
        for key in RecordingAdvice.knownKeys {
            XCTAssertEqual(RecordingAdvice.adviceKey(raw: key), key)
        }
    }

    func testEveryAdviceStringExistsInAllSixLanguages() {
        let keys = RecordingAdvice.knownKeys.union(["recording_advice_title", "confirm"])
        for key in keys {
            let table = LocalizationManager.generatedStrings[key]
            XCTAssertNotNil(table, "缺少 \(key)")
            for language in AppLanguage.allCases {
                let text = table?[language] ?? ""
                XCTAssertFalse(text.isEmpty, "\(key) 缺 \(language.rawValue)")
                XCTAssertNotEqual(text, key)
            }
        }
    }

    /// 錄音預設不走藍牙 HFP 輸入（見 `CoreAudioCapture.recordingCategoryOptions`）。
    func testRecordingDoesNotRouteInputToBluetoothHFP() {
        let options = CoreAudioCapture.recordingCategoryOptions
        XCTAssertFalse(options.contains(.allowBluetooth), "HFP 會把輸入切到耳機的窄頻麥克風")
        XCTAssertTrue(options.contains(.allowBluetoothA2DP))
        XCTAssertTrue(options.contains(.defaultToSpeaker))
    }
}
