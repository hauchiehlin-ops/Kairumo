//
//  OpusAudioPlayer.swift
//  Kairumo
//
//  播放 Ogg-Opus 錄音（R3）。
//
//  # 為什麼不能用 AVAudioPlayer
//
//  `AVAudioPlayer` **播不動 Ogg-Opus**，AVFoundation 也沒有內建的 Opus
//  解碼器。而錄音的格式是 Ogg-Opus，理由是檔案大小：語音 32 kbps 一小時
//  約 14 MB，而同步走的是使用者自己的雲端空間。
//
//  所以播放走「核心解碼 → PCM → AVAudioPlayerNode」。Android 端不需要這一層
//  （MediaPlayer 解得了 Ogg-Opus），但**解碼本身在核心**，兩個平台聽到的
//  才保證是同一段聲音。
//
//  # 為什麼是串流，不是整段解完再播
//
//  一小時錄音解出來是 230 MB 的 PCM（16 kHz 單聲道 f32）。一次解完等於
//  在手機上一次配置 230 MB —— App 會直接被系統收掉。所以這裡一次只排
//  幾秒的緩衝，播完一段再要下一段。
//
//  # 跳轉的代價
//
//  Opus 在 Ogg 裡要靠 granule 才能精準跳轉，而那需要在核心做頁面搜尋。
//  目前的做法是**重開解碼器再往前丟掉 N 個樣本** —— 對幾分鐘的錄音
//  （絕大多數）沒有感覺，對一小時的錄音跳到結尾會明顯卡一下。
//  真的變成問題時再往核心加 granule 搜尋，不要在這裡自己解 Ogg。
//

import AVFoundation
import Foundation

/// 用核心解碼器播放 `.opus` 錄音。
@MainActor
final class OpusAudioPlayer {

    /// 一次排進去的樣本數。
    ///
    /// 太小會讓完成回呼頻繁到影響音訊執行緒；太大則讓暫停與跳轉的反應
    /// 變鈍（已經排進去的緩衝還是會播完）。0.25 秒是折衷。
    private static let chunkSamples: UInt32 = 4_000

    /// 預先排幾段。少於兩段時，解碼稍微慢一點就會斷音。
    private static let bufferAhead = 3

    private let engine = AVAudioEngine()
    private let node = AVAudioPlayerNode()
    private let format: AVAudioFormat

    private var decoder: FfiAudioDecoder?
    private var sourceURL: URL?
    /// 已經排進播放佇列的樣本數（不是已經播出去的）。
    private var scheduledSamples: Int = 0
    /// 已經播完的樣本數，由緩衝的完成回呼累加。
    private var playedSamples: Int = 0
    private var totalSamples: Int = 0
    private var reachedEnd = false
    private var isRunning = false

    /// 播完了（自然結束，不是被停掉）。
    var onFinished: (() -> Void)?

    init?() {
        // 核心固定輸出 16 kHz 單聲道 f32。
        guard let fmt = AVAudioFormat(
            commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false)
        else { return nil }
        self.format = fmt
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: fmt)
    }

    var isPlaying: Bool { node.isPlaying }

    /// 0…1。長度讀不出來時回 0，而不是讓進度條亂跳。
    var progress: Double {
        guard totalSamples > 0 else { return 0 }
        return min(1, Double(playedSamples) / Double(totalSamples))
    }

    var duration: TimeInterval {
        guard totalSamples > 0 else { return 0 }
        return Double(totalSamples) / format.sampleRate
    }

    var currentTime: TimeInterval {
        Double(playedSamples) / format.sampleRate
    }

    /// 開始播放某個檔案。回傳 false 表示這個檔案打不開。
    @discardableResult
    func play(url: URL) -> Bool {
        stop()
        guard let decoder = audioDecoderOpen(path: url.path) else { return false }
        self.decoder = decoder
        self.sourceURL = url
        let info = decoder.info()
        totalSamples = Int(Double(info.durationUs) * format.sampleRate / 1_000_000)
        playedSamples = 0
        scheduledSamples = 0
        reachedEnd = false

        do {
            #if os(iOS) || targetEnvironment(macCatalyst)
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            #endif
            if !engine.isRunning {
                try engine.start()
            }
        } catch {
            print("[OpusAudioPlayer] 引擎啟動失敗：\(error)")
            return false
        }

        isRunning = true
        for _ in 0..<Self.bufferAhead {
            scheduleNext()
        }
        node.play()
        return true
    }

    func pause() {
        node.pause()
    }

    func resume() {
        guard decoder != nil else { return }
        if !engine.isRunning {
            try? engine.start()
        }
        node.play()
    }

    func stop() {
        isRunning = false
        node.stop()
        node.reset()
        if engine.isRunning {
            engine.stop()
        }
        decoder = nil
        sourceURL = nil
        scheduledSamples = 0
        playedSamples = 0
        totalSamples = 0
        reachedEnd = false
    }

    /// 跳到某個時間點。
    ///
    /// 重開解碼器再往前丟樣本 —— 代價見檔頭說明。
    func seek(to time: TimeInterval) {
        guard let url = sourceURL else { return }
        let wasPlaying = node.isPlaying
        let target = max(0, min(time, duration))
        let targetSamples = Int(target * format.sampleRate)

        node.stop()
        node.reset()
        guard let fresh = audioDecoderOpen(path: url.path) else { return }
        decoder = fresh
        // 丟掉目標之前的樣本。整段一次要會把記憶體吃光，所以分批丟。
        var dropped = 0
        while dropped < targetSamples {
            let want = min(Self.chunkSamples, UInt32(targetSamples - dropped))
            let chunk = fresh.nextChunk(maxSamples: want)
            if chunk.isEmpty { break }
            dropped += chunk.count
        }
        playedSamples = dropped
        scheduledSamples = dropped
        reachedEnd = false
        isRunning = true

        for _ in 0..<Self.bufferAhead {
            scheduleNext()
        }
        if wasPlaying {
            node.play()
        }
    }

    /// 排下一段緩衝。
    private func scheduleNext() {
        guard isRunning, !reachedEnd, let decoder else { return }
        let samples = decoder.nextChunk(maxSamples: Self.chunkSamples)
        guard !samples.isEmpty else {
            reachedEnd = true
            return
        }
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
            let channel = buffer.floatChannelData?[0]
        else { return }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { src in
            channel.update(from: src.baseAddress!, count: samples.count)
        }
        scheduledSamples += samples.count

        let count = samples.count
        node.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            // 回呼在音訊執行緒上，狀態都是 @MainActor 的，所以跳回去。
            Task { @MainActor in
                guard let self, self.isRunning else { return }
                self.playedSamples += count
                self.scheduleNext()
                // 排不出新的而且佇列見底了 ⇒ 真的播完了。
                if self.reachedEnd && self.playedSamples >= self.scheduledSamples {
                    let finished = self.onFinished
                    self.stop()
                    finished?()
                }
            }
        }
    }
}
