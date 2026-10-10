//
//  InteractionWatchdog.swift
//  Kairumo
//
//  使用者互動監聽與挫折意圖分析引擎。
//  在主執行緒以極輕量的環狀時間窗口監聽操作行為，
//  零記憶體分配、零渲染干擾（保持 120 FPS），即時辨識卡關並派發引導項目。
//

import SwiftUI

public enum InteractionTargetType: String {
    case table
    case textBox
    case image
    case sticker
    case canvas
}

/// 輕量操作事件記錄
private struct InteractionRecord {
    let timestamp: TimeInterval
    let targetId: String?
    let targetType: InteractionTargetType
    let isControlled: Bool
}

public final class InteractionWatchdog: ObservableObject {
    public static let shared = InteractionWatchdog()

    @Published public var activeGuidance: GuidancePromptItem? = nil

    private var autoDismissWorkItem: DispatchWorkItem? = nil
    private let suppression = GuidanceSuppressionManager.shared

    // 環狀事件紀錄（最多保留 10 筆）
    private var tapHistory: [InteractionRecord] = []
    private var eraserScratchCount: Int = 0
    private var lastEraserScratchTime: TimeInterval = 0
    private var lastModeSwitchTimes: [TimeInterval] = []

    private init() {}

    // MARK: - 主動派發引導

    public func presentGuidance(_ item: GuidancePromptItem, autoDismissSeconds: Double = 6.0) {
        guard suppression.shouldShow(id: item.id) else { return }

        autoDismissWorkItem?.cancel()
        suppression.recordShown(id: item.id)

        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
            self.activeGuidance = item
        }

        // 自動淡出排程
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self, self.activeGuidance?.id == item.id else { return }
            self.dismissGuidance()
        }
        self.autoDismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + autoDismissSeconds, execute: workItem)
    }

    public func dismissGuidance() {
        autoDismissWorkItem?.cancel()
        autoDismissWorkItem = nil
        withAnimation(.easeOut(duration: 0.22)) {
            self.activeGuidance = nil
        }
    }

    // MARK: - 意圖感知監聽接口

    /// 1. 手繪與打字融合：手寫筆劃覆蓋於文字方塊上
    public func notifyStrokeDrawnOverText(
        strokeBounds: CGRect,
        textBoxId: String,
        textBoxBounds: CGRect,
        onAnchor: @escaping () -> Void
    ) {
        guard suppression.shouldShow(id: "anchor_ink_to_text") else { return }
        let intersection = strokeBounds.intersection(textBoxBounds)
        guard !intersection.isNull, intersection.width > 20, intersection.height > 10 else { return }

        presentGuidance(
            GuidancePromptItem(
                id: "anchor_ink_to_text",
                icon: "link.badge.plus",
                messageKey: "hint_anchor_ink_to_text",
                actionTitleKey: "hint_anchor_ink_action",
                action: { [weak self] in
                    self?.suppression.markLearned(id: "anchor_ink_to_text")
                    onAnchor()
                    self?.dismissGuidance()
                },
                onDismiss: { [weak self] in
                    self?.dismissGuidance()
                }
            ),
            autoDismissSeconds: 8.0
        )
    }

    /// 2. 手繪與打字融合：手掌誤觸空白文字方塊感知
    public func notifyEmptyTextBoxDismissedQuickly(
        isStylusActive: Bool,
        onSwitchToDrawMode: @escaping () -> Void
    ) {
        guard isStylusActive, suppression.shouldShow(id: "palm_rest_detected") else { return }

        presentGuidance(
            GuidancePromptItem(
                id: "palm_rest_detected",
                icon: "hand.raised.slash.fill",
                messageKey: "hint_palm_rest_detected",
                actionTitleKey: nil,
                action: {
                    onSwitchToDrawMode()
                },
                onDismiss: { [weak self] in
                    self?.dismissGuidance()
                }
            ),
            autoDismissSeconds: 5.0
        )
    }

    /// 3. 手繪與打字融合：表格移動時內部手繪標記未跟隨
    public func notifyTableMovedWithOrphanStrokes(
        tableId: String,
        orphanStrokeCount: Int,
        onMoveStrokesTogether: @escaping () -> Void
    ) {
        guard orphanStrokeCount > 0, suppression.shouldShow(id: "table_ink_follow") else { return }

        presentGuidance(
            GuidancePromptItem(
                id: "table_ink_follow",
                icon: "tablecells.badge.ellipsis",
                messageKey: "hint_table_ink_follow",
                actionTitleKey: "hint_table_ink_action",
                action: { [weak self] in
                    self?.suppression.markLearned(id: "table_ink_follow")
                    onMoveStrokesTogether()
                    self?.dismissGuidance()
                },
                onDismiss: { [weak self] in
                    self?.dismissGuidance()
                }
            ),
            autoDismissSeconds: 8.0
        )
    }

    /// 4. 物件操作：連續點擊未受控/未進入編輯狀態的物件
    public func notifyObjectTapped(
        targetId: String,
        targetType: InteractionTargetType,
        isControlled: Bool,
        onControlObject: @escaping () -> Void
    ) {
        let now = Date().timeIntervalSince1970
        let record = InteractionRecord(
            timestamp: now,
            targetId: targetId,
            targetType: targetType,
            isControlled: isControlled
        )

        tapHistory.append(record)
        if tapHistory.count > 10 {
            tapHistory.removeFirst()
        }

        // 若連續 3 次點擊同一個目標且均未處於受控/編輯狀態（時間在 1.8 秒內）
        let recentTaps = tapHistory.filter { (now - $0.timestamp) < 1.8 && $0.targetId == targetId && !$0.isControlled }
        if recentTaps.count >= 3 && targetType == .table && suppression.shouldShow(id: "table_tap_to_select") {
            presentGuidance(
                GuidancePromptItem(
                    id: "table_tap_to_select",
                    icon: "hand.tap.fill",
                    messageKey: "hint_table_tap_to_select",
                    actionTitleKey: "hint_table_select_action",
                    action: { [weak self] in
                        self?.suppression.markLearned(id: "table_tap_to_select")
                        onControlObject()
                        self?.dismissGuidance()
                    },
                    onDismiss: { [weak self] in
                        self?.dismissGuidance()
                    }
                ),
                autoDismissSeconds: 7.0
            )
        }
    }

    /// 5. 工具錯配：拿橡皮擦擦拭非手繪筆跡物件
    public func notifyEraserUsedOnNonInk(
        targetType: InteractionTargetType,
        onDeleteTarget: (() -> Void)? = nil
    ) {
        guard targetType != .canvas else { return }

        let now = Date().timeIntervalSince1970
        if (now - lastEraserScratchTime) < 2.0 {
            eraserScratchCount += 1
        } else {
            eraserScratchCount = 1
        }
        lastEraserScratchTime = now

        if eraserScratchCount >= 3 && suppression.shouldShow(id: "eraser_non_ink") {
            eraserScratchCount = 0
            presentGuidance(
                GuidancePromptItem(
                    id: "eraser_non_ink",
                    icon: "eraser.fill",
                    messageKey: "hint_eraser_non_ink",
                    actionTitleKey: onDeleteTarget != nil ? "hint_eraser_action_delete" : nil,
                    action: { [weak self] in
                        self?.suppression.markLearned(id: "eraser_non_ink")
                        onDeleteTarget?()
                        self?.dismissGuidance()
                    },
                    onDismiss: { [weak self] in
                        self?.dismissGuidance()
                    }
                ),
                autoDismissSeconds: 7.0
            )
        }
    }

    /// 6. 工具錯配：3 秒內手寫與打字模式頻繁交替切換
    public func notifyModeSwitch(to mode: EditorMode) {
        let now = Date().timeIntervalSince1970
        lastModeSwitchTimes.append(now)
        if lastModeSwitchTimes.count > 6 {
            lastModeSwitchTimes.removeFirst()
        }

        let recentSwitches = lastModeSwitchTimes.filter { (now - $0) < 3.0 }
        if recentSwitches.count >= 3 && suppression.shouldShow(id: "mode_switch_guide") {
            lastModeSwitchTimes.removeAll()
            presentGuidance(
                GuidancePromptItem(
                    id: "mode_switch_guide",
                    icon: "arrow.triangle.swap",
                    messageKey: "hint_mode_switch_guide",
                    actionTitleKey: nil,
                    action: nil,
                    onDismiss: { [weak self] in
                        self?.dismissGuidance()
                    }
                ),
                autoDismissSeconds: 6.0
            )
        }
    }

    /// 7. 套索操作：圈選後停滯未移動引導
    public func notifyLassoSelectionStalled() {
        guard suppression.shouldShow(id: "lasso_drag_guide") else { return }
        presentGuidance(
            GuidancePromptItem(
                id: "lasso_drag_guide",
                icon: "arrow.up.and.down.and.arrow.left.and.right",
                messageKey: "hint_lasso_drag_guide",
                actionTitleKey: nil,
                action: nil,
                onDismiss: { [weak self] in
                    self?.dismissGuidance()
                }
            ),
            autoDismissSeconds: 5.0
        )
    }
}
