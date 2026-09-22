//
//  StickerCatalogue.swift
//  Kairumo
//
//  內建貼紙庫。
//
//  # 為什麼原本是空的
//
//  貼紙庫一直只存**使用者自己存下來的**筆跡 —— 沒有任何內建內容。
//  第一次打開它的人看到的是一片空白加一句「還沒有貼紙」，而他根本不知道
//  要怎麼生出第一張。一個要使用者先餵資料才有用的功能，等於沒有。
//
//  # 圖形在核心
//
//  40 張貼紙的路徑資料在 `padnote-core` 的 `ffi_stickers`，Android 讀同一份
//  —— 各畫一套的話，兩邊的笑臉不會是同一個笑臉。這裡只負責把路徑變成
//  `PKDrawing`（貼進畫布的格式）與預覽圖。
//

import SwiftUI
import PencilKit

#if canImport(PadnoteCore)
import PadnoteCore
#endif

public enum StickerCatalogue {

    /// 貼紙畫成 `PKDrawing`，可以直接貼進畫布。
    ///
    /// # 為什麼是筆跡不是圖片
    ///
    /// 貼進來之後它就是**一般的筆跡** —— 可以擦掉一部分、可以套索搬走、
    /// 可以換顏色。變成圖片的話它就成了另一種東西，使用者得用另一套操作，
    /// 而「貼紙貼上去就不能改了」是很多筆記 App 的通病。
    ///
    /// - Parameters:
    ///   - size: 要畫多大（點）。核心給的座標在 100×100 的方格裡。
    ///   - origin: 貼在畫布的哪裡。
    ///   - color: 主線色。強調色會自動帶一點紅 —— 勾、叉、星星那些
    ///     本來就該跳出來。
    @MainActor
    public static func drawing(
        code: String,
        size: CGFloat,
        origin: CGPoint,
        color: UIColor
    ) -> PKDrawing {
        let unit = stickerCanvasSize()
        let scale = size / CGFloat(unit)
        var strokes: [PKStroke] = []

        for path in stickerDrawing(code: code) {
            let points = sample(path.segs)
            guard points.count >= 2 else { continue }
            let ink = PKInk(
                .pen,
                color: path.accent ? accentTint(of: color) : color)
            // 線寬也要跟著縮 —— 不縮的話，小尺寸的貼紙會變成一團墨。
            let width = max(1.0, CGFloat(path.width) * scale)
            // 逐項拆開而不是一行 map：整條寫在一起時 Swift 的型別推導
            // 會超時（"unable to type-check this expression in reasonable
            // time"），而那個錯誤訊息完全指不出是哪一個運算式的問題。
            let dot = CGSize(width: width, height: width)
            var controls: [PKStrokePoint] = []
            controls.reserveCapacity(points.count)
            for p in points {
                let x: CGFloat = origin.x + p.x * scale
                let y: CGFloat = origin.y + p.y * scale
                controls.append(
                    PKStrokePoint(
                        location: CGPoint(x: x, y: y),
                        timeOffset: 0,
                        size: dot,
                        opacity: 1,
                        force: 1,
                        azimuth: 0,
                        altitude: .pi / 2))
            }
            strokes.append(PKStroke(ink: ink, path: PKStrokePath(controlPoints: controls, creationDate: Date())))
        }
        return PKDrawing(strokes: strokes)
    }

    /// 強調色：把使用者選的顏色往紅偏一點。
    ///
    /// 直接寫死紅色的話，在紅色筆記本上貼一個紅勾會看不見；
    /// 完全跟著主色的話，勾與框又分不出來。
    private static func accentTint(of color: UIColor) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard color.getHue(&h, saturation: &s, brightness: &b, alpha: &a) else { return .systemRed }
        return UIColor(hue: 0.0, saturation: max(s, 0.75), brightness: max(b, 0.7), alpha: a)
    }

    /// 路徑指令 → 取樣過的點。
    ///
    /// `PKStroke` 只吃點，不吃貝茲 —— 曲線要自己取樣。16 段是實測的下限：
    /// 再少的話笑臉的嘴會變成折線，而那在 120 點的格子裡看得出來。
    private static func sample(_ segs: [FfiPathSeg]) -> [CGPoint] {
        var out: [CGPoint] = []
        var current = CGPoint.zero
        var start = CGPoint.zero
        for s in segs {
            let to = CGPoint(x: CGFloat(s.x), y: CGFloat(s.y))
            switch s.verb {
            case .move:
                current = to
                start = to
                out.append(to)
            case .line:
                out.append(to)
                current = to
            case .curve:
                let c1 = CGPoint(x: CGFloat(s.c1x), y: CGFloat(s.c1y))
                let c2 = CGPoint(x: CGFloat(s.c2x), y: CGFloat(s.c2y))
                for i in 1...16 {
                    out.append(bezier(current, c1, c2, to, CGFloat(i) / 16.0))
                }
                current = to
            case .close:
                out.append(start)
                current = start
            }
        }
        return out
    }

    private static func bezier(
        _ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, _ t: CGFloat
    ) -> CGPoint {
        let u = 1 - t
        let a = u * u * u, b = 3 * u * u * t, c = 3 * u * t * t, d = t * t * t
        return CGPoint(
            x: a * p0.x + b * p1.x + c * p2.x + d * p3.x,
            y: a * p0.y + b * p1.y + c * p2.y + d * p3.y)
    }
}

/// 一張貼紙的預覽。
public struct StickerGlyph: View {
    let code: String
    var color: Color = .primary

    public init(code: String, color: Color = .primary) {
        self.code = code
        self.color = color
    }

    public var body: some View {
        Canvas { context, size in
            let unit = CGFloat(stickerCanvasSize())
            let scale = min(size.width, size.height) / unit
            for item in stickerDrawing(code: code) {
                var path = Path()
                var start = CGPoint.zero
                for s in item.segs {
                    let to = CGPoint(x: CGFloat(s.x) * scale, y: CGFloat(s.y) * scale)
                    switch s.verb {
                    case .move: path.move(to: to); start = to
                    case .line: path.addLine(to: to)
                    case .curve:
                        path.addCurve(
                            to: to,
                            control1: CGPoint(x: CGFloat(s.c1x) * scale, y: CGFloat(s.c1y) * scale),
                            control2: CGPoint(x: CGFloat(s.c2x) * scale, y: CGFloat(s.c2y) * scale))
                    case .close: path.addLine(to: start); path.closeSubpath()
                    }
                }
                context.stroke(
                    path,
                    with: .color(item.accent ? .red : color),
                    style: StrokeStyle(
                        lineWidth: CGFloat(item.width) * scale,
                        lineCap: .round,
                        lineJoin: .round))
            }
        }
    }
}
