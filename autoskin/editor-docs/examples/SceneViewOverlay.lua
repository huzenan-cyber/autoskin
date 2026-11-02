-- Two independent SceneView.duringSceneGui listeners with explicit registration lifecycle.
-- Package Editor scripts are loaded at startup; listener registration does not require a watcher.

local window = Editor.Window("SceneView Overlay", "examples.scene_view_overlay", {
    width = 560,
    height = 360,
})
local subscribed = false
local lastHitName = "Move the mouse over scene geometry"

local function DrawMouseHit(sceneView)
    if not Editor.SceneView.IsHovered() then
        return
    end

    local ray = Editor.SceneView.MouseRay()
    local hit = Editor.SceneView.Raycast(ray)
    if not hit then
        lastHitName = "No hit"
        return
    end

    lastHitName = hit.node and hit.node:GetName() or "Unnamed node"
    Editor.Handles.DrawSphere(hit.position, 0.12, Color(1.0, 0.75, 0.2, 1.0))
    Editor.Handles.DrawLine(
        hit.position, hit.position + hit.normal * 0.75, Color(1.0, 0.75, 0.2, 1.0))
end

local function DrawSelection(sceneView)
    local node = Editor.Selection.GetActiveNode()
    if not node then
        return
    end

    local center = node:GetWorldPosition()
    Editor.Handles.DrawPolyline({
        center + Vector3(-0.5, 0, 0),
        center + Vector3(0, 0.75, 0),
        center + Vector3(0.5, 0, 0),
        center + Vector3(-0.5, 0, 0),
    }, Color(0.3, 1.0, 0.5, 1.0))

    if Editor.Handles.Button("scene_view_overlay.focus", center + Vector3(0, 0.9, 0), 0.16) then
        Editor.SceneView.Focus(node)
    end
end

local function Subscribe()
    if subscribed then
        return
    end
    Editor.SceneView.duringSceneGui:AddListener(DrawMouseHit)
    Editor.SceneView.duringSceneGui:AddListener(DrawSelection)
    subscribed = true
    Editor.Log("SceneView Overlay subscribed two listeners")
end

local function Unsubscribe()
    if not subscribed then
        return
    end
    Editor.SceneView.duringSceneGui:RemoveListener(DrawMouseHit)
    Editor.SceneView.duringSceneGui:RemoveListener(DrawSelection)
    subscribed = false
    Editor.Log("SceneView Overlay unsubscribed")
end

function window:OnGUI()
    EditorGUILayout.LabelField("Subscribed", tostring(subscribed))
    EditorGUILayout.LabelField("Mouse hit", lastHitName)
    EditorGUILayout.LabelField("Scene generation", Editor.Scene.GetGeneration())
    EditorGUILayout.LabelField("Scene revision", tostring(Editor.Scene.GetRevision()))

    GUILayout.BeginHorizontal()
    EditorGUI.BeginDisabledGroup(subscribed)
    if GUILayout.Button("Subscribe") then
        Subscribe()
    end
    EditorGUI.EndDisabledGroup()

    EditorGUI.BeginDisabledGroup(not subscribed)
    if GUILayout.Button("Unsubscribe") then
        Unsubscribe()
    end
    EditorGUI.EndDisabledGroup()
    GUILayout.EndHorizontal()

    local node = Editor.Selection.GetActiveNode()
    EditorGUI.BeginDisabledGroup(node == nil)
    if GUILayout.Button("Focus Active Node") and node then
        Editor.SceneView.Focus(node)
    end
    EditorGUI.EndDisabledGroup()
end

Subscribe()

Editor.MenuItem("Tools/Examples/SceneView Overlay", function()
    window:Show()
end, {
    description = "Inspect mouse hits and manage multiple SceneView listeners",
})
