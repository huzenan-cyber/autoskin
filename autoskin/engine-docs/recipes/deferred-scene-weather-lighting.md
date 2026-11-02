# 动态环境场景指南：昼夜、天气、打光与体积光（延迟渲染）

面向用 Lua 搭建高画质 3D 场景：延迟渲染 + 昼夜循环 + 晴雨天气 + 体积光 + 大面积水面。本文只讲通用做法和参考数值，具体实现可对照完整示例 [examples/30-pelican-bike](../../examples/30-pelican-bike)。

相关专题：[延迟渲染](deferred-rendering.md) · [天空与环境光](sky-and-environment-lighting.md) · [灯光与阴影](lights-and-shadows.md) · [体积雾与体积光](volumetric-fog.md) · [后处理](post-processing.md)

> 文中数值都是**参考起点**（ACES 色调映射、固定曝光下调出），按自己的场景尺度和美术风格调整。

---

## 1. 总体架构：环境模块是唯一的真源

按职责拆模块，每帧固定顺序更新：

| 模块 | 职责 |
|---|---|
| 环境（Atmosphere） | 时间、天气状态机；Zone、主光、天空、雾、降水、闪电 |
| 地表 / 水面 | 大面积地表，读取环境状态 |
| 场景 | 静态物体与人造光源的句柄 |
| 角色 | 角色与动画 |
| main | 输入、相机，把环境状态分发给各模块 |

- 环境模块每帧算出**一份状态表**：主光方向与辐亮度、昼夜系数、天气强度、人造光开关强度。
- 其他模块只读这份状态，不各自重算太阳位置或天气。天空、雾、水面、灯光因此永远同步，不会出现"天黑了水面还按白天打光"。
- 每帧顺序：输入 → 环境 → 角色 → 场景灯光 → 地表/水面（需要环境状态和相机位置）→ 相机 → HUD。

---

## 2. 延迟渲染与后处理

### 2.1 开启

- 在 `.project/engine.json` 中将 `rendering.pipeline` 设为 `deferred`，开启延迟管线（GBuffer、HiZ、运动矢量、GTAO、SSGI、SSR、TAA、体积雾）。完整配置示例及构建要求见 [deferred-rendering.md](deferred-rendering.md#11-开启方式)。只在 Lua 里 `viewport:SetRenderPath(...)` 不能代替管线配置。

### 2.2 开关大多在 Zone 上

```lua
zone:SetSSREnabled(true)            -- 屏幕空间反射：湿地面、水面倒影的关键
zone:SetSSGIEnabled(true)           -- 默认关
zone:SetSSGIQuality(2)
zone:SetSSAORadius(0.8)             -- GTAO，半径单位是米
zone:SetSSAOIntensity(1.6)
zone:SetTonemapMode(TONEMAP_MODE_ACES)
zone:SetBloomMode(BLOOM_MODE_UE)
zone:SetBloomUEIntensity(0.55)
zone:SetBloomUEThreshold(1.2)
zone:SetMotionBlurEnabled(true)     -- 默认关，按风格决定
zone:SetMotionBlurAmount(0.35)
zone.volumetricFogEnabled = true
zone.autoExposureForceTarget = true -- 固定曝光：亮度由脚本控制，昼夜切换时画面不会"呼吸"
```

```lua
renderer:SetHDRRendering(true)
renderer:SetShadowQuality(SHADOWQUALITY_PCF_24BIT)
renderer:SetShadowMapSize(4096)
renderer:SetVolumetricFogFroxelEnabled(true)                  -- 需要 compute
renderer:SetVolumetricFogQuality(VOLUMETRIC_FOG_QUALITY_ULTRA)
```

### 2.3 Zone 基线：预设打底，属性调参

1. 加载一个 LightGroup 预设（如 `LightGroup/Daytime.xml`），取出其中的 Zone 作为后处理和曝光的默认值。
2. 脚本自己管理主光时，删掉预设自带的方向光。
3. 在 Zone 所在节点上加 `SkyLightCapture`，环境光由天空实时捕获（见 3.5）。
4. 雾、体积雾、曝光都用 Zone 属性设置，每帧直接改即可。

```lua
local lg = scene:CreateChild("LightGroup")
lg:LoadXML(cache:GetResource("XMLFile", "LightGroup/Daytime.xml"):GetRoot())
local presetSun = lg:GetChild("Directional Light", true)
if presetSun then presetSun:Remove() end
local zone = lg:GetComponent("Zone")

zone.depthFogStart, zone.depthFogEnd = 250, 1400
zone.volumetricFogDensity = 0.004
zone.volumetricFogHeightFalloff = 0.025

lg:CreateComponent("SkyLightCapture")
zone.envTextureDiffIntensity = 1.0   -- 捕获结果是天空的真实亮度
zone.envTextureSpecIntensity = 1.0
```

---

## 3. 昼夜系统

### 3.1 时间与太阳方向

- 状态：`tod`（0–24 小时）、`dayLength`（现实多少秒一天）、`timeRunning`。
- 太阳走一个倾斜的圆轨道即可，不必做天文计算：

```lua
local a = (tod - 6) / 12 * math.pi        -- 6 点日出、12 点最高、18 点日落
local tilt = math.rad(32)                 -- 轨道倾角，决定正午最高仰角
local sun = Vector3(math.cos(a), math.sin(a) * math.cos(tilt), -math.sin(a) * math.sin(tilt)):Normalized()
local moon = (sun * -1 + Vector3(0.25, 0.15, 0.3)):Normalized()   -- 与太阳错开，避免重合
sunNode.direction = sun * -1              -- 灯光方向与"指向太阳"相反
```

### 3.2 从太阳高度 `h = sun.y` 派生所有系数

| 系数 | 公式 | 用途 |
|---|---|---|
| `dayMix` | `smoothstep(-0.06, 0.30, h)` | 白天程度（天空、主光、云） |
| `golden` | `exp(-((h-0.04)/0.13)^2)` | 日出日落的暖色峰值，也可驱动晨昏雾 |
| `nightMix` | `1 - smoothstep(-0.20, -0.02, h)` | 星空、月亮、夜间雾 |
| `lamps` | `max(smoothstep(0.10, -0.04, h), 雨天项)` | 人造光开关 |

所有过渡都用 smoothstep 或指数形式，**不要用 if 硬切**：时间流动时硬切会闪烁。

### 3.3 一盏方向光轮流扮演太阳和月亮

- 只用**一盏**带级联阴影的方向光：太阳亮度 ≥ 月亮亮度时扮演太阳，否则扮演月亮（冷色、低亮度）。
- 两盏带阴影的方向光代价翻倍；而在地平线附近两者亮度都趋近 0，切换看不出来。
- 太阳颜色按高度插值：低空偏橙红（约 `1.0, 0.36, 0.10`），高空接近白（约 `1.0, 0.95, 0.88`）。

### 3.4 天空

两种做法，都配合 `SkyLightCapture` 让环境光跟随天空：

- **`ProceduralSky` 组件**：渐变天空 + 绑定方向光当太阳，参数对标 Godot。示例 [examples/29-procedural-sky](../../examples/29-procedural-sky)。
- **自写 `shader_type sky`**：需要云、星空、月亮、闪电时用。
  - 颜色在 Lua 里算好作为 uniform 下发，shader 只负责"形状"（光晕、日盘、星空、云、闪电）。
  - 调色板分白天 / 日落 / 夜晚三组天顶色和地平线色：先按 `dayMix` 插值，再按 `golden` 混入日落色，最后按天气向灰色插值。

**雾色直接用天空的地平线色**，天空和雾之间就不会有接缝。

### 3.5 环境光（IBL）：从天空实时捕获

- `SkyLightCapture` 把天空渲染成环境光（漫反射 SH + 预滤波反射）交给同节点的 Zone。天空一变环境光就跟着变，昼夜、天气、闪电**不用再单独调 IBL**。
- 强度保持 1：夜晚天空暗，环境光自然就暗。
- 自写 sky shader 在捕获时用 `if (!AT_CUBEMAP_PASS)` 去掉高亮日盘，只保留光晕，否则反射里会有亮斑噪点。
- 天空每帧都在变时（时间流动、云在飘），默认 `minCaptureInterval = 0.25` 秒，桌面 GPU 每帧约 +0.2–0.3 ms。
- 不支持捕获的设备（`capture.supported == false`）可由脚本按时段切换项目自备的预过滤镜面 IBL cubemap（设置 `zone.envSpecTexture`）。使用前须确认资源存在并随项目发布，强度根据 `dayMix` 和纹理实际亮度调整；没有这类资源时，保留 Zone 原有环境数据。

细节见 [天空与环境光](sky-and-environment-lighting.md)。

---

## 4. 天气系统

### 4.1 状态机：目标值 + 平滑值 + 滞后的湿度

```lua
weatherTarget   -- 0 晴 / 1 雨；手动或计时器切换
weather         -- 以约 1/10 每秒逼近 target，约 10 秒过渡
w = smoothstep(0, 1, weather)     -- 所有视觉量都用 w
wet             -- 变湿快（约 +0.08/s）、变干慢（约 -0.02/s）
```

**湿度与降雨分离**：湿度驱动湿地面和水洼，于是"雨停了但地还湿"自然出现。

### 4.2 雨天要一起变的量

| 量 | 晴 → 雨（参考） |
|---|---|
| 天空 | 天顶、地平线色向灰插值；云覆盖增加 |
| 主光 | 强度 × (1 - 0.85w) |
| 深度雾 | 起止距离明显拉近 |
| 体积雾密度 | 小幅增加 |
| 环境光 | 捕获模式下随天空自动变化 |
| 人造光 | 大雨时提前点亮 |
| 水面 | 浪高、陡峭度增加，泡沫增多，雨滴涟漪 |
| 地面 | GBuffer 湿润后处理（压暗、降粗糙度）与水洼 |
| 降水粒子 | 发射率随 w |
| 闪电 | 强降雨时随机触发 |

漏掉任何一项都会显得假，比如下雨了主光还很强，或雾还是晴天的距离。

### 4.3 雨丝粒子

- 贴图可在 Lua 里用 `Image` 生成一张窄长的软竖条，材质用 `Techniques/DiffUnlitParticleAdd.xml`，不依赖图片资源。
- `ParticleEffect` 用盒形发射器，速度 20–26 m/s、方向带一点风偏，粒子细长。
- `emitter:SetFaceCameraMode(FC_DIRECTION)`：沿速度方向拉伸成雨丝。
- 发射器节点每帧跟随相机（放在上方十几米），粒子保持世界空间。
- 叠加混合的雨在夜里会过亮：每帧按环境亮度调 `MatDiffColor`。

### 4.4 湿地面：GBuffer 后处理

所有表面统一变湿，不需要给每个材质加雨天参数：

```glsl
shader_type spatial;
render_mode gbuffer_postprocess;
uniform float wetness = 0.0;
void fragment() {
    if (wetness > 0.001 && (SHADING_MODEL == SHADING_MODEL_PBR || SHADING_MODEL == SHADING_MODEL_TOON)) {
        float facing = mix(0.5, 1.0, smoothstep(0.3, 0.9, NORMAL.y));   // 竖直面只湿一半
        float exposed = wetness * facing;
        ALBEDO *= mix(1.0, 0.6, exposed);
        ROUGHNESS = mix(ROUGHNESS, min(ROUGHNESS, 0.18), exposed);      // 只降不升，不破坏本来就光滑的表面
        // 水洼：朝上平面 + 世界空间噪声阈值，ROUGHNESS 降到约 0.03，由 SSR 产生倒影
    }
}
```

- 注册：`local handle = zone:AddGBufferPostProcess(mat)`，再 `zone:SetGBufferPostProcessEnabled(handle, true)`。
- 水洼倒影依赖 SSR，所以必须开启延迟管线和 SSR。

### 4.5 闪电

- 一盏无阴影方向光当闪光源，每次随机方向。
- 包络用两次闪烁：`exp(-t·18) + 0.8·exp(-|t-0.22|·30)`，总长约 0.45 秒。
- 同时提高闪光灯亮度、天空的闪电项（云越厚越亮）和雾色。只闪天空不闪地面会显得假。
- 捕获的环境光受 `minCaptureInterval` 限制，跟不上一次闪电，照亮地面主要靠闪光灯。

---

## 5. 打光规范

### 5.1 光源分层

| 层 | 典型光源 | 阴影 | 体积雾 |
|---|---|---|---|
| 主光 | 1 盏方向光（太阳 / 月亮） | 级联阴影 | 开，并开体积阴影（光柱） |
| 环境 | `SkyLightCapture` 捕获天空 | — | 天光散射 |
| 叙事光 | 探照灯、塔楼旋转灯等高亮聚光 | 通常关 | 开，强度高 |
| 氛围光 | 路灯等成组点光 | 关 | 开 |
| 角色光 | 车灯、手电 | 关键的一盏开 | 开 |
| 点缀光 | 信号灯、闪烁小灯 | 关 | 开 |
| 特效光 | 闪电、爆炸 | 关 | 开 |

- **只给少数关键光开阴影**（主光 + 一盏角色光）。延迟渲染里大量无阴影点光很便宜，阴影才是开销大头。
- **每盏人造光配一个自发光网格**（灯泡、灯罩玻璃）。`MatEmissiveColor` 与灯光亮度由同一个系数驱动，自发光取 HDR 值（分量 > 1）让泛光起作用。
- 自发光网格设 `castShadows = false`，否则会挡住自己内部的光源。
- 贴近地面的小点光亮度要低，否则会把一大片地面染色。

### 5.2 光照数值参考（ACES，固定曝光）

| 光源 | 参考值 |
|---|---|
| 太阳 | brightness 3–3.5，雨天 × 0.15 |
| 月光 | brightness 约 0.5，冷色（约 `0.55, 0.66, 1.0`） |
| 路灯点光 | brightness 约 9，range 约 11，体积强度约 6 |
| 高处叙事聚光 | brightness 可到 100 以上，体积强度约 25 |
| 自写天空 exposure | 1.5 左右（按天空亮度调） |

### 5.3 PBR 材质约定

- 纯色道具用 `Techniques/PBR/PBRNoTexture.xml`，参数 `MatDiffColor`、`Roughness`、`Metallic`、`MatEmissiveColor`。
- roughness 参考：布料 / 羽毛 0.75–0.85，木头 0.6–0.8，车漆 0.22（metallic 0.55），镀铬 0.12（metallic 1），橡胶 0.7–0.85，水 0.03。
- 同一类表面准备 2–3 个略有差异的材质交替使用，打破重复感。

---

## 6. 体积光与雾

### 6.1 三层雾各司其职

| 层 | 作用 | 设置要点 |
|---|---|---|
| 深度雾 | 远景融入天空 | 雾色 = 天空地平线色；起止距离随天气变 |
| 全局体积雾（froxel） | 光柱、灯光光晕 | 密度很低：约 0.0015 起，晨昏、夜晚、雨天各加一点 |
| `LocalFogVolume` | 局部雾团（晨雾、山谷雾） | 节点 scale 决定椭球大小；按时段调 extinction |

### 6.2 让灯光进入体积雾

灯光默认参与体积雾（`affectVolumetricFog` 默认 true），开启 Zone 体积雾后就能看到光晕：

```lua
sun.volumetricFogShadows = true         -- 主光用阴影在雾里刻出光柱（需 castShadows）
spot.volumetricFogIntensity = 25        -- 叙事光加强
smallLamp.affectVolumetricFog = false   -- 不需要光晕的小灯关掉
```

### 6.3 关键参数

- **密度要低**：0.02 以上画面会糊成一片。光柱感来自前向散射 `volumetricFogPhaseG`（约 0.55）和光源体积强度，不是来自浓雾。
- **`volumetricFogHeightFalloff` 要小（约 0.025）**：高处光源（几十米高的灯）需要高处还有介质，衰减大了光束会完全不可见。
- **`volumetricFogViewDistance`** 决定体积雾覆盖多远，远景光束需要调大（如 260）。

完整参数见 [volumetric-fog.md](volumetric-fog.md)。

---

## 7. 大面积水面

- **用 PBR 着色写入 GBuffer**（`shading_model_pbr`），自动获得 SSR 倒影、延迟光照和体积雾。**不要用 unlit 加手写天空反射**。
- **波浪用 GPU FFT**（Tessendorf）时直接复用引擎已验证的 compute 链路（`Tests/SurfaceShader/fixtures/surface_shader_compute_ocean`），不要自己重写 FFT。天气缩放浪高时，在计算链路里缩放位移，让法线和泡沫从同一份位移算出；只在材质里放大顶点位移，法线和泡沫不会跟着变。
- **相机跟随的非均匀网格**：一张 `PlaneGeometry` 在顶点着色器里映射到世界，中心格距约等于一个波浪纹素、外圈铺到地平线；中心按格距吸附相机位置，避免近处顶点游移；位移随距离淡出，远处只保留法线。
- 几何由着色器生成时：包围盒设为巨大值、`SetOccludee(false)`，避免被裁剪或被 HiZ 剔除。
- 多尺度法线按**斜率相加**（`n.xz / n.y`），大尺度一层用来打破平铺感。
- 逆光透光、泡沫、雨滴涟漪都可以在 fragment 里叠加；主光方向和辐亮度由 Lua 以 uniform 传入。

完整实现见示例的水面着色器与 FFT 脚本。

---

## 8. 常见坑

| 现象 | 原因 | 解决 |
|---|---|---|
| SurfaceShader 材质参数或贴图偶尔丢失 | 异步编译或热重载会重置覆盖值 | 动态材质的 uniform 与 `SetSurfaceTexture` **每帧重新设置**（值不变时不会触发天空重新捕获） |
| `ComputeDispatch` 为 nil 或设备不支持 compute | 平台或构建不支持 | 先判空和检查支持再用，不支持时降级（如水面改用静态法线） |
| 画面整体糊成一片 | 体积雾过浓，或与 `LocalFogVolume`、降水叠加 | 体积雾保持 0.002–0.01；局部雾 extinction 在 0.005 左右 |
| 高处光束几乎看不见 | 体积雾高度衰减太大，高处没有介质；光源体积强度不足 | 减小 `volumetricFogHeightFalloff`，加大 `volumetricFogViewDistance` 和光源体积强度 |
| 画面四角有白色光晕 | 开了暗角（Vignette），当前参数表现为提亮 | 不启用 Vignette |
| 夜晚场景发灰偏亮 | 环境光过强 | 捕获模式强度用 1 并让夜空足够暗；回退路径夜间约 0.025；明暗靠人造光和月光塑造 |
| 贴地小灯把一大片地面染色 | 点光亮度过高 | 降到 0.5 左右 |
| 天空与远景之间有一道色差线 | 雾色与天空地平线色不同 | 雾色直接用天空地平线色 |
| 用 LightGroup 预设后反射方向不对 | 预设自带非零 `envCubeFollowAngle`，实际旋转角 = `envCubeAngle + envCubeFollowAngle` | 用 `SkyLightCapture`（捕获按世界方向对齐）；手动管理反射图时把两个角度都设成 0 |
| 首次启动很久没画面，截图截到加载界面 | 首次要编译大量 shader | 先跑一次预热 shader 缓存；截图帧号取足够大 |
| 自动截图时天气或时间已经变了 | 计时器在加载和编译期间照常走 | 提供固定时间、固定天气、冻结时间的启动参数，验证时都加上 |

---

## 9. 验证清单

1. 在 `.project/engine.json` 中配置 `rendering.pipeline` 为 `deferred` 后启动，先预热一次 shader，确认日志没有 `ERROR`，自写的 SurfaceShader 都已加载。
2. 固定时间与天气截几张：正午、黄昏、夜晚、雨天，都冻结时间。
3. 逐张检查：
   - 天空与雾之间没有接缝；
   - 环境反射颜色与天空一致（黄昏偏暖、雨天偏灰）；
   - 阴影方向与太阳一致；
   - 夜里人造光有光晕，高处光束可见；
   - 雨天有雨丝、湿地面倒影、水面变化；
   - 水面、湿地面有 SSR 倒影。
4. 再看一张远景，检查整体构图与体积光。
