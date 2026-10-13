package com.kairumo.padnote.platform

import android.app.ActivityManager
import android.app.ApplicationExitInfo
import org.junit.Assert.assertTrue
import org.junit.Test

class ExitReasonLoggerTest {
    @Test
    fun aNativeCrashIsNamedAsSuch() {
        val line = ExitReasonLogger.format(
            reason = ApplicationExitInfo.REASON_CRASH_NATIVE, status = 11, timestamp = 1_791_900_000_000L,
            description = "signal 11 (SIGSEGV)", importance = ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND,
            pssKb = 512 * 1024L
        )
        assertTrue(line, line.contains("原生層崩潰"))
        assertTrue(line, line.contains("SIGSEGV"))
        assertTrue(line, line.contains("512 MB"))
        assertTrue(line, line.contains("前景"))
    }

    @Test
    fun everyReasonHasAReadableName() {
        for (reason in 0..15) {
            assertTrue(ExitReasonLogger.reasonName(reason).isNotBlank())
        }
    }
}
