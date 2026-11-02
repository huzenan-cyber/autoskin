# UrhoX Lua Development Documentation

AI coding assistant reference for UrhoX Lua game development.

---

## Core Documentation

### [gotchas/](gotchas/index.md) ⚠️
常见陷阱与注意事项 - **只记录实际遇到并验证过的问题**（当前 7 个）。
- [物理系统](gotchas/physics.md)：Rolling Friction 不兼容、Collision Margin 过大
- [相机系统](gotchas/camera.md)：orthoSize 的 0.5 因子、GetScreenRay 无缓存、正交投影公式

### [API Reference](api/index.md)
Lua 5.4 API 模块文档，详细签名由 `.emmylua/` 接管。

**Quick links**:
- [Core](api/core.md) - Scene, Node, Component
- [Graphics](api/graphics.md) - StaticModel, Camera, Light, Material
- [Physics](api/physics.md) - RigidBody, CollisionShape
- [Physics 2D](api/physics-2d.md) - RigidBody2D, CollisionShape2D
- **UI → [recipes/ui.md](recipes/ui.md)**（urhox-libs/UI：Yoga + NanoVG，40+ 控件）
- [Audio](api/audio.md) - Sound, SoundSource
- [Input](api/input.md) - Keyboard, Mouse, Touch
- [Math](api/math.md) - Vector3, Quaternion, Color
- [Enums](api/enums.md) - All enumerations
- [Globals](api/globals.md) - Global functions and properties

---

## Recipes (Solutions)

### Ready
- [recipes/scene-cloud-save.md](recipes/scene-cloud-save.md) - **场景云存档与读档（clientCloud / serverCloud、个人与世界存档、场景替换）**
- [recipes/ui.md](recipes/ui.md) - **UI 开发指南（Yoga + NanoVG，40+ 控件）** ⭐
- [recipes/custom-lobby.md](recipes/custom-lobby.md) - **自定义大厅开发手册（模板换皮 / 完全自建，界面用 urhox-libs/UI）** ⭐
- [recipes/materials.md](recipes/materials.md) - 材质列表和参数
- [recipes/rendering.md](recipes/rendering.md) - 渲染配置（灯光组、天空盒/天空球、后效开关）
- [recipes/sky-and-environment-lighting.md](recipes/sky-and-environment-lighting.md) - **天空与环境光（ProceduralSky 程序化天空、SkyLightCapture 环境光实时跟随天空、自写 sky shader）**
- [recipes/surface-shader-addons/cloud.md](recipes/surface-shader-addons/cloud.md) - **体积云（SkyAtmosphere + VolumetricCloud 最小场景、`shader_type cloud` 自定义云材质）**
- [recipes/deferred-rendering.md](recipes/deferred-rendering.md) - **延迟渲染（管线选择、SSR/SSGI/GTAO/TAA、GBuffer 后处理、平台限制）**
- [recipes/lights-and-shadows.md](recipes/lights-and-shadows.md) - 灯光与阴影（灯光类型、级联阴影、局部光阴影、时域阴影、预算）
- [recipes/volumetric-fog.md](recipes/volumetric-fog.md) - **体积雾与体积光（光柱、灯光光晕、LocalFogVolume）**
- [recipes/grass.md](recipes/grass.md) - **草地（GrassField：GPU 生成的风吹草叶、草簇、踩踏互动、地形密度图）**
- [recipes/post-processing.md](recipes/post-processing.md) - 后处理（SSR/SSGI/GTAO/运动模糊/泛光/自动曝光/景深）
- [recipes/deferred-scene-weather-lighting.md](recipes/deferred-scene-weather-lighting.md) - 动态环境场景指南：昼夜、晴雨天气、打光规范、体积光、水面（配套示例 examples/30-pelican-bike）
- [recipes/scene-to-nanovg.md](recipes/scene-to-nanovg.md) - 在界面中创建、绘制和关闭 3D 场景预览
- [recipes/state-machine.md](recipes/state-machine.md) - **动画状态机（Pose Graph、BlendSpace、AimOffset、Root Motion、后处理骨骼挂点）**
- [recipes/kawaii-physics.md](recipes/kawaii-physics.md) - **次级骨骼运动（预览版；头发、尾巴、裙摆、胸臀辅助骨骼；模拟空间、碰撞与参数曲线）**
- [recipes/nanovg_bloom_glow_guide.md](recipes/nanovg_bloom_glow_guide.md) - NanoVG Bloom 发光特效
- [recipes/procedural-lua-headless.md](recipes/procedural-lua-headless.md) - 程序化 / 离线 Lua（用引擎跑一段脚本然后退出，写法搭配 `run-lua-headless` skill）
- [recipes/voxel-physics.md](recipes/voxel-physics.md) - **体素物理（Teardown 风格可破坏世界：爆炸挖掘/碎块/浮力/角色/抓取/铰链/载具）**
- [recipes/voxel-networking.md](recipes/voxel-networking.md) - **体素物理联网（Lua 服务端权威、资源预热、Ready、两域色板、晚加入与重连）**

---

## Keyword Index

| Need | File |
|------|------|
| **常见陷阱/坑** | **gotchas/index.md** |
| API reference | api/index.md |
| Create scene | api/core.md |
| **保存场景 / 读取场景 / 体素进度 / 房主继续游戏** | [recipes/scene-cloud-save.md](recipes/scene-cloud-save.md) |
| Add model | api/graphics.md |
| Camera | api/graphics.md |
| Lighting | api/graphics.md |
| Physics (3D) | api/physics.md |
| Physics (2D) | api/physics-2d.md |
| Collision | api/physics.md |
| **UI system (Yoga + NanoVG)** | **recipes/ui.md** |
| **3D 场景预览 / nvgCreateVideo** | [recipes/scene-to-nanovg.md](recipes/scene-to-nanovg.md) |
| **自定义大厅 / 大厅 UI / lobby 定制** | **recipes/custom-lobby.md** |
| Audio | api/audio.md |
| Input | api/input.md |
| Math types | api/math.md |
| Enumerations | api/enums.md |
| Global functions | api/globals.md |
| **材质列表** | **recipes/materials.md** |
| **渲染/灯光组/天空盒/天空球** | **recipes/rendering.md** |
| **动态天空/程序化天空/太阳/环境光跟随天空/IBL 捕获** | **recipes/sky-and-environment-lighting.md** |
| **体积云/云层/自定义云材质/shader_type cloud** | **recipes/surface-shader-addons/cloud.md** |
| **延迟渲染/SSR/SSGI/GTAO/TAA/GBuffer 后处理** | **recipes/deferred-rendering.md** |
| **灯光类型/阴影/级联阴影/局部光阴影/灯光数量上限** | **recipes/lights-and-shadows.md** |
| **体积雾/体积光/光柱/丁达尔/灯光光晕/局部雾团** | **recipes/volumetric-fog.md** |
| **草地/草坪/风吹草动/踩踏草丛/植被地表** | **recipes/grass.md** |
| **泛光/色调映射/自动曝光/景深/运动模糊** | **recipes/post-processing.md** |
| **昼夜循环/晴雨天气/闪电/湿地面/打光规范/水面** | **recipes/deferred-scene-weather-lighting.md** |
| **角色动画/FSM/BlendSpace/AimOffset/Root Motion/武器挂点** | **recipes/state-machine.md** |
| **次级骨骼运动/弹性骨骼/骨骼物理/头发、尾巴、裙摆、胸臀摆动/KawaiiPhysics** | **recipes/kawaii-physics.md** |
| **瓦片地形生成/加载** | **recipes/tile-terrain-guide.md** |
| **体素破坏/爆炸挖掘/Teardown 风格/体素载具** | **recipes/voxel-physics.md** |
| **体素联网/多人破坏/体素 Ready/联网色板** | **recipes/voxel-networking.md** |
| **文本审核/敏感词/聊天与昵称检查** | [recipes/text-moderation.md](recipes/text-moderation.md) |

---

**Version**: v0.1.0-alpha  
**Status**: Core framework ready, content in development
