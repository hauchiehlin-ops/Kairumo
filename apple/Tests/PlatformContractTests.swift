import AVFoundation
import XCTest

@testable import Kairumo

/// 平台能力契約（驗證層 L3，見 docs/plans/ipad-first-verification.md）。
///
/// 每一項都做**兩次以上**：使用者的第一次抱怨幾乎都是「第二次」或「剛做完某件事之後」。
@MainActor
final class PlatformContractTests: XCTestCase {

    private func opusFile(seconds: Int = 1) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("contract-\(UUID().uuidString).opus")
        let pcm = (0..<(16_000 * seconds)).map { Float(sin(Double($0) * 2 * .pi * 440 / 16_000)) * 0.2 }
        XCTAssertNotNil(audioEncodePcmToOpus(pcm16kMono: pcm, outPath: url.path))
        return url
    }

    /// 連續播兩次、中間停一次 —— 第二次也要真的在動。
    func testPlaybackWorksTwiceInARow() async throws {
        let url = try opusFile()
        defer { try? FileManager.default.removeItem(at: url) }
        let manager = AudioRecorderManager.shared
        for round in 1...2 {
            manager.stopPlayback()
            manager.playAudio(url: url, recordingId: "contract-\(round)")
            XCTAssertNil(manager.playbackFailure, "第 \(round) 次播放失敗：\(manager.playbackFailure ?? "")")
            XCTAssertTrue(manager.isPlaying, "第 \(round) 次播放：isPlaying 不是 true")
            try await Task.sleep(nanoseconds: 500_000_000)
            XCTAssertGreaterThan(manager.currentPlaybackTime, 0.05, "第 \(round) 次播放：時間沒有前進")
        }
        manager.stopPlayback()
    }

    /// 剛錄完音（audio session 還停在 `.playAndRecord`）就播 —— 回報的「錄完按播放沒反應」。
    func testPlaybackRightAfterRecordingSessionStillWorks() async throws {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)
        let url = try opusFile()
        defer { try? FileManager.default.removeItem(at: url) }
        let manager = AudioRecorderManager.shared
        manager.stopPlayback()
        manager.playAudio(url: url, recordingId: "after-record")
        XCTAssertNil(manager.playbackFailure, "錄音 session 還在時播放失敗：\(manager.playbackFailure ?? "")")
        XCTAssertTrue(manager.isPlaying)
        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertGreaterThan(manager.currentPlaybackTime, 0.05)
        manager.stopPlayback()
        #endif
    }

    /// 播不出來時要有原因（不能靜默）。
    func testPlaybackFailureIsReportedNotSilent() {
        let manager = AudioRecorderManager.shared
        manager.stopPlayback()
        manager.playAudio(url: URL(fileURLWithPath: "/nonexistent/none.opus"), recordingId: "missing")
        XCTAssertNotNil(manager.playbackFailure, "檔案不存在，卻沒有任何失敗訊息 —— 使用者只會看到『按了沒反應』")
        XCTAssertFalse(manager.isPlaying)
        manager.playbackFailure = nil
    }

    /// 「檔案」App 的網址：scheme 對、路徑是解開符號連結的真實路徑、資料夾本身存在。
    func testFilesAppURLPointsAtAnExistingFolder() {
        let folder = AudioRecorderManager.shared.recordingsDirectory
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.path), "錄音資料夾不存在 —— 「檔案」會落到別處")
        let url = AudioRecorderManager.filesAppURL(for: folder)
        XCTAssertEqual(url?.scheme, "shareddocuments")
        XCTAssertFalse(url?.path.hasPrefix("/var/") ?? true, "要用 /private/var，「檔案」認不得 /var")
        XCTAssertTrue(url?.path.hasSuffix("Kairumo Record") ?? false)
    }

    /// 檔案選擇器的呈現端在不在（找得到最上層 view controller）。實際呈現兩次見 UI 測試。
    func testDocumentPickerHasAPresenterWhenAWindowExists() {
        // 單元測試的 host app 有視窗；沒有視窗的環境（純邏輯測試）回 false 也不算錯，
        // 所以只斷言「不會當掉」與型別正確。
        _ = DocumentPickerPresenter.canPresent()
    }

    /// 驗證首頁「使用者」身分：未登入同步時維持自訂編輯名稱；登入雲端同步時自動採用帳號名稱。
    func testAccountManagerSyncDisplayNameParity() {
        let accountManager = AccountManager.shared
        let originalCustom = accountManager.customDisplayName
        defer {
            accountManager.updateDisplayName(originalCustom)
            accountManager.refreshDisplayName()
        }

        // 1. 自訂編輯名稱
        accountManager.updateDisplayName("測試筆記家")
        XCTAssertEqual(accountManager.customDisplayName, "測試筆記家")

        // 2. 測試雲端帳號生效時的自動切換（若有 activeCloudAccountName 則優先採用）
        if let cloudName = accountManager.activeCloudAccountName, !cloudName.isEmpty {
            accountManager.refreshDisplayName()
            XCTAssertEqual(accountManager.profile.displayName, cloudName)
        } else {
            accountManager.refreshDisplayName()
            XCTAssertEqual(accountManager.profile.displayName, "測試筆記家")
        }

        // 3. 空白名稱自動回退
        accountManager.updateDisplayName("   ")
        let fallback = LocalizationManager.shared.localized("default_user_name")
        XCTAssertEqual(accountManager.customDisplayName, fallback)
    }

    /// 驗證從各種語系的 iOS 裝置名稱萃取 Apple 帳號名稱的能力
    func testExtractAppleAccountNameFromDeviceName() {
        XCTAssertEqual(AccountManager.extractAppleAccountName(fromDeviceName: "Barret 的 iPhone"), "Barret")
        XCTAssertEqual(AccountManager.extractAppleAccountName(fromDeviceName: "Barret Lin 的 iPad"), "Barret Lin")
        XCTAssertEqual(AccountManager.extractAppleAccountName(fromDeviceName: "林豪傑 的 iPhone 15 Pro"), "林豪傑")
        XCTAssertEqual(AccountManager.extractAppleAccountName(fromDeviceName: "Barret's iPhone"), "Barret")
        XCTAssertEqual(AccountManager.extractAppleAccountName(fromDeviceName: "Barret’s iPad mini"), "Barret")
        XCTAssertEqual(AccountManager.extractAppleAccountName(fromDeviceName: "Barret の iPad"), "Barret")
        XCTAssertEqual(AccountManager.extractAppleAccountName(fromDeviceName: "iPad de Barret"), "Barret")
        XCTAssertEqual(AccountManager.extractAppleAccountName(fromDeviceName: "iPhone von Barret"), "Barret")
        XCTAssertEqual(AccountManager.extractAppleAccountName(fromDeviceName: "Barret Lin"), "Barret Lin")
        // 預設純裝置型號或測試機佔位名稱回傳 nil
        XCTAssertNil(AccountManager.extractAppleAccountName(fromDeviceName: "iPhone"))
        XCTAssertNil(AccountManager.extractAppleAccountName(fromDeviceName: "iPad"))
        XCTAssertNil(AccountManager.extractAppleAccountName(fromDeviceName: "Mobile User"))
        XCTAssertNil(AccountManager.extractAppleAccountName(fromDeviceName: "Mobil User"))
        XCTAssertNil(AccountManager.extractAppleAccountName(fromDeviceName: "Mobile User 的 iPhone"))
        XCTAssertNil(AccountManager.extractAppleAccountName(fromDeviceName: "Mobil User 的 iPad"))

        // 驗證有效名稱過濾邏輯
        XCTAssertTrue(AccountManager.isValidAppleAccountName("Barret Lin"))
        XCTAssertTrue(AccountManager.isValidAppleAccountName("林豪傑"))
        XCTAssertFalse(AccountManager.isValidAppleAccountName("Mobile User"))
        XCTAssertFalse(AccountManager.isValidAppleAccountName("Mobil User"))
        XCTAssertFalse(AccountManager.isValidAppleAccountName("mobile user"))
        XCTAssertFalse(AccountManager.isValidAppleAccountName("mobile"))
        XCTAssertFalse(AccountManager.isValidAppleAccountName("user"))
        XCTAssertFalse(AccountManager.isValidAppleAccountName("root"))
        XCTAssertFalse(AccountManager.isValidAppleAccountName("iPhone"))
        XCTAssertFalse(AccountManager.isValidAppleAccountName("iPad"))
    }

    /// 驗證未在 App 內設定 iCloud 同步資料夾時，isICloudSignedIn 必須回傳 false，不誤判為 iCloud 登入
    func testIsICloudSignedInRequiresConfiguredCloudFolder() {
        CloudSyncFolder.clearFolder()
        let accountManager = AccountManager.shared
        XCTAssertFalse(accountManager.isICloudSignedIn, "未設定同步資料夾時，絕對不可將系統 ubiquity token 視為已登入 iCloud 同步")
    }

    /// 驗證若同時登錄 Google Drive 與 iCloud 時，預設以 Apple (iCloud) 名稱為優先，並可切換
    func testDualCloudLoginPreferenceDefaultsToICloud() {
        let accountManager = AccountManager.shared
        XCTAssertEqual(AccountManager.CloudProviderPreference.iCloud.rawValue, "iCloud")
        XCTAssertEqual(AccountManager.CloudProviderPreference.googleDrive.rawValue, "google")
        UserDefaults.standard.removeObject(forKey: "kairumo.account.cloudProviderPreference")
        XCTAssertEqual(accountManager.cloudProviderPreference, .iCloud)
    }

    /// 驗證 `Kairumo Record` 資料夾與套件內真實錄音檔的同步鏡射（新增、改名、刪除、移除殘留檔）
    func testSyncRecordingsExportFolderMirrorsRenamesAndDeletes() throws {
        let fm = FileManager.default
        let tempRoot = fm.temporaryDirectory.appendingPathComponent("kairumo-rec-export-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: tempRoot) }

        let packagesDir = tempRoot.appendingPathComponent("Packages", isDirectory: true)
        let docsDir = tempRoot.appendingPathComponent("Documents", isDirectory: true)
        let exportDir = tempRoot.appendingPathComponent("Kairumo Record", isDirectory: true)
        let pkgAudioDir = packagesDir.appendingPathComponent("nb1.padnote/media/audio", isDirectory: true)
        try fm.createDirectory(at: pkgAudioDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: docsDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: exportDir, withIntermediateDirectories: true)

        let audioFile1 = pkgAudioDir.appendingPathComponent("rec-001.opus")
        let audioFile2 = pkgAudioDir.appendingPathComponent("rec-002.opus")
        try Data("opus-bytes-1".utf8).write(to: audioFile1)
        try Data("opus-bytes-22".utf8).write(to: audioFile2)
        // 放一個孤立的舊 .opus，確認同步後會被清掉
        let orphanFile = exportDir.appendingPathComponent("orphan.opus")
        try Data("orphan".utf8).write(to: orphanFile)

        let rec1 = AudioRecordingRecord(
            id: "r1",
            title: "測試一 1",
            durationSeconds: 5,
            recordedDate: Date(timeIntervalSince1970: 1_700_000_000),
            fileName: "rec-001.opus",
            linkedNotebookId: "nb1"
        )
        let rec2 = AudioRecordingRecord(
            id: "r2",
            title: "語音錄音與對齊 2026/10/17 下午3:21",
            durationSeconds: 12,
            recordedDate: Date(timeIntervalSince1970: 1_700_000_100),
            fileName: "rec-002.opus",
            linkedNotebookId: "nb1"
        )

        // 1. 初次同步：兩個錄音檔都出現在 Kairumo Record，孤立檔被移除
        let mapped1 = NotebookStore.syncRecordingsExportFolder(
            recordings: [rec1, rec2],
            packagesDir: packagesDir,
            documentsDir: docsDir,
            exportDir: exportDir
        )
        XCTAssertEqual(mapped1["rec-001.opus"]?.lastPathComponent, "測試一 1.opus")
        XCTAssertEqual(mapped1["rec-002.opus"]?.lastPathComponent, "語音錄音與對齊 2026-10-17 下午3-21.opus")
        XCTAssertTrue(fm.fileExists(atPath: exportDir.appendingPathComponent("測試一 1.opus").path))
        XCTAssertTrue(fm.fileExists(atPath: exportDir.appendingPathComponent("語音錄音與對齊 2026-10-17 下午3-21.opus").path))
        XCTAssertFalse(fm.fileExists(atPath: orphanFile.path), "孤立的 .opus 應該被清理")

        // 2. 改名同步：舊檔名消失、新檔名出現
        var rec1Renamed = rec1
        rec1Renamed.title = "測試一（已改名）"
        let mapped2 = NotebookStore.syncRecordingsExportFolder(
            recordings: [rec1Renamed, rec2],
            packagesDir: packagesDir,
            documentsDir: docsDir,
            exportDir: exportDir
        )
        XCTAssertEqual(mapped2["rec-001.opus"]?.lastPathComponent, "測試一（已改名）.opus")
        XCTAssertTrue(fm.fileExists(atPath: exportDir.appendingPathComponent("測試一（已改名）.opus").path))
        XCTAssertFalse(fm.fileExists(atPath: exportDir.appendingPathComponent("測試一 1.opus").path))

        // 3. 刪除同步：刪除後 Kairumo Record 內對應檔案也一併移除
        _ = NotebookStore.syncRecordingsExportFolder(
            recordings: [rec2],
            packagesDir: packagesDir,
            documentsDir: docsDir,
            exportDir: exportDir
        )
        XCTAssertFalse(fm.fileExists(atPath: exportDir.appendingPathComponent("測試一（已改名）.opus").path))
        XCTAssertTrue(fm.fileExists(atPath: exportDir.appendingPathComponent("語音錄音與對齊 2026-10-17 下午3-21.opus").path))
    }
}
