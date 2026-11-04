package com.kairumo.padnote.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Divider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInRoot
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.zIndex
import kotlin.math.roundToInt

/**
 * 浮在畫布上的浮動工作面板（Android）。
 *
 * 與 Apple 端 `FloatingPanel.swift` 對齊：
 * - 取代 blocking modal sheet / AlertDialog：物件與控制項同時在畫面上，
 *   調整即時反映在畫布上，擋到了就把面板拖開。
 * - 標題列可拖曳移動、可收合、有關閉鈕。
 * - 非模態：畫布不會被遮蔽變暗，改動即時生效。
 */
/**
 * 正在編修的物件在螢幕上的框（根座標、像素）。物件被選取時由物件層回報
 * （形狀、圖片），編修面板據此把初始位置擺到物件的另一側 —— 與 Apple
 * `EditingObjectBoundsKey` + `FloatingPanel.avoidingOffset` 同一套規則。
 */
// profile-scope: device 螢幕上選取物件的框，純畫面狀態，不含使用者資料
object EditingObjectBounds {
    var rect by mutableStateOf<androidx.compose.ui.geometry.Rect?>(null)

    /** 物件層呼叫：選取中就回報，取消選取時清掉（只清自己回報的那一份）。 */
    fun report(id: String, selected: Boolean, bounds: androidx.compose.ui.geometry.Rect) {
        if (selected) { owner = id; rect = bounds } else if (owner == id) { owner = null; rect = null }
    }

    private var owner: String? = null
}

@Composable
fun FloatingPanel(
    title: String,
    onClose: () -> Unit,
    modifier: Modifier = Modifier,
    initialOffsetX: Float = 0f,
    initialOffsetY: Float = 24f,
    content: @Composable () -> Unit
) {
    var offsetX by remember { mutableFloatStateOf(initialOffsetX) }
    var offsetY by remember { mutableFloatStateOf(initialOffsetY) }
    var isCollapsed by remember { mutableStateOf(false) }
    // 使用者拖過面板之後以使用者的位置為準，不再自動避讓。
    var userMoved by remember { mutableStateOf(false) }
    var containerOrigin by remember { mutableStateOf(androidx.compose.ui.geometry.Offset.Zero) }

    BoxWithConstraints(
        modifier = modifier
            .fillMaxSize()
            .zIndex(900f)
            .onGloballyPositioned { containerOrigin = it.positionInRoot() }
    ) {
        val density = androidx.compose.ui.platform.LocalDensity.current.density
        val availableWidthDp = maxWidth.value
        val panelWidth = minOf(340f, maxOf(260f, availableWidthDp - 24f))
        val maxAvailableHeight = maxHeight.value - 60f
        val maxPanelHeight = minOf(640f, maxOf(240f, maxAvailableHeight))

        // 預設靠右上角（留 24dp 邊距）
        val baseRightX = (availableWidthDp - panelWidth - 24f).coerceAtLeast(0f)
        var currentX = (baseRightX + offsetX).coerceIn(0f, (availableWidthDp - panelWidth).coerceAtLeast(0f))
        var currentY = (offsetY).coerceIn(0f, (maxHeight.value - 100f).coerceAtLeast(0f))
        val avoid = EditingObjectBounds.rect
        if (!userMoved && avoid != null) {
            // 候選：右上（預設）、左上、物件下方、物件上方 —— 取與物件重疊最少的。
            val t = androidx.compose.ui.geometry.Rect(
                (avoid.left - containerOrigin.x) / density - 12f, (avoid.top - containerOrigin.y) / density - 12f,
                (avoid.right - containerOrigin.x) / density + 12f, (avoid.bottom - containerOrigin.y) / density + 12f)
            val panelH = if (isCollapsed) 52f else minOf(maxHeight.value, maxPanelHeight + 52f)
            val maxX = (availableWidthDp - panelWidth).coerceAtLeast(0f)
            val maxY = (maxHeight.value - panelH).coerceAtLeast(0f)
            val leftX = minOf(24f, maxX)
            fun y(v: Float) = v.coerceIn(0f, maxY)
            val candidates = listOf(
                currentX to currentY, leftX to currentY,
                currentX to y(t.bottom), currentX to y(t.top - panelH),
                leftX to y(t.bottom), leftX to y(t.top - panelH)
            )
            fun overlap(x: Float, yy: Float): Float {
                val r = androidx.compose.ui.geometry.Rect(x, yy, x + panelWidth, yy + panelH)
                val i = r.intersect(t)
                return if (i.width <= 0f || i.height <= 0f) 0f else i.width * i.height
            }
            val best = candidates.minByOrNull { (x, yy) -> overlap(x, yy) } ?: candidates[0]
            currentX = best.first
            currentY = best.second
        }
        // 拖曳區塊只在 key 變了才重啟：讀最新的落點要經過 rememberUpdatedState。
        val currentXState by androidx.compose.runtime.rememberUpdatedState(currentX)
        val currentYState by androidx.compose.runtime.rememberUpdatedState(currentY)
        val baseRightXState by androidx.compose.runtime.rememberUpdatedState(baseRightX)

        Surface(
            modifier = Modifier
                .offset { IntOffset((currentX * density).roundToInt(), (currentY * density).roundToInt()) }
                .width(panelWidth.dp)
                .shadow(8.dp, RoundedCornerShape(14.dp))
                .clip(RoundedCornerShape(14.dp))
                .border(0.5.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.6f), RoundedCornerShape(14.dp)),
            color = MaterialTheme.colorScheme.surface,
            shape = RoundedCornerShape(14.dp)
        ) {
            Column(modifier = Modifier.width(panelWidth.dp)) {
                // Header (可拖曳標題列)
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f))
                        .pointerInput(Unit) {
                            detectDragGestures { change, dragAmount ->
                                change.consume()
                                if (!userMoved) {
                                    // 從自動避讓的位置接手。
                                    userMoved = true
                                    offsetX = currentXState - baseRightXState
                                    offsetY = currentYState
                                }
                                offsetX += dragAmount.x / density
                                offsetY += dragAmount.y / density
                            }
                        }
                        .padding(horizontal = 12.dp, vertical = 6.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "≡",
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f),
                        modifier = Modifier.padding(end = 8.dp)
                    )
                    Text(
                        text = title,
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    Spacer(modifier = Modifier.weight(1f))
                    // 收合按鈕
                    IconButton(
                        onClick = { isCollapsed = !isCollapsed },
                        modifier = Modifier.size(28.dp)
                    ) {
                        Text(
                            text = if (isCollapsed) "▾" else "▴",
                            fontSize = 14.sp,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                    // 關閉按鈕
                    IconButton(
                        onClick = { onClose() },
                        modifier = Modifier.size(28.dp)
                    ) {
                        Box(
                            modifier = Modifier
                                .size(20.dp)
                                .background(MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.6f), CircleShape),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                text = "✕",
                                fontSize = 11.sp,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.onSurface
                            )
                        }
                    }
                }

                if (!isCollapsed) {
                    Divider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f), thickness = 0.5.dp)
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .heightIn(max = maxPanelHeight.dp)
                            .verticalScroll(rememberScrollState())
                            .padding(12.dp)
                    ) {
                        content()
                    }
                }
            }
        }
    }
}

