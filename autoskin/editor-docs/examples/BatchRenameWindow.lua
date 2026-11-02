-- Example: Editor window with a prefix field.
local window = Editor.Window("Batch Rename")
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
end, {
    description = "Open the batch rename window",
})
