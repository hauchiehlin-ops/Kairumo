package com.kairumo.padnote.platform

import android.content.Context
import android.net.Uri
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import java.io.File
import java.util.UUID
import uniffi.padnote_core.FfiImportSlot
import uniffi.padnote_core.importCheck
import uniffi.padnote_core.importExtensions

/**
 * 從本機檔案匯入東西到筆記頁（Android）。
 *
 * # 為什麼是共用的
 *
 * 插入工具原本只給得出**內建的東西** —— 3D 模型只有六個固定幾何體。
 * 使用者手上那個檔案進不來，而那才是他真正想放進筆記的東西。
 *
 * 每個插入工具各寫一份「挑檔案 → 檢查 → 複製」的話，第七個工具出現時
 * 會再抄一次，而抄漏的那一次（忘了關 stream、忘了檢查大小）要等使用者
 * 掉資料或 App 被系統殺掉才發現。
 *
 * 「收不收」的判斷在核心（`importCheck`），與 Apple 端同一套規則 ——
 * 同一個檔案在兩台裝置上得到不同答案是使用者完全無法理解的行為。
 */
object FileImport {

    /** 匯入的結果。`errorKey` 非空時其餘欄位無意義。 */
    data class Outcome(
        val storedName: String = "",
        val displayName: String = "",
        /** 失敗原因的語系鍵。成功時是空字串。 */
        val errorKey: String = ""
    )

    /**
     * 檔案挑選器收哪些 MIME 型別。副檔名清單來自核心（`importExtensions`）——
     * 「這個檔案在 iPad 上挑得到、在手機上挑不到」是使用者完全無法理解的行為。
     *
     * 對不出 MIME 的那些不是丟掉，而是整個退回「全部型別」：讓使用者至少挑得到
     * 東西，核心的 `importCheck` 會在挑完之後擋下不對的格式。把挑選器
     * 縮到只剩一半格式的話，他會以為自己的檔案壞了。
     */
    fun mimeTypes(slot: FfiImportSlot): Array<String> {
        val map = MimeTypeMap.getSingleton()
        val exts = importExtensions(slot)
        val types = exts.mapNotNull { map.getMimeTypeFromExtension(it) }.distinct()
        return if (types.size < exts.size || types.isEmpty()) {
            // 萬用型別。Kotlin 的區塊註解可以巢狀，所以**不要**把這個
            // 字面值寫進上面的說明裡 —— 那裡的 /* 會在註解裡開一層新的，
            // 而編譯器的抱怨會指到這一行，完全看不出原因（踩過）。
            arrayOf("*/*")
        } else {
            types.toTypedArray()
        }
    }

    /**
     * 把 `uri` 指到的檔案收進 App 的附件目錄。
     *
     * **整個過程只讀一次檔案。** 先問大小再決定要不要讀 —— 讀進來才發現
     * 太大的話，手機上那一下配置就可能直接被系統殺掉。
     *
     * `destDir` 指定收到哪裡，預設是附件目錄。匯入的音訊**不能**放在那裡：
     * 播放與同步兩條路都是照「錄音就在套件的 media/audio 底下」在解析
     * 的，放錯地方的症狀是「按了播放沒有反應」，而且沒有任何錯誤訊息。
     */
    fun take(
        context: Context,
        uri: Uri,
        slot: FfiImportSlot,
        destDir: File? = null
    ): Outcome {
        val (name, size) = query(context, uri)
        val verdict = importCheck(slot, name, size.toULong())
        if (!verdict.accepted) {
            return Outcome(errorKey = verdict.reasonKey)
        }

        val stored = if (verdict.extension.isEmpty()) {
            "imp_${UUID.randomUUID()}"
        } else {
            "imp_${UUID.randomUUID()}.${verdict.extension}"
        }
        val dir = (destDir ?: attachmentsDir(context)).apply { mkdirs() }
        val target = File(dir, stored)
        return try {
            // 寫到暫存檔再改名：寫到一半被中斷的話，留下的是沒有檔，
            // 不是一個讀得到但壞掉的檔 —— 後者會讓使用者看到一個打不開
            // 的物件，而且看不出原因。
            val tmp = File(target.parentFile, "${stored}.part")
            context.contentResolver.openInputStream(uri).use { input ->
                if (input == null) return Outcome(errorKey = "import_failed_read")
                tmp.outputStream().use { output -> input.copyTo(output) }
            }
            if (!tmp.renameTo(target)) {
                tmp.delete()
                return Outcome(errorKey = "import_failed_read")
            }
            Outcome(
                storedName = stored,
                displayName = name.substringBeforeLast('.', name)
            )
        } catch (_: Exception) {
            Outcome(errorKey = "import_failed_read")
        }
    }

    /**
     * 匯入檔案在磁碟上的位置。**不保證它存在**。
     */
    // 插入圖片用它把剛收進來的檔案讀回去解碼。匯入的 3D 模型這一側
    // 畫不出來（沒有 USDZ／GLB 算繪器），顯示的是檔名 —— 但檔案是真的
    // 存著也同步著。
    fun fileFor(context: Context, storedName: String): File =
        File(attachmentsDir(context), storedName)

    private fun attachmentsDir(context: Context): File =
        File(context.filesDir, "attachments").apply { mkdirs() }

    /**
     * 問檔案的名字與大小。
     *
     * 走 `ContentResolver` 而不是路徑：從「檔案」App 拿到的是 content URI，
     * 它**沒有路徑可言** —— 硬轉成路徑會拿到一個不存在的檔名，
     * 而錯誤訊息會變成「找不到檔案」。
     */
    private fun query(context: Context, uri: Uri): Pair<String, Long> {
        var name = uri.lastPathSegment?.substringAfterLast('/') ?: "file"
        var size = 0L
        runCatching {
            context.contentResolver.query(uri, null, null, null, null)?.use { c ->
                if (c.moveToFirst()) {
                    val ni = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (ni >= 0 && !c.isNull(ni)) name = c.getString(ni)
                    val si = c.getColumnIndex(OpenableColumns.SIZE)
                    if (si >= 0 && !c.isNull(si)) size = c.getLong(si)
                }
            }
        }
        return name to size
    }
}
