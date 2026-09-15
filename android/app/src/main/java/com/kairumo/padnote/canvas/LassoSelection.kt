package com.kairumo.padnote.canvas

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.geometry.Offset
import com.kairumo.padnote.ink.InkEngine
import uniffi.padnote_core.FullStroke
import uniffi.padnote_core.PadnoteSession

/**
 * 套索選取（Android）。
 *
 * # 判定規則在核心，與 Apple 同一份
 *
 * 「圈到算不算選到」走核心的 `lassoSelect`，Apple 走 `lassoEncloses`——
 * 同一段幾何程式碼。各寫一份的話，同一個圈選會在 iPad 上選得到、在
 * Android 上選不到，而使用者會描述成「Android 的套索很難用」。
 *
 * # 為什麼 Android 這邊直接吃核心的筆畫
 *
 * Android 的墨跡本來就寫在核心裡（`InkEngine` 每一筆都 `add_stroke`），
 * 所以選取、刪除、複製、貼上全部可以在核心完成。Apple 不行——它編輯中
 * 的真相來源是 PencilKit 的 `PKDrawing`，核心只有在匯出／匯入時才被寫到，
 * 所以那邊是拿點去問核心的規則，自己改 `PKDrawing`。
 *
 * **後端不同，規則同一條。**
 *
 * # 座標
 *
 * 手勢收到的是 Compose 的**像素**，核心的筆畫用的是**頁面點**。
 * 兩者差一個 density。不換算的話，在 3x 的手機上圈選會差三倍，
 * 而症狀是「圈很大一圈卻什麼都沒選到」。
 */
class LassoSelection {

    /** 正在畫的那一圈（像素）。空的表示沒有在圈。 */
    var path by mutableStateOf<List<Offset>>(emptyList())
        private set

    /** 圈完之後那一圈仍然留著，讓使用者看得到選取範圍。 */
    var committed by mutableStateOf<List<Offset>>(emptyList())
        private set

    /** 選到的核心筆畫 id。 */
    var selected by mutableStateOf<List<String>>(emptyList())
        private set

    /**
     * 剪貼簿。**不用系統剪貼簿**：筆畫沒有標準的貼上格式，
     * 貼到別的 App 對方也讀不懂。放在這裡至少「複製→貼上」是會動的。
     */
    private var clipboard: List<FullStroke> = emptyList()

    val hasSelection: Boolean get() = selected.isNotEmpty()
    val canPaste: Boolean get() = clipboard.isNotEmpty()

    // ── 圈選 ──────────────────────────────────────────────────

    fun begin(at: Offset) {
        path = listOf(at)
        selected = emptyList()
        committed = emptyList()
    }

    fun extend(to: Offset) {
        val last = path.lastOrNull()
        // 太近的點不收：手指抖動會塞進上千個幾乎重合的點，而點在不在
        // 多邊形裡是 O(頂點數)，那會讓每次判定都變慢。
        if (last != null && kotlin.math.abs(last.x - to.x) < 4f &&
            kotlin.math.abs(last.y - to.y) < 4f
        ) {
            return
        }
        path = path + to
    }

    /** 放開手指：算出選到哪幾筆。 */
    fun finish(engine: InkEngine, density: Float) {
        val drawn = path
        path = emptyList()
        if (drawn.size < 3) {
            // 點一下就放開，不是圈選。清掉，不要留一個看不見的選取狀態。
            selected = emptyList()
            committed = emptyList()
            return
        }
        val handles = engine.coreHandles()
        if (handles == null) {
            selected = emptyList()
            committed = emptyList()
            return
        }
        val (session, pageId) = handles
        val polygon = drawn.flatMap { listOf(it.x / density, it.y / density) }
        val picked = runCatching { session.lassoSelect(pageId, polygon) }.getOrDefault(emptyList())
        selected = picked
        // 沒選到東西就不要留著那一圈 —— 畫面上掛著一個空的虛線框，
        // 使用者會以為選取還在。
        committed = if (picked.isEmpty()) emptyList() else drawn
    }

    fun clear() {
        path = emptyList()
        selected = emptyList()
        committed = emptyList()
    }

    // ── 動作 ──────────────────────────────────────────────────
    //
    // 每一個動作做完都要 `engine.load()`：核心已經改了，但 `InkEngine`
    // 記憶體裡那份還是動作前的 —— 不重讀的話畫面毫無變化，使用者會
    // 以為按鈕沒有作用。

    /** 回傳是否真的改了東西（呼叫端據此決定要不要重繪）。 */
    fun delete(engine: InkEngine): Boolean = act(engine) { session, pageId ->
        session.lassoDelete(pageId, selected) > 0u
    }

    fun copy(engine: InkEngine): Boolean {
        val (session, pageId) = engine.coreHandles() ?: return false
        clipboard = runCatching { session.lassoCopy(pageId, selected) }.getOrDefault(emptyList())
        // 複製不改內容，所以不必重讀，也不清掉選取 ——
        // 使用者常常是「複製完再貼一次」。
        return false
    }

    fun cut(engine: InkEngine): Boolean {
        copy(engine)
        return delete(engine)
    }

    fun duplicate(engine: InkEngine): Boolean = act(engine) { session, pageId ->
        val copied = session.lassoCopy(pageId, selected)
        // 偏移一點，不然新的那一份完全蓋在原本上面，看起來什麼也沒發生。
        session.lassoPaste(pageId, copied, OFFSET, OFFSET).isNotEmpty()
    }

    fun paste(engine: InkEngine): Boolean {
        if (clipboard.isEmpty()) return false
        return act(engine) { session, pageId ->
            session.lassoPaste(pageId, clipboard, OFFSET, OFFSET).isNotEmpty()
        }
    }

    private fun act(engine: InkEngine, body: (PadnoteSession, String) -> Boolean): Boolean {
        val (session, pageId) = engine.coreHandles() ?: return false
        val changed = runCatching { body(session, pageId) }.getOrDefault(false)
        if (changed) {
            engine.load()
            clear()
        }
        return changed
    }

    private companion object {
        /** 再製與貼上的偏移量（頁面點）。夠大到看得出是兩份，夠小到還在視野裡。 */
        const val OFFSET = 24f
    }
}
