package com.kairumo.padnote.library

import android.content.Context
import androidx.documentfile.provider.DocumentFile
import com.kairumo.padnote.sync.FolderSync
import java.io.File
import uniffi.padnote_core.FfiMilestone
import uniffi.padnote_core.PadnoteSession

/**
 * 這台裝置上的所有筆記本（Android）。
 *
 * # 為什麼需要它
 *
 * Android 原本只認一本固定檔名的 `notebook.padnote`。後果是跨平台同步**做不完**：
 * iPad 那邊每一本筆記是一個以 id 命名的套件，同步下來之後 Android 根本不會去開
 * 它們 —— 檔案就躺在資料夾裡，畫面上什麼也沒有。使用者看到的是「同步成功，
 * 但筆記沒出現」。
 *
 * 所以這裡把筆記本當成**一個目錄下的多個套件**，跟 Apple 端同一個模型。
 */
object NotebookLibrary {

    private const val DIRECTORY = "Notebooks"
    private const val LEGACY_NAME = "notebook.padnote"
    const val EXTENSION = "padnote"

    /**
     * `folderId` 的「不分層，全部列出來」哨兵值。
     *
     * 不能用 null 表示 —— null 已經是「最上層」的意思。兩者混在一起的話，
     * 搜尋（要搜全部）與瀏覽最上層（只要根目錄那幾本）會變成同一件事。
     */
    val ANY_FOLDER: String = "\u0000any"

    /** 一本筆記本。 */
    data class Entry(
        val id: String,
        val title: String,
        val pageCount: Int,
        val path: File,
        /** 最後修改時間（毫秒）。首頁要依此排序與顯示「最近」。 */
        val modifiedAt: Long = 0L
    )

    /** 清單排序方式。與 Apple 端的「全部筆記」排序選單同一組。 */
    enum class Sort { MODIFIED, TITLE, PAGES }

    /** 套件目錄。第一次呼叫時會把舊版那本單一筆記搬進來。 */
    fun directory(context: Context): File {
        val dir = File(context.filesDir, DIRECTORY)
        if (!dir.exists()) dir.mkdirs()
        migrateLegacyNotebook(context, dir)
        return dir
    }

    /**
     * 把舊版的 `filesDir/notebook.padnote` 搬進套件目錄。
     *
     * 搬而不是複製一份：留兩份的話，使用者在新位置寫的東西同步得出去，
     * 而他以為自己在看的那本（舊位置）永遠不會更新。
     *
     * 搬不動時保持原狀而不是刪掉 —— 那是使用者唯一的一份資料。
     */
    private fun migrateLegacyNotebook(context: Context, dir: File) {
        val legacy = File(context.filesDir, LEGACY_NAME)
        if (!legacy.exists()) return
        val target = File(dir, LEGACY_NAME)
        if (target.exists()) return
        runCatching { legacy.renameTo(target) }
    }

    /** 所有筆記本，依標題排序。開不起來的套件會被跳過，不會讓整份清單失敗。 */
    fun all(
        context: Context,
        deviceId: UInt,
        sort: Sort = Sort.MODIFIED,
        /** 只列這個資料夾底下的。null 表示最上層；傳 [ANY_FOLDER] 表示不分層全部列。 */
        folderId: String? = ANY_FOLDER
    ): List<Entry> {
        val entries = directory(context).listFiles()
            ?.filter { it.isDirectory && it.name.endsWith(".$EXTENSION") }
            ?.mapNotNull { describe(it, deviceId) }
            // 另一台裝置刪掉的不要列出來。檔案這時可能還在本機硬碟上
            // （真正的清除是同步引擎的事），但它已經被刪了 ——
            // 還列出來的話，使用者在 A 上刪掉、走到 B 前面又看到它。
            //
            // 用 `isHidden` 而不是 `isDeleted`：後者只看自己那一筆，
            // 刪掉一個資料夾之後，裡面的筆記本仍然會被列出來。
            ?.filter { !AccountSyncStore.isHidden(context, it.id) }
            ?.filter { folderId == ANY_FOLDER || FolderTree.parentOf(context, it.id) == folderId }
            ?: return emptyList()
        return when (sort) {
            // 最近修改排前面 —— 使用者要找的十之八九是剛剛在寫的那本。
            Sort.MODIFIED -> entries.sortedByDescending { it.modifiedAt }
            Sort.TITLE -> entries.sortedBy { it.title }
            Sort.PAGES -> entries.sortedByDescending { it.pageCount }
        }
    }

    private fun describe(path: File, deviceId: UInt): Entry? {
        val session = runCatching { PadnoteSession.openExisting(path.absolutePath, deviceId) }
            .getOrNull() ?: return null
        return Entry(
            id = path.nameWithoutExtension,
            title = runCatching { session.title() }.getOrDefault(path.nameWithoutExtension),
            pageCount = runCatching { session.pageCount().toInt() }.getOrDefault(0),
            path = path,
            // 取套件裡最新的那個檔案。目錄本身的 mtime 在某些檔案系統上
            // 不會隨內容更新，拿它排序會得到一個永遠不動的清單。
            modifiedAt = path.walkTopDown().filter { it.isFile }
                .maxOfOrNull { it.lastModified() } ?: path.lastModified()
        )
    }

    /** 改標題。改的是套件裡的標題，不是檔名 —— 檔名是 id，換掉會斷掉同步。 */
    fun rename(context: Context, id: String, title: String, deviceId: UInt): Boolean =
        runCatching {
            val path = File(directory(context), "$id.$EXTENSION")
            if (!path.exists()) return false
            val session = PadnoteSession.openExisting(path.absolutePath, deviceId)
            session.setTitle(title)
            // 記進同步索引。改名**不能**靠「刪掉舊的再加一個」表示 ——
            // 那在合併時與真正的刪除完全一樣，另一台裝置會把它當成已刪除。
            // 保住原本所在的資料夾。不帶 parentId 的話，改個名字
            // 就會被搬回最上層 —— 而使用者完全不知道為什麼。
            AccountSyncStore.record(
                context, id = id, title = title, parentId = FolderTree.parentOf(context, id)
            )
            true
        }.getOrDefault(false)

    // ---- 里程碑快照（時光機，工作項 S-99）----
    //
    // 三支都只是把 session 的取得集中在一處。Android 的套件就是**唯一**的
    // 真相來源，所以還原一步到位 —— 不像 Apple 還要先把工作副本鏡進套件。

    /** 這本筆記的全部里程碑，新的在前。開不了套件時回空清單。 */
    fun milestones(context: Context, id: String, deviceId: UInt): List<FfiMilestone> =
        runCatching {
            val path = File(directory(context), "$id.$EXTENSION")
            PadnoteSession.openExisting(path.absolutePath, deviceId).milestones()
        }.getOrDefault(emptyList())

    /** 在現在這一刻插一個名字。 */
    fun createMilestone(
        context: Context, id: String, deviceId: UInt, title: String, creator: String
    ): FfiMilestone? = runCatching {
        val path = File(directory(context), "$id.$EXTENSION")
        PadnoteSession.openExisting(path.absolutePath, deviceId)
            .createMilestone(title, creator, System.currentTimeMillis().toULong())
    }.getOrNull()

    /**
     * 還原到某個里程碑，回傳「還原之前」那一刻的自動里程碑。
     *
     * `safetyTitle` 由呼叫端給（要在地化）。回傳的那一個一定要顯示出來 ——
     * 還原到它就等於取消這次還原，使用者不知道有這條路的話，會以為
     * 剛才那半小時的東西沒了。
     */
    fun restoreMilestone(
        context: Context, id: String, deviceId: UInt, milestoneId: String, safetyTitle: String
    ): FfiMilestone? = runCatching {
        val path = File(directory(context), "$id.$EXTENSION")
        PadnoteSession.openExisting(path.absolutePath, deviceId)
            .restoreMilestone(milestoneId, System.currentTimeMillis().toULong(), safetyTitle)
    }.getOrNull()

    /**
     * 刪除一本筆記本。
     *
     * 真的刪掉整個套件目錄。**沒有回收桶** —— 呼叫端一定要先跟使用者確認，
     * 這是使用者唯一的一份資料。
     */
    fun delete(context: Context, id: String): Boolean =
        runCatching {
            val removed = File(directory(context), "$id.$EXTENSION").deleteRecursively()
            // **留墓碑。** 不留的話，等雲端接上，另一台還沒同步到刪除的裝置
            // 會把這本筆記原封不動傳回來 —— 刪除永遠刪不掉。
            if (removed) AccountSyncStore.recordDeletion(context, id)
            removed
        }.getOrDefault(false)

    /** 開啟（或建立）一本筆記本，回傳 session 與第一頁。 */
    fun open(
        context: Context,
        id: String,
        deviceId: UInt,
        title: String = "Kairumo",
        style: uniffi.padnote_core.PageStyle = uniffi.padnote_core.PageStyle.BLANK
    ): Pair<PadnoteSession, String>? = runCatching {
        val path = File(directory(context), "$id.$EXTENSION")
        val session = if (path.exists()) {
            PadnoteSession.openExisting(path.absolutePath, deviceId)
        } else {
            PadnoteSession.create(
                path.absolutePath, title, System.currentTimeMillis().toULong(), deviceId
            )
        }
        // 紙張只在**沒有任何頁**時才由這裡決定。
        //
        // 不要在這裡「順便把第一頁換成指定的紙張」—— `open()` 在一次
        // 新增筆記的流程裡會被呼叫三次，而其中兩次用的是預設的 BLANK。
        // 那樣寫的結果是：第一次正確設成康乃爾，第二次又被換回空白。
        // 換紙張是**建立**那一刻的事，所以它在 `create()` 裡。
        val page = session.firstPageId() ?: session.addPage(style)
        session to page
    }.getOrNull()

    /** 這一頁是不是完全空的。換掉第一頁之前一定要確認。 */

    /** 從外部 .padnote 封裝壓縮檔匯入整本筆記本。 */
    fun importArchive(context: Context, archiveFile: File, deviceId: UInt): Entry? = runCatching {
        val tempDir = File(context.cacheDir, "import_${System.currentTimeMillis()}")
        tempDir.mkdirs()
        try {
            uniffi.padnote_core.extractNotebook(archiveFile.absolutePath, tempDir.absolutePath)
            val manifestFile = File(tempDir, "manifest.json")
            val id = if (manifestFile.exists()) {
                runCatching {
                    org.json.JSONObject(manifestFile.readText()).getString("notebook_id")
                }.getOrNull() ?: java.util.UUID.randomUUID().toString()
            } else {
                java.util.UUID.randomUUID().toString()
            }

            var targetDir = File(directory(context), "$id.$EXTENSION")
            if (targetDir.exists()) {
                val uniqueId = "$id-${java.util.UUID.randomUUID().toString().take(6)}"
                targetDir = File(directory(context), "$uniqueId.$EXTENSION")
            }
            targetDir.mkdirs()
            tempDir.copyRecursively(targetDir, overwrite = true)

            describe(targetDir, deviceId)?.also { entry ->
                AccountSyncStore.record(context, id = entry.id, title = entry.title, parentId = null)
            }
        } finally {
            tempDir.deleteRecursively()
        }
    }.getOrNull()

    /**
     * 建立一本新筆記本，回傳它的 id。
     *
     * `folderId` 是它要放進哪個資料夾；null 表示最上層。建在使用者當下
     * 看著的那一層 —— 一律建在最上層的話，人在某個資料夾裡按「新增」，
     * 東西卻出現在別的地方。
     */
    fun create(
        context: Context,
        title: String,
        deviceId: UInt,
        folderId: String? = null,
        style: uniffi.padnote_core.PageStyle = uniffi.padnote_core.PageStyle.BLANK,
        /**
         * 這本筆記用的紙張 id。
         *
         * 底紋（`style`）只有六種，而紙張有三十幾種 —— 康乃爾與四象限的
         * 底紋都是 BLANK，差別在**版面**。不記下 id 的話，重開這本筆記時
         * 版面會消失，而使用者沒有做過任何事。
         */
        paperId: String = "",
        /** 版面配色的 id（核心 `guidePalettes()`）。空字串用預設那一組。 */
        paletteId: String = ""
    ): String? {
        val id = java.util.UUID.randomUUID().toString()
        val opened = open(context, id, deviceId, title, style = style) ?: return null

        // **核心建立筆記本時已經先放了一頁 `Lined`。**
        //
        // 所以 `open()` 裡的 `firstPageId() ?: addPage(style)` 永遠走前半段，
        // 使用者挑的紙張被完全忽略 —— 每一本都是橫線紙。實機上看得出來：
        // 選了康乃爾，畫面上卻是滿版的橫線。
        //
        // 核心沒有「改既有頁面底紋」的操作（那是一筆會進 oplog 的格式變更，
        // 不為了這件事開這個口子），但**先加一頁、再刪掉原本那頁**用的是
        // 既有的兩個操作，而且順序上不會出現零頁的中間狀態。
        //
        // 只在這裡做：這一刻筆記本必定是空的，不可能刪到使用者的內容。
        val (session, firstPage) = opened
        runCatching {
            if (session.pageStyle(firstPage) != style && session.pageCount() == 1u) {
                session.addPage(style)
                session.removePage(firstPage)
            }
        }
        if (paperId.isNotEmpty() || paletteId.isNotEmpty()) {
            val meta = NotebookMeta.load(session)
            if (paperId.isNotEmpty()) meta.setPaperId(session, paperId)
            if (paletteId.isNotEmpty()) meta.setPaletteId(session, paletteId)
        }
        AccountSyncStore.record(context, id = id, title = title, parentId = folderId)
        return id
    }

    /**
     * 「錄音收件匣」筆記本，不存在就建立。回傳它的 id。
     *
     * # 為什麼首頁的快速錄音需要它
     *
     * 錄音**必須住在某個套件裡** —— 套件才是同步的單位。使用者在首頁
     * 直接按錄音時沒有指定筆記本，總要有個地方放。
     *
     * 舊版是落在 `entries.firstOrNull()`（清單上的第一本），那等於把錄音
     * 塞進一本完全不相干的筆記；沒有筆記時又另外建一本，於是清單會被
     * 錄音洗版。
     *
     * id 由核心給（`recordingInboxNotebookId()`），**兩個平台共用同一個值**：
     * 兩台裝置各自建立的收件匣會收斂成同一本，內容由 CRDT 合併。
     * 各取各的話，使用者會看到「錄音收件匣」「錄音收件匣 2」。
     */
    fun recordingInbox(context: Context, deviceId: UInt, title: String): String? {
        val id = uniffi.padnote_core.recordingInboxNotebookId()
        val path = File(directory(context), "$id.$EXTENSION")
        if (!path.exists()) {
            open(context, id, deviceId, title) ?: return null
            AccountSyncStore.record(context, id = id, title = title, parentId = null)
        }
        return id
    }

    /**
     * 這台裝置要開的那一本。
     *
     * 沒有任何筆記本時建一本 —— 打開 App 看到空畫面，使用者不會知道下一步該做什麼。
     */
    fun currentOrCreate(context: Context, deviceId: UInt): String? =
        all(context, deviceId).firstOrNull()?.id
            ?: create(context, "Kairumo", deviceId)

    /**
     * 把同步資料夾裡本機還沒有的筆記本整包抓下來。
     *
     * 少了這一步，另一台裝置**新建**的筆記本永遠不會出現：`FolderSync.sync` 只
     * 對齊「本機已經有的那些套件」，沒見過的它不會主動去拿。
     *
     * @return 新抓下來的筆記本數。
     */
    fun pullNewNotebooks(context: Context, remoteRoot: DocumentFile, languageTag: String): Int {
        val dir = directory(context)
        var pulled = 0
        for (remote in remoteRoot.listFiles()) {
            val name = remote.name ?: continue
            if (!remote.isDirectory || !name.endsWith(".$EXTENSION")) continue
            val local = File(dir, name)
            if (local.exists()) continue
            val result = FolderSync.sync(context, local, remoteRoot, languageTag)
            if (result.downloaded.isNotEmpty()) pulled++
        }
        return pulled
    }

    /** 把每一本都與同步資料夾對齊。 */
    fun syncAll(context: Context, remoteRoot: DocumentFile, languageTag: String): FolderSync.Result {
        var merged = FolderSync.Result()
        for (path in directory(context).listFiles().orEmpty()) {
            if (!path.isDirectory || !path.name.endsWith(".$EXTENSION")) continue
            val result = FolderSync.sync(context, path, remoteRoot, languageTag)
            merged = FolderSync.Result(
                uploaded = merged.uploaded + result.uploaded,
                downloaded = merged.downloaded + result.downloaded,
                needsAttention = merged.needsAttention + result.needsAttention,
                failures = merged.failures + result.failures
            )
        }
        return merged
    }
}
