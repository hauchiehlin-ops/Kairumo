package com.kairumo.padnote.platform

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/**
 * 平台能力契約（驗證層 L3）：Android 版的裝置自檢在這台裝置上跑得出結果，
 * 而且不依賴麥克風／使用者授權的那幾項（播放、簡繁轉換、資料夾、選擇器）都通過。
 * 與 Apple 的 `PlatformContractTests` 對應。連跑兩次 —— 第二次才是使用者的第一次抱怨。
 */
@RunWith(AndroidJUnit4::class)
class PlatformSelfCheckTest {

    @Test
    fun coreChecksPassTwiceInARow() = runBlocking {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        repeat(2) { round ->
            val results = PlatformSelfCheck.run(context, "zh-Hant")
            val byId = results.associateBy { it.id }
            for (id in listOf("audio.playback", "folder.library", "picker.presenter", "transcript.script")) {
                val r = byId[id]
                assertTrue("第 ${round + 1} 次：缺少 $id", r != null)
                assertTrue(
                    "第 ${round + 1} 次：$id 失敗 — ${r?.detail}",
                    r?.status != SelfCheckResult.Status.FAIL
                )
            }
        }
    }
}
