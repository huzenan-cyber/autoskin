-- Static AssetPreview gallery: full previews, mini thumbnails, and type-icon fallbacks.
-- Preview generation is asynchronous; request again from OnGUI instead of blocking.

local window = Editor.Window("Asset Preview Gallery", "examples.asset_preview_gallery", {
    width = 980,
    height = 700,
})

local entries = {
    { label = "Material", typeName = "Material", path = "Materials/Stone.xml" },
    { label = "Model", typeName = "Model", path = "Models/TeaPot.mdl" },
    { label = "Texture", typeName = "Texture2D", path = "Textures/UrhoIcon.png" },
    { label = "Prefab", typeName = "XMLFile", path = "Objects/SnowCrate.xml" },
}

local function LoadEntry(entry)
    entry.asset, entry.error = AssetDatabase.LoadAssetAtPath(entry.typeName, entry.path)
end

function window:OnEnable()
    for _, entry in ipairs(entries) do
        LoadEntry(entry)
    end
end

local function DrawEntry(entry)
    GUILayout.BeginVertical()
    GUILayout.Label(entry.label)

    if not entry.asset then
        GUILayout.Image(AssetPreview.GetMiniTypeThumbnail(entry.typeName), {
            width = 64,
            height = 64,
            scaleMode = "ScaleToFit",
            tooltip = entry.error or "Asset could not be loaded",
        })
        GUILayout.Label(entry.error or "Load failed")
        GUILayout.EndVertical()
        return
    end

    local preview = AssetPreview.GetAssetPreview(entry.asset)
    local mini = AssetPreview.GetMiniThumbnail(entry.asset)
    local fallback = AssetPreview.GetMiniTypeThumbnail(entry.typeName)

    GUILayout.Image(preview or fallback, {
        width = 200,
        height = 200,
        scaleMode = "ScaleToFit",
        tooltip = entry.path,
    })
    GUILayout.BeginHorizontal()
    GUILayout.Image(mini or fallback, { width = 64, height = 64, scaleMode = "ScaleToFit" })
    GUILayout.BeginVertical()
    GUILayout.Label(entry.path)
    GUILayout.Label(AssetPreview.IsLoadingAssetPreview(entry.asset) and "Generating..." or
        (preview and "Ready" or "No generated preview"))
    GUILayout.EndVertical()
    GUILayout.EndHorizontal()
    GUILayout.EndVertical()
end

function window:OnGUI()
    EditorGUILayout.HelpBox(
        "GetAssetPreview and GetMiniThumbnail may return nil on the first frames. A type thumbnail is a safe fallback.",
        EditorGUI.MessageType.Info)
    EditorGUILayout.LabelField("Any preview jobs", tostring(AssetPreview.IsLoadingAssetPreviews()))
    GUILayout.Separator()

    GUILayout.BeginScrollView("asset_preview_gallery.scroll", { expandWidth = true, height = 570 })
    GUILayout.BeginHorizontal()
    for _, entry in ipairs(entries) do
        DrawEntry(entry)
        GUILayout.Space(12)
    end
    GUILayout.EndHorizontal()
    GUILayout.EndScrollView()
end

Editor.MenuItem("Tools/Examples/Asset Preview Gallery", function()
    window:Show()
end, {
    description = "Show asynchronous full previews, mini thumbnails, and type-icon fallbacks",
})
