# Editor Script API 索引

全局表，只存在于 Editor Script state。不要 `require` 它们。
Canonical EmmyLua 声明见 [`editor-api.lua`](editor-api.lua)。

| 表 | 用途 |
|---|---|
| [`Editor`](editor.md) | 菜单、窗口、日志、对话框、Scene |
| [`Editor.Selection`](selection.md) | 当前选中节点 / 组件 |
| [`Editor.Undo`](undo.md) | 改场景的 Undo 组 |
| [`Editor.Handles`](handles.md) / `Editor.SceneView` | 视口辅助线、拖点、拾取 |
| [`EditorGUILayout` / `GUILayout` / `EditorGUI`](editor-gui.md) | 编辑字段、普通控件、UI 状态 Scope |
| [`AssetDatabase`](asset.md) | Project / Package 资产加载、工程内创建与复制 |
| [`AssetPreview` / `Editor.CreateEditor`](asset-preview.md) | 静态缩略图与材质、模型、纹理、Prefab 交互式预览 |
| [`Editor.Animation`](animation.md) | 加载 / 概况 / 采样 / 裁剪 / 合并 / 写出 `.ani` |
| [`Editor.MaterialBaking`](material-baking.md) | GPU 材质 UV 烘焙、CPU 可采样的 Image 和 UV 映射 |
| [`Editor.CustomEditor`](inspector.md) / `ContextMenu` | Inspector / Scene GUI、Hierarchy / 资源右键 |

```lua
Editor.MenuItem("Tools/Foo", function()
end)

local nodes = Editor.Selection.GetNodes()
Editor.Undo.Begin("Foo")
-- ...
Editor.Undo.End()
```
