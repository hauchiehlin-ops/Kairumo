//
//  FloatingPanel.swift
//  Kairumo
//
//  可拖曳移動的浮動工作面板
//

import SwiftUI

/// 浮在畫布上、可拖到一旁的面板。
///
/// 取代 `.sheet`：modal sheet 會蓋住畫布，調濾鏡時**看不到自己在調什麼**，
/// 只能關掉看一眼再打開。浮動面板讓物件與控制項同時在畫面上，
/// 調整即時反映在畫布上，擋到了就把面板拖開。
struct FloatingPanel<Content: View>: View {
    let title: String
    var onClose: () -> Void
    @ViewBuilder var content: Content

    /// 面板位置。以「相對於初始落點的位移」保存，換頁或旋轉螢幕都還算合理。
    @State private var offset: CGSize = .zero
    @State private var dragStart: CGSize = .zero
    @State private var isCollapsed: Bool = false
    /// 正在編修的物件在螢幕上的框（全域座標）。面板的**初始落點**避開它：
    /// 預設右上角；物件在右半邊就改放左邊，左右都會壓到就放到物件上方或下方。
    /// 使用者拖過面板之後以使用者的位置為準。
    @Environment(\.floatingPanelAvoidRect) private var avoidRect
    @State private var userMoved = false
    /// 最近一次自動落點換算成的 `offset`。用類別盒子存：在 body 裡寫入不會觸發重繪。
    @State private var autoBase = AutoPlacement()

    private final class AutoPlacement { var offset: CGSize = .zero }


    var body: some View {
        // 寬度要跟著可用空間走，不能寫死。
        //
        // Mac 的視窗可以縮得比面板還窄（iPad 不行，所以 iPad 上驗不出來）。
        // 寫死 340 的話，視窗一窄面板右緣就被裁掉 —— 而被裁掉的正是
        // **關閉鈕與最後一個分頁**，使用者連把它關掉都做不到（實機看到）。
        GeometryReader { geo in
            let available = geo.size.width - 24   // 兩側各留 12 的邊距
            // 永遠不超過可用空間。硬底限（260）會讓面板在空間不足時
            // 仍然溢出被裁掉 —— 那正是第一版沒解決的原因。
            let width = min(FloatingPanelMetrics.preferredWidth,
                            max(FloatingPanelMetrics.minimumWidth, available))

            VStack(spacing: 0) {
                header
                if !isCollapsed {
                    Divider()
                    ScrollView {
                        content
                            .padding(14)
                    }
                    // 高度同理：視窗矮的時候不能硬撐 420。
                    .frame(maxHeight: min(420, max(160, geo.size.height - 120)))
                }
            }
            .frame(width: width)
            .modifier(FloatingPanelChrome())
            .offset(userMoved || avoidRect == nil
                    ? clampedOffset(in: geo.size, panelWidth: width)
                    : avoidingOffset(in: geo, panelWidth: width))
        }
        .allowsHitTesting(true)
    }

    /// 把面板夾在可視範圍內。
    ///
    /// 沒有這一步，使用者可以把面板拖出視窗外再也拉不回來 ——
    /// 位置是存在 `offset` 裡的，關掉重開還是在外面。
    /// 避開物件的落點。候選：右上（預設）、左上、物件下方、物件上方 —— 取與物件重疊最少的那個。
    private func avoidingOffset(in geo: GeometryProxy, panelWidth: CGFloat) -> CGSize {
        let size = geo.size
        guard let global = avoidRect else { return clampedOffset(in: size, panelWidth: panelWidth) }
        let origin = geo.frame(in: .global).origin
        let target = global.offsetBy(dx: -origin.x, dy: -origin.y).insetBy(dx: -12, dy: -12)
        let panelHeight = isCollapsed ? 52 : min(size.height, min(420, max(160, size.height - 120)) + 52)
        let maxX = max(0, size.width - panelWidth)
        let maxY = max(0, size.height - panelHeight)
        let clampY: (CGFloat) -> CGFloat = { min(max($0, 0), maxY) }
        let candidates: [CGPoint] = [
            CGPoint(x: maxX, y: 0),
            CGPoint(x: 0, y: 0),
            CGPoint(x: maxX, y: clampY(target.maxY)),
            CGPoint(x: maxX, y: clampY(target.minY - panelHeight)),
            CGPoint(x: 0, y: clampY(target.maxY)),
            CGPoint(x: 0, y: clampY(target.minY - panelHeight)),
        ]
        let best = candidates.min { a, b in
            overlap(CGRect(origin: a, size: CGSize(width: panelWidth, height: panelHeight)), target)
                < overlap(CGRect(origin: b, size: CGSize(width: panelWidth, height: panelHeight)), target)
        } ?? candidates[0]
        autoBase.offset = CGSize(width: best.x - maxX, height: best.y)
        return CGSize(width: best.x, height: best.y)
    }

    private func overlap(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let i = a.intersection(b)
        return i.isNull ? 0 : i.width * i.height
    }

    private func clampedOffset(in size: CGSize, panelWidth: CGFloat) -> CGSize {
        // 初始落點在右上角（面板一向從畫布右側浮出來）：基準 x 是最右邊，
        // `offset.width` 是從那裡往左的位移，所以合法範圍是 [-(maxX + 半個面板), 0]。
        let maxX = max(0, size.width - panelWidth)
        let maxY = max(0, size.height - 120)
        return CGSize(
            width: min(max(offset.width, -(maxX + panelWidth / 2)), 0) + maxX,
            height: min(max(offset.height, 0), maxY)
        )
    }


    private var header: some View {
        HStack(spacing: 8) {
            // 可拖曳區域：只綁定在標題與拖曳把手，避免劫持右側按鈕的點擊手勢
            HStack(spacing: 8) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.secondary)

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(coordinateSpace: .global)
                    .onChanged { value in
                        if !userMoved {
                            // 從自動避讓的位置接手：換算成 `offset` 的基準（以右上角為原點的位移）。
                            userMoved = true
                            dragStart = autoBase.offset
                        }
                        var transaction = Transaction()
                        transaction.animation = nil
                        withTransaction(transaction) {
                            offset = CGSize(
                                width: dragStart.width + value.translation.width,
                                height: dragStart.height + value.translation.height
                            )
                        }
                    }
                    .onEnded { _ in dragStart = offset }
            )

            Button {
                withAnimation(.easeInOut(duration: 0.18)) { isCollapsed.toggle() }
            } label: {
                Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .highPriorityGesture(TapGesture().onEnded {
                onClose()
            })
            .accessibilityLabel(LocalizationManager.shared.localized("close"))
        }
        .padding(.leading, 12)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
    }
}

private struct FloatingPanelAvoidRectKey: EnvironmentKey {
    static let defaultValue: CGRect? = nil
}

extension EnvironmentValues {
    /// 編修面板要避開的物件框（全域座標）。見 `FloatingPanel`。
    var floatingPanelAvoidRect: CGRect? {
        get { self[FloatingPanelAvoidRectKey.self] }
        set { self[FloatingPanelAvoidRectKey.self] = newValue }
    }
}

/// 面板的外觀：材質底、圓角、細框、陰影。
///
/// 抽成 modifier 只是為了讓 `body` 裡的版面邏輯讀得出來 ——
/// 寬度計算與外觀混在同一條鏈上時，很難看出哪一段在決定尺寸。
private struct FloatingPanelChrome: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.regularMaterial)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.22), radius: 18, y: 8)
    }
}

/// 面板尺寸。放在泛型外面 —— 泛型型別不能有 static stored property。
enum FloatingPanelMetrics {
    /// 理想寬度。空間不夠時會依可用寬度縮。
    static let preferredWidth: CGFloat = 340
    /// 再窄下去控制項會開始互相擠。視窗最小尺寸已由
    /// `applyMacWindowMinimumSize()` 擋住，正常情況不會用到這個值。
    static let minimumWidth: CGFloat = 200
}
