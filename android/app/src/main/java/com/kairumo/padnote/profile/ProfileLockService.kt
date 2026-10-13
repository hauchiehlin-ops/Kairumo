package com.kairumo.padnote.profile

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import org.json.JSONObject
import java.security.MessageDigest
import java.security.SecureRandom
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.PBEKeySpec

/**
 * 設定檔鎖：PIN，加上可選的生物辨識捷徑（Android）。與 Apple 端的 `ProfileLockService.swift` 對應。
 *
 * # 這是什麼、不是什麼
 *
 * 它擋的是「同一台裝置上的**另一個設定檔的使用者**不小心（或好奇）點進你的環境」。
 * 它**不是**加密：資料在 App 的私有目錄裡，核心直接讀寫檔案，沒有針對設定檔的加密層。
 * 真正的保密要靠 Android 的多使用者（每個使用者各自加密）或裝置密碼。
 *
 * # PIN
 *
 * 4～8 位數字。PBKDF2-HMAC-SHA256（12 萬次）加隨機鹽雜湊後存進**加密偏好**（Keystore 保護），
 * 設定檔名單裡只記「有沒有設 PIN」。連續輸錯會**遞增鎖定**，鎖定狀態同樣存在加密偏好，
 * 重開 App 不會歸零。
 *
 * **忘記 PIN 沒有救援。** 用裝置密碼救援的話，知道裝置密碼的家人就能重設別人的 PIN ——
 * 那正是這個鎖要擋的對象。唯一的出路是刪除這個設定檔；有登入 Google 的話，
 * 重新登入就能把雲端上的筆記拉回來。
 */
interface ProfileSecretStore {
    fun read(account: String): String?
    fun write(account: String, value: String): Boolean
    fun delete(account: String)
}

class InMemorySecretStore : ProfileSecretStore {
    private val items = mutableMapOf<String, String>()
    override fun read(account: String) = items[account]
    override fun write(account: String, value: String): Boolean {
        items[account] = value
        return true
    }
    override fun delete(account: String) {
        items.remove(account)
    }
}

/** 正式版：加密偏好。建不起來（極舊裝置、Keystore 損壞）時**不退回明文** —— 寧可無法設鎖。 */
class EncryptedSecretStore(context: Context) : ProfileSecretStore {
    private val prefs: SharedPreferences? = try {
        val app = context.applicationContext
        val key = MasterKey.Builder(app).setKeyScheme(MasterKey.KeyScheme.AES256_GCM).build()
        EncryptedSharedPreferences.create(
            app, PREFS, key,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    } catch (e: Exception) {
        android.util.Log.e("ProfileLock", "加密偏好建立失敗：${e.message}", e)
        null
    }

    val isAvailable: Boolean get() = prefs != null

    override fun read(account: String) = prefs?.getString(account, null)
    override fun write(account: String, value: String): Boolean =
        prefs?.edit()?.putString(account, value)?.commit() ?: false
    override fun delete(account: String) {
        prefs?.edit()?.remove(account)?.commit()
    }

    companion object {
        /** 裝置共用（不屬於任何設定檔），所以不經過 [ProfileContext.prefs]。 */
        const val PREFS = "kairumo.profilelock"
    }
}

sealed class PinVerifyResult {
    object Ok : PinVerifyResult()

    /** 輸錯了。[attemptsBeforeLock] 是再錯幾次會開始鎖定。 */
    data class Wrong(val attemptsBeforeLock: Int) : PinVerifyResult()
    data class LockedOut(val untilMillis: Long) : PinVerifyResult()

    /** 這個設定檔根本沒有設 PIN。 */
    object NoPin : PinVerifyResult()
}

class ProfileLockService(private val store: ProfileSecretStore) {

    private class Record(
        val salt: ByteArray,
        val hash: ByteArray,
        val iterations: Int,
        val failures: Int,
        val lockedUntil: Long
    ) {
        fun toJson(): String = JSONObject()
            .put("salt", java.util.Base64.getEncoder().encodeToString(salt))
            .put("hash", java.util.Base64.getEncoder().encodeToString(hash))
            .put("iterations", iterations)
            .put("failures", failures)
            .put("lockedUntil", lockedUntil)
            .toString()

        companion object {
            fun fromJson(json: String): Record? = try {
                val o = JSONObject(json)
                Record(
                    java.util.Base64.getDecoder().decode(o.getString("salt")),
                    java.util.Base64.getDecoder().decode(o.getString("hash")),
                    o.getInt("iterations"), o.getInt("failures"), o.getLong("lockedUntil")
                )
            } catch (e: Exception) {
                null
            }
        }
    }

    private fun account(profileId: String) = "pin.$profileId"

    @Synchronized
    fun hasPin(profileId: String): Boolean = load(profileId) != null

    /** 設定（或更換）PIN。格式不對丟 [ProfileException.Kind.INVALID_PIN]。回傳有沒有真的存進去。 */
    @Synchronized
    fun setPin(pin: String, profileId: String): Boolean {
        if (!isValidPin(pin)) throw ProfileException(ProfileException.Kind.INVALID_PIN)
        val salt = ByteArray(16).also { SecureRandom().nextBytes(it) }
        val record = Record(salt, derive(pin, salt, ITERATIONS), ITERATIONS, 0, 0L)
        return save(record, profileId)
    }

    @Synchronized
    fun clearPin(profileId: String) = store.delete(account(profileId))

    @Synchronized
    fun verify(pin: String, profileId: String, now: Long = System.currentTimeMillis()): PinVerifyResult {
        val record = load(profileId) ?: return PinVerifyResult.NoPin
        if (record.lockedUntil > now) return PinVerifyResult.LockedOut(record.lockedUntil)
        val candidate = derive(pin, record.salt, record.iterations)
        if (MessageDigest.isEqual(candidate, record.hash)) {
            save(Record(record.salt, record.hash, record.iterations, 0, 0L), profileId)
            return PinVerifyResult.Ok
        }
        val failures = record.failures + 1
        val lock = lockDurationMillis(failures)
        val lockedUntil = if (lock > 0) now + lock else 0L
        save(Record(record.salt, record.hash, record.iterations, failures, lockedUntil), profileId)
        return if (lock > 0) {
            PinVerifyResult.LockedOut(lockedUntil)
        } else {
            PinVerifyResult.Wrong(maxOf(0, FREE_ATTEMPTS + 1 - failures))
        }
    }

    /** 生物辨識成功之後呼叫：把輸錯次數歸零（人確實是本人）。 */
    @Synchronized
    fun noteBiometricSuccess(profileId: String) {
        val record = load(profileId) ?: return
        save(Record(record.salt, record.hash, record.iterations, 0, 0L), profileId)
    }

    private fun load(profileId: String): Record? =
        store.read(account(profileId))?.let { Record.fromJson(it) }

    private fun save(record: Record, profileId: String): Boolean =
        store.write(account(profileId), record.toJson())

    companion object {
        const val MIN_DIGITS = 4
        const val MAX_DIGITS = 8

        /** 連續輸錯幾次以內不鎖定。 */
        const val FREE_ATTEMPTS = 4
        internal const val ITERATIONS = 120_000

        fun isValidPin(pin: String): Boolean =
            pin.length in MIN_DIGITS..MAX_DIGITS && pin.all { it in '0'..'9' }

        /** 鎖定時間表：第 5 次錯 30 秒、第 6 次 1 分鐘、第 7 次 5 分鐘、第 8 次 15 分鐘、之後每次 1 小時。 */
        fun lockDurationMillis(failures: Int): Long = when {
            failures < 5 -> 0L
            failures == 5 -> 30_000L
            failures == 6 -> 60_000L
            failures == 7 -> 300_000L
            failures == 8 -> 900_000L
            else -> 3_600_000L
        }

        internal fun derive(pin: String, salt: ByteArray, iterations: Int): ByteArray {
            val spec = PBEKeySpec(pin.toCharArray(), salt, iterations, 256)
            return SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256").generateSecret(spec).encoded
        }
    }
}
