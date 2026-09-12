import Foundation
import UIKit

/// 掌拒與輸入分流的整合範例（S-36）。
///
/// 展示 UIKit 的觸控事件如何餵進 core 的仲裁器，以及
/// **`retract` 為什麼不能忽略**。
final class ArbitratedInkView: UIView {

    private let arbiter = InkArbiter()
    private let session: PadnoteSession
    private let pageId: String

    /// 進行中的筆畫：指標 id → 已收集的取樣點。
    private var inProgress: [UInt64: [StrokePoint]] = [:]
    /// 已寫入 core 的筆畫：指標 id → 筆畫 id。用來執行收回。
    private var committed: [UInt64: String] = [:]

    init(session: PadnoteSession, pageId: String, frame: CGRect) {
        self.session = session
        self.pageId = pageId
        super.init(frame: frame)

        // 使用者可在設定中改成「僅筆書寫」—— 掌拒最可靠的模式。
        arbiter.setMode(mode: .penAndFinger)
        arbiter.setPressureAction(action: .strokeWidth)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) 未實作") }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        process(touches, event: event, phase: .began)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        process(touches, event: event, phase: .moved)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        process(touches, event: event, phase: .ended)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        process(touches, event: event, phase: .cancelled)
    }

    private func process(_ touches: Set<UITouch>, event: UIEvent?, phase: FfiPhase) {
        for touch in touches {
            let decision = arbiter.handle(event: pointerEvent(from: touch, phase: phase))

            // --- 這一段不能省略 ---
            // 使用者的自然動作是手掌先碰螢幕、筆才落下。手掌那一筆此時
            // 已經在畫了，必須收回。不處理的話掌拒只擋得住一半的情況。
            for id in decision.retract {
                retract(pointerId: id)
            }

            switch decision.verdict {
            case .draw:
                collect(touch, event: event, phase: phase)
            case .gesture:
                // 交給 UIScrollView / pinch recognizer
                break
            case .reject:
                // 手掌 —— 丟棄這個指標累積的一切
                inProgress[UInt64(touch.hashValue)] = nil
            }
        }
    }

    /// 把 UIKit 的觸控轉成 core 的統一事件。
    private func pointerEvent(from touch: UITouch, phase: FfiPhase) -> FfiPointerEvent {
        let p = touch.preciseLocation(in: self)
        return FfiPointerEvent(
            id: UInt64(touch.hashValue),
            kind: kind(of: touch),
            phase: phase,
            x: Float(p.x),
            y: Float(p.y),
            pressure: touch.type == .pencil
                ? Float(touch.force / max(touch.maximumPossibleForce, 1))
                : 0.5,
            // 平台提供接觸面積時填實際值；不提供填 0（表示未知，
            // core 不會因此判成手掌）。
            contactRadius: Float(touch.majorRadius),
            timestampUs: UInt64(touch.timestamp * 1_000_000)
        )
    }

    private func kind(of touch: UITouch) -> FfiPointerKind {
        switch touch.type {
        case .pencil:
            // Apple Pencil 的橡皮擦端
            return touch.perpendicularForce > 0 ? .eraser : .pen
        case .direct: return .finger
        case .indirectPointer: return .mouse
        default: return .unknown
        }
    }

    private func collect(_ touch: UITouch, event: UIEvent?, phase: FfiPhase) {
        let id = UInt64(touch.hashValue)

        // coalesced 才拿得到完整取樣。120Hz Pencil 在 60Hz 畫面上每幀有 2+ 個點。
        // ⚠️ 絕不放 predictedTouches —— 那是視覺補償不是真實輸入。
        for t in event?.coalescedTouches(for: touch) ?? [touch] {
            let p = t.preciseLocation(in: self)
            let pressure = t.type == .pencil
                ? Float(t.force / max(t.maximumPossibleForce, 1))
                : 0.5
            inProgress[id, default: []].append(
                StrokePoint(
                    x: Float(p.x), y: Float(p.y),
                    pressure: pressure,
                    tilt: Float(t.altitudeAngle),
                    azimuth: Float(t.azimuthAngle(in: self)),
                    dtUs: 8_333
                )
            )
        }

        guard phase == .ended, let points = inProgress.removeValue(forKey: id), !points.isEmpty
        else { return }

        if let strokeId = try? session.addStroke(
            pageId: pageId,
            tool: .fountainPen,
            colorRgba: Data([0, 0, 0, 255]),
            baseWidth: 2.0,
            points: points
        ) {
            committed[id] = strokeId
        }
    }

    /// 收回被判定為手掌的筆畫。
    private func retract(pointerId: UInt64) {
        inProgress[pointerId] = nil
        if let strokeId = committed.removeValue(forKey: pointerId) {
            try? session.eraseStroke(pageId: pageId, strokeId: strokeId)
        }
        setNeedsDisplay()
    }
}

/// 物件對齊與吸附的用法（S-38）。
enum ObjectEditingUsage {

    /// 拖曳物件時每一幀呼叫，取得吸附建議。
    static func snapWhileDragging(
        moving: CGRect,
        others: [CGRect],
        gridSize: Float
    ) -> (delta: CGVector, guides: (vertical: Bool, horizontal: Bool)) {
        let result = snapObject(
            moving: rect(moving),
            targets: others.map(rect),
            grid: gridSize,
            threshold: 8.0
        )
        return (
            CGVector(dx: CGFloat(result.dx), dy: CGFloat(result.dy)),
            (result.snappedX, result.snappedY)
        )
    }

    /// 對齊選取的物件。基準是整體外框，與選取順序無關。
    static func alignSelection(_ bounds: [CGRect], to how: FfiAlignment) -> [CGVector] {
        alignObjects(bounds: bounds.map(rect), how: how)
            .map { CGVector(dx: CGFloat($0.dx), dy: CGFloat($0.dy)) }
    }

    private static func rect(_ r: CGRect) -> FfiRect {
        FfiRect(
            minX: Float(r.minX), minY: Float(r.minY),
            maxX: Float(r.maxX), maxY: Float(r.maxY)
        )
    }
}

/// 匯入外部文件前，先讓使用者知道會失去什麼（S-41）。
enum ImportUsage {

    /// 顯示匯入前的確認資訊。
    static func describeImport(extension ext: String) -> String? {
        guard let info = formatInfo(extension: ext) else { return nil }

        var lines = [info.isEditable ? "匯入後可直接編輯" : "匯入後僅能預覽"]
        if !info.limitations.isEmpty {
            lines.append("以下項目不會保留：" + info.limitations.joined(separator: "、"))
        }
        lines.append("原始檔會一併保存，隨時可以取回。")
        return lines.joined(separator: "\n")
    }
}
