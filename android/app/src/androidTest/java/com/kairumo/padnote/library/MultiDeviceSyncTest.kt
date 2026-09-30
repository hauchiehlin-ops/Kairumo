package com.kairumo.padnote.library

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.json.JSONObject
import org.junit.After
import org.junit.Assume
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.net.HttpURLConnection
import java.net.URL

/**
 * 多裝置劇本裡 Android 那一台的步驟（與 iOS 的 `MultiDeviceUITests` 配套）。
 *
 * # 怎麼用
 *
 * 不是一般的測試：每個 `step…` 是劇本的一步，要在 iOS 的某幾步之間單獨跑
 * （`-Pandroid.testInstrumentationRunnerArguments.class=…MultiDeviceSyncTest#stepC1…`）。
 * 前置：`python3 scripts/fake-drive-server.py` 在跑；模擬器用 `10.0.2.2` 連到這台 Mac。
 *
 * # 這裡驗證什麼
 *
 * **資料層**，不走畫面：呼叫 App 自己每輪同步用的 [CloudSync.runFull]，再讀
 * [NotebookLibrary] 看筆記本清單。這正是使用者會看到的標題的來源。
 *
 * 標題存在兩個地方 —— 套件內的標題 CRDT 與同步索引 —— 而兩個平台原本各信一個：
 * Android 顯示的是 CRDT，Apple 更名只寫索引。所以 iPad 上改名之後，Android 會不會還顯示舊名字，
 * 是這組測試要回答的。
 */
@RunWith(AndroidJUnit4::class)
class MultiDeviceSyncTest {

    private val context = InstrumentationRegistry.getInstrumentation().targetContext
    private val server = "http://10.0.2.2:8765"

    @Before
    fun useTheFakeDrive() {
        // 這些是三台裝置劇本的**其中一步**，要配合假 Drive 與 iPad／iPhone 的步驟依序跑
        // （scripts/multi-device-run.sh 會帶 `-e multiDevice true`）。整套儀器測試時沒有
        // 劇本，單獨跑只會紅 —— 所以預設跳過。
        val args = InstrumentationRegistry.getArguments()
        Assume.assumeTrue("三台裝置劇本的一步：只在 multi-device-run.sh 下執行", args.getString("multiDevice") == "true")
        System.setProperty("kairumo.fakeDrive", server)
    }

    @After
    fun stopUsingIt() {
        System.clearProperty("kairumo.fakeDrive")
    }

    /** 與 App（`MainActivity.deviceId`）同一個偏好、同一個演算法，所以是「同一台裝置」。 */
    private fun deviceId(): UInt {
        val prefs = context.getSharedPreferences("kairumo", android.content.Context.MODE_PRIVATE)
        val saved = prefs.getInt("deviceId", 0)
        if (saved != 0) return saved.toUInt()
        var hash = 2_166_136_261u
        for (b in java.util.UUID.randomUUID().toString().toByteArray()) {
            hash = hash xor b.toUInt()
            hash *= 16_777_619u
        }
        prefs.edit().putInt("deviceId", hash.toInt()).apply()
        return hash
    }

    private fun cloudRead(name: String): String? {
        val url = URL("$server/_admin/read?name=" + java.net.URLEncoder.encode(name, "UTF-8"))
        val conn = url.openConnection() as HttpURLConnection
        return try {
            if (conn.responseCode == 200) conn.inputStream.bufferedReader().readText() else null
        } finally {
            conn.disconnect()
        }
    }

    /** 雲端索引裡劇本那本筆記本（標題以 `MD-` 開頭、還活著）。 */
    private fun scenarioItem(): JSONObject? {
        val index = JSONObject(cloudRead("notebooks/index.json") ?: return null).getJSONObject("items")
        for (key in index.keys()) {
            val item = index.getJSONObject(key)
            if (item.getString("title").startsWith("MD-") && !item.optBoolean("deleted", false)) return item
        }
        return null
    }

    private fun sync() {
        val result = CloudSync.runFull(context, deviceId())
        assertTrue("同步被略過或失敗：$result", !result.skipped)
    }

    private fun shownTitle(id: String): String? =
        NotebookLibrary.all(context, deviceId()).firstOrNull { it.id == id }?.title

    private fun assertShowsTheCloudTitle() {
        sync()
        val item = scenarioItem()
        assertNotNull("雲端索引裡找不到劇本的筆記本（先在 iOS 跑 step1）", item)
        val id = item!!.getString("id")
        val indexTitle = item.getString("title")
        assertEquals(
            "Android 顯示的標題與雲端索引不同 —— 另一台改名之後這台還顯示舊名字",
            indexTitle, shownTitle(id)
        )
    }

    /** C1：Android 加入，拉到劇本那本筆記本，標題與雲端索引一致。 */
    @Test
    fun stepC1_pullsTheNotebookAndShowsTheCurrentTitle() = assertShowsTheCloudTitle()

    /**
     * C1b：**這台已經有這本了，另一台（iPad）才改名。** 同步之後這台要顯示新標題，
     * 而不是還停在舊名字。這才是「標題存在兩個地方」的真正考驗 —— C1 是全新下載，
     * 一定拿得到當下的標題。
     */
    @Test
    fun stepC1b_seesTheRenameMadeElsewhere() = assertShowsTheCloudTitle()

    /** C2：Android 更名，等新標題進雲端索引。 */
    @Test
    fun stepC2_renamesIt() {
        val item = scenarioItem()
        assertNotNull(item)
        val id = item!!.getString("id")
        val renamed = item.getString("title") + "-ANDROID"
        assertTrue(NotebookLibrary.rename(context, id, renamed, deviceId()))
        sync()
        assertEquals("Android 更名之後本機沒有顯示新標題", renamed, shownTitle(id))
        val after = scenarioItem()
        assertEquals("新標題沒有進雲端索引", renamed, after?.getString("title"))
    }

    /** 雲端索引裡劇本那本筆記本的**墓碑**（標題以 `MD-` 開頭、已刪除）。 */
    private fun deletedScenarioItem(): JSONObject? {
        val index = JSONObject(cloudRead("notebooks/index.json") ?: return null).getJSONObject("items")
        for (key in index.keys()) {
            val item = index.getJSONObject(key)
            if (item.getString("title").startsWith("MD-") && item.optBoolean("deleted", false)) return item
        }
        return null
    }

    /**
     * C3：Android 同步到 iPad 的刪除，並發布確認。
     *
     * iPad 按過「永久刪除」（墓碑帶 `purgeAt`），所以墓碑對每台裝置都是**立即期滿**：
     * 這台的本機副本會在這一輪被清掉（不會停在回收桶裡），而且確認檔要追上那一筆。
     */
    @Test
    fun stepC3_syncsTheDeletionConfirmsAndPurgesItsLocalCopy() {
        sync()
        val tomb = deletedScenarioItem()
        assertNotNull("雲端索引裡找不到劇本那本的墓碑", tomb)
        val id = tomb!!.getString("id")
        val lamport = tomb.getLong("lamport")

        assertEquals("刪除之後這台的筆記本清單裡還有它", null, shownTitle(id))
        assertTrue(
            "iPad 要求了永久刪除，這台的本機副本應該已被清掉，而不是停在回收桶",
            !NotebookTrash.trashedIds(context).contains(id)
        )

        val device = AccountSyncStore.deviceId(context).lowercase()
        val ack = JSONObject(cloudRead("sync/$device/ack.json") ?: "{}")
        assertTrue(
            "這台的確認檔沒有追上刪除：seenLamport=${ack.optLong("seenLamport")} < $lamport",
            ack.optLong("seenLamport") >= lamport
        )
    }
}
