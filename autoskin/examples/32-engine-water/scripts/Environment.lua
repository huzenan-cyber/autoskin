--- Sun, sky, clouds and fog of the engine water example. Both skies exist from the start: Apply() shows either the
--- physical SkyAtmosphere or the ProceduralSky, and the SkyLightCapture that lights and reflects the water follows the
--- one that is drawn. Water reflects the Zone's environment light, so reflections always match the visible sky.
---@class Environment
---@field zone Zone
---@field capture SkyLightCapture
---@field sun Light
---@field procedural ProceduralSky
---@field atmosphere SkyAtmosphere
---@field clouds VolumetricCloud
local Environment = {}
Environment.__index = Environment

local HORIZON = Color(0.66, 0.76, 0.88)
-- The physical atmosphere dims the sun by its transmittance; a brighter sun keeps the exposure of the procedural sky.
local SUN_COLOR, SUN_BRIGHTNESS, SUN_BRIGHTNESS_ATMOSPHERE = Color(1.0, 0.95, 0.86), 3.0, 5.0

--- Create the environment nodes in scene. Call Apply() before the first frame.
---@param scene Scene
---@return Environment
function Environment.Create(scene)
    local self = setmetatable({}, Environment)
    local node = scene:CreateChild("Environment")
    local zone = node:CreateComponent("Zone")
    zone.boundingBox = BoundingBox(-4000, 4000)
    zone.envTextureDiffIntensity, zone.envTextureSpecIntensity = 1.0, 1.0
    zone.autoExposureEnabled, zone.ssgiEnabled = false, false
    zone.ssaoIntensity = 0
    -- Distance fog for the procedural sky; the physical atmosphere adds its own aerial perspective.
    zone.fogColor = HORIZON
    zone:SetDepthFogStart(150)
    zone:SetDepthFogEnd(2500)
    self.zone = zone
    self.capture = node:CreateComponent("SkyLightCapture")
    self.capture.minCaptureInterval = 0.25

    -- Water shades with the first non-negative directional light; keep exactly one sun.
    local sunNode = scene:CreateChild("Sun")
    local sun = sunNode:CreateComponent("Light")
    sun.lightType = LIGHT_DIRECTIONAL
    sun.color = SUN_COLOR
    sun.castShadows = true
    -- Separate nearby geometry from the distant ocean. Keep the default shadow resolution and bias:
    -- increasing depth bias to hide coarse self-shadowing makes the thin boat hull leak light.
    sun.shadowCascade = CascadeParameters(25, 150, 0, 0, 0.8)
    self.sun = sun

    local procedural = scene:CreateChild("Sky"):CreateComponent("ProceduralSky")
    procedural.sunLight = sun
    procedural.skyTopColor = Color(0.22, 0.42, 0.82)
    procedural.skyHorizonColor = HORIZON
    -- Below the horizon the procedural sky shows sea haze rather than ground, for reflections that point down.
    procedural.groundHorizonColor = HORIZON
    procedural.groundBottomColor = Color(0.30, 0.42, 0.52)
    self.procedural = procedural

    local atmosphere = scene:CreateChild("Atmosphere"):CreateComponent("SkyAtmosphere")
    atmosphere.sunLight = sun
    self.atmosphere = atmosphere

    -- A cumulus layer from 1.5 km; the wind drifts it slowly across the sky.
    local clouds = scene:CreateChild("Clouds"):CreateComponent("VolumetricCloud")
    clouds.layerBottomAltitude = 1500
    clouds.layerHeight = 3000
    clouds.windVelocity = Vector2(12, 4)
    clouds.cloudShadowEnabled = true
    self.clouds = clouds
    return self
end

--- Apply the environment settings: sky ("atmosphere" or "procedural"), clouds, cloudCoverage, sunElevation and
--- sunAzimuth in degrees (azimuth 0 toward +Z, 90 toward +X), depthFog and ssr.
---@param settings WaterSettings
function Environment:Apply(settings)
    local elevation, azimuth = math.rad(settings.sunElevation), math.rad(settings.sunAzimuth)
    local toSun = Vector3(math.sin(azimuth) * math.cos(elevation), math.sin(elevation),
                          math.cos(azimuth) * math.cos(elevation))
    self.sun.node.direction = -toSun
    local physical = settings.sky == "atmosphere"
    self.sun.brightness = physical and SUN_BRIGHTNESS_ATMOSPHERE or SUN_BRIGHTNESS
    self.procedural.enabled = not physical
    self.atmosphere.enabled = physical
    self.clouds.enabled = settings.clouds
    self.clouds.cloudGlobalCoverage = settings.cloudCoverage
    self.zone:SetDepthFogEnable(settings.depthFog)
    self.zone.ssrEnabled = settings.ssr
    local capture = self.capture
    capture.captureSource = physical and SKY_CAPTURE_ATMOSPHERE or SKY_CAPTURE_SKYBOX
    capture.includeClouds = settings.clouds
    -- A switched source or cloud layer is not a sky material change: ask for a new capture explicitly.
    capture:RequestCapture()
end

--- Return the unit direction toward the sun and its linear color times brightness, for the water materials.
---@return Vector3 toSun
---@return Vector3 sunColor
function Environment:GetSun()
    local color = self.sun.color * self.sun.brightness
    return -self.sun.node.worldDirection, Vector3(color.r, color.g, color.b)
end

return Environment
