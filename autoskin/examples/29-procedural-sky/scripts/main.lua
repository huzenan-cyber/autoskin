-- ProceduralSky + SkyLightCapture: a day/night sky that also lights the scene.
--
-- ProceduralSky draws a gradient sky with a sun (Godot ProceduralSkyMaterial parameters) and follows
-- a directional light as its sun. SkyLightCapture, placed on the Zone's node, captures that sky into
-- the Zone's ambient light (diffuse SH + reflections) whenever it changes.
-- Docs: engine-docs/recipes/sky-and-environment-lighting.md
--
-- Controls: time slider and toggles in the panel; right mouse drag to look, WASD / QE to move.

local UI = require("urhox-libs/UI")

---@type Scene|nil
local scene_ = nil
---@type Zone|nil
local zone_ = nil
---@type SkyLightCapture|nil
local capture_ = nil
---@type ProceduralSky|nil
local sky_ = nil
---@type Node|nil
local sunNode_ = nil
---@type Light|nil
local sun_ = nil
---@type Node|nil
local cameraNode_ = nil
---@type Label|nil
local timeLabel_ = nil

local hour_ = 16.5
local autoTime_ = false
local yaw_ = 0.0
local pitch_ = 0.0

local DAY_SECONDS = 60.0 -- real seconds per in-game day when auto time is on
local MOVE_SPEED = 6.0
local MOUSE_SENSITIVITY = 0.12

-- Sky palettes (sRGB, as picked in a color picker). sRGB values are converted to linear, so a night
-- sky needs roughly 0.1-0.25 here to stay visible (0.05 sRGB is only 0.004 linear).
local TOP_DAY, TOP_NIGHT = Color(0.22, 0.42, 0.82), Color(0.06, 0.09, 0.20)
local HORIZON_DAY, HORIZON_DUSK, HORIZON_NIGHT = Color(0.66, 0.76, 0.90), Color(0.98, 0.52, 0.26), Color(0.16, 0.20, 0.32)
local GROUND_DAY, GROUND_NIGHT = Color(0.30, 0.28, 0.25), Color(0.05, 0.05, 0.07)
local SUN_DAY, SUN_LOW = Color(1.0, 0.95, 0.86), Color(1.0, 0.50, 0.24)

-- Optional: -hour=<h> sets the start time (used for screenshots)
for _, arg in ipairs(GetArguments()) do
    local v = arg:match("^%-hour=(.+)$")
    if v then
        hour_ = tonumber(v) or hour_
    end
end

local function smoothstep(e0, e1, x)
    local t = math.max(0.0, math.min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3.0 - 2.0 * t)
end

function Start()
    graphics.windowTitle = "ProceduralSky Demo"
    renderer.hdrRendering = true

    CreateScene()
    CreateObjects()
    SetupCamera()
    CreateUI()
    ApplyTimeOfDay()

    SubscribeToEvent("Update", "HandleUpdate")
    print("ProceduralSky demo started, capture supported: " .. tostring(capture_.supported))
end

function Stop()
    UI.Shutdown()
end

function CreateScene()
    scene_ = Scene()
    scene_:CreateComponent("Octree")

    -- Zone + SkyLightCapture on the same node: the capture lights this Zone.
    local envNode = scene_:CreateChild("Environment")
    zone_ = envNode:CreateComponent("Zone")
    zone_.boundingBox = BoundingBox(-1000.0, 1000.0)
    zone_.depthFogStart = 60.0
    zone_.depthFogEnd = 400.0
    zone_.envTextureDiffIntensity = 1.0 -- captured light is the sky's real brightness
    zone_.envTextureSpecIntensity = 1.0
    capture_ = envNode:CreateComponent("SkyLightCapture")

    -- The sun: ProceduralSky draws its disc and glow from this light.
    sunNode_ = scene_:CreateChild("Sun")
    sun_ = sunNode_:CreateComponent("Light")
    sun_.lightType = LIGHT_DIRECTIONAL
    sun_.castShadows = true

    -- The sky: creates a Skybox on its node.
    sky_ = scene_:CreateChild("Sky"):CreateComponent("ProceduralSky")
    sky_.sunLight = sun_
    sky_.skyCurve = 0.2
    sky_.sunDiskSize = 1.0
end

function CreateObjects()
    local function material(color, roughness, metallic)
        local m = Material:new()
        m:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
        m:SetShaderParameter("MatDiffColor", Variant(color))
        m:SetShaderParameter("Roughness", Variant(roughness))
        m:SetShaderParameter("Metallic", Variant(metallic))
        return m
    end
    local function add(modelName, mat, position, scale)
        local node = scene_:CreateChild(modelName)
        node.position = position
        node.scale = scale
        local staticModel = node:CreateComponent("StaticModel")
        staticModel.model = cache:GetResource("Model", modelName)
        staticModel.material = mat
        staticModel.castShadows = true
    end

    add("Models/Plane.mdl", material(Color(0.55, 0.55, 0.55), 0.85, 0.0), Vector3(0.0, 0.0, 0.0), Vector3(60.0, 1.0, 60.0))
    -- Rough spheres pick up the sky's diffuse light; the metal spheres reflect the sky.
    add("Models/Sphere.mdl", material(Color(0.9, 0.9, 0.9), 0.9, 0.0), Vector3(-3.0, 1.0, 0.0), Vector3(2.0, 2.0, 2.0))
    add("Models/Sphere.mdl", material(Color(0.95, 0.95, 0.95), 0.05, 1.0), Vector3(0.0, 1.0, 0.0), Vector3(2.0, 2.0, 2.0))
    add("Models/Sphere.mdl", material(Color(0.95, 0.75, 0.35), 0.35, 1.0), Vector3(3.0, 1.0, 0.0), Vector3(2.0, 2.0, 2.0))
    add("Models/Box.mdl", material(Color(0.8, 0.25, 0.2), 0.6, 0.0), Vector3(-1.5, 0.75, 3.5), Vector3(1.5, 1.5, 1.5))
    add("Models/Cylinder.mdl", material(Color(0.2, 0.55, 0.9), 0.4, 0.0), Vector3(1.8, 1.0, 3.5), Vector3(1.2, 2.0, 1.2))
end

--- Drive the sun and the sky colors from the hour. Writing unchanged values costs nothing: the capture only
--- runs when something actually changed.
function ApplyTimeOfDay()
    local angle = (hour_ - 6.0) / 12.0 * math.pi
    sunNode_.direction = Vector3(-math.cos(angle), -math.sin(angle), 0.35)

    local height = math.sin(angle) -- sun elevation, -1 .. 1
    local day = smoothstep(-0.10, 0.35, height)
    local dusk = math.exp(-((height - 0.02) / 0.14) ^ 2)

    local horizon = HORIZON_NIGHT:Lerp(HORIZON_DAY, day):Lerp(HORIZON_DUSK, dusk * 0.85)
    sky_.skyTopColor = TOP_NIGHT:Lerp(TOP_DAY, day)
    sky_.skyHorizonColor = horizon
    sky_.groundHorizonColor = horizon
    sky_.groundBottomColor = GROUND_NIGHT:Lerp(GROUND_DAY, day)

    sun_.color = SUN_LOW:Lerp(SUN_DAY, smoothstep(0.0, 0.5, height))
    sun_.brightness = 3.0 * smoothstep(-0.05, 0.08, height)
    sun_.enabled = height > -0.05

    zone_.fogColor = horizon -- fog matches the horizon, no seam
end

function RefreshTimeLabel()
    timeLabel_:SetText(string.format("时间 %02d:%02d", math.floor(hour_), math.floor((hour_ % 1) * 60)))
end

function CreateUI()
    UI.Init({
        fonts = {
            { family = "sans", weights = { normal = "Fonts/MiSans-Regular.ttf" } },
        },
        scale = UI.Scale.DEFAULT,
    })

    timeLabel_ = UI.Label { text = "", fontSize = 13, fontColor = { 235, 238, 242, 255 } }
    RefreshTimeLabel()

    UI.SetRoot(UI.Panel {
        width = "100%",
        height = "100%",
        pointerEvents = "box-none",
        children = {
            UI.Panel {
                position = "absolute",
                top = 16,
                left = 16,
                width = 320,
                padding = 16,
                gap = 10,
                borderRadius = 8,
                backgroundColor = { 16, 18, 22, 216 },
                children = {
                    UI.Label {
                        text = "ProceduralSky",
                        fontSize = 18,
                        fontWeight = "bold",
                        fontColor = { 255, 255, 255, 255 },
                    },
                    UI.Label {
                        text = "拖动时间：天空、太阳、雾一起变化；环境光由 SkyLightCapture 自动跟随天空。",
                        fontSize = 12,
                        fontColor = { 180, 188, 198, 255 },
                    },
                    timeLabel_,
                    UI.Slider {
                        min = 4.0,
                        max = 22.0,
                        value = hour_,
                        width = "100%",
                        onChange = function(_, value)
                            hour_ = value
                            RefreshTimeLabel()
                            ApplyTimeOfDay()
                        end,
                    },
                    UI.Toggle {
                        label = "自动流逝时间",
                        value = autoTime_,
                        onChange = function(_, value)
                            autoTime_ = value
                        end,
                    },
                    UI.Toggle {
                        label = "环境光跟随天空（SkyLightCapture）",
                        value = true,
                        onChange = function(_, value)
                            -- Off: the Zone falls back to its own default ambient data.
                            capture_.enabled = value
                        end,
                    },
                },
            },
        },
    })
end

function SetupCamera()
    cameraNode_ = scene_:CreateChild("Camera")
    cameraNode_.position = Vector3(0.0, 2.6, -9.0)
    cameraNode_:LookAt(Vector3(0.0, 2.2, 0.0))
    yaw_ = cameraNode_.rotation:YawAngle()
    pitch_ = cameraNode_.rotation:PitchAngle()

    local camera = cameraNode_:CreateComponent("Camera")
    camera.nearClip = 0.1
    camera.farClip = 1000.0
    camera.fov = 60.0
    renderer:SetViewport(0, Viewport:new(scene_, camera))
end

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData:GetFloat("TimeStep")
    if autoTime_ then
        hour_ = hour_ + dt * 24.0 / DAY_SECONDS
        if hour_ > 22.0 then
            hour_ = 4.0
        end
        RefreshTimeLabel()
        ApplyTimeOfDay()
    end
    MoveCamera(dt)
end

function MoveCamera(dt)
    if input:GetMouseButtonDown(MOUSEB_RIGHT) then
        yaw_ = yaw_ + input.mouseMoveX * MOUSE_SENSITIVITY
        pitch_ = Clamp(pitch_ + input.mouseMoveY * MOUSE_SENSITIVITY, -82.0, 82.0)
        cameraNode_.rotation = Quaternion(pitch_, yaw_, 0.0)
    end

    local step = MOVE_SPEED * dt
    if input:GetKeyDown(KEY_W) then
        cameraNode_:Translate(Vector3(0.0, 0.0, step))
    end
    if input:GetKeyDown(KEY_S) then
        cameraNode_:Translate(Vector3(0.0, 0.0, -step))
    end
    if input:GetKeyDown(KEY_A) then
        cameraNode_:Translate(Vector3(-step, 0.0, 0.0))
    end
    if input:GetKeyDown(KEY_D) then
        cameraNode_:Translate(Vector3(step, 0.0, 0.0))
    end
    if input:GetKeyDown(KEY_Q) then
        cameraNode_:Translate(Vector3(0.0, -step, 0.0), TS_WORLD)
    end
    if input:GetKeyDown(KEY_E) then
        cameraNode_:Translate(Vector3(0.0, step, 0.0), TS_WORLD)
    end
end
