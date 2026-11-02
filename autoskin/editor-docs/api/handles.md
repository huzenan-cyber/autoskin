# Scene 视口 Handles

目标相关绘制使用 `Editor.CustomEditor(...).OnSceneGUI`；与 target 无关的全局 overlay 使用
`Editor.SceneView.duringSceneGui`。这是 Unity 的职责划分，多个脚本可以同时注册。

```lua
local function DuringSceneGUI(sceneView)
    local node = Editor.Selection.GetActiveNode()
    if not node then return end

    local position, changed = Editor.Handles.PositionHandle(
        "move", node:GetWorldPosition(), node:GetWorldRotation())
    if changed then
        Editor.Undo.Record(node)
        node:SetWorldPosition(position)
    end
end

Editor.SceneView.duringSceneGui:AddListener(DuringSceneGUI)
-- 不再需要时：RemoveListener(DuringSceneGUI)
```

## Editor.Handles

只能在 Scene GUI 回调中调用：

```lua
Editor.Handles.PositionHandle(id, position, rotation) -> Vector3, changed
Editor.Handles.RotationHandle(id, rotation, position) -> Quaternion, changed
Editor.Handles.ScaleHandle(id, scale, position, rotation, options?) -> Vector3, changed
Editor.Handles.DrawLine(a, b, color?)
Editor.Handles.DrawSphere(center, radius, color?)
Editor.Handles.DrawPolyline({ v3, ... }, color?)
Editor.Handles.Button(id, position, size?) -> bool
```

Scale options：`allowNegative=false`、`uniform=true`。Handle 只返回值，不直接修改 Node；写回前必须
`Editor.Undo.Record(target)`。拖动会使用 Move/Rotate/Scale Handle Undo 组，并复用编辑器 snap 设置。

稳定 `id` 在 Editor Script state 内必须唯一。拖动期间会跳过内置拾取和 Gizmo；Alt 不开始新拖动，
避免挡住相机轨道。

## CustomEditor.OnSceneGUI

```lua
Editor.CustomEditor("SplinePath", {
    OnSceneGUI = function(self)
        local spline = self.target
        -- 绘制只属于该 target 的 Handle
    end,
})
```

`self.target` 是匹配类型的选中组件，`self.targets` 是 target 数组。

## Editor.SceneView

`MouseRay()`、`IsHovered()`、`Raycast(ray, mask?)`、`Focus(node)` 可在 Scene GUI 中使用。
`duringSceneGui` listener 按订阅顺序调用，热加载会自动清理旧 listener。
