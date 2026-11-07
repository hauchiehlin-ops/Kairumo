package com.kairumo.padnote.collab

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kairumo.padnote.LocalizationStrings

/**
 * 協同即時語音 PTT 浮動膠囊（按住說話與發話狀態指示）。
 */
@Composable
fun CollabVoiceFloatingCapsule(
    voice: CollabVoiceManager,
    languageTag: String,
    modifier: Modifier = Modifier
) {
    fun l(key: String) = LocalizationStrings.localized(key, languageTag)

    val isTalking = voice.isTalking
    val scale by animateFloatAsState(targetValue = if (isTalking) 1.05f else 1f, label = "scale")

    Surface(
        shape = RoundedCornerShape(24.dp),
        color = MaterialTheme.colorScheme.surface.copy(alpha = 0.95f),
        tonalElevation = 6.dp,
        shadowElevation = 6.dp,
        modifier = modifier.padding(8.dp)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp)
        ) {
            // 發話者狀態指示標籤
            voice.activeSpeakerName?.let { speaker ->
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                    modifier = Modifier
                        .clip(RoundedCornerShape(12.dp))
                        .background(Color(0xFF4CAF50).copy(alpha = 0.15f))
                        .padding(horizontal = 8.dp, vertical = 4.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .size(8.dp)
                            .clip(CircleShape)
                            .background(Color(0xFF4CAF50))
                    )
                    Text(
                        text = l("collab_voice_peer_talking").replace("%@", speaker),
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Medium,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                }
            }

            // 喇叭靜音切換
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .size(32.dp)
                    .clip(CircleShape)
                    .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.6f))
                    .clickable { voice.setMutedState(!voice.isMuted) }
            ) {
                Text(
                    text = if (voice.isMuted) "🔇" else "🔊",
                    fontSize = 14.sp
                )
            }

            // 按住說話（PTT）按鈕
            val btnColor = if (isTalking) Color(0xFF4CAF50) else MaterialTheme.colorScheme.primary
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                modifier = Modifier
                    .scale(scale)
                    .clip(RoundedCornerShape(20.dp))
                    .background(btnColor)
                    .pointerInput(voice) {
                        detectTapGestures(
                            onPress = {
                                voice.startTalking()
                                tryAwaitRelease()
                                voice.stopTalking()
                            }
                        )
                    }
                    .padding(horizontal = 14.dp, vertical = 8.dp)
            ) {
                Text(
                    text = "🎙️",
                    fontSize = 13.sp
                )
                Text(
                    text = l(if (isTalking) "collab_voice_ptt_talking" else "collab_voice_ptt_hold"),
                    color = Color.White,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold
                )
            }
        }
    }
}
