package com.kairumo.padnote.ink

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.Color
import uniffi.padnote_core.FfiDraftLayer
import uniffi.padnote_core.FfiDraftPen
import uniffi.padnote_core.draftLayers
import uniffi.padnote_core.draftPens

/**
 * 圖學的編輯狀態（對應 Apple 的 `DraftingState`）：目前的製圖筆、要畫在哪一層、
 * 各圖層的顯示與鎖定、吸附與角度鎖定。
 *
 * 圖層與筆組的**定義**在核心（`ffi_draft.rs`），這裡只存使用者的選擇。顯示／鎖定是
 * 這台裝置、這本筆記的檢視狀態，不同步 —— 在平板上隱藏了輔助線，不該讓手機上的同一本
 * 筆記也跟著少了線。
 */
object DraftingState {
    val layers: List<FfiDraftLayer> by lazy { draftLayers() }
    val pens: List<FfiDraftPen> by lazy { draftPens() }

    val angleChoices = listOf(0, 15, 30, 45, 90)

    private var prefs: android.content.SharedPreferences? = null

    /** 目前的製圖筆編號。 */
    var activePenId by mutableStateOf("thick")
        private set

    /** 畫在哪一層。0 = 跟著筆走。 */
    var layerOverride by mutableIntStateOf(0)
        private set

    var snapEnabled by mutableStateOf(true)
        private set

    /** 角度鎖定（度）。0 = 自由。 */
    var angleStep by mutableIntStateOf(15)
        private set

    private var reassignFlag by mutableStateOf(false)
    private var markerFlag by mutableStateOf(false)

    /** 點筆畫就把它改到目前圖層。 */
    var reassignMode: Boolean
        get() = reassignFlag
        set(value) {
            reassignFlag = value
            if (value) markerFlag = false
        }

    /** 點一下就放一個步驟編號（①②③…，畫在中層）。 */
    var markerMode: Boolean
        get() = markerFlag
        set(value) {
            markerFlag = value
            if (value) reassignFlag = false
        }

    /** 下一個要放的編號。 */
    var stepNumber by mutableIntStateOf(1)

    /** 面板收合：-1 = 還沒選過（由螢幕寬度決定，手機預設收合）、0 = 展開、1 = 收合。 */
    var compactChoice by mutableIntStateOf(-1)
        private set

    /** 第一次使用的提示卡看過了沒。 */
    var tipsSeen by mutableStateOf(false)
        private set

    fun setCompact(compact: Boolean) {
        compactChoice = if (compact) 1 else 0
        prefs?.edit()?.putInt("compact", compactChoice)?.apply()
    }

    fun markTipsSeen() {
        tipsSeen = true
        prefs?.edit()?.putBoolean("tipsSeen", true)?.apply()
    }

    /** 每次顯示／鎖定改動就 +1，畫布讀它來重畫。 */
    var version by mutableIntStateOf(0)
        private set

    private var notebookKey = ""
    private var hidden: Set<Int> by mutableStateOf(emptySet())
    private var locked: Set<Int> by mutableStateOf(emptySet())

    fun attach(context: Context) {
        if (prefs != null) return
        val p = context.applicationContext.getSharedPreferences("kairumo_drafting", Context.MODE_PRIVATE)
        prefs = p
        activePenId = p.getString("pen", "thick") ?: "thick"
        layerOverride = p.getInt("layer", 0)
        snapEnabled = p.getBoolean("snap", true)
        angleStep = p.getInt("angle", 15)
        compactChoice = p.getInt("compact", -1)
        tipsSeen = p.getBoolean("tipsSeen", false)
    }

    /** 換筆記本：讀它自己的顯示／鎖定。 */
    fun use(notebookId: String) {
        val key = notebookId.lowercase()
        if (key == notebookKey) return
        notebookKey = key
        val p = prefs
        hidden = p?.getStringSet("hidden.$key", emptySet())?.mapNotNull { it.toIntOrNull() }?.toSet() ?: emptySet()
        locked = p?.getStringSet("locked.$key", emptySet())?.mapNotNull { it.toIntOrNull() }?.toSet() ?: emptySet()
        version++
    }

    val activePen: FfiDraftPen get() = pens.firstOrNull { it.id == activePenId } ?: pens.first()

    /** 這一筆寫進的圖層。 */
    val activeLayerId: Int get() = if (layerOverride != 0) layerOverride else activePen.layer.toInt()

    val activeLineType: Int get() = activePen.lineType.toInt()

    /** 目前的筆色。畫在別的圖層時用那一層的代表色（輔助層永遠是淺藍）。 */
    val activeColorHex: String
        get() = layers.firstOrNull { it.id.toInt() == layerOverride }?.colorHex ?: activePen.colorHex

    fun layerColor(id: Int): Color =
        layers.firstOrNull { it.id.toInt() == id }?.let { parseHex(it.colorHex) } ?: Color.Gray

    fun selectPen(id: String) {
        activePenId = id
        layerOverride = 0   // 換筆回到「跟著筆走」，不然上一支筆的圖層設定會莫名其妙留著。
        prefs?.edit()?.putString("pen", id)?.putInt("layer", 0)?.apply()
        version++
    }

    fun toggleTarget(layer: Int) {
        layerOverride = if (layerOverride == layer) 0 else layer
        prefs?.edit()?.putInt("layer", layerOverride)?.apply()
        version++
    }

    fun setSnap(on: Boolean) {
        snapEnabled = on
        prefs?.edit()?.putBoolean("snap", on)?.apply()
    }

    fun selectAngle(deg: Int) {
        angleStep = deg
        prefs?.edit()?.putInt("angle", deg)?.apply()
    }

    /** 隱藏中的圖層（匯出時略過）。 */
    fun hiddenLayers(): ByteArray = hidden.sorted().map { it.toByte() }.toByteArray()

    fun isHidden(layer: Int) = layer != 0 && layer in hidden
    fun isLocked(layer: Int) = layer != 0 && layer in locked

    /** 擦除／改圖層動得了這一層嗎：隱藏或鎖定的都不行。 */
    fun canEdit(layer: Int) = !isHidden(layer) && !isLocked(layer)

    fun setHidden(layer: Int, on: Boolean) {
        hidden = if (on) hidden + layer else hidden - layer
        prefs?.edit()?.putStringSet("hidden.$notebookKey", hidden.map { it.toString() }.toSet())?.apply()
        version++
    }

    fun setLocked(layer: Int, on: Boolean) {
        locked = if (on) locked + layer else locked - layer
        prefs?.edit()?.putStringSet("locked.$notebookKey", locked.map { it.toString() }.toSet())?.apply()
        version++
    }

    /** 畫在隱藏的圖層上：自動顯示出來，不然使用者畫了卻什麼都沒有。 */
    fun ensureVisible(layer: Int) {
        if (isHidden(layer)) setHidden(layer, false)
    }

    /** 繪製順序：未分層 → 底 → 中 → 頂，隱藏的圖層略過。同層維持原本的先後。 */
    fun <T> drawOrder(strokes: List<T>, layerOf: (T) -> Int): List<T> {
        if (strokes.none { layerOf(it) != 0 }) return strokes
        return strokes.filter { layerOf(it) == 0 || !isHidden(layerOf(it)) }
            .withIndex().sortedWith(compareBy({ layerOf(it.value) }, { it.index })).map { it.value }
    }

    fun parseHex(hex: String): Color =
        runCatching { Color(android.graphics.Color.parseColor(hex)) }.getOrDefault(Color.Black)

    /**
     * 核心排好的一條製圖線 → 筆點。兩點的直線補點到每 4 個頁面單位一點：
     * 虛線與點畫線的間隔由筆點陣挖出來，點太稀會失準。
     */
    fun points(item: uniffi.padnote_core.FfiSheetStroke, ox: Float, oy: Float): List<uniffi.padnote_core.StrokePoint> {
        val pts = ArrayList<uniffi.padnote_core.StrokePoint>()
        fun add(x: Float, y: Float) {
            pts += uniffi.padnote_core.StrokePoint(
                x = x + ox, y = y + oy, pressure = 0.6f, tilt = 0f, azimuth = 0f, dtUs = 2000u, roll = 0f
            )
        }
        if (item.points.isEmpty()) return pts
        add(item.points[0].x, item.points[0].y)
        for (k in 1 until item.points.size) {
            val a = item.points[k - 1]
            val b = item.points[k]
            val n = kotlin.math.max(1, kotlin.math.ceil(kotlin.math.hypot(b.x - a.x, b.y - a.y) / 4f).toInt())
            for (s in 1..n) {
                val t = s.toFloat() / n
                add(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t)
            }
        }
        return pts
    }

    /** `#RRGGBB` → 筆畫用的 RGBA（不透明）。 */
    fun rgba(hex: String): ByteArray {
        val c = parseHex(hex)
        return byteArrayOf(
            (c.red * 255).toInt().toByte(), (c.green * 255).toInt().toByte(),
            (c.blue * 255).toInt().toByte(), -1
        )
    }
}
