package com.kairumo.padnote.oauth

import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import uniffi.padnote_core.FfiByteRange
import uniffi.padnote_core.FfiDriveException
import uniffi.padnote_core.FfiDriveHttp
import uniffi.padnote_core.FfiQueryParam

/**
 * Google Drive 的 HTTP（Android）。
 *
 * 核心負責**送什麼**（查詢字串、分頁、合併規則），這裡只負責**怎麼送**：
 * 帶上權杖、送出去、把回應原樣交回去。
 *
 * # 不要在這裡判斷 Drive 的語意
 *
 * 唯一的例外是**狀態碼的分類**，而那一項非常重要：
 * - 401/403 → `PermissionDenied`，上層據此要求重新登入
 * - 404 → `NotFound`，第一次同步時檔案本來就不存在，那不是錯誤
 * - 其餘 → `Backend`，重試即可
 *
 * 混成同一種的話，使用者會在「該重新登入」時看到一句沒有用的「同步失敗」，
 * 而背景會無限重試一個永遠不會成功的請求。
 *
 * # 為什麼不讓核心自己用 reqwest
 *
 * 試過，`libpadnote_core.so` 從 8.1 MB 變成 13 MB —— 整個 rustls 堆疊被連進來。
 * 而且 OkHttp 帶著系統的 Proxy 設定、VPN 與憑證信任鏈，那些 reqwest 拿不到。
 */
class DriveHttpClient(
    private val accessToken: String,
    private val http: OkHttpClient = shared
) : FfiDriveHttp {

    override fun getJson(url: String, query: List<FfiQueryParam>): String {
        val built = url.toHttpUrl().newBuilder().apply {
            // 讓 OkHttp 做百分號編碼 —— Drive 的 `q=` 裡有空格、單引號與括號，
            // 自己拼字串很容易漏掉其中一種。
            query.forEach { addQueryParameter(it.name, it.value) }
        }.build()
        return text(Request.Builder().url(built).get())
    }

    override fun getBytes(url: String, range: FfiByteRange?): ByteArray {
        val builder = Request.Builder().url(url).get()
        if (range != null) {
            // 核心給的是半開區間 [start, end)，HTTP 的 Range 是**閉區間** ——
            // 尾端要減一。少減那個 1 會每次多拉一個位元組。
            builder.header("Range", "bytes=${range.start}-${range.end - 1u}")
        }
        return bytes(builder)
    }

    override fun postJson(url: String, bodyJson: String): String =
        text(Request.Builder().url(url).post(bodyJson.toRequestBody(JSON)))

    override fun patchBytes(url: String, data: ByteArray) {
        bytes(Request.Builder().url(url).patch(data.toRequestBody(OCTET_STREAM)))
    }

    // ── 內部 ──────────────────────────────────────────────────

    private fun text(builder: Request.Builder): String =
        String(bytes(builder), Charsets.UTF_8)

    private fun bytes(builder: Request.Builder): ByteArray {
        val request = builder.header("Authorization", "Bearer $accessToken").build()
        val response = try {
            http.newCall(request).execute()
        } catch (t: Throwable) {
            // 連不上：網路問題，重試會好。
            throw FfiDriveException.Backend(t.message ?: "network_error")
        }
        response.use {
            val body = it.body?.bytes() ?: ByteArray(0)
            if (it.isSuccessful) return body
            throw classify(it.code, request.url.encodedPath, String(body, Charsets.UTF_8))
        }
    }

    private fun classify(code: Int, path: String, detail: String): FfiDriveException = when (code) {
        401, 403 -> FfiDriveException.PermissionDenied("HTTP $code $detail")
        404 -> FfiDriveException.NotFound(path)
        else -> FfiDriveException.Backend("HTTP $code $detail")
    }

    companion object {
        private val JSON = "application/json".toMediaType()
        private val OCTET_STREAM = "application/octet-stream".toMediaType()

        /** 共用連線池。每次同步都開一個 client 會白白重建 TLS 連線。 */
        private val shared = OkHttpClient()
    }
}
