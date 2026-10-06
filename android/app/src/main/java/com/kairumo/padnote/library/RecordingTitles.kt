package com.kairumo.padnote.library

import android.content.Context
import org.json.JSONObject
import uniffi.padnote_core.PadnoteSession
import java.io.File
import java.security.MessageDigest

/**
 * 錄音的名字（寫入端）。讀取端是 [RecordingIndex.titlesIn]。
 *
 * 錄音檔住在筆記本套件裡，名字也寫進同一個套件，才會跟著同步到別台：第一頁上一個 `rectitle`
 * 信封區塊（與 Apple 的 `RecordingTitle` 同一格式）。區塊 id 由檔名決定，兩台裝置各自寫也是同一個區塊，
 * 不會各長一份；後寫的名字贏過先寫的。
 */
object RecordingTitles {

    private const val KIND = "rectitle"

    /** 1×1 全透明 PNG（與 Apple 的 `ObjectEnvelope.transparentPNG` 同一張）。 */
    private val TRANSPARENT_PNG: ByteArray = android.util.Base64.decode(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==",
        android.util.Base64.DEFAULT)

    /** 幫已經開著的 session 寫一段錄音的名字。成功回 true。 */
    fun write(session: PadnoteSession, fileName: String, title: String): Boolean {
        val clean = title.trim()
        val file = fileName.trim().lowercase()
        if (clean.isEmpty() || file.isEmpty()) return false
        return runCatching {
            val page = session.pageIdAt(0u) ?: return false
            val blockId = stableBlockId("$KIND:$file")
            val appearance = JSONObject()
                .put("object", KIND)
                .put("image", JSONObject().put("fileName", "$KIND:$file.png"))
                .put("payload", JSONObject().put("fileName", file).put("title", clean))
                .toString()
            if (blockId !in session.imageBlockIds(page)) {
                val blob = session.putBlob(TRANSPARENT_PNG)
                session.addImageWithId(page, blockId, blob, 1f, 1f)
                session.setBlockPosition(blockId, 0f, 0f)
            }
            session.setBlockAppearance(blockId, appearance)
            true
        }.getOrDefault(false)
    }

    /** 開套件、寫名字、關掉。 */
    fun write(context: Context, notebookId: String, deviceId: UInt, fileName: String, title: String): Boolean {
        val path = File(NotebookLibrary.directory(context), "$notebookId.${NotebookLibrary.EXTENSION}")
        if (!path.exists()) return false
        val session = runCatching { PadnoteSession.openExisting(path.absolutePath, deviceId) }
            .getOrNull() ?: return false
        return try {
            write(session, fileName, title)
        } finally {
            runCatching { session.close() }
        }
    }

    /** 這個套件裡最新的一個音檔（剛錄完的那一段）。 */
    fun newestAudio(context: Context, notebookId: String): File? =
        File(NotebookLibrary.directory(context), "$notebookId.${NotebookLibrary.EXTENSION}/media/audio")
            .listFiles { f -> f.isFile && f.extension.equals("opus", true) }
            ?.maxByOrNull { it.lastModified() }

    /** 物件 id → 核心的區塊 id。與 Apple 的 `stableBlockId` 逐步一致（見 `ShapeStore`）。 */
    private fun stableBlockId(raw: String): String {
        val b = MessageDigest.getInstance("SHA-256").digest(raw.toByteArray(Charsets.UTF_8)).copyOf(16)
        b[6] = ((b[6].toInt() and 0x0F) or 0x50).toByte()
        b[8] = ((b[8].toInt() and 0x3F) or 0x80).toByte()
        val hex = b.joinToString("") { "%02x".format(it) }
        return "${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-" +
            "${hex.substring(16, 20)}-${hex.substring(20)}"
    }
}
