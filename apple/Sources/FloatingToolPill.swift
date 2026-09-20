//
//  FloatingToolPill.swift
//  Kairumo
//
//  響應式畫布極致極簡模式：可收折為單一懸浮點 / 快捷氣泡的繪圖工作列
//

import SwiftUI

public struct FloatingToolPill<Content: View>: View {
    @Binding var isExpanded: Bool
    var currentToolIcon: String
    var currentColorHex: String
    var currentStrokeWidth: CGFloat
    var toolboxTitle: String
    var expandLabel: String
    var collapseLabel: String
    var exitMinimalLabel: String
    var onRestore: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content

    @State private var dragOffset: CGSize = .zero
    @State private var lastPosition: CGPoint = CGPoint(x: 32, y: 120)
    @Environment(\.colorScheme) private var colorScheme

    public init(
        isExpanded: Binding<Bool>,
        currentToolIcon: String,
        currentColorHex: String,
        currentStrokeWidth: CGFloat,
        toolboxTitle: String,
        expandLabel: String,
        collapseLabel: String,
        exitMinimalLabel: String,
        onRestore: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self._isExpanded = isExpanded
        self.currentToolIcon = currentToolIcon
        self.currentColorHex = currentColorHex
        self.currentStrokeWidth = currentStrokeWidth
        self.toolboxTitle = toolboxTitle
        self.expandLabel = expandLabel
        self.collapseLabel = collapseLabel
        self.exitMinimalLabel = exitMinimalLabel
        self.onRestore = onRestore
        self.content = content
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            if isExpanded {
                // 展開後的微型懸浮工具列面板
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: currentToolIcon)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.accentColor)
                        Text(toolboxTitle)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        Spacer()
                        
                        if let onRestore = onRestore {
                            Button {
                                onRestore()
                            } label: {
                                Label(exitMinimalLabel, systemImage: "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.accentColor)
                                    .labelStyle(.titleAndIcon)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(Color.accentColor.opacity(0.12), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .help(exitMinimalLabel)
                            .accessibilityLabel(exitMinimalLabel)
                        }

                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                isExpanded = false
                            }
                        } label: {
                            Image(systemName: "chevron.down.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help(collapseLabel)
                        .accessibilityLabel(collapseLabel)
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 8)

                    Divider()

                    content()
                        .padding(.horizontal, 6)
                        .padding(.bottom, 8)
                }
                .frame(maxWidth: 340)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.45 : 0.15), radius: 12, y: 4)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.85, anchor: .topLeading).combined(with: .opacity),
                    removal: .scale(scale: 0.85, anchor: .topLeading).combined(with: .opacity)
                ))
            } else {
                // 極簡單一懸浮點 (Floating Action Bubble)
                HStack(spacing: 8) {
                    Button {
                        #if os(iOS)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        #endif
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                            isExpanded = true
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: currentToolIcon)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.primary)

                            // 顏色指示點
                            Circle()
                                .fill(Color(hex: currentColorHex) ?? .primary)
                                .frame(width: 8, height: 8)
                                .overlay(Circle().stroke(Color.white.opacity(0.8), lineWidth: 1))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay {
                            Capsule().stroke(Color.accentColor.opacity(0.4), lineWidth: 1.2)
                        }
                        .shadow(color: Color.black.opacity(0.18), radius: 8, y: 3)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Capsule())
                    .help(expandLabel)
                    .accessibilityLabel(expandLabel)

                    if let onRestore = onRestore {
                        Button {
                            onRestore()
                        } label: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.accentColor)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial, in: Capsule())
                                .overlay {
                                    Capsule().stroke(Color.accentColor.opacity(0.45), lineWidth: 1.2)
                                }
                                .shadow(color: Color.black.opacity(0.18), radius: 8, y: 3)
                        }
                        .buttonStyle(.plain)
                        .help(exitMinimalLabel)
                        .accessibilityLabel(exitMinimalLabel)
                    }
                }
            }
        }
    }
}
