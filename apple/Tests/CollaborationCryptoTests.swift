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

    override func tearDown() {
        CollaborationManager.shared.setRoomKey(base64: nil)
        super.tearDown()
    }
}
