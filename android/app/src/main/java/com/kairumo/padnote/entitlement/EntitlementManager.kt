package com.kairumo.padnote.entitlement

import android.app.Activity
import android.content.Context
import android.util.Base64
import androidx.activity.ComponentActivity
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.android.billingclient.api.AcknowledgePurchaseParams
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.PurchasesUpdatedListener
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryPurchasesParams
import com.kairumo.padnote.LocalizationStrings
import com.kairumo.padnote.ink.InkTool
import com.kairumo.padnote.profile.ProfileContext
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.math.BigInteger
import java.security.MessageDigest

/**
 * Kairumo Pro 專業版功能分類（用於 Paywall 聚焦高亮與功能卡片展示，與 Apple 端 `ProFeatureGate` 完全對齊）。
 */
enum class ProFeatureGate(
    val id: String,
    val iconGlyph: String,
    val titleKey: String,
    val descKey: String
) {
    STUDIOS(
        id = "studios",
        iconGlyph = "∑",
        titleKey = "paywall_feature_studios_title",
        descKey = "paywall_feature_studios_desc"
    ),
    DRAFTING_TOOLS(
        id = "draftingTools",
        iconGlyph = "📐",
        titleKey = "paywall_feature_drafting_title",
        descKey = "paywall_feature_drafting_desc"
    ),
    TRANSLATION_PEN(
        id = "translationPen",
        iconGlyph = "🌐",
        titleKey = "paywall_feature_translation_pen_title",
        descKey = "paywall_feature_translation_pen_desc"
    ),
    PRO_INK_AND_THEMES(
        id = "proInkAndThemes",
        iconGlyph = "🎨",
        titleKey = "paywall_feature_pro_ink_title",
        descKey = "paywall_feature_pro_ink_desc"
    ),
    AUDIO_TRANSCRIPTION(
        id = "audioTranscription",
        iconGlyph = "🎙",
        titleKey = "paywall_feature_audio_transcribe_title",
        descKey = "paywall_feature_audio_transcribe_desc"
    ),
    COLLAB_HOST(
        id = "collabHost",
        iconGlyph = "📡",
        titleKey = "paywall_feature_collab_host_title",
        descKey = "paywall_feature_collab_host_desc"
    )
}

/**
 * 筆刷工具是否屬於 Pro 專業版進階工具（與 Apple 端 `InkTool.isProRequired` 完全對齊）。
 *
 * 免費基礎版永遠開放：
 * - 鋼筆（PEN）、螢光筆（HIGHLIGHTER）、鉛筆（PENCIL）
 * - 橡皮擦（ERASER）、套索（LASSO）
 * - 遮罩膠帶（TAPE，學習遮罩核心亮點）
 */
val InkTool.isProRequired: Boolean
    get() = when (this) {
        InkTool.FOUNTAIN_PEN,
        InkTool.BALLPOINT,
        InkTool.HIGHLIGHTER,
        InkTool.PENCIL,
        InkTool.ERASER,
        InkTool.LASSO,
        InkTool.MASKING_TAPE -> false
        InkTool.FINELINER,
        InkTool.BRUSH,
        InkTool.CALLIGRAPHY,
        InkTool.CHARCOAL,
        InkTool.CRAYON,
        InkTool.AIRBRUSH,
        InkTool.OIL_PAINT,
        InkTool.WATERCOLOR,
        InkTool.MARKER,
        InkTool.TRANSLATION_PEN,
        InkTool.DRAFTING -> true
    }

/** 點擊未解鎖筆刷時對應高亮的 Pro 功能分類。 */
val InkTool.proFeatureGate: ProFeatureGate
    get() = when (this) {
        InkTool.DRAFTING -> ProFeatureGate.DRAFTING_TOOLS
        InkTool.TRANSLATION_PEN -> ProFeatureGate.TRANSLATION_PEN
        else -> ProFeatureGate.PRO_INK_AND_THEMES
    }

/**
 * 離線 Ed25519 簽章之 VIP 禮遇通行證 Payload（由 `scripts/issue-vip-gift.py` 簽發）。
 */
data class VIPGiftPayload(
    val sub: String,
    val tier: String,
    val iat: Long,
    val exp: Long? = null
)

/**
 * 二段式無打擾輕提示（Nudge Toast）狀態。
 */
data class ProNudgeNotice(
    val feature: ProFeatureGate,
    val itemName: String,
    val timestampMs: Long = System.currentTimeMillis()
)

// profile-scope: device Pro 買斷授權與 VIP 禮遇通行證屬於整台裝置／Google 帳號共用，跨設定檔共享
object EntitlementManager {
    /** Google Play Console 內購商品 ID（非消耗型終身買斷，與 Apple StoreKit 2 對齊） */
    const val PRO_LIFETIME_PRODUCT_ID = "com.kairumo.padnote.pro.lifetime"

    /**
     * Kairumo 官方 VIP 禮遇通行證 Ed25519 公鑰（Base64 32 bytes）。
     * 私鑰僅由開發者本機安全保存並透過 `scripts/issue-vip-gift.py` 簽發連結，App 內只含公鑰。
     */
    const val VIP_PUBLIC_KEY_BASE64 = "F+SF0OIF+lUDASUaK4Hi3Iu1kYTUmDfbmF0kdOATeYc="

    private const val PREFS_NAME = "kairumo.entitlements"
    private const val KEY_VIP_TOKEN = "kairumo.entitlement.vipToken"
    private const val KEY_PLAY_PURCHASED = "kairumo.entitlement.playPurchased"
    private const val KEY_SHOW_LOCKED_BRUSHES = "kairumo.entitlement.showLockedProBrushes"

    /** 是否已透過 Google Play Billing 解鎖 Pro */
    var isPlayBillingPurchased by mutableStateOf(false)
        private set

    /** 是否已透過 VIP 禮遇通行證解鎖 Pro */
    var isVIPUnlocked by mutableStateOf(false)
        private set

    /** VIP 禮遇通行證受贈者名稱 */
    var vipRecipientName by mutableStateOf<String?>(null)
        private set

    /** Google Play 商品顯示價格（尚未連線時顯示預設美金參考價） */
    var displayPrice by mutableStateOf("US$9.99")
        private set

    /** 是否正在執行購買或恢復交易 */
    var isPurchasing by mutableStateOf(false)
        private set

    /** Paywall 彈窗目前聚焦介紹的 Pro 功能（非 null 時顯示 PaywallDialog） */
    var activePaywallFeature by mutableStateOf<ProFeatureGate?>(null)

    /** 購買／兌換成功或錯誤的橫幅提示 */
    var feedbackBannerText by mutableStateOf<String?>(null)

    /**
     * 方案 B：二段式無打擾輕提示（首次誤觸 Pro 工具時浮現 3.5 秒膠囊，不強彈購買視窗）。
     */
    var activeNudge by mutableStateOf<ProNudgeNotice?>(null)
        private set

    /**
     * 方案 C：工具列是否展開顯示未解鎖的 Pro 進階筆刷（預設 false 收合，保持免費版工具列清爽）。
     */
    var showLockedProBrushes by mutableStateOf(false)
        private set

    /** 記錄上一次輕提示的功能與時間，用於判斷 6 秒內二次點擊直接開 Paywall */
    private var lastNudgedFeature: ProFeatureGate? = null
    private var lastNudgeTimeMs: Long = 0L
    private var nudgeDismissJob: Job? = null
    private var feedbackDismissJob: Job? = null

    private val mainScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    @Volatile
    private var initialized = false
    private var billingClient: BillingClient? = null
    private var cachedProductDetails: ProductDetails? = null

    /** 單元測試可覆寫此旗標以強制驗證免費版門禁行為 */
    internal var forceFreeForTest: Boolean = false

    /** 偵測是否處於 Android Instrumentation 測試環境（與 Apple 端 `KAIRUMO_UITEST == "1"` 對齊） */
    private val isRunningInstrumentationTest: Boolean by lazy {
        runCatching {
            val clazz = Class.forName("androidx.test.platform.app.InstrumentationRegistry")
            val method = clazz.getMethod("getArguments")
            method.invoke(null) != null
        }.getOrDefault(false)
    }

    /** 使用者是否擁有完整 Pro 專業版權限 */
    val isProUnlocked: Boolean
        get() {
            if (forceFreeForTest) return isPlayBillingPurchased || isVIPUnlocked
            if (isRunningInstrumentationTest) return true
            return isPlayBillingPurchased || isVIPUnlocked
        }

    /**
     * Activity 啟動時載入本機快取授權狀態與 Google Play Billing。
     */
    fun init(context: Context) {
        val appCtx = context.applicationContext
        val prefs = ProfileContext.devicePrefs(appCtx, PREFS_NAME)
        isPlayBillingPurchased = prefs.getBoolean(KEY_PLAY_PURCHASED, false)
        showLockedProBrushes = prefs.getBoolean(KEY_SHOW_LOCKED_BRUSHES, false)
        val savedToken = prefs.getString(KEY_VIP_TOKEN, null)
        if (!savedToken.isNullOrBlank()) {
            val payload = verifyVIPToken(savedToken)
            if (payload != null) {
                isVIPUnlocked = true
                vipRecipientName = payload.sub
            } else {
                prefs.edit().remove(KEY_VIP_TOKEN).apply()
                isVIPUnlocked = false
                vipRecipientName = null
            }
        }
        if (!initialized) {
            initialized = true
            setupBillingClient(appCtx)
        }
    }

    /**
     * 方案 C：切換工具列是否展開顯示未解鎖的 Pro 進階筆刷。
     */
    fun toggleLockedProBrushes(context: Context? = null) {
        showLockedProBrushes = !showLockedProBrushes
        context?.let {
            ProfileContext.devicePrefs(it.applicationContext, PREFS_NAME)
                .edit()
                .putBoolean(KEY_SHOW_LOCKED_BRUSHES, showLockedProBrushes)
                .apply()
        }
    }

    /**
     * 方案 C：判斷指定筆刷是否應顯示於主工具列中。
     * - 已解鎖 Pro：全部顯示
     * - 免費基礎工具：永遠顯示
     * - 未解鎖 Pro 工具：僅在 `showLockedProBrushes == true` 或目前正處於該工具時顯示
     */
    fun shouldDisplayToolInToolbar(tool: InkTool, selectedTool: InkTool): Boolean {
        if (isProUnlocked || !tool.isProRequired) return true
        if (tool == selectedTool) return true
        return showLockedProBrushes
    }

    /**
     * 方案 B：二段式無打擾輕提示。
     * - 第一次點擊未解鎖的 Pro 工具／選單項目時：只顯示底部輕量膠囊提示 3.5 秒，不強行彈出 Paywall。
     * - 6 秒內再次點擊同類 Pro 功能，或點擊膠囊上的「了解詳情」按鈕時：才正式打開 Paywall。
     */
    fun nudgeOrPresentPaywall(focus: ProFeatureGate, itemName: String? = null) {
        val now = System.currentTimeMillis()
        if (lastNudgedFeature == focus && (now - lastNudgeTimeMs) < 6_000L && activeNudge != null) {
            activeNudge = null
            nudgeDismissJob?.cancel()
            presentPaywall(focus)
            return
        }
        lastNudgedFeature = focus
        lastNudgeTimeMs = now
        val label = itemName?.takeIf { it.isNotBlank() } ?: focus.id
        val notice = ProNudgeNotice(feature = focus, itemName = label, timestampMs = now)
        activeNudge = notice
        nudgeDismissJob?.cancel()
        nudgeDismissJob = runCatching {
            if (android.os.Looper.getMainLooper() != null) {
                mainScope.launch {
                    delay(3_600L)
                    if (activeNudge?.timestampMs == notice.timestampMs) {
                        activeNudge = null
                    }
                }
            } else null
        }.getOrNull()
    }

    /** 關閉輕提示膠囊 */
    fun dismissNudge() {
        activeNudge = null
        nudgeDismissJob?.cancel()
    }

    /**
     * 檢查 Pro 權限：若已解鎖則立即執行 `perform()`，否則觸發二段式輕提示並攔截動作。
     */
    inline fun requirePro(
        focus: ProFeatureGate,
        itemName: String? = null,
        perform: () -> Unit
    ): Boolean {
        if (isProUnlocked) {
            perform()
            return true
        }
        nudgeOrPresentPaywall(focus, itemName)
        return false
    }

    /** 直接開啟 Paywall 視窗並聚焦於指定功能 */
    fun presentPaywall(focus: ProFeatureGate = ProFeatureGate.STUDIOS) {
        activeNudge = null
        nudgeDismissJob?.cancel()
        activePaywallFeature = focus
    }

    // ── Google Play Billing 整合 ──────────────────────────────

    private fun setupBillingClient(appContext: Context) {
        val listener = PurchasesUpdatedListener { billingResult, purchases ->
            if (billingResult.responseCode == BillingClient.BillingResponseCode.OK && purchases != null) {
                for (purchase in purchases) {
                    handlePurchase(appContext, purchase, showToast = true)
                }
            }
            isPurchasing = false
        }
        val client = BillingClient.newBuilder(appContext)
            .setListener(listener)
            .enablePendingPurchases()
            .build()
        billingClient = client
        connectBillingClient(appContext, client)
    }

    private fun connectBillingClient(appContext: Context, client: BillingClient) {
        runCatching {
            client.startConnection(object : BillingClientStateListener {
                override fun onBillingSetupFinished(billingResult: BillingResult) {
                    if (billingResult.responseCode == BillingClient.BillingResponseCode.OK) {
                        queryProductDetails(client)
                        queryOwnedPurchases(appContext, client, showRestoreFeedback = false)
                    }
                }

                override fun onBillingServiceDisconnected() {
                    // 下次使用者點擊購買或恢復時會再次嘗試連線
                }
            })
        }
    }

    private fun queryProductDetails(client: BillingClient) {
        val productList = listOf(
            QueryProductDetailsParams.Product.newBuilder()
                .setProductId(PRO_LIFETIME_PRODUCT_ID)
                .setProductType(BillingClient.ProductType.INAPP)
                .build()
        )
        val params = QueryProductDetailsParams.newBuilder()
            .setProductList(productList)
            .build()
        client.queryProductDetailsAsync(params) { result, detailsList ->
            if (result.responseCode == BillingClient.BillingResponseCode.OK && detailsList.isNotEmpty()) {
                val detail = detailsList.first()
                cachedProductDetails = detail
                val formatted = detail.oneTimePurchaseOfferDetails?.formattedPrice
                if (!formatted.isNullOrBlank()) {
                    mainScope.launch { displayPrice = formatted }
                }
            }
        }
    }

    private fun queryOwnedPurchases(
        appContext: Context,
        client: BillingClient,
        showRestoreFeedback: Boolean
    ) {
        val params = QueryPurchasesParams.newBuilder()
            .setProductType(BillingClient.ProductType.INAPP)
            .build()
        client.queryPurchasesAsync(params) { result, purchasesList ->
            mainScope.launch {
                if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                    var foundPro = false
                    for (purchase in purchasesList) {
                        if (purchase.products.contains(PRO_LIFETIME_PRODUCT_ID) &&
                            purchase.purchaseState == Purchase.PurchaseState.PURCHASED
                        ) {
                            foundPro = true
                            handlePurchase(appContext, purchase, showToast = showRestoreFeedback)
                        }
                    }
                    if (!foundPro && showRestoreFeedback) {
                        showFeedback(LocalizationStrings.localized("paywall_restore_nothing", "zh-Hant"))
                    }
                } else if (showRestoreFeedback) {
                    showFeedback(LocalizationStrings.localized("paywall_store_unavailable", "zh-Hant"))
                }
                isPurchasing = false
            }
        }
    }

    private fun handlePurchase(appContext: Context, purchase: Purchase, showToast: Boolean) {
        if (!purchase.products.contains(PRO_LIFETIME_PRODUCT_ID)) return
        if (purchase.purchaseState != Purchase.PurchaseState.PURCHASED) return

        if (!purchase.isAcknowledged) {
            val ackParams = AcknowledgePurchaseParams.newBuilder()
                .setPurchaseToken(purchase.purchaseToken)
                .build()
            billingClient?.acknowledgePurchase(ackParams) { }
        }

        mainScope.launch {
            isPlayBillingPurchased = true
            ProfileContext.devicePrefs(appContext, PREFS_NAME)
                .edit()
                .putBoolean(KEY_PLAY_PURCHASED, true)
                .apply()
            activePaywallFeature = null
            if (showToast) {
                showFeedback(LocalizationStrings.localized("pro_unlocked_toast", "zh-Hant"))
            }
        }
    }

    /** 發起 Google Play 終身買斷購買流程 */
    fun purchaseLifetimePro(activity: Activity, languageTag: String) {
        val appCtx = activity.applicationContext
        val client = billingClient
        if (client == null || !client.isReady) {
            if (client != null) connectBillingClient(appCtx, client)
            showFeedback(LocalizationStrings.localized("paywall_store_unavailable", languageTag))
            return
        }
        val details = cachedProductDetails
        if (details == null) {
            queryProductDetails(client)
            showFeedback(LocalizationStrings.localized("paywall_store_unavailable", languageTag))
            return
        }
        isPurchasing = true
        val productDetailsParamsList = listOf(
            BillingFlowParams.ProductDetailsParams.newBuilder()
                .setProductDetails(details)
                .build()
        )
        val flowParams = BillingFlowParams.newBuilder()
            .setProductDetailsParamsList(productDetailsParamsList)
            .build()
        val result = client.launchBillingFlow(activity, flowParams)
        if (result.responseCode != BillingClient.BillingResponseCode.OK) {
            isPurchasing = false
            showFeedback(LocalizationStrings.localized("paywall_store_unavailable", languageTag))
        }
    }

    /** 恢復先前的 Google Play 購買紀錄 */
    fun restorePurchases(context: Context, languageTag: String) {
        val appCtx = context.applicationContext
        val client = billingClient
        if (client == null || !client.isReady) {
            if (client != null) connectBillingClient(appCtx, client)
            showFeedback(LocalizationStrings.localized("paywall_store_unavailable", languageTag))
            return
        }
        isPurchasing = true
        queryOwnedPurchases(appCtx, client, showRestoreFeedback = true)
    }

    // ── VIP 禮遇通行證（Serverless Ed25519 離線驗章）───────────

    /**
     * 處理 `kairumo://vip?gift=<payload_b64url>.<sig_b64url>` 深層連結或手動貼上的通行證代碼。
     */
    fun handleVIPUri(context: Context, rawUriOrToken: String?, languageTag: String = "zh-Hant"): Boolean {
        val input = rawUriOrToken?.trim()?.takeIf { it.isNotEmpty() } ?: return false
        val token = extractGiftToken(input) ?: return false
        val payload = verifyVIPToken(token)
        if (payload != null) {
            ProfileContext.devicePrefs(context.applicationContext, PREFS_NAME)
                .edit()
                .putString(KEY_VIP_TOKEN, token)
                .apply()
            isVIPUnlocked = true
            vipRecipientName = payload.sub
            activePaywallFeature = null
            showFeedback(
                LocalizationStrings.localized("pro_unlocked_vip_toast", languageTag)
                    .replace("%@", payload.sub)
            )
            return true
        } else {
            showFeedback(LocalizationStrings.localized("pro_vip_invalid_toast", languageTag))
            return false
        }
    }

    /**
     * 從完整 URL（`kairumo://vip?gift=...`）或純 `<payload>.<sig>` 字串擷取 Token。
     */
    internal fun extractGiftToken(input: String): String? {
        val trimmed = input.trim()
        if (trimmed.startsWith("kairumo://", ignoreCase = true)) {
            val uri = runCatching { java.net.URI(trimmed) }.getOrNull() ?: return null
            if (!uri.host.equals("vip", ignoreCase = true)) return null
            val rawQuery = uri.rawQuery ?: return null
            for (pair in rawQuery.split("&")) {
                val idx = pair.indexOf('=')
                if (idx <= 0) continue
                val key = pair.substring(0, idx)
                val value = java.net.URLDecoder.decode(pair.substring(idx + 1), "UTF-8")
                if (key == "gift" || key == "token") {
                    return value.takeIf { it.isNotBlank() }
                }
            }
            return null
        }
        if (trimmed.contains(".") && !trimmed.contains(" ") && !trimmed.contains("://")) {
            return trimmed
        }
        return null
    }

    /**
     * 驗證 `<payload_base64url>.<signature_base64url>` 格式的 Ed25519 簽章與有效期限。
     * 純函式：可在單元測試直接呼叫驗證。
     */
    fun verifyVIPToken(
        rawToken: String,
        publicKeyBase64: String = VIP_PUBLIC_KEY_BASE64,
        nowEpochSeconds: Long = System.currentTimeMillis() / 1000L
    ): VIPGiftPayload? {
        val parts = rawToken.trim().split(".")
        if (parts.size != 2) return null
        val payloadB64 = parts[0]
        val sigB64 = parts[1]

        val payloadBytes = base64UrlDecode(payloadB64) ?: return null
        val sigBytes = base64UrlDecode(sigB64) ?: return null
        val pubKeyBytes = base64StandardDecode(publicKeyBase64) ?: return null
        if (pubKeyBytes.size != 32 || sigBytes.size != 64) return null

        val sigValid = Ed25519Verifier.verify(pubKeyBytes, payloadBytes, sigBytes) ||
            Ed25519Verifier.verify(pubKeyBytes, payloadB64.toByteArray(Charsets.UTF_8), sigBytes)
        if (!sigValid) {
            return null
        }

        return runCatching {
            val json = JSONObject(String(payloadBytes, Charsets.UTF_8))
            val sub = json.optString("to", "").ifEmpty { json.optString("sub", "") }.trim()
            val tier = json.optString("tier", "").trim()
            val iat = json.optLong("iat", 0L)
            val exp = if (json.has("exp") && !json.isNull("exp")) json.optLong("exp") else null
            if (sub.isEmpty() || tier != "pro_lifetime") return null
            if (exp != null && nowEpochSeconds > exp) return null
            VIPGiftPayload(sub = sub, tier = tier, iat = iat, exp = exp)
        }.getOrNull()
    }

    private fun showFeedback(text: String) {
        feedbackBannerText = text
        feedbackDismissJob?.cancel()
        feedbackDismissJob = runCatching {
            if (android.os.Looper.getMainLooper() != null) {
                mainScope.launch {
                    delay(4_000L)
                    if (feedbackBannerText == text) {
                        feedbackBannerText = null
                    }
                }
            } else null
        }.getOrNull()
    }

    /** 僅供單元測試重置記憶體狀態 */
    internal fun resetStateForTesting(
        playPurchased: Boolean = false,
        vipUnlocked: Boolean = false,
        forceFree: Boolean = false,
        showLockedBrushes: Boolean = false
    ) {
        isPlayBillingPurchased = playPurchased
        isVIPUnlocked = vipUnlocked
        forceFreeForTest = forceFree
        showLockedProBrushes = showLockedBrushes
        activeNudge = null
        activePaywallFeature = null
        lastNudgedFeature = null
        lastNudgeTimeMs = 0L
    }

    private fun base64UrlDecode(str: String): ByteArray? = runCatching {
        val normalized = str.replace('-', '+').replace('_', '/')
        val pad = (4 - normalized.length % 4) % 4
        val padded = normalized + "=".repeat(pad)
        java.util.Base64.getDecoder().decode(padded)
    }.getOrElse {
        runCatching {
            Base64.decode(str, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)
        }.getOrNull()
    }

    private fun base64StandardDecode(str: String): ByteArray? = runCatching {
        java.util.Base64.getDecoder().decode(str)
    }.getOrElse {
        runCatching { Base64.decode(str, Base64.DEFAULT) }.getOrNull()
    }
}

/**
 * RFC 8032 標準 Ed25519 純 Kotlin 驗章器。
 *
 * 為什麼不用 `java.security.Signature.getInstance("Ed25519")`：
 * Android 直到 API 33 才在內建 JCA Provider 加入 Ed25519，而 Kairumo 支援 API 29+ 且需在
 * 本機 JVM 單元測試環境直接驗章。使用 `BigInteger` + `SHA-512` 實作 RFC 8032 §5.1.7
 * 扭曲愛德華曲線（Twisted Edwards Curve）點驗證，零外部相依且跨 API 29–35 完全一致。
 */
internal object Ed25519Verifier {
    // p = 2^255 - 19
    private val P: BigInteger = BigInteger.ONE.shiftLeft(255).subtract(BigInteger.valueOf(19))
    // l = 2^252 + 27742317777372353535851937790883648493
    private val L: BigInteger = BigInteger.ONE.shiftLeft(252)
        .add(BigInteger("27742317777372353535851937790883648493"))
    // d = -121665 / 121666 mod p
    private val D: BigInteger = BigInteger.valueOf(-121665).mod(P)
        .multiply(BigInteger.valueOf(121666).modInverse(P)).mod(P)
    // I = 2^((p-1)/4) mod p (sqrt(-1) mod p)
    private val I: BigInteger = BigInteger.valueOf(2).modPow(
        P.subtract(BigInteger.ONE).divide(BigInteger.valueOf(4)),
        P
    )

    private data class Point(val x: BigInteger, val y: BigInteger)

    // Base point B (y = 4/5 mod p, x positive)
    private val B: Point by lazy {
        val y = BigInteger.valueOf(4).multiply(BigInteger.valueOf(5).modInverse(P)).mod(P)
        val x = recoverX(y, 0)!!
        Point(x, y)
    }

    fun verify(publicKey: ByteArray, message: ByteArray, signature: ByteArray): Boolean {
        if (publicKey.size != 32 || signature.size != 64) return false
        val aPoint = decodePoint(publicKey) ?: return false
        val rBytes = signature.copyOfRange(0, 32)
        val sBytes = signature.copyOfRange(32, 64)
        val rPoint = decodePoint(rBytes) ?: return false
        val s = fromLittleEndian(sBytes)
        if (s < BigInteger.ZERO || s >= L) return false

        val sha512 = MessageDigest.getInstance("SHA-512")
        sha512.update(rBytes)
        sha512.update(publicKey)
        sha512.update(message)
        val k = fromLittleEndian(sha512.digest()).mod(L)

        // Check [S]B == R + [k]A
        val lhs = scalarMult(B, s)
        val rhs = edwardsAdd(rPoint, scalarMult(aPoint, k))
        return lhs == rhs
    }

    private fun fromLittleEndian(bytes: ByteArray): BigInteger {
        val rev = ByteArray(bytes.size + 1)
        for (i in bytes.indices) {
            rev[bytes.size - i] = bytes[i]
        }
        return BigInteger(rev)
    }

    private fun decodePoint(bytes: ByteArray): Point? {
        if (bytes.size != 32) return null
        val copy = bytes.copyOf()
        val xSign = (copy[31].toInt() ushr 7) and 1
        copy[31] = (copy[31].toInt() and 0x7F).toByte()
        val y = fromLittleEndian(copy)
        if (y >= P) return null
        val x = recoverX(y, xSign) ?: return null
        return Point(x, y)
    }

    private fun recoverX(y: BigInteger, sign: Int): BigInteger? {
        val y2 = y.multiply(y).mod(P)
        val u = y2.subtract(BigInteger.ONE).mod(P)
        val v = D.multiply(y2).add(BigInteger.ONE).mod(P)
        // x^2 = u / v mod p
        val v3 = v.modPow(BigInteger.valueOf(3), P)
        val v7 = v.modPow(BigInteger.valueOf(7), P)
        val uv7 = u.multiply(v7).mod(P)
        val exp = P.subtract(BigInteger.valueOf(5)).divide(BigInteger.valueOf(8))
        var x = u.multiply(v3).mod(P).multiply(uv7.modPow(exp, P)).mod(P)

        val vx2 = v.multiply(x.multiply(x).mod(P)).mod(P)
        if (vx2 == u) {
            // x is valid root
        } else if (vx2 == P.subtract(u).mod(P)) {
            x = x.multiply(I).mod(P)
        } else {
            return null
        }
        if (x == BigInteger.ZERO && sign == 1) return null
        if ((if (x.testBit(0)) 1 else 0) != sign) {
            x = P.subtract(x)
        }
        return x
    }

    private fun edwardsAdd(p: Point, q: Point): Point {
        val x1 = p.x
        val y1 = p.y
        val x2 = q.x
        val y2 = q.y
        val x1x2 = x1.multiply(x2).mod(P)
        val y1y2 = y1.multiply(y2).mod(P)
        val dxxyy = D.multiply(x1x2).mod(P).multiply(y1y2).mod(P)

        val numX = x1.multiply(y2).add(x2.multiply(y1)).mod(P)
        val denX = BigInteger.ONE.add(dxxyy).mod(P).modInverse(P)
        val x3 = numX.multiply(denX).mod(P)

        val numY = y1y2.add(x1x2).mod(P)
        val denY = BigInteger.ONE.subtract(dxxyy).mod(P).modInverse(P)
        val y3 = numY.multiply(denY).mod(P)
        return Point(x3, y3)
    }

    private fun scalarMult(p: Point, e: BigInteger): Point {
        var result = Point(BigInteger.ZERO, BigInteger.ONE)
        var addend = p
        var k = e
        while (k > BigInteger.ZERO) {
            if (k.testBit(0)) {
                result = edwardsAdd(result, addend)
            }
            addend = edwardsAdd(addend, addend)
            k = k.shiftRight(1)
        }
        return result
    }
}

// ── 方案 A / B / C 視覺標示、輕提示膠囊與 Paywall UI 元件 ─────────────────

private val ProGoldStart = Color(0xFFF5A623)
private val ProGoldEnd = Color(0xFFD97706)
private val ProGoldBrush = Brush.linearGradient(listOf(ProGoldStart, ProGoldEnd))

/**
 * 方案 A：Pro 專屬微章（金色膠囊 `PRO` 或 `🔒`），用於未解鎖筆刷或功能項目旁。
 */
@Composable
fun ProMicroBadge(
    compact: Boolean = false,
    languageTag: String = "zh-Hant",
    modifier: Modifier = Modifier
) {
    val badgeText = LocalizationStrings.localized("pro_badge", languageTag)
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(4.dp))
            .background(ProGoldBrush)
            .padding(horizontal = if (compact) 3.dp else 5.dp, vertical = 1.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = if (compact) "🔒" else "🔒 $badgeText",
            fontSize = if (compact) 8.sp else 9.sp,
            fontWeight = FontWeight.ExtraBold,
            color = Color.White,
            lineHeight = 10.sp
        )
    }
}

/**
 * 方案 A：未解鎖工具列按鈕修飾器（半透明 0.46f + 右上角微型鎖頭角標）。
 */
fun Modifier.proLockedVisual(isLocked: Boolean): Modifier =
    if (isLocked) this.alpha(0.46f) else this

/**
 * 方案 A：插入／更多下拉選單項目文字（未解鎖時在右側顯示 `🔒 PRO` 金色膠囊且文字呈半透明，保持 `testTag` 順序完全不變）。
 */
@Composable
fun ProMenuItemText(
    title: String,
    isLocked: Boolean = !EntitlementManager.isProUnlocked,
    languageTag: String = "zh-Hant"
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(
            text = title,
            modifier = Modifier
                .weight(1f, fill = false)
                .alpha(if (isLocked) 0.55f else 1f),
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
        if (isLocked) {
            Spacer(Modifier.width(8.dp))
            ProMicroBadge(compact = false, languageTag = languageTag)
        }
    }
}

/**
 * 方案 A：下拉選單內的「✨ Kairumo Pro 專業版進階功能」分區標題列。
 */
@Composable
fun ProMenuSectionHeader(languageTag: String) {
    HorizontalDivider(modifier = Modifier.padding(vertical = 4.dp))
    Text(
        text = LocalizationStrings.localized("pro_menu_section_header", languageTag),
        style = MaterialTheme.typography.labelSmall,
        color = ProGoldEnd,
        fontWeight = FontWeight.SemiBold,
        modifier = Modifier.padding(horizontal = 12.dp, vertical = 4.dp)
    )
}

/**
 * 方案 C：工具列尾端的「Pro 進階筆刷收合／展開」膠囊按鈕。
 */
@Composable
fun ProBrushesCollapseButton(
    languageTag: String,
    proToolCount: Int,
    onToggle: () -> Unit = { EntitlementManager.toggleLockedProBrushes() }
) {
    if (EntitlementManager.isProUnlocked) return
    val expanded = EntitlementManager.showLockedProBrushes
    val label = if (expanded) {
        LocalizationStrings.localized("pro_brushes_collapse_btn", languageTag)
    } else {
        LocalizationStrings.localized("pro_brushes_expand_btn", languageTag)
            .replace("%@", proToolCount.toString())
    }
    val hint = LocalizationStrings.localized("pro_brushes_toggle_hint", languageTag)
    Surface(
        onClick = onToggle,
        shape = RoundedCornerShape(999.dp),
        color = ProGoldStart.copy(alpha = if (expanded) 0.20f else 0.12f),
        border = BorderStroke(1.dp, ProGoldStart.copy(alpha = 0.45f)),
        modifier = Modifier
            .padding(horizontal = 4.dp)
            .semantics { contentDescription = hint }
            .testTag("editor.ink.proBrushesToggle")
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 5.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            Text(
                text = "🔒",
                fontSize = 10.sp
            )
            Text(
                text = label,
                fontSize = 11.sp,
                fontWeight = FontWeight.Bold,
                color = ProGoldEnd
            )
            Text(
                text = if (expanded) "◂" else "▸",
                fontSize = 10.sp,
                color = ProGoldEnd
            )
        }
    }
}

/**
 * 方案 B：二段式無打擾輕提示膠囊（首次點擊未解鎖 Pro 功能時浮現在畫面底部，不中斷創作心流）。
 */
@Composable
fun ProNudgeBanner(
    nudge: ProNudgeNotice,
    languageTag: String,
    modifier: Modifier = Modifier
) {
    val msg = LocalizationStrings.localized("pro_nudge_toast_format", languageTag)
        .replace("%@", nudge.itemName)
    val learnMore = LocalizationStrings.localized("pro_nudge_learn_more", languageTag)
    Surface(
        shape = RoundedCornerShape(999.dp),
        color = Color(0xEB1C1C22),
        tonalElevation = 8.dp,
        shadowElevation = 8.dp,
        border = BorderStroke(1.dp, ProGoldStart.copy(alpha = 0.45f)),
        modifier = modifier
            .padding(horizontal = 16.dp, vertical = 12.dp)
            .testTag("paywall.nudge.banner")
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 9.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            ProMicroBadge(compact = false, languageTag = languageTag)
            Text(
                text = msg,
                color = Color.White,
                fontSize = 13.sp,
                fontWeight = FontWeight.Medium,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f, fill = false)
            )
            Surface(
                onClick = { EntitlementManager.presentPaywall(nudge.feature) },
                shape = RoundedCornerShape(999.dp),
                color = ProGoldEnd,
                modifier = Modifier.testTag("paywall.nudge.learnMore")
            ) {
                Text(
                    text = learnMore,
                    color = Color.White,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp)
                )
            }
            Text(
                text = "✕",
                color = Color.White.copy(alpha = 0.65f),
                fontSize = 12.sp,
                modifier = Modifier
                    .clickable { EntitlementManager.dismissNudge() }
                    .padding(horizontal = 4.dp, vertical = 2.dp)
            )
        }
    }
}

/**
 * 掛載於 `KairumoApp` 最外層的輕量次系統宿主：負責顯示方案 B 輕提示膠囊、購買回饋橫幅與 Paywall 對話框。
 */
@Composable
fun PaywallSubsystemHost(languageTag: String) {
    val nudge = EntitlementManager.activeNudge
    val feedback = EntitlementManager.feedbackBannerText
    val activeFeature = EntitlementManager.activePaywallFeature

    Box(modifier = Modifier.fillMaxSize()) {
        if (nudge != null) {
            ProNudgeBanner(
                nudge = nudge,
                languageTag = languageTag,
                modifier = Modifier.align(Alignment.BottomCenter)
            )
        } else if (!feedback.isNullOrBlank()) {
            Surface(
                shape = RoundedCornerShape(999.dp),
                color = Color(0xEB1C1C22),
                tonalElevation = 6.dp,
                shadowElevation = 6.dp,
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(horizontal = 16.dp, vertical = 14.dp)
            ) {
                Text(
                    text = feedback,
                    color = Color.White,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Medium,
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 9.dp)
                )
            }
        }
    }

    if (activeFeature != null) {
        PaywallDialog(
            highlightedFeature = activeFeature,
            languageTag = languageTag,
            onDismiss = { EntitlementManager.activePaywallFeature = null }
        )
    }
}

/**
 * Kairumo Pro 終身買斷解鎖視窗（與 Apple 端 `PaywallSheetView` 對齊）。
 */
@Composable
fun PaywallDialog(
    highlightedFeature: ProFeatureGate,
    languageTag: String,
    onDismiss: () -> Unit
) {
    val context = LocalContext.current
    val activity = context as? ComponentActivity
    var showVipInput by remember { mutableStateOf(false) }
    var vipCodeText by remember { mutableStateOf("") }

    val orderedFeatures = remember(highlightedFeature) {
        listOf(highlightedFeature) + ProFeatureGate.entries.filter { it != highlightedFeature }
    }

    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false)
    ) {
        Surface(
            shape = RoundedCornerShape(24.dp),
            color = MaterialTheme.colorScheme.surface,
            tonalElevation = 8.dp,
            modifier = Modifier
                .widthIn(max = 540.dp)
                .fillMaxWidth(0.94f)
                .padding(vertical = 20.dp)
                .testTag("paywall.dialog")
        ) {
            Column(
                modifier = Modifier
                    .verticalScroll(rememberScrollState())
                    .padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                // 頂部關閉列
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Surface(
                        shape = RoundedCornerShape(999.dp),
                        color = ProGoldStart.copy(alpha = 0.16f)
                    ) {
                        Text(
                            text = "✨ " + LocalizationStrings.localized("paywall_lifetime_badge", languageTag),
                            color = ProGoldEnd,
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Bold,
                            modifier = Modifier.padding(horizontal = 12.dp, vertical = 5.dp)
                        )
                    }
                    TextButton(onClick = onDismiss) {
                        Text(LocalizationStrings.localized("close", languageTag))
                    }
                }

                Spacer(Modifier.height(8.dp))

                Text(
                    text = LocalizationStrings.localized("paywall_title", languageTag),
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.ExtraBold,
                    textAlign = TextAlign.Center
                )
                Spacer(Modifier.height(6.dp))
                Text(
                    text = LocalizationStrings.localized("paywall_subtitle", languageTag),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center
                )

                Spacer(Modifier.height(16.dp))

                // 六大 Pro 專業版亮點卡片（觸發來源排第一並高亮邊框）
                for (feature in orderedFeatures) {
                    val isHighlighted = feature == highlightedFeature
                    Card(
                        shape = RoundedCornerShape(14.dp),
                        colors = CardDefaults.cardColors(
                            containerColor = if (isHighlighted) {
                                ProGoldStart.copy(alpha = 0.12f)
                            } else {
                                MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.45f)
                            }
                        ),
                        border = if (isHighlighted) BorderStroke(1.5.dp, ProGoldEnd) else null,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 4.dp)
                    ) {
                        Row(
                            modifier = Modifier.padding(12.dp),
                            verticalAlignment = Alignment.Top,
                            horizontalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(36.dp)
                                    .clip(CircleShape)
                                    .background(ProGoldStart.copy(alpha = 0.2f)),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(text = feature.iconGlyph, fontSize = 16.sp)
                            }
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = LocalizationStrings.localized(feature.titleKey, languageTag),
                                    style = MaterialTheme.typography.titleSmall,
                                    fontWeight = FontWeight.Bold
                                )
                                Spacer(Modifier.height(2.dp))
                                Text(
                                    text = LocalizationStrings.localized(feature.descKey, languageTag),
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }
                }

                Spacer(Modifier.height(12.dp))

                // 安心承諾：既有筆記與物件永遠可檢視與匯出
                Text(
                    text = "🛡 " + LocalizationStrings.localized("paywall_existing_data_safe", languageTag),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center
                )

                Spacer(Modifier.height(16.dp))

                // 主購買按鈕
                Button(
                    onClick = {
                        if (activity != null) {
                            EntitlementManager.purchaseLifetimePro(activity, languageTag)
                        }
                    },
                    enabled = !EntitlementManager.isPurchasing,
                    colors = ButtonDefaults.buttonColors(containerColor = ProGoldEnd),
                    shape = RoundedCornerShape(14.dp),
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(50.dp)
                        .testTag("paywall.buy.button")
                ) {
                    if (EntitlementManager.isPurchasing) {
                        CircularProgressIndicator(
                            color = Color.White,
                            strokeWidth = 2.dp,
                            modifier = Modifier.size(20.dp)
                        )
                    } else {
                        val buyLabel = LocalizationStrings.localized("paywall_buy_button", languageTag)
                            .replace("%@", EntitlementManager.displayPrice)
                        Text(
                            text = buyLabel,
                            color = Color.White,
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Bold
                        )
                    }
                }

                Spacer(Modifier.height(8.dp))

                // 恢復購買與兌換 VIP 通行證
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceEvenly,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    TextButton(
                        onClick = { EntitlementManager.restorePurchases(context, languageTag) },
                        enabled = !EntitlementManager.isPurchasing
                    ) {
                        Text(
                            text = LocalizationStrings.localized("paywall_restore_button", languageTag),
                            fontSize = 13.sp
                        )
                    }
                    TextButton(
                        onClick = { showVipInput = !showVipInput }
                    ) {
                        Text(
                            text = LocalizationStrings.localized("paywall_redeem_button", languageTag),
                            fontSize = 13.sp
                        )
                    }
                }

                if (showVipInput) {
                    Spacer(Modifier.height(8.dp))
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        OutlinedTextField(
                            value = vipCodeText,
                            onValueChange = { vipCodeText = it },
                            placeholder = {
                                Text(
                                    text = "kairumo://vip?gift=...",
                                    fontFamily = FontFamily.Monospace,
                                    fontSize = 12.sp
                                )
                            },
                            singleLine = true,
                            modifier = Modifier.weight(1f)
                        )
                        OutlinedButton(
                            onClick = {
                                EntitlementManager.handleVIPUri(context, vipCodeText, languageTag)
                            }
                        ) {
                            Text(LocalizationStrings.localized("confirm", languageTag))
                        }
                    }
                }
            }
        }
    }
}
