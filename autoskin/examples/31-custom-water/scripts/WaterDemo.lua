local Ocean = require("WaterOcean")
local Demo = {}

--- Build the water example on the standard 3D scene scaffold's lifecycle and free-camera conventions.
--- The returned table owns the Scene and all simulation resources; keep it alive until Stop.
function Demo.Create()
    renderer.hdrRendering = true
    local scene = Scene()
    scene:CreateComponent("Octree")
    local lightGroup = scene:CreateChild("LightGroup")
    assert(lightGroup:LoadXML(cache:GetResource("XMLFile", "LightGroup/Daytime.xml"):GetRoot()))
    local zone = lightGroup:GetComponent("Zone", true)
    zone.boundingBox = BoundingBox(-1000, 1000)
    zone.autoExposureEnabled, zone.ssgiEnabled, zone.ssrEnabled = false, false, true
    zone.ssaoIntensity = 0
    zone.bloomWeight = 0.08
    zone:SetDepthFogEnable(true)
    zone:SetDepthFogStart(80)
    zone:SetDepthFogEnd(180)
    local sun = lightGroup:GetComponent("Light", true)
    sun.brightness = 2.5
    sun.node.direction = Vector3(0.35, -0.5, -0.8)
    sun.castShadows = true
    local sky = scene:CreateChild("Sky"):CreateComponent("ProceduralSky")
    sky.sunLight = sun
    sky.skyTopColor = Color(0.16, 0.34, 0.70)
    sky.skyHorizonColor = Color(0.65, 0.77, 0.90)
    sky.groundHorizonColor = sky.skyHorizonColor
    sky.groundBottomColor = Color(0.30, 0.42, 0.52)
    zone.fogColor = sky.skyHorizonColor
    -- Capture the visible procedural sky instead of retaining the preset's unrelated HDR environment.
    zone.envTextureDiffIntensity, zone.envTextureSpecIntensity = 1.0, 1.0
    local capture = lightGroup:CreateComponent("SkyLightCapture")
    capture.captureSource = SKY_CAPTURE_SKYBOX
    capture.includeClouds = false
    capture:RequestCapture()
    local function box(name, position, scale, color)
        local node = scene:CreateChild(name)
        node.position, node.scale = position, scale
        local surface = node:CreateComponent("StaticModel")
        surface.model = cache:GetResource("Model", "Models/Box.mdl")
        local material = Material:new()
        material:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
        material:SetShaderParameter("MatDiffColor", Variant(color))
        material:SetShaderParameter("Roughness", Variant(0.65))
        surface.material, surface.castShadows = material, true
    end
    box("Seabed", Vector3(0, -5, 0), Vector3(150, 0.5, 150), Color(0.5, 0.42, 0.28))
    for i = -2, 2 do
        box("Pier" .. i, Vector3(i * 4, -0.5, 8), Vector3(0.6, 9, 0.6), Color(0.42, 0.18, 0.09))
        box("Marker" .. i, Vector3(i * 4, -3, 3), Vector3(1.5, 1, 1.5), Color(0.12, 0.3, 0.6))
    end
    local ocean = Ocean.New(scene)
    local node = scene:CreateChild("Camera")
    node.position = Vector3(0, 2, -10)
    node:LookAt(Vector3(0, 0, 10))
    local camera = node:CreateComponent("Camera")
    camera.nearClip, camera.farClip, camera.fov = 0.1, 250, 60
    local viewport = Viewport:new(scene, camera)
    -- Inherit the selected runtime pipeline; the same material supports desktop forward and deferred views.
    renderer:SetViewport(0, viewport)
    return {
        scene = scene,
        ocean = ocean,
        camera = camera,
        viewport = viewport,
        zone = zone,
        sun = sun
    }
end

return Demo
