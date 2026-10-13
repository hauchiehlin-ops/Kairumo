package com.kairumo.padnote.account

import android.content.Context
import android.content.ContextWrapper
import android.content.SharedPreferences
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test
import java.lang.reflect.Proxy

class AccountManagerTest {

    private class FakeContext(private val prefs: SharedPreferences) : ContextWrapper(null) {
        override fun getSharedPreferences(name: String?, mode: Int): SharedPreferences = prefs

        // 偏好設定現在經過 `ProfileContext.prefs`，它一律用 applicationContext 取偏好（正式環境一定有）。
        override fun getApplicationContext(): Context = this
    }

    private fun mockContext(prefsMap: MutableMap<String, Any?> = mutableMapOf()): Context {
        val editorProxy = Proxy.newProxyInstance(
            SharedPreferences.Editor::class.java.classLoader,
            arrayOf(SharedPreferences.Editor::class.java)
        ) { proxy, method, args ->
            when (method.name) {
                "putString" -> {
                    val key = args[0] as String
                    val value = args[1] as? String
                    prefsMap[key] = value
                    proxy
                }
                "putLong" -> {
                    val key = args[0] as String
                    val value = args[1] as Long
                    prefsMap[key] = value
                    proxy
                }
                "remove" -> {
                    val key = args[0] as String
                    prefsMap.remove(key)
                    proxy
                }
                "clear" -> {
                    prefsMap.clear()
                    proxy
                }
                "apply", "commit" -> {
                    if (method.returnType == Boolean::class.javaPrimitiveType) true else null
                }
                else -> null
            }
        } as SharedPreferences.Editor

        val sharedPrefsProxy = Proxy.newProxyInstance(
            SharedPreferences::class.java.classLoader,
            arrayOf(SharedPreferences::class.java)
        ) { _, method, args ->
            when (method.name) {
                "getString" -> {
                    val key = args[0] as String
                    val defValue = args[1] as? String
                    (prefsMap[key] as? String) ?: defValue
                }
                "getLong" -> {
                    val key = args[0] as String
                    val defValue = args[1] as Long
                    (prefsMap[key] as? Long) ?: defValue
                }
                "edit" -> editorProxy
                else -> null
            }
        } as SharedPreferences

        return FakeContext(sharedPrefsProxy)
    }

    @Test
    fun testDefaultUserWhenNotSignedIn() {
        val context = mockContext()
        val profile = AccountManager.load(context, fallbackName = "使用者")
        assertEquals("使用者", profile.displayName)
        assertFalse(AccountManager.isCloudBound(context))
    }

    @Test
    fun testSaveAndLoadCustomDisplayName() {
        val context = mockContext()
        AccountManager.saveName(context, "自訂小明", fallbackName = "使用者")
        val profile = AccountManager.load(context, fallbackName = "使用者")
        assertEquals("自訂小明", profile.displayName)
        assertEquals("自訂小明", AccountManager.customName(context, "使用者"))
    }

    @Test
    fun testBlankNameFallsBackToDefault() {
        val context = mockContext()
        AccountManager.saveName(context, "   ", fallbackName = "使用者")
        val profile = AccountManager.load(context, fallbackName = "使用者")
        assertEquals("使用者", profile.displayName)
    }

    @Test
    fun testCloudAccountNameOverridesCustomNameWhenSignedIn() {
        val context = mockContext()
        AccountManager.saveName(context, "自訂小明", fallbackName = "使用者")
        // 啟用 FakeDrive 模擬已登入 Google Drive
        System.setProperty("kairumo.fakeDrive", "http://127.0.0.1:8765")
        try {
            org.junit.Assert.assertTrue(AccountManager.isCloudBound(context))
            val profile = AccountManager.load(context, fallbackName = "使用者")
            assertEquals("Fake Drive User", profile.displayName)

            // 設定實際 Google 帳號名稱
            com.kairumo.padnote.library.SyncHistory.setAccountName(context, "張大千")
            val profileWithRealName = AccountManager.load(context, fallbackName = "使用者")
            assertEquals("張大千", profileWithRealName.displayName)
        } finally {
            System.clearProperty("kairumo.fakeDrive")
            com.kairumo.padnote.library.SyncHistory.setAccountName(context, null)
        }

        // 登出後維持現狀（使用自訂名稱）
        assertFalse(AccountManager.isCloudBound(context))
        val profileAfterSignOut = AccountManager.load(context, fallbackName = "使用者")
        assertEquals("自訂小明", profileAfterSignOut.displayName)
    }
}
