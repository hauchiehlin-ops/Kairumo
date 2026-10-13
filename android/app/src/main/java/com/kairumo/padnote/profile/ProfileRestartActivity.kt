package com.kairumo.padnote.profile

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.os.Process
import androidx.core.content.IntentCompat

/**
 * 切換設定檔時重啟 App 用的**跳板**，跑在獨立的行程（`:restart`）裡。
 *
 * # 為什麼需要它
 *
 * 在主行程裡「先 `startActivity`、再自殺」不可靠：行程一死，剛送出去的啟動請求可能跟著消失，
 * 使用者看到的是 App 直接關掉。標準做法是請一個**另一個行程**的 Activity 來殺主行程、
 * 再由它啟動 App —— 它自己不受影響（這也是 ProcessPhoenix 的做法）。
 */
class ProfileRestartActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val relaunch = IntentCompat.getParcelableExtra(intent, EXTRA_RELAUNCH, Intent::class.java)
        val mainPid = intent.getIntExtra(EXTRA_MAIN_PID, -1)
        if (mainPid > 0) Process.killProcess(mainPid)
        if (relaunch != null) startActivity(relaunch)
        finish()
        // 這個跳板行程也結束，不留一個空殼行程在背景。
        Runtime.getRuntime().exit(0)
    }

    companion object {
        private const val EXTRA_RELAUNCH = "relaunch"
        private const val EXTRA_MAIN_PID = "mainPid"

        /** 重啟 App。呼叫之前，設定檔名單與 `ProfileContext` 必須已經用 `commit()` 寫進磁碟。 */
        fun restart(activity: Activity) {
            val launch = activity.packageManager.getLaunchIntentForPackage(activity.packageName)
                ?.apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK) }
                ?: return
            val phoenix = Intent(activity, ProfileRestartActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                putExtra(EXTRA_RELAUNCH, launch)
                putExtra(EXTRA_MAIN_PID, Process.myPid())
            }
            activity.startActivity(phoenix)
            activity.finishAffinity()
        }
    }
}
