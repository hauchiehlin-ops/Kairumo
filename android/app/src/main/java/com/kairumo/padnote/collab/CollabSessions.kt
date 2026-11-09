package com.kairumo.padnote.collab

import android.content.Context

/**
 * 即時協同的「會議室」活在 App 層級，不跟著編輯器畫面走。
 *
 * 以前 [CollaborationManager] 是編輯器裡 `remember(notebookId)` 出來的：關掉筆記回首頁，
 * 畫面一拆就順手 `disconnect()` —— 協作者回首頁看一眼，就被踢出會議室（實機回報）。
 * 現在由這裡保管：
 *
 * - 回首頁、再打開**同一本**：拿回同一個管理器（同一個 user id、同一條連線），編輯器重建時
 *   以房間為基準重新要一次整份狀態，補上不在畫面時錯過的修改。
 * - 打開**另一本**：房間是綁在筆記本上的（別本的內容不能套進這本），先離開原本的房間再換。
 * - 真正離開：使用者在協同面板按「離開／結束協同」。
 *
 * 與 Apple `CollaborationManager.shared` + `leaveRoom(unlessBoundTo:)` 同一套。
 */
// profile-scope: device 只在記憶體裡的連線物件；切換設定檔會重啟行程，不會跨設定檔留著
object CollabSessions {
    private var manager: CollaborationManager? = null
    private var voice: CollabVoiceManager? = null
    private var boundNotebook: String? = null

    /** 目前保管中的管理器（可能不在房間裡）。App 前景／背景切換時通知它。 */
    val current: CollaborationManager? @Synchronized get() = manager

    /** 編輯器打開 [notebookId] 時呼叫：同一本沿用；換本則先離開原本的房間。 */
    @Synchronized
    fun obtain(context: Context, notebookId: String?): CollaborationManager {
        val key = notebookId?.trim()?.lowercase()?.takeIf { it.isNotEmpty() }
        val existing = manager
        if (existing != null && key != null && key == boundNotebook) return existing
        releaseLocked()
        val created = CollaborationManager(context.applicationContext)
        manager = created
        boundNotebook = key
        return created
    }

    /** 這個管理器的語音（一個管理器一個，跟著會議室活著：回首頁仍聽得到其他人說話）。 */
    @Synchronized
    fun voiceFor(context: Context, collaboration: CollaborationManager): CollabVoiceManager {
        val existing = voice
        if (existing != null && collaboration === manager && collaboration.voice === existing) return existing
        val created = CollabVoiceManager(context.applicationContext, collaboration)
        collaboration.voice = created
        if (collaboration === manager) voice = created
        return created
    }

    @Synchronized
    private fun releaseLocked() {
        val old = manager ?: return
        voice?.reset()
        old.voice = null
        old.stateDepositor = null
        old.onRoomClosed = null
        old.disconnect()
        manager = null
        voice = null
        boundNotebook = null
    }
}
