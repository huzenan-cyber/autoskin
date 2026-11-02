-- E5: nudge one Terrain heightmap column via Image pixels + ApplyHeightMap.
-- Copy into the game project's Editor/ folder.

local function FindTerrain()
    local scene = Editor.Scene.Get()
    if not scene then
        return nil
    end
    return scene:GetComponent("Terrain", true)
end

Editor.MenuItem("Tools/Terrain/Nudge Center Column", function()
    local terrain = FindTerrain()
    if not terrain then
        Editor.Dialog.Info("Terrain", "No Terrain component in the scene.")
        return
    end
    local src = terrain:GetHeightMap()
    if not src then
        Editor.Dialog.Info("Terrain", "Terrain has no heightmap Image.")
        return
    end
    local w = src:GetWidth()
    local h = src:GetHeight()
    local clone = src:GetSubimage(IntRect(0, 0, w, h))
    if not clone then
        Editor.Dialog.Info("Terrain", "Failed to clone heightmap.")
        return
    end
    local x = math.floor(w / 2)
    for y = 0, h - 1 do
        local pixel = clone:GetPixel(x, y)
        local r = pixel.r or pixel.r_ or 0
        local g = pixel.g or pixel.g_ or 0
        local b = pixel.b or pixel.b_ or 0
        local a = pixel.a or pixel.a_ or 1
        clone:SetPixel(x, y, Color(math.min(1, r + 0.04), g, b, a))
    end
    Editor.Undo.Begin("Nudge Terrain Column")
    Editor.Undo.Record(terrain)
    terrain:SetHeightMap(clone)
    terrain:ApplyHeightMap()
    Editor.Undo.End()
    local world = Editor.Selection.GetActiveNode()
    local at = world and world:GetWorldPosition() or Vector3(0, 0, 0)
    Editor.Log(string.format("Nudged heightmap column %d. Sample GetHeight=%.2f", x, terrain:GetHeight(at)))
    Editor.Dialog.Info("Terrain", "Raised the center heightmap column.\nCtrl+Z restores the previous Height Map ref.")
end, {
    description = "Clone Terrain heightmap, raise one column, ApplyHeightMap",
})
