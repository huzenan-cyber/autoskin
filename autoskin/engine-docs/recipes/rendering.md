# 渲染配置说明

> UrhoX 渲染系统的关键配置：灯光预设 / 雾 / 天空盒
>
> 进阶专题：[天空与环境光](sky-and-environment-lighting.md) · [延迟渲染](deferred-rendering.md) · [灯光与阴影](lights-and-shadows.md) · [体积雾与体积光](volumetric-fog.md) · [后处理](post-processing.md) · [动态环境场景指南：昼夜 + 天气 + 打光](deferred-scene-weather-lighting.md)

---

## 灯光组 (LightGroup)

LightGroup 预设是一个 **打包好的"光照 + 大气"配置**——加载它就同时配好了方向光（太阳）、雾。多数项目直接用预设即可，不用自己创建 Light / Zone。

### 🔴 核心规则：LightGroup 已包含 Zone，不要重复创建

**LightGroup XML 内部结构**：

```
LightGroup node
├── Zone component         ← 环境光、雾效、IBL、Bloom、SH 光照
└── Directional Light node
    └── Light component    ← 主光源、阴影、CSM
```

**LightGroup 已经包含了完整的 Zone 和方向光配置**（其 Zone 的 priority=-1）。加载 LightGroup 后，场景中就已有 Zone，**不要再手动创建 Zone**——手动创建的 Zone 默认 priority=0，会覆盖 LightGroup 的 Zone，导致预设的 IBL、SH 光照、Bloom、雾效等参数全部丢失。如需调整 Zone 参数，应获取 LightGroup 中已有的 Zone（见下方示例）。

```lua
-- ✅ 正确：只加载 LightGroup，不创建额外的 Zone
local lightGroupFile = cache:GetResource("XMLFile", "LightGroup/Daytime.xml")
local lightGroup = scene_:CreateChild("LightGroup")
lightGroup:LoadXML(lightGroupFile:GetRoot())
-- 场景光照已完整配置，无需其他操作

-- ❌ 错误：加载 LightGroup 后又手动创建 Zone
local lightGroup = scene_:CreateChild("LightGroup")
lightGroup:LoadXML(lightGroupFile:GetRoot())
-- 新 Zone 的 priority=0 > LightGroup Zone 的 priority=-1
-- 整个 Zone 被替换，LightGroup 预设的全部参数（IBL、SH、Bloom、雾效等）都会丢失
local zone = scene_:CreateComponent("Zone")
zone.fogColor = Color(0.5, 0.6, 0.8)
```

### 加载后访问 Zone 和 Light

如果需要在运行时微调 LightGroup 中的参数：

```lua
-- 加载
local lightGroupFile = cache:GetResource("XMLFile", "LightGroup/Daytime.xml")
local lightGroup = scene_:CreateChild("LightGroup")
lightGroup:LoadXML(lightGroupFile:GetRoot())

-- 获取 Zone（第二个参数 true = 递归查找子节点）
local zone = lightGroup:GetComponent("Zone", true)
zone.fogColor = Color(0.5, 0.6, 0.8)        -- 调整雾色
zone.depthFogStart = 100                     -- 深度雾起始距离（米）
zone.depthFogEnd = 500                       -- 深度雾终止距离（米）
-- 注意：默认（AMBIENT_PREBAKED/AMBIENT_SKYBOX）模式下 ambientColor 不生效（shader 中被归零），
-- 环境光由 SH 球谐驱动，通过 LightGroup 预设配置。如需平铺纯色环境光，见下文"环境光烘焙"的 AMBIENT_COLOR 模式

-- 获取方向光（同样递归查找）
local light = lightGroup:GetComponent("Light", true)
light.brightness = 3.0                       -- 调整亮度
light.color = Color(1, 0.9, 0.8)            -- 调整光色
light.castShadows = true                     -- 开关阴影
```

### 可用预设

| 文件 | 说明 | 光色 | 亮度 |
|------|------|------|------|
| `LightGroup/Daytime.xml` | 白天（推荐默认） | 暖白 | 3 |
| `LightGroup/Dusk.xml` | 黄昏 | 橙色 | 5 |
| `LightGroup/Sandstorm.xml` | 沙尘暴 | 暖黄 | 6 |
| `LightGroup/Night.xml` | 夜晚 | 冷蓝 | 0.8 |
| `LightGroup/Midnight.xml` | 午夜 | 冷蓝 | 1.1 |
| `LightGroup/DarkNight.xml` | 暗夜 | 紫蓝 | 1.3 |
| `LightGroup/BloodNight.xml` | 血夜 | 冷白 | 0.55 |

**选择建议**：
- 一般 3D 场景 → `Daytime`
- 温暖氛围 → `Dusk` 或 `Sandstorm`
- 恐怖/悬疑 → `DarkNight` 或 `BloodNight`
- 宁静夜景 → `Night` 或 `Midnight`

### Zone 包含的主要能力

LightGroup 的 Zone 预设了一套可以直接用的基线：

- 远景雾效（深度雾；部分预设含高度雾）
- IBL 环境光照（球谐漫射光照 + 环境反射贴图）
- 泛光参数、暗角贴图（暗角默认**关闭**，需 `zone.vignetteEnabled = true`）
- 水面反射参数

预设**不包含**体积雾、运动模糊、SSGI、自动曝光等，需要时在拿到 Zone 后用属性开启，见 [post-processing.md](post-processing.md)、[volumetric-fog.md](volumetric-fog.md)。所有预设参数都可以在加载后用 Lua 属性覆盖。

### 雾效系统

Zone 支持两种雾效，可同时启用：

**深度雾/距离雾（Depth Fog）**：基于相机距离的线性雾，物体在 `depthFogStart`～`depthFogEnd`（米）之间逐渐被雾覆盖。`depthFogDensity` 控制深度雾的浓度（默认 1.0，仅影响深度雾，不影响高度雾），设为 0 等价于关闭深度雾，< 1.0 雾更稀薄，> 1.0 雾更浓厚。`depthFogEnable` 是开关。LightGroup 预设已配置，默认启用。

**高度雾（Height Fog）**：基于世界 Y 坐标的雾，低于 `heightFogHeight` 的区域产生雾效，`heightFogFalloff` 控制向上衰减的速度，`heightFogDensity` 控制浓度。需 `heightFogEnable = true` 显式开启。

两种雾共用 `fogColor`。

```lua
local zone = lightGroup:GetComponent("Zone", true)

-- 深度雾
zone.fogColor = Color(0.6, 0.7, 0.9)
zone.depthFogStart = 50       -- 起始距离（米）
zone.depthFogEnd = 300        -- 终止距离（米）
zone.depthFogDensity = 1.0    -- 深度雾浓度（默认 1.0，0=关闭深度雾，<1 稀薄 >1 浓厚，不影响高度雾）

-- 高度雾（需显式开启）
zone.heightFogEnable = true
zone.heightFogHeight = 5.0    -- 雾面高度（世界 Y 坐标，米）
zone.heightFogDensity = 1.0   -- 高度雾浓度
zone.heightFogFalloff = 0.12  -- 向上衰减速度，越大雾层越薄；预设取 0.1–0.16
```

> ⚠️ **只用上面这套 `depthFog*` / `heightFog*` 名字**（与 LightGroup XML 的 `Depth Fog Start`、`Height Fog Falloff` 等字段一一对应）。旧名字 `fogStart` / `fogEnd` / `fogDensity` / `fogHeight` / `heightFog` / `fogHeightScale` 仍可运行但已弃用，对照见下文"雾属性新旧名字对照"。
> ⚠️ **Zone 属性名写错不会报错**：例如 `zone.depthFogEnabled = false`（正确是 `depthFogEnable`）不报错，也不生效，读回来还"像是"设上了。写完用 LSP 诊断检查一遍。

> LightGroup 内部细节（XML 字段）由引擎管理，**Lua 层把它当黑盒**——加载就用，需要更细控制时按下面方法在 Lua 里覆盖。

### 环境光 / IBL / SH

LightGroup XML 里带有 **环境光球谐 (SphericalHarmonicsL2)、环境镜面反射 cubemap、环境贴图角度** 等。改法有三种：

| 需求 | 做法 |
|---|---|
| 整体换氛围（白天 → 夜晚） | 换 LightGroup 预设 |
| **天空会变**（昼夜、调色、自写 sky shader），环境光自动跟着变 | 在 Zone 节点上加 `SkyLightCapture`，见 [天空与环境光](sky-and-environment-lighting.md)。**动态天空首选** |
| 有**原始天空图**（全景图或 cubemap），希望环境光和天空一致 | `zone.sourceTexture = 天空图`，引擎自动烘焙 SH + IBL（见下文"自定义环境光"）。**静态天空首选** |
| 只换反射贴图 / 调强度 / 转角度 | `zone.envSpecTexture`、`zone.envTextureDiffIntensity`、`zone.envTextureSpecIntensity`、`zone.envCubeAngle` |

下面直接替换反射贴图的示例中，`<prefiltered-cubemap-resource-path>` 是占位符，必须替换为项目自备、已确认存在并随项目发布的预过滤镜面 IBL cubemap 资源路径（相对于资源根目录，不含 `assets/` 前缀）。没有这类资源时，保留预设的反射贴图，只调整强度。

```lua
-- 换预设
local lgNode = scene_:GetChild("LightGroup")  -- 必须先有已加载的 LightGroup
lgNode:RemoveAllComponents()  -- 清旧
local f = cache:GetResource("XMLFile", "LightGroup/Night.xml")
lgNode:LoadXML(f:GetRoot())

-- 使用项目自备的预过滤反射贴图；没有资源时省略下面的贴图赋值
zone.envSpecTexture = cache:GetResource("TextureCube", "<prefiltered-cubemap-resource-path>")
zone.envTextureDiffIntensity = 0.05   -- 漫反射（SH）强度
zone.envTextureSpecIntensity = 0.1    -- 镜面（IBL）强度
```

- ⚠️ **已经预滤波**的镜面 IBL cubemap 只用于 `envSpecTexture`；**不要**交给 `sourceTexture`，否则会被再卷积一次。`sourceTexture` 应使用未经预滤波的原始天空图。
- ⚠️ 实际旋转角 = `envCubeAngle + envCubeFollowAngle`。预设（如 `Daytime.xml`）自带非零的 `envCubeFollowAngle`；自己控制角度时两个都要设，例如都设为 0。
- 球谐系数本身没有 Lua 接口，只能来自预设、`sourceTexture` 烘焙或 `SkyLightCapture` 捕获。
- 优先级：`SkyLightCapture` 捕获结果 > `sourceTexture` 烘焙结果 > 预设 / `envSpecTexture`。

> ⚠️ **默认模式下 `zone.ambientColor` 是 no-op**——`AMBIENT_PREBAKED`/`AMBIENT_SKYBOX` 模式下引擎硬下发 `cAmbientColor=(0,0,0,0)`。要改环境光 / IBL / SH，用下文"环境光烘焙"的运行时方案（`AMBIENT_SKYBOX` 烘天空球、`sourceTexture` 烘指定纹理、`AMBIENT_COLOR` 平铺纯色），或切换 LightGroup 预设。

---

## 自建点光 / 追光（火把 / 车灯 / 室内灯）

LightGroup 只管太阳和环境，**点光（Point）和追光（Spot）必须自己建**。典型场景：火把、室内灯泡、车灯、手电、霓虹灯、爆炸光闪。

> ⚠️ 下方示例的 brightness 值需配合 **auto-exposure** 使用（`zone.autoExposureEnabled = true`），否则会过曝。详见下方"brightness 取值参考"。

```lua
-- 篝火光（Point Light）
local lightNode = scene_:CreateChild("Campfire")
lightNode.position = Vector3(5, 0.5, 0)
local light = lightNode:CreateComponent("Light")
light.lightType = LIGHT_POINT
light.color     = Color(1.0, 0.6, 0.2)   -- 暖橙色
light.brightness = 80                     -- 亮度（需开启 auto-exposure，见下方参考）
light.range     = 12.0                    -- 光照半径（米）
light.castShadows = false                 -- 点光阴影开销大，看需求
```

```lua
-- 手电 / 车灯（Spot Light）
local lightNode = cameraNode:CreateChild("Flashlight")
lightNode.direction = Vector3(0, 0, 1)
local light = lightNode:CreateComponent("Light")
light.lightType  = LIGHT_SPOT
light.color      = Color(1, 1, 1)
light.brightness = 3000                  -- Spot 较远距离需更高值（需开启 auto-exposure）
light.range      = 20.0
light.fov        = 45.0                   -- 光锥张角（度）
```

### brightness 取值参考

引擎衰减公式与 UE 一致（`1/(d²+1)` + 窗口函数），配合 auto-exposure 使用时 `brightness` 可直接对标 UE 的坎德拉量级。下面是经 UE 美术对齐后的推荐值：

| 用途 | brightness | range | 说明 |
|---|---|---|---|
| 暗房间小蜡烛 | 1 | 3 - 5 | 微弱暖光 |
| 室内灯泡 / 台灯 | 30 | 6 - 12 | 普通房间照明 |
| 火把（单根） | 25 - 30 | 5 - 8 | 小火焰，照亮周围几米 |
| 篝火（火堆） | 80 | 8 - 15 | 大火堆，照亮营地，能看到 bloom |
| 路灯 | 500 | 15 - 25 | 高杆照明 |
| 车灯 / 手电 | 3000 | 20 - 40 | 配 Spot + 较远 range |
| 爆炸 / 闪电瞬闪 | 5000+ | 视场景 | 短暂触发，配合 HDR/Bloom |

> **需要开启 auto-exposure**：`zone.autoExposureEnabled = true`（Zone 属性）。开启后引擎会自动调节曝光，上述值可直接使用。不开启 auto-exposure 时，这些值会严重过曝，需改用更小的经验值（蜡烛 ~0.5、台灯 ~5、篝火 ~8、路灯 ~30）。
>
> **何时开启 auto-exposure**：auto-exposure 会增加一个亮度直方图 RT，带宽接近翻倍。**推荐在以下场景开启**：场景有明暗区域切换（室内↔室外）、多种强度光源共存（蜡烛 + 路灯）、需要物理准确的灯光效果。**不建议开启的场景**：纯 2D 游戏、固定视角且光照不变的简单场景、对移动端性能敏感的项目。

---

## 自定义 Zone（覆盖雾参数）

**先问自己：能不能直接用现成 LightGroup 预设？**——能的话别建 Zone，加载 XML 就完事。需要换天气就换 XML（`Daytime.xml` → `Night.xml`）。

**真正需要自建 Zone 的场景**：

- **风格化的特殊效果**——预设里没有的，比如近距浓毒雾（depthFogStart=1.5, depthFogEnd=15）、地牢级深红雾色等
- **运行时动态调节**——根据天气系统/玩家行为实时改 fogColor / depthFogStart / depthFogEnd（LightGroup XML 是静态的）
- **局部分区雾**——同场景里室内 vs 室外不同雾密度，用 priority 高的小 bbox Zone 覆盖局部

### Zone 在 Lua 能设的属性

```lua
local zoneNode = scene_:CreateChild("Zone")
local zone = zoneNode:CreateComponent("Zone")

-- 必设：bbox 要覆盖玩家可能去的所有位置
zone.boundingBox  = BoundingBox(Vector3(-500, -500, -500), Vector3(500, 500, 500))

-- 雾：典型的"远景柔和大气雾"参数
zone.fogColor     = Color(0.55, 0.60, 0.65, 1.0)   -- 偏冷灰，跟天空淡蓝协调
zone.depthFogStart = 50.0                          -- 50m 开始有雾
zone.depthFogEnd   = 250.0                          -- 250m 完全融入雾色
-- zone.depthFogDensity = 1.0                       -- 深度雾浓度（默认 1.0，0=关闭深度雾，<1 稀薄 >1 浓厚，不影响高度雾）

-- 优先级：默认 0；大于 LightGroup 的 -1 即可自动接管（见下方"跟 LightGroup 共存"）
-- 多 Zone 重叠时数大者赢
zone.priority     = 0

-- 自动曝光（明暗区域切换时推荐开启，有性能开销）
-- zone.autoExposureEnabled = true

-- 高级（少见场景）
-- zone.override    = false      -- 见下方"farClip 陷阱"
-- zone.heightFogEnable  = false  -- 启用高度雾
-- zone.heightFogHeight  = 0      -- 高度雾雾面 Y
-- zone.heightFogFalloff = 0.12   -- 高度雾向上衰减速度
```

### 雾属性新旧名字对照

旧名字来自原版 Urho3D，仍可运行（读写同一个值），但已弃用，新代码统一用右列：

| 旧名字（弃用） | 用这个 | 说明 |
|---|---|---|
| `fogStart` | `depthFogStart` | 同一个值 |
| `fogEnd` | `depthFogEnd` | 同一个值 |
| `fogDensity` | `depthFogDensity` | 同一个值 |
| — | `depthFogEnable` | 深度雾开关（旧接口没有） |
| `heightFog` | `heightFogEnable` | 同一个值 |
| `fogHeight` | `heightFogHeight` | 同一个值 |
| `fogHeightScale` | `heightFogFalloff` | ⚠️ **差 100 倍**：`heightFogFalloff = fogHeightScale × 100`。预设 XML 的 `Height Fog Falloff`（0.1–0.16）对应 `heightFogFalloff` |
| — | `heightFogDensity` | 高度雾浓度（旧接口没有） |
| `fogColor` | `fogColor` | 不变，两种雾共用 |

对应的方法同理：`SetFogStart` → `SetDepthFogStart`、`SetHeightFog` → `SetHeightFogEnable` 等，旧方法在类型定义里标了 `@deprecated`。

### 怎么选参数

| 场景类型 | depthFogStart / depthFogEnd | fogColor 风格 |
|---|---|---|
| **晴天 / 清晰远景** | 80 / 300+ | 跟天空淡蓝一致（0.5-0.7 灰蓝）|
| **阴天 / 雾蒙蒙** | 30 / 150 | 浅灰白（约 0.6, 0.6, 0.65）|
| **夜晚** | 20 / 100 | 暗蓝（约 0.05, 0.08, 0.15）|
| **浓雾 / 视野受限** | 5 / 40 | 跟环境基调匹配（沙暴用暖色、有毒环境用异色等）|

数值是参考起点，按实际场景调整。需要"几乎贴脸都看不清"的极端浓雾场景，可以下到 depthFogStart=2 / depthFogEnd=15。

**boundingBox 选择**：取相机能去到的最远位置 + 余量。如果不确定就 ±1000 兜底（覆盖大多数游戏世界）。

### 跟 LightGroup 共存：自动按 priority 覆盖

LightGroup 预设里带的 Zone 是 **`priority = -1`**（背景级）。任意新建 Zone 默认 `priority = 0`，自动赢——所以加载了 LightGroup 之后**直接建自己的 Zone 就行，不用清理 LightGroup**。

```lua
-- 加载 LightGroup（带个低优先级 Zone）
local lightGroupFile = cache:GetResource("XMLFile", "LightGroup/Daytime.xml")
local lightGroup = scene_:CreateChild("LightGroup")
lightGroup:LoadXML(lightGroupFile:GetRoot())

-- 直接建自己的 Zone，priority=0 > LightGroup 的 -1，自动覆盖
local zoneNode = scene_:CreateChild("Zone")
local zone = zoneNode:CreateComponent("Zone")
-- ...按上面"Zone 在 Lua 能设的属性"里的方式设置 fog 等
```

> 自建 Zone 没生效（看到的还是 LightGroup 的雾）？检查相机当前位置是否在你的 Zone bbox 内。Zone 是按"相机位置在哪个 Zone 内 → 该 Zone 接管"判定的。

### ⚠️ 雾"看不见" / "再远也清晰"的两个陷阱

#### 1. fogColor 跟天空盒地平线色不一致 → 远处看到色差线

雾把远处物体染成 fogColor。如果同时有天空盒，天空底部颜色 ≠ fogColor → 地平线一道明显接缝。

**协调原则**：让天空盒的地平线颜色 ≈ fogColor，过渡才自然。

#### 2. `camera.farClip` 远超 Zone bbox → 远端 fog 被引擎稀释

引擎逻辑：每个物体根据自身位置找所属 Zone。远处物体超出你 Zone 的 bbox 时 → 被分配到 LightGroup 的低优先级 Zone 或引擎默认 Zone（不同的 fog 参数）→ 远端 fog 突然变淡或变色。

**修法二选一**：
- 把 Zone bbox 加大到覆盖 farClip 范围（推荐，简单）
- 或显式 `zone.override = true`（让引擎跳过远端 Zone 查找）

```lua
-- 例：相机 farClip = 2000，Zone bbox 至少要 ±2000
zone.boundingBox = BoundingBox(Vector3(-2000,-2000,-2000), Vector3(2000,2000,2000))
-- 或：
zone.override = true
```

---

## 自定义天空盒

LightGroup 预设 **不包含天空盒**——它配置的是背景纯色（来自 Zone.fogColor）。要可见的天空（渐变 / cubemap 全景）必须额外创建。

> **新项目优先用 `ProceduralSky` 组件**：一行创建带太阳的程序化天空，参数对标 Godot，可绑定方向光当太阳；配合 `SkyLightCapture`，环境光自动跟随天空。见 [天空与环境光](sky-and-environment-lighting.md)。下面的 `SkyUtils` 渐变天空和 cubemap 天空盒仍然可用。

### 模型 + Technique 的对应关系

天空盒统一使用 **`Box.mdl` + `Techniques/DiffSkybox.xml`**。Skybox shader 在 **postopaque pass** 渲染、**不计算雾**——天空与雾彻底解耦，无论 fog 多浓天空都正常可见。

| 想要的效果 | 贴图来源 |
|---|---|
| **程序化渐变天空**（天顶→地平线→地面 三色过渡）| 运行时生成 cubemap（见下方 `MakeGradientCubemap`）|
| **Cubemap 全景**（星空、云海、日落照片、HDRI 全景）| 从文件加载 cubemap（`.xml` 描述 6 面 `.dds`）|

### ⚠️ 别用 `DiffUnlit.xml` 当天空 technique

```lua
-- ❌ 错误：DiffUnlit 是普通几何体 shader，会按距离应用雾
--   用了它，近距浓雾下天空被染成 fogColor，再也看不见
mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/DiffUnlit.xml"))
```

### 程序化渐变天空（推荐做法）

运行时生成 6 面 cubemap，颜色由**视线仰角**决定——全方位无缝，不受相机旋转影响。

```lua
local SkyUtils = require "urhox-libs.Rendering.SkyUtils"

-- 白天（使用内置预设）
SkyUtils.CreateGradientSky(scene_, SkyUtils.Presets.Day)

-- 黄昏
SkyUtils.CreateGradientSky(scene_, SkyUtils.Presets.Sunset)

-- 自定义配色
SkyUtils.CreateGradientSky(scene_, {
    zenith   = Color(0.06, 0.18, 0.52),  -- 天顶色
    horizon  = Color(0.28, 0.52, 0.82),  -- 地平线色（建议 == fogColor）
    ground   = Color(0.15, 0.25, 0.35),  -- 地面色（可选，默认 horizon × 0.7）
    skyExp   = 0.5,                       -- 渐变指数（<1 集中在地平线，>1 更平）
    hdrBoost = 2.0,                       -- ACES 曝光补偿（默认 2.0）
})
```

> 颜色只是参考，实际项目应由美术根据场景风格调整。`hdrBoost` 补偿 Skybox shader 的 ACES 色调映射——不加的话天空会偏暗偏灰。

**底层 API**（需要更细控制时）：

```lua
local SkyUtils = require "urhox-libs.Rendering.SkyUtils"
-- 只生成 cubemap 贴图，不创建节点
local tex = SkyUtils.MakeGradientCubemap({ zenith = ..., horizon = ... })
-- 自己创建材质和 Skybox 节点
```

### Cubemap 全景天空

```lua
local mat = Material:new()
mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/DiffSkybox.xml"))
-- 替换为你的 cubemap 资源路径（.xml 描述 6 面 .dds/.png）
mat:SetTexture(TU_DIFFUSE, cache:GetResource("TextureCube", "Textures/YourSkybox.xml"))
-- 注意：文件加载的 DDS cubemap 通常已是 HDR 值，不需要 MatDiffColor boost
-- （仅程序化生成的 LDR cubemap 才需要 MatDiffColor=2x 补偿 ACES）

local skyNode = scene_:CreateChild("Sky")
local skybox = skyNode:CreateComponent("Skybox")
skybox:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
skybox:SetMaterial(mat)
```

### 预制 Cubemap 天空球

官方预制了多款 cubemap 天空球资源，通过 `uuid://` 协议直接加载，无需自备贴图。

#### 可用预设

**写实风格**：

| UUID | 说明 |
|------|------|
| `uuid://E4ehad-5axjv7Ml9zasxNx06` | 写实天空 A |
| `uuid://E_LhMeSIwE-bKC9lR3h2XYq1` | 写实天空 B |
| `uuid://ENC1IXaQqFYisE64aHW9CwX0` | 写实天空 C |
| `uuid://GNxJASZSCM8_0Qv-m3hrFG9c` | 写实天空 D |

**卡通风格**：

| UUID | 说明 |
|------|------|
| `uuid://FLDDYX_pywJHfYE8c3Jwx0vF` | 卡通天空 A |
| `uuid://GJ8nsQ8Du2jNH7SS-dkUFW8K` | 卡通天空 B |
| `uuid://G66LIcifaqH6u2b4cR-wnXd9` | 卡通天空 C |
| `uuid://HNmLET7gY1d6IAwqWCyBqzZz` | 卡通天空 D |
| `uuid://ENfIIRN-9-n9fRN85B3Axnif` | 卡通天空 E |

#### 用法

```lua
-- 加载预制 cubemap 天空球（以写实风格 A 为例）
local mat = Material:new()
mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/DiffSkybox.xml"))
mat:SetTexture(TU_DIFFUSE, cache:GetResource("TextureCube", "uuid://E4ehad-5axjv7Ml9zasxNx06"))

local skyNode = scene_:CreateChild("Sky")
local skybox = skyNode:CreateComponent("Skybox")
skybox:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
skybox:SetMaterial(mat)
```

**选择建议**：
- PBR / 写实渲染风格 → 写实天空
- 低多边形 / 卡通渲染风格 → 卡通天空
- 不确定 → 先试 `uuid://E4ehad-5axjv7Ml9zasxNx06`（写实天空 A），风格最通用

---

## 常见视觉问题排查

| 症状 | 原因 | 修法 |
|---|---|---|
| 程序化天空颜色偏暗偏灰 | Skybox shader 内部做 ACES 色调映射，LDR 值（0~1）被过度压缩 | `mat:SetShaderParameter("MatDiffColor", Variant(Vector4(2.0, 2.0, 2.0, 1.0)))` 推到 HDR 范围 |
| fogColor 设了饱和色（红/粉）→ 整个场景都染成那个颜色 | fog 不只影响天空地平线——**所有超过 depthFogStart 的物体都会被染成 fogColor** | fogColor 用低饱和的自然色（灰蓝/灰白/暖灰），避免纯色 |
| 远处物体的 fog 突然变色或消失 | 远处物体超出 Zone bbox → 被分配到 LightGroup 的 Zone（不同 fog） | 加大 Zone bbox 覆盖 farClip，或 `zone.override = true` |

---

## 自定义环境光

Zone 支持运行时从天空球或指定纹理自动生成环境光照（漫射 SH + 镜面反射 IBL），在后台异步完成，不阻塞主线程。适用于需要让环境反射和漫射光照匹配场景天空的场景。

### 环境光来源模式

| 模式 | 说明 |
|------|------|
| `AMBIENT_PREBAKED`（默认） | 使用预烘焙的 SH 系数和 specular cubemap（由 LightGroup 或手动设置） |
| `AMBIENT_SKYBOX` | 自动从场景 Skybox 组件的**贴图**（`TU_DIFFUSE` cubemap）获取 cubemap 并烘焙 SH + IBL。天空是 sky shader（`ProceduralSky` 或自写）时没有贴图可取，改用 `SkyLightCapture` |
| `AMBIENT_COLOR` | 平铺纯色环境光：直接把 `ambientColor` 喂给 shader 的 `cAmbientColor`，给整个场景一个均匀环境光项。不做烘焙，无需纹理 |

### 基本用法

```lua
-- 方式 1：自动从 Skybox 烘焙（最简单）
zone.ambientSource = AMBIENT_SKYBOX
zone.ambientIntensity = 1.0
-- View.cpp 自动找到场景中的 Skybox，获取其纹理并触发后台烘焙

-- 方式 2：手动指定源纹理
zone.ambientSource = AMBIENT_PREBAKED
local cubemap = cache:GetResource("TextureCube", "Textures/MySky.ktx")
zone.sourceTexture = cubemap      -- 触发后台烘焙
zone.ambientIntensity = 1.0

-- 方式 3：使用全景图（Texture2D 自动转 cubemap）
local panorama = cache:GetResource("Texture2D", "Textures/Environment.hdr")
zone.sourceTexture = panorama     -- 自动转 cubemap 后烘焙

-- 方式 4：平铺纯色环境光（无需纹理/烘焙）
zone.ambientSource = AMBIENT_COLOR
zone.ambientColor = Color(0.3, 0.3, 0.35)   -- 直接喂给 shader 的 cAmbientColor
-- 整个场景收到一个均匀环境光项，适合卡通/低成本光照或快速调试
```

### 参数说明

| 属性 | 类型 | 说明 |
|------|------|------|
| `ambientSource` | `AmbientSource` | 环境光来源模式（`AMBIENT_PREBAKED` / `AMBIENT_SKYBOX` / `AMBIENT_COLOR`） |
| `ambientColor` | `Color` | 平铺纯色环境光的颜色，仅在 `AMBIENT_COLOR` 模式下生效。喂给 `cAmbientColor` |
| `sourceTexture` | `Texture*` | 源纹理，可以是 TextureCube 或 Texture2D（全景图）。填入后自动触发后台烘焙 |
| `ambientIntensity` | `float` | 统一的环境光强度（同时设置漫射和镜面反射强度）。**注意**：`AMBIENT_COLOR` 模式下漫反射强度恒为 1.0，`ambientIntensity` 只影响镜面反射强度，平铺环境光的亮度由 `ambientColor` 本身控制 |

### 内置原始天空图

引擎随附 4 张原始全景 HDR 天空（CC0，来源见 `Res/Sky/README.md`），可直接作为 `sourceTexture`：

| 路径 | 用途 |
|---|---|
| `Sky/ClearDay.hdr` | 晴天正午 |
| `Sky/Dusk.hdr` | 黄昏 |
| `Sky/Night.hdr` | 夜晚 |
| `Sky/Overcast.hdr` | 阴天 |

```lua
zone.sourceTexture = cache:GetResource("Texture2D", "Sky/Dusk.hdr")
zone.ambientIntensity = 1.0     -- 夜晚建议 0.1–0.3：这几张图的绝对亮度差别不大，明暗靠强度控制
```

每张图第一次使用时烘焙一次（后台，约 1 秒），之后切换即时生效。昼夜切换时按时段换图即可。

### 烘焙行为

- **后台异步**：烘焙在后台线程中执行，不阻塞渲染
- **缓存复用**：相同纹理的烘焙结果会被自动缓存，再次设置同一纹理时即时生效，无需重复烘焙
- **状态恢复**：烘焙结果与预烘焙数据独立存储，将 `ambientSource` 切回 `AMBIENT_PREBAKED` 时自动恢复预烘焙数据
- **全景图支持**：`sourceTexture` 设置 Texture2D 时自动在后台执行全景图→cubemap 转换后再烘焙
- **运行时生成的纹理**：没有资源文件的纹理（例如 `SkyUtils.CreateGradientSky` 生成的 cubemap、Lua 里用 `SetData` 写出的全景图）也能作为源。引擎会从 GPU 异步回读后再烘焙，通常需要几帧。`AMBIENT_SKYBOX` + `SkyUtils` 天空因此可以直接得到匹配的环境光
- **内容更新**：对同一张运行时纹理重新写入像素后，缓存不会自动感知，需要显式重新烘焙：

```lua
tex:SetData(face, newImage)                      -- 改写了源纹理
environmentBakeCache:InvalidateSource(tex)       -- 丢弃旧结果
zone.sourceTexture = nil                         -- 让 Zone 重新请求
zone.sourceTexture = tex
```

- **限制**：运行时纹理需要真实 GPU（headless / 无渲染器时直接失败）；cubemap 还需要显卡支持纹理 blit（桌面 DX11 / GL 已验证）。渲染目标（RenderTexture）作为源在 OpenGL 上可能上下颠倒，暂不建议使用

### 注意事项

- LightGroup 预设已包含预烘焙的 SH 和 specular cubemap，使用 `AMBIENT_SKYBOX` 模式会覆盖预设值（切回 `AMBIENT_PREBAKED` 可恢复）
- 同一 Zone 上有 `SkyLightCapture` 时，捕获结果优先于这里的烘焙结果；烘焙结果只在首次捕获完成前作为过渡
- `ambientIntensity` 默认值为 0.3，使用烘焙模式时通常需要设为 1.0 以获得正确亮度

---

## 后效（Post Effects）

后效全部挂在 **Zone 组件**上。加载 LightGroup 后，从中拿到 Zone 再操作：

```lua
local lightGroup = scene_:CreateChild("LightGroup")
lightGroup:LoadXML(cache:GetResource("XMLFile", "LightGroup/Daytime.xml"):GetRoot())
local zone = lightGroup:GetComponent("Zone", true)
```

游戏脚本可调的后效：

| 后效 | 用途 | 默认 |
|---|---|---|
| Vignette | 暗角，氛围感 | OFF |
| AutoExposure | 室内↔室外明暗自动适配 | OFF |
| GaussianBlur | 全屏模糊，做暂停菜单/弹窗背景虚化 | OFF |
| Tonemap | HDR 色调映射：ACES 曲线或 3D LUT | LUT（见下文回落） |

### Vignette（暗角）

LightGroup 预设里已经内置 vignette 贴图，直接开即可：

```lua
zone.vignetteEnabled   = true
zone.vignetteIntensity = 1.0   -- 默认 1.0 适合大多数场景；值越大暗角越浓
```

`vignetteIntensity` 与暗角浓度成正比：

| 视感 | `vignetteIntensity` |
|---|---|
| 柔和暗角（默认，绝大多数场景） | 1.0 |
| 较浓 | 2 ~ 3 |
| 电影感 | 4 ~ 5 |
| 大面积压黑 | 6+ |

需要换贴图时（中心高亮、四角偏暗的灰度 PNG）：

```lua
zone.vignetteTexture = cache:GetResource("Texture2D", "Textures/MyVignette.png")
```

### AutoExposure（自动曝光）

```lua
zone.autoExposureEnabled = true
```

适合：场景有明暗切换（如室内↔室外、白天↔夜晚切换）、需要物理光照单位的项目。
不适合：纯 2D、固定光照的简单场景、性能敏感的低端设备——会增加一组亮度直方图 RT，约一个全屏 pass 开销。

### GaussianBlur（全屏模糊）

典型用法：游戏暂停时把整个场景虚化，再叠菜单 UI 上去。

```lua
-- 暂停时
zone:SetAttribute("Gaussian Blur Enable", Variant(true))

-- 恢复时
zone:SetAttribute("Gaussian Blur Enable", Variant(false))
```

⚠️ 这个开关目前只能走 `SetAttribute`，没有 Lua property。泛光总开关 `Bloom Enable` 也一样；关掉它会连带关掉色调映射、暗角和曝光，见 [post-processing.md](post-processing.md)。

### Tonemap（色调映射）

HDR 合成时把亮度压到显示器范围。`zone.tonemapMode` 默认是 `TONEMAP_MODE_LUT`：

```lua
zone.tonemapMode = TONEMAP_MODE_NONE   -- Bloom 合成不 tonemap
zone.tonemapMode = TONEMAP_MODE_ACES   -- 解析 ACES filmic 曲线
zone.tonemapMode = TONEMAP_MODE_LUT    -- 属性默认：尝试 3D LUT
```

| 模式 | 值 | 效果 |
|---|---|---|
| `TONEMAP_MODE_NONE` | 0 | 不 tonemap（ACES / LUT 都不走） |
| `TONEMAP_MODE_ACES` | 1 | ACES filmic 曲线 |
| `TONEMAP_MODE_LUT` | 2 | 3D LUT 采样（属性默认） |

`NONE` 只关 Bloom 最终合成里的 tonemap，天空盒 / 粒子里自带的 `toAcesFilmic` 不受影响。HDR 高光不会被压到 0~1，LDR 目标上容易过曝裁切。

⚠️ `NONE` 会连带让 `autoExposureEnabled` 失效：曝光缩放只在 tonemap 分支里应用（shader 的 `#ifndef DISABLE_TONEMAPPINGS`），直方图 pass 仍在跑但不影响画面。

LUT **实际生效**还要同时满足下面两条，否则静默走 ACES（不报错）：

1. **桌面端**（`DESKTOP_GRAPHICS`）。iOS / Android / surfaceless（按 GLES/移动端编译）没有 LUT 路径，选 LUT 也会走 ACES。
2. **LUT 资源加载成功**。Zone 未指定 LUT 时，引擎会懒加载内置的 `Textures/TonemapLut.cube`（随引擎 `Res/` 资源目录一同发布），因此项目通常无需自行提供 LUT。只有裁剪后的部署未包含该默认资源，或资源加载失败时，才会静默回落 ACES。

旧接口 `zone.tonemapLUTEnabled` 仍可用（`true` = LUT，`false` = ACES）。新脚本请用 `tonemapMode`。

### 综合示例：夜景 + 暗角 + 自动曝光

```lua
local lg = scene_:CreateChild("LightGroup")
lg:LoadXML(cache:GetResource("XMLFile", "LightGroup/Night.xml"):GetRoot())
local zone = lg:GetComponent("Zone", true)

zone.autoExposureEnabled = true
zone.vignetteEnabled     = true
zone.vignetteIntensity   = 2.0   -- 比默认略浓
```

---

## 相关文档

- [材质列表](./materials.md) — 物体材质（PBR）
- [天空与环境光](./sky-and-environment-lighting.md) — ProceduralSky、SkyLightCapture（环境光实时跟随天空）、自写 sky shader
- [延迟渲染](./deferred-rendering.md) — 管线选择、延迟独有效果、平台限制
- [灯光与阴影](./lights-and-shadows.md) — 灯光类型、级联阴影、局部光阴影、时域阴影
- [体积雾与体积光](./volumetric-fog.md) — 光柱、灯光光晕、局部雾团
- [后处理](./post-processing.md) — SSR / SSGI / GTAO / 运动模糊 / 泛光 / 曝光 / 景深
- [动态环境场景指南](./deferred-scene-weather-lighting.md) — 昼夜 + 天气 + 打光规范 + 体积光 + 水面

---

[返回文档索引](../index.md)
