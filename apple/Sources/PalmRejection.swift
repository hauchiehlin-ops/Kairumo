//
//  PalmRejection.swift
//  Kairumo
//
//  Apple 端的掌拒與筆畫收回（工作項 S-45）。
//
//  # 原本的狀況
//
//  畫布在手寫模式下是 `drawingPolicy = .anyInput` —— 手指能畫，代價是
//  **手掌也能畫**。沒有 Apple Pencil 的人需要用手指寫字，所以不能單純改成
//  `.pencilOnly`；但有筆的人把手放在螢幕上就會留下一道莫名其妙的線。
//
//  # 解法分成兩層
//
//  1. **系統層**：偵測到觸控筆就切成 `.pencilOnly`。PencilKit 的掌拒做在
//     系統層，比我們在應用層能做的任何判斷都可靠 —— 有現成的就不要自己寫。
//  2. **收回**：切換是有延遲的。使用者的自然動作是手掌先碰螢幕、筆才落下，
//     那一瞬間手掌已經畫出東西了。核心的 `InkArbiter` 會在筆落下時回報
//     `retract`，這裡依它把剛畫出來的筆畫收回。
//
//  掌拒的判定規則走核心（`padnote-input`），與 Android 同一份 —— 不是各寫
//  一套「差不多」的邏輯。
//

import Foundation
import PencilKit
import UIKit

/// 依核心的仲裁結果，決定畫布的輸入政策並收回誤觸的筆畫。
@MainActor
final class PalmRejectionCoordinator {

    /// 使用者的偏好。
    enum Mode {
        /// 偵測到觸控筆就自動切成僅限筆。**預設**。
        case automatic
        /// 永遠只有筆能寫（掌拒最可靠）。
        case penOnly
        /// 手指也能寫，不做掌拒（沒有筆、也不介意的人）。
        case anyInput
    }

    var mode: Mode = .automatic

    private let arbiter = InkArbiter()

    init() {
        applyStoredThresholds()
    }

    /// 把使用者調過的掌拒門檻套進仲裁器（工作項 S-101）。
    ///
    /// 沒有自訂過時用核心的預設值 —— 範圍與預設都來自
    /// `palmThresholdLimits()`，兩個平台同一組數字。各抄一份的話，
    /// 兩邊的滑桿範圍遲早不一樣，而使用者不會知道為什麼同一個數字在
    /// 另一台裝置上效果不同。
    func applyStoredThresholds() {
        let limits = palmThresholdLimits()
        let radius = PalmThresholdStore.radius ?? (drawingPolicy() == .pencilOnly ? limits.defaultRadiusDp : limits.fingerModeRadiusDp)
        arbiter.setPalmThresholds(
            palmRadius: radius,
            retractWindowMs: PalmThresholdStore.retractMs ?? limits.defaultRetractMs)
    }
    /// 最後一次看到觸控筆的時間。
    private var lastPencilAt: Date?

    /// 看到觸控筆之後多久內仍視為「正在用筆」。
    ///
    /// 使用者會停下來想事情。太短的話一停筆就切回 `.anyInput`，
    /// 手掌馬上又畫得出東西；太長的話放下筆改用手指要等很久。
    static let pencilGrace: TimeInterval = 20

    /// 目前該用哪個輸入政策。
    func drawingPolicy(now: Date = Date()) -> PKCanvasViewDrawingPolicy {
        switch mode {
        case .penOnly: return .pencilOnly
        case .anyInput: return .anyInput
        case .automatic:
            guard let last = lastPencilAt else { return .anyInput }
            return now.timeIntervalSince(last) < Self.pencilGrace ? .pencilOnly : .anyInput
        }
    }

    /// 收到一個觸控事件。回傳是否需要把先前的筆畫收回。
    ///
    /// `retract` 一定要處理：使用者的自然動作是手掌先碰螢幕、筆才落下，
    /// 此時手掌那一筆已經畫出來了。不收回的話，掌拒只擋得住「筆之後」的
    /// 誤觸 —— 擋不住最常見的那一種。
    ///
    /// **絕不收回真實筆跡**：若當前政策為 `.pencilOnly` 或最近正在用 Apple Pencil，
    /// 畫布上的所有筆畫皆為真實筆跡（PencilKit 系統層已做硬體掌拒）。
    /// 連續快速書寫或筆勢加重時若觸發收回，會把 0.2~0.5 秒前剛寫完的字抹掉造成「斷線」。
    @discardableResult
    func observe(touch: UITouch, now: Date = Date()) -> Bool {
        let isUsingPencil = (lastPencilAt != nil && now.timeIntervalSince(lastPencilAt!) < Self.pencilGrace)
        if touch.type == .pencil {
            lastPencilAt = now
        }
        let decision = arbiter.handle(event: Self.event(from: touch, now: now))

        if drawingPolicy(now: now) == .pencilOnly || isUsingPencil || touch.type == .pencil {
            return false
        }
        return !decision.retract.isEmpty
    }

    /// 把時間窗內畫出來的筆畫收回。
    ///
    /// 用時間而不是指標 id：PencilKit 不告訴我們某一筆畫是哪根手指畫的，
    /// 所以只能依「筆落下前那一小段時間內完成的筆畫」來判斷。時間窗與核心
    /// 仲裁器用的是同一個值。
    static func retracting(_ drawing: PKDrawing, landedAt: Date, window: TimeInterval = 0.5) -> PKDrawing {
        let cutoff = landedAt.addingTimeInterval(-window)
        let kept = drawing.strokes.filter { stroke in
            // 沒有 creationDate 的筆畫（例如從檔案讀回來的）一律保留 ——
            // 收回一筆不確定的筆畫，比留下一道誤觸的線嚴重得多。
            stroke.path.creationDate <= cutoff || stroke.path.creationDate > landedAt
        }
        return kept.count == drawing.strokes.count ? drawing : PKDrawing(strokes: kept)
    }

    func reset() {
        arbiter.reset()
        lastPencilAt = nil
    }

    // MARK: - 轉換

    /// `UITouch` → 核心的指標事件。
    static func event(from touch: UITouch, now: Date) -> FfiPointerEvent {
        let phase: FfiPhase
        switch touch.phase {
        case .began: phase = .began
        case .moved, .stationary: phase = .moved
        case .ended: phase = .ended
        case .cancelled: phase = .cancelled
        default: phase = .moved
        }

        let kind: FfiPointerKind
        switch touch.type {
        case .pencil: kind = .pen
        case .direct: kind = .finger
        case .indirectPointer: kind = .mouse
        default: kind = .unknown
        }

        // 接觸半徑：UITouch 的 majorRadius 已經是**點**（與核心的門檻同單位），
        // 不需要像 Android 那樣除以密度。
        return FfiPointerEvent(
            id: UInt64(UInt(bitPattern: ObjectIdentifier(touch).hashValue)),
            kind: kind,
            phase: phase,
            x: Float(touch.location(in: nil).x),
            y: Float(touch.location(in: nil).y),
            pressure: touch.maximumPossibleForce > 0
                ? Float(min(touch.force / touch.maximumPossibleForce, 1))
                : 0.5,
            contactRadius: Float(touch.majorRadius),
            timestampUs: UInt64(now.timeIntervalSince1970 * 1_000_000)
        )
    }
}

/// 「點選」順手畫下的墨點要收回。
///
/// 手寫模式下手指還能畫的時候（打開筆記本、Pencil 還沒用過），手指點物件、勾核取方塊、
/// 雙擊開文字框，PencilKit 會和點擊手勢同時收到這一下，於是紙上多一顆點。
///
/// 原本的判準是「最後一筆、renderBounds 小於 10pt、兩秒內」：粗筆點出來的點超過 10pt
/// 永遠收不掉，雙擊的兩顆只收得到一顆。這裡改看**筆路的取樣點**（與筆寬無關）
/// 與**這一筆何時結束**（點擊在抬起時成立，墨點也在那一刻結束）：
/// 稍早寫下的句號、i 上的點結束得早，不會被當成這一下的墨點。
enum TapDotRetraction {
    /// 取樣點的分布範圍上限（點）。點擊手勢容許的移動約 10~25pt（包含手指按壓擴散、滑鼠微幅抖動）。
    static let maxSpread: CGFloat = 32
    /// 墨點中心離點擊位置的上限（點）。
    static let maxDistance: CGFloat = 48
    /// 墨點結束時間要落在點擊成立前這段時間內（雙擊的第一下約早 0.35 秒）。
    static let endWindow: TimeInterval = 0.6
    /// 時鐘誤差的容許（墨點的結束時間可能比點擊成立稍晚記到）。
    static let endTolerance: TimeInterval = 0.20

    static func isTapDot(_ stroke: PKStroke, near location: CGPoint, tappedAt: Date) -> Bool {
        let path = stroke.path
        guard let first = path.first, let last = path.last else { return false }
        let began = path.creationDate
        guard began <= tappedAt else { return false }
        let ended = began.addingTimeInterval(last.timeOffset - first.timeOffset)
        guard ended >= tappedAt.addingTimeInterval(-endWindow),
              ended <= tappedAt.addingTimeInterval(endTolerance) else { return false }
        var minX = CGFloat.infinity, minY = CGFloat.infinity
        var maxX = -CGFloat.infinity, maxY = -CGFloat.infinity
        for point in path {
            let p = point.location.applying(stroke.transform)
            minX = min(minX, p.x); maxX = max(maxX, p.x)
            minY = min(minY, p.y); maxY = max(maxY, p.y)
        }
        guard maxX - minX <= maxSpread, maxY - minY <= maxSpread else { return false }
        return abs((minX + maxX) / 2 - location.x) <= maxDistance
            && abs((minY + maxY) / 2 - location.y) <= maxDistance
    }

    /// 從最後幾筆往回找，收回至多 `maxCount` 顆符合的墨點。沒有符合的就原封不動回傳。
    static func retracting(
        _ drawing: PKDrawing, near location: CGPoint, tappedAt: Date, maxCount: Int = 1
    ) -> PKDrawing {
        var strokes = drawing.strokes
        var removed = 0
        var index = strokes.count - 1
        let floor = max(0, strokes.count - 8)
        while index >= floor, removed < maxCount {
            if isTapDot(strokes[index], near: location, tappedAt: tappedAt) {
                strokes.remove(at: index)
                removed += 1
            }
            index -= 1
        }
        return removed == 0 ? drawing : PKDrawing(strokes: strokes)
    }
}
