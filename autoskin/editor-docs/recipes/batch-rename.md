# 批量重命名

把 [BatchRename.lua](../examples/BatchRename.lua) 放到工程任意 `Editor/` 目录。

```lua
Editor.MenuItem("Tools/Batch Rename", function()
    local nodes = Editor.Selection.GetNodes()
    if #nodes == 0 then
        Editor.Log("No nodes selected")
        return
    end

    Editor.Undo.Begin("Batch Rename")
    for _, node in ipairs(nodes) do
        Editor.Undo.Record(node)
        node:SetName("Enemy_" .. node:GetName())
    end
    Editor.Undo.End()
end, {
    description = "Add a prefix to selected node names",
    validate = function()
        return #Editor.Selection.GetNodes() > 0
    end,
})
```

验收：选 3 个节点 → 菜单或 `editor_script.tools_batch_rename` → 名字带前缀 →
Ctrl+Z / MCP `undo` 恢复。
