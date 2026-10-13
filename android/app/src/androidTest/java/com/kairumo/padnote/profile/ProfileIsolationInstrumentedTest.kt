package com.kairumo.padnote.profile

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.kairumo.padnote.library.AccountSyncStore
import com.kairumo.padnote.library.NotebookLibrary
import com.kairumo.padnote.oauth.GoogleAuth
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.util.UUID

/**
 * **真的裝置上的** A→B→A 隔離測試（Android）。
 *
 * JVM 單元測試只能驗規則；這裡用真的 `Context`、真的檔案系統、真的 `NotebookLibrary`、
 * 加密偏好與 `AccountSyncStore`：切到另一個設定檔、在裡面建筆記本與寫偏好、切回來，
 * 比對兩邊沒有互相滲透。切換在正式環境是「重啟行程」，這裡不重啟（會把測試本身殺掉），
 * 而是直接改 `ProfileContext` —— 所有狀態都是取用當下才問「現在是誰」，所以效果相同。
 */
@RunWith(AndroidJUnit4::class)
class ProfileIsolationInstrumentedTest {
    private val context = InstrumentationRegistry.getInstrumentation().targetContext
    private val profileB = "itest-" + UUID.randomUUID().toString().lowercase()
    private lateinit var original: String

    @Before
    fun setUp() {
        original = ProfileContext.activeId(context)
        ProfileContext.setActive(context, ProfileRecord.DEFAULT_ID)
    }

    @After
    fun tearDown() {
        // 把臨時設定檔整個清掉，並回到原本的設定檔。
        ProfileContext.ownedDirectories(context, profileB).forEach { it.deleteRecursively() }
        ProfileContext.ownedPrefsNames(context, profileB).forEach { context.deleteSharedPreferences(it) }
        ProfileContext.setActive(context, original)
    }

    private fun ids() = NotebookLibrary.all(context, 1u).map { it.id }.sorted()

    @Test
    fun twoProfilesDoNotLeakIntoEachOtherAndTheOriginalComesBackIntact() {
        // ── A（預設設定檔）：記下現況。
        val aDir = NotebookLibrary.directory(context)
        val aIds = ids()
        val aSyncDevice = AccountSyncStore.deviceId(context)
        val aIsSignedIn = GoogleAuth.isSignedIn(context)
        ProfileContext.prefs(context, "kairumo").edit().putString("itest.marker", "a-only").commit()

        // ── 切到 B。
        ProfileContext.setActive(context, profileB)
        val bDir = NotebookLibrary.directory(context)
        assertNotEquals(aDir, bDir)
        assertTrue("B 在 app_profiles/ 底下，不在 files/ 底下", bDir.path.contains("/app_profiles/$profileB/"))
        assertFalse("預設設定檔的 files/ 不能包含別人的設定檔", bDir.path.startsWith(context.filesDir.path + "/"))
        assertTrue("B 是全新的：沒有 A 的任何筆記本", ids().isEmpty())
        assertNotEquals("每個設定檔是同步協定裡獨立的一台裝置", aSyncDevice, AccountSyncStore.deviceId(context))
        assertNull("A 的偏好不能出現在 B", ProfileContext.prefs(context, "kairumo").getString("itest.marker", null))
        if (aIsSignedIn) assertFalse("A 的 Google 登入不能在 B 裡", GoogleAuth.isSignedIn(context))

        // ── 在 B 裡寫東西。
        val created = NotebookLibrary.create(context, "只屬於B", 2u)
        assertNotNull(created)
        assertEquals(listOf(created!!), ids())
        ProfileContext.prefs(context, "kairumo").edit().putString("itest.marker", "b-only").commit()

        // ── 切回 A。
        ProfileContext.setActive(context, ProfileRecord.DEFAULT_ID)
        assertEquals("切了一圈回來，A 必須和原本完全一樣", aIds, ids())
        assertFalse("B 的筆記本不能出現在 A", ids().contains(created))
        assertEquals(aDir, NotebookLibrary.directory(context))
        assertEquals("a-only", ProfileContext.prefs(context, "kairumo").getString("itest.marker", null))
        assertEquals(aSyncDevice, AccountSyncStore.deviceId(context))
        assertEquals(aIsSignedIn, GoogleAuth.isSignedIn(context))

        // ── 再切到 B：它寫的東西還在（真的落了盤）。
        ProfileContext.setActive(context, profileB)
        assertEquals(listOf(created), ids())
        assertEquals("b-only", ProfileContext.prefs(context, "kairumo").getString("itest.marker", null))

        // 清掉 A 這邊的標記，不留痕跡。
        ProfileContext.setActive(context, ProfileRecord.DEFAULT_ID)
        ProfileContext.prefs(context, "kairumo").edit().remove("itest.marker").commit()
    }

    @Test
    fun deletingAProfileRemovesItsDirectoriesAndPrefsButNotTheDefaultOnes() {
        val aIds = ids()
        ProfileContext.setActive(context, profileB)
        NotebookLibrary.create(context, "會被刪掉", 2u)
        ProfileContext.prefs(context, "kairumo").edit().putString("k", "v").commit()
        val bDirs = ProfileContext.ownedDirectories(context, profileB)
        assertTrue(bDirs.any { it.exists() })
        assertTrue(ProfileContext.ownedPrefsNames(context, profileB).isNotEmpty())

        ProfileContext.setActive(context, ProfileRecord.DEFAULT_ID)
        bDirs.forEach(File::deleteRecursively)
        ProfileContext.ownedPrefsNames(context, profileB).forEach { context.deleteSharedPreferences(it) }

        assertTrue(bDirs.none { it.exists() })
        assertTrue(ProfileContext.ownedPrefsNames(context, profileB).isEmpty())
        assertEquals("刪設定檔不能動到預設設定檔", aIds, ids())
        assertTrue("預設設定檔不回報任何自己擁有的目錄", ProfileContext.ownedDirectories(context, ProfileRecord.DEFAULT_ID).isEmpty())
    }
}
