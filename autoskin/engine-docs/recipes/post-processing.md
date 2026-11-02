# 后处理（Post-processing）

> 屏幕空间效果（SSR / SSGI / GTAO / 运动模糊）、泛光、色调映射、自动曝光、景深。
> 暗角、全屏模糊、色调映射模式的详细说明见 [rendering.md](rendering.md)"后效"，本文不重复。

---

## 1. 总览

所有后处理都挂在 **Zone** 上（景深除外，它是独立组件）。先拿到 Zone：

```lua
local lg = scene_:CreateChild("LightGroup")
lg:LoadXML(cache:GetResource("XMLFile", "LightGroup/Daytime.xml"):GetRoot())
local zone = lg:GetComponent("Zone", true)
```

| 效果 | 前向（桌面） | 前向（移动） | 延迟 | 默认 |
|---|:-:|:-:|:-:|---|
| SSR 屏幕空间反射 | — | — | ✅ | **开** |
| SSGI 屏幕空间全局光照 | — | — | ✅ | 关 |
| GTAO 环境光遮蔽 | 固定参数 SSAO | — | ✅ | 始终开（参数可调） |
| TAA | — | — | ✅ 始终开 | — |
| 运动模糊 | — | — | ✅ | 关 |
| 泛光 Bloom | ✅ | ✅ | ✅ | 开（Legacy 模式） |
| 色调映射 Tonemap | ✅ | ✅ | ✅ | LUT |
| 自动曝光 | ✅ | ✅ | ✅ | 关 |
| 景深 DOF | ✅ | ✅ | ✅ | 添加组件即开启 |
| 暗角 Vignette | ✅ | ✅ | ✅ | 关 |

延迟渲染的开启方式见 [deferred-rendering.md](deferred-rendering.md)。

> ⚠️ **色调映射、暗角、曝光缩放都在泛光的最终合成里执行**。用 `zone:SetAttribute("Bloom Enable", Variant(false))` 关掉泛光，会把它们一起关掉，画面会明显过曝。想要"没有泛光"，把泛光强度调到 0，不要关掉泛光本身。

---

## 2. 屏幕空间效果（仅延迟）

```lua
-- 反射：水面、湿地面、车漆的关键
zone.ssrEnabled = true                 -- 默认开
zone.ssrUsePrevFrameColor = true       -- 默认开

-- 间接光：颜色从亮面"反弹"到周围
zone.ssgiEnabled = true                -- 默认关
zone.ssgiQuality = 2                   -- 1–4：4 / 8 / 16 / 32 条光线
zone.ssgiIntensity = 1.0               -- 0–2：0 = 只用环境光，1 = 完整 SSGI，>1 夸张

-- 环境光遮蔽（GTAO）
zone.ssaoRadius = 0.5                  -- 采样半径（米），默认 0.5
zone.ssaoIntensity = 2.2               -- 强度（幂次），0.1–10，默认 2.2

-- 运动模糊
zone.motionBlurEnabled = true          -- 默认关
zone.motionBlurAmount = 0.35           -- 快门比例 0–2，默认 0.5
zone.motionBlurMaxDistortion = 5       -- 最大拖影（屏幕宽度的百分比），默认 5
```

- `ssaoRadius` / `ssaoIntensity` 只影响延迟管线的 GTAO；前向桌面的 SSAO 参数是固定的。
- SSGI 质量每升一级光线数翻倍，开销明显增加；一般用 2。

---

## 3. 泛光（Bloom）

三种模式互斥，用 `zone.bloomMode` 选择：

| 模式 | 参数 | 特点 |
|---|---|---|
| `BLOOM_MODE_LEGACY`（默认） | `bloomThreshold`、`bloomWeight` | 简单阈值泛光 |
| `BLOOM_MODE_PLUS` | 同上 + `bloomPlusIntensity` | 质量更高的版本 |
| `BLOOM_MODE_UE` | `bloomUEIntensity`、`bloomUEThreshold`、`bloomUESizeScale`、各级尺寸与颜色 | 仿 UE 的多级泛光，配合 HDR 自发光效果最好 |

```lua
zone.bloomMode = BLOOM_MODE_UE
zone.bloomUEIntensity = 0.55           -- 默认 0.675
zone.bloomUEThreshold = 1.2            -- 默认 -1（≤ -1 表示不设阈值，所有亮度都参与）
zone.bloomUESizeScale = 4              -- 默认 4，泛光扩散范围
zone:SetBloomUETint(1, Color(1, 0.9, 0.8))   -- 第 1–6 级的颜色
```

- 自发光材质的 `MatEmissiveColor` 用大于 1 的 HDR 值（如 `Vector3(9, 6, 3)`）才会产生明显的泛光。
- UE 模式下 `bloomUEThreshold` 设 1 左右，只让真正亮的东西发光，画面更干净。

---

## 4. 自动曝光

自动曝光有两条路径，由 `autoExposurePlusEnabled` 选择：

| 路径 | 开关 | 参数 |
|---|---|---|
| 旧路径 | `autoExposureEnabled = true` | 参数固定，Lua 不可调 |
| **UE 直方图路径（推荐）** | 再加 `autoExposurePlusEnabled = true` | 下面这些属性**只在这条路径下生效** |

| 属性 | 默认 | 说明 |
|---|--:|---|
| `autoExposureMinBrightness` / `MaxBrightness` | -10 / 20 | 自适应范围（EV）。**两者必须 min < max**，否则直接使用目标曝光 |
| `autoExposureBias` | 0 | 曝光补偿（EV），正值提亮 |
| `autoExposureSpeedUp` / `SpeedDown` | 3 / 1 | 变亮 / 变暗的适应速度 |
| `autoExposureForceTarget` | false | true = 跳过适应过程，每帧直接用目标曝光 |

**固定曝光**（昼夜场景推荐：亮度由脚本控制，没有"呼吸"感）：

```lua
zone.autoExposureEnabled = true
zone.autoExposurePlusEnabled = true
zone.autoExposureMinBrightness = 1
zone.autoExposureMaxBrightness = 1
zone.autoExposureBias = 1
zone.autoExposureForceTarget = true
```

**自适应曝光**（进出隧道、室内外切换）：

```lua
zone.autoExposureEnabled = true
zone.autoExposurePlusEnabled = true
zone.autoExposureMinBrightness = -2
zone.autoExposureMaxBrightness = 4
zone.autoExposureSpeedUp = 3
zone.autoExposureSpeedDown = 1
```

> `tonemapMode = TONEMAP_MODE_NONE` 或关掉泛光都会让曝光失效，见 [rendering.md](rendering.md)"Tonemap"。

---

## 5. 景深（DepthOfField）

景深是独立组件，按顺序查找：**相机节点 → 相机的父节点 → 场景根**。添加组件即开启。

```lua
local dof = cameraNode:CreateComponent("DepthOfField")
dof:SetFocalDistance(6)            -- 焦点距离（米），默认 15
dof:SetFocalRange(4)               -- 清晰范围（米），默认 30
dof:SetMaxBlur(8)                  -- 最大模糊（像素），0–32，默认 4
dof:SetQuality(DOF_QUALITY_HIGH)   -- LOW 4 采样 / MEDIUM 8（默认）/ HIGH 16
dof:SetNearBlurScale(0.3)          -- 近景模糊比例，默认 0.3
dof:SetFarBlurScale(0.8)           -- 远景模糊比例，默认 0.8
dof:SetBokehBrightness(0.3)        -- 光斑亮度 0–2，默认 0.3

dof:FocusOnNode(playerNode)        -- 对焦到某个节点（也可 FocusOnPosition）
dof:SetEnabled(false)              -- 临时关闭
```

---

## 6. 常见问题

| 现象 | 原因 | 解决 |
|---|---|---|
| 设了 SSR / SSGI 没效果 | 不是延迟管线 | 在 `.project/engine.json` 中将 `rendering.pipeline` 设为 `deferred`，构建发布要求见[开启方式](deferred-rendering.md#11-开启方式) |
| 关了泛光后画面过曝 | 色调映射在泛光合成里 | 不要关泛光；把强度调到 0 |
| 曝光参数设了没反应 | 走的是旧路径 | 加 `zone.autoExposurePlusEnabled = true` |
| 场景忽明忽暗（"呼吸"） | 自适应曝光在追场景亮度 | 用固定曝光（`ForceTarget` + min == max） |
| 创建相机后画面突然模糊 | 场景或相机上有 DepthOfField 组件 | 调整焦距，或 `dof:SetEnabled(false)` |
| 泛光太"糊" | UE 模式阈值 ≤ -1，所有亮度都参与 | `bloomUEThreshold` 设 1 左右 |
