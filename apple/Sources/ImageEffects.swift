//
//  ImageEffects.swift
//  Kairumo
//
//  圖片的濾鏡與材質，給縮圖與匯出用。
//
//  畫布上這些是 SwiftUI 修飾詞（`ImageFilterModifier`、`ObjectMaterialModifier`）；匯出走 UIKit/CoreGraphics，
//  原本**完全沒有畫它們** —— 使用者套了「復古」或「黃金」的圖，匯出來是原圖。這裡把同一組數字用逐像素運算
//  重做一遍，順序也照畫布（先濾鏡、再材質、最後蓋上漸層）。數字改了要兩邊一起改。
//

import UIKit

enum ImageEffects {

    private enum Step {
        /// SwiftUI `colorMultiply`。
        case multiply(CGFloat, CGFloat, CGFloat)
        case contrast(CGFloat)
        case saturation(CGFloat)
        /// SwiftUI `grayscale(amount)`：以飽和度 `1 - amount` 近似。
        case grayscale(CGFloat)
        case brightness(CGFloat)
    }

    struct Overlay {
        var colors: [UIColor]
        var start: CGPoint
        var end: CGPoint
    }

    private static func steps(for filter: ImageFilterStyle) -> [Step] {
        switch filter {
        case .original: return []
        case .vintage: return [.multiply(0.95, 0.88, 0.75), .contrast(1.1), .saturation(0.8)]
        case .mono: return [.grayscale(1.0), .contrast(1.2)]
        case .contrast: return [.contrast(1.3), .saturation(1.2)]
        case .warm: return [.multiply(1.0, 0.93, 0.85), .brightness(0.04)]
        }
    }

    private static let diagonal = (start: CGPoint(x: 0, y: 0), end: CGPoint(x: 1, y: 1))
    private static let vertical = (start: CGPoint(x: 0.5, y: 0), end: CGPoint(x: 0.5, y: 1))

    private static func steps(for material: MaterialType) -> [Step] {
        switch material {
        case .plastic: return [.saturation(1.25), .contrast(1.1)]
        case .gold: return [.multiply(1.0, 0.90, 0.65), .contrast(1.18), .saturation(1.3)]
        case .silver: return [.grayscale(0.95), .contrast(1.25), .brightness(0.08)]
        case .copper: return [.multiply(0.95, 0.72, 0.55), .contrast(1.15), .saturation(1.2)]
        case .iron: return [.grayscale(0.85), .contrast(1.3), .brightness(-0.06)]
        case .wood: return [.multiply(0.85, 0.68, 0.50), .contrast(1.12), .saturation(0.9)]
        case .marble: return [.brightness(0.06), .contrast(1.1), .saturation(0.7)]
        case .granite: return [.grayscale(0.65), .contrast(1.35)]
        case .obsidian: return [.brightness(-0.15), .contrast(1.4), .saturation(0.5)]
        }
    }

    static func overlay(for material: MaterialType) -> Overlay {
        func o(_ a: UIColor, _ b: UIColor, _ c: UIColor, vertical v: Bool = false) -> Overlay {
            let g = v ? vertical : diagonal
            return Overlay(colors: [a, b, c], start: g.start, end: g.end)
        }
        let clear = UIColor.clear
        switch material {
        case .plastic:
            return o(UIColor.white.withAlphaComponent(0.18), clear, UIColor.white.withAlphaComponent(0.08))
        case .gold:
            return o(UIColor.systemYellow.withAlphaComponent(0.25), clear, UIColor.systemOrange.withAlphaComponent(0.2))
        case .silver:
            return o(UIColor.white.withAlphaComponent(0.3), clear, UIColor.white.withAlphaComponent(0.15))
        case .copper:
            return o(UIColor.systemOrange.withAlphaComponent(0.2), clear, UIColor.systemRed.withAlphaComponent(0.15))
        case .iron:
            return o(UIColor.black.withAlphaComponent(0.12), clear, UIColor.white.withAlphaComponent(0.1), vertical: true)
        case .wood:
            return o(UIColor.brown.withAlphaComponent(0.18), clear, UIColor.brown.withAlphaComponent(0.12))
        case .marble:
            return o(UIColor.white.withAlphaComponent(0.22), UIColor.gray.withAlphaComponent(0.06),
                     UIColor.white.withAlphaComponent(0.18))
        case .granite:
            return o(UIColor.gray.withAlphaComponent(0.15), clear, UIColor.black.withAlphaComponent(0.12), vertical: true)
        case .obsidian:
            return o(UIColor.white.withAlphaComponent(0.22), UIColor.black.withAlphaComponent(0.4), clear)
        }
    }

    /// 套上濾鏡與材質（照畫布的順序）。沒有任何效果時原樣回傳。
    ///
    /// 用 CPU 逐像素算，**不用 CoreImage**：CoreImage 第一次建立 context／編譯 kernel 在模擬器與 CI 上要好幾分鐘
    /// （實測 3 分鐘），而這裡的運算只是幾個乘加。圖片再大也是一次線性掃描。
    static func apply(filter: ImageFilterStyle, material: MaterialType?, to image: UIImage) -> UIImage {
        var all = steps(for: filter)
        if let material { all += steps(for: material) }
        guard !all.isEmpty, let cg = image.cgImage else { return image }

        let width = cg.width, height = cg.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let ctx = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return image }

        // 亮度權重與 CoreImage／SwiftUI 的飽和度相同（Rec.709）。
        func luma(_ r: Float, _ g: Float, _ b: Float) -> Float { 0.2126 * r + 0.7152 * g + 0.0722 * b }
        for i in stride(from: 0, to: bytes.count, by: 4) {
            let alpha = Float(bytes[i + 3]) / 255
            guard alpha > 0 else { continue }
            // 預乘 → 還原成直通 alpha 再算。
            var r = Float(bytes[i]) / 255 / alpha
            var g = Float(bytes[i + 1]) / 255 / alpha
            var b = Float(bytes[i + 2]) / 255 / alpha
            for step in all {
                switch step {
                case let .multiply(mr, mg, mb):
                    r *= Float(mr); g *= Float(mg); b *= Float(mb)
                case let .contrast(c):
                    let k = Float(c)
                    r = (r - 0.5) * k + 0.5; g = (g - 0.5) * k + 0.5; b = (b - 0.5) * k + 0.5
                case let .saturation(sat):
                    let l = luma(r, g, b), k = Float(sat)
                    r = l + (r - l) * k; g = l + (g - l) * k; b = l + (b - l) * k
                case let .grayscale(a):
                    let l = luma(r, g, b), k = Float(1 - a)
                    r = l + (r - l) * k; g = l + (g - l) * k; b = l + (b - l) * k
                case let .brightness(d):
                    let k = Float(d)
                    r += k; g += k; b += k
                }
            }
            func out(_ v: Float) -> UInt8 { UInt8(max(0, min(1, v)) * alpha * 255 + 0.5) }
            bytes[i] = out(r); bytes[i + 1] = out(g); bytes[i + 2] = out(b)
        }

        let result: CGImage? = bytes.withUnsafeMutableBytes { buffer in
            CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.makeImage()
        }
        guard let result else { return image }
        return UIImage(cgImage: result, scale: image.scale, orientation: image.imageOrientation)
    }

    /// 材質的漸層蓋層（畫在已套濾鏡的圖片上、裁切之內）。
    static func drawOverlay(_ overlay: Overlay, in rect: CGRect, context cg: CGContext) {
        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: overlay.colors.map(\.cgColor) as CFArray,
            locations: [0, 0.5, 1]
        ) else { return }
        cg.saveGState()
        cg.clip(to: rect)
        cg.drawLinearGradient(
            gradient,
            start: CGPoint(x: rect.minX + overlay.start.x * rect.width, y: rect.minY + overlay.start.y * rect.height),
            end: CGPoint(x: rect.minX + overlay.end.x * rect.width, y: rect.minY + overlay.end.y * rect.height),
            options: [])
        cg.restoreGState()
    }
}
