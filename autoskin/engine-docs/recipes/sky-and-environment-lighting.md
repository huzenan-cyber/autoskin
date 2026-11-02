# 天空与环境光

> 做一个会变的天空，并让场景的环境光（漫反射 + 反射）自动跟着天空变：`ProceduralSky`、`SkyLightCapture`、自写 sky shader、原始天空图。
> 灯光组 / 雾 / 老式渐变天空盒见 [rendering.md](rendering.md)；昼夜与天气的整体做法见 [deferred-scene-weather-lighting.md](deferred-scene-weather-lighting.md)。
> 可运行示例：[examples/29-procedural-sky](../../examples/29-procedural-sky)（时间滑条驱动昼夜，可开关环境光捕获做对比）。
> 自写 sky shader + 捕获的完整案例：[examples/30-pelican-bike](../../examples/30-pelican-bike)（云、星空、月亮、闪电，环境光随天空变化）。

---

## 1. 先选方案

| 想要 | 用什么 | 环境光从哪来 |
|---|---|---|
| **会变的天空**（昼夜、调色），环境光自动跟随 | `ProceduralSky` + `SkyLightCapture` | 实时捕获天空 |
| 自己写的 sky shader（云、星空、极光…），环境光自动跟随 | Skybox + `shader_type sky` + `SkyLightCapture` | 实时捕获天空 |
| 固定的照片天空（HDR 全景图） | Skybox 显示 + `zone.sourceTexture` | 烘焙一次，之后零开销 |
| 只要背景色，不要可见天空 | LightGroup 预设 | 预设自带的 SH + 反射图 |
| 物理大气天空 + 体积云（可自定义云材质） | `SkyAtmosphere` + `VolumetricCloud`，见 [云材质](surface-shader-addons/cloud.md) 第 1 节 | 本页未覆盖；云配方只讲云 |

一句话：**天空要动，就加 `SkyLightCapture`**；天空不动，用 `sourceTexture` 或预设就够了。

---

## 2. 最小可运行示例：ProceduralSky + SkyLightCapture

```lua
-- 环境：Zone 和 SkyLightCapture 放在同一个节点上
local env = scene_:CreateChild("Env")
local zone = env:CreateComponent("Zone")
zone.boundingBox = BoundingBox(-1000, 1000)
zone.fogColor = Color(0.6, 0.62, 0.66)       -- 雾色尽量接近天空地平线色
zone.envTextureDiffIntensity = 1.0            -- 捕获结果是真实亮度，强度用 1
zone.envTextureSpecIntensity = 1.0
env:CreateComponent("SkyLightCapture")

-- 太阳：天空里的太阳跟随这盏方向光
local sunNode = scene_:CreateChild("Sun")
sunNode.direction = Vector3(-0.5, -0.6, 0.4)
local sun = sunNode:CreateComponent("Light")
sun.lightType = LIGHT_DIRECTIONAL
sun.color = Color(1.0, 0.92, 0.8)
sun.brightness = 3.0

-- 天空：自动在这个节点上创建 Skybox
local sky = scene_:CreateChild("Sky"):CreateComponent("ProceduralSky")
sky.sunLight = sun
```

效果：天空有渐变和太阳；镜面物体反射出天空，粗糙物体和地面的环境光带着天空的颜色。之后**只改天空参数或转动太阳**，环境光会自己更新，不需要任何烘焙调用。

---

## 3. ProceduralSky

程序化渐变天空 + 太阳，参数与 Godot 4 的 ProceduralSkyMaterial 一致（默认值也一样）。

- 挂到节点上时：节点已有 Skybox 就复用，没有就创建一个；把它的材质换成内置天空 shader。
- 禁用组件会隐藏这个 Skybox。
- 颜色是 **sRGB**，和取色器里看到的一样（内部转线性）。

| 属性 | 默认 | 说明 |
|---|---|---|
| `skyTopColor` | (0.385, 0.454, 0.55) | 天顶色 |
| `skyHorizonColor` | (0.646, 0.656, 0.671) | 天空在地平线处的颜色 |
| `skyCurve` | 0.15 | 地平线色向上过渡的快慢，越小地平线色越窄 |
| `skyEnergy` | 1 | 天空颜色倍数 |
| `groundBottomColor` | (0.2, 0.169, 0.133) | 正下方的颜色 |
| `groundHorizonColor` | (0.646, 0.656, 0.671) | 地面在地平线处的颜色 |
| `groundCurve` | 0.02 | 地面过渡曲线 |
| `groundEnergy` | 1 | 地面颜色倍数 |
| `sunLight` | nil | 当作太阳的方向光；方向、颜色、亮度每帧跟随。只接受方向光 |
| `sunDiskSize` | 0.5 | 日盘视直径（度） |
| `sunAngleMax` | 30 | 光晕消失的角半径（度） |
| `sunCurve` | 0.15 | 光晕衰减曲线 |
| `sunEnergy` | 1 | 太阳亮度 = 灯光颜色 × 亮度 × sunEnergy |
| `exposure` | 1 | 整体倍数 |

昼夜示例（每帧调用）：

```lua
function UpdateSky(hour)
    local a = (hour - 6) / 12 * math.pi
    sunNode.direction = Vector3(-math.cos(a), -math.sin(a), -0.3)
    local day = math.max(0, math.min(1, math.sin(a) * 3))            -- 0 夜 .. 1 白天
    sky.skyTopColor = Color(0.02, 0.03, 0.08):Lerp(Color(0.25, 0.45, 0.85), day)
    sky.skyHorizonColor = Color(0.95, 0.55, 0.3):Lerp(Color(0.65, 0.75, 0.9), day)
    sun.brightness = 3.0 * day
    zone.fogColor = sky.skyHorizonColor                               -- 雾和天空同色，没有接缝
end
```

- 值没变就不会触发重新捕获，所以每帧写相同的值没有代价。
- 颜色是 sRGB：夜空别用 0.01–0.04 这种"线性"小值（转线性后几乎是纯黑），取 0.06–0.3 左右。
- 太阳在地平线以下时，把 `sun.brightness` 降到 0 或禁用灯光，天空里的太阳也会消失。

---

## 4. SkyLightCapture

把场景里的天空（任意 Skybox：`ProceduralSky`、自写 sky shader、cubemap 天空盒都行）实时渲染成环境光，交给**同一节点上的 Zone**。

| 属性 / 方法 | 默认 | 说明 |
|---|---|---|
| `updateMode` | `SKY_CAPTURE_ON_CHANGE` | 何时重新捕获，见下表 |
| `minCaptureInterval` | 0.25 | ON_CHANGE 下两次捕获之间的最短间隔（秒）。0 = 变了就马上捕获 |
| `resolution` | 128（移动端 64） | 每面分辨率，16–256，2 的幂 |
| `timeSliced` | true | 把一次捕获摊到约 9 帧完成 |
| `skybox` | nil | 指定要捕获的 Skybox；nil 取场景里启用、且在 `viewMask` 范围内的那个。范围内应当**只有一个**启用的天空；有多个时属于错误用法：全部会被画进环境光、只监视其中一个（不保证是哪个）的变化，并打警告 |
| `viewMask` | 全开（`0xFFFFFFFF`） | 捕获相机的 view mask，只捕获 `viewMask` 有交集的 Skybox。场景里有多个天空时用它区分，见下文 |
| `RequestCapture()` | — | 手动要求捕获一次（忽略最短间隔） |
| `ready` / `capturing` | — | 是否已有结果 / 是否正在捕获 |
| `capturedCubemap` | — | 当前发布的反射 cubemap |
| `supported` | — | 当前设备能否捕获 |

| `updateMode` | 何时捕获 | 适合 |
|---|---|---|
| `SKY_CAPTURE_ON_CHANGE` | 启动时一次；之后天空材质、参数、贴图或 Skybox 旋转变了才捕获（最多每 `minCaptureInterval` 秒一次）。shader 里用了 `TIME` 的天空视为一直在变 | **默认，绝大多数情况** |
| `SKY_CAPTURE_CONTINUOUS` | 一次接一次不停捕获 | 天空内容来自渲染目标等引擎看不到的变化 |
| `SKY_CAPTURE_MANUAL` | 只在 `RequestCapture()` 时 | 自己完全控制时机 |

行为要点：

- **天空不动时零开销**。天空一直在变（昼夜循环）时，参考开销：桌面 DX11、128 分辨率、默认间隔 0.25 秒，GPU 每帧约 +0.2~0.25 ms。
- 变化不会堆积：同一时间只有一次捕获，下一次总是拿最新的天空。延迟最多约一个间隔 + 一次捕获（默认约 0.4 秒）。
- 首次捕获完成前（通常零点几秒），Zone 使用它原有的环境数据（预设或 `sourceTexture` 结果），所以画面不会黑一下。
- 捕获结果按世界方向对齐，生效期间 `envCubeAngle` / `envCubeFollowAngle` 不起作用，**不需要**再调旋转角。
- 捕获结果是天空的真实亮度，`zone.envTextureDiffIntensity` / `envTextureSpecIntensity` 用 1；要整体压暗/提亮就改这两个值。
- 禁用或移除组件后，Zone 回到它原有的环境数据。天空被禁用、移除或不在 `viewMask` 范围内时也一样，天空恢复后会重新捕获。
- 每个节点只放一个 SkyLightCapture，多出来的会打警告并且不工作。
- 不支持的设备（`capture.supported == false`，如无 GPU 的服务端、部分老设备）上组件什么都不做，Zone 维持原样。要兜底就在这种情况下自己设 `envSpecTexture`。

下面的 `<prefiltered-cubemap-resource-path>` 是占位符，必须替换为项目自备、已确认存在并随项目发布的预过滤镜面 IBL cubemap 资源路径（相对于资源根目录，不含 `assets/` 前缀）。没有这类资源时，省略兜底分支，保留 Zone 原有环境数据。

```lua
local capture = env:CreateComponent("SkyLightCapture")
capture.minCaptureInterval = 0.5      -- 昼夜变化慢，捕获更稀疏
if not capture.supported then
    zone.envSpecTexture = cache:GetResource("TextureCube", "<prefiltered-cubemap-resource-path>")
    zone.envTextureSpecIntensity = 0.3
end
```

### 场景里有多个天空：用 viewMask 区分

捕获画的是**所有**在 `viewMask` 范围内、处于启用状态的 Skybox，不只是 `skybox` 指定的那一个。所以只有一个天空时不用管 `viewMask`；同时开着多个天空（比如主画面一个、小地图或画中画相机另一个）时，要给它们分配不同的位，并让捕获和主相机用同一个 mask：

```lua
local MAIN_SKY = 0x1
local MINIMAP_SKY = 0x2

mainSky.viewMask = MAIN_SKY                -- Skybox（ProceduralSky 用 sky.skybox 取到它）
minimapSky.viewMask = MINIMAP_SKY

-- 相机的 viewMask 要包含场景里其他物体的位，这里只去掉对方的天空
mainCamera.viewMask = 0xFFFFFFFF & ~MINIMAP_SKY
minimapCamera.viewMask = 0xFFFFFFFF & ~MAIN_SKY

capture.viewMask = mainCamera.viewMask     -- 环境光只来自主画面看到的天空
```

- 范围内有不止一个启用的天空时，开始捕获会打一条警告（`... enabled skyboxes match the view mask ...`）。看到它就说明有天空重叠画进了环境光：关掉多余的，或者按上面分配 mask。
- 改 `capture.viewMask` 会触发一次重新捕获。
- `ProceduralSky` 会自己在节点上建一个 Skybox。要用自己配置好的 Skybox（比如先设好 `viewMask`），就在**添加 ProceduralSky 之前**把 Skybox 加到同一节点上，它会被接管；之后再加的 Skybox 不会被接管，节点上会出现两个天空。

---

## 5. 自写 sky shader

`shader_type sky;` 的 SurfaceShader 可以直接被捕获。两条规则：

1. **天空的变化要通过材质参数（uniform）驱动**，引擎才能检测到变化。只靠 `TIME` 的天空会按 `minCaptureInterval` 定期重新捕获。
2. 捕获时 `AT_CUBEMAP_PASS` 为 true，可以借此把不适合进环境光的东西去掉，例如极亮的小日盘（直射光已经由太阳光源负责，亮斑进入反射只会带来噪点）：

```glsl
shader_type sky;
uniform vec3 zenith_color = vec3(0.08, 0.25, 0.62);
uniform vec3 horizon_color = vec3(0.45, 0.62, 0.90);
uniform vec3 sun_direction = vec3(0.0, 0.5, 0.8);

void sky() {
    vec3 d = normalize(EYEDIR);
    vec3 col = mix(horizon_color, zenith_color, pow(max(d.y, 0.0), 0.45));
    float mu = max(dot(d, normalize(sun_direction)), 0.0);
    col += vec3(1.0, 0.9, 0.7) * pow(mu, 48.0) * 0.5;                      // 光晕：保留
    if (!AT_CUBEMAP_PASS) {
        col += vec3(1.0, 0.9, 0.7) * smoothstep(0.9994, 0.9997, mu) * 40.0; // 日盘：只在画面里画
    }
    COLOR = col;
}
```

```lua
local skyMat = Material:new()
skyMat:SetSurfaceShader("Shaders/BLGL/MySky.shader")
local skybox = scene_:CreateChild("Sky"):CreateComponent("Skybox")
skybox.model = cache:GetResource("Model", "Models/Box.mdl")
skybox.material = skyMat
-- 每帧（或变化时）下发参数；值没变不会触发捕获
skyMat:SetShaderParameter("sun_direction", Variant(sunDir))
```

---

## 6. 照片天空（静态）

天空不变时不需要实时捕获。把原始全景图交给 Zone 烘焙一次即可（见 [rendering.md](rendering.md)"自定义环境光"）。

下面使用引擎随附的原始 HDR 全景图 `Sky/ClearDay.hdr`，也可替换为项目自备的 HDR 全景图。使用自备资源时，须确认资源存在并随项目发布，路径相对于资源根目录，不含 `assets/` 前缀：

```lua
zone.sourceTexture = cache:GetResource("Texture2D", "Sky/ClearDay.hdr")
zone.ambientIntensity = 1.0
```

同一场景里既有 `sourceTexture` 又有 `SkyLightCapture` 时，**捕获结果优先**；`sourceTexture` 在首次捕获完成前作为过渡。

---

## 7. 常见问题

| 现象 | 原因 | 解决 |
|---|---|---|
| 加了 SkyLightCapture，环境光没变化 | Zone 不在同一节点上 | 把组件挂到 Zone 所在节点（LightGroup 预设的话就是 LightGroup 节点） |
| 加了 SkyLightCapture，环境光没变化（Zone 在同一节点） | 天空不在 `viewMask` 范围内，或天空被禁用 | 检查 `capture.viewMask` 和天空的 `viewMask` 是否有交集 |
| 日志里有 `enabled skyboxes match the view mask` 警告，环境光颜色不对 | 多个天空同时画进了捕获 | 关掉多余的天空，或按"用 viewMask 区分"分配 mask |
| 环境光过亮 / 场景发灰 | 沿用了预设时代的强度（0.3）或反过来设得过高 | 捕获模式下强度从 1 开始调 |
| 物体反射里有很亮的小点 | 自写天空的日盘进入了捕获 | 用 `AT_CUBEMAP_PASS` 在捕获时去掉日盘（见第 5 节） |
| 天空一直在变但环境光更新有延迟 | 最短间隔 + 分帧捕获 | 正常现象（默认约 0.4 秒）；需要更快就调小 `minCaptureInterval` 或关 `timeSliced` |
| 用 `SetData` 改了天空贴图内容，环境光没更新 | 贴图对象没变，引擎看不到内容变化 | 改完调用 `capture:RequestCapture()` |
| 天空和雾之间有接缝 | 雾色与天空地平线色不同 | `zone.fogColor` 用天空的地平线色 |
| `ProceduralSky` 的太阳不见了 | 灯光被禁用、亮度为 0，或 `sunLight` 设的不是方向光 | 检查灯光；`sky.sunLight` 读回 nil 说明被拒绝了 |
