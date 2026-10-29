package com.kairumo.padnote.library

import android.content.Context
import com.kairumo.padnote.ink.InkPackageWriter
import com.kairumo.padnote.profile.ProfileContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import org.json.JSONObject
import uniffi.padnote_core.PadnoteSession
import java.io.File
import java.text.DateFormat
import java.util.Date
import java.util.UUID

/**
 * 範例筆記本：編輯先放暫存區，離開時再決定。與 Apple `NotebookStore.beginSampleSession` 同一套規則。
 *
 * 被設為「範例」的筆記本（內建範例預設是，任何一本都能設定／解除，見 [isSample]）打開之後，所有操作照常
 * 進行，但**不提示、不同步**：開啟那一刻的整個套件先複製到暫存區（`SampleSessions/<id>/package`）。
 * 使用者離開時，若內容真的有變，再問要「存檔（保留在此範例）」、「另存可編輯副本」或「放棄修改」（[finish]）。
 *
 * App 被關掉時沒辦法問：暫存區留在磁碟上，下次回到首頁再問（[pendingIds]）。
 * 「有沒有變」只比內容摘要（[sessionSignature]：頁面、筆畫與物件、位置、外觀、文字、紙張與圖層設定），
 * 系統自己寫的東西（修改時間、手寫辨識結果…）不算。
 */
// profile-scope: device 只有「清單要重讀」的計數；暫存區本身在設定檔的資料目錄底下（ProfileContext.dataDir）
object SampleFork {

    /** 範例的改動要怎麼處理。 */
    enum class Choice {
        /** 改動留在這本範例裡。 */
        KEEP,
        /** 改動另存成一本一般筆記本，範例回到打開前的樣子。 */
        SAVE_COPY,
        /** 改動丟掉，範例回到打開前的樣子。 */
        DISCARD
    }

    /** 範例另存或還原之後的次數。首頁據此重讀清單。 */
    private val _forks = MutableStateFlow(0)
    val forks: StateFlow<Int> = _forks
    fun noteForked() { _forks.value += 1 }

    /** 這本是不是「範例」：使用者設定過就照設定，沒設定過的話內建範例是、其他不是。 */
    fun isSample(context: Context, id: String, deviceId: UInt): Boolean {
        val dir = packageDir(context, id)
        if (!dir.isDirectory) return false
        val flag = runCatching {
            PadnoteSession.openExisting(dir.absolutePath, deviceId).use { NotebookMeta.load(it).isSample() }
        }.getOrNull()
        return flag ?: SeedNotebooks.isDeviceLocal(id)
    }

    /** 設定或解除「範例」。解除之後就是一般筆記本（照常編輯、照常同步）。 */
    fun setSample(context: Context, id: String, deviceId: UInt, isSample: Boolean) {
        if (!isSample && hasSession(context, id)) finish(context, id, deviceId, "", Choice.KEEP)
        runCatching {
            PadnoteSession.openExisting(packageDir(context, id).absolutePath, deviceId).use {
                NotebookMeta.load(it).setSample(it, isSample)
            }
        }
        NotebookLibrary.invalidateCache(id)
    }

    private fun sessionsRoot(context: Context) = File(ProfileContext.dataDir(context), "SampleSessions")
    private fun sessionDir(context: Context, id: String) = File(sessionsRoot(context), id.lowercase())

    /** 這本是不是正在範例暫存期間（打開了、還沒決定怎麼處理改動）。暫存期間不同步。 */
    fun hasSession(context: Context, id: String): Boolean =
        File(sessionDir(context, id), "signature").isFile

    /** 還沒決定怎麼處理的範例暫存（例如 App 在範例開著時被關掉）。 */
    fun pendingIds(context: Context): List<String> =
        sessionsRoot(context).listFiles()?.filter { File(it, "signature").isFile }
            ?.map { it.name }?.filter { packageDir(context, it).isDirectory } ?: emptyList()

    /** 打開範例時：把整個套件複製到暫存區。已經有暫存（上次還沒決定）就沿用，不覆蓋。在背景執行緒呼叫。 */
    fun begin(context: Context, id: String, deviceId: UInt) {
        if (hasSession(context, id) || !isSample(context, id, deviceId)) return
        val dir = sessionDir(context, id)
        dir.deleteRecursively()
        val ok = runCatching {
            packageDir(context, id).copyRecursively(File(dir, "package"), overwrite = true)
            // signature 最後寫：它在不在就代表暫存是否完整（[hasSession]）。
            File(dir, "signature").writeText(sessionSignature(packageDir(context, id), deviceId).orEmpty())
        }.isSuccess
        if (!ok) dir.deleteRecursively()
    }

    /** 打開之後內容有沒有真的改過。等筆跡寫完再比。在背景執行緒呼叫。 */
    fun hasChanges(context: Context, id: String, deviceId: UInt): Boolean {
        if (!hasSession(context, id)) return false
        InkPackageWriter.awaitIdleBlocking(10_000L)
        val before = runCatching { File(sessionDir(context, id), "signature").readText() }.getOrNull() ?: return false
        val now = sessionSignature(packageDir(context, id), deviceId) ?: return true
        return before != now
    }

    /** 照使用者的選擇處理範例的改動，結束暫存。選「另存可編輯副本」時回傳新那一本的（id, 名字）。在背景執行緒呼叫。 */
    fun finish(context: Context, id: String, deviceId: UInt, languageTag: String, choice: Choice): Pair<String, String>? {
        if (!hasSession(context, id)) return null
        InkPackageWriter.awaitIdleBlocking(10_000L)
        val dir = sessionDir(context, id)
        var copy: Pair<String, String>? = null
        when (choice) {
            Choice.KEEP -> Unit
            Choice.DISCARD -> restoreSession(context, id)
            Choice.SAVE_COPY -> {
                copy = copy(context, id, deviceId, languageTag)
                restoreSession(context, id)
            }
        }
        dir.deleteRecursively()
        NotebookLibrary.invalidateCache(id)
        noteForked()
        return copy
    }

    /** 把範例放回打開前的樣子：用暫存區的套件換掉現在的。 */
    private fun restoreSession(context: Context, id: String) {
        val saved = File(sessionDir(context, id), "package")
        if (!saved.isDirectory) return
        val live = packageDir(context, id)
        val trash = File(live.parentFile, "${live.name}.restoring")
        trash.deleteRecursively()
        // 先搬開再放回：複製途中失敗時，現在的內容還在 trash 裡，不會兩邊都沒有。
        if (live.exists() && !live.renameTo(trash)) return
        if (runCatching { saved.copyRecursively(live, overwrite = true) }.isSuccess) {
            trash.deleteRecursively()
        } else {
            live.deleteRecursively()
            trash.renameTo(live)
        }
    }

    /**
     * 更新程式或修復時重設範例：範例裡若有使用者的內容，先另存成一般筆記本，範例才重設。
     * 跟標準內容一樣（使用者沒動過）的就不另存。只動範例自己，使用者的筆記本與資料夾一律不碰。
     *
     * 做法是把整個範例套件**搬**到一個新 id 底下（不是刪掉），重建標準範例，再比對兩者的內容摘要 ——
     * 一樣就丟掉搬走的那份，不一樣就把它變成一本一般筆記本。任何一步失敗，使用者的內容都還在。
     */
    fun restorePreservingUserContent(context: Context, id: String, deviceId: UInt, languageTag: String) {
        val source = packageDir(context, id)
        if (!source.isDirectory) return
        val newId = UUID.randomUUID().toString().lowercase()
        val moved = packageDir(context, newId)
        if (!source.renameTo(moved)) {
            if (!runCatching { source.copyRecursively(moved, overwrite = false) }.getOrDefault(false)) {
                moved.deleteRecursively()
                return // 搬不走就不重設：寧可範例不乾淨，也不冒險清掉使用者的內容
            }
            source.deleteRecursively()
        }
        NotebookLibrary.invalidateCache(id)
        fun l(key: String) = com.kairumo.padnote.LocalizationStrings.localized(key, languageTag)
        SeedNotebooks.build(context, id.lowercase(), deviceId, languageTag, ::l)
        NotebookLibrary.invalidateCache(id)
        val hasAudio = (File(moved, "media/audio").listFiles()?.isNotEmpty()) == true
        val before = contentSignature(moved, deviceId)
        val standard = contentSignature(packageDir(context, id), deviceId)
        // 讀不出來（null）一律當成「有使用者的內容」留著。
        if (!hasAudio && before != null && before == standard) {
            moved.deleteRecursively()
        } else {
            adopt(context, newId, deviceId, languageTag)
        }
    }

    /** 比對「有沒有使用者的內容」用的摘要：頁數、每頁的筆畫／物件數、所有文字。物件 id 每次產生都不同，只比內容。 */
    internal fun contentSignature(dir: File, deviceId: UInt): String? = runCatching {
        PadnoteSession.openExisting(dir.absolutePath, deviceId).use { session ->
            val parts = mutableListOf("pages:${session.pageCount()}")
            for (index in 0u until session.pageCount()) {
                val page = session.pageIdAt(index) ?: continue
                val texts = session.textBlockIds(page).map { session.blockText(it).orEmpty() }.sorted()
                parts += "p$index:${session.visibleStrokes(page).size}:${session.drawOrder(page).size}:${session.tableBlockIds(page).size}:" +
                    "${session.imageBlockIds(page).size}:" + texts.joinToString("\u001F")
            }
            parts.joinToString("|")
        }
    }.getOrNull()

    /**
     * 範例暫存期間比對「有沒有改」用的摘要。同一個套件裡物件的 id 是穩定的，所以逐一比 id、位置、
     * 變換、外觀與文字 —— 移動、改色、改字、加減筆畫都算。中繼資料只比使用者會改的部分：
     * 修改時間、手寫辨識結果、頁面 id 這些系統自己寫的不算（只是瀏覽就會被寫入）。
     */
    private fun sessionSignature(dir: File, deviceId: UInt): String? = runCatching {
        PadnoteSession.openExisting(dir.absolutePath, deviceId).use { session ->
            val parts = mutableListOf("pages:${session.pageCount()}")
            for (index in 0u until session.pageCount()) {
                val page = session.pageIdAt(index) ?: continue
                val strokes = session.visibleStrokes(page).map {
                    "${it.id}@${it.bounds.joinToString(" ")}"
                }.sorted()
                parts += "p$index:strokes:" + strokes.joinToString(",")
                parts += "p$index:shapes:" + session.drawOrder(page).joinToString(",") {
                    it.objectId + "@" + it.transform.joinToString(" ")
                }
                val blocks = session.textBlockIds(page) + session.imageBlockIds(page) + session.tableBlockIds(page)
                parts += blocks.sorted().joinToString(";") { id ->
                    "$id=${session.blockText(id).orEmpty()}@${session.blockPosition(id)}#${session.blockAppearance(id).orEmpty()}"
                }
            }
            val meta = runCatching { JSONObject(session.notebookMeta() ?: "{}") }.getOrDefault(JSONObject())
            val volatile = setOf("lastModifiedDate", "recognizedText", "objectEnvelopes", "pageIds", "createdAt")
            parts += meta.keys().asSequence().filter { it !in volatile }.sorted()
                .joinToString(";") { "$it=${meta.get(it)}" }
            parts.joinToString("|")
        }
    }.getOrNull()

    /** 由範例另存出來的筆記本名稱：「範例名 日期 時:分:秒」。 */
    fun copyTitle(base: String, at: Date = Date()): String =
        "$base ${DateFormat.getDateTimeInstance(DateFormat.SHORT, DateFormat.MEDIUM).format(at)}"

    private fun packageDir(context: Context, id: String) =
        File(NotebookLibrary.directory(context), "$id.${NotebookLibrary.EXTENSION}")

    /** 整個套件複製一份、換新的 id 與名字。 */
    private fun copy(context: Context, id: String, deviceId: UInt, languageTag: String): Pair<String, String>? {
        val source = packageDir(context, id)
        if (!source.isDirectory) return null
        val newId = UUID.randomUUID().toString().lowercase()
        val target = packageDir(context, newId)
        if (!runCatching { source.copyRecursively(target, overwrite = false) }.getOrDefault(false)) {
            target.deleteRecursively()
            return null
        }
        return adopt(context, newId, deviceId, languageTag)
    }

    /** 一份範例套件（已放在 `newId` 底下）正式成為一般筆記本：換 id 與名字、歸納於未分類筆記（最上層）、記進同步索引。 */
    private fun adopt(context: Context, newId: String, deviceId: UInt, languageTag: String): Pair<String, String> {
        val target = packageDir(context, newId)
        // 操作（編輯）範例後生成的副本，一律歸納於「未分類筆記」（parentId = null），不直接放在該範例的資料夾中
        val parent: String? = null
        // 範例的同步狀態不帶過去；套件自己記的 id 也換掉（同步與里程碑都靠它分辨是哪一本）。
        File(target, "sync").deleteRecursively()
        File(target, "sync").mkdirs()
        runCatching {
            val manifest = File(target, "manifest.json")
            val json = JSONObject(manifest.readText())
            json.put("notebook_id", newId)
            json.put("created_at_unix_ms", System.currentTimeMillis())
            manifest.writeText(json.toString())
        }
        val base = runCatching {
            PadnoteSession.openExisting(target.absolutePath, deviceId).use { it.title() }
        }.getOrNull().orEmpty().let { SeedNotebooks.baseTitle(it, languageTag) }
        val title = copyTitle(base)
        runCatching {
            PadnoteSession.openExisting(target.absolutePath, deviceId).use {
                it.setTitle(title)
                // 另存出來的是一般筆記本：不繼承「範例」標記。
                NotebookMeta.load(it).setSample(it, false)
            }
        }
        AccountSyncStore.record(context, id = newId, title = title, parentId = parent)
        NotebookLibrary.invalidateCache(newId)
        return newId to title
    }

    // ---- 舊版「轉成一般筆記」留下的退役名單 ----

    private const val PREFS = "kairumo.seed"
    private const val KEY_RETIRED = "retired_samples"

    /**
     * 清掉退役名單。範例改成唯讀之後就轉不了了，名單卻一直留著：被轉過的那本範例從此補不回來
     * （使用者回報：Mac 永遠少一本《Kairumo(功能範例)》，Apple 端 `reinstateRetiredSamples` 同一件事）。
     * 使用者刪掉的範例另有回收桶與同步索引擋著，不靠這份名單。
     */
    fun clearRetired(context: Context) {
        val prefs = ProfileContext.prefs(context, PREFS)
        if (prefs.contains(KEY_RETIRED)) prefs.edit().remove(KEY_RETIRED).apply()
    }

    /** 測試用：寫入舊版的退役名單。 */
    internal fun retireForTesting(context: Context, id: String) {
        ProfileContext.prefs(context, PREFS).edit().putStringSet(KEY_RETIRED, setOf(id.lowercase())).apply()
    }

    internal fun retiredForTesting(context: Context): Set<String> =
        ProfileContext.prefs(context, PREFS).getStringSet(KEY_RETIRED, emptySet()) ?: emptySet()
}
