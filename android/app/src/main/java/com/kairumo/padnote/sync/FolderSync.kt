package com.kairumo.padnote.sync

import com.kairumo.padnote.LocalizationStrings

import android.content.Context
import android.net.Uri
import androidx.documentfile.provider.DocumentFile
import uniffi.padnote_core.SyncFileEntry
import uniffi.padnote_core.planFolderSync
import java.io.File

/**
 * 用使用者自己的雲端硬碟同步（決策 D3 選項 A）。
 *
 * # 我們不碰網路
 *
 * 同步由 Google Drive / Dropbox / Syncthing 等等負責 —— 使用者挑一個資料夾，
 * 兩台裝置指到同一個地方。沒有帳號、沒有伺服器。
 *
 * # 為什麼 Android 這邊不能直接給 Rust 一條路徑
 *
 * 雲端硬碟在 Android 上是 SAF 的 `DocumentsProvider`，只有 tree URI，
 * **沒有 POSIX 路徑**，Rust 碰不到。所以 I/O 寫在這裡，而「要複製哪些檔案、
 * 往哪個方向複製」的策略走核心的 `plan_folder_sync` —— 與 Apple 端同一份。
 * 兩個平台對「同步」有不同的理解，在使用者眼中就是資料遺失。
 */
object FolderSync {

    private const val PREFS = "kairumo"
    private const val KEY_TREE_URI = "sync.treeUri"

    data class Result(
        val uploaded: List<String> = emptyList(),
        val downloaded: List<String> = emptyList(),
        /** 需要使用者注意的檔案（目前只有 manifest.json）。 */
        val needsAttention: List<String> = emptyList(),
        val failures: Map<String, String> = emptyMap()
    ) {
        val isNoOp: Boolean get() = uploaded.isEmpty() && downloaded.isEmpty()
    }

    // MARK: - 資料夾位置

    /** 記住使用者選的資料夾，並取得**跨重啟仍有效**的存取權。 */
    fun setFolder(context: Context, treeUri: Uri) {
        // 沒有 takePersistableUriPermission 的話，權限在下次啟動就失效了 ——
        // 使用者會看到「同步失敗」而完全不知道為什麼。
        runCatching {
            context.contentResolver.takePersistableUriPermission(
                treeUri,
                android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    android.content.Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            )
        }
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putString(KEY_TREE_URI, treeUri.toString()).apply()
    }

    fun folderUri(context: Context): Uri? =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_TREE_URI, null)?.let(Uri::parse)

    /**
     * 給使用者看的資料夾路徑。
     *
     * SAF 的 tree URI 長這樣：
     * `content://com.android.externalstorage.documents/tree/primary%3ADocuments%2FKairumo`
     * —— 直接顯示它等於沒說。抽出後面那一段並還原成 `Documents/Kairumo`。
     *
     * 只顯示最後一層資料夾名稱是不夠的：兩個都叫「Kairumo」的資料夾在
     * 畫面上會一模一樣，使用者看不出同步指向哪一個。
     */
    fun displayPath(context: Context): String? {
        val uri = folderUri(context) ?: return null
        val docId = runCatching {
            android.provider.DocumentsContract.getTreeDocumentId(uri)
        }.getOrNull() ?: return uri.toString()
        // `primary:Documents/Kairumo` → `Documents/Kairumo`
        val path = docId.substringAfter(':', docId)
        val volume = docId.substringBefore(':', "")
        return when {
            path.isEmpty() -> docId
            volume == "primary" -> path
            volume.isEmpty() -> path
            else -> "$volume · $path"
        }
    }

    fun clearFolder(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().remove(KEY_TREE_URI).apply()
    }

    // MARK: - 檔案清單

    /** 本機套件目錄下的所有檔案（相對路徑）。 */
    fun localEntries(packageDir: File): List<SyncFileEntry> {
        if (!packageDir.isDirectory) return emptyList()
        // 一定要遞迴：doc/ops 與 ink 底下的東西才是真正的內容，
        // 只列單層會得到一份看起來成功、其實什麼都沒同步的計畫。
        return packageDir.walkTopDown()
            .filter { it.isFile }
            .map { SyncFileEntry(it.relativeTo(packageDir).path, it.length().toULong()) }
            .toList()
    }

    /** SAF 目錄下的所有檔案（相對路徑）。 */
    fun remoteEntries(dir: DocumentFile?): List<SyncFileEntry> {
        if (dir == null || !dir.isDirectory) return emptyList()
        val out = mutableListOf<SyncFileEntry>()
        fun walk(node: DocumentFile, prefix: String) {
            for (child in node.listFiles()) {
                val name = child.name ?: continue
                val path = if (prefix.isEmpty()) name else "$prefix/$name"
                if (child.isDirectory) walk(child, path)
                else out += SyncFileEntry(path, child.length().toULong())
            }
        }
        walk(dir, "")
        return out
    }

    // MARK: - 同步

    /**
     * 把本機套件與同步資料夾裡的同名套件對齊。
     *
     * @param remoteRoot 使用者選的資料夾。套件會以同名子目錄存在其中。
     */
    fun sync(
        context: Context,
        localPackage: File,
        remoteRoot: DocumentFile,
        languageTag: String = "zh-Hant"
    ): Result {
        val packageName = localPackage.name
        SyncLogger.log("【資料夾同步】開始執行，目標：$packageName", SyncSource.FOLDER)
        val remotePackage = remoteRoot.findFile(packageName)?.takeIf { it.isDirectory }
            ?: remoteRoot.createDirectory(packageName)
            ?: return Result(
                failures = mapOf(
                    "<資料夾>" to com.kairumo.padnote.LocalizationStrings
                        .localized("err_sync_folder_failed", languageTag)
                        .replace("%@", packageName)
                )
            ).also {
                SyncLogger.log("【資料夾同步】失敗：無法在遠端建立套件目錄 $packageName", SyncSource.FOLDER)
            }

        val plan = planFolderSync(localEntries(localPackage), remoteEntries(remotePackage))

        val uploaded = mutableListOf<String>()
        val downloaded = mutableListOf<String>()
        val failures = mutableMapOf<String, String>()

        for (path in plan.upload) {
            runCatching { upload(context, localPackage, remotePackage, path) }
                .onSuccess { uploaded += path }
                .onFailure { failures[path] = it.message ?: it.toString() }
        }
        for (path in plan.download) {
            runCatching { download(context, remotePackage, localPackage, path) }
                .onSuccess { downloaded += path }
                .onFailure { failures[path] = it.message ?: it.toString() }
        }
        SyncLogger.log("【資料夾同步】$packageName 完成。上傳: ${uploaded.size}, 下載: ${downloaded.size}, 失敗: ${failures.size}", SyncSource.FOLDER)
        return Result(uploaded, downloaded, plan.needsAttention, failures)
    }

    private fun upload(context: Context, localRoot: File, remoteRoot: DocumentFile, path: String) {
        val source = File(localRoot, path)
        val target = ensureRemoteFile(remoteRoot, path)
            ?: error("無法在同步資料夾建立 $path")
        // 用 "wt"（truncate）而不是 "w"：目的檔可能是較短的舊版本，
        // 不截斷的話尾端會殘留上一版的位元組，檔案就壞了。
        context.contentResolver.openOutputStream(target.uri, "wt").use { out ->
            requireNotNull(out) { "無法寫入 $path" }
            source.inputStream().use { it.copyTo(out) }
        }
    }

    private fun download(context: Context, remoteRoot: DocumentFile, localRoot: File, path: String) {
        val source = findRemoteFile(remoteRoot, path) ?: error("同步資料夾裡找不到 $path")
        val target = File(localRoot, path)
        val parent = target.parentFile ?: localRoot
        parent.mkdirs()
        val tempFile = File.createTempFile("sync_", ".tmp", parent)
        try {
            context.contentResolver.openInputStream(source.uri).use { input ->
                requireNotNull(input) { "無法讀取 $path" }
                tempFile.outputStream().use { out ->
                    input.copyTo(out)
                    out.fd.sync()
                }
            }
            if (!tempFile.renameTo(target)) {
                target.delete()
                if (!tempFile.renameTo(target)) {
                    tempFile.copyTo(target, overwrite = true)
                    tempFile.delete()
                }
            }
        } catch (e: Exception) {
            tempFile.delete()
            throw e
        }
    }

    /** 依相對路徑建立（或取得）SAF 檔案，沿途補上目錄。 */
    private fun ensureRemoteFile(root: DocumentFile, path: String): DocumentFile? {
        val parts = path.split('/')
        var dir = root
        for (segment in parts.dropLast(1)) {
            dir = dir.findFile(segment)?.takeIf { it.isDirectory }
                ?: dir.createDirectory(segment)
                ?: return null
        }
        val name = parts.last()
        dir.findFile(name)?.let { return it }

        // DocumentsProvider 會依 MIME 自己補副檔名：用 application/octet-stream
        // 建立 `manifest.json` 會得到 `manifest.json.bin`。那樣的資料夾兩個平台
        // 都讀不懂，而且建立本身是「成功」的 —— 不檢查就會整包爛掉。
        val created = dir.createFile(mimeFor(name), name) ?: return null
        if (created.name == name) return created
        return if (created.renameTo(name) && created.name == name) {
            created
        } else {
            // 名字改不回來就當作失敗，不要留下一個名字不對的檔案。
            created.delete()
            null
        }
    }

    /** 依副檔名給 MIME，讓 provider 不要再補一個。 */
    private fun mimeFor(name: String): String = when (name.substringAfterLast('.', "")) {
        "json" -> "application/json"
        "txt", "md" -> "text/plain"
        else -> "application/octet-stream"
    }

    private fun findRemoteFile(root: DocumentFile, path: String): DocumentFile? {
        var node: DocumentFile? = root
        for (segment in path.split('/')) {
            node = node?.findFile(segment) ?: return null
        }
        return node?.takeIf { it.isFile }
    }
    fun wipeCloud(context: Context): uniffi.padnote_core.FfiWipeResult? {
        val rootUri = folderUri(context) ?: return uniffi.padnote_core.FfiWipeResult(
            ok = false, deleted = 0u, failed = 0u, error = LocalizationStrings.localized("folder_sync_not_set", context.resources.configuration.locales[0].toLanguageTag()), needsReauth = false
        )
        val root = androidx.documentfile.provider.DocumentFile.fromTreeUri(context, rootUri) ?: return uniffi.padnote_core.FfiWipeResult(
            ok = false, deleted = 0u, failed = 0u, error = LocalizationStrings.localized("folder_sync_inaccessible", context.resources.configuration.locales[0].toLanguageTag()), needsReauth = false
        )
        var deleted = 0u
        var failed = 0u
        var firstError = ""
        for (item in root.listFiles()) {
            val name = item.name ?: continue
            if (name.endsWith(".padnote")) {
                try {
                    if (item.delete()) {
                        deleted++
                    } else {
                        failed++
                        if (firstError.isEmpty()) firstError = "刪除失敗：$name"
                    }
                } catch (e: Exception) {
                    failed++
                    if (firstError.isEmpty()) firstError = e.localizedMessage ?: "Unknown error"
                }
            }
        }
        return uniffi.padnote_core.FfiWipeResult(
            ok = failed == 0u, deleted = deleted, failed = failed, error = firstError, needsReauth = false
        )
    }
}
