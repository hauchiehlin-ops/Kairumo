//
//  CollabVoiceManager.swift
//  Kairumo
//
//  線上協同：按住說話（PTT 對講機）語音即時串流（`live_voice`）。
//  走原生低延遲音訊（iOS/macOS: AVAudioEngine + VoiceProcessingIO 硬體回音消除），
//  透過既有協同房間 WebSocket 傳輸（中繼轉發、不落庫），並以房間金鑰（AES-256-GCM）端對端加密。
//

import AVFoundation
import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// 協同即時語音管理器（單例，MainActor 管控）。
@MainActor
public final class CollabVoiceManager: ObservableObject {
    // profile-scope: device 協同語音硬體管線與即時串流為整台裝置音訊硬體資源，離開協同即停止釋放
    public static let shared = CollabVoiceManager()

    /// 是否正在長按發話中（PTT active）
    @Published public private(set) var isTalking: Bool = false

    /// 房間內目前正在發話的成員名稱（nil 代表無人發話）
    @Published public private(set) var activeSpeakerName: String? = nil

    /// 是否將房間內其他人聲音全域靜音
    @Published public var isMuted: Bool = false {
        didSet {
            player.setMuted(isMuted)
        }
    }

    /// 音訊取樣率（固定 16kHz 單聲道，極致節省頻寬與運算）
    public static let sampleRate: Double = 16_000.0
    private static let frameDuration: TimeInterval = 0.1 // 100ms 一個微音框
    private static let frameSamples: Int = Int(sampleRate * frameDuration) // 1600 samples

    // MARK: - 錄音引擎（VoiceProcessing）
    private var recordEngine: AVAudioEngine?
    private var isRecordingPipelineActive = false
    private var outgoingSeq: UInt32 = 0
    private var pendingOutgoingPcm: [Int16] = []
    private var voiceSendTimer: Timer?

    // MARK: - 播放引擎（獨立序列佇列，見 `CollabVoicePlayer`）
    private let player = CollabVoicePlayer()
    private let audioFormat: AVAudioFormat

    // 遠端發話逾時監視器（若對方斷線未送 end，自動恢復無人發話）
    private var speakerTimeoutTimer: Timer?
    private var currentSpeakerUserId: String?

    private init() {
        self.audioFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: Self.sampleRate,
            channels: 1,
            interleaved: false
        )!
    }

    // MARK: - PTT 按住發話控制

    /// 使用者按下 PTT 按鈕開始說話
    public func startTalking() {
        guard !isTalking else { return }
        guard CollaborationManager.shared.status.isConnected else { return }

        isTalking = true
        outgoingSeq = 0
        pendingOutgoingPcm.removeAll(keepingCapacity: true)

        startAudioCapture()

        // 廣播開始發話標誌，讓房間成員畫面同步顯示「XXX 正在說話」
        CollaborationManager.shared.sendLiveVoice(
            phase: "begin",
            seq: outgoingSeq,
            audioBase64: ""
        )
    }

    /// 使用者放開 PTT 按鈕停止說話
    public func stopTalking() {
        guard isTalking else { return }
        isTalking = false

        stopAudioCapture()

        // 廣播結束發話標誌
        CollaborationManager.shared.sendLiveVoice(
            phase: "end",
            seq: outgoingSeq + 1,
            audioBase64: ""
        )
        pendingOutgoingPcm.removeAll()
    }

    // MARK: - 接收遠端語音（`live_voice`）

    /// 接收遠端成員送來的微音框
    public func receiveRemoteVoice(userId: String, payload: [String: Any]) {
        guard userId != CollaborationManager.shared.currentUserId else { return }

        let phase = (payload["phase"] as? String) ?? "chunk"
        let userName = (payload["user_name"] as? String) ?? userId.prefix(6).description
        let audioBase64 = (payload["audio"] as? String) ?? ""

        switch phase {
        case "begin":
            currentSpeakerUserId = userId
            activeSpeakerName = userName
            resetSpeakerTimeoutTimer()
            player.prepare()

        case "end":
            if currentSpeakerUserId == userId {
                currentSpeakerUserId = nil
                activeSpeakerName = nil
                speakerTimeoutTimer?.invalidate()
                speakerTimeoutTimer = nil
            }

        default: // "chunk"
            if currentSpeakerUserId == nil || currentSpeakerUserId == userId {
                currentSpeakerUserId = userId
                activeSpeakerName = userName
                resetSpeakerTimeoutTimer()
            }
            if !isMuted, !audioBase64.isEmpty, let pcmData = Data(base64Encoded: audioBase64) {
                player.play(pcm16: pcmData)
            }
        }
    }

    private func resetSpeakerTimeoutTimer() {
        speakerTimeoutTimer?.invalidate()
        speakerTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.currentSpeakerUserId = nil
                self?.activeSpeakerName = nil
            }
        }
    }

    // MARK: - 底層音訊擷取（Apple VoiceProcessingIO）

    private func startAudioCapture() {
        CollabVoicePlayer.activateVoiceSession()

        let engine = AVAudioEngine()
        self.recordEngine = engine
        let inputNode = engine.inputNode

        // 開啟 iOS/macOS 系統硬體級回音消除 (AEC) 與降噪
        do {
            try inputNode.setVoiceProcessingEnabled(true)
        } catch {
            print("⚠️ [CollabVoice] setVoiceProcessingEnabled 失敗，退回標準輸入: \(error)")
        }

        let inputFormat = inputNode.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0 else { return }

        // 重採樣器（將設備硬體取樣率轉換為 16kHz 單聲道 Int16）
        guard let converter = AVAudioConverter(from: inputFormat, to: audioFormat) else {
            print("⚠️ [CollabVoice] 無法建立音訊轉碼器")
            return
        }

        inputNode.installTap(onBus: 0, bufferSize: 2048, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }

            let frameCount = AVAudioFrameCount(Double(buffer.frameLength) * (Self.sampleRate / inputFormat.sampleRate))
            guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: self.audioFormat, frameCapacity: frameCount + 64) else { return }

            var error: NSError?
            var haveData = false
            converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                if !haveData {
                    haveData = true
                    outStatus.pointee = .haveData
                    return buffer
                } else {
                    outStatus.pointee = .noDataNow
                    return nil
                }
            }

            if let channelData = convertedBuffer.int16ChannelData?[0], convertedBuffer.frameLength > 0 {
                let count = Int(convertedBuffer.frameLength)
                let samples = Array(UnsafeBufferPointer(start: channelData, count: count))
                Task { @MainActor [weak self] in
                    self?.handleCapturedSamples(samples)
                }
            }
        }

        do {
            engine.prepare()
            try engine.start()
            isRecordingPipelineActive = true
        } catch {
            print("⚠️ [CollabVoice] 錄音引擎啟動失敗: \(error)")
            stopAudioCapture()
        }
    }

    private func handleCapturedSamples(_ samples: [Int16]) {
        guard isTalking else { return }
        pendingOutgoingPcm.append(contentsOf: samples)

        // 滿 100ms（1600 個 samples）就送出一個微封包
        while pendingOutgoingPcm.count >= Self.frameSamples {
            let chunk = Array(pendingOutgoingPcm.prefix(Self.frameSamples))
            pendingOutgoingPcm.removeFirst(Self.frameSamples)

            outgoingSeq += 1
            let data = chunk.withUnsafeBufferPointer { Data(buffer: $0) }
            let b64 = data.base64EncodedString()

            CollaborationManager.shared.sendLiveVoice(
                phase: "chunk",
                seq: outgoingSeq,
                audioBase64: b64
            )
        }
    }

    private func stopAudioCapture() {
        if let engine = recordEngine {
            if isRecordingPipelineActive {
                engine.inputNode.removeTap(onBus: 0)
                engine.stop()
                isRecordingPipelineActive = false
            }
        }
        recordEngine = nil
        // 不在這裡停用 AVAudioSession：舊版放開 PTT 就 `setActive(false)`，
        // 把同一個 session 上的播放引擎一起關掉 —— 房主說過一次話之後就再也聽不到別人。
        // session 只在離開房間（`reset()`）時才釋放。
    }

    /// 離開房間或斷線時完全釋放
    public func reset() {
        stopTalking()
        speakerTimeoutTimer?.invalidate()
        speakerTimeoutTimer = nil
        currentSpeakerUserId = nil
        activeSpeakerName = nil

        player.shutdown()
    }
}

// MARK: - 遠端語音播放器

/// 遠端語音播放（AVAudioEngine + AVAudioPlayerNode），所有操作在自己的序列佇列上執行。
///
/// 為什麼要獨立出來（實機回報「Android 協作者按麥克風，iPad 房主沒有聲音」）：
/// 1. **格式**：舊版把 16-bit 整數（Int16）格式直接接到 `AVAudioPlayerNode → mainMixerNode`，
///    再排入 Int16 緩衝。播放節點只吃標準的 Float32 非交錯格式，Int16 緩衝排進去不是被丟掉就是無聲。
///    這裡一律把收到的 PCM16 轉成 Float32 再排入，取樣率轉換交給混音器。
/// 2. **音訊工作階段**：只聽不講的一方（典型就是房主）從沒設定過 AVAudioSession，
///    停在系統預設的 `soloAmbient`，會被靜音鍵／控制中心靜音吃掉；而講過話的一方放開 PTT
///    時舊版會 `setActive(false)`，把播放引擎一起關掉。現在收到第一個語音事件就把 session
///    設成 `playAndRecord + voiceChat + defaultToSpeaker`，離開房間才釋放。
/// 3. **主執行緒**：`setActive`／`engine.start()` 可能阻塞數十毫秒，放在主執行緒會吃掉筆跡幀預算；
///    改在專用序列佇列上做（Layer 3 主執行緒非阻塞）。
/// 4. **自癒**：音訊路由變更（插拔耳機、錄音引擎開啟語音處理）會讓播放引擎停下，
///    下一個音框到達時偵測到 `!isRunning` 就重建。
final class CollabVoicePlayer: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.kairumo.collab.voice.player", qos: .userInteractive)
    private var engine: AVAudioEngine?
    private var node: AVAudioPlayerNode?
    private var muted = false
    /// 播放用標準格式：16kHz、單聲道、Float32 非交錯。
    private let floatFormat = AVAudioFormat(
        standardFormatWithSampleRate: 16_000, // 與 `CollabVoiceManager.sampleRate` 相同（live_voice 協定固定 16kHz）
        channels: 1
    )!

    /// 設定協同語音用的音訊工作階段（錄音與播放共用）。可重複呼叫。
    static func activateVoiceSession() {
        #if os(iOS) || targetEnvironment(macCatalyst)
        let session = AVAudioSession.sharedInstance()
        do {
            if session.category != .playAndRecord || session.mode != .voiceChat {
                try session.setCategory(
                    .playAndRecord,
                    mode: .voiceChat,
                    options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers]
                )
            }
            try session.setActive(true)
        } catch {
            print("⚠️ [CollabVoice] AVAudioSession 設置失敗: \(error)")
        }
        #endif
    }

    func setMuted(_ value: Bool) {
        queue.async { [self] in
            muted = value
            node?.volume = value ? 0 : 1
        }
    }

    /// 預熱播放引擎（收到對方 `begin` 時呼叫），讓第一個音框不必等引擎啟動。
    func prepare() {
        queue.async { [self] in _ = ensureRunning() }
    }

    /// 播放一個 16kHz 單聲道 16-bit little-endian PCM 音框。
    func play(pcm16 data: Data) {
        queue.async { [self] in
            guard let node = ensureRunning() else { return }
            let count = data.count / 2
            guard count > 0,
                  let buffer = AVAudioPCMBuffer(pcmFormat: floatFormat, frameCapacity: AVAudioFrameCount(count)),
                  let out = buffer.floatChannelData?[0] else { return }
            buffer.frameLength = AVAudioFrameCount(count)
            data.withUnsafeBytes { raw in
                for i in 0..<count {
                    let sample = Int16(littleEndian: raw.loadUnaligned(fromByteOffset: i * 2, as: Int16.self))
                    out[i] = Float(sample) / 32768.0
                }
            }
            node.scheduleBuffer(buffer, completionHandler: nil)
            if !node.isPlaying { node.play() }
        }
    }

    /// 離開房間：停掉引擎並釋放音訊工作階段。
    func shutdown() {
        queue.async { [self] in
            node?.stop()
            engine?.stop()
            node = nil
            engine = nil
            #if os(iOS) || targetEnvironment(macCatalyst)
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            #endif
        }
    }

    /// 只在 `queue` 上呼叫。引擎沒在跑（第一次、或被路由變更停掉）就重建。
    private func ensureRunning() -> AVAudioPlayerNode? {
        if let engine, let node, engine.isRunning { return node }
        node?.stop()
        engine?.stop()
        Self.activateVoiceSession()
        let newEngine = AVAudioEngine()
        let newNode = AVAudioPlayerNode()
        newEngine.attach(newNode)
        newEngine.connect(newNode, to: newEngine.mainMixerNode, format: floatFormat)
        do {
            newEngine.prepare()
            try newEngine.start()
            newNode.volume = muted ? 0 : 1
            newNode.play()
            engine = newEngine
            node = newNode
            return newNode
        } catch {
            print("⚠️ [CollabVoice] 播放引擎啟動失敗: \(error)")
            engine = nil
            node = nil
            return nil
        }
    }
}

private extension CollaborationStatus {
    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}
