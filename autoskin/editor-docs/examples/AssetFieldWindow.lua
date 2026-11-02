-- E3 smoke: ObjectField / Image / Color / Slider / AssetDatabase / window Serialize.
-- Copy into the game project's Editor/ folder.

local window = Editor.Window("Asset Field")
window.texturePath = ""
window.tint = Color(1, 1, 1, 1)
window.intensity = 1
window.mode = 1
window.advanced = false
window.target = nil
window.outputPath = "Generated/Textures/AssetFieldCopy.png"
window.reloadNote = "change me, then Tools / Reload Editor Scripts"

local function ColorChannel(color, name)
    if not color then
        return 1
    end
    local value = color[name]
    if value == nil then
        value = color[name .. "_"]
    end
    return value or 1
end

function window:Serialize()
    local tint = self.tint or Color(1, 1, 1, 1)
    local targetId = 0
    if self.target then
        targetId = self.target:GetID()
    end
    return {
        texturePath = self.texturePath or "",
        intensity = self.intensity or 1,
        mode = self.mode or 1,
        advanced = self.advanced and true or false,
        outputPath = self.outputPath or "",
        reloadNote = self.reloadNote or "",
        targetId = targetId,
        tintR = ColorChannel(tint, "r"),
        tintG = ColorChannel(tint, "g"),
        tintB = ColorChannel(tint, "b"),
        tintA = ColorChannel(tint, "a"),
    }
end

function window:Restore(state)
    if not state then
        return
    end
    self.texturePath = state.texturePath or ""
    self.intensity = state.intensity or 1
    self.mode = state.mode or 1
    self.advanced = state.advanced and true or false
    self.outputPath = state.outputPath or self.outputPath
    self.reloadNote = state.reloadNote or ""
    self.tint = Color(state.tintR or 1, state.tintG or 1, state.tintB or 1, state.tintA or 1)
    self.target = nil
    if state.targetId and state.targetId > 0 then
        self.target = Editor.Scene.FindNode(state.targetId)
    end
end

function window:OnGUI()
    GUILayout.Label("Edit fields below, then Tools → Reload Editor Scripts.")
    GUILayout.Label("Texture / Intensity / Mode / Note / Tint / Output Path / Node should stay.")

    self.reloadNote = EditorGUILayout.TextField("Reload Note", self.reloadNote or "")
    self.texturePath = EditorGUILayout.ObjectField("Texture", self.texturePath or "", "Texture2D")
    self.target = EditorGUILayout.ObjectField("Node", self.target, "Node")
    self.tint = EditorGUILayout.ColorField("Tint", self.tint or Color(1, 1, 1, 1))
    self.intensity = EditorGUILayout.Slider("Intensity", self.intensity or 1, 0, 10)
    self.mode = EditorGUILayout.EnumPopup("Mode", self.mode or 1, { "Low", "Medium", "High" })

    GUILayout.Image(self.texturePath, { width = 128, height = 96, tooltip = "Selected texture" })

    self.advanced = EditorGUILayout.Foldout("Output", self.advanced)
    if self.advanced then
        self.outputPath = EditorGUILayout.TextField("Copy To", self.outputPath or "")
        if GUILayout.Button("Copy Texture") then
            if not self.texturePath or self.texturePath == "" then
                Editor.Dialog.Info("Asset Field", "Pick a texture first.")
            else
                local ok, err = AssetDatabase.CopyAsset(self.texturePath, self.outputPath, { overwrite = true })
                if ok then
                    Editor.Log("Wrote " .. self.outputPath)
                    Editor.Dialog.Info("Asset Field", "Wrote " .. self.outputPath)
                else
                    Editor.Dialog.Info("Asset Field", err or "CopyAsset failed")
                end
            end
        end
    end
end

Editor.MenuItem("Tools/Asset Field Window", function()
    window:Show()
end, {
    description = "Open the ObjectField / Image / AssetDatabase smoke window",
})
