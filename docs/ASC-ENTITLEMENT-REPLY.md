# App Review 回覆：`com.apple.security.network.server`

> 2026-09-22。自動分析退件：「包含 `com.apple.security.network.server`
> 但看不到對應功能」。
>
> **結論：這個權限是必要的，不移除。** 功能本來就存在，問題是使用者介面上
> 看不出它在運作 —— 已補上（見 commit）。本檔同時是要貼進 App Store Connect
> 「App Review Information」欄位的內容。

---

## 一、貼進 App Store Connect → App Review Information → Notes

```
Kairumo includes the com.apple.security.network.server entitlement because the
app can act as the host of a local, peer-to-peer collaboration session.

Kairumo has no backend service of any kind. Notes are stored locally and synced
through the user's own cloud drive. For real-time collaboration there is
therefore no server to connect to, so the device that starts a session hosts the
session itself: it opens a WebSocket listener on the local network and relays
presence and edit operations between the participating devices. This is
implemented with Network.framework's NWListener in Sources/LocalRelayServer.swift.

Without com.apple.security.network.server the listener cannot bind under the App
Sandbox, and a Mac user can join a session started by someone else but can never
start one.

How to see it:
1. Open any notebook.
2. In the editor toolbar, click "Collaborate" (the two-person icon).
3. Click "Start Collaboration".
4. The panel then shows "Hosting relay on this device" together with the LAN
   address other devices connect to (for example ws://192.168.1.20:9002). That
   address is the listener created under this entitlement.
5. On a second device on the same network, open the same panel, click "Join Room",
   and paste the invite link (or room code) shown on the first device.


The app uses only the two network entitlements (client and server) plus
user-selected file access, app-scope bookmarks and audio input. No other
entitlements are requested.
```

## 二、回覆給 App Review 的信

見 `ASC-ENTITLEMENT-REPLY-LETTER.txt`。

### ⚠️ 寄出前要選一個：你有沒有要先上傳新 build？

信裡有一段（"A NOTE ON WHY THE AUTOMATED ANALYSIS MAY HAVE MISSED IT"）
寫著「本次回覆隨附的 build 已經把狀態顯示出來」。**那句話只有在你先上傳
新 build 時才是真的。** 對 App Review 講一句當下不成立的話，代價遠大於
省下的那一趟。

**選項 A｜先上傳新 build（建議）**

顯示中繼狀態的修正已經在 main 上。跑 `./scripts/apple-release.sh` 出新
build、等它出現在那個版本裡，再回信。信照原文寄，不用改。
好處是審查員照著步驟點下去**看得到東西**，不必只憑文字相信你。

**選項 B｜就用現在送審的那個 build 回覆**

權限的功能在現在這個 build 裡本來就有，只是看不到。這條路比較快，
但要把那一段換成下面這版（沒有提到新 build）：

```
A NOTE ON WHY THE AUTOMATED ANALYSIS MAY HAVE MISSED IT

In the build currently under review the app starts the listener but does not
display that it is doing so, and a failure to bind is only logged. The
functionality is present and reachable through the steps above, but it is not
visibly labelled in the interface, which is most likely why the automated
analysis did not find matching functionality.

A subsequent build will surface this directly: the collaboration panel will show
the hosting state and the LAN address, and will report a readable reason if the
listener cannot start.
```

選 B 的話，記得那句「A subsequent build will…」是承諾，下一版要真的做到 ——
它已經在 main 上了，所以做得到。

## 三、這次做的程式修正

退件的字面原因是「看不到對應功能」，而查下去發現那句話**有道理**：

1. **正在擔任中繼這件事，畫面上完全沒有顯示。** `isHostingLocalRelay` 與
   `lanRelayAddress` 從 2024 年就設在 `CollaborationManager` 上，但 Apple 端
   從來沒有把它畫出來（Android 端早就有）。使用者因此也不知道要把哪個位址
   給對方 —— 區網上的另一台裝置連 `127.0.0.1` 是連不到的。

2. **監聽失敗是靜默的。** `NWListener` 的失敗是**非同步**送到
   `stateUpdateHandler` 的，而 `start()` 同步就回傳成功。舊版因此樂觀地把
   `isHostingLocalRelay` 設成 `true` 就不管了 —— 監聽其實失敗時，畫面照樣
   說「正在擔任中繼」，而使用者看到的是「連線中斷，正在自動重新連線」
   無限轉圈。**在沙盒下少了這個權限，症狀就正是這個。**

修正：`LocalRelayServer` 回報真正的狀態（`.ready` / `.failed`），
協同面板顯示「正在擔任中繼 + 區網位址」，失敗時顯示可讀的原因，
連上之後自動清掉（埠被其他中繼佔著時照樣連得上，那不算問題）。

並加了一項測試把權限與實作綁在一起：
`MacReleaseConfigTests.testTheServerEntitlementHasCodeBehindIt` ——
宣告了 `network.server` 就必須有東西在 `NWListener`，而且那個狀態要顯示得出來。
拿掉任何一邊都會紅。

## 四、如果你決定改走「移除權限」

這是產品決定，不是技術決定，所以列在這裡讓你選：

移除 `com.apple.security.network.server` 之後，**macOS 版的使用者只能加入
別人開的房間，不能自己開**。iOS／iPadOS 不受影響（iOS 沒有 App Sandbox
的這個鍵）。如果你認為 Mac 上的協同以「加入」為主，這條路可以更快過審。

程式上要做的是：在 Catalyst 上把「發起協同」的入口關掉，並明講原因 ——
**不要留一個按下去會轉圈的按鈕**。需要的話我可以做。
