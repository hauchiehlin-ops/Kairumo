---
license: apache-2.0
language:
- zh
- en
pipeline_tag: text-classification
tags:
- punctuation
- FunASR
- text-processing
library_name: funasr
---

<div align="center">

### ⭐ Powered by [FunASR](https://github.com/modelscope/FunASR) — please give us a GitHub Star!

This model is part of the **FunASR** ecosystem — one industrial-grade open-source toolkit for **ASR · VAD · punctuation · speaker diarization · emotion / event · LLM-ASR**. A Star really helps the project (and keeps you updated):

[**🌟 FunASR**](https://github.com/modelscope/FunASR)  ·  [**🌟 SenseVoice**](https://github.com/FunAudioLLM/SenseVoice)  ·  [**🌟 Fun-ASR**](https://github.com/FunAudioLLM/Fun-ASR)  ·  [**🌟 FunClip**](https://github.com/modelscope/FunClip)

</div>


# CT-Punc

**Punctuation Restoration** — automatically add punctuation to ASR output text.

CT-Punc (Controllable Time-delay Punctuation) restores punctuation marks for unpunctuated text, commonly used as a post-processing step after speech recognition.

## Quick Start

```python
from funasr import AutoModel

# Standalone punctuation restoration
model = AutoModel(model="funasr/ct-punc", hub="hf", device="cuda")
result = model.generate(input="我们今天讨论三个议题首先是产品发布其次是市场策略最后是团队建设")
print(result[0]["text"])
# → 我们今天讨论三个议题，首先是产品发布，其次是市场策略，最后是团队建设。
```

## Use as Part of ASR Pipeline

```python
from funasr import AutoModel

model = AutoModel(
    model="funasr/paraformer-zh",
    hub="hf",
    vad_model="funasr/fsmn-vad",
    punc_model="funasr/ct-punc",
    device="cuda",
)
result = model.generate(input="audio.wav")
# Output text includes punctuation automatically
```

## Features

- Chinese and English punctuation restoration
- Low latency, suitable for streaming pipelines
- Integrates seamlessly with FunASR ASR models

## Links

- **GitHub**: [FunASR](https://github.com/modelscope/FunASR)
- **Docs**: [modelscope.github.io/FunASR](https://modelscope.github.io/FunASR/)
