package com.kairumo.padnote

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.horizontalScroll
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
import android.Manifest
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.material3.Divider
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.key
import com.kairumo.padnote.ink.InkCanvas
import com.kairumo.padnote.platform.AudioCapture
import com.kairumo.padnote.platform.DocsViewer
import com.kairumo.padnote.platform.Exporter
import com.kairumo.padnote.platform.Handwriting
import com.kairumo.padnote.sync.FolderSync
import com.kairumo.padnote.backup.BackupManager
import com.kairumo.padnote.text.TextBox
import com.kairumo.padnote.text.TextBoxEditor
import com.kairumo.padnote.text.TextBoxLayer
import com.kairumo.padnote.text.TextBoxStore
import androidx.compose.ui.platform.LocalDensity
import androidx.documentfile.provider.DocumentFile
import androidx.compose.runtime.rememberCoroutineScope
import kotlinx.coroutines.launch
import com.kairumo.padnote.ink.InkEngine
import com.kairumo.padnote.ink.InkLatencyMeter
import com.kairumo.padnote.ink.LowLatencyInkCanvas
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
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
    // 真的開一本筆記本：沒有 session 的話，匯出與錄音都沒有東西可寫，
    // 這一頁就只是個畫圖玩具而不是筆記 App。
    val notebook = remember { openNotebook(activity) }
    val engine = remember(notebook) {
        InkEngine(session = notebook?.first, pageId = notebook?.second)
    }
    val latency = remember { InkLatencyMeter() }
    val audio = remember { AudioCapture(activity) }
    var recording by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf<String?>(null) }
    var docsAsset by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()

    // 畫布文字方塊。與 Apple 端同一組資料模型與外觀規則（format-spec §6.2）。
    val textStore = remember(notebook) { TextBoxStore(notebook?.first, notebook?.second) }
    var textRevision by remember { mutableIntStateOf(0) }
    var selectedTextId by remember { mutableStateOf<String?>(null) }
    var editingText by remember { mutableStateOf<TextBox?>(null) }
    LaunchedEffect(notebook) { textStore.load(); textRevision++ }

    // 雲端同步（決策 D3 選項 A）：使用者挑一個資料夾，兩台裝置指同一個地方。
    // 備份檔：選一個既有的備份來復原。
    val backupPicker = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenDocument()
    ) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        message = runRestore(activity, uri)
    }

    val folderPicker = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenDocumentTree()
    ) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        FolderSync.setFolder(activity, uri)
        message = runFolderSync(activity, notebook?.first)
    }

    val micPermission = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        val session = notebook?.first
        if (granted && session != null) {
            message = audio.start(session, deviceLanguageTag()) { message = it }
            recording = audio.isRecording
        } else {
            message = uiString("mic_permission_denied")
        }
    }

    // 離開畫面時一定要停掉麥克風 —— 忘了停的話，App 退到背景還在錄，
    // 使用者只會看到狀態列那個紅點，不知道是誰。
    DisposableEffect(Unit) {
        onDispose { notebook?.first?.let { audio.stop(it) } }
    }
    var penOnly by remember { mutableStateOf(false) }
    // 預設**關閉**低延遲。
    //
    // 實機回報：開著的時候畫布全白、連工具列的按鈕都按不動。前緩衝那條路
    // 還沒在實機上驗過，不能讓它擋在使用者與「能不能寫字」之間 ——
    // 已經驗過會動的那條路才該是預設值。
    var lowLatency by remember { mutableStateOf(false) }
    var lowLatencyUnavailable by remember { mutableStateOf(false) }
    var revision by remember { mutableIntStateOf(0) }
    var clearToken by remember { mutableIntStateOf(0) }
    var showStatus by remember { mutableStateOf(false) }
    var showMenu by remember { mutableStateOf(false) }

    Column(modifier = Modifier.fillMaxSize()) {
        // 只有兩個切換留在工具列上，其餘進溢位選單。
        //
        // 先前把全部動作排成一列再讓它水平捲動 —— 在 320dp 寬的螢幕上，
        // 錄音、匯出、列印、手冊全都被推到畫面外，而且捲不太動。
        // 功能點不到就等於沒做。
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            FilterChip(
                selected = lowLatency && !lowLatencyUnavailable,
                enabled = !lowLatencyUnavailable,
                onClick = { lowLatency = !lowLatency; latency.clear() },
                label = { Text(l10n("ink_low_latency")) }
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
            Box(modifier = Modifier.weight(1f))
            // 只留一個按鈕。兩個切換加兩個按鈕在 320dp 寬的螢幕上就已經
            // 把最右邊那個擠出畫面 —— 而被擠掉的那個永遠是最後加上去的。
            TextButton(onClick = { showMenu = true }) { Text("...") }

            DropdownMenu(expanded = showMenu, onDismissRequest = { showMenu = false }) {
                DropdownMenuItem(
                    text = { Text(l10n("ink_clear")) },
                    onClick = {
                        showMenu = false
                        engine.reset()
                        latency.clear()
                        revision++
                        clearToken++   // 表面上的像素也要清，不是只清資料
                    }
                )
                Divider()
                DropdownMenuItem(
                    text = { Text(l10n(if (recording) "stop_recording" else "start_recording")) },
                    onClick = {
                        showMenu = false
                        val session = notebook?.first ?: return@DropdownMenuItem
                        if (recording) {
                            val us = audio.stop(session)
                            recording = false
                            message = l10n("recorded_duration").replace("%@", "${us / 1_000_000uL}")
                        } else if (AudioCapture.hasPermission(activity)) {
                            message = audio.start(session, deviceLanguageTag()) { message = it }
                            recording = audio.isRecording
                        } else {
                            micPermission.launch(Manifest.permission.RECORD_AUDIO)
                        }
                    }
                )
                Divider()
                DropdownMenuItem(
                    text = { Text(l10n("export_pdf")) },
                    onClick = {
                        showMenu = false
                        message = exportAndShare(activity, notebook?.first, Exporter.Format.PDF)
                    }
                )
                DropdownMenuItem(
                    text = { Text(l10n("export_image")) },
                    onClick = {
                        showMenu = false
                        message = exportAndShare(activity, notebook?.first, Exporter.Format.PNG)
                    }
                )
                DropdownMenuItem(
                    text = { Text(l10n("export_markdown")) },
                    onClick = {
                        showMenu = false
                        message = exportAndShare(activity, notebook?.first, Exporter.Format.MARKDOWN)
                    }
                )
                DropdownMenuItem(
                    text = { Text(l10n("print_note")) },
                    onClick = {
                        showMenu = false
                        val session = notebook?.first ?: return@DropdownMenuItem
                        runCatching { Exporter.print(activity, session) }
                            .onFailure { message = it.message }
                    }
                )
                Divider()
                DropdownMenuItem(
                    text = { Text(l10n("add_text_box")) },
                    onClick = {
                        showMenu = false
                        // 放在頁面左上一點的位置：使用者接著就會把它拖到想要的地方，
                        // 放在正中央反而會蓋住他剛寫的東西。
                        val box = textStore.create(x = 60f, y = 80f)
                        textRevision++
                        selectedTextId = box.id
                        editingText = box
                    }
                )
                Divider()
                DropdownMenuItem(
                    text = { Text(l10n("backup_create")) },
                    onClick = { showMenu = false; message = runBackup(activity) }
                )
                DropdownMenuItem(
                    text = { Text(l10n("backup_restore")) },
                    onClick = { showMenu = false; backupPicker.launch(arrayOf("*/*")) }
                )
                Divider()
                DropdownMenuItem(
                    text = { Text(l10n("sync_choose_folder")) },
                    onClick = { showMenu = false; folderPicker.launch(null) }
                )
                if (FolderSync.folderUri(activity) != null) {
                    DropdownMenuItem(
                        text = { Text(l10n("sync_now")) },
                        onClick = {
                            showMenu = false
                            message = runFolderSync(activity, notebook?.first)
                        }
                    )
                }
                Divider()
                DropdownMenuItem(
                    text = { Text(l10n("recognize_handwriting")) },
                    onClick = {
                        showMenu = false
                        val session = notebook?.first
                        val page = notebook?.second
                        if (session == null || page == null) {
                            message = uiString("err_core_not_ready")
                        } else {
                            message = l10n("recognizing")
                            scope.launch {
                                message = recognizeHandwriting(session, page, engine)
                            }
                        }
                    }
                )
                Divider()
                DropdownMenuItem(
                    text = { Text(l10n("user_manual")) },
                    onClick = { showMenu = false; docsAsset = "manual/index.html" }
                )
                DropdownMenuItem(
                    text = { Text(l10n("privacy_policy")) },
                    onClick = { showMenu = false; docsAsset = "legal/privacy.html" }
                )
                Divider()
                DropdownMenuItem(
                    text = { Text(l10n("system_diagnostics")) },
                    onClick = { showMenu = false; showStatus = true }
                )
            }
        }

        // 讀一下 revision 讓筆畫數會跟著重繪；真相來源仍是 engine。
        val strokeCount = remember(revision) { engine.strokes.size }
        val eventDebug = remember(revision) { engine.lastEventDebug }
        Text(
            l10n("ink_stroke_count").replace("%@", "$strokeCount"),
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(horizontal = 12.dp)
        )

        message?.let {
            Text(
                it,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.primary,
                modifier = Modifier.padding(horizontal = 12.dp)
            )
        }

        // 診斷列：一張截圖就要能告訴我平台回報了什麼。
        Text(
            eventDebug,
            style = MaterialTheme.typography.labelSmall,
            fontFamily = FontFamily.Monospace,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(horizontal = 12.dp)
        )

        if (lowLatencyUnavailable) {
            Text(
                l10n("ink_low_latency_unavailable"),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.error,
                modifier = Modifier.padding(horizontal = 12.dp)
            )
        }

        val canvasDensity = LocalDensity.current.density
        Box(modifier = Modifier.weight(1f).fillMaxWidth().padding(8.dp)) {
            if (lowLatency && !lowLatencyUnavailable) {
                LowLatencyInkCanvas(
                    engine = engine,
                    latency = latency,
                    modifier = Modifier.fillMaxSize(),
                    onInkChanged = { revision++ },
                    onUnavailable = { lowLatencyUnavailable = true },
                    clearToken = clearToken
                )
            } else {
                InkCanvas(
                    engine = engine,
                    modifier = Modifier.fillMaxSize(),
                    onInkChanged = { revision++ }
                )
            }

            // 文字方塊疊在墨跡之上 —— 與 Apple 端的疊放順序一致。
            key(textRevision) {
                TextBoxLayer(
                    boxes = textStore.all,
                    density = canvasDensity,
                    selectedId = selectedTextId,
                    onSelect = { selectedTextId = it },
                    onChanged = { box -> textStore.persist(box); textRevision++ },
                    modifier = Modifier.fillMaxSize()
                )
            }
        }
    }

    editingText?.let { box ->
        TextBoxEditor(
            box = box,
            languageTag = deviceLanguageTag(),
            onChanged = { textStore.persist(it); textRevision++ },
            onDelete = {
                textStore.remove(box)
                editingText = null
                selectedTextId = null
                textRevision++
            },
            onDismiss = { editingText = null }
        )
    }

    docsAsset?.let { asset ->
        // 全螢幕對話框而不是 AlertDialog：說明文件是要「讀」的，
        // 塞進一個固定高度的小框裡，使用者看到的是一小條白色。
        Dialog(
            onDismissRequest = { docsAsset = null },
            properties = DialogProperties(usePlatformDefaultWidth = false)
        ) {
            Surface(modifier = Modifier.fillMaxSize()) {
                Column(modifier = Modifier.fillMaxSize()) {
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 8.dp),
                        horizontalArrangement = Arrangement.End
                    ) {
                        TextButton(onClick = { docsAsset = null }) { Text(l10n("close")) }
                    }
                    DocsViewer(asset, modifier = Modifier.fillMaxSize())
                }
            }
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
                    // 延遲要即時反映，所以不進 remember 的那份快照。
                    Text(
                        "${l10n("ink_latency_label")}：${latency.summaryMs()}",
                        style = MaterialTheme.typography.bodySmall,
                        fontFamily = FontFamily.Monospace
                    )
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

/**
 * 開啟（必要時建立）這台裝置上的筆記本。
 *
 * 目前是單一本 —— 多筆記本的管理是 Apple 端才有的畫面，Android 這一版先把
 * 「寫得下去、匯得出來」做通。回傳 `null` 代表核心開不起來，UI 會退成
 * 純畫圖模式而不是整個當掉。
 */
private fun openNotebook(activity: ComponentActivity): Pair<PadnoteSession, String>? = try {
    val dir = java.io.File(activity.filesDir, "notebook.padnote")
    val session = if (dir.exists()) {
        PadnoteSession.openExisting(dir.absolutePath, deviceId(activity))
    } else {
        PadnoteSession.create(
            dir.absolutePath, "Kairumo", System.currentTimeMillis().toULong(), deviceId(activity)
        )
    }
    val page = session.firstPageId() ?: session.addPage(uniffi.padnote_core.PageStyle.BLANK)
    session to page
} catch (t: Throwable) {
    null
}

/**
 * 這台裝置穩定不變的 32 位元識別碼。
 *
 * 它會進 oplog 檔名，用來保證兩台裝置永遠不寫同一個檔 —— 撞號的後果是
 * 兩邊的編輯互相覆蓋，而且在單機測試時完全不會發生。存下來這一步不能省：
 * 每次啟動換一個 id，同一台裝置在檔案裡會看起來像很多台。
 */
private fun deviceId(activity: ComponentActivity): UInt {
    val prefs = activity.getSharedPreferences("kairumo", android.content.Context.MODE_PRIVATE)
    val saved = prefs.getInt("deviceId", 0)
    if (saved != 0) return saved.toUInt()
    var hash = 2_166_136_261u // FNV-1a
    for (b in java.util.UUID.randomUUID().toString().toByteArray()) {
        hash = hash xor b.toUInt()
        hash *= 16_777_619u
    }
    prefs.edit().putInt("deviceId", hash.toInt()).apply()
    return hash
}

/** 匯出後直接叫出分享面板，並回報給使用者看的一句話。 */
private fun exportAndShare(
    activity: ComponentActivity,
    session: PadnoteSession?,
    format: Exporter.Format
): String {
    if (session == null) return LocalizationStrings.localized("err_core_not_ready", deviceLanguageTag())
    return Exporter.export(activity, session, format).fold(
        onSuccess = { file ->
            runCatching {
                activity.startActivity(
                    android.content.Intent.createChooser(
                        Exporter.shareIntent(activity, file, format), null
                    )
                )
            }
            LocalizationStrings.localized("export_done", deviceLanguageTag())
                .replace("%@", file.name)
        },
        onFailure = { t ->
            LocalizationStrings.localized("export_failed", deviceLanguageTag())
                .replace("%@", t.message ?: t.toString())
        }
    )
}

/**
 * 把這一頁的手寫辨識成文字並寫進搜尋索引（工作包 WP7）。
 *
 * 辨識結果**只進索引**，不取代也不修改任何一筆畫 —— 手寫筆記的價值就在那個
 * 手寫，辨識只是讓它搜得到。
 *
 * 每一組的文字只掛在該組的**第一筆**上。掛在每一筆的話，搜「交付」會為同一個
 * 詞回報好幾個命中，使用者看到的是一堆重複的結果。
 */
private suspend fun recognizeHandwriting(
    session: PadnoteSession,
    pageId: String,
    engine: InkEngine
): String {
    val strokes = engine.strokes.filter { it.coreStrokeId != null }
    if (strokes.isEmpty()) return LocalizationStrings.localized("no_strokes", deviceLanguageTag())

    val groups = Handwriting.group(
        strokeIds = strokes.map { it.coreStrokeId!! },
        strokes = strokes.map { it.points },
        strokeTimesMs = strokes.map { it.startedAtMs }
    )

    var indexed = 0
    val recognized = StringBuilder()
    for (group in groups) {
        val result = Handwriting.recognize(group.strokes, deviceLanguageTag())
        result.onFailure { return it.message ?: it.toString() }
        val text = result.getOrNull().orEmpty()
        if (text.isBlank()) continue
        runCatching { session.indexHandwriting(pageId, group.strokeIds.first(), text) }
            .onSuccess { indexed++; recognized.append(text) }
    }

    return LocalizationStrings.localized("recognized_result", deviceLanguageTag())
        .replace("%1@", "$indexed")
        .replace("%2@", recognized.toString().take(40))
}

/**
 * 把本機筆記本與使用者選的雲端資料夾對齊（決策 D3 選項 A）。
 *
 * 同步由使用者自己的雲端硬碟負責，我們只搬檔案。判斷「搬哪些、往哪邊」
 * 的策略走核心，與 Apple 端同一份。
 */
private fun runFolderSync(activity: ComponentActivity, session: PadnoteSession?): String {
    val tree = FolderSync.folderUri(activity)
        ?: return LocalizationStrings.localized("sync_not_configured", deviceLanguageTag())
    val remote = DocumentFile.fromTreeUri(activity, tree)
        ?: return LocalizationStrings.localized("sync_not_configured", deviceLanguageTag())

    // 同步前先讓核心把手上的東西落盤，否則剛寫的內容不會被帶上去。
    runCatching { session?.title() }

    val local = java.io.File(activity.filesDir, "notebook.padnote")
    val result = FolderSync.sync(activity, local, remote, deviceLanguageTag())

    val lang = deviceLanguageTag()
    result.needsAttention.firstOrNull()?.let {
        return LocalizationStrings.localized("sync_needs_attention", lang).replace("%@", it)
    }
    if (result.failures.isNotEmpty()) {
        return result.failures.entries.first().let { "${it.key}：${it.value}" }
    }
    if (result.isNoOp) return LocalizationStrings.localized("sync_up_to_date", lang)
    return LocalizationStrings.localized("sync_result", lang)
        .replace("%1@", "${result.uploaded.size}")
        .replace("%2@", "${result.downloaded.size}")
}

/**
 * 建立備份檔並叫出分享面板。
 *
 * 一定要讓使用者把它帶走：留在 cache 裡的備份檔，在 App 被清除資料時
 * 會跟著消失 —— 那正是他最需要它的時候。
 */
private fun runBackup(activity: ComponentActivity): String {
    val lang = deviceLanguageTag()
    return runCatching {
        val (file, info) = BackupManager.create(activity, BuildConfig.VERSION_NAME)
        runCatching {
            activity.startActivity(
                android.content.Intent.createChooser(
                    Exporter.shareIntent(activity, file, Exporter.Format.PDF).apply {
                        type = "application/octet-stream"
                    },
                    null
                )
            )
        }
        LocalizationStrings.localized("backup_created", lang)
            .replace("%1@", "${info.fileCount}")
            .replace("%2@", android.text.format.Formatter.formatShortFileSize(
                activity, info.totalBytes.toLong()))
    }.getOrElse { it.message ?: it.toString() }
}

/** 從使用者選的備份檔一鍵復原。 */
private fun runRestore(activity: ComponentActivity, uri: android.net.Uri): String {
    val lang = deviceLanguageTag()
    return runCatching {
        val staged = BackupManager.stage(activity, uri)
        // 先看一眼再動手：使用者要知道自己選到的是什麼。
        BackupManager.inspect(staged)
        val outcome = BackupManager.restore(activity, staged, BuildConfig.VERSION_NAME)

        var text = LocalizationStrings.localized("backup_restored", lang)
            .replace("%@", "${outcome.restored}")
        if (outcome.corrupted.isNotEmpty()) {
            text += "　" + LocalizationStrings.localized("backup_corrupted", lang)
                .replace("%@", "${outcome.corrupted.size}")
        }
        text
    }.getOrElse {
        LocalizationStrings.localized("backup_invalid", lang) + "（${it.message}）"
    }
}
