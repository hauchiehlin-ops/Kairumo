package com.kairumo.padnote.conformance

import androidx.test.platform.app.InstrumentationRegistry
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Test
import uniffi.padnote_core.ToolKind
import uniffi.padnote_core.inkToolIsPressureSensitive
import uniffi.padnote_core.inkWidthScale
import uniffi.padnote_core.layoutMetrics
import uniffi.padnote_core.pageGuides
import uniffi.padnote_core.palmRetractMsClamped
import uniffi.padnote_core.palmThresholdLimits
import uniffi.padnote_core.standardPageSize
import uniffi.padnote_core.symbolCategories
import uniffi.padnote_core.symbolPalette

/**
 * 一致性向量（閘門 1）。
 *
 * # 這支測試存在的理由
 *
 * 在此之前，兩端有大量成對的測試，測的是同一件事，但**期望值各寫一份**。
 * 查證時抓到的例子：這邊檢查「區塊不可以掉到紙外面」，Apple 沒有這一條；
 * 反過來 Apple 檢查「頁數要放得下所有區塊」，這邊用另一種寫法檢查。
 * 兩邊測的是同一件事的不同子集，**而沒有人知道哪一邊漏了什麼**。
 *
 * 向量由核心產生（`crates/padnote-core/tests/conformance_vectors.rs`），
 * 兩端讀同一份檔案。期望值只有一處，漏不掉也漂不走。
 *
 * # 失敗了怎麼辦
 *
 * 先確認核心的改動是不是故意的。是的話重新產生向量：
 * `UPDATE_CONFORMANCE=1 cargo test -p padnote-core --test conformance_vectors`
 * —— 然後**兩個平台的行為都會跟著改**，那正是要被看見的那一刻。
 */
class ConformanceVectorTest {

    private fun vector(name: String): JSONObject {
        val ctx = InstrumentationRegistry.getInstrumentation().context
        return JSONObject(ctx.assets.open("conformance/$name").bufferedReader().readText())
    }

    @Test
    fun layoutMetricsMatchTheVector() {
        val cases = vector("layout.json").getJSONArray("cases")
        for (i in 0 until cases.length()) {
            val c = cases.getJSONObject(i)
            val w = c.getDouble("width").toFloat()
            val m = layoutMetrics(w)
            assertEquals("寬度 $w 的間距", c.getDouble("gutter").toFloat(), m.gutter, 0.001f)
            assertEquals(
                "寬度 $w 的內容最大寬度",
                c.getDouble("content_max_width").toFloat(), m.contentMaxWidth, 0.001f
            )
            assertEquals(
                "寬度 $w 的可讀最大寬度",
                c.getDouble("readable_max_width").toFloat(), m.readableMaxWidth, 0.001f
            )
            assertEquals(
                "寬度 $w 的側欄寬度",
                c.getDouble("sidebar_width").toFloat(), m.sidebarWidth, 0.001f
            )
            assertEquals(
                "寬度 $w 的側欄是否並排",
                c.getBoolean("sidebar_is_inline"), m.sidebarIsInline
            )
            assertEquals(
                "寬度 $w 的卡片欄數",
                c.getInt("note_columns"), m.noteColumns.toInt()
            )
            assertEquals(
                "寬度 $w 的尺寸級別",
                c.getString("size_class"), m.sizeClass.name.pascal()
            )
        }
    }

    @Test
    fun inkPressureCurveMatchesTheVector() {
        val cases = vector("ink-curve.json").getJSONArray("cases")
        for (i in 0 until cases.length()) {
            val c = cases.getJSONObject(i)
            val tool = ToolKind.valueOf(c.getString("tool").screamingSnake())
            assertEquals(
                "${c.getString("tool")} 是否吃壓感",
                c.getBoolean("pressure_sensitive"), inkToolIsPressureSensitive(tool)
            )
            val pressures = c.getJSONArray("pressures")
            val scales = c.getJSONArray("width_scales")
            for (k in 0 until pressures.length()) {
                val p = pressures.getDouble(k).toFloat()
                assertEquals(
                    "${c.getString("tool")} 在壓感 $p 的線寬倍率",
                    scales.getDouble(k).toFloat(), inkWidthScale(tool, p), 0.0001f
                )
            }
        }
    }

    @Test
    fun palmThresholdsMatchTheVector() {
        val v = vector("palm.json")
        val l = palmThresholdLimits()
        assertEquals(v.getDouble("default_radius_dp").toFloat(), l.defaultRadiusDp, 0.001f)
        assertEquals(v.getDouble("finger_mode_radius_dp").toFloat(), l.fingerModeRadiusDp, 0.001f)
        assertEquals(v.getDouble("min_radius_dp").toFloat(), l.minRadiusDp, 0.001f)
        assertEquals(v.getDouble("max_radius_dp").toFloat(), l.maxRadiusDp, 0.001f)
        assertEquals(v.getInt("default_retract_ms"), l.defaultRetractMs.toInt())
        assertEquals(v.getInt("min_retract_ms"), l.minRetractMs.toInt())
        assertEquals(v.getInt("max_retract_ms"), l.maxRetractMs.toInt())

        val clamped = v.getJSONArray("clamped")
        for (i in 0 until clamped.length()) {
            val c = clamped.getJSONObject(i)
            assertEquals(
                "夾制 ${c.getInt("in")}",
                c.getInt("out"), palmRetractMsClamped(c.getInt("in").toUInt()).toInt()
            )
        }
    }

    @Test
    fun symbolPalettesMatchTheVector() {
        val cases = vector("symbols.json").getJSONArray("cases")
        val categories = symbolCategories()
        assertEquals("符號分類數", cases.length(), categories.size)
        for (i in 0 until cases.length()) {
            val c = cases.getJSONObject(i)
            assertEquals(
                "第 $i 個分類",
                c.getString("category"), categories[i].name.pascal()
            )
            val expected = c.getJSONArray("symbols")
            val got = symbolPalette(categories[i])
            assertEquals("${c.getString("category")} 的符號數", expected.length(), got.size)
            for (k in 0 until expected.length()) {
                assertEquals(expected.getString(k), got[k])
            }
        }
    }

    @Test
    fun pageGuidesMatchTheVector() {
        val cases = vector("page-guides.json").getJSONArray("cases")
        for (i in 0 until cases.length()) {
            val c = cases.getJSONObject(i)
            val id = c.getString("paper_id")
            val guides = pageGuides(id, 800f, 1132f)
            assertEquals("$id 的輔助線數量", c.getInt("count"), guides.size)
            val head = c.getJSONArray("guides")
            for (k in 0 until head.length()) {
                val g = head.getJSONObject(k)
                assertEquals("$id 第 $k 條的種類", g.getString("kind"), guides[k].kind.name.pascal())
                assertEquals("$id 第 $k 條的 x", g.getDouble("x").toFloat(), guides[k].x, 0.001f)
                assertEquals("$id 第 $k 條的 y", g.getDouble("y").toFloat(), guides[k].y, 0.001f)
            }
        }
    }

    @Test
    fun pageGeometryMatchesTheVector() {
        val v = vector("page-geometry.json")
        val size = standardPageSize()
        assertEquals(v.getDouble("width").toFloat(), size[0], 0.001f)
        assertEquals(v.getDouble("height").toFloat(), size[1], 0.001f)
    }
}

/**
 * UniFFI 產生的 Kotlin enum 是 `SCREAMING_SNAKE`，而向量記的是 Rust 那邊
 * `{:?}` 印出來的 `PascalCase`。在這裡換算一次，比在向量裡多存一種寫法好 ——
 * 多存一種就是多一份會漂走的表示。
 */
private fun String.pascal(): String =
    split('_').joinToString("") { it.lowercase().replaceFirstChar(Char::uppercase) }

private fun String.screamingSnake(): String =
    replace(Regex("([a-z0-9])([A-Z])"), "$1_$2").uppercase()
