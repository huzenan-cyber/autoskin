# 灯光与阴影

> 灯光类型、亮度、阴影（方向光级联、局部光阴影、时域阴影）和开销预算。
> 基础的点光 / 聚光创建与亮度取值见 [rendering.md](rendering.md)"自建点光 / 追光"；体积光见 [volumetric-fog.md](volumetric-fog.md)。

---

## 1. 灯光类型

| 类型 | 枚举 | 典型用途 | 关键属性 |
|---|---|---|---|
| 方向光 | `LIGHT_DIRECTIONAL` | 太阳、月亮 | 节点 `direction`；`shadowCascade` |
| 点光 | `LIGHT_POINT`（默认） | 灯泡、火把、爆炸闪光 | `range` |
| 聚光 | `LIGHT_SPOT` | 车灯、手电、探照灯、灯塔光束 | `range`、`fov` |
| 矩形面光 | `LIGHT_RECT` | 灯箱、屏幕、窗户 | `sourceWidth`、`sourceHeight`、`barnDoorAngle` |

面积光与"管状光"：

- 点光默认是**理想点光源**（`punctualLight = true`），此时 `radius`（光源半径）和 `length`（管长）被忽略。
- 需要柔和的球形光源或灯管时设 `light.punctualLight = false`，再设 `radius` / `length`。
- **矩形面光和面积点光只在最高画质下生效**。默认最高画质只在 Windows 上启用，其他平台会丢弃这两类灯。跨平台项目用普通点光 / 聚光兜底。

## 2. 亮度与颜色

```lua
local light = node:CreateComponent("Light")
light.lightType = LIGHT_POINT
light.color = Color(1.0, 0.72, 0.42)   -- 颜色
light.brightness = 3.0                  -- 强度倍数
light.range = 11
```

- 最终颜色 = `color × brightness`。矩形面光还会按面积换算（面积越大，同样 brightness 越暗）。
- **色温只有在 `useTemperature = true` 时才生效**：`light.useTemperature = true; light.temperature = 3200`。
- 常用取值参考（ACES 色调映射、固定曝光）：

| 灯 | brightness | 备注 |
|---|--:|---|
| 太阳 | 3–3.5 | 雨天 × 0.15 |
| 月光 | 0.5 | 偏冷色 |
| 路灯点光 | 3–9 | range 10–12 |
| 车前灯聚光 | 4 | fov 40–45 |
| 贴地小灯（尾灯） | 0.5 | 过亮会把一大片地面染色 |

**每盏人造光配一个自发光网格**（灯泡、灯罩、灯箱），并让两者共用同一个开关系数：

```lua
local level = lampsOn and 1 or 0
lampLight.brightness = 9.0 * level
bulbMaterial:SetShaderParameter("MatEmissiveColor", Variant(Vector3(9, 6.2, 3.4) * level))  -- HDR，触发泛光
bulbNode:GetComponent("StaticModel").castShadows = false   -- 否则灯泡会挡住自己的光
```

---

## 3. 阴影

### 3.1 预算原则

- **只给少数关键光开阴影**：主光（太阳/月亮）+ 一两盏叙事性的聚光（车灯、手电）。
- 大量点光 / 路灯**不开阴影**；在支持计算着色器的设备上，无阴影的点光很便宜（见 [deferred-rendering.md](deferred-rendering.md)"大量灯光"）。
- 阴影开关：`light.castShadows = true`；物体侧 `staticModel.castShadows = true` 才会投影。

### 3.2 方向光级联阴影（CSM）

```lua
sun.castShadows = true
sun.shadowCascade = CascadeParameters(8.0, 30.0, 90.0, 260.0, 0.8)
sun.shadowBias = BiasParameters(0.00025, 0.5)
```

- `CascadeParameters(split1, split2, split3, split4, fadeStart[, biasAutoAdjust])`：
  - `split1..4` 是每一级到相机的最远距离（米）；近处分得细，阴影更清晰。
  - `fadeStart` 是总阴影距离中开始淡出的比例（0–1）。
  - **桌面最多 4 级，移动端最多 2 级**，多写的级数会被忽略。
- `BiasParameters(constant, slopeScaled[, normalOffset])`：出现"阴影痤疮"（条纹）调大，出现"彼得潘"（阴影脱离物体）调小。
- `light.shadowResolution`：0.125–1.0，按比例降低该灯的阴影贴图分辨率。

全局设置：

```lua
renderer.shadowMapSize = 2048                    -- 取 2 的幂，最小 64；引擎默认 1024
renderer.shadowQuality = SHADOWQUALITY_PCF_24BIT  -- SIMPLE_16BIT / SIMPLE_24BIT / PCF_16BIT / PCF_24BIT / VSM / BLUR_VSM
```

PCF 阴影（`PCF_16BIT` / `PCF_24BIT`）每个像素的采样次数用 `renderer.shadowPCFSamples` 设置，只能是 4 或 16：手机默认 4，桌面和 Web 默认 16。16 次的阴影边缘更软，但手机上开销明显更大；确认是高端机后再改成 16，PC 想省开销也可以改成 4。运行时修改会让接收阴影的着色器重新编译，第一次用到时可能卡顿，不要频繁切换。

项目级默认值写在 `.project/engine.json`：`shadows.pcf_samples` 对所有平台生效，`platforms.<平台>` 下写同样的结构只覆盖该平台，平台名可用 `windows` / `macos` / `linux` / `android` / `ios` / `ohos` / `web`。下例让 PC 用 4 次，iOS 用 16 次：

```json
{
  "platforms": {
    "windows": { "shadows": { "pcf_samples": 4 } },
    "ios": { "shadows": { "pcf_samples": 16 } }
  }
}
```

手机上画质档位（项目 `engine.json` 的 `rendering.quality`）为 `low` 时，引擎会把 PCF 阴影换成同精度的 SIMPLE 质量渲染（`PCF_16BIT` → `SIMPLE_16BIT`，`PCF_24BIT` → `SIMPLE_24BIT`）。SIMPLE 不做 PCF，每个像素只比较一次，阴影边缘更硬、开销更低。这不是把采样次数改成 1：`shadowPCFSamples` 仍只能设为 4 或 16，设置的值会保留，只是 SIMPLE 下用不到。这时读回的 `renderer.shadowQuality` 是 SIMPLE；切回其他档位后自动恢复成设置的 PCF。

### 3.3 时域阴影（只对方向光）

远处的级联隔几帧才更新一次，节省主光阴影的开销。需要在灯上单独开启：

```lua
sun.temporalShadows = true                           -- 默认关
sun.temporalShadowIntervals = Vector4(1, 2, 4, 8)    -- 每级每隔几帧更新（第 1 级总是 1）
```

以下情况会自动退回普通阴影：灯不投影、`shadowIntensity >= 1`、正交相机、自定义投影、`normalOffset >= 0.25`、有效级联少于 2 级。`renderer.temporalShadows = false` 可以全局关闭。

### 3.4 局部光阴影（点光 / 聚光 / 面光）

局部光阴影共用一张阴影图集，前向、延迟、透明物体和体积雾都会使用：

```lua
spot.castShadows = true
renderer:SetClusterLocalShadowsEnabled(true)   -- 桌面默认开，移动默认关
renderer:SetClusterLocalShadowMaxLights(8)     -- 每个视图最多几盏灯有阴影（桌面默认 8，移动 4）
renderer:SetClusterLocalShadowMaxFaces(48)     -- 面数预算：聚光 1 面，点光和面光 6 面（桌面默认 48，移动 6）
```

- 需要计算着色器等硬件能力，不满足时局部光没有阴影。
- 超出预算的灯照样发光，只是没有阴影。
- 点光阴影比聚光贵 6 倍，能用聚光就用聚光。

---

## 4. 灯光与体积雾

灯光默认参与体积雾（`light.affectVolumetricFog = true`），Zone 开启体积雾后每盏灯都会产生光晕：

- 不想要光晕的灯：`light.affectVolumetricFog = false`。
- 调节强度：`light.volumetricFogIntensity`。
- **方向光必须开阴影才会进入体积雾**。
- 光柱（丁达尔）需要 `light.volumetricFogShadows = true`（默认）且灯本身投影。

详见 [volumetric-fog.md](volumetric-fog.md)。

---

## 5. 常见问题

| 现象 | 原因 | 解决 |
|---|---|---|
| 面光 / 灯管在手机或 Mac 上不亮 | 这两类灯只在最高画质生效 | 用普通点光 / 聚光兜底 |
| 灯多了之后部分灯不亮 | 超出单视图光源上限，被静默丢弃 | 控制数量；远处的灯用自发光网格代替 |
| 设了色温没变化 | 没有打开 `useTemperature` | `light.useTemperature = true` |
| 聚光没有阴影 | 超出局部阴影预算，或设备不支持 | 提高 `SetClusterLocalShadowMaxLights`；检查 `graphics:GetComputeShaderSupport()` |
| 太阳不产生体积光 | 方向光没开阴影 | `sun.castShadows = true` |
| 灯泡模型挡住了自己的光 | 自发光网格也在投影 | 灯泡 `castShadows = false` |
