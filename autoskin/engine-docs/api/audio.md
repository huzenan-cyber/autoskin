# Audio Module

## 概览

音频模块由以下对象组成：

- `Audio`：输出设备、混音状态和全局音量。
- `Sound`：音频资源及其格式、采样率和循环范围。
- `SoundSource`：非定位音频的播放实例。
- `SoundSource3D`：带距离和方向衰减的播放实例。
- `SoundListener`：`SoundSource3D` 使用的监听器标记组件。

详细 API 见 `.emmylua/Audio.d.lua`、`.emmylua/Sound.d.lua`、`.emmylua/SoundSource.d.lua` 等定义文件。

## 音量模型

播放实例的有效音量由多个线性乘数共同决定：

```text
effective gain = master gain * source gain * source attenuation
```

各参数的语义如下：

- 对任一音量乘数，`0` 表示静音，`1` 表示该乘数不产生额外衰减。
- `source.gain` 是播放实例当前音量。带 `gain` 参数的 `Play` 重载会把它设置为传入值，因此 `gain = 1` 表示完整 source 音量，而不是保留之前的音量设置。
- `source.attenuation` 是额外的线性衰减乘数。`SoundSource` 已经是非定位音频，不需要通过设置 `attenuation` 来关闭 3D 行为；普通 `SoundSource` 应保持默认值 `1.0`。
- `SOUND_MASTER`、`SOUND_EFFECT`、`SOUND_AMBIENT`、`SOUND_VOICE` 和 `SOUND_MUSIC` 是 master gain 分组常量。

`SoundSource3D` 的 `attenuation` 由距离和方向计算，不应作为普通音量开关使用。

## 音频设备

```lua
-- buffer length in milliseconds, requested sample rate, stereo, interpolation
local ok = audio:SetMode(50, 44100, true, true)
```

- `SetMode` 会重建输出设备，并在成功后启动播放。缓冲区长度单位是毫秒，采样率单位是 Hz。
- `audio.mixRate` 是后端实际采用的采样率，可能与请求值不同；它不等于素材的采样率。
- `audio.initialized` 表示输出设备已经初始化；`audio.playing` 表示引擎正在向设备混音。设备已初始化不代表宿主系统或浏览器一定允许出声。
- `audio:Stop()` 停止混音但保留设备；`audio:Play()` 重新开始混音，重复调用是安全的。
- `audio:SetMasterGain(type, gain)` 的 `gain` 会限制在 `0..1`。
- `audio:PauseSoundType(type)` 按 sound type 暂停；`audio:ResumeSoundType` 和 `audio:ResumeAll` 只解除这类暂停。
- `audio.listener` 仅供 `SoundSource3D` 计算距离和方向衰减，普通 `SoundSource` 不使用它。

`audio:GetMasterGain(type)` 查询指定 type 的显式配置；未知 type 返回 `1.0`。source 混音时，sound type gain 还会与 `SOUND_MASTER` 相乘。

## Sound 资源

- `sound:GetFrequency()` 返回素材默认采样率，单位是 Hz，例如 `44100` 或 `48000`。
- `sound.length` 单位是秒；`sound.dataSize` 单位是字节；`sound.sampleSize` 是一个交错采样帧的字节数，即每个声道的采样字节数（8-bit 为 1、16-bit 为 2）乘以声道数。
- `Sound:LoadRaw` 不会从原始字节中推断格式，会保留当前 `Sound` 对象的采样率、位深和声道设置；复用对象加载 raw 数据时应显式调用 `SetFormat`。
- WAV 会在加载时读取格式；OGG/MP3 保留压缩数据并在播放过程中解码。
- `sound.looped = true` 会把整个声音设为循环。
- 对原始未压缩数据，可以使用 `SetLoop(repeatOffset, endOffset)` 指定循环范围。偏移量单位是字节，并会按采样边界对齐。

## SoundSource 播放

`SoundSource` 是非定位音频的播放实例。它不需要 `SoundListener`。

```lua
local sound = cache:GetResource("Sound", "Sounds/Hit.wav")
local source = node:CreateComponent("SoundSource")

source:Play(sound, 0, 0.8)
```

`SoundSource:Play(sound, frequency, gain)` 中：

- `frequency` 是绝对播放频率，单位是 Hz，不是 pitch 倍率。
- `frequency = 0` 表示使用 `sound:GetFrequency()`。
- `gain` 会直接设置 source 的当前音量，`0` 静音，`1` 为完整 source 音量；它会覆盖该 source 之前的 `gain` 设置。

`source.frequency` 与 `source:SetFrequency(...)` 等价；`sound.frequency` 和 `sound.intFrequency` 是素材采样率，只读。

`source.panning` 的范围是 `-1..1`：`-1` 全左、`0` 居中、`1` 全右。它仅对单声道素材混入立体声输出生效；立体声素材或单声道输出会忽略该值。`source.timePosition` 的单位是秒，只有混音器（或无输出模式下的时序模拟）处理该 source 时才会推进。

### 改变 pitch

pitch 必须先乘以素材采样率，再传给 `Play`：

```lua
local pitch = 0.94 + math.random() * 0.14
local playbackFrequency = sound:GetFrequency() * pitch

source:Play(sound, playbackFrequency, 0.8)
```

不要直接把倍率作为频率传入：

```lua
-- 错误：0.95 会被解释为 0.95 Hz，而不是 0.95x pitch。
source:Play(sound, 0.95, 0.8)
```

混音器按以下比例推进素材播放位置：

```text
playback step = source frequency / audio mix rate
```

例如，48,000 Hz 的素材若被设置为 `0.95 Hz`，在默认 44,100 Hz 的设备 mix rate 下，每个输出采样的播放步进约为 `0.95 / 44100`；相对于素材原速，一秒音频约需要 14 小时。

### 复用 SoundSource

`source:Play(sound)` 只会在当前 source 频率为 `0` 时读取素材采样率。如果该实例上一次播放设置过非零频率，无参重载会继续沿用旧值。

```lua
-- 恢复为当前素材采样率。
source:Play(sound, 0, gain)

-- 使用相对于当前素材的 pitch。
source:Play(sound, sound:GetFrequency() * pitch, gain)
```

`source:SetFrequency(0)` 只修改播放实例的频率；素材频率会在下一次 `Play(sound)` 时回填。

### 停止和定位

- `source:Stop()` 使用短暂的 de-click 淡出。
- `source:StopImmediate()` 立即停止，不执行淡出。
- `source.declickEnabled` 控制是否启用短暂淡出。
- `source:Seek(seconds)` 的参数单位是秒。位置会按完整声音长度取模，与是否循环无关；未压缩声音随后会被限制到当前循环终点，而不是按 `SetLoop` 范围回绕。压缩声音是否支持定位取决于对应解码器。

## SoundSource3D

`SoundSource3D` 使用 source 节点和 listener 节点的空间关系计算距离衰减、方向衰减和 panning。

- `nearDistance` 和 `farDistance` 使用世界单位；超出 `farDistance` 后声音完全衰减。
- `innerAngle` 和 `outerAngle` 使用度数；默认 `360` 表示全向。
- `rolloffFactor` 是正的距离衰减指数。
- `SoundSource3D` 每次更新会自动重新计算衰减，通常不需要手动调用 `CalculateAttenuation()`。
- listener 必须是无场景节点，或与 source 属于同一个 Scene；否则 source 会被完全衰减。

```lua
local listenerNode = scene:CreateChild("Listener")
audio.listener = listenerNode:CreateComponent("SoundListener")

local source = scene:CreateChild("Emitter"):CreateComponent("SoundSource3D")
source:SetDistanceAttenuation(0, 20, 2)
source:Play(sound, 0, 1)
```
