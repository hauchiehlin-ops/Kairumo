package com.kairumo.padnote.platform

import org.junit.Assert.assertEquals
import org.junit.Test

/** 「插入 › 從檔案選擇圖片（…）」後面標示的格式。規則與 Apple `FileImport.summarize` 相同。 */
class FileImportFormatSummaryTest {

    @Test fun imageSlotListIsShortenedAndJpegFoldsIntoJpg() {
        // 核心圖片槽目前的清單（crates/padnote-core/src/ffi_import.rs）。
        val core = listOf("png", "jpg", "jpeg", "heic", "gif", "webp", "tiff", "bmp")
        assertEquals("PNG/JPG/HEIC/GIF…", FileImport.summarize(core))
    }

    @Test fun shortListHasNoEllipsis() {
        assertEquals("PDF", FileImport.summarize(listOf("pdf")))
        assertEquals("MP3/M4A", FileImport.summarize(listOf("mp3", "m4a"), limit = 2))
    }
}
