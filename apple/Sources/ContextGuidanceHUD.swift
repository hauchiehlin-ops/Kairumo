//
//  ContextGuidanceHUD.swift
//  Kairumo
//
//  智慧操作感知與即時情境輔助引導組件。
//  在使用者遭遇操作困境（如手繪/打字混用、表格選取、橡皮擦擦非筆劃）時，
//  即時浮現具備自適應完整文字、確認代勞與關閉記憶的輕量引導面板。
//

import SwiftUI

/// 智慧引導項目模型
public struct GuidancePromptItem: Identifiable, Equatable {
    public let id: String
    public let icon: String
    public let messageKey: String
    public let actionTitleKey: String?
    public let action: (() -> Void)?
    public let onDismiss: (() -> Void)?

    public init(
        id: String,
        icon: String,
        messageKey: String,
        actionTitleKey: String? = nil,
        action: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.id = id
        self.icon = icon
        self.messageKey = messageKey
        self.actionTitleKey = actionTitleKey
        self.action = action
        self.onDismiss = onDismiss
    }

    public static func == (lhs: GuidancePromptItem, rhs: GuidancePromptItem) -> Bool {
        lhs.id == rhs.id && lhs.messageKey == rhs.messageKey
    }
}

/// 智慧引導冷卻與免打擾管理器
public final class GuidanceSuppressionManager: ObservableObject {
    public static let shared = GuidanceSuppressionManager()

    private let defaults = UserDefaults.standard
    private let enabledKey = "kairumo_smart_guidance_enabled"
    private let historyPrefix = "kairumo_guidance_history_"
    private let learnedPrefix = "kairumo_guidance_learned_"

    @Published public var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: enabledKey)
        }
    }

    private init() {
        // 預設開啟智慧引導
        self.isEnabled = defaults.object(forKey: enabledKey) as? Bool ?? true
    }

    /// 檢查特定情境是否符合顯示條件（未被靜默、未達冷卻）
    public func shouldShow(id: String) -> Bool {
        guard isEnabled else { return false }

        // 若使用者已成功學會該操作，進入 14 天長效靜默期
        if let learnedTime = defaults.object(forKey: learnedPrefix + id) as? Double {
            let daysPassed = (Date().timeIntervalSince1970 - learnedTime) / 86400.0
            if daysPassed < 14.0 {
                return false
            }
        }

        // 檢查當日關閉頻率（同一個提示同一天最多提示 2 次）
        let historyKey = historyPrefix + id
        let records = (defaults.array(forKey: historyKey) as? [Double]) ?? []
        let now = Date().timeIntervalSince1970
        let recentRecords = records.filter { (now - $0) < 86400.0 }

        return recentRecords.count < 2
    }

    /// 記錄提示已被展示
    public func recordShown(id: String) {
        let historyKey = historyPrefix + id
        var records = (defaults.array(forKey: historyKey) as? [Double]) ?? []
        records.append(Date().timeIntervalSince1970)
        // 只保留最近 5 筆
        if records.count > 5 {
            records.removeFirst(records.count - 5)
        }
        defaults.set(records, forKey: historyKey)
    }

    /// 標記使用者已學會並完成正確操作，長效休眠該提示
    public func markLearned(id: String) {
        defaults.set(Date().timeIntervalSince1970, forKey: learnedPrefix + id)
    }
}

/// 自適應智慧情境引導快顯組件（支援寬/窄螢幕動態佈局，保證文字 100% 完整呈現）
public struct ContextGuidanceHUDView: View {
    public let item: GuidancePromptItem
    public let onPerformAction: () -> Void
    public let onDismiss: () -> Void

    @ObservedObject private var localizationManager = LocalizationManager.shared

    public init(
        item: GuidancePromptItem,
        onPerformAction: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.item = item
        self.onPerformAction = onPerformAction
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ViewThatFits(in: .horizontal) {
            // 1. 寬螢幕模式：圖示、說明文字與按鈕單行精巧併排
            wideLayout
                .fixedSize(horizontal: true, vertical: false)

            // 2. 窄螢幕模式：文字在上方自適應折行，按鈕在下方居右
            compactLayout
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.14), radius: 10, y: 4)
        .padding(.horizontal, 16)
        .frame(maxWidth: 580)
        .transition(.asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.95)),
            removal: .opacity.combined(with: .scale(scale: 0.92))
        ))
    }

    // 寬螢幕單行佈局
    private var wideLayout: some View {
        HStack(spacing: 12) {
            Image(systemName: item.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.accentColor)

            Text(localizationManager.localized(item.messageKey))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                actionButtons
            }
        }
    }

    // 窄螢幕自適應多行佈局
    private var compactLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: item.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.accentColor)
                    .padding(.top, 1)

                Text(localizationManager.localized(item.messageKey))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                actionButtons
            }
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        if let actionTitleKey = item.actionTitleKey {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onPerformAction()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                    Text(localizationManager.localized(actionTitleKey))
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.accentColor)
                .cornerRadius(7)
            }
            .buttonStyle(.plain)
        }

        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onDismiss()
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                Text(localizationManager.localized("guidance_dismiss"))
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.secondary.opacity(0.12))
            .cornerRadius(7)
        }
        .buttonStyle(.plain)
    }
}
