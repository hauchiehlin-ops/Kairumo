package com.kairumo.padnote.collab

import android.os.Handler
import android.os.Looper
import android.util.Base64
import java.io.File
import java.io.RandomAccessFile
import java.util.concurrent.Executors
import org.json.JSONObject

/**
 * 整份狀態裡的大圖改成分塊另外送（`state_blob`）。與 Apple `CollabBlobStream` 同一套。
 *
 * 以前每張圖都整張轉成 base64 夾在整份狀態裡：整本的圖一次全讀進記憶體（數 GB 的筆記本有人加入，
 * 房主就被系統砍掉），單張很大的圖也會超過中繼一則訊息的上限、那一段整個送不出去；
 * OkHttp 的送出佇列超過 16 MB 還會直接把連線關掉。
 *
 * 現在小圖照舊夾在整份狀態裡（舊版 App 照樣收得到）；超過 [INLINE_MAX] 的圖只帶描述，
 * 圖檔本身在整份狀態送完後一塊一塊送，送出佇列積太多就先等。收的一方寫進暫存檔、收齊才放進核心。
 */
object CollabBlobStream {
    /** 夾在整份狀態裡的圖檔上限（原始位元組）。超過的改分塊送。與 Apple 相同。 */
    const val INLINE_MAX = 4 * 1024 * 1024
    /** 寄存（`state_store`）時夾帶的圖檔上限：雲端中繼一段放不下更大的。與 Apple 相同。 */
    const val DEPOSIT_INLINE_MAX = 600 * 1024
    /** 一塊的原始位元組。與 Apple 相同。 */
    const val CHUNK_BYTES = 512 * 1024
    /** 兩塊之間的間隔（毫秒）。 */
    const val CHUNK_INTERVAL_MS = 120L
    /** 送出佇列超過這個量就先等一下再送下一塊（OkHttp 超過 16 MB 會關連線）。 */
    const val QUEUE_HIGH_WATER = 2L * 1024 * 1024

    /** 背景讀檔、送出（一次只送一張、一塊）。 */
    private val worker = Executors.newSingleThreadExecutor { r -> Thread(r, "collab-blob").apply { isDaemon = true } }

    /**
     * 依序把每張大圖分塊送給 [to]。[read] 在背景讀整張圖（核心的 blob），[send] 送出一塊、
     * 回傳 `false` 表示已不在房間（停止）；[queued] 是目前送出佇列裡的位元組數。
     */
    fun stream(
        hashes: List<String>, req: String, to: String, proto: Int,
        read: (String) -> ByteArray?, queued: () -> Long, send: (JSONObject) -> Boolean
    ) {
        if (hashes.isEmpty()) return
        worker.execute {
            for (hash in hashes) {
                val bytes = runCatching { read(hash) }.getOrNull() ?: continue
                val count = (bytes.size + CHUNK_BYTES - 1) / CHUNK_BYTES
                for (index in 0 until count) {
                    var waited = 0
                    while (queued() > QUEUE_HIGH_WATER && waited < 100) { Thread.sleep(100); waited++ }
                    val from = index * CHUNK_BYTES
                    val to2 = minOf(bytes.size, from + CHUNK_BYTES)
                    val payload = JSONObject().put("proto", proto).put("req", req).put("to", to)
                        .put("hash", hash).put("index", index).put("count", count).put("size", bytes.size)
                        .put("data", Base64.encodeToString(bytes, from, to2 - from, Base64.NO_WRAP))
                    if (!send(payload)) return@execute
                    Thread.sleep(CHUNK_INTERVAL_MS)
                }
            }
        }
    }
}

/**
 * 收 `state_blob`：每張圖寫進自己的暫存檔（背景執行緒），收齊後讀出整張交給 [store]（例如放進核心），
 * 再在主執行緒呼叫 [onArrived]。只在主執行緒呼叫 [accept]。
 */
class CollabBlobAssembler(
    private val directory: File,
    private val store: (ByteArray) -> Unit,
    private val onArrived: () -> Unit,
) {
    private class Progress(val count: Int) { val received = HashSet<Int>() }

    private val inFlight = HashMap<String, Progress>()
    private val worker = Executors.newSingleThreadExecutor { r -> Thread(r, "collab-blob-in").apply { isDaemon = true } }
    private val main = Handler(Looper.getMainLooper())

    fun accept(payload: JSONObject) {
        val hash = payload.optString("hash")
        if (hash.isEmpty() || !hash.all { it.isLetterOrDigit() }) return
        val index = payload.optInt("index", -1)
        val count = payload.optInt("count", 0)
        val data = payload.optString("data")
        if (count <= 0 || index !in 0 until count || data.isEmpty()) return
        val progress = inFlight.getOrPut(hash) { Progress(count) }
        if (progress.count != count || !progress.received.add(index)) return
        val complete = progress.received.size == count
        if (complete) inFlight.remove(hash)
        val partial = File(directory, "$hash.partial")
        worker.execute {
            runCatching {
                directory.mkdirs()
                val bytes = Base64.decode(data, Base64.NO_WRAP)
                RandomAccessFile(partial, "rw").use { f ->
                    f.seek(index.toLong() * CollabBlobStream.CHUNK_BYTES)
                    f.write(bytes)
                }
                if (complete) {
                    store(partial.readBytes())
                    partial.delete()
                    main.post(onArrived)
                }
            }
        }
    }

    /** 換房間：還沒收齊的丟掉（暫存檔由清理機制收掉）。 */
    fun reset() {
        inFlight.clear()
    }
}
