import XCTest

@testable import Kairumo

/// 錄音卡片的播放鈕按下去之後，播放管線真的有動。
@MainActor
final class AudioPlaybackTests: XCTestCase {

    private func sampleOpus() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("playback-\(UUID().uuidString).opus")
        // 1 秒 440 Hz，走核心的編碼器 —— 與 App 錄出來的是同一種檔案。
        let pcm = (0..<16_000).map { Float(sin(Double($0) * 2 * .pi * 440 / 16_000)) * 0.5 }
        XCTAssertNotNil(audioEncodePcmToOpus(pcm16kMono: pcm, outPath: url.path))
        return url
    }

    func testPlayAudioStartsTheOpusPlayerAndAdvances() async throws {
        let url = try sampleOpus()
        defer { try? FileManager.default.removeItem(at: url) }
        let manager = AudioRecorderManager.shared
        manager.stopPlayback()

        manager.playAudio(url: url, recordingId: "t1")
        XCTAssertTrue(manager.isPlaying, "按下播放之後 isPlaying 應為 true")
        XCTAssertEqual(manager.playingRecordingId, "t1")

        // 等它前進，而不是睡固定 0.6 秒再看：CI 的模擬器上音訊管線啟動要好幾秒
        // （同一條測試在 runner 上整條跑了 7.5 秒），固定時間一到就檢查會誤紅。
        // 管線真的沒在播的話，五秒之後照樣是 0。
        let deadline = Date().addingTimeInterval(5)
        while manager.currentPlaybackTime <= 0.05, Date() < deadline {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTAssertGreaterThan(manager.currentPlaybackTime, 0.05, "播放時間沒有前進 —— 管線沒真的在播")
        manager.stopPlayback()
    }

    /// 錄完當下顯示的秒數，必須與別台掃描檔案時算出來的一樣（同一個核心函式）。
    func testDisplaySecondsComeFromTheFileNotTheTimer() throws {
        let url = try sampleOpus()          // 1 秒的檔案
        defer { try? FileManager.default.removeItem(at: url) }
        // 計時器說 0.4（截斷成 0、四捨五入成 0），檔案是 1 秒 —— 以檔案為準。
        XCTAssertEqual(AudioRecorderManager.displaySeconds(of: url, fallback: 0.4), 1)
        // 檔案讀不出來才退回計時器，而且是四捨五入（5.9 → 6），不是截斷。
        let missing = URL(fileURLWithPath: "/nonexistent/x.opus")
        XCTAssertEqual(AudioRecorderManager.displaySeconds(of: missing, fallback: 5.9), 6)
    }
}
