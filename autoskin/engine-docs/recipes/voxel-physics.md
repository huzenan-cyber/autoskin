# 体素物理指南（VoxelPhysicsWorld）（抢先体验版）
**当前为预览版本，发布前仍需充分验证**

多人玩法另读 [体素物理联网开发](voxel-networking.md)：服务器创建和修改共享体素，客户端等待内容 Ready；场景资源预热、两域色板和重连用法见该文档。

> **Teardown 风格的可破坏体素世界**：体素建筑/载具、爆炸挖掘、碎块飞溅、水面浮力、
> 角色控制器、抓取推拽、铰链机关、悬挂载具和实体组装轮。Jolt 求解器驱动，Lua 全量可用。

> 🖥️ **平台支持：Windows、macOS、iOS、Android 和 Web 可用**。
> HarmonyOS 已接入构建开关，但尚未完成原生构建与实机验证，当前视为实验性支持；
> Linux 暂未经过完整验证，默认构建暂不启用体素物理。

> ⚠️ **与其他系统的边界**（先读，避免混淆）：
> - 它与 `api/physics.md` 的 Bullet 物理（RigidBody/CollisionShape）是**两套互不碰撞的世界**，
>   只共享同一个渲染 Scene。体素体积不会与 RigidBody 发生碰撞——同一玩法请只选一套。
> - `examples/07-minecraft-voxel-world` 是纯 CustomGeometry 手搓渲染，**不是**本系统。
> - 完整可玩脚手架：`examples/27-voxel-town`（可破坏小镇 + 载具 + 水面 + 工具，复制即开工）。
> - 水域浮力与游泳的独立样例：`examples/32-engine-water`（引擎波浪、浮箱、空心船、游泳、水下）。
> - 可用性探测：`scene:CreateComponent("VoxelPhysicsWorld")` 返回 nil 说明当前运行时
>   未启用体素物理模块（在尚未支持的端上就是这个表现）。

---

## 一、最小可运行骨架

```lua
local scene = Scene()
scene:CreateComponent("Octree")
local world = scene:CreateComponent("VoxelPhysicsWorld")
world.gravity = Vector3(0, -9.81, 0) -- 全局重力；动态体积、碎块、载具和角色共用

-- ① 调色板：必须在任何 CreateVolumeFromModel 之前设置完毕
--    （.vox 导入会自动认领空槽位，晚了会被占）
local MAT_STONE, MAT_WOOD = 1, 2
world:SetPaletteEntry(MAT_STONE, Color(0.5, 0.5, 0.52), 6.0)   -- 硬度 6
world:SetPaletteEntry(MAT_WOOD,  Color(0.48, 0.35, 0.22), 1.2) -- 硬度 1.2

-- ② 手建一块 20×1×20 的静态地面（体素尺寸 0.25m）
--    材质自动默认本世界的调色板材质,不需要手动设
local ground = world:CreateVolume(80, 4, 80, 0.25, Vector3(-10, -1, -10))
local g = ground:GetGrid()
g:FillBox(0, 0, 0, 79, 3, 79, true)          -- 体素坐标是整数，含两端
g:PaintBox(0, 0, 0, 79, 3, 79, MAT_STONE)
world:FinalizeVolume(ground)                  -- 定型为静态
ground:RebuildGeometry()

-- ③ 一个会掉下来的动态木箱
local box = world:CreateVolume(6, 6, 6, 0.1, Vector3(0, 3, 0))
box:GetGrid():FillBox(0, 0, 0, 5, 5, 5, true)
box:GetGrid():PaintBox(0, 0, 0, 5, 5, 5, MAT_WOOD)
box.density = 400.0                          -- kg/m³，质量自动算
world:FinalizeVolumeAsDynamic(box)
box:RebuildGeometry()

-- ④ 完成。世界随场景更新自动步进，箱子会落到地面上
```

一个 Scene 只能创建 `PhysicsWorld` 或 `VoxelPhysicsWorld` 其中之一。`VoxelPhysicsWorld`
同样发送标准的 `PhysicsPreStep` / `PhysicsPostStep` 事件，因此 `LogicComponent`、
`LuaScriptInstance` 和玩法组件的固定步回调不需要区分物理后端。

**四条铁规**：
1. 世界随场景更新**自动步进**，无需手动调用。**输入/施力类意图（MoveCharacter、
   载具 SetInput、飞行力）订 `SceneUpdate` 事件**——它在同帧步进之前触发；订 `Update`
   的话场景（含步进）先于脚本执行，意图会晚一帧生效。要自控节奏（固定步长/lockstep）：
   `world.updateEnabled = false` 后自行每帧 `world:Update(timeStep, steps)`。
2. `SetPaletteEntry` 全部做完再导入 `.vox`。
3. 体积创建后必须 `FinalizeVolume`（静态）或 `FinalizeVolumeAsDynamic`（动态）二选一定型。
4. 材质**自动默认** `world:GetPaletteMaterial()`（本世界的调色板材质，绑好了
   调色板纹理，颜色/PBR/断面色都从纹理逐像素读取），`CreateVolume` 手建和
   `.vox` 烘焙都一样——只有换皮肤（自定义 SurfaceShader）才需要设
   `volume.material`。不要直接
   `cache:GetResource("Material", "Materials/VoxelPalette.xml")`——共享缓存资源
   没有绑定本世界的调色板纹理，会渲成白色。

---

## 二、体积（VoxelVolume）：创建、编辑、生命周期

### 从 .vox 模型创建（MagicaVoxel 格式）

```lua
local m = cache:GetResource("VoxelModel", "models/house.vox")   -- 资源路径按项目
local rot = Quaternion(90.0, Vector3(0, 1, 0))
local volume = world:CreateVolumeFromModel(m, 0.1, Vector3.ZERO, rot)

-- ⚠️ 体积原点在网格最小角（不是中心）。带朝向摆放时脚印会被甩走，
--    要按真实尺寸把最小角补偿回中心：
local dims = volume:GetGrid():GetDimensions()
volume:GetNode().position = targetPos
    + rot * Vector3(-dims.x * 0.1 * 0.5, 0.0, -dims.z * 0.1 * 0.5)

world:FinalizeVolume(volume)      -- 动态体先设 density，再 FinalizeVolumeAsDynamic(volume)
volume:RebuildGeometry()
```

材质自动默认 `world:GetPaletteMaterial()`，只有换皮肤才需要手动设 `volume.material`。
`.vox` 自带调色板会自动导入到空槽位；`VoxelModel` 只读接口：`GetDimensions()` /
`GetIndexAt(x,y,z)` / `GetPaletteColor(index)` / `GetVoxelCount()`。

### 手工编辑网格（VoxelGrid）

```lua
local g = volume:GetGrid()
g:SetSolid(x, y, z, true)                    -- 单体素增删
g:SetVoxelMaterial(x, y, z, MAT_WOOD)        -- 单体素调色板槽
g:FillBox(x0, y0, z0, x1, y1, z1, true)      -- 盒填充/挖空（含两端）
g:PaintBox(x0, y0, z0, x1, y1, z1, mat)      -- 盒涂材质
local solid = g:IsSolid(x, y, z)
local dims  = g:GetDimensions()              -- IntVector3
```

**运行时改完 grid 之后**：
- 静态体积：`volume:MarkRegionDirty(x0,y0,z0,x1,y1,z1)`（局部重网格，比整体便宜）或
  `volume:RebuildGeometry()`。
- 动态体积：还要 `world:RebuildDynamicProxy(volume)` 更新碰撞体
  （伤害 API 自己会做，只有**手改**才需要）。
- 从 `.vox` 创建的体积：还要 `volume:DetachFromVoxelModel()`，否则改动在存档
  重载后丢失（见下方"来源模型引用与存档"）。
- 项目开启 CPU 网格释放（`engine.json` 的 `voxel.dda.release_cpu_grid`，默认关闭）后：调用
  `volume:GetGrid()` 或读取 `volume.grid` 会恢复并让该实例的 CPU 网格持续常驻；只需要实心体素数量时用
  `volume:GetSolidCount()`，只需要尺寸时对未改过的模型体积用 `volume:GetVoxelModel():GetDimensions()`。
  这两种写法都不会让网格常驻。

### 来源模型引用与存档（Voxel Model 绑定）

`CreateVolumeFromModel` 会在体积上记录来源 `.vox`。未破坏的体积存档时只存这个
引用（场景文件小两个数量级），加载时自动重烘；第一次被伤害 API 破坏后自动切换为
全量体素快照，伤害状态精确保留。全程自动，通常无需关心。

```lua
volume:HasVoxelModel()          -- 是否仍绑定来源 .vox
volume.voxelModelName           -- 只读资源名；volume.voxelModel 为资源对象
volume:SetVoxelModel(newModel)  -- 换模并原地重烘（body/约束/分组保留）；nil = 脱钩
volume:DetachFromVoxelModel()   -- 手动脱钩：让当前 grid 以快照形式存档
```

⚠️ **绕过伤害 API 直接改 grid（SetSolid/FillBox/PaintBox）不会自动脱钩**——改完
必须调 `volume:DetachFromVoxelModel()`，否则存档重载会按来源 `.vox` 原样重烘，
这些修改全部丢失。伤害/填充 API（`ApplyDamage*` / `ApplyFillAtWorldPoint`）自动
处理，无需关心。

### 有用的属性 / 谓词

```lua
volume.density = 800.0          -- kg/m³（动态才有意义，碎块继承）
volume.gravityFactor = 1.0      -- 全局重力倍率；0 = 失重，不是独立重力值
volume.destructible = false     -- 免疫伤害（地形/道路防误挖必设）
volume.evictable = false        -- 碎块预算不许删我（重要残骸）
volume:SetComOffset(Vector3(0, -0.4, 0))  -- 质心偏移：压低重心防翻车/稳船
volume.static / volume.tumbling / volume.reSettling   -- 只读生命周期谓词
world:RemoveVolume(volume)      -- 删除
```

### 通用刚体参数与解析碰撞代理

动态体积的质量只有一条数据路径：`density × solidVolume`。`mass` 和 `solidVolume`
都是只读派生值，体素被破坏后会自动更新：

```lua
local mass = volume.mass
local occupiedCubicMetres = volume.solidVolume

volume.linearDamping = 0.08
volume.angularDamping = 0.35
volume.gravityFactor = 1.0
volume.useGravity = true
volume.ccdEnabled = true             -- 高速物体按需开启连续碰撞

volume:ApplyForce(force)             -- 持续力，每个物理步都要重新施加
volume:ApplyForce(force, worldPoint) -- 在世界坐标点施力，会产生力矩
volume:ApplyImpulse(impulse)
volume:ApplyImpulse(impulse, worldPoint)
volume:ApplyTorque(torque)
volume:ApplyTorqueImpulse(torqueImpulse)
volume:Activate()
local isAwake = volume:IsActive()    -- Jolt body 是否正在参与求解（未睡眠）
local pointVelocity = volume:GetVelocityAtPoint(worldPoint)

-- 刚体 angularVelocity 的单位是 rad/s；约束的角度接口刻意使用 degree / degree/s。
local radiansPerSecond = volume.angularVelocity

-- 只抑制一个 volume-local 旋转轴；铰链相对轴优先用约束版本。
volume:SetDirectionalAngularDamping(Vector3.UP, 8.0, 200.0)
volume:ClearDirectionalAngularDamping(Vector3.UP)
```

摩擦、弹性和碰撞过滤属于每个体积的接触表面；即使体积加入 Assembly，这些参数仍按
实际命中的 member 生效：

```lua
local machineGroup = 1001
volume.friction = 0.6
volume.restitution = 0.1
volume.collisionLayer = 1
volume.collisionMask = 0xffffffff
volume.collisionGroup = machineGroup -- 相同非零 group 的独立刚体互不碰撞
```

默认碰撞由引擎根据体素占用和平台预算自动选择。对轮胎、保险杠等规则零件可以换成
解析代理；尺寸参数都是**完整尺寸**，不是半尺寸或半径，`localOffset` 是相对体素
occupied bounds 中心的偏移：

```lua
bumper:SetCollisionBox(Vector3(0.5, 0.4, 2.4))
wheel:SetCollisionCylinderAuto(Vector3.FORWARD) -- 轴沿 volume local Z
sensor:SetCollisionSphere(0.8, Vector3(0, 0.1, 0))
-- 也可用 SetCollisionCapsule / SetCollisionCylinder；恢复自动策略：
volume:SetCollisionShapeAuto()
```

解析代理只改变物理形状，不改变体素和渲染。涂色不会使它失效；任何增删体素或拓扑
分裂都会自动回退到 Auto，避免受损模型留下与画面不一致的隐形碰撞体。

---

## 三、调色板与硬度（伤害门槛）

本节省略域参数的 World API 默认操作 **Replicated** 色板。服务器和客户端创建的 `LOCAL` Volume 都使用独立的 **Local** 域，需显式传 `VOXEL_PALETTE_LOCAL`；材质全局编号只在所属域内有效。域、Bank、槽位换算及共享修改范围见 [联网指南的色板章节](voxel-networking.md#5-色板域bank-和材质编号)。

```lua
world:SetPaletteEntry(index, color, hardness, debrisStyle)
```

- **硬度语义：伤害 `power < hardness` 的体素完全免疫**。用它做材质分层：
  土 0.4（铲子能挖）、木 1.2、砖 6（炸药 power 8 才炸得动）、钢 100（几乎免疫）。
- `debrisStyle`：0 = 正常碎块，1 = 碎成粉尘不留渣（玻璃）。
- 槽位纪律：手建体积用固定低槽位（如 1~19），`.vox` 导入自动认领空槽——
  所以**先设完手建槽再导入**。

### 调色板分库（场景总色数突破 255）

调色板按 **bank 分库**，每库 256 槽：`index` 参数是**全局索引 = bank × 256 + 槽位**。
0~255 就是 bank 0——不分库时一切照旧，上面的代码不用改。

场景用色超过 255 时不需要做任何事：`.vox` 导入自动选库（现有库装得下就复用，
装不下就开新库，同一套 .vox 的多个实例天然同库），每个体积记住自己的库
（`volume.paletteBank`，碎块自动继承父体积的）。手动分库只在脚本大量自定义材质时
才需要：

```lua
world:SetPaletteEntry(256 + 1, Color(1, 0, 0), 6.0)   -- bank 1 的 1 号槽
world:GetPaletteBankCount()                            -- 当前库数
volume.paletteBank                                     -- 体积归属的库（碎块继承）
```

- 伤害/建造 API 里的材质参数（`scorchMaterial` / `onlyMaterial` / `ApplyFillAtWorldPoint`
  的 `material`）都收全局索引，跨库时引擎自动把定义翻译进目标体积的库——直接传即可。
- `GetMaterialAtWorldPoint` 返回的也是全局索引，能直接回传给上述 API 或
  `GetPaletteHardness`、`GetPaletteRoughness` 等读取接口。
- 每库 255 色装不下一个 `.vox` 是不可能的（.vox 格式本身 ≤255 色）。库数上限由项目的
  调色板布局决定（`world:GetPaletteBankLimit()` 可查）：
  - 默认 `legacy` 布局最多 256 库（≈6.5 万色），用尽时告警，新模型共用最后一库。
  - 大世界 / UGC 场景在项目 `.project/engine.json` 里切到 `virtualized`，每个域最多 16384 库
    （约 420 万色），GPU 只为当前挂在世界里的体积所用的库占槽位：

    ```json
    { "schema_version": 1, "voxel": { "palette": { "layout": "virtualized" } } }
    ```

    可选 `"slot_capacity"`（0 = 平台默认：移动端/Web 1024，桌面 4096，最大 4096）是同时
    驻留的库数。驻留库超过容量时，多出来的体积按 bank 0 的颜色渲染并打告警；用
    `world:GetPaletteSlotStats()` 看 `pinned` / `peakPinned` / `overflows` 来调容量。
    切到 `virtualized` 前，项目里的自定义体素 shader 必须用下文的 `voxel_palette_uv` 写法。
    联网游戏的服务端读取同一份 `engine.json`，与客户端使用相同的库数上限；`layout` 要写在
    `voxel.palette` 通用配置里，不要放进 `platforms.<平台>` 按平台覆盖，否则服务端与部分客户端
    的上限不一致，超出一方上限的库会被拒绝。

### PBR 层（粗糙度/金属度/高光/自发光）

```lua
-- emissive: rgb = 发光颜色, a = 强度 0~16（1 = 标准亮度，配合泛光可以 >1）
world:SetPaletteEntryPBR(index, roughness, metallic, specular, emissive)
world:SetPaletteEntryPBR(MAT_STEEL, 0.35, 1.0, 0.5)                       -- 金属
world:SetPaletteEntryPBR(MAT_LAMP, 0.9, 0.0, 0.5, Color(1, 0.8, 0.4, 6))  -- 灯
-- 读取:GetPaletteRoughness/Metallic/Specular/Emissive(index)
```

- 不调则用默认（roughness 0.85 / metallic 0 / specular 0.5 / 不发光），即原来的
  哑光体素观感。
- `.vox` 带 MATL 材质（MagicaVoxel 的 metal/emit 类型）导入时**自动翻译**进 PBR 层，
  同色不同 PBR 的会占不同槽位。

### 断面色（Teardown 风格切面）

烘焙/定型（`FinalizeVolume[AsDynamic]` 或 `.vox` 烘焙）时六邻居全实心的体素记为
"内部"；之后被伤害暴露出来的内部体素面自动用**断面色**渲染（默认 = 表面色 × 0.6，
挖开的墙芯比表皮深一截）。密闭房间的内墙不算内部（贴着空腔），保持作者涂的颜色。

```lua
world:SetPaletteCutColor(index, color)   -- 显式指定断面色（否则自动派生）
world:GetPaletteCutColor(index)
```

### UGC：自定义体素表面着色（SurfaceShader）

整个调色板（颜色/PBR/自发光/断面色）打包在一张图集纹理里，每个库占 256×4 的一块：
反照率、粗糙/金属/高光、自发光、断面色四层。体素网格的**顶点色不是颜色**——
`COLOR.r` = 调色板索引/255，`COLOR.g` = 内部体素标记（断面）。自定义 SurfaceShader
从调色板纹理查表拿数据，怎么演绎随你（SurfaceShader 写法见
[surface-shader.md](surface-shader.md)）。

图集里每个库放在哪由引擎决定（随项目调色板布局变化），**不要自己算行列**，用引擎
include 提供的函数：

```glsl
#include "res://Shaders/BLGL/Voxel/VoxelPalette.shaderinc"
```

它提供：

- `voxel_palette_index(COLOR)`：取出顶点色里的调色板索引（0~255）。
- `voxel_palette_uv(index, layer)`：该索引在本体积所属库里的采样坐标。`layer` 用常量
  `VOXEL_PALETTE_ALBEDO` / `VOXEL_PALETTE_PBR` / `VOXEL_PALETTE_EMISSIVE` / `VOXEL_PALETTE_CUT`。
- 三个 uniform（`voxel_palette_slot` 等）：**引擎自动写入**材质，脚本不要设置。

```glsl
// assets/Shaders/BLGL/MyVoxelFx.shader
shader_type spatial;
render_mode shading_model_unlit;

// nearest 是硬要求——索引查表,linear 会把相邻槽位混出错误颜色
// 不要给 palette_tex 加 source_color：整张纹理混了颜色层和标量层，
// 自动 sRGB 解码会把粗糙/金属/高光层一起弄坏，所以必须手动按层处理
uniform sampler2D palette_tex : filter_nearest, repeat_disable;

#include "res://Shaders/BLGL/Voxel/VoxelPalette.shaderinc"

// SurfaceShader 没有内建 sRGB 解码函数，颜色层采样后用本地近似
vec3 srgb_to_linear(vec3 c) {
    return c * (c * (c * 0.305306011 + 0.682171111) + 0.012522878);
}

void fragment() {
    float idx = voxel_palette_index(COLOR);
    // 颜色层(ALBEDO / EMISSIVE.rgb / CUT)按 sRGB 写入，采样后要 srgb_to_linear
    // 再交给 ALBEDO/EMISSION，否则会比同色常规材质更亮、发灰；
    // PBR 层是线性标量参数，不要解码；alpha（覆盖度/自发光强度/16）原样透传
    vec3 albedo = srgb_to_linear(texture(palette_tex, voxel_palette_uv(idx, VOXEL_PALETTE_ALBEDO)).rgb);
    vec3 cut = srgb_to_linear(texture(palette_tex, voxel_palette_uv(idx, VOXEL_PALETTE_CUT)).rgb);
    float interior = step(0.5, COLOR.g);           // 1 = 断面(被打出来的内部体素)
    ALBEDO = mix(albedo, cut, interior);
    ALPHA = 1.0;
}
```

```lua
local mat = Material:new()
if mat:SetSurfaceShader("Shaders/BLGL/MyVoxelFx.shader") then
    -- SetSurfaceShader 返回 true 时槽位表已就绪:纹理设一次即可,持久有效
    mat:SetSurfaceTexture("palette_tex", world:GetPaletteTexture(volume:GetPaletteDomain()))
    volume.material = mat   -- 引擎在这里把体积所在库的位置写进材质
end
```

- 贴图必须走 `SetSurfaceTexture("palette_tex", ...)`（shader 源码里的 sampler 名），
  **不要**用 `mat:SetTexture(slot, ...)` 手写底层槽位——SurfaceShader 的槽位由
  codegen 分配，写死数字槽会绑错。
- 纹理绑定设一次即可。唯一的例外是开发期热重载 `.shader` 文件
  （`cache:SetAutoReloadResources(true)`）：重载会重新生成槽位表，在重载后重设
  一次即可，不需要每帧重申。
- 一个自定义材质只能代表一个库的位置：**只在同库的体积之间共享**（同一个 `.vox` 的
  实例、碎块天然同库）。不同库的体积各建一份材质；体积换库（`SetPaletteBank`）后引擎
  会自动更新它当前材质。
- 运行时改调色板（`SetPaletteEntry*`）后纹理自动重传，shader 侧无感。
- 碎块继承父体积的材质：自定义 shader 会跟着碎片走，断面位（`COLOR.g`）照常有效。
- 旧写法（自己按 256 宽、`palette_bank * 4` 算行，并用 `SetShaderParameter("palette_bank", ...)`
  传库号）只在默认 `legacy` 布局下可用；新代码一律用 `voxel_palette_uv`。
- 完整参考实现（扫描线/闪烁/轮廓光/顶点位移全息投影）：
  `examples/27-voxel-town/assets/Shaders/BLGL/VoxelHologram.shader`
  + `town.lua` 的 `BuildHologram`。

---

## 四、破坏与建造

### 射线 + 点伤害（射击/挖掘的标准形）

```lua
local hit = world:RaycastSingle(Ray(cameraPos, aimDir), 60.0)
if hit.hit then
    -- hit.position / hit.normal / hit.distance / hit.volume / hit.voxel / hit.material
    world:ApplyDamageAtWorldPoint(hit.position, 0.35, 3.0)
    --                            球心           半径   power
end
```

`ApplyDamageAtWorldPoint` 按世界点找到所有被波及的体积（不用关心命中的是谁）。
返回值 = 实际移除的体素数。完整签名：

```lua
world:ApplyDamageAtWorldPoint(center, radius, power, scorchMaterial, onlyMaterial)
-- power 省略 = 无穷大（全材质穿透）
-- scorchMaterial ≠ 0：弹坑外壳幸存体素重涂为该槽（烧焦痕/锯痕）
-- onlyMaterial ≠ 0：只伤害该材质（挖土不伤石头）
```

`RaycastSingle` 的 `hit.volume` 永远是实际命中的准确体积；命中 Assembly member 时
`hit.assembly` 非空，`hit.volumeId` 是该 member 的稳定 ID。还可使用
`world:Raycast(ray, distance, mask)` 获取全部命中，或
`world:SphereCast(Sphere(center, radius), direction, distance, mask)` 做有体积的扫掠。

### 形状伤害（锯/激光/爆破锥）

```lua
world:ApplyDamageCapsule(worldA, worldB, radius, power)          -- 线段扫掠：细长胶囊 = 锯切
world:ApplyDamageBox(center, halfExtent, rotation, power)        -- 薄盒 = 平面切割
world:ApplyDamageCone(apex, direction, halfAngleDeg, range, power) -- 定向锥 = 破门炸药/霰弹
world:ApplyDamage(volume, center, radius, power)                 -- 指定单个体积
```

### 建造（伤害的对偶）与材质查询

```lua
world:ApplyFillAtWorldPoint(center, radius, MAT_WOOD)  -- 在现有体积的空腔里填体素
local mat = world:GetMaterialAtWorldPoint(pos)         -- -1 = 空/不在任何体积内
```

### 爆炸推力

```lua
world:ApplyRadialImpulse(center, radius, impulse)  -- 唤醒范围内冻结碎块并向外抛
-- 通常配合 ApplyDamageAtWorldPoint 一起用：先炸洞，再抛碎块
```

### 世界级破坏参数（一次性配置）

```lua
world.minFragmentVoxels = 6       -- 小于此数的断裂群直接变碎屑
world.maxFrozenFragments = 400    -- 静置碎块总预算（超了删最老的 evictable）
world.spallChunkVoxels = 4        -- 崩落碎块边长（0 关闭崩落）
world.maxSpallChunks = 24         -- 单次伤害最多崩几块
world.spallSpeed = 2.5            -- 碎块初速
world.damageNoise = 0.35          -- 弹坑边缘噪声 0~1（0 = 机加工般光滑）
world.stressBreakFactor = 200     -- 结构应力断裂（0 关闭）：悬空太重自己塌
world.minDamageableVoxels = 10    -- 小于此数的残骸免疫后续伤害（惰性鹅卵石）
world.debrisMaxAge = 30.0         -- 碎块寿命秒数（0 = 永生；结构体积永不过期）
```

---

## 五、事件

```lua
world.contactEventThreshold = 3.0   -- 合速 > 3 m/s 的碰撞才发事件（0 = 关）

SubscribeToEvent("VoxelContact", "OnVoxelContact")
function OnVoxelContact(eventType, eventData)
    local a = eventData["VolumeA"]:GetPtr("VoxelVolume")
    local b = eventData["VolumeB"]:GetPtr("VoxelVolume")
    local pos = eventData["Position"]:GetVector3()
    local vel = eventData["Velocity"]:GetFloat()
end
```

| 事件 | 时机 | 数据字段 |
|---|---|---|
| `VoxelContact` | 高速碰撞（受 `contactEventThreshold` 门控） | `VolumeA`/`VolumeB`(Ptr)、`Position`、`Velocity` |
| `VoxelDamaged` | 每次伤害生效 | `Volume`(Ptr)、`Position`、`Radius`、`Removed`(移除数)、`Material` |
| `VoxelSevered` | 结构断裂分离出新碎块 | `Volume`/`Fragment`(Ptr)、`Voxels`、`Anchored` |
| `VoxelFragmentFrozen` | 碎块静置冻结 | `Volume`(Ptr)、`Position` |
| `VoxelAssemblyMemberDetached` | member 手动或应力脱离后 | `Assembly`/`Volume`(Ptr)、`Force`、`Torque`、`BreakFactor`、`Reason` |
| `VoxelAssemblyRootChanged` | Assembly 根成员改变后 | `Assembly`/`OldRoot`/`NewRoot`(Ptr) |

典型用法：撞击引爆炸弹（VoxelContact 里比对 volume 的 Node ID）、命中计分
（VoxelDamaged 的 Removed 数）、建筑塌了触发任务（VoxelSevered）。

---

## 六、角色控制器（第一/第三人称）

推荐使用 `VoxelCharacterController` 组件。角色根 Node 的世界坐标就是**脚底**；组件每帧把
物理解算得到的位置同步给 Node，但不覆盖旋转，因此朝向、模型层级、动画和相机仍由玩法控制。

```lua
local player = scene:CreateChild("Player")
player.worldPosition = spawnPos                    -- 脚底位置
local character = player:CreateComponent("VoxelCharacterController")
character.height = 1.7
character.radius = 0.35
character.supportRadius = 0.25                    -- 水平支撑圆；窄台/边缘站立判定
character.gravityFactor = 1.0                     -- 全局重力的倍率，不是独立重力

-- 每帧只写意图；VoxelPhysicsWorld 会自动驱动并同步 player 的位置。
character.desiredVelocity = moveDir * speed       -- 地面移动时 y 给 0
if wantJump then character:Jump(6.5) end

player.worldRotation = Quaternion(0, facingYaw, 0) -- 玩法拥有朝向
local grounded = character.onGround
character:Teleport(respawnPosition)
```

需要完整 3C 行为时，可以在同一角色层级添加 `CharacterComponent`。它通过统一的
角色控制器接口驱动 `KinematicCharacterController` 或 `VoxelCharacterController`，
不需要脚本判断物理后端，也不需要自行把物理位置和旋转同步回 Node。

角色没有 `density`：体积密度用于根据体素占用体积计算刚体质量，而虚拟角色直接配置
`mass`。`mass` 和 `maxStrength` 影响角色推挤动态物体时的交互，不改变自由落体加速度。

| 参数 | 默认值 | 含义 |
|---|---:|---|
| `height` / `radius` | `1.8` / `0.4` | 胶囊总高度与半径；脚底坐标不随尺寸改变 |
| `supportRadius` | `0.4` | 水平支撑圆半径，范围 `0~radius`；越小越容易站在窄台上 |
| `gravityFactor` | `1.0` | `world.gravity` 的倍率；`0` 为失重 |
| `mass` | `70` | 与动态物体交互时使用的角色质量（kg） |
| `maxStrength` | `100` | 角色推动动态物体的最大作用力（N） |
| `maxSlopeAngle` | `50` | 可站立坡度上限（度） |
| `stepHeight` | `0.4` | 自动跨越台阶的最大高度（m） |
| `stickToFloorDistance` | `0.5` | 下坡时贴地探测距离（m） |
| `penetrationRecoverySpeed` | `1.0` | 从重叠中恢复的速度系数，范围 `0~1` |
| `enhancedInternalEdgeRemoval` | `false` | 减少复杂碰撞面内部边缘导致的卡顿 |
| `maxNumHits` | `256` | 单次角色碰撞查询的最大命中数 |
| `collisionLayer` | `1` | 角色所属碰撞类别位；启用过滤后，对方 `VoxelVolume.collisionMask` 必须包含其中至少一位 |
| `collisionMask` | `0xffffffff` | 角色接受的 `VoxelVolume.collisionLayer` 位；`0` 忽略所有刚体，包括地面 |

运行时还可读写 `linearVelocity`，并读取 `groundState`、`groundNormal`、
`groundVelocity`、`maxHitsExceeded`。胶囊变大时如果会与场景重叠，尺寸修改会被拒绝。

**碰撞过滤**：角色的 `collisionLayer == 1` 且 `collisionMask == 0xffffffff` 时，
保持历史碰撞行为，不检查 `VoxelVolume` 的 layer/mask。两个值中任意一个偏离默认值，
才启用与 `VoxelVolume` 相同的双向位掩码规则；此时只有
`(character.collisionLayer & volume.collisionMask) ~= 0` 且
`(volume.collisionLayer & character.collisionMask) ~= 0` 时才发生碰撞。
支持 `SetCollisionLayer(layer)` / `GetCollisionLayer()`、
`SetCollisionMask(mask)` / `GetCollisionMask()`，也可直接读写对应属性；
属性随场景保存和网络同步。运行时修改在下一次物理更新及后续胶囊尺寸检查中生效，
移动、跨台阶、贴地和站立支撑使用同一规则，Assembly 按命中的具体成员过滤。
将两个属性恢复为默认值会自动退出过滤；是否启用只取决于当前值，不记录 setter 调用历史。

```lua
-- 业务自定义类别位；不等同于引擎内部的 StaticVolume / DynamicDebris 粗分层。
local LAYER_WORLD = 1
local LAYER_DEBRIS = 2
local LAYER_CHARACTER = 4

-- 碎块保持与地面、其他碎块的碰撞；角色只排除碎块类别。
debris:SetCollisionLayerAndMask(LAYER_DEBRIS, 0xffffffff)
ground.collisionLayer = LAYER_WORLD
character:SetCollisionLayer(LAYER_CHARACTER)
character:SetCollisionMask(0xffffffff & ~LAYER_DEBRIS)
```

`supportRadius` 只改变接触能否算作支撑，不会关闭碰撞；让角色穿过碎块应使用上述掩码。
默认配置的角色不做上述双向位掩码检查；如果需要按体素的 mask 限制角色，角色必须先使用
非默认 layer 或 mask。原有粗分层规则仍生效：独立体素 `mask == 0`，或 Assembly 全部成员
的 mask 都为 `0` 时，整个刚体仍不参与碰撞。此接口不新增虚拟角色之间的碰撞。
与 `CharacterComponent` 联用时，其初始化不会覆盖通过上述接口设置的体素角色过滤配置。
C++ 的 `SetCollisionLayerAndMask` 保留为兼容空接口，维持历史调用行为，不对 Lua 暴露。

**游泳**（开了水面后自动生效）：角色过胸深自动进入游泳态，浮在水面；

```lua
if character.swimming then
    -- 游泳时 desiredVelocity.y 就是潜浮意图：+上浮 / -下潜，jumpSpeed 传 0
    character.desiredVelocity = Vector3(v.x, diveIntent, v.z)
end
```

原有 `CreateCharacter` / `MoveCharacter` 句柄接口继续保留，适合不需要场景组件和 Node
自动同步的底层用法；使用句柄时仍需自行逐帧调用 `MoveCharacter` 并同步模型。

---

## 七、抓取推拽（门、抽屉、搬箱子）

引擎级抓取约束：力走求解器，能拖碎块、摆铰链门、拉抽屉，被墙挡住不会穿模。

```lua
local grabHandle = nil

-- 按下右键：射线找到目标就抓
local hit = world:RaycastSingle(Ray(camPos, camDir), 3.0)
if hit.hit then
    local h = world:BeginGrab(hit.volume, hit.position)
    if h ~= 0 then grabHandle = h end
end

-- 按住期间每帧：target = 手的目标点（如相机前 2m）
if grabHandle then
    if not world:UpdateGrab(grabHandle, target, timeStep, 10.0, 2.0) then
        grabHandle = nil          -- 返回 false = 挣脱/目标死亡/超出 breakDistance
    end
end

-- 松开
if grabHandle then world:EndGrab(grabHandle); grabHandle = nil end
```

---

## 八、水面与浮力

水有两个来源：场景里的水域（`WaterBody` 加同节点的 `PlaneWaterSurface` / `GerstnerWaterSurface` /
`FFTWaterSurface`，见 [水体](surface-shader-addons/water.md)），以及水域之外的全局水平面。
用引擎波浪画水面时只需放水域，浮力、角色游泳会跟着同一片波浪走：

- 体素物体落在水域里时，按物体底下的局部水面计算浮力（宽物体会在船体范围内取平均波面），水域优先于全局平面；
  水域没有 CPU 水面（只有 `WaterBody`）时不施加浮力。浮力再乘以水域密度 / 1000（`volume:SetDensity(1025)` 即海水）。
- 有波浪的水域会让浪上的浮体一直保持唤醒、随浪起伏；沉在水底的物体照常休眠。改变水位、移动或新增水域、
  修改全局水平面，都会唤醒受影响的休眠物体。

```lua
-- Water domain: the same surface drives rendering, buoyancy and swimming.
scene:GetWaterWorld()
local water = scene:CreateChild("Sea")
water:CreateComponent("WaterBody"):SetBounds(Vector3(-200, -20, -200), Vector3(200, 5, 200))
water:CreateComponent("GerstnerWaterSurface"):SetMaxAmplitude(0.4)

-- Global plane outside every domain (legacy scenes without water domains).
world.waterEnabled = true
world.waterLevel = -0.15            -- 全局水平面高度（视觉水面自己画，见 recipes/surface-shader.md）
world:SetWaterDrag(1.2, 0.8)        -- 线性阻尼 / 角阻尼，对水域同样生效

-- 浮力两条路：
volume.density = 400.0   -- 默认按 1000/density 算浮力：木头浮、石头沉
volume.buoyancy = 2.4    -- 显式覆盖（0 = 用密度自动算）。船体密封舱按排水量给高值
```

**破舱进水沉船**：监听 `VoxelDamaged`，按船体损失比例线性调低 `buoyancy` 即可。

完整示例：`examples/32-engine-water`（不同密度的浮箱与石块、空心船、角色游泳、浮标查询、水下效果）；
`examples/27-voxel-town` 的海湾是把同一做法接进大场景，并带破舱沉船。

---

## 九、约束与机关（铰链门、吊桥、旋转臂）

```lua
-- 门板挂在门框上；组件挂在 own volume（门板）的 Node 上
local c = doorVolume:GetNode():CreateComponent("VoxelConstraint")
c.constraintType = VOXEL_CONSTRAINT_HINGE
c.otherVolume = frameVolume
c.worldPosition = hingeWorldPoint          -- 同时换算并保存两侧 local position

-- rotation / otherRotation 分别属于两侧 local frame；铰链轴为 frame local Z。
local worldAxis = Vector3.UP
local ownAxis = doorVolume:GetNode().worldRotation:Inverse() * worldAxis
local otherAxis = frameVolume:GetNode().worldRotation:Inverse() * worldAxis
c.rotation = Quaternion(Vector3.FORWARD, ownAxis)
c.otherRotation = Quaternion(Vector3.FORWARD, otherAxis)
c.disableCollision = true                  -- 只关闭这一对 endpoint 的碰撞
c:SetAngularMotorVelocity(0.0, 40.0)       -- degree/s、N·m；0 速 + 持力矩可作阻尼门
c:SetAngularLimits(-120.0, 0.0)            -- degree
c:SetAxisAngularDamping(8.0, 40.0)         -- 系数 N·m·s/rad、上限 N·m；只抑制铰链相对轴
c:Rebuild()

local angle = c:GetHingeAngle()            -- 遥测：degree；滑轨用 GetSliderPosition()
local forceA = c:GetReactionForce()         -- 上一物理步作用于本节点端点的世界空间力，N
local torqueA = c:GetReactionTorque()       -- 纯约束力矩（不含 r × F），N·m
```

反力遥测固定返回作用于 own volume（组件所在节点、endpoint A）的 world-space 平均值；另一端
承受相反的 wrench。组件未构建、被禁用、因两端合入同一 Assembly 而 suspended、已经退休，
或上一 solver 子步没有有效约束时返回零。读数用于调试、表现和玩法判断，不需要 Lua 再把它
作为修正力施回物理世界。

Motor/servo 按单位拆开，避免同一个方法随约束类型改变含义：

```lua
c:SetAngularMotorVelocity(90.0, 500.0)     -- degree/s、N·m
c:SetLinearMotorVelocity(2.0, 800.0)       -- m/s、N
c:SetServo(45.0, 500.0, 120.0)             -- 目标 degree、N·m、最大 degree/s
c:SetServo(45.0, 500.0, 0.0)               -- max speed <= 0 表示不施加显式速度上限
c:SetServo(270.0, 500.0, 0.0)              -- 周期目标先归一化；270° 等价于 -90°
c:SetAngularLimits(-90.0, 90.0)            -- 铰链
c:SetLinearLimits(-0.5, 0.5)               -- 滑轨，m
c:SetSolverVelocitySteps(0)                 -- 0 = 使用物理世界默认速度迭代次数
c:SetSolverPositionSteps(40)                -- 复杂高载荷关节链可提高位置修正精度
c:DisableMotor()
```

求解步数是约束组件自身的可序列化属性，也可以用 `solverVelocitySteps` 和
`solverPositionSteps` 访问。Jolt 会对同一个物理岛取所有 override 的最大值：在一辆由多个
关节连接的车上重复设置同一个值不会乘以关节数，但整辆车及其当前接触都会使用该次数。
它不是刚度参数；仅在默认精度出现可测的锚点、角度漂移或马达振荡时提高，其他情况保持 0。
实体轮车辆可分别处理两种误差：位置迭代抑制轮轴/主销倾斜；速度迭代帮助高载荷 Servo
和接触约束收敛。VoxelTown 实体轮车经回归选择 `solverVelocitySteps = 60`、
`solverPositionSteps = 40`，这不是全局默认值。

Slider 可以直接配置通用线性弹簧（悬挂、缓冲器、回位机构都使用同一接口）：

```lua
-- 较重的 endpoint 作为 own volume。Slider 使用 frame local X 作为滑动轴，
-- 与 Hinge 使用 local Z 的约定不同。
local slider = heavyBody:GetNode():CreateComponent("VoxelConstraint")
slider.constraintType = VOXEL_CONSTRAINT_SLIDER
slider.otherVolume = movingBody
slider.worldPosition = anchorWorld
local axisWorld = Vector3.UP
slider.rotation = Quaternion(Vector3.RIGHT,
    heavyBody:GetNode().worldRotation:Inverse() * axisWorld)
slider.otherRotation = Quaternion(Vector3.RIGHT,
    movingBody:GetNode().worldRotation:Inverse() * axisWorld)
slider:SetLinearLimits(-0.12, 0.20)         -- 硬行程，m；始终优先于弹簧目标
slider:SetLinearSpring(0.0, 35000.0, 4500.0) -- 平衡位置 m、刚度 N/m、阻尼 N·s/m
slider:SetSolverPositionSteps(40)           -- 可选：重载多关节悬挂减少角度/锚点漂移
assert(slider:Rebuild())

local compression = slider.sliderPosition
slider:SetLinearMotorVelocity(0.2, 5000.0) -- 显式马达临时覆盖弹簧
slider:DisableMotor()                       -- 关闭马达后恢复已经配置的弹簧
slider:ClearLinearSpring()                  -- 只有这个接口关闭弹簧
```

`SetLinearSpring()` 会把负刚度/阻尼钳制到 0，但 0 不是“关闭”哨兵；是否启用由独立的
`Linear Spring Enabled` 属性保存。弹簧参数在非 Slider 约束上会保留但不产生物理力。

**两个必知陷阱**：
1. **约束默认不会关闭两个体之间的碰撞**。只处理一对 endpoint 时设
   `c.disableCollision = true`；需要整台机器的多组独立刚体互不碰撞时，给各 volume
   设置相同的非零 `collisionGroup`。
2. 平接的门会被摩擦"焊死"：门板与门框留 ≥1 体素缝隙，或分到同组。

---

## 十、装配体（VoxelAssembly）

`VoxelAssembly` 把多个已定型的动态 `VoxelVolume` 合成一个 Jolt compound body。
每个 member 仍保留自己的 Node、VoxelGrid、材质、渲染 fallback、碰撞表面参数和稳定
`volumeId`，所以可以独立涂色、破坏、查询和存档；这里只合并刚体及质量属性，不复制
体素内存。

```lua
-- chassis / bumper / leftDoor / roof 都已经 FinalizeVolumeAsDynamic
bumper:SetCollisionBox(Vector3(0.5, 0.4, 2.4))

local assembly = world:CreateAssembly(chassis) -- chassis 同时成为稳定玩法根
assert(assembly ~= nil)
assert(assembly:AddVolume(bumper))
assert(assembly:AddVolume(leftDoor))
assert(assembly:AddVolume(roof))
-- 成员关系立即可见；多次 AddVolume 的 Jolt compound 会在下一物理步前合并重建一次。

-- 完整部件的连接强度：N、N·m。只启用希望自动脱落的 member。
assembly:SetMemberBreakThreshold(bumper, 20000.0, 20000.0)
assembly:SetMemberBreakThreshold(leftDoor, 200000.0, 120000.0)
assert(assembly:IsMemberBreakable(bumper))

assembly.linearDamping = 0.08
assembly.angularDamping = 0.35
assembly.ccdEnabled = true

-- 共享刚体 façade；mass 是所有 member 派生质量之和，只读。
assembly:ApplyImpulse(launchImpulse)
assembly:ApplyTorque(steeringTorque)
local totalMass = assembly.mass
```

断裂由引擎根据实际命中 member 的接触冲量和刚体惯性载荷计算，脚本只配置连接强度，
不需要监听碰撞后手动拆件。边缘超载需要连续物理步，严重超载可当场断裂；部件被打掉
体素后，有效强度会随剩余占用率自动降低。`GetMemberStress(member)` 返回上一物理步的
`force`、`torque`、`forceFactor`、`torqueFactor`、`breakFactor`，适合 UI 和调试，不应
用它在脚本里重复实现断裂判定。

```lua
local stress = assembly:GetMemberStress(bumper)
print("bumper stress", stress.breakFactor)

assembly:RemoveVolume(leftDoor) -- 手动拆成独立动态刚体
assembly:SetRootVolume(roof)    -- 显式切换稳定玩法根
assembly:Dissolve()             -- 所有 member 恢复为独立动态刚体
```

规则与陷阱：

- 只能加入已 `FinalizeVolumeAsDynamic` 的 standalone 动态体；静态、无 body、已在其他
  Assembly 中的体积会被拒绝。
- 从任意 member 调用刚体级 velocity/force/damping/gravity/CCD API，读写的都是同一个
  shared body；接触表面和 collision shape 仍属于各 member。
- `AddVolume` 连续调用只在下一物理安全点构建一次 compound；脚本不需要批处理 API，
  但不要在同一帧、物理步发生前假设各 member 已经拿到相同 body handle。
- `RemoveVolume` 和自动应力断裂会同步完成 body 拆分；调用返回或 detach 事件触发时，
  被移除 member 已经是独立动态刚体。
- root 只定义稳定玩法坐标系，不代表它独占质量。移除 root 时可给
  `RemoveVolume(root, preferredNewRoot)`，否则引擎按稳定 ID 选择新根。
- 两端都进入同一个 Assembly 的 `VoxelConstraint` 会自动 suspended；任一 member
  脱离后按保存的双 local frames 自动恢复。
- member 被破坏到零实体 voxel 后仍保留 Node 和 Assembly 身份，但不参与碰撞、质量、
  质心或惯量；重新填充并重建碰撞后会恢复。全部 member 为空时 Assembly 暂时 bodyless。
- 全部 member 的 `collisionMask` 都为 0 时 shared body 使用 no-collide 粗筛；任一 member
  恢复非零 mask 后重新进入保守 broad phase，最终仍按命中的 member 精确过滤。

完整可玩参考：`examples/27-voxel-town` 的 Assembly 解体车。保险杠、车门和车顶可独立
受损并在撞墙时按参数脱落，底盘与射线悬挂仍只驱动一个刚体。

---

## 十一、悬挂载具（VoxelVehicle）

射线悬挂式载具：轮子不是真实体，底盘一个体积 + 每轮一条悬挂射线。

```lua
-- 底盘（动态体积）＋组件
local chassis = world:CreateVolumeFromModel(carModel, 0.1, origin)
chassis:SetComOffset(Vector3(0, -0.3, 0))     -- 压低质心，高速过弯不翻
chassis.density = 600.0
world:FinalizeVolumeAsDynamic(chassis)
chassis:RebuildGeometry()

local veh = chassis:GetNode():CreateComponent("VoxelVehicle")
-- AddWheel(底盘局部锚点, 轮半径, 悬挂行程, 刚度, 阻尼, 是否转向轮, 是否驱动轮)
local k, c, rest, r = 46000.0, 5600.0, 0.15, 0.45
veh:AddWheel(Vector3(4.3, 0.18, 0.5), r, rest, k, c, true,  false)  -- 前左（转向）
veh:AddWheel(Vector3(4.3, 0.18, 2.0), r, rest, k, c, true,  false)  -- 前右
veh:AddWheel(Vector3(1.1, 0.18, 0.5), r, rest, k, c, false, true)   -- 后左（驱动）
veh:AddWheel(Vector3(1.1, 0.18, 2.0), r, rest, k, c, false, true)   -- 后右
veh.maxDriveForce = 9000.0     -- 单驱动轮峰值推力 N
veh.maxSteerAngle = 32.0       -- 满舵角（度）
veh.maxSpeed = 14.0            -- 极速 m/s：推力线性归零（0 = 不限，会飙到失控）
veh.steerSpeedFalloff = 0.08   -- 车速敏感收舵：高速自动减舵角防甩尾（0 关闭）
veh.grip = 0.85                -- 胎抓地 0~1，低了漂移
veh:ApplyAttributes()

-- 每帧驾驶输入：油门/舵 [-1,1]，刹车 [0,1]
veh:SetInput(throttle, steer, brake)
veh:SetInput(0, 0, 1)          -- 停车拉手刹（防溜坡，别让它保持 0,0,0）

-- 遥测
local v = veh.forwardSpeed                    -- 带符号前进速度
local onGround = veh:IsWheelGrounded(0)
local comp = veh:GetWheelCompression(0)       -- 悬挂压缩量（做轮子视觉动画用）
local patch = veh:GetWheelContactPoint(0)     -- 接地点世界坐标
```

**履带车（推土机/挖掘机/坦克）**：`veh:SetSkidSteer(true)`，全轮 `steers=false`、
`drives=true`，`grip = 1.0`。此时 steer 输入混进左右两侧驱动做差速转向，
原地对转、行进间转向都由引擎处理。重型机械务必给低 `maxSpeed`（如 4~7）——
慢即是它的操控模型。

**调参经验**：刚度 k 先按 `总重 × 9.8 / 轮数 / 期望压缩量` 估；车身翘头/点头
调 `SetComOffset`；轮子陷地板 = 悬挂行程 `rest` 太小或 k 太软。

**铁律：悬挂挂点必须在壳体之外**（壳底之下，或雕空的轮舱内）——挂点垂线下方
若有本体的实体体素，悬挂射线自命中，车辆火箭起飞。

### 实体组装轮（VoxelRollingContact）

如果轮胎本身就是会碰撞、旋转和破坏的 `VoxelVolume`，不要用 `VoxelVehicle` 代替它。
给轮胎设置 Cylinder 解析代理，并在**同一个 Node** 上增加 `VoxelRollingContact`：

```lua
-- tire 已经填好体素；圆柱轴沿 volume local Z。
tire:SetCollisionCylinderAuto(Vector3.FORWARD)
tire.density = 900.0
world:FinalizeVolumeAsDynamic(tire)

local contact = tire:GetNode():CreateComponent("VoxelRollingContact")
-- 纵向使用滑移率；峰值之前是静摩擦容量，之后过渡到高滑移平台。
contact:SetLongitudinalGrip(0.06, 1.2, 0.20, 1.0)
-- 横向使用侧偏角，角度单位是 degree；峰值角之前保持静态/峰值容量。
contact:SetLateralGrip(3.0, 1.2, 20.0, 1.0)
-- normal·gravityUp 从 0.2 到 0.7 之间平滑进入完整胎面抓地。
contact:SetSupportRange(0.2, 0.7)
contact.sidewallFriction = 0.2       -- 轮胎侧面撞墙，不继承胎面高抓地
contact.nonSupportFriction = 0.3     -- 墙面/天花板等非承载接触
contact.rollingResistance = 0.015   -- 无量纲，0 表示关闭
contact:ApplyAttributes()

-- 上一完整物理步的轮级遥测，只用于状态判断、调参与表现。
if contact:HasSupport() then
    local load = contact.normalLoad                 -- N
    local slip = contact.longitudinalSlipRatio
    local angle = contact.lateralSlipAngle          -- degree
    local usage = contact.combinedGripUsage         -- 0..1
end
```

组件只修饰现有圆柱 body 的接触，不创建第二份体素、碰撞体或刚体。驱动、转向和悬挂仍由
通用约束负责：例如 Hinge Servo 做转向，Hinge velocity motor 驱动轮轴，轮胎通过约束挂到
轮轴上。`VoxelRollingContact` 不读取油门或整车结构，也不会扶正车架。

- `active == false` 表示当前没有可用的 live Cylinder body；禁用组件或代理回退 Auto 后，
  接触立即恢复 `VoxelVolume.friction` 的普通标量摩擦，保留 authored 参数。
- `ResetSidewallFriction()` / `ResetNonSupportFriction()` 恢复继承普通摩擦；不要用 setter 传负数。
- 纵横向冲量共享摩擦椭圆预算，满舵加速不会同时得到两份无限抓地。
- `normalLoad` 只统计承载胎面接触；sidewall/non-support 有独立 contact count。
- 滚阻按法向冲量和轮半径缩放，并钳制在停止点，不会把低速轮反向加速。
- 两个都带 `VoxelRollingContact` 的滚轮互相接触时回退普通摩擦，避免两个组件争用同一
  tangential-friction channel。

---

## 十二、施力与唤醒

```lua
volume:Activate()                       -- 唤醒睡眠体
local isAwake = volume:IsActive()       -- true 表示底层刚体未睡眠
volume:ApplyForce(force, worldPoint)    -- 持续力（每个物理步重新施加）
volume:ApplyImpulse(impulse, worldPoint)
volume:ApplyTorque(torque)
volume:ApplyTorqueImpulse(torqueImpulse)
volume:ResetForces()

-- 若 volume 属于 Assembly，上述调用作用于 shared body；也可显式调用 assembly façade。
assembly:ApplyForce(force, worldPoint)
assembly:Activate()
local assemblyAwake = assembly:IsActive()
world.defaultFriction = 0.7    -- 只影响之后创建的体，建场景前设
world:OptimizeBroadPhase()     -- 大批静态体建完后调一次
```

`IsActive()` 查询的是物理睡眠状态，不是组件启用、可碰撞或可破坏状态。Assembly 的
root、非 root member 和 `VoxelAssembly` façade 查询同一个 shared body，因此结果一致。

---

## 十三、空中载具（直升机 / 战斗机 / 客机）

机体是一个动态体积；飞行没有专用组件——每帧读 `linearVelocity`、算气动力、用
`volume:ApplyForce/ApplyTorque` 施回去，就是全部。完整可玩的三机参考实现：
`examples/27-voxel-town/scripts/vehicles.lua`（BuildHelicopter/BuildFighter/BuildAirliner + Drive 函数）。

### 机体准备（两类通用）

```lua
local craft = world:CreateVolumeFromModel(model, 0.1, spawnPos)
craft.angularDamping = 2.5     -- 姿态稳定的主力（默认 0.05 太滑，飞行器 1.5~3.5）
craft.linearDamping = 0.2      -- 兼作空气阻力
craft.gravityFactor = 1.0      -- 悬停辅助可调低；0 = 完全失重
craft.ccdEnabled = true        -- 只有高速机体需要：200m/s 每步跨 3.3m，离散碰撞穿墙
craft.density = 300.0
world:FinalizeVolumeAsDynamic(craft)
craft:RebuildGeometry()

-- 施力点：几何中心≈质心；角点施力会额外产生力矩
local centerLocal = Vector3(len * 0.5, height * 0.5, width * 0.5)  -- 几何中心≈质心;角点施力白送力矩
```

四个调参属性 Finalize 前设好即生效，运行时改也立即应用。断裂出的碎块**不继承**
它们（断翼要正常坠落），机翼被打断走正常切割流程——主体质量/质心自动更新，
断翼自然螺旋，不用写一行代码。不要在创建时缓存质量；以下飞行控制代码每帧从
`craft.mass` 读取当前派生质量。

### 直升机：重力前馈 + 速度伺服

悬停不要让玩家配平——前馈项恒等于重力，伺服项把速度拉向输入意图，零输入即静止：

```lua
local mass = craft.mass
local rot = craft:GetNode().worldRotation
local fwd = rot * Vector3(1, 0, 0); fwd.y = 0; fwd = fwd:Normalized()
local desired = fwd * (fwdIn * cruise) + Vector3(0, upIn * climb, 0)
local force = Vector3(0, mass * 9.81, 0)                       -- 重力前馈
    + (desired - craft.linearVelocity) * (mass * 3.0)          -- 速度伺服(增益 ~3/s)
craft:ApplyForce(force, craft:GetNode().worldTransform * centerLocal)

craft:ApplyTorque(Vector3(0, yawIn * yawTorque, 0))                 -- A/D 偏航
local bodyUp = rot * Vector3(0, 1, 0)                              -- 扶正 + 前飞低头
local targetUp = (Vector3(0, 1, 0) - fwd * (0.18 * fwdIn)):Normalized()
craft:ApplyTorque(bodyUp:CrossProduct(targetUp) * uprightTorque)
```

### 固定翼：四根力学支柱

每一根都是实测教训——缺一根，飞机以对应的方式坏掉：

| 支柱 | 公式 | 缺了会怎样 |
|---|---|---|
| 失速升力 | `lift = mg·min(speed/liftSpeed, 1.15)²` 沿机体上方向 | 无失速：静止也能悬浮 |
| 风向标自稳 | `fwd × velDir` 力矩，机头拉向速度方向 | 满杆俯仰无限增长，3 秒仰 40° 翻筋斗 |
| 压坡转弯 | A/D 倾斜滚转伺服的目标 up，升力水平分量画弧 | 平转横向力只剩推力·sin(侧滑)，转弯半径 870m |
| 操纵权渐入 | 力矩 × `(0.25 + 0.75·speed/liftSpeed)` | 停机坪原地拉杆后空翻 |

```lua
local mass = craft.mass
local fwd = rot * Vector3(1, 0, 0)
local up = rot * Vector3(0, 1, 0)
local vel = craft.linearVelocity
local speed = vel:DotProduct(fwd)
local center = craft:GetNode().worldTransform * centerLocal

-- 推力沿机头，近极速线性归零（同 VoxelVehicle.MaxSpeed 语义）；S 反推刹车
local fade = math.max(1.0 - math.max(speed, 0.0) / maxSpeed, 0.0)
craft:ApplyForce(fwd * ((thrIn * fade - revIn * 0.6) * mass * thrustAccel), center)

-- 支柱 1:失速升力——低于起飞速度自然下沉,跑道上加速过 liftSpeed 才拉得起来
local liftRatio = math.min(math.abs(speed) / liftSpeed, 1.15)
craft:ApplyForce(up * (mass * 9.81 * liftRatio * liftRatio), center)

-- 支柱 2:风向标——满杆 = 有限攻角(≈asin(pitchTorque/weathercock)),松杆自动回平
local vlen = vel:Length()
if vlen > 4.0 then
    craft:ApplyTorque(fwd:CrossProduct(vel * (1.0 / vlen))
        * (weathercock * math.min(vlen / liftSpeed, 1.5)))
end

-- 支柱 3:压坡转弯——滚转伺服的目标 up 向转弯侧倾斜(地面滑行 airRatio≈0 不压坡);
-- 机头由风向标自动跟上弯转的速度矢量 = 协调转弯
local airRatio = math.min(math.max(speed, 0.0) / liftSpeed, 1.0)
local rightDir = rot * Vector3(0, 0, -1)             -- 面向 +X 时右手边 = -Z(实测约定)
local targetUp = (Vector3(0, 1, 0) + rightDir * (yawIn * bank * airRatio * airRatio)):Normalized()
local rollAmount = up:CrossProduct(targetUp):DotProduct(fwd)

-- 支柱 4:操纵权随空速渐入
local auth = 0.25 + 0.75 * airRatio
craft:ApplyTorque((rot * Vector3(0, 0, 1)) * (pitchIn * pitchTorque * auth)
    + Vector3(0, yawIn * yawTorque * auth, 0) + fwd * (rollAmount * rollHold))
```

实测配平参考（VoxelTown）：战斗机 `thrustAccel 8 / liftSpeed 26 / maxSpeed 60 /
bank 0.7(35°坡,15°/s)`；客机 `6 / 17 / 42 / bank 0.4(24°坡,13°/s)`。
`weathercock ≈ 5~6 × pitchTorque`（这个比值就是满杆攻角上限）。

### 起落架（固定翼）

同一机体照常挂 `VoxelVehicle`——滑跑/降落时悬挂正常工作，空中射线不命中自动
零输出，与飞行力天然不打架。三条铁律：

```lua
local gear = craft:GetNode():CreateComponent("VoxelVehicle")
gear:AddWheel(Vector3(noseX, y, 中线), r, rest, k, c, true, false)   -- 前轮转向
gear:AddWheel(Vector3(mainX, y, 左), r, rest, k, c, false, false)    -- 主轮 ×2
gear:AddWheel(Vector3(mainX, y, 右), r, rest, k, c, false, false)
gear.rollingResistance = 0.002   -- ① 必调:默认 0.02/步(1.2/s)是"空挡溜车要停"
                                 --   的设计,会把 27kN 推力按死在 6m/s(实测)
gear:ApplyAttributes()
-- ② 主轮必须在质心之后(前三点布局):压在质心正下方 = 跷跷板,停机坐尾入土,
--   滑跑变犁地;再加一个平时悬空的尾撑轮更保险
-- ③ 模型里画起落架支柱时,支柱体素要离轮子锚点的垂线两格以上,
--   否则悬挂射线自命中,整机火箭起飞(第十一节挂点铁律的飞机版)
-- 驾驶中 gear:SetInput(0, yawIn, 0) 让前轮跟转向;停机 SetInput(0, 0, 1) 驻车
```

---

## 十四、常见陷阱速查

| 症状 | 原因 / 解法 |
|---|---|
| 整个世界纹丝不动 | `world.updateEnabled` 被关了，或场景更新被暂停（自动步进依赖场景更新） |
| `.vox` 颜色错乱 | `SetPaletteEntry` 在导入之后才调；先设完再导入 |
| 体积是隐形的 | 忘了 `RebuildGeometry()` |
| 体积渲成纯白 | 材质直接取了缓存的 `Materials/VoxelPalette.xml`（没绑本世界调色板纹理），改用 `world:GetPaletteMaterial()` |
| 手改 grid 的建造在存档重载后消失 | 从 `.vox` 创建的体积要先 `DetachFromVoxelModel()`（见第二节） |
| 带朝向摆放位置飞了 | 体积原点在最小角，旋转甩脚印；按 dims 补偿（见第二节） |
| 角色悬空/陷地半截 | `CreateCharacter`/`GetCharacterPosition` 的位置是**脚底** |
| 跳跃无效 | 跳跃要走 `MoveCharacter` 第三参 `jumpSpeed`，不是 `vel.y` |
| 手改 grid 后碰撞还是旧的 | 动态体要 `world:RebuildDynamicProxy(volume)` |
| 铰链总成自己抖散架 | 一对 endpoint 设 `constraint.disableCollision = true`；整机独立刚体设相同非零 `volume.collisionGroup` |
| 铰链门推不开 | 平接被摩擦焊死：留 1 体素缝或同组 |
| 载具探针把地面挖出沟 | 地形 `destructible = false` |
| 打不动某材质 | `power < hardness` 完全免疫，这是刻意的门槛语义 |
| 小残骸打不碎 | `minDamageableVoxels` 以下是惰性鹅卵石，刻意的 |
| 载具停着慢慢溜走 | 停车时 `SetInput(0, 0, 1)` 拉住手刹 |
| `VoxelContact` 不触发 | `contactEventThreshold` 默认 0 = 关闭，先设阈值 |
| Assembly 部件轻颠一下就掉 | 连接阈值太低；按 N / N·m 调 `SetMemberBreakThreshold`，边缘超载由引擎滞回处理 |
| Assembly 部件打残后反而撞不掉 | 不要缓存旧碰撞或脚本判定；体素占用变化会回退 Auto，并自动降低有效连接强度 |
| 飞机滑跑龟速上不去 | 起落架 `rollingResistance` 没调低（见第十三节） |
| 飞机停机坐尾/滑跑犁地 | 主轮在质心正下方，后移到质心之后（见第十三节） |
| 飞机满杆翻筋斗 | 缺风向标自稳力矩（见第十三节） |
| 飞机转弯半径巨大 | 平转模型，改压坡转弯（见第十三节） |

---

## 十五、性能提示

- 伤害半径别一次给太大：单次移除上千体素 + 数百碎块会造成巨帧。大范围破坏
  分几帧、分几次小半径调用。
- `maxFrozenFragments` / `maxSpallChunks` / `debrisMaxAge` 是碎块预算三件套，
  移动端从小值起步（如 150 / 12 / 20）。
- 局部编辑用 `MarkRegionDirty`，不要动辄整体 `RebuildGeometry`。
- 详细 API 签名以 `.emmylua/` 里的 `VoxelPhysicsWorld.d.lua`、`VoxelVolume.d.lua`、
  `VoxelAssembly.d.lua`、`VoxelVehicle.d.lua`、`VoxelConstraint.d.lua`、`VoxelGrid.d.lua`、
  `VoxelModel.d.lua` 为准。
