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
            .offset(clampedOffset(in: geo.size, panelWidth: width))
        }
        .allowsHitTesting(true)
    }

    /// 把面板夾在可視範圍內。
    ///
    /// 沒有這一步，使用者可以把面板拖出視窗外再也拉不回來 ——
    /// 位置是存在 `offset` 裡的，關掉重開還是在外面。
    private func clampedOffset(in size: CGSize, panelWidth: CGFloat) -> CGSize {
        let maxX = max(0, size.width - panelWidth)
        let maxY = max(0, size.height - 120)
        return CGSize(
            width: min(max(offset.width, -panelWidth / 2), maxX),
            height: min(max(offset.height, 0), maxY)
        )
    }


    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary)

            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.18)) { isCollapsed.toggle() }
            } label: {
                Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(4)
            }
            .buttonStyle(.plain)

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        // 只有標題列可拖曳：整片都能拖的話，面板內的滑桿會搶不到手勢。
        //
        // **座標空間一定要用 `.global`。** 預設的 `.local` 會跟著這個 view 一起
        // 被 `.offset` 移動 —— 於是位移是對著一個**正在移動的參考點**量的，
        // 形成正回饋：面板移動 → 參考點移動 → 量到更大的位移 → 移動更多。
        // 畫面上看到的就是劇烈晃動。畫布上的物件之所以拖得平順，
        // 正是因為它們用的是固定的具名座標空間。
        .gesture(
            DragGesture(coordinateSpace: .global)
                .onChanged { value in
                    // 拖曳不要動畫：SwiftUI 會替每一次位置變化插補，
                    // 手指已經到了、面板還在追，看起來就是黏滯與抖動。
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
