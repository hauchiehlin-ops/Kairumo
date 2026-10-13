package com.kairumo.padnote.profile

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import java.io.File

/**
 * 多設定檔的規則與根基（Android）。與 Apple 端的 `ProfileTests.swift` 逐條對應 ——
 * 兩邊的規則一旦不同，使用者在手機上建得起來的設定檔到平板上就建不起來。
 */
class ProfileRegistryTest {
    private fun registry() = ProfileRegistry.initial("我", "#007AFF", now = 1000L)

    private fun assertKind(kind: ProfileException.Kind, block: () -> Unit) {
        try {
            block()
            fail("應該丟 $kind")
        } catch (e: ProfileException) {
            assertEquals(kind, e.kind)
        }
    }

    @Test
    fun initialRegistryHasOnlyTheDefaultProfileAndItIsActive() {
        val r = registry()
        assertEquals(1, r.profiles.size)
        assertEquals(ProfileRecord.DEFAULT_ID, r.active.id)
        assertTrue(r.active.isDefault)
    }

    @Test
    fun theLimitIsFiveProfilesInTotal() {
        val r = registry()
        for (i in 1 until ProfileRegistry.MAX_PROFILES) r.add("人$i")
        assertEquals(5, r.profiles.size)
        assertFalse(r.canAdd)
        assertKind(ProfileException.Kind.LIMIT_REACHED) { r.add("第六個") }
    }

    @Test
    fun namesMustBeNonEmptyShortAndUniqueIgnoringCase() {
        val r = registry()
        assertKind(ProfileException.Kind.INVALID_NAME) { r.add("   ") }
        assertKind(ProfileException.Kind.INVALID_NAME) { r.add("長".repeat(25)) }
        r.add("Alice")
        assertKind(ProfileException.Kind.DUPLICATE_NAME) { r.add(" alice ") }
        // 改成自己現在的名字不算重複。
        val alice = r.profiles.first { it.displayName == "Alice" }
        r.rename(alice.id, "Alice")
    }

    @Test
    fun newProfilesGetDistinctColorsUntilThePaletteRunsOut() {
        val r = registry()
        r.add("A")
        r.add("B")
        assertEquals(3, r.profiles.map { it.colorHex }.toSet().size)
    }

    @Test
    fun theLastProfileCannotBeRemoved() {
        assertKind(ProfileException.Kind.LAST_PROFILE) { registry().remove(ProfileRecord.DEFAULT_ID) }
    }

    @Test
    fun removingTheActiveProfileFallsBackToTheMostRecentlyUsedOne() {
        val r = registry()
        val a = r.add("A", now = 2000L)
        val b = r.add("B", now = 3000L)
        r.activate(a.id, now = 4000L)
        r.remove(a.id)
        assertEquals("最近用過的是 B（3000），不是預設（1000）", b.id, r.activeId)
    }

    @Test
    fun oneGoogleAccountCanOnlyBeBoundToOneProfile() {
        val r = registry()
        val a = r.add("A")
        r.bindGoogle("Me@Example.com", ProfileRecord.DEFAULT_ID)
        try {
            r.bindGoogle(" me@example.COM ", a.id)
            fail("同一個帳號不能綁兩個設定檔")
        } catch (e: ProfileException) {
            assertEquals(ProfileException.Kind.GOOGLE_ALREADY_BOUND, e.kind)
            assertEquals("我", e.profileName)
        }
        // 綁回自己是可以的（重新登入同一個帳號）。
        r.bindGoogle("me@example.com", ProfileRecord.DEFAULT_ID)
        // 解綁之後別的設定檔就能用。
        r.unbindGoogle(ProfileRecord.DEFAULT_ID)
        r.bindGoogle("me@example.com", a.id)
        assertEquals(a.id, r.profileBoundTo("ME@example.com")?.id)
    }

    @Test
    fun biometricsCannotExistWithoutAPin() {
        val r = registry()
        r.setLock(ProfileRecord.DEFAULT_ID, ProfileLock(hasPin = false, useBiometrics = true))
        assertEquals("沒有 PIN 就不能只靠生物辨識", ProfileLock.NONE, r.active.lock)
        r.setLock(ProfileRecord.DEFAULT_ID, ProfileLock(hasPin = true, useBiometrics = true))
        assertTrue(r.active.lock.useBiometrics)
    }

    @Test
    fun jsonRoundTripKeepsEverything() {
        val r = registry()
        val a = r.add("A", now = 2000L)
        r.setLock(a.id, ProfileLock(hasPin = true, useBiometrics = true))
        r.bindGoogle("x@y.com", a.id)
        r.activate(a.id, now = 5000L)
        val back = ProfileRegistry.fromJson(r.toJson())
        assertNotNull(back)
        assertEquals(r, back)
        assertEquals("x@y.com", back!!.active.googleEmail)
    }

    @Test
    fun unreadableJsonIsReportedAsNullNotACrash() {
        assertNull(ProfileRegistry.fromJson("not json"))
        assertNull(ProfileRegistry.fromJson("{}"))
    }

    @Test
    fun repairFixesAnInconsistentFile() {
        val a = ProfileRecord("x", "A", "#000", 0, 0, googleEmail = "same@x.com")
        val b = ProfileRecord("y", "B", "#111", 0, 0, googleEmail = "same@x.com")
        val json = ProfileRegistry.initial("seed", "#007AFF").let {
            // 組一份壞掉的檔案：重複的 id、重複的 Google 帳號、使用中的 id 不存在。
            org.json.JSONObject()
                .put("activeId", "missing")
                .put(
                    "profiles",
                    org.json.JSONArray(listOf(a, a, b).map { p ->
                        org.json.JSONObject()
                            .put("id", p.id).put("displayName", p.displayName).put("colorHex", p.colorHex)
                            .put("createdAt", 0).put("lastActiveAt", 0)
                            .put("hasPin", false).put("useBiometrics", false)
                            .put("googleEmail", p.googleEmail)
                    })
                ).toString()
        }
        val fixed = ProfileRegistry.fromJson(json)!!.repaired("我", "#007AFF")
        assertEquals(listOf("x", "y"), fixed.profiles.map { it.id })
        assertEquals("使用中的 id 不存在 → 退到第一個", "x", fixed.activeId)
        assertNull("同一個 Google 帳號不能出現兩次", fixed.profiles[1].googleEmail)
    }
}

class ProfileContextTest {
    @Test
    fun theDefaultProfileKeepsTheOriginalPrefsNames() {
        assertEquals(
            "預設設定檔的偏好檔名不能有後綴，否則升級後既有使用者的設定就全部消失",
            "kairumo", ProfileContext.prefsName("kairumo", ProfileRecord.DEFAULT_ID)
        )
    }

    @Test
    fun otherProfilesGetTheirOwnPrefsFiles() {
        assertEquals("kairumo.pf.abc", ProfileContext.prefsName("kairumo", "abc"))
        assertNotEquals(ProfileContext.prefsName("kairumo", "a"), ProfileContext.prefsName("kairumo", "b"))
        assertNotEquals(
            ProfileContext.prefsName("kairumo", "a"), ProfileContext.prefsName("kairumo", ProfileRecord.DEFAULT_ID)
        )
    }

    @Test
    fun dataRootsAreSeparatePerProfileAndTheDefaultIsTheBaseItself() {
        val base = File("/data/files")
        assertEquals(base, ProfileContext.dataRoot(base, ProfileRecord.DEFAULT_ID))
        assertEquals(File("/data/files/profiles/abc"), ProfileContext.dataRoot(base, "abc"))
        assertNotEquals(ProfileContext.dataRoot(base, "a"), ProfileContext.dataRoot(base, "b"))
    }
}

class ProfileLockServiceTest {
    private fun service(store: ProfileSecretStore = InMemorySecretStore()) = ProfileLockService(store)
    private val t0 = 1_000_000L

    @Test
    fun pinFormat() {
        assertTrue(ProfileLockService.isValidPin("1234"))
        assertTrue(ProfileLockService.isValidPin("12345678"))
        assertFalse(ProfileLockService.isValidPin("123"))
        assertFalse(ProfileLockService.isValidPin("123456789"))
        assertFalse(ProfileLockService.isValidPin("12a4"))
        assertFalse("全形數字不算", ProfileLockService.isValidPin("１２３４"))
    }

    @Test
    fun correctPinUnlocksAndTheWrongOneDoesNot() {
        val s = service()
        assertEquals(PinVerifyResult.NoPin, s.verify("1234", "p", t0))
        s.setPin("2468", "p")
        assertTrue(s.hasPin("p"))
        assertEquals(PinVerifyResult.Ok, s.verify("2468", "p", t0))
        assertEquals(PinVerifyResult.Wrong(4), s.verify("1111", "p", t0))
    }

    @Test
    fun pinsAreIndependentPerProfile() {
        val s = service()
        s.setPin("1111", "a")
        s.setPin("2222", "b")
        assertEquals(PinVerifyResult.Ok, s.verify("1111", "a", t0))
        assertNotEquals(PinVerifyResult.Ok, s.verify("1111", "b", t0))
    }

    @Test
    fun repeatedFailuresLockOutWithIncreasingDelayAndSurviveRelaunch() {
        val store = InMemorySecretStore()
        val s = service(store)
        s.setPin("2468", "p")
        repeat(4) { s.verify("0000", "p", t0) }
        // 第 5 次錯：鎖 30 秒。
        val locked = s.verify("0000", "p", t0)
        assertTrue(locked is PinVerifyResult.LockedOut)
        val until = (locked as PinVerifyResult.LockedOut).untilMillis
        assertEquals(t0 + 30_000L, until)
        // 鎖定中連正確的 PIN 也不收。
        assertEquals(PinVerifyResult.LockedOut(until), s.verify("2468", "p", t0 + 10_000L))
        // 「重開 App」：換一個 service 實例、同一份儲存，鎖定狀態還在。
        val relaunched = service(store)
        assertEquals(PinVerifyResult.LockedOut(until), relaunched.verify("2468", "p", t0 + 10_000L))
        // 鎖定結束後正確的 PIN 可以開，並且歸零。
        assertEquals(PinVerifyResult.Ok, relaunched.verify("2468", "p", t0 + 31_000L))
        assertEquals(PinVerifyResult.Wrong(4), relaunched.verify("0000", "p", t0 + 32_000L))
    }

    @Test
    fun lockDurationsGrowAndAreCapped() {
        assertEquals(0L, ProfileLockService.lockDurationMillis(4))
        assertEquals(30_000L, ProfileLockService.lockDurationMillis(5))
        assertEquals(900_000L, ProfileLockService.lockDurationMillis(8))
        assertEquals(3_600_000L, ProfileLockService.lockDurationMillis(50))
    }

    @Test
    fun theStoredRecordNeverContainsThePin() {
        val store = InMemorySecretStore()
        service(store).setPin("97531", "p")
        assertFalse(store.read("pin.p")!!.contains("97531"))
    }

    @Test
    fun invalidPinIsRejectedAndClearRemovesIt() {
        val s = service()
        try {
            s.setPin("12", "p")
            fail("太短的 PIN 要被擋下")
        } catch (e: ProfileException) {
            assertEquals(ProfileException.Kind.INVALID_PIN, e.kind)
        }
        s.setPin("1234", "p")
        s.clearPin("p")
        assertFalse(s.hasPin("p"))
    }
}
