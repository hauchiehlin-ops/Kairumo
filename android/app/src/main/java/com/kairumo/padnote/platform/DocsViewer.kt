package com.kairumo.padnote.platform

import android.webkit.WebSettings
import android.webkit.WebView
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView

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

                // 文件本身已經是完整的 HTML（有 DOCTYPE、charset 與 viewport），
                // 直接載入即可。
                //
                // 以前這裡會先把內容讀成字串、補上外框再 `loadDataWithBaseURL` ——
                // 因為那時來源是沒有 <html> 的片段。現在來源補齊了，那一層反而是
                // 多的：直接 loadUrl 讓 manual.js 與 img/ 的相對路徑自然生效，
                // 也不必把整份文件（近 100 KB）先搬進記憶體。
                //
                // charset 由文件自己宣告。少了它，WebView 只能猜編碼，中文會變成
                // 一堆亂碼 —— Apple 端實際發生過這件事。
                loadUrl("file:///android_asset/$assetPath")
            }
        }
    )
}
