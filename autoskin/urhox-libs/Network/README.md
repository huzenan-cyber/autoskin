# network/ - 网络工具模块

网络游戏开发的辅助工具。

## 📦 模块清单

| 模块 | 功能 |
|------|------|
| **CommandLineParser.lua** | 命令行参数解析 |
| **NetworkUtils.lua** | 远程事件注册/收发与 VariantMap 互转的最小封装 |
| **PlayerSessions.lua** | 玩家会话生命周期编排：服务端按认证 `user_id` 单表 + 客户端等权威快照 |

---

## CommandLineParser.lua

### 功能
- 解析命令行参数
- 网络配置解析（服务器/客户端）
- 通用参数解析器
- 参数类型转换

### API

#### 网络参数解析

```lua
local CommandLineParser = require "urhox-libs.Network.CommandLineParser"

function Start()
    -- 解析网络参数
    local args = CommandLineParser.ParseNetworkArgs()
    
    if args.runServer then
        print("Starting server on port: " .. args.serverPort)
        StartServer(args.serverPort)
    elseif args.runClient then
        print("Connecting to: " .. args.serverAddress .. ":" .. args.serverPort)
        print("Username: " .. args.userName)
        ConnectToServer(args.serverAddress, args.serverPort, args.userName)
    end
    
    -- 禁用背景音乐
    if args.nobgm then
        DisableBGM()
    end
end
```

**支持的参数**：
```bash
# 服务器模式
./MyGame -server
./MyGame --server -port 2345

# 客户端模式
./MyGame -address 192.168.1.100
./MyGame --address 192.168.1.100 -port 2345 -username Player1

# 其他选项
./MyGame -nobgm  # 禁用背景音乐
```

#### 通用参数解析

```lua
local CommandLineParser = require "urhox-libs.Network.CommandLineParser"

function Start()
    -- 定义参数
    local definitions = {
        {
            name = "fullscreen",
            hasValue = false,  -- 布尔标志
            default = false,
            alias = "f"        -- 支持 -f 或 --fullscreen
        },
        {
            name = "resolution",
            hasValue = true,   -- 需要值
            type = "string",
            default = "1920x1080",
            alias = {"res", "r"}  -- 支持多个别名
        },
        {
            name = "quality",
            hasValue = true,
            type = "number",
            default = 2,
            alias = "q"
        },
        {
            name = "debug",
            hasValue = false,
            default = false,
            alias = "d"
        }
    }
    
    -- 解析参数
    local args = CommandLineParser.Parse(definitions)
    
    -- 使用参数
    if args.fullscreen then
        graphics:SetMode(1920, 1080, true, true)
    end
    
    print("Resolution: " .. args.resolution)
    print("Quality: " .. args.quality)
    
    if args.debug then
        -- 启用调试模式
        log:SetLevel(LOG_DEBUG)
    end
end
```

**使用示例**：
```bash
./MyGame -fullscreen -resolution 2560x1440 -quality 3 -debug
./MyGame -f -res 1920x1080 -q 2 -d
```

#### 辅助方法

```lua
local CommandLineParser = require "urhox-libs.Network.CommandLineParser"

-- 获取所有原始参数
local allArgs = CommandLineParser.GetRawArguments()
for i, arg in ipairs(allArgs) do
    print(i .. ": " .. arg)
end

-- 检查是否存在指定参数
if CommandLineParser.HasArgument("server") then
    print("Server mode enabled")
end

if CommandLineParser.HasArgument("debug") then
    print("Debug mode enabled")
end
```

---

## NetworkUtils.lua

### 功能
- Lua table ↔ `VariantMap` 互转（支持 number / string / boolean / Vector2 / Vector3 / Color）
- 合并「注册远程事件 + 订阅」两步为一步
- 客户端发送 / 服务端广播的便捷包装

### API

| 函数 | 说明 |
|------|------|
| `NetworkUtils.ToVariantMap(tbl)` | Lua table → `VariantMap` |
| `NetworkUtils.FromVariantMap(eventData, keys)` | `VariantMap` → Lua table（按 `keys` 指定的类型取值） |
| `NetworkUtils.OnRemoteEvent(name, handler)` | `RegisterRemoteEvent` + `SubscribeToEvent` |
| `NetworkUtils.SendToServer(name, data, reliable)` | 客户端 → 服务端 |
| `NetworkUtils.BroadcastToClients(name, data, reliable)` | 服务端 → 所有客户端 |
| `NetworkUtils.IsConnectedToServer()` | 是否已连上服务端 |
| `NetworkUtils.GetLatency()` | 当前延迟（毫秒） |

```lua
local NetworkUtils = require("urhox-libs.Network.NetworkUtils")

NetworkUtils.OnRemoteEvent("GameState", "HandleGameState")
NetworkUtils.SendToServer("PlayerMove", { x = 10.5, y = 0, action = "move" })
```

它只做语法糖，不改变引擎原生 API 的语义——需要精确控制 Variant 类型时直接用 `VariantMap()`。

---

## PlayerSessions.lua

### 功能

把引擎四个 `PlayerSession*` 事件（`Joined` / `Disconnected` / `Reconnected` / `Left`）与
「等客户端就绪再设 `connection.scene`、再推权威快照」的时序，封装成可直接抄的骨架。
快照内容与序列化仍由游戏决定，本模块只做编排。

替你挡掉三个不显然的坑（详见文件头注释）：

1. **单表，不要双表**：顶号也触发 `Reconnected`，而那个玩家从未进过「已断线」集合
2. **不能在收到 start 事件时就设 `connection.scene` / 推快照**：客户端脚本可能还没就绪
3. **首次/重连的权威判定在服务端**：客户端 `IsReconnectSession()` 只能驱动 UI 文案

### API

服务端（在 `StartServer()` 的同步执行流里调用 `Setup`）：

| 函数 | 说明 |
|------|------|
| `PlayerSessions.Server.Setup(config)` | 注册四个会话事件与就绪握手，接管单表维护 |
| `PlayerSessions.Server.Get(userId)` / `.GetState(userId)` | 按认证 `user_id` 取会话条目 / 游戏状态 |
| `PlayerSessions.Server.FromConnection(connection)` | 用连接反查玩家（只 lookup，绝不创建） |
| `PlayerSessions.Server.ForEach(fn)` / `.ForEachOnline(fn)` | 遍历全部 / 只遍历在线（**广播用后者**） |
| `PlayerSessions.Server.Count()` / `.CountOnline()` | 玩家数 / 在线数 |
| `PlayerSessions.Server.PushSnapshot(userId)` | 主动重推权威快照 |
| `PlayerSessions.Server.NotifyClientReady(conn, rerequestId)` | 游戏已有自己的就绪握手时手动触发激活。`rerequestId` 省略时，已激活连接的就绪会被当作重试回声丢弃 |
| `PlayerSessions.Server.Shutdown()` | 解订阅 + 清表（单测 / 脚本热切换用） |

客户端（在 `Start()` 的同步执行流里调用 `Setup`）：

| 函数 | 说明 |
|------|------|
| `PlayerSessions.Client.Setup(config)` | 注册快照事件、上报就绪、启动重试与超时兜底。给了 `config.scene` 时，在**每次**上报就绪前幂等赋 `serverConnection.scene`（随重试一并补，故连接晚于 `Setup` 建立也不会漏） |
| `PlayerSessions.Client.IsWaiting()` | 是否仍在等服务端权威激活（增量事件应在此期间忽略） |
| `PlayerSessions.Client.GetUserId()` | 本机认证 user_id（字符串）。**广播必须靠它做归属判断**，否则会把别人的状态写进自己的显示；首份快照抵达前为 nil |
| `PlayerSessions.Client.IsReconnectHint()` | ⚠️ 仅供 UI 文案的本地推断 |
| `PlayerSessions.Client.GetSessionId()` | 本局会话 ID（后台匹配下可能为空串） |
| `PlayerSessions.Client.RequestSnapshot()` | 请求服务端重推权威快照（UI 上的「重试」按钮）。已激活后调用同样有效，服务端走 `PushSnapshot` 应答 |
| `PlayerSessions.Client.Shutdown()` | 解订阅 |

```lua
local PlayerSessions = require("urhox-libs.Network.PlayerSessions")

function StartServer()
    scene_ = Scene()
    scene_:CreateComponent("Octree", LOCAL)

    PlayerSessions.Server.Setup({
        scene = scene_,
        onCreatePlayer = function(userId, connection)
            return { score = 0 }
        end,
        -- 注意是「往传入的 snapshot 里填」，不是返回一个新 map
        onBuildSnapshot = function(entry, isRestore, snapshot)
            snapshot["Score"] = Variant(entry.state.score)
        end,
        onDisposePlayer = function(entry, reason) end,
    })
end
```

完整回调清单、参数顺序与保留字段（可覆盖的 `SessionReady` / `SessionSnapshot` /
`SessionRestore`，以及不可覆盖的 `SessionUserId` / `SessionRerequest`）见
`PlayerSessions.lua` 文件头；可跑骨架见 `LuaScripts/Hand-picked/SessionReconnectDemo/`。

---

## 💡 使用场景

### 场景 1：多人游戏启动器

```lua
local CommandLineParser = require "urhox-libs.Network.CommandLineParser"

function Start()
    local args = CommandLineParser.ParseNetworkArgs()
    
    if args.runServer then
        -- 服务器模式
        network:StartServer(args.serverPort)
        print("Server started on port " .. args.serverPort)
        
    elseif args.runClient then
        -- 客户端模式
        if args.serverAddress == '' then
            args.serverAddress = "localhost"
        end
        
        local success = network:Connect(args.serverAddress, args.serverPort)
        if success then
            print("Connected to server")
            network:SetUsername(args.userName)
        else
            print("Failed to connect")
        end
        
    else
        -- 单机模式或显示 UI 选择
        ShowMainMenu()
    end
end
```

**启动命令**：
```bash
# 服务器
./MyGame -server -port 2000

# 客户端 1
./MyGame -address 192.168.1.100 -port 2000 -username Alice

# 客户端 2
./MyGame -address 192.168.1.100 -port 2000 -username Bob
```

### 场景 2：开发调试模式

```lua
local CommandLineParser = require "urhox-libs.Network.CommandLineParser"

function Start()
    local defs = {
        {name = "debug", hasValue = false},
        {name = "level", hasValue = true, type = "string", default = "Level1"},
        {name = "god", hasValue = false},  -- 无敌模式
        {name = "noclip", hasValue = false}  -- 穿墙模式
    }
    
    local args = CommandLineParser.Parse(defs)
    
    -- 调试模式
    if args.debug then
        debugHud:SetMode(DEBUGHUD_SHOW_ALL)
        console:SetVisible(true)
    end
    
    -- 直接加载关卡
    if args.level then
        LoadLevel(args.level)
    end
    
    -- 作弊模式
    if args.god then
        player.godMode = true
    end
    
    if args.noclip then
        player.noclip = true
    end
end
```

**启动命令**：
```bash
# 调试模式直接进入关卡3
./MyGame -debug -level Level3 -god

# 测试关卡（无敌+穿墙）
./MyGame -level BossRoom -god -noclip
```

### 场景 3：自动化测试

```lua
local CommandLineParser = require "urhox-libs.Network.CommandLineParser"

function Start()
    local defs = {
        {name = "test", hasValue = false},
        {name = "testcase", hasValue = true, type = "string"},
        {name = "headless", hasValue = false},  -- 无GUI模式
        {name = "autoplay", hasValue = false}
    }
    
    local args = CommandLineParser.Parse(defs)
    
    if args.test then
        -- 测试模式
        if args.headless then
            graphics:SetWindowVisible(false)
        end
        
        if args.testcase then
            RunTestCase(args.testcase)
        else
            RunAllTests()
        end
        
        if args.autoplay then
            EnableAutoPlay()
        end
    end
end
```

**启动命令**：
```bash
# 运行所有测试
./MyGame -test -headless

# 运行特定测试
./MyGame -test -testcase "PlayerMovementTest" -autoplay
```

---

## 🔧 参数定义格式

```lua
{
    name = "paramName",       -- 参数名称（必需）
    hasValue = true/false,    -- 是否需要值（必需）
    type = "string",          -- 值类型："string", "number", "boolean"（可选）
    default = value,          -- 默认值（可选）
    alias = "shortName"       -- 别名，可以是字符串或数组（可选）
}
```

### 类型说明

| 类型 | 说明 | 示例 |
|------|------|------|
| **string** | 字符串（默认） | "Player1", "192.168.1.1" |
| **number** | 数字 | 1234, 3.14 |
| **boolean** | 布尔值 | true, false |

---

## 📋 最佳实践

### 1. 提供帮助信息

```lua
function ShowHelp()
    print("Usage: MyGame [options]")
    print("Options:")
    print("  -server, --server         Start as server")
    print("  -address <ip>             Connect to server")
    print("  -port <number>            Server port (default: 1234)")
    print("  -username <name>          Player username")
    print("  -fullscreen, -f           Run in fullscreen")
    print("  -debug, -d                Enable debug mode")
    print("  -help, -h                 Show this help")
end

function Start()
    if CommandLineParser.HasArgument("help") then
        ShowHelp()
        engine:Exit()
        return
    end
    
    -- 正常启动...
end
```

### 2. 验证参数

```lua
local args = CommandLineParser.ParseNetworkArgs()

if args.runClient and args.serverAddress == '' then
    log:Write(LOG_ERROR, "Client mode requires -address parameter")
    engine:Exit()
    return
end

if args.serverPort < 1024 or args.serverPort > 65535 then
    log:Write(LOG_ERROR, "Invalid port number: " .. args.serverPort)
    engine:Exit()
    return
end
```

### 3. 配置文件 + 命令行

```lua
-- 优先级：命令行 > 配置文件 > 默认值
local config = LoadConfig("config.json")
local args = CommandLineParser.ParseNetworkArgs()

local finalConfig = {
    serverPort = args.serverPort or config.serverPort or 1234,
    userName = args.userName ~= '' and args.userName or config.userName or "Guest"
}
```

---

## 📚 相关文档

- [Urho3D Network System](https://urho3d.io/documentation/HEAD/_Network.html)
- [Lua ipairs/pairs](https://www.lua.org/manual/5.4/manual.html#pdf-ipairs)

---

**最后更新**: 2026-07-31

