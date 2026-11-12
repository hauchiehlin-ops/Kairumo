package com.kairumo.padnote

import com.kairumo.padnote.entitlement.Ed25519Verifier
import com.kairumo.padnote.entitlement.EntitlementManager
import com.kairumo.padnote.entitlement.ProFeatureGate
import com.kairumo.padnote.entitlement.isProRequired
import com.kairumo.padnote.ink.InkTool
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.security.KeyPairGenerator
import java.security.Signature
import java.util.Base64

class EntitlementManagerTest {

    @Before
    fun setUp() {
        EntitlementManager.resetStateForTesting(
            playPurchased = false,
            vipUnlocked = false,
            forceFree = true,
            showLockedBrushes = false
        )
    }

    @After
    fun tearDown() {
        EntitlementManager.resetStateForTesting()
    }

    @Test
    fun `free vs pro ink tools match cross-platform specification`() {
        val expectedFree = setOf(
            InkTool.FOUNTAIN_PEN,
            InkTool.BALLPOINT,
            InkTool.HIGHLIGHTER,
            InkTool.PENCIL,
            InkTool.ERASER,
            InkTool.LASSO,
            InkTool.MASKING_TAPE
        )
        for (tool in InkTool.entries) {
            if (tool in expectedFree) {
                assertFalse("${tool.name} 應為免費基礎版工具", tool.isProRequired)
            } else {
                assertTrue("${tool.name} 應為 Pro 專業版進階工具", tool.isProRequired)
            }
        }
        assertEquals(7, InkTool.entries.count { !it.isProRequired })
        assertEquals(11, InkTool.entries.count { it.isProRequired })
    }

    @Test
    fun `two-step nudge shows lightweight banner on first tap and opens paywall on second tap`() {
        assertFalse(EntitlementManager.isProUnlocked)
        assertNull(EntitlementManager.activeNudge)
        assertNull(EntitlementManager.activePaywallFeature)

        // 第一次點擊未解鎖 Pro 功能：僅顯示輕量 Nudge 膠囊，不彈出 Paywall
        val firstAllowed = EntitlementManager.requirePro(ProFeatureGate.STUDIOS, "數學運算") {}
        assertFalse(firstAllowed)
        assertNotNull(EntitlementManager.activeNudge)
        assertEquals("數學運算", EntitlementManager.activeNudge?.itemName)
        assertNull(EntitlementManager.activePaywallFeature)

        // 6 秒內再次點擊同類 Pro 功能：收起輕提示並開啟 Paywall
        val secondAllowed = EntitlementManager.requirePro(ProFeatureGate.STUDIOS, "數學運算") {}
        assertFalse(secondAllowed)
        assertNull(EntitlementManager.activeNudge)
        assertEquals(ProFeatureGate.STUDIOS, EntitlementManager.activePaywallFeature)
    }

    @Test
    fun `pro brushes collapse filter hides locked pro tools by default and expands on toggle`() {
        assertFalse(EntitlementManager.isProUnlocked)
        assertFalse(EntitlementManager.showLockedProBrushes)

        // 免費版預設收合：免費筆刷顯示，未解鎖 Pro 筆刷隱藏（除非剛好是當前選取工具）
        assertTrue(EntitlementManager.shouldDisplayToolInToolbar(InkTool.FOUNTAIN_PEN, InkTool.FOUNTAIN_PEN))
        assertTrue(EntitlementManager.shouldDisplayToolInToolbar(InkTool.MASKING_TAPE, InkTool.FOUNTAIN_PEN))
        assertFalse(EntitlementManager.shouldDisplayToolInToolbar(InkTool.BRUSH, InkTool.FOUNTAIN_PEN))
        assertTrue(EntitlementManager.shouldDisplayToolInToolbar(InkTool.BRUSH, InkTool.BRUSH))

        // 切換展開後：所有 Pro 筆刷皆顯示於工具列以供預覽
        EntitlementManager.toggleLockedProBrushes()
        assertTrue(EntitlementManager.showLockedProBrushes)
        assertTrue(EntitlementManager.shouldDisplayToolInToolbar(InkTool.BRUSH, InkTool.FOUNTAIN_PEN))
        assertTrue(EntitlementManager.shouldDisplayToolInToolbar(InkTool.TRANSLATION_PEN, InkTool.FOUNTAIN_PEN))
    }

    @Test
    fun `ed25519 vip gift token verification accepts valid signature and rejects tampered or expired tokens`() {
        // 使用 JDK Ed25519 產生測試金鑰對，擷取最末 32 bytes 原始公鑰驗證 RFC 8032 純 Kotlin 驗章器
        val kpg = KeyPairGenerator.getInstance("Ed25519")
        val kp = kpg.generateKeyPair()
        val x509Encoded = kp.public.encoded
        val rawPubKey = x509Encoded.copyOfRange(x509Encoded.size - 32, x509Encoded.size)
        val pubKeyB64 = Base64.getEncoder().encodeToString(rawPubKey)

        val payloadJson = """{"sub":"Dr. Lin","tier":"pro_lifetime","iat":1700000000,"exp":1900000000}"""
        val payloadB64 = Base64.getUrlEncoder().withoutPadding()
            .encodeToString(payloadJson.toByteArray(Charsets.UTF_8))

        val signer = Signature.getInstance("Ed25519")
        signer.initSign(kp.private)
        signer.update(payloadB64.toByteArray(Charsets.UTF_8))
        val sigBytes = signer.sign()
        val sigB64 = Base64.getUrlEncoder().withoutPadding().encodeToString(sigBytes)

        val validToken = "$payloadB64.$sigB64"

        // 1. 合法簽章且未過期 -> 驗證通過
        val verified = EntitlementManager.verifyVIPToken(
            rawToken = validToken,
            publicKeyBase64 = pubKeyB64,
            nowEpochSeconds = 1800000000L
        )
        assertNotNull(verified)
        assertEquals("Dr. Lin", verified?.sub)
        assertEquals("pro_lifetime", verified?.tier)

        // 2. 超過有效期限 exp -> 驗證拒絕
        val expired = EntitlementManager.verifyVIPToken(
            rawToken = validToken,
            publicKeyBase64 = pubKeyB64,
            nowEpochSeconds = 1950000000L
        )
        assertNull(expired)

        // 3. 竄改受贈者名稱 -> 驗章失敗
        val tamperedJson = """{"sub":"Hacker","tier":"pro_lifetime","iat":1700000000,"exp":1900000000}"""
        val tamperedPayloadB64 = Base64.getUrlEncoder().withoutPadding()
            .encodeToString(tamperedJson.toByteArray(Charsets.UTF_8))
        val tamperedToken = "$tamperedPayloadB64.$sigB64"
        assertNull(
            EntitlementManager.verifyVIPToken(
                rawToken = tamperedToken,
                publicKeyBase64 = pubKeyB64,
                nowEpochSeconds = 1800000000L
            )
        )

        // 4. 支援從 kairumo://vip?gift=... 深層連結提取 Token
        val extracted = EntitlementManager.extractGiftToken("kairumo://vip?gift=$validToken")
        assertEquals(validToken, extracted)
    }

    @Test
    fun `ed25519 verifier passes official rfc 8032 test vector 1`() {
        val pubHex = "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a"
        val sigHex = "e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e06522490155" +
            "5fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b"
        val pub = pubHex.chunked(2).map { it.toInt(16).toByte() }.toByteArray()
        val sig = sigHex.chunked(2).map { it.toInt(16).toByte() }.toByteArray()
        assertTrue(Ed25519Verifier.verify(pub, ByteArray(0), sig))
    }

    @Test
    fun `license tier state transitions and date formatting`() {
        EntitlementManager.resetStateForTesting(
            playPurchased = false,
            vipUnlocked = false,
            forceFree = true
        )
        // 1. Basic 狀態
        assertEquals(com.kairumo.padnote.entitlement.LicenseTier.Basic, EntitlementManager.licenseTier)

        // 2. Pro 買斷狀態
        EntitlementManager.resetStateForTesting(playPurchased = true)
        assertEquals(com.kairumo.padnote.entitlement.LicenseTier.Pro, EntitlementManager.licenseTier)

        // 3. VIP 狀態
        EntitlementManager.resetStateForTesting(vipUnlocked = true)
        assertEquals(com.kairumo.padnote.entitlement.LicenseTier.Vip, EntitlementManager.licenseTier)

        // 4. 到期日格式化檢驗（2026/12/31）
        val dateStr = EntitlementManager.formatLicenseDate(1798732800L)
        assertTrue(dateStr.contains("2026/12/31") || dateStr.contains("2027/01/01"))
    }
}
