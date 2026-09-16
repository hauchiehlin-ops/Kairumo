package com.kairumo.padnote.library

import android.content.Context
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.kairumo.padnote.audio.AudioCodec
import com.kairumo.padnote.audio.AudioObject
import java.io.File

/**
 * 從首頁把一段錄音插進某一本筆記的某一頁（工作項 S-41）。
 *
 * # 為什麼要**複製**音檔，不能引用
 *
 * 錄音檔住在筆記本套件裡，而**套件是同步的單位**。留一個指向別本筆記的
 * 引用，另一台裝置只會同步到目標那一本 —— 打開之後拿到的是一張播不出來
 * 的卡片，而畫面上看不出為什麼。複製一份是唯一會在所有裝置上成立的做法。
 *
 * 與 Apple 的 `RecordingToNotebookSheet` 對應：同樣挑筆記本、挑頁次。
 */
@Composable
fun InsertRecordingDialog(
    recording: RecordingIndex.Recording,
    entries: List<NotebookLibrary.Entry>,
    deviceId: UInt,
    l: (String) -> String,
    onDismiss: () -> Unit,
    onDone: (String?) -> Unit
) {
    val context = androidx.compose.ui.platform.LocalContext.current
    var selected by remember { mutableStateOf<NotebookLibrary.Entry?>(null) }
    var page by remember { mutableIntStateOf(1) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(l("insert_to_notebook")) },
        text = {
            Column(
                Modifier.heightIn(max = 380.dp).verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Text(recording.file.name, fontWeight = FontWeight.SemiBold)
                Text(
                    "${recording.bytes / 1024} KB",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )

                Text(l("all_notebooks"), style = MaterialTheme.typography.labelSmall)
                if (entries.isEmpty()) {
                    Text(
                        l("notebook_empty"),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                for (entry in entries) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable {
                                selected = entry
                                page = page.coerceIn(1, maxOf(1, entry.pageCount))
                            }
                            .padding(vertical = 8.dp)
                    ) {
                        Text(entry.title, Modifier.weight(1f))
                        if (entry.id == selected?.id) Text("✓")
                    }
                }

                selected?.let { entry ->
                    // 頁次要讓使用者選 —— 一律塞到第 1 頁的話，十頁的會議
                    // 記錄裡那段錄音永遠離它對應的段落十頁遠，等於沒有插。
                    Text(l("insert_audio_page"), style = MaterialTheme.typography.labelSmall)
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        TextButton(
                            onClick = { if (page > 1) page-- },
                            enabled = page > 1
                        ) { Text("−") }
                        Text("${l("page_label")} $page / ${maxOf(1, entry.pageCount)}")
                        TextButton(
                            onClick = { if (page < entry.pageCount) page++ },
                            enabled = page < entry.pageCount
                        ) { Text("＋") }
                    }
                }
            }
        },
        confirmButton = {
            TextButton(
                enabled = selected != null,
                onClick = {
                    val entry = selected ?: return@TextButton
                    val created = InsertRecording.into(
                        context, entry, deviceId, recording.file, page - 1
                    )
                    // **不要寫成 `created?.let { null } ?: 錯誤訊息`** ——
                    // 成功時那個運算式的值是 null，而 `null ?: x` 就是 x，
                    // 於是插入成功卻回報失敗（實際發生過）。
                    onDone(if (created == null) l("err_insert_recording_failed") else null)
                }
            ) { Text(l("insert")) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text(l("cancel")) } }
    )
}

/** 把音檔複製進目標套件並掛上一張卡片。 */
object InsertRecording {

    /** 成功時回傳新卡片的 id。 */
    fun into(
        context: Context,
        entry: NotebookLibrary.Entry,
        deviceId: UInt,
        source: File,
        pageIndex: Int
    ): String? = runCatching {
        val opened = NotebookLibrary.open(context, entry.id, deviceId) ?: return null
        val (session, _) = opened

        // 複製到目標套件的 media/audio。**檔名要保證不撞** —— 直接沿用
        // 來源檔名的話，兩本筆記各有一個同名的錄音時會互相覆蓋。
        val dir = File(entry.path, "media/audio").apply { mkdirs() }
        var target = File(dir, source.name)
        if (target.exists() && target.absolutePath != source.absolutePath) {
            target = File(dir, "${source.nameWithoutExtension}-${System.currentTimeMillis()}.${source.extension}")
        }
        if (target.absolutePath != source.absolutePath) {
            source.copyTo(target, overwrite = true)
        }

        val meta = NotebookMeta.load(session)
        val existing = meta.audioCards()
        val offset = (existing.count { it.pageIndex == pageIndex } % 6) * 18f
        val card = AudioObject(
            id = java.util.UUID.randomUUID().toString(),
            pageIndex = pageIndex,
            recordingId = target.nameWithoutExtension,
            fileName = target.name,
            title = target.nameWithoutExtension,
            durationSeconds = runCatching {
                uniffi.padnote_core.audioDurationSeconds(target.readBytes()).toInt()
            }.getOrDefault(0),
            x = 80f + offset, y = 120f + offset,
            width = 260f, height = 76f
        )
        meta.setAudioCards(session, existing + card)
        @Suppress("UNUSED_EXPRESSION") AudioCodec
        card.id
    }.getOrNull()
}
