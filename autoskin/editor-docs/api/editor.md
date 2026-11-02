# Editor

## MenuItem

```lua
Editor.MenuItem(path, callback, options?)
```

| 参数 | 说明 |
|---|---|
| `path` | `/` 分段。`Tools/Foo` 挂到 Tools。其它第一段成为新顶栏。禁止 `File`/`Edit`/`Help` |
| `callback` | 点击或 MCP 调用，无参数 |
| `options.description` | MCP `tools/list` 说明 |
| `options.validate` | 返回 `false` 时菜单灰显，MCP 返回 `EDITOR_SCRIPT_VALIDATE_FAILED` |
| `options.shortcut` | 仅展示 |
| `options.mcp` | 默认 `true` |
| `options.id` | MCP 后缀，默认由 path 生成 |

MCP 名：`editor_script.<id>`。例如 `Tools/Batch Rename` → `editor_script.tools_batch_rename`。

## Window

```lua
local w = Editor.Window(title, id?, options?)
w:Show()
w:ShowUtility()
w:Focus() -> bool
w:Close()
w:IsOpen()
w:HasFocus()
function w:OnGUI() end
function w:OnEnable() end
function w:OnDisable() end
function w:OnFocus() end
function w:OnLostFocus() end
```

`id` 默认等于 `title`，热加载后用来恢复开关。

- `Show()` 是普通 EditorWindow；`ShowUtility()` 对齐 Unity 同名语义，在 UrhoXEditor 主窗口内部保持在普通编辑器窗口之上。
- `Show()` / `ShowUtility()` 可切换同一个窗口的显示模式，已打开时不会重复触发 `OnEnable`。
- `Focus()` 只对已显示窗口生效，并在下一帧请求焦点；`HasFocus()` 查询当前帧焦点。
- `OnFocus` / `OnLostFocus` 只在焦点边沿触发。用户关闭窗口时，顺序为 `OnLostFocus`（若原来有焦点）→ `OnDisable`。
- Utility 是非模态窗口，不阻止场景、Inspector 或其它窗口交互；系统弹窗和 Modal 仍可显示在它上面。

`options.width` / `options.height` 设置窗口第一次出现时的逻辑像素尺寸；用户仍可自由缩放窗口。
不需要单独指定 `id` 时，也可以把 options 放在第二个参数：

```lua
local w = Editor.Window("Asset Tools", "tools.asset_tools", {
    width = 900,
    height = 700,
})

local quickWindow = Editor.Window("Quick Tool", { width = 480, height = 320 })
```

## Scene

```lua
Editor.Scene.Get()              -- Scene | nil
Editor.Scene.GetGeneration()    -- string
Editor.Scene.GetRevision()      -- number
Editor.Scene.FindNode(id)       -- Node | nil
Editor.Scene.FindNodeByName(name)
```

Prefab 编辑模式下操作的是 Prefab 文档。

## AssetDatabase

加载、创建、复制和导入 Project / Package 资产见 [AssetDatabase](asset.md)。

## AssetPreview / CreateEditor

静态缩略图和材质、模型、纹理、Prefab 的交互式预览见 [Asset Preview](asset-preview.md)。

## CustomEditor / ContextMenu

见 [Inspector](inspector.md)。

## SceneView / Handles

目标相关绘制使用 `CustomEditor.OnSceneGUI`，全局绘制订阅 `SceneView.duringSceneGui`。详见
[Handles](handles.md)。

## 日志与对话框

```lua
Editor.Log(message)
Editor.Warn(message)
Editor.Error(message)
Editor.Dialog.Info(title, message)
Editor.Dialog.Confirm(title, message) -> bool
```

日志带 `[EditorScript]` 前缀，进编辑器 Console。MCP 调用时 `Confirm` 自动返回
`true`，结果里带 `dialog_auto_confirmed`。
