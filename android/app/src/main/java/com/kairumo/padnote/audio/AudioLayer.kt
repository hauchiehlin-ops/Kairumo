package com.kairumo.padnote.audio

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
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
import java.io.File

/**
 * 頁面上的錄音卡片圖層（Android）。
 *
 * 與 Apple 的 `AudioAttachmentItemView` 對齊：同一份資料（中繼資料裡的
 * `audioAttachments`）、同一組手勢（拖曳搬移、右下角縮放、選取後刪除／改名）。
 *
 * # 為什麼選取用長按
 *
 * 點擊要留給卡片裡的播放鈕。兩者都掛在點擊上的話，按播放會先被外層吃掉 ——
 * Apple 端也是這樣處理的。
 */
@Composable
fun AudioLayer(
    interactive: Boolean,
    items: List<AudioObject>,
    density: Float,
    /** 筆記本套件裡的 `media/audio` 目錄。播放要靠它把檔名接成路徑。 */
    audioDirectory: File?,
    selectedId: String?,
    playingId: String?,
    l: (String) -> String,
    onSelect: (String?) -> Unit,
    onTogglePlay: (AudioObject) -> Unit,
    onRename: (AudioObject) -> Unit,
    onDelete: (AudioObject) -> Unit,
    onChanged: (AudioObject) -> Unit,
    zIndexOf: (String) -> Float
) {
    // 不包一層自己的 Box —— zIndex 只在同一個父容器的兄弟之間有效。
    for (item in items) {
        AudioCardView(
            item = item,
            density = density,
            exists = audioDirectory?.let { File(it, item.fileName).isFile } ?: false,
            isSelected = item.id == selectedId,
            isPlaying = item.id == playingId,
            interactive = interactive,
            zIndex = zIndexOf(item.id),
            l = l,
            onSelect = onSelect,
            onTogglePlay = onTogglePlay,
            onRename = onRename,
            onDelete = onDelete,
            onChanged = onChanged
        )
    }
}

@Composable
private fun AudioCardView(
    item: AudioObject,
    density: Float,
    exists: Boolean,
    isSelected: Boolean,
    isPlaying: Boolean,
    interactive: Boolean,
    zIndex: Float,
    l: (String) -> String,
    onSelect: (String?) -> Unit,
    onTogglePlay: (AudioObject) -> Unit,
    onRename: (AudioObject) -> Unit,
    onDelete: (AudioObject) -> Unit,
    onChanged: (AudioObject) -> Unit
) {
    Box(
        modifier = Modifier
            .zIndex(zIndex)
            // 座標是**頁面點**，Compose 的 offset 要像素 —— 差一個 density。
            .offset { IntOffset((item.x * density).toInt(), (item.y * density).toInt()) }
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .width(item.width.dp)
                .height(item.height.dp)
                .rotate(item.rotationDegrees)
                .clip(RoundedCornerShape(item.cornerRadius.dp))
                .background(MaterialTheme.colorScheme.surfaceVariant)
                .then(
                    if (item.hasBorder) {
                        Modifier.border(
                            1.dp, AUDIO_ACCENT.copy(alpha = 0.35f),
                            RoundedCornerShape(item.cornerRadius.dp)
                        )
                    } else {
                        Modifier
                    }
                )
                .then(
                    if (isSelected) {
                        Modifier.border(
                            2.dp, MaterialTheme.colorScheme.primary,
                            RoundedCornerShape(item.cornerRadius.dp)
                        )
                    } else {
                        Modifier
                    }
                )
                .then(
                    if (interactive) {
                        // 選取用長按，點擊留給播放鈕。掛在卡片本體上而不是
                        // 蓋一層全尺寸的透明 Box —— 那層會把播放鈕整個擋掉。
                        Modifier.pointerInput(item.id, isSelected) {
                            detectTapGestures(
                                onLongPress = { onSelect(if (isSelected) null else item.id) }
                            )
                        }
                    } else {
                        Modifier
                    }
                )
                .then(
                    if (interactive) {
                        Modifier.pointerInput(item.id) {
                            detectDragGestures(
                                onDragStart = { onSelect(item.id) },
                                onDrag = { change, drag ->
                                    change.consume()
                                    item.x += drag.x / density
                                    item.y += drag.y / density
                                    onChanged(item)
                                },
                                // 拖出可列印範圍的物件推回邊界（S-85）。規則在核心，
                                // 與 Apple 的 PrintableArea.clampOrigin 同一份。
                                onDragEnd = {
                                    val landed = com.kairumo.padnote.ink.PageGeometry
                                        .clampOrigin(item.x, item.y, item.width, item.height)
                                    item.x = landed.first
                                    item.y = landed.second
                                    onChanged(item)
                                }
                            )
                        }
                    } else {
                        // 手寫模式下不要吃掉觸控 —— 吃掉的話卡片蓋住的地方寫不了字。
                        Modifier
                    }
                )
                .padding(horizontal = 12.dp, vertical = 8.dp)
        ) {
            Box(
                Modifier
                    .size(34.dp)
                    .clip(CircleShape)
                    .background(AUDIO_ACCENT.copy(alpha = if (exists) 0.14f else 0.05f))
                    .clickable(enabled = interactive && exists) { onTogglePlay(item) },
                contentAlignment = Alignment.Center
            ) {
                Text(if (isPlaying) "⏸" else "▶", fontSize = 14.sp)
            }

            Column(Modifier.weight(1f).padding(start = 10.dp)) {
                Text(
                    item.title.ifBlank { l("layer_kind_audio") },
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 13.sp,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.fillMaxWidth()
                )
                Text(
                    // 檔案不見了要講清楚，否則使用者只看到一個按不動的播放鈕。
                    if (exists) AudioCodec.duration(item.durationSeconds)
                    else l("audio_file_missing"),
                    fontSize = 11.sp,
                    color = if (exists) MaterialTheme.colorScheme.onSurfaceVariant
                            else MaterialTheme.colorScheme.error,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }

            Text("〰", fontSize = 14.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }

        if (interactive && isSelected) {
            // 刪除（右上）。與其他圖層的把手位置一致。
            Box(
                Modifier
                    .offset {
                        IntOffset(((item.width - 12f) * density).toInt(), (-12f * density).toInt())
                    }
                    .size(26.dp)
                    .clip(CircleShape)
                    .background(MaterialTheme.colorScheme.error)
                    .clickable { onDelete(item) },
                contentAlignment = Alignment.Center
            ) { Text("✕", fontSize = 11.sp, color = Color.White) }

            // 改名（左下）。
            Box(
                Modifier
                    .offset {
                        IntOffset((-12f * density).toInt(), ((item.height - 12f) * density).toInt())
                    }
                    .size(26.dp)
                    .clip(CircleShape)
                    .background(MaterialTheme.colorScheme.primary)
                    .clickable { onRename(item) },
                contentAlignment = Alignment.Center
            ) { Text("✎", fontSize = 11.sp, color = Color.White) }

            // 縮放（右下）。沒有它，卡片只能用插入時的尺寸。
            Box(
                Modifier
                    .offset {
                        IntOffset(
                            ((item.width - 12f) * density).toInt(),
                            ((item.height - 12f) * density).toInt()
                        )
                    }
                    .size(26.dp)
                    .clip(CircleShape)
                    .background(MaterialTheme.colorScheme.primary)
                    .pointerInput(item.id) {
                        detectDragGestures { change, drag ->
                            change.consume()
                            // 下限取播放鈕還按得到的尺寸，與 Apple 端同一組數字。
                            item.width = maxOf(150f, item.width + drag.x / density)
                            item.height = maxOf(56f, item.height + drag.y / density)
                            onChanged(item)
                        }
                    },
                contentAlignment = Alignment.Center
            ) { Text("⤡", fontSize = 11.sp, color = Color.White) }
        }
    }
}

/** 與 Apple 端錄音卡片同一個強調色。兩邊不一致會看起來像兩種東西。 */
private val AUDIO_ACCENT = Color(0xFFD9453C)
