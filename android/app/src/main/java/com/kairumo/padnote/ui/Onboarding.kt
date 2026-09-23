package com.kairumo.padnote.ui

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import com.kairumo.padnote.LocalizationStrings

/**
 * 首次啟動引導與權限說明（工作項 S-66）。
 *
 * # 為什麼不是「安裝時就要到所有權限」
 *
 * 這件事在 Android 與 iOS 上都**做不到，也不該做**：
 *
 * - 安裝時不會有任何對話框。Android 6 之後危險權限一律在執行期要，
 *   iOS 從來就是這樣。
 * - 系統的權限對話框**只能由 App 主動觸發一次**。使用者按了拒絕之後，
 *   再呼叫同一個 API 不會再跳 —— 只會直接回「被拒絕」。
 *
 * 所以這裡做的是**在使用者第一次打開 App 時把話講清楚**：要哪一個權限、
 * 為什麼要、不給會少什麼，並且**當場提供那顆按鈕**。按下去才是系統對話框。
 * 已經被永久拒絕時，改成把人送進系統設定頁 —— 那是那時候唯一還走得通的路。
 *
 * # 只有一項
 *
 * 這個 App 唯一的危險權限是麥克風，而且只有錄音用得到。清單裡原本還有
 * `NEARBY_WIFI_DEVICES` 與 `ACCESS_WIFI_STATE`，但**程式裡從來沒有用過**
 * （協同是連使用者自己輸入的 ws:// 位址，沒有做任何裝置探索）—— 宣告了
 * 卻不用的危險權限，只會讓商店頁面上多一條嚇人的「附近的裝置」。已移除。
 */
object Onboarding {

    private const val PREFS = "kairumo_onboarding"
    private const val KEY_SEEN = "seen_v1"

    fun hasSeen(context: Context): Boolean =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(KEY_SEEN, false)

    fun markSeen(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putBoolean(KEY_SEEN, true).apply()
    }

    fun hasMicrophone(context: Context): Boolean =
        ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED

    /** 把使用者送到這個 App 的系統設定頁 —— 權限被永久拒絕時唯一的路。 */
    fun openAppSettings(context: Context) {
        val intent = Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.fromParts("package", context.packageName, null)
        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        runCatching { context.startActivity(intent) }
    }
}

@Composable
fun OnboardingScreen(onDone: () -> Unit) {
    val context = LocalContext.current
    val lang = LocalAppLanguage.current
    fun l(key: String) = LocalizationStrings.localized(key, lang)

    var granted by remember { mutableStateOf(Onboarding.hasMicrophone(context)) }
    // 按過一次而且沒拿到 —— 之後再按系統也不會再跳，要改走設定頁。
    var asked by remember { mutableStateOf(false) }

    val micPermission = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { result ->
        granted = result
        asked = true
        // 問完就離開導覽，不論給不給 —— 把人卡在導覽裡沒有道理。
        onDone()
    }

    // 這一頁全是文字，所以用「可讀寬度」而不是一般的內容寬度。
    //
    // 在此之前是 `fillMaxSize()` —— 平板橫向 1280dp 時，「手寫、打字、
    // 錄音同一頁…」那一行從最左邊拉到最右邊，眼睛要橫掃整個螢幕才讀完
    // 一行。那是使用者看到的**第一個畫面**。
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.TopCenter
    ) {
    Column(
        // **順序有意義。** `fillMaxSize()` 會把最小寬度也設成父層的最大值，
        // 後面再 `widthIn(max = 720)` 是沒有用的 —— 最小值贏。
        // 要先夾住上限，再用 `fillMaxWidth()` 把寬度撐到那個上限。
        modifier = Modifier
            .fillMaxHeight()
            .widthIn(max = DS.Content.readableMaxWidth)
            .fillMaxWidth()
            .verticalScroll(rememberScrollState())
            .padding(DS.Space.l),
        verticalArrangement = Arrangement.spacedBy(DS.Space.m)
    ) {
        Spacer(Modifier.height(DS.Space.l))
        Text(l("onboarding_welcome_title"), style = MaterialTheme.typography.headlineSmall)
        Text(l("onboarding_welcome_body"), style = MaterialTheme.typography.bodyMedium)

        Spacer(Modifier.height(DS.Space.s))
        Text(l("onboarding_privacy_title"), style = MaterialTheme.typography.titleMedium)
        Text(l("onboarding_privacy_body"), style = MaterialTheme.typography.bodyMedium)

        Spacer(Modifier.height(DS.Space.s))
        Text(l("onboarding_permission_title"), style = MaterialTheme.typography.titleMedium)
        Text(l("onboarding_permission_body"), style = MaterialTheme.typography.bodyMedium)

        if (granted) {
            Text(
                l("onboarding_microphone_granted"),
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.primary
            )
        } else if (asked) {
            // 已經問過而且被拒 —— 再問一次系統不會有反應，送去設定頁。
            OutlinedButton(onClick = { Onboarding.openAppSettings(context) }) {
                Text(l("permission_open_settings"))
            }
        }

        Spacer(Modifier.height(DS.Space.m))
        // **這顆按鈕只有一個，而且一定會走到系統的權限對話框。**
        //
        // 原本是「允許麥克風」＋「稍後再說」兩顆。那個版本在 App Store 審查
        // 被點名（指南 5.1.1(iv)）：按鈕不可以替使用者預先回答系統的問題，
        // 說明出現之後也不可以給一顆「稍後」把權限對話框跳過。
        //
        // Android 這一側不歸 Apple 管，但同一套流程兩邊要一致 —— 而且那個
        // 意見本身是對的：要不要給，本來就該由系統那個對話框問。
        val needsRequest = !granted && !asked
        Button(
            onClick = {
                Onboarding.markSeen(context)
                if (needsRequest) {
                    // 問完不論給不給都往下走（結果由 micPermission 的回呼
                    // 處理）—— 沒拿到麥克風，App 仍然是一個完整的手寫筆記本。
                    micPermission.launch(Manifest.permission.RECORD_AUDIO)
                } else {
                    onDone()
                }
            },
            modifier = Modifier.fillMaxWidth().widthIn(max = DS.Content.readableMaxWidth)
        ) {
            Text(if (needsRequest) l("onboarding_continue") else l("onboarding_start"))
        }
        Spacer(Modifier.height(DS.Space.l))
    }
    }
}
