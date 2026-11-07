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
            playerNode?.volume = isMuted ? 0.0 : 1.0
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

    // MARK: - 播放引擎
    private var playEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
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
            ensurePlaybackEngineReady()

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
                playPcmChunk(pcmData)
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
        #if os(iOS) || targetEnvironment(macCatalyst)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch {
            print("⚠️ [CollabVoice] AVAudioSession 設置失敗: \(error)")
        }
        #endif

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

        #if os(iOS) || targetEnvironment(macCatalyst)
        // 釋放錄音獨佔
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }

    // MARK: - 底層音訊播放（AVAudioPlayerNode）

    private func ensurePlaybackEngineReady() {
        if playEngine != nil && playEngine?.isRunning == true { return }

        let engine = AVAudioEngine()
        let node = AVAudioPlayerNode()
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: audioFormat)

        do {
            try engine.start()
            node.play()
            self.playEngine = engine
            self.playerNode = node
            node.volume = isMuted ? 0.0 : 1.0
        } catch {
            print("⚠️ [CollabVoice] 播放引擎啟動失敗: \(error)")
        }
    }

    private func playPcmChunk(_ pcmData: Data) {
        ensurePlaybackEngineReady()
        guard let node = playerNode, node.isPlaying else { return }

        let sampleCount = pcmData.count / 2
        guard sampleCount > 0 else { return }
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(sampleCount)) else { return }
        pcmBuffer.frameLength = AVAudioFrameCount(sampleCount)

        pcmData.withUnsafeBytes { raw in
            if let base = raw.baseAddress, let channel = pcmBuffer.int16ChannelData?[0] {
                channel.assign(from: base.assumingMemoryBound(to: Int16.self), count: sampleCount)
            }
        }

        node.scheduleBuffer(pcmBuffer, completionHandler: nil)
    }

    /// 離開房間或斷線時完全釋放
    public func reset() {
        stopTalking()
        speakerTimeoutTimer?.invalidate()
        speakerTimeoutTimer = nil
        currentSpeakerUserId = nil
        activeSpeakerName = nil

        playerNode?.stop()
        playEngine?.stop()
        playerNode = nil
        playEngine = nil
    }
}

private extension CollaborationStatus {
    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}
