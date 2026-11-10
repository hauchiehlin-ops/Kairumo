package com.kairumo.padnote.collab

import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.semantics.clearAndSetSemantics
import com.kairumo.padnote.ink.InkEngine
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

/*
 * 協同：書寫中即時串流筆畫（`live_ink`）。與 Apple 的 CollabLiveInk.swift 同一個協定。
 *
 * 正式筆畫（`ink_add`）要等提筆才送，對方看到的是「一整筆突然出現」。這裡在書寫途中
 * 每 ~50 ms 送一次新增的點，對方先畫一條預覽線；提筆後正式筆畫照舊送達，預覽線隨即收掉。
 *
 * 預覽線只在記憶體、只畫在浮層上：不進引擎、不進套件、中繼不留存（`live_` 開頭的種類是暫態）。
 * 漏收、亂序都無妨 —— 最後一定以 `ink_add` 為準（ADR-0015 筆跡單一真相不受影響）。
 */

/** 送出端：掛在一個筆跡引擎上。 */
class LiveInkSender(
    private val manager: CollaborationManager,
    /** 這一頁的 id；回 `null` 表示現在不串流（不在協同、或這一頁還沒有 id）。 */
    private val pageId: () -> String?,
) {
    private var strokeId: String? = null
    private var page: String? = null
    private var erasingPage: String? = null
    private var erasingPointer: ULong? = null
    private var rgba = "#000000FF"
    private var width = 3f
    private var pending = JSONArray()
    private var lastSentAt = 0L
    private var seq = 0
    private var pointer: ULong? = null

    fun attach(engine: InkEngine) {
        engine.canBeginEdit = {
            val pid = pageId()
            pid == null || manager.tryBeginLocalPageEdit(pid) == null
        }
        engine.onLiveSample = { phase, id, x, y -> sample(engine, phase, id, x, y) }
    }

    fun detach(engine: InkEngine) {
        engine.canBeginEdit = null
        engine.onLiveSample = null
    }

    private fun sample(engine: InkEngine, phase: Int, id: ULong, x: Float, y: Float) {
        when (phase) {
            0 -> {
                if (strokeId != null || erasingPointer != null) return // 已經有一筆在送（多指）：只串流第一筆
                val pid = pageId() ?: return
                manager.tryBeginLocalPageEdit(pid)
                if (engine.isErasing || !manager.isLiveInkReady) {
                    if (engine.isErasing) {
                        erasingPage = pid
                        erasingPointer = id
                    }
                    return
                }
                strokeId = UUID.randomUUID().toString()
                pointer = id
                page = pid
                rgba = "#" + engine.colorRgba.joinToString("") { "%02X".format(it.toInt() and 0xFF) }
                width = engine.baseWidth
                pending = JSONArray()
                seq = 0
                lastSentAt = 0L
                add(x, y)
            }
            1 -> {
                if (erasingPointer == id) {
                    erasingPage?.let { manager.renewLocalPageEdit(it) }
                    return
                }
                if (strokeId == null || pointer != id) return
                page?.let { manager.renewLocalPageEdit(it) }
                add(x, y)
                val now = SystemClock.uptimeMillis()
                if (now - lastSentAt >= INTERVAL_MS * CollaborationManager.crowdFactor(manager.peers.size)) flush(end = false)
            }
            else -> {
                if (erasingPointer == id) {
                    erasingPage?.let { manager.endLocalPageEdit(it, immediate = false) }
                    erasingPage = null
                    erasingPointer = null
                    return
                }
                if (strokeId == null || pointer != id) return
                page?.let { manager.endLocalPageEdit(it, immediate = false) }
                flush(end = true)
                strokeId = null
                pointer = null
            }
        }
    }

    private fun add(x: Float, y: Float) {
        pending.put(x.toDouble())
        pending.put(y.toDouble())
    }

    private fun flush(end: Boolean) {
        val sid = strokeId ?: return
        val pid = page ?: return
        lastSentAt = SystemClock.uptimeMillis()
        if (pending.length() == 0 && !end) return
        manager.sendLiveInk(
            JSONObject()
                .put("page", pid).put("sid", sid).put("seq", seq)
                .put("rgba", rgba).put("w", width.toDouble())
                .put("p", pending).put("end", end)
        )
        seq++
        pending = JSONArray()
    }

    companion object {
        /** 20 Hz（每 50 ms 一批點）：公開中繼按收到的訊息數計額度，30 Hz 多花一半卻看不出差別。與 Apple 相同。 */
        const val INTERVAL_MS = 50L
    }
}

/** 別人書寫中的預覽線。 */
data class LiveInkStroke(
    val pageId: String,
    val color: Color,
    val width: Float,
    val points: List<Offset>,
    val lastSeq: Int,
    val updatedAt: Long,
    val ended: Boolean,
)

/**
 * 收到的預覽線。所有修改都在主執行緒（Compose 狀態不能在 OkHttp 的執行緒上推進）。
 */
class LiveInkStore {
    val strokes = mutableStateMapOf<String, LiveInkStroke>()
    private val main = Handler(Looper.getMainLooper())
    private var sweeping = false

    /** 可在任何執行緒呼叫。 */
    fun receive(userId: String, payload: JSONObject) {
        main.post { apply(userId, payload) }
    }

    /** 正式筆畫到了：那個人已提筆的預覽線收掉。可在任何執行緒呼叫。 */
    fun settle(userId: String) {
        main.post {
            val prefix = "$userId/"
            strokes.keys.filter { it.startsWith(prefix) && strokes[it]?.ended == true }.forEach { strokes.remove(it) }
        }
    }

    fun clear() {
        main.post { strokes.clear() }
    }

    private fun apply(userId: String, payload: JSONObject) {
        val sid = payload.optString("sid").ifEmpty { return }
        val page = payload.optString("page").ifEmpty { return }
        val key = "$userId/$sid"
        val seq = payload.optInt("seq", 0)
        val flat = payload.optJSONArray("p") ?: JSONArray()
        val pts = ArrayList<Offset>(flat.length() / 2)
        var i = 0
        while (i + 1 < flat.length()) {
            pts += Offset(flat.optDouble(i).toFloat(), flat.optDouble(i + 1).toFloat())
            i += 2
        }
        val end = payload.optBoolean("end", false)
        val now = SystemClock.uptimeMillis()
        val existing = strokes[key]
        if (existing != null) {
            if (seq <= existing.lastSeq) return
            strokes[key] = existing.copy(
                points = existing.points + pts, lastSeq = seq, updatedAt = now, ended = existing.ended || end)
        } else {
            strokes[key] = LiveInkStroke(
                pageId = page, color = parseColor(payload.optString("rgba")),
                width = payload.optDouble("w", 3.0).toFloat().coerceAtLeast(1f),
                points = pts, lastSeq = seq, updatedAt = now, ended = end)
        }
        scheduleSweep()
    }

    /** 正式筆畫沒來（被收回、網路掉了）也不能讓預覽線一直掛著。 */
    private fun scheduleSweep() {
        if (sweeping) return
        sweeping = true
        main.postDelayed(object : Runnable {
            override fun run() {
                val now = SystemClock.uptimeMillis()
                strokes.entries.filter { (_, s) -> now - s.updatedAt > if (s.ended) 1_500 else 3_000 }
                    .map { it.key }.forEach { strokes.remove(it) }
                if (strokes.isEmpty()) sweeping = false else main.postDelayed(this, 500)
            }
        }, 500)
    }

    private fun parseColor(hex: String): Color {
        val h = hex.removePrefix("#")
        val v = h.toLongOrNull(16) ?: return Color(0xFF3478F6)
        return when (h.length) {
            8 -> Color(
                red = ((v shr 24) and 0xFF).toInt(), green = ((v shr 16) and 0xFF).toInt(),
                blue = ((v shr 8) and 0xFF).toInt(), alpha = (v and 0xFF).toInt())
            6 -> Color(0xFF000000 or v)
            else -> Color(0xFF3478F6)
        }
    }
}

/**
 * 在頁面上畫出別人書寫中的預覽線。放在與畫布同一個（已縮放的）頁面容器裡：
 * 頁面座標是 dp，乘上密度就是這一層的像素。
 */
@Composable
fun RemoteLiveInkOverlay(store: LiveInkStore, pageId: String?, modifier: Modifier = Modifier) {
    if (pageId == null || store.strokes.isEmpty()) return
    Canvas(modifier.clearAndSetSemantics { }) {
        val d = density
        for (s in store.strokes.values) {
            if (s.pageId != pageId || s.points.isEmpty()) continue
            val path = Path()
            path.moveTo(s.points[0].x * d, s.points[0].y * d)
            for (p in s.points.drop(1)) path.lineTo(p.x * d, p.y * d)
            if (s.points.size == 1) path.lineTo(s.points[0].x * d + 0.1f, s.points[0].y * d)
            drawPath(
                path, s.color.copy(alpha = s.color.alpha * 0.85f),
                style = Stroke(width = s.width * d, cap = StrokeCap.Round, join = StrokeJoin.Round))
        }
    }
}
