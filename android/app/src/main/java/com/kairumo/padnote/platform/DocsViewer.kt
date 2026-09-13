package com.kairumo.padnote.platform

import android.webkit.WebSettings
import android.webkit.WebView
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView

/**
 * 把網頁片段補成一份完整文件。
 *
 * 只補外框與 viewport，不動內容 —— 內容是已經審過的那一份，
 * 在這裡改樣式只會讓兩個平台看到的說明不一樣。
 */
private fun wrapFragment(fragment: String): String = """
    <!doctype html>
    <html>
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    </head>
    <body>
    $fragment
    </body>
    </html>
""".trimIndent()

/**
 * 操作手冊與隱私權政策的檢視器（工作包 WP6）。
 *
 * 文件是既有的 HTML（`docs/manual`、`docs/legal`），由 Gradle 在建置時複製
 * 進 assets —— 與 Apple 版看的是同一份來源，不會出現「Android 版的說明跟
 * 實際功能對不上」。
 *
 * JavaScript 要開：手冊的語言切換下拉選單靠 `manual.js`。開的範圍僅限
 * `file:///android_asset/` 底下的本機檔案，不載入任何外部內容。
 */
@Composable
fun DocsViewer(assetPath: String, modifier: Modifier = Modifier) {
    AndroidView(
        modifier = modifier,
        factory = { context ->
            WebView(context).apply {
                settings.javaScriptEnabled = true
                // 手冊用相對路徑引用 manual.js 與 img/，要允許同目錄的檔案存取。
                settings.allowFileAccess = true
                settings.cacheMode = WebSettings.LOAD_NO_CACHE
                // 這是離線文件，不該有任何對外請求。
                settings.blockNetworkLoads = true
                settings.setSupportZoom(true)
                settings.builtInZoomControls = true
                settings.displayZoomControls = false

                // 手冊與隱私權政策是為了網頁發佈而寫的**片段**（沒有 <html>，
                // 也沒有 viewport meta）。直接 loadUrl 的話，WebView 會用桌面
                // 寬度排版，手機上整頁縮成看不清的小字。補上最小的外框再載入，
                // 並保留 asset 的 base URL，讓 manual.js 與 img/ 的相對路徑還找得到。
                val base = "file:///android_asset/" +
                    assetPath.substringBeforeLast('/', "") + "/"
                val raw = runCatching {
                    context.assets.open(assetPath).bufferedReader().use { it.readText() }
                }.getOrNull()

                if (raw == null) {
                    loadUrl("file:///android_asset/$assetPath")
                } else if (raw.contains("<html", ignoreCase = true)) {
                    loadDataWithBaseURL(base, raw, "text/html", "utf-8", null)
                } else {
                    loadDataWithBaseURL(base, wrapFragment(raw), "text/html", "utf-8", null)
                }
            }
        }
    )
}
