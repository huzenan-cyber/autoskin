# Editor 窗口

示例：[BatchRenameWindow.lua](../examples/BatchRenameWindow.lua)。

```lua
local window = Editor.Window("Batch Rename", "tools.batch_rename", {
    width = 480,
    height = 320,
})
window.prefix = "Enemy_"

function window:OnGUI()
    self.prefix = EditorGUILayout.TextField("Prefix", self.prefix or "")
    GUILayout.Label(#Editor.Selection.GetNodes() .. " selected")
    if GUILayout.Button("Apply") then
        Editor.Undo.Begin("Batch Rename")
        for _, node in ipairs(Editor.Selection.GetNodes()) do
            Editor.Undo.Record(node)
            node:SetName(self.prefix .. node:GetName())
        end
        Editor.Undo.End()
    end
end

Editor.MenuItem("Tools/Batch Rename Window", function()
    window:Show()
end)
```

改 lua 并保存后窗口应按 `id` 重开，用的是新脚本。`prefix` 会回到代码里的初值。

需要非模态置顶工具窗时调用 `window:ShowUtility()`；不要用额外的 ImGui flags 模拟置顶。焦点生命周期使用
`OnFocus` / `OnLostFocus`，主动聚焦使用 `window:Focus()`。完整示例见
[UtilityWindow.lua](../examples/UtilityWindow.lua)。
