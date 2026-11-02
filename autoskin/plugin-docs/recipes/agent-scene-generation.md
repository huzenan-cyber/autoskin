# Agent 场景生成闭环

场景生成的视觉迭代由 Agent 在自己的 Session 内完成。Plugin Lua 负责准备输入、发起任务、
展示进度和显式导入结果，不负责拉起截图 Runtime。

## 1. 正确的数据流

```text
项目 assets/、docs/
    │ Plugin.Files.Read*
    ▼
Agent.CreateSession(input + references)
    ▼
Agent Session
    ├─ Agent 读取 engine-docs / examples / schemas / templates / urhox-libs
    ├─ Agent 生成 scripts / assets
    ├─ Agent 用 run-lua-validate 校验
    ├─ Agent 启动 UrhoXRuntime 截图
    ├─ Agent 读取 screenshots/*.png
    ├─ Agent 修改并再次截图
    └─ Agent 写 result/、generated/、screenshots/
    │
    ▼
Agent.ListArtifacts / ExportArtifacts
    │
    ▼
项目 assets/、docs/
```

截图不经过 Plugin Lua、`Plugin.Files` 或 Viewer。Agent 使用工作目录内的 Runtime 和视觉
能力直接完成“运行 -> 截图 -> 看图 -> 修改”的多轮闭环。

## 2. 读取参考文件

```lua
local Files = require "urhox-libs/Plugin/Files"

Files.ReadBinary("assets/demo.jpg", function(imageBytes, err)
    if err then
        return ShowError(err)
    end
    CreateGenerationSession(imageBytes)
end)
```

`Files.ReadBinary` 的相对路径以正在编辑的项目为根，不是插件包目录。

## 3. 创建带参考图的 Session

```lua
local Agent = require "urhox-libs/Plugin/Agent"

function CreateGenerationSession(imageBytes)
    Agent.CreateSession({
        requestId = NewRequestId("create-scene"),
        profile = "scene-asset-generation",
        input = {
            goal = "生成与参考图一致的可运行 UrhoX 场景",
            output = {
                manifest = "result/manifest.json",
                prefab = "result/prefab.xml",
            },
        },
        references = {
            {
                path = "references/demo.jpg",
                mime = "image/jpeg",
                data = imageBytes,
            },
        },
        requirements = {
            vision = true,
            structuredOutput = true,
        },
    }, function(session, err)
        if err then
            return ShowError(err)
        end
        RunGeneration(session.sessionId)
    end)
end
```

业务输入放在 `input`，文件放在 `references`。不要把本机图片绝对路径写进 Prompt。

## 4. Prompt 明确验收与输出目录

```lua
function RunGeneration(sessionId)
    Agent.SendPrompt(sessionId, {
        requestId = NewRequestId("generate-scene"),
        prompt = [[
读取 references/demo.jpg，生成视觉风格和构图相近的 UrhoX 场景。

要求：
1. 先阅读 engine-docs、相关 examples 和已安装的 run-lua-validate skill。
2. 生成可运行的 Lua 场景和所需资产。
3. 先执行 validate，再启动 UrhoXRuntime 截图。
4. 用视觉能力读取截图，至少完成三轮“截图 -> 对比 -> 修改”。
5. 最终预制体写到 result/prefab.xml。
6. 最终清单写到 result/manifest.json。
7. 需要导出的其他资产写到 generated/。
8. 最终截图保留在 screenshots/。
]],
    }, function(result, err)
        if err then
            return ShowError(err)
        end
        print(result.output)
        ImportGenerationResult(sessionId)
    end)
end
```

SDK是通用 Agent 调用器，不知道某个插件的题材、房间或资产 Schema。业务插件必须通过
`input`、`references`、Prompt 和项目内 Schema 说明输出契约。

## 5. 展示进度

```lua
local unsubscribe = Agent.OnEvent(function(event)
    if event.type == "turn.started" then
        SetStatus("Agent 正在工作")
    elseif event.type == "artifact.created" then
        SetStatus("生成文件：" .. tostring(event.payload.path))
    elseif event.type == "turn.completed" then
        SetStatus("Agent 已完成")
    elseif event.type == "turn.cancelled" then
        SetStatus("已取消")
    elseif event.type == "error" then
        SetStatus("失败：" .. tostring(event.payload.code))
    end
end)
```

当前没有 Runtime 每次截图的专用事件。不要在 UI 中伪造精确迭代轮数；需要可见进度时，可
要求 Agent 将阶段结果放入 `screenshots/` 或 `generated/`，由 `artifact.created` 反馈。

## 6. 校验和导入结果

先列出 Artifact，确认必需文件存在，再导入：

```lua
function ImportGenerationResult(sessionId)
    Agent.ListArtifacts(sessionId, function(items, listErr)
        if listErr then
            return ShowError(listErr)
        end

        local foundManifest = false
        local foundPrefab = false
        for _, item in ipairs(items) do
            foundManifest = foundManifest or item.path == "result/manifest.json"
            foundPrefab = foundPrefab or item.path == "result/prefab.xml"
        end

        if not foundManifest or not foundPrefab then
            return ShowError({
                code = "RESULT_INCOMPLETE",
                message = "Agent result is missing manifest or prefab",
            })
        end

        Agent.ExportArtifacts(sessionId, {
            requestId = NewRequestId("export-scene"),
            items = {
                {
                    source = "result/manifest.json",
                    target = "docs/generated-scene/manifest.json",
                    mode = "text",
                },
                {
                    source = "result/prefab.xml",
                    target = "assets/generated-scene/prefab.xml",
                    mode = "text",
                },
            },
        }, function(result, exportErr)
            if exportErr then
                return ShowError(exportErr)
            end
            SetStatus("生成结果已导入项目")
        end)
    end)
end
```

导入前应按插件自己的 Schema 校验 `manifest.json` 和业务描述文件。Agent callback 成功只
代表 Provider 正常退出，不代表业务文件完整。

## 7. 失败、重试和清理

- 表单草稿先保存，再创建 Session。
- Agent 失败时不要覆盖当前已生效资产。
- 同一业务请求因超时或网络错误重试时复用 `requestId`。
- 要求 Agent继续修改时，对同一 Session 发新 Turn，并使用新 `requestId`。
- 一个 Session 内不要并发提交多个 Prompt。
- 取消时保存 `sessionId` 和最后 `sequence`，需要恢复可调用 `Resume`。
- 完成导入和业务校验前不要 `DiscardSession`。

## 8. 完整最小状态

```lua
local generation = {
    running = false,
    sessionId = nil,
    turnId = nil,
    lastSequence = 0,
    requestHandle = nil,
    unsubscribe = nil,
}
```

把业务草稿、正式生效结果和 Agent Session 状态分开存储。这样 Agent 失败、Runtime 关闭或
用户取消时，都不会破坏当前项目。
