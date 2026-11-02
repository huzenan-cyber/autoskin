---@type Scene
local playerScene

function Start()
    playerScene = Scene()
    playerScene:CreateComponent("Octree")
    local cameraNode = playerScene:CreateChild("Camera")
    local camera = cameraNode:CreateComponent("Camera")
    renderer:SetViewport(0, Viewport:new(playerScene, camera))
    input.mouseMode = MM_FREE
    input.mouseVisible = true
end
