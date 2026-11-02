-- E4 smoke: Custom Inspector on Light + Hierarchy / Resource Browser context menus.
-- Copy into the game project's Editor/ folder.

Editor.CustomEditor("Light", {
    OnInspectorGUI = function(self)
        local light = self.target
        GUILayout.Label("Night light helper")
        if GUILayout.Button("Set Night Light") then
            Editor.Undo.Begin("Night Light")
            Editor.Undo.Record(light)
            light:SetBrightness(0.25)
            Editor.Undo.End()
            Editor.Log("Set Light brightness to 0.25")
        end
    end,
})

Editor.ContextMenu("hierarchy", "Tools/Log Selected Nodes", function(nodes)
    Editor.Log("Hierarchy context: " .. tostring(nodes and #nodes or 0) .. " node(s)")
    if nodes then
        for i = 1, #nodes do
            if nodes[i] then
                Editor.Log("  " .. (nodes[i]:GetName() or "") .. " #" .. tostring(nodes[i]:GetID()))
            end
        end
    end
end, {
    description = "Log Hierarchy selection from the context menu",
})

Editor.ContextMenu("project", "Tools/Log Resource Path", function(paths)
    local path = paths and paths[1] or ""
    Editor.Log("Resource context: " .. path)
end, {
    description = "Log the right-clicked resource path",
})
