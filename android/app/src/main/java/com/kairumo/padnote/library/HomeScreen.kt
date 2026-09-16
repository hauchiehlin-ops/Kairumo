package com.kairumo.padnote.library

import com.kairumo.padnote.audio.AudioPlayback
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.height
import androidx.compose.runtime.Composable
import androidx.compose.runtime.produceState
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.runtime.LaunchedEffect
import kotlinx.coroutines.delay
import androidx.compose.ui.platform.LocalContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.ui.Alignment
import androidx.compose.ui.graphics.vector.ImageVector
import com.kairumo.padnote.ui.DS
import com.kairumo.padnote.ui.KairumoIcons
import com.kairumo.padnote.ui.dsContentWidth
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.text.DateFormat
import java.util.Date

/**
 * 首頁（Android）。
 *
 * # 為什麼要有這個畫面
 *
 * 在此之前 Android **沒有首頁** —— App 一開就直接進一本筆記的一頁，沒有清單、
 * 沒有搜尋、沒有「新增一本」。使用者看到的是一個畫圖玩具，不是筆記本。
 *
 * # 版面與 Apple 端一致
 *
 * 標題 → 身分 → 搜尋 → 三張主要動作卡 → 繼續（橫向捲動）→ 最近錄音 →
 * 全部筆記（資料夾列 + 縮圖格狀）→ 資料與同步（四列）→ 說明與條款 → 頁尾。
 *
 * **不只是順序一致，連版面也要。** 原本 Android 的主要動作是三顆 180dp 寬
 * 的純文字卡，在手機上會疊成三顆佔半個螢幕的大按鈕，而 Apple 那邊是一排
 * 帶圖示與副標的卡片 —— 同一個 App 在兩台裝置上長得像兩個產品。
 * 三張卡改成等寬（`weight(1f)`），窄螢幕上一樣是一排，只是變窄。
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun HomeScreen(
    entries: List<NotebookLibrary.Entry>,
    /** 搜尋內容時要用它開每一本筆記（工作項 S-64）。 */
    deviceId: UInt,
    /** **不分資料夾**的全部筆記本。搜尋要搜整個筆記庫，不是只搜眼前這一層。 */
    allEntries: List<NotebookLibrary.Entry>,
    folders: List<FolderTree.Folder>,
    /** 從最上層到目前位置。空的表示人在最上層。 */
    breadcrumb: List<FolderTree.Folder>,
    profileName: String,
    profileColorHex: String,
    appVersion: String,
    sort: NotebookLibrary.Sort,
    recording: Boolean,
    l: (String) -> String,
    onOpen: (String) -> Unit,
    onCreate: () -> Unit,
    onRename: (NotebookLibrary.Entry) -> Unit,
    onDelete: (NotebookLibrary.Entry) -> Unit,
    onMove: (NotebookLibrary.Entry) -> Unit,
    onSortChange: (NotebookLibrary.Sort) -> Unit,
    onEditIdentity: () -> Unit,
    onToggleRecording: () -> Unit,
    onBackup: () -> Unit,
    onRestore: () -> Unit,
    recordings: List<RecordingIndex.Recording>,
    /** Google 帳號同步的狀態，與 Apple 的 `googleAccountSection` 一一對應。 */
    cloud: CloudSyncUiState,
    onOpenFolder: (String?) -> Unit,
    onCreateFolder: () -> Unit,
    onRenameFolder: (FolderTree.Folder) -> Unit,
    onDeleteFolder: (FolderTree.Folder) -> Unit,
    /** 素材圖庫。與 Apple 首頁的第三張動作卡對應。 */
    onAssetLibrary: () -> Unit,
    /** 選同步資料夾。原本只在編輯器的「⋯」裡，使用者要先開一本筆記才找得到。 */
    onChooseSyncFolder: () -> Unit,
    /** 操作說明與隱私權政策。Apple 首頁最下面有這兩張卡，Android 原本沒有。 */
    onOpenManual: () -> Unit,
    onOpenPrivacy: () -> Unit,
    /** 把一段錄音插進某一本筆記的某一頁（工作項 S-41）。 */
    onInsertRecording: (RecordingIndex.Recording) -> Unit
) {
    var query by remember { mutableStateOf("") }
    val searchContext = LocalContext.current

    // 搜尋時跨整個筆記庫，不是只搜眼前這一層 —— 人在資料夾裡搜尋卻只搜得到
    // 這一層的話，他會以為那本筆記不見了。
    // 內容搜尋（工作項 S-64）。標題比對是即時的；內容要開每一本筆記，
    // 所以丟到背景，結果回來再併進清單。
    //
    // 兩段式而不是等內容查完才顯示：使用者打字時看到的應該是「立刻有東西」，
    // 而不是一片空白等半秒。標題命中先出現，內容命中隨後補上。
    var contentHits by remember { mutableStateOf<Set<String>>(emptySet()) }
    LaunchedEffect(query, allEntries.size) {
        val q = query.trim()
        if (q.length < NotebookSearch.MIN_QUERY_LENGTH) {
            contentHits = emptySet()
            return@LaunchedEffect
        }
        // 防抖：每一次按鍵都把整個筆記庫開一遍的話，打五個字就是五輪。
        delay(280)
        contentHits = withContext(Dispatchers.IO) {
            NotebookSearch.matchingIds(searchContext, allEntries, q, deviceId)
        }
    }

    val filtered = remember(entries, allEntries, query, contentHits) {
        if (query.isBlank()) entries
        else allEntries.filter {
            it.title.contains(query.trim(), ignoreCase = true) || contentHits.contains(it.id)
        }
    }

    // 內容置中並限制最大寬度（工作項 S-62）。
    //
    // 在此之前內容會把整個視窗填滿。平板橫向時，一列設定的文字橫跨整個
    // 螢幕，眼睛要掃過全寬才讀完一行，而右邊大半是空的 —— 那不是用到了
    // 空間，是沒有版面。與 Apple 端同一組數字。
    BoxWithConstraints(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.TopCenter
    ) {
        val gutter = DS.Content.gutter(this.maxWidth)
        // 卡片可以用的寬度（扣掉左右外距、且不超過內容上限）。
        val contentWidth = minOf(this.maxWidth, DS.Content.maxWidth) - gutter * 2
        LazyColumn(
            modifier = Modifier
                .fillMaxHeight()
                .dsContentWidth()
                .padding(horizontal = gutter),
            verticalArrangement = Arrangement.spacedBy(DS.Space.s),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(vertical = DS.Space.m)
        ) {
        // ── 0. 畫面標題 ──────────────────────────────────────────
        // Apple 那邊是一個大標。少了它，第一眼看到的是一張身分卡，
        // 而使用者不知道自己在哪個畫面。
        item {
            Text(
                profileName,
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold
            )
        }

        // ── 1. 身分 ──────────────────────────────────────────────
        item {
            Card(
                modifier = Modifier.fillMaxWidth().clickable { onEditIdentity() },
                shape = RoundedCornerShape(12.dp),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.surfaceVariant
                )
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth().padding(14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .size(40.dp)
                            .background(parseHex(profileColorHex) ?: Color(0xFF007AFF), CircleShape),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            profileName.take(1).uppercase(),
                            color = Color.White,
                            fontWeight = FontWeight.Bold
                        )
                    }
                    Column(Modifier.weight(1f)) {
                        Text(profileName, fontWeight = FontWeight.SemiBold)
                        Text(
                            l("identity_desc_short"),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                    TextButton(onClick = onEditIdentity) { Text(l("edit_identity")) }
                }
            }
        }

        // ── 2. 搜尋 ──────────────────────────────────────────────
        item {
            OutlinedTextField(
                value = query,
                onValueChange = { query = it },
                placeholder = { Text(l("search_placeholder"), maxLines = 1) },
                singleLine = true,
                shape = RoundedCornerShape(12.dp),
                modifier = Modifier.fillMaxWidth()
            )
        }

        // ── 3. 主要動作卡：依寬度決定一排幾張 ────────────────────
        //
        // **不能固定三欄。** 之前這裡是 `Row` + `weight(1f)`，理由寫的是
        // 「等寬在任何寬度下都是一排」—— 但在手機上那一排只有 340dp，
        // 三張卡各得 110dp，於是標題變成「Start Recordi」、說明變成
        // 「transcriptio」。Apple 端其實是**窄螢幕直接疊成一欄**的。
        //
        // 所以照可用寬度算欄數：一張卡至少 200dp，放不下就換行。
        item {
            val perRow = DS.columns(contentWidth, minItem = 200.dp, max = 3)
            val actions = listOf<Triple<String, String, Pair<Color, Boolean>>>(
                Triple(l("new_note"), l("new_note_desc"),
                    MaterialTheme.colorScheme.primary to true),
                Triple(l(if (recording) "stop_recording" else "start_recording"),
                    l("start_recording_desc"), Color(0xFFD9453C) to false),
                Triple(l("asset_library"), l("asset_library_desc"),
                    MaterialTheme.colorScheme.primary to false)
            )
            val clicks = listOf(onCreate, onToggleRecording, onAssetLibrary)
            val icons = listOf(Icons.Filled.Add, KairumoIcons.Mic, KairumoIcons.Cube)

            Column(verticalArrangement = Arrangement.spacedBy(DS.Space.xs)) {
                actions.indices.chunked(perRow).forEach { rowIndices ->
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(DS.Space.xs)
                    ) {
                        rowIndices.forEach { i ->
                            ActionCard(
                                title = actions[i].first,
                                subtitle = actions[i].second,
                                icon = icons[i],
                                accent = actions[i].third.first,
                                primary = actions[i].third.second,
                                modifier = Modifier.weight(1f),
                                onClick = clicks[i]
                            )
                        }
                        // 最後一排不足時補空位，卡片才不會被拉寬。
                        repeat(perRow - rowIndices.size) {
                            Box(modifier = Modifier.weight(1f))
                        }
                    }
                }
            }
        }

        // ── 4. 繼續（橫向捲動，與 Apple 一致）─────────────────────
        if (filtered.isNotEmpty() && query.isBlank()) {
            item { SectionTitle(l("continue_working")) }
            item {
                LazyRow(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    items(filtered.take(6), key = { "recent-${it.id}" }) { entry ->
                        ContinueCard(entry, l, onOpen)
                    }
                }
            }
        }

        // ── 5. 最近錄音 ──────────────────────────────────────────
        // 位置與 Apple 端一致 —— 順序自己排一套的話，同一個人換裝置
        // 就要重新找每一樣東西在哪裡。
        item { SectionTitle(l("recent_recordings")) }
        if (recordings.isEmpty()) {
            item { EmptyHint(l("no_recordings_hint")) }
        } else {
            items(recordings, key = { "rec-${it.file.absolutePath}" }) { recording ->
                RecordingRow(recording, l, onOpen, onInsertRecording)
            }
        }

        // ── 6. 麵包屑（只有不在最上層時才出現）─────────────────────
        if (breadcrumb.isNotEmpty() && query.isBlank()) {
            item { Breadcrumb(breadcrumb, l, onOpenFolder) }
        }

        // ── 7. 全部筆記 ──────────────────────────────────────────
        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                SectionTitle("${l("all_notebooks")} (${entries.size})", Modifier.weight(1f))
                SortMenu(sort, l, onSortChange)
            }
        }

        // 資料夾列：目前這一層 + 新增子資料夾，與 Apple 的那一條一致。
        item {
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(12.dp),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.surfaceVariant
                )
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth().padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("🗂", fontSize = 16.sp, modifier = Modifier.padding(end = 8.dp))
                    Text(
                        breadcrumb.lastOrNull()?.title ?: l("root_folder"),
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.weight(1f)
                    )
                    TextButton(onClick = onCreateFolder) { Text(l("new_subfolder")) }
                }
            }
        }

        if (folders.isNotEmpty() && query.isBlank()) {
            items(folders, key = { "folder-${it.id}" }) { folder ->
                FolderRow(folder, l, onOpenFolder, onRenameFolder, onDeleteFolder)
            }
        }

        if (filtered.isEmpty()) {
            item {
                EmptyHint(if (query.isBlank()) l("notebook_empty") else l("search_no_result"))
            }
        } else {
            // 縮圖格狀而不是一列一本 —— 使用者認得的是那一頁長什麼樣子，
            // 不是標題。與 Apple 的「全部筆記」一致。
            //
            // 用 chunked 自己排而不是 LazyVerticalGrid：格狀不能巢狀在
            // LazyColumn 裡（高度無限），而整個畫面改成格狀又會讓其餘
            // 區塊全部要跨欄。
            items(filtered.chunked(2), key = { row -> "grid-" + row.first().id }) { row ->
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    for (entry in row) {
                        NotebookGridCard(
                            entry, l, onOpen, onRename, onDelete, onMove,
                            modifier = Modifier.weight(1f)
                        )
                    }
                    // 奇數本時補一個空位，最後一張才不會被拉成兩倍寬。
                    if (row.size == 1) Box(Modifier.weight(1f))
                }
            }
        }

        // ── 8. 資料與同步 ────────────────────────────────────────
        item {
            HorizontalDivider()
            Row(verticalAlignment = Alignment.Bottom) {
                SectionTitle(l("data_and_sync"))
                Text(
                    l("no_account_no_server"),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(start = 8.dp, bottom = 3.dp)
                )
            }
        }
        item { CloudSyncCard(cloud, l) }
        item {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                SettingRow("💾", l("backup_create"), l("backup_explainer"), onBackup)
                SettingRow("↺", l("backup_restore"), l("backup_restore_desc"), onRestore)
                SettingRow("☁", l("sync_choose_folder"), l("sync_folder_desc"), onChooseSyncFolder)
            }
        }

        // ── 9. 說明與條款 ────────────────────────────────────────
        // Apple 首頁最下面有這兩張卡。Android 原本只有編輯器的「⋯」裡有，
        // 使用者要先開一本筆記才找得到操作說明。
        item {
            HorizontalDivider()
            SectionTitle(l("help_and_legal"))
        }
        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                DocCard("📖", l("user_manual"), l("user_manual_desc"),
                    Modifier.weight(1f), onOpenManual)
                DocCard("🔒", l("privacy_policy"), l("privacy_policy_desc"),
                    Modifier.weight(1f), onOpenPrivacy)
            }
        }

        // ── 10. 頁尾 ─────────────────────────────────────────────
        item {
            Column(
                modifier = Modifier.fillMaxWidth().padding(vertical = 12.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                HorizontalDivider(Modifier.padding(bottom = 10.dp))
                Text(
                    appVersion,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Text(
                    l("footer_tagline"),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
        }
    }
}

@Composable
private fun EmptyHint(text: String) {
    Text(
        text,
        style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier.fillMaxWidth().padding(vertical = 18.dp)
    )
}

/** 「繼續」那一排的卡片。與 Apple 的同一組資訊：標題、摘要、頁數、時間。 */
@Composable
private fun ContinueCard(
    entry: NotebookLibrary.Entry,
    l: (String) -> String,
    onOpen: (String) -> Unit
) {
    Card(
        modifier = Modifier.width(220.dp).clickable { onOpen(entry.id) },
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant
        )
    ) {
        Column(Modifier.padding(12.dp)) {
            Text("📄", fontSize = 16.sp)
            Text(
                entry.title,
                fontWeight = FontWeight.SemiBold,
                maxLines = 2,
                modifier = Modifier.padding(top = DS.Space.xs)
            )
            Text(
                "${entry.pageCount} ${l("pages_unit")} · ${formatDate(entry.modifiedAt)}",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(top = 6.dp)
            )
        }
    }
}

/** 「資料與同步」的一列：圖示 + 標題 + 說明 + 右箭頭。與 Apple 一致。 */
@Composable
private fun SettingRow(glyph: String, title: String, desc: String, onClick: () -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth().clickable { onClick() },
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant
        )
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(14.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(glyph, fontSize = 18.sp, modifier = Modifier.padding(end = 12.dp))
            Column(Modifier.weight(1f)) {
                Text(title, fontWeight = FontWeight.SemiBold)
                Text(
                    desc,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 2
                )
            }
            Text("›", fontSize = 18.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

/** 說明文件的卡片。 */
@Composable
private fun DocCard(
    glyph: String,
    title: String,
    desc: String,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    Card(
        modifier = modifier.clickable { onClick() },
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant
        )
    ) {
        Column(Modifier.padding(12.dp)) {
            Text(glyph, fontSize = 18.sp)
            Text(title, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(top = 6.dp))
            Text(
                desc,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 2
            )
        }
    }
}

@Composable
private fun SectionTitle(text: String, modifier: Modifier = Modifier) {

    Text(
        text,
        style = MaterialTheme.typography.titleMedium,
        fontWeight = FontWeight.Bold,
        modifier = modifier.padding(top = 6.dp)
    )
}

/**
 * 首頁的主要動作卡。
 *
 * 圖示 + 標題 + 副標，與 Apple 的三張卡一樣 —— 只有一行標籤的話，
 * 使用者要按下去才知道那個按鈕會做什麼。
 */
@Composable
private fun ActionCard(
    title: String,
    subtitle: String,
    icon: ImageVector,
    accent: Color,
    primary: Boolean,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    Card(
        modifier = modifier.clickable { onClick() },
        shape = RoundedCornerShape(DS.Radius.m),
        colors = CardDefaults.cardColors(
            containerColor = if (primary) MaterialTheme.colorScheme.primary
            else MaterialTheme.colorScheme.surfaceVariant
        )
    ) {
        Column(Modifier.padding(DS.Space.m)) {
            // 真的圖示，不是文字符號（工作項 S-62）。
            //
            // 這裡原本畫的是「＋」「◉」「◆」這三個**字元**。它們會跟著
            // 字型走，對不齊基線、大小不一致，在不同裝置的字型上長得也不
            // 一樣 —— 那是「看起來像半成品」最直接的來源之一。
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = if (primary) MaterialTheme.colorScheme.onPrimary else accent,
                modifier = Modifier.size(DS.Icon.large)
            )
            Text(
                title,
                fontWeight = FontWeight.SemiBold,
                maxLines = 2,
                color = if (primary) MaterialTheme.colorScheme.onPrimary
                else MaterialTheme.colorScheme.onSurface,
                modifier = Modifier.padding(top = 6.dp)
            )
            Text(
                subtitle,
                style = MaterialTheme.typography.labelSmall,
                maxLines = 2,
                color = if (primary) MaterialTheme.colorScheme.onPrimary.copy(alpha = 0.85f)
                else MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

/**
 * 「全部筆記」的格狀卡片。
 *
 * 顯示的是**那一頁長什麼樣子**，不是一行標題 —— 使用者記得的是畫面，
 * 不是名字。與 Apple 的「全部筆記」一致。
 */
@Composable
private fun NotebookGridCard(
    entry: NotebookLibrary.Entry,
    l: (String) -> String,
    onOpen: (String) -> Unit,
    onRename: (NotebookLibrary.Entry) -> Unit,
    onDelete: (NotebookLibrary.Entry) -> Unit,
    onMove: (NotebookLibrary.Entry) -> Unit,
    modifier: Modifier = Modifier
) {
    var menu by remember(entry.id) { mutableStateOf(false) }
    Card(
        modifier = modifier.clickable { onOpen(entry.id) },
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant
        )
    ) {
        Column(Modifier.padding(10.dp)) {
            Box(Modifier.fillMaxWidth()) {
                // 有縮圖就用縮圖，沒有就退回「圖示 + 名字」的佔位 ——
                // Android 的縮圖目前只畫得出筆畫與底紋（工作項 S-43），
                // 一本只打字的筆記會是一張全白的圖，那看起來像壞掉。
                NotebookThumbnail(entry, Modifier.fillMaxWidth().height(110.dp)) {
                    Column(
                        Modifier.fillMaxSize(),
                        verticalArrangement = Arrangement.Center,
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Text("📘", fontSize = 22.sp)
                        Text(
                            entry.title,
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            maxLines = 1,
                            modifier = Modifier.padding(top = 4.dp, start = 6.dp, end = 6.dp)
                        )
                    }
                }
                Box(Modifier.align(Alignment.TopEnd)) {
                    TextButton(onClick = { menu = true }) { Text("⋯") }
                    DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                        DropdownMenuItem(
                            text = { Text(l("open_note")) },
                            onClick = { menu = false; onOpen(entry.id) }
                        )
                        DropdownMenuItem(
                            text = { Text(l("rename_note")) },
                            onClick = { menu = false; onRename(entry) }
                        )
                        DropdownMenuItem(
                            text = { Text(l("move_to_folder")) },
                            onClick = { menu = false; onMove(entry) }
                        )
                        DropdownMenuItem(
                            text = { Text(l("delete")) },
                            onClick = { menu = false; onDelete(entry) }
                        )
                    }
                }
            }
            Text(
                entry.title,
                fontWeight = FontWeight.SemiBold,
                maxLines = 1,
                modifier = Modifier.padding(top = 8.dp)
            )
            Text(
                "${entry.pageCount} ${l("pages")} · ${formatDate(entry.modifiedAt)}",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

@Composable
private fun SortMenu(
    sort: NotebookLibrary.Sort,
    l: (String) -> String,
    onSortChange: (NotebookLibrary.Sort) -> Unit
) {
    var open by remember { mutableStateOf(false) }
    val label = when (sort) {
        NotebookLibrary.Sort.MODIFIED -> l("sort_by_date")
        NotebookLibrary.Sort.TITLE -> l("sort_by_title")
        NotebookLibrary.Sort.PAGES -> l("sort_by_pages")
    }
    Box {
        TextButton(onClick = { open = true }) {
            Text(label, style = MaterialTheme.typography.labelMedium)
        }
        DropdownMenu(expanded = open, onDismissRequest = { open = false }) {
            for (option in NotebookLibrary.Sort.entries) {
                val text = when (option) {
                    NotebookLibrary.Sort.MODIFIED -> l("sort_by_date")
                    NotebookLibrary.Sort.TITLE -> l("sort_by_title")
                    NotebookLibrary.Sort.PAGES -> l("sort_by_pages")
                }
                DropdownMenuItem(
                    text = { Text(text) },
                    trailingIcon = { if (option == sort) Text("✓") },
                    onClick = { open = false; onSortChange(option) }
                )
            }
        }
    }
}

/** 重新命名對話框。與 Apple 端同一組字串鍵。 */
@Composable
fun RenameNotebookDialog(
    entry: NotebookLibrary.Entry,
    l: (String) -> String,
    onDismiss: () -> Unit,
    onConfirm: (String) -> Unit
) {
    var title by remember(entry.id) { mutableStateOf(entry.title) }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(l("rename_note")) },
        text = {
            OutlinedTextField(
                value = title,
                onValueChange = { title = it },
                label = { Text(l("note_title")) },
                singleLine = true
            )
        },
        confirmButton = {
            TextButton(onClick = { onConfirm(title.trim()); onDismiss() }) { Text(l("confirm")) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text(l("cancel")) } }
    )
}

/**
 * 刪除確認。
 *
 * 一定要問。刪掉的是整個套件目錄，沒有回收桶，那是使用者唯一的一份資料。
 */
@Composable
fun DeleteNotebookDialog(
    entry: NotebookLibrary.Entry,
    l: (String) -> String,
    onDismiss: () -> Unit,
    onConfirm: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(l("delete")) },
        text = { Text(l("delete_notebook_confirm").replace("%@", entry.title)) },
        confirmButton = {
            TextButton(onClick = { onConfirm(); onDismiss() }) { Text(l("delete")) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text(l("cancel")) } }
    )
}

private fun formatDate(millis: Long): String =
    if (millis <= 0) "—"
    else DateFormat.getDateInstance(DateFormat.MEDIUM).format(Date(millis))

private fun parseHex(hex: String): Color? =
    com.kairumo.padnote.chart.ChartRenderer.parseColor(hex)?.let { Color(it) }

/**
 * 麵包屑：最上層 → … → 現在這一層。
 *
 * 每一段都點得進去。只給一個「上一層」按鈕的話，在三層深的地方要回到
 * 最上層得按三次，而且中間每一次都會重新算一次清單。
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun Breadcrumb(
    path: List<FolderTree.Folder>,
    l: (String) -> String,
    onOpenFolder: (String?) -> Unit
) {
    FlowRow(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(0.dp)
    ) {
        TextButton(onClick = { onOpenFolder(null) }) { Text(l("root_folder")) }
        path.forEachIndexed { index, folder ->
            Text("›", modifier = Modifier.padding(top = 14.dp))
            TextButton(
                onClick = { onOpenFolder(folder.id) },
                // 最後一段是「現在在這裡」，點它沒有意義。
                enabled = index != path.lastIndex
            ) { Text(folder.title, maxLines = 1) }
        }
    }
}

@Composable
private fun FolderRow(
    folder: FolderTree.Folder,
    l: (String) -> String,
    onOpen: (String?) -> Unit,
    onRename: (FolderTree.Folder) -> Unit,
    onDelete: (FolderTree.Folder) -> Unit
) {
    var menu by remember(folder.id) { mutableStateOf(false) }
    Card(
        modifier = Modifier.fillMaxWidth().clickable { onOpen(folder.id) },
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant
        )
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(14.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            // 📁 而不是 🗀 —— 後者不在 Android 的預設字型裡，模擬器上
            // 直接是一個豆腐方塊。
            Text("📁", fontSize = 18.sp)
            Text(
                folder.title,
                fontWeight = FontWeight.SemiBold,
                fontSize = 16.sp,
                modifier = Modifier.weight(1f)
            )
            Box {
                TextButton(onClick = { menu = true }) { Text("⋯") }
                DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                    DropdownMenuItem(
                        text = { Text(l("rename_folder")) },
                        onClick = { menu = false; onRename(folder) }
                    )
                    DropdownMenuItem(
                        text = { Text(l("delete_folder")) },
                        onClick = { menu = false; onDelete(folder) }
                    )
                }
            }
        }
    }
}

/** 建立或重新命名資料夾。兩件事共用一個對話框，差別只在標題與初值。 */
@Composable
fun FolderNameDialog(
    title: String,
    initial: String,
    l: (String) -> String,
    onDismiss: () -> Unit,
    onConfirm: (String) -> Unit
) {
    var text by remember { mutableStateOf(initial) }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(title) },
        text = {
            OutlinedTextField(
                value = text,
                onValueChange = { text = it },
                label = { Text(l("folder_name")) },
                singleLine = true
            )
        },
        confirmButton = {
            TextButton(
                onClick = { onConfirm(text.trim()) },
                // 空名字的資料夾在清單上是一條看不出是什麼的空白列。
                enabled = text.isNotBlank()
            ) { Text(l("confirm")) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text(l("cancel")) } }
    )
}

/**
 * 刪除資料夾的確認。
 *
 * 訊息要講清楚**裡面的東西不會被刪掉** —— 只是跟著一起從清單上消失。
 * 不講的話，使用者會以為自己剛剛毀掉了整個資料夾的筆記。
 */
@Composable
fun DeleteFolderDialog(
    folder: FolderTree.Folder,
    l: (String) -> String,
    onDismiss: () -> Unit,
    onConfirm: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(l("delete_folder")) },
        text = { Text("${folder.title}\n\n${l("delete_folder_explainer")}") },
        confirmButton = {
            TextButton(onClick = onConfirm) { Text(l("delete")) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text(l("cancel")) } }
    )
}

/** 把一本筆記搬到哪個資料夾。列出全部資料夾加一個「最上層」。 */
@Composable
fun MoveToFolderDialog(
    entryTitle: String,
    folders: List<FolderTree.Folder>,
    l: (String) -> String,
    onDismiss: () -> Unit,
    onPick: (String?) -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(l("move_to_folder")) },
        text = {
            LazyColumn(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                item {
                    Text(entryTitle, style = MaterialTheme.typography.bodySmall)
                }
                item {
                    TextButton(onClick = { onPick(null) }) { Text(l("root_folder")) }
                }
                items(folders, key = { it.id }) { folder ->
                    TextButton(onClick = { onPick(folder.id) }) {
                        Text(folder.title, maxLines = 1)
                    }
                }
            }
        },
        confirmButton = {},
        dismissButton = { TextButton(onClick = onDismiss) { Text(l("cancel")) } }
    )
}

/**
 * 第一頁的縮圖。
 *
 * 產圖要開 session、重播 oplog、再光柵化一整頁，**一定要在背景執行緒** ——
 * 清單上有二十本就是二十次，放在主執行緒會讓首頁直接卡住。
 *
 * 還沒算好（或算不出來）時畫一個同樣大小的空框，不要讓版面在圖片到位時
 * 跳一下。
 */
@Composable
private fun NotebookThumbnail(
    entry: NotebookLibrary.Entry,
    modifier: Modifier = Modifier,
    /** 縮圖還沒好、或那一頁根本沒有筆畫時要畫什麼。 */
    placeholder: @Composable () -> Unit = {}
) {
    val context = LocalContext.current
    // 鍵帶上修改時間：內容變了就重算，沒變就直接用快取。
    val bitmap by produceState<ImageBitmap?>(null, entry.id, entry.modifiedAt) {
        value = withContext(Dispatchers.IO) {
            NotebookThumbnails.load(context, entry)
        }
    }

    Box(
        modifier
            .background(MaterialTheme.colorScheme.surface, RoundedCornerShape(6.dp))
            .border(1.dp, MaterialTheme.colorScheme.outlineVariant, RoundedCornerShape(6.dp))
    ) {
        val image = bitmap
        if (image == null || isBlank(image)) {
            placeholder()
        } else {
            Image(
                bitmap = image,
                contentDescription = null,
                // 格狀卡片是**寬**的，縮圖是整頁的直式比例 —— 用 Fit 的話
                // 會在兩側留下大片空白。Crop 取上緣：一頁的重點在上面。
                contentScale = ContentScale.Crop,
                alignment = Alignment.TopCenter,
                modifier = Modifier.fillMaxSize().padding(1.dp)
            )
        }
    }
}

/**
 * 這張縮圖是不是一片空白。
 *
 * Android 的 `export_page_png` 只畫底紋與筆畫（工作項 S-43），所以一本
 * 只打字沒手寫的筆記會得到一張全白的圖。直接顯示的話，格狀清單上會是
 * 一排白方塊 —— 看起來像縮圖壞了，而其實是還沒實作。
 *
 * 抽樣而不是掃全圖：一張縮圖幾萬個像素，每次重組都全掃會卡住捲動。
 */
private fun isBlank(image: ImageBitmap): Boolean {
    val pixels = IntArray(image.width * image.height)
    runCatching { image.readPixels(pixels) }.getOrElse { return false }
    val step = maxOf(1, pixels.size / 512)
    var i = 0
    while (i < pixels.size) {
        val p = pixels[i]
        val r = (p shr 16) and 0xFF
        val g = (p shr 8) and 0xFF
        val b = p and 0xFF
        // 底紋的線也很淡，所以門檻抓在「幾乎純白」之外一點。
        if (r < 235 || g < 235 || b < 235) return false
        i += step
    }
    return true
}

/**
 * 一段錄音。點下去開它所屬的那一本筆記。
 *
 * 顯示的是**筆記本標題**而不是檔名：檔名是 uuid，對使用者沒有意義。
 */
@Composable
private fun RecordingRow(
    recording: RecordingIndex.Recording,
    l: (String) -> String,
    onOpen: (String) -> Unit,
    onInsert: (RecordingIndex.Recording) -> Unit
) {
    var menu by remember(recording.file.absolutePath) { mutableStateOf(false) }
    val playing = AudioPlayback.playingId == recording.file.absolutePath
    var tick by remember { mutableStateOf(0) }

    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant
        )
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            // 播放鈕。與 Apple 的錄音列一致 —— 原本這裡只有一個麥克風符號，
            // 要聽得先開那本筆記再找到它。
            Box(
                Modifier
                    .size(38.dp)
                    .background(Color(0x22D9453C), CircleShape)
                    .clickable {
                        AudioPlayback.toggle(recording.file.absolutePath, recording.file) { tick++ }
                        tick++
                    },
                contentAlignment = Alignment.Center
            ) {
                @Suppress("UNUSED_EXPRESSION") tick
                Text(if (playing) "⏸" else "▶", fontSize = 13.sp, color = Color(0xFFD9453C))
            }
            Column(Modifier.weight(1f)) {
                Text(recording.notebookTitle, fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
                Text(
                    "${formatDate(recording.recordedAt)} · ${recording.bytes / 1024} KB",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            Box {
                TextButton(onClick = { menu = true }) { Text("⋯") }
                DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                    DropdownMenuItem(
                        text = { Text(l("insert_to_notebook")) },
                        onClick = { menu = false; onInsert(recording) }
                    )
                    DropdownMenuItem(
                        text = { Text(l("open_note")) },
                        onClick = { menu = false; onOpen(recording.notebookId) }
                    )
                }
            }
        }
    }
}

/**
 * Google 帳號同步的畫面狀態。
 *
 * 把狀態收成一個資料類別而不是攤成六個參數：這一組要嘛全都有、要嘛全都
 * 沒有意義，拆開來會讓呼叫端有機會只傳一半。
 */
data class CloudSyncUiState(
    val signedIn: Boolean,
    val busy: Boolean,
    /** 給使用者看的一行字（同步中／結果／錯誤）。沒有就不顯示那一行。 */
    val message: String?,
    val onSignIn: () -> Unit,
    val onSyncNow: () -> Unit,
    val onSignOut: () -> Unit
)

/**
 * 雲端同步卡片。欄位與動作與 Apple 的 `googleAccountSection` 一一對應。
 *
 * 兩邊長得不一樣沒關係（一個是 iOS 的 Form、一個是 Material 卡片），
 * **但看得到的東西與做得到的事必須一樣**：使用者換裝置時不該發現
 * 「這台可以登出、那台不行」。
 */
@Composable
private fun CloudSyncCard(state: CloudSyncUiState, l: (String) -> String) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant
        )
    ) {
        Column(
            modifier = Modifier.fillMaxWidth().padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("Google Drive", fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
                Text(
                    // 已登入時顯示「同步」而不是帳號位址：我們沒有要求
                    // email 範圍，手上根本沒有那個資訊，顯示一個假的更糟。
                    if (state.signedIn) l("sync_section") else l("not_signed_in"),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            state.message?.let {
                Text(
                    it,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.primary
                )
            }

            if (state.signedIn) {
                Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    TextButton(onClick = state.onSyncNow, enabled = !state.busy) {
                        Text(l("sync_now"))
                    }
                    TextButton(onClick = state.onSignOut, enabled = !state.busy) {
                        Text(l("sign_out"), color = MaterialTheme.colorScheme.error)
                    }
                }
            } else {
                TextButton(onClick = state.onSignIn, enabled = !state.busy) {
                    Text(l("sign_in_google"))
                }
            }

            Text(
                // 這一段講的是**Google 帳號**這條路，不是「自選資料夾」那一條。
                // 用錯的話，使用者會照著去找一個根本不存在的資料夾設定。
                l("cloud_sync_explainer"),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}
