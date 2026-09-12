//
//  ImageEditControls.swift
//  Kairumo
//
//  圖片美化與樣式調整控制項
//  支援濾鏡特效、邊框風格、圓角弧度、立體陰影與旋轉
//
//  以**浮動面板**呈現而非 modal sheet：sheet 會蓋住畫布，
//  調整時看不到自己在調什麼。見 `FloatingPanel`。
//

import SwiftUI

/// 圖片美化控制項本體（不含容器）。
public struct ImageEditControls: View {
    @Binding var attachment: NoteImageAttachment
    var onDelete: () -> Void
    @ObservedObject var localizationManager = LocalizationManager.shared

    public init(attachment: Binding<NoteImageAttachment>, onDelete: @escaping () -> Void) {
        self._attachment = attachment
        self.onDelete = onDelete
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            group(localizationManager.localized("image_filter")) {
                Picker(localizationManager.localized("image_filter"), selection: $attachment.filterStyle) {
                    ForEach(ImageFilterStyle.allCases) { filter in
                        Text(localizationManager.localized(filter.localizationKey)).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            group(localizationManager.localized("material_style")) {
                Picker(localizationManager.localized("material_style"), selection: $attachment.materialType) {
                    Text(localizationManager.localized("mat_none")).tag(nil as MaterialType?)
                    ForEach(MaterialType.allCases) { mat in
                        Text(localizationManager.localized(mat.localizationKey)).tag(mat as MaterialType?)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            group(localizationManager.localized("image_border")) {
                Toggle(localizationManager.localized("keep_border"), isOn: $attachment.hasBorder)
                Toggle(localizationManager.localized("image_shadow"), isOn: $attachment.hasShadow)
            }

            group(localizationManager.localized("image_rounded")) {
                HStack {
                    Slider(value: $attachment.cornerRadius, in: 0...32, step: 2)
                    Text("\(Int(attachment.cornerRadius)) pt")
                        .font(.caption)
                        .monospacedDigit()
                        .frame(width: 46, alignment: .trailing)
                }
            }

            group(localizationManager.localized("image_rotate")) {
                HStack(spacing: 10) {
                    Button {
                        attachment.rotationDegrees =
                            (attachment.rotationDegrees + 90.0).truncatingRemainder(dividingBy: 360.0)
                    } label: {
                        Label(localizationManager.localized("rotate_right_90"), systemImage: "rotate.right")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Text("\(Int(attachment.rotationDegrees))°")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label(localizationManager.localized("remove_image_from_canvas"), systemImage: "trash")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
    }

    @ViewBuilder
    private func group<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            content()
        }
    }
}
