# UrhoX Plugin Lua 开发文档

本文档面向使用 UrhoX 引擎界面开发插件的工程师和 Coding Agent。插件的场景、交互和 UI
仍然使用普通 UrhoX Lua；Plugin API 只补充宿主环境判断、项目文件访问和 Agent 调用能力。

当前版本只实现 Windows 本地 `Maker-Plugin` 链路。Web/WASM 远端 Agent 与文件 Backend
尚未提供，插件业务 Lua 应只依赖本文档中的异步 API，不能依赖本地绝对路径或 Agent SDK
内部实现。

---

## 首先阅读

1. [Plugin 运行架构](architecture.md)
2. [Plugin Lua 脚本指南](plugin-scripting-guide.md)
3. [API 索引](api/index.md)
4. 涉及大模型生成时阅读 [Agent 场景生成闭环](recipes/agent-scene-generation.md)

插件仍使用完整的引擎 Lua API。创建场景、引擎 UI、材质、渲染和截图验证等内容继续查阅
[engine-docs](../engine-docs/index.md)。

---

## 文档结构

```text
plugin-docs/
├─ index.md
├─ architecture.md
├─ plugin-scripting-guide.md
├─ api/
│  ├─ index.md
│  ├─ environment.md
│  ├─ files.md
│  └─ agent.md
├─ recipes/
│  └─ agent-scene-generation.md
└─ gotchas/
   └─ index.md
```

## 核心概念

| 概念 | 含义 |
|---|---|
| Plugin 环境 | `GetApplicationEnvironment() == "plugin"` 的 UrhoXRuntime |
| 插件包目录 | 发布插件本身的目录；不通过 `Plugin.Files` 暴露 |
| 项目根目录 | 插件正在编辑的目标项目；本地配置名为 `projectRoot` |
| Agent Session | Agent SDK 在 `sandboxRoot` 下创建的独立工作区 |
| Artifact | Agent 明确放入 `result/`、`generated/`、`screenshots/` 的可读取结果 |

最重要的边界：

```text
插件 Lua
├─ 普通 UrhoX API ──────────> 当前插件界面和预览场景
├─ Plugin.Files ────────────> 正在编辑的项目 assets/、docs/
└─ Plugin.Agent ────────────> 独立 Agent Session
                                  └─ Artifact 显式导回项目
```

`Plugin.Files` 不读写插件包目录，Agent 也不直接在正式项目目录工作。

---

## 快速导航

| 需求 | 文档 |
|---|---|
| 判断是否在 Plugin 环境 | [Environment API](api/environment.md) |
| 读取项目图片或文档 | [Files API](api/files.md) |
| 调用 Claude、Codex 或 Gemini | [Agent API](api/agent.md) |
| 把图片传给 Agent | [Agent API：references](api/agent.md#createsession) |
| 读取 Agent 输出 | [Agent API：SendPrompt](api/agent.md#sendprompt) |
| 导入 Agent 生成文件 | [Agent API：Artifact](api/agent.md#artifact) |
| 让 Agent 启动 Runtime 并截图迭代 | [Agent 场景生成闭环](recipes/agent-scene-generation.md) |
| 排查常见错误 | [Plugin 常见问题](gotchas/index.md) |
