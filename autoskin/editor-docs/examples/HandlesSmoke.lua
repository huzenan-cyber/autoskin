-- E2 viewport smoke: draw / drag Position, Rotation, and Scale handles on the selected node.
-- Copy into the game project's Editor/ folder.

local function RequireScene()
    local scene = Editor.Scene.Get()
    if not scene then
        Editor.Dialog.Info("Handles Smoke", "No scene is open.")
        return nil
    end
    return scene
end

local function MarkerPosition()
    local ray = Editor.SceneView.MouseRay()
    if ray and ray.direction then
        local dir = ray.direction
        if dir:Length() > 0.001 then
            return ray.origin + dir:Normalized() * 8
        end
    end
    return Vector3(0, 1, 0)
end

Editor.MenuItem("Tools/Handles Smoke/Create Marker", function()
    local scene = RequireScene()
    if not scene then
        return
    end
    Editor.Undo.Begin("Handles Smoke Marker")
    local node = scene:CreateChild("HandlesSmokeMarker")
    node:SetWorldPosition(MarkerPosition())
    Editor.Undo.End()
    Editor.Selection.SetActiveNode(node)
    Editor.SceneView.Focus(node)
    Editor.Log("Created HandlesSmokeMarker in front of the camera. Drag the cyan circle.")
    Editor.Dialog.Info("Handles Smoke",
        "Created HandlesSmokeMarker in front of the camera.\nYou should see a cyan circle.\nDrag it, then Ctrl+Z.")
end, {
    description = "Create a marker in front of the camera and drag it with a Scene handle",
})

local function DuringSceneGUI(sceneView)
    local node = Editor.Selection.GetActiveNode()
    if not node then
        node = Editor.Scene.FindNodeByName("HandlesSmokeMarker")
    end
    if not node then
        return
    end

    local pos = node:GetWorldPosition()
    Editor.Handles.DrawLine(pos, pos + Vector3(0, 1.5, 0), Color(1, 0.85, 0.2, 1))

    local newPos, changed = Editor.Handles.PositionHandle("handles_smoke.position", pos, node:GetWorldRotation())
    if changed then
        Editor.Undo.Record(node)
        node:SetWorldPosition(newPos)
    end

    local newRotation, rotationChanged = Editor.Handles.RotationHandle(
        "handles_smoke.rotation", node:GetWorldRotation(), newPos)
    if rotationChanged then
        Editor.Undo.Record(node)
        node:SetWorldRotation(newRotation)
    end

    local newScale, scaleChanged = Editor.Handles.ScaleHandle(
        "handles_smoke.scale", node:GetScale(), newPos, node:GetWorldRotation(), {
            allowNegative = false,
            uniform = true,
        })
    if scaleChanged then
        Editor.Undo.Record(node)
        node:SetScale(newScale)
    end

    if Editor.Handles.Button("handles_smoke_log", pos + Vector3(0, 1.5, 0)) then
        Editor.Log(string.format("Handle button at (%.2f, %.2f, %.2f)", pos.x, pos.y, pos.z))
    end
end


Editor.SceneView.duringSceneGui:AddListener(DuringSceneGUI)
