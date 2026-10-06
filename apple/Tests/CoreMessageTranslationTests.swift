import XCTest
@testable import Kairumo

/// 核心（Rust）的診斷訊息是繁體中文；介面邊界依樣式表換成使用者的語言。
/// 這裡守：樣式比得到、動態片段原樣帶進去、巢狀訊息與「、」清單會遞迴翻譯、
/// 比不到的才退成通用訊息，而且繁體中文使用者完全不受影響。
final class CoreMessageTranslationTests: XCTestCase {

    private func with(_ language: AppLanguage, _ body: () -> Void) {
        let saved = LocalizationManager.snapshotLanguage
        defer { LocalizationManager.snapshotLanguage = saved }
        LocalizationManager.snapshotLanguage = language
        body()
    }

    func testAKnownMessageIsTranslatedAndKeepsItsDynamicPart() {
        with(.en) { XCTAssertEqual(L10n.coreText("找不到頁面：abc-123"), "Page not found: abc-123") }
        with(.ja) { XCTAssertEqual(L10n.coreText("找不到頁面：abc-123"), "ページが見つかりません: abc-123") }
        with(.ko) { XCTAssertEqual(L10n.coreText("找不到頁面：abc-123"), "페이지를 찾을 수 없습니다: abc-123") }
        with(.th) { XCTAssertEqual(L10n.coreText("找不到頁面：abc-123"), "ไม่พบหน้า: abc-123") }
        with(.zhHans) { XCTAssertEqual(L10n.coreText("找不到頁面：abc-123"), "找不到页面：abc-123") }
    }

    func testTraditionalChineseIsLeftAlone() {
        with(.zhHant) {
            XCTAssertEqual(L10n.coreText("找不到頁面：abc"), "找不到頁面：abc")
            XCTAssertEqual(L10n.coreText("從來沒見過的訊息"), "從來沒見過的訊息")
        }
    }

    func testANestedCoreMessageIsTranslatedRecursively() {
        with(.en) {
            XCTAssertEqual(L10n.coreText("讀不到 a.json：IO 錯誤：權限不足：x"),
                           "Cannot read a.json: I/O error: Permission denied: x")
        }
    }

    func testAnEnumeratedListIsTranslatedItemByItem() {
        with(.en) { XCTAssertEqual(L10n.coreText("需要：麥克風、手寫辨識"), "Needs: Microphone, Handwriting recognition") }
        with(.ja) { XCTAssertEqual(L10n.coreText("需要：麥克風、手寫辨識"), "必要なもの: マイク、手書き認識") }
    }

    func testRunsOfWhitespaceInTheSourceDoNotBreakMatching() {
        // Rust 原始碼的字串用 `\` 續行時，中間會留一長串空白。
        with(.en) {
            XCTAssertTrue(L10n.coreText("這本筆記是在復原碼還不能解鎖的版本建立的 ——                  它的復原碼從來沒有被用來包住金鑰，只有密碼開得了")
                .hasPrefix("This notebook was created"))
        }
    }

    func testAnUnknownChineseMessageFallsBackToTheGenericOneOnlyWhenNothingMatches() {
        with(.en) { XCTAssertEqual(L10n.coreText("一則沒有登記的新訊息"), L10n.t("error_generic")) }
        with(.en) { XCTAssertEqual(L10n.coreText("plain english from the system"), "plain english from the system") }
    }

    func testSyncLogLinesAreTranslatedAtDisplayTimeButUnknownOnesPassThrough() {
        with(.en) {
            XCTAssertEqual(L10n.logText("【資料夾同步】全部完成。"), "[Folder sync] All done.")
            XCTAssertEqual(L10n.logText("步驟 2 完成。上傳: 3, 下載: 1, 新增: 0"), "Step 2 done. Uploaded: 3, downloaded: 1, new: 0")
            // 日誌不退成通用訊息：認不得的就原樣，免得把有用的資訊整行吃掉。
            XCTAssertEqual(L10n.logText("某一行沒登記的日誌"), "某一行沒登記的日誌")
        }
        with(.zhHant) { XCTAssertEqual(L10n.logText("【資料夾同步】全部完成。"), "【資料夾同步】全部完成。") }
    }

    /// 樣式表的每一條都要有六語譯文：這是 `scripts/core_messages.py check` 的執行期版本，
    /// 避免產生檔與目錄漂開。
    func testEveryPatternHasAllSixLanguages() {
        XCTAssertGreaterThan(CoreMessagePatterns.all.count, 250)
        for (key, _) in CoreMessagePatterns.all {
            for language in AppLanguage.allCases {
                let saved = LocalizationManager.snapshotLanguage
                LocalizationManager.snapshotLanguage = language
                let text = LocalizationManager.localizedString(key)
                LocalizationManager.snapshotLanguage = saved
                XCTAssertNotEqual(text, key, "\(key) 缺 \(language)")
            }
        }
    }
}
