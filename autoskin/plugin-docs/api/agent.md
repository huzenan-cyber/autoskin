# Plugin.Agent

`Plugin.Agent` 提供与 Provider 无关的 Lua 接口。插件不启动 CLI，不知道 Agent Session 的
绝对路径，也不直接读取 Session 文件系统。

```lua
local Agent = require "urhox-libs/Plugin/Agent"
```

当前本地实现支持宿主配置的 Claude、Codex 和 Gemini CLI。实际可用 Provider、模型和能力
由宿主配置决定。

## GetCapabilities

```lua
Agent.GetCapabilities(function(capabilities, err)
end)
```

当前本地结果形状：

```lua
{
    abiVersion = 1,
    protocolVersion = "1.0",
    features = {
        events = true,
        resume = true,
        artifacts = true,
        workspaceIsolation = false,
        workspacePathValidation = true,
        processTreeCleanup = true,
    },
    providers = {
        {
            name = "codex",
            defaultModel = nil,
            allowedModels = {},
            capabilities = {
                vision = true,
                structuredOutput = true,
            },
        },
    },
}
```

`workspaceIsolation == false` 表示当前 SDK 尚未提供可证明的完整 OS 文件隔离，不能把
Provider 的 cwd 当作安全边界。

## CreateSession

```lua
Agent.CreateSession(input, callback)
```

`input`：

```lua
{
    requestId = "create-scene-123",       -- 必填，非空
    profile = "scene-asset-generation",  -- 可选，业务任务类型
    provider = "codex",                  -- 可选，省略则用宿主默认
    model = "opaque-model-id",           -- 可选，必须在宿主允许列表
    input = {                            -- 可选，JSON-compatible 业务输入
        goal = "生成一个风格化房间场景",
        constraints = {},
    },
    references = {                       -- 可选，创建 Session 时写入
        {
            path = "references/demo.jpg",
            mime = "image/jpeg",
            data = imageBytes,           -- Lua binary string
        },
        {
            path = "references/rules.md",
            mime = "text/markdown",
            data = markdownText,
        },
    },
    requirements = {                     -- 可选
        vision = true,
        structuredOutput = true,
    },
}
```

`references[].path` 必须是 `references/...` 下的安全相对路径。引用可以是图片、Markdown、
JSON 或其他格式；`data` 对文本和二进制都使用 Lua string。Lua 不自行 Base64。

当前 `SendPrompt` 不接收新的图片附件。需要给 Agent 的文件必须在创建 Session 时放入
`references`，Prompt 中再引用相对路径：

```text
请查看 references/demo.jpg，并按 references/rules.md 生成场景。
```

成功结果：

```lua
{
    sessionId = "session-...",
    status = "ready",
    provider = "codex",
    model = "",
    modelSource = "cli-default", -- "session" | "host-default" | "cli-default"
}
```

同一 Session 同一时刻只允许一个活动 Turn。

## SendPrompt

```lua
Agent.SendPrompt(sessionId, {
    requestId = "generate-scene-123",
    prompt = "生成场景并把最终文件放到 result/。",
}, callback)
```

也可以使用文本 messages：

```lua
Agent.SendPrompt(sessionId, {
    requestId = "generate-scene-123",
    messages = {
        { type = "text", text = "读取 references/demo.jpg。" },
        { type = "text", text = "生成场景并至少截图迭代三次。" },
    },
}, callback)
```

多个 text message 会按顺序拼接。必须至少提供一段非空文本。模型在 Session 创建后固定，
不能在 `SendPrompt` 中切换。

成功结果：

```lua
{
    turnId = "turn-1",
    sessionId = "session-...",
    status = "completed",
    output = "...",
    exitCode = 0,
}
```

`output` 是当前 Provider CLI 合并后的 stdout/stderr 原文，格式不稳定。Codex `--json`
输出通常是 JSONL；其他 Provider 可能返回 JSON 或文本。界面可显示或记录它，但业务成功
条件应使用 callback、事件和 Artifact，不应依赖 Provider 文案。

本地 SDK还会把同一输出保存到：

```text
<sandboxRoot>/<sessionId>/logs/<turnId>.log
```

例如 `logs/turn-1.log`。该路径用于本地诊断，不属于 `Plugin.Files`，也不是可读取 Artifact。

## Cancel

```lua
Agent.Cancel(sessionId, turnId, function(result, err)
end)
```

取消活动 Turn。原 `SendPrompt` callback 会收到 `CANCELLED`，并产生 `turn.cancelled` 事件。
取消是幂等操作。

## GetSession

```lua
Agent.GetSession(sessionId, function(session, err)
end)
```

结果：

```lua
{
    sessionId = "session-...",
    status = "ready", -- 也可能是 busy / orphaned
    provider = "codex",
    model = "",
    modelSource = "cli-default",
    turnCount = 1,
}
```

## Resume

```lua
Agent.Resume(sessionId, afterSequence, function(result, err)
end)
```

用于重新连接现有 Session，并返回 `sequence > afterSequence` 的历史事件：

```lua
{
    sessionId = "session-...",
    status = "ready",
    provider = "codex",
    model = "",
    modelSource = "cli-default",
    events = {},
}
```

`afterSequence` 省略时按 `0` 处理。

## Event

```lua
local unsubscribe = Agent.OnEvent(function(event)
    print(event.sequence, event.type, event.turnId)
end)

unsubscribe()
```

事件通用形状：

```lua
{
    kind = "event",
    protocolVersion = "1.0",
    sequence = 1,
    sessionId = "session-...",
    turnId = "turn-1", -- Session 事件可以为空
    type = "turn.started",
    payload = {},
    createdAt = 0,
}
```

当前事件：

| type | payload |
|---|---|
| `session.created` | `provider`、`model` |
| `turn.started` | `turnNumber` |
| `artifact.created` | `path`、`size` |
| `turn.completed` | `stopReason`、`exitCode` |
| `turn.cancelled` | `requestId`、`reason` |
| `error` | 至少包含稳定错误 `code` |

Agent 启动 Runtime、截图和读图迭代发生在 Provider 内部，目前没有单独的 Runtime
子进程阶段事件。需要细粒度进度时，让 Agent 写阶段性 Artifact，或根据现有事件展示
粗粒度状态。

## Artifact

Agent 只有以下目录会暴露为 Artifact：

```text
result/
generated/
screenshots/
```

### ListArtifacts

```lua
Agent.ListArtifacts(sessionId, function(items, err)
    for _, item in ipairs(items or {}) do
        print(item.path, item.size)
    end
end)
```

结果项：

```lua
{
    path = "result/manifest.json",
    size = 1234,
}
```

### ReadArtifact

```lua
Agent.ReadArtifact(
    sessionId,
    "result/manifest.json",
    function(bytes, err)
        -- bytes 始终是 Lua binary string；文本文件也一样
    end
)
```

路径必须位于当前 Session 的 `result/`、`generated/` 或 `screenshots/`。

### ExportArtifacts

`ExportArtifacts` 组合 `ReadArtifact` 和 `Plugin.Files.Write*`，将选定结果显式导入正在
编辑的项目：

```lua
Agent.ExportArtifacts(sessionId, {
    requestId = "export-scene-123",
    items = {
        {
            source = "result/scene.json",
            target = "docs/my-plugin/scene.json",
            mode = "text",
        },
        {
            source = "generated/preview.png",
            target = "assets/generated/preview.png",
            mode = "binary",
            mime = "image/png",
        },
    },
}, function(result, err)
end)
```

`source` 只能来自 Artifact 目录，`target` 必须符合 `Plugin.Files` 路径规则。
`mode` 是 `"text"` 或 `"binary"`，省略时按 binary。成功结果：

```lua
{
    requestId = "export-scene-123",
    exported = {
        {
            source = "result/scene.json",
            target = "docs/my-plugin/scene.json",
            result = { written = 123 },
        },
    },
}
```

当前实现整文件读入内存并进行 Base64 转换，不适合无限大的 Artifact。

## DiscardSession

```lua
Agent.DiscardSession(sessionId, function(result, err)
end)
```

成功后删除整个 Session 目录：

```lua
{
    sessionId = "session-...",
    discarded = true,
}
```

这是破坏性操作。确认日志、截图和结果不再需要，并且 Artifact 已成功导入项目后再调用。

## Initialize

```lua
Agent.Initialize(options)
```

业务插件通常不调用。Backend 由 Runtime 宿主在加载业务 Lua 前注入；该入口主要用于测试。
插件不能通过它选择本地绝对路径、CLI、API Key 或网络地址。

## 错误码

| code | 含义 |
|---|---|
| `PLUGIN_ENVIRONMENT_REQUIRED` | 当前不是 Plugin 环境 |
| `AGENT_SDK_UNAVAILABLE` | Agent SDK或 Bridge 未加载 |
| `INVALID_REQUEST` | 请求字段或 Prompt 无效 |
| `INVALID_PATH` | reference / Artifact 路径非法 |
| `REQUEST_ID_COLLISION` | Agent requestId 与内部文件请求冲突 |
| `SESSION_NOT_FOUND` | Session 不存在 |
| `SESSION_BUSY` | 同一 Session 已有活动 Turn |
| `SESSION_LIMIT_REACHED` | 达到宿主 Session 上限 |
| `PROVIDER_UNAVAILABLE` | Provider 未配置或 CLI 不可启动 |
| `MODEL_NOT_ALLOWED` | 模型不在允许列表 |
| `CAPABILITY_UNSUPPORTED` | Provider 不满足 requirements |
| `WORKSPACE_INIT_FAILED` | Agent 工作区初始化失败 |
| `WORKSPACE_WRITE_FAILED` | 输入或日志无法写入 |
| `PROCESS_START_FAILED` | Provider 进程启动失败 |
| `PROVIDER_TIMEOUT` | Provider 超过 Turn wall time |
| `PROVIDER_FAILED` | Provider 非零退出 |
| `CANCELLED` | 请求或 Turn 已取消 |
| `CLEANUP_FAILED` | Session 或 SDK 清理失败 |
| `INTERNAL_ERROR` | Agent SDK 内部错误 |
