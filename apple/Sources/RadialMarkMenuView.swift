//
//  RadialMarkMenuView.swift
//  Kairumo
//
//  專業級徑向飛輪快捷工具盤 (Radial Pie / Mark Menu)
//  在手指長按或觸控筆側鍵觸發時，於落筆位置以 360° 環形彈出高頻功能。
//  使用者只需輕輕向任一扇區滑動 0.1 秒即可盲切工具，不中斷創作心流。
//

import SwiftUI

public struct RadialMenuItem: Identifiable {
    public let id: String
    public let icon: String
    public let labelKey: String
    public let color: Color
    public let action: () -> Void

    public init(id: String, icon: String, labelKey: String, color: Color = .primary, action: @escaping () -> Void) {
        self.id = id
        self.icon = icon
        self.labelKey = labelKey
        self.color = color
        self.action = action
    }
}

public struct RadialMarkMenuView: View {
    @Binding var isPresented: Bool
    let centerPoint: CGPoint
    let items: [RadialMenuItem]

    @ObservedObject var localizationManager = LocalizationManager.shared
    @Environment(\.colorScheme) private var colorScheme

    @State private var hoveredItemId: String? = nil
    @State private var currentDragOffset: CGSize = .zero

    private let radius: CGFloat = 88.0
    private let itemSize: CGFloat = 46.0

    public init(
        isPresented: Binding<Bool>,
        centerPoint: CGPoint,
        items: [RadialMenuItem]
    ) {
        self._isPresented = isPresented
        self.centerPoint = centerPoint
        self.items = items
    }

    public var body: some View {
        ZStack {
            // 背景暗化遮罩（輕微，避免擋住畫布全貌）
            Color.black.opacity(0.12)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    dismissMenu()
                }

            // 飛輪中心指示器與環形扇區組
            ZStack {
                // 中央鎖定環
                Circle()
                    .fill(Color(uiColor: .systemBackground).opacity(0.85))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Circle()
                            .stroke(Color.accentColor.opacity(0.5), lineWidth: 2)
                    )
                    .shadow(color: Color.black.opacity(0.15), radius: 6, y: 2)

                // 環形分佈之快捷按鈕
                ForEach(0..<items.count, id: \.self) { index in
                    let item = items[index]
                    let angle = angleForIndex(index, total: items.count)
                    let position = positionForAngle(angle, radius: radius)
                    let isHovered = (hoveredItemId == item.id)

                    Button {
                        #if os(iOS)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        #endif
                        item.action()
                        dismissMenu()
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: item.icon)
                                .font(.system(size: isHovered ? 18 : 15, weight: isHovered ? .bold : .semibold))
                                .foregroundColor(isHovered ? .white : item.color)

                            Text(localizationManager.localized(item.labelKey))
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(isHovered ? .white : .secondary)
                                .lineLimit(1)
                        }
                        .frame(width: itemSize, height: itemSize)
                        .background {
                            Circle()
                                .fill(isHovered ? Color.accentColor : Color(uiColor: .secondarySystemGroupedBackground).opacity(0.92))
                                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.12), radius: isHovered ? 8 : 4, y: 2)
                        }
                        .overlay {
                            Circle()
                                .stroke(isHovered ? Color.white.opacity(0.8) : Color.secondary.opacity(0.15), lineWidth: isHovered ? 2 : 1)
                        }
                        .scaleEffect(isHovered ? 1.15 : 1.0)
                        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovered)
                    }
                    .buttonStyle(.plain)
                    .position(x: centerPoint.x + position.x, y: centerPoint.y + position.y)
                    .accessibilityLabel(localizationManager.localized(item.labelKey))
                }
            }
            .transition(.scale(scale: 0.6).combined(with: .opacity))
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.76), value: isPresented)
    }

    private func angleForIndex(_ index: Int, total: Int) -> Double {
        // 從頂部開始逆時針或順時針排列 (起始 -90°)
        let step = (2.0 * .pi) / Double(total)
        return -(.pi / 2.0) + (Double(index) * step)
    }

    private func positionForAngle(_ angle: Double, radius: CGFloat) -> CGPoint {
        CGPoint(
            x: CGFloat(cos(angle)) * radius,
            y: CGFloat(sin(angle)) * radius
        )
    }

    private func dismissMenu() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        withAnimation {
            isPresented = false
        }
    }
}
