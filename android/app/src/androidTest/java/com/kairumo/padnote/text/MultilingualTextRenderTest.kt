package com.kairumo.padnote.text

import android.graphics.Bitmap
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.test.captureToImage
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * 打字模式的文字框在泰文、韓文、日文下的排版。
 *
 * 文字框原本把行高固定成「字級 × 1.0」：西文勉強夠用，泰文的上下母音與聲調符號會疊到上一行。
 * 這裡把兩種行高並排畫出來（輸出到 Download/lang-render.png，人眼檢查），
 * 並斷言「不指定行高」時每一行比固定 1.0 倍高 —— 行高真的交給字型了。
 */
@RunWith(AndroidJUnit4::class)
class MultilingualTextRenderTest {
    @get:Rule val compose = createComposeRule()

    private val samples = listOf(
        "English: The quick brown fox",
        "繁體：線性代數與特徵向量",
        "日本語：ひらがなと漢字の文章",
        "한국어: 회의록과 강의 노트 작성",
        "ไทย: ภาษาไทยมีวรรณยุกต์ เช่น ที่ ปู่ ผู้ ซึ่ง นี้",
    )

    @Test
    fun theLinesAreLaidOutByTheFontNotCrammedToOneEm() {
        var fixedHeight = 0
        var naturalHeight = 0
        compose.setContent {
            Column(Modifier.padding(8.dp)) {
                for (mode in 0..1) {
                    val lh = if (mode == 0) 22.sp else TextUnit.Unspecified
                    Text(
                        samples.joinToString("\n"),
                        style = TextStyle(fontSize = 22.sp, lineHeight = lh),
                        modifier = Modifier.padding(bottom = 12.dp),
                        onTextLayout = { r -> if (mode == 0) fixedHeight = r.size.height else naturalHeight = r.size.height }
                    )
                }
            }
        }
        compose.waitForIdle()
        val bitmap = compose.onRoot().captureToImage().asAndroidBitmap()
        // 存到共用的 Download 資料夾（走 MediaStore，不需要權限），測試結束 App 被移除後還拿得到。
        val resolver = InstrumentationRegistry.getInstrumentation().targetContext.contentResolver
        val values = android.content.ContentValues().apply {
            put(android.provider.MediaStore.Downloads.DISPLAY_NAME, "lang-render.png")
            put(android.provider.MediaStore.Downloads.MIME_TYPE, "image/png")
            put(android.provider.MediaStore.Downloads.RELATIVE_PATH, "Download")
        }
        resolver.insert(android.provider.MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)?.let { uri ->
            resolver.openOutputStream(uri)?.use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
        }
        assertTrue("自然行高 $naturalHeight 應該比固定 1.0 倍 $fixedHeight 高", naturalHeight > fixedHeight)
    }
}
