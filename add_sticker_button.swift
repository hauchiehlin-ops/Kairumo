            Button {
                saveSelectedAsSticker()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "photo.on.rectangle")
                    Text(localizationManager.localized("save_as_sticker"))
                }
                .font(.caption2)
                .foregroundColor(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.15))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
