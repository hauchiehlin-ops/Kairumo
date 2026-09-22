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

    /// 把某一張紙的**底紋**畫進 `ctx`。
    ///
    /// # 為什麼底紋也走核心了
    ///
    /// 這一層本來兩端各寫一次，理由是量（5mm 點陣是兩千多個點，
    /// 一顆顆送過 FFI 只是浪費）。理由對、結論錯：實際量過之後，方格
    /// 間距 Apple 28／Android 24、點陣 20／16、五線譜行距 9／10 ——
    /// 同一本方格筆記在兩台裝置上「寫在第幾格」對不起來，而那是使用者
    /// 拿方格紙的唯一理由。
    ///
    /// 核心現在送的是**格子的描述**（`page_texture`）而不是格子本身：
    /// 一族圖元 ＝ 第一個 ＋ 兩個位移向量 ＋ 兩個次數。下面這個雙層迴圈
    /// 就是全部的畫法，Android 端是同一份。
    public static func drawTexture(
        paperId: String,
        style: PageStyle,
        paletteId: String?,
        in ctx: CGContext,
        size: CGSize
    ) {
        guard size.width > 0, size.height > 0 else { return }
        let colors = Palette(id: paletteId)
        let bands = pageTexture(
            paperId: paperId,
            style: style,
            width: Float(size.width),
            height: Float(size.height)
        )
        for b in bands {
            let color = colors.color(b.tone)
            ctx.setStrokeColor(color.cgColor)
            ctx.setFillColor(color.cgColor)
            ctx.setLineWidth(CGFloat(b.weight))
            for i in 0..<Int(b.count) {
                for j in 0..<Int(b.count2) {
                    let fi = Float(i)
                    let fj = Float(j)
                    let px: CGFloat = CGFloat(b.x + b.stepX * fi + b.step2X * fj)
                    let py: CGFloat = CGFloat(b.y + b.stepY * fi + b.step2Y * fj)
                    switch b.kind {
                    case .line:
                        ctx.move(to: CGPoint(x: px, y: py))
                        ctx.addLine(to: CGPoint(x: px + CGFloat(b.w), y: py + CGFloat(b.h)))
                    case .dot:
                        let d = CGFloat(b.w)
                        ctx.fillEllipse(in: CGRect(x: px - d / 2, y: py - d / 2, width: d, height: d))
                    }
                }
            }
            if b.kind == .line { ctx.strokePath() }
        }
    }

    private static func rounded(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> CGPath {
        UIBezierPath(
            roundedRect: CGRect(x: x, y: y, width: w, height: h),
            cornerRadius: max(0, r)
        ).cgPath
    }

    private static func label(_ g: FfiGuide, at point: CGPoint, colors: Palette) {
        // `localizedUnsafe` 而不是 `assumeIsolated { localized }`：縮圖與
        // 匯出都可能在背景執行緒上畫，後者在那裡會直接 trap，而且編譯器
        // 不會警告 —— `assumeIsolated` 的意思正是「我保證這裡是主執行緒」。
        let text = LocalizationManager.shared.localizedUnsafe(g.textKey)
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
