package com.kairumo.padnote.screens

import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import uniffi.padnote_core.FfiImportedModel3d
import uniffi.padnote_core.FfiModel3dException

/**
 * 匯入的 3D 模型在**這一側**真的畫得出東西嗎？
 *
 * # 為什麼要在 Android 上跑，而不是只靠核心的 Rust 測試
 *
 * 核心那邊已經有同樣的測試，但它證明的是「Rust 算得出多邊形」。這一條
 * 證明的是**那些多邊形真的穿過 FFI 到得了 Kotlin** —— 而那正是先前壞掉的
 * 地方：檔案存得下、同步得動，Kotlin 這一側卻什麼都拿不到，於是畫面上
 * 是一張寫著檔名的卡片。
 *
 * UniFFI 的綁定與原生函式庫是兩份東西，Kotlin 編得過不代表跑得動
 * （這個專案已經被這件事咬過好幾次）。這條測試會紅在正確的地方。
 */
@RunWith(AndroidJUnit4::class)
class ImportedModelRenderTest {

    /** 一個四面體。四個面，每一面朝不同方向。 */
    private val tetraObj = """
        v 0 0 0
        v 1 0 0
        v 0 1 0
        v 0 0 1
        f 1 2 3
        f 1 2 4
        f 2 3 4
        f 1 3 4
    """.trimIndent()

    @Test
    fun anImportedObjProducesFacesToDraw() {
        val model = FfiImportedModel3d.parse(tetraObj.toByteArray(), "obj")
        assertEquals(4u, model.faceCount())

        val faces = model.faces(0.3f, 0.4f, 0.0f, 1.0f, 200f, 200f)
        assertTrue("匯入的模型一個面都沒畫出來", faces.isNotEmpty())

        for (f in faces) {
            assertTrue("面少於三個點", f.points.size >= 3)
            for (p in f.points) {
                assertTrue("座標是 NaN：${p.x}, ${p.y}", p.x.isFinite() && p.y.isFinite())
            }
            assertTrue("明暗超出範圍：${f.shade}", f.shade in 0f..1f)
        }
    }

    @Test
    fun everyFaceSurvivesBecauseWindingIsNotTrusted() {
        // 匯入的模型不保證是凸的，纏繞方向也不保證一致（STL 常常整批
        // 反過來）。剔除背面會在模型上挖出洞，而使用者只會覺得
        // 「匯進來的東西破破爛爛的」。
        val model = FfiImportedModel3d.parse(tetraObj.toByteArray(), "obj")
        assertEquals(4, model.faces(0f, 0f, 0f, 1f, 200f, 200f).size)
    }

    @Test
    fun aBinaryStlAlsoWorks() {
        // 二進位 STL 走的是完全不同的解析路徑（位元組而不是文字），
        // 而它是 3D 列印圈子最常見的格式。
        val stl = binaryStl()
        val model = FfiImportedModel3d.parse(stl, "stl")
        assertEquals(1u, model.faceCount())
        assertTrue(model.faces(0f, 0f, 0f, 1f, 120f, 120f).isNotEmpty())
    }

    @Test
    fun anUnsupportedFormatComesBackWithAReasonKey() {
        // 使用者要看得到理由，而且兩端要是同一句話 —— 所以錯誤帶的是
        // 語系鍵，不是一句寫死的英文。
        try {
            FfiImportedModel3d.parse("nope".toByteArray(), "glb")
            throw AssertionError("glb 竟然讀成功了 —— 那會給使用者一個空白方塊")
        } catch (e: FfiModel3dException.Rejected) {
            assertEquals("model_unsupported_format", e.reasonKey)
        }
    }

    private fun binaryStl(): ByteArray {
        val header = 80
        val out = java.nio.ByteBuffer
            .allocate(header + 4 + 50)
            .order(java.nio.ByteOrder.LITTLE_ENDIAN)
        out.position(header)
        out.putInt(1)
        repeat(3) { out.putFloat(0f) } // 法線，故意留 0
        val tri = floatArrayOf(0f, 0f, 0f, 1f, 0f, 0f, 0f, 1f, 0f)
        for (v in tri) out.putFloat(v)
        out.putShort(0)
        return out.array()
    }
}
