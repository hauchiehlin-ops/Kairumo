import XCTest

/// 畫面稽核：**畫得出來就必須點得到**。
///
/// # 這道稽核擋的是哪一類 bug
///
/// 控制項存在、看得到、也是啟用狀態，但**點不到** —— 因為有一層透明的東西
/// 蓋在上面。SwiftUI 裡最常見的成因是 `zIndex`：沒給 `zIndex` 的視圖預設是
/// 0，於是排在標了 `zIndex(1)` 的畫布**底下**。
///
/// 這不是假想。同一個成因在這個專案裡發生過兩次：
///
///   * 討論串面板的收合與關閉鍵 —— 按下去完全沒反應
///   * 圖釘放置層 —— 整個功能等於不存在
///
/// 兩次都是**盯著截圖**才發現的。編譯器不會警告，既有的畫面對照閘門
/// （`check-screen-parity.py`）也看不見 —— 它掃的是原始碼裡有沒有寫出
/// 那個識別碼，而這兩個 bug 的識別碼都寫得好好的。
///
/// # 為什麼清單來自核心，而不是寫在測試裡
///
/// `docs/conformance/screens.json` 由核心的 `ffi_screens` 產生
/// （`UPDATE_CONFORMANCE=1 cargo test -p padnote-core --test conformance_vectors`），
/// 一份檔案兩端共用 —— Android 讀同一個檔的 `android` 那半邊。清單寫在
/// 各自的測試裡的話，兩端會各自漂移，而那正是這個專案一再發生的事。
///
/// 走 JSON 而不是直接呼叫 FFI，是因為 UI 測試 bundle 跑在 App 之外的
/// 行程，連不到 App 連結的核心框架。這也是這個 repo 既有的做法
/// （`docs/conformance/` 底下那七份向量檔）。
///
/// # 為什麼是明確呼叫，不是自動掃全畫面
///
/// 自動掃會把「被 sheet 正當蓋住的背景按鈕」也算成點不到 —— 那是對的行為，
/// 卻會讓稽核在不同時序下結果不同，而**間歇失敗的閘門會在第三次紅的時候
/// 被關掉**。改成由測試在「畫面已到位、還沒開任何浮層」的明確時點呼叫。
enum ScreenAudit {

    /// 稽核一個畫面：規格說**必須有**的控制項，要存在、而且點得到。
    ///
    /// - Parameters:
    ///   - allowMissing: 還沒接上的控制項（棘輪）。只准縮小 —— 每接好一個
    ///     就從這裡拿掉。放著不管的話這道稽核會退化成裝飾。
    static func check(
        _ app: XCUIApplication,
        screen: String,
        allowMissing: Set<String> = [],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let required = requiredControlIds(screen: screen)
        XCTAssertFalse(
            required.isEmpty,
            "核心對畫面「\(screen)」沒有任何必要控制項的規格 —— 畫面 id 打錯了？",
            file: file, line: line)

        var missing: [String] = []
        var unreachable: [String] = []
        let visible = app.windows.firstMatch.frame

        // 先等第一個控制項出現，讓畫面安定下來；之後就用 `.exists` 不再等。
        //
        // 每個控制項各等兩秒的話，27 個缺漏就是 54 秒的純等待 —— 首頁那一輪
        // 實測跑了 92 秒。慢到讓人不想跑的測試等於沒有測試。
        if let anchor = required.first {
            _ = app.descendants(matching: .any)
                .matching(identifier: anchor)
                .firstMatch
                .waitForExistence(timeout: 10)
        }

        for id in required where !allowMissing.contains(id) {
            let element = app.descendants(matching: .any)
                .matching(identifier: id)
                .firstMatch
            guard element.exists else {
                missing.append(id)
                continue
            }
            // 停用的控制項不該被算成「點不到」—— 那是它自己的狀態。
            guard element.isEnabled else { continue }
            // 沒有面積的東西本來就點不到，那是版面問題不是遮蔽問題。
            guard element.frame.width > 0, element.frame.height > 0 else {
                missing.append("\(id)（面積是 0）")
                continue
            }
            // **只看畫面上的**。捲動範圍之外的東西 `isHittable` 本來就是
            // false，那不是 bug，捲下去就點得到 —— 首頁的 home.version、
            // home.docs.manual 都是這樣，第一次跑被誤判成 11 個「點不到」。
            //
            // 這道稽核要抓的是「就在眼前、看得到、卻按不出反應」，
            // 也就是上面蓋了一層沒給 zIndex 的東西。
            guard element.frame.intersects(visible) else { continue }
            if !element.isHittable {
                unreachable.append(id)
            }
        }

        XCTAssertTrue(
            missing.isEmpty,
            "畫面「\(screen)」少了規格要求的控制項：\n"
                + missing.joined(separator: "\n")
                + "\n\n現場實際有的識別碼（最多 20 個）：\n"
                + presentIdentifiers(app).prefix(20).joined(separator: "\n")
                + "\n\n一個都對不上的話，多半不是缺識別碼，是**根本沒到這個畫面**"
                + "（例如卡在首次啟動流程）。",
            file: file, line: line)
        XCTAssertTrue(
            unreachable.isEmpty,
            "畫面「\(screen)」這些控制項畫得出來、也是啟用的，卻**點不到** ——"
                + "多半是上面蓋了一層沒給 zIndex 的東西：\n"
                + unreachable.joined(separator: "\n"),
            file: file, line: line)
    }

    /// 從 `screens.json` 讀這個平台在這個畫面上必須有的控制項。
    private static func requiredControlIds(screen: String) -> [String] {
        guard let url = Bundle(for: ScreenAuditAnchor.self)
            .url(forResource: "screens", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let entry = root[screen] as? [String: Any],
            let ids = entry["apple"] as? [String]
        else {
            XCTFail(
                "讀不到 screens.json 的「\(screen)」—— "
                    + "資源沒被打包進測試 bundle，或核心規格沒有這個畫面")
            return []
        }
        return ids
    }

    /// 現場實際存在的識別碼。只在稽核失敗時取用 —— 掃整棵樹很貴。
    ///
    /// 有這個之後失敗訊息才講得清楚「是缺識別碼，還是根本沒到這個畫面」。
    /// 沒有它的話，兩種情況看起來一模一樣：清單全紅。
    private static func presentIdentifiers(_ app: XCUIApplication) -> [String] {
        var seen: [String] = []
        for query in [app.buttons, app.staticTexts, app.otherElements, app.textFields] {
            for element in query.allElementsBoundByIndex where !element.identifier.isEmpty {
                seen.append(element.identifier)
                if seen.count >= 20 { return seen }
            }
        }
        return seen
    }
}

/// 只為了拿到測試 bundle。`Bundle(for:)` 需要一個這個 bundle 裡的類別，
/// 而 `ScreenAudit` 是 enum。
private final class ScreenAuditAnchor {}
