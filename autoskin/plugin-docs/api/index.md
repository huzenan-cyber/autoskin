# Plugin Lua API 索引

## 模块

| 模块 | 用途 |
|---|---|
| [`Plugin.Environment`](environment.md) | 判断 `runtime` / `plugin` 应用环境 |
| [`Plugin.Files`](files.md) | 异步访问正在编辑项目，并管理预留的本地/远端同步模式 |
| [`Plugin.Agent`](agent.md) | 创建 Agent Session、发送 Prompt、读取和导出结果 |

```lua
local Environment = require "urhox-libs/Plugin/Environment"
local Files = require "urhox-libs/Plugin/Files"
local Agent = require "urhox-libs/Plugin/Agent"
```

## 统一异步约定

除 `Environment` 查询、`Agent.Initialize` 和 `Agent.OnEvent` 外，API 都使用：

```lua
local request = Method(..., function(result, err)
end)

request:Cancel()
```

`Agent.OnEvent(callback)` 返回取消订阅函数：

```lua
local unsubscribe = Agent.OnEvent(function(event)
end)

unsubscribe()
```

## 统一错误

```lua
{
    code = "ERROR_CODE",
    message = "human-readable diagnostic",
    retryable = false,
}
```

常见公共错误：

| code | 含义 |
|---|---|
| `PLUGIN_ENVIRONMENT_REQUIRED` | 当前不是 Plugin 环境 |
| `INVALID_REQUEST` | 参数形状或必填字段错误 |
| `INVALID_PATH` | 路径不合法或试图越界 |
| `PERMISSION_DENIED` | Backend 拒绝当前文件操作 |
| `NOT_FOUND` | 文件、Artifact 或 Session 不存在 |
| `BACKEND_UNAVAILABLE` | 宿主未注入对应 Backend |
| `CANCELLED` | 请求或 Turn 已取消 |
| `PROVIDER_TIMEOUT` | Provider 超过 Turn wall time |

具体错误见对应模块文档。
