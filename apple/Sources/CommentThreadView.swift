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

    public var body: some View {
        VStack(spacing: 0) {
            // 頂部導覽資訊
            HStack(spacing: 10) {
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
                    Text(formatDate(pin.createdAt))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Spacer()

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
        .frame(width: 320)
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
