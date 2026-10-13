package com.kairumo.padnote.profile

import android.content.Context
import com.kairumo.padnote.account.AccountManager

/**
 * 設定檔名單的載入與存檔（Android）。與 Apple 端 `ProfileManager` 的名單部分對應。
 *
 * 名單存在**裝置共用**的偏好（`kairumo.profiles`，不屬於任何設定檔），整份 JSON 一個鍵、`commit()` 同步寫 ——
 * 切換之後行程馬上要結束，非同步的 `apply()` 可能還沒落盤，下次啟動就回到舊的設定檔。
 */
// profile-scope: device 設定檔名單本身是整台裝置共用的
object ProfileManager {
    private const val KEY_REGISTRY = "registry"

    @Volatile
    private var cached: ProfileRegistry? = null

    /** 剛才登入的 Google 帳號已經綁在另一個設定檔：那個設定檔的名稱（畫面據此顯示一次訊息）。 */
    val googleConflict = kotlinx.coroutines.flow.MutableStateFlow<String?>(null)

    /** 目前的名單。第一次呼叫時讀檔（沒有就建立只有預設設定檔的初始名單 —— 它對應既有資料，什麼都不搬）。 */
    fun registry(context: Context): ProfileRegistry {
        cached?.let { return it }
        synchronized(this) {
            cached?.let { return it }
            val prefs = ProfileContext.devicePrefs(context, ProfileContext.DEVICE_PREFS)
            // 預設設定檔的名稱：這台裝置上原本那位使用者的協作身分名稱；沒有就用「你」。
            // 與首頁身分卡上顯示的是同一個名字 —— 選單上叫「Kairumo」、身分卡上叫「你」會讓人以為是兩個人。
            val fallbackName = AccountManager.customName(context, com.kairumo.padnote.L10n.t("default_user_name"))
            val loaded = prefs.getString(KEY_REGISTRY, null)?.let { ProfileRegistry.fromJson(it) }
            val registry = loaded?.repaired(fallbackName, AccountManager.DEFAULT_COLOR)
                ?: ProfileRegistry.initial(fallbackName, AccountManager.DEFAULT_COLOR)
            if (loaded == null || registry != loaded) save(context, registry)
            // `ProfileContext` 與名單必須一致。切換時「先名單、後 context」，兩步之間被中斷就以名單為準。
            if (ProfileContext.activeId(context) != registry.activeId) {
                ProfileContext.setActive(context, registry.activeId)
            }
            cached = registry
            return registry
        }
    }

    /** 存名單。回傳有沒有真的寫進磁碟。 */
    fun save(context: Context, registry: ProfileRegistry): Boolean {
        val ok = ProfileContext.devicePrefs(context, ProfileContext.DEVICE_PREFS)
            .edit().putString(KEY_REGISTRY, registry.toJson()).commit()
        if (ok) cached = registry
        return ok
    }

    /** 只給測試：丟掉快取。 */
    internal fun resetCacheForTesting() {
        cached = null
    }
}

// ── 管理操作（與 Apple 端 `ProfileManagerOperations.swift` 對應）────────────────

private var lockServiceCache: ProfileLockService? = null

/** 設定檔鎖的服務（PIN 存在加密偏好）。 */
fun ProfileManager.lockService(context: Context): ProfileLockService = synchronized(this) {
    lockServiceCache ?: ProfileLockService(EncryptedSecretStore(context)).also { lockServiceCache = it }
}

/** 只給測試：換成記憶體裡的儲存。 */
internal fun ProfileManager.setLockServiceForTesting(service: ProfileLockService?) {
    lockServiceCache = service
}

private fun ProfileManager.commit(context: Context, change: (ProfileRegistry) -> Unit): ProfileRegistry {
    // 改一份複本，存成功才換上去：寫不進去就什麼都沒變。
    val next = ProfileRegistry.fromJson(registry(context).toJson())!!
    change(next)
    if (!save(context, next)) throw ProfileException(ProfileException.Kind.INVALID_NAME)
    return next
}

/** 新增一個設定檔（**不會**自動切過去）。新設定檔從乾淨的環境開始，語言沿用建立者目前的。 */
fun ProfileManager.createProfile(context: Context, name: String, colorHex: String? = null): ProfileRecord {
    var created: ProfileRecord? = null
    commit(context) { created = it.add(name, colorHex) }
    val record = created!!
    // 新設定檔自己的偏好檔：協作身分（名稱與顏色）與語言。這時候它還不是使用中的，
    // 所以直接寫它的檔名，不經過 `ProfileContext.prefs`（那個只認使用中的）。
    val account = context.applicationContext.getSharedPreferences(
        ProfileContext.prefsName("kairumo.account", record.id), Context.MODE_PRIVATE
    )
    account.edit()
        .putString("displayName", record.displayName)
        .putString("customDisplayName", record.displayName)
        .putString("colorHex", record.colorHex)
        .commit()
    return record
}

fun ProfileManager.renameProfile(context: Context, id: String, name: String) {
    val registry = commit(context) { it.rename(id, name) }
    val trimmed = registry.profile(id)?.displayName ?: name
    syncIdentity(context, id) { it.putString("displayName", trimmed).putString("customDisplayName", trimmed) }
}

fun ProfileManager.setProfileColor(context: Context, id: String, hex: String) {
    commit(context) { it.setColor(id, hex) }
    syncIdentity(context, id) { it.putString("colorHex", hex) }
}

/** 設定檔的名稱與顏色同時是協作身分。兩邊不同步的話，選單上叫「小明」的人在協作畫面上卻叫別的名字。 */
private fun syncIdentity(context: Context, id: String, edit: (android.content.SharedPreferences.Editor) -> Unit) {
    val prefs = context.applicationContext.getSharedPreferences(
        ProfileContext.prefsName("kairumo.account", id), Context.MODE_PRIVATE
    )
    prefs.edit().also(edit).commit()
}

/**
 * 刪除一個設定檔：**它的所有資料**（筆記、偏好、登入、PIN、同步快取）。不可復原，呼叫端要先讓使用者確認。
 * 雲端上的那份**不動** —— 用同一個 Google 帳號重新建立設定檔並登入，筆記就會回來。
 */
fun ProfileManager.deleteProfile(context: Context, id: String) {
    val current = registry(context)
    if (id == current.activeId) throw ProfileException(ProfileException.Kind.CANNOT_DELETE_ACTIVE)
    var removed: ProfileRecord? = null
    commit(context) { removed = it.remove(id) }  // 預設設定檔、最後一個、不存在，都在這裡擋下
    ProfileContext.ownedDirectories(context, id).forEach { it.deleteRecursively() }
    ProfileContext.ownedPrefsNames(context, id).forEach { context.deleteSharedPreferences(it) }
    lockService(context).clearPin(id)
}

/** 設定 PIN（新設定或更換）。更換**既有**的 PIN 前，呼叫端要先用 [verifyPin] 確認舊的。 */
fun ProfileManager.setPin(context: Context, pin: String, id: String) {
    if (registry(context).profile(id) == null) throw ProfileException(ProfileException.Kind.NOT_FOUND)
    if (!lockService(context).setPin(pin, id)) throw ProfileException(ProfileException.Kind.PIN_STORAGE_FAILED)
    val useBio = registry(context).profile(id)?.lock?.useBiometrics ?: false
    commit(context) { it.setLock(id, ProfileLock(hasPin = true, useBiometrics = useBio)) }
}

/** 移除鎖（PIN 與生物辨識一起）。**需要目前的 PIN** —— 否則走過來的人按一下就把你的鎖拿掉了。 */
fun ProfileManager.removeLock(context: Context, id: String, currentPin: String) {
    if (lockService(context).verify(currentPin, id) != PinVerifyResult.Ok) {
        throw ProfileException(ProfileException.Kind.WRONG_PIN)
    }
    lockService(context).clearPin(id)
    commit(context) { it.setLock(id, ProfileLock.NONE) }
    if (id == registry(context).activeId) ProfileGate.unlock()
}

fun ProfileManager.setBiometrics(context: Context, id: String, enabled: Boolean) {
    val record = registry(context).profile(id) ?: throw ProfileException(ProfileException.Kind.NOT_FOUND)
    if (!record.lock.hasPin) throw ProfileException(ProfileException.Kind.PIN_REQUIRED)
    commit(context) { it.setLock(id, ProfileLock(hasPin = true, useBiometrics = enabled)) }
}

fun ProfileManager.verifyPin(context: Context, pin: String, id: String): PinVerifyResult =
    lockService(context).verify(pin, id)

/** 目前設定檔登入了某個 Google 帳號：綁上去。已經綁在**別的**設定檔上就丟錯（呼叫端要登出）。 */
fun ProfileManager.bindGoogle(context: Context, email: String) {
    val current = registry(context)
    val next = ProfileRegistry.fromJson(current.toJson())!!
    next.bindGoogle(email, current.activeId)
    if (next != current) save(context, next)
}

/** 目前設定檔登出：解除綁定，帳號可以讓別的設定檔用。 */
fun ProfileManager.unbindGoogle(context: Context) {
    val current = registry(context)
    val next = ProfileRegistry.fromJson(current.toJson())!!
    next.unbindGoogle(current.activeId)
    if (next != current) save(context, next)
}

/**
 * 畫面閘門：使用中的設定檔上了鎖，要過關才看得到內容。**只是畫面閘門**（見 [ProfileLockService]）。
 *
 * 切換設定檔是重啟行程，所以新行程一開始是「鎖住」的；剛在切換選單裡過了 PIN 的人不該被問第二次 ——
 * 過關時在裝置偏好裡留一個 20 秒的「剛解過」記號，新行程啟動時消費掉它。
 */
// profile-scope: device 只有一個使用中的設定檔，閘門是這個行程的畫面狀態
object ProfileGate {
    private const val KEY_JUST_UNLOCKED = "justUnlocked"
    private const val JUST_UNLOCKED_WINDOW_MS = 20_000L
    const val RELOCK_AFTER_BACKGROUND_MS = 60_000L

    @Volatile
    private var unlocked = false

    @Volatile
    private var stoppedAt = 0L

    fun unlock() {
        unlocked = true
    }

    /** 這個行程一開始要不要擋住畫面。 */
    fun isLocked(context: Context, now: Long = System.currentTimeMillis()): Boolean {
        val registry = ProfileManager.registry(context)
        if (!registry.active.lock.isEnabled) return false
        if (unlocked) return false
        if (consumeJustUnlocked(context, registry.activeId, now)) {
            unlocked = true
            return false
        }
        return true
    }

    /** 切換之前、使用者已經過了目標設定檔的 PIN：新行程啟動時不要再問一次。 */
    fun markJustUnlockedFor(context: Context, profileId: String, now: Long = System.currentTimeMillis()) {
        ProfileContext.devicePrefs(context, ProfileContext.DEVICE_PREFS)
            .edit().putString(KEY_JUST_UNLOCKED, "$profileId@$now").commit()
    }

    private fun consumeJustUnlocked(context: Context, activeId: String, now: Long): Boolean {
        val prefs = ProfileContext.devicePrefs(context, ProfileContext.DEVICE_PREFS)
        val raw = prefs.getString(KEY_JUST_UNLOCKED, null) ?: return false
        prefs.edit().remove(KEY_JUST_UNLOCKED).commit()
        val parts = raw.split("@")
        val ts = parts.getOrNull(1)?.toLongOrNull() ?: return false
        return parts[0] == activeId && now - ts in 0..JUST_UNLOCKED_WINDOW_MS
    }

    /** App 進背景。 */
    fun noteStopped(now: Long = System.currentTimeMillis()) {
        stoppedAt = now
    }

    /** 回到前景：離開超過一分鐘、而且有鎖，就重新上鎖。 */
    fun noteStarted(context: Context, now: Long = System.currentTimeMillis()): Boolean {
        val left = stoppedAt
        stoppedAt = 0L
        if (left == 0L || !ProfileManager.registry(context).active.lock.isEnabled) return false
        if (now - left >= RELOCK_AFTER_BACKGROUND_MS) unlocked = false
        return !unlocked
    }

    /** 只給測試。 */
    internal fun resetForTesting() {
        unlocked = false
        stoppedAt = 0L
    }
}
