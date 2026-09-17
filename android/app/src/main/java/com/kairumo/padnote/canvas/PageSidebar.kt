package com.kairumo.padnote.canvas

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.painter.BitmapPainter
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.Image
import com.kairumo.padnote.platform.PageImageRenderer
import com.kairumo.padnote.ui.DS
import com.kairumo.padnote.ui.dsCard
import com.kairumo.padnote.ui.dsHairline
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import uniffi.padnote_core.PadnoteSession

/**
 * 編輯器左側的頁面結構欄。
 *
 * # 為什麼要有它
 *
 * 在此之前 Android 的換頁只有「‹ 1/3 ›」兩顆箭頭 —— 十二頁的筆記要按
 * 十一次才翻得到最後一頁，而且**看不到任何一頁長什麼樣子**。Apple 端
 * 一直有一條 280pt 的結構欄並排在畫布旁邊；同一本筆記在平板上，一邊是
 * 雙欄工作區，一邊是把手機版拉寬。
 *
 * # 並排還是覆蓋，由核心決定
 *
 * `layoutMetrics(width).sidebarIsInline` —— 用**實際寬度**算，不是查
 * 尺寸級別的表。840 寬的摺疊機並排之後畫布還有 560，可以；但使用者把
 * 視窗拉到 700 時級別還是 Medium，畫布卻只剩 420，那時就該改用覆蓋。
 */
@Composable
fun PageSidebar(
    session: PadnoteSession?,
    pageCount: Int,
    pageIndex: Int,
    /** 內容有變動就換一個值，縮圖才會重讀。 */
    revision: Int,
    l: (String) -> String,
    onSelectPage: (Int) -> Unit,
    onAddPage: () -> Unit,
    onClose: (() -> Unit)? = null,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .width(DS.Layout.sidebarWidth)
            .fillMaxHeight()
            .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.35f))
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = DS.Space.m, vertical = DS.Space.s),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                l("structure_pages"),
                style = MaterialTheme.typography.titleSmall,
                modifier = Modifier.weight(1f)
            )
            if (onClose != null) {
                TextButton(onClick = onClose) { Text(l("close")) }
            }
        }
        HorizontalDivider()

        LazyColumn(
            modifier = Modifier.weight(1f).fillMaxWidth(),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(DS.Space.m),
            verticalArrangement = Arrangement.spacedBy(DS.Space.m)
        ) {
            items((0 until maxOf(1, pageCount)).toList()) { index ->
                PageSidebarRow(
                    session = session,
                    index = index,
                    isCurrent = index == pageIndex,
                    revision = revision,
                    onClick = { onSelectPage(index) }
                )
            }
        }

        HorizontalDivider()
        TextButton(
            onClick = onAddPage,
            modifier = Modifier.fillMaxWidth().padding(DS.Space.xs)
        ) { Text("+ " + l("add_page")) }
    }
}

@Composable
private fun PageSidebarRow(
    session: PadnoteSession?,
    index: Int,
    isCurrent: Boolean,
    revision: Int,
    onClick: () -> Unit
) {
    val context = LocalContext.current
    var thumb by remember(index, revision) { mutableStateOf<ImageBitmap?>(null) }
    // 縮圖框的比例要跟著**那一頁實際的尺寸**走。
    //
    // 寫死 800:1132 的話，使用者把某一頁往下延長之後，側欄裡那一格
    // 仍然是 A4 比例，縮圖縮在左上角、下面一大塊空白 —— 看起來像壞了。
    var ratio by remember(index, revision) { mutableFloatStateOf(800f / 1132f) }

    // 縮圖在背景算。放在合成裡算的話，翻頁時整條側欄會卡住 ——
    // 而使用者按的是「跳到第 9 頁」，不是「等一下」。
    LaunchedEffect(index, revision, session) {
        val s = session ?: return@LaunchedEffect
        thumb = withContext(Dispatchers.Default) {
            runCatching {
                val pageId = s.pageIdAt(index.toUInt()) ?: return@runCatching null
                s.pageSize(pageId)?.let { size ->
                    if (size.size >= 2 && size[0] > 0f && size[1] > 0f) {
                        ratio = size[0] / size[1]
                    }
                }
                val png = PageImageRenderer.renderPng(s, pageId, 0.22f, context.cacheDir)
                android.graphics.BitmapFactory
                    .decodeByteArray(png, 0, png.size)
                    ?.asImageBitmap()
            }.getOrNull()
        }
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
    ) {
        Text(
            "P.${index + 1}",
            style = MaterialTheme.typography.labelSmall,
            color = if (isCurrent) {
                MaterialTheme.colorScheme.primary
            } else {
                MaterialTheme.colorScheme.onSurfaceVariant
            },
            modifier = Modifier.padding(bottom = 4.dp)
        )
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .aspectRatio(ratio)
                .dsCard(DS.Radius.s)
                .border(
                    width = if (isCurrent) 2.dp else 1.dp,
                    color = if (isCurrent) MaterialTheme.colorScheme.primary else dsHairline(),
                    shape = RoundedCornerShape(DS.Radius.s)
                )
        ) {
            val bitmap = thumb
            if (bitmap != null) {
                Image(
                    painter = BitmapPainter(bitmap),
                    contentDescription = null,
                    contentScale = ContentScale.Fit,
                    modifier = Modifier.fillMaxWidth()
                )
            }
        }
    }
}
