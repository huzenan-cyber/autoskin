# 体积云材质 / Volumetric Cloud Material

返回 [Surface Shader 编写教程](../surface-shader.md)。只需为当前任务阅读本 addon。

`shader_type cloud` 自定义天上的体积云：云的形状、颜色、自发光、散射。写一个 `.shader`，
绑到 `Material`，再交给场景里的 `VolumetricCloud` 组件。不设材质时组件画引擎内置的默认云。
写法对应 UE 的体积云材质（Volume 域）：每个采样点调用一次 `cloud()`，返回该点的介质属性。

English: `shader_type cloud` replaces the per-sample medium of the engine volumetric cloud (UE Volume-domain
cloud material). Write `void cloud()`, bind the shader to a Material and assign it to `VolumetricCloud.material`.
The engine keeps the integrator, shadows, Sky AO and sky-light capture; nil restores the built-in cloud.
This is an UrhoX extension, not Godot syntax.

## 1. 先搭好云场景

云需要桌面图形和 compute。两种管线都能画云：

| 管线 | 条件 |
|---|---|
| 延迟（`.project/engine.json` 设 `deferred`，见[延迟渲染](../deferred-rendering.md#11-开启方式)） | 有 `VolumetricCloud` 即可；建议同时加 `SkyAtmosphere` |
| 前向（桌面默认） | 必须有启用的 `SkyAtmosphere`，否则不画云 |
| 前向（移动） | 不画云 |

下面是最小场景，先不设材质，确认能看到内置默认云：

```lua
scene_ = Scene()
scene_:CreateComponent("Octree")

local sunNode = scene_:CreateChild("Sun")
sunNode.direction = Vector3(-0.5, -0.65, -0.5)
local sun = sunNode:CreateComponent("Light")
sun.lightType = LIGHT_DIRECTIONAL
sun.brightness = 5

-- Physical sky; also required by clouds in the forward pipeline.
local atmosphere = scene_:CreateChild("Atmosphere"):CreateComponent("SkyAtmosphere")
atmosphere.sunLight = sun

local cloud = scene_:CreateChild("Cloud"):CreateComponent("VolumetricCloud")
cloud.layerBottomAltitude = 1500   -- meters above the ground
cloud.layerHeight = 3000
cloud.tracingMaxDistance = 30000

-- The default weather map has clouds around this area; any position works, coverage varies.
local cameraNode = scene_:CreateChild("Camera")
cameraNode.position = Vector3(2000, 100, 15650)
cameraNode:LookAt(Vector3(2000, 2000, 20000))
local camera = cameraNode:CreateComponent("Camera")
camera.nearClip = 1.0
camera.farClip = 30000
renderer:SetViewport(0, Viewport:new(scene_, camera))
```

- 距离单位是米，世界 Y 向上。一个场景只用第一个启用的 `VolumetricCloud`。
- 云动画由 `cloud.weatherTime`（秒）驱动，引擎不自动推进。每帧加上 `timeStep` 即可让云飘动；不加就是静止的。

## 2. 写一个云材质

下面的材质就是内置默认云的等价写法，可以直接复制再改。引擎也带了同一份文件：
`Shaders/BLGL/Volumetric/VolumetricCloudDefault.shader`，可以直接 `SetSurfaceShader` 加载。

```glsl
shader_type cloud;
render_mode ms_octaves_2;

// Declaration order: weather, shape, profile (matches the built-in cloud).
uniform sampler2D weather_map : repeat_enable, filter_linear;
uniform sampler3D shape_noise : repeat_enable, filter_linear;
uniform sampler2D height_profile : repeat_enable, filter_linear;

uniform float density_scale = 1.0;
uniform float global_scale = 256000.0;  // meters covered by one weather map tile
uniform float coverage = -0.2;
uniform vec2 wind_velocity = vec2(1.0, 1.0);
uniform vec3 albedo = vec3(0.98, 0.98, 0.98);

void cloud() {
    ALBEDO = albedo;
    PHASE_G = 0.8;
    PHASE_G2 = 0.166667;
    PHASE_BLEND = 0.575;
    MS_CONTRIBUTION = 0.666667;
    MS_OCCLUSION = 0.25;
    MS_ECCENTRICITY = 0.18;

    float h = CLOUD_NORMALIZED_ALTITUDE;
    // Y-up world meters -> Z-up coordinates in units of the global scale.
    vec3 weather_coord = WORLD_POSITION.xzy / global_scale + vec3(0.5, 0.5, 0.0);
    vec3 cloud_types = texture(weather_map, weather_coord.xy - 0.5).rgb;
    float layout_coverage = max(max(cloud_types.r, cloud_types.g), cloud_types.b);
    // Cheap empty-space test: samples with a value <= 0 skip the full material.
    CONSERVATIVE_DENSITY = layout_coverage;
    EXTINCTION = 0.0;
    if (h >= 0.02 && h <= 0.98) {
        float profile = max(max(texture(height_profile, vec2(h, cloud_types.r)).r,
            texture(height_profile, vec2(h, cloud_types.g)).g),
            texture(height_profile, vec2(h, cloud_types.b)).b) - 0.5;

        float pattern_width = float(textureSize(weather_map, 0).x);
        vec3 wind = vec3(wind_velocity, 0.5) * 0.333333 * TIME * global_scale / (pattern_width * 1000000.0);
        vec3 noise2_uv = weather_coord * vec3(60.0, 60.0, 75.0) - wind * 6.0;
        float noise2 = (texture(shape_noise, noise2_uv).r - 0.8) * 0.08;
        float height = h * 0.95 + 0.05;
        float height_shape = abs(height - 0.5) * 2.0;
        vec3 distortion = vec3(height, height, height_shape * height_shape) * noise2;
        vec3 noise1_uv = weather_coord * vec3(4.167, 4.444, 9.091) + wind * 7.0 + distortion;
        float noise1 = (texture(shape_noise, noise1_uv).g - 0.5 + coverage) * 0.8;

        float density = layout_coverage * (profile + noise1) * (0.008 * max(density_scale, 0.0));
        // Fade out samples right next to the camera.
        float camera_fade = clamp(length(WORLD_POSITION - CAMERA_POSITION) * 0.002, 0.0, 1.0);
        EXTINCTION = clamp(density * camera_fade, 0.0, 1.0);   // per meter
    }
}
```

把它存成 `assets/Shaders/BLGL/MyClouds.shader`，绑定引擎自带的三张云贴图：

```lua
local material = Material:new()
assert(material:SetSurfaceShader("Shaders/BLGL/MyClouds.shader"))
assert(material:SetSurfaceTexture("weather_map",
    cache:GetResource("Texture2D", "EngineRes/Textures/VolumetricCloud/CloudPattern.dds")))
assert(material:SetSurfaceTexture("shape_noise",
    cache:GetResource("Texture3D", "EngineRes/Textures/VolumetricCloud/PerlinWorley.dds")))
assert(material:SetSurfaceTexture("height_profile",
    cache:GetResource("Texture2D", "EngineRes/Textures/VolumetricCloud/HeightProfile.dds")))
cloud.material = material

-- Runtime tweak: use the uniform name from the .shader source.
material:SetShaderParameter("coverage", Variant(-0.1))
```

`cloud.material = nil` 恢复内置默认云。固定搭配的材质也可以写成材质 XML（`<surfaceshader>`、`<surfacetexture>`、
`<parameter>`），格式见 [Surface Shader 教程](../surface-shader.md#材质文件配置material-xml)。

常见改法：

- 云更厚 / 更稀：调 `density_scale` 或 `coverage`。
- 黄昏暖色、底部发光：按 `CLOUD_NORMALIZED_ALTITUDE` 混合 `ALBEDO`；`EMISSION = color * EXTINCTION * 强度`，自发光要乘消光才跟着云形走。
- 换云的分布：换 `weather_map`（RGB 三种云型的覆盖）或直接用程序噪声算 `layout_coverage`。

## 3. 输入与输出

只读输入（长度单位都是米）：

| 名字 | 含义 |
|---|---|
| `WORLD_POSITION` | 采样点世界坐标（Y 向上） |
| `CAMERA_POSITION` | 相机位置 |
| `CLOUD_ALTITUDE` | 离地面高度 |
| `CLOUD_ALTITUDE_IN_LAYER` | 离云层底面高度 |
| `CLOUD_NORMALIZED_ALTITUDE` | 云层内归一化高度，0 底、1 顶 |
| `SHADOW_SAMPLE_DISTANCE` | 求阴影时沿光线的距离；视线采样为 0 |
| `TIME` | `cloud.weatherTime`，不是真实时钟 |

另有常量 `PI`、`TAU`、`E`。没有 UV、法线、屏幕坐标和深度。

输出（不写就用默认值）：

| 名字 | 默认 | 说明 |
|---|---|---|
| `EXTINCTION` | 1.0 | 消光，每米。**一定要写**：不写时整层是浓雾，编译会警告 |
| `ALBEDO` | (0,0,0) | 反照率，0–1 |
| `EMISSION` | (0,0,0) | 每米自发光 |
| `AO` | 不生效 | 写了才生效，0–1，只压暗天空光；替换组件的 Sky Light Bottom Occlusion |
| `PHASE_G` / `PHASE_G2` / `PHASE_BLEND` | 0 / 0 / 0 | 双 HG 相位：两瓣的偏心与混合 |
| `MS_CONTRIBUTION` / `MS_OCCLUSION` / `MS_ECCENTRICITY` | 0.5 | 多阶散射：亮度、遮挡、方向性 |
| `CONSERVATIVE_DENSITY` | 不生效 | 写了才生效；≤ 0 的样本直接跳过。要便宜，不要做重的贴图采样 |

相位和多阶散射每条视线只求一次，求值时 `WORLD_POSITION` 等于相机位置、高度为 0；让它们与位置无关。
写了 `render_mode phase_per_sample` 时相位改为每个样本求。

render_mode：

| 模式 | 作用 |
|---|---|
| `ms_octaves_0` / `_1` / `_2` | 多阶散射附加阶次，默认 0；三者只能写一个。想要内置云的效果用 2 |
| `phase_per_sample` | 相位每个样本求值 |
| `grayscale` | `ALBEDO`、`EMISSION` 只取 R |
| `ground_contribution` | 加上地面反射到云底的光 |
| `ms_contribution_unclamped` | `MS_CONTRIBUTION` 允许大于 1 |

## 4. 设了材质后，组件哪些属性还有用

| 不再生效（改在材质里做） | 继续生效 |
|---|---|
| `densityScale`、`albedo`、`emissive`、`phaseG`、`phaseG2`、`phaseBlend`、`multiScattering*`、`groundContribution`、`cloudGlobalScale`、`cloudGlobalCoverage`、`conservativeDensity`、`grayscaleLighting`、`windVelocity`、`weatherMap`、`shapeNoise`、`heightProfile` | `layerBottomAltitude`、`layerHeight`、`planetRadius`、`planetCenter`、`tracing*` 距离、`viewSampleCountScale`、`shadowSampleCountScale`、`shadowTracingDistance`、`stopTracingTransmittance`、`groundAlbedo`、`skyLightBottomOcclusion`（材质未写 `AO` 时）、`perSampleAtmosphereTransmittance`、`aerialPerspectiveEnabled`、`cloudShadow*`、`skyAOEnabled`、`renderInMainPass`、`skyLightingMode`、`weatherTime`（作为 `TIME`） |

## 5. 限制

- 贴图最多 6 张，只能是 `sampler2D`、`sampler2DArray`、`sampler3D`。第 6 张要求设备有 16 个 compute 绑定，不够时整朵云关闭。
- `texture()` 一律按 mip 0 采样；需要别的 mip 用 `textureLod`。不能用 `dFdx`、`dFdy`、`fwidth`、`textureQueryLod`、`discard`。
- 不能声明 `varying`、`global uniform`、`instance uniform`；只能有一个 `cloud()` 入口。
- uniform 数组不能写初值，不设置时是 0。
- 局部变量不要叫 `cloudIn`、`cloudOut`：会和引擎生成的参数重名，编译失败。
- 带 `source_color` 的颜色参数不做 sRGB 转换，直接按线性值使用。
- 材质参数每帧变化（动画）会让云的时域历史每帧重置，和 `weatherTime` 动画一样；只在需要时改参数。
- 天光捕获（`SkyLightCapture` 的 `includeClouds`）和云影、Sky AO 自动使用同一材质。

## 6. 出错时

- `SetSurfaceShader` 返回 false：`.shader` 解析失败，看日志里的报错行。
- 材质没绑 cloud 类型的 shader、或 shader 编译失败：整朵云不画（不会退回默认云），日志打一次
  `VolumetricCloud disabled: ...`。
- 要在失败时保底，设 `cloud.material = nil` 用回默认云。

## 7. 保存场景

组件只保存材质的资源名。用 `Material:new()` 在运行时建的材质没有资源名，保存场景再读回后会变回默认云。
要随场景保存，把材质写成 `assets/Materials/*.xml`，用 `cache:GetResource("Material", ...)` 赋给组件。
禁用组件或把云节点移出场景不会丢掉材质。
