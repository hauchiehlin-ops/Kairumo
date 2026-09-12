import Foundation
import QuartzCore

/// S1 的機上量測：記錄從觸控事件時間戳到 GPU 完成的耗時。
///
/// ⚠️ **這不是 motion-to-photon**。它量不到：
/// - 觸控面板取樣到事件送達 App 的硬體延遲
/// - GPU 完成到面板實際發光的顯示延遲
///
/// 因此它只能作為**迴歸偵測**（有沒有變慢），不能用來宣告達成 9ms 門檻。
/// 真正的 Go/No-Go 判定必須用高速攝影機，見 `apple/README.md`。
final class LatencyProbe {

    struct Statistics {
        var sampleCount: Int
        var meanMillis: Double
        var p95Millis: Double
        var maxMillis: Double
        /// 超過 1.5 幀（120Hz 下約 12.5ms）的幀數，代表掉幀。
        var droppedFrames: Int
    }

    private var frameStart: CFTimeInterval = 0
    private var durations: [Double] = []
    private let lock = NSLock()

    func frameBegan(inputTimestamp: UInt32?) {
        frameStart = CACurrentMediaTime()
    }

    func frameCompleted(gpuEnd: CFTimeInterval) {
        let elapsed = (gpuEnd - frameStart) * 1000.0
        guard elapsed.isFinite, elapsed >= 0 else { return }
        lock.lock()
        durations.append(elapsed)
        // 只保留最近 10 分鐘的樣本（120Hz × 600s）以符合 Go 門檻的觀察窗。
        if durations.count > 72_000 { durations.removeFirst(durations.count - 72_000) }
        lock.unlock()
    }

    var statistics: Statistics {
        lock.lock()
        defer { lock.unlock() }
        guard !durations.isEmpty else {
            return Statistics(sampleCount: 0, meanMillis: 0, p95Millis: 0,
                              maxMillis: 0, droppedFrames: 0)
        }
        let sorted = durations.sorted()
        let p95Index = min(sorted.count - 1, Int(Double(sorted.count) * 0.95))
        return Statistics(
            sampleCount: sorted.count,
            meanMillis: durations.reduce(0, +) / Double(durations.count),
            p95Millis: sorted[p95Index],
            maxMillis: sorted[sorted.count - 1],
            droppedFrames: durations.filter { $0 > 12.5 }.count
        )
    }

    func reset() {
        lock.lock()
        durations.removeAll(keepingCapacity: true)
        lock.unlock()
    }
}
