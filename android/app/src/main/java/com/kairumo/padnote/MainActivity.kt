package com.kairumo.padnote

import com.kairumo.padnote.canvas.fingerTapOnLockedObject
import com.kairumo.padnote.text.doubleTapToWrite
import android.os.Bundle
import java.io.File
import android.view.KeyEvent
import androidx.activity.ComponentActivity
import androidx.fragment.app.FragmentActivity
import com.kairumo.padnote.profile.ProfileGate
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
import com.kairumo.padnote.text.WordFormatAction
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
import androidx.compose.runtime.mutableLongStateOf
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
import com.kairumo.padnote.platform.ExportPreviewDialog
import com.kairumo.padnote.platform.Exporter
import com.kairumo.padnote.platform.FileImport
import com.kairumo.padnote.platform.DocumentImport
import com.kairumo.padnote.platform.PdfPageInsertDialog
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
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.testTagsAsResourceId
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
import com.kairumo.padnote.canvas.LassoPastePill
import com.kairumo.padnote.canvas.lassoBarPlacement
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
import com.kairumo.padnote.ui.pressAndHoldForRadialMenu
import com.kairumo.padnote.ui.radialHoldArea
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
import com.kairumo.padnote.library.RecordingTitles
import com.kairumo.padnote.sync.AutoSync
import com.kairumo.padnote.library.RecordingIndex
import com.kairumo.padnote.library.InsertRecordingDialog
import com.kairumo.padnote.library.SeedNotebooks
import com.kairumo.padnote.library.FolderNameDialog
import com.kairumo.padnote.library.DeleteFolderDialog
import com.kairumo.padnote.library.MoveToFolderDialog
import com.kairumo.padnote.library.TransferPagesDialog
import com.kairumo.padnote.shape.NoteConnection
import com.kairumo.padnote.shape.NoteShape
import com.kairumo.padnote.shape.ShapeLayer
import com.kairumo.padnote.shape.LayerPanel
import com.kairumo.padnote.shape.ObjectLayer
import com.kairumo.padnote.shape.ShapePicker
import com.kairumo.padnote.shape.ShapeStore
import com.kairumo.padnote.shape.ConnectionDraft
import com.kairumo.padnote.shape.ConnectionEditDialog
import com.kairumo.padnote.shape.ShapeEditDialog
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
import com.kairumo.padnote.canvas.CanvasHistory
import com.kairumo.padnote.canvas.CanvasSnapshot
import com.kairumo.padnote.canvas.ContinuousUndoController
import com.kairumo.padnote.text.RichText
import com.kairumo.padnote.text.TextFormatScope
import com.kairumo.padnote.text.WordFormatControls
import com.kairumo.padnote.text.WordFormatState
import com.kairumo.padnote.text.applyWordFormat
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
import com.kairumo.padnote.ink.PalmThresholdDialog
import com.kairumo.padnote.ink.PalmThresholdStore
import com.kairumo.padnote.ink.AdvancedPenSettingsDialog
import com.kairumo.padnote.ink.PenSettingsStore
import com.kairumo.padnote.ink.SketchRefineBar
import android.view.HapticFeedbackConstants
import androidx.compose.ui.platform.LocalView
import com.kairumo.padnote.ai.NoteIntelligenceSheet
import com.kairumo.padnote.ai.notePlainText
import com.kairumo.padnote.ink.PenHardware
import uniffi.padnote_core.FfiImportSlot
import uniffi.padnote_core.FfiPenOutcome
import com.kairumo.padnote.asset.AssetLibrarySheet
import com.kairumo.padnote.collab.CollaborationManager
import com.kairumo.padnote.collab.AndroidCollabCanvas
import com.kairumo.padnote.collab.AndroidCollabController
import com.kairumo.padnote.collab.CollabPageStores
import com.kairumo.padnote.collab.ContinuousCollabBridge
import com.kairumo.padnote.collab.PeerSelectionLayer
import com.kairumo.padnote.collab.CollaborationSheet
import com.kairumo.padnote.asset.renderAssetPng
import com.kairumo.padnote.model3d.Model3DLayer
import com.kairumo.padnote.model3d.Model3DObject
import com.kairumo.padnote.model3d.Model3DStudio
import com.kairumo.padnote.theme.CompositionOverlay
import com.kairumo.padnote.theme.ThemeToolsSheet
import com.kairumo.padnote.ink.InkTool
import com.kairumo.padnote.ink.DraftingState
import com.kairumo.padnote.ink.inkToolShortcutOrder
import com.kairumo.padnote.ink.InkToolbar
import com.kairumo.padnote.ink.InkLatencyMeter
import com.kairumo.padnote.ink.DraftTool
import com.kairumo.padnote.ink.DraftToolController
import com.kairumo.padnote.ink.DraftingToolboxDialog
import com.kairumo.padnote.ink.LowLatencyInkCanvas
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
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
import uniffi.padnote_core.collabDecrypt
import uniffi.padnote_core.collabEncrypt
import uniffi.padnote_core.collabGenerateRoomKey
import uniffi.padnote_core.coreVersion
import uniffi.padnote_core.PadnoteSession
import uniffi.padnote_core.RelayServer
import java.util.Locale
import com.kairumo.padnote.profile.ProfileContext

/**
 * Android 外殼的起點（工作包 WP2）。
 *
 * 現階段的唯一任務：證明 Kotlin ⇄ UniFFI ⇄ libpadnote_core.so 這條路是通的。
 * 筆跡引擎（WP5）與其餘平台功能（WP6）會在這之上長出來。
 */
@OptIn(androidx.compose.ui.ExperimentalComposeUiApi::class)
class MainActivity : FragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        com.kairumo.padnote.platform.CrashLogger.install(applicationContext)
        com.kairumo.padnote.platform.MainThreadStallMonitor.start()
        com.kairumo.padnote.platform.ExitReasonLogger.logRecent(applicationContext)
        com.kairumo.padnote.platform.StartupLogger.logKey("log_main_activity_create")
        // 跨裝置語言要在畫出任何東西**之前**讀進來，不然第一幀會是舊語言，
        // 使用者會看到介面閃一下才變過去。
        applySyncedLanguage(this)
        com.kairumo.padnote.platform.StartupLogger.logKey("log_language_applied", deviceLanguageTag())
        // 自動清理暫存、過期殘檔與期滿的回收桶（背景執行緒，不拖慢第一幀）。
        Thread {
            runCatching { com.kairumo.padnote.platform.StorageSweeper.sweepAtLaunch(applicationContext) }
        }.start()
        val isTabletDevice = (resources.configuration.screenLayout and android.content.res.Configuration.SCREENLAYOUT_SIZE_MASK) >= android.content.res.Configuration.SCREENLAYOUT_SIZE_LARGE
        if (isTabletDevice) {
            // 平板開啟時預設自動展開全螢幕
            androidx.core.view.WindowCompat.setDecorFitsSystemWindows(window, false)
        }
        setContent {
            // 用自己的主題，不用 MaterialTheme 的預設值（工作項 S-62）。
            // 預設值是 Material 的基準紫，而且**不跟隨深色模式** ——
            // 使用者把系統切成深色，App 仍然一片白。見 ui/Theme.kt。
            // 介面語言在最外層提供一次（見 ui/LocalAppLanguage.kt）——
            // 畫布上的把手那種葉節點才不必為了兩個無障礙標籤，
            // 把 languageTag 一路串過六個檔案。
            CompositionLocalProvider(LocalAppLanguage provides deviceLanguageTag()) {
            KairumoTheme {
                Surface(
                    modifier = Modifier.fillMaxSize().semantics { testTagsAsResourceId = true }
                ) {
                    // 使用中的設定檔上了鎖：過了關才看得到內容。**只是畫面閘門**（見 ProfileLockService）。
                    var locked by remember { mutableStateOf(ProfileGate.isLocked(this@MainActivity)) }
                    DisposableEffect(Unit) {
                        // 離開超過一分鐘再回來，有鎖的設定檔要重新上鎖。
                        val observer = androidx.lifecycle.LifecycleEventObserver { _, event ->
                            when (event) {
                                androidx.lifecycle.Lifecycle.Event.ON_STOP -> ProfileGate.noteStopped()
                                androidx.lifecycle.Lifecycle.Event.ON_START ->
                                    if (ProfileGate.noteStarted(this@MainActivity)) locked = true
                                else -> Unit
                            }
                        }
                        lifecycle.addObserver(observer)
                        onDispose { lifecycle.removeObserver(observer) }
                    }
                    if (locked) {
                        com.kairumo.padnote.profile.ProfileLockScreen(this@MainActivity) { locked = false }
                    } else {
                        KairumoApp()
                    }
                }
            }
            }
        }
    }

    /**
     * 系統要求釋放記憶體時，先放掉常駐的 Whisper 模型（約 574 MB）。
     * 下次轉錄會自動重新載入。
     *
     * 只是切到背景（`UI_HIDDEN`）不放：背景錄音時轉錄還在跑，放掉只會讓下一段重載好幾秒。
     */
    @Suppress("DEPRECATION") // TRIM_MEMORY_RUNNING_LOW 在 API 34 標為過時，但 minSdk 29 仍會收到
    override fun onTrimMemory(level: Int) {
        super.onTrimMemory(level)
        if (level != android.content.ComponentCallbacks2.TRIM_MEMORY_UI_HIDDEN &&
            level >= android.content.ComponentCallbacks2.TRIM_MEMORY_RUNNING_LOW
        ) {
            uniffi.padnote_core.whisperReleaseModel()
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

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
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
    val initialOpenId = remember { activity.intent?.getStringExtra("open_notebook_id") }
    var openedId by remember { mutableStateOf<String?>(initialOpenId) }

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

    // 範例（見 SampleFork）：打開時先把套件備份到暫存區，期間不提示、不同步；
    // 離開或切換時內容真的有改，才問要存檔（保留在此範例）、另存可編輯副本或放棄修改。
    // 用這個 scope：它活過 openedId 的切換。
    val sampleScope = rememberCoroutineScope()
    val sampleDevice = remember { deviceId(activity) }
    LaunchedEffect(initialOpenId) {
        if (initialOpenId != null) {
            withContext(Dispatchers.IO) {
                com.kairumo.padnote.library.SampleFork.begin(activity, initialOpenId, sampleDevice)
            }
        }
    }
    var sampleAskId by remember { mutableStateOf<String?>(null) }
    var afterSampleLeave by remember { mutableStateOf<(() -> Unit)?>(null) }
    fun openNotebook(target: String) {
        sampleScope.launch {
            withContext(Dispatchers.IO) { com.kairumo.padnote.library.SampleFork.begin(activity, target, sampleDevice) }
            openedId = target
        }
    }
    fun leaveNotebook(current: String, then: () -> Unit) {
        sampleScope.launch {
            val changed = withContext(Dispatchers.IO) {
                com.kairumo.padnote.library.SampleFork.hasChanges(activity, current, sampleDevice)
            }
            if (changed) {
                afterSampleLeave = then
                sampleAskId = current
            } else {
                withContext(Dispatchers.IO) {
                    com.kairumo.padnote.library.SampleFork.finish(
                        activity, current, sampleDevice, deviceLanguageTag(),
                        com.kairumo.padnote.library.SampleFork.Choice.KEEP)
                }
                then()
            }
        }
    }
    fun resolveSample(choice: com.kairumo.padnote.library.SampleFork.Choice) {
        val sampleId = sampleAskId ?: return
        val then = afterSampleLeave
        sampleAskId = null
        afterSampleLeave = null
        sampleScope.launch {
            withContext(Dispatchers.IO) {
                com.kairumo.padnote.library.SampleFork.finish(activity, sampleId, sampleDevice, deviceLanguageTag(), choice)
            }
            then?.invoke()
        }
    }
    // 回到首頁時補問：上次離開範例時沒機會問的（App 被關掉）。沒改的直接收掉。
    LaunchedEffect(openedId, sampleAskId) {
        if (openedId != null || sampleAskId != null) return@LaunchedEffect
        sampleAskId = withContext(Dispatchers.IO) {
            var changedId: String? = null
            for (pending in com.kairumo.padnote.library.SampleFork.pendingIds(activity)) {
                if (com.kairumo.padnote.library.SampleFork.hasChanges(activity, pending, sampleDevice)) {
                    changedId = pending
                    break
                }
                com.kairumo.padnote.library.SampleFork.finish(
                    activity, pending, sampleDevice, deviceLanguageTag(),
                    com.kairumo.padnote.library.SampleFork.Choice.KEEP)
            }
            changedId
        }
    }
    sampleAskId?.let { _ ->
        val lang = deviceLanguageTag()
        AlertDialog(
            onDismissRequest = { /* 一定要選一個；按外面不關 */ },
            title = { Text(LocalizationStrings.localized("sample_leave_title", lang)) },
            text = { Text(LocalizationStrings.localized("sample_leave_message", lang)) },
            confirmButton = {
                Column(horizontalAlignment = Alignment.End) {
                    TextButton(
                        onClick = { resolveSample(com.kairumo.padnote.library.SampleFork.Choice.KEEP) },
                        modifier = Modifier.testTag("sample.leave.keep")
                    ) { Text(LocalizationStrings.localized("sample_leave_keep", lang)) }
                    TextButton(
                        onClick = { resolveSample(com.kairumo.padnote.library.SampleFork.Choice.SAVE_COPY) },
                        modifier = Modifier.testTag("sample.leave.copy")
                    ) { Text(LocalizationStrings.localized("sample_leave_copy", lang)) }
                    TextButton(
                        onClick = { resolveSample(com.kairumo.padnote.library.SampleFork.Choice.DISCARD) },
                        modifier = Modifier.testTag("sample.leave.discard")
                    ) {
                        Text(LocalizationStrings.localized("sample_leave_discard", lang), color = MaterialTheme.colorScheme.error)
                    }
                    // 從編輯器離開時可以取消、回到範例繼續；回首頁補問的沒有「取消」（範例已經關了）。
                    if (afterSampleLeave != null) {
                        TextButton(onClick = { sampleAskId = null; afterSampleLeave = null }) {
                            Text(LocalizationStrings.localized("cancel", lang))
                        }
                    }
                }
            }
        )
    }

    val id = openedId
    if (id == null) {
        NotebookHome(
            folderId = folderId,
            onFolderChange = { folderId = it },
            onOpen = {
                if (!it.equals(uniffi.padnote_core.recordingInboxNotebookId(), ignoreCase = true)) {
                    openNotebook(it)
                }
            }
        )
    } else {
        InkScreen(
            notebookId = id,
            onBack = { leaveNotebook(id) { openedId = null } },
            onOpenNotebook = { target ->
                if (!target.equals(uniffi.padnote_core.recordingInboxNotebookId(), ignoreCase = true)) {
                    leaveNotebook(id) { openNotebook(target) }
                }
            }
        )
    }
}

/**
 * 首頁：筆記本清單、搜尋、新增、身分、備份。
 *
 * 這一層只負責「把狀態接上 [HomeScreen]」—— 版面在那邊，資料在
 * [NotebookLibrary]，兩邊都不知道對方的存在。
 */

/**
 * 手寫畫面（工作包 WP5）。
 *
 * 主體是畫布 —— 這是一個筆記 App，開起來就該能寫字。核心狀態那些數字移進
 * 對話框：它們是驗證用的憑據，不是使用者每天要看的東西。
 */


@OptIn(ExperimentalLayoutApi::class, ExperimentalFoundationApi::class)
@Composable
private fun InkScreen(
    notebookId: String? = null,
    onBack: (() -> Unit)? = null,
    /** 從結構欄的「資料夾目錄」分頁切到另一本筆記（S-96）。 */
    onOpenNotebook: ((String) -> Unit)? = null
) {
    val activity = LocalContext.current as ComponentActivity
    val ctx = rememberEditorCanvasContext(activity, notebookId, onBack, onOpenNotebook)

    val toolbarPlacement = com.kairumo.padnote.ui.ToolbarSettings.placement

    val inkBarState = InkBarState(
        tool = ctx.inkTool,
        colorHex = ctx.inkColorHex,
        width = ctx.inkWidth,
        languageTag = deviceLanguageTag(),
        // 一定要走 applyInkTool：只改 inkTool 的話 engine.isErasing／engine.tool 不會跟著改，
        // 從工具列點橡皮擦畫下去還是墨跡、離開套索時選取框也不會收掉（拆檔時斷掉的那一條）。
        onToolChange = { t -> ctx.applyInkTool(t) },
        onColorChange = { c -> ctx.inkColorHex = c },
        onWidthChange = { w -> ctx.inkWidth = w },
        onOpenColorWheel = { ctx.showProColorWheel = true },
        onAddTextBox = {
            val box = ctx.textStore.createBoxed(200f, 200f, ctx.textStore.pageRules(ctx.meta.paperId(ctx.pageIndex)), ctx.snapToGrid)
            ctx.textStore.persist(box)
            ctx.editingText = box
            ctx.selectText(box.id)
            ctx.editorMode = EditorMode.TYPE
            ctx.textRevision++
            ctx.stackRevision++
        }
    )

    ctx.toolbarPlacement = toolbarPlacement
    ctx.inkBarState = inkBarState

    with(ctx) {
        val topBarState = EditorTopBarState(
            title = noteTitle,
            showPageSidebar = showPageSidebar,
            minimalistCanvasMode = minimalistCanvasMode,
            editorMode = editorMode,
            effectiveToolbarMode = effectiveToolbarMode,
            showRadialMenu = showRadialMenu,
            isTabletopActive = isTabletopActive,
            hiddenTools = com.kairumo.padnote.ui.ToolbarSettings.hiddenIdentifiers,
            canUndo = true,
            canRedo = true,
            isPlacingCommentPin = isPlacingCommentPin,
            pageIndex = pageIndex,
            pageCount = pageCount,
            pageDisplayMode = pageDisplayMode,
            isCollabConnected = collabActive,
            recording = recording,
            recordingPaused = recordingPaused,
            recordSeconds = recordSeconds,
            backlogUs = backlogUs,
            lowLatency = lowLatency,
            lowLatencyUnavailable = lowLatencyUnavailable,
            penOnly = penOnly,
            toolbarPlacement = toolbarPlacement,
            marqueeActive = marqueeActive,
            marqueeAdditive = marqueeAdditive,
            canSelectAll = marqueeSelection.size < marqueeCandidatesLatest.size,
            canDeselectAll = marqueeSelection.isNotEmpty(),
            hasMarqueeSelection = marqueeSelection.isNotEmpty(),
            marqueeSelectionCount = marqueeSelection.size,
            hasClipboardContent = objectClipboard.isNotEmpty(),
            snapToGrid = snapToGrid,
            showInkDebug = showInkDebug,
            micBlocked = micBlocked,
            statusMessage = message,
            languageTag = deviceLanguageTag(),
            isGoogleSignedIn = AccountManager.isCloudBound(activity),
            hasFolderSyncUri = FolderSync.folderUri(activity) != null
        )

        val topBarActions = EditorTopBarActions(
            onBack = onBack,
            onToggleSidebar = { showPageSidebar = !showPageSidebar },
            onEnterMinimalist = { minimalistCanvasMode = true },
            onExitMinimalist = { minimalistCanvasMode = false },
            onRenameTitle = { renamingCurrent = true },
            onModeChange = { newMode ->
                editorMode = newMode
                if (newMode == EditorMode.DRAW) {
                    clearSelection()
                    editingText = null
                }
            },
            onToggleRadialMenu = {
                // 從工具列叫出的放在畫布正中央（與 Apple 一致）。拆檔時這一段掉了，
                // 工具盤會開在上一次長按的位置，甚至在畫面角落。
                radialMenuCenter = androidx.compose.ui.geometry.Offset(
                    if (canvasViewport.width > 0) canvasViewport.width / 2f else 300f,
                    if (canvasViewport.height > 0) canvasViewport.height / 2f else 300f
                )
                showRadialMenu = !showRadialMenu
            },
            onToggleTabletop = { isTabletopActive = !isTabletopActive },
            onUndo = { globalUndo() },
            onRedo = { globalRedo() },
            onRevertInitial = { showRevertConfirm = true },
            onOpenAssetLibrary = { showAssetLibrary = true },
            onToggleCommentPin = { isPlacingCommentPin = !isPlacingCommentPin },
            onPrevPage = { switchToPage(pageIndex - 1) },
            onNextPage = { switchToPage(pageIndex + 1) },
            onAddPage = {
                val s = notebook?.first
                if (s != null) {
                    runCatching { s.addPage(uniffi.padnote_core.PageStyle.BLANK) }
                    pageCount = runCatching { s.pageCount().toInt() }.getOrDefault(pageCount + 1)
                    switchToPage(pageCount - 1)
                    revision++
                    continuousContentRevision++
                }
            },
            onTogglePageDisplayMode = {
                pageDisplayMode = if (pageDisplayMode == PageDisplayMode.CONTINUOUS) {
                    PageDisplayMode.SINGLE
                } else {
                    PageDisplayMode.CONTINUOUS
                }
                ProfileContext.prefs(activity, "kairumo_editor")
                    .edit().putString("pageDisplayMode", pageDisplayMode.wire).apply()
            },
            onOpenCollaboration = { showCollaboration = true },
            onExport = { fmt -> exportNow(fmt) },
            onPrint = { notebook?.first?.let { printNow(it) } },
            onSaveAs = {
                val id = notebookId
                if (id != null) {
                    val dir = File(NotebookLibrary.directory(activity), "$id.${NotebookLibrary.EXTENSION}")
                    val title = FolderTree.titleOf(activity, id) ?: "Notebook"
                    Exporter.sharePackage(activity, dir, title)
                        .mapCatching { it.readBytes() }
                        .fold(
                            onSuccess = {
                                pendingSaveBytes = it
                                saveAsPicker.launch("$title.${NotebookLibrary.EXTENSION}")
                            },
                            onFailure = { message = exportFailureMessage(it) }
                        )
                }
            },
            onSharePackage = {
                val id = notebookId
                if (id != null) {
                    val dir = File(NotebookLibrary.directory(activity), "$id.${NotebookLibrary.EXTENSION}")
                    val title = FolderTree.titleOf(activity, id) ?: "Notebook"
                    message = shareNotebookPackage(activity, dir, title)
                }
            },
            onFolderSyncNow = {
                message = runFolderSync(activity, notebook?.first)
            },
            onOpenProColors = { showProColors = true },
            onOpenLanguagePicker = { showLanguagePicker = true },
            onAiSummary = { showNoteIntelligence = true },
            onThemeTools = { showThemeTools = true },
            onCustomizeToolbar = { showToolbarCustomization = true },
            onInsertStickers = { showStickerLibrary = true },
            onInsertImage = {
                photoPicker.launch(androidx.activity.result.PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
            },
            // 這三個原本沒接上（`EditorTopBarActions` 的預設是空的）：選單點下去什麼都不會發生。
            onInsertPdf = { pdfPicker.launch(com.kairumo.padnote.platform.FileImport.mimeTypes(uniffi.padnote_core.FfiImportSlot.PDF)) },
            onInsertDocument = { documentPicker.launch(com.kairumo.padnote.platform.FileImport.mimeTypes(uniffi.padnote_core.FfiImportSlot.DOCUMENT)) },
            onImportImageFile = { imagePicker.launch(com.kairumo.padnote.platform.FileImport.mimeTypes(uniffi.padnote_core.FfiImportSlot.IMAGE)) },
            onInsertAudio = { insertingAudio = true },
            onInsertChart = { insertingChart = true },
            onInsertTable = { insertingTable = true },
            onInsertShape = { insertingShape = true },
            onInsertMath = { showCalculator = true },
            onShowDiagnostics = { showStatus = true },
            onOpenAppSettings = {
                val intent = android.content.Intent(
                    android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    android.net.Uri.fromParts("package", activity.packageName, null)
                )
                activity.startActivity(intent)
            },
            onToggleSnapToGrid = { snapToGrid = !snapToGrid },
            onAddTextBox = {
                val box = textStore.createBoxed(200f, 200f, textStore.pageRules(meta.paperId(pageIndex)), snapToGrid)
                textStore.persist(box)
                editingText = box
                selectText(box.id)
                editorMode = EditorMode.TYPE
                textRevision++
                stackRevision++
            },
            onInsertSymbol = { showSymbolPicker = true },
            onInsertLink = { insertingLink = true },
            onInsertModel3D = { insertingModel3D = true }
        )

        val formatTarget = selectedTextId?.let { textStore.find(it) }

        Column(modifier = Modifier.fillMaxSize().statusBarsPadding()) {
            EditorTopBar(
                state = topBarState,
                actions = topBarActions,
                inkBarState = inkBarState,
                formatTarget = formatTarget,
                contextualState = contextualState,
                l10n = l10n
            )
            EditorCanvasContainer(ctx)
        }
    }
    EditorFloatingPanels(ctx)
}

// ────────────────────────────── 平台共用輔助 ──────────────────────────────

/**
 * 依裝置語系取介面字串。
 *
 * 字串表由 i18n/ui-strings.json 產生，Apple 版的 LocalizationManager 讀的是
 * 同一份來源產出的 Swift 表 —— 兩邊逐字相同，不會各自漂移。
 */
internal fun uiString(key: String): String =
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
internal fun catalogLang(tag: String): String = when (tag) {
    "zh-Hant" -> "zhHant"
    "zh-Hans" -> "zhHans"
    "en" -> "en"
    "ja" -> "ja"
    "ko" -> "ko"
    "th" -> "th"
    else -> "zhHant"
}

internal fun currentLanguageTag(): String = deviceLanguageTag()

/** 測試用：只改這個 process 的語言，不寫進跨裝置設定。傳 null 還原。 */
internal fun overrideLanguageForTest(tag: String?) {
    syncedLanguageOverride = tag
}

internal fun deviceLanguageTag(): String {
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
internal fun openNotebook(
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
internal fun deviceId(activity: ComponentActivity): UInt {
    val prefs = ProfileContext.prefs(activity, "kairumo")
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

/** 叫出系統分享面板，並回報給使用者看的一句話。 */
internal fun shareExported(
    activity: ComponentActivity,
    file: java.io.File,
    format: Exporter.Format
): String {
    runCatching {
        activity.startActivity(
            android.content.Intent.createChooser(
                Exporter.shareIntent(activity, file, format), null
            )
        )
    }
    return LocalizationStrings.localized("export_done", deviceLanguageTag())
        .replace("%@", file.name)
}

internal fun exportFailureMessage(t: Throwable): String =
    LocalizationStrings.localized("export_failed", deviceLanguageTag())
        .replace("%@", t.message ?: t.toString())


/**
 * 把這一頁的手寫辨識成文字並寫進搜尋索引（工作包 WP7）。
 *
 * 辨識結果**只進索引**，不取代也不修改任何一筆畫 —— 手寫筆記的價值就在那個
 * 手寫，辨識只是讓它搜得到。
 *
 * 每一組的文字只掛在該組的**第一筆**上。掛在每一筆的話，搜「交付」會為同一個
 * 詞回報好幾個命中，使用者看到的是一堆重複的結果。
 */
internal suspend fun recognizeHandwriting(
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

/** `#RRGGBB` → 核心要的 RGBA 位元組（不透明）。 */
internal fun hexToRgba(hex: String): ByteArray {
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

/**
 * 這支 App 的版本字串（系統診斷對話框用）。
 *
 * 獨立成頂層函式的理由同 [placeSolidSheet]：寫在 `InkScreen` 裡，`remember { runCatching { … } }`
 * 會整段內聯進那個四百多個暫存器的函式，D8 在這一段配出型別衝突的暫存器，啟動即 `VerifyError`
 * （2026-10 改連續模式飛梭盤時實際踩到）。
 */
internal fun appVersionName(activity: android.app.Activity): String =
    runCatching { activity.packageManager.getPackageInfo(activity.packageName, 0).versionName }
        .getOrNull() ?: "1.0.0"
