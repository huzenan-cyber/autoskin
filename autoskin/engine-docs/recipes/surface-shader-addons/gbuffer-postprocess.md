# 延迟表面后处理 / GBuffer Postprocess

返回 [Surface Shader 编写教程](../surface-shader.md)。只需为当前任务阅读本 addon。

`render_mode gbuffer_postprocess` 在延迟表面完成后、光照和 SSR 等消费者之前，对当前像素的
表面属性执行 `fragment()`。引擎提供全屏绘制和深度重建，作者将 Material 注册到 Zone。
原始物体只要写入兼容的 GBuffer，就能参与，无需使用 SurfaceShader。

English: GBuffer postprocess is a zone-owned fullscreen SurfaceShader domain. Properties start
from the current deferred surface. The renderer preserves untouched channels and applies effects
in registration order before lighting. The first integrated path is `CEMapDeferred` with single-sample targets.

例如 `assets/Shaders/BLGL/WetSurface.shader`：

```glsl
shader_type spatial;
render_mode gbuffer_postprocess;

uniform float wetness : hint_range(0.0, 1.0) = 0.5;

void fragment() {
    if (SHADING_MODEL == SHADING_MODEL_PBR || SHADING_MODEL == SHADING_MODEL_TOON) {
        float upward = smoothstep(0.3, 0.8, NORMAL.y);
        ROUGHNESS = mix(ROUGHNESS, 0.08, wetness * upward * RAIN_EXPOSURE);
    }
}
```

在场景生效的 Zone 上注册，视口使用 `CEMapDeferred`：

```lua
local zone = scene:GetChild("Zone"):GetComponent("Zone")
local wetSurface = Material:new()
assert(wetSurface:SetSurfaceShader("Shaders/BLGL/WetSurface.shader"))
local wetHandle = zone:AddGBufferPostProcess(wetSurface)
assert(wetHandle ~= 0)

wetSurface:SetShaderParameter("wetness", Variant(0.8))
zone:SetGBufferPostProcessEnabled(wetHandle, true)
-- 不再需要时：zone:RemoveGBufferPostProcess(wetHandle)
```

Zone 使用引擎现有的优先级和主控选择规则；生效 Zone 的空列表表示无效果，不叠加其他 Zone。
效果覆盖当前视图，Zone 包围盒不会自动裁剪像素。局部范围由 shader 的世界坐标等输入控制。
多个视图共享同一 Zone 配置时，各自保留效果状态和历史，临时纹理由引擎屏幕缓冲池复用；列表在本帧 Zone 选择完成后取快照，
之后的列表修改在下一次 View 更新生效。Material uniform 继续使用当前参数。
这些方法注册运行时 Material 实例，列表目前不作为 Zone 场景属性保存，场景加载后应由脚本注册。

## Zone 效果列表

| 方法 | 参数与返回值 |
|------|-------------|
| `AddGBufferPostProcess(material)` | 追加并持有 Material；返回非零 handle。不兼容材质返回 `0`。同一 Material 可注册多次，每次 handle 独立 |
| `RemoveGBufferPostProcess(handle)` | 删除对应注册；找到时返回 `true`，未知 handle 返回 `false` |
| `SetGBufferPostProcessEnabled(handle, enabled)` | 切换执行状态且保留顺序；未知 handle 返回 `false` |
| `MoveGBufferPostProcess(handle, index)` | 移到从 `0` 开始的位置；未知 handle 或越界返回 `false`，成功返回 `true` |
| `ClearGBufferPostProcesses()` | 删除全部注册，释放 Zone 持有的 Material 引用 |

后一个效果读取前一个效果的结果。uniform、`SetSurfaceTexture()`、默认纹理和资源热重载继续使用
现有材质接口。禁用、空链及没有表面属性写入的效果不产生额外 draw/copy。
有效效果结构或 shader 改变后，已接入的 TAA、SSR、SSGI、GTAO 和屏幕空间阴影历史失效，相机运动与
深度历史保持连续。空 Zone 之间切换、禁用/no-op 效果调整及连续 uniform 更新不会触发历史重置。
这个 Material 只生成 `gbufferpostprocess` pass；挂到普通 Drawable 时，现有场景 pass 选择会跳过它。
普通材质注册成 GBuffer 效果时，Zone 接口返回 `0` 并输出诊断。

## 属性与输入

`ALBEDO`、`ROUGHNESS`、`SPECULAR`、`METALLIC`、`NORMAL`、`EMISSION` 可读写；初值来自当前表面。
未修改值与辅助通道保持原样。`fragment()` 沿用 Godot 的入口函数规则，不允许 `return`；
需要跳过修改时使用 `if` 条件分支。辅助函数中的 `return` 沿用原有规则。标量材质属性写回限制为 `[0, 1]`；
`EMISSION` 保留 HDR。非有限输出和无效法线保留对应输入属性，有效法线会归一化。

| `SHADING_MODEL` 常量 | 可写属性 |
|----------------------|------------|
| `SHADING_MODEL_PBR` / `SHADING_MODEL_TOON` | 全部六种属性 |
| `SHADING_MODEL_CLEAR_COAT` / `SHADING_MODEL_PBR_BACKLIGHT` | 全部六种属性；保留清漆或透光的专用参数 |
| `SHADING_MODEL_LAMBERT` / `SHADING_MODEL_TOON_OUTLINE` | `ALBEDO`、`NORMAL`、`EMISSION`；保留各模型原生参数 |
| `SHADING_MODEL_UNLIT` | `NORMAL`；合并后的无光照颜色保持原样 |
| 未知模型或背景 | 原样保留 |

`SHADING_MODEL` 为只读 `uint`。不支持的标量读值为粗糙度 `1`、高光/金属度 `0`；不支持的底色/
发光读值为 `vec3(0)`，写入不生效。合法 Unlit 表面不是背景，背景由深度判断。

只读场景输入包括世界空间 `VERTEX`、`VIEW`、`SCREEN_UV`、`VIEWPORT_SIZE`、
`CAMERA_POSITION_WORLD`、`VIEW_MATRIX`、`INV_VIEW_MATRIX`、`PROJECTION_MATRIX`、
`INV_PROJECTION_MATRIX` 和 `TIME`。`NORMAL` 是世界空间着色法线。

只读 `RAIN_EXPOSURE` 表示直接雨暴露度；首版为全未遮挡默认值 **`1.0`**，常量折叠后不增加雨图
采样或场景绘制。尚未实现真实雨遮挡与积水历史，不提供 `hint_rain_occlusion_map`。

该模式只接受 `fragment()` 和普通辅助函数，禁止 `vertex()`、`light()`、varying、`discard`、
其他 render_mode/stencil_mode、深度/覆盖率写入，以及 `UV`、切线、对象/实例数据和无对应表面语义
的属性。普通 screen/depth/normal-roughness sampler hint 也不接受。自有 sampler 沿用现有规则，
输入附件占用五个槽位，桌面最多剩余三个作者 sampler；移动/Web 的编译预算剩余一个，但尚需平台验收。

首版使用引擎现有的 GBuffer 编码，RenderPath 只需声明 `gbufferpostprocess` 阶段及其输入输出，
并满足单采样、附件格式与尺寸要求。Forward、透明物体及未进入 GBuffer 的
表面不在此阶段处理。玩法项目优先使用已支持的 `CEMapDeferred`；其他 RenderPath 需要运行环境本身
已提供对应阶段，不能仅靠添加 `render_mode` 启用。
