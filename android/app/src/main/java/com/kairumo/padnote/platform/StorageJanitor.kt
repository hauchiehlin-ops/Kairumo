package com.kairumo.padnote.platform

import android.content.Context
import com.kairumo.padnote.library.NotebookLibrary
import com.kairumo.padnote.library.NotebookTrash
import com.kairumo.padnote.sync.AutoSync
import com.kairumo.padnote.sync.SyncLogger
import com.kairumo.padnote.sync.SyncSource
import uniffi.padnote_core.FfiStorageOptimizationReport
import uniffi.padnote_core.optimizeNotebookStorage
import java.io.File
import java.util.UUID

/**
 * 清除不再引用的檔案，並提供核心儲存空間最佳化（與 Apple 端的 `StorageJanitor` 完全同構對應）。
 */
// profile-scope: device
object StorageJanitor {

    /** 附件圖片要多舊才算垃圾（3 天）。 */
    const val ATTACHMENT_MIN_AGE_MS = 3L * 24 * 60 * 60 * 1000

    /** 頁面筆跡要多舊才算垃圾（1 天）。 */
    const val DRAWING_MIN_AGE_MS = 24L * 60 * 60 * 1000

    data class NotebookInfo(
        val id: String,
        val pageCount: Int
    )

    data class PageFile(
        val notebookId: String,
        val page: Int
    )

    data class Plan(
        val files: MutableList<File> = mutableListOf(),
        var bytes: Long = 0L,
        val keptSuspicious: MutableList<File> = mutableListOf()
    ) {
        fun add(file: File, size: Long) {
            files.add(file)
            bytes += size
        }
    }

    /** `att_<UUID>.png`。 */
    fun isAttachmentImageName(name: String): Boolean {
        if (!name.startsWith("att_") || !name.endsWith(".png")) return false
        val id = name.removePrefix("att_").removeSuffix(".png")
        return runCatching { UUID.fromString(id) }.isSuccess
    }

    /** `<筆記本 id>_p<N>.drawing` 或 `.proink.json` / `.proink-foreign.json`。 */
    fun pageFile(name: String): PageFile? {
        val suffixes = listOf(".drawing", ".proink.json", ".proink-foreign.json")
        for (suffix in suffixes) {
            if (name.endsWith(suffix)) {
                val stem = name.removeSuffix(suffix)
                val idx = stem.lastIndexOf("_p")
                if (idx < 0) return null
                val pageStr = stem.substring(idx + 2)
                val page = pageStr.toIntOrNull() ?: return null
                if (page < 0) return null
                val id = stem.substring(0, idx)
                if (id.isEmpty()) return null
                return PageFile(notebookId = id, page = page)
            }
        }
        return null
    }

    fun isEmptyPageFile(file: File): Boolean {
        if (!file.exists() || file.length() == 0L) return true
        if (file.name.endsWith(".proink.json") || file.name.endsWith(".proink-foreign.json")) {
            val content = runCatching { file.readText().trim() }.getOrDefault("")
            return content == "[]" || content.isEmpty()
        }
        return false
    }

    fun plan(
        attachmentsDirectory: File,
        pageDirectories: List<File>,
        notebooks: List<NotebookInfo>,
        protectedIds: Set<String>,
        referencedAttachments: Set<String>,
        nowMs: Long = System.currentTimeMillis()
    ): Plan {
        val plan = Plan()
        if (notebooks.isEmpty()) return plan

        val attFiles = attachmentsDirectory.listFiles()?.filter { isAttachmentImageName(it.name) }.orEmpty()
        for (file in attFiles) {
            if (!referencedAttachments.contains(file.name) && (nowMs - file.lastModified()) >= ATTACHMENT_MIN_AGE_MS) {
                plan.add(file, file.length())
            }
        }

        val known = notebooks.associate { it.id.lowercase() to it.pageCount }
        val protectedSet = protectedIds.map { it.lowercase() }.toSet()

        for (dir in pageDirectories) {
            val files = dir.listFiles().orEmpty()
            for (file in files) {
                val pf = pageFile(file.name) ?: continue
                if ((nowMs - file.lastModified()) < DRAWING_MIN_AGE_MS) continue
                val id = pf.notebookId.lowercase()
                val pages = known[id]
                if (pages != null) {
                    if (pf.page < maxOf(pages, 1)) continue
                    if (isEmptyPageFile(file)) {
                        plan.add(file, file.length())
                    } else {
                        plan.keptSuspicious.add(file)
                    }
                } else if (protectedSet.contains(id)) {
                    continue
                } else {
                    plan.add(file, file.length())
                }
            }
        }
        return plan
    }

    fun execute(plan: Plan): Pair<Int, Long> {
        var count = 0
        var bytes = 0L
        for (file in plan.files) {
            val len = file.length()
            if (file.delete()) {
                count++
                bytes += len
            }
        }
        return Pair(count, bytes)
    }

    /**
     * 最佳化所有本機與回收桶中的筆記本套件（Oplog 壓實、未引用 Blob 回收、筆跡壓實）。
     */
    fun optimizeAllNotebooks(context: Context, deepClean: Boolean = false): FfiStorageOptimizationReport {
        val deviceId = AutoSync.currentDeviceId()
        val notebookDirs = listOfNotNull(
            runCatching { NotebookLibrary.directory(context) }.getOrNull(),
            runCatching { NotebookTrash.directory(context) }.getOrNull()
        )

        var totalOplogs = 0u
        var totalBlobs = 0u
        var totalBlobBytes = 0uL
        var totalInkPages = 0u
        var totalInkBytes = 0uL

        for (dir in notebookDirs) {
            if (!dir.exists() || !dir.isDirectory) continue
            val packages = dir.listFiles { f -> f.isDirectory && f.name.endsWith(".${NotebookLibrary.EXTENSION}") }.orEmpty()
            for (pkg in packages) {
                try {
                    val report = optimizeNotebookStorage(pkg.absolutePath, deviceId, deepClean)
                    totalOplogs += report.oplogFilesMerged
                    totalBlobs += report.blobsRemoved
                    totalBlobBytes += report.blobBytesReclaimed
                    totalInkPages += report.inkPagesCompacted
                    totalInkBytes += report.inkBytesReclaimed
                } catch (t: Throwable) {
                    SyncLogger.log("StorageJanitor: optimize failed for ${pkg.name}: ${t.message}", SyncSource.GENERAL)
                }
            }
        }

        val totalFreed = totalBlobBytes + totalInkBytes
        if (totalOplogs > 0u || totalBlobs > 0u || totalInkPages > 0u) {
            val mb = "%.2f".format(totalFreed.toDouble() / 1_048_576.0)
            SyncLogger.log(
                "StorageJanitor: 最佳化完成，合併 $totalOplogs 個 oplog，清除 $totalBlobs 個 blob，壓實 $totalInkPages 個筆跡頁，釋放 ${mb} MB",
                SyncSource.GENERAL
            )
        }

        return FfiStorageOptimizationReport(
            oplogFilesMerged = totalOplogs,
            blobsRemoved = totalBlobs,
            blobBytesReclaimed = totalBlobBytes,
            inkPagesCompacted = totalInkPages,
            inkBytesReclaimed = totalInkBytes
        )
    }
}
