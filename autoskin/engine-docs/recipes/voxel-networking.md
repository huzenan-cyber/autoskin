# 体素物理联网开发 / Voxel networking for Lua gameplay

本文面向用 Lua 编写多人破坏、建造、体素载具等玩法的开发者。当前支持服务器权威：服务器创建和修改体素，客户端发送操作意图，引擎自动复制对象、体素内容和色板。Lua 不需要编写 Diff 协议、发送 Grid Buffer、登记 Volume 或手动标记网络 dirty。

The server owns voxel content and physics. Lua gameplay sends input or action requests; the engine replicates voxel objects, content and palettes. This guide covers the current server-authoritative implementation.

先读 [体素物理指南](voxel-physics.md) 了解创建、破坏和物理 API，再读 [联网游戏开发指南](network-game-guide.md) 接入项目已有的大厅、玩家会话和输入链路。本文中的代码放在项目的 Client / Server gameplay 模块内；检查 `.project/settings.json` 的 `multiplayer.enabled`，不要把服务端逻辑写进单机入口。

## 1. 哪些工作放在哪一端

| 工作 | 服务端 | 客户端 |
|---|---|---|
| 创建、删除共享的 World / Volume / 约束 / 载具 | 创建 `REPLICATED` 对象，执行玩法逻辑 | 接收复制，不再创建同一份对象 |
| 破坏、填充、涂色、碎裂、动力学 | 验证玩家操作后执行 | 发送输入或请求，接收结果 |
| 共享体素的色板和 Bank | 分配、修改并自动同步 | 使用服务器传来的定义和引用 |
| 体素 Mesh / DDA 渲染 | 专用服务器自动关闭派生渲染 | 引擎根据收到的内容自动构建 |
| 音效、粒子、镜头、UI | 发送必要的玩法反馈 | 本地播放和展示 |
| `LOCAL` 体素 | 可创建，例如服务器空气墙 | 可创建，例如本地预览物件 |

普通场景复制负责节点、组件和位姿；体素模块负责内容同步。通用联网指南中“客户端通过 `ScriptObject.DelayedStart` 添加渲染组件”的写法，不需要套在 `VoxelVolume` 上。不要另建一套 `StaticModel` / `CustomGeometry` 来显示远程体素，也不要在客户端重复生成共享体素。

服务端 `LOCAL` 对象不会出现在客户端。若空气墙需要客户端也有碰撞代理，应创建共享对象并配置其显示方式，不能只依靠服务端的 `LOCAL` 对象。

## 2. 接入已有的场景绑定流程

### 服务端创建体素

下面是服务端入口示例。它使用现有 `PlayerSessions` 管理玩家会话，并在客户端上报脚本就绪后绑定场景；项目已有的玩家状态、计分和离开逻辑应合并进对应回调。

```lua
local PlayerSessions = require("urhox-libs.Network.PlayerSessions")

---@type Scene
local scene_
---@type VoxelPhysicsWorld
local world_

function StartServer()
    scene_ = Scene()
    scene_:CreateComponent("Octree", LOCAL)
    world_ = scene_:CreateComponent("VoxelPhysicsWorld", REPLICATED)
    world_.gravity = Vector3(0, -9.81, 0)

    -- 先定义手建体素使用的槽位，再导入 .vox 模型。
    local brickSlot = 7
    world_:SetPaletteEntry(brickSlot, Color(0.65, 0.3, 0.2), 6.0)
    local wall = world_:CreateVolume(
        32, 16, 4, 0.25, Vector3(0, 0, 0), Quaternion(), REPLICATED)
    wall.node.name = "DestructibleWall"
    wall.grid:FillBox(0, 0, 0, 31, 15, 3, true)
    wall.grid:PaintBox(0, 0, 0, 31, 15, 3, brickSlot)
    world_:FinalizeVolume(wall)

    -- Setup 留在 StartServer 的同步执行流中，及时接收首批玩家会话事件。
    PlayerSessions.Server.Setup({
        -- 此处不填 scene；在 onActivated 中显式选择场景同步模式。
        onCreatePlayer = function(userId, connection)
            return { score = 0 }
        end,
        onBuildSnapshot = function(entry, isRestore, snapshot)
            snapshot["Score"] = Variant(entry.state.score)
        end,
        onActivated = function(entry, isRestore)
            entry.connection:SetScene(scene_, SCENE_SYNC_SERVER_REPLICATED)
        end,
        onDisposePlayer = function(entry, reason)
            -- 在这里清理项目自己创建的玩家对象。
        end,
    })
end
```

`onActivated` 是已有的玩家会话回调，此时客户端已准备好接收场景。这里省略服务端 Setup 的 `scene` 配置，是为了由这一处 `SetScene` 选择模式，避免 helper 先按默认模式绑定一次。业务状态快照可能先于体素内容到达，客户端分别等待业务状态和体素就绪。

这个例子只演示体素与会话接入，相机、Viewport、灯光和玩家控制沿用项目模块。服务端模块退出时调用 `PlayerSessions.Server.Shutdown()` 清理会话订阅。专用 `UrhoXServer` 已关闭体素派生渲染；服务端无需为这堵墙调用 `RebuildGeometry()`。需要可移动物件时，在填好 Grid、设好密度后改用 `FinalizeVolumeAsDynamic(volume)`。

### 从 XML 或 .vox 创建

如果关卡来自场景文件，用以下代码替换上面的程序化场景创建部分。文件应包含 `VoxelPhysicsWorld` 和需要复制的 `VoxelVolume`：

```lua
scene_ = Scene()
assert(scene_:LoadXML(cache:GetFile("Scenes/Level.xml")))
world_ = assert(scene_:GetComponent("VoxelPhysicsWorld"))
```

也可以在服务端 World 中追加资源模型，再正常定型：

```lua
local model = assert(cache:GetResource("VoxelModel", "models/house.vox"))
local house = world_:CreateVolumeFromModel(
    model, 0.1, Vector3(8, 0, 0), Quaternion(), REPLICATED)
world_:FinalizeVolume(house)
```

资源路径从 ResourceCache 根开始，不加 `assets/` 前缀。`.vox` 导入、色板合并和 Bank 选择由服务端完成，客户端使用同步的结果。

### 两种场景同步模式

| 服务端绑定写法 | 客户端如何处理服务器的场景文件 |
|---|---|
| `connection.scene = scene_` 或 `connection:SetScene(scene_)` | 保持引擎原来的场景文件加载流程 |
| `connection:SetScene(scene_, SCENE_SYNC_SERVER_REPLICATED)` | 文件存在时使用 `LOAD_RESOURCES_ONLY` 预热资源；文件中的节点、组件不在客户端创建，由服务器复制 |

两种模式都能同步体素内容。希望共享对象完全由服务器生成时，使用第二种；若服务器 Scene 没有文件名，就直接接收复制对象，没有场景文件预热这一步。资源预热减少后续组件到达时的同步资源加载，仍可能需要时间安装大块体素、构建碰撞和显示内容。

采用 `SCENE_SYNC_SERVER_REPLICATED` 时，XML 场景预热校验允许 CRLF 与 LF 行尾不同，不会改写文件；单独的 CR、缩进、属性和文本等其余字节仍需一致。默认同步模式、二进制场景及资源包校验不变。服务端和客户端应一起升级；旧引擎仍按原始字节计算时可能校验失败，没有自动兼容回退。项目应处理 `NetworkSceneLoadFailed`，不要无限等待加载。

客户端不用显式调用 `LoadAsyncXML(..., LOAD_RESOURCES_ONLY)`，模式由上述服务端绑定传递。不要在已经绑定网络连接的客户端 Scene 上另行 `LoadXML` / `LoadAsyncXML`；需要独立预览场景时使用另一份未绑定的 Scene。

服务器使用 `LoadAsyncXML` 时，由游戏决定何时 `SetScene`：可以在 `AsyncLoadFinished` 后绑定，也可以先绑定、边加载边复制。引擎不会替脚本等待服务器整张场景加载完成。采用延后绑定时，玩家会话订阅仍应及时建立，并由脚本记录待绑定连接。

### 客户端安装事件与场景

先订阅体素事件，再启动已有的客户端场景绑定流程。Scene 要保存在模块变量或对象字段中，不能只依赖 Connection 持有它。

```lua
local PlayerSessions = require("urhox-libs.Network.PlayerSessions")

---@type Scene
local scene_
local voxelReady_ = false
local score_ = 0

local function ApplyBusinessState(data)
    score_ = data["Score"]:GetInt()
end

function Start()
    scene_ = Scene()
    scene_:CreateComponent("Octree", LOCAL)
    voxelReady_ = false

    SubscribeToEvent("VoxelContentReady", function(_, data)
        local volume = data["Volume"]:GetPtr("VoxelVolume")
        if not volume or volume:GetScene() ~= scene_ then return end
        local collisionReadyNow = data["CollisionReady"]:GetBool()
        -- volume 的完整内容已可读；可在这里初始化该物件的本地交互提示。
        -- collisionReadyNow 只描述此刻有没有物理 Body，不是全场景就绪条件。
    end)

    SubscribeToEvent("VoxelInitialSyncFinished", function(_, data)
        local world = data["World"]:GetPtr("VoxelPhysicsWorld")
        if world and world:GetScene() == scene_ then
            voxelReady_ = true
        end
    end)

    SubscribeToEvent("VoxelSyncFailed", function(_, data)
        print("[Voxel] " .. data["Reason"]:GetString())
    end)

    PlayerSessions.Client.Setup({
        scene = scene_,
        onFreshStart = ApplyBusinessState,
        onApplySnapshot = ApplyBusinessState,
    })
end

local function CanInteract()
    return voxelReady_ and not PlayerSessions.Client.IsWaiting()
end

function Stop()
    PlayerSessions.Client.Shutdown()
    UnsubscribeFromEvent("VoxelContentReady")
    UnsubscribeFromEvent("VoxelInitialSyncFinished")
    UnsubscribeFromEvent("VoxelSyncFailed")
    voxelReady_ = false
end
```

`PlayerSessions.Client.Setup({ scene = scene_ })` 会先把 Scene 赋给服务器连接，再发送会话的“客户端脚本就绪”消息。这个消息表示能够接收场景，必须发生在接收体素之前；不能等 `VoxelInitialSyncFinished` 后才发送，否则服务器还没有开始给这个客户端复制场景。

如果项目使用自有会话流程，保持同样顺序：客户端先设置 `network:GetServerConnection().scene`，再发送项目原有的就绪消息；服务端收到后在原绑定位置调用 `SetScene`。不要为体素再新增一套连接握手。

`CanInteract()` 是示例里的 Lua 函数，项目还应加入玩家节点、UI 等自身条件。切场景、重新绑定或断线进入等待状态时，脚本重置自己的 `voxelReady_`；不要复用上一张场景的布尔值。

## 3. Ready 具体保证什么

| API / 事件 | 语义 |
|---|---|
| `volume:IsContentReady()` / `volume.contentReady` | 远程 Volume 首次完整内容安装前为 false，成功后为 true；后续 Diff、重建和体素重新同步保留旧完整内容，不反复变成 false |
| `VoxelContentReady` | 远程组件首次安装成功时触发一次，发送者是 Volume 的 Node；参数为 `Volume`、`CollisionReady` |
| `VoxelInitialSyncFinished` | 客户端 World 完成本次初始内容安装并追赶到确认进度时触发，每个同步代次一次；参数为 `World` |

节点或组件刚创建、`ScriptObject.DelayedStart` 被调用，都不等于体素内容已就绪。后挂载的脚本可能错过首次事件，应先查 `IsContentReady()`；未就绪时再等待事件。服务器权威对象和本端 `LOCAL` 对象由脚本管理内容，`IsContentReady()` 返回 true，不会等待联网初始事件。

Ready 表示完整内容可以使用，不保证所有远处 Mesh / GPU 工作已经完成。`CollisionReady` 是事件发生时的 Body 状态；`PresentationOnly`、无碰撞对象等可以为 false，不要等待每个 Volume 都为 true。初始完成以后，服务器新建的 Volume 仍有自己的首次内容事件，在线修改也继续同步。

等待期间要保持 Scene 和 World 更新。禁用 Scene / World，或设置 `world.updateEnabled = false`，会延后内容安装；网络暂存有上限。若只想冻结物理步进，可以使用 `world:SetSimulationPaused(true)`，它不会停掉内容安装。

## 4. 破坏、建造与精确选取

沿用项目的输入同步：连续移动、驾驶意图用 `connection.controls`，挖掘、放置等离散操作可以用已注册的远程事件。客户端可先做准星、声音等本地反馈，共享世界的修改交给服务器。

服务端收到请求后，用事件的 `Connection` 反查真实玩家，检查其状态、工具、冷却和操作权限；射线起点来自服务端玩家状态，距离、破坏半径和强度来自服务端规则。客户端上报的命中点、Volume ID、材质或伤害数值都需要验证。

下面是供已完成上述验证的服务端操作处理器调用的玩法函数；`DigWithValidatedRay` 是示例函数名，不是引擎 API：

```lua
---@param world VoxelPhysicsWorld
---@param ray Ray 服务端计算并验证过的世界空间射线，方向已归一化
local function DigWithValidatedRay(world, ray)
    local hit = world:RaycastGridSingle(ray, 6.0)
    if not hit.hit or not hit.volume then return 0 end
    if hit.paletteDomain ~= VOXEL_PALETTE_REPLICATED then return 0 end
    if not hit.volume:IsDestructible() then return 0 end

    -- 同一材质编号要在命中物件的域里查硬度。
    local power = 8.0
    if world:GetPaletteHardness(hit.material, hit.paletteDomain) > power then
        return 0
    end
    return world:ApplyDamage(hit.volume, hit.position, 0.5, power)
end
```

`RaycastGridSingle(ray, maxDistance, layerMask, ignoreVolume)` 精确查询当前 CPU Grid，不依赖 Drawable、Octree 渲染对象或 Jolt Body；省略后两项时查询所有层且不排除 Volume。服务器无渲染也可以调用。`RaycastGrid` 返回沿射线的多个命中结果。

结果常用字段是 `hit`、`volume`、`volumeId`、`position`、`normal`、`distance`、`voxel`、`material`、`paletteDomain`。客户端只能查询已经安装的内容，因网络延迟可能与服务端结果不同，最终操作结果以服务端为准。

这类查询也能命中 `LOCAL`、`PresentationOnly`、`collidable = false` 的体素。是否允许挖掘、是否阻挡工具射线由玩法决定，可用层掩码、忽略对象和结果过滤表达。上面的例子把先命中的 LOCAL 物件当作阻挡并停止挖掘；不要无意中让本地辅助体素成为可破坏目标。

破坏、填充、涂色使用 [体素物理指南](voxel-physics.md) 中的 World 操作接口，它们自动处理修改后的物理与显示更新，并同步权威结果。直接编辑 `volume.grid` 时，网络内容会自动变脏，但原有的几何刷新、动态碰撞重建和资源解绑规则仍适用，不能把“自动同步”等同于“替脚本完成所有本地编辑步骤”。删除共享物件可调用 `world:RemoveVolume(volume)`。

客户端不要再执行同一次权威 `ApplyDamage` 来“保持同步”。远程 Grid、资源来源、色板和破坏/填充/涂色等权威内容禁止客户端脚本写入。密度、摩擦等普通组件属性保留原本地 setter 语义，客户端修改只影响自身、不回传服务器；共享配置仍应由服务端设置。

`VoxelDamaged` 等玩法事件在执行破坏的一端产生，内容 Diff 不承诺在客户端重放同一组事件。计分和掉落归服务器；需要每个客户端播放一次命中声音或粒子时，使用项目自己的效果事件，不要再传一份体素数据。

## 5. 色板：域、Bank 和材质编号

### 两个域不是服务器 / 客户端两个角色

一个 World 内有两份独立色板域，每个域各有若干 Bank，每个 Bank 有 256 个槽位。一个 Volume 引用其中一个域和一个 Bank。

| Volume 类型 | `GetPaletteDomain()` | 色板由谁维护 |
|---|---|---|
| 服务器创建的共享 Volume 及其客户端副本 | `VOXEL_PALETTE_REPLICATED` | 服务器维护，客户端接收 |
| 任意一端的 `LOCAL` Volume | `VOXEL_PALETTE_LOCAL` | 当前这一端维护，不复制 |

域按对象的有效 `CreateMode` 确定，不按机器是不是服务器确定。客户端接收共享 Volume 时不会再次自行合并它的 `.vox` 色板，因此本地预览模型的导入顺序不会改变共享物件的颜色。

### 修改入口在 World

当前没有 `volume:SetPaletteEntry(...)`。使用以下已经实现的 API：

```lua
-- 省略 domain 始终表示 Replicated，debrisStyle 默认 0。
world:SetPaletteEntry(7, Color(1, 0, 0), 1.0)

-- 显式设置 Local 域。第四项是碎块样式，第五项才是域。
world:SetPaletteEntry(7, Color(0, 1, 0), 1.0, 0, VOXEL_PALETTE_LOCAL)

-- PBR 的域参数在 emissive 之后。
world:SetPaletteEntryPBR(
    7, 0.35, 1.0, 0.5, Color(0, 0, 0, 0), VOXEL_PALETTE_LOCAL)
```

没有域参数的读取接口也默认 Replicated，例如 `GetPaletteColor(index)`、`GetPaletteHardness(index)`、`GetPaletteBankCount()`。要读 Local，显式传域。客户端对收到的 Replicated 色板写入会被拒绝，但可以正常修改 Local 色板。

### 区分 Bank 内槽位与域内全局编号

```text
index = bank * 256 + slot
```

| 接口或字段 | 编号含义 |
|---|---|
| `grid:SetVoxelMaterial(...)`、`grid:PaintBox(...)` | 当前 Volume 的 Bank 内槽位 `slot`，范围 0～255 |
| World 色板读写接口的 `index` | 选定域中的全局编号 `bank * 256 + slot` |
| 射线结果 `hit.material` | `hit.paletteDomain` 中的全局编号 |
| World 破坏、填充、涂色中的 `material` / `scorchMaterial` / `onlyMaterial` | 按每个目标 Volume 的域解释的全局编号；需要时在该域内映射进目标 Bank |

两域中的同一个整数可以表示完全不同的材质。对跨域范围调用填充或涂色时，应为两个域都定义好对应编号，或由玩法限定目标；这些整数参数不会自动把 Replicated 材质复制到 Local 域。

若玩法想“修改某个 Volume 正在使用的槽位”，可以在项目中写这样一个普通 Lua helper：

```lua
---@param world VoxelPhysicsWorld volume 所属的 World
---@param volume VoxelVolume 本端有权修改内容的 Volume
local function SetVolumePaletteSlot(world, volume, slot, color, hardness)
    assert(slot >= 0 and slot <= 255 and slot % 1 == 0)
    local index = volume:GetPaletteBank() * 256 + slot
    world:SetPaletteEntry(index, color, hardness, 0, volume:GetPaletteDomain())
end
```

这个 helper 只省去域和 Bank 的换算，仍然修改共享色板定义：所有引用同一 `(domain, bank, slot)` 的物件都会受影响。它不会为某个 Volume 自动复制独占色板。只想给一个物件涂色时，修改其 Grid 槽位选择；希望单独变更材质定义时，先规划不与其他物件共享的槽位或 Bank。

### Volume 可以切换 Bank，不能直接切换域

```lua
local domain = volume:GetPaletteDomain() -- 只读，没有 SetPaletteDomain
local bank = volume:GetPaletteBank()

-- 示例：为手建体素准备 bank 1 的 7 号槽。
world:SetPaletteEntry(1 * 256 + 7, Color(0.2, 0.4, 0.8), 6.0, 0, domain)
volume:SetPaletteBank(1)
```

`SetPaletteBank` 可以在服务器权威或本端 LOCAL Volume 上动态调用，会同步共享 Volume 的 Bank 引用。它保留 Grid 中原来的槽位字节，不会逐格寻找相同颜色；原来所有 `slot = 7` 的格子改为查新 Bank 的 7 号定义。实际换库前要准备好该物件使用的全部槽位，不能只补一个颜色。客户端不能给远程副本换 Bank。

程序化体素应先注册固定材质，再导入 `.vox`。模型导入会按完整材质定义寻找可复用槽位并选择 Bank，颜色相同但 PBR 等定义不同也可能占不同槽位；源 `.vox` 的颜色编号不一定等于导入后 Grid 的槽位。运行时要改某个已导入格子的材质定义，先读取该格子的实际槽位，再结合 Volume 的域和 Bank 定位。

服务器修改 Replicated 色板条目、Bank 引用或体素格子都会自动进入同步。Lua 不需要调用 `MarkNetworkUpdate`，也不需要每帧重写同一组色板参数。

## 6. LOCAL 体素与客户端物理

### 两端都能创建本地物件

以下代码可用于客户端本地预览，也可放在服务端创建本地辅助物件。World 必须已存在；客户端不要为了创建 LOCAL 物件，提前创建一个与服务器 World 冲突的共享 World。

```lua
world:SetPaletteEntry(7, Color(0.2, 0.8, 0.5), 1.0, 0, VOXEL_PALETTE_LOCAL)
local preview = world:CreateVolume(
    4, 4, 4, 0.25, Vector3(0, 2, 0), Quaternion(), LOCAL)
preview.grid:FillBox(0, 0, 0, 3, 3, 3, true)
preview.grid:PaintBox(0, 0, 0, 3, 3, 3, 7)
preview:SetCollidable(false)
preview:RebuildGeometry()
```

需要服务器空气墙时，另建 LOCAL Volume，保持 `collidable = true`，设置 `destructible = false`，再用 `world:FinalizeVolume(volume)` 建立静态碰撞；只在服务器创建即可。LOCAL 编号由引擎与 Replicated 分开分配，不需要 Lua 手动设置 Volume ID。

同 Scene 重绑时，即使原生生命周期保留了某些 LOCAL 节点，旧复制 World 的 Local 色板也不会自动迁移到新 World。脚本负责清理旧引用，在新 World 到达后重新初始化这些 LOCAL 体素与色板。

### 服务器决定远程副本的 Body 模式

| 服务端设置 | 客户端行为 |
|---|---|
| `VOXEL_CLIENT_COLLISION_PROXY`（默认） | 静态物件使用静态碰撞；运动物件使用跟随服务器节点位姿的运动学碰撞代理 |
| `VOXEL_CLIENT_PRESENTATION_ONLY` | 保留 Grid、显示和精确体素查询，不创建 Jolt Body |
| `VOXEL_CLIENT_SIMULATED` | 当前阶段未开放，设置会被拒绝 |

```lua
-- 在服务端设置，可在运行中调整。
volume:SetClientBodyMode(VOXEL_CLIENT_PRESENTATION_ONLY)
```

CollisionProxy 同时适用于静态和运动物件，客户端不独立求解共享物件的碎裂和自由动力学。这个模式只控制远程副本，服务器和本端 LOCAL 物件仍使用原有物理逻辑。Assembly 共用一个 Body，客户端策略由根 Volume 决定。

### 角色状态直接通过原有 Lua 属性读取

`VoxelCharacterController` 的配置和运行状态都会从服务端同步。客户端可以直接读取远程组件的 `onGround`、`groundState`、`linearVelocity`、`groundNormal`、`groundVelocity`、`swimming`、`maxHitsExceeded`，用于落地反馈、动画和 UI；它们返回最近收到的服务器状态，无需 Lua 另发同一份状态。

```lua
-- controller 是服务器复制来的 VoxelCharacterController。
local grounded = controller.onGround
local velocity = controller.linearVelocity
local swimming = controller.swimming
```

这些值随网络更新到达，客户端不重新推断物理结果。`onGround` 由同步的 `groundState` 得出，两者保持一致；离开支撑面后，`groundNormal` / `groundVelocity` 会随服务器状态清零。`desiredVelocity` 也同步，但表示服务器提交的移动意图，不能替代实际速度；给客户端该属性赋值不会自动向服务器发送玩家输入。

`created` / `IsCreated()` 仍表示本端是否存在角色求解器，因此远程副本为 false，不应把它用作“是否收到角色状态”的判断。服务器和 LOCAL 控制器继续读取本端实际求解结果。上述运行状态走普通组件属性复制，不需要等待 `VoxelContentReady`，也不写入场景文件。

角色移动、载具驱动、约束和抓取的权威计算也放在服务器。连续输入在服务端 `SceneUpdate` 等原有物理前时序应用，客户端显示复制结果。当前阶段没有角色或载具预测、回滚与延迟补偿，不要在远程副本上再运行一套相同的驱动逻辑。

## 7. 晚加入、重连与资源一致性

假设一栋房子已经被其他玩家破坏，后来进入的客户端会得到它的当前状态：

1. 先通过原场景绑定流程准备资源；采用服务器同步模式时，客户端只预热 XML 引用的资源。
2. 服务器复制当前仍存在的节点和组件，以及各 Volume 所需的色板与内容。
3. 未修改的资源模型使用资源引用；破坏后仍以资源为基准的模型以相同资源为起点应用差异；纯程序化或已脱离资源来源的体素需要传输当前完整内容。客户端不必逐次重演历史破坏。
4. 安装期间发生的新修改继续同步并追赶；单个物件首次完整安装后触发 `VoxelContentReady`，本次初始追赶完成后触发 `VoxelInitialSyncFinished`。
5. 此后继续接收在线修改。已经删除的物件不会作为原始场景物件重新留下来，仍存在的碎块按当前对象和内容复制。

短命碎块、粒子或历史爆裂动画不保证被后来进入的玩家看到；玩法不能依靠重放这些过程来恢复计分、背包或任务。此类业务状态仍放在游戏已有的 `PlayerSessions` 快照中，体素 Grid 不要重复塞进去。

服务器和客户端必须使用一致的引擎版本、场景及 `.vox` 等资源。资源缺失或内容不一致属于项目构建、发布或加载问题，需要修正两端资源；体素同步不会把这种错误自动降级为“服务器再发整份模型”。

`VoxelSyncFailed` 的 `Reason` 可以用于日志诊断，但通知是尽力送达。断线处理继续使用项目原来的 `ServerDisconnected` / 大厅会话流程，不要只等这个体素事件。

### 删除后仍被 Lua 引用的物件

Lua 拿到的节点或组件（例如在碎块回调里调用过 `fragment:GetNode()`）会一直保活到 GC。默认情况下，原生场景复制要等对象真正销毁后才通知客户端删除；而体素内容的删除记录在物件移出场景时立即发出。客户端先收到体素删除、原生对象却还在，会报 `Native voxel removal did not arrive` 并断开。频繁破坏、大量碎块的玩法最容易遇到。

这类项目在服务端和客户端初始化时都打开开关，最好在开始场景复制之前：

```lua
network:SetReplicateRemovalOnDetach(true)
```

打开后，节点或组件一旦移出场景，客户端在下一次网络更新就会删除对应副本，不再等服务端 GC；移出后再加回场景的节点会以新 ID 重新复制。客户端只在原生对象连续缺失 5 秒后才判定"创建未到达"。默认关闭，存量游戏行为不变。不要用延长碎块寿命、强制 GC 或关闭失步检测来规避这个问题。

## 8. 性能与排查

UGC 对象数量、体素尺寸、破坏强度和在线人数都影响成本，不能只用玩家人数判断承载量。实际项目优先关注以下几点：

- 静态关卡优先复用 `.vox` 资源；按建筑或局部地形组织 Volume，避免把每次小破坏都放进一个巨大的程序化 Grid。
- 用 `FillBox` / `PaintBox` 等批量 API 初始化；不要在每帧重新 `SetDimensions`、重设资源模型或生成整张地图。
- 服务端限制工具频率、范围和碎块预算，例如 `SetMaxSpallChunks`、`SetMinFragmentVoxels`、`SetMaxFrozenFragments`，并测试连续破坏和多人同时操作。
- 色板在实际变化时才写。一个条目可能被许多 Volume 共用，逐帧改色会同时带来联网与显示更新成本。
- 测试晚加入大场景、进入时持续破坏、断线重连、客户端低帧率和大块程序化体素，不能只验证开局静止场景。

开发时可按需输出 `world:GetNetworkStatsString()`，查看内容队列、安装耗时和发布计数。没有修改时，初始同步后的 `publication_volume_checks` / `publication_bank_checks` 应保持不变；没有观察连接时不会为内容发布周期性扫描全部 Volume。这些是诊断计数，不是整条连接的总流量，也不要把字符串格式当玩法协议解析。

| 现象 | 优先检查 |
|---|---|
| 客户端有节点但还看不到体素 | 检查该 Volume 的 `contentReady`，再检查显示、相机和资源；组件创建不代表内容安装完成 |
| 一直没有初始就绪事件 | 是否先绑定客户端 Scene 并发送原就绪消息；Scene / World 是否被暂停更新；两端资源是否一致 |
| LOCAL 物件颜色错误，或客户端改色无效 | 是否遗漏第五个域参数；World 无域接口默认 Replicated |
| 修改一个物件后其他物件也变色 | 是否共享同一个域、Bank 和槽位；World 改的是共享定义 |
| 换 Bank 后整件物体花色 | 是否为新 Bank 准备了所有使用中的槽位；换 Bank 不会自动保色重映射 |
| 客户端调用破坏没有生效 | 是否在修改远程权威内容；应发送操作意图，由服务器执行 |
| 重连后本地预览或辅助体素异常 | 是否仍引用旧 World / Local 色板；在新 World 上重新初始化 |
| 连续破坏后报 `Native voxel removal did not arrive` 并断线 | 被删物件是否仍被 Lua 引用；两端是否都调用了 `network:SetReplicateRemovalOnDetach(true)`，见第 7 节 |

完整方法签名以运行时随附的 `.emmylua/VoxelPhysicsWorld.d.lua`、`.emmylua/VoxelVolume.d.lua` 和 `.emmylua/Connection.d.lua` 为准。通用 API 入口见 [Network](../api/network.md)，单机创建与各玩法组件见 [体素物理指南](voxel-physics.md)。
