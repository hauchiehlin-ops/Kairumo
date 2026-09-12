//
//  ImageEditSheet.swift
//  Kairumo
//
//  圖片美化與樣式調整面板
//  支援濾鏡特效、邊框風格、圓角弧度、立體陰影與旋轉
//

import SwiftUI

public struct ImageEditSheet: View {
    @Binding var attachment: NoteImageAttachment
    var onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var localizationManager = LocalizationManager.shared

    public init(attachment: Binding<NoteImageAttachment>, onDelete: @escaping () -> Void) {
        self._attachment = attachment
        self.onDelete = onDelete
    }

    public var body: some View {
        NavigationStack {
            Form {
                // 1. 濾鏡特效
                Section(header: Text(localizationManager.localized("image_filter"))) {
                    Picker(localizationManager.localized("image_filter"), selection: $attachment.filterStyle) {
                        ForEach(ImageFilterStyle.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // 2. 外觀材料屬性（9 大材質特性）
                Section(header: Text(localizationManager.localized("material_style"))) {
                    Picker(localizationManager.localized("material_style"), selection: $attachment.materialType) {
                        Text(localizationManager.localized("mat_none")).tag(nil as MaterialType?)
                        ForEach(MaterialType.allCases) { mat in
                            Text(localizationManager.localized(mat.localizationKey)).tag(mat as MaterialType?)
                        }
                    }
                    .pickerStyle(.menu)
                }

                // 2. 邊框與陰影裝飾
                Section(header: Text(localizationManager.localized("image_border"))) {
                    Toggle(localizationManager.localized("image_border"), isOn: $attachment.hasBorder)
                    Toggle(localizationManager.localized("image_shadow"), isOn: $attachment.hasShadow)
                }

                // 3. 圓角半徑
                Section(header: Text(localizationManager.localized("image_rounded"))) {
                    HStack {
                        Slider(value: $attachment.cornerRadius, in: 0...32, step: 2)
                        Text("\(Int(attachment.cornerRadius)) pt")
                            .font(.caption)
                            .frame(width: 40)
                    }
                }

                // 4. 旋轉操作
                Section(header: Text(localizationManager.localized("image_rotate"))) {
                    Button {
                        attachment.rotationDegrees = (attachment.rotationDegrees + 90.0).truncatingRemainder(dividingBy: 360.0)
                    } label: {
                        HStack {
                            Image(systemName: "rotate.right")
                            Text("向右旋轉 90° (目前: \(Int(attachment.rotationDegrees))°)")
                        }
                    }
                }

                // 5. 刪除
                Section {
                    Button(role: .destructive) {
                        onDelete()
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("從畫布移除此圖片")
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(localizationManager.localized("image_beautify"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(localizationManager.localized("confirm")) {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 380, minHeight: 460)
    }
}
