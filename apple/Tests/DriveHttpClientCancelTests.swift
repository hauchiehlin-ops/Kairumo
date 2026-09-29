import XCTest

@testable import Kairumo

/// 使用者中斷同步之後，下一輪同步不可以讓 App 崩潰。
///
/// # 這條測試守的是什麼
///
/// TestFlight 4.15.0（build 71）的崩潰報告：`abort()`，堆疊是
/// `CloudSync.refresh` → `FfiSyncSession.refresh` → Rust 的
/// `__rust_foreign_exception`。
///
/// 原因是 `cancelAll()` 對共用的 URLSession 呼叫了 `invalidateAndCancel()`。
/// 那個 session 會被下一輪同步重複使用（`resetCancellation()` 只清旗標），
/// 於是 `dataTask(with:)` 打在已失效的 session 上，Foundation 丟出
/// `NSGenericException`。那是 Objective-C 例外 —— Swift 的 `catch` 接不到，
/// 而 Rust 的 `catch_unwind` 只認自己的 panic，遇到外來例外就直接 `abort()`。
///
/// **這種崩潰在測試行程裡也一樣是整個行程死掉**，所以這條測試「通過」就
/// 代表沒有丟例外；失敗的樣子是整個測試執行中斷，不是一行斷言訊息。
final class DriveHttpClientCancelTests: XCTestCase {

    override func tearDown() {
        DriveHttpClient.resetCancellation()
        super.tearDown()
    }

    func testRequestAfterCancelAndResetDoesNotRaiseAnException() {
        let client = DriveHttpClient(accessToken: "test-token")

        // 使用者按了「中斷同步」，下一輪同步開頭清掉旗標 —— 與
        // `CloudSync.reclaimDeleted` / `wipeCloud` 的順序一樣。
        DriveHttpClient.cancelAll()
        DriveHttpClient.resetCancellation()

        // 用不存在的 file:// 網址：立刻失敗，完全不碰網路。不能拿本機的
        // 空埠來試 —— session 設了 `waitsForConnectivity`，連不上會一路等到
        // 60 秒逾時、還重試四次（實測 255 秒）。
        //
        // 這裡要的不是請求成功，而是**打得出去而不崩潰**：失敗必須以
        // Swift 錯誤的形式回來。
        XCTAssertThrowsError(
            try client.getJson(url: "file:///kairumo-test-does-not-exist", query: [])
        ) { error in
            XCTAssertTrue(
                error is FfiDriveError,
                "失敗應該是 FfiDriveError，實際是 \(type(of: error))：\(error)")
        }
    }
}
