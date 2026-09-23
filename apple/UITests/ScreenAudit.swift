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
        var matchedByLabelOnly: [String] = []
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

        let labels = labelsById(screen: screen)
        for id in required where !allowMissing.contains(id) {
            // **順序很重要。** 先用識別字找（必要時捲動），真的找不到才退回標籤。
            //
            // 反過來寫過一次，結果是災難：標籤在整個 App 裡不是唯一的。
            // 「自訂工具列」那張表底下四列（遮蔽膠帶／復原／重做／清除頁面）
            // 在小螢幕上要捲才看得到，而 `app.buttons["Undo"]` 立刻就對上了
            // **編輯器自己那顆復原**（它在表單後面、被蓋住、點不到）——
            // 於是稽核報了四個「點不到」，而那四個是它自己找錯的元素。
            //
            // 識別字才是唯一的。標籤只用在識別字真的不存在的地方（選單項目）。
            let byId = app.descendants(matching: .any).matching(identifier: id).firstMatch
            var element = byId
            var matchedByLabel = false
            if !exists(byId, in: app) {
                guard let label = labels[id], !label.isEmpty,
                      case let byLabel = app.buttons[label].firstMatch,
                      byLabel.exists
                else {
                    missing.append(id)
                    continue
                }
                element = byLabel
                matchedByLabel = true
            }
            // 用標籤對上的，代表識別字沒跟進無障礙樹。功能可能是通的，
            // 但下一個人改文案就會把這條稽核改紅 —— 值得知道，不值得擋。
            if matchedByLabel { matchedByLabelOnly.append(id) }
            // 停用的控制項不該被算成「點不到」—— 那是它自己的狀態。
            guard element.isEnabled else { continue }
            // 沒有面積的東西本來就點不到，那是版面問題不是遮蔽問題。
            guard element.frame.width > 0, element.frame.height > 0 else {
                missing.append("\(id)（面積是 0）")
                continue
            }
            // **只看完整落在畫面上的**。捲動範圍之外的東西 `isHittable`
            // 本來就是 false，那不是 bug，捲下去就點得到 —— 首頁的
            // home.version、home.docs.manual 都是這樣，第一次跑被誤判成
            // 11 個「點不到」。
            //
            // 條件是「完整包含」而不是「有重疊」。被視窗邊緣切掉一半的東西
            // 也點不到，而那同樣不是 bug —— 「更多」選單最下面四項就是這樣
            // （實測：視窗高 874，它們在 y=723～912），排在更後面、完全在
            // 窗外的那幾項反而因為沒有重疊而被正確跳過。同一個成因兩種結論，
            // 分界線畫錯了。
            //
            // 這道稽核要抓的是「就在眼前、整個看得到、卻按不出反應」，
            // 也就是上面蓋了一層沒給 zIndex 的東西。
            guard visible.contains(element.frame) else { continue }
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
        if !matchedByLabelOnly.isEmpty {
            // 不是失敗。是「這些只能靠標籤認出來」的清單 —— 文案一改就會
            // 變成假的缺失，所以要看得見。
            print("【稽核｜\(screen)】只能用標籤對上（識別字沒跟進無障礙樹）："
                  + matchedByLabelOnly.joined(separator: ", "))
        }
        XCTAssertTrue(
            unreachable.isEmpty,
            "畫面「\(screen)」這些控制項畫得出來、也是啟用的，卻**點不到** ——"
                + "多半是上面蓋了一層沒給 zIndex 的東西：\n"
                + unreachable.joined(separator: "\n"),
            file: file, line: line)
    }

    /// 從 `screens.json` 讀這個平台在這個畫面上必須有的控制項。
    /// 只稽核指定的幾個控制項，其餘不管。
    ///
    /// 給「要先做一個動作才看得到」的東西用 —— 選單項目就是這樣：
    /// `check` 是在「畫面已到位、還沒開任何浮層」的時點呼叫的，那時選單
    /// 是關的，十八個項目一個都不在樹裡。不能把開選單塞進 `check`，
    /// 因為開著的選單會把它底下的控制項全部變成點不到。
    /// - Parameters:
    ///   - requireHittable: 是否要求「點得到」。系統算繪的選單要傳 `false`。
    ///
    ///     原因不是為了讓測試變綠。這道稽核抓的是「上面蓋了一層沒給 zIndex
    ///     的東西」，而**那件事在系統選單裡不可能發生** —— 版面是 UIKit 的，
    ///     不是我們排的。實測「更多」選單有十八項，底下幾項落在選單自己的
    ///     捲動範圍外，`isHittable` 因此是 false；那跟遮蔽沒有關係，
    ///     捲一下就點得到。
    ///
    ///     這裡守得住的是「項目在不在、是不是啟用的」，而那已經從
    ///     **完全沒有執行期檢查**變成有了。
    static func checkOnly(
        _ app: XCUIApplication,
        screen: String,
        ids: [String],
        requireHittable: Bool = true,
        /// 找不到就捲一下再找。
        ///
        /// **選單放不下的時候一定要開。** 「更多」選單有二十幾項，在手機
        /// 尺寸上底下幾項根本沒被算繪出來 —— 於是稽核報「少了
        /// editor.insert.ai_summary」，看起來像那個功能不見了，實際上是
        /// 它在捲動範圍外。加一個項目就可能把最後一項擠出去，而那個紅燈
        /// 指向的是一個完全無辜的 id（實際踩過）。
        scrollToFind: Bool = false,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let labels = labelsById(screen: screen)
        var missing: [String] = []
        var unreachable: [String] = []
        let visible = app.windows.firstMatch.frame

        for id in ids {
            var (element, _) = elementFor(id, label: labels[id], in: app)
            if scrollToFind && !element.exists {
                for _ in 0..<6 where !element.exists {
                    app.swipeUp()
                    (element, _) = elementFor(id, label: labels[id], in: app)
                }
            }
            guard element.exists else {
                missing.append("\(id)（標籤：\(labels[id] ?? "—")）")
                continue
            }
            guard element.isEnabled else { continue }
            // 同 `check`：完整落在畫面上才問點不點得到。理由見那邊。
            guard requireHittable, visible.contains(element.frame) else { continue }
            if !element.isHittable {
                // 座標一起印。「點不到」有兩種完全不同的成因 ——
                // 上面蓋了東西（要修產品），或是它其實在畫面外而
                // `intersects` 因為選單裁切而誤判（要修稽核）。
                // 沒有座標就分不出來，而分不出來就只能猜。
                unreachable.append(
                    "\(id) frame=\(element.frame) 視窗=\(visible)"
                    + " label=\(labels[id] ?? "—")")
            }
        }

        XCTAssertTrue(
            missing.isEmpty,
            "畫面「\(screen)」少了這些控制項：\n" + missing.joined(separator: "\n"),
            file: file, line: line)
        XCTAssertTrue(
            unreachable.isEmpty,
            "畫面「\(screen)」這些控制項在、也是啟用的，卻**點不到**：\n"
                + unreachable.joined(separator: "\n"),
            file: file, line: line)
    }

    /// 控制項 id → 英文標籤。只給 `elementFor` 當後備。
    ///
    /// # 為什麼需要後備
    ///
    /// SwiftUI 的 `Menu` 把選單項目交給 UIKit 的 `UIAction` 算繪，而
    /// **`.accessibilityIdentifier` 不會跟過去**。實測（`MenuProbe`）：打開
    /// 「更多」之後，十八個項目全部在無障礙樹裡，`identifier` 全是空的，
    /// `label` 全部正確。
    ///
    /// 在量到這件事之前，編輯器棘輪裡那 40 項的註解寫的是「藏在選單／浮層裡」
    /// —— 那個說法讓人以為是**時序**問題（沒展開所以看不到），於是沒有人再
    /// 往下追。真正的原因是識別字在跨進 UIKit 時掉了，而那是修得動的。
    ///
    /// 標籤來自核心的字串表（經由 `screens.json`），不是測試自己寫死的 ——
    /// 寫死的話文案一改，稽核就會開始報假的缺失。
    private static func labelsById(screen: String) -> [String: String] {
        guard let entry = specEntry(screen: screen),
              let controls = entry["controls"] as? [[String: Any]]
        else { return [:] }
        var out: [String: String] = [:]
        for c in controls {
            if let id = c["id"] as? String,
               let label = c["label_en"] as? String,
               !label.isEmpty {
                out[id] = label
            }
        }
        return out
    }

    /// 先用識別字找；找不到才退而用標籤找。
    ///
    /// 順序不能反 —— 標籤會重複（兩顆按鈕寫著同一個字是常態），
    /// 識別字才是唯一的。標籤只是「總比完全驗不到好」。
    private static func elementFor(
        _ id: String, label: String?, in app: XCUIApplication
    ) -> (element: XCUIElement, matchedByLabel: Bool) {
        let byId = app.descendants(matching: .any).matching(identifier: id).firstMatch
        if byId.exists { return (byId, false) }
        if let label, !label.isEmpty {
            let byLabel = app.buttons[label].firstMatch
            if byLabel.exists { return (byLabel, true) }
        }
        return (byId, false)
    }

    private static func specEntry(screen: String) -> [String: Any]? {
        guard let url = Bundle(for: ScreenAuditAnchor.self)
            .url(forResource: "screens", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return root[screen] as? [String: Any]
    }

    private static func requiredControlIds(screen: String) -> [String] {
        guard let entry = specEntry(screen: screen),
              let ids = entry["apple"] as? [String]
        else {
            XCTFail(
                "讀不到 screens.json 的「\(screen)」—— "
                    + "資源沒被打包進測試 bundle，或核心規格沒有這個畫面")
            return []
        }
        return ids
    }

    /// 在不在 —— 找不到就捲一下再找。
    ///
    /// # 為什麼要捲
    ///
    /// Android 端踩過這個：Compose 的 LazyColumn 只組合看得見的項目，
    /// 沒捲到的控制項根本不在語意樹裡。當時稽核報了三個「缺失」，
    /// 而那三個在程式碼裡是**無條件**渲染的 —— 是稽核錯了，不是程式錯了。
    ///
    /// SwiftUI 的 `List` 與 `LazyVStack` 有同樣的性質。不捲就下結論的話，
    /// 棘輪裡會塞滿假的缺失，而**假的缺失會讓真的缺失被忽略**。
    private static func exists(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        if element.exists { return true }
        for _ in 0..<12 {
            app.swipeUp()
            if element.exists { return true }
        }
        // 捲回頂端，下一個控制項才從同一個起點找。
        for _ in 0..<14 { app.swipeDown() }
        return false
    }

    /// 現場實際存在的識別碼。只在稽核失敗時取用 —— 掃整棵樹很貴。
    ///
    /// 有這個之後失敗訊息才講得清楚「是缺識別碼，還是根本沒到這個畫面」。
    /// 沒有它的話，兩種情況看起來一模一樣：清單全紅。
    static func presentIdentifiers(_ app: XCUIApplication) -> [String] {
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
