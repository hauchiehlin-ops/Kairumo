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
    private val rawBitmaps = HashMap<String, android.graphics.Bitmap>()

    val all: List<NoteImage> get() = images.values.toList()

    fun rawBitmap(image: NoteImage): android.graphics.Bitmap? {
        rawBitmaps[image.blobId]?.let { return it }
        val s = session ?: return null
        val bytes = runCatching { s.blobBytes(image.blobId) }.getOrNull() ?: return null
        val bmp = runCatching { BitmapFactory.decodeByteArray(bytes, 0, bytes.size) }
            .getOrNull() ?: return null
        rawBitmaps[image.blobId] = bmp
        return bmp
    }

    fun bitmap(image: NoteImage): ImageBitmap? {
        bitmaps[image.blobId]?.let { return it }
        val bmp = rawBitmap(image) ?: return null
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

    /**
     * 放一張已知大小與位置的圖（整份匯入 PDF 用）。不解碼點陣圖 —— 尺寸呼叫端已經知道了，
     * 為了量大小把一張整頁的圖解出來是白做工（而且在記憶體裡多一份 14 MB）。
     * PDF 頁面是底稿：沒有圓角、沒有陰影。
     */
    fun insertPlaced(bytes: ByteArray, fileName: String, x: Float, y: Float, width: Float, height: Float): NoteImage? {
        val s = session ?: return null
        val page = pageId ?: return null
        return runCatching {
            val blob = s.putBlob(bytes)
            val blockId = s.addImage(page, blob, width, height)
            val image = NoteImage(
                id = blockId, blobId = blob, x = x, y = y, width = width, height = height,
                cornerRadius = 0f, hasShadow = false, fileName = fileName
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

    /** 讓這一頁的圖片變成 [target] 那一份（全域復原用）。刪掉的用原 id 放回。 */
    fun restoreTo(target: List<NoteImage>) {
        val wanted = target.associateBy { it.id }
        for (image in all) if (image.id !in wanted) remove(image)
        for (image in target) {
            val copy = image.copy()
            if (!images.containsKey(image.id)) {
                val s = session
                val page = pageId
                if (s != null && page != null) {
                    runCatching { s.addImageWithId(page, image.id, image.blobId, image.width, image.height) }
                }
            }
            persist(copy)
        }
    }

    /** 協同：新增或更新一張圖（新的用原本的 id 與 blob 建立；blob 要先放進核心）。 */
    fun upsert(image: NoteImage) {
        if (!images.containsKey(image.id)) {
            val s = session
            val page = pageId
            if (s != null && page != null) {
                runCatching { s.addImageWithId(page, image.id, image.blobId, image.width, image.height) }
            }
        }
        persist(image)
    }

    fun find(id: String): NoteImage? = images[id]

    /** 讀出圖片原始位元組（供剪下／複製到剪貼簿保存，避免剪下刪除原區塊後貼不回來）。 */
    fun blobBytes(image: NoteImage): ByteArray? {
        val s = session ?: return null
        return runCatching { s.blobBytes(image.blobId) }.getOrNull()
    }

    /**
     * 以新區塊 ID 建立一份圖片副本（貼上到本頁或其他頁指定座標 [x], [y]）。
     * 完整保留原圖尺寸、旋轉、圓角、陰影、邊框、濾鏡、材質與算式欄位。
     */
    fun createCopy(source: NoteImage, blobBytes: ByteArray?, x: Float, y: Float): NoteImage? {
        val s = session ?: return null
        val page = pageId ?: return null
        return runCatching {
            val blob = if (blobBytes != null && blobBytes.isNotEmpty()) {
                s.putBlob(blobBytes)
            } else {
                source.blobId
            }
            val blockId = s.addImage(page, blob, source.width, source.height)
            val copy = source.copy(
                id = blockId,
                blobId = blob,
                x = x,
                y = y
            )
            s.setBlockPosition(blockId, copy.x, copy.y)
            s.setBlockAppearance(blockId, ImageAppearance.encode(copy))
            images[blockId] = copy
            copy
        }.getOrNull()
    }

}
