package com.kairumo.padnote.profile

import org.json.JSONArray
import org.json.JSONObject

/**
 * 多設定檔（profile）的資料模型與規則（Android）。
 *
 * **規則必須與 Apple 端的 `Profile.swift` 逐條相同** —— 上限 5 個、名稱不可空白或重複、
 * 一個 Google 帳號只能綁一個設定檔、不能刪掉最後一個、生物辨識不能沒有 PIN。
 * 兩邊各自長出不同的規則，使用者在手機上建得起來的設定檔到平板上建不起來。
 *
 * 這一層只管「有哪些設定檔、各自的設定」，不碰任何檔案與偏好設定 —— 那些由 [ProfileContext]
 * 依「現在是哪個設定檔」決定放在哪裡。純資料，所以可以不啟動 App 就完整測試。
 *
 * # 預設設定檔
 *
 * [ProfileRecord.DEFAULT_ID] 永遠對應**升級前就存在的那一份資料**：檔案位置、偏好設定名稱
 * 全部維持原樣，既有使用者升級後沒有任何東西被搬動。只有「新增」的設定檔才用新的位置。
 */

/** 設定檔鎖。PIN 是基礎，生物辨識只是它上面的捷徑（沒有 PIN 就不能只靠生物辨識）。 */
data class ProfileLock(val hasPin: Boolean = false, val useBiometrics: Boolean = false) {
    /** 建構時就把「沒有 PIN 的生物辨識」修正掉。 */
    fun normalized() = ProfileLock(hasPin, hasPin && useBiometrics)

    val isEnabled: Boolean get() = hasPin

    companion object {
        val NONE = ProfileLock()
    }
}

data class ProfileRecord(
    val id: String,
    val displayName: String,
    val colorHex: String,
    val createdAt: Long,
    val lastActiveAt: Long,
    val lock: ProfileLock = ProfileLock.NONE,
    /** 綁定的 Google 帳號（小寫）。一個帳號只能綁一個設定檔 —— 範例筆記的 id 是固定的。 */
    val googleEmail: String? = null
) {
    val isDefault: Boolean get() = id == DEFAULT_ID

    companion object {
        const val DEFAULT_ID = "default"
    }
}

class ProfileException(val kind: Kind, val profileName: String? = null) : Exception(kind.name) {
    enum class Kind {
        /** 已經有 [ProfileRegistry.MAX_PROFILES] 個設定檔。 */
        LIMIT_REACHED,
        INVALID_NAME,
        DUPLICATE_NAME,
        NOT_FOUND,
        /** 不能刪掉最後一個設定檔 —— 沒有設定檔就沒有地方放資料。 */
        LAST_PROFILE,
        /** 這個 Google 帳號已經綁在另一個設定檔上（[profileName] 是那個設定檔的名稱）。 */
        GOOGLE_ALREADY_BOUND,
        INVALID_PIN,
        PIN_REQUIRED,
        WRONG_PIN,

        /** PIN 格式沒問題，但存不進去（金鑰庫拒絕）。與 INVALID_PIN 分開，理由同 Apple 端。 */
        PIN_STORAGE_FAILED,

        /** 預設設定檔對應升級前就存在的那一份資料，不能刪。 */
        CANNOT_DELETE_DEFAULT,

        /** 要刪的是正在使用的設定檔：先切到別的。 */
        CANNOT_DELETE_ACTIVE
    }
}

/** 所有設定檔與「現在是哪一個」。 */
class ProfileRegistry private constructor(
    profiles: List<ProfileRecord>,
    activeId: String
) {
    private val list = profiles.toMutableList()

    var activeId: String = activeId
        private set

    val profiles: List<ProfileRecord> get() = list.toList()

    val active: ProfileRecord get() = list.firstOrNull { it.id == activeId } ?: list[0]

    val canAdd: Boolean get() = list.size < MAX_PROFILES

    fun profile(id: String): ProfileRecord? = list.firstOrNull { it.id == id }

    /** 綁著這個 Google 帳號的設定檔（有的話）。 */
    fun profileBoundTo(email: String): ProfileRecord? {
        val key = normalizedEmail(email)
        if (key.isEmpty()) return null
        return list.firstOrNull { it.googleEmail == key }
    }

    /** 新增一個設定檔。回傳新設定檔（**不會**自動切過去）。 */
    fun add(
        displayName: String,
        colorHex: String? = null,
        now: Long = System.currentTimeMillis(),
        id: String = java.util.UUID.randomUUID().toString().lowercase()
    ): ProfileRecord {
        if (!canAdd) throw ProfileException(ProfileException.Kind.LIMIT_REACHED)
        val name = validatedName(displayName)
        val used = list.map { it.colorHex }.toSet()
        val color = colorHex ?: PALETTE.firstOrNull { it !in used } ?: DEFAULT_COLOR
        val record = ProfileRecord(id, name, color, now, now)
        list.add(record)
        return record
    }

    fun rename(id: String, displayName: String) {
        val name = validatedName(displayName, excluding = id)
        val index = indexOf(id)
        list[index] = list[index].copy(displayName = name)
    }

    fun setColor(id: String, hex: String) {
        val index = indexOf(id)
        list[index] = list[index].copy(colorHex = hex)
    }

    /**
     * 刪除設定檔。刪掉的若是目前使用的，改成最近用過的另一個。
     * 呼叫端負責**實際清掉資料**（檔案、偏好設定、金鑰）—— 這裡只管名單。
     */
    fun remove(id: String): ProfileRecord {
        val index = indexOf(id)
        if (list.size <= 1) throw ProfileException(ProfileException.Kind.LAST_PROFILE)
        if (id == ProfileRecord.DEFAULT_ID) throw ProfileException(ProfileException.Kind.CANNOT_DELETE_DEFAULT)
        val removed = list.removeAt(index)
        if (activeId == id) {
            activeId = list.maxByOrNull { it.lastActiveAt }?.id ?: list[0].id
        }
        return removed
    }

    fun activate(id: String, now: Long = System.currentTimeMillis()) {
        val index = indexOf(id)
        activeId = id
        list[index] = list[index].copy(lastActiveAt = now)
    }

    fun setLock(id: String, lock: ProfileLock) {
        val index = indexOf(id)
        list[index] = list[index].copy(lock = lock.normalized())
    }

    /** 把 Google 帳號綁到設定檔。已經綁在**別的**設定檔上就拒絕。 */
    fun bindGoogle(email: String, id: String) {
        val key = normalizedEmail(email)
        val index = indexOf(id)
        if (key.isEmpty()) return
        val other = list.firstOrNull { it.googleEmail == key && it.id != id }
        if (other != null) {
            throw ProfileException(ProfileException.Kind.GOOGLE_ALREADY_BOUND, other.displayName)
        }
        list[index] = list[index].copy(googleEmail = key)
    }

    fun unbindGoogle(id: String) {
        val index = list.indexOfFirst { it.id == id }
        if (index >= 0) list[index] = list[index].copy(googleEmail = null)
    }

    private fun indexOf(id: String): Int {
        val index = list.indexOfFirst { it.id == id }
        if (index < 0) throw ProfileException(ProfileException.Kind.NOT_FOUND)
        return index
    }

    private fun validatedName(raw: String, excluding: String? = null): String {
        val name = raw.trim()
        if (name.isEmpty() || name.length > MAX_NAME_LENGTH) {
            throw ProfileException(ProfileException.Kind.INVALID_NAME)
        }
        val clash = list.any { it.id != excluding && it.displayName.equals(name, ignoreCase = true) }
        if (clash) throw ProfileException(ProfileException.Kind.DUPLICATE_NAME)
        return name
    }

    /**
     * 載入後的自我修復：名單不能是空的、使用中的 id 必須存在、同一個 Google 帳號不能出現兩次。
     * 檔案可能被舊版、手動編輯或半途寫壞 —— 寧可修成一個合法狀態，也不要讓 App 開不起來。
     */
    fun repaired(fallbackName: String, fallbackColor: String): ProfileRegistry {
        if (list.isEmpty()) return initial(fallbackName, fallbackColor)
        val seen = mutableSetOf<String>()
        var fixed = list.filter { seen.add(it.id) }.toMutableList()
        val bound = mutableSetOf<String>()
        for (i in fixed.indices) {
            val email = fixed[i].googleEmail ?: continue
            if (!bound.add(email)) fixed[i] = fixed[i].copy(googleEmail = null)
        }
        if (fixed.size > MAX_PROFILES) fixed = fixed.take(MAX_PROFILES).toMutableList()
        val active = if (fixed.any { it.id == activeId }) activeId else fixed[0].id
        return ProfileRegistry(fixed, active)
    }

    // ── 存檔 ────────────────────────────────────────────────

    fun toJson(): String {
        val array = JSONArray()
        for (p in list) {
            array.put(
                JSONObject()
                    .put("id", p.id)
                    .put("displayName", p.displayName)
                    .put("colorHex", p.colorHex)
                    .put("createdAt", p.createdAt)
                    .put("lastActiveAt", p.lastActiveAt)
                    .put("hasPin", p.lock.hasPin)
                    .put("useBiometrics", p.lock.useBiometrics)
                    .put("googleEmail", p.googleEmail ?: JSONObject.NULL)
            )
        }
        return JSONObject().put("activeId", activeId).put("profiles", array).toString()
    }

    override fun equals(other: Any?): Boolean =
        other is ProfileRegistry && other.activeId == activeId && other.list == list

    override fun hashCode(): Int = 31 * activeId.hashCode() + list.hashCode()

    companion object {
        const val MAX_PROFILES = 5
        const val MAX_NAME_LENGTH = 24

        /** 與 Apple 端的 `IdentityPalette.hexes` 同一組（見 `AccountManager.PALETTE`）。 */
        val PALETTE = listOf(
            "#007AFF", "#34C759", "#AF52DE", "#FF9500",
            "#FF2D55", "#5856D6", "#00C7BE", "#A2845E"
        )
        const val DEFAULT_COLOR = "#007AFF"

        /** 第一次使用：只有預設設定檔（它對應既有的資料）。 */
        fun initial(displayName: String, colorHex: String, now: Long = System.currentTimeMillis()): ProfileRegistry {
            val name = displayName.trim().ifEmpty { "Kairumo" }
            val record = ProfileRecord(ProfileRecord.DEFAULT_ID, name, colorHex, now, now)
            return ProfileRegistry(listOf(record), record.id)
        }

        fun normalizedEmail(email: String) = email.trim().lowercase()

        /** 讀不懂就回 `null`（呼叫端再決定要建立初始名單，還是先把壞檔留一份）。 */
        fun fromJson(json: String): ProfileRegistry? = try {
            val root = JSONObject(json)
            val array = root.getJSONArray("profiles")
            val records = (0 until array.length()).map { i ->
                val o = array.getJSONObject(i)
                ProfileRecord(
                    id = o.getString("id"),
                    displayName = o.getString("displayName"),
                    colorHex = o.getString("colorHex"),
                    createdAt = o.getLong("createdAt"),
                    lastActiveAt = o.getLong("lastActiveAt"),
                    lock = ProfileLock(o.optBoolean("hasPin"), o.optBoolean("useBiometrics")).normalized(),
                    googleEmail = if (o.isNull("googleEmail")) null else o.getString("googleEmail")
                )
            }
            ProfileRegistry(records, root.getString("activeId"))
        } catch (e: Exception) {
            null
        }
    }
}
