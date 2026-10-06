package com.kairumo.padnote.ink

import android.content.Context
import android.content.Intent
import androidx.core.content.FileProvider
import uniffi.padnote_core.FfiExportStroke
import uniffi.padnote_core.FfiPoint
import uniffi.padnote_core.FfiSolidProfile
import uniffi.padnote_core.draftExportDxf
import uniffi.padnote_core.draftExportSvg
import uniffi.padnote_core.draftUnitsPerMm
import uniffi.padnote_core.solidExport3d
import java.io.File

/**
 * 匯出：本頁的製圖線（SVG、DXF）與立體（STL、OBJ、GLB、USDZ）。
 *
 * 檔案只放在 App 私有的 `cache/exports/`，用 `FileProvider` 逐次授權給接收方
 * （與 `Exporter` 同一條路，不開放整個目錄）。
 */
object DraftingExport {
    private fun mime(ext: String) = when (ext) {
        "svg" -> "image/svg+xml"
        "dxf" -> "image/vnd.dxf"
        "stl" -> "model/stl"
        "obj" -> "model/obj"
        "glb" -> "model/gltf-binary"
        "usdz" -> "model/vnd.usdz+zip"
        else -> "application/octet-stream"
    }

    private fun exportsDir(context: Context) = File(context.cacheDir, "exports").also { it.mkdirs() }

    /** 本頁看得見的製圖線 → 匯出用的筆畫（隱藏的圖層不輸出）。 */
    fun strokesFor(engine: InkEngine): List<FfiExportStroke> =
        engine.strokes.filter { it.points.size >= 2 && (it.layer == 0 || !DraftingState.isHidden(it.layer)) }.map { s ->
            val c = s.colorRgba
            val hex = if (c.size >= 3) "#%02X%02X%02X".format(c[0].toInt() and 0xFF, c[1].toInt() and 0xFF, c[2].toInt() and 0xFF) else "#111827"
            FfiExportStroke(s.points.map { FfiPoint(it.x, it.y) }, s.layer.toUByte(), s.lineType.toUByte(), s.baseWidth, hex)
        }

    /** 本頁 → SVG／DXF 的文字。沒有任何線回 null。 */
    fun pageText(engine: InkEngine, format: String, pageWidth: Float, pageHeight: Float): String? {
        val strokes = strokesFor(engine)
        if (strokes.isEmpty()) return null
        return if (format == "dxf") draftExportDxf(strokes, pageWidth, pageHeight)
        else draftExportSvg(strokes, pageWidth, pageHeight)
    }

    /** 立體 → 檔案位元組（一個頁面單位 = 1/每毫米單位數 毫米）。 */
    fun solidBytes(profile: FfiSolidProfile, depth: Float, format: String): ByteArray? =
        solidExport3d(profile, depth, format, 1f / draftUnitsPerMm())

    /** 寫進 `cache/exports/` 並開分享表。成功回 true。 */
    fun share(context: Context, name: String, ext: String, bytes: ByteArray): Boolean = runCatching {
        val file = File(exportsDir(context), "$name.$ext")
        file.writeBytes(bytes)
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
        val send = Intent(Intent.ACTION_SEND).apply {
            type = mime(ext)
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        context.startActivity(Intent.createChooser(send, null).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        true
    }.getOrDefault(false)

    fun sharePage(context: Context, engine: InkEngine, format: String, pageWidth: Float, pageHeight: Float): Boolean {
        val text = pageText(engine, format, pageWidth, pageHeight) ?: return false
        return share(context, "padnote-page", format, text.toByteArray(Charsets.UTF_8))
    }

    fun shareSolid(context: Context, profile: FfiSolidProfile, depth: Float, format: String): Boolean {
        val bytes = solidBytes(profile, depth, format) ?: return false
        return share(context, "solid", format, bytes)
    }
}
