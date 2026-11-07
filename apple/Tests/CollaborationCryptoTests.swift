//
//  CollaborationCryptoTests.swift
//  KairumoTests
//
//  協同訊息的解密邊界（工作項 S-75）。
//

import XCTest
@testable import Kairumo

/// # 為什麼要有這一組測試
///
/// 這裡守的是一個**不會報錯的失敗**：加密的訊息落到手上沒有金鑰的那一端時，
/// `decryptPayload` 原本回傳的是信封本身（`{"ciphertext": ...}`）而不是 nil。
/// 下游每一個 `guard let pageIndex = payload["page_index"]` 都會靜靜地
/// return —— 訊息收到了、也「處理」了，畫面上什麼都沒發生，log 裡也沒有錯誤。
///
/// 實機症狀是：兩台都顯示「已連線」、成員清單也對，但對方畫的東西永遠不會
/// 出現。這種缺陷靠人工測試很難抓，所以釘在這裡。
@MainActor
final class CollaborationCryptoTests: XCTestCase {

    private func makeManager() -> CollaborationManager {
        let manager = CollaborationManager.shared
        manager.setRoomKey(base64: nil)
        return manager
    }

    /// 沒有金鑰 + 訊息是加密的 → 必須丟掉，不能把信封當內容傳下去。
    func testEncryptedPayloadWithoutKeyIsDropped() {
        let manager = makeManager()
        let envelope: [String: Any] = ["ciphertext": "bm90LXJlYWwtY2lwaGVy"]

        let result = manager.decryptPayload(envelope, isEncrypted: true)

        XCTAssertNil(
            result,
            "沒有金鑰卻回傳了內容 —— 下游會拿到一個沒有 page_index 的字典並靜靜地丟掉")
    }

    /// 明文的房間照常放行：不是每一間房都開加密。
    func testPlainPayloadPassesThrough() {
        let manager = makeManager()
        let payload: [String: Any] = ["page_index": 2, "drawing_base64": "AAA="]

        let result = manager.decryptPayload(payload, isEncrypted: false)

        XCTAssertEqual(result?["page_index"] as? Int, 2)
    }

    /// 用對的金鑰加密再解密，要拿回原本那份 payload。
    func testRoundTripWithKeyPreservesPayload() {
        let manager = makeManager()
        let key = manager.generateRoomKey()
        XCTAssertFalse(key.isEmpty, "核心沒產出金鑰，後面的斷言都沒有意義")

        let payload: [String: Any] = ["page_index": 3, "drawing_base64": "QUJD"]
        let (envelope, isEncrypted) = manager.encryptPayload(payload)
        XCTAssertTrue(isEncrypted, "有金鑰卻沒有加密")

        let result = manager.decryptPayload(envelope, isEncrypted: isEncrypted)
        XCTAssertEqual(result?["page_index"] as? Int, 3)
        XCTAssertEqual(result?["drawing_base64"] as? String, "QUJD")
    }

    /// 拿另一把金鑰的人要解不開，而且是**明確地**解不開（nil），
    /// 不是拿到一份缺欄位的字典。
    func testWrongKeyIsDropped() {
        let manager = makeManager()
        _ = manager.generateRoomKey()
        let payload: [String: Any] = ["page_index": 1]
        let (envelope, isEncrypted) = manager.encryptPayload(payload)
        XCTAssertTrue(isEncrypted)

        _ = manager.generateRoomKey()   // 換一把
        XCTAssertNil(manager.decryptPayload(envelope, isEncrypted: isEncrypted))
    }

    /// 曾經開啟本機中繼（Wi‑Fi / Tailscale）後，改切到雲端共享（或結束會議），
    /// 再重新點選「Wi‑Fi / Tailscale」時，本機中繼必須重新回報 `.ready` 並恢復 `isHostingLocalRelay = true`，
    /// 否則畫面會永遠因為 `isHostingLocalRelay == false` 而退化成只顯示「遠端中繼」單一 QR Code。
    func testSwitchingToCloudRelayAndBackToLocalRestoresLocalRelayState() async throws {
        let port: UInt16 = 19092
        defer { LocalRelayServer.shared.stop() }

        let firstReady = expectation(description: "第一次啟動本機中繼回報 .ready")
        LocalRelayServer.shared.onStateChange = { state in
            if case .ready(let p, _) = state, p == port {
                firstReady.fulfill()
            }
        }
        _ = LocalRelayServer.shared.start(port: port, roomId: "room-1", hostName: "Test")
        await fulfillment(of: [firstReady], timeout: 3.0)
        XCTAssertTrue(LocalRelayServer.shared.isRunning)

        // 模擬：listener 仍在同一個 port 上執行時，再次呼叫 start(port:) 必須依然觸發 onStateChange(.ready)
        let secondReady = expectation(description: "同埠重入 start 時仍須回報 .ready")
        LocalRelayServer.shared.onStateChange = { state in
            if case .ready(let p, _) = state, p == port {
                secondReady.fulfill()
            }
        }
        _ = LocalRelayServer.shared.start(port: port, roomId: "room-2", hostName: "Test")
        await fulfillment(of: [secondReady], timeout: 3.0)
    }

    /// 遠端協作者／房主在某頁下筆或打字時，所有人畫布應收到跳轉至該頁的通知；
    /// 且當對方仍在該頁編輯中時，本機若嘗試在「不同頁」下筆／打字會被擋下並收到提示，
    /// 直到對方編輯結束後才輪到下一位編輯者。
    func testRemotePageEditTriggersAutoJumpAndBlocksCrossPageEditUntilEnded() {
        let manager = makeManager()
        manager.resetPageEditLeaseState()
        manager.status = .connected(roomId: "room-test")
        defer {
            manager.resetPageEditLeaseState()
            manager.status = .disconnected
        }

        var jumpedPages: [String] = []
        var blockedLeases: [PageEditLease] = []
        let jumpCancellable = manager.pageJumpRequested.sink { req in
            jumpedPages.append(req.pageId)
        }
        let blockCancellable = manager.pageEditBlocked.sink { lease in
            blockedLeases.append(lease)
        }
        defer {
            jumpCancellable.cancel()
            blockCancellable.cancel()
        }

        let now = Date()
        manager.receiveRemotePageEdit(
            userId: "peer-host",
            payload: [
                "page": "page-2",
                "phase": "begin",
                "started_lamport": 5,
                "user_name": "Alice",
                "is_host": true,
            ],
            lamport: 5,
            now: now
        )

        XCTAssertEqual(jumpedPages.last, "page-2", "遠端開始編輯時應通知全員跳轉至 page-2")

        // 本機嘗試在不同頁（page-1）下筆：應被擋下並跳出提示、跳回 page-2
        let blocker = manager.tryBeginLocalPageEdit(pageId: "page-1", now: now.addingTimeInterval(0.2))
        XCTAssertNotNil(blocker, "不同頁同時編輯時，後下筆者必須被擋下")
        XCTAssertEqual(blocker?.userName, "Alice")
        XCTAssertEqual(blocker?.isHost, true)
        XCTAssertEqual(blockedLeases.count, 1)
        let notice = manager.formatPageEditWaitNotice(for: blocker!)
        XCTAssertTrue(notice.contains("Alice"), "提示訊息應包含正在編輯的成員名稱：\(notice)")

        // 本機在同一頁（page-2）協同編輯：不應被擋下
        let samePageBlocker = manager.tryBeginLocalPageEdit(pageId: "page-2", now: now.addingTimeInterval(0.3))
        XCTAssertNil(samePageBlocker, "同一頁共編不應被跨頁鎖阻擋")

        // 遠端結束編輯後，本機即可在 page-1 正常開始編輯
        manager.receiveRemotePageEdit(
            userId: "peer-host",
            payload: ["page": "page-2", "phase": "end", "started_lamport": 5],
            lamport: 5,
            now: now.addingTimeInterval(1.0)
        )
        let afterEndBlocker = manager.tryBeginLocalPageEdit(pageId: "page-1", now: now.addingTimeInterval(1.1))
        XCTAssertNil(afterEndBlocker, "前一位編輯結束後，下一位編輯者應可正常在不同頁下筆")
        XCTAssertEqual(manager.activePageEditLease?.pageId, "page-1")
    }

    /// 兩人幾乎同時在不同頁下筆（網路尚未送達對方）時，以第一個下筆（較小 Lamport 時鐘）為主，
    /// 較晚下筆者收到對方訊息後應立即被搶佔（取消進行中筆畫並跳頁提示）。
    func testCrossPageSimultaneousEditFirstStrokeWinsAndPreemptsLaterEditor() {
        let manager = makeManager()
        manager.resetPageEditLeaseState()
        manager.status = .connected(roomId: "room-race")
        defer {
            manager.resetPageEditLeaseState()
            manager.status = .disconnected
        }

        var preemptedLeases: [PageEditLease] = []
        let preemptCancellable = manager.pageEditPreempted.sink { lease in
            preemptedLeases.append(lease)
        }
        defer { preemptCancellable.cancel() }

        let now = Date()
        // 先推進本機時鐘，使本機下筆的 startedLamport 較大（例如 > 10）
        for _ in 0..<10 { _ = manager.nextLamport() }
        XCTAssertNil(manager.tryBeginLocalPageEdit(pageId: "page-3", now: now))
        XCTAssertEqual(manager.activePageEditLease?.pageId, "page-3")

        // 此時收到遠端其實更早下筆（started_lamport = 2）在 page-1 的訊息 -> 遠端勝出並搶佔本機
        manager.receiveRemotePageEdit(
            userId: "peer-early",
            payload: [
                "page": "page-1",
                "phase": "begin",
                "started_lamport": 2,
                "user_name": "Bob",
                "is_host": false,
            ],
            lamport: 2,
            now: now.addingTimeInterval(0.05)
        )

        XCTAssertEqual(preemptedLeases.count, 1, "較晚下筆的本機應收到搶佔通知")
        XCTAssertEqual(preemptedLeases.first?.userName, "Bob")
        XCTAssertEqual(manager.activePageEditLease?.pageId, "page-1")
        XCTAssertEqual(manager.activePageEditLease?.userId, "peer-early")
    }

    override func tearDown() {
        CollaborationManager.shared.setRoomKey(base64: nil)
        super.tearDown()
    }
}
