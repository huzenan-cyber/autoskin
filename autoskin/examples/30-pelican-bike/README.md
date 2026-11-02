# PelicanBike — 鹈鹕骑单车 / Pelican on a Bicycle

一只白鹈鹕骑着单车，绕着海上环形栈桥转圈。场景只用 Lua 和 SurfaceShader 编写，不需要图片或模型资源。

A white pelican rides a bicycle around a ring boardwalk over the sea. The scene is pure Lua plus SurfaceShaders and needs no image or model assets.

## 运行 / Run

```
UrhoXRuntime.exe main.lua -tapcode_dir=<本目录 / this dir> -skip_login -deferred
```

必须加 `-deferred`，SSR、SSGI 和 GBuffer 湿润后处理都依赖延迟渲染管线。FFT 海面需要 compute shader，已在 Windows DX11 上验证。首次启动要编译 shader，耗时较长。

`-deferred` is required: SSR, SSGI and the GBuffer wetness pass depend on the deferred path. The FFT ocean needs compute shaders (verified on Windows DX11). The first launch compiles shaders and takes a while.

可选参数 / Optional: `-tod=<小时 hours>` `-rain=<0|1>` `-freeze` `-cam=<follow|cinematic|free>` `-shot=<1-4>`

## 按键 / Controls

| 按键 Key | 作用 Action |
|---|---|
| `T` | 暂停/继续时间 · pause/resume time |
| `[` `]` | 时间 -1h / +1h |
| `-` `=` | 放慢/加快昼夜循环 · slower/faster day cycle |
| `R` / `Y` | 切换雨天 / 开关自动天气 · toggle rain / auto weather |
| `C` | 切换相机：跟随 / 电影镜头 / 自由 · cycle camera |
| `Shift` / `Ctrl` | 加速/减速 · bike speed |
| `H` | 隐藏 HUD · hide HUD |

## 组成 / Structure

| 文件 File | 内容 Contents |
|---|---|
| `scripts/main.lua` | 入口、相机、HUD、灯光联动 · entry, camera, HUD, light wiring |
| `scripts/atmosphere.lua` | 昼夜、天气、Zone 延迟特效、体积雾、雨、闪电 · time of day, weather, Zone effects, volumetric fog, rain, lightning |
| `scripts/ocean.lua` `spectrum.lua` | Tessendorf FFT 海面：Phillips 频谱，每帧 18 次 compute dispatch · FFT ocean, 18 dispatches/frame |
| `scripts/world.lua` | 小岛、灯塔旋转光束、栈桥、路灯、浮标 · island, lighthouse beams, boardwalk, lamps, buoys |
| `scripts/rider.lua` | 鹈鹕与单车，含踏板 IK · pelican and bicycle with pedal IK |
| `assets/Shaders/BLGL/Ocean.shader` | 延迟 PBR 海面：位移、多尺度法线、泡沫、透光、雨滴涟漪 · deferred PBR sea |
| `assets/Shaders/BLGL/Sky.shader` | 程序化天空：太阳、月亮、星空、云、闪电；同一份 shader 由 `SkyLightCapture` 捕获为环境光（IBL + SH），天空变了环境光自动跟着变 · procedural sky, also captured by `SkyLightCapture` as the scene's image-based lighting |
| `assets/Shaders/BLGL/Wetness.shader` | GBuffer 后处理：地面湿润与水洼 · wet surfaces and puddles |
| `assets/Shaders/BLGL/Ocean*CS.shader` | 频谱演化 / Stockham FFT / 结果解算 · spectrum / FFT / resolve |

FFT 计算链路改编自 `Tests/SurfaceShader/fixtures/surface_shader_compute_ocean`；解算阶段新增 `height_scale`，天气变化时浪高、法线和泡沫同步缩放。

The FFT pipeline is adapted from `Tests/SurfaceShader/fixtures/surface_shader_compute_ocean`. The resolve pass adds `height_scale` so wave height, normals and foam stay consistent as the weather changes.
