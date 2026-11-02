# 自定义水体（三帧 FFT） / Custom Water: Three FFT Snapshots

这是自定义 GPU 波浪接入的进阶样例：Lua 调度 FFT，材质显式提供位移、速度、入水查询与水线。
使用现成引擎波浪及浮力、游泳、驾驶时，从[引擎水域样例](../32-engine-water/README.md)开始。

English: an advanced example for authoring a custom GPU wave source and connecting displacement, motion and
immersion to the engine water pipeline. Use the engine-water example for built-in waves, buoyancy and gameplay.

此目录独立包含所需脚本与 shader；依赖引擎随附的模型、Daytime 光照预设与 urhox-libs/UI。
水体使用 `shading_model_water`，需要 compute。支持前向和延迟渲染，继承项目选定的管线。

复制 `scripts/` 和 `assets/` 内容到项目同名目录，入口为 `main.lua`。开启线性 HDR 后处理，延迟使用单采样，前向可使用单采样或 4× MSAA。
Runtime 本地启动示例（路径由自己的安装位置决定）：

```text
UrhoXRuntime.exe main.lua -tapcode_dir=<project-root> -skip_login -deferred -m 1
```

前向启动改用 `-rendering_pipeline=forward`，可直接使用默认的 4× MSAA，样例保持 FXAA 关闭。
前向管线保留折射、环境反射和水下效果，
没有水体 SSR、时域反射和运动矢量，雾沿用普通前向近似。前向水面只采样仍有效的持久阴影图集。

右键转向、WASD 移动、Q/E 升降、Shift 加速；
面板可暂停 FFT 或限制为 30Hz，快照编号和已采用结果延迟每 0.25 秒更新。

English: Copy scripts and assets into your project and run main.lua with HDR and compute, using the project's forward or deferred rendering. Deferred uses single sampling; forward also supports the default 4x MSAA.
Forward uses environment reflections without SSR/velocity, and FXAA remains disabled.
The panel controls pause and simulation rate. RMB looks, WASD moves,
Q/E descends/ascends. The sample keeps all final displacement snapshots separate from FFT scratch buffers.

`WaterOcean.lua` 可独立嵌入已有场景。保持返回对象存活，每个渲染 Update 调用一次 `Advance(time)`；
暂停传 nil。不要把模拟提交放在绘制事件，也不要在渲染停滞时无限积压 Update 提交。
`WaterDemo.lua` 和 main.lua 采用标准 3D 场景脚手架的场景持有、自由相机与 UI 生命周期。

样例用四组 256×256 的方向性 JONSWAP 频谱，波段平铺长度为 512 / 128 / 32 / 8 米。
`WaterSpectrum.lua` 的 `settings` 在初始化前设置海况：风速 8 m/s、吹程 30 km、风向 100°、水平位移强度 1.4，
默认不叠加远处涌浪。这与引擎水域样例的默认海况一致；频谱、方向分布、分频窗口和时间重复周期采用相同公式。
波峰的水平位移向峰顶收拢；逐像素法线来自各波段的真实 FFT 导数，细浪不再由程序噪声冒充。

绘制网格仍为 128 米有限水域、每格 0.5 米，与频谱平铺长度独立。节点保持单位变换，包围盒根据频谱振幅上界计算。
修改 FFT 分辨率、波段数、网格或节点变换时，需同步修改采样 helper、反求和包围盒。
顶点、速度和入水查询使用相同的四波段位移；查询按实际网格三角形插值，不能直接用连续波面高度代替。
此例不包含浮力、碰撞、焦散或自动透明物体分层，也没有引擎波浪的完整 LOD、泡沫记忆和岸深衰减。

每张快照是 1032×516 的 RGBA32F 图集：四列对应四个波段，两行保存位移和导数；各块带一圈周期边界像素，
防止双线性过滤串到相邻波段。三个 sampler 都使用相同的线性采样 hint 和显式 LOD 0；不要直接给整张图集生成 mip。
远处按像素覆盖范围淡出无法分辨的法线。仅三张快照约占 24.4 MiB，频谱和 FFT 临时 buffer 另占约 20 MiB。

泡沫由各波段的浪峰压缩生成，程序噪声只负责打散泡沫，场景几何接触处叠加薄层泡沫。
其时间取显示快照，暂停模拟时一起停止。顶点保留平面法线，供引擎按它与像素法线之差计算折射偏移。
场景用 SkyLightCapture 捕获可见程序天空，环境反射与天空一致。

English: Four 256×256 directional JONSWAP bands tile at 512, 128, 32 and 8 meters, using the same spectrum,
spreading, band windows and repeat period as the engine waves. Configure the sea before initialization in
WaterSpectrum.lua; defaults match the engine-water demo (8 m/s wind, 30 km fetch, 100 degrees, choppiness 1.4).
Real FFT derivatives supply pixel normals. Procedural noise only breaks up compression/contact foam.
The finite mesh remains 128 meters with 0.5-meter cells; vertex motion and immersion share its displaced triangles.
Keep the water node at identity. This example does not implement full engine wave LOD, foam memory or depth attenuation.
Each snapshot is a padded 1032×516 RGBA32F atlas containing displacement and derivatives of all four bands.
Use linear LOD-zero sampling with periodic gutters, not whole-atlas mipmaps. Three snapshots cost about 24.4 MiB
plus about 20 MiB of spectrum/FFT buffers. Unresolved normal detail fades with pixel footprint. SkyLightCapture matches the visible sky.

三张最终位移纹理保持独立：`vertex()` 采样 F[n-1] 显示水面，采样 F[n-2] 得到上一帧顶点，
两者之差写入 `VELOCITY`；`occlude_camera()` 采样 F[n] 查询相机浸没深度。Lua 负责快照轮换及绑定。
Compute 的频谱和 FFT 中间缓存不能复用这些仍在渲染/查询的最终快照。异步 GPU 回读仍可能跨帧，
三帧排程用于抵消常见一帧回读延迟，不保证任意 GPU 负载下的结果零延迟。

水体材质的深度和混合状态由引擎管理，手写相关 render_mode 会告警并被忽略。
主着色只提交一次：第一盏影响水面的非负平行光、Cluster 局部光、环境光和折射在同次绘制中完成。
额外平行光和未进入 Cluster 的传统逐灯局部光不累加到新水体。请保留样例的平行光并确保 light mask
匹配；仅有 Cluster 局部光时可使用引擎现有载体。完全没有可用光照队列时主着色不执行，
深度仍可能写入，当前不支持正确的无灯水面。

Three final displacement textures retain F[n-2], F[n-1] and F[n]. Vertex displacement uses F[n-1],
VELOCITY is the difference from F[n-2], and occlude_camera uses F[n]. Lua rotates the bindings;
FFT scratch textures stay separate. Asynchronous readback can still span more than one frame.
Depth/blend state is renderer-owned. Water shades once using one directional light and clustered local lights.
Keep the sample directional light affecting the water. Cluster-only scenes can use the existing carrier.
Without an eligible lighting queue, surface shading is skipped while depth may still be written.
