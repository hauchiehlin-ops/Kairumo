package com.kairumo.padnote.model3d

import android.content.Context
import com.kairumo.padnote.platform.FileImport
import uniffi.padnote_core.FfiImportedModel3d

/**
 * 已經讀進來的匯入模型。
 *
 * # 為什麼要快取
 *
 * 使用者拖旋轉滑桿的時候每一幀都要重算投影。解析也塞進那條路的話，等於
 * 每一幀重讀一次整個檔案 —— 一個兩萬面的模型會讓滑桿變成幻燈片。
 *
 * # 為什麼「讀失敗」也要記住
 *
 * 檔案可能還沒從雲端同步下來，或根本壞了。不記住失敗的話，每一幀都會再
 * 試一次讀那個讀不到的檔 —— 那比慢更糟，那是整個畫面卡在磁碟 I/O 上。
 */
object ImportedModelCache {

    private val entries = HashMap<String, FfiImportedModel3d?>()

    /** 讀得到就回模型，讀不到回 `null`（介面退回檔名卡片）。 */
    @Synchronized
    fun get(context: Context, storedName: String): FfiImportedModel3d? {
        if (entries.containsKey(storedName)) return entries[storedName]

        val model = runCatching {
            val file = FileImport.fileFor(context, storedName)
            if (!file.isFile) return@runCatching null
            FfiImportedModel3d.parse(
                file.readBytes(),
                file.extension
            )
        }.getOrNull()

        entries[storedName] = model
        return model
    }

    /**
     * 忘掉某一個檔案。
     *
     * 同步把一個原本缺的檔案補下來之後要呼叫它，否則那本筆記在這次啟動
     * 期間會一直顯示檔名卡片 —— 而使用者會以為同步沒成功。
     */
    @Synchronized
    fun forget(storedName: String) {
        entries.remove(storedName)
    }
}
