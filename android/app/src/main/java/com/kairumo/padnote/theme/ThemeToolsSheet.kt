package com.kairumo.padnote.theme

import com.kairumo.padnote.ui.DialogResizeHandle
import com.kairumo.padnote.ui.rememberDialogHeight
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.kairumo.padnote.LocalizationStrings
import uniffi.padnote_core.FfiThemeTab
import uniffi.padnote_core.themeDimensionCallouts
import uniffi.padnote_core.themeGestures
import uniffi.padnote_core.themeMaterials
import uniffi.padnote_core.themePalettes
import uniffi.padnote_core.themeTabKey
import uniffi.padnote_core.themeTabs
import uniffi.padnote_core.themeWireframes

/**
 * 主題專屬工具（Android）。
 *
 * 三個主題（美學視覺、工程製程、數位體驗）的素材全部來自核心
 * （`themePalettes` / `themeDimensionCallouts` / `themeMaterials` /
 * `themeWireframes` / `themeGestures`），與 Apple 的 `ThemeSpecificToolsView`
 * 讀同一份資料，所以兩邊的清單內容與順序必然一致。
 *
 * **插進去的是文字方塊，不是圖片。** 使用者回報過 Apple 端「插入主題工具後
 * 不知道怎麼利用，因為它只是一張圖片，也不能編輯」—— 標註插成點陣圖之後，
 * 尺寸與公差都改不了。這裡一律插文字方塊，插完就能改數字、字級與顏色。
 *
 * 線框元件是唯一的例外（它本來就是圖形、沒有可編輯文字），Android 目前
 * 以文字標籤代替算繪圖形 —— 見 `onInsertText` 的呼叫處說明。
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun ThemeToolsSheet(
    languageTag: String,
    goldenSpiral: Boolean,
    ruleOfThirds: Boolean,
    onGoldenSpiralChange: (Boolean) -> Unit,
    onRuleOfThirdsChange: (Boolean) -> Unit,
    /** 吸取色票到目前的筆。傳入 `#RRGGBB`。 */
    onPickColor: (String) -> Unit,
    /** 插入一個文字方塊。 */
    onInsertText: (String) -> Unit,
    onDismiss: () -> Unit
) {
    val height = rememberDialogHeight("themeTools", 520.dp)

    fun l(key: String) = LocalizationStrings.localized(key, languageTag)

    var tab by remember { mutableStateOf(FfiThemeTab.AESTHETIC) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(l("theme_tools")) },
        confirmButton = {},
        dismissButton = { TextButton(onClick = onDismiss) { Text(l("close")) } },
        text = {
            Column(
                Modifier.height(height.value).verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    for (t in themeTabs()) {
                        FilterChip(
                            selected = t == tab,
                            onClick = { tab = t },
                            label = { Text(l(themeTabKey(t))) }
                        )
                    }
                }
                HorizontalDivider()

                when (tab) {
                    FfiThemeTab.AESTHETIC -> AestheticSection(
                        ::l, goldenSpiral, ruleOfThirds,
                        onGoldenSpiralChange, onRuleOfThirdsChange, onPickColor, onInsertText, onDismiss
                    )
                    FfiThemeTab.ENGINEERING -> EngineeringSection(::l, onInsertText, onDismiss)
                    FfiThemeTab.DIGITAL -> DigitalSection(::l, onInsertText, onDismiss)
                }
            }
            // 底部的拖曳把手：往下拖變高。放在捲動容器**外面** ——
            // 放進去的話把手會跟著內容捲走，捲到一半就再也找不到它。
            DialogResizeHandle(height, "themeTools")
        }
    )
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun AestheticSection(
    l: (String) -> String,
    goldenSpiral: Boolean,
    ruleOfThirds: Boolean,
    onGoldenSpiralChange: (Boolean) -> Unit,
    onRuleOfThirdsChange: (Boolean) -> Unit,
    onPickColor: (String) -> Unit,
    onInsertText: (String) -> Unit,
    onDismiss: () -> Unit
) {
    Text(l("composition_overlay"), style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
    ToggleRow(l("golden_spiral_ref"), l("golden_spiral_desc"), goldenSpiral, onGoldenSpiralChange)
    ToggleRow(l("rule_of_thirds_ref"), l("rule_of_thirds_desc"), ruleOfThirds, onRuleOfThirdsChange)

    HorizontalDivider()
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
        Text(l("palette_swatches"), style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
        Text(
            l("palette_tip"),
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }

    for (pal in themePalettes()) {
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(l(pal.nameKey), style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Bold)
                TextButton(onClick = {
                    // 配色卡插成一行文字（名稱＋色碼），不是圖片：
                    // 色碼是要拿來抄的，選得起來才有用。
                    onInsertText("${l(pal.nameKey)}  ${pal.hexes.joinToString("  ")}")
                    onDismiss()
                }) { Text(l("insert_swatch")) }
            }
            FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                for (hex in pal.hexes) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        modifier = Modifier.clickable { onPickColor(hex) }
                    ) {
                        Box(
                            Modifier
                                .width(48.dp).height(34.dp)
                                .background(parseHex(hex), RoundedCornerShape(6.dp))
                                .border(1.dp, Color.Black.copy(alpha = 0.1f), RoundedCornerShape(6.dp))
                        )
                        Text(
                            hex,
                            style = MaterialTheme.typography.labelSmall,
                            fontFamily = FontFamily.Monospace,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun EngineeringSection(
    l: (String) -> String,
    onInsertText: (String) -> Unit,
    onDismiss: () -> Unit
) {
    Text(l("dimension_callout"), style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
    Text(
        l("engineering_dim_tip"),
        style = MaterialTheme.typography.labelSmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant
    )
    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        for (item in themeDimensionCallouts()) {
            InsertCard(l(item.titleKey), item.symbol) {
                // 符號與數值與語言無關，直接插；使用者接著就地改數字。
                onInsertText(item.symbol); onDismiss()
            }
        }
    }

    HorizontalDivider()
    Text(l("material_specs_card"), style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
    Text(
        l("material_specs_tip"),
        style = MaterialTheme.typography.labelSmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant
    )
    for (m in themeMaterials()) {
        val tag = l(m.traitKey)
        val spec = l(m.specKey)
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                // 牌號不在地化 —— SUS304 是國際代號，翻了工程師反而認不出來。
                Text("${m.designation}　$tag", style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Bold)
                Text(spec, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            TextButton(onClick = {
                onInsertText(
                    "【${l("material_card_title")}】${m.designation}\n" +
                        "${l("material_card_trait")}：$tag\n" +
                        "${l("material_card_process")}：$spec"
                )
                onDismiss()
            }) { Text(l("insert")) }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun DigitalSection(
    l: (String) -> String,
    onInsertText: (String) -> Unit,
    onDismiss: () -> Unit
) {
    Text(l("wireframe_kit"), style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
    Text(
        l("ui_wireframe_tip"),
        style = MaterialTheme.typography.labelSmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant
    )
    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        for (w in themeWireframes()) {
            // 線框元件在 Apple 端是算繪出來的示意圖。Android 先插成標籤文字 ——
            // 標籤改得動、搬得動，而一張改不了的示意圖使用者已經抱怨過一次。
            // 真正的向量線框排在形狀範本那條線上（見 docs/TODO.md A-06）。
            InsertCard(l(w.titleKey), "[wireframe] ${w.symbol}") {
                onInsertText("[${l(w.titleKey)}]"); onDismiss()
            }
        }
    }

    HorizontalDivider()
    Text(l("interaction_arrow"), style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
    Text(
        l("interaction_flow_tip"),
        style = MaterialTheme.typography.labelSmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant
    )
    for (g in themeGestures()) {
        val label = "${g.symbol} ${l(g.titleKey)}"
        Row(
            Modifier
                .fillMaxWidth()
                .clickable { onInsertText(label); onDismiss() }
                .padding(vertical = 6.dp),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Text(label, style = MaterialTheme.typography.bodyMedium)
            Text("＋", color = MaterialTheme.colorScheme.primary)
        }
    }
}

@Composable
private fun ToggleRow(
    title: String,
    desc: String,
    checked: Boolean,
    onChange: (Boolean) -> Unit
) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f)) {
            Text(title, style = MaterialTheme.typography.bodyMedium)
            Text(desc, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        Switch(checked = checked, onCheckedChange = onChange)
    }
}

@Composable
private fun InsertCard(title: String, detail: String, onClick: () -> Unit) {
    Column(
        Modifier
            .width(150.dp)
            .clickable(onClick = onClick)
            .background(MaterialTheme.colorScheme.surfaceVariant, RoundedCornerShape(8.dp))
            .padding(10.dp)
    ) {
        Text(title, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(
            detail,
            style = MaterialTheme.typography.bodyMedium,
            fontFamily = FontFamily.Monospace,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.primary
        )
    }
}

/** `#RRGGBB` → Color。核心給的色碼格式固定，壞掉就用灰色，不讓面板整個掛掉。 */
private fun parseHex(hex: String): Color =
    runCatching { Color(android.graphics.Color.parseColor(hex)) }.getOrDefault(Color.Gray)
