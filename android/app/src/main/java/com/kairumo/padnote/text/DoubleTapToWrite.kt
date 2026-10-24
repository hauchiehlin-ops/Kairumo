package com.kairumo.padnote.text

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import com.kairumo.padnote.canvas.MarqueeHit
import com.kairumo.padnote.canvas.ObjectMarquee
import com.kairumo.padnote.canvas.ObjectStacking
import com.kairumo.padnote.canvas.fingerDoubleTap
import com.kairumo.padnote.ink.InkEngine
import com.kairumo.padnote.library.NotebookMeta
import uniffi.padnote_core.PadnoteSession

/**
 * 單頁模式：手寫模式下手指雙擊空白處 → 建立文字方塊並進入就地編輯
 * （對齊 Apple `handleCanvasDirectDoubleTap`；連續模式見 `ContinuousPages`）。
 *
 * 邏輯全收在這裡、不寫進 `MainActivity.InkScreen`：那個函式已在 ART 驗證器的上限邊緣，
 * 多幾個 lambda 就會啟動即 `VerifyError`。
 *
 * [onWritten] 在方塊建好、已排到最上層之後呼叫：呼叫端選取它並切到打字模式。
 */
@Composable
fun Modifier.doubleTapToWrite(
    enabled: Boolean,
    density: Float,
    engine: InkEngine,
    textStore: TextBoxStore,
    meta: NotebookMeta,
    session: PadnoteSession?,
    pageIndex: Int,
    snapToGrid: Boolean,
    frames: List<MarqueeHit>,
    stackOrder: List<String>,
    onWritten: (TextBox) -> Unit
): Modifier {
    val framesLatest by rememberUpdatedState(frames)
    val orderLatest by rememberUpdatedState(stackOrder)
    val snapLatest by rememberUpdatedState(snapToGrid)
    val onWrittenLatest by rememberUpdatedState(onWritten)
    return fingerDoubleTap(
        listOf(enabled, pageIndex),
        hitAt = { p ->
            enabled && ObjectMarquee.topmostHit(Offset(p.x / density, p.y / density), framesLatest) == null
        },
        onCancelInk = { engine.cancelInFlight() },
        onDoubleTap = { p ->
            val box = textStore.createTapToWrite(
                p.x / density, p.y / density,
                textStore.pageRules(meta.paperId(pageIndex)), snapLatest
            )
            meta.setObjectOrder(session, pageIndex, ObjectStacking.bringToFront(setOf(box.id), orderLatest))
            InlineTextEditing.activeId = box.id
            onWrittenLatest(box)
        }
    )
}
