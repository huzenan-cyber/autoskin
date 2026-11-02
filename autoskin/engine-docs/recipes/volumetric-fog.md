# 体积雾与体积光

> 让灯光在空气里"看得见"：光柱（丁达尔效应）、路灯光晕、晨雾、局部雾团。
> 灯光本身的设置见 [lights-and-shadows.md](lights-and-shadows.md)。

---

## 1. 组成与支持情况

体积雾由三部分组成：

| 部分 | 负责什么 | 在哪设置 |
|---|---|---|
| 全局介质 | 整个场景的空气密度、颜色、随高度变薄 | Zone 的 `volumetricFog*` 属性 |
| 灯光注入 | 哪些灯在雾里发光、强度、是否产生光柱 | Light 的 `affectVolumetricFog` 等属性 |
| 局部雾团 | 贴地晨雾、烟雾、魔法雾球 | `LocalFogVolume` 组件 |

| 管线 | 支持 |
|---|---|
| 前向（桌面）/ 延迟 + 支持计算着色器 | ✅ 完整版（froxel 体积网格）：所有灯、局部光阴影、局部雾团 |
| 不支持计算着色器 | 简化版：只有方向光和天光，**没有**局部灯光晕和 `LocalFogVolume` |
| 前向（移动） | ❌ 没有体积雾 |

UrhoXRuntime 在桌面（非 WebGL）默认开启完整版。其他情况可以手动开启：

```lua
renderer:SetVolumetricFogFroxelEnabled(true)                   -- 需要计算着色器
renderer:SetVolumetricFogQuality(VOLUMETRIC_FOG_QUALITY_HIGH)  -- LOW / HIGH / ULTRA
```

| 质量 | 网格精度 | 用途 |
|---|---|---|
| `LOW` | 16 像素 × 64 层 | 移动端、WebGL 默认 |
| `HIGH` | 8 像素 × 128 层 | 桌面默认 |
| `ULTRA` | 4 像素 × 128 层 | 截图、展示，开销最大 |

---

## 2. 最小示例

```lua
-- 1. Zone：开启并设置很稀薄的介质
zone.volumetricFogEnabled = true
zone.volumetricFogDensity = 0.004
zone.volumetricFogHeight = 0
zone.volumetricFogHeightFalloff = 0.025
zone.volumetricFogViewDistance = 200
zone.volumetricFogPhaseG = 0.55

-- 2. 太阳：必须投影，才能在雾里刻出光柱
sun.castShadows = true
sun.volumetricFogShadows = true      -- 默认 true
sun.volumetricFogIntensity = 2.0

-- 3. 路灯：默认就参与体积雾，按需调强度
lamp.volumetricFogIntensity = 6.0
```

---

## 3. 全局介质（Zone）

| 属性 | 默认 | 说明 |
|---|--:|---|
| `volumetricFogEnabled` | false | 总开关 |
| `volumetricFogDensity` | 0.06 | 介质密度。**做光柱用 0.002–0.01**；0.02 以上画面会糊成一片 |
| `volumetricFogHeight` | 80 | 基准高度（Zone 节点空间） |
| `volumetricFogHeightFalloff` | 0 | 随高度变薄的速度。**高处的灯（灯塔、探照灯）需要很小的值（约 0.025）**，否则高处没有介质，光束看不见 |
| `volumetricFogViewDistance` | 120 | 体积雾覆盖的距离（米）；远处的光束要调大 |
| `volumetricFogStartDistance` | 2 | 从离相机多远开始有雾 |
| `volumetricFogPhaseG` | 0.12 | 散射方向性，-0.95–0.95。正值 = 迎着光看更亮（光柱更明显），常用 0.5–0.6 |
| `volumetricFogScatteringColor` | (1, 0.86, 0.55) | 散射颜色，白色即中性 |
| `volumetricFogAbsorptionColor` / `AbsorptionIntensity` | — / 0.01 | 吸收；做光柱时通常设 0 |
| `volumetricFogMaxOpacity` | 0.55 | 雾的最大不透明度，0–1 |
| `skyLightVolumetricScatteringIntensity` | 0 | 环境天光对雾的照亮程度，夜景或阴天调到 0.3–0.6 让雾不至于全黑 |

只有 `enabled`、`density > 0`、`viewDistance > 0` 同时满足时才会渲染。

**光柱增强**（可选）：`volumetricFogShaftContrast`（0 = 关闭）以及 `volumetricFogShaftEdge*`、`volumetricFogShaftGroundFade*` 等参数，用来加强阴影边缘的对比，一般不需要调。

---

## 4. 灯光注入（Light）

| 属性 | 默认 | 说明 |
|---|--:|---|
| `affectVolumetricFog` | **true** | 这盏灯是否在雾里发光 |
| `volumetricFogIntensity` | 1 | 在雾里的强度倍数（不影响照亮表面的亮度） |
| `volumetricFogShadows` | true | 是否用该灯的阴影在雾里刻出光柱（灯本身需投影） |

规则：

- **方向光必须 `castShadows = true` 才会进入体积雾**；场景里只使用第一盏满足条件的方向光。
- 点光、聚光、面光：在完整版里全部参与（受光源上限约束，见 [deferred-rendering.md](deferred-rendering.md)）；局部光的雾中阴影需要局部光阴影可用（见 [lights-and-shadows.md](lights-and-shadows.md)）。
- 不需要光晕的小灯（尾灯、指示灯）设 `affectVolumetricFog = false`，画面更干净。

强度参考：

| 灯 | `volumetricFogIntensity` |
|---|--:|
| 太阳 | 2–2.5（夜间月光 1.2） |
| 路灯 | 3–6 |
| 灯塔 / 探照灯光束 | 20–25，配合很窄的 `fov` 和较大的 `brightness` |

---

## 5. 局部雾团（LocalFogVolume）

节点上的一个椭球形雾团，节点的 `scale` 决定椭球大小（支持非等比缩放）。只在完整版体积雾中生效，场景中最多同时渲染 16 个。

```lua
local node = scene:CreateChild("MorningMist")
node.position = Vector3(0, 0.5, 0)
node.scale = Vector3(320, 10, 320)          -- 扁平的大椭球 = 贴地雾
local mist = node:CreateComponent("LocalFogVolume")
mist.albedo = Color(0.9, 0.93, 1.0)
mist.radialExtinction = 0.004               -- 中心处的密度
mist.heightExtinction = 0.08                -- 椭球底部额外的密度
mist.heightFalloff = 4.0
mist.radialFalloff = 0.6                    -- 0 = 硬边
```

| 属性 | 默认 | 说明 |
|---|--:|---|
| `albedo` | 白 | 雾的颜色 |
| `emissive` | 黑 | 自发光颜色与强度，不依赖灯光；发光贡献随该雾团的局部密度变化，零局部密度不发光 |
| `radialExtinction` | 1 | 中心密度（每米）。**大面积雾团用 0.001–0.01**，默认值 1 非常浓 |
| `heightExtinction` / `heightFalloff` | 0 / 1 | 底部额外密度及其随高度衰减 |
| `radialFalloff` | 1 | 从中心到边缘的衰减 |
| `phaseG` | 0.5 | 散射方向性 |
| `maxDrawDistance` | 0 | 超过该距离不渲染，0 = 不限 |

**自发光调参**：先用 `radialExtinction`、`heightExtinction` 和节点 `scale` 确定雾团的浓度与范围，再逐步提高 `emissive` 调整发光效果。使用 `radialExtinction = 0.001–0.01` 的低密度魔法雾团时，可能需要较大的 `emissive`；若径向和高度密度都为 0，增大它也不会发光。最终画面亮度还受雾团厚度、透射率和曝光影响，应在相同曝光条件下观察调参结果。

---

## 6. 调试

```lua
renderer:SetVolumetricFogDebugMode(1)   -- 0 = 正常，1 = 介质密度，2 = 光照注入
```

## 7. 常见问题

| 现象 | 原因 | 解决 |
|---|---|---|
| 画面整体糊成一片、看不清远景 | 密度太大，或局部雾团与全局雾叠加 | 全局密度 0.002–0.01；局部雾团 `radialExtinction` 0.001–0.01 |
| 太阳没有光柱 | 方向光没投影，或 `volumetricFogShadows = false` | `sun.castShadows = true` |
| 高处的灯（灯塔）光束看不见 | `volumetricFogHeightFalloff` 太大，高处没有介质 | 调到 0.01–0.03；同时提高 `volumetricFogIntensity` |
| 远处光束被截断 | 超出 `volumetricFogViewDistance` | 调大 |
| 手机上没有体积雾 | 移动前向管线不支持 | 用自发光网格 + 泛光模拟光晕 |
| `LocalFogVolume` 不显示 | 设备不支持计算着色器，走的是简化版 | 检查 `graphics:GetComputeShaderSupport()` |
| 夜里雾是黑的 | 只有灯周围被照亮 | 提高 `skyLightVolumetricScatteringIntensity` |
