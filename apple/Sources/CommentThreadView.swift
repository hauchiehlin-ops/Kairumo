//
//  CommentThreadView.swift
//  Kairumo
//
//  畫布圖釘即時討論串視圖（第二階段：畫布即時交流與討論）
//

import SwiftUI

/// 畫布上的小圖釘標記
public struct CommentPinMarkerView: View {
    public let pin: NoteCommentPin
    public let isSelected: Bool
    public let onTap: () -> Void

    public init(pin: NoteCommentPin, isSelected: Bool, onTap: @escaping () -> Void) {
        self.pin = pin
        self.isSelected = isSelected
        self.onTap = onTap
    }

    private var pinColor: Color {
        Color(hex: pin.authorColor) ?? .blue
    }

    public var body: some View {
        Button(action: onTap) {
            ZStack {
                // 陰影底盤
                Circle()
                    .fill(pin.isResolved ? Color.gray.opacity(0.85) : pinColor)
                    .frame(width: 34, height: 34)
                    .shadow(color: Color.black.opacity(0.25), radius: 4, y: 2)
                    .overlay(
                        Circle()
                            .stroke(isSelected ? Color.yellow : Color.white, lineWidth: isSelected ? 2.5 : 2)
                    )

                if pin.isResolved {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "text.bubble.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                }

                // 訊息數量標籤（若大於 1 則顯示徽章）
                if pin.messages.count > 1 {
                    Text("\(pin.messages.count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.red)
                        .clipShape(Capsule())
                        .offset(x: 14, y: -12)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

/// 畫布圖釘展開後的詳細對話浮層
public struct CommentThreadDialog: View {
    @ObservedObject var localizationManager = LocalizationManager.shared
    public let pin: NoteCommentPin
    public let currentUserId: String
    public let currentUserName: String
    public let currentUserColor: String
    public let onReply: (String, String) -> Void // pinId, messageText
    public let onToggleResolve: (String) -> Void // pinId
    public let onDelete: (String) -> Void // pinId
    public let onClose: () -> Void

    @State private var replyText: String = ""

    // 浮層自由拖曳位移。圖釘固定在畫布座標上，但對話框常常正好蓋住
    // 要討論的那塊內容，所以浮層本身必須可以被拖到旁邊；縮小成標題列
    // 之後同樣要能拖，否則縮小只是換個地方擋住畫面。
    @State private var dragOffset: CGSize = .zero
    @GestureState private var liveDrag: CGSize = .zero
    @State private var isMinimized: Bool = false

    public init(
        pin: NoteCommentPin,
        currentUserId: String,
        currentUserName: String,
        currentUserColor: String,
        onReply: @escaping (String, String) -> Void,
        onToggleResolve: @escaping (String) -> Void,
        onDelete: @escaping (String) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.pin = pin
        self.currentUserId = currentUserId
        self.currentUserName = currentUserName
        self.currentUserColor = currentUserColor
        self.onReply = onReply
        self.onToggleResolve = onToggleResolve
        self.onDelete = onDelete
        self.onClose = onClose
    }

    private var pinAuthorColor: Color {
        Color(hex: pin.authorColor) ?? .blue
    }

    /// 拖曳浮層用的手勢。只掛在標題列（或縮小後的整條列）上，
    /// 避免和訊息列表的捲動、輸入框的點擊互相搶事件。
    private var moveGesture: some Gesture {
        // 座標系必須用 .global。用預設的 .local 時，手勢的座標系會跟著
        // 被 `.offset` 移動的視圖一起動 —— 位移改變 → 座標系改變 →
        // translation 又被重算，形成回授迴圈，畫面就是劇烈抖動。
        // 全域座標系不受自身位移影響，拖曳才會穩。
        DragGesture(minimumDistance: 2, coordinateSpace: .global)
            .updating($liveDrag) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                dragOffset.width += value.translation.width
                dragOffset.height += value.translation.height
            }
    }

    private var totalOffset: CGSize {
        CGSize(width: dragOffset.width + liveDrag.width, height: dragOffset.height + liveDrag.height)
    }

    /// 縮小後的精簡標題列（仍可拖曳、可還原、可關閉）
    private var minimizedBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal")
                .font(.caption)
                .foregroundColor(.secondary)

            Circle()
                .fill(pinAuthorColor)
                .frame(width: 18, height: 18)
                .overlay(
                    Text(String(pin.authorName.prefix(1)).uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                )

            Text(pin.authorName)
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(1)

            Text("\(pin.messages.count)")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Color.accentColor)
                .clipShape(Capsule())

            Button(action: { withAnimation(.easeInOut(duration: 0.18)) { isMinimized = false } }) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(5)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(5)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(width: 240)
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.18), radius: 10, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .gesture(moveGesture)
    }

    public var body: some View {
        Group {
            if isMinimized {
                minimizedBar
            } else {
                expandedDialog
            }
        }
        .offset(x: totalOffset.width, y: totalOffset.height)
    }

    private var expandedDialog: some View {
        VStack(spacing: 0) {
            // 頂部導覽資訊
            HStack(spacing: 10) {
                // 拖曳握把：按住這裡可以把整個對話框搬到不擋住內容的位置
                Image(systemName: "line.3.horizontal")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.trailing, 2)

                Circle()
                    .fill(pinAuthorColor)
                    .frame(width: 26, height: 26)
                    .overlay(
                        Text(String(pin.authorName.prefix(1)).uppercased())
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text(pin.authorName)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(formatDate(pin.createdAt))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .layoutPriority(1)

                Spacer(minLength: 4)

                // 已解決 / 未解決切換鈕
                Button(action: {
                    onToggleResolve(pin.id)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: pin.isResolved ? "arrow.uturn.backward" : "checkmark.circle.fill")
                            .font(.caption)
                        Text(pin.isResolved ? localizationManager.localized("reopen") : localizationManager.localized("resolve"))
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .fixedSize()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(pin.isResolved ? Color.gray.opacity(0.15) : Color.green.opacity(0.15))
                    .foregroundColor(pin.isResolved ? .primary : .green)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                // 刪除按鈕
                Button(action: {
                    onDelete(pin.id)
                }) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(6)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help(localizationManager.localized("delete_comment"))

                // 縮小按鈕（縮成標題列，仍可繼續拖曳移動）
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.18)) { isMinimized = true }
                }) {
                    Image(systemName: "minus")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(6)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help(localizationManager.localized("minimize_dialog"))

                // 關閉按鈕
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(6)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(uiColor: .secondarySystemBackground))
            .contentShape(Rectangle())
            .gesture(moveGesture)

            Divider()

            // 對話訊息滾動列表
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(pin.messages) { msg in
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(Color(hex: msg.authorColor) ?? .blue)
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Text(String(msg.authorName.prefix(1)).uppercased())
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                )

                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(msg.authorName)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    Text(formatDate(msg.createdAt))
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                }

                                Text(msg.text)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(14)
            }
            .frame(maxHeight: 200)

            Divider()

            // 底部輸入框
            HStack(spacing: 8) {
                TextField(localizationManager.localized("comment_placeholder"), text: $replyText)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(Color(uiColor: .tertiarySystemBackground))
                    .cornerRadius(8)
                    .onSubmit {
                        submitReply()
                    }

                Button(action: submitReply) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 26))
                        .foregroundColor(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : .accentColor)
                }
                .buttonStyle(.plain)
                .disabled(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(10)
            .background(Color(uiColor: .secondarySystemBackground))
        }
        .frame(width: 360)
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.18), radius: 12, y: 6)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private func submitReply() {
        let trimmed = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onReply(pin.id, trimmed)
        replyText = ""
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
}
