import AVFoundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// 首次啟動引導與權限說明（工作項 S-66）。
///
/// # 為什麼不是「安裝時就要到所有權限」
///
/// 這件事在 iOS 上做不到，也不該做：
///
/// - 安裝時不會有任何對話框。權限一律在 App **實際用到那個 API** 時才問。
/// - 系統的權限對話框**一個 App 一輩子只跳一次**。使用者按了不允許之後，
///   再呼叫同一個 API 不會再跳 —— 只會直接回被拒絕。
///
/// 所以這裡做的是**在第一次打開時把話講清楚**：要哪一個權限、為什麼要、
/// 不給會少什麼，並且當場給那顆按鈕。按下去才是系統對話框。已經被拒絕過
/// 的話，改成把人送進設定頁 —— 那是那時候唯一還走得通的路。
///
/// Android 端是同一套流程（見 `ui/Onboarding.kt`）。
struct OnboardingView: View {

    /// 看過了沒。存 `UserDefaults` —— 它跟著 App 的備份走，
    /// 使用者換手機還原之後不會再被問一次。
    static let seenKey = "kairumo.onboarding.seen.v1"

    static var hasSeen: Bool {
        if let forced = Self.uiTestHasSeen { return forced }
        return UserDefaults.standard.bool(forKey: Self.seenKey)
    }

    /// UI 測試指定的起始狀態。
    ///
    /// # 為什麼需要它
    ///
    /// 導覽看過沒是存在 `UserDefaults` 的，所以測試的起始畫面取決於這台
    /// 模擬器之前被怎麼玩過 —— 同一份程式碼，有時候從首頁開始、有時候卡在
    /// 導覽。畫面稽核第一次跑就踩到：規格要求的 27 個首頁控制項全部「找不到」，
    /// 而真正的原因是**根本沒到首頁**。
    ///
    /// `KAIRUMO_UITEST=1` 一律當成看過了。要測導覽本身就再給
    /// `KAIRUMO_UITEST_SHOW_ONBOARDING=1`。
    ///
    /// 只讀不寫 —— 不碰 `UserDefaults`，不會污染使用者的狀態。
    static var uiTestHasSeen: Bool? {
        let env = ProcessInfo.processInfo.environment
        guard env["KAIRUMO_UITEST"] == "1" else { return nil }
        return env["KAIRUMO_UITEST_SHOW_ONBOARDING"] == "1" ? false : true
    }

    let onDone: () -> Void

    @ObservedObject private var localizationManager = LocalizationManager.shared
    @State private var granted: Bool = OnboardingView.microphoneGranted()
    /// 問過一次而且沒拿到 —— 再問系統也不會有反應，要改走設定頁。
    @State private var asked: Bool = false

    static func microphoneGranted() -> Bool {
        #if os(iOS) || targetEnvironment(macCatalyst)
        if #available(iOS 17.0, *) {
            return AVAudioApplication.shared.recordPermission == .granted
        }
        return AVAudioSession.sharedInstance().recordPermission == .granted
        #else
        return true
        #endif
    }

    private func l(_ key: String) -> String { localizationManager.localized(key) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.m) {
                Text(l("onboarding_welcome_title"))
                    .font(.largeTitle.weight(.semibold))
                Text(l("onboarding_welcome_body"))
                    .foregroundStyle(.secondary)

                Divider().padding(.vertical, DS.Space.xs)

                Text(l("onboarding_privacy_title")).font(.headline)
                Text(l("onboarding_privacy_body")).foregroundStyle(.secondary)

                Divider().padding(.vertical, DS.Space.xs)

                Text(l("onboarding_permission_title")).font(.headline)
                Text(l("onboarding_permission_body")).foregroundStyle(.secondary)

                if granted {
                    Label(l("onboarding_microphone_granted"), systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                } else if asked {
                    // 問過而且沒拿到：系統對話框不會再跳，設定頁是唯一還
                    // 走得通的路。
                    Button(l("permission_open_settings"), action: openSettings)
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("onboarding.open_settings")
                }

                Spacer(minLength: DS.Space.l)

                // **這顆按鈕只有一個，而且一定會走到系統的權限對話框。**
                //
                // 原本這裡是「允許麥克風」＋「稍後再說」兩顆。App Store 審查
                // 指南 5.1.1(iv) 兩件事都點名了：
                //
                //   1. 按鈕不可以寫「允許麥克風」—— 那是在替使用者預先回答
                //      系統的問題。要寫「繼續」這種中性的字。
                //   2. 說明出現之後**一定要走到權限對話框**，不可以給一顆
                //      「稍後」把它跳過。
                //
                // 所以說明看完就是繼續，而「要不要給」由系統那個對話框問 ——
                // 那本來就是使用者做決定的地方，我們不該在前面先攔一次。
                Button(action: continueFromIntro) {
                    Text(needsRequest ? l("onboarding_continue") : l("onboarding_start"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("onboarding.continue")
            }
            .frame(maxWidth: DS.Content.readableMaxWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(DS.Space.l)
        }
    }

    /// 還沒問過，所以按下去會跳系統對話框。
    private var needsRequest: Bool { !granted && !asked }

    /// 說明看完之後唯一的動作。
    ///
    /// 還沒問過就去問（問完就結束導覽，不論使用者給不給）；問過了就直接
    /// 結束。**不會有「跳過權限」這條路** —— 那正是審查指南 5.1.1(iv)
    /// 不允許的。
    private func continueFromIntro() {
        guard needsRequest else {
            finish()
            return
        }
        requestMicrophone(then: finish)
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: Self.seenKey)
        onDone()
    }

    /// 問麥克風權限，問完（不論結果）再做 `then`。
    ///
    /// `then` 一定會被呼叫 —— 使用者按「不允許」也一樣往下走。App 沒拿到
    /// 麥克風仍然是一個完整的手寫筆記本，把人卡在導覽裡沒有道理。
    private func requestMicrophone(then: (() -> Void)? = nil) {
        #if os(iOS) || targetEnvironment(macCatalyst)
        Task {
            let result: Bool
            if #available(iOS 17.0, *) {
                result = await AVAudioApplication.requestRecordPermission()
            } else {
                result = await withCheckedContinuation { continuation in
                    AVAudioSession.sharedInstance().requestRecordPermission { granted in
                        continuation.resume(returning: granted)
                    }
                }
            }
            await MainActor.run {
                granted = result
                asked = true
                then?()
            }
        }
        #else
        then?()
        #endif
    }

    private func openSettings() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
        #endif
    }
}
