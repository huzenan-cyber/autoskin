# Editor Script 运行架构

## 1. 目标

用和玩法相同的 Lua，在 UrhoXEditor 里加菜单、窗口、批处理。对标 Unity Editor
脚本，不对标 `plugins/` iframe。

```text
<project>/**/Editor/**/*.lua
        │
        v
 UrhoXEditor EditorScriptHost
        │
        +-- 独立 LuaScript (LuaEnvironment::EditorScript = 4)
        +-- Editor / EditorGUI 只注入这一条 state
        +-- 菜单 → Tools / 自定义顶栏
        +-- 窗口 → 每帧 OnGUI
        +-- 视口 → 每帧 OnSceneGUI / Handles（可抢占拾取与 Gizmo）
        +-- 资产 → AssetDatabase（Project 可写、Package 只读）、Editor.Animation（.ani）
        +-- 材质烘焙 → Editor.MaterialBaking（GPU UV 求值 → Image → AssetDatabase）
        +-- Inspector / Scene GUI / 右键 → CustomEditor、SceneView、ContextMenu
        +-- 写场景 → EditorCommandService Undo
        +-- 菜单默认登记 MCP editor_script.*
```

## 2. 发现规则

从当前工程根扫描。相对路径里**至少有一段恰好为 `Editor`** 的 `.lua` 都会加载。

合法：`Editor/Foo.lua`、`scripts/Editor/Foo.lua`、`scripts/Combat/Editor/Bar.lua`。

`Editor` 是工程内保留目录名。玩法不要把运行时文件放进去。
`EDITOR_SCRIPT_NOT_IN_RUNTIME` 目前只在 `URHOX_EDITOR` 构建里拦截玩法 `require`；
玩家 Runtime 先不拦，避免存量工程已有 `Editor/` 目录被打挂。发布扫描跳过整棵
`Editor/` 树会后补。

跳过：隐藏目录、`node_modules`、`dist`、`build`、`urhox-libs`、`engine-docs`、
`examples` 等。见引擎设计文档。

## 3. 不要和这些东西混用

| 东西 | 区别 |
|---|---|
| `LuaEnvironment::Editor`（值为 2） | 场景上玩法脚本的检查 VM，不跑 Start/Stop |
| `plugins/` / `@tapcode/plugin-sdk` | Maker Web iframe |
| `Plugin.Agent` / `Maker-Plugin` | 插件运行时调大模型 |

`GetLuaEnvironment()` 在编辑器脚本里是 `4`。不要用 `GetApplicationEnvironment()`
判断自己是不是编辑器脚本。

## 4. 一个工程一条 state

所有 `Editor/` 脚本共享一个 Lua state。单文件 `pcall` 加载，一个文件失败不影响其它文件。
保存后约 200ms 热加载：重建 state，按窗口 `id` 重开，窗口字段不自动恢复。
