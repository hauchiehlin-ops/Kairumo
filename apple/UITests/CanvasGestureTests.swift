//
//  CanvasGestureTests.swift
//  KairumoUITests
//
//  畫布手勢：兩指捏合到底有沒有作用。
//
//  # 為什麼需要這一條
//
//  使用者回報「雙指縮放模式無法落地」，而**看程式碼是看不出來的**：
//  `minimumZoomScale` / `maximumZoomScale` 設了、delegate 接了、
//  `viewForZooming` 也回了第一個子視圖 —— 每一項單獨看都對。
//
//  中間任何一層都會讓它靜靜地失效：另一個手勢辨識器把觸控吃掉、
//  scroll view 在某個模式下被停用、`viewForZooming` 回到錯的子視圖。
//  這幾種在程式碼上長得一模一樣，只有實際捏一次才分得出來。
//

import XCTest

final class CanvasGestureTests: XCTestCase {

    /// 兩指捏合要真的改變縮放倍率。
    func testPinchZoomsTheCanvas() {
        let app = XCUIApplication()
        app.launchEnvironment["KAIRUMO_UITEST"] = "1"
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))

        guard openSeedNotebook(app) else { return }

        // **要抓 scroll view 那一個。**
        //
        // `descendants(matching: .any)` 的 `firstMatch` 抓到的是型別
        // `Other` 的那個 —— 同一個識別碼在樹上不只一個元素（SwiftUI 的
        // 包裝層會把它繼承下去），而捏合要送給真正的 `UIScrollView`。
        // 抓錯的症狀是 `value` 一直是空字串，看起來像「讀數沒掛上」。
        let canvas = app.scrollViews.matching(identifier: "editor.canvas").firstMatch
        guard canvas.waitForExistence(timeout: 15) else {
            XCTFail("找不到畫布的 scroll view。掛著 editor.canvas 的元素有："
                    + app.descendants(matching: .any)
                        .matching(identifier: "editor.canvas")
                        .allElementsBoundByIndex
                        .map { "\($0.elementType.rawValue)" }
                        .joined(separator: ", "))
            return
        }

        let before = canvas.value as? String
        XCTAssertNotNil(
            before,
            "畫布沒有回報縮放倍率 —— 讀數只在 KAIRUMO_UITEST=1 時掛上，"
                + "環境變數沒傳到？")

        // 放大。velocity 要夠大，太小的話會被當成雜訊而不觸發手勢。
        canvas.pinch(withScale: 2.5, velocity: 3.0)

        let after = canvas.value as? String
        XCTAssertNotEqual(
            before, after,
            "兩指捏合之後縮放倍率沒有變（前：\(before ?? "nil")，後：\(after ?? "nil")）"
                + " —— 捏合手勢沒有生效。")
    }

    /// 縮放之後再捏回去，倍率要回得來。
    ///
    /// 只測「會變」不夠：夾在上下限上動不了、或每次都跳到同一個值，
    /// 都會讓上面那條通過，而使用者感覺到的還是「縮放怪怪的」。
    func testPinchZoomsBackOut() {
        let app = XCUIApplication()
        app.launchEnvironment["KAIRUMO_UITEST"] = "1"
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))

        guard openSeedNotebook(app) else { return }

        let canvas = app.scrollViews.matching(identifier: "editor.canvas").firstMatch
        guard canvas.waitForExistence(timeout: 15) else {
            XCTFail("找不到畫布的 scroll view")
            return
        }

        canvas.pinch(withScale: 2.5, velocity: 3.0)
        let zoomedIn = zoomValue(canvas)
        canvas.pinch(withScale: 0.4, velocity: -3.0)
        let zoomedOut = zoomValue(canvas)

        XCTAssertGreaterThan(zoomedIn, 1.0, "放大之後倍率應該大於 1")
        XCTAssertLessThan(
            zoomedOut, zoomedIn,
            "捏回去之後倍率沒有變小（放大後 \(zoomedIn)，捏回後 \(zoomedOut)）")
    }

    /// 從讀數裡取**縮放倍率**。
    ///
    /// 讀數是 `zoom:1.000 strokes:3` —— 兩個欄位。原本這裡是
    /// `split(separator: ":").last`，在只有 `zoom:` 一個欄位的年代是對的，
    /// 加上筆畫數之後它抓到的是**筆畫數**，而那個數字照樣是個 Double，
    /// 於是測試不會報錯，只會安靜地量錯東西（實際發生：放大前後都「3.0」，
    /// 那是三筆筆畫，不是三倍）。
    ///
    /// 認欄位名，不要認位置。
    private func zoomValue(_ element: XCUIElement) -> Double {
        guard let raw = element.value as? String,
              let field = raw.split(separator: " ")
                .first(where: { $0.hasPrefix("zoom:") }),
              let value = Double(field.dropFirst("zoom:".count))
        else { return .nan }
        return value
    }
}
