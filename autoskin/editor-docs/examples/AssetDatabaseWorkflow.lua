-- Safe package/project asset workflow: load -> clone -> create -> edit -> save.
-- Paths are project-relative Resource paths and are not restricted to assets/.

local window = Editor.Window("AssetDatabase Workflow", "examples.asset_database_workflow")
window.sourcePath = ""
window.createdPath = "Generated/AgentExamples/MaterialCopy.material"
window.copiedPath = "Generated/AgentExamples/MaterialFileCopy.material"
window.roughness = 0.5
window.overwrite = false
window.status = "Choose a Material from the project or a mounted package."

local function Report(self, ok, message)
    self.status = message
    if ok then
        Editor.Log(message)
    else
        Editor.Error(message)
    end
end

local function LoadMaterial(self, path)
    local material, err = AssetDatabase.LoadAssetAtPath("Material", path)
    if not material then
        Report(self, false, err or ("Could not load " .. path))
        return nil
    end
    return material
end

function window:OnGUI()
    self.sourcePath = EditorGUILayout.ObjectField("Source Material", self.sourcePath, "Material")
    self.createdPath = EditorGUILayout.TextField("Clone Destination", self.createdPath)
    self.copiedPath = EditorGUILayout.TextField("File-copy Destination", self.copiedPath)
    self.roughness = EditorGUILayout.Slider("Roughness", self.roughness, 0, 1)
    self.overwrite = EditorGUILayout.Toggle("Overwrite", self.overwrite)

    local sourceExists = self.sourcePath ~= "" and AssetDatabase.AssetPathExists(self.sourcePath)
    EditorGUILayout.LabelField("Source exists", tostring(sourceExists))
    EditorGUILayout.HelpBox(self.status,
        sourceExists and EditorGUI.MessageType.Info or EditorGUI.MessageType.Warning)

    EditorGUI.BeginDisabledGroup(not sourceExists)
    if GUILayout.Button("1. Load, clone, and CreateAsset") then
        local source = LoadMaterial(self, self.sourcePath)
        if source then
            -- Never mutate a package asset directly. Clone it, edit the clone, then
            -- create a project-owned asset at any project-relative destination.
            local clone, cloneErr = Object.Instantiate(source)
            if not clone then
                Report(self, false, cloneErr or "Object.Instantiate failed")
            else
                clone:SetShaderParameter("Roughness", Variant(self.roughness))
                local created, createErr = AssetDatabase.CreateAsset(
                    clone, self.createdPath, { overwrite = self.overwrite })
                Report(self, created ~= nil,
                    created and ("Created " .. self.createdPath) or (createErr or "CreateAsset failed"))
            end
        end
    end

    if GUILayout.Button("CopyAsset without deserializing") then
        local ok, err = AssetDatabase.CopyAsset(
            self.sourcePath, self.copiedPath, { overwrite = self.overwrite })
        Report(self, ok, ok and ("Copied to " .. self.copiedPath) or (err or "CopyAsset failed"))
    end
    EditorGUI.EndDisabledGroup()

    local createdExists = AssetDatabase.AssetPathExists(self.createdPath)
    EditorGUI.BeginDisabledGroup(not createdExists)
    if GUILayout.Button("2. Edit, SetDirty, and SaveAssetIfDirty") then
        local material = LoadMaterial(self, self.createdPath)
        if material then
            material:SetShaderParameter("Roughness", Variant(self.roughness))
            EditorUtility.SetDirty(material)
            local ok, err = AssetDatabase.SaveAssetIfDirty(material)
            Report(self, ok, ok and ("Saved " .. self.createdPath) or (err or "SaveAssetIfDirty failed"))
        end
    end

    if GUILayout.Button("ImportAsset") then
        local ok, err = AssetDatabase.ImportAsset(self.createdPath)
        Report(self, ok, ok and ("Imported " .. self.createdPath) or (err or "ImportAsset failed"))
    end
    EditorGUI.EndDisabledGroup()

    if GUILayout.Button("Refresh Resource Browser") then
        AssetDatabase.Refresh()
        Report(self, true, "AssetDatabase.Refresh completed")
    end
end

Editor.MenuItem("Tools/Examples/AssetDatabase Workflow", function()
    window:Show()
end, {
    description = "Clone package/project assets and save project-owned derived assets safely",
})
