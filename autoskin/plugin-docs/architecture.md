# Plugin 运行架构

## 1. 目标

Plugin 的业务代码只写一套 Lua：

```text
本地开发：UrhoXEditor -> Maker-Plugin -> UrhoXRuntime -> Plugin Lua
发布运行：Plugin Host -> engine-viewer (WASM) -> Plugin Lua
```

两种环境都应提供相同的：

- UrhoX 场景、渲染、输入和 UI API
- `Plugin.Environment`
- `Plugin.Files`
- `Plugin.Agent`

Lua 不检测 `local` / `web`，也不选择传输协议。

## 2. 界面和场景都在引擎内

Plugin 的主界面、场景视图、预览和交互都可以用 UrhoX Lua 完成。业务代码继续使用：

- `urhox-libs/UI`
- `Scene`、`Node`、`Camera`、`Viewport`
- 输入事件和引擎事件
- 材质、模型、纹理和程序化几何

Plugin 不需要为 Agent 再建立 Web UI。发布宿主只负责承载 `engine-viewer`、提供权限和注入
Backend。

## 3. 宿主边界

```text
Plugin Lua
    |
    +-- UrhoX API
    |
    +-- Plugin.Environment
    |
    +-- Plugin.Files ----> Files Backend ----> 正在编辑的项目
    |
    +-- Plugin.Agent ----> Agent Backend ----> Agent Session
```

业务 Lua 只调用 `urhox-libs/Plugin/*`。以下符号属于宿主内部实现，不是公开 API：

```text
__urhox_plugin_agent_native_submit
__urhox_plugin_agent_native_cancel
__urhox_plugin_files_native_op
__urhox_plugin_agent_backend
__urhox_plugin_files_backend
```

插件不能覆盖或直接调用这些全局符号。

## 4. 本地链路

当前 Windows 本地链路：

```text
UrhoXEditor Maker-Plugin
    |
    +-- 生成一次性配置
    +-- -application_environment=plugin
    +-- -plugin_agent_config=<path>
    v
UrhoXRuntime PluginAgentBridge
    |
    +-- Local Files Backend -> projectRoot/assets、projectRoot/docs
    +-- ResourceCache -------> projectRoot/assets（资源名相对 assets/）
    |
    +-- AgentSDK.dll -> Provider CLI
                         |
                         +-- cwd = sandboxRoot/session-<id>
                         +-- Agent 启动 Session 内 UrhoXRuntime
                         +-- Agent 截图并视觉迭代
```

Runtime Bridge 每帧 Poll Agent SDK，并在 Lua 主线程的后续 Tick 投递 callback 和事件。

## 5. 发布链路

发布后由 Web Plugin Host 加载 `engine-viewer`。Viewer 负责运行同一份 Plugin Lua，并将应用
环境标记为 `"plugin"`。

文件和 Agent 的发布态实现属于宿主 Backend：

```text
Plugin.Files -> Web Files Backend -> REMOTE 云端项目 / LOCAL 本地挂载项目
ResourceCache --------------------> LOCAL 本地挂载项目的 assets/
Plugin.Agent -> Remote Agent Backend -> 远端 Agent 服务
```

Web Files Backend 需要把宿主 Promise、Blob/ArrayBuffer 和错误映射为 Lua 的 callback、
binary string 和统一错误结构，并负责 `SetMode`、`SyncToRemote`、`SyncToLocal` 的实际
同步。宿主完成本地目录挂载后，还需要把挂载项目的 `assets/` 目录注册进 Runtime
`ResourceCache`。Remote Agent Backend 需要把 Session、Turn、Event 和
Artifact 映射为同一 Lua 契约。

业务 Lua 不直接调用浏览器侧 `plugin.fs`，也不重写 Native file operation；这些都是宿主
适配层的职责。

当前代码库尚未实现 Web Files Backend 和 Remote Agent Backend。因此：

- `engine-viewer` 中的普通 UrhoX Lua 场景和 UI 可以按 Viewer 能力运行。
- Web 中调用 `Plugin.Files` / `Plugin.Agent` 仍可能返回 `BACKEND_UNAVAILABLE`。
- Files 同步模式 API 当前只有占位实现，不执行本地与云端传输。
- Plugin 业务 API 不为当前缺失能力增加 Web 特例。

## 6. 目录所有权

| 目录 | 所有者 | Plugin Lua 访问方式 |
|---|---|---|
| 插件包目录 | Plugin 发布系统 | 不通过 `Plugin.Files` 访问 |
| 正在编辑的项目 | Plugin Host | `Plugin.Files` |
| Agent Session | Agent Backend | `Plugin.Agent` 与 Artifact API |

Agent SDK不接收 `projectRoot`。本地 `projectRoot` 只交给 Local Files Backend。这样 Agent
Session 与正式项目天然分离，只有经过业务校验的 Artifact 才会导入项目。

## 7. 兼容规则

为了让同一 Lua 将来直接运行在 Web：

1. 只使用虚拟相对路径。
2. 所有文件和 Agent 操作都按异步 callback 编写。
3. 图片和二进制使用 Lua string，不自行 Base64。
4. 只依赖稳定错误 `code`、事件 `type` 和 Artifact 路径。
5. 不读取 Agent Session 绝对路径。
6. 不依赖 Provider CLI 输出格式。
7. 不从 Lua 选择 HTTP、Entrance 或 Native C ABI。
