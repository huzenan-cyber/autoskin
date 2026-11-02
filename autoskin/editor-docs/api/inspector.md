# Custom Editor 与右键

## CustomEditor

```lua
Editor.CustomEditor("Light", {
    OnInspectorGUI = function(self)
        local light = self.target
        GUILayout.Label("Night light helper")
        if GUILayout.Button("Set Night Light") then
            Editor.Undo.Record(light)
            light:SetBrightness(0.25)
        end
    end,

    OnSceneGUI = function(self)
        local light = self.target
        Editor.Handles.DrawSphere(light:GetNode():GetWorldPosition(), 0.2, Color.YELLOW)
    end,
})
```

`typeName` 对应组件 `GetTypeName()`。`self.target` 是当前对象，`self.targets` 是对象数组。
Inspector UI 画在默认属性下方；Scene GUI 只在对应 target 被选中时运行。同一类型后加载的注册覆盖先加载者。

## ContextMenu

```lua
Editor.ContextMenu("hierarchy", "Tools/Log Selected Nodes", function(nodes)
end)

Editor.ContextMenu("project", "Tools/Log Resource Path", function(paths)
end, {
    description = "…",
    mcp = true,
    validate = function() return true end,
})
```

`hierarchy` 回调收到节点数组；`project` 回调收到 Resource path 数组。选项与 `MenuItem` 相同：
`description`、`mcp`、`validate`、`id`。默认 MCP 名为 `editor_script.ctx_<id>`。
