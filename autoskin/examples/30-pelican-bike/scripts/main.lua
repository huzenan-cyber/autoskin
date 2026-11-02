-- ====================================================================
-- main.lua — 鹈鹕骑单车 / Pelican on a Bicycle
--
-- A white pelican pedals around a ring boardwalk over a GPU FFT ocean.
--   * Deferred path (CEMapDeferred): GBuffer, SSR, SSGI, GTAO, TAA, UE bloom,
--     ACES tonemapping, motion blur, cascaded shadows
--   * Continuous day/night cycle with procedural sky, sun/moon, stars
--   * Clear/rain weather: overcast sky, rain streaks, wet GBuffer surfaces,
--     puddles, rougher and choppier sea, rain ripples, lightning
--   * Volumetric fog lit by the sun (god rays), lighthouse beams, street
--     lamps, buoy beacons and the bicycle headlight
--   * Tessendorf FFT ocean: 256^2 spectrum, 18 compute dispatches per frame
--
-- Run (deferred rendering is required):
--   UrhoXRuntime.exe main.lua -tapcode_dir=<this dir> -skip_login -deferred
-- Optional: -tod=<hours> -rain=<0|1> -freeze -cam=<follow|cinematic|free> -shot=<1-4>
-- ====================================================================
require "LuaScripts/Utilities/Sample"

local Parts = require("parts")
local World = require("world")
local Rider = require("rider")
local Ocean = require("ocean")
local Atmos = require("atmosphere")

---@type WorldHandles
local worldHandles
local hudText
local hudVisible = true
local simTime = 0.0

local camMode = "follow"
local CAM_MODES = { "follow", "cinematic", "free" }
local camYaw, camPitch, camDist = -120.0, 10.0, 6.5
local idleTime = 0.0
local shotIndex, shotTime, holdShot = 1, 0.0, false
---@type Vector3
local smoothFocus

local function parseArguments()
    local deferred = false
    for _, arg in ipairs(GetArguments()) do
        local v = arg:match("^%-tod=(.+)$")
        if v then Atmos.tod = tonumber(v) or Atmos.tod end
        v = arg:match("^%-rain=(.+)$")
        if v then
            local r = tonumber(v) or 0
            Atmos.weatherTarget, Atmos.weather, Atmos.wet = r, r, r
            Atmos.autoWeather = false
        end
        if arg == "-freeze" then Atmos.timeRunning = false end
        v = arg:match("^%-cam=(.+)$")
        if v then camMode = v end
        v = arg:match("^%-shot=(%d)$")
        if v then camMode, shotIndex, holdShot = "cinematic", tonumber(v), true end
        if arg == "-deferred" then deferred = true end
    end
    if not deferred then
        print("[PelicanBike] WARNING: run with -deferred for the full deferred pipeline (SSR/SSGI/GBuffer wetness)")
    end
end

local function setupRenderer()
    renderer:SetHDRRendering(true)
    renderer:SetShadowQuality(SHADOWQUALITY_PCF_24BIT)
    renderer:SetShadowMapSize(4096)
    renderer:SetVolumetricFogFroxelEnabled(true)
    renderer:SetVolumetricFogQuality(VOLUMETRIC_FOG_QUALITY_ULTRA)
end

local function createScene()
    scene_ = Scene()
    scene_:CreateComponent("Octree")
    Atmos.Create(scene_)
    worldHandles = World.Create(scene_)
    Rider.Create(scene_)
    Ocean.Create(scene_)

    cameraNode = scene_:CreateChild("Camera")
    local camera = cameraNode:CreateComponent("Camera")
    camera.farClip = 3000
    camera.fov = 55
    cameraNode.position = Vector3(0, 8, -60)
    renderer:SetViewport(0, Viewport:new(scene_, camera))
end

local function createHud()
    hudText = ui.root:CreateChild("Text")
    hudText:SetFont(cache:GetResource("Font", "Fonts/Anonymous Pro.ttf"), 14)
    hudText.horizontalAlignment = HA_LEFT
    hudText.verticalAlignment = VA_TOP
    hudText:SetPosition(16, 16)
    hudText.color = Color(1, 1, 1, 0.9)
end

local function updateHud()
    if not hudVisible then hudText.visible = false return end
    hudText.visible = true
    local hh = math.floor(Atmos.tod)
    local mm = math.floor((Atmos.tod - hh) * 60)
    local weather = Atmos.weather > 0.5 and "Rain" or "Clear"
    if Atmos.weatherTarget ~= (Atmos.weather > 0.5 and 1 or 0) then weather = weather .. " (changing)" end
    hudText.text = string.format(
        "Pelican on a Bicycle   %02d:%02d  %s%s  %s\n" ..
        "Speed %.1f m/s  |  Ocean: %s\n\n" ..
        "T pause time   [ ] -/+1h   -/= day speed (%.0fs/day)\n" ..
        "R rain on/off   Y auto weather   C camera (%s)\n" ..
        "Mouse orbit   Wheel zoom   WASD free cam   Shift/Ctrl bike speed   H hide HUD",
        hh, mm, weather, Atmos.autoWeather and " [auto]" or "",
        Atmos.timeRunning and "" or "[time paused]",
        Rider.speed, Ocean.failed and "disabled (no compute)" or "FFT 256x256 / 18 dispatches",
        Atmos.dayLength, camMode)
end

local function handleInput(dt)
    if input:GetKeyPress(KEY_T) then Atmos.timeRunning = not Atmos.timeRunning end
    if input:GetKeyPress(KEY_LEFTBRACKET) then Atmos.tod = (Atmos.tod - 1) % 24 end
    if input:GetKeyPress(KEY_RIGHTBRACKET) then Atmos.tod = (Atmos.tod + 1) % 24 end
    if input:GetKeyPress(KEY_MINUS) then Atmos.dayLength = math.min(Atmos.dayLength * 2, 1920) end
    if input:GetKeyPress(KEY_EQUALS) then Atmos.dayLength = math.max(Atmos.dayLength / 2, 30) end
    if input:GetKeyPress(KEY_R) then
        Atmos.autoWeather = false
        Atmos.weatherTarget = (Atmos.weatherTarget > 0.5) and 0 or 1
    end
    if input:GetKeyPress(KEY_Y) then Atmos.autoWeather = not Atmos.autoWeather end
    if input:GetKeyPress(KEY_H) then hudVisible = not hudVisible end
    if input:GetKeyPress(KEY_C) then
        for i, m in ipairs(CAM_MODES) do
            if m == camMode then camMode = CAM_MODES[i % #CAM_MODES + 1] break end
        end
        if camMode == "free" then
            local e = cameraNode.rotation:EulerAngles()
            pitch, yaw = e.x, e.y
        end
        shotTime = 0
    end
    if input:GetKeyDown(KEY_SHIFT) then Rider.speed = math.min(Rider.speed + dt * 3, 12) end
    if input:GetKeyDown(KEY_CTRL) then Rider.speed = math.max(Rider.speed - dt * 3, 0) end
end

local function clampAboveWater(p)
    if p.y < 2.2 then p.y = 2.2 end
    return p
end

local function updateCamera(dt)
    local focus = Rider.GetFocus()
    smoothFocus = smoothFocus and smoothFocus:Lerp(focus, math.min(1, dt * 8)) or focus
    local move = input.mouseMove
    local wheel = input.mouseMoveWheel

    if camMode == "free" then
        yaw = yaw + 0.1 * move.x
        pitch = Clamp(pitch + 0.1 * move.y, -89, 89)
        cameraNode.rotation = Quaternion(pitch, yaw, 0)
        local speed = input:GetKeyDown(KEY_SPACE) and 60 or 15
        if input:GetKeyDown(KEY_W) then cameraNode:Translate(Vector3(0, 0, 1) * speed * dt) end
        if input:GetKeyDown(KEY_S) then cameraNode:Translate(Vector3(0, 0, -1) * speed * dt) end
        if input:GetKeyDown(KEY_A) then cameraNode:Translate(Vector3(-1, 0, 0) * speed * dt) end
        if input:GetKeyDown(KEY_D) then cameraNode:Translate(Vector3(1, 0, 0) * speed * dt) end
        return
    end

    if camMode == "cinematic" then
        shotTime = shotTime + dt
        if shotTime > 11 and not holdShot then shotTime, shotIndex = 0, shotIndex % 4 + 1 end
        local heading = Rider.node.worldRotation
        local pos, look
        if shotIndex == 1 then      -- low tracking shot beside the front wheel
            pos = Rider.node.worldPosition + heading * Vector3(1.6, 0.45, 1.8)
            look = smoothFocus + Vector3(0, -0.5, 0)
        elseif shotIndex == 2 then  -- wide shot with the lighthouse behind
            local dir = Vector3(Rider.node.worldPosition.x, 0, Rider.node.worldPosition.z):Normalized()
            pos = Rider.node.worldPosition + dir * 16 + Vector3(0, 3.5, 0)
            look = smoothFocus + Vector3(0, 2, 0)
        elseif shotIndex == 3 then  -- head-on, pelican riding into camera
            pos = Rider.node.worldPosition + heading * Vector3(-0.4, 1.4, 5.5)
            look = smoothFocus + Vector3(0, 0.2, 0)
        else                        -- high crane shot over the sea
            local a = shotTime * 0.05
            pos = Vector3(90 * math.cos(a + 0.8), 26, 90 * math.sin(a + 0.8))
            look = Vector3(0, 8, 0)
        end
        cameraNode.position = clampAboveWater(pos)
        cameraNode:LookAt(look)
        return
    end

    -- Orbit follow camera; slowly auto-orbits when the mouse is idle.
    if math.abs(move.x) + math.abs(move.y) > 0 then idleTime = 0 else idleTime = idleTime + dt end
    camYaw = camYaw + 0.12 * move.x
    camPitch = Clamp(camPitch + 0.12 * move.y, -5, 70)
    if idleTime > 4 then camYaw = camYaw + dt * 6 end
    camDist = Clamp(camDist - wheel * 0.6, 2.5, 40)
    local baseYaw = Rider.node.worldRotation:YawAngle()
    local rot = Quaternion(camPitch, baseYaw + camYaw, 0)
    local pos = smoothFocus - rot * Vector3(0, 0, camDist)
    cameraNode.position = clampAboveWater(pos)
    cameraNode:LookAt(smoothFocus)
end

local function updateWorldLights(s, dt)
    local L = s.lamps
    for _, light in ipairs(worldHandles.lamps) do light.brightness = 9.0 * L end
    worldHandles.bulbMat:SetShaderParameter("MatEmissiveColor", Variant(Vector3(9, 6.2, 3.4) * L))
    worldHandles.lanternMat:SetShaderParameter("MatEmissiveColor", Variant(Vector3(14, 11, 7) * L))
    worldHandles.lanternLight.brightness = 4 * L
    for _, beam in ipairs(worldHandles.beams) do beam.brightness = 120 * L end
    worldHandles.beamRotor.rotation = Quaternion(0, simTime * 40, 0)

    local blink = ((simTime * 0.5) % 1.0) < 0.12 and 1 or 0
    worldHandles.buoyMat:SetShaderParameter("MatEmissiveColor", Variant(Vector3(12, 1.5, 0.6) * blink))
    local waves = 0.35 + 0.5 * s.weather
    for _, b in ipairs(worldHandles.buoys) do
        b.light.brightness = 3 * blink * math.max(L, 0.25)
        local t = simTime + b.phase
        b.node.position = b.base + Vector3(0, math.sin(t * 0.9) * waves - 0.25, 0)
        b.node.rotation = Quaternion(math.sin(t * 0.7) * 8 * waves, 0, math.cos(t * 0.8) * 8 * waves)
    end
    Rider.SetLights(math.max(L, s.weather * 0.6))
end

function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    simTime = simTime + dt
    handleInput(dt)

    local camPos = cameraNode.worldPosition
    local s = Atmos.Update(dt, camPos)
    Rider.Update(dt)
    updateWorldLights(s, dt)

    local w = s.weather
    Ocean.heightScale = Parts.Lerp(0.55, 1.0, w)
    Ocean.choppiness = Parts.Lerp(1.0, 1.5, w)
    local day = 0.08 + 0.92 * s.dayMix
    Ocean.Update(simTime, camPos, {
        water_color = Vector3(0.004, 0.020, 0.032) * (1 - 0.4 * w),
        scatter_color = Vector3(0.02, 0.15, 0.12) * day,
        sun_direction = s.mainDir,
        sun_radiance = s.mainRadiance,
        foam_threshold = Parts.Lerp(0.5, 0.3, w),
        rain = w,
    })

    updateCamera(dt)
    updateHud()
end

function Start()
    parseArguments()
    SampleStart()
    setupRenderer()
    createScene()
    createHud()
    SampleInitMouseMode(MM_RELATIVE)
    SubscribeToEvent("Update", "HandleUpdate")
end
