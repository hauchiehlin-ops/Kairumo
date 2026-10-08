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

/// 專責音訊重採樣與管線串流的背景處理器。
/// 保證所有麥克風取樣都在專用序列佇列上完成轉碼與送交核心，避免阻塞主執行緒或丟失收尾取樣。
private final class CoreAudioPipeline: @unchecked Sendable {
    private static let targetSampleRate: Double = 16_000
    private let audioQueue = DispatchQueue(label: "com.kairumo.audio.capture", qos: .userInitiated)
    private var converter: AVAudioConverter?
    private var targetFormat: AVAudioFormat?
    private var session: PadnoteSession?
    private var isPaused = false

    func configure(session: PadnoteSession, sourceFormat: AVAudioFormat, targetFormat: AVAudioFormat) {
        audioQueue.sync {
            self.session = session
            self.targetFormat = targetFormat
            self.converter = AVAudioConverter(from: sourceFormat, to: targetFormat)
            self.isPaused = false
        }
    }

    func pause() {
        audioQueue.sync { self.isPaused = true }
    }

    func resume() {
        audioQueue.sync { self.isPaused = false }
    }

    /// 停止管線並同步等待所有在隊列中的音訊緩衝處理完畢
    func stop() {
        audioQueue.sync {
            self.converter = nil
            self.targetFormat = nil
            self.session = nil
            self.isPaused = false
        }
    }

    func feed(_ buffer: AVAudioPCMBuffer, onError: (@Sendable (String) -> Void)?) {
        guard let copy = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameLength) else { return }
        copy.frameLength = buffer.frameLength
        let channelCount = Int(buffer.format.channelCount)
        if buffer.format.isInterleaved {
            if let src = buffer.floatChannelData?[0], let dst = copy.floatChannelData?[0] {
                dst.assign(from: src, count: Int(buffer.frameLength) * channelCount)
            } else if let src = buffer.int16ChannelData?[0], let dst = copy.int16ChannelData?[0] {
                dst.assign(from: src, count: Int(buffer.frameLength) * channelCount)
            }
        } else {
            if let srcData = buffer.floatChannelData, let dstData = copy.floatChannelData {
                for ch in 0..<channelCount {
                    dstData[ch].assign(from: srcData[ch], count: Int(buffer.frameLength))
                }
            } else if let srcData = buffer.int16ChannelData, let dstData = copy.int16ChannelData {
                for ch in 0..<channelCount {
                    dstData[ch].assign(from: srcData[ch], count: Int(buffer.frameLength))
                }
            }
        }

        audioQueue.async { [weak self] in
            guard let self = self else { return }
            self.process(copy, onError: onError)
        }
    }

    private func process(_ buffer: AVAudioPCMBuffer, onError: (@Sendable (String) -> Void)?) {
        guard !isPaused,
              let target = targetFormat,
              let session = session
        else { return }

        if converter == nil || converter?.inputFormat != buffer.format {
            converter = AVAudioConverter(from: buffer.format, to: target)
        }
        guard let converter = converter else { return }

        let ratio = target.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 64
        guard let out = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return }

        var consumed = false
        var error: NSError?
        converter.convert(to: out, error: &error) { _, status in
            if consumed {
                status.pointee = .noDataNow
                return nil
            }
            consumed = true
            status.pointee = .haveData
            return buffer
        }
        if let error = error {
            onError?(L10n.f("rec_err_convert", L10n.errorText(error)))
            return
        }
        guard out.frameLength > 0, let channel = out.floatChannelData?[0] else { return }
        let samples = Array(UnsafeBufferPointer(start: channel, count: Int(out.frameLength)))
        do {
            _ = try session.feedAudio(pcm16kMono: samples)
            session.advanceTime(notebookTimeUs: session.recordedAudioUs())
        } catch {
            onError?(L10n.f("rec_err_feed", "\(error)"))
        }
    }
}

/// 從麥克風擷取音訊並餵給核心的錄音管線。
@MainActor
final class CoreAudioCapture {

    /// 核心要的格式。
    private static let targetSampleRate: Double = 16_000

    #if os(iOS) || targetEnvironment(macCatalyst)
    /// 錄音時 `AVAudioSession` 的選項（非 Mac）。三個開始錄音的地方共用這一份。
    ///
    /// # 為什麼不用 `.allowBluetooth`
    ///
    /// `.allowBluetooth` 開的是 **HFP**：只要戴著藍牙耳機，輸入就被切到耳機的
    /// 麥克風，取樣率掉到 8／16 kHz 窄頻、還經過耳機自己的通話降噪 —— 對「把
    /// 裝置放在桌上錄整堂課」是最差的來源，講者的聲音幾乎收不到。
    /// `.allowBluetoothA2DP` 只讓**輸出**走藍牙（高品質播放），輸入留在內建麥克風。
    nonisolated static let recordingCategoryOptions: AVAudioSession.CategoryOptions = [
        .defaultToSpeaker, .allowBluetoothA2DP,
    ]

    #if !targetEnvironment(macCatalyst)
    /// 階段 2：若硬體支援心形或次心形指向收音，優先設定（物理降噪，抑制後方與側邊雜音）。
    nonisolated static func configureCardioidIfAvailable(_ session: AVAudioSession) {
        guard let inputs = session.availableInputs,
              let builtIn = inputs.first(where: { $0.portType == .builtInMic }) else { return }
        do {
            try session.setPreferredInput(builtIn)
            if let dataSources = builtIn.dataSources {
                let selectedSource = dataSources.first { ds in
                    ds.supportedPolarPatterns?.contains(.cardioid) == true ||
                    ds.supportedPolarPatterns?.contains(.subcardioid) == true
                } ?? dataSources.first
                if let ds = selectedSource {
                    if let patterns = ds.supportedPolarPatterns {
                        if patterns.contains(.cardioid) {
                            try ds.setPreferredPolarPattern(.cardioid)
                        } else if patterns.contains(.subcardioid) {
                            try ds.setPreferredPolarPattern(.subcardioid)
                        }
                    }
                    try builtIn.setPreferredDataSource(ds)
                }
            }
        } catch {
            StartupLogger.logKey("log_capture_cardioid", "\(error)")
        }
    }
    #endif
    #endif

    private var engine: AVAudioEngine?
    private let pipeline = CoreAudioPipeline()
    private var tapInstalled = false

    /// 餵音訊失敗時回報（例如核心那邊沒有在錄音）。
    var onError: ((String) -> Void)?

    var isCapturing: Bool { engine?.isRunning ?? false }

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

        #if os(iOS) || targetEnvironment(macCatalyst)
        let audioSession = AVAudioSession.sharedInstance()
        do {
            if ProcessInfo.processInfo.isiOSAppOnMac {
                try audioSession.setCategory(.playAndRecord, mode: .default)
            } else {
                try audioSession.setCategory(.playAndRecord, mode: .default, options: CoreAudioCapture.recordingCategoryOptions)
            }
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            #if os(iOS) && !targetEnvironment(macCatalyst)
            if !ProcessInfo.processInfo.isiOSAppOnMac {
                Self.configureCardioidIfAvailable(audioSession)
            }
            #endif
        } catch {
            StartupLogger.logKey("log_capture_session", "\(error)")
        }
        #endif

        let newEngine = AVAudioEngine()
        self.engine = newEngine
        let input = newEngine.inputNode

        #if os(iOS) || targetEnvironment(macCatalyst)
        if !AVAudioSession.sharedInstance().isInputAvailable || AVAudioSession.sharedInstance().inputNumberOfChannels == 0 {
            onError?(L10n.t("rec_err_no_mic"))
            stop()
            return nil
        }
        #endif

        let hwFormat = input.inputFormat(forBus: 0)
        let outFormat = input.outputFormat(forBus: 0)
        if hwFormat.channelCount == 0 && outFormat.channelCount == 0 {
            onError?(L10n.t("rec_err_no_channels"))
            stop()
            return nil
        }

        var chosenFormat = (outFormat.channelCount > 0 && outFormat.sampleRate > 0) ? outFormat : hwFormat
        if chosenFormat.sampleRate <= 0 || chosenFormat.channelCount == 0 {
            chosenFormat = input.inputFormat(forBus: 0)
        }

        // 取樣率或聲道為 0 表示麥克風硬體不可用（權限沒過、無輸入設備、或被別的 App 佔用）。
        guard chosenFormat.sampleRate > 0 && chosenFormat.channelCount > 0 else {
            onError?(L10n.f("rec_err_not_ready", chosenFormat.sampleRate, chosenFormat.channelCount))
            stop()
            return nil
        }

        let recordingId: String
        do {
            recordingId = try session.startRecording()
        } catch {
            onError?(L10n.f("rec_err_core_start", "\(error)"))
            stop()
            return nil
        }

        pipeline.configure(session: session, sourceFormat: chosenFormat, targetFormat: target)

        let errorHandler = self.onError
        input.installTap(onBus: 0, bufferSize: 4096, format: chosenFormat) { [weak self] buffer, _ in
            self?.pipeline.feed(buffer, onError: errorHandler)
        }
        tapInstalled = true

        do {
            newEngine.prepare()
            try newEngine.start()
        } catch {
            onError?(L10n.f("rec_err_engine_start", "\(error)"))
            stop()
            return nil
        }
        return recordingId
    }

    func pause() {
        pipeline.pause()
    }

    func resume() {
        pipeline.resume()
    }

    /// 停止擷取。**不呼叫核心的 stopRecording** —— 那是呼叫端的事，
    /// 因為它還要拿回長度與檔名。
    func stop() {
        if let engine = self.engine {
            if tapInstalled {
                engine.inputNode.removeTap(onBus: 0)
                tapInstalled = false
            }
            if engine.isRunning {
                engine.stop()
            }
            engine.reset()
            self.engine = nil
            // **把錄音用的 audio session 還回去。**
            //
            // 停止錄音之後 session 還停在 `.playAndRecord` 且啟用中。緊接著按錄音卡片的
            // 播放鈕時，播放那邊要把它切成 `.playback` 再啟動引擎 —— 麥克風剛放開的那一瞬間
            // 切換可能失敗，而失敗只印一行 log，使用者看到的就是「按了沒有反應」，
            // 轉文字（不碰 audio session）卻是好的。先在這裡停用，播放端拿到的就是乾淨的 session。
            #if os(iOS) || targetEnvironment(macCatalyst)
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            #endif
        }
        pipeline.stop()
    }
}
