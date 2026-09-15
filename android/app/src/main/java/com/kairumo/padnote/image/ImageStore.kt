package com.kairumo.padnote.image

import android.graphics.BitmapFactory
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import uniffi.padnote_core.PadnoteSession

/**
 * 圖片的持久化。
 *
 * 走核心的 `put_blob` / `add_image` / `set_block_position` / `set_block_appearance`
 * —— 與 Apple 端匯出 `.padnote` 時是同一組操作，所以兩邊的圖片互相打得開，
 * 連圓角、邊框、濾鏡都跨得過去。
 */
class ImageStore(
    private val session: PadnoteSession?,
    private val pageId: String?
) {
    private val images = LinkedHashMap<String, NoteImage>()
    /** 解碼後的點陣圖快取。每次重繪都解一次的話，捲動會卡到不能用。 */
    private val bitmaps = HashMap<String, ImageBitmap>()

    val all: List<NoteImage> get() = images.values.toList()

    fun bitmap(image: NoteImage): ImageBitmap? {
        bitmaps[image.blobId]?.let { return it }
        val s = session ?: return null
        val bytes = runCatching { s.blobBytes(image.blobId) }.getOrNull() ?: return null
        val bmp = runCatching { BitmapFactory.decodeByteArray(bytes, 0, bytes.size) }
            .getOrNull() ?: return null
        val out = bmp.asImageBitmap()
        bitmaps[image.blobId] = out
        return out
    }

    /** 從核心讀回這一頁的圖片。 */
    fun load() {
        val s = session ?: return
        val page = pageId ?: return
        images.clear()
        for (blockId in runCatching { s.imageBlockIds(page) }.getOrDefault(emptyList())) {
            val appearance = runCatching { s.blockAppearance(blockId) }.getOrNull()
            // 圖表與衍生圖片（連結卡片、3D）不是普通圖片 —— 當成普通圖片載入的話，
            // 同一個物件會在畫面上出現兩份，而且各自能拖到不同的地方。
            if (ImageAppearance.isChart(appearance) || ImageAppearance.isDerived(appearance)) continue
            val blobId = runCatching { s.blockBlobId(blockId) }.getOrNull() ?: continue
            val size = runCatching { s.imageBlockSize(blockId) }.getOrNull()
            val image = NoteImage(
                id = blockId,
                blobId = blobId,
                width = size?.getOrNull(0) ?: 240f,
                height = size?.getOrNull(1) ?: 180f
            )
            runCatching { s.blockPosition(blockId) }.getOrNull()?.let { xy ->
                if (xy != null && xy.size >= 2) { image.x = xy[0]; image.y = xy[1] }
            }
            ImageAppearance.apply(appearance, image)
            images[blockId] = image
        }
    }

    /**
     * 插入一張圖片。
     *
     * @param bytes 原始的檔案位元組（PNG／JPEG）。存原始位元組而不是重新編碼過的 ——
     *   重新編碼會讓每同步一趟畫質就掉一級。
     */
    fun insert(bytes: ByteArray, fileName: String, maxWidth: Float = 320f): NoteImage? {
        val s = session ?: return null
        val page = pageId ?: return null
        val bmp = runCatching { BitmapFactory.decodeByteArray(bytes, 0, bytes.size) }
            .getOrNull() ?: return null
        // 照原比例縮到版面放得下。用原始像素當點數的話，一張手機拍的照片
        // 會是 4000 點寬 —— 整個頁面被它蓋掉，而使用者要縮很久。
        val ratio = if (bmp.width > 0) bmp.height.toFloat() / bmp.width else 0.75f
        val width = minOf(maxWidth, bmp.width.toFloat())
        val height = width * ratio

        return runCatching {
            val blob = s.putBlob(bytes)
            val blockId = s.addImage(page, blob, width, height)
            val image = NoteImage(
                id = blockId, blobId = blob,
                width = width, height = height, fileName = fileName
            )
            s.setBlockPosition(blockId, image.x, image.y)
            s.setBlockAppearance(blockId, ImageAppearance.encode(image))
            images[blockId] = image
            image
        }.getOrNull()
    }

    /** 寫回位置與外觀。 */
    fun persist(image: NoteImage) {
        images[image.id] = image
        val s = session ?: return
        runCatching { s.setBlockPosition(image.id, image.x, image.y) }
        runCatching { s.setBlockAppearance(image.id, ImageAppearance.encode(image)) }
    }

    fun remove(image: NoteImage) {
        images.remove(image.id)
        bitmaps.remove(image.blobId)
        runCatching { session?.removeBlock(image.id) }
    }
}
