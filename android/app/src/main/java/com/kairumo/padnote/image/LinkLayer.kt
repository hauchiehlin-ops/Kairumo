package com.kairumo.padnote.image

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
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
    onEdit: (LinkObject) -> Unit,
    onDelete: (LinkObject) -> Unit,
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
            onEdit = onEdit,
            onDelete = onDelete,
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
    onEdit: (LinkObject) -> Unit,
    onDelete: (LinkObject) -> Unit,
    onChanged: (LinkObject) -> Unit
) {
    // 座標是**頁面點**，Compose 要的是像素 —— 差一個 density。
    // 不乘的話，在 3x 的手機上卡片會擠到左上角只剩三分之一的位置。
    Box(
        modifier = Modifier
            .zIndex(zIndex)
            .offset { IntOffset((link.x * density).toInt(), (link.y * density).toInt()) }
    ) {
        Box(
            modifier = Modifier
                .width(link.width.dp)
                // 高度也照模型走。只綁寬度的話，卡片的選取框與把手會落在
                // 內容之外 —— Apple 端修掉的是同一個問題。
                .height(link.height.dp)
                .rotate(link.rotationDegrees)
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
                        // 選取用長按，點擊留給「開啟連結」。
                        Modifier.pointerInput(link.id, isSelected) {
                            detectTapGestures(
                                onLongPress = { onSelect(if (isSelected) null else link.id) }
                            )
                        }
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
                                },
                                // 拖出可列印範圍的物件推回邊界（S-85）。規則在核心，
                                // 與 Apple 的 PrintableArea.clampOrigin 同一份。
                                onDragEnd = {
                                    val landed = com.kairumo.padnote.ink.PageGeometry
                                        .clampOrigin(link.x, link.y, link.width, link.height)
                                    link.x = landed.first
                                    link.y = landed.second
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

        // 把手掛在旋轉**外面**：包進去的話它們會跟著轉，拖曳算出的位移
        // 會疊加自身旋轉，卡片會失控。與 Apple 端同一個做法。
        if (interactive && isSelected) {
            // 刪除（右上）。在此之前 Android 的連結卡片**刪不掉** ——
            // 插錯一張就只能整頁清掉。
            Box(
                Modifier
                    .offset {
                        IntOffset(((link.width - 12f) * density).toInt(), (-12f * density).toInt())
                    }
                    .size(26.dp)
                    .clip(CircleShape)
                    .background(MaterialTheme.colorScheme.error)
                    .clickable { onDelete(link) },
                contentAlignment = Alignment.Center
            ) { Text("\u2715", fontSize = 11.sp, color = Color.White) }

            // 編修（左下）：網址、標題、說明都改得動。
            Box(
                Modifier
                    .offset {
                        IntOffset((-12f * density).toInt(), ((link.height - 12f) * density).toInt())
                    }
                    .size(26.dp)
                    .clip(CircleShape)
                    .background(MaterialTheme.colorScheme.primary)
                    .clickable { onEdit(link) },
                contentAlignment = Alignment.Center
            ) { Text("\u270E", fontSize = 11.sp, color = Color.White) }

            // 縮放（右下）。
            Box(
                Modifier
                    .offset {
                        IntOffset(
                            ((link.width - 12f) * density).toInt(),
                            ((link.height - 12f) * density).toInt()
                        )
                    }
                    .size(26.dp)
                    .clip(CircleShape)
                    .background(MaterialTheme.colorScheme.primary)
                    .pointerInput(link.id) {
                        detectDragGestures { change, drag ->
                            change.consume()
                            // 下限與 Apple 端同一組數字：再小就只剩邊框。
                            link.width = maxOf(140f, link.width + drag.x / density)
                            link.height = maxOf(64f, link.height + drag.y / density)
                            onChanged(link)
                        }
                    },
                contentAlignment = Alignment.Center
            ) { Text("\u2921", fontSize = 11.sp, color = Color.White) }

            // 旋轉（上方中央）。一次 15°，與 Apple 端旋轉盤的快捷角度同一套邏輯：
            // 觸控上拖一個小圓把手很難停在整數角度，點一下加 15° 反而準。
            Box(
                Modifier
                    .offset {
                        IntOffset(
                            ((link.width / 2f - 13f) * density).toInt(),
                            (-34f * density).toInt()
                        )
                    }
                    .size(26.dp)
                    .clip(CircleShape)
                    .background(MaterialTheme.colorScheme.secondary)
                    .clickable {
                        link.rotationDegrees = (link.rotationDegrees + 15f) % 360f
                        onChanged(link)
                    },
                contentAlignment = Alignment.Center
            ) { Text("\u21BB", fontSize = 11.sp, color = Color.White) }
        }
    }
}

/** 與 `LinkCard` 算繪 PNG 時用的同一個顏色。兩者不一致會看起來像兩種東西。 */
private val LINK_ACCENT = Color(0xFF1E6FD9)
