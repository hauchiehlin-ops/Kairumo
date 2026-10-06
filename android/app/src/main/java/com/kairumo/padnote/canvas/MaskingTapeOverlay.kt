package com.kairumo.padnote.canvas

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Divider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import java.util.UUID
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

/**
 * 遮蔽膠帶（Masking Tape）資料模型。
 * 對齊 Apple 端 NoteTapeAttachment。
 */
data class NoteTape(
    val id: String = UUID.randomUUID().toString(),
    var pageIndex: Int,
    var x: Float,
    var y: Float,
    var width: Float,
    var height: Float,
    var isRevealed: Boolean = false,
    var colorHex: String = "#FCEEAC",
    val unknown: org.json.JSONObject = org.json.JSONObject()
)

object NoteTapeCodec {
    private val KNOWN = setOf("id", "pageIndex", "rect", "x", "y", "width", "height", "isRevealed", "colorHex")

    fun decode(obj: org.json.JSONObject): NoteTape? {
        val id = obj.optString("id").takeIf { it.isNotEmpty() } ?: return null
        val pageIndex = obj.optInt("pageIndex", 0)
        val isRevealed = obj.optBoolean("isRevealed", false)
        val colorHex = obj.optString("colorHex").takeIf { it.isNotEmpty() } ?: "#FCEEAC"

        var x = 0f
        var y = 0f
        var w = 120f
        var h = 32f

        // Apple 的 `CGRect` 預設編碼是 `[[x, y], [w, h]]`。原本只認物件寫法，
        // 於是 Apple 建立的膠帶在這裡全部落在 (0,0)、120×32。
        val rectArray = obj.optJSONArray("rect")
        val rect = obj.optJSONObject("rect")
        if (rectArray != null && rectArray.length() >= 2) {
            val o = rectArray.optJSONArray(0)
            val sz = rectArray.optJSONArray(1)
            if (o != null && sz != null) {
                x = o.optDouble(0, 0.0).toFloat()
                y = o.optDouble(1, 0.0).toFloat()
                w = sz.optDouble(0, 120.0).toFloat()
                h = sz.optDouble(1, 32.0).toFloat()
            }
        } else if (rect != null) {
            val origin = rect.optJSONObject("origin")
            val size = rect.optJSONObject("size")
            if (origin != null && size != null) {
                x = origin.optDouble("x", 0.0).toFloat()
                y = origin.optDouble("y", 0.0).toFloat()
                w = size.optDouble("width", 120.0).toFloat()
                h = size.optDouble("height", 32.0).toFloat()
            } else {
                x = rect.optDouble("x", 0.0).toFloat()
                y = rect.optDouble("y", 0.0).toFloat()
                w = rect.optDouble("width", 120.0).toFloat()
                h = rect.optDouble("height", 32.0).toFloat()
            }
        } else {
            x = obj.optDouble("x", 0.0).toFloat()
            y = obj.optDouble("y", 0.0).toFloat()
            w = obj.optDouble("width", 120.0).toFloat()
            h = obj.optDouble("height", 32.0).toFloat()
        }

        val unknown = org.json.JSONObject()
        for (key in obj.keys()) {
            if (key !in KNOWN) unknown.put(key, obj.get(key))
        }

        return NoteTape(
            id = id,
            pageIndex = pageIndex,
            x = x,
            y = y,
            width = maxOf(w, 20f),
            height = maxOf(h, 16f),
            isRevealed = isRevealed,
            colorHex = colorHex,
            unknown = unknown
        )
    }

    fun decodeAll(array: org.json.JSONArray?): MutableList<NoteTape> {
        val out = mutableListOf<NoteTape>()
        val source = array ?: return out
        for (i in 0 until source.length()) {
            val obj = source.optJSONObject(i) ?: continue
            decode(obj)?.let { out.add(it) }
        }
        return out
    }

    /** 解一個 `tape` 信封。不是這種區塊、或內容不完整就回 null。 */
    fun parseEnvelope(json: String, pageIndex: Int): NoteTape? {
        val root = runCatching { org.json.JSONObject(json) }.getOrNull() ?: return null
        if (root.optString("object") != "tape") return null
        val payload = root.optJSONObject("payload") ?: return null
        val tape = decode(payload) ?: return null
        tape.pageIndex = pageIndex
        return tape
    }

    fun encode(tape: NoteTape): org.json.JSONObject {
        val obj = org.json.JSONObject(tape.unknown.toString())
        obj.put("id", tape.id)
        obj.put("pageIndex", tape.pageIndex)
        obj.put("isRevealed", tape.isRevealed)
        obj.put("colorHex", tape.colorHex)

        // Apple 端 `CGRect` 的 Codable 格式：[[x, y], [w, h]]（寫成物件的話 Apple 解不開）。
        obj.put(
            "rect",
            org.json.JSONArray()
                .put(org.json.JSONArray().put(tape.x.toDouble()).put(tape.y.toDouble()))
                .put(org.json.JSONArray().put(tape.width.toDouble()).put(tape.height.toDouble()))
        )

        // 扁平座標後備，供純 JSON 客戶端讀取
        obj.put("x", tape.x.toDouble())
        obj.put("y", tape.y.toDouble())
        obj.put("width", tape.width.toDouble())
        obj.put("height", tape.height.toDouble())
        return obj
    }

    private val TRANSPARENT_PNG: ByteArray by lazy {
        android.util.Base64.decode(
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==",
            android.util.Base64.DEFAULT)
    }

    /** 物件 id → 核心的區塊 id。與 Apple 的 `stableBlockId` 逐步一致（見 `ShapeStore`）。 */
    private fun stableBlockId(raw: String): String {
        runCatching { java.util.UUID.fromString(raw) }.getOrNull()?.let {
            if (it.toString().equals(raw, ignoreCase = true)) return it.toString().lowercase()
        }
        val b = java.security.MessageDigest.getInstance("SHA-256")
            .digest(raw.toByteArray(Charsets.UTF_8)).copyOf(16)
        b[6] = ((b[6].toInt() and 0x0F) or 0x50).toByte()
        b[8] = ((b[8].toInt() and 0x3F) or 0x80).toByte()
        val hex = b.joinToString("") { "%02x".format(it) }
        return "${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-" +
            "${hex.substring(16, 20)}-${hex.substring(20)}"
    }

    /**
     * 把這一頁的膠帶寫成逐物件的信封區塊（kind = `tape`），與 Apple 同一格式。
     *
     * 讀取時**信封為準**、中繼資料清單只補信封沒有的。原本 Android 只更新清單：
     * 在 Android 移動／縮放一條 Apple 建立的膠帶，下次載入信封還是舊的位置與大小 ——
     * 「移動並調整大小之後，自己又回到原來的位置與大小」。
     */
    fun writeEnvelopes(session: uniffi.padnote_core.PadnoteSession, pageId: String, pageTapes: List<NoteTape>) {
        runCatching {
            val existing = HashMap<String, String>() // 物件 id（小寫）→ 區塊 id
            for (blockId in session.imageBlockIds(pageId)) {
                val json = session.blockAppearance(blockId) ?: continue
                val root = runCatching { org.json.JSONObject(json) }.getOrNull() ?: continue
                if (root.optString("object") != "tape") continue
                val id = root.optJSONObject("payload")?.optString("id")?.lowercase() ?: continue
                existing[id] = blockId
            }
            val keep = HashSet<String>()
            for (tape in pageTapes) {
                val id = tape.id.lowercase()
                keep += id
                val blockId = existing[id] ?: stableBlockId(tape.id).also { fresh ->
                    val blob = session.putBlob(TRANSPARENT_PNG)
                    session.addImageWithId(pageId, fresh, blob, 1f, 1f)
                }
                session.setBlockPosition(blockId, tape.x, tape.y)
                val appearance = org.json.JSONObject()
                    .put("object", "tape")
                    .put("image", org.json.JSONObject().put("fileName", "${tape.id}.png"))
                    .put("payload", encode(tape))
                    .toString()
                session.setBlockAppearance(blockId, appearance)
            }
            for ((id, blockId) in existing) {
                if (id !in keep) session.removeBlock(blockId)
            }
        }
    }

    fun encodeAll(items: List<NoteTape>): org.json.JSONArray {
        val array = org.json.JSONArray()
        for (item in items) {
            array.put(encode(item))
        }
        return array
    }
}

private val tapePresetHexes = listOf(
    "#FCEEAC", // 暖黃
    "#FFD1DC", // 柔粉
    "#C8E6C9", // 薄荷綠
    "#BBDEFB", // 晴空藍
    "#FFE0B2", // 淺杏橙
    "#E1BEE7", // 薰衣草紫
    "#CFD8DC"  // 莫蘭迪灰
)

/**
 * 遮蔽膠帶覆蓋層（Masking Tape Overlay）。
 *
 * 在筆記上貼附膠帶以覆蓋文字或考題答案，點一下即可翻開（Reveal）或遮回，
 * 方便背誦或自我測驗。與 Apple 端 MaskingTapeOverlayView 完全對齊。
 *
 * 支援多筆繪製、選取、移動、拉伸縮放、切換顏色、翻開/遮蔽與刪除。
 */
@Composable
fun MaskingTapeOverlay(
    pageIndex: Int,
    isActive: Boolean,
    tapeColor: Color = Color(0xFFFCEEAC),
    currentInkHex: String = "#FCEEAC",
    tapes: MutableList<NoteTape>,
    onTapesChanged: () -> Unit = {},
    modifier: Modifier = Modifier
) {
    val density = LocalDensity.current.density
    var selectedTapeId by remember { mutableStateOf<String?>(null) }
    var dragStart by remember { mutableStateOf<Offset?>(null) }
    var currentDragRect by remember { mutableStateOf<Rect?>(null) }

    Box(
        modifier = modifier
            .fillMaxSize()
            .then(
                if (isActive) {
                    Modifier.pointerInput(Unit) {
                        detectDragGestures(
                            onDragStart = { start ->
                                selectedTapeId = null
                                dragStart = start
                            },
                            onDrag = { change, _ ->
                                val start = dragStart ?: return@detectDragGestures
                                val pos = change.position
                                val x = min(start.x, pos.x) / density
                                val y = (start.y - 20f) / density
                                val width = max(abs(pos.x - start.x) / density, 20f)
                                val height = 36f
                                currentDragRect = Rect(x, y, x + width, y + height)
                            },
                            onDragEnd = {
                                currentDragRect?.let { r ->
                                    val newTape = NoteTape(
                                        pageIndex = pageIndex,
                                        x = r.left,
                                        y = r.top,
                                        width = r.width,
                                        height = r.height,
                                        colorHex = currentInkHex
                                    )
                                    tapes.add(newTape)
                                    selectedTapeId = newTape.id
                                    onTapesChanged()
                                }
                                dragStart = null
                                currentDragRect = null
                            },
                            onDragCancel = {
                                dragStart = null
                                currentDragRect = null
                            }
                        )
                    }
                } else {
                    Modifier
                }
            )
    ) {
        val pageTapes = tapes.filter { it.pageIndex == pageIndex }
        for (tape in pageTapes) {
            val isSelected = isActive && selectedTapeId == tape.id
            val parsedColor = runCatching { Color(android.graphics.Color.parseColor(tape.colorHex)) }.getOrDefault(tapeColor)
            val tapeAlpha = if (tape.isRevealed) 0.18f else 0.92f

            Box(
                modifier = Modifier
                    .offset {
                        IntOffset(
                            (tape.x * density).toInt(),
                            (tape.y * density).toInt()
                        )
                    }
                    .size((tape.width).dp, (tape.height).dp)
                    .background(
                        parsedColor.copy(alpha = tapeAlpha),
                        shape = RoundedCornerShape(4.dp)
                    )
                    .border(
                        if (isSelected) 1.5.dp else 1.dp,
                        if (isSelected) MaterialTheme.colorScheme.primary else parsedColor.copy(alpha = 0.6f),
                        shape = RoundedCornerShape(4.dp)
                    )
                    .clickable {
                        if (isActive) {
                            if (isSelected) {
                                val idx = tapes.indexOfFirst { it.id == tape.id }
                                if (idx >= 0) {
                                    tapes[idx] = tape.copy(isRevealed = !tape.isRevealed)
                                    onTapesChanged()
                                }
                            } else {
                                selectedTapeId = tape.id
                            }
                        } else {
                            val idx = tapes.indexOfFirst { it.id == tape.id }
                            if (idx >= 0) {
                                tapes[idx] = tape.copy(isRevealed = !tape.isRevealed)
                                onTapesChanged()
                            }
                        }
                    }
                    .then(
                        if (isSelected) {
                            Modifier.pointerInput(tape.id) {
                                detectDragGestures(onDragEnd = { onTapesChanged() }) { change, dragAmount ->
                                    change.consume()
                                    val idx = tapes.indexOfFirst { it.id == tape.id }
                                    if (idx >= 0) {
                                        val cur = tapes[idx]
                                        tapes[idx] = cur.copy(
                                            x = cur.x + dragAmount.x / density,
                                            y = cur.y + dragAmount.y / density
                                        )
                                    }
                                }
                            }
                        } else Modifier
                    )
            ) {
                // 左縮放把手
                if (isSelected) {
                    Box(
                        modifier = Modifier
                            .align(Alignment.CenterStart)
                            .offset((-10).dp, 0.dp)
                            .size(24.dp)
                            .pointerInput(tape.id) {
                                detectDragGestures(onDragEnd = { onTapesChanged() }) { change, dragAmount ->
                                    change.consume()
                                    val idx = tapes.indexOfFirst { it.id == tape.id }
                                    if (idx >= 0) {
                                        val cur = tapes[idx]
                                        val deltaX = dragAmount.x / density
                                        val newW = max(20f, cur.width - deltaX)
                                        val actualDelta = cur.width - newW
                                        tapes[idx] = cur.copy(
                                            x = cur.x + actualDelta,
                                            width = newW
                                        )
                                    }
                                }
                            },
                        contentAlignment = Alignment.Center
                    ) {
                        Box(
                            modifier = Modifier
                                .size(12.dp)
                                .background(Color.White, CircleShape)
                                .border(2.dp, MaterialTheme.colorScheme.primary, CircleShape)
                        )
                    }

                    // 右縮放把手
                    Box(
                        modifier = Modifier
                            .align(Alignment.CenterEnd)
                            .offset(10.dp, 0.dp)
                            .size(24.dp)
                            .pointerInput(tape.id) {
                                detectDragGestures(onDragEnd = { onTapesChanged() }) { change, dragAmount ->
                                    change.consume()
                                    val idx = tapes.indexOfFirst { it.id == tape.id }
                                    if (idx >= 0) {
                                        val cur = tapes[idx]
                                        val deltaX = dragAmount.x / density
                                        val newW = max(20f, cur.width + deltaX)
                                        tapes[idx] = cur.copy(width = newW)
                                    }
                                }
                            },
                        contentAlignment = Alignment.Center
                    ) {
                        Box(
                            modifier = Modifier
                                .size(12.dp)
                                .background(Color.White, CircleShape)
                                .border(2.dp, MaterialTheme.colorScheme.primary, CircleShape)
                        )
                    }
                }

                // 未選中時右上角小刪除按鈕
                if (isActive && !isSelected) {
                    IconButton(
                        onClick = {
                            tapes.removeAll { it.id == tape.id }
                            onTapesChanged()
                        },
                        modifier = Modifier
                            .align(Alignment.CenterEnd)
                            .size(24.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Close,
                            contentDescription = com.kairumo.padnote.L10n.t("tape_delete"),
                            tint = Color.DarkGray,
                            modifier = Modifier.size(14.dp)
                        )
                    }
                }
            }

            // 選中時在上方浮現快捷色票與操作面板
            if (isSelected) {
                Box(
                    modifier = Modifier
                        .offset {
                            IntOffset(
                                (tape.x * density).toInt(),
                                ((tape.y - 48f) * density).toInt()
                            )
                        }
                        .shadow(4.dp, RoundedCornerShape(20.dp))
                        .background(MaterialTheme.colorScheme.surface, RoundedCornerShape(20.dp))
                        .padding(horizontal = 8.dp, vertical = 4.dp)
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        for (hex in tapePresetHexes) {
                            val c = runCatching { Color(android.graphics.Color.parseColor(hex)) }.getOrDefault(Color.Yellow)
                            val isColorActive = tape.colorHex.equals(hex, ignoreCase = true)
                            Box(
                                modifier = Modifier
                                    .size(18.dp)
                                    .background(c, CircleShape)
                                    .border(
                                        if (isColorActive) 2.dp else 1.dp,
                                        if (isColorActive) MaterialTheme.colorScheme.primary else Color.Gray.copy(alpha = 0.4f),
                                        CircleShape
                                    )
                                    .clickable {
                                        val idx = tapes.indexOfFirst { it.id == tape.id }
                                        if (idx >= 0) {
                                            tapes[idx] = tape.copy(colorHex = hex)
                                            onTapesChanged()
                                        }
                                    }
                            )
                        }

                        Divider(
                            modifier = Modifier
                                .height(14.dp)
                                .width(1.dp)
                        )

                        // 翻開 / 遮回切換
                        IconButton(
                            onClick = {
                                val idx = tapes.indexOfFirst { it.id == tape.id }
                                if (idx >= 0) {
                                    tapes[idx] = tape.copy(isRevealed = !tape.isRevealed)
                                    onTapesChanged()
                                }
                            },
                            modifier = Modifier.size(24.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Default.Refresh,
                                contentDescription = com.kairumo.padnote.L10n.t("tape_toggle"),
                                tint = MaterialTheme.colorScheme.primary,
                                modifier = Modifier.size(16.dp)
                            )
                        }

                        // 刪除按鈕
                        IconButton(
                            onClick = {
                                selectedTapeId = null
                                tapes.removeAll { it.id == tape.id }
                                onTapesChanged()
                            },
                            modifier = Modifier.size(24.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Default.Delete,
                                contentDescription = com.kairumo.padnote.L10n.t("tape_delete"),
                                tint = MaterialTheme.colorScheme.error,
                                modifier = Modifier.size(16.dp)
                            )
                        }
                    }
                }
            }
        }

        // 正在拖曳產生的預覽膠帶
        currentDragRect?.let { r ->
            Box(
                modifier = Modifier
                    .offset {
                        IntOffset(
                            (r.left * density).toInt(),
                            (r.top * density).toInt()
                        )
                    }
                    .size((r.width).dp, (r.height).dp)
                    .background(
                        tapeColor.copy(alpha = 0.75f),
                        shape = RoundedCornerShape(4.dp)
                    )
                    .border(
                        1.5.dp,
                        MaterialTheme.colorScheme.primary,
                        shape = RoundedCornerShape(4.dp)
                    )
            )
        }
    }
}

