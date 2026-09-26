//
//  CoreAudioCapture.swift
//  Kairumo
//
//  用麥克風餵核心的錄音管線（R2）。
//
//  # 為什麼不再用 AVAudioRecorder
//
//  `AVAudioRecorder` 寫的是 `.m4a`，而且寫在它自己指定的路徑上。
//  那條路的後果是：錄音存在 `Documents/Kairumo Record` —— **套件外面**，
//  而同步的單位是套件，所以 Apple 的錄音**從來沒有被同步過**。
//  格式也對不上：核心的同步只搬 `media/audio/*.opus`。
//
//  改走核心之後，錄音直接落在所屬筆記本的 `media/audio/<uuid>.opus`，
//  同步不必再多做任何事（`gdrive_sync_media` 早就在搬那個目錄），
//  而且與 Android 走的是**同一條**管線 —— 兩邊錄出來的檔案逐位元組同構。
//
//  # 取樣率
//
//  核心固定吃 16 kHz 單聲道 f32（ASR 模型也是這個格式，錄製端直接對齊
//  可以省一次重採樣）。麥克風給的通常是 44.1 或 48 kHz，所以中間要
//  `AVAudioConverter`。**不能只是抽樣丟點** —— 那會產生混疊，
//  聽起來像金屬聲，而且 ASR 的辨識率會掉。
//

import AVFoundation
import Foundation

/// 從麥克風擷取音訊並餵給核心的錄音管線。
@MainActor
final class CoreAudioCapture {

    /// 核心要的格式。
    private static let targetSampleRate: Double = 16_000

    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private var targetFormat: AVAudioFormat?
    private var session: PadnoteSession?
    private var isPaused = false
    private var tapInstalled = false

    /// 餵音訊失敗時回報（例如核心那邊沒有在錄音）。
    var onError: ((String) -> Void)?

    var isCapturing: Bool { engine.isRunning }

    /// 開始錄音，回傳核心給的 session uuid（＝ `media/audio/<uuid>.opus`）。
    ///
    /// 失敗時回 nil，並且**不會留下半開的狀態** —— 引擎、tap 與核心的
    /// 錄音狀態都會收乾淨。
    func start(session: PadnoteSession) -> String? {
        stop()

        guard let target = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Self.targetSampleRate,
            channels: 1,
            interleaved: false)
        else { return nil }

        let input = engine.inputNode
        var chosenFormat = input.outputFormat(forBus: 0)
        if chosenFormat.sampleRate <= 0 || chosenFormat.channelCount == 0 {
            chosenFormat = input.inputFormat(forBus: 0)
        }
        if chosenFormat.sampleRate <= 0 || chosenFormat.channelCount == 0 {
            #if os(iOS) || targetEnvironment(macCatalyst)
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playAndRecord, mode: .default)
            try? session.setActive(true)
            chosenFormat = input.outputFormat(forBus: 0)
            if chosenFormat.sampleRate <= 0 || chosenFormat.channelCount == 0 {
                chosenFormat = input.inputFormat(forBus: 0)
            }
            #endif
        }

        // 取樣率為 0 表示麥克風還沒準備好（權限沒過、或被別的 App 佔用）。
        guard chosenFormat.sampleRate > 0 && chosenFormat.channelCount > 0 else {
            onError?("麥克風尚未就緒（取樣率: \(chosenFormat.sampleRate), 聲道: \(chosenFormat.channelCount)）")
            return nil
        }
        guard let converter = AVAudioConverter(from: chosenFormat, to: target) else {
            onError?("建不出音訊轉換器")
            return nil
        }

        let recordingId: String
        do {
            recordingId = try session.startRecording()
        } catch {
            onError?("核心無法開始錄音：\(error)")
            return nil
        }

        self.converter = converter
        self.targetFormat = target
        self.session = session
        self.isPaused = false

        input.installTap(onBus: 0, bufferSize: 4096, format: chosenFormat) { [weak self] buffer, _ in
            // 這個回呼在音訊執行緒上。**不要在這裡碰 @MainActor 的狀態**，
            // 也不要做會配置記憶體以外的重活 —— 卡住它就是卡住麥克風。
            self?.feed(buffer)
        }
        tapInstalled = true

        do {
            engine.prepare()
            try engine.start()
        } catch {
            onError?("音訊引擎啟動失敗：\(error)")
            stop()
            return nil
        }
        return recordingId
    }

    func pause() {
        isPaused = true
    }

    func resume() {
        isPaused = false
    }

    /// 停止擷取。**不呼叫核心的 stopRecording** —— 那是呼叫端的事，
    /// 因為它還要拿回長度與檔名。
    func stop() {
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        if engine.isRunning {
            engine.stop()
        }
        converter = nil
        targetFormat = nil
        session = nil
        isPaused = false
    }

    /// 把麥克風的緩衝轉成 16 kHz 單聲道再餵給核心。
    private nonisolated func feed(_ buffer: AVAudioPCMBuffer) {
        Task { @MainActor in
            guard !self.isPaused,
                  let target = self.targetFormat,
                  let session = self.session
            else { return }

            if self.converter == nil || self.converter?.inputFormat != buffer.format {
                self.converter = AVAudioConverter(from: buffer.format, to: target)
            }
            guard let converter = self.converter else { return }

            // 輸出容量按取樣率比例估，多給一點餘裕：估太小會被轉換器截斷，
            // 而截斷的症狀是聲音會週期性地缺一小塊。
            let ratio = target.sampleRate / buffer.format.sampleRate
            let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 64
            guard let out = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else {
                return
            }

            var consumed = false
            var error: NSError?
            converter.convert(to: out, error: &error) { _, status in
                // 同一個輸入緩衝只能交出去一次。再交一次會讓轉換器
                // 把同一段音重複算進去。
                if consumed {
                    status.pointee = .noDataNow
                    return nil
                }
                consumed = true
                status.pointee = .haveData
                return buffer
            }
            if let error {
                self.onError?("音訊轉換失敗：\(error.localizedDescription)")
                return
            }
            guard out.frameLength > 0, let channel = out.floatChannelData?[0] else { return }
            let samples = Array(UnsafeBufferPointer(start: channel, count: Int(out.frameLength)))
            do {
                _ = try session.feedAudio(pcm16kMono: samples)
            } catch {
                self.onError?("餵音訊失敗：\(error)")
            }
        }
    }
}
