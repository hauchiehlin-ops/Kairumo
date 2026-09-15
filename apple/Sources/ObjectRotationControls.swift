//
//  ObjectRotationControls.swift
//  Kairumo
//
//  畫布物件的自由角度旋轉：面板上的精準控制 + 畫布上的拖曳把手。
//
//  # 為什麼兩種都要
//
//  只有拖曳把手的話，使用者轉不出「正好 30°」；只有數值控制的話，
//  想隨手擺歪一點就得先估角度再輸入。兩者互補，而且共用同一組吸附規則
//  （`CanvasRotation`），不然同一個物件用兩種方式轉會停在不同角度。
//
//  # 為什麼把手畫在旋轉外面
//
//  把手若放進 `.rotationEffect` 裡面，它的座標系會跟著轉 —— 拖曳時算出來的
//  角度會疊加自身的旋轉，物件會失控加速。這裡把手與內容同層但**不參與旋轉**，
//  只用三角函式把它擺到旋轉後該在的位置。
//

import SwiftUI

// MARK: - 面板控制

/// 編輯面板裡的旋轉控制：滑桿 + 數值 + 常用角度 + 歸零。
public struct ObjectRotationDial: View {
    @Binding var degrees: Double
    @ObservedObject private var localizationManager = LocalizationManager.shared

    public init(degrees: Binding<Double>) {
        self._degrees = degrees
    }

    private let quickAngles: [Double] = [0, 90, 180, 270]

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Slider(
                    value: Binding(
                        get: { CanvasRotation.normalized(degrees) },
                        set: { degrees = CanvasRotation.normalized($0) }
                    ),
                    in: 0...359,
                    step: 1
                )

                Text("\(Int(CanvasRotation.normalized(degrees)))°")
                    .font(.caption)
                    .monospacedDigit()
                    .frame(width: 42, alignment: .trailing)
            }

            HStack(spacing: 6) {
                // 逐度微調。滑桿在 0–359 的範圍下很難停在特定整數上。
                stepButton("minus", delta: -1)
                stepButton("plus", delta: 1)

                Divider().frame(height: 18)

                ForEach(quickAngles, id: \.self) { angle in
                    Button {
                        degrees = angle
                    } label: {
                        Text("\(Int(angle))°")
                            .font(.system(size: 11, weight: .medium))
                            .frame(minWidth: 34, minHeight: 24)
                            .foregroundColor(isCurrent(angle) ? .white : .primary)
                            .background(isCurrent(angle) ? Color.accentColor : Color.secondary.opacity(0.12))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Button {
                    degrees = 0
                } label: {
                    Label(localizationManager.localized("reset"), systemImage: "arrow.counterclockwise")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                .disabled(CanvasRotation.normalized(degrees) == 0)
            }
        }
    }

    private func isCurrent(_ angle: Double) -> Bool {
        abs(CanvasRotation.normalized(degrees) - angle) < 0.5
    }

    private func stepButton(_ icon: String, delta: Double) -> some View {
        Button {
            degrees = CanvasRotation.normalized(degrees + delta)
        } label: {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .frame(width: 24, height: 24)
                .background(Color.secondary.opacity(0.12))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 畫布把手

/// 畫布上的旋轉把手。放在物件框的 ZStack 裡，**不要**包進 `.rotationEffect`。
public struct ObjectRotationHandle: View {
    @Binding var degrees: Double
    /// 物件（未旋轉時）的尺寸，用來算把手該擺在哪。
    let size: CGSize
    /// 拖曳結束時通知外層存檔／廣播。
    var onCommit: () -> Void

    @State private var isDragging = false

    public init(degrees: Binding<Double>, size: CGSize, onCommit: @escaping () -> Void = {}) {
        self._degrees = degrees
        self.size = size
        self.onCommit = onCommit
    }

    /// 把手離物件中心的距離。
    private var radius: CGFloat { max(size.height, 44) / 2 + 26 }

    public var body: some View {
        let angle = CanvasRotation.normalized(degrees) * .pi / 180
        // 把手在未旋轉座標系裡是正上方 (0, -radius)，隨物件角度繞中心轉。
        let dx = CGFloat(sin(angle)) * radius
        let dy = -CGFloat(cos(angle)) * radius

        ZStack {
            // 連到中心的細線，讓使用者看得出把手是繞著哪裡轉。
            Path { path in
                path.move(to: CGPoint(x: size.width / 2, y: size.height / 2))
                path.addLine(to: CGPoint(x: size.width / 2 + dx, y: size.height / 2 + dy))
            }
            .stroke(Color.accentColor.opacity(isDragging ? 0.9 : 0.45),
                    style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

            Image(systemName: "arrow.trianglehead.clockwise.rotate.90")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color.accentColor))
                .shadow(color: .black.opacity(0.25), radius: isDragging ? 5 : 2, y: 1)
                .scaleEffect(isDragging ? 1.15 : 1)
                .position(x: size.width / 2 + dx, y: size.height / 2 + dy)
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
                        .onChanged { value in
                            isDragging = true
                            // atan2 的 0 在 +x 方向，把手的 0 在正上方，差 90°。
                            let vx = value.location.x - size.width / 2
                            let vy = value.location.y - size.height / 2
                            let raw = atan2(vy, vx) * 180 / .pi + 90
                            degrees = CanvasRotation.snapped(Double(raw))
                        }
                        .onEnded { _ in
                            isDragging = false
                            onCommit()
                        }
                )
        }
        .frame(width: size.width, height: size.height)
        .coordinateSpace(name: Self.space)
        // 把手畫在框外，不能被裁掉。
        .allowsHitTesting(true)
    }

    private static let space = "kairumo.objectRotation"
}

// MARK: - 命中測試

public enum RotatedHitTest {
    /// 點是否落在一個**旋轉過**的矩形內。
    ///
    /// 做法是把點反向旋轉回物件自己的座標系，再做一般的矩形判斷 ——
    /// 比起去算旋轉後的四個頂點再做多邊形內外判定，這個版本短很多也不會錯。
    ///
    /// 沒有這一步的話，物件轉過之後看得到卻點不到（或點到旁邊的空白處會選到它）
    /// —— 而且角度越大錯得越離譜。
    public static func contains(
        point: CGPoint,
        center: CGPoint,
        size: CGSize,
        degrees: Double
    ) -> Bool {
        let radians = -CanvasRotation.normalized(degrees) * .pi / 180
        let dx = point.x - center.x
        let dy = point.y - center.y
        let cosA = CGFloat(cos(radians))
        let sinA = CGFloat(sin(radians))
        let localX = dx * cosA - dy * sinA
        let localY = dx * sinA + dy * cosA
        return abs(localX) <= size.width / 2 && abs(localY) <= size.height / 2
    }

    /// 旋轉後在畫布上佔用的軸對齊外框（捲動範圍、縮圖裁切會用到）。
    public static func boundingBox(center: CGPoint, size: CGSize, degrees: Double) -> CGRect {
        let radians = CanvasRotation.normalized(degrees) * .pi / 180
        let cosA = abs(CGFloat(cos(radians)))
        let sinA = abs(CGFloat(sin(radians)))
        let w = size.width * cosA + size.height * sinA
        let h = size.width * sinA + size.height * cosA
        return CGRect(x: center.x - w / 2, y: center.y - h / 2, width: w, height: h)
    }
}
