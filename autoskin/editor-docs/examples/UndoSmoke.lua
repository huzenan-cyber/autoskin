-- E1 undo smoke: create node/component, set Light brightness, delete.
-- Copy into the game project's Editor/ folder.

local function RequireScene()
    local scene = Editor.Scene.Get()
    if not scene then
        Editor.Dialog.Info("Undo Smoke", "No scene is open.")
        return nil
    end
    return scene
end

Editor.MenuItem("Tools/Undo Smoke/1 Create Node + Light", function()
    local scene = RequireScene()
    if not scene then
        return
    end
    Editor.Undo.Begin("Undo Smoke Create")
    local node = scene:CreateChild("UndoSmokeLight")
    node:SetPosition(Vector3(0, 2, 0))
    local light = node:CreateComponent("Light")
    Editor.Undo.Record(light)
    light:SetBrightness(20)
    Editor.Undo.End()
    Editor.Log("Created UndoSmokeLight with Light brightness 20. Press Ctrl+Z.")
    Editor.Dialog.Info("Undo Smoke", "Created node UndoSmokeLight.\nPress Ctrl+Z — node should disappear.")
end, {
    description = "Create a node and Light, then undo with Ctrl+Z",
})

Editor.MenuItem("Tools/Undo Smoke/2 Dim First Selected Light", function()
    local nodes = Editor.Selection.GetNodes()
    if not nodes or #nodes == 0 then
        Editor.Dialog.Info("Undo Smoke", "Select a node that has a Light.")
        return
    end
    local light = nodes[1]:GetComponent("Light")
    if not light then
        Editor.Dialog.Info("Undo Smoke", "Selected node has no Light.")
        return
    end
    Editor.Undo.Begin("Undo Smoke Dim Light")
    Editor.Undo.Record(light)
    light:SetBrightness(0.1)
    Editor.Undo.End()
    Editor.Log("Set Light brightness to 0.1. Press Ctrl+Z to restore.")
    Editor.Dialog.Info("Undo Smoke", "Brightness set to 0.1.\nCtrl+Z should restore the old value.")
end, {
    description = "Record a Light and change brightness",
})

Editor.MenuItem("Tools/Undo Smoke/3 Delete Selected Nodes", function()
    local nodes = Editor.Selection.GetNodes()
    if not nodes or #nodes == 0 then
        Editor.Dialog.Info("Undo Smoke", "Select node(s) to delete.")
        return
    end
    Editor.Undo.Begin("Undo Smoke Delete")
    for i = 1, #nodes do
        nodes[i]:Remove()
    end
    Editor.Undo.End()
    Editor.Log("Deleted selection. Press Ctrl+Z to restore.")
    Editor.Dialog.Info("Undo Smoke", "Deleted selection.\nCtrl+Z should bring the nodes back.")
end, {
    description = "Delete selection and restore with Ctrl+Z",
})
