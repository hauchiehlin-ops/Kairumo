package com.kairumo.padnote.image

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.zIndex

/**
 * 連結卡片圖層（Android）。
 *
 * # 為什麼要有這一層
 *
 * 連結卡片的真身住在筆記本中繼資料（`linkAttachments`），而套件裡同時
 * 還有一張算繪好的 PNG 當後備。`ImageStore` 會**跳過**那張 PNG（不然同一張
 * 卡片會出現兩份）—— 所以少了這一層，Apple 上建的連結卡片在 Android 上
 * 會**整個看不見**：資料同步過來了，畫面上什麼都沒有。
 *
 * # 為什麼在 Android 這邊是即時畫的
 *
 * 用中繼資料即時畫，而不是顯示那張 PNG：文字不會糊、換系統字級會跟著走、
 * 而且深色模式下不會是一張白底的圖。PNG 留給還不認得這個型別的其他版本。
 */
@Composable
fun LinkLayer(
    interactive: Boolean,
    links: List<LinkObject>,
    density: Float,
    selectedId: String?,
    onSelect: (String?) -> Unit,
    onOpen: (String) -> Unit,
    onChanged: (LinkObject) -> Unit,
    zIndexOf: (String) -> Float
) {
    // 不包一層自己的 Box —— zIndex 只在同一個父容器的兄弟之間有效，
    // 包起來的話連結卡片永遠只能跟連結卡片比順序。
    for (link in links) {
        LinkCardView(
            link = link,
            density = density,
            isSelected = link.id == selectedId,
            interactive = interactive,
            zIndex = zIndexOf(link.id),
            onSelect = onSelect,
            onOpen = onOpen,
            onChanged = onChanged
        )
    }
}

@Composable
private fun LinkCardView(
    link: LinkObject,
    density: Float,
    isSelected: Boolean,
    interactive: Boolean,
    zIndex: Float,
    onSelect: (String?) -> Unit,
    onOpen: (String) -> Unit,
    onChanged: (LinkObject) -> Unit
) {
    // 座標是**頁面點**，Compose 要的是像素 —— 差一個 density。
    // 不乘的話，在 3x 的手機上卡片會擠到左上角只剩三分之一的位置。
    Box(
        modifier = Modifier
            .zIndex(zIndex)
            .offset { IntOffset((link.x * density).toInt(), (link.y * density).toInt()) }
            .width((link.width).dp)
            .clip(RoundedCornerShape(link.cornerRadius.dp))
            .background(MaterialTheme.colorScheme.surface)
            .then(
                if (link.hasBorder) {
                    Modifier.border(
                        1.dp,
                        MaterialTheme.colorScheme.outlineVariant,
                        RoundedCornerShape(link.cornerRadius.dp)
                    )
                } else {
                    Modifier
                }
            )
            .then(
                if (isSelected) {
                    Modifier.border(
                        2.dp,
                        MaterialTheme.colorScheme.primary,
                        RoundedCornerShape(link.cornerRadius.dp)
                    )
                } else {
                    Modifier
                }
            )
            .then(
                if (interactive) {
                    Modifier.pointerInput(link.id) {
                        detectDragGestures(
                            onDragStart = { onSelect(link.id) },
                            onDrag = { change, drag ->
                                change.consume()
                                link.x += drag.x / density
                                link.y += drag.y / density
                                onChanged(link)
                            }
                        )
                    }
                } else {
                    // 手寫模式下不要吃掉觸控 —— 吃掉的話，卡片蓋住的地方
                    // 就寫不了字，而使用者看不出是被什麼擋住的。
                    Modifier
                }
            )
            .clickable(enabled = interactive) { onOpen(link.urlString) }
    ) {
        Box(Modifier.size(width = 4.dp, height = link.height.dp).background(LINK_ACCENT))
        Column(Modifier.padding(start = 14.dp, top = 10.dp, end = 12.dp, bottom = 10.dp)) {
            Text(
                link.title,
                fontWeight = FontWeight.SemiBold,
                fontSize = 14.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.fillMaxWidth()
            )
            Text(
                link.descriptionText,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )
            Text(
                link.siteName,
                fontSize = 10.sp,
                color = LINK_ACCENT,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }
    }
}

/** 與 `LinkCard` 算繪 PNG 時用的同一個顏色。兩者不一致會看起來像兩種東西。 */
private val LINK_ACCENT = Color(0xFF1E6FD9)
