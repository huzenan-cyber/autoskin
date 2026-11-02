# Plugin Lua 脚本指南

整体宿主关系先读 [Plugin 运行架构](architecture.md)。

## 1. Plugin 是 UrhoX Lua 应用

Plugin 的入口、场景、UI 和输入处理与普通 UrhoX Lua 项目一致：

```text
projectRoot/
├─ .project/
├─ scripts/
│  └─ main.lua
├─ assets/
└─ docs/
```

创建节点、相机、灯光和 UI 时继续使用 `engine-docs/` 与 `urhox-libs/`。不要为了调用
Agent 再拆一套 Web UI，也不要在业务脚本中调用 Provider CLI、HTTP 或 C ABI。

Plugin 专用能力来自三个模块：

```lua
local Environment = require "urhox-libs/Plugin/Environment"
local Files = require "urhox-libs/Plugin/Files"
local Agent = require "urhox-libs/Plugin/Agent"
```

## 2. 运行环境

普通 `Maker` 和直接启动的 Runtime 是 `runtime` 环境；UrhoXEditor 的 `Maker-Plugin`
按钮启动 `plugin` 环境。

```lua
if not Environment.IsPlugin() then
    print("Please start with Maker-Plugin")
    return
end
```

`GetLuaEnvironment()` 表示 Lua VM 类型，不能判断 Plugin。统一使用
`Environment.IsPlugin()` 或只读的 `GetApplicationEnvironment()`。

Plugin API 在普通 Runtime 中仍可 `require`，但调用会异步返回
`PLUGIN_ENVIRONMENT_REQUIRED`。

## 3. 三个互相隔离的目录

### 3.1 插件包目录

插件包目录保存发布的插件自身内容。`Plugin.Files` 不以它为根，也不允许业务 Lua取得其
绝对路径。

### 3.2 正在编辑的项目

`Plugin.Files` 操作插件正在编辑的目标项目。本地调试时：

```text
Files.ReadBinary("assets/demo.jpg")
    -> <projectRoot>/assets/demo.jpg
```

这里只接受虚拟相对路径。插件代码不拼接 `projectRoot`，也不能传绝对路径。

本地 `Maker-Plugin` 会把目标项目的 `assets/` 目录加入 Runtime 的 `ResourceCache`。引擎
资源路径相对于 `assets/`：

```lua
local texture = cache:GetResource("Texture2D", "demo.jpg")
```

Web/WASM 将来由宿主把本地硬盘目录挂载成项目目录，并在 `Files.LOCAL` 模式下提供相同的
`assets/` ResourceCache 路径。同步 API 和当前实现状态见
[`Plugin.Files`](api/files.md#同步模式预留)。

### 3.3 Agent Session

每次 `Agent.CreateSession` 都创建一个独立工作区：

```text
<sandboxRoot>/session-<id>/
├─ scripts/
├─ assets/
├─ input/
├─ references/
├─ generated/
├─ screenshots/
├─ result/
└─ logs/
```

Agent 在这个目录内生成、运行、截图和迭代，不直接修改正式项目。插件只能通过 Artifact
API 读取 `result/`、`generated/`、`screenshots/`，再显式导入项目。

## 4. 所有 Plugin I/O 都是异步的

`Plugin.Files` 和 `Plugin.Agent` 统一采用 callback：

```lua
local handle = Files.ReadText("docs/config.json", function(text, err)
    if err then
        print(err.code .. ": " .. err.message)
        return
    end
    print(text)
end)

-- callback 尚未投递时可取消
handle:Cancel()
```

契约：

- 方法立即返回 `RequestHandle`。
- callback 形状统一为 `function(result, err)`。
- 成功时 `err == nil`；失败时 `result == nil`。
- callback 最多调用一次，而且不会在当前调用栈同步执行。
- `RequestHandle:Cancel()` 可重复调用。
- Agent 事件使用 `Agent.OnEvent`，不混入请求 callback。

不要这样写：

```lua
local value
Files.ReadText("docs/config.json", function(result)
    value = result
end)
UseImmediately(value) -- 错误：callback 尚未执行
```

## 5. Request ID

`CreateSession`、`SendPrompt` 和 `ExportArtifacts` 要求非空 `requestId`。同一次业务操作重试
时复用原 ID可以获得幂等结果；新的业务操作必须使用新 ID。

```lua
local requestSequence = 0

local function NewRequestId(prefix)
    requestSequence = requestSequence + 1
    return prefix .. "-" .. tostring(os.time()) .. "-" .. tostring(requestSequence)
end
```

UI 按钮还应使用 `running` 状态防止用户重复点击并发创建 Session。

## 6. 错误处理

所有异步错误都使用同一结构：

```lua
{
    code = "INVALID_PATH",
    message = "virtual path is not allowed",
    retryable = false,
}
```

业务判断依赖 `code`，`message` 用于日志和界面提示。`retryable == true` 只表示错误可能适合
重试，不表示可以无上限自动重试。

```lua
local function ShowError(err)
    local code = type(err) == "table" and err.code or "UNKNOWN"
    local message = type(err) == "table" and err.message or tostring(err)
    print(code .. ": " .. message)
end
```

## 7. 生命周期

建议每个生成流程维护：

- 当前 `sessionId`
- 当前 `turnId`
- 当前 `requestId`
- `running` / `cancelled` 状态
- `Agent.OnEvent` 返回的取消订阅函数

关闭界面时：

1. 取消尚未完成的请求或 Turn。
2. 取消事件订阅。
3. 需要保留结果排障时不要立即 `DiscardSession`。
4. 确认结果已经导入项目后，再按产品策略删除 Session。

Runtime 正常退出时宿主会关闭 Agent SDK 并回收受控子进程。Session 目录默认保留用于日志、
截图和故障恢复。

## 8. 当前平台状态

当前已实现：

- Windows x64 本地 `Maker-Plugin`
- Native `Plugin.Agent`
- Local `Plugin.Files`
- 当前目标项目 `assets/` 目录的 `ResourceCache` 挂载
- `Files.SetMode`、`Files.SyncToRemote`、`Files.SyncToLocal` 占位接口
- Claude、Codex、Gemini Provider 配置入口
- Agent Session、事件、Artifact、取消和输出日志

当前未实现：

- Web/WASM Remote Agent Backend
- Web/WASM Plugin Files Lua Backend
- Web/WASM 本地项目目录挂载及实际双向同步
- 非 Windows Native Agent 进程执行
- `SendPrompt` 中附加新图片；图片和其他文件应在 `CreateSession.references` 中提供

业务 Lua 不应按平台或 Backend 写两套逻辑。未实现的平台会返回结构化错误。
