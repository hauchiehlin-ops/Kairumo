package com.kairumo.padnote.profile

import android.app.Activity
import android.content.Context
import android.content.SharedPreferences

/** 記憶體裡的 SharedPreferences（JVM 單元測試的 android.jar 是空殼，沒有真的實作）。 */
class FakeSharedPreferences : SharedPreferences {
    val map = mutableMapOf<String, Any?>()
    var commitFails = false

    override fun getAll(): MutableMap<String, *> = map.toMutableMap()
    override fun getString(key: String?, defValue: String?) = (map[key] as? String) ?: defValue
    override fun getStringSet(key: String?, defValues: MutableSet<String>?): MutableSet<String>? =
        @Suppress("UNCHECKED_CAST") ((map[key] as? MutableSet<String>) ?: defValues)
    override fun getInt(key: String?, defValue: Int) = (map[key] as? Int) ?: defValue
    override fun getLong(key: String?, defValue: Long) = (map[key] as? Long) ?: defValue
    override fun getFloat(key: String?, defValue: Float) = (map[key] as? Float) ?: defValue
    override fun getBoolean(key: String?, defValue: Boolean) = (map[key] as? Boolean) ?: defValue
    override fun contains(key: String?) = map.containsKey(key)
    override fun registerOnSharedPreferenceChangeListener(l: SharedPreferences.OnSharedPreferenceChangeListener?) {}
    override fun unregisterOnSharedPreferenceChangeListener(l: SharedPreferences.OnSharedPreferenceChangeListener?) {}

    override fun edit(): SharedPreferences.Editor = object : SharedPreferences.Editor {
        private val pending = mutableMapOf<String, Any?>()
        private val removals = mutableSetOf<String>()
        private var clear = false
        override fun putString(key: String, value: String?) = apply { pending[key] = value }
        override fun putStringSet(key: String, values: MutableSet<String>?) = apply { pending[key] = values }
        override fun putInt(key: String, value: Int) = apply { pending[key] = value }
        override fun putLong(key: String, value: Long) = apply { pending[key] = value }
        override fun putFloat(key: String, value: Float) = apply { pending[key] = value }
        override fun putBoolean(key: String, value: Boolean) = apply { pending[key] = value }
        override fun remove(key: String) = apply { removals += key }
        override fun clear() = apply { clear = true }
        override fun commit(): Boolean {
            if (commitFails) return false
            apply()
            return true
        }
        override fun apply() {
            if (clear) map.clear()
            removals.forEach { map.remove(it) }
            map.putAll(pending)
        }
    }
}

/** 一個 Activity 的替身：每個偏好檔名各一份記憶體偏好，`applicationContext` 就是自己。 */
class FakeActivity : Activity() {
    val prefsByName = mutableMapOf<String, FakeSharedPreferences>()

    /** 假的應用程式資料夾：files／cache／app_profiles／shared_prefs 都在這底下。 */
    val root: java.io.File = java.nio.file.Files.createTempDirectory("fake-activity").toFile()
    private val filesRoot = java.io.File(root, "files").also { it.mkdirs() }
    private val cacheRoot = java.io.File(root, "cache").also { it.mkdirs() }
    private val appInfo = android.content.pm.ApplicationInfo().also { it.dataDir = root.path }

    fun prefs(name: String) = prefsByName.getOrPut(name) { FakeSharedPreferences() }

    /** 把偏好檔也落成真的檔案（`ownedPrefsNames` 掃的是 shared_prefs/ 底下的檔名）。 */
    private fun touchPrefsFile(name: String) {
        val dir = java.io.File(root, "shared_prefs").also { it.mkdirs() }
        java.io.File(dir, "$name.xml").writeText("<map/>")
    }

    override fun getSharedPreferences(name: String?, mode: Int): SharedPreferences {
        if (name != null) touchPrefsFile(name)
        return prefs(name ?: "")
    }

    override fun deleteSharedPreferences(name: String?): Boolean {
        prefsByName.remove(name)
        return java.io.File(java.io.File(root, "shared_prefs"), "$name.xml").delete()
    }

    override fun getApplicationContext(): Context = this
    override fun getFilesDir(): java.io.File = filesRoot
    override fun getCacheDir(): java.io.File = cacheRoot
    override fun getDir(name: String?, mode: Int): java.io.File = java.io.File(root, "app_$name").also { it.mkdirs() }
    override fun getApplicationInfo(): android.content.pm.ApplicationInfo = appInfo
}
