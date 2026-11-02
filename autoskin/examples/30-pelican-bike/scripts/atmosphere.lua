-- Time of day, weather and all global lighting: Zone (deferred effects, fog,
-- volumetric fog, IBL), sun/moon light, procedural sky, rain particles,
-- wet-surface GBuffer post-process, sea mist and lightning.
local Parts = require("parts")
local World = require("world")

local Atmos = {}

local lerp, lerpC, ss = Parts.Lerp, Parts.LerpColor, Parts.Smoothstep

Atmos.tod = 16.5          -- hours
Atmos.dayLength = 240.0   -- real seconds per in-game day
Atmos.timeRunning = true
Atmos.weather = 0.0       -- 0 clear .. 1 storm (smoothed)
Atmos.weatherTarget = 0.0
Atmos.autoWeather = true
Atmos.wet = 0.0
Atmos.state = {}

local zone, zoneNode, celestial, celestialNode, flashLight, flashNode
local skyMaterial, wetMaterial, wetHandle = nil, nil, 0
local skyCapture
local rainNode, rainEmitter, rainEffect, rainMaterial
local mist
local envCube = ""
local weatherTimer = 50.0
local lightningTimer = 6.0
local flashT, flashLevel = 99.0, 0.0
local clock = 0.0

-- Sky palettes
local ZEN_DAY, HOR_DAY = Color(0.07, 0.22, 0.60), Color(0.46, 0.64, 0.93)
local ZEN_SET, HOR_SET = Color(0.13, 0.13, 0.36), Color(1.00, 0.46, 0.20)
local ZEN_NIGHT, HOR_NIGHT = Color(0.003, 0.006, 0.020), Color(0.014, 0.025, 0.055)

local function createZone(scene)
    -- Baseline from the Daytime light group: it carries the ambient SH, which has no
    -- Lua setter. Its sun is removed; the celestial light below replaces it.
    zoneNode = scene:CreateChild("LightGroup")
    zoneNode:LoadXML(cache:GetResource("XMLFile", "LightGroup/Daytime.xml"):GetRoot())
    local presetSun = zoneNode:GetChild("Directional Light", true)
    if presetSun then presetSun:Remove() end
    zone = zoneNode:GetComponent("Zone")
    zone.boundingBox = BoundingBox(-100000, 100000)

    -- Distance and height fog (colour and range are animated every frame).
    zone.fogColor = HOR_DAY
    zone.depthFogEnable = true
    zone.depthFogDensity = 1.0
    zone.depthFogStart = 250
    zone.depthFogEnd = 1400
    zone.heightFogEnable = true
    zone.heightFogDensity = 0.002
    zone.heightFogFalloff = 0.5
    zone.heightFogHeight = 0

    -- Image-based lighting comes from the sky itself: SkyLightCapture renders Sky.shader into a
    -- prefiltered cube plus diffuse SH and hands both to this Zone, recapturing whenever the sky's
    -- parameters change. The prebaked cube below only lights the first frames (and devices that
    -- cannot capture, where it is swapped per time of day instead).
    zone.envSpecTexture = cache:GetResource("TextureCube", "Cube/Day/DaySpecularHDR.dds")
    skyCapture = zoneNode:CreateComponent("SkyLightCapture")
    zone.envCubeAngle = 0
    zone.envCubeFollowAngle = 0     -- the preset adds its own rotation on top of envCubeAngle
    zone.envTextureDiffIntensity = 0.3
    zone.envTextureSpecIntensity = 0.3

    -- Froxel volumetric fog: thin media reaching high enough for the lighthouse beams.
    zone.volumetricFogEnabled = true
    zone.volumetricFogDensity = 0.004
    zone.volumetricFogHeight = 0
    zone.volumetricFogHeightFalloff = 0.025
    zone.volumetricFogViewDistance = 260
    zone.volumetricFogPhaseG = 0.55
    zone.volumetricFogScatteringColor = Color(1, 1, 1)
    zone.volumetricFogAbsorptionIntensity = 0
    zone.volumetricFogStartDistance = 0
    zone.volumetricFogMaxOpacity = 1
    zone.skyLightVolumetricScatteringIntensity = 0.6

    -- Fixed exposure: brightness is driven by the script, so no adaptation "breathing".
    zone.autoExposureEnabled = true
    zone.autoExposurePlusEnabled = true
    zone.autoExposureMinBrightness = 1
    zone.autoExposureMaxBrightness = 1
    zone.autoExposureBias = 1
    zone.autoExposureForceTarget = true

    -- Deferred screen-space stack: SSR + SSGI + GTAO + UE bloom + ACES + motion blur.
    zone:SetSSREnabled(true)
    zone:SetSSRUsePrevFrameColor(true)
    zone:SetSSGIEnabled(true)
    zone:SetSSGIQuality(2)
    zone:SetSSGIIntensity(1.0)
    zone:SetSSAORadius(0.8)
    zone:SetSSAOIntensity(1.6)
    zone:SetTonemapMode(TONEMAP_MODE_ACES)
    zone:SetBloomMode(BLOOM_MODE_UE)
    zone:SetBloomUEIntensity(0.55)
    zone:SetBloomUEThreshold(1.2)
    zone:SetMotionBlurEnabled(true)
    zone:SetMotionBlurAmount(0.35)

    wetMaterial = Material:new()
    if wetMaterial:SetSurfaceShader("Shaders/BLGL/Wetness.shader") then
        wetHandle = zone:AddGBufferPostProcess(wetMaterial)
        zone:SetGBufferPostProcessEnabled(wetHandle, true)
    else
        print("[PelicanBike] Wetness.shader failed to load")
        wetMaterial = nil
    end
end

local function createLights(scene)
    celestialNode = scene:CreateChild("Celestial")
    celestial = celestialNode:CreateComponent("Light")
    celestial.lightType = LIGHT_DIRECTIONAL
    celestial.castShadows = true
    celestial.shadowCascade = CascadeParameters(8.0, 30.0, 90.0, 260.0, 0.8)
    celestial.shadowBias = BiasParameters(0.00025, 0.5)
    World.Volumetric(celestial, 2.0, true)

    flashNode = scene:CreateChild("Lightning")
    flashLight = flashNode:CreateComponent("Light")
    flashLight.lightType = LIGHT_DIRECTIONAL
    flashLight.color = Color(0.75, 0.82, 1.0)
    flashLight.brightness = 0
    flashLight.castShadows = false
    World.Volumetric(flashLight, 1.0, false)
end

local function createSky(scene)
    local node = scene:CreateChild("Sky")
    node:SetScale(500)
    local sky = node:CreateComponent("Skybox")
    sky.model = cache:GetResource("Model", "Models/Box.mdl")
    skyMaterial = Material:new()
    if not skyMaterial:SetSurfaceShader("Shaders/BLGL/Sky.shader") then
        print("[PelicanBike] Sky.shader failed to load")
    end
    sky:SetMaterial(skyMaterial)
end

local function createRain(scene)
    -- Soft vertical streak texture, generated so the project needs no image assets.
    local img = Image()
    img:SetSize(8, 64, 4)
    for y = 0, 63 do
        local v = math.sin((y + 0.5) / 64 * math.pi)
        for x = 0, 7 do
            local u = (x - 3.5) / 3.5
            local a = v * math.exp(-u * u * 3.0)
            img:SetPixel(x, y, Color(a, a, a, a))
        end
    end
    local tex = Texture2D:new()
    tex:SetData(img, true)
    rainMaterial = Material:new()
    rainMaterial:SetTechnique(0, cache:GetResource("Technique", "Techniques/DiffUnlitParticleAdd.xml"))
    rainMaterial:SetTexture(TU_DIFFUSE, tex)

    rainEffect = ParticleEffect:new()
    rainEffect:SetMaterial(rainMaterial)
    rainEffect:SetNumParticles(9000)
    rainEffect:SetEmitterType(EMITTER_BOX)
    rainEffect:SetEmitterSize(Vector3(70, 1, 70))
    rainEffect:SetMinDirection(Vector3(0.10, -1, 0.04))
    rainEffect:SetMaxDirection(Vector3(0.16, -1, 0.08))
    rainEffect:SetMinVelocity(20)
    rainEffect:SetMaxVelocity(26)
    rainEffect:SetMinTimeToLive(1.3)
    rainEffect:SetMaxTimeToLive(1.6)
    rainEffect:SetMinParticleSize(Vector2(0.018, 0.55))
    rainEffect:SetMaxParticleSize(Vector2(0.026, 0.85))
    rainEffect:SetMinEmissionRate(0)
    rainEffect:SetMaxEmissionRate(0)
    rainEffect:SetUpdateInvisible(true)

    rainNode = scene:CreateChild("Rain")
    rainEmitter = rainNode:CreateComponent("ParticleEmitter")
    rainEmitter:SetEffect(rainEffect)
    rainEmitter:SetFaceCameraMode(FC_DIRECTION)
    rainEmitter.castShadows = false
end

local function createMist(scene)
    local node = scene:CreateChild("SeaMist")
    node.position = Vector3(0, 0.5, 0)
    node.scale = Vector3(320, 10, 320)
    mist = node:CreateComponent("LocalFogVolume")
    mist.albedo = Color(0.9, 0.93, 1.0)
    mist.radialExtinction = 0.0
    mist.heightExtinction = 0.0
    mist.heightFalloff = 4.0
    mist.radialFalloff = 0.6
end

function Atmos.Create(scene)
    createZone(scene)
    createLights(scene)
    createSky(scene)
    createRain(scene)
    createMist(scene)
end

local function sunDirection(tod)
    local a = (tod - 6.0) / 12.0 * math.pi
    local tilt = math.rad(32)
    local d = Vector3(math.cos(a), math.sin(a) * math.cos(tilt), -math.sin(a) * math.sin(tilt) + 0.15)
    return d:Normalized()
end

local function setEnvCube(name)
    if envCube == name then return end
    envCube = name
    zone.envSpecTexture = cache:GetResource("TextureCube", name)
end

local function updateLightning(dt, w)
    flashT = flashT + dt
    lightningTimer = lightningTimer - dt
    if w > 0.75 and lightningTimer <= 0 then
        flashT = 0
        lightningTimer = 5 + math.random() * 9
        local a = math.random() * math.pi * 2
        flashNode.direction = Vector3(math.cos(a), -0.8, math.sin(a))
    end
    -- Double-strike envelope over ~0.45 s.
    local f = 0
    if flashT < 0.45 then
        f = math.exp(-flashT * 18) + 0.8 * math.exp(-math.abs(flashT - 0.22) * 30)
        if math.random() < 0.25 then f = f * 0.5 end
    end
    flashLevel = f
end

--- Advance time and weather and apply everything to the scene.
function Atmos.Update(dt, camPos)
    clock = clock + dt
    if Atmos.timeRunning then
        Atmos.tod = (Atmos.tod + dt * 24.0 / Atmos.dayLength) % 24.0
    end
    if Atmos.autoWeather then
        weatherTimer = weatherTimer - dt
        if weatherTimer <= 0 then
            Atmos.weatherTarget = (Atmos.weatherTarget > 0.5) and 0.0 or 1.0
            weatherTimer = (Atmos.weatherTarget > 0.5) and (35 + math.random() * 25) or (55 + math.random() * 35)
        end
    end
    local rate = dt / 10.0
    Atmos.weather = Atmos.weather + math.max(-rate, math.min(rate, Atmos.weatherTarget - Atmos.weather))
    local w = ss(0, 1, Atmos.weather)
    if w > Atmos.wet then
        Atmos.wet = math.min(w, Atmos.wet + dt * 0.08)
    else
        Atmos.wet = math.max(w, Atmos.wet - dt * 0.02)
    end
    updateLightning(dt, w)

    local sun = sunDirection(Atmos.tod)
    local moon = (sun * -1 + Vector3(0.25, 0.15, 0.3)):Normalized()
    local h = sun.y
    local dayMix = ss(-0.06, 0.30, h)
    local golden = math.exp(-((h - 0.04) / 0.13) ^ 2)
    local nightMix = 1 - ss(-0.20, -0.02, h)

    -- Sky gradient, blended towards overcast grey by the weather.
    local zen = lerpC(ZEN_NIGHT, ZEN_DAY, dayMix)
    zen = lerpC(zen, ZEN_SET, golden * 0.45)
    local hor = lerpC(HOR_NIGHT, HOR_DAY, dayMix)
    hor = lerpC(hor, HOR_SET, golden * 0.8)
    local grey = 0.015 + 0.42 * dayMix + 0.05 * golden
    zen = lerpC(zen, Color(0.50 * grey, 0.54 * grey, 0.60 * grey), w * 0.92)
    hor = lerpC(hor, Color(0.66 * grey, 0.70 * grey, 0.75 * grey), w * 0.92)

    local sunCol = lerpC(Color(1.0, 0.36, 0.10), Color(1.0, 0.95, 0.88), ss(0.0, 0.4, h))
    local sunInt = 3.4 * ss(-0.03, 0.10, h) * (1 - 0.85 * w)
    local moonInt = 0.5 * ss(-0.02, 0.2, moon.y) * nightMix * (1 - 0.8 * w)
    local mainDir, mainCol, mainInt
    if sunInt >= moonInt then
        mainDir, mainCol, mainInt = sun, sunCol, sunInt
    else
        mainDir, mainCol, mainInt = moon, Color(0.55, 0.66, 1.0), moonInt
    end
    celestialNode.direction = mainDir * -1
    celestial.color = mainCol
    celestial.brightness = mainInt
    celestial.volumetricFogIntensity = lerp(2.5, 1.2, nightMix)
    flashLight.brightness = flashLevel * 5.0

    -- Zone: fog, IBL, volumetric media
    zone:SetFogColor(lerpC(hor, Color(0.6, 0.65, 0.75), flashLevel * 0.5))
    zone:SetDepthFogStart(lerp(260, 40, w))
    zone:SetDepthFogEnd(lerp(1500, 520, w))
    zone:SetAmbientColor(lerpC(zen, hor, 0.5))
    local ibl
    if skyCapture.supported then
        -- The captured sky already carries time of day, weather and lightning.
        ibl = 1.0
    else
        if h > 0.16 then
            setEnvCube("Cube/Day/DaySpecularHDR.dds")
        elseif h > -0.10 then
            setEnvCube("Cube/Dusk/DuskSpecularHDR.dds")
        else
            setEnvCube("Cube/Night/NightSpecularHDR.dds")
        end
        ibl = (0.025 + 0.34 * dayMix + 0.08 * golden) * (1 - 0.45 * w) + flashLevel * 0.6
    end
    zone.envTextureDiffIntensity = ibl
    zone.envTextureSpecIntensity = ibl
    zone.volumetricFogDensity = 0.0015 + 0.004 * golden + 0.006 * nightMix + 0.006 * w
    zone:SetVolumetricFogDirectionalInscatteringColor(Color(mainCol.r * 0.05, mainCol.g * 0.05, mainCol.b * 0.05))

    -- Morning / storm sea mist
    local morning = math.exp(-((Atmos.tod - 6.5) / 1.5) ^ 2)
    mist.radialExtinction = 0.004 * morning + 0.003 * w
    mist.heightExtinction = 0.08 * morning + 0.05 * w

    -- Sky shader parameters (re-applied every frame: async shader reloads reset overrides).
    if skyMaterial then
        local sunGlow = sunCol * (ss(-0.1, 0.05, h) * (1 - 0.7 * w))
        skyMaterial:SetShaderParameter("zenith_color", Variant(Vector3(zen.r, zen.g, zen.b)))
        skyMaterial:SetShaderParameter("horizon_color", Variant(Vector3(hor.r, hor.g, hor.b)))
        skyMaterial:SetShaderParameter("sun_direction", Variant(sun))
        skyMaterial:SetShaderParameter("sun_color", Variant(Vector3(sunGlow.r, sunGlow.g, sunGlow.b)))
        skyMaterial:SetShaderParameter("moon_direction", Variant(moon))
        local lit = hor * 1.25 + sunCol * ((0.35 * dayMix + 0.7 * golden) * (1 - w))
        local shade = hor * lerp(0.6, 0.4, w)
        skyMaterial:SetShaderParameter("cloud_lit", Variant(Vector3(lit.r, lit.g, lit.b)))
        skyMaterial:SetShaderParameter("cloud_shade", Variant(Vector3(shade.r, shade.g, shade.b)))
        skyMaterial:SetShaderParameter("night", Variant(nightMix))
        skyMaterial:SetShaderParameter("cloud_cover", Variant(lerp(0.30, 1.0, w)))
        skyMaterial:SetShaderParameter("sky_time", Variant(clock))
        skyMaterial:SetShaderParameter("flash", Variant(flashLevel))
        skyMaterial:SetShaderParameter("exposure", Variant(1.6))
    end
    if wetMaterial then
        wetMaterial:SetShaderParameter("wetness", Variant(Atmos.wet))
        wetMaterial:SetShaderParameter("puddles", Variant(ss(0.3, 1.0, Atmos.wet)))
    end

    -- Rain follows the camera, slightly ahead so streaks fill the view.
    local raining = w > 0.02
    rainEmitter:SetEmitting(raining)
    local emission = 5500 * w
    rainEffect:SetMinEmissionRate(emission)
    rainEffect:SetMaxEmissionRate(emission)
    rainNode.position = camPos + Vector3(-3, 14, 0)
    local rainLevel = (0.05 + 0.35 * dayMix + 0.3 * flashLevel) * math.min(1, w * 1.5)
    rainMaterial:SetShaderParameter("MatDiffColor", Variant(Color(0.55 * rainLevel, 0.6 * rainLevel, 0.7 * rainLevel, 1)))

    local s = Atmos.state
    s.sun, s.moon, s.h = sun, moon, h
    s.mainDir = mainDir
    s.mainRadiance = Vector3(mainCol.r * mainInt, mainCol.g * mainInt, mainCol.b * mainInt)
    s.dayMix, s.nightMix, s.golden, s.weather, s.flash = dayMix, nightMix, golden, w, flashLevel
    -- Artificial lights come on at dusk and in heavy rain.
    s.lamps = math.max(ss(0.10, -0.04, h), ss(0.5, 0.9, w) * 0.8)
    return s
end

return Atmos
