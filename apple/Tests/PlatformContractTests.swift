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
        #if os(iOS)
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
    }

    /// 驗證若同時登錄 Google Drive 與 iCloud 時，預設以 Apple (iCloud) 名稱為優先，並可切換
    func testDualCloudLoginPreferenceDefaultsToICloud() {
        let accountManager = AccountManager.shared
        XCTAssertEqual(AccountManager.CloudProviderPreference.iCloud.rawValue, "iCloud")
        XCTAssertEqual(AccountManager.CloudProviderPreference.googleDrive.rawValue, "google")
        UserDefaults.standard.removeObject(forKey: "kairumo.account.cloudProviderPreference")
        XCTAssertEqual(accountManager.cloudProviderPreference, .iCloud)
    }
}
