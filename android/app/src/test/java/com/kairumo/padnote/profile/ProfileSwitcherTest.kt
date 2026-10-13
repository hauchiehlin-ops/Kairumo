package com.kairumo.padnote.profile

import android.app.Activity
import android.content.Context
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * 設定檔名單與切換器（Android）。
 *
 * 切換是「寫名單 → 改 context → 重啟行程」，順序與失敗路徑都在這裡驗：
 * 名單寫不進去就整個放棄、什麼都不能變，也不能重啟（重啟之後使用者會落在一個不一致的狀態）。
 */
class ProfileSwitcherTest {
    private lateinit var activity: FakeActivity
    private val calls = mutableListOf<String>()

    @Before
    fun setUp() {
        activity = FakeActivity()
        ProfileManager.resetCacheForTesting()
        ProfileContext.resetCacheForTesting()
    }

    private fun hooks(saveSucceeds: Boolean = true) = object : ProfileSwitcher.Hooks {
        override suspend fun flushPending(context: Context) { calls += "flush" }
        override fun saveRegistry(context: Context, registry: ProfileRegistry): Boolean {
            calls += "save:${registry.activeId}"
            return saveSucceeds && ProfileManager.save(context, registry)
        }
        override fun setActive(context: Context, id: String) {
            calls += "setActive:$id"
            ProfileContext.setActive(context, id)
        }
        override fun restart(activity: Activity) { calls += "restart" }
    }

    private fun registryWithOther(): ProfileRecord {
        val registry = ProfileManager.registry(activity)
        val other = registry.add("別人")
        ProfileManager.save(activity, registry)
        return other
    }

    @Test
    fun firstUseCreatesOnlyTheDefaultProfileAndKeepsContextConsistent() {
        val registry = ProfileManager.registry(activity)
        assertEquals(1, registry.profiles.size)
        assertEquals(ProfileRecord.DEFAULT_ID, registry.activeId)
        assertEquals(ProfileRecord.DEFAULT_ID, ProfileContext.activeId(activity))
        // 寫進磁碟了：丟掉快取重讀，還是同一份。
        ProfileManager.resetCacheForTesting()
        assertEquals(registry, ProfileManager.registry(activity))
    }

    @Test
    fun theRegistryWinsWhenContextWasLeftBehindByAnInterruptedSwitch() {
        val other = registryWithOther()
        val registry = ProfileManager.registry(activity)
        registry.activate(other.id)
        ProfileManager.save(activity, registry)
        // 切換在「寫名單」與「改 context」之間被中斷：context 還指著舊的。
        ProfileContext.setActive(activity, ProfileRecord.DEFAULT_ID)
        ProfileManager.resetCacheForTesting()
        ProfileContext.resetCacheForTesting()

        ProfileManager.registry(activity)

        assertEquals(other.id, ProfileContext.activeId(activity))
    }

    @Test
    fun theSwitchRunsInOrderAndRestartsLast() = runBlocking {
        val other = registryWithOther()

        val result = ProfileSwitcher(hooks()).switchTo(activity, other.id)

        assertEquals(ProfileSwitcher.Result.Switched, result)
        assertEquals(
            listOf("flush", "save:${other.id}", "setActive:${other.id}", "restart"), calls
        )
        assertEquals(other.id, ProfileManager.registry(activity).activeId)
        assertEquals(other.id, ProfileContext.activeId(activity))
    }

    @Test
    fun ifTheRegistryCannotBeSavedNothingChangesAndThereIsNoRestart() = runBlocking {
        val other = registryWithOther()

        val result = ProfileSwitcher(hooks(saveSucceeds = false)).switchTo(activity, other.id)

        assertEquals(ProfileSwitcher.Result.RegistryNotSaved, result)
        assertTrue("setActive 與 restart 都不能發生", calls.none { it.startsWith("setActive") || it == "restart" })
        assertEquals(ProfileRecord.DEFAULT_ID, ProfileContext.activeId(activity))
        assertEquals(ProfileRecord.DEFAULT_ID, ProfileManager.registry(activity).activeId)
    }

    @Test
    fun switchingToTheActiveOrAnUnknownProfileIsRejectedWithoutSideEffects() = runBlocking {
        registryWithOther()
        assertEquals(
            ProfileSwitcher.Result.AlreadyActive,
            ProfileSwitcher(hooks()).switchTo(activity, ProfileRecord.DEFAULT_ID)
        )
        assertEquals(
            ProfileSwitcher.Result.UnknownProfile,
            ProfileSwitcher(hooks()).switchTo(activity, "nope")
        )
        assertTrue(calls.isEmpty())
    }

    @Test
    fun theRegistryPersistsAcrossAFakeProcessRestart() = runBlocking {
        val other = registryWithOther()
        ProfileSwitcher(hooks()).switchTo(activity, other.id)

        // 「重啟行程」：靜態快取全部消失，只剩磁碟上的偏好。
        ProfileManager.resetCacheForTesting()
        ProfileContext.resetCacheForTesting()

        assertEquals(other.id, ProfileContext.activeId(activity))
        assertEquals(other.id, ProfileManager.registry(activity).activeId)
        assertNotNull(ProfileManager.registry(activity).profile(ProfileRecord.DEFAULT_ID))
        assertNull(ProfileManager.registry(activity).profile("nope"))
    }
}
