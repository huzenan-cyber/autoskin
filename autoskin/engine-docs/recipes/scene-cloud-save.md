# 场景云存档与读档

`SaveScene` 保存整个场景的可序列化状态（包括体素破坏结果），`LoadScene` 读取后返回一个新的 `Scene`。引擎负责压缩、临时文件、分块传输和校验，玩法不需要先把场景转换成字符串再调用 `Set`。

完整参数、选项和回调类型以随 kit 分发的 `.emmylua/ClientCloud.d.lua`、`.emmylua/ServerCloud.d.lua` 为准；本文说明接入流程。

## 选择调用端和存档归属

| 需求 | 调用端 | 归属 |
|------|--------|------|
| 单机进度 | `clientCloud:SaveScene/LoadScene` | 当前项目、当前登录账号、`slot` |
| 联机房主下次建房继续 | `serverCloud:SaveScene/LoadScene` | 当前项目、`{ kind = "player", playerId = hostUserId }`、`slot` |
| 持久世界 | `serverCloud:SaveScene/LoadScene` | 当前项目、`{ kind = "world", ownerId = ownerId, worldId = worldId }`、`slot` |

- `slot` 为 1–32 个 ASCII 字母、数字或短横线，例如 `park-solo`、`park-host`。它是存档槽名，不是文件路径。同一归属、同一槽的保存会更新当前版本。
- 项目隔离依赖实际配置的项目 ID；两个项目复用同一个 ID 就会共享命名空间。同项目、同账号的客户端个人存档和服务端 `kind = "player"` 存档也共用槽，单机和联机建议使用不同槽名。
- `playerId`、`ownerId`、`worldId` 必须是正整数。服务器从已认证的玩家身份和可信世界元数据确定归属；临时 `roomId` 不能代替持久 `worldId`。这些接口不会创建世界或授予访问权限。
- 联机场景由服务端保存权威状态。客户端的暂停菜单发送玩法请求，服务端验证房主权限后调用 `serverCloud`，再把结果通知玩家。

## 保存频率与存储空间

**同一槽再次保存会上传一份完整的新存档，已发布的旧版本当前不会自动删除。** 更新的是“当前版本”指向，数据库仍保留旧版本的数据。例如每次压缩后的归档为 20 MiB，成功保存 100 次约占 2000 MiB（另有少量记录开销），即使玩家只看到一个存档槽。64 MiB 上限针对单次归档，不是该槽的累计存储上限。

**已发布版本保留多久、保留几份以及何时删除，由游戏逻辑决定；引擎不会自动回收它们。** 尚未接入清理时建议采用低频手动保存或关卡检查点保存；保存频率与存储配额一起规划。

游戏清理旧版本时，按以下约定使用现有云变量删除接口：

1. 保存成功后，持久记录项目、归属、`slot`、`info.version` 和 `info.chunkCount`，用于后续定位分块。清理在同一项目、同一归属下执行；当前没有历史版本枚举接口，丢失记录后无法仅靠 `LoadScene` 找回全部旧版本。
2. 新版本保存成功后，由游戏协调同槽的保存和读取，确认待删版本已被替代，且所有设备、房间均不再读取它。仅发现当前版本已变化不能证明旧版本无人读取；`PublishUnknown` 对应的版本继续保留。
3. 旧版本的分块 key 为 `__scene/<slot>/<version>/<index>`，`index` 从 `0` 到 `chunkCount - 1`。逐批删除并检查回调；删除失败时保留清理记录，以便后续重试。清理也消耗普通云变量额度，由游戏控制频率。

| 存档归属 | 删除单个已确认可回收的分块 |
|------|------|
| 客户端个人存档 | `clientCloud:BatchSet():Delete(key):Save("清理旧存档", events)` |
| 服务端个人存档 | `serverCloud:Delete(playerId, key, events)` |
| 服务端世界存档 | `serverCloud:BatchCommit("清理旧存档"):WorldDataDelete(ownerId, key, worldId):Commit(events)`；该构建器方法已注册，但暂未出现在 `.d.lua` 中 |

目前没有 `DeleteScene` 一类的整槽删除接口。清理旧版本只删除其分块，保留当前版本及 `__scene/<slot>/head`；普通业务字段仍使用自己的 key，不占用 `__scene/` 前缀。

## 先区分入队与完成

两类接口都同步返回 `taskId` 或 `nil, reason`。拿到 `taskId` 只表示任务已入队；入队失败不会再调用该任务的回调。

| 回调 | 含义 |
|------|------|
| 保存 `ok(info)` | 云端已经确认本次存档成为当前版本，此时才显示“保存成功” |
| 读取 `ok(scene, data, info)` | 下载和校验完成，得到新场景及保存时的附加数据 |
| `error(code, reason)` | 异步失败；`code` 是字符串 `Failed` 或 `PublishUnknown`，不是普通云变量的数字错误码 |

`info.version` 可用于记录实际存档版本，`info.totalBytes` 是归档文件大小。`LoadScene` 的 `options` 当前保留，传 `nil` 即可；即使不用选项，也要保留它的位置再传 `events`。存档接口没有独立的 `timeout` 回调。

## 单机暂停菜单示例

以下两个函数放进已有玩法模块，分别绑定“保存”和“读取”按钮。前提：模块已持续持有 `activeScene` 和 `progress`，当前处于暂停菜单，场景中有带 `Camera` 组件的 `Camera` 节点。示例只演示相机绑定；玩家、工具和事件引用按后文的替换流程处理。

```lua
local archiveBusy = false

local function ArchiveError(code, reason)
    archiveBusy = false
    print("Scene archive:", code, reason)
end

function SaveCheckpoint()
    if archiveBusy then return end
    archiveBusy = true
    local taskId, reason = clientCloud:SaveScene("park-solo", activeScene, {
        data = { schema = 1, level = progress.level },
    }, {
        ok = function(info)
            archiveBusy = false
            print("Saved:", info.version)
        end,
        error = ArchiveError,
    })
    if not taskId then ArchiveError("Rejected", reason) end
end

function LoadCheckpoint()
    if archiveBusy then return end
    archiveBusy = true
    local taskId, reason = clientCloud:LoadScene("park-solo", nil, {
        ok = function(loaded, data, info)
            local cameraNode = loaded:GetChild("Camera", true)
            local camera = cameraNode and cameraNode:GetComponent("Camera")
            if type(data) ~= "table" or data.schema ~= 1 or not camera then
                loaded:Dispose()
                ArchiveError("IncompatibleSave", "Missing camera or unsupported progress schema")
                return
            end

            local oldScene = activeScene
            activeScene = loaded
            progress = data
            renderer:SetViewport(0, Viewport:new(activeScene, camera))
            -- Rebind any additional gameplay references before disposing the old scene.
            if oldScene then oldScene:Dispose() end
            archiveBusy = false
            print("Loaded:", info.version)
        end,
        error = ArchiveError,
    })
    if not taskId then ArchiveError("Rejected", reason) end
end
```

`Rejected`、`IncompatibleSave` 是示例自己的提示分类，不是引擎返回码。引擎不会自动保存、自动读档或自动重新开始；这些入口由玩法决定。存取期间禁用重复点击，不要在每帧更新中发起任务。

## 联机房主存档示例

以下代码只放在服务端。`serverScene`、`roomProgress` 是模块持续持有的当前场景和业务进度；`hostUserId` 由服务器可信房间信息取得。保存函数由通过权限验证的菜单请求触发。

```lua
function SaveHostCheckpoint(hostUserId)
    local target = { kind = "player", playerId = hostUserId }
    local taskId, reason = serverCloud:SaveScene(target, "park-host", serverScene, {
        data = { schema = 1, chapter = roomProgress.chapter },
    }, {
        ok = function(info)
            print("Room saved:", info.version)
        end,
        error = function(code, message)
            print("Room save failed:", code, message)
        end,
    })
    if not taskId then print("Room save rejected:", reason) end
end

-- Use during room setup, before assigning any player connection to the scene.
function LoadHostCheckpoint(hostUserId)
    local target = { kind = "player", playerId = hostUserId }
    local taskId, reason = serverCloud:LoadScene(target, "park-host", nil, {
        ok = function(loaded, data, info)
            if type(data) ~= "table" or data.schema ~= 1 then
                loaded:Dispose()
                print("Unsupported room save")
                return
            end
            local oldScene = serverScene
            serverScene = loaded
            roomProgress = data
            -- Rebind any gameplay references before disposing the old scene.
            if oldScene then oldScene:Dispose() end
            print("Room loaded:", info.version)
            -- Continue the existing Ready flow only after rebinding is complete.
        end,
        error = function(code, message)
            print("Room load failed:", code, message)
        end,
    })
    if not taskId then print("Room load rejected:", reason) end
end
```

持久世界使用同样的调用顺序，把两处 `target` 换为 `{ kind = "world", ownerId = ownerId, worldId = worldId }`，保存与读取保持一致。房主个人存档在下次建房时仍使用原房主账号和同一槽名，不跟随新房间的临时 ID。

**已有玩家在线时读档，还需要玩法实现一次完整的场景切换**：暂停权威逻辑，让客户端准备新场景，解除旧连接场景及玩家对象引用，安装新场景并重新绑定，随后按既有 Ready 流程恢复同步。`LoadScene` 本身不会重连玩家、重建玩家控制器或广播读档结果。接入细节见 [联网游戏指南](network-game-guide.md) 和 [体素联网指南](voxel-networking.md)。

## 场景替换与业务数据

读取期间保留旧场景；成功回调也不会自动替换它。推荐顺序：

1. 校验 `data.schema` 和必要节点；不接受该版本时 `Dispose()` 新场景，继续使用旧场景。
2. 清理旧场景的事件订阅、计时器、玩家/工具引用及视口、连接绑定。
3. 用模块级变量持有新场景，恢复附加数据，重新查找节点、绑定相机和玩法对象，再恢复输入与更新。
4. 显式 `Dispose()` 旧场景并清除残留引用。仅给 `viewport.scene` 或 `connection.scene` 赋值不足以保活新场景，见 [Lua 开发指南的对象生命周期章节](../lua-scripting-guide.md)。

存档包含节点、组件的可序列化属性和体素状态，不是进程内存快照：普通 Lua table、闭包、计时器、网络连接和资源文件内容不会因此自动保存。任务进度、关卡版本等放进 `options.data`；模型、材质等引用的资源仍需随项目发布并在加载时可用。

`data` 使用普通 Lua 值（字符串、数字、布尔值和无环 table），上限 1 MiB、最多 16 层 table（包含根 table，最深层内仍可放字符串、数字等普通值）；不要放入 Scene、Node、Connection、函数或循环引用。用自己的 `schema` 处理玩法数据迁移，不要在恢复后再运行会重置地图、体素硬度或已消耗物件的首次初始化逻辑。

## 时机、失败与运行条件

- 保存入队后，在任务实际启动的帧末于主线程同步采集并写入临时文件，再异步上传；场景和 `options.data` 在采集前保持引用，并非调用那一刻就已复制。需要固定暂停时的状态时，由玩法保持暂停并避免修改待保存数据。
- 下载完成后同样在主线程同步创建新场景。大场景保存、加载都可能卡帧，适合放在暂停菜单或加载界面；保存默认启用压缩，当前归档文件上限为 64 MiB。
- 存档与普通云变量共享额度。两端存档传输按 50% 的长期预算份额调度；客户端额度全局共享，服务器同房间的所有玩家共用额度。每个网络请求默认等待 15 秒，**不是整个存档任务 15 秒内完成**。
- `Failed` 表示任务未成功完成；空槽、下载失败和损坏数据目前都可能返回它，没有独立 `NotFound` 码。不要把所有读取失败当成“没有存档”而立即覆盖保存。
- `PublishUnknown` 表示最后发布的回复未确认，云端可能已经保存成功。提示“保存结果未确认”，允许恢复网络后读取同槽并核对版本/业务进度；不要直接宣布存档丢失或循环自动重存。
- 当前不支持断点续传，也不会靠客户端断线缓存自动补发存档。项目/脚本切换、Stop 会取消任务并解除回调；需要“保存后退出”时，在成功回调中再触发退出，退出期间发起保存不能保证完成。崩溃或直接关闭不保证未完成的进度落云。
- 客户端需要登录，两端都需要有效项目 ID 和可用的云变量通道。临时文件由引擎管理；Web 需要可用的 OPFS。编辑器本地联机预览的服务端使用项目 `.cache/scene-archives/`，目录按需创建；独立部署的服务端需要宿主设置 `URHOX_SCENE_ARCHIVE_ROOT` 为可写绝对目录，玩法 Lua 不负责创建此配置。
- 同一账号或世界的同一槽由一个会话负责写入；接口不提供跨设备/跨房间并发写入的冲突合并。普通云变量不要占用引擎保留的 `__scene/` 键前缀。

普通进度字段和排行榜继续使用 [clientCloud](client-cloud-score.md) / [serverCloud](server-cloud-score.md) 的云变量接口；仅需本地文件时见 [文件存储](file-storage.md) 及 `.emmylua/SceneArchive.d.lua`。
