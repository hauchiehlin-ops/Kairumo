package com.kairumo.padnote.sync

import android.content.Context
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import com.kairumo.padnote.library.CloudSync
import com.kairumo.padnote.library.SyncHistory
import com.kairumo.padnote.oauth.GoogleAuth
import java.util.concurrent.TimeUnit

/**
 * 背景同步（P2）。
 *
 * # 為什麼前景的計時器不夠
 *
 * App 切到背景之後，行程隨時會被系統收掉，[AutoSync] 的協程跟著停。
 * 使用者把 App 切走之前寫的最後一段，要等他下次打開才會上雲 ——
 * 而他通常是**在另一台裝置上**發現那一段不見了。
 *
 * # 為什麼是 WorkManager 而不是 AlarmManager
 *
 * Doze、省電模式、開機重啟、失敗重試，這四件事只有 WorkManager 會處理。
 * 週期最短 15 分鐘是系統的硬限制，不是我們選的 —— 所以它是**保底**，
 * 不是主要路徑。真正的「即時」靠前景觸發（見 [AutoSync]）。
 *
 * # 為什麼要 unmetered 之外的網路也允許
 *
 * 只在 Wi-Fi 同步的話，整天在外面的使用者會以為同步壞了。
 * 同步的量很小（P1 之後沒有變動就是一個請求），不值得為它設限。
 */
class SyncWorker(context: Context, params: WorkerParameters) :
    CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        val context = applicationContext
        if (!GoogleAuth.isSignedIn(context)) {
            // 沒登入不是失敗，也不該退避重試。
            return Result.success()
        }
        return runCatching {
            val full = CloudSync.runFull(context, AutoSync.currentDeviceId())
            val meta = full.meta
            when {
                // 被擋下來代表有一輪正在跑；這次排程重試即可。
                // 當成 success 的話這次排程就這樣沒了。
                full.skipped -> Result.retry()
                meta == null -> Result.success() // 拿不到權杖：等使用者去登入
                meta.needsReauth -> Result.success()
                !meta.ok -> Result.retry()
                else -> {
                    SyncHistory.markGoogleSynced(context)
                    Result.success()
                }
            }
        }.getOrElse { Result.retry() }
    }

    companion object {
        private const val WORK_NAME = "kairumo.sync.periodic"

        /**
         * 註冊週期性背景同步。重複呼叫是安全的（KEEP 會保留既有排程，
         * 不會每次開 App 就把倒數重設 —— 那會讓它永遠不執行）。
         */
        fun schedule(context: Context) {
            val request = PeriodicWorkRequestBuilder<SyncWorker>(15, TimeUnit.MINUTES)
                .setConstraints(
                    Constraints.Builder()
                        .setRequiredNetworkType(NetworkType.CONNECTED)
                        .build()
                )
                .build()
            runCatching {
                WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                    WORK_NAME, ExistingPeriodicWorkPolicy.KEEP, request
                )
            }
        }

        fun cancel(context: Context) {
            runCatching { WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME) }
        }
    }
}
