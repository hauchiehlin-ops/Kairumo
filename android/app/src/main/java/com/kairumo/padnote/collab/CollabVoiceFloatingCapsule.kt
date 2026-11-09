package com.kairumo.padnote.collab

import android.Manifest
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.offset
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.ui.unit.IntOffset
import kotlin.math.roundToInt
import androidx.compose.foundation.gestures.waitForUpOrCancellation
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
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import com.kairumo.padnote.LocalizationStrings

/** 短於此毫秒數的按壓視為「點一下」：鎖定發話，再點一下才結束（與 Apple 相同）。 */
private const val TAP_LATCH_MS = 350L

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
    val context = LocalContext.current

    var hasMicPermission by remember {
        mutableStateOf(
            ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
        )
    }
    val micPermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        hasMicPermission = granted
    }

    val isTalking = voice.isTalking
    val scale by animateFloatAsState(targetValue = if (isTalking) 1.05f else 1f, label = "scale")
    var offsetX by remember { mutableFloatStateOf(0f) }
    var offsetY by remember { mutableFloatStateOf(0f) }

    Surface(
        shape = RoundedCornerShape(24.dp),
        color = MaterialTheme.colorScheme.surface.copy(alpha = 0.95f),
        tonalElevation = 6.dp,
        shadowElevation = 6.dp,
        modifier = modifier
            .offset { IntOffset(offsetX.roundToInt(), offsetY.roundToInt()) }
            .padding(8.dp)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp)
        ) {
            // 拖曳把手。拖曳只綁在把手上 —— 舊版綁在整顆膠囊，按住說話時手指一滑超過觸控斜率，
            // 外層拖曳就把手勢吃掉，PTT 按鈕收到取消、立刻送出 `end`，對方只聽到一片空白。
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .size(width = 22.dp, height = 32.dp)
                    .pointerInput(Unit) {
                        detectDragGestures { change, dragAmount ->
                            change.consume()
                            offsetX += dragAmount.x
                            offsetY += dragAmount.y
                        }
                    }
            ) {
                Text(
                    text = "≡",
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f)
                )
            }

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
                    .pointerInput(voice, hasMicPermission) {
                        // 兩種用法都要能說話（實機回報「點擊麥克風膠囊，房主那沒有聲音」）：
                        // - 按住說話：按下開始、放開結束（原本的 PTT）。
                        // - 點一下：短按（< TAP_LATCH_MS）不結束，維持發話；再點一下才結束。
                        //   舊版短按只送出 begin／end，100ms 一個的音框一個都還沒湊滿，對方當然沒聲音。
                        awaitEachGesture {
                            awaitFirstDown(requireUnconsumed = false)
                            if (!hasMicPermission) {
                                micPermissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
                                return@awaitEachGesture
                            }
                            if (voice.isTalking) {
                                // 已經在（點一下鎖定的）發話中：這一下是結束。
                                waitForUpOrCancellation()
                                voice.stopTalking()
                                return@awaitEachGesture
                            }
                            val downAt = System.currentTimeMillis()
                            voice.startTalking()
                            val up = waitForUpOrCancellation()
                            val heldMs = System.currentTimeMillis() - downAt
                            if (up == null || heldMs >= TAP_LATCH_MS) voice.stopTalking()
                        }
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
