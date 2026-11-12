//
//  EntitlementManagerTests.swift
//  KairumoTests
//
//  驗證 Kairumo 基礎版（Free）與專業版（Pro）功能切分、StoreKit 2 狀態管理，
//  以及方法五（Serverless Ed25519 數位簽章 VIP 禮遇通行證）驗章與深層連結解鎖。
//

import XCTest
@testable import Kairumo

@MainActor
final class EntitlementManagerTests: XCTestCase {

    // 由 `scripts/issue-vip-gift.py` 簽發的標準測試向量
    private static let validVIPToken =
        "eyJ0aWVyIjoicHJvX2xpZmV0aW1lIiwiaWQiOiJ0ZXN0MDAwMSIsInRvIjoiUHJvZi4gTGluIiwiaWF0IjoxNzYwMDAwMDAwLCJub3RlIjoiVW5pdCBUZXN0In0.q2sR9TCWif9YSN2crf5AAmPMI253JjKcJdqosiAi7rbG7jFijqw81KnGSqepNom5m8n5g1UCQrDvHWnttNU1AQ"

    private static let expiredVIPToken =
        "eyJ0aWVyIjoicHJvX2xpZmV0aW1lIiwiaWQiOiJleHAwMDAwMSIsInRvIjoiRXhwaXJlZCBHdWVzdCIsImlhdCI6MTcwMDAwMDAwMCwiZXhwIjoxNzAwMDg2NDAwfQ.VAXxzHnJwAatSzRxBaAW1ETgm4phO4OGNT-A_evEdCdTvyLVeZdBRCG6CRiXWDMKAAGQWcb-1nDjFV5FdZirBw"

    func testFreeVsProToolClassification() {
        // 基礎版免費日常筆刷與基礎工具
        let freeTools: [EditorToolType] = [
            .pen, .ballpoint, .pencil, .highlighter, .eraser, .lasso, .maskingTape
        ]
        for tool in freeTools {
            XCTAssertFalse(tool.isProRequired, "\(tool) 應為免費基礎版工具")
        }

        // Pro 獨家賣點：工程圖學筆、掃描翻譯筆、9 款進階藝術筆刷
        let proTools: [EditorToolType] = [
            .drafting, .translationPen,
            .fineliner, .brush, .calligraphy, .charcoal, .crayon,
            .airbrush, .oilpaint, .watercolor, .marker
        ]
        for tool in proTools {
            XCTAssertTrue(tool.isProRequired, "\(tool) 應為 Pro 專屬工具")
        }

        XCTAssertEqual(EditorToolType.drafting.proFeatureGate, .draftingAndSolid)
        XCTAssertEqual(EditorToolType.translationPen.proFeatureGate, .translationPen)
        XCTAssertEqual(EditorToolType.calligraphy.proFeatureGate, .proInk)
    }

    func testEd25519VIPTokenVerificationAcceptsValidSignature() {
        let payload = EntitlementManager.verifyVIPToken(
            Self.validVIPToken,
            nowTimestamp: 1_760_000_100
        )
        XCTAssertNotNil(payload, "合法簽發的 Ed25519 VIP 通行證應通過驗章")
        XCTAssertEqual(payload?.tier, "pro_lifetime")
        XCTAssertEqual(payload?.id, "test0001")
        XCTAssertEqual(payload?.to, "Prof. Lin")
        XCTAssertEqual(payload?.note, "Unit Test")
    }

    func testEd25519VIPTokenVerificationRejectsTamperedToken() {
        let tampered = String(Self.validVIPToken.dropLast(4)) + "AAAA"
        let payload = EntitlementManager.verifyVIPToken(
            tampered,
            nowTimestamp: 1_760_000_100
        )
        XCTAssertNil(payload, "遭到竄改的簽章必須被拒絕")
    }

    func testEd25519VIPTokenVerificationRejectsExpiredToken() {
        // 未過期時應通過
        let beforeExpiry = EntitlementManager.verifyVIPToken(
            Self.expiredVIPToken,
            nowTimestamp: 1_700_050_000
        )
        XCTAssertNotNil(beforeExpiry)

        // 超過 exp 時間戳後應拒絕
        let afterExpiry = EntitlementManager.verifyVIPToken(
            Self.expiredVIPToken,
            nowTimestamp: 1_700_100_000
        )
        XCTAssertNil(afterExpiry, "已過期的 VIP 通行證必須被拒絕")
    }

    func testHandleVIPDeepLinkUnlocksPro() throws {
        let manager = EntitlementManager.shared
        manager.resetVIPForTesting()
        defer { manager.resetVIPForTesting() }

        XCTAssertFalse(manager.isVIPUnlocked)

        let url = try XCTUnwrap(URL(string: "kairumo://vip?gift=\(Self.validVIPToken)"))
        let handled = manager.handleVIPUrl(url)
        XCTAssertTrue(handled)
        XCTAssertTrue(manager.isVIPUnlocked)
        XCTAssertEqual(manager.vipRecipientName, "Prof. Lin")
    }

    func testTwoStepNudgeOnlyOpensPaywallOnSecondConsecutiveTap() {
        let manager = EntitlementManager.shared
        manager.resetVIPForTesting()
        manager.dismissNudge()
        manager.activePaywallFeature = nil
        defer {
            manager.dismissNudge()
            manager.activePaywallFeature = nil
        }

        // 第一次點擊未解鎖功能：僅顯示頂部輕提示膠囊，不直接彈出全螢幕購買視窗
        manager.nudgeOrPresentPaywall(focus: .draftingAndSolid, itemName: "工程製圖筆")
        XCTAssertNotNil(manager.activeNudge, "第一次點擊應顯示二段式輕提示")
        XCTAssertEqual(manager.activeNudge?.feature, .draftingAndSolid)
        XCTAssertEqual(manager.activeNudge?.itemName, "工程製圖筆")
        XCTAssertNil(manager.activePaywallFeature, "第一次點擊不應直接彈出大視窗")

        // 連續第二次點擊同一項功能：收起輕提示並開啟完整購買視窗
        manager.nudgeOrPresentPaywall(focus: .draftingAndSolid, itemName: "工程製圖筆")
        XCTAssertNil(manager.activeNudge, "第二次點擊後應收起輕提示")
        XCTAssertEqual(manager.activePaywallFeature, .draftingAndSolid, "第二次點擊應開啟購買視窗")
    }

    func testProBrushesCollapseToggle() {
        let manager = EntitlementManager.shared
        let initial = manager.showLockedProBrushes
        defer {
            if manager.showLockedProBrushes != initial {
                manager.toggleLockedProBrushes()
            }
        }

        if manager.showLockedProBrushes {
            manager.toggleLockedProBrushes()
        }
        XCTAssertFalse(manager.showLockedProBrushes)
        XCTAssertTrue(manager.shouldDisplayToolInToolbar(.pen), "免費筆刷永遠顯示")

        manager.toggleLockedProBrushes()
        XCTAssertTrue(manager.showLockedProBrushes)
        XCTAssertTrue(manager.shouldDisplayToolInToolbar(.drafting), "展開時 Pro 筆刷應顯示於工具列")
    }
}
