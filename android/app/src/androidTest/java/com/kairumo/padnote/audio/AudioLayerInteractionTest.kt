package com.kairumo.padnote.audio

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import java.io.File
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import uniffi.padnote_core.audioEncodePcmToOpus
import kotlin.math.PI
import kotlin.math.sin

/**
 * 互動矩陣（驗證層 L2）的 Android 版：錄音卡片「點得動」。
 *
 * 與 Apple 的 `InteractionMatrixAudit` 同一組問題：播放鈕點下去真的會呼叫播放（不被外層的
 * 點擊選取吃掉）、刪除鈕點下去真的會呼叫刪除、而且兩者都有描述（TalkBack 念得出來）。
 * 直接渲染 [AudioLayer]，不依賴整個編輯器的狀態。
 */
@RunWith(AndroidJUnit4::class)
class AudioLayerInteractionTest {

    @get:Rule
    val compose = createComposeRule()

    private val dir = File(InstrumentationRegistry.getInstrumentation().targetContext.cacheDir, "audio-matrix")

    @After
    fun cleanUp() { dir.deleteRecursively() }

    private fun card(file: String) = AudioObject(
        id = "c1", pageIndex = 0, recordingId = "r", fileName = file, title = "Fixture",
        durationSeconds = 1, x = 60f, y = 60f, width = 260f, height = 76f
    )

    @Test
    fun playAndDeleteButtonsReachTheirCallbacks() {
        dir.mkdirs()
        val pcm = List(16_000) { (sin(it * 2.0 * PI * 440.0 / 16_000.0) * 0.2).toFloat() }
        val name = "fixture.opus"
        assertTrue(audioEncodePcmToOpus(pcm, File(dir, name).absolutePath) != null)

        var plays = 0
        var deletes = 0
        var selected: String? by mutableStateOf("c1") // 刪除鈕只在選取後出現
        compose.setContent {
            Box(Modifier.size(600.dp, 400.dp)) {
                AudioLayer(
                    interactive = true,
                    items = listOf(card(name)),
                    density = InstrumentationRegistry.getInstrumentation().targetContext.resources.displayMetrics.density,
                    audioDirectory = dir,
                    selectedId = selected,
                    playingId = null,
                    l = { it },
                    onSelect = { selected = it },
                    onTogglePlay = { plays++ },
                    onRename = {},
                    onDelete = { deletes++ },
                    onChanged = {},
                    zIndexOf = { 0f }
                )
            }
        }

        compose.onNodeWithTag("audio.card.play").assertIsDisplayed().performClick()
        compose.runOnIdle { assertEquals("播放鈕點下去沒有呼叫播放（被外層選取手勢吃掉？）", 1, plays) }

        // 連點第二次也要有反應（使用者的第一次抱怨通常是第二次）。
        compose.onNodeWithTag("audio.card.play").performClick()
        compose.runOnIdle { assertEquals(2, plays) }

        compose.onNodeWithTag("audio.card.delete").performClick()
        compose.runOnIdle { assertEquals("刪除鈕點下去沒有呼叫刪除", 1, deletes) }
    }
}
