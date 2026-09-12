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
        VStack(spacing: 0) {
            header
            if !isCollapsed {
                Divider()
                ScrollView {
                    content
                        .padding(14)
                }
                .frame(maxHeight: 420)
            }
        }
        .frame(width: 340)
        .background(.regularMaterial)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.22), radius: 18, y: 8)
        .offset(offset)
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
        .gesture(
            DragGesture()
                .onChanged { value in
                    offset = CGSize(
                        width: dragStart.width + value.translation.width,
                        height: dragStart.height + value.translation.height
                    )
                }
                .onEnded { _ in dragStart = offset }
        )
    }
}
