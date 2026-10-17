package com.kairumo.padnote.platform

import android.webkit.WebSettings
import android.webkit.WebView
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView
import android.content.Context
import android.content.Intent
import android.print.PrintAttributes
import android.print.PrintManager
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import com.kairumo.padnote.L10n

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
fun DocsViewer(
    assetPath: String,
    languageTag: String,
    modifier: Modifier = Modifier,
    onWebView: (WebView) -> Unit = {}
) {
    AndroidView(
        modifier = modifier,
        factory = { context ->
            WebView(context).apply {
                onWebView(this)
                settings.javaScriptEnabled = true
                addJavascriptInterface(object {
                    @android.webkit.JavascriptInterface
                    fun print() {
                        post {
                            val jobName = if (assetPath.startsWith("legal/")) L10n.t("privacy_policy") else L10n.t("user_manual")
                            printDocument(context, this@apply, jobName)
                        }
                    }
                }, "kairumoAndroid")
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
                // `?lang=`：語言已經在 App 裡選過，頁面就照那個語言顯示並隱藏自己的語言選單。
                loadUrl("file:///android_asset/$assetPath?lang=$languageTag")
            }
        }
    )
}


/** 公開網頁版（與 Apple 端相同的網站）。分享連結用。 */
internal fun docsOnlineUrl(assetPath: String): String? = when {
    assetPath.startsWith("manual/") -> "https://hauchiehlin-ops.github.io/Kairumo/manual/index-android.html"
    assetPath.startsWith("legal/") -> "https://hauchiehlin-ops.github.io/Kairumo/legal/privacy-android.html"
    else -> null
}

/**
 * 操作手冊／隱私權政策的全螢幕畫面：檢視器加上「分享、匯出或列印」與關閉。
 *
 * 列印走系統列印框架 —— 它同時也是 Android 上「存成 PDF」的標準入口（印表機選「儲存為 PDF」，
 * 存好之後可以從檔案管理員分享）。分享則送出公開網頁版的連結。
 */
@Composable
fun DocsScreen(assetPath: String, languageTag: String, onClose: () -> Unit) {
    val context = LocalContext.current
    var webView by remember { mutableStateOf<WebView?>(null) }
    var menuOpen by remember { mutableStateOf(false) }
    val title = if (assetPath.startsWith("legal/")) L10n.t("privacy_policy") else L10n.t("user_manual")

    Column(modifier = Modifier.fillMaxSize()) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.End
        ) {
            TextButton(onClick = { menuOpen = true }, modifier = Modifier.testTag("document.share.menu")) {
                Text(L10n.t("doc_share_or_print"))
            }
            DropdownMenu(expanded = menuOpen, onDismissRequest = { menuOpen = false }) {
                DropdownMenuItem(
                    text = { Text(L10n.t("doc_print_or_pdf")) },
                    modifier = Modifier.testTag("document.print"),
                    onClick = { menuOpen = false; webView?.let { printDocument(context, it, title) } }
                )
                docsOnlineUrl(assetPath)?.let { url ->
                    DropdownMenuItem(
                        text = { Text(L10n.t("doc_share_link")) },
                        modifier = Modifier.testTag("document.share.link"),
                        onClick = { menuOpen = false; shareLink(context, title, url) }
                    )
                }
            }
            TextButton(onClick = onClose) { Text(L10n.t("close")) }
        }
        DocsViewer(
            assetPath, languageTag = languageTag,
            modifier = Modifier.fillMaxSize(),
            onWebView = { webView = it }
        )
    }
}

private fun printDocument(context: Context, webView: WebView, jobName: String) {
    val manager = context.getSystemService(Context.PRINT_SERVICE) as? PrintManager ?: return
    manager.print(
        jobName,
        webView.createPrintDocumentAdapter(jobName),
        PrintAttributes.Builder().setMediaSize(PrintAttributes.MediaSize.ISO_A4).build()
    )
}

private fun shareLink(context: Context, title: String, url: String) {
    val send = Intent(Intent.ACTION_SEND).apply {
        type = "text/plain"
        putExtra(Intent.EXTRA_SUBJECT, title)
        putExtra(Intent.EXTRA_TEXT, url)
    }
    context.startActivity(Intent.createChooser(send, title).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
}
