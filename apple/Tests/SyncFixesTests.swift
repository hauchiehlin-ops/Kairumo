//
//  SyncFixesTests.swift
//  KairumoTests
//
//  實機回報的同步問題：被登出、一直在同步、錄音卡片消失、日誌時間不對、錄音名稱帶筆記本名。
//

import XCTest
@testable import Kairumo

@MainActor
final class SyncFixesTests: XCTestCase {

    // MARK: 被登出

    func testADriveRateLimitIsNotTreatedAsAnAuthorisationFailure() {
        // 實測：兩台裝置開著一段時間之後雙雙被登出。Drive 用 403 回報速率限制，
        // 當成 PermissionDenied 會讓平台登出並**撤銷**授權。
        for reason in ["rateLimitExceeded", "userRateLimitExceeded", "sharingRateLimitExceeded", "quotaExceeded"] {
            let body = "{\"error\":{\"code\":403,\"errors\":[{\"reason\":\"\(reason)\"}]}}"
            let error = DriveHttpClient.classify(status: 403, path: "/files", detail: body)
            guard case .Backend = error else {
                return XCTFail("\(reason) 被當成授權問題：\(error)")
            }
            XCTAssertTrue(DriveHttpClient.isRateLimit(body: Data(body.utf8)))
        }
    }

    func testARealAuthorisationFailureStillAsksForASignIn() {
        let forbidden = "{\"error\":{\"code\":403,\"errors\":[{\"reason\":\"forbidden\"}]}}"
        guard case .PermissionDenied = DriveHttpClient.classify(status: 403, path: "/f", detail: forbidden) else {
            return XCTFail("真正的 403 要請使用者重新登入")
        }
        guard case .PermissionDenied = DriveHttpClient.classify(status: 401, path: "/f", detail: "") else {
            return XCTFail("401 要請使用者重新登入")
        }
        guard case .NotFound = DriveHttpClient.classify(status: 404, path: "/f", detail: "") else {
            return XCTFail("404 是找不到")
        }
        guard case .Backend = DriveHttpClient.classify(status: 503, path: "/f", detail: "") else {
            return XCTFail("5xx 是可重試的後端錯誤")
        }
    }

    // MARK: 日誌時間

    @MainActor
    func testALogLineKeepsTheTimeItHappenedNotTheTimeItWasWritten() {
        let logger = SyncLogger.shared
        logger.clear()
        let happened = Date(timeIntervalSinceNow: -240)
        logger.log("四分鐘前發生的事", at: happened)
        XCTAssertEqual(logger.entries.last?.timestamp, happened,
                       "日誌要記事件發生的時間；主執行緒忙時才輪到寫入，不能拿寫入時間當發生時間")
    }

    // MARK: 錄音名稱

    func testANewRecordingIsNotNamedAfterTheNotebook() {
        let title = NotebookStore.defaultRecordingTitle(at: Date(timeIntervalSince1970: 0))
        XCTAssertFalse(title.contains("mac建立"))
        XCTAssertTrue(title.hasPrefix(LocalizationManager.shared.localized("recording_suffix")),
                      "名稱應該以「錄音」開頭、後面接時間：\(title)")
    }

    // MARK: 匯入不吃掉剛新增的物件

    private func doc(audio: [String]) -> NotebookDocument {
        var d = NotebookDocument(title: "N", pageCount: 1)
        d.audioAttachments = audio.map { NoteAudioAttachment(id: $0, fileName: "\($0).opus", title: $0) }
        return d
    }

    private func snapshot(_ d: NotebookDocument) -> [String: Int] {
        ExportedObjectIds.fingerprints(of: d)
    }

    func testAnObjectAddedAfterTheExportSurvivesTheImport() {
        // 一輪同步是「匯出 → 等網路 → 匯入」，匯入是整份取代。等網路時使用者插了一段錄音，
        // 它不在匯出的套件裡，整份取代之後就消失了（回報：一同步錄音卡片就不見）。
        let exportedDoc = doc(audio: ["old"])
        let imported = doc(audio: ["old"])
        let local = doc(audio: ["old", "just-added"])
        let (merged, preserved) = NotebookSyncCoordinator.preservingLocalChanges(
            imported, local: local, exported: snapshot(exportedDoc))
        XCTAssertEqual(merged.audioAttachments?.map(\.id), ["old", "just-added"])
        XCTAssertTrue(preserved, "有保住新增物件時不能標成「已同步」，它還沒進套件")
    }

    func testAnObjectMovedAfterTheExportDoesNotJumpBack() {
        // 回報：畫布上的物件移不動，一同步就回到原位。移動發生在匯出之後、匯入之前，
        // 匯入的結果是舊位置。
        var exportedDoc = doc(audio: [])
        exportedDoc.textAttachments = [NoteTextAttachment(id: "t", text: "hi", x: 10, y: 10)]
        let imported = exportedDoc // 套件裡還是舊位置
        var local = exportedDoc
        local.textAttachments?[0].x = 300
        local.textAttachments?[0].y = 400
        let (merged, preserved) = NotebookSyncCoordinator.preservingLocalChanges(
            imported, local: local, exported: snapshot(exportedDoc))
        XCTAssertEqual(merged.textAttachments?.first?.x, 300)
        XCTAssertEqual(merged.textAttachments?.first?.y, 400)
        XCTAssertTrue(preserved, "移動還沒進套件，下一輪要匯出")
    }

    func testAnotherDevicesMoveIsAcceptedWhenIDidNotTouchTheObject() {
        // 我沒動過它（指紋與匯出當下相同），別台移動的結果要接受。
        var exportedDoc = doc(audio: [])
        exportedDoc.textAttachments = [NoteTextAttachment(id: "t", text: "hi", x: 10, y: 10)]
        var imported = exportedDoc
        imported.textAttachments?[0].x = 500
        let (merged, preserved) = NotebookSyncCoordinator.preservingLocalChanges(
            imported, local: exportedDoc, exported: snapshot(exportedDoc))
        XCTAssertEqual(merged.textAttachments?.first?.x, 500)
        XCTAssertFalse(preserved)
    }

    func testAnObjectAnotherDeviceDeletedStaysDeleted() {
        // 匯出當下就有、匯入結果沒有 = 別台刪掉的。補回去會讓刪除復活。
        let exportedDoc = doc(audio: ["gone"])
        let imported = doc(audio: [])
        let (merged, preserved) = NotebookSyncCoordinator.preservingLocalChanges(
            imported, local: exportedDoc, exported: snapshot(exportedDoc))
        XCTAssertTrue(merged.audioAttachments?.isEmpty ?? true)
        XCTAssertFalse(preserved)
    }

    func testWithoutAnExportSnapshotNothingIsTouched() {
        let imported = doc(audio: ["a"])
        let (merged, preserved) = NotebookSyncCoordinator.preservingLocalChanges(
            imported, local: doc(audio: ["a", "b"]), exported: nil)
        XCTAssertEqual(merged.audioAttachments?.map(\.id), ["a"], "沒有名單就分不出「新增」與「被刪」，不能補")
        XCTAssertFalse(preserved)
    }
}
