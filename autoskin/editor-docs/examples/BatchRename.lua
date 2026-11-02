-- Example: add a prefix to selected node names. Undoable.
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
