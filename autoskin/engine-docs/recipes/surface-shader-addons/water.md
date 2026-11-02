# 水体 / Water

返回 [SurfaceShader](../surface-shader.md)。GPU 模拟配合 [Compute](compute.md) 使用。

`render_mode shading_model_water` 使用引擎的水体路径。
前向和延迟共用水体材质、波浪、折射、PBR 光照、环境反射及水下效果；延迟另外提供水体 SSR 和运动矢量。
水面光学及水下后处理移植自 UE SingleLayerWater 对应算法；入水判断由作者的 GPU 查询提供，
使用引擎波浪时改由 CPU 查询当帧给出。

English: Spatial water materials support forward and deferred rendering. The renderer owns refraction inputs,
lighting, depth, blending and motion. Author the displaced surface, camera immersion query and
display-snapshot waterline together. The complete three-snapshot FFT example is included here.

水体需要 compute 和线性 HDR 后处理，前向和延迟均可使用；管线选择见[延迟渲染](../deferred-rendering.md#11-开启方式)。
延迟使用单采样；前向支持单采样及默认的 4× MSAA，无需为了水体开启 FXAA。2×/8× MSAA 暂不支持。
MSAA 水体读取单采样背景快照，混合覆盖的岸线和物体轮廓采用近似折射。
前向保留 FFT/Gerstner、自定义 GPU 波浪、泡沫/尾流、浮力查询和水下效果，但反射只来自环境图，
不提供水体 SSR、时域反射、运动矢量或局部反射探针。前向使用现有雾效果，没有延迟路径的空气/水体分段雾合成；
建议用 ProceduralSky 或 Skybox，物理大气/体积云不由这次水体适配补齐。
前向晚期水面不能采样已经复用的普通阴影图集；只有仍有效的持久阴影可用，不要依赖水面具有全部物体阴影。
没有可见的新 Water 材质时，不分配或复制水体专用 SceneColor/Depth 快照。
蒙皮、LightMap/Paint 不在当前支持的材质组合内，没有自动替代；
不满足水体配置要求的视图按下文“不支持时回退”换材质。
旧的 SingleLayerWater 材质保留原行为，不会自动升级成这个模式。

水面使用第一盏影响它的非负平行光和 Cluster 局部光。额外平行光不累加到水面，局部灯需要启用
Cluster。当前请保留一盏影响水面的非负平行光，并确保 light mask 匹配；仅有 Cluster 局部光时可使用
引擎现有载体。完全没有可用光照队列时水面主着色不会执行，延迟深度仍可能写入，不能用于正确的无灯水面。
不要用多盏平行光叠加水面亮度。

反射来自 Zone 的环境立方体图；延迟路径在屏幕内另由水体 SSR 补充。环境图要和画面上的天空一致：
Zone 用的是带云、陆地的照片 HDRI，而可见天空是程序化渐变时，水面会映出与天空无关的亮斑和暗块。
天空会变或是程序化天空时，加 `SkyLightCapture` 从可见天空捕获环境光，见
[天空与环境光](../sky-and-environment-lighting.md)；保留照片 HDRI 时可提高水面粗糙度、减弱细节法线。

## 先运行完整样例

两个样例都包含全部脚本和 shader，不需要其他示例工程：

- [引擎水域](../../../examples/32-engine-water/README.md)：用引擎波浪（FFT 海面 / Gerstner 湖面），一个水域同时驱动
  水面、体素浮力、角色游泳、水面查询和水下效果，并演示不支持时的回退。不需要自写波浪时从它开始。
- [自定义水体（三帧 FFT）](../../../examples/31-custom-water/README.md)：自定义 GPU 波浪接入进阶示例，手动管理三帧 FFT，并提供速度、相机入水查询和水线。

把样例的 `scripts/`、`assets/` 内容复制到项目对应目录；新项目以 `scripts/main.lua` 为入口，已有项目
参考 `WaterScene.lua` / `WaterOcean.lua` 接入自己的场景和 Update，不覆盖原来的 Start。

三帧 FFT 样例是 128 米有限水域，由四组 256×256 JONSWAP 波段驱动（平铺长度 512 / 128 / 32 / 8 米），
在固定、不旋转、不缩放的节点上绘制。自定义 Compute 生成波浪，三张图集分别保存三帧的全部波段。可自由移动相机、
进入水下、暂停模拟、切换模拟频率。这个坐标约束属于样例的反求算法；如果移动或倾斜
水域，必须同时改写 vertex、查询、水线的坐标变换，不能只移动节点。

## 材质与水域一起设置

`WaterWorld` 是场景根节点上的组件，可在编辑器的 Subsystem 分类中添加，或在初始化时调用
`scene:GetWaterWorld()` 取得或创建。水域查询和引擎波浪渲染需要这个组件；仅添加 `WaterBody` 或波浪组件不会创建它。
禁用它会暂停水域查询，
但不会隐藏水面或停止可见波浪。清空场景或删除该组件后，旧引用不再提供查询；重建后重新取得引用。

在同一个节点放置水面的 `StaticModel` 或 `CustomGeometry` 以及 `WaterBody`。
先设置模型，再设置材质，最后关联水域。域的局部包围盒要覆盖水底、侧界和全部 XYZ 波浪位移；
Drawable 的可见性包围盒也要覆盖形变。空域不查询，水面离屏仍可入水。

```lua
scene:GetWaterWorld()
local material = Material:new()
assert(material:SetSurfaceShader("Shaders/WaterExample/Water.shader"))
-- Bind the three produced displacement textures before the first rendered frame.
assert(material:SetSurfaceTexture("fft_previous", previousTexture))
assert(material:SetSurfaceTexture("fft_display", displayTexture))
assert(material:SetSurfaceTexture("fft_query", queryTexture))
surface:SetMaterial(material)
local volume = surface.node:CreateComponent("WaterBody")
volume:SetBounds(domainMinimum, domainMaximum)
```

这里的 texture、surface 和 domain 变量来自项目自己的创建代码；完整可运行版本在样例中。
多材质模型用 `SetMaterialSlot()` 选择水材质；多个域重叠时高 Priority 优先，同优先级按组件 ID 稳定选择。

水材质继续写 `ALBEDO`、`ROUGHNESS`、`SPECULAR`、`NORMAL`。`WATER_ABSORPTION` 和
`WATER_SCATTERING` 是非负 RGB 每米系数，`WATER_PHASE_G` 控制相函数。`ALPHA` 是 UE 的
表面 Opacity 分配：0 保留介质透射/散射，1 趋向普通表面；不是普通 alpha 混合的不透明度。
泡沫可以提高 ALPHA 和粗糙度。`WATER_COLOR_SCALE` 默认 1，缩放水后背景颜色。

`fragment()` 写的 `NORMAL` 是世界空间法线（与 Godot 的视空间约定不同），直接写，不要再乘 `VIEW_MATRIX`。
写成视空间法线时光照、反射和水体散射都会随相机朝向变化，散射里还会出现一条随视角移动的硬边。

折射按 UE 水体材质的像素法线偏移：背景按 `vertex()` 输出的法线与 `fragment()` 法线之差偏移，强度随水面视深
从 1.15 过渡到 1.02（50 米处）。`vertex()` 不写 `NORMAL` 时顶点法线就是网格的平面法线，与 UE 一致；
在 `vertex()` 里写波浪法线，偏移只剩细节法线那一部分。

`fragment()` 可以只读 `SCENE_DEPTH_WITHOUT_WATER`：当前像素水面后方场景的线性视深（米，沿相机朝向），
对应 UE 的 SceneDepthWithoutWater。减去水面自身的视深就是视线方向的水厚，可用来做岸边泡沫或按深浅调颜色：

```glsl
void fragment() {
    float surface_depth = (VIEW_MATRIX * vec4(VERTEX, 1.0)).z;   // VERTEX is world space in fragment()
    float thickness = SCENE_DEPTH_WITHOUT_WATER - surface_depth;
    float shore = 1.0 - smoothstep(0.0, 0.6, thickness);
    ALBEDO = mix(vec3(0.05, 0.15, 0.12), vec3(0.85), shore);
    ALPHA = shore * 0.7;
}
```

它只能在水体材质的 `fragment()` 中读取，可以作为参数传给辅助函数；后方是天空时为远裁剪面距离。

无需写 blend/depth render_mode。显式写这些状态会告警并被忽略，写 `DEPTH` 也不能替换水面的
硬件深度。用真实顶点位置决定水面深度。裁剪可以使用 `discard`；保留表面 PBR 计算，不写 custom light。

## 使用引擎波浪

不想自己写波浪时，使用引擎波浪：同一组参数同时驱动画面、CPU 查询（浮力等玩法）和入水判断。
在水面节点上依次放置水面模型、`WaterBody` 和下面一种波浪组件：

- `GerstnerWaterSurface`：若干道解析波，适合湖面、池塘和小片水域，所有设备都能运行。
- `FFTWaterSurface`：按风速、风区生成海浪频谱，在 GPU 上逐帧计算，适合海面，带白浪。需要设备支持 compute。

材质调用波浪函数；两种组件用同一份材质：

```glsl
shader_type spatial;
render_mode shading_model_water, cull_disabled, world_vertex_coords;

varying vec3 rest;                       // undisplaced world position

void vertex() {
    rest = VERTEX;
    VERTEX += water_wave_offset(rest);
    // NORMAL keeps the flat mesh normal: refraction offsets by its difference to the pixel normal.
}

void fragment() {
    // Per-pixel normal and whitecaps resolve waves shorter than the mesh spacing. NORMAL is world space here.
    NORMAL = water_wave_normal(rest);
    float foam = smoothstep(0.1, 0.6, water_wave_foam(rest));
    ALBEDO = mix(vec3(0.05, 0.15, 0.12), vec3(0.85), foam);
    ROUGHNESS = mix(0.12, 0.6, foam);
    ALPHA = foam * 0.8;
    WATER_ABSORPTION = vec3(0.3, 0.07, 0.025);
    WATER_SCATTERING = vec3(0.03, 0.09, 0.12);
}
```

```lua
local volume = waterNode:CreateComponent("WaterBody")
volume:SetBounds(Vector3(-50, -10, -50), Vector3(50, 3, 50))

-- Lake: analytic waves.
local waves = waterNode:CreateComponent("GerstnerWaterSurface")
waves:SetMinWavelength(2)
waves:SetMaxWavelength(9)
waves:SetMaxAmplitude(0.3)

-- Or an ocean: wind sea plus swell, simulated on the GPU.
-- local waves = waterNode:CreateComponent("FFTWaterSurface")
-- waves:SetWindSpeed(11)        -- m/s
-- waves:SetWindAngle(0)         -- degrees; 0 blows towards +Z
-- waves:SetFetch(140)           -- km of open water upwind
-- waves:SetChoppiness(1)        -- horizontal sharpening of the crests

local world = scene:GetWaterWorld()
local sample = world:SampleSurface(Vector3(0, -1, 0), world:GetTime())
```

- CPU 查询传 `world:GetTime()`：它就是画面上波浪所用的时间，跟随场景的时间缩放和暂停，不会回绕。不要传
  `scene.elapsedTime`，它（以及 shader 的 `TIME`）每 20 秒回绕一次，过了 20 秒就和画面对不上。
- 体素物理（`VoxelPhysicsWorld`）会自动对水域里的体素物体施加浮力并处理角色游泳，不需要再设全局水平面，
  见 [体素物理](../voxel-physics.md) 的“水面与浮力”。
- 函数都用世界坐标、单位米：`water_wave_offset(p)` 是加到未位移点 `p` 上的位移，`water_wave_normal(p)` 是该点法线，
  `water_wave_height(p)` 是 `p` 正上方水面的世界高度，与 CPU 查询同一算法。`water_wave_foam(p)` 返回 0~1 的白浪覆盖，
  只有 FFT 水面有值：浪峰被挤压时升高，散开后慢慢消退；长浪的权重大，白浪沿长浪浪峰聚成斑块。用 `smoothstep`
  调阈值，并按上例提高 ALPHA 和粗糙度。
- 在 `fragment()` 里调用时，用 varying 传入未位移位置；逐像素的法线和白浪能看到比网格间距更短的浪，远处自动平滑。
- `vertex()` 里请用 `world_vertex_coords`，或先用 `MODEL_MATRIX` 换算到世界坐标；运动矢量由引擎处理，不需要写 `VELOCITY`。
- 这种材质不写 `occlude_camera()` 和 `waterline()`：引擎用 CPU 查询当帧判断入水，没有回读延迟，
  并按同一组波浪生成水线。写了 `occlude_camera()` 的材质按自写波浪处理，仍走它的 GPU 查询。
- 在 `vertex()` 或 `fragment()` 调用波浪函数的材质最多声明 2 个 sampler（水体材质原本可用 3 个）：第三个位置留给引擎的
  FFT 波浪纹理，超出会编译报错。
- 网格做成静水位的平面网格，`Height` 设静水位；波浪固定在世界 XZ，节点可以平移、绕 Y 轴旋转，但不能倾斜。
  水域包围盒要覆盖波高和水平位移：Gerstner 用 `GetMaxWaveHeight()`（各道波振幅之和），FFT 用 `GetDisplacementBound()`。
  FFT 的界是各层振幅的保守之和，通常明显大于实际浪高，只用来定包围盒，不要当成浪高显示给玩家。
- 平面网格的可见性包围盒也要放大到波高，否则浪尖抬起时被剔除。用 `CustomGeometry:FillModel()` 得到 `Model`，
  设置 `model.boundingBox` 后再赋给 `StaticModel`：`StaticModel` 在赋值模型时复制包围盒，之后改 `Model` 不会生效。
- 切换波浪类型时删除旧组件再创建新的：水域只用节点上的第一个波浪组件，禁用它会让水域失去浮力。
- 材质自己的滚动细节（细节法线、泡沫贴图流动）不要用 `TIME`：它每 20 秒回绕，滚动会跳一下。
  每帧把 `world:GetTime()` 写进一个 uniform 使用。
- Gerstner 参数沿用 UE 简单生成器的含义，长度换算为米、角度用度；最多 64 道波。浅水和岸边减弱波浪见下文
  “浅水衰减与水底地面”。
- FFT 分四层平铺，边长 `PatchLength`、1/4、1/16、1/64（默认 256、64、16、4 米）。最大一层决定最长的浪：`PatchLength`
  太小会丢掉长浪，在高空能看到重复。最小一层提供厘米级小波，破碎浪峰的白浪靠它碎成花边。大风、长风区或有涌浪的海面
  用 512 左右：最小一层 8 米，近处约 3 厘米一个 texel。
  `Swell` 是外来涌浪相对本地风浪的能量，`EnergyScale` 整体缩放能量（波高按平方根变化）。海面每 `RepeatPeriod` 秒
  （默认 1000）完全重复一次。设备不支持 compute 时，FFT 水面画成平面，但 CPU 查询照常返回波浪。
- 涌浪的波长约 165 米。比这小的水域里涌浪只会让整片水面一起升降，应 `SetSwell(0)`，用风速和风区调本地风浪
  （例如风速 8、风区 30 公里：有效波高约 0.9 米，主波长约 23 米）。
- 浪主要通过反射显形：太阳低、在视线前方时会有闪光带，顺光时只剩天空反射，浪显得平；吸收小、散射强的清水会透出
  浅色水底，盖过反射。浪看不出来时，先调太阳方向、水色和白浪阈值，再考虑加大浪高。
- CPU 查询（`SampleSurface`）返回几何波浪的高度和法线（含浅水衰减），不含白浪。FFT 的 GPU 纹理是半精度，与 CPU
  结果相差在毫米量级。
- `PlaneWaterSurface` 也能配合这些函数，得到平静水面。水面节点上没有这几种组件时，函数返回零位移、竖直法线、高度 0、无白浪。
- 波浪函数只能用在 `shading_model_water` 材质中，可以在 `vertex()`、`fragment()` 和水体查询入口里调用；
  函数名是保留名，不要自己定义同名函数。

### 浪尖破碎、远处粗糙度和细节法线

- `water_wave_jacobian(p)`：水平位移把水面压缩的程度，平静水面为 1，浪峰挤压时低于 1，翻卷时小于 0。
  用它找正在破碎的浪峰，再与 `water_wave_foam()`（破碎后留下的拖尾泡沫）合并成白浪覆盖。Gerstner 和 FFT 水面都有值。
  波浪随风变陡得慢，而真实海面的白浪随风速增长很快，两个阈值要跟着风速移动（风速每帧从 Lua 写进 uniform）：

```glsl
float wind_bias = clamp((wind_speed - 8.0) * 0.022, -0.12, 0.25);
float breaking = clamp((0.6 + wind_bias - water_wave_jacobian(rest)) * 3.0, 0.0, 1.0);
float trailing = water_wave_foam(rest, 0.4 - wind_bias, 2.5);
float cover = clamp(breaking + trailing * 0.6, 0.0, 1.0);
```

三参数的 `water_wave_foam` 在每个 FFT 波段内先判断压缩量是否超过第二个参数，再按第三个参数控制覆盖增长，
最后返回加权和，可能超过 1；与当前破碎合成后再截到 0~1，不要提前截断拖尾。它适合选择性地保留破碎浪峰后的拖尾，
避免几个波段的弱压缩一起跨过阈值。单参数调用仍返回原来的 0~1 汇总压缩覆盖；需要保留已有材质响应时继续使用它。

- `water_wave_slope_variance(p)`：远处一个像素里装下的细浪斜率方差。`water_wave_normal()` 在远处按像素自动平滑，
  这部分起伏会丢失；把它加进粗糙度，远处的闪光带才会变宽变柔，而不是一条细亮线。只有 FFT 水面在 `fragment()`
  里有值，其余情况为 0。按 UE 贴图压缩用的公式换算：

```glsl
// UE CompositeNormalLengthToRoughness: slope variance widens the GGX lobe.
float composite_roughness(float roughness, float slope_variance) {
    float variance = 0.5 * slope_variance - 0.00004;
    if (variance <= 0.0)
        return roughness;
    float a2 = pow(roughness, 4.0);
    float b = 2.0 * variance * (a2 - 1.0);
    return pow((b - a2) / (b - 1.0), 0.25);
}
// ROUGHNESS = composite_roughness(0.045, water_wave_slope_variance(rest) + detail_variance);
```

- 引擎自带细节贴图 `Textures/Water/DetailNormal.ktx`：RG 是细节法线 XY，B 是泡沫密度，A 是该级 mip 被平均掉的
  法线方差（存的是一半，用时乘 2）。按世界 XZ 采样并随风滚动；把 A 通道方差按细节强度的平方加进上面的
  `slope_variance`，近处细节清晰，远处变成粗糙度。
- 泡沫用 B 通道：覆盖度把阈值从 1 往下压，`clamp((lace - (1.0 - cover)) * 2.5 + cover * cover * 0.6, 0.0, 1.0)`，
  覆盖薄时只剩气泡壁，覆盖满时连成整片。`lace` 取两层：按世界 XZ 每 7 米一次，加一层按风向坐标每 25.9 米一次、
  拖尾越强沿风向拉得越长的层，泡沫顺风拉成条带。太阳下的泡沫亮度已接近纯白，只靠 `ALBEDO` 显不出花纹，纹路得走在
  `ALPHA` 上：覆盖与花纹共同决定不透明度，较弱覆盖主要留下花边壁；`ALPHA = 0` 时介质透射和散射照旧。
- 花边要靠厘米级小波切碎：FFT 平铺太小会丢长浪，太大则最小一层过粗，浪峰白浪变成边缘光滑的团块。海面用 512 左右。
- 逐格随机旋转或偏移 UV 时（三角网格防重复），用 `textureGrad` 采样，导数传连续 uv 的 `dFdx` / `dFdy`，
  并按同一角度旋转。直接用 `texture()` 时，跨网格边的相邻像素 UV 相差很大，硬件会选最粗的 mip，
  A 通道方差沿每条网格边变大，反射里出现一串点状亮线。
- 完整写法（两层细节、随机旋转防重复、泡沫花纹、浪尖透光和气泡）见
  [引擎水域样例](../../../examples/32-engine-water/README.md) 的 `assets/Shaders/OceanWater.shaderinc`。

### 浅水衰减与水底地面

波浪按 UE 的 WaveDepthFalloff 随水深衰减：系数 `1 - exp(-水深 / (衰减深度 / 2))`，作用于位移、法线、白浪、
CPU 查询和浮力。需要两样东西：

1. 波浪组件的 `SetWaveAttenuationDepth(米)`：默认 20.48（UE 的 Wave Attenuation Water Depth）。它按大洋设计，
   用在几米深的小海湾里会把整片浪压低；小水域取 3~5，设 0 关闭衰减。
2. 水域的水底地面（没有地面时不衰减）。二选一：
   - `volume:SetGroundHeights(Rect(最小XZ, 最大XZ), 宽, 高, 高度数组)`：直接给世界高度，数组按行排列，第一行在
     最大 Z 一侧（俯视图的上方）。地形是脚本生成的、或高度已知时用这个，CPU 和画面完全一致。
   - `volume:SetGroundViewMask(掩码)`：从水域顶部向下拍一次俯视深度，把 view mask 含该位的 Drawable 当作水底
     （对应 UE 只取 Landscape 和标记为地形的物体）。拍摄只在设置后、`CaptureGround()` 时进行，地形改动后再调用一次；
     结果读回 CPU 前沿用旧地面。只捕获有 depth pass 的普通几何（StaticModel、Terrain 等），水面本身不会被当成地面；
     体素物理的 DDA 体素体没有 depth pass，拍不到，用 `SetGroundHeights` 提供。拍摄时在水里的船、浮体如果也带这个位，
     会被当成水底，先清掉它们的位或先拍摄后再生成。

```lua
local waves = waterNode:CreateComponent("FFTWaterSurface")
waves:SetWaveAttenuationDepth(4)          -- meters; small bay
-- Seabed rising along X only: one row, west to east.
local heights = {}
for i = 1, 256 do
    local x = -64 + (i - 0.5) * 0.5        -- texel center
    heights[i] = Clamp(-9 + (x - 16) * 0.33, -9, 1.5)
end
volume:SetGroundHeights(Rect(Vector2(-64, -64), Vector2(64, 64)), 256, 1, heights)
```

地面矩形之外视为没有地面，波浪不衰减；`volume:GetGroundHeight(位置, 0)` 返回 `是否有地面, 高度`，可以给玩法用。
水深为 0（地面高过静水位）时波浪完全静止。

### 延伸到地平线的远处水面

UE 在水域外围加一圈远景网格：8 块平面（四角 E×E、四边与近处网格等长），每块只有 4×4 个四边形，
用关掉顶点波浪的材质。UE 把它放在静水位减去最大浪高处，盖住接缝处的波谷；这一级台阶让接缝两侧的视深突变，
雾和法线过滤跟着跳变，地平线下方会出现一条线。样例改为让近处网格最外一圈的顶点波浪淡出到 0，远景网格放在
静水位，两者没有台阶。做法：

- 远景网格和水面放在同一个节点上，并且在水面模型之后创建：水域把节点上的第一个 Drawable 当作水面。
  这样它的材质能读到同一组波浪；远处片元自动取到平均法线和完整的斜率方差，粗糙度与近处一致，不会出现一圈亮边。
- 材质用同一份代码去掉顶点位移：把主体放进 `.shaderinc`，远景 `.shader` 在 include 前 `#define` 一个宏，
  主体里用 `#ifndef` 跳过 `VERTEX += water_wave_offset(...)`。
- 近处网格的顶点位移乘一个淡出系数：按顶点到网格中心的 `max(|dx|, |dz|)` 用 `smoothstep` 从 1 降到 0，
  网格边缘正好平在静水位（样例的 `wave_fade` uniform，淡出宽度 64 米）。片元法线不淡出，远近着色连续。
- 近处网格要足够大，接缝才看不见（UE 默认 512 米宽的水域）。中心用细网格、往外逐格加长的网格只增加少量顶点，
  也没有裂缝；水域 `WaterBody` 仍只需覆盖要浮力和游泳的范围。
- 相机远裁剪要覆盖远景网格，深度雾的起止距离也要相应拉远，否则远处还是一堵雾墙。

样例的 `WaterScene.lua`（`BuildFarMesh` 和 `CreateWater`）是完整实现。

### 水底焦散

UE 水体材质的解析焦散：把水底点沿近似折射的太阳方向投回水面，用三处波浪法线的差算出一小块光斑落到水底后的面积，
面积缩小处更亮，写进 `WATER_COLOR_SCALE`（引擎在岸边按水厚自动淡出）。水底位置用 `SCENE_DEPTH_WITHOUT_WATER`
沿当前像素的视线重建：

```glsl
float surface_depth = (VIEW_MATRIX * vec4(VERTEX, 1.0)).z;
vec3 behind = CAMERA_POSITION_WORLD + (VERTEX - CAMERA_POSITION_WORLD) * (SCENE_DEPTH_WITHOUT_WATER / surface_depth);
WATER_COLOR_SCALE = vec3(water_caustics(behind, rest.y));   // see the sample's OceanWater.shaderinc
```

完整函数在样例的 `OceanWater.shaderinc`（`water_caustics`，由 `OCEAN_CAUSTICS` 宏开关），每像素多 4 次
`water_wave_normal()`。只作用于从水面上方透过水看到的背景；相机在水下时没有焦散。俯视浅水时最明显，
掠射角下远处细节已被平滑，焦散随之变弱。

## 查询与水线必须对应真实波面

自写波浪的水 shader 必须有 `occlude_camera()`，使用引擎波浪时省略。它读取真实的 `CAMERA_POSITION_WORLD`，写
`CAMERA_IMMERSION_DEPTH`（米，水面在相机上方为正）和 `CAMERA_OCCLUSION_VALID`。
默认无效；域外、无解或不收敛时保持无效。引擎生成 compute、绑定当前材质/实例输入、异步回读，
不需要作者再建输出 buffer。相机朝水底时也会执行，不依赖可见水面 Batch。

要启用水下效果，再实现 `waterline()`：使用只读 `WATERLINE_POSITION_WORLD` 求近裁剪面每像素
浸没深度，写 `WATERLINE_IMMERSION_DEPTH` / `WATERLINE_VALID`。这里应采显示快照；
`CAMERA_POSITION_WORLD` 仍是真实相机，不能当作逐像素水线点。缺少此入口会告警并禁用水下后处理。
入口内调用共享高度函数，将位置、sampler 显式传入 helper，将最终输出在入口赋值。

两个入口都只接受 compute 可用的运算：显式 LOD/texelFetch、材质与实例参数、MODEL_MATRIX、TIME；
不能使用屏幕采样、导数、varying、逐顶点输入或 discard。水线和相机查询不能互相调用。
TIME 是场景时间，不一定等于作者 FFT 模拟时间；暂停或变速时以绑定的模拟快照为准。

如果 FFT 包含水平位移，不能只在相机 XZ 直接采高度。样例使用六步有界 Newton 反求，将
`q + displacement(q).xz` 对齐查询 XZ，再使用同一网格三角形取高度。水平残差需小于 0.00002 米，
拒绝折叠/近奇异三角形与有限网格之外的结果。改变 FFT 分辨率、网格拓扑或波强度时必须一起调整并验证。

## 三份快照的分工

| 输入 | 正常每帧模拟时 | 用途 |
| --- | --- | --- |
| fft_previous | F[N-2] | 上一次实际显示的顶点 |
| fft_display | F[N-1] | 本次顶点、法线、泡沫、GPU 水线 |
| fft_query | F[N] | 本次提交的相机入水查询 |

vertex 用本次位置减上次位置写 `VELOCITY`，单位是帧间位移，不除以 deltaTime。局部坐标模式下
只写局部形变，对象整体运动由引擎处理；`world_vertex_coords` 下写完整世界位置差。
即使位移为零也显式写零。没有写 VELOCITY 时引擎采用自动顶点重放，它不能恢复被覆盖的旧 FFT。

Lua 先提交本帧 FFT，再绑定三个 sampler，引擎查询随后执行。FFT 中间蝶形使用自己的临时 buffer，
不能拿它们充当最终纹理历史。只覆写与上一显示和本次显示都不同的槽位；首次使用前初始化三张纹理。
暂停时继续推进显示记录，排空已有一帧显示延迟后 previous/display/query 相同，速度归零。
不同模拟频率下保留实际显示历史，不能每个渲染帧机械轮换三张旧纹理。

这能补偿一部分波浪相位延迟，不保证相机入水零延迟。CPU 查询结果经异步回读到达，实际帧龄随运行条件变化；
移动相机、GPU 迟到和暂停恢复仍有剩余误差。GPU 水线使用当帧显示波面，独立于迟到的 CPU 布尔结果。

## 无渲染的平面水面查询

玩法可以用场景水域做同步查询，不需要相机、Drawable 或 Graphics。先在同一节点创建
`WaterBody` 和 `PlaneWaterSurface`，再查询指定模拟时刻的水面：

```lua
local node = scene:CreateChild("QueryWater")
local volume = node:CreateComponent("WaterBody")
volume:SetBounds(Vector3(-50, -10, -50), Vector3(50, 5, 50))
node:CreateComponent("PlaneWaterSurface"):SetHeight(0)
local world = scene:GetWaterWorld()
local sample = world:SampleSurface(Vector3(0, -1, 0), world:GetTime())
if sample:IsValid() then
    print(sample.immersionDepth) -- Positive below the surface, in meters.
end
```

局部水位随节点变换；这个组件只定义查询平面，不创建模型或自动对齐材质。不要将它加到自写 FFT 的水面上
并期待查询到波浪。需要波浪时改用上文的 `GerstnerWaterSurface` 或 `FFTWaterSurface`。查询本身不施加力；
体素物理会按水域自动施加浮力，Bullet 刚体（`RigidBody`）不受影响。材质写了 `occlude_camera()` 时，
GPU 相机入水查询仍独立运行。

采样点必须位于有限水域边界内。重叠水域选择优先级最高者，同优先级按 component ID；选中域没有
启用的 CPU sampler 时返回 `WATER_SURFACE_UNSUPPORTED`，不会改查低优先级水域。批量查询用
`SampleSurfaces({point1, point2}, time)`，结果顺序与输入一致，消费前逐项检查 `IsValid()`。

## 大气、雾、透明物体和水下颜色

水上视图先捕获折射背景再画水，最后叠加环境和普通透明；水下视图先处理环境/普通透明，再捕获背景、
画水，最后在色调映射之后应用水下效果。不会自动把普通透明物体按水面逐像素分层。
不要自己额外加一次全屏水色，否则会重复施加介质。

水下参数通过 `WaterBody:SetUnderwaterMaterial()` 的独立 Material 配置，未提供时使用内置默认值。
它是参数容器，不需要给它绑定水面 shader。例如调整吸收与雾密度：

```lua
local underwater = Material:new()
underwater:SetShaderParameter("UnderwaterAbsorption", Variant(Vector4(25, 5, 2, 75)))
underwater:SetShaderParameter("UnderwaterFog", Variant(Vector4(2500, 0.02, 0.2, 0.002)))
volume:SetUnderwaterMaterial(underwater)
```

Absorption 的 RGB 是相对吸收，W 是米制分母；Fog 是最大深度（米）、密度（每米）、Schlick k、
湿边宽度（米）。水下 k 与表面 WATER_PHASE_G 不是同一个参数，不要直接互相复制。
其他参数可保留默认值；效果在 UE 的色调映射后颜色空间计算，不要预先手工 gamma 转换场景颜色。

## 不支持时回退

不满足上面配置要求的视图（未开启线性 HDR、不支持的采样数、没有 compute 等）不绘制水体材质，并在日志里告警一次。
视图渲染过水域后，`viewport:GetWaterState()` 不再是 nil，`IsSupported()` 说明这个视图能否绘制水体材质；
为 false 时把水面换成普通半透材质。水域本身不依赖渲染：浮力、游泳和 `SampleSurface` 查询照常工作。

```lua
local checked = false

-- Call once per frame (e.g. from Update) until the view has rendered the water once.
local function CheckWaterSupport(surface)
    if checked then return end
    local viewport = renderer:GetViewport(0)
    local state = viewport ~= nil and viewport:GetWaterState() or nil
    if state == nil then return end
    checked = true
    if not state:IsSupported() then
        print("Water fallback: " .. state:GetLastError())
        local material = Material:new()
        material:SetTechnique(0, cache:GetResource("Technique", "Techniques/NoTextureAlpha.xml"))
        material:SetShaderParameter("MatDiffColor", Variant(Color(0.08, 0.30, 0.38, 0.65)))
        material.cullMode = CULL_NONE
        surface.material = material
    end
end
```

回退材质是平的，不跟随波浪；需要水下色调时自己用 UI 叠一层，这类视图里也没有引擎水下效果。
以后再换波浪组件或重建水面时，继续使用回退材质。

## 调试视图状态

`viewport:GetWaterState()` 可用于调试当前 View。先检查 nil / `IsValid()`，再读取浸没深度；
Unknown 不是明确的水上结果。深度对应记录的 QueryPosition/QueryTime/QueryFrame，不能当作本帧
当前相机的精确深度。引擎使用 0.02 米滞回、250ms 时效和 0.5 米位移上限；传送后等待新结果，
不要在 Lua 中阻塞轮询。完整方法和类型见随 kit 分发的 `.d.lua`，这里不重复接口定义。
