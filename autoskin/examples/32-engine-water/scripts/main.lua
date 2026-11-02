-- Engine water example: one water domain with engine waves drives the rendered surface, buoyancy of voxel bodies,
-- swimming, gameplay queries and the underwater view. The panel switches the sky, clouds and waves and tunes the water.
--   G switches the FFT ocean and the Gerstner lake, R resets the floaters, M the downward reflections, H the panel,
--   B boards/leaves the motorboat, Backspace leaves the boat and respawns the swimmer.
-- Optional: -waves=gerstner starts on the lake; -sky=procedural with the procedural sky; -clouds=0 without clouds;
-- -boat starts aboard the motorboat; -mirror=0 with the default reflection composite; -panel=0 with the panel hidden; -view=x:y:z:yaw:pitch holds a fixed
-- camera (screenshots). Separate the -view values with colons: the engine splits command line arguments at commas.
local WaterScene = require("WaterScene")
local Environment = require("Environment")
local Swimmer = require("Swimmer")
local BoatController = require("BoatController")
local ControlPanel = require("ControlPanel")
local UI = require("urhox-libs/UI")

-- Gameplay query point: a buoy placed on the wave surface every frame, without physics.
local BUOY_XZ = Vector2(22, 2)

---@type table?
local demo = nil
---@type table?
local environment = nil
---@type table?
local swimmer = nil
---@type table?
local panel = nil
local boat = nil
local startAboard = false
local buoy = nil
local fixedView = nil
local fallback, supportChecked = false, false
local hudTimer = 0.0

local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = Copy(item) end
    return result
end

-- Shared by the scene, the environment and the panel. The sun stands low in the west, ahead of the start view:
-- wave shape reads through the sun glitter and the reflected sky gradient.
local settings = Copy(WaterScene.DEFAULTS)
settings.sky, settings.clouds, settings.cloudCoverage = "atmosphere", true, -0.2
settings.sunElevation, settings.sunAzimuth = 22, 290
settings.depthFog, settings.ssr, settings.mirror = false, true, true
local showPanel = true

local function ParseArguments()
    for _, argument in ipairs(GetArguments()) do
        local waves = argument:match("^%-waves=(%a+)$")
        if waves == "gerstner" or waves == "fft" then settings.waves = waves end
        local sky = argument:match("^%-sky=(%a+)$")
        if sky == "procedural" or sky == "atmosphere" then
            settings.sky = sky
            settings.depthFog = sky == "procedural"
        end
        if argument == "-clouds=0" then settings.clouds = false end
        if argument == "-mirror=0" then settings.mirror = false end
        if argument == "-panel=0" then showPanel = false end
        if argument == "-boat" then startAboard = true end
        local view = argument:match("^%-view=(.+)$")
        if view then
            local values = {}
            for number in view:gmatch("[-%d%.]+") do table.insert(values, tonumber(number)) end
            if #values == 5 then fixedView = values end
        end
    end
end

-- The engine's water reflection composite reads downward reflections from the mirrored sky when its command defines
-- WATER_MIRRORED_ENVIRONMENT. Editing the viewport render path defines switches this view.
local function ApplyMirroredEnvironment()
    local path = renderer:GetViewport(0):GetRenderPath()
    for i = 0, path:GetNumCommands() - 1 do
        local command = path:GetCommand(i)
        if command.tag == "Water Reflections" then
            local defines = command.pixelShaderDefines:gsub("WATER_MIRRORED_ENVIRONMENT", ""):match("^%s*(.-)%s*$")
            if settings.mirror then defines = (defines .. " WATER_MIRRORED_ENVIRONMENT"):match("^%s*(.-)%s*$") end
            command.pixelShaderDefines = defines
        end
    end
end

local function CreateBuoy(scene)
    local node = scene:CreateChild("Buoy")
    local float = node:CreateChild("Float")
    float.scale = Vector3(0.7, 0.9, 0.7)
    local model = float:CreateComponent("StaticModel")
    model.model = cache:GetResource("Model", "Models/Cylinder.mdl")
    local material = Material:new()
    material:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    material:SetShaderParameter("MatDiffColor", Variant(Color(0.85, 0.2, 0.08)))
    material:SetShaderParameter("Roughness", Variant(0.5))
    model.material, model.castShadows = material, true
    return node
end

-- Unsupported views (missing water pass, unsupported sample count, no compute) do not draw Water materials:
-- swap in a plain translucent surface. Buoyancy and swimming keep using the water domain.
local function UseFallbackSurface()
    local material = Material:new()
    material:SetTechnique(0, cache:GetResource("Technique", "Techniques/NoTextureAlpha.xml"))
    material:SetShaderParameter("MatDiffColor", Variant(Color(0.08, 0.30, 0.38, 0.65)))
    material.cullMode = CULL_NONE
    -- WaterScene reassigns water.material with the bounds, so a later wave switch keeps the fallback.
    demo.water.material = material
    demo.water.model.material = material
    demo.water.far.material = material
    fallback = true
end

-- The view's water state exists once it has rendered the domain; IsSupported() tells whether Water materials draw.
local function CheckWaterSupport()
    if supportChecked then return end
    local viewport = renderer:GetViewport(0)
    local state = viewport ~= nil and viewport:GetWaterState() or nil
    if state == nil then return end
    supportChecked = true
    if not state:IsSupported() then
        print("EngineWaterDemo: " .. state:GetLastError())
        UseFallbackSurface()
    end
end

-- Place the buoy on the surface over BUOY_XZ. Pass WaterWorld:GetTime(): it is the time the rendered waves use,
-- follows the scene time scale and never wraps. Any height inside the domain works for the query point.
local function UpdateBuoy()
    local waterWorld = demo.scene:GetWaterWorld()
    local time = waterWorld:GetTime()
    local sample = waterWorld:SampleSurface(Vector3(BUOY_XZ.x, WaterScene.SEA_LEVEL, BUOY_XZ.y), time)
    if not sample:IsValid() then return nil end
    buoy.position = sample.position
    buoy.rotation = Quaternion(Vector3.UP, sample.normal)
    return sample, time
end

local function DescribeView()
    local state = renderer:GetViewport(0):GetWaterState()
    if fallback then return "水体管线不可用（需要水体 pass、HDR、单采样或前向 4× MSAA、桌面 DX11/GL + compute），已换成平面材质" end
    -- No domain contains the camera: above the domain top, or outside the sea.
    if state ~= nil and state:GetStatus() == WATER_NO_DOMAIN then return "相机：水域外" end
    if state == nil or not state:IsValid() then return "相机：等待水域查询" end
    return string.format("相机：%s（浸没 %+.2f m）", state:IsUnderwater() and "水下" or "水上",
                         state:GetImmersionDepth())
end

local function UpdateStatus(sample, time)
    local waves = demo.water.kind == "fft" and "FFT 海面" or "Gerstner 湖面"
    local lines = {string.format("%s | 水域时间 %.1f s", waves, time or 0)}
    if sample then
        local slope = math.deg(math.acos(Clamp(sample.normal.y, -1, 1)))
        local rise = sample.hasVelocity and sample.velocity.y or 0
        table.insert(lines, string.format("浮标：高度 %+.2f m / 坡度 %.1f° / 升降 %+.2f m/s", sample.position.y, slope,
                                          rise))
    end
    table.insert(lines, DescribeView())
    if boat.aboard then
        table.insert(lines, string.format("驾驶中：%.1f km/h | W/S 油门/倒车  A/D 转向  Space 刹车", boat.speed * 3.6))
        table.insert(lines, boat.touchingWater and "B 下船游泳 | 右键转视角观察尾流" or "等待触水或已搁浅/出水域，R 复位")
    else
        table.insert(lines, swimmer.controller.swimming and "游泳中：Space 上浮 / C 下潜 | B 上船" or "步行中 | B 一键上船展示尾流")
    end
    panel:SetStatus(table.concat(lines, "\n"))
end

local function SwitchWaves()
    settings.waves = settings.waves == "fft" and "gerstner" or "fft"
    WaterScene.SetSurface(demo, settings.waves, settings)
    panel:Refresh()
end

function Start()
    graphics.windowTitle = "Engine Water / Boat, Wakes and Swimming"
    ParseArguments()
    demo = WaterScene.Create(settings)
    environment = Environment.Create(demo.scene)
    environment:Apply(settings)
    buoy = CreateBuoy(demo.scene)
    -- Feet on the beach, looking out to sea (-X).
    swimmer = Swimmer.New(demo.scene, Vector3(48, 1.6, 4), -90)
    boat = BoatController.New(demo, swimmer)
    if startAboard then boat:Enter() end
    renderer:SetViewport(0, Viewport:new(demo.scene, swimmer.camera))
    ApplyMirroredEnvironment()
    input.mouseVisible = true

    UI.Init({scale = UI.Scale.DEFAULT})
    panel = ControlPanel.Create(settings, {
        environment = function() environment:Apply(settings) end,
        waveKind = function() WaterScene.SetSurface(demo, settings.waves, settings) end,
        waves = function() WaterScene.ApplyWaves(demo, settings) end,
        mirror = ApplyMirroredEnvironment,
    })
    if not showPanel then panel:ToggleVisible() end
    SubscribeToEvent("SceneUpdate", "HandleSceneUpdate")
    SubscribeToEvent("PostUpdate", "HandlePostUpdate")
end

-- Intent before the physics step of this frame.
function HandleSceneUpdate(_eventType, eventData)
    if not demo or not swimmer then return end
    CheckWaterSupport()
    if input:GetKeyPress(KEY_G) then SwitchWaves() end
    if input:GetKeyPress(KEY_R) then
        WaterScene.Reset(demo)
        boat:ResetCamera()
    end
    if input:GetKeyPress(KEY_BACKSPACE) then
        boat:Leave()
        swimmer:Respawn()
    end
    if not fixedView and input:GetKeyPress(KEY_B) then
        if boat.aboard then boat:Leave() else boat:Enter() end
    end
    if input:GetKeyPress(KEY_H) then panel:ToggleVisible() end
    if input:GetKeyPress(KEY_M) then
        settings.mirror = not settings.mirror
        ApplyMirroredEnvironment()
        panel:Refresh()
    end
    local timeStep = eventData:GetFloat("TimeStep")
    if fixedView then boat:Drive(timeStep, 0, 0, false) else boat:Control(timeStep) end
    if not fixedView and not boat.aboard then swimmer:Control() end
end

---@param _eventType string
---@param eventData PostUpdateEventData
function HandlePostUpdate(_eventType, eventData)
    if not demo or not swimmer or not panel then return end
    boat:Update(eventData:GetFloat("TimeStep") * demo.scene.timeScale)
    if fixedView then
        local v = fixedView
        swimmer.cameraNode.worldPosition = Vector3(v[1], v[2], v[3])
        swimmer.cameraNode.worldRotation = Quaternion(v[5], v[4], 0)
    elseif not boat.aboard then
        swimmer:UpdateCamera()
    end
    -- The character's controller owns contact with the water. A small foot-to-chest offset follows its waterline;
    -- deep dives leave no surface wake. No GPU readback is needed for this gameplay decision.
    local world = demo.scene:GetWaterWorld()
    local time = world:GetTime()
    local position = swimmer.node.worldPosition + Vector3(0, 1.0, 0)
    local surface = world:SampleSurface(position, time)
    local contact = not boat.aboard and swimmer.controller.swimming and surface:IsValid() and math.abs(surface.immersionDepth) < 0.8
    demo.water.wake:Feed("swimmer", position, time, 0.45, 0.8, contact)
    WaterScene.Update(demo, settings, environment:GetSun())
    local sample, time = UpdateBuoy()
    hudTimer = hudTimer + eventData:GetFloat("TimeStep")
    if hudTimer > 0.2 then
        hudTimer = 0
        UpdateStatus(sample, time)
    end
end

function Stop()
    UI.Shutdown()
    boat = nil
    demo, environment, swimmer, panel = nil, nil, nil, nil
end
