# ADR-0012：Windows 版的低延遲墨跡（暫不實作）

- 狀態：**已接受**（2026-09-15）
- 決策：S-35 的處置
- 相關：`docs/TODO.md` §待實作、ADR-0002（筆畫不進 CRDT）、`apple/InkSpike/`

## 背景

`S-35「Windows 低延遲墨跡」` 一直掛在待辦清單上，但它**不是一個待辦**：
目前沒有 Windows 版，這一條在有 Windows 版之前根本不成立。

留在待辦清單裡有實際壞處。清單是用來決定「下一件做什麼」的，
放一個永遠不會被挑到的項目，只會讓每次回顧都要重新解釋一次為什麼跳過它。
而它裡面真正有價值的是一個**技術結論**，那種東西屬於 ADR，不屬於待辦清單。

## 決策

**把 S-35 從待辦清單移到這裡，保留結論，不排期。**

結論是：**Compose Multiplatform Desktop 達不到 9ms 的墨跡延遲預算。**

理由：
- Compose MP Desktop 走 Skia + JVM。從觸控事件進到 JVM、經過 Compose 的
  事件分派、再到 Skia 算繪、最後等合成器換頁，這條路上的每一段都不保證
  在一個更新週期內完成。
- 9ms 預算的前提是**前緩衝渲染**（直接畫進正在掃描的那個緩衝區）。
  Android 靠 `androidx.graphics.lowlatency`、Apple 靠 PencilKit 自己的路徑；
  JVM 上沒有對應品。
- Windows 上做得到的路徑是原生的 **Windows Ink（`InkPresenter`）** 或
  **DirectComposition**，兩者都要原生程式碼，不是換一個 Compose 後端就有。

換句話說，Windows 版的墨跡延遲不是「調一調參數」的問題，
而是「要不要為 Windows 再寫一條原生渲染路徑」的問題。

## 這個決策**不**否定什麼

- 不否定做 Windows 版。核心（Rust）本來就跨平台，`.padnote` 格式、同步、
  匯出、辨識全部可以直接用。做一個**沒有低延遲手寫**的 Windows 版
  （看、找、匯出、打字、同步）在技術上沒有障礙。
- 不鎖定 Compose MP。真的要做 Windows 手寫時，重新評估當時的
  Compose MP / 原生 WinUI / 自繪 DirectComposition 三條路。

## 重新評估的時機

出現下列任一情況時，把這份 ADR 拿出來重看：

1. 產品決定要出 Windows 版，且**手寫是必要功能**（不只是檢視與同步）。
2. Compose MP Desktop 提供了前緩衝或等效的低延遲渲染路徑。
3. S1 實機量測（`TODO.md` H1）的結論改變了 9ms 這個預算本身。

## 後果

- `TODO.md` 少一個永遠不會被挑到的項目。
- 之後有人問「為什麼不用 Compose MP 做 Windows 手寫」，答案在這裡，
  不必每次重新量一遍。
- 若日後要做 Windows 手寫，這份 ADR 是起點而不是結論 ——
  它記的是 2026 年的技術現況，不是永久事實。
