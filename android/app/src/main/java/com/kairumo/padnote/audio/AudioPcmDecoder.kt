package com.kairumo.padnote.audio

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * 把音檔解成核心要的 **16 kHz 單聲道 Float32 PCM**。
 *
 * # 為什麼要有這個檔案
 *
 * 核心的 `whisperTranscribePcm` 吃的是 PCM，不是檔案 —— 解碼是平台的事
 * （Android 有 MediaCodec，Apple 有 AVFoundation），而**重採樣與聲道混合
 * 不能亂做**：只是抽樣丟點會產生混疊，聽起來像金屬聲，ASR 的辨識率也會掉。
 *
 * # 為什麼不用 MediaMetadataRetriever
 *
 * 那個只給得出中繼資料（長度、格式），給不出樣本。舊版的轉錄就是只問了
 * 中繼資料，然後**把檔名當成轉錄結果回傳** —— 而畫面顯示「轉錄成功」。
 *
 * # 記憶體
 *
 * 一小時 16 kHz 單聲道 f32 是 230 MB。這個函式會把整段解進記憶體，
 * 所以**只適合使用者手動觸發的單次轉錄**，而且長檔要先擋
 * （見 [MAX_SECONDS]）。串流轉錄是另一件事，要走核心的錄音管線。
 */
object AudioPcmDecoder {

    /** 單次轉錄的長度上限。超過就要求使用者分段 —— 不擋的話會 OOM。 */
    const val MAX_SECONDS = 60 * 30

    private const val TARGET_RATE = 16_000

    /**
     * 解碼並重採樣。失敗回 null（檔案壞了、格式不支援、或太長）。
     *
     * **會阻塞，要在背景執行緒呼叫。**
     */
    fun decodeTo16kMono(file: File): FloatArray? {
        if (!file.isFile || file.length() <= 0) return null
        val extractor = MediaExtractor()
        var codec: MediaCodec? = null
        try {
            extractor.setDataSource(file.absolutePath)
            val track = (0 until extractor.trackCount).firstOrNull { i ->
                extractor.getTrackFormat(i).getString(MediaFormat.KEY_MIME)
                    ?.startsWith("audio/") == true
            } ?: return null

            val format = extractor.getTrackFormat(track)
            val durationUs = runCatching { format.getLong(MediaFormat.KEY_DURATION) }.getOrDefault(0L)
            if (durationUs > MAX_SECONDS * 1_000_000L) return null

            val sourceRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            val channels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            val mime = format.getString(MediaFormat.KEY_MIME) ?: return null

            extractor.selectTrack(track)
            codec = MediaCodec.createDecoderByType(mime)
            codec.configure(format, null, null, 0)
            codec.start()

            val decoded = ArrayList<Short>(1024)
            val info = MediaCodec.BufferInfo()
            var sawInputEnd = false
            var sawOutputEnd = false

            while (!sawOutputEnd) {
                if (!sawInputEnd) {
                    val inIndex = codec.dequeueInputBuffer(10_000)
                    if (inIndex >= 0) {
                        val buffer = codec.getInputBuffer(inIndex) ?: continue
                        val size = extractor.readSampleData(buffer, 0)
                        if (size < 0) {
                            codec.queueInputBuffer(
                                inIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM
                            )
                            sawInputEnd = true
                        } else {
                            codec.queueInputBuffer(inIndex, 0, size, extractor.sampleTime, 0)
                            extractor.advance()
                        }
                    }
                }

                val outIndex = codec.dequeueOutputBuffer(info, 10_000)
                if (outIndex >= 0) {
                    if (info.size > 0) {
                        val out = codec.getOutputBuffer(outIndex)
                        if (out != null) {
                            out.position(info.offset)
                            out.limit(info.offset + info.size)
                            val shorts = out.order(ByteOrder.nativeOrder()).asShortBuffer()
                            while (shorts.hasRemaining()) decoded.add(shorts.get())
                        }
                    }
                    codec.releaseOutputBuffer(outIndex, false)
                    if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                        sawOutputEnd = true
                    }
                }
            }
            if (decoded.isEmpty()) return null

            // 先混成單聲道，再重採樣 —— 順序反過來會在立體聲上重採樣兩次。
            val mono = toMono(decoded, channels)
            return resample(mono, sourceRate, TARGET_RATE)
        } catch (t: Throwable) {
            return null
        } finally {
            runCatching { codec?.stop() }
            runCatching { codec?.release() }
            runCatching { extractor.release() }
        }
    }

    /** 多聲道取平均，不是只取左聲道 —— 只取一邊會丟掉只錄在另一邊的聲音。 */
    private fun toMono(samples: List<Short>, channels: Int): FloatArray {
        if (channels <= 1) {
            return FloatArray(samples.size) { samples[it] / 32768f }
        }
        val frames = samples.size / channels
        return FloatArray(frames) { i ->
            var sum = 0f
            for (c in 0 until channels) sum += samples[i * channels + c] / 32768f
            sum / channels
        }
    }

    /**
     * 線性內插重採樣。
     *
     * 不是最好的重採樣器，但**遠好於抽樣丟點**：後者在 48 kHz → 16 kHz 時
     * 會把 8 kHz 以上的內容折回可聽頻段（混疊），而人聲的齒音就落在那裡。
     */
    private fun resample(input: FloatArray, from: Int, to: Int): FloatArray {
        if (from == to || input.isEmpty()) return input
        val ratio = to.toDouble() / from.toDouble()
        val outLength = (input.size * ratio).toInt().coerceAtLeast(1)
        val out = FloatArray(outLength)
        for (i in 0 until outLength) {
            val src = i / ratio
            val i0 = src.toInt()
            val i1 = (i0 + 1).coerceAtMost(input.size - 1)
            val t = (src - i0).toFloat()
            out[i] = input[i0] * (1 - t) + input[i1] * t
        }
        return out
    }
}
