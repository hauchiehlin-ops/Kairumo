import UIKit
import Metal
import QuartzCore

/// M0 / Spike S1：低延遲墨跡視圖。
///
/// Go 門檻（`docs/roadmap.md`）：**motion-to-photon ≤ 9ms**，連續書寫 10 分鐘無掉幀。
///
/// 延遲預算（`docs/architecture.md` §5.1）：
/// ```
/// 觸控事件到達   ~1ms
/// 幾何處理       ~1ms
/// GPU 提交       ~2ms
/// 合成與顯示     ~4ms
/// ─────────────────
/// 合計           ~8ms
/// ```
///
/// 三個延遲關鍵手段，缺一不可：
/// 1. `presentsWithTransaction = false` + 手動 `present()` —— 繞過 CoreAnimation 交易，
///    不等下一次 commit。
/// 2. **預測筆跡**（`predictedTouches`）—— 補足 1–2 幀的視覺延遲，這是「筆黏在螢幕上」
///    的錯覺來源。
/// 3. **雙層渲染** —— 已完成筆畫快取為 GPU texture，每幀只重繪進行中的那一筆。
final class LowLatencyInkView: UIView {

    override class var layerClass: AnyClass { CAMetalLayer.self }

    private var metalLayer: CAMetalLayer { layer as! CAMetalLayer }

    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let renderer: InkRenderer

    /// 進行中的筆畫（已確定的點）。
    private var activePoints: [InkSample] = []
    /// 預測點：每幀丟棄重算，**永不寫入持久化資料**。
    private var predictedPoints: [InkSample] = []

    /// 落筆的 host time，用於換算 `started_at_us`（對齊 format-spec §4 時間軸）。
    private var strokeStartHostTime: CFTimeInterval = 0

    private let latencyProbe = LatencyProbe()

    override init(frame: CGRect) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else {
            fatalError("此裝置不支援 Metal")
        }
        self.device = device
        self.queue = queue
        self.renderer = InkRenderer(device: device)
        super.init(frame: frame)
        configureLayer()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) 未實作") }

    private func configureLayer() {
        metalLayer.device = device
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = true
        metalLayer.isOpaque = true

        // 關鍵一：不透過 CoreAnimation 交易提交，改為手動 present。
        // 設為 true 反而會等到交易 commit，多出一整幀。
        metalLayer.presentsWithTransaction = false

        // 最高更新率。ProMotion 的 120Hz 讓每幀預算從 8.3ms 降到 4.2ms。
        metalLayer.maximumDrawableCount = 3

        isMultipleTouchEnabled = false
        isOpaque = true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let scale = window?.screen.nativeScale ?? UIScreen.main.nativeScale
        metalLayer.contentsScale = scale
        metalLayer.drawableSize = CGSize(width: bounds.width * scale,
                                         height: bounds.height * scale)
        renderer.resize(to: metalLayer.drawableSize)
    }

    // MARK: - 觸控

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        strokeStartHostTime = touch.timestamp
        activePoints.removeAll(keepingCapacity: true)
        predictedPoints.removeAll(keepingCapacity: true)
        append(touch: touch, event: event)
        renderIncremental()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        append(touch: touch, event: event)
        renderIncremental()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        append(touch: touch, event: event)

        // 預測點是視覺補償，不是真實輸入 —— 落筆結束時必須丟棄，
        // 否則會把不存在的取樣寫進 .padnote（format-spec §5.4）。
        predictedPoints.removeAll()

        renderer.commitStroke(activePoints)
        activePoints.removeAll(keepingCapacity: true)
        renderFull()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        activePoints.removeAll()
        predictedPoints.removeAll()
        renderFull()
    }

    /// 收集 coalesced（本幀累積的完整取樣）與 predicted（外推）觸控。
    ///
    /// **只讀 `touches.first` 會丟點**：120Hz Apple Pencil 在 60Hz 畫面上，
    /// 每幀有 2 個以上取樣，coalesced 才拿得到全部。
    private func append(touch: UITouch, event: UIEvent?) {
        let coalesced = event?.coalescedTouches(for: touch) ?? [touch]
        for t in coalesced {
            activePoints.append(sample(from: t))
        }

        predictedPoints = (event?.predictedTouches(for: touch) ?? []).map(sample(from:))
    }

    private func sample(from touch: UITouch) -> InkSample {
        let p = touch.preciseLocation(in: self)
        return InkSample(
            x: Float(p.x),
            y: Float(p.y),
            // 非 Pencil 輸入沒有壓感，回退為固定值而非 0。
            pressure: touch.type == .pencil
                ? Float(touch.force / max(touch.maximumPossibleForce, 1))
                : 0.5,
            altitude: Float(touch.altitudeAngle),
            azimuth: Float(touch.azimuthAngle(in: self)),
            // 相對落筆時刻的微秒偏移 → 對應 InkPoint.t_us
            offsetMicros: UInt32(max(0, (touch.timestamp - strokeStartHostTime) * 1_000_000))
        )
    }

    // MARK: - 渲染

    /// 每幀只重繪進行中的筆畫，已完成的部分來自快取 texture。
    private func renderIncremental() {
        draw(active: activePoints + predictedPoints, redrawCommitted: false)
    }

    private func renderFull() {
        draw(active: [], redrawCommitted: true)
    }

    private func draw(active: [InkSample], redrawCommitted: Bool) {
        guard let drawable = metalLayer.nextDrawable(),
              let commandBuffer = queue.makeCommandBuffer() else { return }

        latencyProbe.frameBegan(inputTimestamp: active.last?.offsetMicros)

        renderer.encode(into: commandBuffer,
                        drawable: drawable,
                        activeStroke: active,
                        redrawCommitted: redrawCommitted)

        // 關鍵二：手動 present 而非 `commandBuffer.present(drawable)` 後才 commit，
        // 讓 GPU 完成即上屏。
        commandBuffer.addScheduledHandler { _ in drawable.present() }
        commandBuffer.addCompletedHandler { [weak self] buffer in
            self?.latencyProbe.frameCompleted(gpuEnd: buffer.gpuEndTime)
        }
        commandBuffer.commit()
    }

    /// 供 S1 量測使用。
    var latencyStatistics: LatencyProbe.Statistics { latencyProbe.statistics }
}

/// 單一取樣點。欄位與 `padnote-ink::InkPoint` 一一對應。
struct InkSample {
    var x: Float
    var y: Float
    var pressure: Float
    var altitude: Float
    var azimuth: Float
    var offsetMicros: UInt32
}
