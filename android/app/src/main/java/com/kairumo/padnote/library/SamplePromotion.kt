package com.kairumo.padnote.library

import android.content.Context
import com.kairumo.padnote.ink.InkPackageWriter
import com.kairumo.padnote.profile.ProfileContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import org.json.JSONObject
import uniffi.padnote_core.PadnoteSession
import java.io.File
import java.util.UUID

/**
 * 改過的範例轉成一般（會同步的）筆記本。與 Apple 端 `NotebookStore.promoteEditedSample` 相同。
 *
 * 範例是每台裝置自己產生、不同步的（見 [SeedNotebooks.isDeviceLocal]）—— 代價是使用者在範例裡
 * 寫的東西永遠只在那一台。所以：一改過範例，它就換一個新的 id、整個套件搬過去、資料夾不變，
 * 從此跟其他筆記一樣同步；原本的範例在這台退役，不再自動補回。
 *
 * 「改過」以開啟時與關閉後的套件指紋比對（每個檔案的路徑與大小 —— 操作與筆跡都是附加寫入），
 * 只是打開看看不會轉。
 */
// profile-scope: device 開啟時的指紋只活在「開著一本範例」的那幾分鐘；切換設定檔前一定先關掉編輯器（退役名單本身存在設定檔的偏好設定裡）
object SamplePromotion {

    private const val PREFS = "kairumo.seed"
    private const val KEY_RETIRED = "retired_samples"

    private val baselines = HashMap<String, String>()

    /** 轉換完成的次數。首頁據此重讀清單。 */
    private val _promotions = MutableStateFlow(0)
    val promotions: StateFlow<Int> = _promotions

    fun retired(context: Context): Set<String> =
        ProfileContext.prefs(context, PREFS).getStringSet(KEY_RETIRED, emptySet()) ?: emptySet()

    /** 編輯器打開一本範例時記下它的樣子。 */
    fun noteOpened(context: Context, id: String) {
        if (!SeedNotebooks.isDeviceLocal(id) || baselines.containsKey(id.lowercase())) return
        baselines[id.lowercase()] = fingerprint(packageDir(context, id))
    }

    /** 編輯器關掉之後：等筆跡寫完再比對，改過就轉。在背景執行緒做。 */
    fun promoteIfEditedSoon(context: Context, id: String, deviceId: UInt) {
        val app = context.applicationContext
        val baseline = baselines.remove(id.lowercase()) ?: return
        Thread {
            InkPackageWriter.awaitIdleBlocking(10_000L)
            if (fingerprint(packageDir(app, id)) != baseline && promote(app, id, deviceId) != null) {
                _promotions.value += 1
            }
        }.start()
    }

    private fun packageDir(context: Context, id: String) =
        File(NotebookLibrary.directory(context), "$id.${NotebookLibrary.EXTENSION}")

    private fun fingerprint(dir: File): String =
        dir.walkTopDown().filter { it.isFile }
            .map { it.relativeTo(dir).path + ":" + it.length() }
            .sorted().joinToString("|")

    /** 把一本範例整個轉成一般筆記本。回傳新的 id。 */
    fun promote(context: Context, id: String, deviceId: UInt): String? {
        val source = packageDir(context, id)
        if (!source.isDirectory) return null
        val newId = UUID.randomUUID().toString().lowercase()
        val target = packageDir(context, newId)
        val parent = FolderTree.parentOf(context, id)
        if (!runCatching { source.copyRecursively(target, overwrite = false) }.getOrDefault(false)) {
            target.deleteRecursively()
            return null
        }
        // 套件自己記的 id 也換掉（同步以目錄名為準，這裡只是讓兩者一致）。
        runCatching {
            val manifest = File(target, "manifest.json")
            val json = JSONObject(manifest.readText())
            if (json.has("notebook_id")) {
                json.put("notebook_id", newId)
                manifest.writeText(json.toString())
            }
        }
        val title = runCatching {
            PadnoteSession.openExisting(target.absolutePath, deviceId).use { it.title() }
        }.getOrNull().orEmpty()
        AccountSyncStore.record(context, id = newId, title = title, parentId = parent)
        source.deleteRecursively()
        NotebookLibrary.invalidateCache(id)
        NotebookLibrary.invalidateCache(newId)
        val prefs = ProfileContext.prefs(context, PREFS)
        prefs.edit().putStringSet(KEY_RETIRED, retired(context) + id.lowercase()).apply()
        return newId
    }
}
