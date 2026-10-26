package com.kairumo.padnote

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.width
import androidx.compose.material3.VerticalDivider
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.kairumo.padnote.canvas.PageSidebar
import com.kairumo.padnote.ui.FoldPosture
import uniffi.padnote_core.PadnoteSession

/**
 * 編輯器工作區容器：處理側欄與畫布的並排或重疊版面，支援折疊機鉸鏈（Hinge）安全避讓。
 */
@Composable
fun ColumnScope.EditorWorkArea(
    sidebarInline: Boolean,
    /**
     * 折疊機的姿態（S-77）。
     *
     * 攤開的折疊機中間有一道實體摺痕 —— 並排的側欄剛好跨在上面的話，
     * 縮圖會被摺痕切成兩半，畫布的左緣也壓在凹槽裡。鉸鏈是分欄的天然
     * 位置：側欄靠左半邊、畫布靠右半邊，中間把鉸鏈本身讓出來。
     *
     * 非折疊機時是一個空姿態，什麼都不會變。
     */
    posture: FoldPosture = FoldPosture(),
    modifier: Modifier = Modifier.weight(1f),
    sidebar: @Composable () -> Unit,
    canvas: @Composable RowScope.() -> Unit
) {
    Row(modifier = modifier.fillMaxWidth()) {
        if (sidebarInline) {
            val snapToHinge = posture.separatingVertically && posture.hingeStart > 120.dp
            Box(modifier = if (snapToHinge) Modifier.width(posture.hingeStart) else Modifier) {
                sidebar()
            }
            if (snapToHinge) {
                // 鉸鏈本身讓出來。摺痕型（無縫）的機器回 0，那就跟原本一樣。
                Spacer(modifier = Modifier.width(posture.hingeSize))
            }
            VerticalDivider()
        }
        canvas()
    }
}

/**
 * 編輯器頁面結構與縮圖導覽側欄模組（與 Apple 端 EditorSidebars 完全對齊）。
 */
@Composable
fun EditorSidebar(
    session: PadnoteSession?,
    pageCount: Int,
    pageIndex: Int,
    revision: Int,
    l10n: (String) -> String,
    deviceId: UInt,
    onSelectPage: (Int) -> Unit,
    onAddPage: () -> Unit,
    onMovePage: (from: Int, to: Int) -> Unit,
    onInsertPageAfter: (afterIndex: Int, paperId: String?) -> Unit,
    onDuplicatePage: (index: Int) -> Unit,
    onDeletePage: (index: Int) -> Unit,
    onTransferPage: (index: Int, moveOut: Boolean) -> Unit,
    onOpenNotebook: ((String) -> Unit)?,
    onClose: () -> Unit
) {
    PageSidebar(
        session = session,
        pageCount = pageCount,
        pageIndex = pageIndex,
        revision = revision,
        l = l10n,
        onSelectPage = onSelectPage,
        onAddPage = onAddPage,
        onMovePage = onMovePage,
        onInsertPageAfter = onInsertPageAfter,
        onDuplicatePage = onDuplicatePage,
        onDeletePage = onDeletePage,
        onTransferPage = onTransferPage,
        onOpenNotebook = { id -> onOpenNotebook?.invoke(id) },
        deviceId = deviceId,
        onClose = onClose
    )
}
