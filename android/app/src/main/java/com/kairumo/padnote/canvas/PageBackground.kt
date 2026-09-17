package com.kairumo.padnote.canvas

import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.unit.sp
import com.kairumo.padnote.ink.PageGeometry
import uniffi.padnote_core.FfiGuideKind
import uniffi.padnote_core.FfiGuideTone
import uniffi.padnote_core.PageStyle
import uniffi.padnote_core.pageGuides

/**
 * 紙張底紋。
 *
 * # 為什麼在此之前沒有
 *
 * `add_page(style)` 一直把底紋寫進 `.padnote`，但核心**沒有把它讀回來的
 * 出口**（`page_style` 是這次才加的），所以 Android 每一頁都是白紙 ——
 * 使用者在「新增筆記」裡選了「方格點陣」或「康乃爾」，畫面上完全看不出
 * 差別，而同一本筆記在 Apple 上是有底紋的。
 *
 * # 為什麼只有六種
 *
 * 核心的 `PageStyle` 就是這六種，而它是**存進使用者檔案裡**的那一個列舉。
 * 介面上的十三種紙張是它的上層分類（見核心 `paper_templates`）：
 * 「工程藍圖」與「方格點陣」都落在 `Grid`。Apple 端另外畫了藍圖標題欄、
 * 等角軸測、手機線框這些**額外裝飾**，那一層 Android 還沒有 —— 但底紋
 * 本身從這裡開始是對齊的。
 *
 * 顏色一律很淡：底紋是拿來對齊的參考線，不是內容。壓過筆跡就本末倒置。
 */
@Composable
fun PageBackground(
    style: PageStyle,
    modifier: Modifier = Modifier,
    pageWidth: Float = PageGeometry.width,
    pageHeight: Float = PageGeometry.height
) {
    Canvas(modifier = modifier) {
        val density = if (pageWidth > 0f) size.width / pageWidth else 1f
        drawPageBackground(style, density, pageWidth, pageHeight)
    }
}

/**
 * 在既有的繪製範圍裡畫底紋。
 *
 * 給 `InkCanvas` 直接呼叫 —— 底紋必須畫在它自己的白底之上、筆跡之下，
 * 疊一層 Composable 在外面會被那層白底整個蓋掉。
 */
fun DrawScope.drawPageBackground(
    style: PageStyle,
    /**
     * 每個頁面單位對應幾個像素。
     *
     * **不能用 `size.width / pageWidth` 推。** 畫布這個 View 比頁面寬
     * （頁面只占它的左上角），用 View 的寬度算出來的倍率會把底紋放大，
     * 線條一路畫到頁面外面去 —— 實機上看到的就是格線跑到紙的右邊。
     * 與 `drawPageBoundary(density)` 用同一個倍率才會對齊。
     */
    density: Float,
    pageWidth: Float = PageGeometry.width,
    pageHeight: Float = PageGeometry.height,
    /**
     * 這張紙的識別字（核心 `paperTemplates()` 的 id）。
     *
     * 底紋只有六種，而紙張有三十幾種 —— 「康乃爾」與「四象限」的 `PageStyle`
     * 都是 BLANK，差別在**版面**。版面由核心的 `pageGuides` 供應。
     */
    paperId: String = "",
    /** 版面上的文字要翻譯。沒有它的話欄位標題會是一串語系鍵。 */
    localize: (String) -> String = { it },
    textMeasurer: TextMeasurer? = null
) {
    drawPageStyle(style, density, pageWidth, pageHeight)
    if (paperId.isNotEmpty()) {
        drawPageGuides(paperId, density, pageWidth, pageHeight, localize, textMeasurer)
    }
}

/**
 * 版面引導線。
 *
 * # 為什麼是核心送資料過來
 *
 * Apple 端原本用一個 `switch template` 搭配 CoreGraphics，十三種紙就是十三段
 * 手寫的繪圖程式碼；Android 這邊**只畫得出底紋**，藍圖標題欄、手機線框那一層
 * 完全沒有 —— 同一本筆記在兩台裝置上長得不一樣。
 *
 * 現在核心回傳一串圖元（線、框、文字、勾選框、點），兩邊各自只認得這六種
 * 怎麼畫。新增一種紙是改核心，兩邊同時就有。
 *
 * **核心只說輕重，不說顏色**：深色模式是平台的事。
 */
private fun DrawScope.drawPageGuides(
    paperId: String,
    scale: Float,
    pageWidth: Float,
    pageHeight: Float,
    localize: (String) -> String,
    textMeasurer: TextMeasurer?
) {
    val guides = runCatching { pageGuides(paperId, pageWidth, pageHeight) }.getOrNull() ?: return
    for (g in guides) {
        val x = g.x * scale
        val y = g.y * scale
        val w = g.w * scale
        val h = g.h * scale
        when (g.kind) {
            FfiGuideKind.LINE -> drawLine(
                guideColor(g.tone),
                Offset(x, y),
                Offset(x + w, y + h),
                strokeWidth = g.weight
            )

            FfiGuideKind.RECT -> drawRoundRect(
                color = guideColor(g.tone),
                topLeft = Offset(x, y),
                size = Size(w, h),
                cornerRadius = CornerRadius(g.size * scale),
                style = Stroke(width = g.weight)
            )

            FfiGuideKind.FILL_RECT -> drawRoundRect(
                // 標題底色條。比最淡的線還淡 —— 它是背景，不是內容。
                color = Color(0x0F000000),
                topLeft = Offset(x, y),
                size = Size(w, h),
                cornerRadius = CornerRadius(g.size * scale)
            )

            FfiGuideKind.CHECKBOX -> drawRoundRect(
                color = guideColor(FfiGuideTone.LIGHT),
                topLeft = Offset(x, y),
                size = Size(w, h),
                cornerRadius = CornerRadius(minOf(3f * scale, w * 0.25f)),
                style = Stroke(width = 1f)
            )

            FfiGuideKind.DOT -> drawCircle(
                guideColor(g.tone),
                radius = w / 2f,
                center = Offset(x + w / 2f, y + w / 2f)
            )

            FfiGuideKind.LABEL -> {
                val measurer = textMeasurer ?: continue
                val text = localize(g.textKey)
                if (text.isEmpty()) continue
                // 縮圖上的頁面只有兩百多點寬，字級照比例縮下去會小於一個像素。
                // 下限不是為了好看，是為了「畫了等於沒畫」。
                val fontPx = maxOf(6f, g.size * scale)
                val layout = measurer.measure(
                    text = AnnotatedString(text),
                    style = TextStyle(fontSize = (fontPx / density).sp)
                )
                // `x` 是錨點，不是左上角 —— 置中的欄位標題要以中心對齊。
                val originX = when (g.align.toInt()) {
                    1 -> x - layout.size.width / 2f
                    2 -> x - layout.size.width
                    else -> x
                }
                drawText(
                    textLayoutResult = layout,
                    color = guideColor(FfiGuideTone.MUTED),
                    topLeft = Offset(originX, y - layout.size.height)
                )
            }
        }
    }
}

private fun guideColor(tone: FfiGuideTone): Color = when (tone) {
    FfiGuideTone.HAIRLINE -> Color(0x24000000)
    FfiGuideTone.LIGHT -> Color(0x47000000)
    FfiGuideTone.ACCENT -> Color(0x733F51B5)
    FfiGuideTone.MUTED -> Color(0xA6000000)
}

/** 與 Apple 端 `NotebookEditorView` 的底紋繪製對應的六種。 */
private fun DrawScope.drawPageStyle(
    style: PageStyle,
    scale: Float,
    pageWidth: Float,
    pageHeight: Float
) {
    val w = pageWidth * scale
    val h = pageHeight * scale
    val line = Color(0x1A000000)
    val accent = Color(0x33448AFF)

    when (style) {
        PageStyle.BLANK -> Unit

        PageStyle.LINED -> {
            // 行高 32pt，與 Apple 端相同 —— 兩邊不同的話，同一本筆記
            // 在兩台裝置上「寫在第幾行」會對不起來。
            val step = 32f * scale
            var y = step
            while (y < h) {
                drawLine(line, Offset(0f, y), Offset(w, y), strokeWidth = 1f)
                y += step
            }
        }

        PageStyle.GRID -> {
            val step = 24f * scale
            var x = step
            while (x < w) {
                drawLine(line, Offset(x, 0f), Offset(x, h), strokeWidth = 1f)
                x += step
            }
            var y = step
            while (y < h) {
                drawLine(line, Offset(0f, y), Offset(w, y), strokeWidth = 1f)
                y += step
            }
        }

        PageStyle.DOTTED -> {
            val step = 16f * scale
            val radius = 1.2f
            var x = step
            while (x < w) {
                var y = step
                while (y < h) {
                    drawCircle(line, radius = radius, center = Offset(x, y))
                    y += step
                }
                x += step
            }
        }

        PageStyle.CORNELL -> {
            // 左側提綱欄、底部總結欄。比例與 Apple 端相同。
            val cueX = w * 0.3f
            val summaryY = h * 0.8f
            drawLine(accent, Offset(cueX, 0f), Offset(cueX, summaryY), strokeWidth = 2f)
            drawLine(accent, Offset(0f, summaryY), Offset(w, summaryY), strokeWidth = 2f)
            // 主體區的橫線只畫在右邊那一欄裡。
            val step = 32f * scale
            var y = step
            while (y < summaryY) {
                drawLine(line, Offset(cueX, y), Offset(w, y), strokeWidth = 1f)
                y += step
            }
        }

        PageStyle.MUSIC_STAFF -> {
            // 五線譜：五條一組，組間留白。
            val lineGap = 10f * scale
            val groupGap = 48f * scale
            var top = groupGap
            while (top + lineGap * 4 < h) {
                for (i in 0..4) {
                    val y = top + lineGap * i
                    drawLine(line, Offset(0f, y), Offset(w, y), strokeWidth = 1f)
                }
                top += lineGap * 4 + groupGap
            }
        }
    }

    // 頁緣。沒有它的話，縮小之後看不出一頁到哪裡結束。
    drawRect(
        color = Color(0x14000000),
        topLeft = Offset.Zero,
        size = Size(w, h),
        style = Stroke(width = 1f)
    )
}
