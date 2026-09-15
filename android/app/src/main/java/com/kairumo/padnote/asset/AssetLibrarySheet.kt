package com.kairumo.padnote.asset

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.kairumo.padnote.LocalizationStrings
import uniffi.padnote_core.FfiAssetCategory
import uniffi.padnote_core.FfiAssetItem
import uniffi.padnote_core.FfiAssetRenderStyle
import uniffi.padnote_core.FfiAssetSource
import uniffi.padnote_core.assetCategories
import uniffi.padnote_core.assetCategoryKey
import uniffi.padnote_core.assetItems

/**
 * 素材圖庫（Android）。
 *
 * 目錄與線圖都來自核心（`assetItems()` / `assetDrawing()`），與 Apple 的
 * `AssetLibraryView` 是同一批 58 件素材、同樣的分類與同樣的圖形。
 *
 * # 為什麼不做「下載」
 *
 * Apple 端有一套下載／快取／容量統計。那套東西的實質是「把本機算繪出來的
 * 圖存成 PNG」—— 沒有遠端伺服器。在 Android 這裡直接即時算繪：向量畫起來
 * 很快，而且縮放不會糊。少一套快取就少一個會過期、會對不上的狀態。
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun AssetLibrarySheet(
    languageTag: String,
    /** 把素材插進畫布。回傳線圖代號、標題與風格，由呼叫端決定怎麼落盤。 */
    onInsert: (FfiAssetItem, FfiAssetRenderStyle) -> Unit,
    onDismiss: () -> Unit
) {
    fun l(key: String) = LocalizationStrings.localized(key, languageTag)

    var query by remember { mutableStateOf("") }
    var category by remember { mutableStateOf<FfiAssetCategory?>(null) }
    var style by remember { mutableStateOf(FfiAssetRenderStyle.BLUEPRINT) }

    val results = remember(query, category, languageTag) {
        val q = query.trim()
        assetItems().filter {
            val title = localizedAssetTitle(it, languageTag)
            (category == null || it.category == category) &&
                (q.isEmpty() ||
                    title.contains(q, ignoreCase = true) ||
                    it.title.contains(q, ignoreCase = true) ||
                    it.specs.contains(q, ignoreCase = true) ||
                    it.material.contains(q, ignoreCase = true))
        }
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(l("asset_library")) },
        confirmButton = {},
        dismissButton = { TextButton(onClick = onDismiss) { Text(l("close")) } },
        text = {
            Column(
                Modifier.heightIn(max = 560.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                OutlinedTextField(
                    value = query,
                    onValueChange = { query = it },
                    label = { Text(l("search_assets_placeholder")) },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )

                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    FilterChip(
                        selected = style == FfiAssetRenderStyle.BLUEPRINT,
                        onClick = { style = FfiAssetRenderStyle.BLUEPRINT },
                        label = { Text(l("style_blueprint")) }
                    )
                    FilterChip(
                        selected = style == FfiAssetRenderStyle.SOLID,
                        onClick = { style = FfiAssetRenderStyle.SOLID },
                        label = { Text(l("style_solid")) }
                    )
                }

                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    modifier = Modifier.heightIn(max = 96.dp).verticalScroll(rememberScrollState())
                ) {
                    FilterChip(
                        selected = category == null,
                        onClick = { category = null },
                        label = { Text(l("all_themes")) }
                    )
                    for (c in assetCategories()) {
                        FilterChip(
                            selected = category == c,
                            onClick = { category = c },
                            label = { Text(l(assetCategoryKey(c))) }
                        )
                    }
                }

                HorizontalDivider()

                if (results.isEmpty()) {
                    Text(
                        l("no_assets_found"),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                } else {
                    Column(
                        Modifier.verticalScroll(rememberScrollState()),
                        verticalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        for (item in results) {
                            AssetRow(item, style, languageTag, ::l) { onInsert(item, style); onDismiss() }
                        }
                    }
                }
            }
        }
    )
}

@Composable
private fun AssetRow(
    item: FfiAssetItem,
    style: FfiAssetRenderStyle,
    languageTag: String,
    l: (String) -> String,
    onInsert: () -> Unit
) {
    // AI 概念提案走深色藍圖底 —— 分類本身就是資訊，一眼看出那不是既有產品的圖紙。
    val dark = item.source == FfiAssetSource.AI_CONCEPT

    Row(
        Modifier.fillMaxWidth().clickable(onClick = onInsert),
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Box(
            Modifier
                .height(92.dp)
                .background(AssetRenderer.backgroundColor(dark), RoundedCornerShape(8.dp))
        ) {
            Canvas(Modifier.height(92.dp).padding(2.dp).fillMaxWidth(0.34f)) {
                AssetRenderer.draw(this, item.drawingCode, style, dark, size.width, size.height)
            }
        }
        Column(Modifier.weight(1f)) {
            Text(
                localizedAssetTitle(item, languageTag),
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Bold
            )
            Text(
                item.specs,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Text(
                "${item.dimensions}　${item.material}",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            TextButton(onClick = onInsert) { Text(l("insert_to_canvas")) }
        }
    }
}

private fun localizedAssetTitle(item: FfiAssetItem, languageTag: String): String {
    val key = "asset_${item.id}_title"
    val localized = LocalizationStrings.localized(key, languageTag)
    return if (localized == key) item.title else localized
}
