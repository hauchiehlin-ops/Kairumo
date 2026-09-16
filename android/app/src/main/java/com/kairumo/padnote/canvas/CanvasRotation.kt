package com.kairumo.padnote.canvas

import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.background
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import com.kairumo.padnote.LocalizationStrings
import com.kairumo.padnote.ui.LocalAppLanguage
import androidx.compose.ui.unit.dp
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.round
import kotlin.math.sin

/**
 * 畫布物件的自由角度旋轉規則。
 *
 * **數值必須與 Apple 端的 `CanvasRotation`（`NotebookStore.swift`）一致。**
 * 兩邊吸附角度不同的話，同一個物件在兩個平台拖出來的角度會停在不同地方，
 * 而使用者只會覺得「同步壞了」。
 */
object CanvasRotation {

    /** 拖曳旋轉把手時吸附到這個倍數（度）。 */
    const val SNAP_STEP = 15f

    /** 距離吸附角多少度以內才吸附。超過就自由角度。 */
    const val SNAP_TOLERANCE = 3f

    /** 把任意角度正規化到 [0, 360)。 */
    fun normalized(degrees: Float): Float {
        val r = degrees % 360f
        return if (r < 0f) r + 360f else r
    }

    /**
     * 拖曳中的角度 → 實際要套用的角度（含吸附）。
     *
     * 吸附只在**接近**整數角時發生。無條件吸附的話使用者就永遠轉不出 22°
     * 這種角度，而「自由角度」正是這個功能的重點。
     */
    fun snapped(degrees: Float): Float {
        val value = normalized(degrees)
        val nearest = round(value / SNAP_STEP) * SNAP_STEP
        return if (abs(value - nearest) <= SNAP_TOLERANCE) normalized(nearest) else value
    }

    /**
     * 點是否落在一個**旋轉過**的矩形內。
     *
     * 把點反向旋轉回物件自己的座標系，再做一般的矩形判斷。少了這一步，
     * 物件轉過之後看得到卻點不到，而且角度越大錯得越離譜。
     */
    fun contains(
        px: Float, py: Float,
        centerX: Float, centerY: Float,
        width: Float, height: Float,
        degrees: Float
    ): Boolean {
        val radians = (-normalized(degrees) * Math.PI / 180.0).toFloat()
        val dx = px - centerX
        val dy = py - centerY
        val localX = dx * cos(radians) - dy * sin(radians)
        val localY = dx * sin(radians) + dy * cos(radians)
        return abs(localX) <= width / 2f && abs(localY) <= height / 2f
    }
}

/**
 * 畫布上的旋轉把手。
 *
 * 必須疊在物件的**未旋轉**版面框上，不能放進 `graphicsLayer { rotationZ = … }`
 * 裡面 —— 包進旋轉裡的話，拖曳算出的角度會疊加自身旋轉，物件會失控加速。
 *
 * @param widthDp／@param heightDp 物件未旋轉時的尺寸，用來算把手位置。
 */
@Composable
fun RotationHandle(
    degrees: Float,
    widthDp: Float,
    heightDp: Float,
    density: Float,
    onRotate: (Float) -> Unit,
    onCommit: () -> Unit,
    modifier: Modifier = Modifier
) {
    val handleLabel = LocalizationStrings.localized("rotate_handle", LocalAppLanguage.current)
    val radius = (maxOf(heightDp, 40f) / 2f) + 52f
    // 元件自己撐出容納軌道的空間，**不要**用負的 offset 把把手畫到父容器外面。
    // 負偏移看起來可行，但只要任何一層祖先有裁切，把手就整個消失 ——
    // 而且只在把手轉到物件上方時消失，轉到右邊又看得見，非常難查
    // （實機上就是這樣：0° 看不到、90° 看得到）。
    val margin = radius + HANDLE_DP

    Box(
        modifier = modifier
            .offset(x = (-margin).dp, y = (-margin).dp)
            .size((widthDp + margin * 2).dp, (heightDp + margin * 2).dp)
    ) {
        val radians = (CanvasRotation.normalized(degrees) * Math.PI / 180.0).toFloat()
        // 把手在未旋轉座標系裡是正上方 (0, -radius)，隨物件角度繞中心轉。
        val cx = margin + widthDp / 2f
        val cy = margin + heightDp / 2f
        val hx = cx + sin(radians) * radius
        val hy = cy - cos(radians) * radius

        Box(
            modifier = Modifier
                .offset(x = (hx - HANDLE_DP / 2f).dp, y = (hy - HANDLE_DP / 2f).dp)
                .size(HANDLE_DP.dp)
                .background(MaterialTheme.colorScheme.primary, CircleShape)
                .pointerInput(Unit) {
                    detectDragGestures(
                        onDrag = { change, _ ->
                            change.consume()
                            // change.position 相對於把手自己，換算回物件中心。
                            val px = change.position.x / density + (hx - HANDLE_DP / 2f)
                            val py = change.position.y / density + (hy - HANDLE_DP / 2f)
                            // atan2 的 0 在 +x 方向，把手的 0 在正上方，差 90°。
                            val raw = Math.toDegrees(
                                atan2(py - cy, px - cx).toDouble()
                            ).toFloat() + 90f
                            onRotate(CanvasRotation.snapped(raw))
                        },
                        onDragEnd = { onCommit() }
                    )
                }
                // 標籤放在**可拖曳的容器**上，不是裡面那顆圖示 —— 圖示是
                // 裝飾（所以維持 null），真正能操作的是這個 Box。
                // 沒有它的話，TalkBack 掃過畫布上的把手時什麼也不會念。
                .semantics { contentDescription = handleLabel }
        ) {
            Icon(
                imageVector = Icons.Filled.Refresh,
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier.size(16.dp).offset(5.dp, 5.dp)
            )
        }
    }
}

private const val HANDLE_DP = 26f
