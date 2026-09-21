package com.kairumo.padnote.models

import android.content.Context
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import uniffi.padnote_core.FfiModelDownloadResult
import uniffi.padnote_core.FfiModelException
import uniffi.padnote_core.FfiModelFetcher
import uniffi.padnote_core.FfiModelInfo
import uniffi.padnote_core.modelCapabilityReady
import uniffi.padnote_core.modelCatalog
import uniffi.padnote_core.modelDiskUsage
import uniffi.padnote_core.modelDownload
import uniffi.padnote_core.modelPath as coreModelPath
import uniffi.padnote_core.modelRemove

/**
 * 按需下載端側模型（A2，決策 D4）。
 *
 * # 為什麼下載邏輯不在這裡
 *
 * 這一層只做一件事：**從第 N 個位元組開始拿一段回來**。
 * 續傳怎麼保進度、SHA-256 怎麼驗、驗完怎麼改名，全部在核心
 * （`padnote-models`）—— 那些正是最容易寫錯、又最難在真機上重現的地方。
 *
 * Apple 端走的是同一組核心函式，所以兩邊「下到一半斷線」的行為一樣。
 * 各寫一份不會一樣：Apple 原本那條路**沒有續傳也沒有驗證**，
 * 574 MB 斷一次就從頭來。
 */
object ModelDownloadManager {

    /** 一次請求最多拿多少。整包拿會在手機上一次配置幾百 MB。 */
    private const val CHUNK_BYTES = 8 * 1024 * 1024

    /**
     * 模型放哪裡。
     *
     * `filesDir` 而不是外部儲存：這些是**可重新下載的衍生資料**，
     * 不該出現在使用者的檔案管理員裡，也不需要權限。
     */
    fun root(context: Context): String =
        File(context.filesDir, "models").apply { mkdirs() }.absolutePath

    fun catalog(context: Context): List<FfiModelInfo> = modelCatalog(root(context))

    fun modelPath(context: Context, id: String): String = coreModelPath(root(context), id)

    fun isCapabilityReady(context: Context, capability: String): Boolean =
        modelCapabilityReady(root(context), capability)

    fun diskUsage(context: Context): ULong = modelDiskUsage(root(context))

    fun remove(context: Context, id: String): Boolean = modelRemove(root(context), id)

    /**
     * 下載（或續傳）一個模型。**會阻塞，要在背景執行緒呼叫。**
     *
     * `onProgress` 收到的是「總共拿到第幾個位元組」。進度只有這一層知道：
     * 核心的下載是一個會跑很久的同步呼叫，中途不回報。
     */
    fun download(
        context: Context,
        id: String,
        onProgress: (Long) -> Unit = {}
    ): FfiModelDownloadResult = modelDownload(root(context), id, RangeFetcher(onProgress))

    private class RangeFetcher(private val onProgress: (Long) -> Unit) : FfiModelFetcher {

        override fun supportsRange(): Boolean = true

        override fun fetch(url: String, from: ULong): ByteArray {
            var conn: HttpURLConnection? = null
            try {
                val end = from + CHUNK_BYTES.toULong() - 1u
                conn = (URL(url).openConnection() as HttpURLConnection).apply {
                    connectTimeout = 30_000
                    readTimeout = 60_000
                    setRequestProperty("Range", "bytes=$from-$end")
                }
                val code = conn.responseCode
                if (code !in 200..299) {
                    throw FfiModelException.Network("HTTP $code")
                }
                val bytes = conn.inputStream.use { it.readBytes() }
                if (bytes.isNotEmpty()) onProgress(from.toLong() + bytes.size)
                return bytes
            } catch (e: FfiModelException) {
                throw e
            } catch (t: Throwable) {
                throw FfiModelException.Network(t.message ?: t.toString())
            } finally {
                runCatching { conn?.disconnect() }
            }
        }
    }
}
