# 延迟渲染（Deferred Rendering）

> 什么时候该用延迟渲染、怎么开启、开启后多了哪些效果、各平台的限制。
> 灯光与阴影见 [lights-and-shadows.md](lights-and-shadows.md)，体积雾见 [volumetric-fog.md](volumetric-fog.md)，后处理见 [post-processing.md](post-processing.md)。

---

## 1. 三条渲染管线

项目通过 `.project/engine.json` 配置渲染管线。

| 管线 | 何时使用 | 渲染路径文件 |
|---|---|---|
| 前向（桌面） | 默认。Windows / macOS / Linux 桌面、WebGL | `CEMapSSAO.xml` |
| 前向（移动） | 默认。iOS / Android / 其他 ARM 设备 | `CEMap.xml` |
| **延迟** | `.project/engine.json` 中 `rendering.pipeline` 为 `deferred` | `CEMapDeferred.xml` |

> WebGL 在引擎内部按"桌面图形"处理，所以前向时走 `CEMapSSAO`。

### 1.1 开启方式

在项目根目录的 `.project/engine.json` 中设置 `rendering.pipeline`：

```json
{
  "schema_version": 1,
  "rendering": {
    "pipeline": "deferred"
  }
}
```

已有文件时合并上述字段，保留其他配置；修改配置后随项目重新构建发布。Runtime 在执行项目 Lua 入口前自动应用配置，无需在 Lua 中手动加载。

Lua 的 `viewport:SetRenderPath(...)` 只替换渲染命令，不改变管线设置，不能代替 `engine.json` 的管线配置。

---

## 2. 延迟渲染多了什么

| 效果 | 前向（桌面） | 前向（移动） | 延迟 | Lua 开关 |
|---|:-:|:-:|:-:|---|
| 屏幕空间反射 SSR | — | — | ✅ | `zone.ssrEnabled`（默认 **开**） |
| 屏幕空间全局光照 SSGI | — | — | ✅ | `zone.ssgiEnabled`（默认关） |
| 环境光遮蔽 | 计算着色器 SSAO（固定参数） | — | ✅ GTAO | `zone.ssaoRadius` / `ssaoIntensity`（仅延迟生效） |
| TAA 抗锯齿 | — | — | ✅ 始终开启 | 无 |
| 运动模糊 | — | — | ✅ | `zone.motionBlurEnabled` |
| GBuffer 后处理（湿地面、水洼等） | — | — | ✅ | `zone:AddGBufferPostProcess(mat)` |
| 反射探针 | — | — | ✅（需 compute） | — |
| 体积雾 | ✅ | — | ✅ | 见 [volumetric-fog.md](volumetric-fog.md) |
| 泛光、色调映射、自动曝光、景深、暗角 | ✅ | ✅ | ✅ | 见 [post-processing.md](post-processing.md) |
| 单层水面 | ✅ | ✅ | ✅（额外有 SSR） | — |

要点：

- **SSR 默认开启**。延迟下光滑表面（水、湿地面、车漆）自动有屏幕空间倒影；SurfaceShader 用 `shading_model_pbr` 写入 GBuffer 即可获得，不要用 unlit 手写反射。
- **TAA 在延迟下始终开启**，没有 Lua 开关。它会让高频细节（细栏杆、雨丝）略软；前向桌面默认用 MSAA，延迟不用 MSAA。
- **GBuffer 后处理只在延迟下执行**。在前向管线下注册不会报错，但没有效果。写法见 [surface-shader-addons/gbuffer-postprocess.md](surface-shader-addons/gbuffer-postprocess.md)。
- 延迟下有一个全屏"场景雾"pass，`zone.skyFogIntensity` 只在这里生效。

---

## 3. 大量灯光

延迟渲染适合灯很多的场景，但**灯多不多、便宜不便宜，主要取决于"集群光照"是否可用**，而不只取决于管线：

- 设备支持计算着色器时，点光、聚光、面光进入同一个 GPU 光源列表（集群光照），前向和延迟都受益，灯的数量对开销影响很小。
- 不支持计算着色器（或使用正交相机）时退回逐灯绘制，灯越多越慢。
- 方向光不进集群，单独计算。

每个视图的光源上限（超出的灯会被**静默丢弃**，不报错）：

| 类型 | 桌面 | 移动 |
|---|--:|--:|
| 点光 | 150 | 75 |
| 聚光 | 150 | 75 |
| 面积点光（`punctualLight = false`） | 150 | 20 |
| 矩形面光 | 150 | 18 |

> 面光（`LIGHT_RECT`）和面积点光只在最高画质下生效，而默认最高画质只在 Windows 上启用；其他平台这两类灯会被丢弃。详见 [lights-and-shadows.md](lights-and-shadows.md)。

---

## 4. 平台与能力

| 能力 | 依赖 |
|---|---|
| 集群光照、froxel 体积雾、局部光阴影、反射探针 | 计算着色器：`graphics:GetComputeShaderSupport()` |
| 延迟渲染本身 | 引擎不阻止在移动端或 WebGL 开启（GBuffer 需要 5 个渲染目标），但**未经验证**，不建议在这些平台使用 |

检查计算着色器支持：

```lua
if not graphics:GetComputeShaderSupport() then
    print("[MyGame] 设备不支持计算着色器：体积雾退回简化版本，局部光没有阴影")
end
```

---

## 5. 选择建议

| 需求 | 建议 |
|---|---|
| 手机、网页、普通 3D 小游戏 | 前向（默认）。LightGroup 预设 + 少量点光就够 |
| 桌面、追求画质：水面/湿地倒影、间接光、运动模糊、GBuffer 特效 | 延迟 |
| 夜景、城市、大量路灯 | 两者都行；关键是设备支持计算着色器（集群光照） |
| 体积光/丁达尔光柱 | 两者都行（桌面）；移动前向没有体积雾 |

昼夜、天气、打光与体积光的通用做法：[deferred-scene-weather-lighting.md](deferred-scene-weather-lighting.md)（完整示例 [examples/30-pelican-bike](../../examples/30-pelican-bike)）。
