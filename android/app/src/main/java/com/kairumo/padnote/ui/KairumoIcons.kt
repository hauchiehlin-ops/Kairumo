package com.kairumo.padnote.ui

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.path
import androidx.compose.ui.unit.dp

/**
 * 跨平台對齊之原生向量圖示集（對齊 Apple SF Symbols 設計語言）。
 *
 * # 為什麼不使用文字符號或 Emoji
 *
 * 原本畫的是「🏠」「📖」「⤢」「◎」「💻」「↶」「↷」「🎬」「📌」「📄」「📜」「👥」「🎙️」「⇪」
 * 等字元與 Emoji。字元會依各家 Android 廠牌字型差異變形、基線失準、色調突兀，
 * 是「看起來太有 AI 味 / 半成品感」的最直接來源。
 *
 * 這裡以細緻的高對比向量線條（1.7f ~ 1.8f 筆線寬，圓角端點），
 * 完全對齊 Apple SF Symbols 的外型與視覺重心。
 */
object KairumoIcons {

    /** 首頁（對齊 Apple house.fill）。 */
    val Home: ImageVector by lazy {
        ImageVector.Builder(
            name = "KairumoHome",
            defaultWidth = 24.dp, defaultHeight = 24.dp,
            viewportWidth = 24f, viewportHeight = 24f
        ).apply {
            path(
                stroke = SolidColor(Color.Black),
                strokeLineWidth = 1.8f,
                strokeLineCap = StrokeCap.Round,
                strokeLineJoin = StrokeJoin.Round
            ) {
                moveTo(3.5f, 10.5f)
                lineTo(12f, 3.5f)
                lineTo(20.5f, 10.5f)
                verticalLineTo(20f)
                curveTo(20.5f, 20.6f, 20.1f, 21f, 19.5f, 21f)
                horizontalLineTo(15f)
                verticalLineTo(14.5f)
                horizontalLineTo(9f)
                verticalLineTo(21f)
                horizontalLineTo(4.5f)
                curveTo(3.9f, 21f, 3.5f, 20.6f, 3.5f, 20f)
                close()
            }
        }.build()
    }

    /** 側欄展開／收合開關（對齊 Apple sidebar.left）。 */
    val Sidebar: ImageVector by lazy {
        ImageVector.Builder(
            name = "KairumoSidebar",
            defaultWidth = 24.dp, defaultHeight = 24.dp,
            viewportWidth = 24f, viewportHeight = 24f
        ).apply {
            path(
                stroke = SolidColor(Color.Black),
                strokeLineWidth = 1.7f,
                strokeLineCap = StrokeCap.Round,
                strokeLineJoin = StrokeJoin.Round
            ) {
                moveTo(4f, 4.5f)
                curveTo(4f, 3.7f, 4.7f, 3f, 5.5f, 3f)
                horizontalLineTo(18.5f)
                curveTo(19.3f, 3f, 20f, 3.7f, 20f, 4.5f)
                verticalLineTo(19.5f)
                curveTo(20f, 20.3f, 19.3f, 21f, 18.5f, 21f)
                horizontalLineTo(5.5f)
                curveTo(4.7f, 21f, 4f, 20.3f, 4f, 19.5f)
                close()
                moveTo(9f, 3f)
                verticalLineTo(21f)
            }
        }.build()
    }

    /** 進入極簡全螢幕畫布（對齊 Apple arrow.up.left.and.arrow.down.right）。 */
    val Fullscreen: ImageVector by lazy {
        ImageVector.Builder(
            name = "KairumoFullscreen",
            defaultWidth = 24.dp, defaultHeight = 24.dp,
            viewportWidth = 24f, viewportHeight = 24f
        ).apply {
            path(
                stroke = SolidColor(Color.Black),
                strokeLineWidth = 1.8f,
                strokeLineCap = StrokeCap.Round,
                strokeLineJoin = StrokeJoin.Round
            ) {
                // 左上擴展箭頭
                moveTo(9f, 4f)
                horizontalLineTo(4f)
                verticalLineTo(9f)
                moveTo(4f, 4f)
                lineTo(10f, 10f)
                // 右下擴展箭頭
                moveTo(15f, 20f)
                horizontalLineTo(20f)
                verticalLineTo(15f)
                moveTo(20f, 20f)
                lineTo(14f, 14f)
            }
        }.build()
    }

    /** 退出全螢幕（對齊 Apple arrow.down.right.and.arrow.up.left）。 */
    val FullscreenExit: ImageVector by lazy {
        ImageVector.Builder(
            name = "KairumoFullscreenExit",
            defaultWidth = 24.dp, defaultHeight = 24.dp,
            viewportWidth = 24f, viewportHeight = 24f
        ).apply {
            path(
                stroke = SolidColor(Color.Black),
                strokeLineWidth = 1.8f,
                strokeLineCap = StrokeCap.Round,
                strokeLineJoin = StrokeJoin.Round
            ) {
                moveTo(4f, 10f)
                horizontalLineTo(10f)
                verticalLineTo(4f)
                moveTo(10f, 10f)
                lineTo(4.5f, 4.5f)

                moveTo(20f, 14f)
                horizontalLineTo(14f)
                verticalLineTo(20f)
                moveTo(14f, 14f)
                lineTo(19.5f, 19.5f)
            }
        }.build()
    }

    /** 復原（對齊 Apple arrow.uturn.backward）。 */
    val Undo: ImageVector by lazy {
        ImageVector.Builder(
            name = "KairumoUndo",
            defaultWidth = 24.dp, defaultHeight = 24.dp,
            viewportWidth = 24f, viewportHeight = 24f
        ).apply {
            path(
                stroke = SolidColor(Color.Black),
                strokeLineWidth = 1.8f,
                strokeLineCap = StrokeCap.Round,
                strokeLineJoin = StrokeJoin.Round
            ) {
                moveTo(7.5f, 8f)
                lineTo(3.5f, 12f)
                lineTo(7.5f, 16f)
                moveTo(4.5f, 12f)
                horizontalLineTo(14.5f)
                curveTo(17.8f, 12f, 20.5f, 14.5f, 20.5f, 17.5f)
            }
        }.build()
    }

    /** 重做（對齊 Apple arrow.uturn.forward）。 */
    val Redo: ImageVector by lazy {
        ImageVector.Builder(
            name = "KairumoRedo",
            defaultWidth = 24.dp, defaultHeight = 24.dp,
            viewportWidth = 24f, viewportHeight = 24f
        ).apply {
            path(
                stroke = SolidColor(Color.Black),
                strokeLineWidth = 1.8f,
                strokeLineCap = StrokeCap.Round,
                strokeLineJoin = StrokeJoin.Round
            ) {
                moveTo(16.5f, 8f)
                lineTo(20.5f, 12f)
                lineTo(16.5f, 16f)
                moveTo(19.5f, 12f)
                horizontalLineTo(9.5f)
                curveTo(6.2f, 12f, 3.5f, 14.5f, 3.5f, 17.5f)
            }
        }.build()
    }

    /** 重設回初始狀態（對齊 Apple arrow.counterclockwise）。 */
    val Revert: ImageVector by lazy {
        ImageVector.Builder(
            name = "KairumoRevert",
            defaultWidth = 24.dp, defaultHeight = 24.dp,
            viewportWidth = 24f, viewportHeight = 24f
        ).apply {
            path(
                stroke = SolidColor(Color.Black),
                strokeLineWidth = 1.8f,
                strokeLineCap = StrokeCap.Round,
                strokeLineJoin = StrokeJoin.Round
            ) {
                moveTo(4f, 4f)
                verticalLineTo(9f)
                horizontalLineTo(9f)
                moveTo(5.5f, 14.5f)
                arcTo(8f, 8f, 0f, true, false, 8f, 6.5f)
                lineTo(4f, 9f)
            }
        }.build()
    }

    /** 留言圖釘（對齊 Apple pin.fill / pin.circle.fill）。 */
    val PushPin: ImageVector by lazy {
        ImageVector.Builder(
            name = "KairumoPushPin",
            defaultWidth = 24.dp, defaultHeight = 24.dp,
            viewportWidth = 24f, viewportHeight = 24f
        ).apply {
            path(
                stroke = SolidColor(Color.Black),
                strokeLineWidth = 1.7f,
                strokeLineCap = StrokeCap.Round,
                strokeLineJoin = StrokeJoin.Round
            ) {
                moveTo(16f, 4f)
                lineTo(20f, 8f)
                lineTo(17f, 11f)
                lineTo(18f, 15f)
                lineTo(13f, 15f)
                lineTo(9f, 19f)
                moveTo(13f, 15f)
                lineTo(9f, 11f)
                lineTo(9f, 6f)
                lineTo(13f, 7f)
                close()
                moveTo(9f, 19f)
                lineTo(4f, 21f)
                lineTo(6f, 16f)
            }
        }.build()
    }

    /** 單頁模式（對齊 Apple doc.text）。 */
    val PageSingle: ImageVector by lazy {
        ImageVector.Builder(
            name = "KairumoPageSingle",
            defaultWidth = 24.dp, defaultHeight = 24.dp,
            viewportWidth = 24f, viewportHeight = 24f
        ).apply {
            path(
                stroke = SolidColor(Color.Black),
                strokeLineWidth = 1.7f,
                strokeLineCap = StrokeCap.Round,
                strokeLineJoin = StrokeJoin.Round
            ) {
                moveTo(6f, 3f)
                horizontalLineTo(14f)
                lineTo(19f, 8f)
                verticalLineTo(20.5f)
                curveTo(19f, 21.3f, 18.3f, 22f, 17.5f, 22f)
                horizontalLineTo(6.5f)
                curveTo(5.7f, 22f, 5f, 21.3f, 5f, 20.5f)
                verticalLineTo(4.5f)
                curveTo(5f, 3.7f, 5.7f, 3f, 6.5f, 3f)
                close()
                moveTo(14f, 3f)
                verticalLineTo(8f)
                horizontalLineTo(19f)
                moveTo(8.5f, 13f)
                horizontalLineTo(15.5f)
                moveTo(8.5f, 17f)
                horizontalLineTo(13.5f)
            }
        }.build()
    }

    /** 連續捲動頁面模式（對齊 Apple rectangle.split.1x2）。 */
    val PageContinuous: ImageVector by lazy {
        ImageVector.Builder(
            name = "KairumoPageContinuous",
            defaultWidth = 24.dp, defaultHeight = 24.dp,
            viewportWidth = 24f, viewportHeight = 24f
        ).apply {
            path(
                stroke = SolidColor(Color.Black),
                strokeLineWidth = 1.7f,
                strokeLineCap = StrokeCap.Round,
                strokeLineJoin = StrokeJoin.Round
            ) {
                moveTo(5f, 3.5f)
                curveTo(5f, 2.7f, 5.7f, 2f, 6.5f, 2f)
                horizontalLineTo(17.5f)
                curveTo(18.3f, 2f, 19f, 2.7f, 19f, 3.5f)
                verticalLineTo(10.5f)
                curveTo(19f, 11.3f, 18.3f, 12f, 17.5f, 12f)
                horizontalLineTo(6.5f)
                curveTo(5.7f, 12f, 5f, 11.3f, 5f, 10.5f)
                close()

                moveTo(5f, 13.5f)
                curveTo(5f, 12.7f, 5.7f, 12f, 6.5f, 12f)
                horizontalLineTo(17.5f)
                curveTo(18.3f, 12f, 19f, 12.7f, 19f, 13.5f)
                verticalLineTo(20.5f)
                curveTo(19f, 21.3f, 18.3f, 22f, 17.5f, 22f)
                horizontalLineTo(6.5f)
                curveTo(5.7f, 22f, 5f, 21.3f, 5f, 20.5f)
                close()
            }
        }.build()
    }

    /** 快速輪盤選單（對齊 Apple circle.circle / circle.circle.fill）。 */
    val RadialMenu: ImageVector by lazy {
        ImageVector.Builder(
            name = "KairumoRadialMenu",
            defaultWidth = 24.dp, defaultHeight = 24.dp,
            viewportWidth = 24f, viewportHeight = 24f
        ).apply {
            path(
                stroke = SolidColor(Color.Black),
                strokeLineWidth = 1.8f,
                strokeLineCap = StrokeCap.Round
            ) {
                moveTo(12f, 2f)
                arcToRelative(10f, 10f, 0f, true, true, -0.01f, 0f)
                close()
                moveTo(12f, 7f)
                arcToRelative(5f, 5f, 0f, true, true, -0.01f, 0f)
                close()
            }
            path(fill = SolidColor(Color.Black)) {
                moveTo(12f, 10.5f)
                arcToRelative(1.5f, 1.5f, 0f, true, true, -0.01f, 0f)
                close()
            }
        }.build()
    }

    /** 創作工作盤 - 筆電立起（對齊 Apple laptopcomputer.and.ipad）。 */
    val TabletopLaptop: ImageVector by lazy {
        ImageVector.Builder(
            name = "KairumoTabletopLaptop",
            defaultWidth = 24.dp, defaultHeight = 24.dp,
            viewportWidth = 24f, viewportHeight = 24f
        ).apply {
            path(
                stroke = SolidColor(Color.Black),
                strokeLineWidth = 1.7f,
                strokeLineCap = StrokeCap.Round,
                strokeLineJoin = StrokeJoin.Round
            ) {
                moveTo(4f, 6f)
                curveTo(4f, 4.9f, 4.9f, 4f, 6f, 4f)
                horizontalLineTo(18f)
                curveTo(19.1f, 4f, 20f, 4.9f, 20f, 6f)
                verticalLineTo(15f)
                horizontalLineTo(4f)
                close()
                moveTo(2f, 18f)
                curveTo(2f, 17f, 2.8f, 16f, 3.8f, 16f)
                horizontalLineTo(20.2f)
                curveTo(21.2f, 16f, 22f, 17f, 22f, 18f)
                verticalLineTo(19f)
                horizontalLineTo(2f)
                close()
            }
        }.build()
    }

    /** 創作工作盤 - 平放創作板（對齊 Apple ipad.landscape）。 */
    val TabletopTablet: ImageVector by lazy {
        ImageVector.Builder(
            name = "KairumoTabletopTablet",
            defaultWidth = 24.dp, defaultHeight = 24.dp,
            viewportWidth = 24f, viewportHeight = 24f
        ).apply {
            path(
                stroke = SolidColor(Color.Black),
                strokeLineWidth = 1.7f,
                strokeLineCap = StrokeCap.Round,
                strokeLineJoin = StrokeJoin.Round
            ) {
                moveTo(3f, 6.5f)
                curveTo(3f, 5.1f, 4.1f, 4f, 5.5f, 4f)
                horizontalLineTo(18.5f)
                curveTo(19.9f, 4f, 21f, 5.1f, 21f, 6.5f)
                verticalLineTo(17.5f)
                curveTo(21f, 18.9f, 19.9f, 20f, 18.5f, 20f)
                horizontalLineTo(5.5f)
                curveTo(4.1f, 20f, 3f, 18.9f, 3f, 17.5f)
                close()
                moveTo(19.5f, 12f)
                arcToRelative(0.5f, 0.5f, 0f, true, true, -0.01f, 0f)
            }
        }.build()
    }

    /** 線上多人協同（對齊 Apple person.2.fill）。 */
    val Group: ImageVector by lazy {
        ImageVector.Builder(
            name = "KairumoGroup",
            defaultWidth = 24.dp, defaultHeight = 24.dp,
            viewportWidth = 24f, viewportHeight = 24f
        ).apply {
            path(
                stroke = SolidColor(Color.Black),
                strokeLineWidth = 1.7f,
                strokeLineCap = StrokeCap.Round,
                strokeLineJoin = StrokeJoin.Round
            ) {
                // 主人像
                moveTo(9f, 7f)
                arcToRelative(4f, 4f, 0f, true, true, -0.01f, 0f)
                close()
                moveTo(2f, 20f)
                curveTo(2f, 16.5f, 5.1f, 14f, 9f, 14f)
                curveTo(12.9f, 14f, 16f, 16.5f, 16f, 20f)
                // 副人像
                moveTo(16f, 3.5f)
                arcToRelative(3.2f, 3.2f, 0f, false, true, 0f, 6.4f)
                moveTo(16.5f, 14f)
                curveTo(19f, 14.5f, 21f, 16.5f, 21f, 19.5f)
            }
        }.build()
    }

    /** 停止錄音（對齊 Apple stop.fill）。 */
    val Stop: ImageVector by lazy {
        ImageVector.Builder(
            name = "KairumoStop",
            defaultWidth = 24.dp, defaultHeight = 24.dp,
            viewportWidth = 24f, viewportHeight = 24f
        ).apply {
            path(fill = SolidColor(Color.Black)) {
                moveTo(6.5f, 6.5f)
                curveTo(6.5f, 5.4f, 7.4f, 4.5f, 8.5f, 4.5f)
                horizontalLineTo(15.5f)
                curveTo(16.6f, 4.5f, 17.5f, 5.4f, 17.5f, 6.5f)
                verticalLineTo(17.5f)
                curveTo(17.5f, 18.6f, 16.6f, 19.5f, 15.5f, 19.5f)
                horizontalLineTo(8.5f)
                curveTo(7.4f, 19.5f, 6.5f, 18.6f, 6.5f, 17.5f)
                close()
            }
        }.build()
    }

    /** 匯出與分享（對齊 Apple square.and.arrow.up）。 */
    val Share: ImageVector by lazy {
        ImageVector.Builder(
            name = "KairumoShare",
            defaultWidth = 24.dp, defaultHeight = 24.dp,
            viewportWidth = 24f, viewportHeight = 24f
        ).apply {
            path(
                stroke = SolidColor(Color.Black),
                strokeLineWidth = 1.8f,
                strokeLineCap = StrokeCap.Round,
                strokeLineJoin = StrokeJoin.Round
            ) {
                // 上升箭頭
                moveTo(12f, 2.5f)
                verticalLineTo(14.5f)
                moveTo(7.5f, 7f)
                lineTo(12f, 2.5f)
                lineTo(16.5f, 7f)
                // 托盤
                moveTo(4f, 11f)
                verticalLineTo(19.5f)
                curveTo(4f, 20.3f, 4.7f, 21f, 5.5f, 21f)
                horizontalLineTo(18.5f)
                curveTo(19.3f, 21f, 20f, 20.3f, 20f, 19.5f)
                verticalLineTo(11f)
            }
        }.build()
    }

    /** 手繪工作室（對齊 Apple pencil.tip）。 */
    val PencilTip: ImageVector by lazy {
        ImageVector.Builder(
            name = "KairumoPencilTip",
            defaultWidth = 24.dp, defaultHeight = 24.dp,
            viewportWidth = 24f, viewportHeight = 24f
        ).apply {
            path(
                stroke = SolidColor(Color.Black),
                strokeLineWidth = 1.8f,
                strokeLineCap = StrokeCap.Round,
                strokeLineJoin = StrokeJoin.Round
            ) {
                moveTo(12f, 2.5f)
                lineTo(19f, 13f)
                lineTo(15.5f, 21f)
                lineTo(8.5f, 21f)
                lineTo(5f, 13f)
                close()
                moveTo(12f, 2.5f)
                verticalLineTo(13f)
                moveTo(9f, 13f)
                horizontalLineTo(15f)
            }
        }.build()
    }

    /** 專業文字智庫（對齊 Apple doc.text）。 */
    val DocText: ImageVector by lazy {
        ImageVector.Builder(
            name = "KairumoDocText",
            defaultWidth = 24.dp, defaultHeight = 24.dp,
            viewportWidth = 24f, viewportHeight = 24f
        ).apply {
            path(
                stroke = SolidColor(Color.Black),
                strokeLineWidth = 1.7f,
                strokeLineCap = StrokeCap.Round,
                strokeLineJoin = StrokeJoin.Round
            ) {
                moveTo(5f, 4f)
                curveTo(5f, 2.9f, 5.9f, 2f, 7f, 2f)
                horizontalLineTo(17f)
                curveTo(18.1f, 2f, 19f, 2.9f, 19f, 4f)
                verticalLineTo(20f)
                curveTo(19f, 21.1f, 18.1f, 22f, 17f, 22f)
                horizontalLineTo(7f)
                curveTo(5.9f, 22f, 5f, 21.1f, 5f, 20f)
                close()
                moveTo(8.5f, 7f)
                horizontalLineTo(15.5f)
                moveTo(8.5f, 11f)
                horizontalLineTo(15.5f)
                moveTo(8.5f, 15f)
                horizontalLineTo(12.5f)
            }
        }.build()
    }

    /** 橡皮擦（對齊 Apple eraser）。 */
    val Eraser: ImageVector by lazy {
        ImageVector.Builder(
            name = "KairumoEraser",
            defaultWidth = 24.dp, defaultHeight = 24.dp,
            viewportWidth = 24f, viewportHeight = 24f
        ).apply {
            path(
                stroke = SolidColor(Color.Black),
                strokeLineWidth = 1.8f,
                strokeLineCap = StrokeCap.Round,
                strokeLineJoin = StrokeJoin.Round
            ) {
                moveTo(15.5f, 3.5f)
                lineTo(20.5f, 8.5f)
                lineTo(9.5f, 19.5f)
                lineTo(3.5f, 19.5f)
                lineTo(2.5f, 16.5f)
                close()
                moveTo(6.5f, 12.5f)
                lineTo(14f, 20f)
            }
        }.build()
    }

    /** 套索選取（對齊 Apple lasso）。 */
    val Lasso: ImageVector by lazy {
        ImageVector.Builder(
            name = "KairumoLasso",
            defaultWidth = 24.dp, defaultHeight = 24.dp,
            viewportWidth = 24f, viewportHeight = 24f
        ).apply {
            path(
                stroke = SolidColor(Color.Black),
                strokeLineWidth = 1.7f,
                strokeLineCap = StrokeCap.Round,
                strokeLineJoin = StrokeJoin.Round
            ) {
                moveTo(12f, 3.5f)
                curveTo(6f, 3.5f, 3.5f, 7.5f, 3.5f, 12f)
                curveTo(3.5f, 16.5f, 7.5f, 19f, 12.5f, 19f)
                curveTo(17f, 19f, 20.5f, 16f, 20.5f, 11.5f)
                curveTo(20.5f, 7f, 16.5f, 3.5f, 12f, 3.5f)
                close()
                moveTo(13f, 19f)
                curveTo(13.5f, 21.5f, 15f, 22f, 17f, 22f)
                curveTo(19f, 22f, 21f, 20f, 21f, 18.5f)
            }
        }.build()
    }

    /** 遮蔽膠帶（對齊 Apple bandage）。 */
    val Bandage: ImageVector by lazy {
        ImageVector.Builder(
            name = "KairumoBandage",
            defaultWidth = 24.dp, defaultHeight = 24.dp,
            viewportWidth = 24f, viewportHeight = 24f
        ).apply {
            path(
                stroke = SolidColor(Color.Black),
                strokeLineWidth = 1.7f,
                strokeLineCap = StrokeCap.Round,
                strokeLineJoin = StrokeJoin.Round
            ) {
                moveTo(6.5f, 3.5f)
                lineTo(20.5f, 17.5f)
                curveTo(21.8f, 18.8f, 21.8f, 20.9f, 20.5f, 22.2f)
                curveTo(19.2f, 23.5f, 17.1f, 23.5f, 15.8f, 22.2f)
                lineTo(1.8f, 8.2f)
                curveTo(0.5f, 6.9f, 0.5f, 4.8f, 1.8f, 3.5f)
                curveTo(3.1f, 2.2f, 5.2f, 2.2f, 6.5f, 3.5f)
                close()
                moveTo(8f, 10f)
                lineTo(14f, 16f)
            }
        }.build()
    }

    /** 製圖尺規（對齊 Apple ruler）。 */
    val Ruler: ImageVector by lazy {
        ImageVector.Builder(
            name = "KairumoRuler",
            defaultWidth = 24.dp, defaultHeight = 24.dp,
            viewportWidth = 24f, viewportHeight = 24f
        ).apply {
            path(
                stroke = SolidColor(Color.Black),
                strokeLineWidth = 1.7f,
                strokeLineCap = StrokeCap.Round,
                strokeLineJoin = StrokeJoin.Round
            ) {
                moveTo(3f, 7f)
                horizontalLineTo(21f)
                verticalLineTo(17f)
                horizontalLineTo(3f)
                close()
                moveTo(6f, 7f)
                verticalLineTo(12f)
                moveTo(9f, 7f)
                verticalLineTo(10f)
                moveTo(12f, 7f)
                verticalLineTo(13f)
                moveTo(15f, 7f)
                verticalLineTo(10f)
                moveTo(18f, 7f)
                verticalLineTo(12f)
            }
        }.build()
    }

    /** 翻譯筆（對齊 Apple character.book.closed）。 */
    val Translate: ImageVector by lazy {
        ImageVector.Builder(
            name = "KairumoTranslate",
            defaultWidth = 24.dp, defaultHeight = 24.dp,
            viewportWidth = 24f, viewportHeight = 24f
        ).apply {
            path(
                stroke = SolidColor(Color.Black),
                strokeLineWidth = 1.7f,
                strokeLineCap = StrokeCap.Round,
                strokeLineJoin = StrokeJoin.Round
            ) {
                moveTo(5f, 3f)
                horizontalLineTo(18f)
                curveTo(19.1f, 3f, 20f, 3.9f, 20f, 5f)
                verticalLineTo(20f)
                curveTo(20f, 21.1f, 19.1f, 22f, 18f, 22f)
                horizontalLineTo(5f)
                curveTo(3.9f, 22f, 3f, 21.1f, 3f, 20f)
                verticalLineTo(5f)
                curveTo(3f, 3.9f, 3.9f, 3f, 5f, 3f)
                close()
                moveTo(3f, 18f)
                horizontalLineTo(20f)
                moveTo(8f, 8f)
                horizontalLineTo(15f)
                moveTo(11.5f, 8f)
                verticalLineTo(14f)
            }
        }.build()
    }

    /** 調色盤（對齊 Apple paintpalette）。 */
    val Palette: ImageVector by lazy {
        ImageVector.Builder(
            name = "KairumoPalette",
            defaultWidth = 24.dp, defaultHeight = 24.dp,
            viewportWidth = 24f, viewportHeight = 24f
        ).apply {
            path(
                stroke = SolidColor(Color.Black),
                strokeLineWidth = 1.7f,
                strokeLineCap = StrokeCap.Round,
                strokeLineJoin = StrokeJoin.Round
            ) {
                moveTo(12f, 2.5f)
                curveTo(6.5f, 2.5f, 2.5f, 6.5f, 2.5f, 12f)
                curveTo(2.5f, 17f, 6.5f, 21.5f, 11.5f, 21.5f)
                curveTo(13f, 21.5f, 14f, 20.5f, 14f, 19f)
                curveTo(14f, 18.2f, 13.5f, 17.5f, 13.5f, 16.5f)
                curveTo(13.5f, 15f, 15f, 14f, 16.5f, 14f)
                horizontalLineTo(18f)
                curveTo(20.5f, 14f, 22f, 12f, 22f, 9.5f)
                curveTo(22f, 5.5f, 17.5f, 2.5f, 12f, 2.5f)
                close()
                moveTo(7f, 9.5f)
                arcToRelative(1.2f, 1.2f, 0f, true, true, -0.01f, 0f)
                moveTo(11.5f, 6.5f)
                arcToRelative(1.2f, 1.2f, 0f, true, true, -0.01f, 0f)
                moveTo(16.5f, 8f)
                arcToRelative(1.2f, 1.2f, 0f, true, true, -0.01f, 0f)
            }
        }.build()
    }

    /** 紙張規格比例（對齊 Apple 規格與格點）。 */
    val AspectRatio: ImageVector by lazy {
        ImageVector.Builder(
            name = "KairumoAspectRatio",
            defaultWidth = 24.dp, defaultHeight = 24.dp,
            viewportWidth = 24f, viewportHeight = 24f
        ).apply {
            path(
                stroke = SolidColor(Color.Black),
                strokeLineWidth = 1.7f,
                strokeLineCap = StrokeCap.Round,
                strokeLineJoin = StrokeJoin.Round
            ) {
                moveTo(4f, 5.5f)
                curveTo(4f, 4.4f, 4.9f, 3.5f, 6f, 3.5f)
                horizontalLineTo(18f)
                curveTo(19.1f, 3.5f, 20f, 4.4f, 20f, 5.5f)
                verticalLineTo(18.5f)
                curveTo(20f, 19.6f, 19.1f, 20.5f, 18f, 20.5f)
                horizontalLineTo(6f)
                curveTo(4.9f, 20.5f, 4f, 19.6f, 4f, 18.5f)
                close()
                moveTo(8f, 7.5f)
                horizontalLineTo(16f)
                moveTo(8f, 16.5f)
                horizontalLineTo(12f)
            }
        }.build()
    }

    /** 磁吸吸附（對齊 Apple magnet）。 */
    val Magnet: ImageVector by lazy {
        ImageVector.Builder(
            name = "KairumoMagnet",
            defaultWidth = 24.dp, defaultHeight = 24.dp,
            viewportWidth = 24f, viewportHeight = 24f
        ).apply {
            path(
                stroke = SolidColor(Color.Black),
                strokeLineWidth = 1.8f,
                strokeLineCap = StrokeCap.Round,
                strokeLineJoin = StrokeJoin.Round
            ) {
                moveTo(4f, 3.5f)
                verticalLineTo(11f)
                curveTo(4f, 15.5f, 7.5f, 19.5f, 12f, 19.5f)
                curveTo(16.5f, 19.5f, 20f, 15.5f, 20f, 11f)
                verticalLineTo(3.5f)
                moveTo(8.5f, 3.5f)
                verticalLineTo(11f)
                curveTo(8.5f, 13f, 10f, 15f, 12f, 15f)
                curveTo(14f, 15f, 15.5f, 13f, 15.5f, 11f)
                verticalLineTo(3.5f)
                moveTo(4f, 7f)
                horizontalLineTo(8.5f)
                moveTo(15.5f, 7f)
                horizontalLineTo(20f)
            }
        }.build()
    }

    /** 錨定（對齊 Apple link）。 */
    val Anchor: ImageVector by lazy {
        ImageVector.Builder(
            name = "KairumoAnchor",
            defaultWidth = 24.dp, defaultHeight = 24.dp,
            viewportWidth = 24f, viewportHeight = 24f
        ).apply {
            path(
                stroke = SolidColor(Color.Black),
                strokeLineWidth = 1.8f,
                strokeLineCap = StrokeCap.Round,
                strokeLineJoin = StrokeJoin.Round
            ) {
                moveTo(10f, 13f)
                arcToRelative(5f, 5f, 0f, false, false, 7.54f, 0.54f)
                lineTo(20f, 11f)
                arcToRelative(5f, 5f, 0f, false, false, -7.07f, -7.07f)
                lineTo(11.25f, 5.61f)
                moveTo(14f, 11f)
                arcToRelative(5f, 5f, 0f, false, false, -7.54f, -0.54f)
                lineTo(4f, 13f)
                arcToRelative(5f, 5f, 0f, false, false, 7.07f, 7.07f)
                lineTo(12.75f, 18.39f)
            }
        }.build()
    }

    /** 筆跡防抖波形（對齊 Apple waveform.path）。 */
    val Waveform: ImageVector by lazy {
        ImageVector.Builder(
            name = "KairumoWaveform",
            defaultWidth = 24.dp, defaultHeight = 24.dp,
            viewportWidth = 24f, viewportHeight = 24f
        ).apply {
            path(
                stroke = SolidColor(Color.Black),
                strokeLineWidth = 1.8f,
                strokeLineCap = StrokeCap.Round,
                strokeLineJoin = StrokeJoin.Round
            ) {
                moveTo(2.5f, 12f)
                lineTo(6f, 12f)
                lineTo(8.5f, 5f)
                lineTo(12f, 19f)
                lineTo(15.5f, 8f)
                lineTo(18f, 14f)
                lineTo(21.5f, 12f)
            }
        }.build()
    }

    /** 鍵盤模式（對齊 Apple keyboard）。 */
    val Keyboard: ImageVector by lazy {
        ImageVector.Builder(
            name = "KairumoKeyboard",
            defaultWidth = 24.dp, defaultHeight = 24.dp,
            viewportWidth = 24f, viewportHeight = 24f
        ).apply {
            path(
                stroke = SolidColor(Color.Black),
                strokeLineWidth = 1.7f,
                strokeLineCap = StrokeCap.Round,
                strokeLineJoin = StrokeJoin.Round
            ) {
                moveTo(3f, 6.5f)
                curveTo(3f, 5.1f, 4.1f, 4f, 5.5f, 4f)
                horizontalLineTo(18.5f)
                curveTo(19.9f, 4f, 21f, 5.1f, 21f, 6.5f)
                verticalLineTo(17.5f)
                curveTo(21f, 18.9f, 19.9f, 20f, 18.5f, 20f)
                horizontalLineTo(5.5f)
                curveTo(4.1f, 20f, 3f, 18.9f, 3f, 17.5f)
                close()
                moveTo(7f, 8f)
                horizontalLineTo(7.01f)
                moveTo(11f, 8f)
                horizontalLineTo(11.01f)
                moveTo(15f, 8f)
                horizontalLineTo(15.01f)
                moveTo(7f, 12f)
                horizontalLineTo(7.01f)
                moveTo(11f, 12f)
                horizontalLineTo(11.01f)
                moveTo(15f, 12f)
                horizontalLineTo(15.01f)
                moveTo(8f, 16f)
                horizontalLineTo(16f)
            }
        }.build()
    }

    /** 向左導航箭頭（對齊 Apple chevron.left）。 */
    val ChevronLeft: ImageVector by lazy {
        ImageVector.Builder(
            name = "KairumoChevronLeft",
            defaultWidth = 24.dp, defaultHeight = 24.dp,
            viewportWidth = 24f, viewportHeight = 24f
        ).apply {
            path(
                stroke = SolidColor(Color.Black),
                strokeLineWidth = 2.2f,
                strokeLineCap = StrokeCap.Round,
                strokeLineJoin = StrokeJoin.Round
            ) {
                moveTo(15f, 18f)
                lineTo(9f, 12f)
                lineTo(15f, 6f)
            }
        }.build()
    }

    /** 向右導航箭頭（對齊 Apple chevron.right）。 */
    val ChevronRight: ImageVector by lazy {
        ImageVector.Builder(
            name = "KairumoChevronRight",
            defaultWidth = 24.dp, defaultHeight = 24.dp,
            viewportWidth = 24f, viewportHeight = 24f
        ).apply {
            path(
                stroke = SolidColor(Color.Black),
                strokeLineWidth = 2.2f,
                strokeLineCap = StrokeCap.Round,
                strokeLineJoin = StrokeJoin.Round
            ) {
                moveTo(9f, 6f)
                lineTo(15f, 12f)
                lineTo(9f, 18f)
            }
        }.build()
    }

    /** 加號（對齊 Apple plus）。 */
    val Plus: ImageVector by lazy {
        ImageVector.Builder(
            name = "KairumoPlus",
            defaultWidth = 24.dp, defaultHeight = 24.dp,
            viewportWidth = 24f, viewportHeight = 24f
        ).apply {
            path(
                stroke = SolidColor(Color.Black),
                strokeLineWidth = 2.2f,
                strokeLineCap = StrokeCap.Round
            ) {
                moveTo(12f, 5f)
                verticalLineTo(19f)
                moveTo(5f, 12f)
                horizontalLineTo(19f)
            }
        }.build()
    }

    /** 垂直更多選單三點（對齊 Apple ellipsis）。 */
    val MoreVert: ImageVector by lazy {
        ImageVector.Builder(
            name = "KairumoMoreVert",
            defaultWidth = 24.dp, defaultHeight = 24.dp,
            viewportWidth = 24f, viewportHeight = 24f
        ).apply {
            path(fill = SolidColor(Color.Black)) {
                moveTo(12f, 6.5f)
                arcToRelative(1.5f, 1.5f, 0f, true, true, -0.01f, 0f)
                moveTo(12f, 12f)
                arcToRelative(1.5f, 1.5f, 0f, true, true, -0.01f, 0f)
                moveTo(12f, 17.5f)
                arcToRelative(1.5f, 1.5f, 0f, true, true, -0.01f, 0f)
            }
        }.build()
    }

    /** 麥克風。用於「開始錄音」（對齊 Apple mic.fill）。 */
    val Mic: ImageVector by lazy {
        ImageVector.Builder(
            name = "KairumoMic",
            defaultWidth = 24.dp, defaultHeight = 24.dp,
            viewportWidth = 24f, viewportHeight = 24f
        ).apply {
            // 收音頭
            path(fill = SolidColor(Color.Black)) {
                moveTo(12f, 2f)
                curveTo(10.34f, 2f, 9f, 3.34f, 9f, 5f)
                verticalLineTo(12f)
                curveTo(9f, 13.66f, 10.34f, 15f, 12f, 15f)
                curveTo(13.66f, 15f, 15f, 13.66f, 15f, 12f)
                verticalLineTo(5f)
                curveTo(15f, 3.34f, 13.66f, 2f, 12f, 2f)
                close()
            }
            // 拾音弧線
            path(
                stroke = SolidColor(Color.Black),
                strokeLineWidth = 1.7f,
                strokeLineCap = StrokeCap.Round,
                strokeLineJoin = StrokeJoin.Round
            ) {
                moveTo(5.5f, 11.5f)
                verticalLineTo(12.2f)
                curveTo(5.5f, 15.8f, 8.4f, 18.7f, 12f, 18.7f)
                curveTo(15.6f, 18.7f, 18.5f, 15.8f, 18.5f, 12.2f)
                verticalLineTo(11.5f)
            }
            // 支架
            path(
                stroke = SolidColor(Color.Black),
                strokeLineWidth = 1.7f,
                strokeLineCap = StrokeCap.Round
            ) {
                moveTo(12f, 18.7f)
                verticalLineTo(21.5f)
            }
        }.build()
    }

    /** 立方體／素材庫（對齊 Apple shippingbox.fill）。 */
    val Cube: ImageVector by lazy {
        ImageVector.Builder(
            name = "KairumoCube",
            defaultWidth = 24.dp, defaultHeight = 24.dp,
            viewportWidth = 24f, viewportHeight = 24f
        ).apply {
            path(
                stroke = SolidColor(Color.Black),
                strokeLineWidth = 1.7f,
                strokeLineJoin = StrokeJoin.Round
            ) {
                moveTo(12f, 2.6f)
                lineTo(20.5f, 7.3f)
                verticalLineTo(16.7f)
                lineTo(12f, 21.4f)
                lineTo(3.5f, 16.7f)
                verticalLineTo(7.3f)
                close()
            }
            path(
                stroke = SolidColor(Color.Black),
                strokeLineWidth = 1.7f,
                strokeLineJoin = StrokeJoin.Round
            ) {
                moveTo(3.5f, 7.3f)
                lineTo(12f, 12f)
                lineTo(20.5f, 7.3f)
            }
            path(
                stroke = SolidColor(Color.Black),
                strokeLineWidth = 1.7f,
                strokeLineCap = StrokeCap.Round
            ) {
                moveTo(12f, 12f)
                verticalLineTo(21.4f)
            }
        }.build()
    }

    /** 地球。用於「介面語系」。 */
    val Globe: ImageVector by lazy {
        ImageVector.Builder(
            name = "KairumoGlobe",
            defaultWidth = 24.dp, defaultHeight = 24.dp,
            viewportWidth = 24f, viewportHeight = 24f
        ).apply {
            path(
                stroke = SolidColor(Color.Black),
                strokeLineWidth = 1.7f,
                strokeLineJoin = StrokeJoin.Round
            ) {
                moveTo(12f, 3f)
                arcToRelative(9f, 9f, 0f, true, true, -0.01f, 0f)
                close()
            }
            path(
                stroke = SolidColor(Color.Black),
                strokeLineWidth = 1.7f,
                strokeLineJoin = StrokeJoin.Round
            ) {
                moveTo(12f, 3f)
                arcTo(5.2f, 9f, 0f, false, true, 12f, 21f)
                arcTo(5.2f, 9f, 0f, false, true, 12f, 3f)
                close()
            }
            path(
                stroke = SolidColor(Color.Black),
                strokeLineWidth = 1.7f,
                strokeLineCap = StrokeCap.Round
            ) {
                moveTo(3.4f, 9.2f)
                horizontalLineTo(20.6f)
                moveTo(3.4f, 14.8f)
                horizontalLineTo(20.6f)
            }
        }.build()
    }

    /** 匯入筆記（向下箭頭與托盤）。 */
    val Import: ImageVector by lazy {
        ImageVector.Builder(
            name = "KairumoImport",
            defaultWidth = 24.dp, defaultHeight = 24.dp,
            viewportWidth = 24f, viewportHeight = 24f
        ).apply {
            path(
                stroke = SolidColor(Color.Black),
                strokeLineWidth = 1.8f,
                strokeLineCap = StrokeCap.Round,
                strokeLineJoin = StrokeJoin.Round
            ) {
                moveTo(12f, 3f)
                verticalLineTo(15f)
                moveTo(7.5f, 10.5f)
                lineTo(12f, 15f)
                lineTo(16.5f, 10.5f)
            }
            path(
                stroke = SolidColor(Color.Black),
                strokeLineWidth = 1.8f,
                strokeLineCap = StrokeCap.Round,
                strokeLineJoin = StrokeJoin.Round
            ) {
                moveTo(4f, 14f)
                verticalLineTo(19f)
                curveTo(4f, 20.1f, 4.9f, 21f, 6f, 21f)
                horizontalLineTo(18f)
                curveTo(19.1f, 21f, 20f, 20.1f, 20f, 19f)
                verticalLineTo(14f)
            }
        }.build()
    }
}
