package com.kairumo.padnote.audio

import android.media.MediaPlayer
import java.io.File

/**
 * 播放頁面上的錄音卡片。
 *
 * # 為什麼一次只播一個
 *
 * 同一頁可以放好幾張卡片。不擋的話，使用者按第二張時兩段聲音會疊在一起，
 * 而且第一張的按鈕還停在「暫停」—— 看起來像壞了。
 *
 * 狀態以**卡片 id** 為鍵，不是錄音檔名：同一段錄音可以插在兩頁上，
 * 按第 2 頁那張時第 1 頁不該一起變成暫停鈕。
 */
object AudioPlayback {

    private var player: MediaPlayer? = null
    private var currentId: String? = null

    val playingId: String? get() = if (player?.isPlaying == true) currentId else null

    val currentPositionMs: Int get() = runCatching { player?.currentPosition ?: 0 }.getOrDefault(0)
    val durationMs: Int get() = runCatching { player?.duration ?: 0 }.getOrDefault(0)

    fun seekTo(positionMs: Int) {
        runCatching { player?.seekTo(positionMs) }
    }

    /**
     * 切換播放／暫停。回傳現在正在播的卡片 id（沒有就 null）——
     * 呼叫端拿它更新畫面。
     */
    fun toggle(cardId: String, file: File, onFinished: () -> Unit): String? {
        if (currentId == cardId && player?.isPlaying == true) {
            runCatching { player?.pause() }
            return null
        }
        if (currentId == cardId && player != null) {
            return runCatching { player?.start(); cardId }.getOrNull()
        }
        stop()
        if (!file.isFile) return null
        return runCatching {
            val mp = MediaPlayer()
            mp.setDataSource(file.absolutePath)
            mp.prepare()
            mp.setOnCompletionListener {
                stop()
                onFinished()
            }
            mp.start()
            player = mp
            currentId = cardId
            cardId
        }.getOrNull()
    }

    /** 放掉播放器。離開編輯畫面一定要叫 —— 不放的話聲音會繼續播下去。 */
    fun stop() {
        runCatching { player?.stop() }
        runCatching { player?.release() }
        player = null
        currentId = null
    }
}
