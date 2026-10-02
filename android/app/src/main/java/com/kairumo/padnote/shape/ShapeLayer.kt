package com.kairumo.padnote.shape

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.waitForUpOrCancellation
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.List
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.zIndex
import com.kairumo.padnote.LocalizationStrings
import com.kairumo.padnote.canvas.CanvasRotation
import com.kairumo.padnote.canvas.LocalObjectReorder
import com.kairumo.padnote.canvas.ObjectStacking
import com.kairumo.padnote.canvas.gesturesIf
import com.kairumo.padnote.ui.LocalAppLanguage
import uniffi.padnote_core.FfiPoint
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.sin

/** 拖曳連接點拉線時的預覽（頁面座標，單位是點）。 */
data class ConnectionDraft(val startX: Float, val startY: Float, val currentX: Float, val currentY: Float)

/**
 * 畫布上的形狀與連接線（Android）。
 *
 * 外框、連線路徑、箭頭全部照**核心算好的頂點**畫 —— 這一層不做任何幾何。
 * 自己畫一個「差不多的菱形」的話，同一張流程圖在 iPad 上的頂點位置會不一樣，
 * 連接線的落點也就跟著錯。
 *
 * # 編修（對應 Apple 的 `ShapeAttachmentItemView`）
 *
 * 選取之後：八個縮放把手（對面那條邊在畫布上釘住，轉過角度也成立）、旋轉把手、
 * 四個連接點「+」（拖到另一個形狀就連線）、編輯／層級／刪除鈕。線／箭頭則是兩個端點
 * 各自可拖（任意角度與長度）。連接線可以點選，然後改走線、端點樣式、顏色…
 *
 * # 為什麼所有把手都畫在一個「放大過的外層」裡
 *
 * Compose 的命中測試只會把事件交給**落在父容器範圍內**的子節點。把手若放在物件框的
 * 外面（負的偏移），那一塊就點不到 —— 而且只在某些角度、某些位置點不到，很難查。
 * 所以每個物件的外層多留一圈邊（[HANDLE_MARGIN]），把手全部用正的座標放在裡面。
 */
@Composable
fun ShapeLayer(
    /**
     * 這一層要不要吃觸控。
     *
     * 手寫模式下一律 false：使用者拿筆想在物件上圈重點，筆畫要到得了
     * 底下的畫布。與 Apple 端 `allowsHitTesting(editorMode != .draw)`
     * 是同一條規則 —— 兩邊不一致的話，同一個人換裝置就會發現
     * 「在 iPad 上圈得到重點，在 Android 上圈不到」。
     */
    interactive: Boolean,
    shapes: List<NoteShape>,
    connections: List<NoteConnection>,
    density: Float,
    selectedIds: Set<String>,
    onSelect: (String?) -> Unit,
    /** 開編輯面板。 */
    onEdit: (NoteShape) -> Unit,
    onDelete: (NoteShape) -> Unit,
    onChanged: (NoteShape) -> Unit,
    /**
     * 這個物件的堆疊 z 值。跨型別共用同一份順序（見 ObjectStacking）。
     */
    zIndexOf: (String) -> Float,
    modifier: Modifier = Modifier,
    selectedConnectionId: String? = null,
    onSelectConnection: (String?) -> Unit = {},
    onEditConnection: (NoteConnection) -> Unit = {},
    onDeleteConnection: (NoteConnection) -> Unit = {},
    connectionDraft: ConnectionDraft? = null,
    /** 從連接點拉線：座標是頁面座標；`finished == true` 是放開。 */
    onConnectDrag: (NoteShape, ShapeAnchor, FfiPoint, FfiPoint, Boolean) -> Unit = { _, _, _, _, _ -> }
) {
    val foreground = MaterialTheme.colorScheme.onSurface
    val background = MaterialTheme.colorScheme.surface
    val accent = MaterialTheme.colorScheme.primary
    val shapeById = shapes.associateBy { it.id }

    // 每條連接線的幾何只算一次：畫、命中測試、標籤、動作鈕都要用。
    val geometries = remember(connections, shapes) {
        connections.mapNotNull { link ->
            val from = shapeById[link.fromShapeId] ?: return@mapNotNull null
            val to = shapeById[link.toShapeId] ?: return@mapNotNull null
            val g = ShapeGeometry.connection(link, from, to) ?: return@mapNotNull null
            Triple(link, g, minOf(zIndexOf(from.id), zIndexOf(to.id)) - 0.1f)
        }
    }

    // **不包一層自己的 Box。**
    //
    // Compose 的 zIndex 只在**同一個父容器的兄弟之間**生效。每一層各包一個 Box
    // 的話，圖片的 zIndex 只跟圖片比、文字的只跟文字比 —— 跨型別永遠是
    // 「圖片一定在文字下面」，圖層面板就排不動。
    // 直接把物件發到呼叫端的 Box 裡，它們才是彼此的兄弟。

    // 連接線：畫在它連著的兩個形狀的**下面**，但仍然在更低層的其他物件之上。
    for ((link, g, z) in geometries) {
        ConnectionView(
            link = link, geometry = g, density = density, zIndex = z,
            color = link.colorHex?.let { parseColor(it) } ?: foreground,
            haloColor = accent, background = background,
            isSelected = link.id == selectedConnectionId,
            interactive = interactive,
            onSelect = { onSelectConnection(if (link.id == selectedConnectionId) null else link.id) },
            onEdit = { onEditConnection(link) },
            onDelete = { onDeleteConnection(link) }
        )
    }

    // 拉線預覽。
    if (connectionDraft != null) {
        Canvas(Modifier.fillMaxSize().zIndex(9000f)) {
            val s = density
            drawLine(
                color = Color(0xFF34C759),
                start = Offset(connectionDraft.startX * s, connectionDraft.startY * s),
                end = Offset(connectionDraft.currentX * s, connectionDraft.currentY * s),
                strokeWidth = 2f * s,
                cap = StrokeCap.Round,
                pathEffect = PathEffect.dashPathEffect(floatArrayOf(6f * s, 4f * s))
            )
            drawCircle(
                Color(0xFF34C759), radius = 5f * s,
                center = Offset(connectionDraft.currentX * s, connectionDraft.currentY * s)
            )
        }
    }

    for (shape in shapes) {
        ShapeObjectView(
            zIndex = zIndexOf(shape.id),
            shape = shape, density = density,
            isSelected = selectedIds.contains(shape.id),
            isSoleSelection = selectedIds.size <= 1,
            onSelect = onSelect, onEdit = onEdit, onDelete = onDelete,
            onChanged = onChanged, onConnectDrag = onConnectDrag,
            interactive = interactive
        )
    }
}

// =============================================================================
// 連接線
// =============================================================================

@Composable
private fun ConnectionView(
    link: NoteConnection,
    geometry: ShapeGeometry.Connection,
    density: Float,
    zIndex: Float,
    color: Color,
    haloColor: Color,
    background: Color,
    isSelected: Boolean,
    interactive: Boolean,
    onSelect: () -> Unit,
    onEdit: () -> Unit,
    onDelete: () -> Unit
) {
    // 命中測試只在線附近成立，其餘地方**不消耗事件** —— 這一層是整頁大小，
    // 一律吃下觸控的話，在空白處點一下新增文字方塊就再也不會發生。
    val hitSlop = 14f
    Canvas(
        Modifier
            .fillMaxSize()
            .zIndex(zIndex)
            .gesturesIf(interactive) {
                pointerInput(geometry) {
                    awaitEachGesture {
                        val down = awaitFirstDown(requireUnconsumed = true)
                        val px = down.position.x / density
                        val py = down.position.y / density
                        if (geometry.distanceTo(px, py) > hitSlop) return@awaitEachGesture
                        down.consume()
                        val up = waitForUpOrCancellation()
                        if (up != null) {
                            up.consume()
                            onSelect()
                        }
                    }
                }
            }
    ) {
        val s = density
        val path = Path().apply {
            moveTo(geometry.path[0].x * s, geometry.path[0].y * s)
            geometry.path.drop(1).forEach { lineTo(it.x * s, it.y * s) }
        }
        if (isSelected) {
            drawPath(
                path, haloColor.copy(alpha = 0.28f),
                style = Stroke(width = (link.lineWidth + 8f) * s, cap = StrokeCap.Round)
            )
        }
        drawPath(path, color, style = dashedStroke(link.lineWidth, link.dash, s))

        for (cap in listOfNotNull(geometry.startCap, geometry.endCap)) {
            drawCap(cap, color, background, link.lineWidth, s)
        }
        if (isSelected) {
            for (p in listOf(geometry.path.first(), geometry.path.last())) {
                drawCircle(Color.White, 5f * s, Offset(p.x * s, p.y * s))
                drawCircle(haloColor, 5f * s, Offset(p.x * s, p.y * s), style = Stroke(2f * s))
            }
        }
    }

    val mid = geometry.midpoint()
    if (link.label.isNotEmpty()) {
        Text(
            link.label,
            fontSize = 12.sp,
            color = MaterialTheme.colorScheme.onSurface,
            modifier = Modifier
                .zIndex(zIndex)
                .offset((mid.x - 30f).dp, (mid.y - 9f).dp)
                .background(background.copy(alpha = 0.9f))
        )
    }
    if (isSelected && interactive) {
        Box(Modifier.zIndex(9500f).offset((mid.x - 30f).dp, (mid.y - 40f).dp)) {
            RoundHandle(Icons.Filled.Edit, MaterialTheme.colorScheme.primary,
                LocalizationStrings.localized("edit", LocalAppLanguage.current), onEdit,
                Modifier.offset(0.dp, 0.dp))
            RoundHandle(Icons.Filled.Close, MaterialTheme.colorScheme.error,
                LocalizationStrings.localized("delete", LocalAppLanguage.current), onDelete,
                Modifier.offset(34.dp, 0.dp))
        }
    }
}

private fun DrawScope.drawCap(
    cap: ShapeGeometry.Cap, color: Color, background: Color, lineWidth: Float, s: Float
) {
    when (cap.kind) {
        ConnectionCap.NONE -> Unit
        ConnectionCap.CIRCLE ->
            drawCircle(color, cap.radius * s, Offset(cap.centerX * s, cap.centerY * s))
        ConnectionCap.ARROW, ConnectionCap.DIAMOND -> {
            if (cap.points.size < 3) return
            drawPath(polygon(cap.points, s), color)
        }
        ConnectionCap.HOLLOW -> {
            if (cap.points.size < 3) return
            val p = polygon(cap.points, s)
            // 空心 = 底色填滿再描邊，這樣線不會從箭頭裡穿出來。
            drawPath(p, background)
            drawPath(p, color, style = Stroke(width = lineWidth * s))
        }
    }
}

private fun polygon(points: List<FfiPoint>, s: Float): Path = Path().apply {
    moveTo(points[0].x * s, points[0].y * s)
    points.drop(1).forEach { lineTo(it.x * s, it.y * s) }
    close()
}

private fun dashedStroke(width: Float, dash: ShapeDash, s: Float): Stroke {
    val pattern = dash.pattern(width)
    return Stroke(
        width = width * s,
        cap = if (dash == ShapeDash.DOTTED) StrokeCap.Round else StrokeCap.Butt,
        pathEffect = pattern?.let { p -> PathEffect.dashPathEffect(FloatArray(p.size) { p[it] * s }) }
    )
}

// =============================================================================
// 形狀
// =============================================================================

/** 每個形狀外層多留的邊（dp）。把手都在這一圈裡，見 [ShapeLayer] 的說明。 */
private const val HANDLE_MARGIN = 56f
private const val HANDLE_SIZE = 34f

@Composable
private fun ShapeObjectView(
    /** 堆疊 z 值，見 ObjectStacking。 */
    zIndex: Float,
    shape: NoteShape,
    density: Float,
    isSelected: Boolean,
    isSoleSelection: Boolean,
    onSelect: (String?) -> Unit,
    onEdit: (NoteShape) -> Unit,
    onDelete: (NoteShape) -> Unit,
    onChanged: (NoteShape) -> Unit,
    onConnectDrag: (NoteShape, ShapeAnchor, FfiPoint, FfiPoint, Boolean) -> Unit,
    /** 見同檔案公開版本的說明。 */
    interactive: Boolean = true
) {
    // **手勢區塊裡一律讀 `current`，不要讀參數 `shape`。** `pointerInput` 的區塊只在 key 變了
    // 才重啟，拖曳進行中形狀每一幀都換成新的物件 —— 區塊裡抓到的若是第一幀的舊物件，
    // 每一幀都從同一個起點算起，結果是「拖了沒動」或「越拖越歪」。
    val current by androidx.compose.runtime.rememberUpdatedState(shape)
    val foreground = MaterialTheme.colorScheme.onSurface
    val stroke = shape.strokeColorHex?.let { parseColor(it) } ?: foreground
    val fill = when (val hex = shape.fillColorHex) {
        // "clear" 是哨符不是顏色 —— 走顏色轉換會變成黑色。
        "clear", null -> null
        else -> parseColor(hex)
    }
    val rotation = CanvasRotation.normalized(shape.rotationDegrees ?: 0f)
    val linear = shape.isLinear
    val showHandles = isSelected && interactive

    // 線狀形狀的外框只有 2dp 高，點不到。把命中區撐到至少 32dp，
    // 畫線時再往下平移讓線仍然在中央（旋轉中心不變）。
    val pad = if (linear) max(0f, (32f - shape.height) / 2f) else 0f
    val frameH = shape.height + pad * 2f
    val m = HANDLE_MARGIN

    // 座標的單位是**頁面點**（＝dp），與 Apple 端和 format-spec 一致。
    //
    // 原本這裡把存下來的值當成**像素**在用（offset 與 size 都除以 density，
    // 拖曳再乘回去）。在 density = 1.0 的模擬器上看不出差別 —— 但真實手機
    // 是 2～3.5 倍，同一本筆記裡的形狀會縮到三分之一並擠在左上角，
    // 而同一份筆記在 iPad 上位置是對的。文字方塊一直都用 dp，兩套並存
    // 代表同一頁裡的文字與形狀連相對位置都對不上。
    Box(
        Modifier
            .offset((shape.x - m).dp, (shape.y - pad - m).dp)
            .zIndex(zIndex)
            .size((shape.width + m * 2f).dp, (frameH + m * 2f).dp)
    ) {
        // ---- 本體（會旋轉的那一層）----
        Box(
            Modifier
                .offset(m.dp, m.dp)
                .size(shape.width.dp, frameH.dp)
                // 整個視圖一起轉（輪廓 + 標籤）。核心的 outline 刻意不轉：
                // 只轉輪廓的話標籤會留在正的，而且轉過的輪廓會超出畫布被裁掉。
                .graphicsLayer {
                    rotationZ = rotation
                    alpha = shape.opacity ?: 1f
                }
                .then(
                    if (isSelected && !linear) {
                        Modifier.border(1.dp, MaterialTheme.colorScheme.primary.copy(alpha = 0.7f))
                    } else Modifier
                )
                .gesturesIf(interactive) {
                    pointerInput(shape.id) {
                        detectTapGestures(
                            onTap = { onSelect(current.id) },
                            // 點兩下：開編輯面板（改文字、顏色、大小…）。
                            onDoubleTap = { onEdit(current) }
                        )
                    }
                }
                .gesturesIf(interactive) {
                    pointerInput(shape.id) {
                        // **從手勢開始時的形狀 ＋ 累計位移算起**，不要每一幀讀「目前」的形狀再加一小步：
                        // 兩幀之間若還沒重組，「目前」是舊的，每一步都從同一個起點算起，
                        // 結果只剩最後一步的位移（拖了沒動）。
                        var base: NoteShape? = null
                        var accX = 0f
                        var accY = 0f
                        detectDragGestures(
                            onDragStart = { base = current; accX = 0f; accY = 0f },
                            onDrag = { change, drag ->
                                change.consume()
                                val s0 = base ?: return@detectDragGestures
                                accX += drag.x
                                accY += drag.y
                                // 子節點座標系是**轉過的**：位移要轉回頁面座標才是搬動的方向。
                                val rad = (s0.rotationDegrees ?: 0f) * PI / 180.0
                                val c = cos(rad).toFloat()
                                val sn = sin(rad).toFloat()
                                val dx = (accX * c - accY * sn) / density
                                val dy = (accX * sn + accY * c) / density
                                onChanged(s0.copyShape().apply { x = s0.x + dx; y = s0.y + dy })
                            },
                            onDragEnd = {
                                val s0 = current
                                val landed = com.kairumo.padnote.ink.PageGeometry
                                    .clampOrigin(s0.x, s0.y, s0.width, s0.height)
                                if (landed.first != s0.x || landed.second != s0.y) {
                                    onChanged(s0.copyShape().apply { x = landed.first; y = landed.second })
                                }
                            }
                        )
                    }
                },
            contentAlignment = Alignment.Center
        ) {
            Canvas(Modifier.fillMaxSize()) {
                val points = shape.outline()
                if (points.size < 2) return@Canvas
                // Canvas 內部是像素，頂點是頁面點 —— 乘上 density。
                val scale = density
                val oy = pad
                fun px(p: FfiPoint) = (p.x - shape.x) * scale
                fun py(p: FfiPoint) = (p.y - shape.y + oy) * scale
                val path = Path().apply {
                    // 頂點是畫布座標，這個 Canvas 的原點在物件左上角 —— 要減掉偏移。
                    moveTo(px(points[0]), py(points[0]))
                    points.drop(1).forEach { lineTo(px(it), py(it)) }
                    // 線狀形狀（線／箭頭／雙箭頭）只有兩個點，不能收尾也不能填色。
                    if (!linear) close()
                }
                if (!linear) fill?.let { drawPath(path, it) }
                drawPath(path, stroke, style = dashedStroke(shape.lineWidth, shape.dash, scale))

                for (head in shape.arrowHeads()) {
                    val tri = Path().apply {
                        moveTo(px(head[0]), py(head[0]))
                        head.drop(1).forEach { lineTo(px(it), py(it)) }
                        close()
                    }
                    drawPath(tri, stroke)
                }
            }

            if (shape.acceptsText && shape.label.isNotEmpty()) {
                Text(
                    shape.label,
                    color = shape.textColorHex?.let { parseColor(it) } ?: foreground,
                    fontSize = (shape.fontSize ?: 14f).sp,
                    fontWeight = if (shape.isBold == true) FontWeight.Bold else FontWeight.Normal,
                    fontStyle = if (shape.isItalic == true) FontStyle.Italic else FontStyle.Normal,
                    textAlign = TextAlign.Center
                )
            }
        }

        if (showHandles) {
            if (linear) {
                if (isSoleSelection) EndpointHandles(shape, pad, m, density, onChanged)
            } else {
                if (isSoleSelection) ResizeHandles(shape, m, density, onChanged)
                RotateHandle(shape, m, density, onChanged)
                if (isSoleSelection) ConnectHandles(shape, m, density, onConnectDrag)
            }
            ActionHandles(shape, m, onEdit, onDelete)
        }
    }
}

// ---- 把手 ------------------------------------------------------------------

/** 一顆圓形把手：放在外層的正座標裡，命中區 [HANDLE_SIZE]、視覺直徑 [visual]。 */
@Composable
private fun RoundHandle(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    tint: Color,
    description: String,
    onTap: () -> Unit,
    modifier: Modifier = Modifier,
    visual: Float = 24f
) {
    Box(
        modifier
            .size(HANDLE_SIZE.dp)
            .clickable { onTap() }
            .semantics { contentDescription = description },
        contentAlignment = Alignment.Center
    ) {
        Box(Modifier.size(visual.dp).background(tint, CircleShape), contentAlignment = Alignment.Center) {
            Icon(icon, null, tint = Color.White, modifier = Modifier.size((visual * 0.62f).dp))
        }
    }
}

/** 編輯、層級、刪除。放在物件框的右上角外側。 */
@Composable
private fun ActionHandles(
    shape: NoteShape, m: Float, onEdit: (NoteShape) -> Unit, onDelete: (NoteShape) -> Unit
) {
    val language = LocalAppLanguage.current
    val reorder = LocalObjectReorder.current
    var menu by remember(shape.id) { mutableStateOf(false) }
    val top = m - HANDLE_SIZE - 2f
    val right = m + shape.width

    Box(Modifier.offset((right - HANDLE_SIZE * 2f).dp, top.dp)) {
        RoundHandle(Icons.Filled.Edit, MaterialTheme.colorScheme.primary,
            LocalizationStrings.localized("edit", language), { onEdit(shape) })
    }
    Box(Modifier.offset((right - HANDLE_SIZE).dp, top.dp)) {
        RoundHandle(Icons.Filled.Close, MaterialTheme.colorScheme.error,
            LocalizationStrings.localized("delete", language), { onDelete(shape) })
    }
    if (reorder != null) {
        Box(Modifier.offset((right - HANDLE_SIZE * 3f).dp, top.dp)) {
            RoundHandle(Icons.Filled.List, MaterialTheme.colorScheme.tertiary,
                LocalizationStrings.localized("layers_panel", language), { menu = true })
            DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                for (op in ObjectStacking.Reorder.entries) {
                    DropdownMenuItem(
                        text = { Text(LocalizationStrings.localized(op.labelKey, language)) },
                        onClick = { menu = false; reorder(shape.id, op) }
                    )
                }
            }
        }
    }
}

/**
 * 八個縮放把手。
 *
 * 把手在**頁面座標**裡的位置是形狀自己的邊（轉過之後）；拖曳量是頁面座標，
 * 要先轉回形狀自己的軸再交給 [ShapeFrameMath.resized]，而且對面那條邊在畫布上釘住。
 */
@Composable
private fun ResizeHandles(
    shape: NoteShape, m: Float, density: Float, onChanged: (NoteShape) -> Unit
) {
    val language = LocalAppLanguage.current
    val current by androidx.compose.runtime.rememberUpdatedState(shape)
    val rotation = shape.rotationDegrees ?: 0f
    val rad = rotation * PI / 180.0
    val c = cos(rad).toFloat()
    val sn = sin(rad).toFloat()
    val label = LocalizationStrings.localized("resize_shape", language)
    val signs = listOf(
        -1f to -1f, 0f to -1f, 1f to -1f, 1f to 0f, 1f to 1f, 0f to 1f, -1f to 1f, -1f to 0f
    )
    for ((sx, sy) in signs) {
        // 把手相對形狀中心的位置，轉到頁面座標。
        val lx = sx * shape.width / 2f
        val ly = sy * shape.height / 2f
        val hx = m + shape.width / 2f + lx * c - ly * sn
        val hy = m + shape.height / 2f + lx * sn + ly * c
        Box(
            Modifier
                .offset((hx - HANDLE_SIZE / 2f).dp, (hy - HANDLE_SIZE / 2f).dp)
                .size(HANDLE_SIZE.dp)
                .semantics { contentDescription = label }
                .pointerInput(shape.id, sx, sy) {
                    var base: NoteShape? = null
                    var accX = 0f
                    var accY = 0f
                    detectDragGestures(
                        onDragStart = { base = current; accX = 0f; accY = 0f },
                        onDrag = { change, drag ->
                            change.consume()
                            val s0 = base ?: return@detectDragGestures
                            accX += drag.x
                            accY += drag.y
                            val deg = s0.rotationDegrees ?: 0f
                            val r0 = deg * PI / 180.0
                            val c0 = cos(r0).toFloat()
                            val sn0 = sin(r0).toFloat()
                            val dx = accX / density
                            val dy = accY / density
                            // 頁面位移 → 形狀自己的軸（反向旋轉）。
                            val ldx = dx * c0 + dy * sn0
                            val ldy = -dx * sn0 + dy * c0
                            val f = ShapeFrameMath.resized(
                                ShapeFrameMath.Frame(s0.x, s0.y, s0.width, s0.height),
                                deg, sx, sy, ldx, ldy
                            )
                            onChanged(s0.copyShape().apply {
                                x = f.x; y = f.y; width = f.width; height = f.height
                            })
                        }
                    )
                },
            contentAlignment = Alignment.Center
        ) {
            Box(
                Modifier.size(12.dp).background(Color.White, CircleShape)
                    .border(1.5.dp, MaterialTheme.colorScheme.primary, CircleShape)
            )
        }
    }
}

/** 旋轉把手：形狀上方，隨旋轉繞中心轉。靠近 15° 的倍數會吸附。 */
@Composable
private fun RotateHandle(
    shape: NoteShape, m: Float, density: Float, onChanged: (NoteShape) -> Unit
) {
    val language = LocalAppLanguage.current
    val current by androidx.compose.runtime.rememberUpdatedState(shape)
    val rotation = shape.rotationDegrees ?: 0f
    val radius = max(shape.height, 40f) / 2f + 40f
    val rad = rotation * PI / 180.0
    val cx = m + shape.width / 2f
    val cy = m + shape.height / 2f
    val hx = cx + sin(rad).toFloat() * radius
    val hy = cy - cos(rad).toFloat() * radius
    Box(
        Modifier
            .offset((hx - HANDLE_SIZE / 2f).dp, (hy - HANDLE_SIZE / 2f).dp)
            .size(HANDLE_SIZE.dp)
            .semantics { contentDescription = LocalizationStrings.localized("rotate_handle", language) }
            .pointerInput(shape.id) {
                // 手指的位置在外層座標裡累加；中心用目前形狀的（縮放時中心會動，但旋轉時不會）。
                var px = 0f
                var py = 0f
                detectDragGestures(
                    onDragStart = { offset ->
                        val s0 = current
                        val r0 = (s0.rotationDegrees ?: 0f) * PI / 180.0
                        val rad0 = max(s0.height, 40f) / 2f + 40f
                        px = m + s0.width / 2f + sin(r0).toFloat() * rad0
                        py = m + s0.height / 2f - cos(r0).toFloat() * rad0
                    },
                    onDrag = { change, drag ->
                        change.consume()
                        val s0 = current
                        px += drag.x / density
                        py += drag.y / density
                        val ccx = m + s0.width / 2f
                        val ccy = m + s0.height / 2f
                        // atan2 的 0 在 +x 方向，把手的 0 在正上方，差 90°。
                        val raw = Math.toDegrees(
                            kotlin.math.atan2((py - ccy).toDouble(), (px - ccx).toDouble())
                        ).toFloat() + 90f
                        val snapped = CanvasRotation.snapped(raw)
                        onChanged(s0.copyShape().apply { rotationDegrees = snapped })
                    }
                )
            },
        contentAlignment = Alignment.Center
    ) {
        Box(Modifier.size(24.dp).background(MaterialTheme.colorScheme.primary, CircleShape),
            contentAlignment = Alignment.Center) {
            Icon(Icons.Filled.Refresh, null, tint = Color.White, modifier = Modifier.size(15.dp))
        }
    }
}

/** 線／箭頭的兩個端點：各自可拖，任意角度與長度。 */
@Composable
private fun EndpointHandles(
    shape: NoteShape, pad: Float, m: Float, density: Float, onChanged: (NoteShape) -> Unit
) {
    val language = LocalAppLanguage.current
    val current by androidx.compose.runtime.rememberUpdatedState(shape)
    val label = LocalizationStrings.localized("line_endpoint_handle", language)
    val ends = shape.lineEndpoints()
    for (isStart in listOf(true, false)) {
        val p = if (isStart) ends.first else ends.second
        // 端點是頁面座標；外層的原點在 (shape.x - m, shape.y - pad - m)。
        val hx = p.x - shape.x + m
        val hy = p.y - shape.y + pad + m
        Box(
            Modifier
                .offset((hx - HANDLE_SIZE / 2f).dp, (hy - HANDLE_SIZE / 2f).dp)
                .size(HANDLE_SIZE.dp)
                .semantics { contentDescription = label }
                .pointerInput(shape.id, isStart) {
                    var base: NoteShape? = null
                    var accX = 0f
                    var accY = 0f
                    detectDragGestures(
                        onDragStart = { base = current; accX = 0f; accY = 0f },
                        onDrag = { change, drag ->
                            change.consume()
                            val s0 = base ?: return@detectDragGestures
                            accX += drag.x
                            accY += drag.y
                            val cur = s0.lineEndpoints()
                            val moving = if (isStart) cur.first else cur.second
                            val other = if (isStart) cur.second else cur.first
                            val nx = moving.x + accX / density
                            val ny = moving.y + accY / density
                            val (frame, deg) = if (isStart)
                                ShapeFrameMath.lineFrame(nx, ny, other.x, other.y)
                            else ShapeFrameMath.lineFrame(other.x, other.y, nx, ny)
                            onChanged(s0.copyShape().apply {
                                x = frame.x; y = frame.y; width = frame.width; height = frame.height
                                rotationDegrees = deg
                            })
                        }
                    )
                },
            contentAlignment = Alignment.Center
        ) {
            Box(Modifier.size(16.dp).background(MaterialTheme.colorScheme.primary, CircleShape)
                .border(2.dp, Color.White, CircleShape))
        }
    }
}

/** 四個連接點「+」：拖到另一個形狀就連線。 */
@Composable
private fun ConnectHandles(
    shape: NoteShape, m: Float, density: Float,
    onConnectDrag: (NoteShape, ShapeAnchor, FfiPoint, FfiPoint, Boolean) -> Unit
) {
    val language = LocalAppLanguage.current
    val current by androidx.compose.runtime.rememberUpdatedState(shape)
    val label = LocalizationStrings.localized("connection_handle", language)
    val rad = (shape.rotationDegrees ?: 0f) * PI / 180.0
    val c = cos(rad).toFloat()
    val sn = sin(rad).toFloat()
    for (anchor in ShapeAnchor.entries) {
        val edge = shape.anchorPoint(anchor)
        // 往外推 20dp（沿旋轉後的法線），不要壓在縮放把手上。
        val (nx, ny) = when (anchor) {
            ShapeAnchor.TOP -> 0f to -1f
            ShapeAnchor.RIGHT -> 1f to 0f
            ShapeAnchor.BOTTOM -> 0f to 1f
            ShapeAnchor.LEFT -> -1f to 0f
        }
        val rx = nx * c - ny * sn
        val ry = nx * sn + ny * c
        val hx = edge.x - shape.x + m + rx * 22f
        val hy = edge.y - shape.y + m + ry * 22f
        Box(
            Modifier
                .offset((hx - HANDLE_SIZE / 2f).dp, (hy - HANDLE_SIZE / 2f).dp)
                .size(HANDLE_SIZE.dp)
                .semantics { contentDescription = label }
                .pointerInput(shape.id, anchor) {
                    var start = FfiPoint(0f, 0f)
                    var finger = FfiPoint(0f, 0f)
                    detectDragGestures(
                        onDragStart = {
                            start = current.anchorPoint(anchor)
                            finger = start
                        },
                        onDrag = { change, drag ->
                            change.consume()
                            finger = FfiPoint(finger.x + drag.x / density, finger.y + drag.y / density)
                            onConnectDrag(current, anchor, start, finger, false)
                        },
                        onDragEnd = { onConnectDrag(current, anchor, start, finger, true) },
                        onDragCancel = {
                            // 取消不連線：只清掉預覽（放在頁面外等於沒落在任何形狀上）。
                            onConnectDrag(current, anchor, start, FfiPoint(-10000f, -10000f), true)
                        }
                    )
                },
            contentAlignment = Alignment.Center
        ) {
            Box(Modifier.size(20.dp).background(Color(0xFF34C759), CircleShape),
                contentAlignment = Alignment.Center) {
                Icon(Icons.Filled.Add, null, tint = Color.White, modifier = Modifier.size(14.dp))
            }
        }
    }
}

private fun parseColor(hex: String): Color? =
    com.kairumo.padnote.chart.ChartRenderer.parseColor(hex)?.let { Color(it) }
