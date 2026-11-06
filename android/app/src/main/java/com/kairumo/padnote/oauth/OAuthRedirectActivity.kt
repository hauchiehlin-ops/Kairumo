package com.kairumo.padnote.oauth

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/**
 * 接住 Google 授權跳回來的自訂 scheme。
 *
 * 這個 activity 沒有畫面（`Theme.NoDisplay`）：它唯一的工作是把授權碼交給
 * [GoogleAuth] 換權杖，然後立刻關掉自己回到原本的畫面。
 *
 * # 為什麼要另外開一個 activity
 *
 * 跳轉是從**瀏覽器**進來的，所以接收端必須 `exported="true"`。
 * 讓 MainActivity 直接接的話，等於把整個編輯器暴露成任何 App 都叫得動的
 * 入口；分一個只會解析授權碼的小 activity 出來，暴露面就只有這一件事。
 */
class OAuthRedirectActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handle(intent)
    }

    /**
     * `singleTask` 模式下，App 已經在跑時會走這裡而不是 `onCreate` ——
     * 只實作 onCreate 的話，第二次之後的授權會完全沒有反應。
     */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handle(intent)
    }

    private fun handle(intent: Intent) {
        val context = applicationContext
        // 換權杖是網路請求，在背景進行並即時發送狀態通知。
        CoroutineScope(Dispatchers.IO).launch {
            GoogleAuth.handleRedirect(context, intent)
        }
        // 將 MainActivity 喚回最上層並清空上方的 Custom Tab 任務堆疊，
        // 避免瀏覽器以子母畫面（PiP overlay）形式殘留在畫面上。
        val mainIntent = Intent(this, com.kairumo.padnote.MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        startActivity(mainIntent)
        finish()
    }
}
