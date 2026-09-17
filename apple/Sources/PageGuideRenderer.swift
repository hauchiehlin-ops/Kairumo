//
//  PageGuideRenderer.swift
//  Kairumo
//
//  版面引導線的繪製器。
//
//  # 為什麼獨立成一個檔案
//
//  同一份版面要畫在兩個地方：畫布（`TemplateBackedCanvasBackground`）與
//  頁面結構欄的縮圖（`PageThumbnailRenderer`）。各畫一份的結果是縮圖上
//  看不到康乃爾的分區線 —— 使用者在側欄裡分不出哪一頁是哪一種紙。
//
//  圖元本身來自核心的 `page_guides`，這裡只負責「線怎麼畫、字用什麼顏色」。
//  **核心只說輕重，不說顏色**：深色模式是平台的事，核心不需要知道。
//

import CoreGraphics
import UIKit

public enum PageGuideRenderer {

    /// 把某一張紙的版面畫進 `ctx`。
    ///
    /// `size` 是頁面尺寸（不是畫布尺寸）—— 畫布在寬螢幕上比頁面寬，
    /// 用畫布尺寸算的話引導線會一路畫到紙的外面。
    public static func draw(
        paperId: String,
        paletteId: String?,
        in ctx: CGContext,
        size: CGSize
    ) {
        guard size.width > 0, size.height > 0 else { return }
        let colors = Palette(id: paletteId)
        let guides = pageGuides(
            paperId: paperId,
            width: Float(size.width),
            height: Float(size.height)
        )
        guard !guides.isEmpty else { return }

        for g in guides {
            let x = CGFloat(g.x), y = CGFloat(g.y)
            let w = CGFloat(g.w), h = CGFloat(g.h)
            switch g.kind {
            case .line:
                ctx.setStrokeColor(colors.color(g.tone).cgColor)
                ctx.setLineWidth(CGFloat(g.weight))
                ctx.move(to: CGPoint(x: x, y: y))
                ctx.addLine(to: CGPoint(x: x + w, y: y + h))
                ctx.strokePath()

            case .rect:
                ctx.setStrokeColor(colors.color(g.tone).cgColor)
                ctx.setLineWidth(CGFloat(g.weight))
                ctx.addPath(rounded(x, y, w, h, CGFloat(g.size)))
                ctx.strokePath()

            case .fillRect:
                // 標題底色條。它是背景，不是內容 —— 所以是配色裡最淡的那一個。
                ctx.setFillColor(colors.band.cgColor)
                ctx.addPath(rounded(x, y, w, h, CGFloat(g.size)))
                ctx.fillPath()

            case .checkbox:
                ctx.setStrokeColor(colors.color(.light).cgColor)
                ctx.setLineWidth(1.0)
                ctx.addPath(rounded(x, y, w, h, min(3, w * 0.25)))
                ctx.strokePath()

            case .dot:
                ctx.setFillColor(colors.color(g.tone).cgColor)
                ctx.fillEllipse(in: CGRect(x: x, y: y, width: w, height: w))

            case .label:
                label(g, at: CGPoint(x: x, y: y), colors: colors)
            }
        }
    }

    private static func rounded(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> CGPath {
        UIBezierPath(
            roundedRect: CGRect(x: x, y: y, width: w, height: h),
            cornerRadius: max(0, r)
        ).cgPath
    }

    private static func label(_ g: FfiGuide, at point: CGPoint, colors: Palette) {
        let text = MainActor.assumeIsolated { LocalizationManager.shared.localized(g.textKey) }
        guard !text.isEmpty else { return }
        // 縮圖上的頁面只有兩百多點寬，字級照比例縮下去會小於一個像素。
        // 下限不是為了好看，是為了「畫了等於沒畫」。
        let size = max(6, CGFloat(g.size))
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: size, weight: .medium),
            .foregroundColor: colors.color(.muted)
        ]
        let measured = (text as NSString).size(withAttributes: attrs)
        // `x` 是錨點，不是左上角 —— 置中的欄位標題要以中心對齊。
        let originX: CGFloat
        switch g.align {
        case 1: originX = point.x - measured.width / 2
        case 2: originX = point.x - measured.width
        default: originX = point.x
        }
        (text as NSString).draw(
            at: CGPoint(x: originX, y: point.y - measured.height),
            withAttributes: attrs
        )
    }

    /// 一組配色。
    ///
    /// **色相來自核心**（使用者選的那一組），**深淺留在這裡** ——
    /// 同一個色相在深色模式下要淡得多，而那是平台的事，核心不需要知道
    /// 現在是不是深色。
    struct Palette {
        let accent: UIColor
        let band: UIColor
        let line: UIColor
        let text: UIColor

        init(id: String?) {
            let p = guidePalette(id: id ?? "")
            accent = UIColor(hexString: p.accentHex) ?? .systemIndigo
            band = UIColor(hexString: p.bandHex) ?? UIColor.secondarySystemFill
            line = UIColor(hexString: p.lineHex) ?? .secondaryLabel
            text = UIColor(hexString: p.textHex) ?? .secondaryLabel
        }

        func color(_ tone: FfiGuideTone) -> UIColor {
            switch tone {
            case .hairline: return line.withAlphaComponent(0.30)
            case .light: return line.withAlphaComponent(0.55)
            case .accent: return accent.withAlphaComponent(0.75)
            case .muted: return text.withAlphaComponent(0.85)
            }
        }
    }
}
