//
//  MacReleaseConfigTests.swift
//  KairumoTests
//
//  Mac App Store 的上傳前提。
//
//  # 為什麼這幾條值得寫成測試
//
//  這些錯誤**在本機完全看不出來**：App 建得起來、跑得起來、測試也全過，
//  直到 `altool` 上傳時才被擋下：
//
//  - 90296：缺 `com.apple.security.app-sandbox`
//  - 90242：`Info.plist` 缺 `LSApplicationCategoryType`
//
//  兩個都是設定檔漏一行。而發現它們的代價是跑完一整輪封裝與上傳。
//
//  這裡直接讀專案設定檔 —— 測試跑在 iOS 模擬器上，拿不到 Mac 的產物，
//  但設定本身是純文字，讀得到就驗得了。
//

import XCTest
@testable import Kairumo

final class MacReleaseConfigTests: XCTestCase {

    /// 從測試 bundle 往上找到專案根目錄。
    ///
    /// 用 `#filePath` 而不是 bundle 路徑：設定檔不會被打包進 App，
    /// 只有原始碼樹裡才有。
    private var appleDirectory: URL {
        URL(fileURLWithPath: #filePath)          // .../apple/Tests/MacReleaseConfigTests.swift
            .deletingLastPathComponent()          // .../apple/Tests
            .deletingLastPathComponent()          // .../apple
    }

    private func read(_ relativePath: String) throws -> String {
        try String(contentsOf: appleDirectory.appendingPathComponent(relativePath), encoding: .utf8)
    }

    // MARK: - 90296：沙盒

    func testTheMacEntitlementsFileExists() throws {
        // 沒有這個檔案，Mac 版連上傳都上傳不了。
        XCTAssertNoThrow(try read("Kairumo-Mac.entitlements"))
    }

    func testTheSandboxIsEnabledForMac() throws {
        // altool 90296：Mac App Store 的硬性要求。
        let entitlements = try read("Kairumo-Mac.entitlements")
        XCTAssertTrue(
            entitlements.contains("com.apple.security.app-sandbox"),
            "缺少沙盒 entitlement —— 上傳會被 90296 擋下"
        )
    }

    func testTheAppCanStillReachTheUsersSyncFolder() throws {
        // 沙盒開了卻沒開這兩條的話，同步資料夾讀不到，而且**不會有錯誤**：
        // 使用者按下同步，什麼都沒搬，畫面上看起來像成功了。
        let entitlements = try read("Kairumo-Mac.entitlements")
        XCTAssertTrue(
            entitlements.contains("com.apple.security.files.user-selected.read-write"),
            "選了資料夾卻讀不到"
        )
        XCTAssertTrue(
            entitlements.contains("com.apple.security.files.bookmarks.app-scope"),
            "重開 App 之後資料夾的權限就沒了，使用者每次都要重選"
        )
    }

    func testRecordingAndCollaborationStillWork() throws {
        // 沙盒會把這些預設關掉。錄音按下去沒聲音、協同連不上，
        // 都是使用者要到實際用的時候才發現。
        let entitlements = try read("Kairumo-Mac.entitlements")
        XCTAssertTrue(entitlements.contains("com.apple.security.device.audio-input"), "錄不到音")
        XCTAssertTrue(entitlements.contains("com.apple.security.network.server"), "別人連不進來")
        XCTAssertTrue(entitlements.contains("com.apple.security.network.client"), "自己加入不了房間")
    }

    /// **每一個權限都要指得出是誰在用它。**
    ///
    /// 2026-09-22 被 App Review 的自動分析退件：
    /// 「包含 `com.apple.security.network.server` 但看不到對應功能」。
    /// 那一次功能是真的有（`LocalRelayServer` 用 `NWListener` 監聽區網連入），
    /// 只是**畫面上完全看不出來** —— 狀態只存在屬性裡，沒有顯示。
    ///
    /// 這一項把「權限 ↔ 實作」綁在一起：哪天有人把中繼拿掉卻忘了拿掉權限，
    /// 它會紅；哪天有人為了過審把權限拿掉，協同的房主功能會先被這裡擋下來。
    func testTheServerEntitlementHasCodeBehindIt() throws {
        let entitlements = try read("Kairumo-Mac.entitlements")
        guard entitlements.contains("com.apple.security.network.server") else {
            return // 沒有宣告就沒有要對帳的東西
        }
        let relay = try read("Sources/LocalRelayServer.swift")
        XCTAssertTrue(
            relay.contains("NWListener"),
            "宣告了 network.server，就必須真的有東西在監聽連入連線")

        // 而且那個狀態要顯示得出來 —— 看不到的功能，審查員也看不到。
        let sheet = try read("Sources/CollaborationSheet.swift")
        XCTAssertTrue(
            sheet.contains("isHostingLocalRelay"),
            "正在擔任中繼這件事要顯示在協同面板上，否則沒有人（包含審查員）看得到它")
    }

    // MARK: - 90242：類別

    func testTheAppDeclaresAStoreCategory() throws {
        // altool 90242：Mac App Store 必填。
        let project = try read("project.yml")
        XCTAssertTrue(
            project.contains("INFOPLIST_KEY_LSApplicationCategoryType"),
            "缺少 App 類別 —— 上傳會被 90242 擋下"
        )
    }

    // MARK: - 只掛在 Mac 上

    func testTheSandboxIsScopedToMacOnly() throws {
        // iOS 一律沙盒化，帶這個鍵反而會讓佈建檔對不上。
        let project = try read("project.yml")
        XCTAssertTrue(
            project.contains("CODE_SIGN_ENTITLEMENTS[sdk=macosx*]"),
            "entitlements 必須用 macosx SDK 條件掛，不能全平台套用"
        )
        XCTAssertFalse(
            project.contains("\n        CODE_SIGN_ENTITLEMENTS:"),
            "entitlements 被無條件套到所有平台了"
        )
    }

    // MARK: - 發行腳本

    func testTheReleaseScriptBuildsTheMacVariant() throws {
        // 只上傳 iOS 的話，Mac 的 TestFlight 會顯示「要求的 App 無法使用或
        // 不存在」—— 因為那裡根本沒有可安裝的組建。
        let script = try String(
            contentsOf: appleDirectory
                .deletingLastPathComponent()
                .appendingPathComponent("scripts/apple-release.sh"),
            encoding: .utf8
        )
        XCTAssertTrue(script.contains("variant=Mac Catalyst"), "發行腳本沒有封裝 Mac 版")
        XCTAssertTrue(script.contains("\"macos\""), "發行腳本沒有以 macos 平台上傳")
    }
}
