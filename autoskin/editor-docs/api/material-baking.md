# Editor.MaterialBaking

在 UV 空间执行模型材质的 GPU shader，返回 Lua 可直接采样的 `Image`。用于体素取色、
贴图导出、材质简化等编辑器工具。输入输出不依赖体素系统。

Evaluate material shaders in UV space and return CPU-readable images to Editor Scripts.
This API is independent of voxelization and exists only in the Editor Script VM.

## 调用 / Usage

```lua
local model, modelErr = AssetDatabase.LoadAssetAtPath("Model", "Models/Wall.mdl")
local material, materialErr = AssetDatabase.LoadAssetAtPath("Material", "Materials/Brick.xml")
if not model or not material then
    Editor.Error(modelErr or materialErr)
    return
end

local accepted, err = Editor.MaterialBaking.Bake(model, { material }, {
    resolution = 512,
    allowFallback = false,
}, function(result, bakeErr)
    if not result then
        Editor.Error(bakeErr)
        return
    end
    local g = result.geometries[1] -- LOD0 geometry 0
    local rect = g.uvRect
    local sourceU, sourceV = 0.25, 0.75
    local u = (sourceU - rect.x) * rect.z
    local v = (sourceV - rect.y) * rect.w
    local color = g.albedo:GetPixelBilinear(u, v)
    Editor.Log(string.format("RGB %.3f %.3f %.3f", color.r, color.g, color.b))
    local image, saveErr = AssetDatabase.CreateAsset(
        g.albedo, "Generated/Baked/Wall_albedo.png", { overwrite = false })
    if not image then
        Editor.Error(saveErr)
    end
end)
if not accepted then
    Editor.Error(err)
end
```

把调用放进菜单回调或按钮处理，避免每帧提交。多材质模型传入按 geometry 顺序排列的
`{ material0, material1, ... }`；Lua 数组从 1 开始，`geometryIndex` 从 0 开始。
也可使用模型组件已有的 `Model` 和 `Material`，或脚本在内存中创建的资源。

## 调度与生命周期 / Scheduling and lifetime

| API | 说明 |
|---|---|
| `IsSupported() -> bool` | 检查真实渲染器是否可用；不代表某个 shader 一定可烘焙 |
| `Bake(model, materials, options, onComplete) -> accepted, err` | 入队。立即拒绝返回 `false, err`，不调用回调 |
| `onComplete(result, err)` | 后续 Update 中调用一次；成功为 `result, nil`，烘焙失败为 `nil, err` |

每次 Update 最多执行一个请求，安排在编辑器视口/UI 绘制之前。GPU 绘制和读回在主线程同步
执行，大模型仍会暂时阻塞编辑器；入队不等于后台线程烘焙。回调不在 `OnGUI` 内，不能调用
`GUILayout` / `EditorGUILayout`。需要预览时保存结果，在后续 `OnGUI` 中绘制。

宿主持有排队中的输入资源，执行时读取其状态；提交后不要在完成前修改模型或材质。
结果中的 `Image` 由 Lua 引用计数管理，可以保留到回调结束之后。释放 Lua 引用后可被 GC 回收。
热加载脚本、卸载/切换工程会清理未执行的请求，不再调用旧回调。PIE 中拒绝烘焙；排队后进入
PIE 的请求通过回调报告 `EDITOR_SCRIPT_NOT_IN_EDIT_MODE`。

Saving uses the existing `AssetDatabase` project boundary, metadata generation and overwrite rules.
No files are created by `Bake` itself. Scene changes in a completion callback should use `Editor.Undo`.
回调报错时，宿主只撤销本次回调创建的隐式 Undo 组；已存在的外部事务由其调用方负责
提交或取消，宿主不会因烘焙回调报错而取消该事务。

## 参数 / Options

| 字段 | 默认 | 契约 |
|---|---|---|
| `resolution` | 256 | 整数 1..2048，不超过 GPU 纹理上限；每个 geometry 一套正方形图片 |
| `allowFallback` | false | false 时要求材质 shader 接入烘焙契约；true 时允许启发式固定 PBR 降级 |

最多排队 8 个请求；单次请求的 `geometry 数量 * resolution²` 不超过 16,777,216。
所有 geometry 成功才返回结果，失败不返回部分图片。默认必须提供每个 geometry 的材质；
显式允许降级时可以用空槽，仍保持原 geometry 索引。

## 输出 / Result

顶层为 `{ version = 1, resolution = N, format = "RGBA8", geometries = {...} }`。
这是 Editor Lua 返回结构的版本，独立于 CLI `bake.json` 的版本 2。
版本由 `MaterialBakeResult.h` 中的 `kEditorBakeResultVersion` 定义；不兼容的字段或编码
语义变更必须提升该版本，消费方应检查自己支持的版本。

| 每个 geometry 的字段 | 含义 |
|---|---|
| `geometryIndex` | 模型 LOD0 索引，0-based |
| `layout` | `Material` 或降级的 `FixedPBR` |
| `colorEncoding` | `Material` 为 `sRGB`；`FixedPBR` 为 `source`，不保证等价于真实材质求值 |
| `uvRect` | `Vector4(minU, minV, inverseExtentU, inverseExtentV)` |
| `albedo` | 底色；alpha 是扩张后的覆盖率，**不能当材质透明度** |
| `rme` | R=roughness，G=metallic，B=occlusion |
| `normal`, `normalEncoding` | EncodeNormal 编码的 shader/model 空间法线，**不能直接当切线空间 normal map**；降级时缺省 |
| `emissive` | 自发光颜色 |
| `opacity` | red 是未扩张的材质透明度/裁剪结果，UV 岛外为 1；降级时缺省 |
| `coverage` | alpha 是原始 UV 几何覆盖，不受材质 discard 影响 |
| `rawTargets` | 未转换、未扩张的 MRT `Image[]`，Lua `[1]` 对应 RT0 |

`Material` 原始目标：RT0=linear albedo + opacity；RT1=roughness/metallic/AO/1；
RT2=EncodeNormal/1；RT3=linear emissive/1。`albedo` / `emissive` 便利图转为 sRGB。
`FixedPBR` 只有三个原始目标：albedo、roughness/metallic/AO、emissive。
所有图片都是 RGBA8，不是 HDR；`Image:GetPixel*` 返回 0..1 通道值，不会自动解码 sRGB。

UV 范围按该 geometry 实际引用的顶点计算。先使用 `uvRect` 映射源 UV，再采样；不需要手动翻转 V。
覆盖掩码保留原始区域；便利颜色图会扩张 UV 岛边缘。需要准确区分空白和透明孔洞时同时读取
`coverage` 与 `opacity`。

## 支持边界 / Limits

当前烘焙静态 LOD0，模型变换为 identity，时间固定为 0。不烘焙动画姿态或节点世界变换。
场景光照、阴影、视角依赖、屏幕/深度纹理和世界位置依赖效果不能保证复现；重叠 UV 也无法
保存同一 UV 下多个表面的不同属性。ClearCoat 等额外专属属性不单独输出。

Built-in material families and generated SurfaceShaders use the common `MATERIALBAKE` shader contract.
Unsupported shaders fail by default. Fallback is opt-in and is labeled in each geometry result.
Atlas packing, tangent-space conversion and voxel color reduction belong to the consumer.

## 错误 / Errors

| 错误码 | 含义 |
|---|---|
| `EDITOR_SCRIPT_BAKE_INVALID_ARGUMENT` | 模型、选项或回调类型不合法 |
| `EDITOR_SCRIPT_BAKE_INVALID_MATERIALS` | 槽位不是 1-based geometry 索引、类型错误或默认模式下缺材质 |
| `EDITOR_SCRIPT_BAKE_INVALID_RESOLUTION` | 非整数、超出接口/GPU 上限 |
| `EDITOR_SCRIPT_BAKE_PIXEL_LIMIT` | 单请求总像素预算超限 |
| `EDITOR_SCRIPT_BAKE_QUEUE_FULL` | 已有 8 个排队请求；可在前一个完成回调中提交下一个 |
| `EDITOR_SCRIPT_BAKE_UNSUPPORTED` | 没有真实渲染器；headless/Noop 不可用 |
| `EDITOR_SCRIPT_BAKE_FAILED` | 几何/UV、shader 编译或 GPU 烘焙失败；Console 有详细原因 |
| `EDITOR_SCRIPT_NOT_IN_EDIT_MODE` | 当前是 PIE |

完整工具示例：[MaterialBakeTool.lua](../examples/MaterialBakeTool.lua)。
