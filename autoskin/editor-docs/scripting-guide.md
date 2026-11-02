# Editor Script 指南

先读 [架构](architecture.md)。

## 1. 文件放哪

工程内任意 `Editor/` 目录，普通 Lua 文件，不是 `ScriptObject`。顶层调用
`Editor.MenuItem` / `Editor.Window` 完成注册。

`Editor/` 下可以继续嵌套任意业务目录；宿主会递归加载全部 `.lua`。启用 Package 若包含 Editor
Script，需要在 Settings → Packages 显式打开 **Run Editor scripts** 并重启。Package 脚本不参与热加载，
Project 脚本仍由现有 watcher 自动重载。

```lua
-- <project>/Editor/HelloMenu.lua
Editor.MenuItem("Tools/Hello Editor Script", function()
    Editor.Log("Hello from Editor Script")
end)
```

打开工程或 **Tools → Reload Editor Scripts** 后生效。完整可运行脚本在
[examples/](examples/)，复制进工程 `Editor/` 即可。

## 2. 改场景必须 Undo

```lua
Editor.Undo.Begin("Batch Rename")
for _, node in ipairs(Editor.Selection.GetNodes()) do
    Editor.Undo.Record(node)
    node:SetName("Enemy_" .. node:GetName())
end
Editor.Undo.End()
```

可以直接调 `Node:SetName` / `SetPosition`。菜单回调里如果忘了 Undo，宿主会尽量补隐式组。
加载顶层不要改场景。PIE 播放中写操作返回 `EDITOR_SCRIPT_NOT_IN_EDIT_MODE`。

## 3. 窗口

`EditorGUILayout`、`GUILayout` 和 `EditorGUI` scope 只能在 `OnGUI` 里调用。

```lua
local window = Editor.Window("Batch Rename")
window.prefix = "Enemy_"

function window:OnGUI()
    self.prefix = EditorGUILayout.TextField("Prefix", self.prefix or "")
    if GUILayout.Button("Apply") then
        -- Undo + 改节点
    end
end

Editor.MenuItem("Tools/Batch Rename Window", function()
    window:Show()
end)
```

需要保持在普通编辑器窗口之上的非模态工具窗时使用 `window:ShowUtility()`。窗口预览资产时，静态列表缩略图使用
[`AssetPreview`](api/asset-preview.md)，需要旋转、缩放或纹理通道检查时使用 `Editor.CreateEditor(asset)`。

热加载会按窗口 `id` 调用 `Serialize` / `Restore`，只支持一层 string / number / bool。资产落盘使用
[`AssetDatabase`](api/asset.md)，路径始终是工程相对 Resource path。

```lua
function window:Serialize()
    return { prefix = self.prefix }
end

function window:Restore(state)
    self.prefix = state.prefix
end
```

## 4. require

模块名用相对工程根、`.` 代 `/`：

```lua
local names = require("scripts.Editor.util.names")
```

`require` 继续走 LuaScript / ResourceCache：Project 和已挂载 Package 的 Lua 模块都能读取，且同名资源
沿用 ResourceCache 的 Project-first 优先级。不要按文件名在所有 `Editor/` 里搜索。

## 5. 视口 Handles

目标无关的视口工具订阅 `Editor.SceneView.duringSceneGui`。多个 listener 按订阅顺序运行。

```lua
local function DuringSceneGUI(sceneView)
    local node = Editor.Selection.GetActiveNode()
    if not node then
        return
    end
    local pos = node:GetWorldPosition()
    local newPos, changed = Editor.Handles.PositionHandle("move", pos, node:GetWorldRotation())
    if changed then
        Editor.Undo.Record(node)
        node:SetWorldPosition(newPos)
    end
end

Editor.SceneView.duringSceneGui:AddListener(DuringSceneGUI)
```

目标相关的 Handle 改用 `Editor.CustomEditor(typeName, { OnSceneGUI = ... })`。拖动中宿主会打开对应
Move/Rotate/Scale Undo 组，写回节点前仍要 `Record`。详见 [Handles](api/handles.md)。

## 6. MCP 自验

`Editor.MenuItem` 默认登记为 `editor_script.<id>`。写完后：

1. `get_editor_state` 看 `editor_scripts.loaded` / `last_error`
2. 选节点
3. `tools/call` 对应 `editor_script.*`
4. `list_scene_tree` 断言
5. `undo` 再断言恢复

`options.mcp = false` 可关闭登记。

## 7. 禁止

- 往 `File` / `Edit` / `Help` 挂菜单
- `Plugin.Agent` / `Plugin.Files`
- 在 Runtime 或玩法脚本里 `require` `Editor/`
- 把 `Node` userdata 存过场景重载或热加载（存 `node:GetID()`）
