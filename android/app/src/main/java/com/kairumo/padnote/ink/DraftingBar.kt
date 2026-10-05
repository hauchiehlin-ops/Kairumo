package com.kairumo.padnote.ink

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kairumo.padnote.LocalizationStrings
import uniffi.padnote_core.FfiDraftPen
import uniffi.padnote_core.draftLinePattern

/**
 * 圖學的浮動工具列：製圖筆組、圖層（顯示／鎖定／目標）、吸附與角度鎖定、改圖層。
 * 對應 Apple 的 `DraftingBar`；狀態在 [DraftingState]，畫布那邊讀同一份落筆。
 */
@Composable
fun DraftingBar(
    languageTag: String,
    modifier: Modifier = Modifier,
    onOpenSolidStudio: () -> Unit = {}
) {
    fun l10n(key: String) = LocalizationStrings.localized(key, languageTag)
    // 讀 version：顯示／鎖定改了就重組。
    @Suppress("UNUSED_EXPRESSION") DraftingState.version

    Surface(
        modifier = modifier.testTag("draft.bar"),
        shape = RoundedCornerShape(14.dp),
        tonalElevation = 6.dp,
        shadowElevation = 8.dp
    ) {
        Column(modifier = Modifier.padding(10.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            // ── 製圖筆 ──
            Row(
                modifier = Modifier.horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                for (pen in DraftingState.pens) {
                    val selected = pen.id == DraftingState.activePenId
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        modifier = Modifier
                            .clip(RoundedCornerShape(8.dp))
                            .background(if (selected) MaterialTheme.colorScheme.primary.copy(alpha = 0.16f) else Color.Transparent)
                            .clickable { DraftingState.selectPen(pen.id) }
                            .padding(horizontal = 6.dp, vertical = 4.dp)
                            .testTag("draft.pen.${pen.id}")
                            .semantics {
                                contentDescription = l10n(pen.nameKey)
                                stateDescription = if (selected) "selected" else "unselected"
                            }
                    ) {
                        DraftLinePreview(pen, Modifier.width(54.dp).height(14.dp))
                        Text(
                            l10n(pen.nameKey), fontSize = 10.sp,
                            fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
                            color = if (selected) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }
            HorizontalDivider()
            // ── 圖層（頂在最上面，與疊放順序一致）──
            Row(
                modifier = Modifier.horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                for (layer in DraftingState.layers.reversed()) {
                    val id = layer.id.toInt()
                    val hidden = DraftingState.isHidden(id)
                    val locked = DraftingState.isLocked(id)
                    val target = DraftingState.activeLayerId == id
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(4.dp),
                        modifier = Modifier
                            .clip(RoundedCornerShape(9.dp))
                            .background(
                                if (target) MaterialTheme.colorScheme.primary.copy(alpha = 0.14f)
                                else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.06f)
                            )
                            .padding(horizontal = 8.dp, vertical = 3.dp)
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(5.dp),
                            modifier = Modifier
                                .clickable { DraftingState.toggleTarget(id) }
                                .testTag("draft.layer.$id.target")
                                .semantics {
                                    contentDescription = l10n("draft_draw_on_layer") + " " + l10n(layer.nameKey)
                                    stateDescription = if (target) "selected" else "unselected"
                                }
                        ) {
                            androidx.compose.foundation.layout.Box(
                                Modifier.size(12.dp).clip(CircleShape).background(DraftingState.layerColor(id))
                            )
                            Text(
                                l10n(layer.nameKey), fontSize = 12.sp,
                                fontWeight = if (target) FontWeight.SemiBold else FontWeight.Normal,
                                textDecoration = if (hidden) androidx.compose.ui.text.style.TextDecoration.LineThrough else null,
                                color = if (hidden) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.onSurface
                            )
                        }
                        Text(
                            if (hidden) "🙈" else "👁", fontSize = 15.sp,
                            modifier = Modifier
                                .clickable { DraftingState.setHidden(id, !hidden) }
                                .padding(4.dp)
                                .testTag("draft.layer.$id.visible")
                                .semantics {
                                    contentDescription = l10n(if (hidden) "draft_show_layer" else "draft_hide_layer")
                                }
                        )
                        Text(
                            if (locked) "🔒" else "🔓", fontSize = 15.sp,
                            modifier = Modifier
                                .clickable { DraftingState.setLocked(id, !locked) }
                                .padding(4.dp)
                                .testTag("draft.layer.$id.lock")
                                .semantics {
                                    contentDescription = l10n(if (locked) "draft_unlock_layer" else "draft_lock_layer")
                                }
                        )
                    }
                }
            }
            HorizontalDivider()
            // ── 吸附、角度鎖定、改圖層 ──
            Row(
                modifier = Modifier.horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                FilterChip(
                    selected = DraftingState.snapEnabled,
                    onClick = { DraftingState.setSnap(!DraftingState.snapEnabled) },
                    label = { Text(l10n("draft_snap"), fontSize = 12.sp) },
                    modifier = Modifier.testTag("draft.snap")
                )
                var angleMenu by remember { mutableStateOf(false) }
                androidx.compose.foundation.layout.Box {
                    FilterChip(
                        selected = DraftingState.angleStep != 0,
                        onClick = { angleMenu = true },
                        label = {
                            Text(
                                l10n("draft_angle_lock") + " " + angleTitle(DraftingState.angleStep, ::l10n),
                                fontSize = 12.sp
                            )
                        },
                        modifier = Modifier.testTag("draft.angle")
                    )
                    DropdownMenu(expanded = angleMenu, onDismissRequest = { angleMenu = false }) {
                        for (deg in DraftingState.angleChoices) {
                            DropdownMenuItem(
                                text = { Text((if (deg == DraftingState.angleStep) "✓ " else "") + angleTitle(deg, ::l10n)) },
                                onClick = { DraftingState.selectAngle(deg); angleMenu = false },
                                modifier = Modifier.testTag("draft.angle.$deg")
                            )
                        }
                    }
                }
                FilterChip(
                    selected = DraftingState.reassignMode,
                    onClick = { DraftingState.reassignMode = !DraftingState.reassignMode },
                    label = { Text(l10n("draft_reassign"), fontSize = 12.sp) },
                    modifier = Modifier.testTag("draft.reassign")
                )
                // 步驟編號：開著時點頁面就放一個 ①②③…（中層，跟輔助線一起隱藏）。
                FilterChip(
                    selected = DraftingState.markerMode,
                    onClick = { DraftingState.markerMode = !DraftingState.markerMode },
                    label = { Text(l10n("draft_step_marker") + " " + DraftingState.stepNumber, fontSize = 12.sp) },
                    modifier = Modifier.testTag("draft.marker")
                )
                if (DraftingState.markerMode) {
                    FilterChip(
                        selected = false,
                        onClick = { DraftingState.stepNumber = (DraftingState.stepNumber - 1).coerceAtLeast(1) },
                        label = { Text("−", fontSize = 14.sp) },
                        modifier = Modifier.testTag("draft.marker.minus")
                    )
                    FilterChip(
                        selected = false,
                        onClick = { DraftingState.stepNumber = (DraftingState.stepNumber + 1).coerceAtMost(99) },
                        label = { Text("+", fontSize = 14.sp) },
                        modifier = Modifier.testTag("draft.marker.plus")
                    )
                    FilterChip(
                        selected = false,
                        onClick = { DraftingState.stepNumber = 1 },
                        label = { Text(l10n("draft_step_reset"), fontSize = 12.sp) },
                        modifier = Modifier.testTag("draft.marker.reset")
                    )
                }
                // 立體輔助：草圖拉伸、三視圖、等角圖、剖面。
                FilterChip(
                    selected = false,
                    onClick = onOpenSolidStudio,
                    label = { Text("📦 " + l10n("solid_studio"), fontSize = 12.sp) },
                    modifier = Modifier.testTag("draft.solidStudio")
                )
            }
        }
    }
}

private fun angleTitle(deg: Int, l10n: (String) -> String) =
    if (deg == 0) l10n("draft_angle_free") else "$deg°"

/** 製圖筆的線樣：依核心的線型圖樣畫出實線／隱藏線／中心線／假想線，粗細也照筆組。 */
@Composable
fun DraftLinePreview(pen: FfiDraftPen, modifier: Modifier = Modifier) {
    val pattern = remember(pen.lineType) { draftLinePattern(pen.lineType) }
    val color = remember(pen.colorHex) { DraftingState.parseHex(pen.colorHex) }
    Canvas(modifier = modifier) {
        val y = size.height / 2
        val on = pattern.map { it * 0.9f * density }.toFloatArray()
        drawLine(
            color = color,
            start = Offset(2.dp.toPx(), y),
            end = Offset(size.width - 2.dp.toPx(), y),
            strokeWidth = pen.width * 1.3f * density,
            pathEffect = if (on.size >= 2) PathEffect.dashPathEffect(on, 0f) else null
        )
    }
}
