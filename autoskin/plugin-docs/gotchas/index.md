# Plugin 常见问题

这里只记录当前实现中已经确认过的 Plugin 陷阱。

## 1. 点击了 Maker 而不是 Maker-Plugin

现象：

```text
PLUGIN_ENVIRONMENT_REQUIRED
```

原因：普通 `Maker` 启动的是 `runtime` 环境。使用 UrhoXEditor Debug Toolbar 的
`Maker-Plugin`。

## 2. 用 GetLuaEnvironment 判断 Plugin

`GetLuaEnvironment()` 表示 Lua VM 生命周期类型，PluginViewer 仍可能是 Runtime Lua VM。
使用：

```lua
Environment.IsPlugin()
```

## 3. 混淆三个根目录

```text
插件包目录              != projectRoot
projectRoot             != Agent Session
Agent Session           != 插件包目录
```

`Plugin.Files` 操作正在编辑的项目。Agent 在独立 Session 工作。生成结果必须通过 Artifact
显式导回项目。

## 4. 给 Files 传绝对路径

错误：

```lua
Files.ReadBinary("C:/tmp/demo.jpg", callback)
```

正确：

```lua
Files.ReadBinary("assets/demo.jpg", callback)
```

路径以项目根为基准，只能使用 `assets/`、`docs/` 虚拟路径。

## 5. 把异步接口当同步接口

`Files.Read*`、`Files.Write*` 和所有 Agent 操作都在后续 Tick 回调。方法返回值是
`RequestHandle`，不是结果。

## 6. 忘记 requestId

`CreateSession`、`SendPrompt` 和 `ExportArtifacts` 必须提供非空 `requestId`，否则返回
`INVALID_REQUEST`。

## 7. 在 SendPrompt 中传图片

当前 `SendPrompt` 只提取 `prompt` 或 `messages[].type == "text"`。图片、Markdown 和其他
参考文件应放在 `CreateSession.references`，Prompt 引用 `references/...`。

## 8. 把 references.path 当成项目路径

```lua
{
    path = "references/demo.jpg",
    data = imageBytes,
}
```

该路径相对于 Agent Session，不相对于 `projectRoot`。通常先用
`Files.ReadBinary("assets/demo.jpg")` 读取项目图片，再把字节放进 reference。

## 9. 把 output 当稳定文本

`SendPrompt` 的 `result.output` 是 Provider CLI 原始 stdout/stderr。Codex 常见格式是
JSONL，其他 Provider 格式不同。业务流程使用 callback、事件和 Artifact 判断结果，不解析
Provider 的自然语言作为稳定协议。

## 10. 找不到对话日志

本地日志位于：

```text
<sandboxRoot>/<sessionId>/logs/turn-1.log
```

不是项目 `logs/`，也不能通过 `Plugin.Files` 读取。只有 `result/`、`generated/`、
`screenshots/` 对插件暴露为 Artifact。

## 11. Agent 完成但项目里没有新资产

Agent 只写 Session，不会自动写正式项目。完成后调用：

```lua
Agent.ListArtifacts(...)
Agent.ExportArtifacts(...)
```

或使用 `ReadArtifact + Files.WriteText/WriteBinary`。

## 12. Prompt 成功但业务结果缺文件

Provider 退出码为 0 不等于业务输出完整。导入前检查必需 Artifact，并按插件自己的 Schema
校验内容。

## 13. WORKSPACE_INIT_FAILED

依次检查：

1. Python 路径及 `-X utf8` 参数。
2. `<EditorBin>/tools/taptap_code/create_agent_workspace.py`。
3. CDN 下载是否成功。
4. ai-dev-kit 是否包含 `.installer/local-skill-filter.json`。
5. skill 是否安装到 `.claude/.codex/.cursor/.gemini`。
6. `<EditorBin>/Res/Shaders` 是否存在。

详细错误会附在 callback 的 `message` 中。

## 14. Provider 返回乱码

工作区 initializer 使用：

```text
python -X utf8 create_agent_workspace.py <sessionDir>
```

Provider 和 Runtime 日志仍取决于进程实际编码。业务层不要把 Provider 原始输出当结构化
结果；正式结果写 UTF-8 文件并通过 Artifact 读取。

## 15. 关闭 Runtime 后担心 Agent 残留

Windows Provider 和其启动的 Runtime 位于 Job Object 中，正常取消、超时和 Shutdown 会
回收进程树。Session 目录和日志默认保留，目录仍存在不表示 Agent 进程仍在运行。

Runtime 崩溃或 Task Manager 强杀属于需要重点验收的边界；业务不能依赖 Lua 退出回调完成
清理，也不要把未导入的 Session 半成品当正式资产。
