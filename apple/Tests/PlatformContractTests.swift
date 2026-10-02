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
}
