//
//  RadialMarkMenuView.swift
//  Kairumo
//
//  專業級徑向飛輪快捷工具盤 (Radial Pie / Mark Menu)
//  在手指長按或觸控筆側鍵觸發時，於落筆位置以 360° 環形彈出高頻功能。
//  使用者只需輕輕向任一扇區滑動 0.1 秒即可盲切工具，不中斷創作心流。
//

import SwiftUI

#if canImport(PadnoteCore)
import PadnoteCore
#endif

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

    // 這個工具盤畫在**螢幕座標**（不隨頁面縮放）。原本 46pt 的按鈕 + 8pt 的字
    // 放在被縮放的頁面裡，實際只剩 30pt 左右、字約 5pt，看不清楚是什麼工具。
    private let radius: CGFloat = 118.0
    private let itemSize: CGFloat = 72.0

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
                    .position(x: 190, y: 190)

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
                        VStack(spacing: 3) {
                            Image(systemName: item.icon)
                                .font(.system(size: isHovered ? 24 : 22, weight: .semibold))
                                .foregroundColor(isHovered ? .white : item.color)

                            Text(localizationManager.localized(item.labelKey))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(isHovered ? .white : .primary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.75)
                                .padding(.horizontal, 4)
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
                        .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .onHover { inside in
                        hoveredItemId = inside ? item.id : (hoveredItemId == item.id ? nil : hoveredItemId)
                    }
                    .frame(width: itemSize, height: itemSize)
                    .contentShape(Circle())
                    .position(x: 190 + position.x, y: 190 + position.y)
                    .accessibilityLabel(localizationManager.localized(item.labelKey))
                    // 槽位 id（`radial.pen`…，與 Android 同一組）：旅程測試與 VoiceOver 認得出是哪一格。
                    .accessibilityIdentifier(item.id)
                }
            }
            .frame(width: 380, height: 380)
            .position(centerPoint)
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

// MARK: - 可自訂的槽位（核心 `padnote_toolbar::radial`）

extension FfiRadialAction {
    /// 對應的繪圖工具（快捷動作沒有）。
    var editorTool: EditorToolType? {
        switch self {
        case .pen: return .pen
        case .ballPoint: return .ballpoint
        case .fineliner: return .fineliner
        case .brush: return .brush
        case .calligraphy: return .calligraphy
        case .pencil: return .pencil
        case .charcoal: return .charcoal
        case .crayon: return .crayon
        case .airbrush: return .airbrush
        case .oilPaint: return .oilpaint
        case .watercolor: return .watercolor
        case .marker: return .marker
        case .highlighter: return .highlighter
        case .eraser: return .eraser
        case .lasso: return .lasso
        case .maskingTape: return .maskingTape
        case .drafting: return .drafting
        case .undo, .redo, .color, .stabilizer, .toggleMode: return nil
        }
    }

    /// 跨平台識別字，與核心 `RadialAction::parity_identifier`、Android `RadialSlots.identifier` 逐字相同。
    var parityIdentifier: String {
        switch self {
        case .pen: return "radial.pen"
        case .ballPoint: return "radial.ballpoint"
        case .fineliner: return "radial.fineliner"
        case .brush: return "radial.brush"
        case .calligraphy: return "radial.calligraphy"
        case .pencil: return "radial.pencil"
        case .charcoal: return "radial.charcoal"
        case .crayon: return "radial.crayon"
        case .airbrush: return "radial.airbrush"
        case .oilPaint: return "radial.oilpaint"
        case .watercolor: return "radial.watercolor"
        case .marker: return "radial.marker"
        case .highlighter: return "radial.highlighter"
        case .eraser: return "radial.eraser"
        case .lasso: return "radial.lasso"
        case .maskingTape: return "radial.maskingTape"
        case .drafting: return "radial.drafting"
        case .undo: return "radial.undo"
        case .redo: return "radial.redo"
        case .color: return "radial.color"
        case .stabilizer: return "radial.stabilizer"
        case .toggleMode: return "radial.toggleMode"
        }
    }

    /// 字串表的鍵 —— 與工具列、設定畫面同一個字，使用者才認得出是哪一支。
    var labelKey: String {
        switch self {
        case .undo: return "undo"
        case .redo: return "redo"
        case .color: return "pro_color"
        case .stabilizer: return "stab_title"
        case .toggleMode: return "radial_toggle_mode"
        default:
            return editorTool.map { ToolbarCustomizationView.uiLabelKey($0.parityIdentifier) } ?? "tool_pen"
        }
    }

    var symbol: String {
        switch self {
        case .pen: return "pencil.tip"
        case .ballPoint: return "pencil"
        case .fineliner: return "pencil.line"
        case .brush: return "paintbrush.pointed"
        case .calligraphy: return "signature"
        case .pencil: return "pencil"
        case .charcoal: return "scribble"
        case .crayon: return "scribble.variable"
        case .airbrush: return "aqi.medium"
        case .oilPaint: return "paintbrush"
        case .watercolor: return "drop"
        case .marker: return "highlighter"
        case .highlighter: return "highlighter"
        case .eraser: return "eraser"
        case .lasso: return "lasso"
        case .maskingTape: return "bandage"
        case .drafting: return "ruler"
        case .undo: return "arrow.uturn.backward"
        case .redo: return "arrow.uturn.forward"
        case .color: return "paintpalette.fill"
        case .stabilizer: return "waveform.path.ecg"
        case .toggleMode: return "keyboard"
        }
    }

    var tint: Color {
        switch self {
        case .eraser: return .red
        case .lasso: return .purple
        case .undo, .redo: return .blue
        case .color: return .pink
        case .stabilizer: return .green
        case .toggleMode: return .teal
        case .highlighter, .marker: return .orange
        case .maskingTape, .drafting: return .brown
        default: return .accentColor
        }
    }
}
