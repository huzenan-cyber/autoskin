-- Unity-style EditorWindow.ShowUtility, focus, and lifecycle example.
-- Open Tools -> Examples -> Utility Window Controller.

local utility = Editor.Window("Utility Asset Helper", "examples.utility_asset_helper", {
    width = 560,
    height = 380,
})
utility.focusEvents = 0
utility.lastEvent = "Not shown"

function utility:OnEnable()
    self.lastEvent = "OnEnable"
end

function utility:OnDisable()
    self.lastEvent = "OnDisable"
end

function utility:OnFocus()
    self.focusEvents = self.focusEvents + 1
    self.lastEvent = "OnFocus"
end

function utility:OnLostFocus()
    self.lastEvent = "OnLostFocus"
end

function utility:OnGUI()
    EditorGUILayout.HelpBox(
        "ShowUtility is non-modal: this window stays above normal editor windows while the rest of the editor remains usable.",
        EditorGUI.MessageType.Info)
    EditorGUILayout.LabelField("Has focus", tostring(self:HasFocus()))
    EditorGUILayout.LabelField("Focus events", tostring(self.focusEvents))
    EditorGUILayout.LabelField("Last lifecycle event", self.lastEvent)

    GUILayout.Space(8)
    GUILayout.BeginHorizontal()
    if GUILayout.Button("Request Focus", { width = 130 }) then
        self:Focus()
    end
    if GUILayout.Button("Show As Normal", { width = 130 }) then
        self:Show()
    end
    if GUILayout.Button("Close", { width = 90 }) then
        self:Close()
    end
    GUILayout.EndHorizontal()
end

local controller = Editor.Window("Utility Window Controller", "examples.utility_window_controller", {
    width = 520,
    height = 300,
})

function controller:OnGUI()
    GUILayout.Label("The same EditorWindow can switch between normal and Utility modes.")
    GUILayout.Space(8)
    if GUILayout.Button("Show Utility") then
        utility:ShowUtility()
    end
    if GUILayout.Button("Show Normal") then
        utility:Show()
    end
    EditorGUI.BeginDisabledGroup(not utility:IsOpen())
    if GUILayout.Button("Focus Utility") then
        utility:Focus()
    end
    EditorGUI.EndDisabledGroup()
end

Editor.MenuItem("Tools/Examples/Utility Window Controller", function()
    controller:Show()
end, {
    description = "Demonstrate ShowUtility, Focus, HasFocus, OnFocus, and OnLostFocus",
})

Editor.MenuItem("Tools/Examples/Show Utility Directly", function()
    utility:ShowUtility()
end, {
    description = "Open a non-modal always-on-top utility window",
})
