package com.kairumo.padnote.audio

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kairumo.padnote.models.ModelDownloadManager
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import uniffi.padnote_core.transcriptNeedsTranslation
import uniffi.padnote_core.transcriptOutputLanguage
import uniffi.padnote_core.whisperIsModelAvailable

/** 與 Apple 的 `AppLanguage.endonym` 相同。 */
private fun endonym(tag: String): String = when (tag) {
    "zh-Hant" -> "繁體中文"
    "zh-Hans" -> "简体中文"
    "en" -> "English"
    "ja" -> "日本語"
    "ko" -> "한국어"
    "th" -> "ไทย"
    else -> tag
}

/**
 * 首頁設定裡的「語音轉錄」：音訊語言、轉出文字語言（含翻譯模型）、降噪、Whisper 模型。
 *
 * 與 Apple 首頁的語音轉錄區塊對應。Android 原本沒有任何地方能下載 Whisper 模型，
 * 錄音轉錄永遠停在「需要模型」—— 模型的下載與刪除也放在這裡。
 */
@Composable
fun SpeechSettingsCard(l: (String) -> String) {
    var open by remember { mutableStateOf(false) }
    Card(
        modifier = Modifier.fillMaxWidth().clickable { open = true }.testTag("home.speech.settings"),
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
    ) {
        Row(Modifier.fillMaxWidth().padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
            Text("🎙", fontSize = 18.sp, modifier = Modifier.padding(end = 12.dp))
            Column(Modifier.weight(1f)) {
                Text(l("hw_asr_settings_title"), fontWeight = FontWeight.SemiBold)
                Text(
                    l("hw_asr_settings_desc"),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 2
                )
            }
            Text("›", fontSize = 18.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
    if (open) SpeechSettingsDialog(l) { open = false }
}

@Composable
private fun SpeechSettingsDialog(l: (String) -> String, onDismiss: () -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    var source by remember { mutableStateOf(AudioTranscriber.sourceLanguagePreference(context)) }
    var output by remember { mutableStateOf(AudioTranscriber.outputLanguagePreference(context)) }
    var denoise by remember { mutableStateOf(AudioTranscriber.isDenoiseEnabled(context)) }

    val sourceTag = source.ifEmpty { AudioTranscriber.sourceLanguageTag(context) }
    val needsTranslation = transcriptNeedsTranslation(sourceTag, output)
    val targetTag = transcriptOutputLanguage(sourceTag, output)

    // 翻譯模型：null = 檢查中。
    var packReady by remember { mutableStateOf<Boolean?>(null) }
    var packBusy by remember { mutableStateOf(false) }
    var packError by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(sourceTag, targetTag, needsTranslation) {
        packReady = null
        packError = null
        if (needsTranslation) packReady = TranscriptTranslator.isReady(sourceTag, targetTag)
    }

    // Whisper 模型。
    val modelPath = remember { ModelDownloadManager.modelPath(context, AudioTranscriber.WHISPER_MODEL_ID) }
    var modelReady by remember { mutableStateOf(whisperIsModelAvailable(modelPath)) }
    var modelProgress by remember { mutableStateOf<Float?>(null) }
    var modelError by remember { mutableStateOf<String?>(null) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(l("hw_asr_settings_title")) },
        text = {
            Column(
                Modifier.verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                LanguagePicker(
                    label = l("hw_asr_source_language"),
                    defaultLabel = l("hw_asr_source_follow_ui"),
                    selected = source,
                    tag = "home.speech.source_language"
                ) {
                    source = it
                    AudioTranscriber.setSourceLanguagePreference(context, it)
                }
                LanguagePicker(
                    label = l("hw_asr_output_language"),
                    defaultLabel = l("hw_asr_output_same"),
                    selected = output,
                    tag = "home.speech.output_language"
                ) {
                    output = it
                    AudioTranscriber.setOutputLanguagePreference(context, it)
                }

                if (needsTranslation) {
                    when {
                        packBusy -> Column {
                            Text(l("hw_asr_translate_pack_downloading"), style = MaterialTheme.typography.bodySmall)
                            LinearProgressIndicator(Modifier.fillMaxWidth())
                        }
                        packReady == true -> Text(
                            "✓ " + l("hw_asr_translate_pack_ready"),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.primary
                        )
                        packReady == false && TranscriptTranslator.mlkitLanguage(targetTag) == null ->
                            Text(l("hw_asr_translate_pack_unsupported"), style = MaterialTheme.typography.bodySmall)
                        packReady == false -> OutlinedButton(onClick = {
                            packBusy = true
                            packError = null
                            scope.launch {
                                packError = runCatching { TranscriptTranslator.download(sourceTag, targetTag) }
                                    .exceptionOrNull()?.let { it.message ?: it.javaClass.simpleName }
                                packReady = TranscriptTranslator.isReady(sourceTag, targetTag)
                                packBusy = false
                            }
                        }) { Text(l("hw_asr_translate_pack_download")) }
                    }
                    packError?.let {
                        Text(it, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error)
                    }
                }
                Text(
                    l("hw_asr_translate_hint"),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )

                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text(l("hw_asr_denoise"))
                        Text(
                            l("hw_asr_denoise_hint"),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                    Switch(
                        checked = denoise,
                        onCheckedChange = {
                            denoise = it
                            AudioTranscriber.setDenoiseEnabled(context, it)
                        },
                        modifier = Modifier.testTag("home.speech.denoise")
                    )
                }

                when {
                    modelReady -> Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(l("hw_asr_model_ready_size"), Modifier.weight(1f), style = MaterialTheme.typography.bodySmall)
                        TextButton(onClick = {
                            ModelDownloadManager.remove(context, AudioTranscriber.WHISPER_MODEL_ID)
                            modelReady = whisperIsModelAvailable(modelPath)
                        }) { Text(l("asr_remove_model"), color = MaterialTheme.colorScheme.error) }
                    }
                    modelProgress != null -> Column {
                        Text(l("whisper_downloading"), style = MaterialTheme.typography.bodySmall)
                        LinearProgressIndicator(progress = { modelProgress ?: 0f }, modifier = Modifier.fillMaxWidth())
                    }
                    else -> OutlinedButton(onClick = {
                        modelError = null
                        modelProgress = 0f
                        scope.launch {
                            val total = ModelDownloadManager.catalog(context)
                                .firstOrNull { it.id == AudioTranscriber.WHISPER_MODEL_ID }?.sizeBytes?.toLong() ?: 0L
                            val result = withContext(Dispatchers.IO) {
                                runCatching {
                                    ModelDownloadManager.download(context, AudioTranscriber.WHISPER_MODEL_ID) { got ->
                                        if (total > 0) {
                                            scope.launch { modelProgress = (got.toFloat() / total).coerceIn(0f, 1f) }
                                        }
                                    }
                                }
                            }
                            modelProgress = null
                            result.onSuccess {
                                if (!it.ok) modelError = it.error.ifEmpty { null }
                            }.onFailure { modelError = it.message ?: it.javaClass.simpleName }
                            modelReady = whisperIsModelAvailable(modelPath)
                        }
                    }) { Text(l("hw_asr_download_official")) }
                }
                modelError?.let {
                    Text(
                        l("hw_asr_download_failed").replace("%@", it),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.error
                    )
                }
            }
        },
        confirmButton = { TextButton(onClick = onDismiss) { Text(l("done")) } }
    )
}

@Composable
private fun LanguagePicker(
    label: String,
    defaultLabel: String,
    selected: String,
    tag: String,
    onSelect: (String) -> Unit
) {
    var expanded by remember { mutableStateOf(false) }
    Column {
        Text(label, style = MaterialTheme.typography.labelMedium)
        Box {
            OutlinedButton(onClick = { expanded = true }, modifier = Modifier.fillMaxWidth().testTag(tag)) {
                Text(if (selected.isEmpty()) defaultLabel else endonym(selected))
            }
            DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                DropdownMenuItem(text = { Text(defaultLabel) }, onClick = { onSelect(""); expanded = false })
                AudioTranscriber.transcriptLanguages.forEach { lang ->
                    DropdownMenuItem(text = { Text(endonym(lang)) }, onClick = { onSelect(lang); expanded = false })
                }
            }
        }
    }
}
