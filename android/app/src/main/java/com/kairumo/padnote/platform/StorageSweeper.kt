package com.kairumo.padnote.platform

import android.content.Context
import com.kairumo.padnote.library.NotebookTrash
import java.io.File

/**
 * 自動清理 App 自己留下的暫存與過時資料（與 Apple 的 `StorageSweeper` 同一組規則）。
 *
 * 1. **快取目錄（`cacheDir`）** 裡超過一小時的暫存：匯入的暫存資料夾（`import_…`）、
 *    `temp_import_….padnote`、匯出檔、渲染用的 PDF、自檢暫存 —— 各自用完會刪，但被中斷時就留下。
 *    Android 只在儲存空間吃緊時才清快取，實際上會一直長。
 * 2. **縮圖快取**（`thumbnails/`）：改一次筆記換一張新縮圖，已刪筆記的縮圖沒人會再讀。
 *    超過 30 天沒動的刪掉，總量超過上限就從最舊的開始清。縮圖隨時可重畫，所以什麼都不怕。
 * 3. **模型續傳殘檔**（`models` 資料夾裡的 `.partial` 檔）放了兩週沒人接著下，就是放棄了。
 * 4. **回收桶期滿**：原本只在雲端同步跑完一輪之後才清，不同步的使用者永遠不會清。
 *
 * 文件庫（筆記、錄音）一律不碰。
 */
object StorageSweeper {

    const val TEMP_MIN_AGE_MS = 60L * 60 * 1000
    const val PARTIAL_MIN_AGE_MS = 14L * 24 * 60 * 60 * 1000
    const val THUMBNAIL_MAX_AGE_MS = 30L * 24 * 60 * 60 * 1000
    const val THUMBNAIL_MAX_BYTES = 30L * 1024 * 1024

    data class Report(var files: Int = 0, var bytes: Long = 0, var trashPurged: Int = 0)

    /** 項目（檔案或資料夾）最近一次被動過的時間；資料夾要看裡面最新的。 */
    internal fun newestModified(file: File): Long {
        var newest = file.lastModified()
        if (file.isDirectory) {
            file.walkTopDown().forEach { if (it.lastModified() > newest) newest = it.lastModified() }
        }
        return newest
    }

    internal fun sizeOf(file: File): Long =
        if (file.isDirectory) file.walkTopDown().filter { it.isFile }.sumOf { it.length() } else file.length()

    /** 目錄底下第一層、早於 `now - minAge` 的項目。 */
    internal fun stale(
        dir: File, minAgeMs: Long, now: Long, skip: (String) -> Boolean = { false },
        accept: (String) -> Boolean = { true }
    ): List<File> =
        dir.listFiles().orEmpty()
            .filter { !skip(it.name) && accept(it.name) && now - newestModified(it) >= minAgeMs }

    private fun delete(files: List<File>, into: Report) {
        for (f in files) {
            val size = sizeOf(f)
            if (f.deleteRecursively()) {
                into.files++
                into.bytes += size
            }
        }
    }

    /** 縮圖：太舊的、以及超出總量上限的（從最舊的開始）。 */
    internal fun overBudgetThumbnails(dir: File, now: Long): List<File> {
        val all = dir.listFiles().orEmpty().filter { it.isFile }.sortedBy { it.lastModified() }
        val old = all.filter { now - it.lastModified() >= THUMBNAIL_MAX_AGE_MS }
        var total = all.sumOf { it.length() } - old.sumOf { it.length() }
        val extra = mutableListOf<File>()
        for (f in all - old.toSet()) {
            if (total <= THUMBNAIL_MAX_BYTES) break
            extra += f
            total -= f.length()
        }
        return old + extra
    }

    data class Usage(val library: Long, val cache: Long, val models: Long) {
        val total get() = library + cache + models
    }

    /** 用量：筆記與錄音（filesDir 扣掉模型）、快取、已下載的模型。背景執行緒呼叫。 */
    fun usage(context: Context): Usage {
        val models = sizeOf(File(context.filesDir, "models"))
        val files = sizeOf(context.filesDir)
        return Usage(library = (files - models).coerceAtLeast(0), cache = sizeOf(context.cacheDir), models = models)
    }

    /** 清可丟棄的東西（背景執行緒呼叫）。 */
    fun sweepDisposables(context: Context, now: Long = System.currentTimeMillis()): Report {
        val report = Report()
        // 縮圖由下面自己的規則管，不歸「一小時」那條。
        delete(stale(context.cacheDir, TEMP_MIN_AGE_MS, now, skip = { it == "thumbnails" }), report)
        delete(overBudgetThumbnails(File(context.cacheDir, "thumbnails"), now), report)
        delete(
            stale(File(context.filesDir, "models"), PARTIAL_MIN_AGE_MS, now, accept = { it.endsWith(".partial") }),
            report
        )
        return report
    }

    /** 啟動時的完整清理：可丟棄的 + 回收桶期滿。 */
    fun sweepAtLaunch(context: Context): Report {
        val report = sweepDisposables(context)
        report.trashPurged = runCatching { NotebookTrash.purgeExpired(context) }.getOrDefault(0)
        if (report.bytes > 0 || report.trashPurged > 0) {
            StartupLogger.log(
                "自動清理：${report.files} 項（${"%.1f".format(report.bytes / 1_048_576.0)} MB），回收桶期滿 ${report.trashPurged} 本"
            )
        }
        return report
    }
}
