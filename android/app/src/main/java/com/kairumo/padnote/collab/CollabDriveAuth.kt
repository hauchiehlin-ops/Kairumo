package com.kairumo.padnote.collab

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.browser.customtabs.CustomTabsIntent
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.withTimeoutOrNull
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import uniffi.padnote_core.FfiOAuthPlatform
import uniffi.padnote_core.FfiTokenSet
import uniffi.padnote_core.oauthCollabAuthorizeUrl
import uniffi.padnote_core.oauthExchangeBody
import uniffi.padnote_core.oauthIsAccessValid
import uniffi.padnote_core.oauthNeedsReauth
import uniffi.padnote_core.oauthNewPkce
import uniffi.padnote_core.oauthParseCallback
import uniffi.padnote_core.oauthParsePickedIds
import uniffi.padnote_core.oauthParseTokenResponse
import uniffi.padnote_core.oauthRefreshBody
import uniffi.padnote_core.oauthTokenEndpoint

/**
 * 雲端協作的憑證（`drive.file`）。與主帳號同步用的 `drive.appdata` **分開存放**：
 * Google 的挑選器規定只能要 `drive.file` 一個權限。與 Apple `CollabDriveAuth` 相同。
 *
 * 授權走 Custom Tabs，回來的重導向由 `OAuthRedirectActivity` 交給 [ownsState] 判斷是誰的。
 */
// profile-scope: device 權杖存在依設定檔命名的加密偏好檔裡；切換設定檔會重啟行程，記憶體狀態不跨設定檔
object CollabDriveAuth {
    private const val PREFS = "kairumo_collab_drive"
    private const val KEY_ACCESS = "access"
    private const val KEY_REFRESH = "refresh"
    private const val KEY_EXPIRES = "expires"
    private const val KEY_VERIFIER = "verifier"
    private const val KEY_STATE = "state"
    private val http = OkHttpClient()

    data class Outcome(val ok: Boolean, val picked: List<String> = emptyList(), val error: String = "")

    @Volatile private var waiting: CompletableDeferred<Outcome>? = null

    private fun prefs(context: Context): android.content.SharedPreferences {
        val name = com.kairumo.padnote.profile.ProfileContext.prefsName(
            PREFS, com.kairumo.padnote.profile.ProfileContext.activeId(context))
        return runCatching {
            val key = MasterKey.Builder(context).setKeyScheme(MasterKey.KeyScheme.AES256_GCM).build()
            EncryptedSharedPreferences.create(
                context, name, key,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
            )
        }.getOrElse { context.getSharedPreferences(name, Context.MODE_PRIVATE) }
    }

    private fun tokens(context: Context): FfiTokenSet {
        val p = prefs(context)
        return FfiTokenSet(
            accessToken = p.getString(KEY_ACCESS, "") ?: "",
            refreshToken = p.getString(KEY_REFRESH, "") ?: "",
            expiresAtS = p.getLong(KEY_EXPIRES, 0L).toULong(),
            error = ""
        )
    }

    fun isAuthorized(context: Context): Boolean = tokens(context).refreshToken.isNotEmpty()

    /**
     * 開 Google 授權（`pickFolderId` 有值時是挑選器，預選那個資料夾），等它回來。
     * 使用者五分鐘內沒完成就當成取消。
     */
    suspend fun authorize(activity: Activity, pickFolderId: String = "", loginHint: String = ""): Outcome {
        val pkce = oauthNewPkce()
        if (pkce.verifier.isEmpty()) return Outcome(false, error = "random_unavailable")
        prefs(activity).edit().putString(KEY_VERIFIER, pkce.verifier).putString(KEY_STATE, pkce.state).commit()
        val deferred = CompletableDeferred<Outcome>()
        waiting = deferred
        val url = oauthCollabAuthorizeUrl(FfiOAuthPlatform.ANDROID, pkce.challenge, pkce.state, loginHint, pickFolderId)
        CustomTabsIntent.Builder().setShowTitle(true).build().launchUrl(activity, Uri.parse(url))
        return withTimeoutOrNull(5 * 60_000L) { deferred.await() } ?: Outcome(false, error = "cancelled")
    }

    /** 這個重導向是不是協作授權的（比對 state）。 */
    fun ownsState(context: Context, intent: Intent): Boolean {
        val data = intent.data ?: return false
        val expected = prefs(context).getString(KEY_STATE, "") ?: ""
        return expected.isNotEmpty() && oauthParseCallback(data.toString()).state == expected
    }

    /** 處理重導向（背景執行緒）。結果交給正在等的 [authorize]。 */
    fun handleRedirect(context: Context, intent: Intent) {
        val url = intent.data?.toString().orEmpty()
        val callback = oauthParseCallback(url)
        val p = prefs(context)
        val expected = p.getString(KEY_STATE, "") ?: ""
        val verifier = p.getString(KEY_VERIFIER, "") ?: ""
        p.edit().remove(KEY_STATE).remove(KEY_VERIFIER).commit()
        val outcome = when {
            callback.error.isNotEmpty() -> Outcome(false, error = callback.error)
            expected.isEmpty() || callback.state != expected -> Outcome(false, error = "state_mismatch")
            callback.code.isEmpty() || verifier.isEmpty() -> Outcome(false, error = "missing_code")
            else -> post(oauthExchangeBody(FfiOAuthPlatform.ANDROID, callback.code, verifier)).fold(
                onSuccess = { json ->
                    val t = oauthParseTokenResponse(json, nowS())
                    if (t.error.isNotEmpty()) Outcome(false, error = t.error) else {
                        save(context, t, tokens(context).refreshToken)
                        Outcome(true, oauthParsePickedIds(url))
                    }
                },
                onFailure = { Outcome(false, error = "network_error") }
            )
        }
        waiting?.complete(outcome)
        waiting = null
    }

    /** 一個能用的 access token；必要時換證。null = 要重新授權。**背景執行緒呼叫。** */
    fun validAccessToken(context: Context): String? {
        val current = tokens(context)
        if (oauthIsAccessValid(current, nowS())) return current.accessToken
        return refresh(context).token
    }

    /** 換證。失敗**不會**影響主帳號。 */
    fun refresh(context: Context): com.kairumo.padnote.oauth.GoogleAuth.RefreshOutcome {
        val current = tokens(context)
        if (current.refreshToken.isEmpty()) return com.kairumo.padnote.oauth.GoogleAuth.RefreshOutcome(null, true)
        val json = post(oauthRefreshBody(FfiOAuthPlatform.ANDROID, current.refreshToken)).getOrNull()
            ?: return com.kairumo.padnote.oauth.GoogleAuth.RefreshOutcome(null, false)
        val refreshed = oauthParseTokenResponse(json, nowS())
        if (refreshed.error.isNotEmpty()) {
            val fatal = oauthNeedsReauth(refreshed.error) || refreshed.error.contains("invalid_grant")
            if (fatal) prefs(context).edit().remove(KEY_ACCESS).remove(KEY_REFRESH).apply()
            return com.kairumo.padnote.oauth.GoogleAuth.RefreshOutcome(null, fatal)
        }
        save(context, refreshed, current.refreshToken)
        return com.kairumo.padnote.oauth.GoogleAuth.RefreshOutcome(refreshed.accessToken, false)
    }

    /** 給核心用的 HTTP（換證走協作憑證）。**背景執行緒呼叫。** */
    fun makeHttp(context: Context): com.kairumo.padnote.oauth.DriveHttpClient? {
        val token = validAccessToken(context) ?: return null
        val app = context.applicationContext
        return com.kairumo.padnote.oauth.DriveHttpClient(token, refresher = { refresh(app) })
    }

    private fun save(context: Context, t: FfiTokenSet, previousRefresh: String) {
        prefs(context).edit()
            .putString(KEY_ACCESS, t.accessToken)
            .putString(KEY_REFRESH, t.refreshToken.ifEmpty { previousRefresh })
            .putLong(KEY_EXPIRES, t.expiresAtS.toLong())
            .apply()
    }

    private fun post(body: String): Result<String> = runCatching {
        val request = Request.Builder()
            .url(oauthTokenEndpoint())
            .post(body.toRequestBody("application/x-www-form-urlencoded".toMediaType()))
            .build()
        http.newCall(request).execute().use { it.body?.string() ?: error("empty_body") }
    }

    private fun nowS(): ULong = (System.currentTimeMillis() / 1000).toULong()
}
