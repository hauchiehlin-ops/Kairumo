package com.kairumo.padnote

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.kairumo.padnote.ink.InkCanvas
import com.kairumo.padnote.ink.InkEngine
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import uniffi.padnote_core.appInfo
import uniffi.padnote_core.coreVersion
import uniffi.padnote_core.sessionKeyGenerate
import uniffi.padnote_core.sessionOpen
import uniffi.padnote_core.sessionSeal
import uniffi.padnote_core.PadnoteSession
import uniffi.padnote_core.RelayServer
import java.util.Locale

/**
 * Android 外殼的起點（工作包 WP2）。
 *
 * 現階段的唯一任務：證明 Kotlin ⇄ UniFFI ⇄ libpadnote_core.so 這條路是通的。
 * 筆跡引擎（WP5）與其餘平台功能（WP6）會在這之上長出來。
 */
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme {
                Surface(modifier = Modifier.fillMaxSize()) {
                    InkScreen()
                }
            }
        }
    }
}

/**
 * 手寫畫面（工作包 WP5）。
 *
 * 主體是畫布 —— 這是一個筆記 App，開起來就該能寫字。核心狀態那些數字移進
 * 對話框：它們是驗證用的憑據，不是使用者每天要看的東西。
 */
@Composable
private fun InkScreen() {
    val activity = LocalContext.current as ComponentActivity
    val l10n = { key: String -> uiString(key) }
    val engine = remember { InkEngine() }
    var penOnly by remember { mutableStateOf(false) }
    var revision by remember { mutableIntStateOf(0) }
    var showStatus by remember { mutableStateOf(false) }

    Column(modifier = Modifier.fillMaxSize()) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text(
                "Kairumo",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.weight(1f)
            )
            FilterChip(
                selected = penOnly,
                onClick = {
                    penOnly = !penOnly
                    // 掌拒最可靠的模式：手指一律當手勢，只有筆能寫。
                    engine.setPenOnly(penOnly)
                },
                label = { Text(l10n("ink_pen_only")) }
            )
            TextButton(onClick = { engine.reset(); revision++ }) { Text(l10n("ink_clear")) }
            TextButton(onClick = { showStatus = true }) { Text("ⓘ") }
        }

        // 讀一下 revision 讓筆畫數會跟著重繪；真相來源仍是 engine。
        val strokeCount = remember(revision) { engine.strokes.size }
        Text(
            l10n("ink_stroke_count").replace("%@", "$strokeCount"),
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(horizontal = 12.dp)
        )

        Box(modifier = Modifier.weight(1f).fillMaxWidth().padding(8.dp)) {
            InkCanvas(
                engine = engine,
                modifier = Modifier.fillMaxSize(),
                onInkChanged = { revision++ }
            )
        }
    }

    if (showStatus) {
        val rows = remember { readCoreStatus(activity) }
        AlertDialog(
            onDismissRequest = { showStatus = false },
            confirmButton = {
                TextButton(onClick = { showStatus = false }) { Text(l10n("close")) }
            },
            title = { Text("Kairumo · WP5") },
            text = {
                Column(
                    modifier = Modifier.verticalScroll(rememberScrollState()),
                    verticalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    rows.forEach { (label, value) ->
                        Text("$label：$value",
                            style = MaterialTheme.typography.bodySmall,
                            fontFamily = FontFamily.Monospace)
                    }
                }
            }
        )
    }
}

@Composable
private fun CoreStatusScreen() {
    // 真的呼叫 Rust —— 這裡回傳值出得來，就代表 .so 有被載入、JNA 綁定也對得上
    // 需要 Activity 才拿得到 App 專屬外部目錄（交接檔就放在那裡）。
    val activity = LocalContext.current as ComponentActivity
    val status = remember { readCoreStatus(activity) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Text("Kairumo", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
        Text(
            "Android 外殼 · WP2 骨架",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        status.forEach { (label, value) ->
            Text(
                "$label：$value",
                style = MaterialTheme.typography.bodyMedium,
                fontFamily = FontFamily.Monospace
            )
        }
    }
}

private fun readCoreStatus(activity: ComponentActivity): List<Pair<String, String>> = try {
    val info = appInfo()
    listOf(
        "核心版本" to coreVersion(),
        "目標平台" to "${info.targetOs}/${info.targetArch}",
        "介面版本" to "${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})",
        "協同加密" to checkSessionCrypto(),
        "協同中繼" to checkRelay(),
        "介面語系" to deviceLanguageTag(),
        "字串表" to "${LocalizationStrings.table.size} 條（與 Apple 版同源）",
        "示例字串" to uiString("about_app")
    ) + activity.readHandoffPackage()
} catch (t: Throwable) {
    // 綁定或 .so 載入失敗時要講清楚，不要給一個空白畫面
    listOf("核心載入失敗" to (t.message ?: t.toString()))
}

/**
 * 走核心的協同加密做一次 round-trip。
 *
 * 格式與 Apple 版的 CryptoKit AES-256-GCM 逐位元組相同（核心那邊有跨語言測試），
 * 所以 Android 與 iOS 能在同一個協同房間裡互相解得開。
 */
/**
 * 啟動核心的協同中繼（padnote-relay），確認在 Android 上真的綁得到埠。
 *
 * 與 Apple 版共用同一份 JSON 協定 —— Apple 端維持它自己的 Swift 實作，
 * 兩邊仍然可以加入同一個房間。
 */
private fun checkRelay(): String = try {
    val relay = RelayServer()
    val port = relay.start(0u)
    val running = relay.isRunning()
    relay.stop()
    if (running && port > 0u) "已啟動於埠 $port（已停止）" else "啟動失敗"
} catch (t: Throwable) {
    "失敗：${t.message}"
}

/**
 * 打開 iOS 端匯出的 `.padnote` 套件並回報內容（工作包 WP4 的驗收）。
 *
 * 驗收條件是「iOS 建立的多頁筆記在 Android 開啟後，筆畫數、座標、顏色與
 * 頁面高度與原稿一致」。所以這裡不只顯示「開得起來」—— 要把可以逐項比對的
 * 數字攤出來：每頁筆畫數、第一筆的顏色與起點座標、每頁高度。
 *
 * 檔案放在 App 內部 filesDir。不用外部目錄：Android 10 之後 adb push 進去的
 * 檔案屬於 shell、App 反而讀不到，會得到一個看起來像「檔案壞掉」的錯誤訊息。
 * 放內部目錄則用 `adb shell run-as` 解壓進去即可（debug 版）。
 * 沒有檔案時整段略過。
 */
private fun ComponentActivity.readHandoffPackage(): List<Pair<String, String>> {
    val pkg = java.io.File(filesDir, "handoff.padnote")
    if (!pkg.exists()) return emptyList()

    return try {
        val session = PadnoteSession.openExisting(pkg.absolutePath, 0xB0u)
        val rows = mutableListOf<Pair<String, String>>()
        rows += "跨平台筆記" to session.title()
        val pageCount = session.pageCount().toInt()
        rows += "頁數" to pageCount.toString()

        for (i in 0 until pageCount) {
            val pageId = session.pageIdAt(i.toUInt()) ?: continue
            val strokes = session.visibleStrokeDetails(pageId)
            val height = session.pageSize(pageId)?.getOrNull(1) ?: 0f
            rows += "第 ${i + 1} 頁" to "筆畫 ${strokes.size}、高 ${height.toInt()}pt"
            strokes.firstOrNull()?.let { s ->
                val rgba = s.colorRgba.joinToString(",") { (it.toInt() and 0xFF).toString() }
                val p0 = s.points.first()
                rows += "　首筆" to "RGBA($rgba)、起點(${p0.x}, ${p0.y})、${s.points.size} 點"
            }
        }
        rows
    } catch (t: Throwable) {
        listOf("跨平台筆記" to "開啟失敗：${t.message}")
    }
}

/**
 * 依裝置語系取介面字串。
 *
 * 字串表由 i18n/ui-strings.json 產生，Apple 版的 LocalizationManager 讀的是
 * 同一份來源產出的 Swift 表 —— 兩邊逐字相同，不會各自漂移。
 */
private fun uiString(key: String): String =
    LocalizationStrings.localized(key, deviceLanguageTag())

/** 把系統語系對應成字串表用的標籤（中文要分繁簡，所以不能只看語言碼）。 */
private fun deviceLanguageTag(): String {
    val locale = Locale.getDefault()
    return when (locale.language) {
        "zh" -> if (locale.script == "Hans" || locale.country in setOf("CN", "SG")) "zh-Hans" else "zh-Hant"
        "ja" -> "ja"
        "ko" -> "ko"
        "th" -> "th"
        else -> "en"
    }
}

private fun checkSessionCrypto(): String = try {
    val key = sessionKeyGenerate()
    val message = "Kairumo 協同訊息"
    val sealed = sessionSeal(key, message.toByteArray())
    val opened = String(sessionOpen(key, sealed))
    if (opened == message) "AES-256-GCM round-trip 通過" else "內容不符"
} catch (t: Throwable) {
    "失敗：${t.message}"
}
