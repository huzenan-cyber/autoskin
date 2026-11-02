-- PropertyField chooses controls from UrhoX Attribute metadata and records Undo automatically.
-- This custom editor also demonstrates Unity-style OnSceneGUI on a specific component type.

Editor.CustomEditor("Camera", {
    OnInspectorGUI = function(self)
        EditorGUILayout.HelpBox(
            "These fields use Camera Attribute names, not Lua getter names.",
            EditorGUI.MessageType.Info)

        EditorGUILayout.PropertyField(self.target, "Is Enabled")
        EditorGUILayout.PropertyField(self.target, "FOV")
        EditorGUILayout.PropertyField(self.target, "Near Clip")
        EditorGUILayout.PropertyField(self.target, "Far Clip")
        EditorGUILayout.PropertyField(self.target, "Projection Offset")
        EditorGUILayout.PropertyField(self.target, "View Mask")

        EditorGUILayout.PropertyField(self.target, "Orthographic")
        EditorGUI.BeginDisabledGroup(not self.target:IsOrthographic())
        EditorGUILayout.PropertyField(self.target, "Orthographic Size")
        EditorGUI.EndDisabledGroup()

        if #self.targets > 1 then
            EditorGUILayout.HelpBox(
                "This compact example edits self.target; self.targets contains the full multi-selection.",
                EditorGUI.MessageType.Warning)
        end
    end,

    OnSceneGUI = function(self)
        local node = self.target:GetNode()
        if not node then
            return
        end

        local position = node:GetWorldPosition()
        Editor.Handles.DrawSphere(position, 0.18, Color(0.3, 0.8, 1.0, 1.0))
        Editor.Handles.DrawLine(
            position, position + Vector3(0, 1, 0), Color(0.3, 0.8, 1.0, 1.0))
    end,
})
