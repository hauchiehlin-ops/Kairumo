package com.kairumo.padnote

import android.os.Bundle
import java.io.File
import android.view.KeyEvent
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.layout.Box
import com.kairumo.padnote.canvas.SmartMagneticSnap
import com.kairumo.padnote.library.StickyAnnotationAnchor
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.width
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Slider
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.draw.clip
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.FilledTonalButton
import com.kairumo.padnote.ui.InstantTooltip
import com.kairumo.padnote.ui.AppDiagnosticsDialog
import com.kairumo.padnote.sync.SyncLogger
import com.kairumo.padnote.sync.SyncSource
import com.kairumo.padnote.ui.LogExportUtility
import com.kairumo.padnote.ui.SyncLogCard
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.sp
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.mutableStateListOf
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
import com.kairumo.padnote.audio.AudioCodec
import com.kairumo.padnote.canvas.MarqueeHit
import com.kairumo.padnote.canvas.MarqueeLayer
import com.kairumo.padnote.canvas.ObjectMarquee
import com.kairumo.padnote.audio.AudioInsertDialog
import com.kairumo.padnote.audio.AudioLayer
import com.kairumo.padnote.audio.AudioObject
import com.kairumo.padnote.audio.AudioPlayback
import com.kairumo.padnote.image.ImageEditor
import com.kairumo.padnote.image.ImageLayer
import com.kairumo.padnote.image.ImageStore
import com.kairumo.padnote.image.LinkCard
import com.kairumo.padnote.image.LinkLayer
import com.kairumo.padnote.image.LinkObject
import com.kairumo.padnote.image.LinkCodec
import com.kairumo.padnote.image.LinkInsertDialog
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
import com.kairumo.padnote.library.LanguagePickerDialog
import com.kairumo.padnote.library.NotebookMeta
import com.kairumo.padnote.comment.CommentLayer
import com.kairumo.padnote.comment.CommentPin
import com.kairumo.padnote.comment.CommentThreadDialog
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.material3.VerticalDivider
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.testTag
import androidx.compose.foundation.gestures.calculatePan
import androidx.compose.foundation.gestures.calculateZoom
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.PointerType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.runtime.mutableFloatStateOf
import com.kairumo.padnote.canvas.CanvasStackPanel
import com.kairumo.padnote.canvas.PageBackground
import com.kairumo.padnote.canvas.PageSidebar
import com.kairumo.padnote.canvas.LassoSelection
import com.kairumo.padnote.canvas.LassoOverlay
import com.kairumo.padnote.canvas.LassoActionBar
import com.kairumo.padnote.canvas.ContinuousPagesView
import com.kairumo.padnote.canvas.InkSettings
import com.kairumo.padnote.canvas.PageDisplayMode
import com.kairumo.padnote.math.MathCalculatorDialog
import com.kairumo.padnote.canvas.ObjectGeometry
import com.kairumo.padnote.canvas.ProColorPicker
import com.kairumo.padnote.canvas.ProColorWheelDialog
import com.kairumo.padnote.canvas.EditorMode
import com.kairumo.padnote.ui.DynamicPortalIsland
import com.kairumo.padnote.ui.ContextualPortalState
import com.kairumo.padnote.ui.FloatingToolPill
import com.kairumo.padnote.ui.RadialMarkMenu
import com.kairumo.padnote.ui.RadialMenuItem
import com.kairumo.padnote.account.IdentityDialog
import com.kairumo.padnote.library.HomeScreen
import com.kairumo.padnote.library.DocumentTemplateCatalog
import androidx.compose.runtime.CompositionLocalProvider
import com.kairumo.padnote.ui.FoldPosture
import com.kairumo.padnote.ui.rememberFoldPosture
import com.kairumo.padnote.ui.LocalAppLanguage
import com.kairumo.padnote.ui.AppCommand
import com.kairumo.padnote.ui.AppCommands
import com.kairumo.padnote.ui.KairumoTheme
import com.kairumo.padnote.ui.Onboarding
import com.kairumo.padnote.ui.OnboardingScreen
import com.kairumo.padnote.library.NewNotebookDialog
import com.kairumo.padnote.library.RenameNotebookDialog
import com.kairumo.padnote.library.DeleteNotebookDialog
import com.kairumo.padnote.library.NotebookLibrary
import com.kairumo.padnote.library.FolderTree
import com.kairumo.padnote.library.RecordingIndex
import com.kairumo.padnote.library.InsertRecordingDialog
import com.kairumo.padnote.library.SeedNotebooks
import com.kairumo.padnote.library.FolderNameDialog
import com.kairumo.padnote.library.DeleteFolderDialog
import com.kairumo.padnote.library.MoveToFolderDialog
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
import android.content.Context
import android.content.Intent
import androidx.compose.foundation.gestures.detectTapGestures
import com.kairumo.padnote.text.TextBoxLayer
import com.kairumo.padnote.text.TextBoxStore
import androidx.compose.ui.platform.LocalDensity
import androidx.documentfile.provider.DocumentFile
import androidx.compose.runtime.rememberCoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import com.kairumo.padnote.ink.InkEngine
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.draganddrop.dragAndDropTarget
import androidx.compose.ui.draganddrop.DragAndDropEvent
import androidx.compose.ui.draganddrop.DragAndDropTarget
import androidx.compose.ui.draganddrop.mimeTypes
import androidx.compose.ui.draganddrop.toAndroidDragEvent
import com.kairumo.padnote.image.ImageDropPlacement
import com.kairumo.padnote.ink.PageGeometry
import com.kairumo.padnote.ink.SketchRefineBar
import android.view.HapticFeedbackConstants
import androidx.compose.ui.platform.LocalView
import com.kairumo.padnote.ai.NoteIntelligenceSheet
import com.kairumo.padnote.ai.notePlainText
import com.kairumo.padnote.ink.PenHardware
import uniffi.padnote_core.FfiPenOutcome
import com.kairumo.padnote.asset.AssetLibrarySheet
import com.kairumo.padnote.collab.CollaborationManager
import com.kairumo.padnote.collab.CollaborationSheet
import com.kairumo.padnote.asset.renderAssetPng
import com.kairumo.padnote.model3d.Model3DLayer
import com.kairumo.padnote.model3d.Model3DObject
import com.kairumo.padnote.model3d.Model3DStudio
import com.kairumo.padnote.theme.CompositionOverlay
import com.kairumo.padnote.theme.ThemeToolsSheet
import com.kairumo.padnote.ink.InkTool
import com.kairumo.padnote.ink.InkToolbar
import com.kairumo.padnote.ink.InkLatencyMeter
import com.kairumo.padnote.ink.LowLatencyInkCanvas
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.zIndex
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
        com.kairumo.padnote.platform.StartupLogger.log("MainActivity.onCreate 啟動")
        // 跨裝置語言要在畫出任何東西**之前**讀進來，不然第一幀會是舊語言，
        // 使用者會看到介面閃一下才變過去。
        applySyncedLanguage(this)
        com.kairumo.padnote.platform.StartupLogger.log("語言套用完成: ${deviceLanguageTag()}")
        setContent {
            // 用自己的主題，不用 MaterialTheme 的預設值（工作項 S-62）。
            // 預設值是 Material 的基準紫，而且**不跟隨深色模式** ——
            // 使用者把系統切成深色，App 仍然一片白。見 ui/Theme.kt。
            // 介面語言在最外層提供一次（見 ui/LocalAppLanguage.kt）——
            // 畫布上的把手那種葉節點才不必為了兩個無障礙標籤，
            // 把 languageTag 一路串過六個檔案。
            CompositionLocalProvider(LocalAppLanguage provides deviceLanguageTag()) {
            KairumoTheme {
                Surface(modifier = Modifier.fillMaxSize()) {
                    KairumoApp()
                }
            }
            }
        }
    }

    /**
     * 實體鍵盤快捷鍵（見 `ui/AppCommands.kt`）。
     *
     * 用 `onKeyDown` 而不是 `dispatchKeyEvent`：後者在畫面拿到按鍵**之前**
     * 就攔截，文字框裡的 Ctrl+A（全選）之類會被我們吃掉。`onKeyDown` 是
     * 沒有人處理時才輪到 Activity —— 正好是快捷鍵該有的位置。
     */
    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        val command = AppCommands.command(
            keyCode = keyCode,
            ctrlPressed = event?.isCtrlPressed == true,
            shiftPressed = event?.isShiftPressed == true
        )
        if (command != null) {
            AppCommands.send(command)
            return true
        }
        return super.onKeyDown(keyCode, event)
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

    // **資料夾位置放在這裡，不放在 NotebookHome 裡。**
    //
    // 打開一本筆記時 `NotebookHome` 會整個離開組合樹，它裡面的 `remember`
    // 也就跟著沒了 —— 實測：從資料夾裡開一本筆記再返回，人會被丟回最上層。
    // 在巢狀資料夾裡工作時，每開一本筆記就要重新點進去一次。
    var folderId by remember { mutableStateOf<String?>(null) }

    // 首次啟動引導（見 ui/Onboarding.kt）。放在這裡而不是 Activity：
    // 它要能在看完之後就地換成首頁，不必再起一個畫面。
    var onboarding by remember { mutableStateOf(!Onboarding.hasSeen(activity)) }
    if (onboarding) {
        OnboardingScreen(onDone = { onboarding = false })
        return
    }

    val id = openedId
    if (id == null) {
        NotebookHome(
            folderId = folderId,
            onFolderChange = { folderId = it },
            onOpen = { openedId = it }
        )
    } else {
        InkScreen(
            notebookId = id,
            onBack = { openedId = null },
            onOpenNotebook = { openedId = it }
        )
    }
}

/**
 * 首頁：筆記本清單、搜尋、新增、身分、備份。
 *
 * 這一層只負責「把狀態接上 [HomeScreen]」—— 版面在那邊，資料在
 * [NotebookLibrary]，兩邊都不知道對方的存在。
 */
@Composable
private fun NotebookHome(
    folderId: String?,
    onFolderChange: (String?) -> Unit,
    onOpen: (String) -> Unit
) {
    val activity = LocalContext.current as ComponentActivity
    val lang = deviceLanguageTag()
    fun l(key: String) = LocalizationStrings.localized(key, lang)

    val device = remember { deviceId(activity) }
    // 鍵盤快捷鍵：Ctrl+Shift+N 新增筆記（見 ui/AppCommands.kt）。
    // 搜尋的 Ctrl+F 在 HomeScreen 裡收 —— 焦點請求器在搜尋框旁邊。
    var sort by remember { mutableStateOf(NotebookLibrary.Sort.MODIFIED) }
    var revision by remember { mutableIntStateOf(0) }
    var creatingNotebook by remember { mutableStateOf(false) }
    // 換介面語系。原本只有編輯器的「⋯」裡有，使用者得先開一本筆記才找得到。
    var homeLanguagePicker by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        AppCommands.events.collect { command ->
            if (command is AppCommand.NewNotebook) creatingNotebook = true
        }
    }
    var renaming by remember { mutableStateOf<NotebookLibrary.Entry?>(null) }
    var deleting by remember { mutableStateOf<NotebookLibrary.Entry?>(null) }
    var moving by remember { mutableStateOf<NotebookLibrary.Entry?>(null) }
    var creatingFolder by remember { mutableStateOf(false) }
    var renamingFolder by remember { mutableStateOf<FolderTree.Folder?>(null) }
    // 最上層那一層沒有對應的資料夾物件，所以要一個自己的狀態。
    var renamingRoot by remember { mutableStateOf(false) }
    // 首頁的系統診斷。Apple 在頁尾的版本號上，Android 原本只在編輯器選單裡 ——
    // 要回報問題的人得先開一本筆記才找得到那一頁。
    var homeStatus by remember { mutableStateOf(false) }
    var showBackupCreateDialog by remember { mutableStateOf(false) }
    var showBackupRestoreDialog by remember { mutableStateOf(false) }
    var showFolderSyncDialog by remember { mutableStateOf(false) }
    var showCloudSyncDialog by remember { mutableStateOf(false) }
    var deletingFolder by remember { mutableStateOf<FolderTree.Folder?>(null) }
    var editingIdentity by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf<String?>(null) }
    var recording by remember { mutableStateOf(false) }
    var showQuickRecordDialog by remember { mutableStateOf(false) }
    val homeMicPermission = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) {
            showQuickRecordDialog = true
        } else {
            message = LocalizationStrings.localized("mic_permission_blocked", lang)
        }
    }

    var profile by remember {
        mutableStateOf(AccountManager.load(activity, l("default_user_name")))
    }
    // 首頁上的素材圖庫、說明文件與「插入至筆記本」。
    // Apple 的首頁都有，Android 原本只有編輯器的「⋯」裡有 ——
    // 使用者要先開一本筆記才找得到操作說明。
    var homeAssets by remember { mutableStateOf(false) }
    var homeDocs by remember { mutableStateOf<String?>(null) }
    var insertingRecording by remember { mutableStateOf<RecordingIndex.Recording?>(null) }
    val syncFolderPicker = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenDocumentTree()
    ) { uri ->
        if (uri != null) {
            // 走與編輯器同一條路（`FolderSync.setFolder`），不要另外記一份 ——
            // 兩份設定遲早會指到不同的資料夾，而使用者只會看到「同步沒作用」。
            FolderSync.setFolder(activity, uri)
            message = l("sync_choose_folder")
        }
    }

    // 第一次啟動時放兩本有內容的範例筆記。
    //
    // 放在這裡而不是 `NotebookLibrary.currentOrCreate`：那條路只有「直接開一本」
    // 才會走到，從首頁進來的使用者看到的會是空清單。已經有東西就什麼也不做 ——
    // 見 `SeedNotebooks.seedIfEmpty`。
    val seeded = remember { SeedNotebooks.seedIfEmpty(activity, device, lang) }

    // revision 是重讀的觸發器。清單來自檔案系統，沒有觀察者可以訂閱 ——
    // 新增或刪除之後不主動重讀的話，畫面會停在舊的內容。
    val entries = remember(revision, sort, folderId, seeded) {
        NotebookLibrary.all(activity, device, sort, folderId)
    }
    // 搜尋要搜整個筆記庫，不是只搜眼前這一層。
    val allEntries = remember(revision, sort, seeded) {
        NotebookLibrary.all(activity, device, sort)
    }
    val folders = remember(revision, folderId) { FolderTree.subfolders(activity, folderId) }
    val breadcrumb = remember(revision, folderId) { FolderTree.pathTo(activity, folderId) }
    // 搬移對話框要列出**全部**資料夾，不是只有這一層的。
    val allFolders = remember(revision) { FolderTree.all(activity) }
    // 掃整個筆記本目錄，所以不要每次重組都做 —— 綁在 revision 上就好。
    val recordings = remember(revision) { RecordingIndex.recent(activity, device) }

    // 同步都在背景執行緒跑，共用同一個 scope。宣告要在第一個使用點之前 ——
    // Compose 的函式本體是由上往下讀的。
    val autoSyncScope = rememberCoroutineScope()

    // Google 帳號同步的畫面狀態。與 Apple 的 `googleAccountSection` 對應。
    var cloudBusy by remember { mutableStateOf(false) }
    var cloudMessage by remember { mutableStateOf<String?>(null) }
    val authRevision by com.kairumo.padnote.oauth.GoogleAuth.authRevision.collectAsState()
    // `revision` 與 `authRevision` 也當成重讀的觸發器：登入是跳出去系統瀏覽器再回來的，
    // 回來時要重新問一次「現在登入了沒」。
    val signedIn = remember(revision, cloudBusy, authRevision) {
        com.kairumo.padnote.oauth.GoogleAuth.isSignedIn(activity)
    }

    fun runCloudSync() {
        if (cloudBusy) return
        cloudBusy = true
        cloudMessage = l("syncing")
        autoSyncScope.launch {
            val result = withContext(Dispatchers.IO) {
                com.kairumo.padnote.library.CloudSync.runFull(activity, device)
            }
            val meta = result.meta
            cloudBusy = false
            // 成功才記時間 —— 失敗也記的話，「上次同步」會變成
            // 「上次按下按鈕」，那正好是使用者想分辨的兩件事。
            if (meta != null && meta.ok && !meta.needsReauth) {
                com.kairumo.padnote.library.SyncHistory.markGoogleSynced(activity)
                // 順便問一次「這是誰的帳號」。不必新增授權範圍：
                // Drive 的 about.get 在 drive.appdata 底下就讀得到。
                withContext(Dispatchers.IO) {
                    com.kairumo.padnote.library.SyncHistory.setAccount(
                        activity,
                        com.kairumo.padnote.library.CloudSync.accountEmail(activity)
                    )
                }
            }
            cloudMessage = when {
                meta == null -> l("not_signed_in")
                meta.needsReauth -> l("sync_needs_reauth")
                !meta.ok -> l("sync_failed").replace("%@", meta.error)
                // 講出上傳與下載的數量，與 Apple 一致。只說「完成」的話，
                // 使用者分不出「真的傳了東西」與「其實什麼也沒做」。
                else -> l("sync_result")
                    .replace("%1@", result.uploaded.toString())
                    .replace("%2@", result.downloaded.toString())
            }
            if (result.changed.isNotEmpty()) revision++
        }
    }

    LaunchedEffect(authRevision) {
        if (authRevision > 0 && com.kairumo.padnote.oauth.GoogleAuth.isSignedIn(activity)) {
            cloudMessage = "Google 帳號授權成功，正在同步..."
            com.kairumo.padnote.sync.AutoSync.request(
                activity, uniffi.padnote_core.FfiSyncTrigger.SIGNED_IN)
            runCloudSync()
        }
    }

    // 自動同步（P2）。
    //
    // **這一段是「跨裝置感覺得到」的全部差別。** 機制本身早就寫好了，
    // 但在此之前只有「回到首頁」與選單裡那一個按鈕會觸發它 ——
    // 使用者在編輯器裡寫完一段、切到別台打開，什麼也不會發生。
    //
    // 節奏（去抖動、週期、退避）由核心的排程器決定，Apple 端同一套：
    // 兩邊各寫一份的話，使用者看到的不是「排程策略不同」，是「Android 比較慢」。
    //
    // 失敗時**不出訊息**。自動同步是背景行為，網路不通就下次再說；
    // 每次回到首頁都跳一次「同步失敗」只會讓人關掉這個功能。
    val lifecycleOwner = androidx.compose.ui.platform.LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        com.kairumo.padnote.sync.AutoSync.start(activity, device)
        val observer = androidx.lifecycle.LifecycleEventObserver { _, event ->
            when (event) {
                androidx.lifecycle.Lifecycle.Event.ON_RESUME ->
                    com.kairumo.padnote.sync.AutoSync.request(
                        activity, uniffi.padnote_core.FfiSyncTrigger.FOREGROUND)
                // 進背景前推一次：系統隨時可能把行程收掉，
                // 沒推出去的內容要等下次開啟才會走。
                androidx.lifecycle.Lifecycle.Event.ON_PAUSE ->
                    com.kairumo.padnote.sync.AutoSync.request(
                        activity, uniffi.padnote_core.FfiSyncTrigger.BACKGROUND)
                else -> Unit
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    // 同步把別台的 oplog 寫進套件之後，清單要重讀 —— 不重讀的話，
    // 畫面上還是同步前的樣子，使用者會以為同步沒作用。
    val changedNotebooks by com.kairumo.padnote.sync.AutoSync.changedNotebooks.collectAsState()
    LaunchedEffect(changedNotebooks) {
        if (changedNotebooks.isNotEmpty()) {
            revision++
            com.kairumo.padnote.sync.AutoSync.consumeChanged()
        }
    }

    val restorePicker = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenDocument()
    ) { uri ->
        if (uri != null) {
            message = runRestore(activity, uri)
            revision++
        }
    }

    val createBackupPicker = rememberLauncherForActivityResult(
        ActivityResultContracts.CreateDocument("application/zip")
    ) { uri ->
        if (uri != null) {
            message = runBackupToUri(activity, uri)
            revision++
        }
    }

    val importNotePicker = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenDocument()
    ) { uri ->
        if (uri != null) {
            val imported = runImportNote(activity, uri, device)
            if (imported != null) {
                message = l("import_success").replace("%@", imported.title)
                revision++
            } else {
                message = l("import_failed").replace("%@", "")
            }
        }
    }

    LaunchedEffect(Unit) {
        val intent = activity.intent
        val uri = intent?.data
        if (intent?.action == Intent.ACTION_VIEW && uri != null) {
            runImportNote(activity, uri, device)?.let { entry ->
                onOpen(entry.id)
            }
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
            deviceId = device,
            allEntries = allEntries,
            folders = folders,
            breadcrumb = breadcrumb,
            profileName = profile.displayName,
            profileColorHex = profile.colorHex,
            appVersion = "Kairumo v${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})",
            sort = sort,
            recording = recording,
            l = ::l,
            onOpen = onOpen,
            onCreate = { creatingNotebook = true },
            onRename = { renaming = it },
            onDelete = { deleting = it },
            onMove = { moving = it },
            onSortChange = { sort = it },
            onEditIdentity = { editingIdentity = true },
            onToggleRecording = {
                if (AudioCapture.hasPermission(activity)) {
                    showQuickRecordDialog = true
                } else {
                    homeMicPermission.launch(Manifest.permission.RECORD_AUDIO)
                }
            },
            onBackup = { showBackupCreateDialog = true },
            onRestore = { showBackupRestoreDialog = true },
            onImportNotebook = { importNotePicker.launch(arrayOf("*/*")) },
            recordings = recordings,
            cloud = com.kairumo.padnote.library.CloudSyncUiState(
                signedIn = signedIn,
                busy = cloudBusy,
                message = cloudMessage,
                // 哪一個帳號、上次什麼時候同步、自選資料夾在哪裡。
                // 這三行是使用者判斷「同步到底有沒有在動」的唯一依據。
                account = com.kairumo.padnote.library.SyncHistory.account(activity),
                lastSync = com.kairumo.padnote.library.SyncHistory
                    .lastGoogleSync(activity, l("sync_never")),
                folderPath = com.kairumo.padnote.sync.FolderSync.displayPath(activity),
                folderLastSync = com.kairumo.padnote.library.SyncHistory
                    .lastFolderSync(activity, l("sync_never")),
                onSignIn = {
                    // 授權會跳到系統瀏覽器，回來時由 OAuthRedirectActivity 接。
                    com.kairumo.padnote.oauth.GoogleAuth.startSignIn(activity)
                },
                onSyncNow = { runCloudSync() },
                onSignOut = {
                    autoSyncScope.launch {
                        // 撤銷要打網路，不能在主執行緒。
                        withContext(Dispatchers.IO) {
                            com.kairumo.padnote.oauth.GoogleAuth.signOut(activity)
                        }
                        cloudMessage = null
                        // 逼畫面重問一次登入狀態。
                        revision++
                    }
                },
                onOpenDetail = { showCloudSyncDialog = true }
            ),
            onOpenFolder = onFolderChange,
            onCreateFolder = { creatingFolder = true },
            onRenameFolder = { renamingFolder = it },
            onDeleteFolder = { deletingFolder = it },
            onAssetLibrary = { homeAssets = true },
            onChooseSyncFolder = { showFolderSyncDialog = true },
            onSelectLanguage = { homeLanguagePicker = true },
            onOpenManual = { homeDocs = "manual/index.html" },
            onOpenPrivacy = { homeDocs = "legal/privacy.html" },
            onInsertRecording = { insertingRecording = it },
            onRenameRootFolder = {
                // 人在某個資料夾裡就是改那一個；在最上層就是改最上層的顯示名稱。
                val here = breadcrumb.lastOrNull()
                if (here != null) renamingFolder = here else renamingRoot = true
            },
            onOpenDiagnostics = { homeStatus = true },
            onMoveNotebookToFolder = { noteId, targetFolder ->
                // 與「移動到資料夾」選單走同一條路（同一個索引、同一套環狀保護），
                // 不要為了拖放另寫一份 —— 兩份規則遲早會分岔。
                val title = FolderTree.titleOf(activity, noteId) ?: ""
                val ok = FolderTree.move(
                    activity, noteId, title, isFolder = false, toParent = targetFolder
                )
                message = l(if (ok) "move_done" else "move_cycle_refused")
                revision++
            }
        )
    }

    if (homeLanguagePicker) {
        LanguagePickerDialog(
            current = deviceLanguageTag(),
            onPick = { tag ->
                setAppLanguage(activity, tag)
                homeLanguagePicker = false
                // 換語言要整個畫面重畫。重建 Activity 是最省事也最可靠的做法 ——
                // 逐個字串狀態去追，一定會漏掉幾個沒有重組的地方。
                activity.recreate()
            },
            onDismiss = { homeLanguagePicker = false }
        )
    }

    if (homeAssets) {
        // 首頁的素材圖庫只負責瀏覽 —— 要插進畫布得先有一本打開的筆記，
        // 所以這裡挑完之後直接開那一本。與 Apple 首頁的那張卡一致。
        com.kairumo.padnote.asset.AssetLibrarySheet(
            languageTag = lang,
            onInsert = { _, _ ->
                homeAssets = false
                entries.firstOrNull()?.id?.let(onOpen)
            },
            onDismiss = { homeAssets = false }
        )
    }

    homeDocs?.let { asset ->
        androidx.compose.ui.window.Dialog(
            onDismissRequest = { homeDocs = null },
            properties = androidx.compose.ui.window.DialogProperties(
                usePlatformDefaultWidth = false
            )
        ) {
            Surface(modifier = Modifier.fillMaxSize()) {
                Column(modifier = Modifier.fillMaxSize()) {
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 8.dp),
                        horizontalArrangement = Arrangement.End
                    ) {
                        TextButton(onClick = { homeDocs = null }) { Text(l("close")) }
                    }
                    DocsViewer(asset, modifier = Modifier.fillMaxSize())
                }
            }
        }
    }

    insertingRecording?.let { rec ->
        InsertRecordingDialog(
            recording = rec,
            entries = allEntries,
            deviceId = device,
            l = ::l,
            onDismiss = { insertingRecording = null },
            onDone = { error ->
                insertingRecording = null
                message = error ?: l("insert_to_notebook")
                revision++
            }
        )
    }

    if (showQuickRecordDialog) {
        val homeAudio = remember { AudioCapture(activity) }
        var isRec by remember { mutableStateOf(false) }
        var isPaused by remember { mutableStateOf(false) }
        var elapsedSec by remember { mutableIntStateOf(0) }
        var recTitle by remember { mutableStateOf("") }
        var targetNoteId by remember { mutableStateOf<String?>(entries.firstOrNull()?.id) }
        var activeSession by remember { mutableStateOf<PadnoteSession?>(null) }

        LaunchedEffect(isRec, isPaused) {
            if (isRec && !isPaused) {
                while (true) {
                    kotlinx.coroutines.delay(1000L)
                    elapsedSec++
                }
            }
        }

        AlertDialog(
            onDismissRequest = {
                if (isRec) {
                    activeSession?.let { homeAudio.stop(it) }
                    isRec = false
                }
                showQuickRecordDialog = false
            },
            title = { Text(l("quick_record"), fontWeight = FontWeight.Bold) },
            text = {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 8.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    val min = elapsedSec / 60
                    val sec = elapsedSec % 60
                    val timeStr = String.format(java.util.Locale.US, "%02d:%02d", min, sec)

                    Text(
                        text = timeStr,
                        style = MaterialTheme.typography.headlineLarge,
                        fontWeight = FontWeight.Bold,
                        color = if (isRec && !isPaused) Color(0xFFDC2626) else if (isPaused) Color(0xFFF97316) else MaterialTheme.colorScheme.onSurface
                    )

                    if (isPaused) {
                        Text(
                            l("recording_paused"),
                            color = Color(0xFFF97316),
                            style = MaterialTheme.typography.labelMedium,
                            fontWeight = FontWeight.SemiBold,
                            modifier = Modifier.padding(top = 4.dp)
                        )
                    }

                    Spacer(Modifier.height(16.dp))

                    OutlinedTextField(
                        value = recTitle,
                        onValueChange = { recTitle = it },
                        label = { Text(l("recording_title")) },
                        placeholder = { Text(l("enter_recording_title")) },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth()
                    )

                    Spacer(Modifier.height(16.dp))

                    // 筆記附加選項
                    Text(
                        l("attach_to_note"),
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.align(Alignment.Start)
                    )
                    Spacer(Modifier.height(4.dp))
                    var showNotePicker by remember { mutableStateOf(false) }
                    Box(modifier = Modifier.fillMaxWidth()) {
                        OutlinedButton(
                            onClick = { showNotePicker = true },
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            val selTitle = entries.firstOrNull { it.id == targetNoteId }?.title
                                ?: l("standalone_recording")
                            Text(selTitle, maxLines = 1)
                        }
                        DropdownMenu(
                            expanded = showNotePicker,
                            onDismissRequest = { showNotePicker = false }
                        ) {
                            DropdownMenuItem(
                                text = { Text(l("standalone_recording")) },
                                onClick = {
                                    targetNoteId = null
                                    showNotePicker = false
                                }
                            )
                            entries.forEach { entry ->
                                DropdownMenuItem(
                                    text = { Text(entry.title) },
                                    onClick = {
                                        targetNoteId = entry.id
                                        showNotePicker = false
                                    }
                                )
                            }
                        }
                    }

                    Spacer(Modifier.height(20.dp))

                    // 控制按鈕
                    if (isRec) {
                        Row(
                            horizontalArrangement = Arrangement.spacedBy(12.dp),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Button(
                                onClick = {
                                    if (isPaused) {
                                        homeAudio.resume()
                                        isPaused = false
                                    } else {
                                        homeAudio.pause()
                                        isPaused = true
                                    }
                                },
                                modifier = Modifier.weight(1f),
                                colors = ButtonDefaults.buttonColors(
                                    containerColor = if (isPaused) Color(0xFFF97316) else Color(0xFFFED7AA)
                                )
                            ) {
                                Text(
                                    if (isPaused) l("resume_recording") else l("pause_recording"),
                                    color = if (isPaused) Color.White else Color(0xFF9A3412),
                                    fontWeight = FontWeight.Bold
                                )
                            }

                            Button(
                                onClick = {
                                    activeSession?.let { s ->
                                        val us = homeAudio.stop(s)
                                        message = l("recorded_duration").replace("%@", "${us / 1_000_000uL}")
                                    }
                                    isRec = false
                                    isPaused = false
                                    showQuickRecordDialog = false
                                    revision++
                                },
                                modifier = Modifier.weight(1f),
                                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFDC2626))
                            ) {
                                Text(l("stop_and_save_record"), color = Color.White, fontWeight = FontWeight.Bold)
                            }
                        }
                    } else {
                        Button(
                            onClick = {
                                // 沒指定筆記本時落在「錄音收件匣」，不是清單上的
                                // 第一本 —— 那等於把錄音塞進一本完全不相干的筆記。
                                // 收件匣的 id 由核心給，與 Apple 端同一本。
                                val bookId = targetNoteId
                                    ?: NotebookLibrary.recordingInbox(
                                        activity, device, l("recording_inbox"))
                                if (bookId != null) {
                                    val notePath = File(NotebookLibrary.directory(activity), "$bookId.${NotebookLibrary.EXTENSION}")
                                    val session = runCatching {
                                        PadnoteSession.openExisting(notePath.absolutePath, device)
                                    }.getOrNull()
                                    activeSession = session
                                    elapsedSec = 0
                                    isPaused = false
                                    if (session != null) {
                                        val err = homeAudio.start(session, lang)
                                        if (err != null) {
                                            message = err
                                        } else {
                                            isRec = true
                                        }
                                    }
                                }
                            },
                            modifier = Modifier.fillMaxWidth(),
                            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFDC2626))
                        ) {
                            Text(l("quick_record_title"), color = Color.White, fontWeight = FontWeight.Bold)
                        }
                    }
                }
            },
            confirmButton = {},
            dismissButton = {
                TextButton(
                    onClick = {
                        if (isRec) {
                            activeSession?.let { homeAudio.stop(it) }
                            isRec = false
                        }
                        showQuickRecordDialog = false
                    }
                ) {
                    Text(l("close"))
                }
            }
        )
    }

    if (renamingRoot) {
        FolderNameDialog(
            title = l("edit_root_folder"),
            initial = FolderTree.rootName(activity, l("root_folder")),
            l = ::l,
            onDismiss = { renamingRoot = false },
            onConfirm = { name ->
                FolderTree.renameRoot(activity, name)
                renamingRoot = false
                revision++
            }
        )
    }

    if (homeStatus) {
        val rows = remember { readCoreStatus(activity) }
        val packageInfo = remember {
            runCatching {
                activity.packageManager.getPackageInfo(activity.packageName, 0)
            }.getOrNull()
        }
        val ver = packageInfo?.versionName ?: "1.0.0"
        AppDiagnosticsDialog(
            versionString = ver,
            coreStatusRows = rows,
            latencySummary = null,
            l = ::l,
            onDismiss = { homeStatus = false }
        )
    }

    if (showCloudSyncDialog) {
        CloudSyncDetailDialog(
            signedIn = signedIn,
            busy = cloudBusy,
            message = cloudMessage,
            account = com.kairumo.padnote.library.SyncHistory.account(activity),
            lastSync = com.kairumo.padnote.library.SyncHistory.lastGoogleSync(activity, l("sync_never")),
            l = ::l,
            onDismiss = { showCloudSyncDialog = false },
            onSignIn = { com.kairumo.padnote.oauth.GoogleAuth.startSignIn(activity) },
            onSyncNow = { runCloudSync() },
            onSignOut = {
                autoSyncScope.launch {
                    withContext(Dispatchers.IO) {
                        com.kairumo.padnote.oauth.GoogleAuth.signOut(activity)
                    }
                    cloudMessage = null
                    revision++
                }
            }
        )
    }

    if (showBackupCreateDialog) {
        var backupCreating by remember { mutableStateOf(false) }
        var backupResultMsg by remember { mutableStateOf<String?>(null) }
        BackupCreateDetailDialog(
            notebookCount = allEntries.size,
            recordingCount = recordings.size,
            isCreating = backupCreating,
            statusMessage = backupResultMsg,
            l = ::l,
            onDismiss = { showBackupCreateDialog = false },
            onCreateBackup = {
                val stamp = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH-mm-ss", java.util.Locale.US).format(java.util.Date())
                val unique = java.util.UUID.randomUUID().toString().take(6)
                createBackupPicker.launch("Kairumo-$stamp-$unique.kairumobackup")
                showBackupCreateDialog = false
            }
        )
    }

    if (showBackupRestoreDialog) {
        BackupRestoreDetailDialog(
            statusMessage = message,
            l = ::l,
            onDismiss = { showBackupRestoreDialog = false },
            onChooseBackupFile = {
                restorePicker.launch(arrayOf("*/*"))
            }
        )
    }

    if (showFolderSyncDialog) {
        var folderSyncBusy by remember { mutableStateOf(false) }
        var folderSyncMsg by remember { mutableStateOf<String?>(null) }
        val folderPath = FolderSync.displayPath(activity)
        val folderUri = FolderSync.folderUri(activity)
        val folderLastSync = com.kairumo.padnote.library.SyncHistory.lastFolderSync(activity, l("sync_never"))
        FolderSyncDetailDialog(
            folderPath = folderPath,
            isConfigured = folderUri != null,
            lastSync = folderLastSync,
            isSyncing = folderSyncBusy,
            statusMessage = folderSyncMsg,
            l = ::l,
            onDismiss = { showFolderSyncDialog = false },
            onPickFolder = { syncFolderPicker.launch(null) },
            onSyncNow = {
                autoSyncScope.launch {
                    folderSyncBusy = true
                    folderSyncMsg = l("syncing")
                    val res = withContext(Dispatchers.IO) {
                        runFolderSync(activity, null)
                    }
                    if (res.contains(l("sync_result")) || res == l("sync_up_to_date")) {
                        com.kairumo.padnote.library.SyncHistory.markFolderSynced(activity)
                    }
                    folderSyncMsg = res
                    message = res
                    folderSyncBusy = false
                    revision++
                }
            },
            onClearFolder = {
                FolderSync.clearFolder(activity)
                folderSyncMsg = null
                revision++
            }
        )
    }

    if (creatingFolder) {
        FolderNameDialog(
            title = l("new_subfolder"),
            initial = "",
            l = ::l,
            onDismiss = { creatingFolder = false },
            onConfirm = { title ->
                FolderTree.create(activity, title, folderId)
                creatingFolder = false
                revision++
            }
        )
    }

    renamingFolder?.let { folder ->
        FolderNameDialog(
            title = l("rename_folder"),
            initial = folder.title,
            l = ::l,
            onDismiss = { renamingFolder = null },
            onConfirm = { title ->
                FolderTree.rename(activity, folder.id, title)
                renamingFolder = null
                revision++
            }
        )
    }

    deletingFolder?.let { folder ->
        DeleteFolderDialog(
            folder = folder,
            l = ::l,
            onDismiss = { deletingFolder = null },
            onConfirm = {
                FolderTree.delete(activity, folder.id)
                // 人站在被刪掉的那個資料夾裡面時要退回上一層，
                // 否則畫面會停在一個已經不存在的地方，而且空無一物。
                if (folderId == folder.id) onFolderChange(folder.parentId)
                deletingFolder = null
                revision++
            }
        )
    }

    moving?.let { entry ->
        MoveToFolderDialog(
            entryTitle = entry.title,
            folders = allFolders,
            l = ::l,
            onDismiss = { moving = null },
            onPick = { target ->
                val ok = FolderTree.move(
                    activity, entry.id, entry.title, isFolder = false, toParent = target
                )
                message = l(if (ok) "move_done" else "move_cycle_refused")
                moving = null
                revision++
            }
        )
    }

    if (creatingNotebook) {
        NewNotebookDialog(
            // **只列文件範本。** 紙張樣板那個主題掛在上面的紙張清單底下，
            // 兩個地方都列的話同一份範本會有兩個入口。
            themes = DocumentTemplateCatalog.documentThemes(activity),
            lang = catalogLang(lang),
            l = ::l,
            recentTemplates = com.kairumo.padnote.library.RecentTemplates
                .load(activity)
                .mapNotNull { id ->
                    DocumentTemplateCatalog.template(activity, id)
                        ?: DocumentTemplateCatalog.paperTemplate(activity, id)
                },
            onDismiss = { creatingNotebook = false },
            onConfirm = { title, templateId, kind, paperId, paperVariant, paletteId ->
                creatingNotebook = false
                // 建在使用者當下看著的那一層 —— 一律建在最上層的話，
                // 人在某個資料夾裡按「新增」，東西卻出現在別的地方。
                val name = title.ifBlank { l("new_note") }
                // 紙張跟著文件範本走。各選各的話，公文「簽」會鋪在行動端
                // 線框紙上 —— 本文底下壓著兩個手機外框。
                val tmpl = templateId?.let { DocumentTemplateCatalog.template(activity, it) }
                val paper = tmpl?.let { DocumentTemplateCatalog.paperOf(it) }
                    ?: DocumentTemplateCatalog.paperStyle(paperId)
                // 紙張 id 也要記下來：底紋只有六種，而版面（康乃爾的三區、
                // 四象限的十字）跟著 id 走。不記的話重開這本筆記時版面會消失。
                val chosenPaper = tmpl?.let {
                    uniffi.padnote_core.docTemplatePaperId(it.pageStyle)
                } ?: paperId
                val id = NotebookLibrary.create(
                    activity, name, device, folderId, style = paper, paperId = chosenPaper,
                    paletteId = paletteId
                )
                if (id != null) {
                    // 選了文件範本就把內容鋪進去。開檔失敗也不擋 ——
                    // 使用者至少拿得到一本空白筆記，而不是什麼都沒有。
                    if (tmpl != null) {
                        NotebookLibrary.open(activity, id, device, name)?.let { (session, page) ->
                            DocumentTemplateCatalog.apply(
                                session, page, tmpl, kind, catalogLang(lang)
                            )
                        }
                    } else if (paperVariant != null) {
                        // 沒選文件範本，但紙張自己帶了示範內容。
                        DocumentTemplateCatalog.paperTemplate(activity, paperId)?.let { paperTmpl ->
                            NotebookLibrary.open(activity, id, device, name)
                                ?.let { (session, page) ->
                                    DocumentTemplateCatalog.apply(
                                        session, page, paperTmpl, paperVariant, catalogLang(lang)
                                    )
                                }
                        }
                    }
                    // 記下這一次用了哪個樣板，下次直接從「常用樣板」點。
                    val usedId = templateId ?: paperId.takeIf { paperVariant != null }
                    if (usedId != null) {
                        com.kairumo.padnote.library.RecentTemplates.record(activity, usedId)
                    }
                    revision++
                    // 新增之後直接開 —— 建了一本卻停在清單上，使用者還要再點一次。
                    onOpen(id)
                } else {
                    revision++
                }
            }
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
/**
 * 編輯器的工作區：左邊（可選）的頁面結構欄 + 右邊的畫布。
 *
 * 與 Apple 端的 `HStack { notebookStructureSidebar; canvasWorkArea }` 是同一個
 * 版面 —— 側欄在工具列**下面**，不是蓋住整個畫面。
 *
 * 並排與否由核心的 `layoutMetrics(width).sidebarIsInline` 決定：塞不下兩欄
 * 的寬度硬並排，畫布會只剩兩指寬，寫字的地方比工具列還窄。
 */
@Composable
private fun ColumnScope.EditorWorkArea(
    sidebarInline: Boolean,
    /**
     * 折疊機的姿態（S-77）。
     *
     * 攤開的折疊機中間有一道實體摺痕 —— 並排的側欄剛好跨在上面的話，
     * 縮圖會被摺痕切成兩半，畫布的左緣也壓在凹槽裡。鉸鏈是分欄的天然
     * 位置：側欄靠左半邊、畫布靠右半邊，中間把鉸鏈本身讓出來。
     *
     * 非折疊機時是一個空姿態，什麼都不會變。
     */
    posture: FoldPosture = FoldPosture(),
    modifier: Modifier = Modifier.weight(1f),
    sidebar: @Composable () -> Unit,
    canvas: @Composable RowScope.() -> Unit
) {
    Row(modifier = modifier.fillMaxWidth()) {
        if (sidebarInline) {
            val snapToHinge = posture.separatingVertically && posture.hingeStart > 120.dp
            Box(modifier = if (snapToHinge) Modifier.width(posture.hingeStart) else Modifier) {
                sidebar()
            }
            if (snapToHinge) {
                // 鉸鏈本身讓出來。摺痕型（無縫）的機器回 0，那就跟原本一樣。
                Spacer(modifier = Modifier.width(posture.hingeSize))
            }
            VerticalDivider()
        }
        canvas()
    }
}

@OptIn(ExperimentalLayoutApi::class, ExperimentalFoundationApi::class)
@Composable
private fun InkScreen(
    notebookId: String? = null,
    onBack: (() -> Unit)? = null,
    /** 從結構欄的「資料夾目錄」分頁切到另一本筆記（S-96）。 */
    onOpenNotebook: ((String) -> Unit)? = null
) {
    val activity = LocalContext.current as ComponentActivity
    val l10n = { key: String -> uiString(key) }
    // 真的開一本筆記本：沒有 session 的話，匯出與錄音都沒有東西可寫，
    // 這一頁就只是個畫圖玩具而不是筆記 App。
    // 同步把別台的 oplog 寫進套件之後，要重開 session 才看得到 ——
    // 檔案變了，記憶體裡那份還是同步前的。
    var sessionRevision by remember(notebookId) { mutableIntStateOf(0) }
    val notebook = remember(notebookId, sessionRevision) { openNotebook(activity, notebookId) }
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

    /// 頁面顯示模式。記住使用者的選擇 —— 每次開筆記都退回整頁模式的話，
    /// 習慣連續捲動的人每次都要再按一次。與 Apple 端的 AppStorage 對應。
    var pageDisplayMode by remember {
        mutableStateOf(
            PageDisplayMode.fromWire(
                activity.getSharedPreferences("kairumo_editor", android.content.Context.MODE_PRIVATE)
                    .getString("pageDisplayMode", null)
            )
        )
    }


    val pageId = remember(notebook, pageIndex, pageCount) {
        runCatching { notebook?.first?.pageIdAt(pageIndex.toUInt()) }.getOrNull()
            ?: notebook?.second
    }

    val engine = remember(notebook, pageId) {
        InkEngine(session = notebook?.first, pageId = pageId).apply {
            // 一筆畫完就通知同步。**會去抖動** —— 使用者還在寫字時
            // 每一筆都推只是浪費電，而且會拖慢正在編輯的這一本。
            onContentCommitted = { com.kairumo.padnote.sync.AutoSync.noteLocalEdit(activity) }
        }
    }
    // 套索選取。換頁就換一個 —— 選取的是「這一頁的筆畫 id」，
    // 留著會指到另一頁不相干的東西。
    val lasso = remember(notebook, pageId) { LassoSelection() }
    val latency = remember { InkLatencyMeter() }
    val audio = remember { AudioCapture(activity) }
    var recording by remember { mutableStateOf(false) }
    var recordingPaused by remember { mutableStateOf(false) }
    var recordSeconds by remember { mutableIntStateOf(0) }
    var message by remember { mutableStateOf<String?>(null) }
    var docsAsset by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()

    LaunchedEffect(recording, recordingPaused) {
        if (recording && !recordingPaused) {
            while (true) {
                kotlinx.coroutines.delay(1000L)
                recordSeconds++
            }
        }
    }

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
    val maskingTapes = remember { mutableStateListOf<com.kairumo.padnote.canvas.NoteTape>() }

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
    var snapToGrid by remember { mutableStateOf(true) }

    var showProColorWheel by remember { mutableStateOf(false) }
    var minimalistCanvasMode by remember { mutableStateOf(false) }
    var floatingPillExpanded by remember { mutableStateOf(false) }
    var strokeStabilizer by remember { mutableFloatStateOf(0f) }
    var showSymmetryGuide by remember { mutableStateOf(false) }
    var showRadialMenu by remember { mutableStateOf(false) }
    var radialMenuCenter by remember { mutableStateOf(Offset(300f, 300f)) }
    var magneticGuideActive by remember { mutableStateOf(false) }
    var magneticGuideStart by remember { mutableStateOf(Offset.Zero) }
    var magneticGuideEnd by remember { mutableStateOf(Offset.Zero) }

    val contextualState = remember(editorMode, editingText, selectedTextId) {
        if (editorMode == EditorMode.DRAW && (editingText != null || selectedTextId != null)) {
            ContextualPortalState.EditingTextInDrawMode(
                "${l10n("tool_text")} • ${l10n("edit")}"
            )
        } else {
            null
        }
    }

    val effectiveToolbarMode = remember(editorMode, editingText, selectedTextId) {
        if (editorMode == EditorMode.DRAW && (editingText != null || selectedTextId != null)) {
            EditorMode.TYPE
        } else {
            editorMode
        }
    }

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

    // 3D 模型。與圖釘一樣存在筆記本中繼資料（`model3DAttachments`），
    // 讀的是 Apple 端寫進去的同一個鍵。
    var models3D by remember(notebook) { mutableStateOf(meta.models3D()) }
    var model3DRevision by remember { mutableIntStateOf(0) }
    // 連結卡片。真身在中繼資料（`linkAttachments`），與 Apple 同一個鍵 ——
    // 少了這一份，Apple 上建的卡片在 Android 上會整個看不見：資料同步過來了，
    // 畫面上什麼都沒有（`ImageStore` 會跳過那張後備 PNG）。
    var links by remember(notebook) { mutableStateOf(meta.links()) }
    var linkRevision by remember { mutableIntStateOf(0) }
    var selectedLinkId by remember { mutableStateOf<String?>(null) }
    var insertingLink by remember { mutableStateOf(false) }
    var editingLink by remember { mutableStateOf<LinkObject?>(null) }

    // 頁面上的錄音卡片。與連結卡片一樣住在中繼資料（`audioAttachments`），
    // 與 Apple 端同一個鍵 —— 在此之前 Android 讀不到，iPad 上貼在某一頁的
    // 錄音同步過來就像不存在。
    var audioCards by remember(notebook) { mutableStateOf(meta.audioCards()) }
    var audioRevision by remember { mutableIntStateOf(0) }
    var selectedAudioId by remember { mutableStateOf<String?>(null) }
    var playingAudioId by remember { mutableStateOf<String?>(null) }
    var insertingAudio by remember { mutableStateOf(false) }

    // 框選。與 Apple 同一套規則 —— 見 canvas/ObjectMarquee.kt 的說明。
    var marqueeActive by remember { mutableStateOf(false) }
    var marqueeSelection by remember { mutableStateOf(setOf<String>()) }
    var renamingAudio by remember { mutableStateOf<AudioObject?>(null) }
    // 套件裡的錄音目錄。錄音檔就住在這裡（format-spec §5），
    // 播放與「插入錄音」的清單都看它。
    val audioDirectory = remember(notebook, notebookId) {
        val id = notebookId ?: return@remember null
        java.io.File(
            java.io.File(NotebookLibrary.directory(activity), "$id.${NotebookLibrary.EXTENSION}"),
            "media/audio"
        )
    }
    // 離開編輯畫面要放掉播放器 —— 不放的話聲音會在使用者回到首頁之後
    // 繼續播下去，而且畫面上沒有任何東西能停它。
    androidx.compose.runtime.DisposableEffect(notebook) {
        onDispose { AudioPlayback.stop() }
    }
    var selectedModel3DId by remember { mutableStateOf<String?>(null) }
    var editingModel3D by remember { mutableStateOf<Model3DObject?>(null) }
    var insertingModel3D by remember { mutableStateOf(false) }






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
        textRevision, shapeRevision, tableRevision, chartRevision, imageRevision,
        model3DRevision, linkRevision, pageId
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
            models3D.filter { it.pageIndex == pageIndex }.forEach {
                add(ObjectStacking.Item(
                    it.id, ObjectStacking.Kind.MODEL3D,
                    it.title.ifBlank { l10n("model3d_title") }))
            }
            links.filter { it.pageIndex == pageIndex }.forEach {
                add(ObjectStacking.Item(
                    it.id, ObjectStacking.Kind.IMAGE,
                    it.title.ifBlank { l10n("insert_link") }))
            }
            textStore.all.forEach {
                add(ObjectStacking.Item(
                    it.id, ObjectStacking.Kind.TEXT,
                    it.text.trim().take(24).ifBlank { l10n("layer_kind_text") }))
            }
        }
    }

    // 框選要用的「每個物件在哪、多大」。與 stackItems 走同一批來源，
    // 但這裡要的是幾何不是名字。
    val marqueeCandidates = remember(
        textRevision, shapeRevision, tableRevision, chartRevision, imageRevision,
        model3DRevision, linkRevision, audioRevision, pageId
    ) {
        buildList {
            imageStore.all.forEach { add(MarqueeHit(it.id, it.x, it.y, it.width, it.height)) }
            shapeStore.all.forEach { add(MarqueeHit(it.id, it.x, it.y, it.width, it.height)) }
            tableStore.all.forEach {
                // 表格的高度由核心的版面決定，模型上沒有可信的 height。
                val layout = it.layout()
                add(MarqueeHit(it.id, it.x, it.y, it.width, layout.height.toFloat()))
            }
            chartStore.all.forEach { add(MarqueeHit(it.id, it.x, it.y, it.width, it.height)) }
            textStore.all.forEach { add(MarqueeHit(it.id, it.x, it.y, it.width, it.height)) }
            links.filter { it.pageIndex == pageIndex }.forEach {
                add(MarqueeHit(it.id, it.x, it.y, it.width, it.height))
            }
            models3D.filter { it.pageIndex == pageIndex }.forEach {
                add(MarqueeHit(it.id, it.x, it.y, it.width, it.height))
            }
            audioCards.filter { it.pageIndex == pageIndex }.forEach {
                add(MarqueeHit(it.id, it.x, it.y, it.width, it.height))
            }
        }
    }

    /** 把選取的物件整組位移。每一種型別各自寫回自己的 store。 */
    fun moveMarqueeSelection(dx: Float, dy: Float) {
        if (marqueeSelection.isEmpty() || (dx == 0f && dy == 0f)) return
        imageStore.all.filter { it.id in marqueeSelection }.forEach {
            it.x += dx; it.y += dy; imageStore.persist(it)
        }
        shapeStore.all.filter { it.id in marqueeSelection }.forEach {
            shapeStore.persist(it.copyShape().apply { x = it.x + dx; y = it.y + dy })
        }
        tableStore.all.filter { it.id in marqueeSelection }.forEach {
            tableStore.persist(it.copyTable().apply { x = it.x + dx; y = it.y + dy })
        }
        chartStore.all.filter { it.id in marqueeSelection }.forEach {
            chartStore.persist(it.copy(x = it.x + dx, y = it.y + dy))
        }
        textStore.all.filter { it.id in marqueeSelection }.forEach {
            it.x += dx; it.y += dy; textStore.persist(it)
        }
        var linksChanged = false
        links = links.map {
            if (it.id in marqueeSelection) {
                linksChanged = true
                it.copy(x = it.x + dx, y = it.y + dy)
            } else it
        }.toMutableList()
        if (linksChanged) meta.setLinks(notebook?.first, links)

        var modelsChanged = false
        models3D = models3D.map {
            if (it.id in marqueeSelection) {
                modelsChanged = true
                it.copy(x = it.x + dx, y = it.y + dy)
            } else it
        }.toMutableList()
        if (modelsChanged) meta.setModels3D(notebook?.first, models3D)

        var audioChanged = false
        audioCards = audioCards.map {
            if (it.id in marqueeSelection) {
                audioChanged = true
                it.copy(x = it.x + dx, y = it.y + dy)
            } else it
        }.toMutableList()
        if (audioChanged) meta.setAudioCards(notebook?.first, audioCards)

        imageRevision++; shapeRevision++; tableRevision++; chartRevision++
        textRevision++; linkRevision++; model3DRevision++; audioRevision++
    }

    /** 刪掉選取的物件。形狀連同它的連接線一起刪 —— 只刪形狀的話，
     *  線會留在畫布上，兩端各指著一個不存在的東西。 */
    fun deleteMarqueeSelection() {
        if (marqueeSelection.isEmpty()) return
        imageStore.all.filter { it.id in marqueeSelection }.forEach { imageStore.remove(it) }
        shapeStore.all.filter { it.id in marqueeSelection }.forEach { shapeStore.remove(it) }
        tableStore.all.filter { it.id in marqueeSelection }.forEach { tableStore.remove(it) }
        chartStore.all.filter { it.id in marqueeSelection }.forEach { chartStore.remove(it) }
        textStore.all.filter { it.id in marqueeSelection }.forEach { textStore.remove(it) }
        links = links.filter { it.id !in marqueeSelection }.toMutableList()
        meta.setLinks(notebook?.first, links)
        models3D = models3D.filter { it.id !in marqueeSelection }.toMutableList()
        meta.setModels3D(notebook?.first, models3D)
        audioCards = audioCards.filter { it.id !in marqueeSelection }.toMutableList()
        meta.setAudioCards(notebook?.first, audioCards)
        marqueeSelection = emptySet()
        imageRevision++; shapeRevision++; tableRevision++; chartRevision++
        textRevision++; linkRevision++; model3DRevision++; audioRevision++
    }

    /** 建立副本。位移一段距離，貼在原位的話使用者會以為沒成功。 */
    fun duplicateMarqueeSelection() {
        if (marqueeSelection.isEmpty()) return
        val d = ObjectMarquee.PASTE_OFFSET
        val created = mutableSetOf<String>()
        shapeStore.all.filter { it.id in marqueeSelection }.forEach {
            created += shapeStore.create(it.copyShape().apply { x = it.x + d; y = it.y + d }).id
        }
        tableStore.all.filter { it.id in marqueeSelection }.forEach {
            created += tableStore.create(it.copyTable().apply { x = it.x + d; y = it.y + d }).id
        }
        chartStore.all.filter { it.id in marqueeSelection }.forEach {
            created += chartStore.create(it.spec, it.x + d, it.y + d).id
        }
        textStore.all.filter { it.id in marqueeSelection }.forEach { source ->
            val box = textStore.create(source.x + d, source.y + d)
            box.text = source.text
            box.width = source.width
            box.height = source.height
            box.fontSize = source.fontSize
            box.bold = source.bold
            box.italic = source.italic
            box.textColorHex = source.textColorHex
            box.backgroundColorHex = source.backgroundColorHex
            box.hasBorder = source.hasBorder
            textStore.persist(box)
            created += box.id
        }
        // 連結、3D 與錄音卡片住在中繼資料裡，直接複製一份帶新 id。
        val newLinks = links.filter { it.id in marqueeSelection }.map {
            it.copy(id = java.util.UUID.randomUUID().toString(), x = it.x + d, y = it.y + d)
        }
        if (newLinks.isNotEmpty()) {
            links = (links + newLinks).toMutableList()
            meta.setLinks(notebook?.first, links)
            created += newLinks.map { it.id }
        }
        val newAudio = audioCards.filter { it.id in marqueeSelection }.map {
            it.copy(id = java.util.UUID.randomUUID().toString(), x = it.x + d, y = it.y + d)
        }
        if (newAudio.isNotEmpty()) {
            audioCards = (audioCards + newAudio).toMutableList()
            meta.setAudioCards(notebook?.first, audioCards)
            created += newAudio.map { it.id }
        }
        marqueeSelection = created
        imageRevision++; shapeRevision++; tableRevision++; chartRevision++
        textRevision++; linkRevision++; model3DRevision++; audioRevision++
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

    val editorBackupCreatePicker = rememberLauncherForActivityResult(
        ActivityResultContracts.CreateDocument("application/zip")
    ) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        message = runBackupToUri(activity, uri)
    }

    val folderPicker = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenDocumentTree()
    ) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        FolderSync.setFolder(activity, uri)
        message = runFolderSync(activity, notebook?.first)
    }

    // 被永久拒絕之後，畫面上要多一條「開啟設定」—— 那是唯一還走得通的路。
    var micBlocked by remember { mutableStateOf(false) }
    val micPermission = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        val session = notebook?.first
        if (granted && session != null) {
            recordSeconds = 0
            recordingPaused = false
            message = audio.start(session, deviceLanguageTag()) { message = it }
            recording = audio.isRecording
        } else {
            // 被拒之後再按同一顆按鈕，系統**不會再跳對話框** —— 只會直接回
            // 拒絕。所以這裡要講的是「去設定裡開」，而不是重複同一句話。
            micBlocked = true
            message = uiString("mic_permission_blocked")
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

    /**
     * 把第 `from` 頁搬到 `to`（S-86／S-87）。
     *
     * 走核心的 `movePage` —— 它會記進 oplog，所以這個順序**跟著同步走到
     * 別台裝置**。Apple 端的頁面順序住在它自己的檔案裡，所以那邊不必用
     * 這一支；Android 的頁面住在核心裡，沒有它就搬不動。
     */
    fun movePage(from: Int, to: Int) {
        val session = notebook?.first ?: return
        if (from == to) return
        val pageId = runCatching { session.pageIdAt(from.toUInt()) }.getOrNull() ?: return
        runCatching { session.movePage(pageId, to.toUInt()) }
            .onSuccess {
                // 跟著搬過去 —— 停在原本的索引會變成「我搬了一頁，
                // 畫面卻跳到別頁」。
                pageIndex = to.coerceIn(0, maxOf(0, pageCount - 1))
                revision++
            }
    }

    /**
     * 在指定頁面後插入新頁（S-93／S-86）。
     * 若 paperId != null 則套用指定樣板，否則為空白頁。
     */
    fun insertPageAfter(afterIndex: Int, paperId: String?) {
        val s = notebook?.first ?: return
        val tmpl = if (paperId != null) {
            uniffi.padnote_core.paperTemplates().firstOrNull { it.id == paperId }
        } else null
        val style = tmpl?.pageStyle ?: uniffi.padnote_core.PageStyle.BLANK
        val newPageId = runCatching { s.addPage(style) }.getOrNull() ?: return
        val newCount = runCatching { s.pageCount().toInt() }.getOrDefault(pageCount + 1)
        val targetIndex = (afterIndex + 1).coerceAtMost(newCount - 1)
        if (targetIndex < newCount - 1) {
            runCatching { s.movePage(newPageId, targetIndex.toUInt()) }
        }
        if (paperId != null) {
            meta.insertPageTemplate(s, targetIndex, paperId, newCount)
        }
        pageCount = newCount
        pageIndex = targetIndex
        revision++
    }

    /**
     * 刪除指定頁面（S-86）。
     */
    fun deletePageAt(atIndex: Int) {
        val s = notebook?.first ?: return
        if (pageCount <= 1) return
        val target = runCatching { s.pageIdAt(atIndex.toUInt()) }.getOrNull() ?: return
        runCatching { s.removePage(target) }
        meta.removePageTemplate(s, atIndex, pageCount)
        pageCount = runCatching { s.pageCount().toInt() }.getOrDefault(pageCount - 1)
        if (pageIndex >= pageCount) {
            pageIndex = (pageCount - 1).coerceAtLeast(0)
        }
        revision++
    }

    var clearToken by remember { mutableIntStateOf(0) }
    // 改名對話框（頂列的標題點一下就開）。
    var renamingCurrent by remember { mutableStateOf(false) }
    // 跨本複製／搬移頁面（S-91）：(頁次, 是否為搬移)。
    var transferringPage by remember { mutableStateOf<Pair<Int, Boolean>?>(null) }
    // 特殊符號面板（S-97）。
    var showSymbolPicker by remember { mutableStateOf(false) }

    // 把這一頁已經存在檔案裡的筆畫讀回來。
    //
    // 少了這一步，使用者寫的字在重開筆記本之後就消失了 —— 資料其實還在
    // `.padnote` 裡，只是沒有人去讀。物件（文字方塊、表格、形狀）都有各自的
    // `load()`，只有墨跡沒有，所以症狀是「圖還在、字不見了」，
    // 看起來像渲染壞掉而不是少讀一份資料。
    LaunchedEffect(notebook, pageId, penOnly) {
        engine.setPenOnly(penOnly)
        engine.load()
        revision++
        clearToken++   // 低延遲路徑的前緩衝也要重畫，否則讀回來的筆畫不會出現
    }

    // 筆刷、顏色、筆寬。在此之前 Android 只有一支固定的黑色鋼筆，
    // 連橡皮擦都選不到 —— 核心一直支援，缺的只是 UI。
    var inkTool by remember { mutableStateOf(InkTool.FOUNTAIN_PEN) }

    // 最後用過的**筆刷**。觸控筆放開側鍵時要回到它（工作項 S-67）。
    // 記筆刷而不是「上一個工具」：後者在擦完之後可能回到套索。
    var lastBrushTool by remember { mutableStateOf(InkTool.FOUNTAIN_PEN) }
    // 按著側鍵之前選的是哪一支。放開時回到它。
    //
    // `null` 表示「這一次的橡皮擦不是側鍵切出來的」—— 使用者自己在工具列
    // 選的橡皮擦，不能因為他碰了一下側鍵就被換掉。
    var penHeldTool by remember { mutableStateOf<InkTool?>(null) }
    // 有東西正懸在畫布上等著放下（工作項 S-68）。一定要有這個回饋：
    // 拖放看不見目標的話，使用者分不出「這裡不能放」與「放了但沒反應」。
    var isImageDropTargeted by remember { mutableStateOf(false) }
    // 次世代 UI/UX Phase 5: 折疊立起雙屏模式 (Tabletop Mode / Stage Manager Posture)
    var isTabletopManual by remember { mutableStateOf(false) }
    // 次世代 UI/UX Phase 4: 筆跡磁吸對齊與幾何角度引導 (Smart Magnetic Snap)
    var isMagneticSnapActive by remember { mutableStateOf(false) }

    LaunchedEffect(isMagneticSnapActive) {
        engine.isMagneticSnapActive = isMagneticSnapActive
    }
    LaunchedEffect(magneticGuideActive) {
        if (magneticGuideActive) {
            kotlinx.coroutines.delay(1200)
            magneticGuideActive = false
        }
    }
    LaunchedEffect(inkTool) { if (inkTool.kind != null) lastBrushTool = inkTool }

    val view = LocalView.current

    // 換工具。工具列與筆身控制項走同一條路 —— 各寫一份的話，用側鍵切到
    // 橡皮擦時 `engine.isErasing` 會忘了跟著改，症狀是「側鍵選到橡皮擦了，
    // 但畫下去還是墨跡」。
    fun applyInkTool(picked: InkTool) {
        inkTool = picked
        engine.isErasing = picked.isEraser
        picked.kind?.let { engine.tool = it }
        // 離開套索就清掉選取。留著的話，畫面上會浮著一個虛線框與
        // 一排按鈕，而它們作用的對象使用者早就看不出是什麼了。
        if (!picked.isLasso) lasso.clear()
    }

    // 觸控筆側鍵（或把筆倒過來）。
    //
    // **規則不在這裡** —— 「這個動作要做什麼」整張表在核心
    // （`padnote-input::pen`），與 Apple 共用同一份。這裡只把核心回的結果
    // 換成 Android 這一側的工具。
    val penControls = remember { PenHardware.controls(activity) }
    DisposableEffect(engine) {
        engine.onPenControlChanged = { control, pressed ->
            if (control != null) {
                val momentary = penControls.isMomentary(control)
                // 按著的控制項放開時，只還原**我們自己切過去的那一次**。
                // 使用者自己在工具列上選了橡皮擦、然後碰了一下側鍵，
                // 放開時把他的橡皮擦換掉是錯的。
                val shouldHandle = !momentary || pressed || penHeldTool != null
                if (shouldHandle) {
                    if (momentary && pressed) penHeldTool = inkTool

                    when (penControls.outcome(
                        control, pressed, inkTool.isEraser, inkTool.isLasso
                    )) {
                        FfiPenOutcome.NOTHING -> Unit
                        FfiPenOutcome.USE_ERASER -> applyInkTool(InkTool.ERASER)
                        // 放開時回到按下去之前那一支，而不是「最後用過的筆刷」
                        // —— 兩者通常一樣，但使用者若在按著側鍵的期間又換過筆，
                        // 他要的是回到他剛剛選的那一支。
                        FfiPenOutcome.USE_LAST_BRUSH ->
                            applyInkTool(penHeldTool ?: lastBrushTool)
                        FfiPenOutcome.USE_LASSO -> applyInkTool(InkTool.LASSO)
                        FfiPenOutcome.SHOW_INK_ATTRIBUTES -> showProColors = true
                        // **復原、重做與尺規在 Android 的手寫畫布上還不存在**
                        // （工具列沒有這三顆按鈕），所以指派到它們等於關掉。
                        // 這樣比硬湊一個行為好：按了沒反應，使用者會去換一個
                        // 指派；按了做出別的事，他會以為是壞的。
                        //
                        // 核心那張表是兩個平台共用的，有這三個選項是因為 Apple
                        // 那邊做得到 —— 之後 Android 補上時，這裡改成真的呼叫即可。
                        FfiPenOutcome.UNDO,
                        FfiPenOutcome.REDO,
                        FfiPenOutcome.TOGGLE_RULER -> Unit
                    }

                    if (momentary && !pressed) penHeldTool = null
                    // 筆身的動作是看不見的 —— 使用者當下正看著筆尖，
                    // 一下短回饋讓他知道剛剛那下有收到。
                    view.performHapticFeedback(HapticFeedbackConstants.CONTEXT_CLICK)
                }
            }
        }
        engine.onMagneticSnap = { start, end ->
            magneticGuideStart = start
            magneticGuideEnd = end
            magneticGuideActive = true
            view.performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
        }
        onDispose {
            engine.onPenControlChanged = null
            engine.onMagneticSnap = null
        }
    }
    // Ctrl+1–Ctrl+6 選工具。索引超過工具數就忽略 —— Apple 有九支、
    // Android 只有六支，按 Ctrl+7 不該讓 App 當掉。
    LaunchedEffect(Unit) {
        AppCommands.events.collect { command ->
            when (command) {
                is AppCommand.SelectTool ->
                    InkTool.entries.getOrNull(command.index)?.let { inkTool = it }
                // 切回手寫時要清掉選取 —— 與工具列上那顆按鈕做的事一樣。
                // 只翻模式不清的話，畫面上會浮著一組在手寫模式下按不動的把手。
                is AppCommand.ToggleEditorMode ->
                    if (editorMode == EditorMode.DRAW) {
                        editorMode = EditorMode.TYPE
                    } else {
                        editorMode = EditorMode.DRAW
                        selectedTextId = null
                    }
                else -> Unit
            }
        }
    }
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

    /// 草圖美化控制列。與 Apple 端一樣是**浮動列**而不是對話框：
    /// 調強度時要看得到畫布上的變化，對話框會把畫布蓋住。
    var showRefineBar by remember { mutableStateOf(false) }

    /// 主題專屬工具與它的兩個構圖輔助疊層。
    var showThemeTools by remember { mutableStateOf(false) }
    var showAssetLibrary by remember { mutableStateOf(false) }

    /// 協同編輯。與 Apple 端講同一套協定（房號、邀請連結、端對端加密都在核心）。
    var showCollaboration by remember { mutableStateOf(false) }
    /// 語言選擇。Apple 端一直有，Android 原本只能跟著系統語系走 ——
    /// 而語言是跨裝置設定（G-04），在這台改了也要傳到別台。
    var showLanguagePicker by remember { mutableStateOf(false) }
    // 摘要與待辦（工作項 S-20）。
    var showNoteIntelligence by remember { mutableStateOf(false) }
    // 標題只在摘要時用得到，而編輯器畫面上不顯示它 —— 查一次存著，
    // 不要每次重組都去掃一遍筆記庫。
    val noteTitle = remember(notebookId) {
        notebookId?.let { id ->
            runCatching {
                NotebookLibrary.all(activity, deviceId(activity))
                    .firstOrNull { it.id == id }?.title
            }.getOrNull()
        }.orEmpty()
    }
    val collaboration = remember { CollaborationManager(activity) }
    var goldenSpiral by remember { mutableStateOf(false) }
    var ruleOfThirds by remember { mutableStateOf(false) }
    /// 美化後按鈕的可用狀態要跟著變（engine 才是真相來源，這只是重繪訊號）。
    var refineRevision by remember { mutableIntStateOf(0) }


    // 系統返回鍵＝回首頁。Android 使用者按的第一個東西就是它，
    // 不接的話按下去會直接把 App 關掉 —— 看起來像當掉。
    if (minimalistCanvasMode) {
        androidx.activity.compose.BackHandler {
            minimalistCanvasMode = false
            floatingPillExpanded = false
        }
    } else if (onBack != null) {
        // 系統返回鍵。Android 專有（規格裡標成 AndroidOnly）——
        // 沒有它的話，使用者按下返回鍵會直接離開 App 而不是回到首頁。
        // parity: editor.system_back
        androidx.activity.compose.BackHandler { onBack() }
    }
    var showMenu by remember { mutableStateOf(false) }
    // 頁面結構欄。與 Apple 端一樣預設收起來 —— 手機上它會吃掉大半個畫布。
    var showPageSidebar by remember { mutableStateOf(false) }
    // 畫布的縮放與平移。換頁時歸位 —— 上一頁放大到 3 倍之後翻頁，
    // 新的一頁還停在同一個放大位置，使用者會以為翻頁沒成功。
    var canvasScale by remember(pageId) { mutableFloatStateOf(1f) }
    var canvasOffset by remember(pageId) { mutableStateOf(Offset.Zero) }
    var canvasViewport by remember { mutableStateOf(Size.Zero) }
    // 這一格畫面有多寬，決定側欄要並排還是覆蓋。**用實際寬度算**，
    // 不是查尺寸級別的表：摺疊機與分割視窗的寬度是連續變化的。
    val configuration = LocalConfiguration.current
    val layout = remember(configuration.screenWidthDp) {
        uniffi.padnote_core.layoutMetrics(configuration.screenWidthDp.toFloat())
    }
    // 折疊機的鉸鏈在哪（S-77）。Configuration 給得出寬度，給不出「畫面
    // 中間橫著一條摺痕」—— 而內容壓在摺痕上是折疊機最明顯的毛病。
    val posture = rememberFoldPosture(activity)
    val isTabletopActive = posture.separatingHorizontally || isTabletopManual

    Column(modifier = Modifier.fillMaxSize().statusBarsPadding()) {
        // 只有兩個切換留在工具列上，其餘進溢位選單。
        //
        // 工具列分兩排，與 Apple 端一致（工作項 S-59）。
        //
        // **第一排是「這個畫面本身」，第二排是「目前模式的工具」。**
        // 原本全部攤在同一個 FlowRow 裡，在 320dp 的手機上會換成四五行、
        // 佔掉半個螢幕 —— 而且手寫工具在打字模式下照樣列著，使用者看不出
        // 哪些按鈕現在有意義。Apple 那邊第二排是跟著模式換的。
        //
        // 仍然用 FlowRow 而不是 Row：窄螢幕上 Row 會把最後一個元素壓成
        // 一欄一個字的直書（實機看過「Stylus Only」被壓成一直條）。
        FlowRow(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 6.dp),
            horizontalArrangement = Arrangement.spacedBy(6.dp),
            verticalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            // 回首頁。沒有這顆的話，進了筆記就出不來了 ——
            // Android 的系統返回鍵在單一 Compose 畫面裡不會有任何作用。
            if (onBack != null) {
                TextButton(
                    onClick = onBack,
                    modifier = Modifier.testTag("editor.home")
                ) { Text("‹ ${l10n("back_to_home")}") }
            }
            if (minimalistCanvasMode) {
                // 🌟 畫布極簡模式恢復按鈕（讓使用者一秒找到退出鍵）
                FilledTonalButton(
                    onClick = {
                        minimalistCanvasMode = false
                        floatingPillExpanded = false
                    },
                    contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp),
                    modifier = Modifier.height(36.dp).testTag("editor.exit_minimalist")
                ) {
                    Text("⤢ ", fontSize = 14.sp, fontWeight = FontWeight.Bold)
                    Text(l10n("exit_canvas_minimal_mode"), fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                }

                // 筆記標題（極簡模式下保留以辨識當前筆記）
                run {
                    val title = remember(notebookId, revision) {
                        notebookId?.let { FolderTree.titleOf(activity, it) }
                            ?: l10n("untitled_note")
                    }
                    TextButton(
                        onClick = { renamingCurrent = true },
                        modifier = Modifier.testTag("editor.title")
                    ) {
                        Text(
                            title.ifBlank { l10n("untitled_note") },
                            style = MaterialTheme.typography.labelLarge,
                            maxLines = 1
                        )
                    }
                }
            } else {
                // 流體動態傳送門 (Dynamic Portal Island)。
                // 決定畫布模式並支援即時情境展開（如手繪模式中編輯文字方塊）。
                DynamicPortalIsland(
                    currentMode = editorMode,
                    contextualState = contextualState,
                    languageTag = deviceLanguageTag(),
                    onModeChange = { newMode ->
                        editorMode = newMode
                        if (newMode == EditorMode.DRAW) {
                            selectedTextId = null
                            selectedShapeIds = emptySet()
                            selectedTableId = null
                            selectedChartId = null
                        }
                    }
                )

                // 極簡畫布切換（收折工具列為懸浮膠囊）
                InstantTooltip(text = l10n("enter_canvas_minimal_mode")) {
                    IconButton(
                        onClick = {
                            minimalistCanvasMode = true
                            floatingPillExpanded = false
                        },
                        modifier = Modifier.size(36.dp)
                    ) {
                        Text("⤡", fontSize = 14.sp)
                    }
                }

            // 徑向飛輪快捷工具盤 (Radial Pie Menu) 手動喚醒按鈕
            IconButton(
                onClick = {
                    radialMenuCenter = Offset(
                        if (canvasViewport.width > 0) canvasViewport.width / 2f else 300f,
                        if (canvasViewport.height > 0) canvasViewport.height / 2f else 300f
                    )
                    showRadialMenu = !showRadialMenu
                },
                modifier = Modifier.size(36.dp).testTag("editor.radialMenuToggle")
            ) {
                Text(
                    text = if (showRadialMenu) "◎" else "○",
                    fontSize = 15.sp,
                    color = if (showRadialMenu) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface
                )
            }

            // 立起雙屏模式切換 (Tabletop Mode)
            IconButton(
                onClick = { isTabletopManual = !isTabletopManual },
                modifier = Modifier.size(36.dp).testTag("editor.tabletop_mode")
            ) {
                Text(
                    text = if (isTabletopActive) "⧉" else "⬚",
                    fontSize = 15.sp,
                    color = if (isTabletopActive) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface
                )
            }

            // 筆記標題。Apple 的頂列一直有，點一下就能改名；Android 原本
            // **完全沒有顯示筆記名稱** —— 開了三本筆記之後分不出自己在哪一本。
            run {
                val title = remember(notebookId, revision) {
                    notebookId?.let { FolderTree.titleOf(activity, it) }
                        ?: l10n("untitled_note")
                }
                TextButton(
                    onClick = { renamingCurrent = true },
                    modifier = Modifier.testTag("editor.title")
                ) {
                    Text(
                        title.ifBlank { l10n("untitled_note") },
                        style = MaterialTheme.typography.labelLarge,
                        maxLines = 1
                    )
                }
            }

            // 頁面結構欄的開關。Apple 端工具列上就有這一顆。
            TextButton(
                onClick = { showPageSidebar = !showPageSidebar },
                modifier = Modifier.testTag("editor.sidebar_toggle")
            ) {
                Text(
                    l10n("structure_pages"),
                    style = MaterialTheme.typography.labelSmall,
                    color = if (showPageSidebar) {
                        MaterialTheme.colorScheme.primary
                    } else {
                        MaterialTheme.colorScheme.onSurface
                    }
                )
            }

            // 分頁導覽。與 Apple 端同一組：上一頁 · 頁碼 · 下一頁 · 新增。
            TextButton(
                onClick = { if (pageIndex > 0) pageIndex-- },
                enabled = pageIndex > 0,
                modifier = Modifier.testTag("editor.page.prev")
            ) { Text("‹") }
            Text(
                "${pageIndex + 1}/${maxOf(1, pageCount)}",
                style = MaterialTheme.typography.labelMedium,
                modifier = Modifier.padding(top = 14.dp).testTag("editor.page.indicator")
            )
            TextButton(
                onClick = { if (pageIndex < pageCount - 1) pageIndex++ },
                enabled = pageIndex < pageCount - 1,
                modifier = Modifier.testTag("editor.page.next")
            ) { Text("›") }
            TextButton(modifier = Modifier.testTag("editor.page.display_mode"), onClick = {
                pageDisplayMode = if (pageDisplayMode == PageDisplayMode.CONTINUOUS) {
                    PageDisplayMode.SINGLE
                } else {
                    PageDisplayMode.CONTINUOUS
                }
                activity.getSharedPreferences("kairumo_editor", android.content.Context.MODE_PRIVATE)
                    .edit().putString("pageDisplayMode", pageDisplayMode.wire).apply()
            }) {
                Text(
                    l10n(
                        if (pageDisplayMode == PageDisplayMode.CONTINUOUS) "page_mode_continuous"
                        else "page_mode_single"
                    ),
                    style = MaterialTheme.typography.labelSmall
                )
            }
            TextButton(modifier = Modifier.testTag("editor.page.add"), onClick = {
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
            // 頁面規格（S-84）。Apple 的頂列一直都有這一顆，Android 原本
            // 連「這本筆記是什麼尺寸」都看不到。
            Box {
                var formatMenu by remember { mutableStateOf(false) }
                val meta = remember(notebookId, revision) {
                    com.kairumo.padnote.library.NotebookMeta.load(notebook?.first)
                }
                val currentFormat = remember(meta) {
                    meta.pageFormatId().ifEmpty { uniffi.padnote_core.defaultPageFormatId() }
                }
                TextButton(
                    onClick = { formatMenu = true },
                    modifier = Modifier.testTag("editor.page_format")
                ) {
                    Text(
                        l10n(uniffi.padnote_core.pageFormat(currentFormat).titleKey),
                        style = MaterialTheme.typography.labelSmall
                    )
                }
                DropdownMenu(expanded = formatMenu, onDismissRequest = { formatMenu = false }) {
                    uniffi.padnote_core.pageFormats().forEach { format ->
                        DropdownMenuItem(
                            text = { Text(l10n(format.titleKey)) },
                            trailingIcon = { if (format.id == currentFormat) Text("✓") },
                            onClick = {
                                formatMenu = false
                                meta.setPageFormatId(notebook?.first, format.id)
                                com.kairumo.padnote.ink.PageGeometry.use(format.id)
                                revision++
                            }
                        )
                    }
                }
            }

            // 版面配色（S-93）。建立筆記時選過，之後也改得動 —— 與 Apple 一致。
            Box {
                var paletteMenu by remember { mutableStateOf(false) }
                val meta = remember(notebookId, revision) {
                    com.kairumo.padnote.library.NotebookMeta.load(notebook?.first)
                }
                val currentPalette = remember(meta) {
                    meta.paletteId().ifEmpty { uniffi.padnote_core.guidePalettes().first().id }
                }
                TextButton(
                    onClick = { paletteMenu = true },
                    modifier = Modifier.testTag("editor.guide_palette")
                ) {
                    Text(
                        l10n(
                            uniffi.padnote_core.guidePalettes()
                                .firstOrNull { it.id == currentPalette }?.nameKey
                                ?: "guide_palette"
                        ),
                        style = MaterialTheme.typography.labelSmall
                    )
                }
                DropdownMenu(expanded = paletteMenu, onDismissRequest = { paletteMenu = false }) {
                    uniffi.padnote_core.guidePalettes().forEach { palette ->
                        DropdownMenuItem(
                            text = { Text(l10n(palette.nameKey)) },
                            trailingIcon = { if (palette.id == currentPalette) Text("✓") },
                            onClick = {
                                paletteMenu = false
                                meta.setPaletteId(notebook?.first, palette.id)
                                revision++
                            }
                        )
                    }
                }
            }

            // 復原／重做（S-64 的缺口）。Apple 的兩個工具列上都有，
            // Android 原本**完全沒有** —— 寫錯一筆只能用橡皮擦擦掉。
            TextButton(
                onClick = { if (engine.undo()) { revision++; clearToken++ } },
                enabled = engine.canUndo,
                modifier = Modifier.testTag(
                    if (editorMode == EditorMode.DRAW) "editor.ink.undo" else "editor.text.undo"
                )
            ) { Text("↶") }
            TextButton(
                onClick = { if (engine.redo()) { revision++; clearToken++ } },
                enabled = engine.canRedo,
                modifier = Modifier.testTag(
                    if (editorMode == EditorMode.DRAW) "editor.ink.redo" else "editor.text.redo"
                )
            ) { Text("↷") }

            var showShareMenu by remember { mutableStateOf(false) }
            TextButton(
                onClick = { showShareMenu = true },
                modifier = Modifier.testTag("editor.share")
            ) { Text("↗") }

            DropdownMenu(expanded = showShareMenu, onDismissRequest = { showShareMenu = false }) {
                DropdownMenuItem(
                    text = { Text(l10n("export_pdf")) },
                    modifier = Modifier.testTag("editor.export.pdf"),
                    onClick = {
                        showShareMenu = false
                        message = exportAndShare(activity, notebook?.first, Exporter.Format.PDF)
                    }
                )
                DropdownMenuItem(
                    text = { Text(l10n("export_image")) },
                    modifier = Modifier.testTag("editor.export.image"),
                    onClick = {
                        showShareMenu = false
                        message = exportAndShare(activity, notebook?.first, Exporter.Format.PNG)
                    }
                )
                DropdownMenuItem(
                    text = { Text(l10n("export_markdown")) },
                    onClick = {
                        showShareMenu = false
                        message = exportAndShare(activity, notebook?.first, Exporter.Format.MARKDOWN)
                    }
                )
                DropdownMenuItem(
                    text = { Text(l10n("print_note")) },
                    modifier = Modifier.testTag("editor.export.print"),
                    onClick = {
                        showShareMenu = false
                        val session = notebook?.first ?: return@DropdownMenuItem
                        runCatching { Exporter.print(activity, session) }
                            .onFailure { message = it.message }
                    }
                )
                Divider()
                DropdownMenuItem(
                    text = { Text(l10n("share_note")) },
                    modifier = Modifier.testTag("editor.export.share"),
                    onClick = {
                        showShareMenu = false
                        val id = notebook?.second ?: notebookId
                        if (id != null) {
                            val dir = File(NotebookLibrary.directory(activity), "$id.${NotebookLibrary.EXTENSION}")
                            val title = FolderTree.titleOf(activity, id) ?: "Notebook"
                            message = shareNotebookPackage(activity, dir, title)
                        }
                    }
                )
            }

            TextButton(
                onClick = { showMenu = true },
                modifier = Modifier.testTag("editor.more")
            ) { Text("⋯") }

            DropdownMenu(expanded = showMenu, onDismissRequest = { showMenu = false }) {
                DropdownMenuItem(
                    text = { Text(l10n("ink_clear")) },
                    modifier = Modifier.testTag("editor.ink.clear"),
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
                    modifier = Modifier.testTag("editor.record"),
                    onClick = {
                        showMenu = false
                        val session = notebook?.first ?: return@DropdownMenuItem
                        if (recording) {
                            val us = audio.stop(session)
                            recording = false
                            recordingPaused = false
                            message = l10n("recorded_duration").replace("%@", "${us / 1_000_000uL}")
                        } else if (AudioCapture.hasPermission(activity)) {
                            recordSeconds = 0
                            recordingPaused = false
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
                DropdownMenuItem(
                    text = { Text(l10n("share_note")) },
                    onClick = {
                        showMenu = false
                        val id = notebook?.second ?: notebookId
                        if (id != null) {
                            val dir = File(NotebookLibrary.directory(activity), "$id.${NotebookLibrary.EXTENSION}")
                            val title = FolderTree.titleOf(activity, id) ?: "Notebook"
                            message = shareNotebookPackage(activity, dir, title)
                        }
                    }
                )
                Divider()
                DropdownMenuItem(
                    text = { Text(l10n("add_comment_pin")) },
                    modifier = Modifier.testTag("editor.insert.comment_pin"),
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
                    modifier = Modifier.testTag("editor.insert.math"),
                    onClick = { showMenu = false; showCalculator = true }
                )
                DropdownMenuItem(
                    text = { Text(l10n("layers_panel")) },
                    modifier = Modifier.testTag("editor.insert.layers"),
                    onClick = { showMenu = false; showStackPanel = true }
                )
                DropdownMenuItem(
                    text = { Text(l10n("refine_sketch")) },
                    modifier = Modifier.testTag("editor.insert.refine_sketch"),
                    onClick = { showMenu = false; showRefineBar = true }
                )
                // 摘要與待辦（工作項 S-20）。核心的 `llm_summarize` 早就在
                // FFI 上，缺的一直是這一顆按鈕。
                DropdownMenuItem(
                    text = { Text(l10n("ai_summary")) },
                    modifier = Modifier.testTag("editor.insert.ai_summary"),
                    onClick = { showMenu = false; showNoteIntelligence = true }
                )
                DropdownMenuItem(
                    text = { Text(l10n("posture_tabletop_mode")) },
                    modifier = Modifier.testTag("editor.tabletop_mode_menu"),
                    onClick = {
                        showMenu = false
                        isTabletopManual = !isTabletopManual
                    }
                )
                DropdownMenuItem(
                    text = { Text(l10n("theme_tools")) },
                    modifier = Modifier.testTag("editor.insert.theme_tools"),
                    onClick = { showMenu = false; showThemeTools = true }
                )
                DropdownMenuItem(
                    text = { Text(l10n("insert_3d")) },
                    modifier = Modifier.testTag("editor.insert.model3d"),
                    onClick = { showMenu = false; insertingModel3D = true }
                )
                DropdownMenuItem(
                    text = { Text(l10n("asset_library")) },
                    modifier = Modifier.testTag("editor.insert.assets"),
                    onClick = { showMenu = false; showAssetLibrary = true }
                )
                DropdownMenuItem(
                    text = { Text(l10n("collaborate")) },
                    modifier = Modifier.testTag("editor.insert.collaborate"),
                    onClick = { showMenu = false; showCollaboration = true }
                )
                DropdownMenuItem(
                    text = { Text(l10n("language")) },
                    onClick = { showMenu = false; showLanguagePicker = true }
                )
                DropdownMenuItem(
                    text = {
                        Text(
                            if (com.kairumo.padnote.oauth.GoogleAuth.isSignedIn(activity)) {
                                l10n("cloud_sync")
                            } else {
                                l10n("sign_in_google")
                            }
                        )
                    },
                    onClick = {
                        showMenu = false
                        if (!com.kairumo.padnote.oauth.GoogleAuth.isSignedIn(activity)) {
                            // 授權會跳到系統瀏覽器，回來時由 OAuthRedirectActivity 接。
                            com.kairumo.padnote.oauth.GoogleAuth.startSignIn(activity)
                            return@DropdownMenuItem
                        }
                        message = l10n("syncing")
                        scope.launch {
                            // 同步會阻塞網路 I/O —— 一定要在背景執行緒，
                            // 在主執行緒跑會直接卡死畫面。
                            val result = withContext(Dispatchers.IO) {
                                // 中繼資料 → 再逐本同步內容。順序不能反：
                                // 先收斂索引才知道哪些筆記本還活著，不然會把
                                // 另一台已經刪掉的筆記本內容又推上去。
                                com.kairumo.padnote.library.CloudSync.runFull(activity, deviceId(activity), notebookId)
                            }
                            val meta = result.meta
                            message = when {
                                meta == null -> l10n("not_signed_in")
                                meta.needsReauth -> l10n("sync_needs_reauth")
                                !meta.ok -> l10n("sync_failed").replace("%@", meta.error)
                                else -> l10n("sync_result")
                                    .replace("%1@", "${result.uploaded}")
                                    .replace("%2@", "${result.downloaded}")
                            }
                            // **只重開這一本的 session，不要 recreate 整個 Activity。**
                            // recreate 會把使用者當下的一切打掉：捲動位置、選取範圍、
                            // 開著的面板、還沒送出的文字方塊內容。而真正需要重載的
                            // 只有「這一本剛好被別台改過」這一種情況。
                            if (notebookId != null && result.changed.contains(notebookId)) {
                                sessionRevision++
                            }
                        }
                    }
                )
                DropdownMenuItem(
                    text = { Text(l10n("insert_image")) },
                    modifier = Modifier.testTag("editor.insert.image"),
                    onClick = { showMenu = false; imagePicker.launch(arrayOf("image/*")) }
                )
                DropdownMenuItem(
                    text = { Text(l10n("insert_link")) },
                    onClick = { showMenu = false; insertingLink = true }
                )
                DropdownMenuItem(
                    text = { Text(l10n("insert_audio")) },
                    modifier = Modifier.testTag("editor.insert.audio"),
                    onClick = { showMenu = false; insertingAudio = true }
                )
                DropdownMenuItem(
                    text = { Text(l10n("marquee_select")) },
                    onClick = {
                        showMenu = false
                        marqueeActive = !marqueeActive
                        if (!marqueeActive) marqueeSelection = emptySet()
                        // 框選只在打字模式下有意義 —— 手繪模式下物件本來就
                        // 不吃觸控，框了也動不了。
                        if (marqueeActive) editorMode = EditorMode.TYPE
                    }
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
                    modifier = Modifier.testTag("editor.insert.chart"),
                    onClick = { showMenu = false; insertingChart = true }
                )
                DropdownMenuItem(
                    text = { Text(l10n("table_studio")) },
                    modifier = Modifier.testTag("editor.insert.table"),
                    onClick = { showMenu = false; insertingTable = true }
                )
                DropdownMenuItem(
                    text = { Text(l10n("shape_studio")) },
                    modifier = Modifier.testTag("editor.insert.shape"),
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
                    onClick = { 
                        showMenu = false
                        val stamp = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH-mm-ss", java.util.Locale.US).format(java.util.Date())
                        val unique = java.util.UUID.randomUUID().toString().take(6)
                        editorBackupCreatePicker.launch("Kairumo-$stamp-$unique.kairumobackup")
                    }
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
                    modifier = Modifier.testTag("editor.insert.recognize"),
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
    }

    if (!minimalistCanvasMode) {
        // ── 第二排：目前模式的工具 ────────────────────────────────
        //
        // 與 Apple 一致：手寫模式顯示筆刷與顏色，打字模式顯示文字與物件的
        // 工具。原本兩種工具同時列著 —— 使用者在打字模式下看到一整排筆，
        // 點下去卻畫不出東西（因為 S-59 之前筆還畫得出來，之後就更怪了）。
        FlowRow(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp),
            horizontalArrangement = Arrangement.spacedBy(6.dp),
            verticalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            // 雙向情境工具列：effectiveToolbarMode 在「手繪模式中編輯文字方塊」時
            // 自動切為 TYPE，讓使用者在不切換全域模式的情況下使用文字工具。
            if (effectiveToolbarMode == EditorMode.DRAW) {
                // 低延遲與掌拒是**手寫的**設定。
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
                        engine.setPenOnly(penOnly)
                    },
                    label = { Text(l10n("ink_pen_only")) }
                )
                // 防手震滑桿（Stroke Stabilizer）
                FilterChip(
                    selected = strokeStabilizer > 0f,
                    onClick = { strokeStabilizer = if (strokeStabilizer > 0f) 0f else 50f },
                    label = { Text(l10n("refine_sketch")) }
                )
                // 對稱繪圖輔助線（使用現有構圖輔助線 i18n key）
                FilterChip(
                    selected = showSymmetryGuide,
                    onClick = { showSymmetryGuide = !showSymmetryGuide },
                    label = { Text("⟺ " + l10n("composition_overlay")) }
                )
            } else {
                FilterChip(
                    selected = marqueeActive,
                    onClick = {
                        marqueeActive = !marqueeActive
                        if (!marqueeActive) marqueeSelection = emptySet()
                    },
                    label = { Text(l10n("marquee_select")) },
                    modifier = Modifier.testTag("editor.text.select")
                )
                if (marqueeActive) {
                    Text(
                        l10n("marquee_selected").replace("%@", marqueeSelection.size.toString()),
                        style = MaterialTheme.typography.labelSmall
                    )
                    TextButton(
                        onClick = { duplicateMarqueeSelection() },
                        enabled = marqueeSelection.isNotEmpty()
                    ) { Text(l10n("action_duplicate")) }
                    TextButton(
                        onClick = { deleteMarqueeSelection() },
                        enabled = marqueeSelection.isNotEmpty()
                    ) { Text(l10n("action_delete"), color = MaterialTheme.colorScheme.error) }
                }
                // 1. 新增文字方塊
                TextButton(
                    onClick = {
                        val box = textStore.create(x = 100f, y = 150f)
                        selectedTextId = box.id
                        editingText = box
                        val updated = com.kairumo.padnote.canvas.ObjectStacking.bringToFront(setOf(box.id), stackOrder)
                        meta.setObjectOrder(notebook?.first, pageIndex, updated)
                        stackRevision++
                        textRevision++
                    },
                    modifier = Modifier.testTag("editor.text.add_box")
                ) { Text("+ ${l10n("add_text_box")}") }

                // 2. 文字排版
                TextButton(
                    modifier = Modifier.testTag("editor.text.studio"),
                    onClick = {
                        val box = selectedTextId?.let { textStore.find(it) } ?: textStore.create(x = 60f, y = 80f)
                        textRevision++
                        selectedTextId = box.id
                        editingText = box
                    }
                ) { Text(l10n("tool_text")) }

                // 3. 粗體、斜體、底線快捷按鈕
                TextButton(
                    onClick = {
                        selectedTextId?.let { id ->
                            textStore.find(id)?.let { box ->
                                box.bold = !box.bold
                                textStore.persist(box)
                                textRevision++
                            }
                        }
                    },
                    modifier = Modifier.testTag("editor.text.bold")
                ) { Text("B", fontWeight = androidx.compose.ui.text.font.FontWeight.Bold) }

                TextButton(
                    onClick = {
                        selectedTextId?.let { id ->
                            textStore.find(id)?.let { box ->
                                box.italic = !box.italic
                                textStore.persist(box)
                                textRevision++
                            }
                        }
                    },
                    modifier = Modifier.testTag("editor.text.italic")
                ) { Text("I", fontStyle = androidx.compose.ui.text.font.FontStyle.Italic) }

                TextButton(
                    onClick = {
                        selectedTextId?.let { id ->
                            textStore.find(id)?.let { box ->
                                box.underline = !box.underline
                                textStore.persist(box)
                                textRevision++
                            }
                        }
                    },
                    modifier = Modifier.testTag("editor.text.underline")
                ) { Text("U", textDecoration = androidx.compose.ui.text.style.TextDecoration.Underline) }

                // 4. 段落對齊
                TextButton(
                    onClick = {
                        selectedTextId?.let { id ->
                            textStore.find(id)?.let { box ->
                                box.alignment = "left"
                                textStore.persist(box)
                                textRevision++
                            }
                        }
                    },
                    modifier = Modifier.testTag("editor.text.align_left")
                ) { Text(l10n("align_left")) }

                TextButton(
                    onClick = {
                        selectedTextId?.let { id ->
                            textStore.find(id)?.let { box ->
                                box.alignment = "center"
                                textStore.persist(box)
                                textRevision++
                            }
                        }
                    },
                    modifier = Modifier.testTag("editor.text.align_center")
                ) { Text(l10n("align_center_h")) }

                TextButton(
                    onClick = {
                        selectedTextId?.let { id ->
                            textStore.find(id)?.let { box ->
                                box.alignment = "right"
                                textStore.persist(box)
                                textRevision++
                            }
                        }
                    },
                    modifier = Modifier.testTag("editor.text.align_right")
                ) { Text(l10n("align_right")) }

                // 5. 格線/方格吸附開關
                TextButton(
                    onClick = { snapToGrid = !snapToGrid },
                    modifier = Modifier.testTag("editor.text.snap_grid")
                ) { Text(if (snapToGrid) "✓ ${l10n("snap_to_grid")}" else l10n("snap_to_grid")) }

                // 6. 圖層層級調整（物件與文字相對順序）
                TextButton(
                    onClick = {
                        val targetId = selectedTextId ?: selectedShapeIds.firstOrNull() ?: selectedImageId
                        if (targetId != null) {
                            val updated = com.kairumo.padnote.canvas.ObjectStacking.bringForward(setOf(targetId), stackOrder)
                            meta.setObjectOrder(notebook?.first, pageIndex, updated)
                            stackRevision++
                        }
                    },
                    modifier = Modifier.testTag("editor.text.layer_forward")
                ) { Text(l10n("layer_bring_forward")) }

                TextButton(
                    onClick = {
                        val targetId = selectedTextId ?: selectedShapeIds.firstOrNull() ?: selectedImageId
                        if (targetId != null) {
                            val updated = com.kairumo.padnote.canvas.ObjectStacking.sendBackward(setOf(targetId), stackOrder)
                            meta.setObjectOrder(notebook?.first, pageIndex, updated)
                            stackRevision++
                        }
                    },
                    modifier = Modifier.testTag("editor.text.layer_backward")
                ) { Text(l10n("layer_send_backward")) }

                // 7. 特殊符號
                TextButton(
                    onClick = { showSymbolPicker = true },
                    modifier = Modifier.testTag("editor.text.symbols")
                ) { Text(l10n("special_symbols")) }

                // 8. 插入連結
                TextButton(
                    onClick = { insertingLink = true },
                    modifier = Modifier.testTag("editor.text.link")
                ) { Text(l10n("insert_link")) }
            }
        }

        // 這個模式下筆會不會畫線、物件動不動得了。
        //
        // 兩個模式都要說 —— 只在打字模式掛提示的話，切回手寫時畫面上
        // 沒有任何差別，而兩邊「同一個手勢會發生什麼事」完全不同。
        Text(
            l10n(if (editorMode == EditorMode.DRAW) "mode_draw_hint" else "mode_type_hint"),
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 2.dp)
        )

        // 筆刷列只在手寫模式出現（雙向情境切換：effectiveToolbarMode）。
        if (effectiveToolbarMode == EditorMode.DRAW) {
            InkToolbar(
                tool = inkTool,
                colorHex = inkColorHex,
                width = inkWidth,
                languageTag = deviceLanguageTag(),
                onToolChange = { picked -> applyInkTool(picked) },
                onColorChange = { hex ->
                    inkColorHex = hex
                    engine.colorRgba = hexToRgba(hex)
                },
                onWidthChange = { value ->
                    inkWidth = value
                    engine.baseWidth = value
                },
                onOpenColorWheel = { showProColorWheel = true }
            )
            // 防手震強度滑桿（只在滑桿開啟時顯示）
            if (strokeStabilizer > 0f) {
                androidx.compose.foundation.layout.Row(
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp),
                    verticalAlignment = androidx.compose.ui.Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Text(l10n("refine_sketch"), style = MaterialTheme.typography.labelSmall)
                    Slider(
                        value = strokeStabilizer,
                        onValueChange = { strokeStabilizer = it },
                        valueRange = 0f..100f,
                        modifier = Modifier.weight(1f)
                    )
                    Text("${strokeStabilizer.toInt()}%", style = MaterialTheme.typography.labelSmall)
                }
            }
        }
    }

        // 套索的動作列。只在真的有東西可以做的時候出現 —— 一選了套索就
        // 跳出來的話，那時候每一顆按鈕都是空操作。
        if (inkTool.isLasso) {
            LassoActionBar(
                lasso = lasso,
                engine = engine,
                l = { key -> l10n(key) },
                onChanged = { revision++ },
                onRecognizeToText = {
                    val selIds = lasso.selected
                    val strokes = engine.strokes.filter { it.coreStrokeId in selIds }
                    if (strokes.isNotEmpty()) {
                        message = l10n("recognizing")
                        scope.launch {
                            val recognized = StringBuilder()
                            val groups = Handwriting.group(
                                strokeIds = strokes.map { it.coreStrokeId ?: "" },
                                strokes = strokes.map { it.points },
                                strokeTimesMs = strokes.map { it.startedAtMs }
                            )
                            for (group in groups) {
                                val res = Handwriting.recognize(group.strokes, deviceLanguageTag())
                                val txt = res.getOrNull().orEmpty()
                                if (txt.isNotBlank()) recognized.append(txt).append("\n")
                            }
                            val finalStr = recognized.toString().trim()
                            if (finalStr.isNotEmpty()) {
                                val minX = strokes.flatMap { it.points }.minOfOrNull { it.x } ?: 100f
                                val maxY = strokes.flatMap { it.points }.maxOfOrNull { it.y } ?: 200f
                                val box = textStore.create(minX, maxY + 20f)
                                box.text = finalStr
                                box.width = 320f
                                box.height = 120f
                                box.backgroundColorHex = "#FFFFFF"
                                box.hasBorder = true
                                textStore.persist(box)
                                selectedTextId = box.id
                                textRevision++
                                message = l10n("recognized_result").replace("%1@", "${strokes.size}").replace("%2@", finalStr.take(20))
                            } else {
                                message = l10n("no_recognition_result")
                            }
                        }
                    }
                },
                onAnchorToText = {
                    val session = notebook?.first
                    val handles = engine.coreHandles()
                    val pageBoxes = textStore.all.filter { it.pageIndex == pageIndex }
                    val targetBox = pageBoxes.firstOrNull()
                    if (session != null && handles != null && targetBox != null) {
                        val (_, pageId) = handles
                        var selIds = lasso.selected
                        if (selIds.isEmpty()) {
                            val poly = listOf(
                                targetBox.x - 10f, targetBox.y - 10f,
                                targetBox.x + targetBox.width + 10f, targetBox.y - 10f,
                                targetBox.x + targetBox.width + 10f, targetBox.y + targetBox.height + 10f,
                                targetBox.x - 10f, targetBox.y + targetBox.height + 10f
                            )
                            selIds = runCatching { session.lassoSelect(pageId, poly) }.getOrDefault(emptyList())
                        }
                        if (selIds.isNotEmpty()) {
                            val meta = NotebookMeta.load(session)
                            val anchors = meta.stickyAnchors()
                            anchors.removeAll { it.targetId == targetBox.id }
                            anchors.add(
                                com.kairumo.padnote.library.StickyAnnotationAnchor(
                                    pageIndex = pageIndex,
                                    targetId = targetBox.id,
                                    strokeIds = selIds,
                                    anchorOriginX = targetBox.x,
                                    anchorOriginY = targetBox.y
                                )
                            )
                            meta.setStickyAnchors(session, anchors)
                            lasso.clear()
                            revision++
                            clearToken++
                            message = l10n("sticky_anchored_hint")
                        } else {
                            message = l10n("sticky_anchor_ink")
                        }
                    }
                },
                modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp)
            )
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

        if (micBlocked) {
            TextButton(onClick = { Onboarding.openAppSettings(activity) }) {
                Text(l10n("permission_open_settings"))
            }
        }

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
        // 即時錄音控制條（支援暫停、繼續、停止並計算時長）
        if (recording) {
            val min = recordSeconds / 60
            val sec = recordSeconds % 60
            val timeStr = String.format(java.util.Locale.US, "%02d:%02d", min, sec)
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(if (recordingPaused) Color(0xFFFFF7ED) else Color(0xFFFEF2F2))
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(
                        modifier = Modifier
                            .size(10.dp)
                            .clip(CircleShape)
                            .background(if (recordingPaused) Color(0xFFF97316) else Color(0xFFDC2626))
                    )
                    Spacer(Modifier.width(8.dp))
                    Text(
                        if (recordingPaused) "${l10n("recording_paused")}: $timeStr"
                        else "${l10n("sync_recording_in_progress")}: $timeStr",
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = if (recordingPaused) Color(0xFFC2410C) else Color(0xFFDC2626)
                    )
                }

                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    TextButton(
                        onClick = {
                            if (recordingPaused) {
                                audio.resume()
                                recordingPaused = false
                            } else {
                                audio.pause()
                                recordingPaused = true
                            }
                        }
                    ) {
                        Text(
                            if (recordingPaused) l10n("resume_recording") else l10n("pause_recording"),
                            color = Color(0xFFEA580C),
                            fontWeight = FontWeight.Bold
                        )
                    }

                    Button(
                        onClick = {
                            val session = notebook?.first
                            if (session != null) {
                                val us = audio.stop(session)
                                recording = false
                                recordingPaused = false
                                message = l10n("recorded_duration").replace("%@", "${us / 1_000_000uL}")
                            }
                        },
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFDC2626))
                    ) {
                        Text(l10n("finish_recording"), color = Color.White)
                    }
                }
            }
        }




        // 兩條完全獨立的路。連續模式不碰整頁模式的任何一行 ——
        // 那一段綁著存檔、物件層、掌拒與模式切換，是最沒本錢壞掉的地方。
        if (pageDisplayMode == PageDisplayMode.CONTINUOUS) {
            EditorWorkArea(
                sidebarInline = showPageSidebar && layout.sidebarIsInline,
                posture = posture,
                sidebar = {
                    PageSidebar(
                        session = notebook?.first,
                        pageCount = pageCount,
                        pageIndex = pageIndex,
                        revision = textRevision + shapeRevision + tableRevision +
                            chartRevision + imageRevision + model3DRevision,
                        l = { key -> l10n(key) },
                        onSelectPage = { pageIndex = it },
                        onAddPage = {
                            val s = notebook?.first
                            if (s != null) {
                                runCatching { s.addPage(uniffi.padnote_core.PageStyle.BLANK) }
                                pageCount = runCatching { s.pageCount().toInt() }
                                    .getOrDefault(pageCount + 1)
                                pageIndex = pageCount - 1
                            }
                        },
                        onMovePage = { from, to -> movePage(from, to) },
                        onInsertPageAfter = { idx, pid -> insertPageAfter(idx, pid) },
                        onDeletePage = { idx -> deletePageAt(idx) },
                        onTransferPage = { index, moveOut -> transferringPage = index to moveOut },
                        onOpenNotebook = { id -> showPageSidebar = false; onOpenNotebook?.invoke(id) },
                        deviceId = deviceId(activity),
                        onClose = { showPageSidebar = false }
                    )
                }
            ) {
            ContinuousPagesView(
                session = notebook?.first,
                meta = meta,
                pageCount = pageCount,
                focusIndex = pageIndex,
                // 焦點頁就是外層的 pageIndex，所以選單裡的插入動作
                // 自然落在使用者正在看的那一頁。
                onFocusChange = { pageIndex = it },
                ink = InkSettings(
                    tool = engine.tool,
                    colorRgba = engine.colorRgba,
                    baseWidth = engine.baseWidth,
                    isErasing = engine.isErasing,
                    penOnly = penOnly
                ),
                editorMode = editorMode,
                // 任何一種物件有變動就讓連續模式重讀。逐項接 callback 的話，
                // 之後新增一種物件很容易忘記接上，而症狀是「插進去看不到」。
                reloadToken = textRevision + shapeRevision + tableRevision +
                    chartRevision + imageRevision + model3DRevision,
                modifier = Modifier.weight(1f).fillMaxHeight()
            )
            }
            return@Column
        }

        // 從別的 App 把圖拖進來（工作項 S-68）。
        //
        // 掛在畫布這個 Box 上而不是整個畫面：落點要能換算成頁面座標，
        // 掛在外層的話拖到工具列上也會插進去，而且位置會偏掉。
        //
        // 落點與尺寸的計算走 `ImageDropPlacement`，與 Apple 端同一份規則 ——
        // 同一張圖拖到同一個位置，兩台裝置上要落在同一個地方。
        val canvasDensity = LocalDensity.current.density

        val imageDropTarget = remember(pageId, canvasDensity) {
            object : DragAndDropTarget {
                override fun onEntered(event: DragAndDropEvent) { isImageDropTargeted = true }
                override fun onExited(event: DragAndDropEvent) { isImageDropTargeted = false }
                override fun onEnded(event: DragAndDropEvent) { isImageDropTargeted = false }

                override fun onDrop(event: DragAndDropEvent): Boolean {
                    isImageDropTargeted = false
                    val drag = event.toAndroidDragEvent()
                    val uri = drag.clipData?.takeIf { it.itemCount > 0 }
                        ?.getItemAt(0)?.uri ?: return false

                    // **這一行不能少。** 跨 App 拖進來的 URI 預設讀不到 ——
                    // 少了它 `openInputStream` 會丟 SecurityException，症狀是
                    // 「從相簿拖過來什麼也沒發生」，而且沒有任何畫面提示。
                    val grant = runCatching {
                        activity.requestDragAndDropPermissions(drag)
                    }.getOrNull()
                    try {
                        val bytes = runCatching {
                            activity.contentResolver.openInputStream(uri)?.use { it.readBytes() }
                        }.getOrNull()
                        if (bytes == null) {
                            message = l10n("err_image_read_failed")
                            return false
                        }
                        val name = uri.lastPathSegment?.substringAfterLast('/') ?: "image.png"
                        val inserted = imageStore.insert(bytes, name) ?: run {
                            message = l10n("err_image_read_failed")
                            return false
                        }
                        val bounds = android.graphics.BitmapFactory.Options().apply {
                            inJustDecodeBounds = true
                        }
                        android.graphics.BitmapFactory.decodeByteArray(
                            bytes, 0, bytes.size, bounds)
                        val placed = ImageDropPlacement.frame(
                            dropX = drag.x / canvasDensity,
                            dropY = drag.y / canvasDensity,
                            imageWidth = bounds.outWidth.toFloat(),
                            imageHeight = bounds.outHeight.toFloat(),
                            pageWidth = PageGeometry.width,
                            pageHeight = PageGeometry.height
                        )
                        inserted.x = placed.x
                        inserted.y = placed.y
                        inserted.width = placed.width
                        inserted.height = placed.height
                        imageStore.persist(inserted)
                        imageRevision++
                        selectedImageId = inserted.id
                        // 插進來之後切到打字模式：手寫模式下物件不吃觸控，
                        // 使用者剛拖進來的圖會拖不動，看起來像插壞了。
                        editorMode = EditorMode.TYPE
                        return true
                    } finally {
                        grant?.release()
                    }
                }
            }
        }

        EditorWorkArea(
            sidebarInline = showPageSidebar && layout.sidebarIsInline,
            posture = posture,
            modifier = Modifier.weight(if (isTabletopActive) 0.58f else 1f),
            sidebar = {
                PageSidebar(
                    session = notebook?.first,
                    pageCount = pageCount,
                    pageIndex = pageIndex,
                    revision = textRevision + shapeRevision + tableRevision +
                        chartRevision + imageRevision + model3DRevision,
                    l = { key -> l10n(key) },
                    onSelectPage = { pageIndex = it },
                    onAddPage = {
                        val s = notebook?.first
                        if (s != null) {
                            runCatching { s.addPage(uniffi.padnote_core.PageStyle.BLANK) }
                            pageCount = runCatching { s.pageCount().toInt() }
                                .getOrDefault(pageCount + 1)
                            pageIndex = pageCount - 1
                        }
                    },
                    onMovePage = { from, to -> movePage(from, to) },
                    onInsertPageAfter = { idx, pid -> insertPageAfter(idx, pid) },
                    onDeletePage = { idx -> deletePageAt(idx) },
                    onTransferPage = { index, moveOut -> transferringPage = index to moveOut },
                    onOpenNotebook = { id -> showPageSidebar = false; onOpenNotebook?.invoke(id) },
                    deviceId = deviceId(activity),
                    onClose = { showPageSidebar = false }
                )
            }
        ) {
        // **畫布的捲動與縮放。**
        //
        // 在此之前整頁模式的畫布是一個固定的 `Box` —— 既不捲動也不縮放。
        // 使用者的回報是「在手機上手指沒辦法捲動，也沒辦法變更畫面大小」，
        // 而那不是設定錯了，是根本沒做（連續模式只是剛好外面包了
        // `LazyColumn` 才捲得動）。
        //
        // 規則走核心的 `canvasGesture`，兩端同一套：
        //   手指能畫 → 一指畫線、兩指平移與縮放
        //   只有筆能畫 / 打字模式 → 一指就平移
        val gesture = remember(editorMode, penOnly) {
            uniffi.padnote_core.canvasGesture(
                if (editorMode == EditorMode.DRAW) {
                    uniffi.padnote_core.FfiEditorMode.DRAW
                } else {
                    uniffi.padnote_core.FfiEditorMode.TYPE
                },
                if (penOnly) {
                    uniffi.padnote_core.FfiInkPolicy.STYLUS_ONLY
                } else {
                    uniffi.padnote_core.FfiInkPolicy.ANY_INPUT
                }
            )
        }
        val onePanFinger = gesture.oneFinger == uniffi.padnote_core.FfiFingerAction.PAN

        Box(
            modifier = Modifier.weight(1f).fillMaxHeight().padding(8.dp)
                .dragAndDropTarget(
                    shouldStartDragAndDrop = { start ->
                        start.mimeTypes().any { it.startsWith("image/") }
                    },
                    target = imageDropTarget
                )
                // 手勢攔在**外層**，而且只在該攔的時候攔。
                //
                // 全部攔下來的話筆就畫不了了；完全不攔的話，`InkCanvas` 的
                // `pointerInteropFilter` 會把每一個觸控都吃掉。所以逐點判斷：
                // 兩指以上一律是平移縮放，一指只有在「手指本來就不能畫」時才攔。
                .pointerInput(onePanFinger, canvasViewport) {
                    awaitPointerEventScope {
                        while (true) {
                            val first = awaitPointerEvent(PointerEventPass.Initial)
                            val pointers = first.changes.count { it.pressed }
                            val stylus = first.changes.any {
                                it.type == PointerType.Stylus
                            }
                            // 一指平移**只在放大之後**才接管。
                            //
                            // 沒放大時頁面剛好是一個畫面寬，一指拖曳會把整頁
                            // 拉出畫布範圍（實機上看到工具列被蓋掉），而且那
                            // 不是使用者要的 —— 想看下面就用連續模式或翻頁。
                            // 放大之後就不一樣了：畫面裝不下整頁，不給拖就
                            // 永遠看不到右下角。
                            val takeIt = pointers >= 2 ||
                                (onePanFinger && !stylus && canvasScale > 1f)
                            if (!takeIt) continue

                            var event = first
                            while (event.changes.any { it.pressed }) {
                                val zoomChange = event.calculateZoom()
                                val panChange = event.calculatePan()
                                if (zoomChange != 1f || panChange != Offset.Zero) {
                                    canvasScale = uniffi.padnote_core.clampZoom(
                                        canvasScale * zoomChange
                                    )
                                    // **內容是「頁面」，不是「視窗」。**
                                    //
                                    // 一開始兩個參數都填了視窗尺寸，於是
                                    // `scaled <= viewport` 永遠成立、可拖範圍
                                    // 一律是 0 —— 畫面完全不動，看起來就像
                                    // 手勢沒接上。頁面比視窗高的時候本來就
                                    // 該拖得動。
                                    val contentW = PageGeometry.width * canvasDensity
                                    val contentH = PageGeometry.height * canvasDensity
                                    val maxX = uniffi.padnote_core.maxPanOffset(
                                        contentW, canvasViewport.width, canvasScale
                                    )
                                    val maxY = uniffi.padnote_core.maxPanOffset(
                                        contentH, canvasViewport.height, canvasScale
                                    )
                                    canvasOffset = Offset(
                                        (canvasOffset.x + panChange.x).coerceIn(-maxX, maxX),
                                        (canvasOffset.y + panChange.y).coerceIn(-maxY, maxY)
                                    )
                                }
                                event.changes.forEach { it.consume() }
                                event = awaitPointerEvent(PointerEventPass.Initial)
                            }
                        }
                    }
                }
                .onSizeChanged {
                    canvasViewport = Size(it.width.toFloat(), it.height.toFloat())
                }
        ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .graphicsLayer(
                    scaleX = canvasScale,
                    scaleY = canvasScale,
                    translationX = canvasOffset.x,
                    translationY = canvasOffset.y,
                    // **一定要裁切。** 不裁的話平移之後頁面會畫到畫布範圍
                    // 外面，蓋在工具列上 —— 實機上看到的是「捲一下工具列
                    // 就不見了」。
                    clip = true
                )
                .then(
                    if (editorMode == EditorMode.TYPE) {
                        Modifier.pointerInput(pageIndex, snapToGrid) {
                            detectTapGestures { offset: Offset ->
                                val tapX = offset.x / canvasDensity
                                val tapY = offset.y / canvasDensity
                                val hitExisting = textStore.all.firstOrNull { box ->
                                    tapX >= (box.x - 10f) && tapX <= (box.x + box.width + 10f) &&
                                    tapY >= (box.y - 10f) && tapY <= (box.y + box.height + 10f)
                                }
                                if (hitExisting != null) {
                                    selectedTextId = hitExisting.id
                                    editingText = hitExisting
                                } else {
                                    var targetX = tapX
                                    var targetY = tapY
                                    if (snapToGrid) {
                                        val step = 20f
                                        targetX = kotlin.math.round(targetX / step) * step
                                        targetY = kotlin.math.round(targetY / step) * step
                                    }
                                    val newBox = textStore.create(
                                        x = maxOf(20f, minOf(targetX, 700f)),
                                        y = maxOf(20f, minOf(targetY, 1000f))
                                    )
                                    val updatedOrder = com.kairumo.padnote.canvas.ObjectStacking.bringToFront(
                                        setOf(newBox.id),
                                        stackOrder
                                    )
                                    meta.setObjectOrder(notebook?.first, pageIndex, updatedOrder)
                                    stackRevision++
                                    textRevision++
                                    selectedTextId = newBox.id
                                    editingText = newBox
                                }
                            }
                        }
                    } else {
                        Modifier
                    }
                )
        ) {
            // 紙張底紋。畫在墨跡**底下**：先畫的先被蓋住。
            //
            // 底紋來自那一頁自己存的 `PageStyle`（`add_page` 寫進去的），
            // 不是筆記層級的設定 —— 同一本筆記可以一頁方格、一頁康乃爾。
            val pageStyle = remember(pageId, revision) {
                runCatching {
                    notebook?.first?.pageStyle(pageId ?: return@runCatching null)
                }.getOrNull() ?: uniffi.padnote_core.PageStyle.BLANK
            }
            // 這張紙的**版面**。底紋只有六種，紙張有三十幾種 ——
            // 康乃爾與四象限的底紋都是 BLANK，差別全在版面上。
            val notebookMeta = remember(notebookId, revision) {
                com.kairumo.padnote.library.NotebookMeta.load(notebook?.first)
            }
            // 這本筆記的頁面規格（S-84）。畫布、底紋、分頁與匯出五條路都讀
            // `PageGeometry`，所以在這裡設一次就好 —— 與 Apple 的
            // `PageGeometry.use(format:)` 同一個做法。
            LaunchedEffect(notebookMeta) {
                com.kairumo.padnote.ink.PageGeometry.use(notebookMeta.pageFormatId())
            }
            // **逐頁**：同一本筆記可以一頁四象限、一頁日程表。
            val paperId = remember(notebookMeta, pageIndex) { notebookMeta.paperId(pageIndex) }
            val guidePaletteId = remember(notebookMeta) { notebookMeta.paletteId() }
            // 同步縮放與位移至筆跡引擎（S-80）。
            // 縮放時座標反變換，避免墨跡因手勢位移脫位。
            LaunchedEffect(canvasScale, canvasOffset, canvasDensity) {
                engine.zoom = canvasScale
                engine.offsetX = canvasOffset.x / canvasDensity
                engine.offsetY = canvasOffset.y / canvasDensity
            }
            val guideMeasurer = androidx.compose.ui.text.rememberTextMeasurer()
            // 縮放時不能走低延遲路徑。
            //
            // `LowLatencyInkCanvas` 畫在 `SurfaceView` 上，而 SurfaceView 是
            // 另一層合成的表面 —— `graphicsLayer` 的縮放**對它無效**，
            // 結果是底下的頁面縮小了、筆跡還是原本大小，兩層對不起來。
            if (lowLatency && !lowLatencyUnavailable && canvasScale == 1f) {
                LowLatencyInkCanvas(
                    engine = engine,
                    latency = latency,
                    modifier = Modifier.fillMaxSize().testTag("editor.canvas"),
                    onInkChanged = {
                        revision++
                        if (engine.consumeOutsidePrintableArea()) {
                            message = l10n("outside_printable_rejected")
                        }
                    },
                    onUnavailable = { lowLatencyUnavailable = true },
                    clearToken = clearToken,
                    acceptsInk = editorMode == EditorMode.DRAW
                )
            } else {
                InkCanvas(
                    engine = engine,
                    modifier = Modifier.fillMaxSize().testTag("editor.canvas"),
                    inkColor = runCatching {
                        Color(android.graphics.Color.parseColor(inkColorHex))
                    }.getOrDefault(Color.Black),
                    onInkChanged = {
                        revision++
                        // 整筆畫在框線外會被引擎收回（S-85）。使用者要知道
                        // 那一筆去哪裡了 —— 沒有提示的話它就只是「消失了」。
                        if (engine.consumeOutsidePrintableArea()) {
                            message = l10n("outside_printable_rejected")
                        }
                    },
                    onFingerIgnored = {
                        if (penOnly) {
                            message = "已開啟「僅限觸控筆」，手指觸控已忽略。如需手指書寫請關閉此開關。"
                        }
                    },
                    contentVersion = revision,
                    // 底紋要畫在**畫布自己的白底之上、筆跡之下**。
                    // 疊一層 Composable 在外面是不行的：`InkCanvas` 會用
                    // `Color.White` 把整塊塗掉，底紋就消失了（實機看過）。
                    pageStyle = pageStyle,
                    paperId = paperId,
                    localizeGuide = l10n,
                    guideMeasurer = guideMeasurer,
                    guidePaletteId = guidePaletteId,
                    // 打字模式下筆也不會畫線 —— 這個模式只處理文字與物件。
                    acceptsInk = editorMode == EditorMode.DRAW
                )
            }

            // 拖放的落點提示。與 Apple 端一樣是一圈虛線。
            if (isImageDropTargeted) {
                Box(
                    modifier = Modifier.fillMaxSize()
                        .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.08f))
                        .border(
                            3.dp,
                            MaterialTheme.colorScheme.primary,
                            RoundedCornerShape(8.dp)
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    Surface(
                        shape = RoundedCornerShape(20.dp),
                        color = MaterialTheme.colorScheme.primary,
                        shadowElevation = 6.dp
                    ) {
                        Text(
                            text = l10n("multi_window_drop_hint"),
                            style = MaterialTheme.typography.titleMedium,
                            color = MaterialTheme.colorScheme.onPrimary,
                            modifier = Modifier.padding(horizontal = 20.dp, vertical = 10.dp)
                        )
                    }
                }
            }

            // 套索層疊在畫布上面。套索模式下它吃掉所有觸控，畫布完全收不到 ——
            // 不必在 InkEngine 裡加「現在是不是套索模式」的分支，而那種分支
            // 正是墨跡路徑最不該有的東西。
            if (inkTool.isLasso) {
                LassoOverlay(
                    lasso = lasso,
                    engine = engine,
                    onChanged = { revision++ },
                    modifier = Modifier.fillMaxSize()
                )
            }

            // 遮蔽膠帶覆蓋層（對齊 Apple MaskingTapeOverlayView）。
            com.kairumo.padnote.canvas.MaskingTapeOverlay(
                pageIndex = pageIndex,
                isActive = inkTool.isMaskingTape,
                tapeColor = runCatching { Color(android.graphics.Color.parseColor(inkColorHex)) }.getOrDefault(Color(0xFFFCEEAC)),
                tapes = maskingTapes,
                onTapesChanged = { revision++ },
                modifier = Modifier.fillMaxSize()
            )

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
                    onMoved = { box, dx, dy ->
                        val session = notebook?.first
                        val handles = engine.coreHandles()
                        if (session != null && handles != null) {
                            val (_, pageId) = handles
                            val meta = NotebookMeta.load(session)
                            val anchors = meta.stickyAnchors()
                            val matched = anchors.filter { it.targetId == box.id && it.pageIndex == pageIndex }
                            if (matched.isNotEmpty()) {
                                var changedAny = false
                                for (anchor in matched) {
                                    if (anchor.strokeIds.isNotEmpty()) {
                                        val newIds = runCatching {
                                            session.lassoTranslate(pageId, anchor.strokeIds, dx, dy)
                                        }.getOrNull()
                                        if (newIds != null) {
                                            anchor.strokeIds = newIds
                                            anchor.anchorOriginX += dx
                                            anchor.anchorOriginY += dy
                                            changedAny = true
                                        }
                                    }
                                }
                                if (changedAny) {
                                    meta.setStickyAnchors(session, anchors)
                                    engine.load()
                                    revision++
                                    clearToken++
                                }
                            }
                        }
                    },
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

            // 3D 模型。位置與大小是頁面座標，與其他圖層同一套規則。
            key(linkRevision) {
                LinkLayer(
                    interactive = editorMode == EditorMode.TYPE,
                    links = links.filter { it.pageIndex == pageIndex },
                    density = canvasDensity,
                    selectedId = selectedLinkId,
                    onSelect = { selectedLinkId = it },
                    onOpen = { url ->
                        // 交給系統瀏覽器。在 App 裡開 WebView 的話，使用者
                        // 已經登入的 cookie 都不在，而那正是他點連結的理由。
                        runCatching {
                            activity.startActivity(
                                android.content.Intent(
                                    android.content.Intent.ACTION_VIEW,
                                    android.net.Uri.parse(url)
                                )
                            )
                        }
                    },
                    onEdit = { editingLink = it },
                    onDelete = { target ->
                        links = links.filter { it.id != target.id }.toMutableList()
                        meta.setLinks(notebook?.first, links)
                        selectedLinkId = null
                        linkRevision++
                    },
                    onChanged = { updated ->
                        links = links.map { if (it.id == updated.id) updated else it }
                            .toMutableList()
                        meta.setLinks(notebook?.first, links)
                        linkRevision++
                    },
                    zIndexOf = zIndexOf
                )
            }

            // 錄音卡片。疊在連結卡片之上 —— 與 Apple 端的預設層級一致。
            key(audioRevision) {
                AudioLayer(
                    interactive = true,
                    items = audioCards.filter { it.pageIndex == pageIndex },
                    density = canvasDensity,
                    audioDirectory = audioDirectory,
                    selectedId = selectedAudioId,
                    playingId = playingAudioId,
                    l = { key -> l10n(key) },
                    onSelect = { selectedAudioId = it },
                    onTogglePlay = { card ->
                        val file = audioDirectory?.let { java.io.File(it, card.fileName) }
                        playingAudioId = if (file == null) null else {
                            AudioPlayback.toggle(card.id, file) { playingAudioId = null }
                        }
                    },
                    onRename = { renamingAudio = it },
                    onDelete = { card ->
                        if (playingAudioId == card.id) { AudioPlayback.stop(); playingAudioId = null }
                        audioCards = audioCards.filter { it.id != card.id }.toMutableList()
                        meta.setAudioCards(notebook?.first, audioCards)
                        selectedAudioId = null
                        audioRevision++
                    },
                    onChanged = { updated ->
                        audioCards = audioCards.map { if (it.id == updated.id) updated else it }
                            .toMutableList()
                        meta.setAudioCards(notebook?.first, audioCards)
                        audioRevision++
                    },
                    onTranscribe = { card ->
                        scope.launch {
                            val file = audioDirectory?.let { java.io.File(it, card.fileName) }
                            if (file == null || !file.isFile) {
                                message = l10n("audio_file_missing")
                                return@launch
                            }
                            message = l10n("recognizing")
                            val outcome = withContext(Dispatchers.IO) {
                                com.kairumo.padnote.audio.AudioTranscriber.transcribe(
                                    activity, file, deviceLanguageTag())
                            }
                            // **每一種拿不到都要講清楚原因。** 混成一句
                            // 「轉錄失敗」的話，使用者會一直按重試，
                            // 而其中兩種重試一百次也一樣。
                            val text = when (outcome) {
                                is com.kairumo.padnote.audio.AudioTranscriber.Outcome.Text ->
                                    outcome.value
                                com.kairumo.padnote.audio.AudioTranscriber.Outcome.ModelMissing -> {
                                    message = l10n("transcribe_needs_model")
                                    return@launch
                                }
                                com.kairumo.padnote.audio.AudioTranscriber.Outcome.EngineUnavailable -> {
                                    message = l10n("transcribe_engine_unavailable")
                                    return@launch
                                }
                                com.kairumo.padnote.audio.AudioTranscriber.Outcome.AudioUnreadable -> {
                                    message = l10n("transcribe_audio_unreadable")
                                    return@launch
                                }
                                com.kairumo.padnote.audio.AudioTranscriber.Outcome.NoSpeech -> {
                                    message = l10n("transcribe_no_speech")
                                    return@launch
                                }
                                is com.kairumo.padnote.audio.AudioTranscriber.Outcome.Failed -> {
                                    message = l10n("transcribe_failed").replace("%@", outcome.detail)
                                    return@launch
                                }
                            }
                            // 在錄音卡片下方插入文字方塊（與 Apple 端 insertTranscriptText 規格一致）
                            val targetX = card.x
                            val targetY = card.y + card.height + 16f
                            val newBox = textStore.create(targetX, targetY)
                            newBox.text = text
                            newBox.width = maxOf(240f, card.width)
                            newBox.height = maxOf(80f, minOf(240f, 40f + (text.length / 20) * 24f))
                            newBox.backgroundColorHex = "#F2F4F7"
                            newBox.borderColorHex = "#D0D5DD"
                            newBox.hasBorder = true
                            newBox.borderWidth = 1f
                            newBox.cornerRadius = 10f
                            textStore.persist(newBox)
                            selectedTextId = newBox.id
                            editingText = newBox
                            editorMode = EditorMode.TYPE
                            textRevision++
                            message = l10n("transcribe_success")
                        }
                    },
                    zIndexOf = zIndexOf
                )
            }

            // 框選層。只有在框選模式下才存在 —— 平常掛一層可命中的
            // 透明視圖，底下的物件就全部點不到了。
            if (marqueeActive && editorMode == EditorMode.TYPE) {
                MarqueeLayer(
                    candidates = marqueeCandidates,
                    density = canvasDensity,
                    selectedIds = marqueeSelection,
                    onSelectionChange = { marqueeSelection = it },
                    onCommitMove = { dx, dy -> moveMarqueeSelection(dx, dy) }
                )
            }

            key(model3DRevision) {
                Model3DLayer(
                    interactive = editorMode == EditorMode.TYPE,
                    models = models3D.filter { it.pageIndex == pageIndex },
                    density = canvasDensity,
                    selectedId = selectedModel3DId,
                    onSelect = { selectedModel3DId = it },
                    onEdit = { editingModel3D = it },
                    onChanged = { updated ->
                        models3D = models3D.map { if (it.id == updated.id) updated else it }
                            .toMutableList()
                        meta.setModels3D(notebook?.first, models3D)
                        model3DRevision++
                    },
                    zIndexOf = zIndexOf
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

            // 🌟 聲筆動態同步與波形卡拉 OK 高亮 (Audio-Ink Karaoke Sync)
            val audioPlaying = remember(revision) { AudioPlayback.playingId != null }
            if (audioPlaying && engine.strokes.isNotEmpty()) {
                val karaokePath = remember { androidx.compose.ui.graphics.Path() }
                androidx.compose.foundation.Canvas(
                    modifier = Modifier.fillMaxSize().zIndex(8_999f)
                ) {
                    val currentPos = AudioPlayback.currentPositionMs
                    val duration = maxOf(1, AudioPlayback.durationMs)
                    val progressRatio = (currentPos.toFloat() / duration.toFloat()).coerceIn(0f, 1f)
                    val activeIdx = ((engine.strokes.size - 1) * progressRatio).toInt().coerceIn(0, engine.strokes.size - 1)
                    val startIdx = maxOf(0, activeIdx - 1)
                    val endIdx = minOf(engine.strokes.size - 1, activeIdx + 1)
                    for (i in startIdx..endIdx) {
                        val stroke = engine.strokes[i]
                        val pts = stroke.points
                        if (pts.size >= 2) {
                            karaokePath.reset()
                            karaokePath.moveTo(pts.first().x * canvasDensity, pts.first().y * canvasDensity)
                            for (p in pts.drop(1)) {
                                karaokePath.lineTo(p.x * canvasDensity, p.y * canvasDensity)
                            }
                            drawPath(
                                path = karaokePath,
                                color = Color(0xFFFBBF24).copy(alpha = 0.55f),
                                style = androidx.compose.ui.graphics.drawscope.Stroke(width = 6.dp.toPx())
                            )
                        }
                    }
                }
            }

            // 構圖輔助線。畫在所有內容之上但**不吃觸控** —— 它是參考線，
            // 擋住筆的話等於把畫布鎖住。
            CompositionOverlay(
                goldenSpiral = goldenSpiral,
                ruleOfThirds = ruleOfThirds,
                modifier = Modifier.fillMaxSize().zIndex(9_000f)
            )

            // 🌟 專業鏡像對稱尺規視覺參考線（與 Apple 端對稱軸對齊）
            if (showSymmetryGuide && editorMode == EditorMode.DRAW) {
                androidx.compose.foundation.Canvas(
                    modifier = Modifier.fillMaxSize().zIndex(9_001f)
                ) {
                    val axisX = (PageGeometry.width * canvasDensity) / 2f
                    val strokeDash = androidx.compose.ui.graphics.PathEffect.dashPathEffect(floatArrayOf(12f, 12f))
                    drawLine(
                        color = Color(0xFF6366F1).copy(alpha = 0.65f),
                        start = Offset(axisX, 0f),
                        end = Offset(axisX, size.height),
                        strokeWidth = 2.dp.toPx(),
                        pathEffect = strokeDash
                    )
                }
            }

            // 🌟 筆跡磁吸對齊與幾何角度引導 (Smart Magnetic Snap Laser Guide)
            if ((snapToGrid || isMagneticSnapActive) && editorMode == EditorMode.DRAW && magneticGuideActive) {
                androidx.compose.foundation.Canvas(
                    modifier = Modifier.fillMaxSize().zIndex(9_002f)
                ) {
                    val strokeDash = androidx.compose.ui.graphics.PathEffect.dashPathEffect(floatArrayOf(8f, 6f))
                    drawLine(
                        color = Color(0xFF06B6D4).copy(alpha = 0.85f),
                        start = Offset(magneticGuideStart.x * canvasDensity, magneticGuideStart.y * canvasDensity),
                        end = Offset(magneticGuideEnd.x * canvasDensity, magneticGuideEnd.y * canvasDensity),
                        strokeWidth = 1.5.dp.toPx(),
                        pathEffect = strokeDash
                    )
                }
            }

            if (showRefineBar) {
                // 讀一下 revision，按鈕的 enabled 才會跟著美化結果更新。
                @Suppress("UNUSED_EXPRESSION") refineRevision
                SketchRefineBar(
                    languageTag = deviceLanguageTag(),
                    canRestore = engine.canRestoreSketch(),
                    canRedo = engine.canRedoRefine(),
                    onApply = { intensity ->
                        val n = engine.refineSketch(intensity)
                        refineRevision++
                        revision++       // 畫布重繪
                        clearToken++     // 低延遲路徑的前緩衝也要清，否則舊筆畫還留在畫面上
                        message = if (n > 0) l10n("apply_refine") else l10n("nothing_to_refine")
                    },
                    onRestore = {
                        engine.restoreSketch(); refineRevision++; revision++; clearToken++
                    },
                    onRedo = {
                        engine.redoRefine(); refineRevision++; revision++; clearToken++
                    },
                    onDismiss = { showRefineBar = false },
                    modifier = Modifier.align(Alignment.BottomCenter)
                )
            }

            // 極簡懸浮點 (Floating Tool Pill) — 極簡畫布模式下顯示
            if (minimalistCanvasMode) {
                FloatingToolPill(
                    isExpanded = floatingPillExpanded,
                    currentToolName = l10n(inkTool.labelKey),
                    currentColorHex = inkColorHex,
                    languageTag = deviceLanguageTag(),
                    onToggleExpand = { floatingPillExpanded = !floatingPillExpanded },
                    onExitMinimalMode = {
                        minimalistCanvasMode = false
                        floatingPillExpanded = false
                    },
                    modifier = Modifier
                        .align(Alignment.TopStart)
                        .padding(start = 8.dp, top = 8.dp)
                ) {
                    // 展開後的快速工具槽
                    androidx.compose.foundation.layout.Column(
                        verticalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        InkToolbar(
                            tool = inkTool,
                            colorHex = inkColorHex,
                            width = inkWidth,
                            languageTag = deviceLanguageTag(),
                            onToolChange = { picked -> applyInkTool(picked) },
                            onColorChange = { hex ->
                                inkColorHex = hex
                                engine.colorRgba = hexToRgba(hex)
                            },
                            onWidthChange = { value ->
                                inkWidth = value
                                engine.baseWidth = value
                            },
                            onOpenColorWheel = { showProColorWheel = true }
                        )
                    }
                }
            }

            // 🌟 徑向飛輪快捷工具盤 (Radial Pie / Mark Menu)
            if (showRadialMenu) {
                RadialMarkMenu(
                    visible = showRadialMenu,
                    centerOffset = radialMenuCenter,
                    items = listOf(
                        RadialMenuItem(id = "pen", icon = "✏️", label = l10n("tool_pen"), color = MaterialTheme.colorScheme.primary) {
                            applyInkTool(InkTool.FOUNTAIN_PEN)
                        },
                        RadialMenuItem(id = "highlighter", icon = "🖍️", label = l10n("tool_highlighter"), color = Color(0xFFF59E0B)) {
                            applyInkTool(InkTool.HIGHLIGHTER)
                        },
                        RadialMenuItem(id = "eraser", icon = "🧹", label = l10n("tool_eraser"), color = Color(0xFFEF4444)) {
                            applyInkTool(InkTool.ERASER)
                        },
                        RadialMenuItem(id = "lasso", icon = "➰", label = l10n("tool_lasso"), color = Color(0xFF8B5CF6)) {
                            applyInkTool(InkTool.LASSO)
                        },
                        RadialMenuItem(id = "undo", icon = "↩️", label = l10n("undo"), color = Color(0xFF3B82F6)) {
                            if (engine.undo()) { revision++; clearToken++ }
                        },
                        RadialMenuItem(id = "redo", icon = "↪️", label = l10n("redo"), color = Color(0xFF3B82F6)) {
                            if (engine.redo()) { revision++; clearToken++ }
                        },
                        RadialMenuItem(id = "color", icon = "🎨", label = l10n("pro_color"), color = Color(0xFFEC4899)) {
                            showProColorWheel = true
                        },
                        RadialMenuItem(id = "stabilizer", icon = "〰️", label = l10n("refine_sketch"), color = Color(0xFF10B981)) {
                            strokeStabilizer = if (strokeStabilizer > 0f) 0f else 50f
                        }
                    ),
                    onDismiss = { showRadialMenu = false }
                )
            }
        }
        }
        }

        // 次世代 UI/UX Phase 5: 折疊立起雙屏創作工作盤 (Tabletop Studio Control Deck)
        if (isTabletopActive) {
            HorizontalDivider()
            TabletopControlDeck(
                l10n = { key -> l10n(key) },
                currentTool = inkTool,
                onPickTool = { applyInkTool(it) },
                isMagneticSnapActive = isMagneticSnapActive,
                onToggleMagneticSnap = { isMagneticSnapActive = !isMagneticSnapActive },
                onOpenRadial = {
                    radialMenuCenter = Offset(
                        if (canvasViewport.width > 0) canvasViewport.width / 2f else 300f,
                        if (canvasViewport.height > 0) canvasViewport.height / 2f else 300f
                    )
                    showRadialMenu = true
                },
                onAnchorSticky = {
                    val session = notebook?.first
                    val handles = engine.coreHandles()
                    val pageBoxes = textStore.all.filter { it.pageIndex == pageIndex }
                    val target = pageBoxes.firstOrNull()
                    if (session != null && handles != null && target != null) {
                        val (_, pageId) = handles
                        var strokeIds: List<String> = lasso.selected
                        if (strokeIds.isEmpty()) {
                            val poly = listOf(
                                target.x - 10f, target.y - 10f,
                                target.x + target.width + 10f, target.y - 10f,
                                target.x + target.width + 10f, target.y + target.height + 10f,
                                target.x - 10f, target.y + target.height + 10f
                            )
                            strokeIds = runCatching { session.lassoSelect(pageId, poly) }.getOrDefault(emptyList())
                        }
                        if (strokeIds.isNotEmpty()) {
                            val meta = NotebookMeta.load(session)
                            val anchors = meta.stickyAnchors().toMutableList()
                            anchors.removeAll { it.targetId == target.id }
                            anchors.add(
                                StickyAnnotationAnchor(
                                    pageIndex = pageIndex,
                                    targetId = target.id,
                                    strokeIds = strokeIds,
                                    anchorOriginX = target.x,
                                    anchorOriginY = target.y
                                )
                            )
                            meta.setStickyAnchors(session, anchors)
                            lasso.clear()
                            revision++
                            clearToken++
                            message = l10n("sticky_anchored_hint")
                        } else {
                            message = l10n("sticky_anchor_ink")
                        }
                    }
                },
                onUndo = { if (engine.undo()) { revision++; clearToken++ } },
                onRedo = { if (engine.redo()) { revision++; clearToken++ } },
                onAddPage = {
                    val s = notebook?.first
                    if (s != null) {
                        runCatching { s.addPage(uniffi.padnote_core.PageStyle.BLANK) }
                        pageCount = runCatching { s.pageCount().toInt() }.getOrDefault(pageCount + 1)
                        pageIndex = pageCount - 1
                    }
                },
                onColorPick = { hex -> engine.colorRgba = hexToRgba(hex) },
                onExitTabletop = { isTabletopManual = false },
                modifier = Modifier.fillMaxWidth().weight(0.42f)
            )
        }
    }

    // 塞不下兩欄時，結構欄用覆蓋的方式出現。
    //
    // 硬並排的結果是畫布只剩兩指寬 —— 寫字的地方比工具列還窄，
    // 而使用者打開結構欄是為了「翻到第 9 頁」，不是為了改變版面。
    if (showPageSidebar && !layout.sidebarIsInline) {
        androidx.compose.ui.window.Dialog(
            onDismissRequest = { showPageSidebar = false },
            properties = androidx.compose.ui.window.DialogProperties(
                usePlatformDefaultWidth = false
            )
        ) {
            Surface(modifier = Modifier.fillMaxHeight()) {
                PageSidebar(
                    session = notebook?.first,
                    pageCount = pageCount,
                    pageIndex = pageIndex,
                    revision = textRevision + shapeRevision + tableRevision +
                        chartRevision + imageRevision + model3DRevision,
                    l = { key -> l10n(key) },
                    onSelectPage = { pageIndex = it; showPageSidebar = false },
                    onAddPage = {
                        val s = notebook?.first
                        if (s != null) {
                            runCatching { s.addPage(uniffi.padnote_core.PageStyle.BLANK) }
                            pageCount = runCatching { s.pageCount().toInt() }
                                .getOrDefault(pageCount + 1)
                            pageIndex = pageCount - 1
                        }
                        showPageSidebar = false
                    },
                    onMovePage = { from, to -> movePage(from, to) },
                    onInsertPageAfter = { idx, pid -> insertPageAfter(idx, pid) },
                    onDeletePage = { idx -> deletePageAt(idx) },
                    onTransferPage = { index, moveOut -> transferringPage = index to moveOut },
                    onOpenNotebook = { id -> showPageSidebar = false; onOpenNotebook?.invoke(id) },
                    deviceId = deviceId(activity),
                    onClose = { showPageSidebar = false }
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

    // 專業 HSV 色相環（Studio Drawing 進階色輪）
    if (showProColorWheel) {
        ProColorWheelDialog(
            languageTag = deviceLanguageTag(),
            initialHex = inkColorHex,
            onPick = { hex ->
                inkColorHex = hex
                engine.colorRgba = hexToRgba(hex)
                showProColorWheel = false
            },
            onDismiss = { showProColorWheel = false }
        )
    }

    if (insertingLink) {
        LinkInsertDialog(
            l = { key -> l10n(key) },
            onDismiss = { insertingLink = false },
            // 參數叫 `fetched` 不叫 `meta` —— 外層的 `meta` 是這本筆記的
            // NotebookMeta，同名會把它整個遮掉，而且編譯器只會說
            // 「找不到 setLinks」，不會說是被遮蔽。
            onInsert = { fetched ->
                val (w, h) = LinkCard.cardSize()
                val link = LinkObject(
                    id = java.util.UUID.randomUUID().toString(),
                    pageIndex = pageIndex,
                    urlString = fetched.url,
                    title = fetched.title,
                    descriptionText = fetched.description,
                    siteName = fetched.siteName,
                    x = 60f, y = 120f, width = w, height = h
                )
                links = (links + link).toMutableList()
                // 真身寫進中繼資料（會跟著同步走），另外存一張算繪好的 PNG
                // 當後備 —— 還不認得這個型別的版本至少看得到內容。
                meta.setLinks(notebook?.first, links)
                LinkCard.render(
                    uniffi.padnote_core.FfiLinkMetadata(
                        url = link.urlString,
                        title = link.title,
                        description = link.descriptionText,
                        siteName = link.siteName
                    )
                )?.let { png ->
                    runCatching {
                        val s2 = notebook?.first ?: return@runCatching
                        val page = pageId ?: return@runCatching
                        val blob = s2.putBlob(png)
                        val blockId = s2.addImage(page, blob, link.width, link.height)
                        s2.setBlockPosition(blockId, link.x, link.y)
                        // 標成衍生圖片，`ImageStore` 才會跳過它 ——
                        // 不標的話同一張卡片會出現兩份，各自能拖到不同地方。
                        s2.setBlockAppearance(
                            blockId,
                            org.json.JSONObject().put("object", "link").toString()
                        )
                    }
                }
                insertingLink = false
                linkRevision++
            }
        )
    }

    editingLink?.let { target ->
        // 網址、標題與說明一直都在模型裡、也一直跟著同步走，但在這一版
        // 之前沒有任何介面改得到 —— 解析錯一次就只能刪掉重插。
        var draftTitle by remember(target.id) { mutableStateOf(target.title) }
        var draftDesc by remember(target.id) { mutableStateOf(target.descriptionText) }
        androidx.compose.material3.AlertDialog(
            onDismissRequest = { editingLink = null },
            title = { Text(l10n("link_edit")) },
            text = {
                androidx.compose.foundation.layout.Column {
                    androidx.compose.material3.OutlinedTextField(
                        value = draftTitle,
                        onValueChange = { draftTitle = it },
                        label = { Text(l10n("link_title")) },
                        singleLine = true
                    )
                    androidx.compose.material3.OutlinedTextField(
                        value = draftDesc,
                        onValueChange = { draftDesc = it },
                        label = { Text(l10n("link_description")) },
                        modifier = Modifier.padding(top = 8.dp)
                    )
                }
            },
            confirmButton = {
                androidx.compose.material3.TextButton(onClick = {
                    val updated = target.copy(
                        title = draftTitle, descriptionText = draftDesc
                    )
                    links = links.map { if (it.id == target.id) updated else it }.toMutableList()
                    meta.setLinks(notebook?.first, links)
                    linkRevision++
                    editingLink = null
                }) { Text(l10n("done")) }
            },
            dismissButton = {
                androidx.compose.material3.TextButton(onClick = { editingLink = null }) {
                    Text(l10n("cancel"))
                }
            }
        )
    }

    if (insertingAudio) {
        AudioInsertDialog(
            l = { key -> l10n(key) },
            audioDirectory = audioDirectory,
            onDismiss = { insertingAudio = false },
            onPick = { file ->
                // 位置逐張往右下錯開。全部疊在同一點的話，插第二張時
                // 使用者會以為沒插進去。
                val existing = audioCards.count { it.pageIndex == pageIndex }
                val offset = (existing % 6) * 18f
                val card = AudioObject(
                    id = java.util.UUID.randomUUID().toString(),
                    pageIndex = pageIndex,
                    recordingId = file.nameWithoutExtension,
                    fileName = file.name,
                    title = file.nameWithoutExtension,
                    // 長度走核心算（S-42）。各平台問各自的系統 API 的話，
                    // 同一段錄音在兩台裝置上會顯示不同的秒數。
                    durationSeconds = runCatching {
                        uniffi.padnote_core.audioDurationSeconds(file.readBytes()).toInt()
                    }.getOrDefault(0),
                    x = 80f + offset, y = 120f + offset,
                    width = 260f, height = 76f
                )
                audioCards = (audioCards + card).toMutableList()
                meta.setAudioCards(notebook?.first, audioCards)
                insertingAudio = false
                selectedAudioId = card.id
                // 插入後切到打字模式 —— 手寫模式下物件不吃觸控，
                // 剛插進來的卡片會拖不動，看起來像插壞了。
                editorMode = EditorMode.TYPE
                audioRevision++
            }
        )
    }

    renamingAudio?.let { target ->
        var draft by remember(target.id) { mutableStateOf(target.title) }
        androidx.compose.material3.AlertDialog(
            onDismissRequest = { renamingAudio = null },
            title = { Text(l10n("rename_audio_card")) },
            text = {
                androidx.compose.material3.OutlinedTextField(
                    value = draft,
                    onValueChange = { draft = it },
                    label = { Text(l10n("recording_title")) },
                    singleLine = true
                )
            },
            confirmButton = {
                androidx.compose.material3.TextButton(onClick = {
                    val trimmed = draft.trim()
                    if (trimmed.isNotEmpty()) {
                        target.title = trimmed
                        audioCards = audioCards.map { if (it.id == target.id) target else it }
                            .toMutableList()
                        meta.setAudioCards(notebook?.first, audioCards)
                        audioRevision++
                    }
                    renamingAudio = null
                }) { Text(l10n("done")) }
            },
            dismissButton = {
                androidx.compose.material3.TextButton(onClick = { renamingAudio = null }) {
                    Text(l10n("cancel"))
                }
            }
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

    if (insertingModel3D || editingModel3D != null) {
        val editing = editingModel3D
        Model3DStudio(
            languageTag = deviceLanguageTag(),
            existing = editing,
            onCommit = { model ->
                models3D = if (editing == null) {
                    (models3D + model.copy(pageIndex = pageIndex)).toMutableList()
                } else {
                    models3D.map { if (it.id == model.id) model else it }.toMutableList()
                }
                meta.setModels3D(notebook?.first, models3D)
                model3DRevision++
                selectedModel3DId = model.id
                // 插完切到打字模式，不然物件層不吃觸控、剛插的東西選不到。
                editorMode = EditorMode.TYPE
            },
            onDismiss = { insertingModel3D = false; editingModel3D = null }
        )
    }

    if (showNoteIntelligence) {
        NoteIntelligenceSheet(
            // 取的五種內容與首頁搜尋比對的**完全一樣**。不一致的話會出現
            // 一個很難解釋的狀況：使用者搜得到某句話，但摘要說筆記裡沒有
            // 提到它。
            text = notePlainText(
                // 標題從筆記庫查 —— 編輯器畫面上沒有顯示它，所以手上沒有。
                title = noteTitle,
                textBoxes = textStore.all.map { it.text },
                tableCells = tableStore.all.flatMap { it.cells },
                shapeLabels = shapeStore.all.map { it.label }
            ),
            locale = deviceLanguageTag(),
            l = { key -> l10n(key) },
            onInsert = { inserted ->
                // 插成一個文字方塊，位置固定在左上角一帶 —— 摘要是整則筆記
                // 的東西，不屬於任何一個特定位置。
                val box = textStore.create(60f, 80f)
                textStore.persist(box.copy(text = inserted))
                textRevision++
            },
            onDismiss = { showNoteIntelligence = false }
        )
    }

    if (showLanguagePicker) {
        LanguagePickerDialog(
            current = deviceLanguageTag(),
            onPick = { tag ->
                setAppLanguage(activity, tag)
                showLanguagePicker = false
                // 換語言要整個畫面重畫。重建 Activity 是最省事也最可靠的做法 ——
                // 逐個字串狀態去追，一定會漏掉幾個沒有重組的地方。
                activity.recreate()
            },
            onDismiss = { showLanguagePicker = false }
        )
    }

    if (showCollaboration) {
        CollaborationSheet(
            manager = collaboration,
            languageTag = deviceLanguageTag(),
            onDismiss = { showCollaboration = false }
        )
    }

    if (showAssetLibrary) {
        AssetLibrarySheet(
            languageTag = deviceLanguageTag(),
            onInsert = { item, style ->
                // 素材是**線圖**，沒有可編輯的文字內容，所以插成圖片區塊
                // ——與 Apple 端一致。向量在這裡算繪成 PNG 落盤，讓匯出 PDF
                // 與尚未支援素材的讀取器也看得到東西。
                val png = renderAssetPng(item.drawingCode, style, item.source)
                if (png != null) {
                    imageStore.insert(png, "${item.id}.png")
                    imageRevision++
                    editorMode = EditorMode.TYPE
                } else {
                    message = l10n("no_assets_found")
                }
            },
            onDismiss = { showAssetLibrary = false }
        )
    }

    if (showThemeTools) {
        ThemeToolsSheet(
            languageTag = deviceLanguageTag(),
            goldenSpiral = goldenSpiral,
            ruleOfThirds = ruleOfThirds,
            onGoldenSpiralChange = { goldenSpiral = it },
            onRuleOfThirdsChange = { ruleOfThirds = it },
            onPickColor = { inkColorHex = it },
            onInsertText = { text ->
                // 插成文字方塊而不是圖片 —— 標註插完還要改數字。
                val box = textStore.create(x = 60f, y = 80f)
                box.text = text
                textStore.persist(box)
                textRevision++
                selectedTextId = box.id
                editorMode = EditorMode.TYPE
            },
            onDismiss = { showThemeTools = false }
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

    if (showSymbolPicker) {
        com.kairumo.padnote.text.SymbolPickerDialog(
            l = { key -> l10n(key) },
            onDismiss = { showSymbolPicker = false },
            onPick = { symbol ->
                showSymbolPicker = false
                // 與 Apple 的 `insertQuickTextSnippet` 一樣：插進一個**新的**
                // 文字方塊，而不是塞進目前選取的那一個 —— 使用者按符號時
                // 通常正在標註，不是在編輯某一段文字。
                val box = textStore.create(x = 100f, y = 120f)
                box.text = symbol
                box.fontSize = 20f
                box.bold = true
                box.width = 260f
                box.height = 64f
                textStore.persist(box)
                textRevision++
                selectedTextId = box.id
                editorMode = EditorMode.TYPE
            }
        )
    }

    transferringPage?.let { (pageIdx, moveOut) ->
        val others = remember(revision, notebookId) {
            NotebookLibrary.all(activity, deviceId(activity), folderId = NotebookLibrary.ANY_FOLDER)
                .filter { it.id != notebookId }
        }
        com.kairumo.padnote.library.TransferPagesDialog(
            title = l10n(if (moveOut) "move_pages_to_title" else "copy_pages_to_title"),
            notebooks = others,
            l = { key -> l10n(key) },
            onDismiss = { transferringPage = null },
            onPick = { target ->
                val session = notebook?.first
                val moved = if (session == null) {
                    0u
                } else {
                    runCatching {
                        session.transferPages(
                            listOf(pageIdx.toUInt()),
                            target.path.absolutePath,
                            moveOut
                        )
                    }.getOrDefault(0u)
                }
                transferringPage = null
                message = if (moved > 0u) {
                    l10n(if (moveOut) "pages_moved" else "pages_copied")
                        .replaceFirst("%@", moved.toString())
                        .replaceFirst("%@", target.title)
                } else {
                    l10n("transfer_failed")
                }
                // 搬移會少一頁，頁碼要夾回範圍內。
                pageCount = runCatching { session?.pageCount()?.toInt() }.getOrNull() ?: pageCount
                pageIndex = pageIndex.coerceIn(0, maxOf(0, pageCount - 1))
                revision++
            }
        )
    }

    if (renamingCurrent && notebookId != null) {
        // 用 FolderNameDialog 這個通用的「一個標題欄位」對話框 ——
        // RenameNotebookDialog 要一個 NotebookLibrary.Entry，而編輯器手上
        // 只有 id，為了它去掃整個筆記庫只是白做工。
        FolderNameDialog(
            title = l10n("rename_note"),
            initial = FolderTree.titleOf(activity, notebookId) ?: "",
            l = { key -> l10n(key) },
            onDismiss = { renamingCurrent = false },
            onConfirm = { newTitle ->
                if (newTitle.isNotBlank()) {
                    NotebookLibrary.rename(activity, notebookId, newTitle, deviceId(activity))
                    revision++
                }
                renamingCurrent = false
            }
        )
    }

    if (showStatus) {
        val rows = remember { readCoreStatus(activity) }
        val packageInfo = remember {
            runCatching {
                activity.packageManager.getPackageInfo(activity.packageName, 0)
            }.getOrNull()
        }
        val ver = packageInfo?.versionName ?: "1.0.0"
        AppDiagnosticsDialog(
            versionString = ver,
            coreStatusRows = rows,
            latencySummary = latency.summaryMs(),
            l = { k -> l10n(k) },
            onDismiss = { showStatus = false }
        )
    }
}

/**
 * 次世代 UI/UX Phase 5: 折疊立起雙屏創作工作盤 (Tabletop Studio Control Deck)。
 *
 * 當折疊機處於半折立起 (Tabletop / Flex Mode) 或使用者手動開啟雙視窗時，
 * 上半部為完整畫布與文件預覽區，下半部為高效率觸控創作工作盤。
 */
@Composable
private fun TabletopControlDeck(
    l10n: (String) -> String,
    currentTool: InkTool,
    onPickTool: (InkTool) -> Unit,
    isMagneticSnapActive: Boolean,
    onToggleMagneticSnap: () -> Unit,
    onOpenRadial: () -> Unit,
    onAnchorSticky: () -> Unit,
    onUndo: () -> Unit,
    onRedo: () -> Unit,
    onAddPage: () -> Unit,
    onColorPick: (String) -> Unit,
    onExitTabletop: () -> Unit,
    modifier: Modifier = Modifier
) {
    Surface(
        modifier = modifier,
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
        shape = RoundedCornerShape(topStart = 16.dp, topEnd = 16.dp)
    ) {
        Column(
            modifier = Modifier.fillMaxSize().padding(horizontal = 14.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            // 頂部狀態列與功能按鈕
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "⧉ ${l10n("posture_tabletop_mode")}",
                    style = MaterialTheme.typography.titleSmall,
                    color = MaterialTheme.colorScheme.primary
                )
                Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    IconButton(onClick = onUndo, modifier = Modifier.size(32.dp)) {
                        Text("↶", fontSize = 16.sp)
                    }
                    IconButton(onClick = onRedo, modifier = Modifier.size(32.dp)) {
                        Text("↷", fontSize = 16.sp)
                    }
                    IconButton(onClick = onAddPage, modifier = Modifier.size(32.dp)) {
                        Text("+", fontSize = 18.sp, color = MaterialTheme.colorScheme.primary)
                    }
                    IconButton(onClick = onExitTabletop, modifier = Modifier.size(32.dp)) {
                        Text("✕", fontSize = 13.sp)
                    }
                }
            }

            // 常用筆刷工具組
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                FilterChip(
                    selected = currentTool == InkTool.FOUNTAIN_PEN,
                    onClick = { onPickTool(InkTool.FOUNTAIN_PEN) },
                    label = { Text(l10n("tool_pen"), maxLines = 1) },
                    modifier = Modifier.weight(1f)
                )
                FilterChip(
                    selected = currentTool == InkTool.HIGHLIGHTER,
                    onClick = { onPickTool(InkTool.HIGHLIGHTER) },
                    label = { Text(l10n("tool_highlighter"), maxLines = 1) },
                    modifier = Modifier.weight(1f)
                )
                FilterChip(
                    selected = currentTool == InkTool.ERASER,
                    onClick = { onPickTool(InkTool.ERASER) },
                    label = { Text(l10n("tool_eraser"), maxLines = 1) },
                    modifier = Modifier.weight(1f)
                )
                FilterChip(
                    selected = currentTool == InkTool.LASSO,
                    onClick = { onPickTool(InkTool.LASSO) },
                    label = { Text(l10n("tool_lasso"), maxLines = 1) },
                    modifier = Modifier.weight(1f)
                )
            }

            // 次世代功能輔助鍵：Radial Menu / 磁吸 / 錨定
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                OutlinedButton(
                    onClick = onOpenRadial,
                    modifier = Modifier.weight(1f),
                    contentPadding = PaddingValues(horizontal = 4.dp, vertical = 2.dp)
                ) {
                    Text("◎ Radial", fontSize = 11.sp, maxLines = 1)
                }

                OutlinedButton(
                    onClick = onToggleMagneticSnap,
                    modifier = Modifier.weight(1.2f),
                    contentPadding = PaddingValues(horizontal = 4.dp, vertical = 2.dp)
                ) {
                    Text(
                        text = if (isMagneticSnapActive) "🧲 Snap ON" else "🧲 Snap",
                        fontSize = 11.sp,
                        color = if (isMagneticSnapActive) MaterialTheme.colorScheme.primary else Color.Unspecified,
                        maxLines = 1
                    )
                }

                OutlinedButton(
                    onClick = onAnchorSticky,
                    modifier = Modifier.weight(1f),
                    contentPadding = PaddingValues(horizontal = 4.dp, vertical = 2.dp)
                ) {
                    Text("🔗 Anchor", fontSize = 11.sp, maxLines = 1)
                }
            }

            // 常用色彩圓點
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceEvenly,
                verticalAlignment = Alignment.CenterVertically
            ) {
                val colorList = listOf(
                    "#000000" to Color.Black,
                    "#1E40AF" to Color(0xFF1E40AF),
                    "#DC2626" to Color(0xFFDC2626),
                    "#16A34A" to Color(0xFF16A34A),
                    "#D97706" to Color(0xFFD97706),
                    "#7C3AED" to Color(0xFF7C3AED)
                )
                colorList.forEach { (hex, color) ->
                    Box(
                        modifier = Modifier
                            .size(28.dp)
                            .clip(CircleShape)
                            .background(color)
                            .border(1.dp, Color.White.copy(alpha = 0.5f), CircleShape)
                            .clickable { onColorPick(hex) }
                    )
                }
            }
        }
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
/**
 * 跨裝置同步過來的語言。null 表示沒設過，退回系統語系。
 *
 * 用 process 範圍的快取而不是每次都讀 SharedPreferences：`deviceLanguageTag()`
 * 在每一次重組裡都會被呼叫好幾次，每次開檔案太貴。Activity 啟動時設一次
 * （見 `syncLanguageOverride`），與 Apple 端的 `snapshotLanguage` 同一個模式。
 */
private var syncedLanguageOverride: String? = null

/** Activity 啟動時把跨裝置設定讀進來。 */
fun applySyncedLanguage(context: android.content.Context) {
    syncedLanguageOverride =
        com.kairumo.padnote.library.AccountSyncStore.syncedLanguage(context)
}

/** 改語言並記進跨裝置設定（G-04）。 */
fun setAppLanguage(context: android.content.Context, tag: String) {
    com.kairumo.padnote.library.AccountSyncStore.setSyncedLanguage(context, tag)
    syncedLanguageOverride = tag
}

/**
 * 介面語言標籤 → 文件範本目錄裡的語言鍵。
 *
 * 目錄用的是 `zhHant` 這種寫法，不是 BCP 47 的 `zh-Hant` —— 直接拿標籤去查
 * 會每次落空，然後**靜靜地**退回繁體中文，英文使用者不會看到錯誤，
 * 只會覺得範本沒有英文版。與 Apple 端 `AppLanguage.catalogKey` 同一組對應。
 */
private fun catalogLang(tag: String): String = when (tag) {
    "zh-Hant" -> "zhHant"
    "zh-Hans" -> "zhHans"
    "en" -> "en"
    "ja" -> "ja"
    "ko" -> "ko"
    "th" -> "th"
    else -> "zhHant"
}

private fun deviceLanguageTag(): String {
    // 跨裝置設定優先於系統語系：使用者在 iPad 上把語言改成日文之後，
    // 這台也要跟著變（ADR-0011）。反過來的話，同步過來的設定永遠不生效，
    // 使用者會覺得「同步根本沒在動」。
    syncedLanguageOverride?.let { return it }
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
    // 版面標籤要照使用者目前的語系（S-90）—— 不傳的話匯出的康乃爾
    // 會寫著繁體中文的「提示／筆記／摘要」，而 App 是英文介面。
    return Exporter.export(
        activity, session, format, languageTag = deviceLanguageTag()
    ).fold(
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

/** 分享 .padnote 筆記套件檔。 */
private fun shareNotebookPackage(
    activity: ComponentActivity,
    notebookDir: File,
    title: String
): String {
    return Exporter.sharePackage(activity, notebookDir, title).fold(
        onSuccess = { file ->
            runCatching {
                activity.startActivity(
                    android.content.Intent.createChooser(
                        Exporter.sharePackageIntent(activity, file), null
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
 * 建立備份檔並寫入使用者選擇的位置。
 */
private fun runBackupToUri(activity: ComponentActivity, uri: android.net.Uri): String {
    val lang = deviceLanguageTag()
    return runCatching {
        val (file, info) = BackupManager.create(activity, BuildConfig.VERSION_NAME)
        activity.contentResolver.openOutputStream(uri)?.use { out ->
            file.inputStream().use { input ->
                input.copyTo(out)
            }
        }
        file.delete()
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

/** 從外部 URI 匯入 .padnote 筆記本檔案。 */
private fun runImportNote(context: Context, uri: android.net.Uri, deviceId: UInt): NotebookLibrary.Entry? = runCatching {
    val tempFile = File(context.cacheDir, "temp_import_${System.currentTimeMillis()}.padnote")
    context.contentResolver.openInputStream(uri)?.use { input ->
        tempFile.outputStream().use { output ->
            input.copyTo(output)
        }
    }
    try {
        NotebookLibrary.importArchive(context, tempFile, deviceId)
    } finally {
        tempFile.delete()
    }
}.getOrNull()

// MARK: - 1. 雲端同步專屬獨立視窗 (Google Drive)
@Composable
private fun CloudSyncDetailDialog(
    signedIn: Boolean,
    busy: Boolean,
    message: String?,
    account: String?,
    lastSync: String?,
    l: (String) -> String,
    onDismiss: () -> Unit,
    onSignIn: () -> Unit,
    onSyncNow: () -> Unit,
    onSignOut: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = {
            TextButton(onClick = onDismiss) { Text(l("close")) }
        },
        title = {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("☁", fontSize = 22.sp, modifier = Modifier.padding(end = 8.dp))
                Text(l("cloud_sync"), fontWeight = FontWeight.Bold)
            }
        },
        text = {
            Column(
                modifier = Modifier.verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                // 頂部狀態列
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("Google Drive", fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
                    Text(
                        if (signedIn) l("sync_section") else l("not_signed_in"),
                        style = MaterialTheme.typography.bodySmall,
                        color = if (signedIn) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.error
                    )
                }

                // 帳號與同步資訊卡
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(10.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
                ) {
                    Column(
                        modifier = Modifier.padding(12.dp),
                        verticalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        if (signedIn) {
                            account?.let { DialogDetailRow(l("sync_account"), it) }
                            HorizontalDivider()
                            DialogDetailRow(l("sync_destination"), l("sync_destination_appdata"))
                            HorizontalDivider()
                            DialogDetailRow(l("sync_last_at"), lastSync ?: l("sync_never"))
                        } else {
                            Text(
                                l("not_signed_in"),
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }

                message?.let {
                    Text(
                        it,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.primary
                    )
                }

                // 動作按鈕
                if (signedIn) {
                    Button(
                        onClick = onSyncNow,
                        enabled = !busy,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        if (busy) {
                            CircularProgressIndicator(
                                modifier = Modifier.size(18.dp).padding(end = 8.dp),
                                strokeWidth = 2.dp,
                                color = MaterialTheme.colorScheme.onPrimary
                            )
                        }
                        Text(l("sync_now"))
                    }

                    OutlinedButton(
                        onClick = onSignOut,
                        enabled = !busy,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text(l("sign_out"), color = MaterialTheme.colorScheme.error)
                    }
                } else {
                    Button(
                        onClick = onSignIn,
                        enabled = !busy,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text(l("sign_in_google"))
                    }
                }

                // 同步醫生：日誌答得出「發生過什麼」，答不出「現在是什麼狀態」。
                val doctorActivity = LocalContext.current as? ComponentActivity
                if (doctorActivity != null) {
                    com.kairumo.padnote.ui.SyncDoctorCard(deviceId = deviceId(doctorActivity))
                }

                // 即時雲端同步日誌（含複製、匯出、清理）
                SyncLogCard(
                    filterSource = SyncSource.GOOGLE_DRIVE,
                    l = l
                )

                // 詳細操作指引
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(10.dp),
                    colors = CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
                    )
                ) {
                    Column(
                        modifier = Modifier.padding(12.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        Text(
                            l("help_and_legal"),
                            style = MaterialTheme.typography.labelLarge,
                            fontWeight = FontWeight.Bold
                        )
                        DialogGuideStep(
                            step = "1",
                            title = l("sign_in_google"),
                            desc = l("cloud_sync_explainer")
                        )
                        DialogGuideStep(
                            step = "2",
                            title = l("sync_destination"),
                            desc = l("sync_destination_appdata")
                        )
                        DialogGuideStep(
                            step = "3",
                            title = l("sync_section"),
                            desc = l("sync_explainer")
                        )
                    }
                }
            }
        }
    )
}

// MARK: - 2. 建立備份檔專屬獨立視窗
@Composable
private fun BackupCreateDetailDialog(
    notebookCount: Int,
    recordingCount: Int,
    isCreating: Boolean,
    statusMessage: String?,
    l: (String) -> String,
    onDismiss: () -> Unit,
    onCreateBackup: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = {
            TextButton(onClick = onDismiss) { Text(l("close")) }
        },
        title = {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("💾", fontSize = 22.sp, modifier = Modifier.padding(end = 8.dp))
                Text(l("backup_create"), fontWeight = FontWeight.Bold)
            }
        },
        text = {
            Column(
                modifier = Modifier.verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Text(
                    l("backup_create_desc"),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )

                // 統計資訊卡
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(10.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
                ) {
                    Column(
                        modifier = Modifier.padding(12.dp),
                        verticalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        DialogDetailRow(l("all_notebooks"), "$notebookCount")
                        HorizontalDivider()
                        DialogDetailRow(l("recent_recordings"), "$recordingCount")
                        HorizontalDivider()
                        DialogDetailRow(l("storage_location"), "App Storage & Cache")
                    }
                }

                statusMessage?.let {
                    Text(
                        it,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.primary
                    )
                }

                Button(
                    onClick = onCreateBackup,
                    enabled = !isCreating,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    if (isCreating) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(18.dp).padding(end = 8.dp),
                            strokeWidth = 2.dp,
                            color = MaterialTheme.colorScheme.onPrimary
                        )
                    }
                    Text(l("backup_create"))
                }

                // 操作說明與指引
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(10.dp),
                    colors = CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
                    )
                ) {
                    Column(
                        modifier = Modifier.padding(12.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        Text(
                            l("backup_section"),
                            style = MaterialTheme.typography.labelLarge,
                            fontWeight = FontWeight.Bold
                        )
                        DialogGuideStep(
                            step = "1",
                            title = l("backup_create"),
                            desc = l("backup_explainer")
                        )
                        DialogGuideStep(
                            step = "2",
                            title = l("backup_restore"),
                            desc = l("backup_safety_note")
                        )
                        DialogGuideStep(
                            step = "3",
                            title = l("storage_location"),
                            desc = l("backup_created").replace("%1@", "...").replace("%2@", "...")
                        )
                    }
                }
            }
        }
    )
}

// MARK: - 3. 從備份復原專屬獨立視窗
@Composable
private fun BackupRestoreDetailDialog(
    statusMessage: String?,
    l: (String) -> String,
    onDismiss: () -> Unit,
    onChooseBackupFile: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = {
            TextButton(onClick = onDismiss) { Text(l("close")) }
        },
        title = {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("↺", fontSize = 22.sp, modifier = Modifier.padding(end = 8.dp))
                Text(l("backup_restore"), fontWeight = FontWeight.Bold)
            }
        },
        text = {
            Column(
                modifier = Modifier.verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Text(
                    l("backup_restore_desc"),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )

                // 安全防護聲明卡片
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(10.dp),
                    colors = CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.tertiaryContainer.copy(alpha = 0.6f)
                    )
                ) {
                    Column(
                        modifier = Modifier.padding(12.dp),
                        verticalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        Text(
                            "🛡️ " + l("backup_safety_note"),
                            style = MaterialTheme.typography.bodyMedium,
                            fontWeight = FontWeight.SemiBold,
                            color = MaterialTheme.colorScheme.onTertiaryContainer
                        )
                        Text(
                            l("backup_explainer"),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onTertiaryContainer
                        )
                    }
                }

                statusMessage?.let {
                    Text(
                        it,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.primary
                    )
                }

                Button(
                    onClick = onChooseBackupFile,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text(l("backup_restore"))
                }

                // 詳細復原步驟指引
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(10.dp),
                    colors = CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
                    )
                ) {
                    Column(
                        modifier = Modifier.padding(12.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        Text(
                            l("backup_section"),
                            style = MaterialTheme.typography.labelLarge,
                            fontWeight = FontWeight.Bold
                        )
                        DialogGuideStep(
                            step = "1",
                            title = l("backup_restore"),
                            desc = l("backup_restore_desc")
                        )
                        DialogGuideStep(
                            step = "2",
                            title = l("backup_safety_note"),
                            desc = l("backup_safety_note")
                        )
                        DialogGuideStep(
                            step = "3",
                            title = l("app_version_info"),
                            desc = l("backup_restored").replace("%@", "...")
                        )
                    }
                }
            }
        }
    )
}

// MARK: - 4. 選擇同步資料夾專屬獨立視窗
@Composable
private fun FolderSyncDetailDialog(
    folderPath: String?,
    isConfigured: Boolean,
    lastSync: String?,
    isSyncing: Boolean,
    statusMessage: String?,
    l: (String) -> String,
    onDismiss: () -> Unit,
    onPickFolder: () -> Unit,
    onSyncNow: () -> Unit,
    onClearFolder: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = {
            TextButton(onClick = onDismiss) { Text(l("close")) }
        },
        title = {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("☁", fontSize = 22.sp, modifier = Modifier.padding(end = 8.dp))
                Text(l("sync_choose_folder"), fontWeight = FontWeight.Bold)
            }
        },
        text = {
            Column(
                modifier = Modifier.verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Text(
                    l("sync_folder_desc"),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )

                // 狀態卡
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(10.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
                ) {
                    Column(
                        modifier = Modifier.padding(12.dp),
                        verticalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        DialogDetailRow(
                            l("migration_status"),
                            if (isConfigured) l("sync_done") else l("sync_not_configured")
                        )

                        if (isConfigured && folderPath != null) {
                            HorizontalDivider()
                            Text(
                                l("sync_folder_path"),
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                            Text(
                                folderPath,
                                style = MaterialTheme.typography.bodySmall,
                                fontFamily = FontFamily.Monospace,
                                maxLines = 2,
                                overflow = TextOverflow.Ellipsis
                            )
                            HorizontalDivider()
                            DialogDetailRow(l("sync_last_at"), lastSync ?: l("sync_never"))
                        }
                    }
                }

                statusMessage?.let {
                    Text(
                        it,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.primary
                    )
                }

                Button(
                    onClick = onPickFolder,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text(l("sync_choose_folder"))
                }

                if (isConfigured) {
                    OutlinedButton(
                        onClick = onSyncNow,
                        enabled = !isSyncing,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        if (isSyncing) {
                            CircularProgressIndicator(
                                modifier = Modifier.size(18.dp).padding(end = 8.dp),
                                strokeWidth = 2.dp,
                                color = MaterialTheme.colorScheme.primary
                            )
                        }
                        Text(l("sync_now"))
                    }

                    TextButton(
                        onClick = onClearFolder,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text(l("delete_item"), color = MaterialTheme.colorScheme.error)
                    }
                }

                // 即時資料夾同步日誌（含複製、匯出、清理）
                SyncLogCard(
                    filterSource = SyncSource.FOLDER,
                    l = l
                )

                // 操作指引
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(10.dp),
                    colors = CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
                    )
                ) {
                    Column(
                        modifier = Modifier.padding(12.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        Text(
                            l("help_and_legal"),
                            style = MaterialTheme.typography.labelLarge,
                            fontWeight = FontWeight.Bold
                        )
                        DialogGuideStep(
                            step = "1",
                            title = l("sync_choose_folder"),
                            desc = l("sync_folder_desc")
                        )
                        DialogGuideStep(
                            step = "2",
                            title = l("sync_section"),
                            desc = l("sync_explainer")
                        )
                        DialogGuideStep(
                            step = "3",
                            title = l("no_account_needed"),
                            desc = l("cloud_sync_explainer")
                        )
                    }
                }
            }
        }
    )
}

// MARK: - 通用對話框輔助元件
@Composable
private fun DialogDetailRow(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            label,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Text(
            value,
            style = MaterialTheme.typography.bodySmall,
            fontWeight = FontWeight.Medium,
            textAlign = TextAlign.End,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
    }
}

@Composable
private fun DialogGuideStep(step: String, title: String, desc: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        verticalAlignment = Alignment.Top
    ) {
        Surface(
            shape = RoundedCornerShape(12.dp),
            color = MaterialTheme.colorScheme.primary.copy(alpha = 0.15f),
            modifier = Modifier.size(24.dp)
        ) {
            Box(contentAlignment = Alignment.Center) {
                Text(
                    step,
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.primary
                )
            }
        }
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            Text(
                title,
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.SemiBold
            )
            Text(
                desc,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}
