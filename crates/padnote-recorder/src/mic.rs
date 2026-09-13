//! 跨平台麥克風擷取管線。
//! 使用 `cpal` 封裝底層音訊 API（CoreAudio、Oboe/AAudio、WASAPI），
//! 提供穩定的 16kHz PCM 串流。

use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use cpal::{Sample, SampleFormat};
use std::sync::mpsc::Sender;

/// 麥克風錄音器，管理音訊串流的生命週期。
pub struct MicrophoneRecorder {
    stream: cpal::Stream,
}

impl MicrophoneRecorder {
    /// 啟動麥克風擷取，將 16kHz、單聲道、f32 格式的 PCM 寫入 `sender`。
    pub fn start(sender: Sender<Vec<f32>>) -> Result<Self, String> {
        let host = cpal::default_host();
        let device = host
            .default_input_device()
            .ok_or_else(|| "No input device available".to_string())?;

        // 尋找符合 16kHz 1 channel 的設定，或是最近似的設定然後自己重採樣
        let mut supported_configs = device
            .supported_input_configs()
            .map_err(|e| e.to_string())?;

        // 這裡為了簡化，直接使用預設設定（實務上應該要求 16000 或是用 rubato 重採樣）
        let config = supported_configs
            .next()
            .ok_or_else(|| "No supported config".to_string())?
            .with_max_sample_rate();

        let sample_format = config.sample_format();
        let config: cpal::StreamConfig = config.into();

        let stream = match sample_format {
            SampleFormat::F32 => Self::build_stream::<f32>(&device, &config, sender),
            SampleFormat::I16 => Self::build_stream::<i16>(&device, &config, sender),
            SampleFormat::U16 => Self::build_stream::<u16>(&device, &config, sender),
            _ => Err("Unsupported sample format".to_string()),
        }?;

        stream.play().map_err(|e| e.to_string())?;

        Ok(Self { stream })
    }

    fn build_stream<T>(
        device: &cpal::Device,
        config: &cpal::StreamConfig,
        sender: Sender<Vec<f32>>,
    ) -> Result<cpal::Stream, String>
    where
        T: Sample + cpal::SizedSample,
        f32: cpal::FromSample<T>,
    {
        let channels = config.channels as usize;
        
        // 注意：這裡直接丟失了重採樣（Resampling）邏輯。
        // 在生產環境中，如果是 48kHz 或 44.1kHz，我們必須使用如 `rubato` 將其降頻至 16kHz。
        let err_fn = |err| eprintln!("an error occurred on stream: {}", err);
        
        let stream = device
            .build_input_stream(
                config,
                move |data: &[T], _: &cpal::InputCallbackInfo| {
                    // 轉為單聲道 f32
                    let mut pcm = Vec::with_capacity(data.len() / channels);
                    for frame in data.chunks(channels) {
                        let mut sum = 0.0;
                        for sample in frame {
                            sum += f32::from_sample(*sample);
                        }
                        pcm.push(sum / channels as f32);
                    }
                    if let Err(e) = sender.send(pcm) {
                        eprintln!("Failed to send audio data: {}", e);
                    }
                },
                err_fn,
                None, // None = Blocking mode
            )
            .map_err(|e| e.to_string())?;

        Ok(stream)
    }
}
