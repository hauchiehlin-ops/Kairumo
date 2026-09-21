//
//  ProColorWheelView.swift
//  Kairumo
//
//  專業手繪工作室 HSV 色相環與色彩和諧推薦調色盤（參考 CSP / Sketchbook / ibisPaint）
//

import SwiftUI

public struct ProColorWheelView: View {
    @Binding var selectedColorHex: String
    var onColorSelected: (String) -> Void

    @State private var hue: Double = 0.0          // 0...1
    @State private var saturation: Double = 1.0   // 0...1
    @State private var brightness: Double = 1.0   // 0...1

    public init(selectedColorHex: Binding<String>, onColorSelected: @escaping (String) -> Void) {
        self._selectedColorHex = selectedColorHex
        self.onColorSelected = onColorSelected
    }

    public var body: some View {
        VStack(spacing: 12) {
            // 1. 核心色相環與明度方形
            ZStack {
                // 外圈色相圓環
                Circle()
                    .strokeBorder(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                .red, .yellow, .green, .cyan, .blue, .purple, .red
                            ]),
                            center: .center
                        ),
                        lineWidth: 24
                    )
                    .frame(width: 170, height: 170)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                updateHueFromDrag(location: value.location, center: CGPoint(x: 85, y: 85))
                            }
                    )

                // 內核飽和度與明度調整方形
                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            Color(hue: hue, saturation: saturation, brightness: brightness)
                        )
                        .frame(width: 64, height: 44)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white, lineWidth: 2)
                                .shadow(radius: 2)
                        }

                    Text(currentColorHex.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.primary)
                }
            }
            .frame(width: 180, height: 180)

            // 2. 飽和度 & 明度滑桿
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Text(LocalizationManager.shared.localized("cw_saturation"))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 24)
                    Slider(value: $saturation, in: 0...1)
                        .onChange(of: saturation) { _ in applyColor() }
                }

                HStack(spacing: 8) {
                    Text(LocalizationManager.shared.localized("cw_brightness"))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 24)
                    Slider(value: $brightness, in: 0...1)
                        .onChange(of: brightness) { _ in applyColor() }
                }
            }
            .padding(.horizontal, 8)

            Divider()

            // 3. 專業色彩和諧推薦（互補色、對比色、相鄰色）
            VStack(alignment: .leading, spacing: 5) {
                Text(LocalizationManager.shared.localized("cw_harmonies"))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    harmonyChip(title: "主色", h: hue)
                    harmonyChip(title: "互補色", h: fmod(hue + 0.5, 1.0))
                    harmonyChip(title: "類似色 1", h: fmod(hue + 0.08, 1.0))
                    harmonyChip(title: "類似色 2", h: fmod(hue + 0.92, 1.0))
                    harmonyChip(title: "三等分", h: fmod(hue + 0.33, 1.0))
                }
            }
        }
        .padding(10)
        .frame(width: 230)
        .onAppear {
            parseCurrentHex()
        }
    }

    private var currentColorHex: String {
        let (r, g, b) = hsbToRgb(h: hue, s: saturation, b: brightness)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }

    private func updateHueFromDrag(location: CGPoint, center: CGPoint) {
        let dx = location.x - center.x
        let dy = location.y - center.y
        var angle = atan2(dy, dx) + .pi / 2
        if angle < 0 { angle += .pi * 2 }
        hue = Double(angle / (.pi * 2))
        applyColor()
    }

    private func applyColor() {
        let hex = currentColorHex
        selectedColorHex = hex
        onColorSelected(hex)
    }

    private func harmonyChip(title: String, h: Double) -> some View {
        let (r, g, b) = hsbToRgb(h: h, s: saturation, b: brightness)
        let hex = String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
        return Button {
            selectedColorHex = hex
            onColorSelected(hex)
            parseCurrentHex()
        } label: {
            VStack(spacing: 2) {
                Circle()
                    .fill(Color(hue: h, saturation: saturation, brightness: brightness))
                    .frame(width: 22, height: 22)
                    .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: 1))
                Text(title)
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func parseCurrentHex() {
        // 從 selectedColorHex 解析 HSB
        guard let color = Color(hex: selectedColorHex) else { return }
        #if os(iOS)
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        UIColor(color).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        hue = Double(h)
        saturation = Double(s)
        brightness = Double(b)
        #endif
    }

    private func hsbToRgb(h: Double, s: Double, b: Double) -> (Double, Double, Double) {
        if s == 0 { return (b, b, b) }
        let h6 = fmod(h * 6.0, 6.0)
        let i = floor(h6)
        let f = h6 - i
        let p = b * (1.0 - s)
        let q = b * (1.0 - s * f)
        let t = b * (1.0 - s * (1.0 - f))
        switch Int(i) {
        case 0: return (b, t, p)
        case 1: return (q, b, p)
        case 2: return (p, b, t)
        case 3: return (p, q, b)
        case 4: return (t, p, b)
        default: return (b, p, q)
        }
    }
}
