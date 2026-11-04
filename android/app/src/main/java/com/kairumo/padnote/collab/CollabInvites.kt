package com.kairumo.padnote.collab

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

/**
 * 從外面進來的協同邀請（相機掃了 QR Code、點了 `kairumo://collab?...` 連結）。
 *
 * 不直接加入房間：使用者可能正開著別本筆記，要讓他看見是哪個房間、按「加入」才連。
 * 編輯器看到 [pending] 有值就打開協同面板，面板把連結帶進「加入房間」欄位。
 * 與 Apple `CollaborationManager.pendingInviteLink` 同一套流程。
 */
// profile-scope: device 只是「剛收到、還沒按加入」的一條連結，交給目前畫面就清掉
object CollabInvites {
    var pending by mutableStateOf<String?>(null)

    /** 是協同邀請就收下（回 true）。只認 `kairumo://collab`，其他連結原樣放行。 */
    fun offer(link: String?): Boolean {
        val text = link?.trim() ?: return false
        if (!text.startsWith("kairumo://collab", ignoreCase = true)) return false
        pending = text
        return true
    }
}
