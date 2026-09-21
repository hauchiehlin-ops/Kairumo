//
//  AudioRecorderManager.swift
//  Kairumo
//
//  真實音訊錄製與播放管理員（AVFoundation 實作）
//  支援即時波形計算、時間戳對齊與音訊檔案持久化
//  預設儲存路徑：本機「文件」資料夾中的「Kairumo Record」目錄
//

import Foundation
import AVFoundation
import Combine
import UIKit

/// 即時錄音狀態
public enum RecordingStatus {
    case idle
    case recording
    case paused
}

@MainActor
public final class AudioRecorderManager: NSObject, ObservableObject, AVAudioRecorderDelegate, AVAudioPlayerDelegate {
    public static let shared = AudioRecorderManager()

    @Published public var status: RecordingStatus = .idle
    @Published public var elapsedSeconds: TimeInterval = 0
    @Published public var audioLevels: [CGFloat] = Array(repeating: 0.15, count: 20)
    @Published public var showPermissionAlert: Bool = false
    @Published public var isPlaying: Bool = false
    @Published public var playingRecordingId: String? = nil
    @Published public var playbackProgress: Double = 0.0

    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    /// Ogg-Opus 的播放器。`AVAudioPlayer` 播不動這個格式，見 `OpusAudioPlayer`。
    private var opusPlayer: OpusAudioPlayer?
    private var timer: Timer?
    private var playbackTimer: Timer?
    private var currentAudioUrl: URL?

    /// 錄音檔預設儲存位置：本機文件資料夾（自動新設「Kairumo Record」資料夾）
    public var recordingsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let kairumoRecordDir = docs.appendingPathComponent("Kairumo Record", isDirectory: true)

        if !FileManager.default.fileExists(atPath: kairumoRecordDir.path) {
            do {
                try FileManager.default.createDirectory(at: kairumoRecordDir, withIntermediateDirectories: true, attributes: nil)
                print("📁 成功建立錄音目錄: \(kairumoRecordDir.path)")
            } catch {
                print("⚠️ 建立 Kairumo Record 目錄失敗: \(error)")
            }
        }
        return kairumoRecordDir
    }

    private override init() {
        super.init()
        _ = recordingsDirectory // 啟動時自動檢查並建立「Kairumo Record」資料夾
    }

    /// 在「檔案」／Finder 中開啟「Kairumo Record」資料夾。
    ///
    /// # iOS 這條路有兩個前提，少一個都會安靜地跑錯地方
    ///
    /// 1. `Info.plist` 要有 `UIFileSharingEnabled` —— 沒有的話，App 的
    ///    Documents 根本不會出現在「檔案」App 裡，`shareddocuments://`
    ///    沒有東西可以導航到，「檔案」只會停在它上次待的地方。
    ///    **URL 仍然「開成功」**，所以不會有任何錯誤可以看。
    /// 2. 目標資料夾**必須已經存在**。指向一個不存在的路徑時，
    ///    「檔案」一樣會落到別的地方 —— 使用者看到的還是「開錯資料夾」。
    ///    第一次啟動後還沒錄過音就是這個狀態。
    public func openRecordingsFolderInFinder() {
        // 先確保它存在（getter 本身會建立）。
        let folderUrl = recordingsDirectory
        #if targetEnvironment(macCatalyst) || os(macOS)
        if let wsClass = NSClassFromString("NSWorkspace") as? NSObjectProtocol,
           let shared = wsClass.perform(NSSelectorFromString("sharedWorkspace"))?.takeUnretainedValue() {
            _ = shared.perform(NSSelectorFromString("openURL:"), with: folderUrl)
            return
        }
        #else
        // 標準化路徑：`/var/...` 是 `/private/var/...` 的符號連結，
        // 而「檔案」認的是後者。不解析的話會導航失敗。
        let resolved = folderUrl.resolvingSymlinksInPath()
        var components = URLComponents(url: resolved, resolvingAgainstBaseURL: false)
        components?.scheme = "shareddocuments"
        if let filesAppUrl = components?.url {
            UIApplication.shared.open(filesAppUrl, options: [:]) { opened in
                guard !opened else { return }
                // 退回開 Documents 根目錄：至少落在這個 App 自己的區域裡，
                // 而不是「檔案」上次待的某個不相干的地方。
                var root = URLComponents(
                    url: self.recordingsDirectory.deletingLastPathComponent()
                        .resolvingSymlinksInPath(),
                    resolvingAgainstBaseURL: false)
                root?.scheme = "shareddocuments"
                if let rootUrl = root?.url {
                    UIApplication.shared.open(rootUrl, options: [:], completionHandler: nil)
                }
            }
            return
        }
        #endif
        UIApplication.shared.open(folderUrl, options: [:], completionHandler: nil)
    }

    /// 自動引導使用者開啟系統隱私與安全性設定頁面（自動化權限流程）
    public func openSystemSettings() {
        showPermissionAlert = false
        #if targetEnvironment(macCatalyst) || os(macOS)
        // Mac Catalyst: 優先嘗試開啟系統設定中的「麥克風」隱私頁面
        if let micPrefUrl = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            if let wsClass = NSClassFromString("NSWorkspace") as? NSObjectProtocol,
               let shared = wsClass.perform(NSSelectorFromString("sharedWorkspace"))?.takeUnretainedValue() {
                _ = shared.perform(NSSelectorFromString("openURL:"), with: micPrefUrl)
                return
            }
        }
        #endif

        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl, options: [:], completionHandler: nil)
        }
    }

    // MARK: - 錄音控制

    /// 請求麥克風權限並啟動錄音
    public func startRecording(title: String? = nil) async -> Bool {
        #if targetEnvironment(macCatalyst)
        let authStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        let permissionGranted: Bool
        if authStatus == .authorized {
            permissionGranted = true
        } else if authStatus == .notDetermined {
            permissionGranted = await AVCaptureDevice.requestAccess(for: .audio)
        } else {
            permissionGranted = false
        }
        guard permissionGranted else {
            print("[AudioRecorderManager] Mac Catalyst 麥克風權限被拒絕")
            self.showPermissionAlert = true
            return false
        }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
        } catch {
            print("[AudioRecorderManager] Mac Catalyst 音訊 Session 設定警告: \(error)")
        }
        #elseif os(iOS)
        let session = AVAudioSession.sharedInstance()
        let permissionGranted: Bool
        if #available(iOS 17.0, *) {
            permissionGranted = await AVAudioApplication.requestRecordPermission()
        } else {
            permissionGranted = await withCheckedContinuation { continuation in
                session.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }

        guard permissionGranted else {
            print("[AudioRecorderManager] 麥克風權限被拒絕，自動啟動設定引導流程")
            self.showPermissionAlert = true
            return false
        }

        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch {
            print("[AudioRecorderManager] 音訊 Session 設定失敗: \(error)")
        }
        #elseif os(macOS)
        let permissionGranted: Bool
        if #available(macOS 10.14, *) {
            permissionGranted = await AVCaptureDevice.requestAccess(for: .audio)
        } else {
            permissionGranted = true
        }
        guard permissionGranted else {
            print("[AudioRecorderManager] macOS 麥克風權限被拒絕")
            self.showPermissionAlert = true
            return false
        }
        #endif

        let fileId = UUID().uuidString
        let fileUrl = recordingsDirectory.appendingPathComponent("\(fileId).m4a")
        self.currentAudioUrl = fileUrl

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            let recorder = try AVAudioRecorder(url: fileUrl, settings: settings)
            recorder.delegate = self
            recorder.isMeteringEnabled = true
            let prepared = recorder.prepareToRecord()
            print("[AudioRecorderManager] prepareToRecord: \(prepared)")
            guard recorder.record() else {
                print("[AudioRecorderManager] recorder.record() 回傳 false")
                return false
            }

            self.audioRecorder = recorder
            self.status = .recording
            self.elapsedSeconds = 0

            self.timer?.invalidate()
            self.timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self, let rec = self.audioRecorder, rec.isRecording else { return }
                rec.updateMeters()
                self.elapsedSeconds = rec.currentTime
                let power = rec.averagePower(forChannel: 0)
                let normalized = max(0.12, CGFloat((power + 60.0) / 60.0))
                var current = self.audioLevels
                current.removeFirst()
                current.append(normalized)
                self.audioLevels = current
            }
            return true
        } catch {
            print("[AudioRecorderManager] 建立錄音器失敗: \(error)")
            return false
        }
    }

    /// 暫停當前錄音
    public func pauseRecording() {
        guard let recorder = audioRecorder, status == .recording else { return }
        recorder.pause()
        status = .paused
        timer?.invalidate()
        timer = nil
    }

    /// 恢復繼續錄音
    public func resumeRecording() {
        guard let recorder = audioRecorder, status == .paused else { return }
        guard recorder.record() else { return }
        status = .recording

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let rec = self.audioRecorder, rec.isRecording else { return }
            rec.updateMeters()
            self.elapsedSeconds = rec.currentTime
            let power = rec.averagePower(forChannel: 0)
            let normalized = max(0.12, CGFloat((power + 60.0) / 60.0))
            var current = self.audioLevels
            current.removeFirst()
            current.append(normalized)
            self.audioLevels = current
        }
    }

    /// 停止錄音並回傳儲存的檔案 URL 及總時長（秒）
    public func stopRecording() -> (url: URL, duration: TimeInterval)? {
        guard let recorder = audioRecorder, status == .recording || status == .paused else { return nil }
        let duration = recorder.currentTime
        recorder.stop()
        timer?.invalidate()
        timer = nil
        status = .idle
        audioLevels = Array(repeating: 0.15, count: 20)

        guard let url = currentAudioUrl else { return nil }
        return (url, duration)
    }

    // MARK: - 播放控制

    /// 播放一段錄音。
    ///
    /// `.opus` 走核心解碼（`AVAudioPlayer` 播不動 Ogg-Opus），
    /// 其餘（遷移完成前殘留的 `.m4a`）走 AVFoundation。
    public func playAudio(url: URL, recordingId: String) {
        if playingRecordingId == recordingId && isPlaying {
            pauseAudio()
            return
        }

        stopPlayback()

        if url.pathExtension.lowercased() == "opus" {
            playOpus(url: url, recordingId: recordingId)
            return
        }

        do {
            #if os(iOS) || targetEnvironment(macCatalyst)
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            #endif

            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.prepareToPlay()
            player.play()

            self.audioPlayer = player
            self.isPlaying = true
            self.playingRecordingId = recordingId

            self.playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self, let p = self.audioPlayer else { return }
                if p.duration > 0 {
                    self.playbackProgress = p.currentTime / p.duration
                }
            }
        } catch {
            print("[AudioRecorderManager] 播放音訊失敗: \(error)")
        }
    }

    /// Ogg-Opus 的播放路徑（R3）。
    private func playOpus(url: URL, recordingId: String) {
        guard let player = opusPlayer ?? OpusAudioPlayer() else {
            print("[AudioRecorderManager] 建不出 Opus 播放器")
            return
        }
        opusPlayer = player
        player.onFinished = { [weak self] in
            self?.stopPlayback()
        }
        guard player.play(url: url) else {
            print("[AudioRecorderManager] 打不開錄音：\(url.lastPathComponent)")
            return
        }
        isPlaying = true
        playingRecordingId = recordingId
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let p = self.opusPlayer else { return }
                self.playbackProgress = p.progress
            }
        }
    }

    public func pauseAudio() {
        audioPlayer?.pause()
        opusPlayer?.pause()
        isPlaying = false
    }

    public func seek(to time: TimeInterval) {
        if let opus = opusPlayer, opus.duration > 0 {
            opus.seek(to: time)
            playbackProgress = opus.progress
            return
        }
        guard let player = audioPlayer else { return }
        player.currentTime = max(0, min(time, player.duration))
        playbackProgress = player.currentTime / player.duration
    }

    public func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        opusPlayer?.stop()
        opusPlayer = nil
        playbackTimer?.invalidate()
        playbackTimer = nil
        isPlaying = false
        playingRecordingId = nil
        playbackProgress = 0.0
    }

    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        stopPlayback()
    }
}
