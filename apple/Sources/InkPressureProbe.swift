//
//  InkPressureProbe.swift
//  Kairumo
//
//  手寫板壓力測試（設定頁的「輸入診斷」）。
//
//  為什麼要有它：外接手寫板接到 Mac 上，系統會不會把壓力交給 App，**從程式碼看不出來** ——
//  取決於 Mac Catalyst 與手寫板驅動。原本的診斷只在「啟用」時記錄、而且沒有任何開關可以啟用，
//  只看得到最後一個觸點（筆一抬起壓力就歸零）。這裡改成獨立的測試區：使用者直接在上面寫，
//  數字即時更新，並記住看過的最大壓力，寫完還看得到結論。

import SwiftUI
import UIKit

/// 一次測試累積下來的結果。純資料，可以不啟動畫面就測。
struct PressureProbe: Equatable {
    /// 最近一個取樣點的來源（finger / pencil / pointer…）。
    var lastInput: String = "—"
    /// 最近一個取樣點的壓力（0–1）。
    var lastPressure: Double = 0
    /// 看過的最大壓力（0–1）。
    var peakPressure: Double = 0
    var pressureSamples: Int = 0
    var totalSamples: Int = 0

    /// 這個輸入有沒有回報過壓力。**要有大於 0 的實際壓力值**才算：
    /// 只有 `maximumPossibleForce > 0` 但每個取樣點都是 0 的裝置，對壓力感應沒有用。
    var reportsPressure: Bool { pressureSamples > 0 }

    mutating func record(input: String, force: Double, maximumPossibleForce: Double) {
        totalSamples += 1
        lastInput = input
        guard maximumPossibleForce > 0, force > 0 else {
            lastPressure = 0
            return
        }
        let normalized = min(1, force / maximumPossibleForce)
        lastPressure = normalized
        peakPressure = max(peakPressure, normalized)
        pressureSamples += 1
    }
}

/// 接觸控的測試板。每個取樣點（含 coalesced）都交給 `onSample`。
final class InkProbePadView: UIView {
    var onSample: ((_ input: String, _ force: Double, _ maximumPossibleForce: Double) -> Void)?
    /// 板上最近的軌跡，讓人看得出自己寫到哪裡。
    private var path = UIBezierPath()
    private let shape = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = false
        backgroundColor = UIColor.secondarySystemFill
        layer.cornerRadius = 10
        clipsToBounds = true
        shape.strokeColor = UIColor.label.cgColor
        shape.fillColor = nil
        shape.lineWidth = 2
        shape.lineCap = .round
        layer.addSublayer(shape)
        accessibilityIdentifier = "diag.probe.pad"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func report(_ touch: UITouch, _ event: UIEvent?) {
        let samples = event?.coalescedTouches(for: touch) ?? [touch]
        for sample in samples {
            onSample?(Self.describe(sample.type), Double(sample.force), Double(sample.maximumPossibleForce))
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        path = UIBezierPath()
        path.move(to: touch.location(in: self))
        shape.path = path.cgPath
        report(touch, event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        path.addLine(to: touch.location(in: self))
        shape.path = path.cgPath
        report(touch, event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        report(touch, event)
    }

    private static func describe(_ type: UITouch.TouchType) -> String {
        switch type {
        case .direct: return "finger"
        case .pencil: return "pencil"
        case .indirect: return "indirect"
        case .indirectPointer: return "pointer"
        @unknown default: return "unknown"
        }
    }
}

private struct InkProbePad: UIViewRepresentable {
    var onSample: (String, Double, Double) -> Void

    func makeUIView(context _: Context) -> InkProbePadView {
        let view = InkProbePadView()
        view.onSample = onSample
        return view
    }

    func updateUIView(_ view: InkProbePadView, context _: Context) {
        view.onSample = onSample
    }
}

/// 設定頁的測試區。
struct InkPressureProbeSection: View {
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @State private var probe = PressureProbe()

    var body: some View {
        Section(localizationManager.localized("diag_probe_title")) {
            Text(localizationManager.localized("diag_probe_hint"))
                .font(.caption)
                .foregroundColor(.secondary)
            InkProbePad { input, force, maximum in
                probe.record(input: input, force: force, maximumPossibleForce: maximum)
            }
            .frame(height: 160)

            row("diag_input_device", probe.lastInput)
            row("diag_pressure", String(format: "%.2f", probe.lastPressure))
            row("diag_peak_pressure", String(format: "%.2f", probe.peakPressure))
            row("diag_probe_samples", "\(probe.pressureSamples) / \(probe.totalSamples)")

            Text(verdict)
                .font(.footnote)
                .foregroundColor(probe.totalSamples == 0 ? .secondary : (probe.reportsPressure ? .green : .orange))
                .accessibilityIdentifier("diag.probe.verdict")

            Button(localizationManager.localized("diag_probe_reset")) { probe = PressureProbe() }
        }
    }

    private var verdict: String {
        if probe.totalSamples == 0 { return localizationManager.localized("diag_probe_waiting") }
        return localizationManager.localized(
            probe.reportsPressure ? "diag_probe_pressure_yes" : "diag_probe_pressure_no")
    }

    private func row(_ key: String, _ value: String) -> some View {
        HStack {
            Text(localizationManager.localized(key))
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
                .font(.system(.body, design: .monospaced))
        }
    }
}
