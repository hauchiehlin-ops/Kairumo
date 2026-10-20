package com.kairumo.padnote.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.zIndex
import kotlin.math.cos
import kotlin.math.sin

/**
 * 徑向飛輪快捷工具項目定義
 */
data class RadialMenuItem(
    val id: String,
    val icon: String,
    val label: String,
    val color: Color = Color.Unspecified,
    val action: () -> Unit
)

/**
 * 專業級徑向飛輪快捷工具盤 (Radial Pie / Mark Menu - Android 版)。
 *
 * 在手指長按或觸控筆側鍵觸發時，於落筆位置以 360° 環形彈出高頻功能。
 * 使用者只需輕輕向任一扇區滑動或點擊即可切換工具，完全不中斷創作心流。
 */
@Composable
fun RadialMarkMenu(
    visible: Boolean,
    centerOffset: Offset,
    items: List<RadialMenuItem>,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier
) {
    if (!visible) return

    val haptic = LocalHapticFeedback.current
    val density = LocalDensity.current

    // 飛輪幾何參數 (dp)
    val radiusDp = 88.dp
    val itemSizeDp = 46.dp
    val radiusPx = with(density) { radiusDp.toPx() }

    Box(
        modifier = modifier
            .fillMaxSize()
            .zIndex(10_000f)
            .background(Color.Black.copy(alpha = 0.15f))
            .pointerInput(Unit) {
                detectTapGestures(onTap = { onDismiss() })
            }
    ) {
        AnimatedVisibility(
            visible = visible,
            enter = fadeIn(spring()) + scaleIn(spring(dampingRatio = 0.76f, stiffness = 400f)),
            exit = fadeOut() + scaleOut()
        ) {
            Box(modifier = Modifier.fillMaxSize()) {
                // 中央指示錨點 (32dp)
                Box(
                    modifier = Modifier
                        .offset {
                            IntOffset(
                                (centerOffset.x - with(density) { 16.dp.toPx() }).toInt(),
                                (centerOffset.y - with(density) { 16.dp.toPx() }).toInt()
                            )
                        }
                        .size(32.dp)
                        .clip(CircleShape)
                        .background(MaterialTheme.colorScheme.surface.copy(alpha = 0.9f))
                        .border(2.dp, MaterialTheme.colorScheme.primary.copy(alpha = 0.5f), CircleShape)
                        .shadow(6.dp, CircleShape)
                )

                // 環形分佈之快捷按鈕
                items.forEachIndexed { index, item ->
                    val angle = angleForIndex(index, items.size)
                    val offsetX = cos(angle) * radiusPx
                    val offsetY = sin(angle) * radiusPx

                    var isPressed by remember { mutableStateOf(false) }
                    val scale by animateFloatAsState(
                        targetValue = if (isPressed) 1.15f else 1.0f,
                        label = "radial_scale"
                    )

                    Box(
                        modifier = Modifier
                            .offset {
                                IntOffset(
                                    (centerOffset.x + offsetX - with(density) { (itemSizeDp / 2).toPx() }).toInt(),
                                    (centerOffset.y + offsetY - with(density) { (itemSizeDp / 2).toPx() }).toInt()
                                )
                            }
                            .size(itemSizeDp)
                            .scale(scale)
                            .shadow(6.dp, CircleShape)
                            .clip(CircleShape)
                            .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.95f))
                            .border(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f), CircleShape)
                            .clickable {
                                haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                                item.action()
                                onDismiss()
                            },
                        contentAlignment = Alignment.Center
                    ) {
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            Text(
                                text = item.icon,
                                fontSize = 15.sp
                            )
                            Text(
                                text = item.label,
                                style = MaterialTheme.typography.labelSmall.copy(
                                    fontSize = 8.sp,
                                    fontWeight = FontWeight.Bold
                                ),
                                color = if (item.color != Color.Unspecified) item.color else MaterialTheme.colorScheme.onSurfaceVariant,
                                maxLines = 1
                            )
                        }
                    }
                }
            }
        }
    }
}

private fun angleForIndex(index: Int, total: Int): Double {
    val step = (2.0 * Math.PI) / total.toDouble()
    // 從正上方 (-90度) 起始
    return - (Math.PI / 2.0) + (index.toDouble() * step)
}

/** 長按叫出飛梭工具盤的等待時間。與 Apple 的 `AdaptiveCanvasView.pressHoldDuration` 一致。 */
const val PRESS_HOLD_MILLIS = 550L
/** 落下後移動超過這個距離（dp）就不算長按。與 Apple 的 `pressHoldMaxJitter` 一致。 */
private const val PRESS_HOLD_SLOP_DP = 8f

/**
 * 筆尖或單指落在畫布上、**還沒移動**就停住 [PRESS_HOLD_MILLIS]，於落點呼叫 [onHold]。
 *
 * 與 Hold-to-Snap 不衝突：那個是「畫了一段之後停住」，這個是「落下就停住」，
 * 以「落下後有沒有移動過」區分；時間也比 Hold-to-Snap 長，避免誤觸。
 *
 * 看的是 `Initial` 階段、不消費 —— 底下的畫布照常收到落筆。`onHold` 回傳 true（已打開工具盤）
 * 之後才把這一次觸控剩下的事件全部消費掉：畫布的 `pointerInteropFilter` 看到被消費會收到
 * ACTION_CANCEL，落下的那一點就不會留在頁面上（呼叫端也要 `cancelInFlight`）。
 * 第二根手指落下（捏合、雙指捲動）就作廢。
 */
fun Modifier.pressAndHoldForRadialMenu(
    key: Any?,
    onHold: (Offset) -> Boolean
): Modifier = pointerInput(key) {
    val slop = PRESS_HOLD_SLOP_DP * density
    awaitEachGesture {
        val down = awaitFirstDown(requireUnconsumed = false, pass = PointerEventPass.Initial)
        val origin = down.position
        var aborted = false
        val stillHeld = withTimeoutOrNull(PRESS_HOLD_MILLIS) {
            while (true) {
                val event = awaitPointerEvent(PointerEventPass.Initial)
                val pressed = event.changes.filter { it.pressed }
                val tracked = event.changes.firstOrNull { it.id == down.id }
                if (pressed.size != 1 || tracked == null || !tracked.pressed ||
                    (tracked.position - origin).getDistance() > slop
                ) {
                    aborted = true
                    break
                }
            }
        }
        // withTimeoutOrNull 逾時回 null：手還按著、沒動過 → 長按成立。
        if (stillHeld != null || aborted) return@awaitEachGesture
        if (!onHold(origin)) return@awaitEachGesture
        // 收掉這一次觸控剩下的事件，直到所有手指離開。
        while (true) {
            val event = awaitPointerEvent(PointerEventPass.Initial)
            event.changes.forEach { it.consume() }
            if (event.changes.none { it.pressed }) break
        }
    }
}

/**
 * 飛梭工具盤的中心：往內收，整圈都要在畫面裡。
 * 半徑 88dp + 按鈕半徑 23dp + 一點邊。
 */
fun clampRadialCenter(point: Offset, viewportWidth: Float, viewportHeight: Float, density: Float): Offset {
    val margin = 120f * density
    return Offset(
        point.x.coerceIn(margin, maxOf(margin, viewportWidth - margin)),
        point.y.coerceIn(margin, maxOf(margin, viewportHeight - margin))
    )
}

/**
 * 編輯器的飛梭工具盤：八個項目的外觀在這裡，動作由呼叫端依 id 處理。
 *
 * 從編輯器畫面搬出來的原因：整頁與連續兩種模式都要用，而編輯器那個 Composable 已經大到
 * ART 驗證器的上限 —— 在裡面多寫一份就 VerifyError 閃退。
 */
@Composable
fun EditorRadialMenu(
    center: Offset,
    l: (String) -> String,
    /** 項目的 id；點選單外面是 [RADIAL_DISMISS]。 */
    onAction: (String) -> Unit
) {
    RadialMarkMenu(
        visible = true,
        centerOffset = center,
        items = listOf(
            RadialMenuItem(id = "pen", icon = "✏️", label = l("tool_pen"), color = MaterialTheme.colorScheme.primary) { onAction("pen") },
            RadialMenuItem(id = "highlighter", icon = "🖍️", label = l("tool_highlighter"), color = Color(0xFFF59E0B)) { onAction("highlighter") },
            RadialMenuItem(id = "eraser", icon = "🧹", label = l("tool_eraser"), color = Color(0xFFEF4444)) { onAction("eraser") },
            RadialMenuItem(id = "lasso", icon = "➰", label = l("tool_lasso"), color = Color(0xFF8B5CF6)) { onAction("lasso") },
            RadialMenuItem(id = "undo", icon = "↩️", label = l("undo"), color = Color(0xFF3B82F6)) { onAction("undo") },
            RadialMenuItem(id = "redo", icon = "↪️", label = l("redo"), color = Color(0xFF3B82F6)) { onAction("redo") },
            RadialMenuItem(id = "color", icon = "🎨", label = l("pro_color"), color = Color(0xFFEC4899)) { onAction("color") },
            RadialMenuItem(id = "stabilizer", icon = "〰️", label = l("refine_sketch"), color = Color(0xFF10B981)) { onAction("stabilizer") }
        ),
        onDismiss = { onAction(RADIAL_DISMISS) }
    )
}

/** [EditorRadialMenu] 點選單外面時送出的動作 id。 */
const val RADIAL_DISMISS = "dismiss"

/**
 * 「長按叫出飛梭工具盤」的區域（連續頁面模式用；整頁模式直接掛 [pressAndHoldForRadialMenu]）。
 *
 * 自己量區域大小、算往內收的中心（[clampRadialCenter]）並給觸覺回饋；`canOpen` 回 false 時
 * 這一次長按不攔，底下照常畫。`onOpen` 拿到的是這塊區域裡的座標，選單也要疊在同一塊區域裡。
 */
fun Modifier.radialHoldArea(
    /** 這一刻能不能叫出（繪圖模式、選單沒開著、不是放圖釘或遮蔽膠帶）。 */
    enabled: Boolean,
    /** 套索模式時的選取：正在拖曳或已有選取就不叫出（長按是要搬它）。不是套索模式傳 null。 */
    lasso: com.kairumo.padnote.canvas.LassoSelection?,
    /** 打開：中心點（這塊區域裡的座標，已往內收）。 */
    onOpen: (Offset) -> Unit
): Modifier = composed {
    val haptic = LocalHapticFeedback.current
    val density = LocalDensity.current.density
    val canOpen by androidx.compose.runtime.rememberUpdatedState(enabled)
    var size by remember { mutableStateOf(androidx.compose.ui.unit.IntSize.Zero) }
    onSizeChanged { size = it }
        .pressAndHoldForRadialMenu(lasso) { point ->
            if (!canOpen || (lasso != null && (lasso.isDragging || lasso.hasSelection))) {
                return@pressAndHoldForRadialMenu false
            }
            // 落下的那一點：這之後手勢把事件全部消費掉，畫布收到 ACTION_CANCEL 就丟掉它。
            lasso?.cancelGesture()
            onOpen(clampRadialCenter(point, size.width.toFloat(), size.height.toFloat(), density))
            haptic.performHapticFeedback(HapticFeedbackType.LongPress)
            true
        }
}
