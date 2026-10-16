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
 * 唯讀範例：使用者一編輯，就把目前的樣子另存成一本一般的（會同步的）筆記本。
 * 與 Apple 端 `NotebookStore.forkEditedSample` 同一套規則。
 *
 * - 範例在任何安裝狀態下都保持乾淨的標準內容，清單上的名字標「（唯讀）」（[SeedNotebooks.displayTitle]）。
 * - 另存的那一本叫「範例名 日期 時:分:秒」，放在範例所在的資料夾，編輯器換到那一本繼續。
 * - 範例本身重設回標準內容（[SeedNotebooks.restore]），並提示「此範本為唯讀檔案，系統已自動增加可編輯筆記本」。
 *
 * 「改過」以開啟時與現在的套件指紋比對（每個檔案的路徑與大小 —— 操作與筆跡都是附加寫入），
 * 只是打開看看不算。
 */
// profile-scope: device 開啟時的指紋只活在「開著一本範例」的那幾分鐘；切換設定檔前一定先關掉編輯器
object SampleFork {

    private val baselines = HashMap<String, String>()

    /** 另存完成的次數。首頁據此重讀清單。 */
    private val _forks = MutableStateFlow(0)
    val forks: StateFlow<Int> = _forks
    fun noteForked() { _forks.value += 1 }

    /** 編輯器打開一本範例時記下它的樣子。 */
    fun noteOpened(context: Context, id: String) {
        if (!SeedNotebooks.isDeviceLocal(id) || baselines.containsKey(id.lowercase())) return
        baselines[id.lowercase()] = fingerprint(packageDir(context, id))
    }

    /** 打開之後有沒有被改過。 */
    fun wasEdited(context: Context, id: String): Boolean {
        val baseline = baselines[id.lowercase()] ?: return false
        return fingerprint(packageDir(context, id)) != baseline
    }

    /**
     * 等筆跡寫完，把範例目前的樣子另存成一本一般筆記本。回傳（新 id, 新名字）；沒改過或失敗回 null。
     * 範例本身**不在這裡**重設：編輯器還開著它，要等換到新的那一本之後再呼叫 [restore]。
     * 在背景執行緒呼叫。
     */
    fun forkIfEdited(context: Context, id: String, deviceId: UInt, languageTag: String): Pair<String, String>? {
        InkPackageWriter.awaitIdleBlocking(10_000L)
        if (!wasEdited(context, id)) return null
        baselines.remove(id.lowercase())
        return copy(context, id, deviceId, languageTag)
    }

    /** 編輯器已經離開範例之後：等它最後的寫入做完，再把範例重設回標準內容。在背景執行緒呼叫。 */
    fun restore(context: Context, id: String, deviceId: UInt, languageTag: String) {
        InkPackageWriter.awaitIdleBlocking(10_000L)
        SeedNotebooks.restore(context, id, deviceId, languageTag)
    }

    /** 編輯器關掉之後的後備：即時偵測沒抓到的改動也要另存，範例才不會帶著改動留下來。 */
    fun forkIfEditedSoon(context: Context, id: String, deviceId: UInt, languageTag: String, onForked: () -> Unit = {}) {
        val app = context.applicationContext
        if (!baselines.containsKey(id.lowercase())) return
        Thread {
            if (forkIfEdited(app, id, deviceId, languageTag) != null) {
                restore(app, id, deviceId, languageTag)
                noteForked()
                onForked()
            }
            baselines.remove(id.lowercase())
        }.start()
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
            adopt(context, id, newId, deviceId, languageTag)
        }
    }

    /** 比對「有沒有使用者的內容」用的摘要：頁數、每頁的筆畫／物件數、所有文字。物件 id 每次產生都不同，只比內容。 */
    internal fun contentSignature(dir: File, deviceId: UInt): String? = runCatching {
        PadnoteSession.openExisting(dir.absolutePath, deviceId).use { session ->
            val parts = mutableListOf("pages:${session.pageCount()}")
            for (index in 0u until session.pageCount()) {
                val page = session.pageIdAt(index) ?: continue
                val texts = session.textBlockIds(page).map { session.blockText(it).orEmpty() }.sorted()
                parts += "p$index:${session.drawOrder(page).size}:${session.tableBlockIds(page).size}:" +
                    "${session.imageBlockIds(page).size}:" + texts.joinToString("\u001F")
            }
            parts.joinToString("|")
        }
    }.getOrNull()

    /** 由範例另存出來的筆記本名稱：「範例名 日期 時:分:秒」。 */
    fun copyTitle(base: String, at: Date = Date()): String =
        "$base ${DateFormat.getDateTimeInstance(DateFormat.SHORT, DateFormat.MEDIUM).format(at)}"

    private fun packageDir(context: Context, id: String) =
        File(NotebookLibrary.directory(context), "$id.${NotebookLibrary.EXTENSION}")

    private fun fingerprint(dir: File): String =
        dir.walkTopDown().filter { it.isFile }
            .map { it.relativeTo(dir).path + ":" + it.length() }
            .sorted().joinToString("|")

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
        return adopt(context, id, newId, deviceId, languageTag)
    }

    /** 一份範例套件（已放在 `newId` 底下）正式成為一般筆記本：換 id 與名字、放在範例所在的資料夾、記進同步索引。 */
    private fun adopt(context: Context, sampleId: String, newId: String, deviceId: UInt, languageTag: String): Pair<String, String> {
        val target = packageDir(context, newId)
        val parent = FolderTree.parentOf(context, sampleId)
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
        runCatching { PadnoteSession.openExisting(target.absolutePath, deviceId).use { it.setTitle(title) } }
        AccountSyncStore.record(context, id = newId, title = title, parentId = parent)
        NotebookLibrary.invalidateCache(newId)
        return newId to title
    }

    // ---- 舊版「轉成一般筆記」留下的退役名單（範例改成唯讀之後不再寫入；退役的範例不補回）----

    private const val PREFS = "kairumo.seed"
    private const val KEY_RETIRED = "retired_samples"

    fun retired(context: Context): Set<String> =
        ProfileContext.prefs(context, PREFS).getStringSet(KEY_RETIRED, emptySet()) ?: emptySet()
}
