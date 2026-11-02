# 引擎水域：FFT 海面、开船尾流与游泳 / Engine Water: FFT Sea, Boat Wakes and Swimming

一片水域、一组引擎波浪，同时驱动画面上的水面、体素物体的浮力、角色游泳、玩法查询和水下画面。
场景是 128 米见方的海湾：体素沙滩和栈桥、几块不同密度的木箱和石块、一条可驾驶的空心小船、一个按水面查询摆放的浮标；
海面向外一直延伸到地平线。左上角的面板可以切换天空、体积云和波浪，并实时调水体参数。

English: one water domain with engine waves drives the rendered surface, voxel buoyancy, swimming, gameplay
queries and the underwater view. The scene is a 128 m bay with a voxel beach and pier, floating crates, a sinking
stone, a drivable hollow boat and a buoy placed from surface queries. A panel switches the sky, volumetric clouds and waves
and tunes the water at run time.

此目录独立包含所需脚本与 shader；依赖引擎随附的模型、细节贴图与 urhox-libs/UI。
复制 `scripts/` 和 `assets/` 到项目同名目录，入口为 `main.lua`。

```text
UrhoXRuntime.exe main.lua -tapcode_dir=<project-root> -skip_login -deferred
```

水面按 Graphics 能力判定：需要线性 HDR、compute、当前格式/采样数下可读取的场景深度，以及启用的 water 场景命令。
延迟仅支持单采样；前向支持单采样或 4× MSAA。DX11、OpenGL 和 Vulkan 是已有验证覆盖的桌面后端，
其他后端即使通过能力判定，也不代表已完成画面验证。
前向用 `-rendering_pipeline=forward -sky=procedural -clouds=0` 启动。样例关闭 FXAA，可直接使用前向默认的 4× MSAA。
前向保留波浪、泡沫/尾流、折射、环境反射和水下效果，不提供水体 SSR、时域反射及运动矢量；
物理大气和云的延迟合成不移植，距离雾沿用前向近似，水面只采样仍有效的持久阴影图集。
English: forward water shares waves, refraction, environment reflections and underwater effects. Launch with
`-rendering_pipeline=forward -sky=procedural -clouds=0`. FXAA is disabled; forward supports single sampling and
the default 4x MSAA when Graphics reports linear HDR, compute and readable scene depth for that format/sample count.
Deferred requires single sampling. DX11, OpenGL and Vulkan have desktop validation coverage; capability eligibility
alone does not imply visual validation on other backends. SSR, temporal reflection,
water velocity and deferred atmosphere/cloud composition are omitted. Reused shadow atlases are unavailable to late water.
其他不支持的视图里水体材质不绘制，
样例检测到后换成半透平面材质，浮力和游泳照常工作。

| 按键 | 作用 |
| --- | --- |
| WASD / Shift | 移动、奔跑 |
| 鼠标右键拖动 | 转视角（左键留给面板） |
| Space | 跳跃；游泳时上浮；驾驶时刹车 |
| B | 一键上船 / 下船；船上 W/S 前进/倒车，A/D 转向 |
| C | 游泳时下潜，相机入水后显示引擎水下效果 |
| G | 切换 FFT 海面 / Gerstner 湖面 |
| R | 把小船和浮体放回起点，保留当前驾驶状态并清除尾流 |
| M | 切换朝下反射：镜像天空 / 默认环境合成 |
| H | 显示 / 隐藏面板 |
| Backspace | 离开驾驶并回到沙滩 |

启动参数：`-boat` 直接进入驾驶视角；`-waves=gerstner` 以湖面启动；`-sky=procedural` 用程序天空（同时打开距离雾）；`-clouds=0` 关闭体积云；
`-mirror=0` 以默认的朝下反射启动；`-panel=0` 隐藏面板；`-view=x:y:z:yaw:pitch` 固定机位截图
（例如 `-view=38:2.2:-14:-55:12`，用冒号分隔，引擎会在逗号处拆分命令行参数）。

## 面板

- **环境**：物理大气（`SkyAtmosphere`）/ 程序天空（`ProceduralSky`）、体积云开关与云量、太阳高度和方位、距离雾。
- **波浪**：FFT（风速、风区、尖锐度、涌浪）或 Gerstner（波数、最长波长、最大振幅、方向扩散），以及共用的风向。
- **水体**：朝下反射、屏幕空间反射、水底焦散、焦散亮度、浪尖透光、基础粗糙度、细节法线、吸收、散射、
  白浪起始覆盖、破碎浪峰阈值、岸边泡沫厚度。

面板和按键改的是同一张 settings 表：环境和波浪的改动立即应用到组件；材质参数由 `WaterScene.Update()` 每帧写进
近处和远景两份水面材质。

## 结构

```
scripts/main.lua          入口、启动参数、按键、状态栏、浮标查询、回退检测
scripts/WaterScene.lua    沙滩、栈桥、水域节点、波浪组件、远景水面、浮体，每帧写材质参数
scripts/Environment.lua   太阳、物理大气 / 程序天空、体积云、Zone 与雾、SkyLightCapture
scripts/ControlPanel.lua  面板（urhox-libs/UI）：环境、波浪、水体三页
scripts/Swimmer.lua       第一人称步行/游泳（VoxelCharacterController）
scripts/BoatController.lua  小船推进、转向、上下船、跟随相机与船尾接触查询
scripts/WaterWake.lua     水面接触者的视觉尾流历史，上传给近处和远景水面材质
assets/Shaders/OceanWater.shader     引擎波浪水面材质
assets/Shaders/OceanWaterFar.shader  远景水面材质：同一主体，去掉顶点波浪
assets/Shaders/OceanWater.shaderinc  两份材质共用的主体：细节法线、粗糙度、白浪、焦散、浪尖透光
```

## 做法要点

1. **先建场景服务，再组合水面**：场景根节点创建 `WaterWorld`，或调用 `scene:GetWaterWorld()` 取得或创建。
   每个水面节点放置模型、`WaterBody`、一种波浪组件（`FFTWaterSurface` 或 `GerstnerWaterSurface`）。
   网格是静水位上的平面网格：中心 96 米内 0.5 米一格，往外每格加长 8%，铺到 256 米外；模型包围盒要盖住波高，
   否则浪尖抬起时会被剔除。水域包围盒从海床到浪尖之上，查询、浮力和水下效果都以它为界，不必覆盖整张网格。
2. **材质只写表面细节**：`shading_model_water` + `world_vertex_coords`。`vertex()` 用未位移位置调用
   `water_wave_offset`，不写 `NORMAL`：保留平面网格法线，折射按它与像素法线之差偏移背景（像素法线偏移）。
   未位移位置经 varying 传给 `fragment()`，逐像素取 `water_wave_normal` 和 `water_wave_foam`（FFT 白浪）；
   `fragment()` 的 `NORMAL` 是世界空间法线，直接写，不要乘 `VIEW_MATRIX`。
   不写 `occlude_camera()` / `waterline()`：入水判断和水线由引擎按同一组波浪完成。
   调用波浪函数的材质最多 2 个 sampler（本例只用引擎细节贴图 `Textures/Water/DetailNormal.ktx`）。
   粗糙度加上 `water_wave_slope_variance`（远处像素里看不见的细浪）和细节贴图 A 通道的方差，通过法线方差加宽高光；
   白浪由 `water_wave_jacobian`（正在破碎的浪峰）和 `water_wave_foam`（拖尾）合成覆盖度，两个阈值随风速移动。
   拖尾使用三参数调用，在每个 FFT 波段内先做压缩阈值判断，再加权合成；保留超过 1 的历史量，和当前破碎相加后才截断覆盖；
   拖尾花纹随覆盖度沿风向连续拉伸，水下气泡散射仍使用原单参数调用的覆盖度。
   泡沫通过 `diffuse_lambert_wrap` 接收场景光照、大气衰减和阴影，让亮面与侧面柔和过渡；默认不额外叠泡沫自发光。
   可在 `OceanWater.shaderinc` 中取消 `OCEAN_FOAM_FORWARD_SCATTER` 定义行的注释，开启附加散射。
   此模式只改变按泡沫覆盖加权的漫反射，清水的反射、折射率和介质参数保持原设置。
   深水白浪的覆盖和不透明度按 water-test 公式计算：当前破碎加上 0.6 倍拖尾，再截到 0~1；花纹密度包含覆盖平方填白项，
   截断密度后只平滑覆盖的起始区间，不另乘透明度系数。泡沫压低细节法线扰动，同时保留波面坡度。水下气泡的基础散射强度
   独立计算，避免花边的覆盖规则直接改写它。浪峰的花边要靠厘米级小波切碎，所以 FFT 平铺用 512 米（最小一层 8 米）。
3. **岸边泡沫**：`SCENE_DEPTH_WITHOUT_WATER` 减去水面视深就是视线方向的水厚，薄处叠泡沫；负值是前景物体轮廓，不算岸线。
4. **浮力自动完成**：`VoxelPhysicsWorld` 按物体底下的局部波面施加浮力，宽物体取船体范围的平均波面。
   密度决定浮沉（木箱浮、石块沉）；空心船体用 `buoyancy` 给出密封壳的排水量，`SetComOffset` 压低重心防翻。
   `WaterBody:SetDensity(1025)` 是海水，浮力按密度 / 1000 缩放。不需要设置全局水平面。
5. **游泳自动完成**：`VoxelCharacterController` 过胸深进入 `swimming`，浮在波面上；游泳时 `desiredVelocity.y` 是上浮/下潜意图。
6. **玩法查询传 `WaterWorld:GetTime()`**：浮标每帧用 `SampleSurface` 取高度、法线和速度。这个时间就是画面波浪的时间，
   跟随时间缩放、不会回绕；不要传 `scene.elapsedTime`（每 20 秒回绕）。
7. **切换波浪时删旧组件再建新的**：水域只认节点上的第一个波浪组件，禁用它会让水域失去浮力。同类波浪的参数
   直接在原组件上改。
8. **回退**：视图渲染过水域后，`viewport:GetWaterState():IsSupported()` 说明水体材质能否绘制；为 false 时换普通材质。
9. **水下效果由引擎完成**：相机入水后自动生效，参数用 `WaterBody:SetUnderwaterMaterial()` 调，省略的参数用默认值。
10. **天空、云与反射一致**：两种天空都在启动时创建，切换时只启用一个；`SkyLightCapture` 的 `captureSource` 跟着在
    `SKY_CAPTURE_ATMOSPHERE` 和 `SKY_CAPTURE_SKYBOX` 之间切换，`includeClouds` 跟随云层开关，改完调用
    `RequestCapture()`，水面反射和环境光始终来自画面上的天空。体积云只需要一盏平行光；物理大气自带空气透视，
    所以只在程序天空下打开距离雾。
11. **远景水面**：同一节点上的 8 块平面，去掉顶点波浪、放在静水位；近处网格最外 64 米把顶点波浪淡出到 0，
    两者无台阶相接，避免接缝两侧视深、雾和法线滤波突变产生可见线条。相机远裁剪和深度雾随之拉远。
12. **焦散与透光**：`OCEAN_CAUSTICS`（解析焦散，写进 `WATER_COLOR_SCALE`）、`OCEAN_CREST_SSS`、`OCEAN_FOAM_BUBBLES`
    三个宏在 `OceanWater.shaderinc` 开头，注释掉即可对比；焦散也可以在面板里开关。后两项分别补充浪尖透光与水下气泡散射。
    公共头部默认定义 `OCEAN_CAUSTICS_FILTERED`，前向和延迟都用像素足迹与有限太阳光源滤波，防止 FFT 波面
    把焦斑压成闪烁的 HDR 亮点。注释掉这一行即可恢复点光源面积比公式做 A/B，焦散本身仍然开启。
    这层滤波只影响样例焦散，不改变引擎波浪或水体介质公式。

English: keep the mesh, `WaterBody` and one wave surface on one node; size the model bounds and the domain for
the waves. The material displaces from the rest position and leaves the vertex normal flat, so refraction offsets
by the difference to the per-pixel normal; it re-evaluates normal and whitecaps per pixel and writes
`NORMAL` in world space, derives shore foam from `SCENE_DEPTH_WITHOUT_WATER`, and omits the camera and waterline
queries. Buoyancy and swimming need no script; gameplay queries pass `WaterWorld:GetTime()`. Replace, do not
disable, the wave component when switching. Check `IsSupported()` on the view's water state to swap in a fallback
material. The sky light capture follows the visible sky and cloud layer. A far mesh at the rest level carries the
sea to the horizon while the near mesh fades its vertex waves out at the edge, and the material adds
analytical caustics; each extra effect has a macro at the top of `OceanWater.shaderinc`. `OCEAN_CAUSTICS_FILTERED`
is defined there by default for both forward and deferred paths, filtering caustic patches with the pixel footprint
and a finite solar disc. Comment out that definition to A/B against the point-source area ratio while keeping caustics
on. The engine wave and water medium formulas are unchanged. Deep-water whitecaps use the water-test coverage and opacity formulas: add current breaking to 0.6 times the weighted trailing memory,
then clamp coverage. The lace density includes the squared-coverage fill term; clamp it to opacity and fade only
the coverage onset, without an extra transparency multiplier. Trailing memory thresholds each FFT band before
combining it through the three-argument `water_wave_foam` call; its sum can exceed one and continuously stretches
the lace along the wind. Foam follows the wave slope while damping detail ripples. The subsurface bubble source
keeps the original one-argument coverage; surface foam still attenuates its transmission. Foam uses `diffuse_lambert_wrap`
with the scene lights, atmosphere attenuation and shadows, with additive foam emission disabled by default.
Uncomment the `OCEAN_FOAM_FORWARD_SCATTER` definition in `OceanWater.shaderinc` to enable it. Wrapped diffuse
only changes the coverage-weighted diffuse term; clear-water reflections, refraction index and medium parameters stay unchanged.

## 开船观察尾流 / Driving the boat

按 `B` 可从任意位置直接上船，或带 `-boat` 启动；这是展示用的快捷切换，不必先游到船边。
按住 `W` 加速，`S` 减速并倒车，`A/D` 转向，`Space` 刹车。相机从船后方跟随，按住右键可绕船观察，
适合边转弯边检查弧形尾流。再按 `B` 在船边下水，恢复步行/游泳；`Backspace` 直接回岸。

船体沿本地 +X 前进。控制器只施加水平推进、侧向阻力和转向力矩，船的高度、俯仰、横滚与碰撞
仍由 `VoxelPhysicsWorld` 和同一水域的浮力求解。上船时暂停角色碰撞，避免角色把船推翻。
船尾实际接触水面时才发射尾流，离水不产生新尾流；停车后已有泡沫自然消散。
海湾的物理水域是 128 米见方，驶出水域、搁浅或翻船时按 `R` 复位；驾驶中也可用 `G` 切换波浪。

English: press B anywhere to board, or start with `-boat`. W/S provide forward/reverse thrust, A/D steer and Space
brakes. Right-drag orbits the chase camera to inspect curved wakes. B leaves beside the hull; Backspace returns to
the beach. Horizontal forces and yaw torque drive the existing floating body; engine buoyancy and collisions
still determine its pose. The character collider is suspended while aboard. Wakes use actual stern contact and
motion. R resets the boat and clears its wake while retaining the driving mode; use it if grounded, capsized or
outside the 128 m water domain. G can switch waves while driving.

## 视觉尾流 / Visual wakes

当前尾流是基础视觉近似，船舶尾流画质待后续优化：两侧波列、中央翻搅泡沫、沿航迹的细节与消散尚不完善，
近看会出现较粗的网状花纹。当前保留此效果用于驾驶和尾流接入展示。

English: this basic visual approximation is retained for driving and wake integration demonstrations. Boat-wake
quality needs further work on side waves, central foam, trail-aligned detail and decay; coarse net-like patterns remain visible.

角色在水面游动时会留下泡沫和细小法线扰动，下潜、离水和静止不继续产生。尾流沿用同一水域时间，
暂停时冻结，切换波浪或重置场景时清除；它只改变材质，不改变 FFT、顶点、运动矢量、浮力和流速。

`WaterWake.lua` 由玩法提供接触水面的世界位置；接入船只时，按船体的水面接触点调用 `Feed`，
使用独立来源 ID，并在销毁时 `Remove`。是否接触水面由控制器或 CPU 水面查询决定，不能仅凭物体在水域范围内发射。
本例已接入游泳角色和可驾驶小船，箱子和木筏不发射。两份水面材质共用历史，每帧上传最新的 32 段，
四秒后消失；这是总段数预算，不是来源数量限制。多人同时发射时旧段可能因预算被舍弃。

计算函数在引擎随附的 `Shaders/BLGL/Water/WaterWake.shaderinc` 中，原生 shader 和 SurfaceShader 都可包含。
它不占纹理槽，但每个受影响像素需要遍历附近历史段；先用宽度和发射频率控制覆盖范围，
不要直接扩大数组。本轮只验证桌面延迟 DX11 / OpenGL，未测量性能。

English: the swimmer and motorboat emit visual foam and normal ripples while touching the surface. The gameplay tracker owns
source histories; feed a stable source ID and a confirmed water contact, then remove it on destruction. Crates and
rafts do not emit in this example. Both materials share a four-second history with a total budget
of 32 recent segments. Older segments may be dropped under load. Pausing freezes the field; resetting the scene or
switching waves clears it. The shared shader helper adds no texture binding and changes no wave displacement,
motion vector, buoyancy or fluid velocity. Only desktop deferred DX11 / OpenGL are verified; GPU cost is unmeasured.

## FFT 与 Gerstner 怎么选

- FFT：按风速、风区生成的海浪，带白浪，每帧在 GPU 上模拟；适合海面。
- Gerstner：若干道解析波，没有 GPU 模拟开销；适合湖面、池塘和小片水域。

两种组件用同一份材质，浮力、游泳、查询都不用改。两者都需要上面的桌面水体管线。

## 让浪看得出来

浪高够了不等于看得见。本例的 FFT 有效波高约 0.9 米、主波长约 23 米，下面几项一起决定浪的观感：

- **波长要比水域小**：涌浪（`SetSwell`）的波长约 165 米，比 128 米的海湾还长，只会让整片水面一起升降，
  还会把水位推上栈桥，所以本例设为 0。小水域靠本地风浪，用风速和风区调波长和浪高，`SetChoppiness` 让浪峰更尖。
- **浪靠反射显形**：起伏主要通过天空明暗、太阳高光和白浪表现出来。太阳低、在视线前方时，浪面上会有一条闪光带；
  顺光看时只剩天空反射，浪就显得平。
- **水色别太清**：吸收小、散射强的清水会透出浅色海底，盖过反射，浅水区像一块平板。本例加深了水色，
  降低了白浪阈值。

English: wave height alone does not make waves visible. Keep the wavelengths smaller than the water body (the
swell is longer than this bay, so it is off), light the surface with a low sun ahead of the view, and use a medium
dark enough that reflections and whitecaps, not the seabed, dominate.

## 限制

- 本例不使用浅水衰减，浪在近岸不会变小、变陡或破碎。引擎的水深衰减见
  [水体文档](../../engine-docs/recipes/surface-shader-addons/water.md)的“浅水衰减与水底地面”。
- 焦散只作用于从水面上方看到的水底；相机在水下时没有焦散。
- 浮力只作用于 `VoxelPhysicsWorld` 的体素物体，每个物体用一个平面近似底下的波面。
- 水域时间是本地场景时间，联网时不会自动同步。
- 只在桌面 DX11 / OpenGL 上验证过。
- [自定义水体（三帧 FFT）](../31-custom-water/README.md) 是自写 FFT 波浪的做法（自带入水查询和水线），需要完全自定义波浪时参考它。
