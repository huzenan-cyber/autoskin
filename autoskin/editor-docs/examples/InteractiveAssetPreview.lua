-- Editor.CreateEditor example for interactive material, model, texture, and Prefab previews.
-- The returned AssetEditor owns preview state but does not create a top-level window.

local window = Editor.Window("Interactive Asset Preview", "examples.interactive_asset_preview", {
    width = 920,
    height = 720,
})
window.assetKind = 1
window.assetPath = "Materials/Stone.xml"
window.status = "Choose an asset and click Load Preview."
window.interactive = true

local kinds = { "Material", "Model", "Texture2D", "XMLFile" }
local defaultPaths = {
    "Materials/Stone.xml",
    "Models/TeaPot.mdl",
    "Textures/UrhoIcon.png",
    "Objects/SnowCrate.xml",
}

local function LoadPreview(self)
    local typeName = kinds[self.assetKind]
    local asset, err = AssetDatabase.LoadAssetAtPath(typeName, self.assetPath)
    if not asset then
        self.asset = nil
        self.assetEditor = nil
        self.status = err or ("Could not load " .. self.assetPath)
        return
    end

    self.asset = asset -- Keep the target alive for as long as the preview is shown.
    self.assetEditor = Editor.CreateEditor(asset)
    if self.assetEditor:HasPreviewGUI() then
        self.status = "Loaded " .. self.assetEditor:GetPreviewTitle()
    else
        self.status = "This asset type has no interactive preview."
    end
end

function window:OnEnable()
    LoadPreview(self)
end

function window:OnGUI()
    local previousKind = self.assetKind
    self.assetKind = EditorGUILayout.Popup("Asset Type", self.assetKind, kinds)
    if previousKind ~= self.assetKind then
        self.assetPath = defaultPaths[self.assetKind]
    end
    self.assetPath = EditorGUILayout.ObjectField("Asset", self.assetPath, kinds[self.assetKind])
    self.interactive = EditorGUILayout.Toggle("Interactive", self.interactive)

    GUILayout.BeginHorizontal()
    if GUILayout.Button("Load Preview", { width = 130 }) then
        LoadPreview(self)
    end
    GUILayout.Label(self.status)
    GUILayout.EndHorizontal()
    GUILayout.Separator()

    if not self.assetEditor or not self.assetEditor:HasPreviewGUI() then
        EditorGUILayout.HelpBox("Load a supported asset to create its type-specific Editor preview.",
            EditorGUI.MessageType.Warning)
        return
    end

    GUILayout.BeginHorizontal()
    GUILayout.Label(self.assetEditor:GetPreviewTitle())
    GUILayout.FlexibleSpace()
    self.assetEditor:OnPreviewSettings()
    GUILayout.EndHorizontal()

    if self.interactive then
        self.assetEditor:OnInteractivePreviewGUI({ expandWidth = true, height = 520 })
    else
        self.assetEditor:OnPreviewGUI({ expandWidth = true, height = 520 })
    end

    if self.assetEditor:RequiresConstantRepaint() then
        GUILayout.Label("This preview requests constant repaint.")
    end
end

Editor.MenuItem("Tools/Examples/Interactive Asset Preview", function()
    window:Show()
end, {
    description = "Preview materials, models, textures, and Prefabs through Editor.CreateEditor",
})
