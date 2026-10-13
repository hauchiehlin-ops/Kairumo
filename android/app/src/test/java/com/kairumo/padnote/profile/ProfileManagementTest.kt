package com.kairumo.padnote.profile

import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test

/**
 * 管理操作：新增、重新命名、刪除、鎖、Google 帳號綁定、畫面閘門（Android）。
 * 與 Apple 端的 `ProfileManagementTests` 逐條對應。PIN 用記憶體儲存，不碰真的 Keystore。
 */
class ProfileManagementTest {
    private lateinit var activity: FakeActivity

    @Before
    fun setUp() {
        activity = FakeActivity()
        ProfileManager.resetCacheForTesting()
        ProfileContext.resetCacheForTesting()
        ProfileManager.setLockServiceForTesting(ProfileLockService(InMemorySecretStore()))
        ProfileGate.resetForTesting()
    }

    @After
    fun tearDown() {
        ProfileManager.setLockServiceForTesting(null)
        activity.root.deleteRecursively()
    }

    private fun assertKind(kind: ProfileException.Kind, block: () -> Unit) {
        try {
            block()
            fail("應該丟 $kind")
        } catch (e: ProfileException) {
            assertEquals(kind, e.kind)
        }
    }

    @Test
    fun creatingAProfileSeedsItsOwnIdentityWithoutTouchingTheDefault() {
        val record = ProfileManager.createProfile(activity, "小明")

        assertEquals(2, ProfileManager.registry(activity).profiles.size)
        val identity = activity.prefs(ProfileContext.prefsName("kairumo.account", record.id))
        assertEquals("小明", identity.getString("displayName", null))
        assertEquals(record.colorHex, identity.getString("colorHex", null))
        assertEquals("新增不會自動切過去", ProfileRecord.DEFAULT_ID, ProfileManager.registry(activity).activeId)
        assertNull("預設設定檔的偏好沒有被動到", activity.prefsByName["kairumo.account"]?.getString("displayName", null))
    }

    @Test
    fun theFiveProfileLimitAppliesToCreate() {
        for (i in 1 until ProfileRegistry.MAX_PROFILES) ProfileManager.createProfile(activity, "人$i")
        assertFalse(ProfileManager.registry(activity).canAdd)
        assertKind(ProfileException.Kind.LIMIT_REACHED) { ProfileManager.createProfile(activity, "第六個") }
    }

    @Test
    fun renameKeepsTheCollaborationIdentityInSync() {
        val record = ProfileManager.createProfile(activity, "舊名")
        ProfileManager.renameProfile(activity, record.id, "新名")
        ProfileManager.setProfileColor(activity, record.id, "#FF2D55")

        assertEquals("新名", ProfileManager.registry(activity).profile(record.id)?.displayName)
        val identity = activity.prefs(ProfileContext.prefsName("kairumo.account", record.id))
        assertEquals("選單上叫新名，協作畫面上也要叫新名", "新名", identity.getString("displayName", null))
        assertEquals("#FF2D55", identity.getString("colorHex", null))
        assertKind(ProfileException.Kind.DUPLICATE_NAME) {
            ProfileManager.renameProfile(activity, record.id, ProfileManager.registry(activity).profile(ProfileRecord.DEFAULT_ID)!!.displayName)
        }
    }

    @Test
    fun deleteRemovesEverythingOfThatProfileAndNothingElse() {
        val doomed = ProfileManager.createProfile(activity, "要刪的")
        val kept = ProfileManager.createProfile(activity, "要留的")
        ProfileManager.setPin(activity, "1234", doomed.id)
        val doomedDirs = ProfileContext.ownedDirectories(activity, doomed.id)
        doomedDirs.forEach { it.mkdirs(); java.io.File(it, "note").writeText("x") }
        val keptDirs = ProfileContext.ownedDirectories(activity, kept.id)
        keptDirs.forEach { it.mkdirs(); java.io.File(it, "note").writeText("keep") }
        activity.getSharedPreferences(ProfileContext.prefsName("kairumo", doomed.id), 0)
        activity.getSharedPreferences(ProfileContext.prefsName("kairumo", kept.id), 0)

        ProfileManager.deleteProfile(activity, doomed.id)

        assertNull(ProfileManager.registry(activity).profile(doomed.id))
        assertTrue(doomedDirs.none { it.exists() })
        assertTrue(ProfileContext.ownedPrefsNames(activity, doomed.id).isEmpty())
        assertFalse("PIN 也要清掉", ProfileManager.lockService(activity).hasPin(doomed.id))
        assertTrue("別的設定檔完全不受影響", keptDirs.all { it.exists() })
        assertTrue(ProfileContext.ownedPrefsNames(activity, kept.id).isNotEmpty())
        assertNotNull(ProfileManager.registry(activity).profile(kept.id))
    }

    @Test
    fun theDefaultAndTheActiveProfileCannotBeDeleted() {
        val other = ProfileManager.createProfile(activity, "別人")
        assertKind(ProfileException.Kind.CANNOT_DELETE_ACTIVE) { ProfileManager.deleteProfile(activity, ProfileRecord.DEFAULT_ID) }
        // 切到 other 之後，預設設定檔不再是使用中的，但仍然不能刪。
        val registry = ProfileManager.registry(activity)
        registry.activate(other.id)
        ProfileManager.save(activity, registry)
        assertKind(ProfileException.Kind.CANNOT_DELETE_DEFAULT) { ProfileManager.deleteProfile(activity, ProfileRecord.DEFAULT_ID) }
        assertKind(ProfileException.Kind.CANNOT_DELETE_ACTIVE) { ProfileManager.deleteProfile(activity, other.id) }
        assertKind(ProfileException.Kind.NOT_FOUND) { ProfileManager.deleteProfile(activity, "nope") }
    }

    @Test
    fun pinLifecycleSetVerifyChangeRemove() {
        val id = ProfileRecord.DEFAULT_ID
        assertFalse(ProfileManager.registry(activity).active.lock.isEnabled)

        ProfileManager.setPin(activity, "2468", id)
        assertTrue(ProfileManager.registry(activity).active.lock.hasPin)
        assertEquals(PinVerifyResult.Ok, ProfileManager.verifyPin(activity, "2468", id))

        ProfileManager.setBiometrics(activity, id, true)
        assertTrue(ProfileManager.registry(activity).active.lock.useBiometrics)
        ProfileManager.setPin(activity, "1357", id)
        assertTrue("更換 PIN 之後生物辨識設定保留", ProfileManager.registry(activity).active.lock.useBiometrics)
        assertTrue(ProfileManager.verifyPin(activity, "2468", id) != PinVerifyResult.Ok)

        assertKind(ProfileException.Kind.WRONG_PIN) { ProfileManager.removeLock(activity, id, "0000") }
        assertTrue("輸錯 PIN，鎖還在", ProfileManager.registry(activity).active.lock.hasPin)
        ProfileManager.removeLock(activity, id, "1357")
        assertEquals(ProfileLock.NONE, ProfileManager.registry(activity).active.lock)
        assertFalse(ProfileManager.lockService(activity).hasPin(id))
        assertKind(ProfileException.Kind.PIN_REQUIRED) { ProfileManager.setBiometrics(activity, id, true) }
    }

    @Test
    fun oneGoogleAccountCannotBeBoundToTwoProfiles() {
        val other = ProfileManager.createProfile(activity, "別人")
        ProfileManager.bindGoogle(activity, "Me@Example.com")  // 綁在使用中的（預設）

        val registry = ProfileManager.registry(activity)
        registry.activate(other.id)
        ProfileManager.save(activity, registry)
        try {
            ProfileManager.bindGoogle(activity, "me@example.com")
            fail("同一個帳號不能綁兩個設定檔")
        } catch (e: ProfileException) {
            assertEquals(ProfileException.Kind.GOOGLE_ALREADY_BOUND, e.kind)
            assertEquals(ProfileManager.registry(activity).profile(ProfileRecord.DEFAULT_ID)?.displayName, e.profileName)
        }
        // 預設設定檔登出之後帳號才放出來。
        val back = ProfileManager.registry(activity)
        back.unbindGoogle(ProfileRecord.DEFAULT_ID)
        ProfileManager.save(activity, back)
        ProfileManager.bindGoogle(activity, "me@example.com")
        assertEquals("me@example.com", ProfileManager.registry(activity).profile(other.id)?.googleEmail)
    }

    // ── 畫面閘門 ─────────────────────────────────────────────

    @Test
    fun aProfileWithoutALockIsNeverGated() {
        assertFalse(ProfileGate.isLocked(activity, now = 0L))
        ProfileGate.noteStopped(now = 0L)
        assertFalse(ProfileGate.noteStarted(activity, now = 3_600_000L))
    }

    @Test
    fun aLockedProfileStartsLockedAndUnlocksOnce() {
        ProfileManager.setPin(activity, "2468", ProfileRecord.DEFAULT_ID)
        assertTrue(ProfileGate.isLocked(activity, now = 0L))
        ProfileGate.unlock()
        assertFalse(ProfileGate.isLocked(activity, now = 1L))
    }

    @Test
    fun theLockComesBackAfterTheAppWasAwayLongEnoughButNotForAQuickLook() {
        ProfileManager.setPin(activity, "2468", ProfileRecord.DEFAULT_ID)
        ProfileGate.unlock()

        ProfileGate.noteStopped(now = 1_000L)
        assertFalse("只是看一下通知，不該重新上鎖", ProfileGate.noteStarted(activity, now = 1_000L + ProfileGate.RELOCK_AFTER_BACKGROUND_MS - 1))

        ProfileGate.noteStopped(now = 1_000L)
        assertTrue(ProfileGate.noteStarted(activity, now = 1_000L + ProfileGate.RELOCK_AFTER_BACKGROUND_MS + 1))
    }

    @Test
    fun justUnlockedBeforeASwitchSkipsTheSecondPromptButOnlyOnceAndOnlyBriefly() {
        val other = ProfileManager.createProfile(activity, "別人")
        ProfileManager.setPin(activity, "2468", other.id)
        val registry = ProfileManager.registry(activity)
        registry.activate(other.id)
        ProfileManager.save(activity, registry)

        // 在切換選單裡剛過了 PIN → 新行程啟動時不再問。
        ProfileGate.markJustUnlockedFor(activity, other.id, now = 1_000L)
        assertFalse(ProfileGate.isLocked(activity, now = 5_000L))

        // 只消費一次：下一個行程（記號已被拿走）要照常問。
        ProfileGate.resetForTesting()
        assertTrue(ProfileGate.isLocked(activity, now = 6_000L))

        // 太久以前的記號不算。
        ProfileGate.resetForTesting()
        ProfileGate.markJustUnlockedFor(activity, other.id, now = 1_000L)
        assertTrue(ProfileGate.isLocked(activity, now = 1_000L + 60_000L))

        // 別的設定檔的記號不算。
        ProfileGate.resetForTesting()
        ProfileGate.markJustUnlockedFor(activity, ProfileRecord.DEFAULT_ID, now = 1_000L)
        assertTrue(ProfileGate.isLocked(activity, now = 2_000L))
    }

    @Test
    fun aPinThatCannotBeStoredIsReportedAsStorageFailureNotAnInvalidPin() {
        ProfileManager.setLockServiceForTesting(ProfileLockService(object : ProfileSecretStore {
            override fun read(account: String): String? = null
            override fun write(account: String, value: String) = false
            override fun delete(account: String) {}
        }))
        assertKind(ProfileException.Kind.PIN_STORAGE_FAILED) {
            ProfileManager.setPin(activity, "2468", ProfileRecord.DEFAULT_ID)
        }
        assertFalse("鎖不能因為存失敗而被標成已啟用", ProfileManager.registry(activity).active.lock.hasPin)
        assertKind(ProfileException.Kind.INVALID_PIN) { ProfileManager.setPin(activity, "12", ProfileRecord.DEFAULT_ID) }
    }
}
