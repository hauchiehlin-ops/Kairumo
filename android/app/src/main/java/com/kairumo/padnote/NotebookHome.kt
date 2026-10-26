package com.kairumo.padnote

import android.Manifest
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.documentfile.provider.DocumentFile
import com.kairumo.padnote.account.AccountManager
import com.kairumo.padnote.account.IdentityDialog
import com.kairumo.padnote.audio.AudioPlayback
import com.kairumo.padnote.backup.BackupManager
import com.kairumo.padnote.crypto.EncryptedNotebookDialog
import com.kairumo.padnote.crypto.UnlockNotebookDialog
import com.kairumo.padnote.library.*
import com.kairumo.padnote.oauth.GoogleAuth
import com.kairumo.padnote.platform.AudioCapture
import com.kairumo.padnote.platform.Exporter
import com.kairumo.padnote.profile.*
import com.kairumo.padnote.sync.*
import com.kairumo.padnote.ui.SyncDoctorCard
import com.kairumo.padnote.ui.SyncLogCard
import com.kairumo.padnote.ui.AppCommands
import com.kairumo.padnote.ui.AppCommand
import com.kairumo.padnote.ui.AppDiagnosticsDialog

import com.kairumo.padnote.sync.SyncSource
import java.io.File
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import uniffi.padnote_core.PadnoteSession

@Composable
internal fun NotebookHome(
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
    /// 建立**加密**筆記本的流程（H-CRYPTO）。與一般新增分開：
    /// 它有三步而且不能跳（設密碼 → 抄復原碼 → 把復原碼輸回來）。
    var creatingEncryptedNotebook by remember { mutableStateOf(false) }
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
    // 從資料夾的「⋯ → 新增子資料夾」建立時，新資料夾的上層；null = 目前所在的這一層。
    var newFolderParent by remember { mutableStateOf<String?>(null) }
    var renamingFolder by remember { mutableStateOf<FolderTree.Folder?>(null) }
    // 最上層那一層沒有對應的資料夾物件，所以要一個自己的狀態。
    var renamingRoot by remember { mutableStateOf(false) }
    // 首頁的系統診斷。Apple 在頁尾的版本號上，Android 原本只在編輯器選單裡 ——
    // 要回報問題的人得先開一本筆記才找得到那一頁。
    var homeStatus by remember { mutableStateOf(false) }
    var showBackupCreateDialog by remember { mutableStateOf(false) }
    var showNotebookSnapshotPicker by remember { mutableStateOf(false) }
    var showBackupRestoreDialog by remember { mutableStateOf(false) }
    var showFolderSyncDialog by remember { mutableStateOf(false) }
    var showCloudSyncDialog by remember { mutableStateOf(false) }
    var deletingFolder by remember { mutableStateOf<FolderTree.Folder?>(null) }
    var editingIdentity by remember { mutableStateOf(false) }
    var showProfilePicker by remember { mutableStateOf(false) }
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
    var renamingRecording by remember { mutableStateOf<RecordingIndex.Recording?>(null) }
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
    // 範例修復、筆記本核心重播和錄音索引讀取都可能很慢；不要在 Compose 主執行緒開啟套件。
    var seedGeneration by remember { mutableIntStateOf(-1) }
    var allEntries by remember { mutableStateOf(emptyList<NotebookLibrary.Entry>()) }
    var recordings by remember { mutableStateOf(emptyList<RecordingIndex.Recording>()) }
    LaunchedEffect(Unit) {
        seedGeneration = withContext(Dispatchers.IO) {
            SeedNotebooks.seedIfEmpty(activity, device, lang)
        }
    }
    LaunchedEffect(revision, sort, seedGeneration) {
        if (seedGeneration < 0) return@LaunchedEffect
        val loaded = withContext(Dispatchers.IO) {
            val notebooks = NotebookLibrary.all(activity, device, sort)
            val recentRecordings = RecordingIndex.recent(activity, device, notebooks = notebooks)
            notebooks to recentRecordings
        }
        allEntries = loaded.first
        recordings = loaded.second
    }
    // 搬移對話框要列出**全部**資料夾，不是只有這一層的。
    val treeVer = FolderTree.treeVersion
    val allFolders = remember(revision, treeVer) { FolderTree.all(activity) }
    // revision 是重讀的觸發器。清單來自檔案系統，沒有觀察者可以訂閱 ——
    // 新增或刪除之後不主動重讀的話，畫面會停在舊的內容。
    val entries = remember(revision, treeVer, allEntries, folderId, allFolders) {
        if (folderId == NotebookLibrary.ANY_FOLDER) allEntries
        else allEntries.filter {
            val parent = FolderTree.parentOf(activity, it.id)
            if (folderId == null) {
                parent == null || allFolders.none { f -> f.id.equals(parent, ignoreCase = true) }
            } else {
                parent != null && parent.equals(folderId, ignoreCase = true)
            }
        }
    }
    val folders = remember(revision, treeVer, folderId) { FolderTree.subfolders(activity, folderId) }
    val breadcrumb = remember(revision, treeVer, folderId) { FolderTree.pathTo(activity, folderId) }
    // 同步都在背景執行緒跑，共用同一個 scope。宣告要在第一個使用點之前 ——
    // Compose 的函式本體是由上往下讀的。
    val autoSyncScope = rememberCoroutineScope()

    // Google 帳號同步的畫面狀態。與 Apple 的 `googleAccountSection` 對應。
    var cloudBusy by remember { mutableStateOf(false) }
    var cloudMessage by remember { mutableStateOf<String?>(null) }
    val authRevision by com.kairumo.padnote.oauth.GoogleAuth.authRevision.collectAsState()
    val lastAuthError by com.kairumo.padnote.oauth.GoogleAuth.lastAuthError.collectAsState()
    val autoSyncRunning by com.kairumo.padnote.sync.AutoSync.isSyncing.collectAsState()
    // `revision` 與 `authRevision` 也當成重讀的觸發器：登入是跳出去系統瀏覽器再回來的，
    // 回來時要重新問一次「現在登入了沒」。
    val signedIn = remember(revision, cloudBusy, authRevision, autoSyncRunning) {
        com.kairumo.padnote.oauth.GoogleAuth.isSignedIn(activity)
    }

    fun runCloudSync() {
        if (cloudBusy) return
        cloudBusy = true
        cloudMessage = l("syncing")
        autoSyncScope.launch {
            var result = withContext(Dispatchers.IO) {
                com.kairumo.padnote.library.CloudSync.runFull(activity, device)
            }
            // 若剛剛好撞上 AutoSync 正在跑的那一輪（skipped = true），等那一輪結束後再補跑一次，
            // 絕不能把 skipped 的 meta == null 誤判成「尚未登入」。
            if (result.skipped && com.kairumo.padnote.oauth.GoogleAuth.isSignedIn(activity)) {
                kotlinx.coroutines.delay(1200)
                result = withContext(Dispatchers.IO) {
                    com.kairumo.padnote.library.CloudSync.runFull(activity, device)
                }
            }
            val meta = result.meta
            cloudBusy = false
            if (result.skipped) {
                // 另一輪仍在同步中，不顯示假錯誤，交由該輪完成時更新畫面。
                revision++
                return@launch
            }
            // 成功才記時間 —— 失敗也記的話，「上次同步」會變成
            // 「上次按下按鈕」，那正好是使用者想分辨的兩件事。
            if (meta != null && meta.ok && !meta.needsReauth) {
                com.kairumo.padnote.library.SyncHistory.markGoogleSynced(activity)
                // 順便問一次「這是誰的帳號」。`accountEmail` 內部會分別寫入 email 與顯示名稱，
                // 切勿把回傳的顯示名稱再塞回 `setAccount`，否則會把 email 蓋掉。
                withContext(Dispatchers.IO) {
                    com.kairumo.padnote.library.CloudSync.accountEmail(activity)
                }
                profile = AccountManager.load(activity, l("default_user_name"))
            }
            cloudMessage = when {
                meta == null ->
                    if (com.kairumo.padnote.oauth.GoogleAuth.isSignedIn(activity)) {
                        l("sync_failed").replace("%@", L10n.t("drive_cred_refresh_failed"))
                    } else {
                        l("not_signed_in")
                    }
                meta.needsReauth -> l("sync_needs_reauth")
                !meta.ok -> l("sync_failed").replace("%@", L10n.coreText(meta.error))
                // 講出上傳與下載的數量，與 Apple 一致。只說「完成」的話，
                // 使用者分不出「真的傳了東西」與「其實什麼也沒做」。
                else -> l("sync_result")
                    .replace("%1@", result.uploaded.toString())
                    .replace("%2@", result.downloaded.toString())
            }
            if (result.changed.isNotEmpty() || result.downloaded > 0 || (meta != null && meta.ok)) revision++
        }
    }

    LaunchedEffect(authRevision, signedIn, lastAuthError) {
        if (signedIn) {
            withContext(Dispatchers.IO) {
                if (com.kairumo.padnote.library.SyncHistory.accountName(activity) == null ||
                    com.kairumo.padnote.library.AccountSyncStore.lastAccount(activity).isEmpty()
                ) {
                    com.kairumo.padnote.library.CloudSync.accountEmail(activity)
                }
            }
        }
        profile = AccountManager.load(activity, l("default_user_name"))
        if (lastAuthError != null && !signedIn) {
            cloudMessage = l("sync_failed").replace("%@", L10n.coreText(lastAuthError ?: ""))
        } else if (authRevision > 0 && com.kairumo.padnote.oauth.GoogleAuth.isSignedIn(activity)) {
            cloudMessage = l("sync_google_authorized")
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
                androidx.lifecycle.Lifecycle.Event.ON_RESUME -> {
                    com.kairumo.padnote.sync.AutoSync.request(
                        activity, uniffi.padnote_core.FfiSyncTrigger.FOREGROUND)
                    com.kairumo.padnote.sync.FocusSync.onForeground()
                }
                // 進背景前推一次：系統隨時可能把行程收掉，
                // 沒推出去的內容要等下次開啟才會走。
                androidx.lifecycle.Lifecycle.Event.ON_PAUSE -> {
                    com.kairumo.padnote.sync.AutoSync.request(
                        activity, uniffi.padnote_core.FfiSyncTrigger.BACKGROUND)
                    com.kairumo.padnote.sync.FocusSync.onBackground()
                    // 有還沒推上雲端的編輯：排一個加急背景工作，讓行程活到推完。
                    if (com.kairumo.padnote.sync.FocusSync.hasUnflushed()) {
                        com.kairumo.padnote.sync.FlushWorker.enqueue(activity)
                    }
                }
                else -> Unit
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    // 同步把別台的 oplog 寫進套件之後，清單要重讀 —— 不重讀的話，
    // 畫面上還是同步前的樣子，使用者會以為同步沒作用。
    // 範例另存成一般筆記本、範例重設之後（背景完成），清單要重讀。
    val sampleForks by com.kairumo.padnote.library.SampleFork.forks.collectAsState()
    LaunchedEffect(sampleForks) { if (sampleForks > 0) revision++ }
    val changedNotebooks by com.kairumo.padnote.sync.AutoSync.changedNotebooks.collectAsState()
    LaunchedEffect(changedNotebooks) {
        if (changedNotebooks.isNotEmpty()) {
            revision++
            com.kairumo.padnote.sync.AutoSync.consumeChanged()
        }
    }
    val syncCompletedRev by com.kairumo.padnote.sync.AutoSync.syncCompletedRevision.collectAsState()
    LaunchedEffect(syncCompletedRev) {
        if (syncCompletedRev > 0) {
            profile = AccountManager.load(activity, l("default_user_name"))
            revision++
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
            onSwitchUser = { showProfilePicker = true },
            onToggleRecording = {
                if (AudioCapture.hasPermission(activity)) {
                    showQuickRecordDialog = true
                } else {
                    homeMicPermission.launch(Manifest.permission.RECORD_AUDIO)
                }
            },
            onBackup = { showBackupCreateDialog = true },
            onCreateSnapshot = { entry ->
                if (entry == null) {
                    showNotebookSnapshotPicker = true
                } else {
                    message = shareNotebookPackage(activity, entry.path, entry.title)
                }
            },
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
            onCreateFolder = { newFolderParent = null; creatingFolder = true },
            onCreateSubfolder = { newFolderParent = it.id; creatingFolder = true },
            onRenameFolder = { renamingFolder = it },
            onDeleteFolder = { deletingFolder = it },
            onAssetLibrary = { homeAssets = true },
            onChooseSyncFolder = { showFolderSyncDialog = true },
            onSelectLanguage = { homeLanguagePicker = true },
            onOpenManual = { homeDocs = "manual/index.html" },
            onOpenPrivacy = { homeDocs = "legal/privacy.html" },
            onInsertRecording = { insertingRecording = it },
            onRenameRecording = { renamingRecording = it },
            onToggleSample = { entry ->
                autoSyncScope.launch {
                    withContext(Dispatchers.IO) {
                        com.kairumo.padnote.library.SampleFork.setSample(activity, entry.id, device, !entry.isSample)
                    }
                    AutoSync.noteLocalEdit(activity)
                    revision++
                }
            },
            onDuplicateNotebook = { entry ->
                autoSyncScope.launch {
                    val title = l("copy_suffix").replace(
                        "%@", com.kairumo.padnote.library.SeedNotebooks.baseTitle(entry.title, lang))
                    val newId = withContext(Dispatchers.IO) {
                        NotebookLibrary.duplicate(activity, entry.id, title, device)
                    }
                    if (newId != null) {
                        AutoSync.noteLocalEdit(activity)
                        revision++
                    }
                }
            },
            onDeleteRecording = { rec ->
                // 與 Apple `deleteRecording` 同一條路：核心刪檔並留下帶裝置 id 的媒體墓碑，別台同步後也會消失。
                autoSyncScope.launch {
                    withContext(Dispatchers.IO) {
                        val pkg = java.io.File(
                            NotebookLibrary.directory(activity), "${rec.notebookId}.${NotebookLibrary.EXTENSION}")
                        val error = uniffi.padnote_core.mediaDeleteAudio(pkg.absolutePath, rec.file.name, device)
                        if (error.isNotEmpty()) android.util.Log.w("Kairumo", "刪除錄音：$error")
                        if (rec.file.exists()) rec.file.delete()
                    }
                    if (AudioPlayback.playingId == rec.file.absolutePath) AudioPlayback.stop()
                    AutoSync.noteLocalEdit(activity)
                    revision++
                }
            },
            onRenameRootFolder = {
                // 人在某個資料夾裡就是改那一個；在最上層就是改最上層的顯示名稱。
                val here = breadcrumb.lastOrNull()
                if (here != null) renamingFolder = here else renamingRoot = true
            },
            onOpenDiagnostics = { homeStatus = true },
            onMoveNotebookToFolder = { noteId, targetFolder ->
                // 與「移動到資料夾」選單走同一條路（同一個索引、同一套環狀保護），
                // 不要為了拖放另寫一份 —— 兩份規則遲早會分岔。
                val ok = FolderTree.move(
                    activity, noteId, isFolder = false, toParent = targetFolder
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
                com.kairumo.padnote.platform.DocsScreen(asset, deviceLanguageTag()) { homeDocs = null }
            }
        }
    }

    renamingRecording?.let { rec ->
        FolderNameDialog(
            title = l("rename_audio_card"),
            initial = rec.displayTitle,
            l = ::l,
            onDismiss = { renamingRecording = null },
            onConfirm = { title ->
                renamingRecording = null
                if (title.isNotBlank() &&
                    RecordingTitles.write(activity, rec.notebookId, device, rec.file.name, title)
                ) {
                    // 名字寫進套件了，叫同步去推（與別的本機編輯同一條路）。
                    AutoSync.noteLocalEdit(activity)
                    revision++
                }
            }
        )
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
                                        // 使用者取的名字寫進套件，別台才看得到（原本輸入框的內容被丟掉了）。
                                        val named = recTitle.trim()
                                        val book = targetNoteId ?: NotebookLibrary.recordingInbox(
                                            activity, device, l("recording_inbox"))
                                        if (named.isNotEmpty() && book != null) {
                                            RecordingTitles.newestAudio(activity, book)?.let {
                                                if (RecordingTitles.write(s, it.name, named)) {
                                                    AutoSync.noteLocalEdit(activity)
                                                }
                                            }
                                        }
                                        message = l("recorded_duration").replace("%@", "${us / 1_000_000uL}")
                                        homeAudio.showAdviceOnce(deviceLanguageTag())
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
                                        val err = homeAudio.start(null, session, lang)
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
        val ver = remember { appVersionName(activity) }
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

    if (showNotebookSnapshotPicker) {
        TransferPagesDialog(
            title = l("backup_snapshot_picker_title"),
            notebooks = allEntries,
            l = ::l,
            onDismiss = { showNotebookSnapshotPicker = false },
            onPick = { entry ->
                showNotebookSnapshotPicker = false
                message = shareNotebookPackage(activity, entry.path, entry.title)
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
            onDismiss = { creatingFolder = false; newFolderParent = null },
            onConfirm = { title ->
                FolderTree.create(activity, title, newFolderParent ?: folderId)
                creatingFolder = false
                newFolderParent = null
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
                    activity, entry.id, isFolder = false, toParent = target
                )
                message = l(if (ok) "move_done" else "move_cycle_refused")
                moving = null
                revision++
            }
        )
    }

    if (creatingEncryptedNotebook) {
        com.kairumo.padnote.crypto.EncryptedNotebookDialog(
            l = ::l,
            onDismiss = { creatingEncryptedNotebook = false },
            onCreated = { id, title ->
                // 套件已經由核心建好了（含加密），這裡只補上索引那一筆。
                com.kairumo.padnote.library.AccountSyncStore.record(
                    activity, id = id,
                    title = title.ifBlank { l("new_note") }, parentId = null
                )
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
            // 加密是**另一條路**，不是這張表單裡的一個開關 ——
            // 塞成開關會讓人以為那是可以之後再說的選項，
            // 而復原碼沒有「之後再說」。
            onCreateEncrypted = {
                creatingNotebook = false
                creatingEncryptedNotebook = true
            },
            onCreateKit = { kit ->
                creatingNotebook = false
                var first: String? = null
                for (nb in kit.notebooks) {
                    val name = l(nb.titleKey)
                    val style = DocumentTemplateCatalog.paperStyle(nb.paperId)
                    val id = NotebookLibrary.create(
                        activity, name, device, folderId, style = style, paperId = nb.paperId
                    ) ?: continue
                    NotebookLibrary.open(activity, id, device, name)?.let { (session, _) ->
                        val meta = com.kairumo.padnote.library.NotebookMeta.load(session)
                        if (nb.pageFormatId != uniffi.padnote_core.defaultPageFormatId()) {
                            meta.setPageFormatId(session, nb.pageFormatId)
                        }
                        // 核心建立時已經有第一頁，只補其餘的頁數。
                        repeat((nb.pageCount.toInt() - 1).coerceAtLeast(0)) {
                            runCatching { session.addPage(style) }
                        }
                    }
                    if (first == null) first = id
                }
                revision++
                first?.let { onOpen(it) }
            },
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

    if (showProfilePicker) {
        com.kairumo.padnote.profile.ProfilePickerDialog(activity as androidx.fragment.app.FragmentActivity) {
            showProfilePicker = false
        }
    }
    // 登入的 Google 帳號已經綁在另一位使用者：告訴使用者一次。
    com.kairumo.padnote.profile.ProfileGoogleConflictDialog()

    if (editingIdentity) {
        IdentityDialog(
            profile = profile,
            isCloudBound = AccountManager.isCloudBound(activity),
            l = ::l,
            onDismiss = { editingIdentity = false },
            onSave = { name, hex ->
                if (!AccountManager.isCloudBound(activity)) {
                    AccountManager.saveName(activity, name, l("default_user_name"))
                }
                AccountManager.saveColor(activity, hex)
                profile = AccountManager.load(activity, l("default_user_name"))
            }
        )
    }
}


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

                    var showUnlinkConfirm by remember { mutableStateOf(false) }

                    TextButton(
                        onClick = { showUnlinkConfirm = true },
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text(l("sync_folder_cancel_setting"), color = MaterialTheme.colorScheme.error)
                    }

                    if (showUnlinkConfirm) {
                        AlertDialog(
                            onDismissRequest = { showUnlinkConfirm = false },
                            title = { Text(l("sync_folder_unlink_confirm_title")) },
                            text = { Text(l("sync_folder_unlink_confirm_desc")) },
                            confirmButton = {
                                TextButton(
                                    onClick = {
                                        showUnlinkConfirm = false
                                        onClearFolder()
                                    }
                                ) {
                                    Text(l("folder_unlink"), color = MaterialTheme.colorScheme.error)
                                }
                            },
                            dismissButton = {
                                TextButton(onClick = { showUnlinkConfirm = false }) {
                                    Text(l("cancel"))
                                }
                            }
                        )
                    }

                    var showWipeConfirm by remember { mutableStateOf(false) }
                    var wiping by remember { mutableStateOf(false) }
                    var wipeMessage by remember { mutableStateOf<String?>(null) }
                    val scope = rememberCoroutineScope()
                    val context = LocalContext.current

                    TextButton(
                        onClick = { showWipeConfirm = true },
                        enabled = !wiping && !isSyncing,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        if (wiping) {
                            CircularProgressIndicator(
                                modifier = Modifier.size(18.dp).padding(end = 8.dp),
                                strokeWidth = 2.dp,
                                color = MaterialTheme.colorScheme.error
                            )
                            Text(l("sync_reset_cloud_running"), color = MaterialTheme.colorScheme.error)
                        } else {
                            Text(l("sync_reset_cloud"), color = MaterialTheme.colorScheme.error)
                        }
                    }

                    if (showWipeConfirm) {
                        AlertDialog(
                            onDismissRequest = { showWipeConfirm = false },
                            title = { Text(l("sync_reset_cloud_confirm_title")) },
                            text = { Text(l("sync_reset_cloud_confirm_body")) },
                            confirmButton = {
                                TextButton(onClick = {
                                    showWipeConfirm = false
                                    wiping = true
                                    wipeMessage = l("sync_reset_cloud_running")
                                    scope.launch {
                                        val result = withContext(Dispatchers.IO) {
                                            runCatching { com.kairumo.padnote.sync.FolderSync.wipeCloud(context) }.getOrNull()
                                        }
                                        wipeMessage = when {
                                            result == null -> l("sync_reset_cloud_busy")
                                            result.ok -> l("sync_reset_cloud_done")
                                                .replace("%1@", "${result.deleted}")
                                            else -> l("sync_reset_cloud_partial")
                                                .replace("%1@", "${result.deleted}")
                                                .replace("%2@", "${result.failed}")
                                        }
                                        wiping = false
                                    }
                                }) {
                                    Text(l("sync_reset_cloud"), color = MaterialTheme.colorScheme.error)
                                }
                            },
                            dismissButton = {
                                TextButton(onClick = { showWipeConfirm = false }) { Text(l("cancel")) }
                            }
                        )
                    }

                    wipeMessage?.let { msg ->
                        Text(
                            text = msg,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            textAlign = TextAlign.Center,
                            modifier = Modifier.fillMaxWidth().padding(top = 4.dp)
                        )
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


internal fun shareNotebookPackage(
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



internal fun runFolderSync(activity: ComponentActivity, session: PadnoteSession?): String {
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
internal fun runBackupToUri(activity: ComponentActivity, uri: android.net.Uri): String {
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
internal fun runRestore(activity: ComponentActivity, uri: android.net.Uri): String {
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



private fun runImportNote(context: Context, uri: android.net.Uri, deviceId: UInt): NotebookLibrary.Entry? = runCatching {
    // profile-scope: device 匯入的暫存檔
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
            "Android · Kairumo",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        status.forEach { (label, value) ->
            Text(
                "$label: $value",
                style = MaterialTheme.typography.bodyMedium,
                fontFamily = FontFamily.Monospace
            )
        }
    }
}

