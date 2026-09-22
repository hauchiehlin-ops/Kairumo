import XCTest

/// 普查：按下去到底有沒有反應。
///
/// # 這不是閘門，是一次量測
///
/// 提案 ② 的想法是「點一下 → 比對前後狀態 → 沒變化就是死的」。在把它變成
/// 閘門之前要先知道兩件事：**真的抓得到幾個**，以及**跑一輪要多久**。
/// 估錯成本的閘門會變成沒人跑的閘門。
///
/// 比對用無障礙樹的雜湊。真正的死按鈕不會讓樹有任何變化。
///
/// 每點一個就重啟 App —— 這是唯一確定的重置方式。開了 sheet 再想辦法關掉
/// 會變成每個畫面各一套關法，而其中任何一套失手都會讓後面的結果全錯。
/// 代價是慢，所以這支是 `DISABLED_` 前綴，手動跑：
///
///     xcodebuild test … -only-testing:KairumoUITests/DeadControlSurvey
final class DeadControlSurvey: XCTestCase {

    func testSurveyHomeControls() throws {
        let ids = try requiredControlIds(screen: "home")
        var noEffect: [String] = []
        var notPresent: [String] = []
        var effective = 0
        let started = Date()

        for id in ids {
            let app = XCUIApplication()
            app.launchEnvironment["KAIRUMO_UITEST"] = "1"
            app.launch()
            _ = app.descendants(matching: .any).matching(identifier: "home.title")
                .firstMatch.waitForExistence(timeout: 10)

            let element = app.descendants(matching: .any).matching(identifier: id).firstMatch
            guard element.exists, element.isHittable else {
                notPresent.append(id)
                app.terminate()
                continue
            }

            let before = app.debugDescription.hashValue
            element.tap()
            // 讓轉場跑完。太短會把「還沒畫出來」誤判成「沒反應」。
            Thread.sleep(forTimeInterval: 1.2)
            let after = app.debugDescription.hashValue

            if before == after {
                noEffect.append(id)
            } else {
                effective += 1
            }
            app.terminate()
        }

        let elapsed = Date().timeIntervalSince(started)
        print("""

            ───────── 死控制項普查：home ─────────
            規格要求      \(ids.count) 項
            當下點得到    \(effective + noEffect.count) 項
            **按了沒反應  \(noEffect.count) 項**
            不在畫面上    \(notPresent.count) 項
            耗時          \(String(format: "%.0f", elapsed)) 秒（每項約 \
            \(String(format: "%.1f", elapsed / Double(max(ids.count, 1)))) 秒）

            按了沒反應的：
            \(noEffect.isEmpty ? "（無）" : noEffect.joined(separator: "\n"))
            ─────────────────────────────────────

            """)
    }

    private func requiredControlIds(screen: String) throws -> [String] {
        let url = try XCTUnwrap(
            Bundle(for: DeadControlSurvey.self).url(forResource: "screens", withExtension: "json"),
            "測試 bundle 裡沒有 screens.json")
        let data = try Data(contentsOf: url)
        let root = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let entry = try XCTUnwrap(root[screen] as? [String: Any], "規格沒有畫面「\(screen)」")
        return try XCTUnwrap(entry["apple"] as? [String])
    }
}
