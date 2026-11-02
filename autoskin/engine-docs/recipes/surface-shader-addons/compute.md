# GPU 计算 / Compute

返回 [Surface Shader 编写教程](../surface-shader.md)。只需为当前任务阅读本 addon。

`shader_type compute` 用于生成遮罩/数据纹理、批量变换数组或逐元素更新模拟状态。继续使用
Godot 风格的 `.shader`，由 Lua 的 `ComputeDispatch` 提交；输出纹理可直接交给普通材质，
输出 buffer 可交给下一次计算，或异步读回 Lua。

English: Use `shader_type compute` with `ComputeDispatch` to process textures and typed buffers on the GPU.
Prefer `DispatchThreads` for logical element counts. Dispatches run in order before rendering;
buffer readback is asynchronous. The shader syntax and Lua API below are UrhoX extensions.

这属于抢先体验功能。当前已验证 Windows DX11 和桌面 OpenGL；其他后端尚未完成验收。
运行时先用 `graphics:GetComputeShaderSupport()` 检查总体能力，再检查 `SetShader`、资源创建及
调度的返回值；总体能力为 true 不代表所有工作组尺寸、资源格式和读回方式都可用。
无图形设备的服务端、Noop/validate 环境不执行计算；不支持时没有自动 CPU 回退。
面向 Web/移动平台的玩法应准备不依赖 compute 的替代效果，并在目标设备验证。

## 文件与对象分工

| 对象 | 负责什么 |
|------|----------|
| `assets/Shaders/BLGL/*CS.shader` | `shader_type compute`、工作组尺寸、资源声明、唯一的 `void compute()` 入口；文件名用大写驼峰并以 `CS` 结尾 |
| `ComputeDispatch:new()` | 持有一份 shader 的参数和绑定，允许复用；同一 shader 的多个实例互不影响 |
| `Texture2D` / `ComputeBuffer` | 持有 GPU 数据；资源可在不同 ComputeDispatch 之间共享 |
| `ComputeReadback` | 一次 buffer 快照的异步结果，通过 `IsReady()` / `HasError()` 判断状态 |

Lua 路径从 `Shaders/` 开始，不带 `assets/`。资源和参数都按 shader 源码名称绑定，区分大小写，
无需指定槽位。不要将 compute shader 传给 `Material:SetSurfaceShader()`；材质使用另一个
`shader_type spatial` 文件采样计算结果。也不要使用 Unity 的 `#pragma kernel`、`FindKernel`、
HLSL 线程语义或 Godot RenderingDevice 的原生 GLSL 写法。

## 示例一：生成纹理并用于材质

保存为 `assets/Shaders/BLGL/GenerateMaskCS.shader`：

```glsl
shader_type compute;
workgroup_size(8, 8, 1);

uniform float radius = 0.3;
uniform writeonly image2D result : format_rgba8;

void compute() {
    ivec2 pixel = ivec2(GLOBAL_INVOCATION_ID.xy);
    vec2 uv = (vec2(pixel) + vec2(0.5)) / vec2(DISPATCH_SIZE.xy);
    float mask = 1.0 - smoothstep(radius, radius + 0.02, length(uv - vec2(0.5)));
    imageStore(result, pixel, vec4(vec3(mask), 1.0));
}
```

保存采样材质为 `assets/Shaders/BLGL/ShowMask.shader`：

```glsl
shader_type spatial;
render_mode shading_model_unlit;
uniform sampler2D mask_map : filter_linear, repeat_disable;

void fragment() {
    ALBEDO = texture(mask_map, UV).rgb;
}
```

在 Lua 中提供创建函数，并在现有 `Start()` 中调用：

```lua
---@param width integer
---@param height integer
---@return Material
---@return ComputeDispatch
---@return Texture2D
local function CreateMaskMaterial(width, height)
    assert(graphics and graphics:GetComputeShaderSupport(), "Compute is unavailable on this device")
    local compute = ComputeDispatch:new()
    assert(compute:SetShader("Shaders/BLGL/GenerateMaskCS.shader"), compute:GetLastError())

    local mask = compute:CreateImage2D("result", width, height)
    assert(mask, compute:GetLastError())
    assert(compute:SetShaderParameter("radius", 0.35), compute:GetLastError())
    assert(compute:DispatchThreads(width, height), compute:GetLastError())

    local material = Material:new()
    assert(material:SetSurfaceShader("Shaders/BLGL/ShowMask.shader"))
    assert(material:SetSurfaceTexture("mask_map", mask))
    return material, compute, mask
end
```

例如在 `Start()` 中用 `CreateMaskMaterial(513, 257)` 获取材质，再通过现有
`StaticModel:SetMaterial(material)` 挂到模型。需要后续更新时，把返回的 compute 和 mask 保存到
模块变量或组件字段；在 `Update` 中设置新参数并再次 `DispatchThreads(mask:GetWidth(), mask:GetHeight())`。
不要每帧重建资源。

`CreateImage2D` 自动按 `result` 声明创建线性、单 mip 的普通 Texture2D 并绑定。新纹理内容未定义，
本例在采样前写满全部像素。遮罩是数值数据，材质 sampler 不加 `source_color`。
513 和 257 不必是工作组尺寸的整数倍：引擎屏蔽补齐线程，只有指定范围内的像素进入 `compute()`。

## 调度尺寸、三维索引与设备适配

| Lua 调用 | 参数单位 | 边界责任 |
|----------|----------|----------|
| `DispatchThreads(x, y = 1, z = 1)` | 逻辑线程数，通常对应元素数/像素数 | 引擎逐轴向上取整组数，并屏蔽超出逻辑范围的补齐线程；推荐默认使用 |
| `DispatchGroups(x, y = 1, z = 1)` | 工作组数 | 完整工作组都会执行，作者必须保护算法的数据边界；高级用法 |

两者都支持一维、二维、三维；省略轴默认为 1。`workgroup_size(64, 1, 1)` 配合
`DispatchThreads(1000)` 会启动 16 组，但只有全局 x 为 0..999 的线程执行用户入口。
同样调用 `DispatchGroups(16)` 时，0..1023 的线程都会执行，`DISPATCH_SIZE.x` 也变成 1024。

**DispatchThreads 只保护调度范围，不保证任意资源访问安全。** 输出资源比范围小、读取相邻元素、
自定义下标错误或多个线程写同一地址仍由作者负责。尺寸必须是非负整数；任一轴为 0 时不执行计算。
非法尺寸/超限返回 false，不截断，也不自动拆成多次 dispatch。

`workgroup_size(x, y, z)` 必须声明一次，三个参数都是正的编译期整数常量。
跨设备优先从 `(64, 1, 1)`、`(8, 8, 1)` 或 `(4, 4, 4)` 起步。引擎按声明计算组数，
不会按设备悄悄修改工作组；`GetWorkgroupSize()` 可读取实际声明值。当前桌面 DX11/DX12/OpenGL
总线程数上限为 1024，其他后端按 128 限制，z 轴最多 64；这不是对未验证平台的可用性承诺。
每轴组数最多 65535，每轴逻辑线程数最多 16777216（2^24），还受实际设备能力限制。

| shader 内建量 | 类型 | 含义 |
|---------------|------|------|
| `GLOBAL_INVOCATION_ID` | `uvec3` | 全局线程坐标，从 0 开始；一维算法使用 `.x` |
| `LOCAL_INVOCATION_ID` | `uvec3` | 当前组内线程坐标，从 0 开始 |
| `WORKGROUP_ID` | `uvec3` | 当前工作组坐标，从 0 开始 |
| `WORKGROUP_SIZE` | `uvec3` | 源码声明的工作组尺寸 |
| `NUM_WORKGROUPS` | `uvec3` | 本次三个轴的实际组数 |
| `LOCAL_INVOCATION_INDEX` | `uint` | 当前组内的一维索引，不是整个 buffer 的索引 |
| `DISPATCH_SIZE` | `uvec3` | Threads 的逻辑范围；Groups 则为组数乘工作组尺寸 |

所有内建量只读，不能重新声明或作为 `out/inout` 参数写入。
三维计算可用 `DispatchThreads(width, height, depth)`，把坐标展开到一维 buffer：

```glsl
uvec3 p = GLOBAL_INVOCATION_ID;
uint i = p.x + DISPATCH_SIZE.x * (p.y + DISPATCH_SIZE.y * p.z);
```

该片段放在 `compute()` 内，x 轴变化最快。调用方按 `width * height * depth` 分配 buffer，并确保
乘积不超过 buffer 元素上限；三维调度不需要 image3D，当前也没有开放该资源类型。

## 示例二：buffer 变换与异步读回

保存为 `assets/Shaders/BLGL/ScalePointsCS.shader`：

```glsl
shader_type compute;
workgroup_size(64, 1, 1);

uniform float scale = 2.0;
readonly buffer vec4 source_data[];
writeonly buffer vec4 result_data[];

void compute() {
    uint i = GLOBAL_INVOCATION_ID.x;
    if (i < bufferLength(source_data) && i < bufferLength(result_data)) {
        vec4 position = source_data[i];
        result_data[i] = vec4(position.xyz * scale, position.w);
    }
}
```

Lua 示例展示 1000 个点及结果检查；已有项目将初始化和轮询合入自己的 `Start` / `Update`，
不要定义第二个 `Start()` 覆盖原有入口：

```lua
---@type ComputeReadback?
local pendingResult = nil

function Start()
    if not graphics or not graphics:GetComputeShaderSupport() then
        print("Compute is unavailable; use the project's CPU or static fallback")
        return
    end

    local initial = VectorBuffer()
    for luaIndex = 1, 1000 do
        initial:WriteVector4(Vector4(luaIndex - 1, 0, 0, 1))
    end

    local compute = ComputeDispatch:new()
    assert(compute:SetShader("Shaders/BLGL/ScalePointsCS.shader"), compute:GetLastError())
    local source = compute:CreateBuffer("source_data", 1000, initial)
    assert(source, compute:GetLastError())
    local output = compute:CreateBuffer("result_data", 1000)
    assert(output, compute:GetLastError())
    assert(compute:SetShaderParameter("scale", 3.0), compute:GetLastError())
    assert(compute:DispatchThreads(1000), compute:GetLastError())
    pendingResult = output:RequestReadback()
    SubscribeToEvent("Update", "PollComputeResult")
end

function PollComputeResult()
    local request = pendingResult
    if not request or not request:IsReady() then
        return
    end
    pendingResult = nil
    if request:HasError() then
        print("Compute readback failed: " .. request:GetError())
        return
    end

    local data = request:GetData()
    for luaIndex = 1, 1000 do
        local point = data:ReadVector4()
        assert(point == Vector4((luaIndex - 1) * 3, 0, 0, 1))
    end
    print("Compute result verified")
end
```

shader 下标从 0 开始；Lua table 索引仍从 1 开始。VectorBuffer 按写入顺序连续存放字节，
初始化数据必须正好等于 `count * stride` 字节，不是把 Lua table 直接传给 `CreateBuffer`。
没有初始数据的 buffer 会清零。`GetData()` 返回游标从 0 开始的快照副本，只在成功后取一次再顺序读取。

**不要用 while 循环等待 `IsReady()`。** 请求需要后续渲染帧推进；在之后的 Update 中检查。
`IsReady()` 为 true 也可能表示失败/取消，必须再检查 `HasError()`。不支持读回的设备会返回错误请求。
只把结果用于材质或下一次 compute 时，不需要 CPU 读回；也不要每帧对大 buffer 做读回。

## 资源类型、共享与权限

| buffer 元素类型 | 每元素字节数 | VectorBuffer 写入 / 读取 |
|-----------------|--------------|-------------------------|
| `float` | 4 | `WriteFloat` / `ReadFloat` |
| `int` | 4 | `WriteInt` / `ReadInt` |
| `uint` | 4 | `WriteUInt` / `ReadUInt` |
| `vec4` | 16 | `WriteVector4` / `ReadVector4` |
| `ivec4` | 16 | 连续四次 `WriteInt` / `ReadInt` |
| `uvec4` | 16 | 连续四次 `WriteUInt` / `ReadUInt` |

每个 buffer 有 1..16777216 个元素，绑定时类型必须与声明精确一致。没有 `vec3`、bool、矩阵或
用户 struct 的 storage 布局，也不支持将 VertexBuffer/IndexBuffer 直接传给 `SetBuffer`。
buffer 内容中的 int/uint 保留完整 32 位值；它们与整数 uniform 的范围限制不同。

buffer 不必通过某个 ComputeDispatch 创建。需要独立管理时：

```lua
local shared = ComputeBuffer:new()
assert(shared:SetSize("vec4", 1000), shared:GetLastError())

local compute = ComputeDispatch:new()
assert(compute:SetShader("Shaders/BLGL/ScalePointsCS.shader"), compute:GetLastError())
assert(compute:SetBuffer("source_data", shared), compute:GetLastError())
local output = compute:CreateBuffer("result_data", 1000)
assert(output, compute:GetLastError())
```

`ComputeBuffer:SetSize(type, count, initialData?)` 创建/重建存储；`GetElementType()`、`GetCount()`、
`GetStride()` 查询布局，`Release()` 释放存储。它没有 `SetData()` 更新接口；再次初始化可新建 buffer，
或通过另一个 compute 写入。已入队后不要对其 `SetSize` / `Release`，否则依赖旧存储的任务会失败。

`readonly` 允许读，`writeonly` 允许写，`readwrite` 同时允许读写。`readwrite` buffer 支持
`positions[i].x += value`、swizzle 和元素的 `out/inout` 传参；整个 buffer 只能用于下标访问及
`bufferLength(buffer)`，不能整体赋值或当作普通数组参数传递。`+=` / `++` 不是原子操作。
一个线程独占一个元素时可以原地更新；需要读邻居旧值的模拟应使用两个 buffer 交替读写。

image 声明为 `uniform readonly image2D name : format_rgba8;` 或 `uniform writeonly image2D ...`，
必须指定 `format_rgba8`、`format_rgba16f` 或 `format_rgba32f`，并由设备支持。
使用 `imageLoad` / `imageStore` 读写，`imageSize` 查询绑定 mip 的尺寸，坐标与 `texelFetch` 一致。
当前不支持 `readwrite image2D`。`SetImage` 可绑定已有的兼容 Texture2D：必须线性、单采样、格式一致，
可写纹理必须在 `SetSize()` 分配之前启用 `SetComputeWrite(true)`；事后改标志不能补齐已有存储能力。
优先用 `CreateImage2D` 避免遗漏配置；也可将前一阶段的输出通过 `SetImage` 或 `SetTexture` 交给下一阶段。

同一次 dispatch 中，同一资源不能绑定到多个名称且任一绑定可写，包括 sampler/image 别名和不同 mip。
一个 `readwrite buffer` 声明内部的读写允许；跨 dispatch 共享允许，按提交顺序执行。

## Lua 接口速查与参数

下表是 `ComputeDispatch` 的方法；类名不是 `ComputeShader` 或 `Compute`，无需 `require`。

| 方法 | 返回与约束 |
|------|------------|
| `SetShader(pathOrSurfaceShader)` | bool；加载 compute `.shader` 并准备执行。成功后重置参数为默认值并清空绑定，失败保留原配置；初始化时调用 |
| `SetShaderParameter(name, value)` | bool；设置普通 uniform，按源码名称和类型检查 |
| `SetTexture(name, texture)` | bool；绑定 `sampler2D`，输入为单采样 Texture2D |
| `SetImage(name, texture, mip = 0)` | bool；绑定 storage image 的指定 mip，不自动生成其他 mip |
| `SetBuffer(name, buffer)` | bool；绑定 ComputeBuffer，校验元素类型 |
| `CreateImage2D(name, width, height)` | Texture2D 或 nil；按声明创建并绑定 image，宽高必须为正整数 |
| `CreateBuffer(name, count, initialData?)` | ComputeBuffer 或 nil；按声明创建并绑定 buffer |
| `GetWorkgroupSize()` | IntVector3；成功设置 shader 后读取工作组的 x/y/z |
| `DispatchThreads(x, y = 1, z = 1)` | bool；按逻辑线程数入队，推荐入口 |
| `DispatchGroups(x, y = 1, z = 1)` | bool；按工作组数入队，高级入口 |
| `GetLastError()` | 最近一次失败的可读诊断；每次 false/nil 后立即读取 |

三个资源 setter 可以传 nil 清除绑定。参与执行的资源必须绑定齐全，不会用默认白图代替缺失输入。
`SetShaderParameter` 可直接传 Lua number/boolean、Vector2/3/4、Color、Matrix3/4，以及从 1 开始的
无空洞数组。`mat2` 可用 Vector4，矩阵也可用按行排列的嵌套 table；uniform 数组的元素数量必须匹配声明。
无显式初值的 uniform 为零值（矩阵也是零矩阵）。整数 uniform 必须是整数且绝对值不超过 2^24，uint 不能为负。

## 提交时序、失败与生命周期

在 `Start` / `Update` / `PostUpdate` 提交，计算会在随后成功开始的渲染帧中、普通绘制之前按序执行。
不要在 `NanoVGRender` 等绘制回调中提交。`Dispatch*` 返回 true 表示已接受，**不表示 GPU 已完成**。
纹理可由同帧后续绘制直接采样；GPU 结果不会自动变成 Lua 数组或改变场景节点、碰撞体、网格顶点。

两次 dispatch 可以通过共享资源串联：先提交生产者，再提交消费者。入队时保存参数、绑定与范围，
之后改参数不会修改已接受的任务，但资源内容仍按执行顺序共享。读回请求也在同一顺序中取快照，
请求之后再写同一 buffer，不会覆盖该请求要返回的内容。

暂时跳过渲染时，任务和未完成读回保持 pending，恢复后继续；队列有容量上限，满时拒绝新请求，
保留已接受任务。遇到容量错误应停止本帧继续入队，等待后续帧再试，不要循环重试或每帧积压大量任务。
游戏退出/切换、设备丢失会取消任务；资源重建会使依赖旧存储的任务失效。设备恢复后重新创建和绑定所需资源。

入队后的取消/执行准备失败通过 `ComputeDispatchFailed` 事件报告；`Shader` 是路径，
`Sequence` 是提交序号，`Error` 是原因。异步读回通过请求本身报告失败，不要只检查 dispatch 的返回值：

```lua
function HandleComputeFailure(eventType, eventData)
    print(eventData["Shader"]:GetString() .. ": " .. eventData["Error"]:GetString())
end

-- Subscribe in Start; use SubscribeToEvent(compute, ...) to filter by instance.
SubscribeToEvent("ComputeDispatchFailed", "HandleComputeFailure")
```

队列持有已接受任务所需的引用。需要后续帧复用的 ComputeDispatch、资源及待轮询请求仍应由脚本保存；
完成使用后释放自己的引用即可。显式更换 shader 后必须重新设置参数和绑定。热重载后，已有参数或绑定
不再兼容时，提交返回 false，GetLastError 保留具体原因，实例仍保留旧配置；连续重试也不会使用默认值执行。
可以恢复兼容的 shader 声明，或重新调用 SetShader，再按新声明设置参数和绑定。

## 当前限制与常见错误

- 每个文件只有一个 `void compute()`，没有 kernel 名称参数；可用普通辅助函数和 include。
  入口内不能 `return`，跳过工作用 `if`；辅助函数可正常返回。
- 没有自动注入 `TIME`、相机矩阵或材质输出；时间、步长和场景数据须声明 uniform 并由 Lua 设置。
  不支持 `varying`、其他阶段入口、材质 render_mode 或屏幕/深度 sampler hint。
- 采样纹理用 `textureLod(source, uv, 0.0)` 或 `texelFetch(source, pixel, 0)`。
  不支持隐式导数采样 `texture` / `textureProj` 及 `dFdx` / `dFdy` / `fwidth`。
  sampler 可用 filter/repeat hint，不支持 `source_color` 或默认纹理 hint。
- 当前不支持 shared memory、barrier、atomic、indirect dispatch、image3D/array 和自定义 struct storage。
  `DispatchGroups` 也不会使这些能力变为可用；跨组依赖拆成多个有序 dispatch。
- 不使用 `surfaceCompute*`、`u_Compute*`、`ComputeStorage*`、`ComputeDispatchSize`、`ComputeGroups`、
  `ComputeResourceInfo` 声明用户变量、函数或资源；这些名字保留给运行环境。

| 现象 | 先检查 |
|------|--------|
| `SetShader` 返回 false | `.shader` 路径、`shader_type compute`、`workgroup_size`、设备支持，以及 `GetLastError()` 和运行日志的编译诊断 |
| 资源名称错误或没有绑定 | 名称区分大小写；sampler 用 SetTexture，image 用 SetImage，buffer 用 SetBuffer |
| 写入权限错误 | `+=` 需要 readwrite，不能用于 writeonly；image 不支持 readwrite |
| 输出边缘错误 | DispatchGroups 是否遗漏数据边界；DispatchThreads 的范围是否与资源和自定义下标一致 |
| 输入输出别名冲突 | 给本次计算分配独立输出，下一次 dispatch 再交换输入输出 |
| 提交成功但 Lua 没有结果 | 使用 RequestReadback，并在后续 Update 检查 IsReady 和 HasError；不能同步等待 |
| 读回一直 pending | 渲染是否暂停；不要通过重复请求催促完成 |
| 资源修改后旧任务失败 | 不要在已入队任务执行前 resize、Release 或重建其资源 |
