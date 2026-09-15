package com.kairumo.padnote.oauth

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.browser.customtabs.CustomTabsIntent
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import java.io.IOException
import okhttp3.FormBody
import okhttp3.OkHttpClient
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import uniffi.padnote_core.FfiOAuthPlatform
import uniffi.padnote_core.FfiTokenSet
import uniffi.padnote_core.oauthAuthorizeUrl
import uniffi.padnote_core.oauthExchangeBody
import uniffi.padnote_core.oauthIsAccessValid
import uniffi.padnote_core.oauthNeedsReauth
import uniffi.padnote_core.oauthNewPkce
import uniffi.padnote_core.oauthParseCallback
import uniffi.padnote_core.oauthParseTokenResponse
import uniffi.padnote_core.oauthRefreshBody
import uniffi.padnote_core.oauthRevokeUrl
import uniffi.padnote_core.oauthTokenEndpoint

/**
 * Google 授權（Android，G-01 / ADR-0011）。
 *
 * # 核心負責「送什麼」，這裡負責「怎麼送」
 *
 * PKCE 怎麼算、redirect URI 長什麼樣、交換權杖要帶哪些欄位，全部在核心
 * （`ffi_oauth`）—— 任何一項兩邊寫得不一樣，Google 只會回一句
 * `invalid_grant`，而那句話對「哪裡不一樣」毫無提示。
 *
 * 這個檔案只做三件 Android 非做不可的事：開 Custom Tabs、打 HTTP、
 * 把權杖放進加密儲存區。
 *
 * # 為什麼是 Custom Tabs 而不是 WebView
 *
 * Google **會拒絕**在 WebView 裡完成的 OAuth（`disallowed_useragent`）。
 * 而且 WebView 拿不到使用者已登入的 Google session，每次都要重打密碼。
 */
object GoogleAuth {

    private const val PREFS = "kairumo_oauth"
    private const val KEY_ACCESS = "access_token"
    private const val KEY_REFRESH = "refresh_token"
    private const val KEY_EXPIRES = "expires_at_s"
    private const val KEY_VERIFIER = "pending_verifier"
    private const val KEY_STATE = "pending_state"

    private val http = OkHttpClient()
    private val FORM_MEDIA_TYPE = "application/x-www-form-urlencoded".toMediaType()

    /**
     * 權杖存在**加密**的 SharedPreferences。
     *
     * refresh token 等同「不必再問密碼就能存取使用者雲端硬碟」的長期憑證。
     * 一般 SharedPreferences 是明文 XML，root 過的裝置或備份都讀得到。
     *
     * 建不起來（極舊裝置、Keystore 損壞）時回 null，呼叫端退化成「不保存」——
     * 使用者每次都要重新登入，但**不會**把長期憑證明文寫到硬碟上。
     */
    private fun store(context: Context) = runCatching {
        val key = MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        EncryptedSharedPreferences.create(
            context,
            PREFS,
            key,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    }.getOrNull()

    /** 目前存著的權杖。沒登入過時每個欄位都是空的。 */
    fun tokens(context: Context): FfiTokenSet {
        val p = store(context)
        return FfiTokenSet(
            accessToken = p?.getString(KEY_ACCESS, "") ?: "",
            refreshToken = p?.getString(KEY_REFRESH, "") ?: "",
            expiresAtS = (p?.getLong(KEY_EXPIRES, 0L) ?: 0L).toULong(),
            error = ""
        )
    }

    fun isSignedIn(context: Context): Boolean = tokens(context).refreshToken.isNotEmpty()

    /**
     * 開始授權。把使用者丟進 Custom Tabs。
     *
     * PKCE 的 verifier 與 state 要**先存起來**，因為授權跳出去之後這個
     * process 可能會被系統回收；回來時要拿它們驗證與交換權杖。
     */
    fun startSignIn(activity: Activity, loginHint: String = "") {
        val pkce = oauthNewPkce()
        if (pkce.verifier.isEmpty()) return  // 亂數失敗，寧可不授權

        store(activity)?.edit()
            ?.putString(KEY_VERIFIER, pkce.verifier)
            ?.putString(KEY_STATE, pkce.state)
            ?.apply()

        val url = oauthAuthorizeUrl(
            FfiOAuthPlatform.ANDROID,
            pkce.challenge,
            pkce.state,
            loginHint
        )
        CustomTabsIntent.Builder().build().launchUrl(activity, Uri.parse(url))
    }

    /**
     * 處理授權跳回來的 Intent。回傳給使用者看的結果。
     *
     * 會**比對 state**。不比對的話，別人可以誘導 App 去交換一個攻擊者取得的
     * 授權碼，結果是資料同步到攻擊者的雲端硬碟。
     */
    fun handleRedirect(context: Context, intent: Intent): Result<Unit> {
        val data = intent.data ?: return Result.failure(IllegalStateException("no_redirect_data"))
        val callback = oauthParseCallback(data.toString())
        val p = store(context)

        val expectedState = p?.getString(KEY_STATE, "") ?: ""
        val verifier = p?.getString(KEY_VERIFIER, "") ?: ""
        // 用完就清掉，不管成功失敗 —— 一組 PKCE 只能用一次。
        p?.edit()?.remove(KEY_STATE)?.remove(KEY_VERIFIER)?.apply()

        if (callback.error.isNotEmpty()) {
            // 使用者按「取消」也走這裡，那不是當機。
            return Result.failure(IllegalStateException(callback.error))
        }
        if (expectedState.isEmpty() || callback.state != expectedState) {
            return Result.failure(IllegalStateException("state_mismatch"))
        }
        if (callback.code.isEmpty() || verifier.isEmpty()) {
            return Result.failure(IllegalStateException("missing_code"))
        }

        val body = oauthExchangeBody(FfiOAuthPlatform.ANDROID, callback.code, verifier)
        return post(body).mapCatching { json ->
            val tokens = oauthParseTokenResponse(json, nowSeconds())
            if (tokens.error.isNotEmpty()) throw IllegalStateException(tokens.error)
            save(context, tokens, previousRefresh = "")
        }
    }

    /**
     * 拿一個能用的 access token，必要時先更新。
     *
     * 回 null 代表**要請使用者重新登入**，不是「等一下再試」——
     * 兩者混在一起會變成無限重試的背景迴圈，而使用者只看到「同步失敗」
     * 卻不知道該去登入。專案還在 Testing 狀態時，refresh token 七天就會到這裡。
     */
    fun validAccessToken(context: Context): String? {
        val current = tokens(context)
        if (oauthIsAccessValid(current, nowSeconds())) return current.accessToken
        if (current.refreshToken.isEmpty()) return null

        val json = post(oauthRefreshBody(FfiOAuthPlatform.ANDROID, current.refreshToken))
            .getOrNull() ?: return null
        val refreshed = oauthParseTokenResponse(json, nowSeconds())
        if (refreshed.error.isNotEmpty()) {
            if (oauthNeedsReauth(refreshed.error)) signOutLocally(context)
            return null
        }
        // 更新回應通常**沒有** refresh_token，要沿用舊的 ——
        // 覆蓋成空字串的話下一次就再也更新不了。
        save(context, refreshed, previousRefresh = current.refreshToken)
        return refreshed.accessToken
    }

    /**
     * 登出並**撤銷**授權。
     *
     * 只清本機權杖是不夠的：授權還留在使用者的 Google 帳號裡，
     * 他在帳號設定裡看得到一個「已授權但我明明登出了」的項目。
     */
    fun signOut(context: Context) {
        val refresh = tokens(context).refreshToken
        if (refresh.isNotEmpty()) {
            runCatching {
                http.newCall(
                    Request.Builder().url(oauthRevokeUrl(refresh)).post(FormBody.Builder().build()).build()
                ).execute().close()
            }
        }
        signOutLocally(context)
    }

    private fun signOutLocally(context: Context) {
        store(context)?.edit()?.clear()?.apply()
    }

    private fun save(context: Context, tokens: FfiTokenSet, previousRefresh: String) {
        val refresh = tokens.refreshToken.ifEmpty { previousRefresh }
        store(context)?.edit()
            ?.putString(KEY_ACCESS, tokens.accessToken)
            ?.putString(KEY_REFRESH, refresh)
            ?.putLong(KEY_EXPIRES, tokens.expiresAtS.toLong())
            ?.apply()
    }

    /** 送出 token endpoint 的 POST。回應原樣交給核心解析。 */
    private fun post(body: String): Result<String> = runCatching {
        val request = Request.Builder()
            .url(oauthTokenEndpoint())
            .post(body.toRequestBody(FORM_MEDIA_TYPE))
            .build()
        http.newCall(request).execute().use { response ->
            // **錯誤回應的內容也要交給核心**：Google 把 `invalid_grant`
            // 放在 body 裡，只看 HTTP 狀態碼的話分不出「該重新登入」與
            // 「網路壞了」。
            response.body?.string() ?: throw IOException("empty_body")
        }
    }

    private fun nowSeconds(): ULong = (System.currentTimeMillis() / 1000).toULong()
}
