package com.kairumo.padnote.canvas

import androidx.compose.ui.Modifier

/**
 * 編輯模式。**與 Apple 端的 `EditorMode` 同一組語意。**
 *
 * - [DRAW]：主角是筆。畫布上的物件**不攔截觸控** —— 使用者拿筆想在一張圖上
 *   圈重點，筆畫要到得了畫布。代價是這個模式下不能直接拖動物件。
 * - [TYPE]：主角是物件。可以選取、拖曳、縮放、編輯；手指用來捲動與選取。
 *
 * 這個取捨是刻意的，Apple 端已經這樣運作 —— 兩邊不一致的話，同一個人換裝置
 * 就會發現「在 iPad 上圈得到重點，在 Android 上圈不到」。
 */
enum class EditorMode { DRAW, TYPE }

/**
 * 只在 [enabled] 為真時套用手勢修飾子。
 *
 * Compose 沒有 `allowsHitTesting` 這種一翻就關掉整個子樹的開關；要讓一層
 * 不吃觸控，唯一可靠的做法是**根本不掛上去**。包成這個工具是為了讓四個
 * 物件層用同一種寫法 —— 各寫各的 if 遲早會有一層忘記關。
 */
inline fun Modifier.gesturesIf(enabled: Boolean, block: Modifier.() -> Modifier): Modifier =
    if (enabled) this.block() else this
