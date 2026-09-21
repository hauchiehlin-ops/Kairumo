//
//  ProColorPickerSheet.swift
//  Kairumo
//
//  進階調色中樞 (Advanced Color Studio)
//  支援 RGB、HSB、HEX 十六進位色碼精確輸入、不透明度調節與五大設計師色盤
//

import SwiftUI

public struct ProColorPickerSheet: View {
    @Binding var selectedColor: Color
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var localizationManager = LocalizationManager.shared

    // 調色模式
    @State private var colorModeIndex: Int = 0 // 0: RGB, 1: HSB, 2: HEX, 3: 設計師色盤

    // RGB 分量 (0~255)
    @State private var redValue: Double = 0
    @State private var greenValue: Double = 0
    @State private var blueValue: Double = 0
    @State private var alphaValue: Double = 1.0

    // HSB 分量
    @State private var hueValue: Double = 0 // 0~360
    @State private var satValue: Double = 0 // 0~1
    @State private var briValue: Double = 0 // 0~1

    // HEX 字串
    @State private var hexInputString: String = "#000000"

    // 收藏色盤 (持久化於 UserDefaults)
    @State private var favoriteColors: [String] = [
        "#1E88E5", "#E53935", "#43A047", "#FB8C00", "#8E24AA", "#3949AB"
    ]

    // 最近使用色
    @State private var recentColors: [String] = [
        "#000000", "#1E88E5", "#E53935", "#43A047", "#FDD835"
    ]

    // 五大設計師色盤
    /// 設計師色盤。**來源是核心的 `designerPalette()`，不在這裡寫死。**
    ///
    /// 原本這 40 個顏色與名字全寫在這個檔案裡，而名字是寫死的繁體中文 ——
    /// 日文或英文使用者在一個已經翻成六國語系的面板裡看到一整面中文。
    /// 顏色本身也是會落盤的資料，Android 各寫一份就會漂移。
    private func palette(_ group: FfiPaletteGroup) -> [(String, String)] {
        designerPalette(group: group).map {
            ($0.hex, localizationManager.localized($0.key))
        }
    }

    public init(selectedColor: Binding<Color>) {
        self._selectedColor = selectedColor
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // 1. 當前選中色彩大預覽區 + HEX 標籤 + 收藏按鈕
                colorPreviewHeader
                    .padding(.horizontal)
                    .padding(.top, 12)

                Divider()

                // 2. 調色模式分段切換器 (RGB / HSB / HEX / 設計師色盤)
                Picker("", selection: $colorModeIndex) {
                    Text("RGB").tag(0)
                    Text("HSB").tag(1)
                    Text("HEX").tag(2)
                    Text(LocalizationManager.shared.localized("designer_palette")).tag(3)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // 3. 各模式對應的調色面板
                ScrollView {
                    VStack(spacing: 16) {
                        switch colorModeIndex {
                        case 0:
                            rgbSlidersView
                        case 1:
                            hsbSlidersView
                        case 2:
                            hexInputView
                        default:
                            designerPalettesView
                        }

                        // 不透明度 Alpha 滑桿
                        opacitySliderView

                        Divider().padding(.vertical, 4)

                        // 收藏與最近使用色盤
                        recentAndFavoriteSwatches
                    }
                    .padding(.horizontal)
                }

                Spacer()
            }
            .navigationTitle(localizationManager.localized("pro_color"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(localizationManager.localized("confirm")) {
                        commitColor()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                initFromCurrentColor()
            }
        }
    }

    // MARK: - 1. 預覽頭部
    private var colorPreviewHeader: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: redValue / 255.0, green: greenValue / 255.0, blue: blueValue / 255.0).opacity(alphaValue))
                .frame(width: 80, height: 60)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1.5)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 4, y: 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(hexInputString)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))

                Text("RGB: (\(Int(redValue)), \(Int(greenValue)), \(Int(blueValue))) • \(Int(alphaValue * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                if !favoriteColors.contains(hexInputString) {
                    favoriteColors.insert(hexInputString, at: 0)
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    Text(localizationManager.localized("add_favorite_color"))
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.12))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 2. RGB 滑桿
    private var rgbSlidersView: some View {
        VStack(spacing: 14) {
            sliderRow(title: LocalizationManager.shared.localized("cp_red"), value: $redValue, range: 0...255, accentColor: .red) {
                syncFromRgb()
            }
            sliderRow(title: LocalizationManager.shared.localized("cp_green"), value: $greenValue, range: 0...255, accentColor: .green) {
                syncFromRgb()
            }
            sliderRow(title: LocalizationManager.shared.localized("cp_blue"), value: $blueValue, range: 0...255, accentColor: .blue) {
                syncFromRgb()
            }
        }
    }

    // MARK: - 3. HSB 滑桿
    private var hsbSlidersView: some View {
        VStack(spacing: 14) {
            sliderRow(title: LocalizationManager.shared.localized("cp_hue"), value: $hueValue, range: 0...360, accentColor: .purple) {
                syncFromHsb()
            }
            sliderRow(title: LocalizationManager.shared.localized("cp_saturation2"), value: $satValue, range: 0...100, accentColor: .orange) {
                syncFromHsb()
            }
            sliderRow(title: LocalizationManager.shared.localized("cp_brightness2"), value: $briValue, range: 0...100, accentColor: .yellow) {
                syncFromHsb()
            }
        }
    }

    // MARK: - 4. HEX 輸入
    private var hexInputView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localizationManager.localized("hex_code"))
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)

            HStack {
                TextField("#000000", text: $hexInputString)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .autocapitalization(.allCharacters)
                    .disableAutocorrection(true)

                Button(LocalizationManager.shared.localized("apply_hex")) {
                    applyHex(hexInputString)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: - 5. 五大設計師色盤
    private var designerPalettesView: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 組別與順序也來自核心 —— 兩邊各排一套的話，使用者換裝置要重新找。
            ForEach(designerPaletteGroups(), id: \.self) { group in
                paletteSection(
                    title: localizationManager.localized(designerPaletteGroupKey(group: group)),
                    list: palette(group)
                )
            }
        }
    }

    private func paletteSection(title: String, list: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(list, id: \.0) { hex, name in
                        Button {
                            applyHex(hex)
                        } label: {
                            VStack(spacing: 3) {
                                Circle()
                                    .fill(Color(hex: hex) ?? .gray)
                                    .frame(width: 28, height: 28)
                                    .overlay(Circle().stroke(Color.secondary.opacity(0.3), lineWidth: 1))

                                Text(name)
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - 不透明度滑桿
    private var opacitySliderView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(localizationManager.localized("opacity"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(alphaValue * 100))%")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            Slider(value: $alphaValue, in: 0.05...1.0)
                .accentColor(.primary)
        }
    }

    // MARK: - 收藏色與最近使用色
    private var recentAndFavoriteSwatches: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 我的收藏
            if !favoriteColors.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(localizationManager.localized("favorite_colors"))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        ForEach(favoriteColors, id: \.self) { hex in
                            Button {
                                applyHex(hex)
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex) ?? .gray)
                                    .frame(width: 26, height: 26)
                                    .overlay(Circle().stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            // 最近使用
            VStack(alignment: .leading, spacing: 6) {
                Text(localizationManager.localized("recent_colors"))
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    ForEach(recentColors, id: \.self) { hex in
                        Button {
                            applyHex(hex)
                        } label: {
                            Circle()
                                .fill(Color(hex: hex) ?? .gray)
                                .frame(width: 26, height: 26)
                                .overlay(Circle().stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - 輔助滑桿列組件
    private func sliderRow(title: String, value: Binding<Double>, range: ClosedRange<Double>, accentColor: Color, onCommit: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.caption)
                .fontWeight(.bold)
                .frame(width: 60, alignment: .leading)

            Slider(value: value, in: range) { _ in
                onCommit()
            }
            .accentColor(accentColor)

            Text("\(Int(value.wrappedValue))")
                .font(.caption)
                .frame(width: 36, alignment: .trailing)
        }
    }

    // MARK: - 運算同步
    private func initFromCurrentColor() {
        let uic = UIColor(selectedColor)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 1
        if uic.getRed(&r, green: &g, blue: &b, alpha: &a) {
            self.redValue = Double(r * 255.0)
            self.greenValue = Double(g * 255.0)
            self.blueValue = Double(b * 255.0)
            self.alphaValue = Double(a)
            syncFromRgb()
        }
    }

    private func syncFromRgb() {
        let r = redValue / 255.0
        let g = greenValue / 255.0
        let b = blueValue / 255.0
        let uic = UIColor(red: r, green: g, blue: b, alpha: 1.0)
        var h: CGFloat = 0
        var s: CGFloat = 0
        var br: CGFloat = 0
        var a: CGFloat = 1
        if uic.getHue(&h, saturation: &s, brightness: &br, alpha: &a) {
            self.hueValue = Double(h * 360.0)
            self.satValue = Double(s * 100.0)
            self.briValue = Double(br * 100.0)
        }
        self.hexInputString = String(format: "#%02X%02X%02X", Int(redValue), Int(greenValue), Int(blueValue))
    }

    private func syncFromHsb() {
        let h = hueValue / 360.0
        let s = satValue / 100.0
        let br = briValue / 100.0
        let uic = UIColor(hue: h, saturation: s, brightness: br, alpha: 1.0)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 1
        if uic.getRed(&r, green: &g, blue: &b, alpha: &a) {
            self.redValue = Double(r * 255.0)
            self.greenValue = Double(g * 255.0)
            self.blueValue = Double(b * 255.0)
            self.hexInputString = String(format: "#%02X%02X%02X", Int(redValue), Int(greenValue), Int(blueValue))
        }
    }

    private func applyHex(_ hex: String) {
        if let c = Color(hex: hex) {
            let uic = UIColor(c)
            var r: CGFloat = 0
            var g: CGFloat = 0
            var b: CGFloat = 0
            var a: CGFloat = 1
            if uic.getRed(&r, green: &g, blue: &b, alpha: &a) {
                self.redValue = Double(r * 255.0)
                self.greenValue = Double(g * 255.0)
                self.blueValue = Double(b * 255.0)
                syncFromRgb()
            }
        }
    }

    private func commitColor() {
        let finalColor = Color(red: redValue / 255.0, green: greenValue / 255.0, blue: blueValue / 255.0).opacity(alphaValue)
        selectedColor = finalColor

        // 加入最近使用清單
        if !recentColors.contains(hexInputString) {
            recentColors.insert(hexInputString, at: 0)
            if recentColors.count > 8 {
                recentColors.removeLast()
            }
        }
    }
}
