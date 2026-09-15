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
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.foundation.shape.RoundedCornerShape
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
import com.kairumo.padnote.image.ImageEditor
import com.kairumo.padnote.image.ImageLayer
import com.kairumo.padnote.image.ImageStore
import com.kairumo.padnote.image.NoteImage
import com.kairumo.padnote.ink.InkCanvas
import com.kairumo.padnote.platform.AudioCapture
import com.kairumo.padnote.platform.DocsViewer
import com.kairumo.padnote.platform.Exporter
import com.kairumo.padnote.platform.Handwriting
import com.kairumo.padnote.sync.FolderSync
import com.kairumo.padnote.backup.BackupManager
import com.kairumo.padnote.text.TextBox
import com.kairumo.padnote.text.TextBoxEditor
import com.kairumo.padnote.account.AccountManager
import com.kairumo.padnote.canvas.ObjectStacking
import com.kairumo.padnote.library.NotebookMeta
import com.kairumo.padnote.comment.CommentLayer
import com.kairumo.padnote.comment.CommentPin
import com.kairumo.padnote.comment.CommentThreadDialog
import com.kairumo.padnote.canvas.CanvasStackPanel
import com.kairumo.padnote.math.MathCalculatorDialog
import com.kairumo.padnote.canvas.ObjectGeometry
import com.kairumo.padnote.canvas.ProColorPicker
import com.kairumo.padnote.canvas.EditorMode
import com.kairumo.padnote.account.IdentityDialog
import com.kairumo.padnote.library.HomeScreen
import com.kairumo.padnote.library.RenameNotebookDialog
import com.kairumo.padnote.library.DeleteNotebookDialog
import com.kairumo.padnote.library.NotebookLibrary
import com.kairumo.padnote.shape.NoteConnection
import com.kairumo.padnote.shape.NoteShape
import com.kairumo.padnote.shape.ShapeLayer
import com.kairumo.padnote.shape.LayerPanel
import com.kairumo.padnote.shape.ObjectLayer
import com.kairumo.padnote.shape.ShapePicker
import com.kairumo.padnote.shape.ShapeStore
import com.kairumo.padnote.shape.ShapeStyleDialog
import com.kairumo.padnote.table.NoteTable
import com.kairumo.padnote.table.TableEditor
import com.kairumo.padnote.table.TableLayer
import com.kairumo.padnote.table.TableStore
import com.kairumo.padnote.chart.ChartLayer
import com.kairumo.padnote.chart.ChartObject
import com.kairumo.padnote.chart.ChartSpec
import com.kairumo.padnote.chart.ChartStore
import com.kairumo.padnote.chart.ChartStudio
import com.kairumo.padnote.text.TextBoxLayer
import com.kairumo.padnote.text.TextBoxStore
import androidx.compose.ui.platform.LocalDensity
import androidx.documentfile.provider.DocumentFile
import androidx.compose.runtime.rememberCoroutineScope
import kotlinx.coroutines.launch
import com.kairumo.padnote.ink.InkEngine
import com.kairumo.padnote.ink.InkTool
import com.kairumo.padnote.ink.InkToolbar
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
                    KairumoApp()
                }
            }
        }
    }
}

/**
 * App 的兩個畫面：首頁與編輯器。
 *
 * 在此之前 Android 只有編輯器 —— App 一開就直接進一本筆記的一頁，沒有清單、
 * 沒有搜尋、沒有「新增一本」。使用者看到的是一個畫圖玩具，不是筆記本。
 *
 * 用一個 `openedId` 而不是 Navigation 元件：只有兩個畫面，狀態也只有一個
 * 「現在開著哪一本」。多拉一個導覽框架進來只會多一層要維護的東西。
 */
@Composable
private fun KairumoApp() {
    val activity = LocalContext.current as ComponentActivity
    var openedId by remember { mutableStateOf<String?>(null) }

    val id = openedId
    if (id == null) {
        NotebookHome(onOpen = { openedId = it })
    } else {
        InkScreen(notebookId = id, onBack = { openedId = null })
    }
}

/**
 * 首頁：筆記本清單、搜尋、新增、身分、備份。
 *
 * 這一層只負責「把狀態接上 [HomeScreen]」—— 版面在那邊，資料在
 * [NotebookLibrary]，兩邊都不知道對方的存在。
 */
@Composable
private fun NotebookHome(onOpen: (String) -> Unit) {
    val activity = LocalContext.current as ComponentActivity
    val lang = deviceLanguageTag()
    fun l(key: String) = LocalizationStrings.localized(key, lang)

    val device = remember { deviceId(activity) }
    var sort by remember { mutableStateOf(NotebookLibrary.Sort.MODIFIED) }
    var revision by remember { mutableIntStateOf(0) }
    var renaming by remember { mutableStateOf<NotebookLibrary.Entry?>(null) }
    var deleting by remember { mutableStateOf<NotebookLibrary.Entry?>(null) }
    var editingIdentity by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf<String?>(null) }
    var recording by remember { mutableStateOf(false) }

    var profile by remember {
        mutableStateOf(AccountManager.load(activity, l("default_user_name")))
    }

    // revision 是重讀的觸發器。清單來自檔案系統，沒有觀察者可以訂閱 ——
    // 新增或刪除之後不主動重讀的話，畫面會停在舊的內容。
    val entries = remember(revision, sort) { NotebookLibrary.all(activity, device, sort) }

    val restorePicker = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenDocument()
    ) { uri ->
        if (uri != null) {
            message = runRestore(activity, uri)
            revision++
        }
    }

    Column(Modifier.fillMaxSize()) {
        message?.let {
            Text(
                it,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.primary,
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 6.dp)
            )
        }

        HomeScreen(
            entries = entries,
            profileName = profile.displayName,
            profileColorHex = profile.colorHex,
            appVersion = "Kairumo v${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})",
            sort = sort,
            recording = recording,
            l = ::l,
            onOpen = onOpen,
            onCreate = {
                val id = NotebookLibrary.create(activity, l("new_note"), device)
                revision++
                // 新增之後直接開 —— 建了一本卻停在清單上，使用者還要再點一次。
                if (id != null) onOpen(id)
            },
            onRename = { renaming = it },
            onDelete = { deleting = it },
            onSortChange = { sort = it },
            onEditIdentity = { editingIdentity = true },
            onToggleRecording = {
                // 錄音要有一本筆記可以寫進去。沒有的話先建一本再開，
                // 不然錄完的音檔沒有歸屬。
                val id = entries.firstOrNull()?.id
                    ?: NotebookLibrary.create(activity, l("new_note"), device)
                if (id != null) onOpen(id)
            },
            onBackup = { message = runBackup(activity) },
            onRestore = { restorePicker.launch(arrayOf("*/*")) }
        )
    }

    renaming?.let { entry ->
        RenameNotebookDialog(
            entry = entry,
            l = ::l,
            onDismiss = { renaming = null },
            onConfirm = { title ->
                if (title.isNotBlank()) {
                    NotebookLibrary.rename(activity, entry.id, title, device)
                    revision++
                }
            }
        )
    }

    deleting?.let { entry ->
        DeleteNotebookDialog(
            entry = entry,
            l = ::l,
            onDismiss = { deleting = null },
            onConfirm = {
                NotebookLibrary.delete(activity, entry.id)
                revision++
            }
        )
    }

    if (editingIdentity) {
        IdentityDialog(
            profile = profile,
            l = ::l,
            onDismiss = { editingIdentity = false },
            onSave = { name, hex ->
                AccountManager.saveName(activity, name, l("default_user_name"))
                AccountManager.saveColor(activity, hex)
                profile = AccountManager.load(activity, l("default_user_name"))
            }
        )
    }
}

/**
 * 手寫畫面（工作包 WP5）。
 *
 * 主體是畫布 —— 這是一個筆記 App，開起來就該能寫字。核心狀態那些數字移進
 * 對話框：它們是驗證用的憑據，不是使用者每天要看的東西。
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun InkScreen(notebookId: String? = null, onBack: (() -> Unit)? = null) {
    val activity = LocalContext.current as ComponentActivity
    val l10n = { key: String -> uiString(key) }
    // 真的開一本筆記本：沒有 session 的話，匯出與錄音都沒有東西可寫，
    // 這一頁就只是個畫圖玩具而不是筆記 App。
    val notebook = remember(notebookId) { openNotebook(activity, notebookId) }
    // 分頁狀態。
    //
    // 在此之前 Android **只認第一頁** —— `notebook.second` 是 firstPageId，
    // 而它從頭到尾沒有變過。一本 6 頁的筆記在 iPad 上翻得動，在 Android 上
    // 永遠停在第 1 頁，其餘 5 頁的內容看不到也刪不掉。
    //
    // 以**索引**為主而不是以 pageId 為主：新增與刪除之後 id 會變，索引不會，
    // 而使用者心裡想的是「第幾頁」。
    var pageCount by remember(notebook) {
        mutableIntStateOf(
            runCatching { notebook?.first?.pageCount()?.toInt() ?: 1 }.getOrDefault(1)
        )
    }
    var pageIndex by remember(notebook) { mutableIntStateOf(0) }

    val pageId = remember(notebook, pageIndex, pageCount) {
        runCatching { notebook?.first?.pageIdAt(pageIndex.toUInt()) }.getOrNull()
            ?: notebook?.second
    }

    val engine = remember(notebook, pageId) {
        InkEngine(session = notebook?.first, pageId = pageId)
    }
    val latency = remember { InkLatencyMeter() }
    val audio = remember { AudioCapture(activity) }
    var recording by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf<String?>(null) }
    var docsAsset by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()

    // 畫布文字方塊。與 Apple 端同一組資料模型與外觀規則（format-spec §6.2）。
    val textStore = remember(notebook, pageId) { TextBoxStore(notebook?.first, pageId) }
    var textRevision by remember { mutableIntStateOf(0) }
    var selectedTextId by remember { mutableStateOf<String?>(null) }
    var editingText by remember { mutableStateOf<TextBox?>(null) }
    LaunchedEffect(notebook, pageId) { textStore.load(); textRevision++ }

    // 數字製圖。設定存進區塊外觀，所以插進去之後還改得動 ——
    // 與 Apple 端同一份 ChartSpec 與同一個核心版面引擎。
    val chartStore = remember(notebook, pageId) { ChartStore(notebook?.first, pageId) }
    var chartRevision by remember { mutableIntStateOf(0) }
    var selectedChartId by remember { mutableStateOf<String?>(null) }
    var editingChart by remember { mutableStateOf<ChartObject?>(null) }
    var insertingChart by remember { mutableStateOf(false) }
    LaunchedEffect(notebook, pageId) { chartStore.load(); chartRevision++ }

    // 表格。內容走核心原生的表格區塊，樣式走區塊外觀 ——
    // 與 Apple 端同一組操作，所以表格互相打得開。
    val tableStore = remember(notebook, pageId) { TableStore(notebook?.first, pageId) }
    var tableRevision by remember { mutableIntStateOf(0) }
    var selectedTableId by remember { mutableStateOf<String?>(null) }
    var editingTable by remember { mutableStateOf<NoteTable?>(null) }
    /// 形狀的樣式編修對話框。strokeColorHex / fillColorHex / lineWidth 這三個
    /// 欄位一直都在、也一直跟著同步走，但過去沒有任何介面碰得到它們。
    var editingShapeStyle by remember { mutableStateOf<NoteShape?>(null) }
    var insertingTable by remember { mutableStateOf(false) }
    LaunchedEffect(notebook, pageId) { tableStore.load(); tableRevision++ }

    // 形狀與流程圖。幾何全部來自核心，與 Apple 端是同一組頂點；
    // 形狀本身也是核心的原生物件，所以關掉 App 再打開它們還在。
    /**
     * 手寫／打字模式。**與 Apple 端的 EditorMode 同一組語意。**
     *
     * 在此之前 Android 沒有這個概念：物件層永遠吃觸控，於是拿筆想在一張圖
     * 上圈重點，筆畫根本到不了畫布 —— 而那在一個手寫筆記 App 裡是最該能做
     * 的事之一。iPad 上圈得到、Android 上圈不到，同一個人換裝置就會發現。
     */
    var editorMode by remember { mutableStateOf(EditorMode.DRAW) }

    // 筆記本中繼資料。Android 在此之前**完全沒有讀過它** —— Apple 放在這裡的
    // 樣板、資料夾、圖釘、連結卡片、3D 與物件堆疊順序，同步過來就像不存在。
    val meta = remember(notebook) { NotebookMeta.load(notebook?.first) }
    var stackRevision by remember { mutableIntStateOf(0) }
    var showStackPanel by remember { mutableStateOf(false) }
    var showCalculator by remember { mutableStateOf(false) }
    var showProColors by remember { mutableStateOf(false) }
    // 討論圖釘。存在筆記本中繼資料裡，Android 在此之前讀不到 ——
    // iPad 上標的討論同步過來就像不存在。
    var pins by remember(notebook) { mutableStateOf(meta.commentPins()) }
    var pinRevision by remember { mutableIntStateOf(0) }
    var openPin by remember { mutableStateOf<CommentPin?>(null) }






    val imageStore = remember(notebook, pageId) { ImageStore(notebook?.first, pageId) }
    var imageRevision by remember { mutableIntStateOf(0) }
    var selectedImageId by remember { mutableStateOf<String?>(null) }
    var editingImage by remember { mutableStateOf<NoteImage?>(null) }
    LaunchedEffect(notebook, pageId) { imageStore.load(); imageRevision++ }

    // 相簿選圖。用 OpenDocument 而不是舊的 GET_CONTENT：前者拿得到持久權限，
    // 而且在 Android 13+ 不需要任何儲存權限。
    val imagePicker = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenDocument()
    ) { uri ->
        if (uri != null) {
            val bytes = runCatching {
                activity.contentResolver.openInputStream(uri)?.use { it.readBytes() }
            }.getOrNull()
            val name = uri.lastPathSegment?.substringAfterLast('/') ?: "image.png"
            if (bytes != null) {
                val inserted = imageStore.insert(bytes, name)
                imageRevision++
                selectedImageId = inserted?.id
                // 插入後自動切到打字模式 —— 手寫模式下物件不吃觸控，
                // 使用者剛插進來的圖會拖不動，看起來像插壞了。
                if (inserted != null) editorMode = EditorMode.TYPE
            } else {
                message = l10n("err_image_read_failed")
            }
        }
    }

    val shapeStore = remember(notebook, pageId) { ShapeStore(notebook?.first, pageId) }
    var shapeRevision by remember { mutableIntStateOf(0) }
    var selectedShapeIds by remember { mutableStateOf(setOf<String>()) }
    var insertingShape by remember { mutableStateOf(false) }
    var showLayerPanel by remember { mutableStateOf(false) }
    LaunchedEffect(notebook, pageId) { shapeStore.load(); shapeRevision++ }

    // 這一頁所有可堆疊的物件，跨五種型別收成同一份清單。
    // 名字取得出來就用內容，取不出來就用型別名 —— 面板上一整排「未命名」
    // 的話，使用者分不出哪一列是哪一個。
    val stackItems = remember(
        textRevision, shapeRevision, tableRevision, chartRevision, imageRevision, pageId
    ) {
        buildList {
            imageStore.all.forEach {
                add(ObjectStacking.Item(it.id, ObjectStacking.Kind.IMAGE, l10n("layer_kind_image")))
            }
            shapeStore.all.forEach {
                add(ObjectStacking.Item(
                    it.id, ObjectStacking.Kind.SHAPE,
                    it.label.ifBlank { l10n("layer_kind_shape") }))
            }
            tableStore.all.forEach {
                add(ObjectStacking.Item(it.id, ObjectStacking.Kind.TABLE, l10n("layer_kind_table")))
            }
            chartStore.all.forEach {
                add(ObjectStacking.Item(it.id, ObjectStacking.Kind.CHART, l10n("chart_studio")))
            }
            textStore.all.forEach {
                add(ObjectStacking.Item(
                    it.id, ObjectStacking.Kind.TEXT,
                    it.text.trim().take(24).ifBlank { l10n("layer_kind_text") }))
            }
        }
    }

    val stackOrder = remember(stackItems, stackRevision) {
        ObjectStacking.normalized(stackItems, meta.objectOrder(pageIndex))
    }
    val kindOf = remember(stackItems) { stackItems.associate { it.id to it.kind } }
    val zIndexOf: (String) -> Float = { id ->
        ObjectStacking.zIndex(id, kindOf[id] ?: ObjectStacking.Kind.TEXT, stackOrder)
    }

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

    // 筆刷、顏色、筆寬。在此之前 Android 只有一支固定的黑色鋼筆，
    // 連橡皮擦都選不到 —— 核心一直支援，缺的只是 UI。
    var inkTool by remember { mutableStateOf(InkTool.FOUNTAIN_PEN) }
    var inkColorHex by remember { mutableStateOf("#000000") }
    var inkWidth by remember { mutableStateOf(3f) }
    var showStatus by remember { mutableStateOf(false) }
    /// 畫布上方那行輸入診斷（tool=/r=/p=/draw=/rej=/ges=）要不要顯示。
    ///
    /// 預設關。那一行是給開發看的，對使用者沒有任何意義，卻讓整個 App
    /// 看起來像個測試程式 —— 使用者就是這樣回報的。留一個開關是因為
    /// 掌拒與筆壓的問題只有實機重現得出來，屆時要能一鍵打開。
    var showInkDebug by remember { mutableStateOf(false) }
    var deletingPage by remember { mutableStateOf(false) }


    // 系統返回鍵＝回首頁。Android 使用者按的第一個東西就是它，
    // 不接的話按下去會直接把 App 關掉 —— 看起來像當掉。
    if (onBack != null) {
        androidx.activity.compose.BackHandler { onBack() }
    }
    var showMenu by remember { mutableStateOf(false) }

    Column(modifier = Modifier.fillMaxSize()) {
        // 只有兩個切換留在工具列上，其餘進溢位選單。
        //
        // 先前把全部動作排成一列再讓它水平捲動 —— 在 320dp 寬的螢幕上，
        // 錄音、匯出、列印、手冊全都被推到畫面外，而且捲不太動。
        // 功能點不到就等於沒做。
        // FlowRow 而不是 Row：320dp 寬的螢幕上，返回鈕加兩個切換再加「...」
        // 就擠不下，Row 會把最後一個壓成一欄一個字的直書（實機上看到的
        // 就是「Stylus Only」被壓成一直條）。換行至少每個字都看得懂。
        FlowRow(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            // 回首頁。沒有這顆的話，進了筆記就出不來了 ——
            // Android 的系統返回鍵在單一 Compose 畫面裡不會有任何作用。
            if (onBack != null) {
                TextButton(onClick = onBack) { Text("‹ ${l10n("back_to_home")}") }
            }
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
            // 手寫／打字切換。與 Apple 端一樣放在最前面 ——
            // 它決定了其餘每一個工具的意義。
            FilterChip(
                selected = editorMode == EditorMode.DRAW,
                onClick = {
                    editorMode = EditorMode.DRAW
                    // 切回手寫時要清掉選取。留著的話，畫面上會浮著一組
                    // 旋轉／樣式／縮放把手，而它們在手寫模式下完全按不動
                    // —— 看得到、點不到的控制項比沒有更糟。
                    selectedTextId = null
                    selectedShapeIds = emptySet()
                    selectedTableId = null
                    selectedChartId = null
                },
                label = { Text(l10n("mode_draw")) }
            )
            FilterChip(
                selected = editorMode == EditorMode.TYPE,
                onClick = { editorMode = EditorMode.TYPE },
                label = { Text(l10n("mode_type")) }
            )

            // 分頁導覽。與 Apple 端同一組：上一頁 · 頁碼 · 下一頁 · 新增。
            TextButton(
                onClick = { if (pageIndex > 0) pageIndex-- },
                enabled = pageIndex > 0
            ) { Text("‹") }
            Text(
                "${pageIndex + 1}/${maxOf(1, pageCount)}",
                style = MaterialTheme.typography.labelMedium,
                modifier = Modifier.padding(top = 14.dp)
            )
            TextButton(
                onClick = { if (pageIndex < pageCount - 1) pageIndex++ },
                enabled = pageIndex < pageCount - 1
            ) { Text("›") }
            TextButton(onClick = {
                val session = notebook?.first
                if (session != null) {
                    runCatching { session.addPage(uniffi.padnote_core.PageStyle.BLANK) }
                    pageCount = runCatching { session.pageCount().toInt() }.getOrDefault(pageCount + 1)
                    // 新增之後直接翻過去 —— 加了一頁卻停在原地，
                    // 使用者不確定到底加成功了沒有。
                    pageIndex = pageCount - 1
                }
            }) { Text("+") }

            // FlowRow 裡沒有 weight 可以撐開，靠換行自然排就好。
            TextButton(onClick = { showMenu = true }) { Text("⋯") }

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
                    text = { Text(l10n("add_comment_pin")) },
                    onClick = {
                        showMenu = false
                        val profile = AccountManager.load(activity, l10n("default_user_name"))
                        val pin = CommentPin(
                            id = java.util.UUID.randomUUID().toString(),
                            pageIndex = pageIndex,
                            x = 80f, y = 120f,
                            authorId = deviceId(activity).toString(),
                            authorName = profile.displayName,
                            authorColor = profile.colorHex,
                            createdAt = java.util.Date(),
                            isResolved = false,
                            messages = mutableListOf()
                        )
                        pins = (pins + pin).toMutableList()
                        meta.setCommentPins(notebook?.first, pins)
                        pinRevision++
                        openPin = pin
                        editorMode = EditorMode.TYPE
                    }
                )
                DropdownMenuItem(
                    text = { Text(l10n("pro_color")) },
                    onClick = { showMenu = false; showProColors = true }
                )
                DropdownMenuItem(
                    text = { Text(l10n("math_calc")) },
                    onClick = { showMenu = false; showCalculator = true }
                )
                DropdownMenuItem(
                    text = { Text(l10n("layers_panel")) },
                    onClick = { showMenu = false; showStackPanel = true }
                )
                DropdownMenuItem(
                    text = { Text(l10n("insert_image")) },
                    onClick = { showMenu = false; imagePicker.launch(arrayOf("image/*")) }
                )
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
                DropdownMenuItem(
                    text = { Text(l10n("chart_studio")) },
                    onClick = { showMenu = false; insertingChart = true }
                )
                DropdownMenuItem(
                    text = { Text(l10n("table_studio")) },
                    onClick = { showMenu = false; insertingTable = true }
                )
                DropdownMenuItem(
                    text = { Text(l10n("shape_studio")) },
                    onClick = { showMenu = false; insertingShape = true }
                )
                DropdownMenuItem(
                    // 這一個只認形狀，做的是**群組**（連接線要接得住，其餘型別
                    // 沒有這回事）。與上面那個跨型別的圖層面板同名的話，
                    // 使用者不知道該點哪一個。
                    text = { Text(l10n("layer_group")) },
                    onClick = { showMenu = false; showLayerPanel = true }
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
                    text = { Text(l10n("delete_page")) },
                    // 只剩一頁時不給刪 —— 刪光了就沒有東西可以寫，
                    // 而 UI 上也沒有「建立第一頁」的入口。
                    enabled = pageCount > 1,
                    onClick = { showMenu = false; deletingPage = true }
                )
                Divider()
                DropdownMenuItem(
                    text = { Text(l10n("system_diagnostics")) },
                    onClick = { showMenu = false; showStatus = true }
                )
                DropdownMenuItem(
                    text = { Text(l10n("ink_input_debug")) },
                    trailingIcon = { if (showInkDebug) Text("✓") },
                    onClick = { showMenu = false; showInkDebug = !showInkDebug }
                )
            }
        }

        InkToolbar(
            tool = inkTool,
            colorHex = inkColorHex,
            width = inkWidth,
            languageTag = deviceLanguageTag(),
            onToolChange = { picked ->
                inkTool = picked
                engine.isErasing = picked.isEraser
                picked.kind?.let { engine.tool = it }
            },
            onColorChange = { hex ->
                inkColorHex = hex
                engine.colorRgba = hexToRgba(hex)
            },
            onWidthChange = { value ->
                inkWidth = value
                engine.baseWidth = value
            }
        )

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
        //
        // 但它**不該預設顯示**。`tool=1 r=27.0dp p=0.41 draw=0 rej=1 ges=0`
        // 這行對使用者沒有任何意義，只會讓整個 App 看起來像個測試程式
        // —— 使用者就是這樣回報的。改成跟著「顯示核心狀態」那個選單項走。
        if (showInkDebug) {
            Text(
                eventDebug,
                style = MaterialTheme.typography.labelSmall,
                fontFamily = FontFamily.Monospace,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(horizontal = 12.dp)
            )
        }

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

            // 圖片疊在墨跡之上、文字方塊之下 —— 與 Apple 端的預設層級一致
            // （ObjectStacking.Kind.defaultLayer：image=0、text=6）。
            key(imageRevision) {
                ImageLayer(
                    zIndexOf = zIndexOf,
                    images = imageStore.all,
                    store = imageStore,
                    density = canvasDensity,
                    selectedId = selectedImageId,
                    interactive = editorMode == EditorMode.TYPE,
                    onSelect = { selectedImageId = it },
                    onEditStyle = { editingImage = it },
                    onChanged = { imageStore.persist(it); imageRevision++ },
                    modifier = Modifier.fillMaxSize()
                )
            }

            // 文字方塊疊在墨跡之上 —— 與 Apple 端的疊放順序一致。
            key(textRevision) {
                TextBoxLayer(
                    zIndexOf = zIndexOf,
                    interactive = editorMode == EditorMode.TYPE,
                    boxes = textStore.all,
                    density = canvasDensity,
                    selectedId = selectedTextId,
                    onSelect = { selectedTextId = it },
                    onEditStyle = { editingText = it },
                    onChanged = { box -> textStore.persist(box); textRevision++ },
                    modifier = Modifier.fillMaxSize()
                )
            }

            // 形狀與連接線。
            key(shapeRevision) {
                ShapeLayer(
                    zIndexOf = zIndexOf,
                    interactive = editorMode == EditorMode.TYPE,
                    shapes = shapeStore.all,
                    connections = shapeStore.allConnections,
                    density = canvasDensity,
                    selectedIds = selectedShapeIds,
                    onSelect = { id ->
                        // 選到群組裡的一個就整組選起來 —— 那正是群組的意義。
                        val mates = if (id == null) emptySet()
                                    else ObjectLayer.groupMates(id, shapeStore.all)
                        selectedShapeIds =
                            if (selectedShapeIds.containsAll(mates) && mates.isNotEmpty()) {
                                selectedShapeIds - mates
                            } else {
                                selectedShapeIds + mates
                            }
                    },
                    onEditStyle = { editingShapeStyle = it },
                    onEdit = { shape ->
                        // 點兩下刪除選中的形狀 —— 插錯一個卻刪不掉是最惱人的。
                        shapeStore.remove(shape)
                        shapeRevision++
                        selectedShapeIds = selectedShapeIds - shape.id
                    },
                    onChanged = { updated ->
                        // 拖曳一個形狀時，同一組的其他成員要跟著走 ——
                        // 不跟的話，群組起來的流程圖一拖就散開了。
                        val previous = shapeStore.all.firstOrNull { it.id == updated.id }
                        val dx = updated.x - (previous?.x ?: updated.x)
                        val dy = updated.y - (previous?.y ?: updated.y)
                        shapeStore.persist(updated)
                        for (mate in ObjectLayer.groupMates(updated.id, shapeStore.all)) {
                            if (mate == updated.id) continue
                            shapeStore.all.firstOrNull { it.id == mate }?.let { other ->
                                shapeStore.persist(
                                    other.copyShape().apply { x += dx; y += dy }
                                )
                            }
                        }
                        shapeRevision++
                    },
                    modifier = Modifier.fillMaxSize()
                )
            }

            // 表格疊在文字方塊之上。
            key(tableRevision) {
                TableLayer(
                    zIndexOf = zIndexOf,
                    interactive = editorMode == EditorMode.TYPE,
                    tables = tableStore.all,
                    density = canvasDensity,
                    selectedId = selectedTableId,
                    onSelect = { selectedTableId = it },
                    onEdit = { editingTable = it },
                    onChanged = { table -> tableStore.persist(table); tableRevision++ },
                    modifier = Modifier.fillMaxSize()
                )
            }

            // 圖表疊在文字方塊之上 —— 與 Apple 端的疊放順序一致。
            key(chartRevision) {
                ChartLayer(
                    zIndexOf = zIndexOf,
                    interactive = editorMode == EditorMode.TYPE,
                    charts = chartStore.all,
                    density = canvasDensity,
                    selectedId = selectedChartId,
                    onSelect = { selectedChartId = it },
                    onEdit = { editingChart = it },
                    onChanged = { chart -> chartStore.persist(chart); chartRevision++ },
                    modifier = Modifier.fillMaxSize()
                )
            }

            // 討論圖釘畫在最上層 —— 它是標記，被內容蓋住就失去意義。
            key(pinRevision) {
                CommentLayer(
                    pins = pins,
                    pageIndex = pageIndex,
                    interactive = editorMode == EditorMode.TYPE,
                    onOpen = { openPin = it },
                    onMoved = { meta.setCommentPins(notebook?.first, pins); pinRevision++ },
                    density = canvasDensity
                )
            }
        }
    }

    if (deletingPage) {
        AlertDialog(
            onDismissRequest = { deletingPage = false },
            title = { Text(l10n("delete_page")) },
            text = { Text(l10n("delete_page_confirm").replace("%@", "${pageIndex + 1}")) },
            confirmButton = {
                TextButton(onClick = {
                    deletingPage = false
                    val session = notebook?.first
                    val target = pageId
                    if (session != null && target != null && pageCount > 1) {
                        runCatching { session.removePage(target) }
                        pageCount = runCatching { session.pageCount().toInt() }
                            .getOrDefault(maxOf(1, pageCount - 1))
                        // 刪的是最後一頁的話，索引要往回收 —— 不收的話
                        // pageIdAt 拿不到東西，畫面會變成一片空白。
                        pageIndex = pageIndex.coerceIn(0, maxOf(0, pageCount - 1))
                    }
                }) { Text(l10n("delete")) }
            },
            dismissButton = {
                TextButton(onClick = { deletingPage = false }) { Text(l10n("cancel")) }
            }
        )
    }

    /**
     * 對齊選取中的物件。
     *
     * 幾何交給核心的 `alignRects`；這裡只負責「哪個 id 是哪個物件」與把新座標
     * 寫回去。**矩形的順序必須與回傳座標的順序一致**，錯位的話每個物件會搬到
     * 別人的位置。
     *
     * id 由圖層面板給 —— 畫布上的選取是「每種型別各一個」，兩個文字方塊
     * 根本選不起來，而對齊最常用的就是那種情況。
     */
    fun alignObjects(mode: uniffi.padnote_core.FfiAlignMode, ids: List<String>) {
        if (ids.size < 2) return

        val rects = ids.map { id ->
            // 有任何一個找不到就整批不動 —— 只搬一半比不搬更難收拾。
            ObjectGeometry.rectOf(id, textStore, imageStore, tableStore, chartStore, shapeStore)
                ?: return
        }
        val origins = uniffi.padnote_core.alignRects(rects, mode)
        if (origins.size != ids.size) return
        ids.forEachIndexed { i, id ->
            ObjectGeometry.move(id, origins[i].x, origins[i].y,
                textStore, imageStore, tableStore, chartStore, shapeStore)
        }
        textRevision++; imageRevision++; tableRevision++; chartRevision++; shapeRevision++
    }

    openPin?.let { pin ->
        val profile = AccountManager.load(activity, l10n("default_user_name"))
        CommentThreadDialog(
            pin = pin,
            languageTag = deviceLanguageTag(),
            currentUserId = deviceId(activity).toString(),
            currentUserName = profile.displayName,
            currentUserColor = profile.colorHex,
            onChanged = { meta.setCommentPins(notebook?.first, pins); pinRevision++ },
            onDelete = {
                pins = pins.filterNot { it.id == pin.id }.toMutableList()
                meta.setCommentPins(notebook?.first, pins)
                pinRevision++
            },
            onDismiss = { openPin = null }
        )
    }

    if (showProColors) {
        ProColorPicker(
            languageTag = deviceLanguageTag(),
            currentHex = inkColorHex,
            // 挑完直接套到目前的筆 —— 專業色盤最常見的用途就是換筆色。
            onPick = { inkColorHex = it },
            onDismiss = { showProColors = false }
        )
    }

    if (showCalculator) {
        MathCalculatorDialog(
            languageTag = deviceLanguageTag(),
            onInsert = { text ->
                // 插成文字方塊而不是圖片 —— 算式之後還改得動。
                val box = textStore.create(x = 60f, y = 80f)
                box.text = text
                textStore.persist(box)
                textRevision++
                selectedTextId = box.id
                editorMode = EditorMode.TYPE
            },
            onDismiss = { showCalculator = false }
        )
    }

    if (showStackPanel) {
        CanvasStackPanel(
            items = stackItems,
            order = stackOrder,
            languageTag = deviceLanguageTag(),
            onOrderChange = { updated ->
                // 只寫這一頁，其餘頁面與其餘中繼資料欄位原封不動。
                meta.setObjectOrder(notebook?.first, pageIndex, updated)
                stackRevision++
            },
            onAlign = { mode, ids -> alignObjects(mode, ids) },
            onDismiss = { showStackPanel = false }
        )
    }

    editingImage?.let { image ->
        ImageEditor(
            image = image,
            languageTag = deviceLanguageTag(),
            onChanged = { imageStore.persist(it); imageRevision++ },
            onDelete = {
                imageStore.remove(image)
                selectedImageId = null
                imageRevision++
            },
            onDismiss = { editingImage = null }
        )
    }

    editingShapeStyle?.let { shape ->
        ShapeStyleDialog(
            shape = shape,
            languageTag = deviceLanguageTag(),
            onDismiss = { editingShapeStyle = null },
            onApply = { updated ->
                shapeStore.persist(updated)
                shapeRevision++
            }
        )
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

    if (insertingShape) {
        ShapePicker(
            languageTag = deviceLanguageTag(),
            onCommit = { newShapes, newConnections ->
                // 範本的連線指向的是**核心給的 id**，不是範本裡的暫時 id ——
                // 用暫時 id 的話，線會指向不存在的物件，畫面上是一條從空氣
                // 連出來的線。
                val created = mutableMapOf<String, NoteShape>()
                for (shape in newShapes) {
                    created[shape.id] = shapeStore.create(shape)
                }
                for (link in newConnections) {
                    val from = created[link.fromShapeId] ?: continue
                    val to = created[link.toShapeId] ?: continue
                    shapeStore.connect(from, to, link.label)
                }
                shapeRevision++
                insertingShape = false
            },
            onDismiss = { insertingShape = false }
        )
    }

    if (showLayerPanel) {
        LayerPanel(
            shapes = shapeStore.all,
            selection = selectedShapeIds,
            languageTag = deviceLanguageTag(),
            onSelectionChange = { selectedShapeIds = it },
            onShapesChange = { updated ->
                shapeStore.replaceAll(updated)
                shapeRevision++
            },
            onDismiss = { showLayerPanel = false }
        )
    }

    // 插入一張新表格。
    if (insertingTable) {
        TableEditor(
            table = NoteTable(),
            languageTag = deviceLanguageTag(),
            isNew = true,
            onCommit = { table ->
                tableStore.create(table)
                tableRevision++
                insertingTable = false
            },
            onDelete = { insertingTable = false },
            onDismiss = { insertingTable = false }
        )
    }

    // 重新編修既有的表格。
    editingTable?.let { table ->
        TableEditor(
            table = table,
            languageTag = deviceLanguageTag(),
            isNew = false,
            onCommit = { updated ->
                // 位置原地保留：使用者只是改了裡面的內容。
                tableStore.persist(
                    updated.copyTable().apply { x = table.x; y = table.y }
                )
                tableRevision++
                editingTable = null
            },
            onDelete = {
                tableStore.remove(table)
                tableRevision++
                editingTable = null
                selectedTableId = null
            },
            onDismiss = { editingTable = null }
        )
    }

    // 插入一張新圖表。
    if (insertingChart) {
        Dialog(onDismissRequest = { insertingChart = false }) {
            Surface(shape = RoundedCornerShape(12.dp)) {
                ChartStudio(
                    languageTag = deviceLanguageTag(),
                    onCommit = { spec ->
                        chartStore.create(spec)
                        chartRevision++
                        insertingChart = false
                    },
                    onDismiss = { insertingChart = false }
                )
            }
        }
    }

    // 重新編修既有的圖表。帶著原本的設定進去，使用者看到的是自己當初輸入的
    // 數字 —— 而不是一張只能刪掉重做的圖。
    editingChart?.let { chart ->
        Dialog(onDismissRequest = { editingChart = null }) {
            Surface(shape = RoundedCornerShape(12.dp)) {
                ChartStudio(
                    languageTag = deviceLanguageTag(),
                    initial = chart.spec,
                    onCommit = { spec ->
                        // 位置與尺寸原地保留：使用者只是改了裡面的數字。
                        chartStore.persist(chart.copy(spec = spec))
                        chartRevision++
                        editingChart = null
                    },
                    onDismiss = { editingChart = null }
                )
            }
        }
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
/**
 * 開啟這台裝置目前那一本筆記。
 *
 * 走 [NotebookLibrary] 而不是固定檔名：iPad 那邊每一本筆記是一個以 id 命名的
 * 套件，只認 `notebook.padnote` 的話，同步下來的筆記本永遠不會被開啟 ——
 * 檔案躺在資料夾裡，畫面上什麼也沒有。
 */
private fun openNotebook(
    activity: ComponentActivity,
    notebookId: String? = null
): Pair<PadnoteSession, String>? {
    val device = deviceId(activity)
    val id = notebookId ?: NotebookLibrary.currentOrCreate(activity, device) ?: return null
    return NotebookLibrary.open(activity, id, device)
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

    val lang = deviceLanguageTag()
    // 先把另一台裝置新建的筆記本整包抓下來 —— FolderSync 只對齊「本機已經有的
    // 那些套件」，沒見過的它不會主動去拿，那些筆記本就永遠不會出現。
    NotebookLibrary.pullNewNotebooks(activity, remote, lang)
    val result = NotebookLibrary.syncAll(activity, remote, lang)
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

/** `#RRGGBB` → 核心要的 RGBA 位元組（不透明）。 */
private fun hexToRgba(hex: String): ByteArray {
    val value = hex.removePrefix("#")
    if (value.length != 6) return byteArrayOf(0, 0, 0, -1)
    return runCatching {
        val n = value.toLong(16)
        byteArrayOf(
            ((n shr 16) and 0xFF).toByte(),
            ((n shr 8) and 0xFF).toByte(),
            (n and 0xFF).toByte(),
            -1
        )
    }.getOrDefault(byteArrayOf(0, 0, 0, -1))
}
