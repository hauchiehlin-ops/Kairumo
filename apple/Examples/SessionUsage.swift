import Foundation

/// Rust core 的呼叫範例（工作項 S-12）。
///
/// 重點示範功能 C1：**點一筆畫，跳回當時的錄音位置** —— 這是 Padnote 與
/// Goodnotes（沒有錄音）和 Granola（沒有手寫）的核心差異。
///
/// 型別來自 `apple/Generated/padnote_core.swift`，由
/// `scripts/generate-bindings.sh` 產生。
enum SessionUsage {

    /// 建立筆記本、錄音、寫字、然後跳回錄音位置。
    static func recordAndAnnotate(at path: String) throws {
        let session = try PadnoteSession.create(
            path: path,
            title: "線性代數 第三週",
            nowUnixMs: UInt64(Date().timeIntervalSince1970 * 1000)
        )

        guard let page = session.firstPageId() else { return }

        // 平台層負責推進時間軸。**必須用 monotonic clock**，
        // 不能用 wall clock —— 使用者調時區會讓時間軸倒退。
        var clock = MonotonicClock()

        session.advanceTime(notebookTimeUs: clock.elapsedMicros())
        let recording = try session.startRecording()
        print("錄音開始：\(recording)")

        // …使用者聽課、寫筆記…
        session.advanceTime(notebookTimeUs: clock.elapsedMicros())
        let strokeId = try session.addStroke(
            pageId: page,
            tool: .fountainPen,
            colorRgba: Data([0, 0, 0, 255]),
            baseWidth: 2.0,
            points: sampleStroke()
        )

        try session.addText(
            pageId: page,
            content: "特徵值與特徵向量",
            style: .heading2
        )

        session.advanceTime(notebookTimeUs: clock.elapsedMicros())
        _ = try session.stopRecording()

        // --- 功能 C1：點筆畫跳回錄音 ---
        let strokes = try session.visibleStrokes(pageId: page)
        if let stroke = strokes.first(where: { $0.id == strokeId }),
           let playback = session.playbackAt(notebookTimeUs: stroke.startedAtUs) {
            print("這一筆寫於錄音的 \(playback.offsetUs / 1_000_000) 秒處")
            print("音檔：\(playback.mediaPath)")
        }
    }

    /// 把 UIKit 的觸控取樣轉成 core 的格式。
    ///
    /// ⚠️ 只放 `coalescedTouches`，**絕不放 `predictedTouches`** ——
    /// 預測點是視覺補償，寫進資料會污染日後訓練 HWR 模型的樣本
    /// （format-spec §5.4）。
    static func sampleStroke() -> [StrokePoint] {
        [
            StrokePoint(x: 0, y: 0, pressure: 0.4, tilt: 0.5, azimuth: 1.2, dtUs: 0),
            StrokePoint(x: 12, y: 8, pressure: 0.7, tilt: 0.5, azimuth: 1.2, dtUs: 8_333),
            StrokePoint(x: 25, y: 20, pressure: 0.9, tilt: 0.5, azimuth: 1.2, dtUs: 8_333),
        ]
    }

    /// 啟動時回報各項權限與模型狀態，設定頁據此顯示按鈕。
    ///
    /// Apple Vision 是**純裝置端、免費、免申請 API key** 的系統框架，
    /// 因此手寫辨識直接回報 ready，不需要任何授權流程。
    static func reportCapabilities(_ session: PadnoteSession) {
        session.reportCapability(capability: "handwriting", state: "ready", sizeBytes: 0)

        switch AVAudioApplicationPermission.current {
        case .granted:
            session.reportCapability(capability: "microphone", state: "ready", sizeBytes: 0)
        case .denied:
            // 被拒絕後再彈系統對話框會被忽略，只能引導到設定。
            session.reportCapability(capability: "microphone", state: "denied", sizeBytes: 0)
        case .undetermined:
            session.reportCapability(capability: "microphone", state: "needs_permission", sizeBytes: 0)
        }

        if !ModelStore.hasAsrModel {
            session.reportCapability(
                capability: "asr_model",
                state: "needs_download",
                sizeBytes: 230_686_720
            )
        }

        // 設定頁直接畫這個列表
        for status in session.featureStatus() {
            print("\(status.feature)：\(status.ready ? "可用" : status.explanation)")
        }
    }
}

/// 單調時鐘。**不可用 `Date()`** —— 使用者調時區或系統校時會讓時間軸倒退，
/// 而筆記本時間軸的單調性是 C1／C4／A10／B6 的前提。
struct MonotonicClock {
    private let start = DispatchTime.now().uptimeNanoseconds

    func elapsedMicros() -> UInt64 {
        (DispatchTime.now().uptimeNanoseconds - start) / 1_000
    }
}

// --- 以下為示意用的占位型別，實作時換成真正的系統 API ---

enum AVAudioApplicationPermission {
    case granted, denied, undetermined
    static var current: Self { .undetermined }
}

enum ModelStore {
    static var hasAsrModel: Bool { false }
}
