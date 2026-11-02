-- Copy into a project's Editor/ directory. Select a StaticModel node and open Tools/Material UV Bake.
-- Baked images stay in memory until Export is clicked; all paths are project-relative.
local window = Editor.Window("Material UV Bake", "examples.material_uv_bake")
window.resolution = 256
window.outputDir = "Generated/MaterialBake"
window.overwrite = false
window.busy = false
window.status = "Select a StaticModel node, then Bake."
---@type MaterialBakeResult|nil
local result
---@type Texture2D[]
local previews = {}

local function BakeSelection()
    if window.busy then return end
    local node = Editor.Selection.GetActiveNode()
    local modelComponent = node and node:GetComponent("StaticModel")
    if not modelComponent or not modelComponent:GetModel() then
        window.status = "Select a node with a StaticModel."
        return
    end
    local model = modelComponent:GetModel()
    local materials = {}
    for geometry = 0, model:GetNumGeometries() - 1 do
        materials[geometry + 1] = modelComponent:GetMaterial(geometry)
    end
    result = nil
    previews = {}
    window.busy = true
    window.status = "Bake queued..."
    local accepted, err = Editor.MaterialBaking.Bake(model, materials, {
        resolution = window.resolution,
        allowFallback = false,
    }, function(baked, bakeErr)
        window.busy = false
        result = baked
        if baked then
            for i, g in ipairs(baked.geometries) do
                local texture = Texture2D()
                texture:SetNumLevels(1)
                texture:SetSRGB(g.colorEncoding == "sRGB")
                if texture:SetData(g.albedo) then previews[i] = texture end
            end
        end
        window.status = baked and ("Baked " .. #baked.geometries .. " geometries.") or bakeErr
        if bakeErr then Editor.Error(bakeErr) end
    end)
    if not accepted then
        window.busy = false
        window.status = err
        Editor.Error(err)
    end
end

local function ExportImages()
    if not result then return end
    local count = 0
    for _, geometry in ipairs(result.geometries) do
        local stem = window.outputDir .. "/geometry_" .. geometry.geometryIndex .. "_"
        for _, name in ipairs({ "albedo", "rme", "normal", "emissive", "opacity", "coverage" }) do
            local image = geometry[name]
            if image then
                local saved, err = AssetDatabase.CreateAsset(image, stem .. name .. ".png", {
                    overwrite = window.overwrite,
                })
                if not saved then
                    window.status = "Export stopped after " .. count .. " images: " .. err
                    Editor.Error(window.status)
                    return
                end
                count = count + 1
            end
        end
        local r = geometry.uvRect
        Editor.Log(string.format("geometry %d UV rect: %.9g %.9g %.9g %.9g",
            geometry.geometryIndex, r.x, r.y, r.z, r.w))
    end
    window.status = "Exported " .. count .. " images. UV mappings are in Console."
end

function window:OnGUI()
    self.resolution = EditorGUILayout.IntSlider("Resolution", self.resolution, 32, 2048)
    self.outputDir = EditorGUILayout.TextField("Output directory", self.outputDir)
    self.overwrite = EditorGUILayout.Toggle("Overwrite", self.overwrite)
    EditorGUILayout.LabelField("Status", self.status or "")
    EditorGUI.BeginDisabledGroup(self.busy or not Editor.MaterialBaking.IsSupported())
    if GUILayout.Button("Bake selected StaticModel") then BakeSelection() end
    EditorGUI.EndDisabledGroup()
    EditorGUI.BeginDisabledGroup(self.busy or result == nil)
    if GUILayout.Button("Export baked images") then ExportImages() end
    EditorGUI.EndDisabledGroup()
    if result then
        for i, g in ipairs(result.geometries) do
            EditorGUILayout.LabelField("Geometry " .. g.geometryIndex, g.layout .. " / " .. g.colorEncoding)
            if previews[i] then GUILayout.Image(previews[i], { width = 192, height = 192 }) end
        end
    end
end

Editor.MenuItem("Tools/Material UV Bake", function() window:Show() end, {
    description = "Bake selected model materials into UV-space images, then export to project assets",
})
