//
//  DynamicPortalIsland.swift
//  Kairumo
//
//  頂部中央「流體動態傳送島 (Mode Portal)」
//  雙模式（手繪工作室 vs 專業文字智庫）之全域無縫穿梭樞紐與上下文感知指示器
//

import SwiftUI

public struct DynamicPortalIsland: View {
    @Binding var editorMode: EditorMode
    var contextualState: ContextualPortalState?
    var onModeChange: (EditorMode) -> Void
    var onExitContextual: (() -> Void)?

    @ObservedObject var localizationManager = LocalizationManager.shared
    @Environment(\.colorScheme) private var colorScheme

    public enum ContextualPortalState: Equatable {
        case editingTextInDrawMode(title: String)
        case drawingInTextMode(title: String)
    }

    public init(
        editorMode: Binding<EditorMode>,
        contextualState: ContextualPortalState? = nil,
        onModeChange: @escaping (EditorMode) -> Void,
        onExitContextual: (() -> Void)? = nil
    ) {
        self._editorMode = editorMode
        self.contextualState = contextualState
        self.onModeChange = onModeChange
        self.onExitContextual = onExitContextual
    }

    public var body: some View {
        HStack(spacing: 0) {
            if let contextual = contextualState {
                // 🌟 上下文穿插模式：提示目前正在雙向穿插
                contextualBanner(contextual)
            } else {
                // 🌟 全域標準雙模傳送島
                standardIsland
            }
        }
        .padding(3)
        .background {
            Capsule()
                .fill(Color(uiColor: .tertiarySystemGroupedBackground).opacity(0.85))
                .background(.ultraThinMaterial, in: Capsule())
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.08), radius: 6, y: 2)
        }
        .overlay {
            Capsule()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(contextualState != nil ? 0.7 : 0.25),
                            Color.secondary.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.78), value: editorMode)
        .animation(.spring(response: 0.35, dampingFraction: 0.78), value: contextualState)
    }

    // MARK: - 標準模式分段傳送門
    private var standardIsland: some View {
        HStack(spacing: 3) {
            // 1. 手繪工作室 (Studio Art)
            portalSegment(
                mode: .draw,
                icon: "pencil.tip",
                labelKey: "handwriting_mode"
            )

            // 中央微型分隔點
            Circle()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 3, height: 3)
                .padding(.horizontal, 2)

            // 2. 專業文字智庫 (Pro Docs)
            portalSegment(
                mode: .type,
                icon: "doc.text.fill",
                labelKey: "typing_mode"
            )
        }
    }

    private func portalSegment(mode: EditorMode, icon: String, labelKey: String) -> some View {
        let isSelected = (editorMode == mode)
        return Button {
            guard editorMode != mode else { return }
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            #endif
            onModeChange(mode)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? .white : .secondary)

                Text(localizationManager.localized(labelKey))
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : .secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                if isSelected {
                    Capsule()
                        .fill(Color.accentColor)
                        .matchedGeometryEffect(id: "PORTAL_ISLAND_PILL", in: portalNamespace)
                        .shadow(color: Color.accentColor.opacity(0.3), radius: 4, y: 1)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizationManager.localized(labelKey))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityIdentifier("portal.\(mode.rawValue)")
    }

    // MARK: - 上下文穿插橫條 (In-Canvas Cross Ingestion)
    private func contextualBanner(_ contextual: ContextualPortalState) -> some View {
        HStack(spacing: 8) {
            switch contextual {
            case .editingTextInDrawMode(let title):
                HStack(spacing: 5) {
                    Image(systemName: "pencil.tip")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.accentColor)
                    Image(systemName: "character.textbox")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.accentColor)
                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.primary)
                }
            case .drawingInTextMode(let title):
                HStack(spacing: 5) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.accentColor)
                    Image(systemName: "hand.draw.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.accentColor)
                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.primary)
                }
            }

            if let onExit = onExitContextual {
                Button {
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                    onExit()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                        Text(localizationManager.localized("done"))
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
    }

    @Namespace private var portalNamespace
}
