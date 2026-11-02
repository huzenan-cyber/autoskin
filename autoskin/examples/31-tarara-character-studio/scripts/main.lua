-- Tarara Character Studio: an official character showcase and a reusable gameplay example.
local Utils = require("Utils")
local Character = require("Character")
local Studio = require("Studio")
local Interface = require("Interface")
local Presentation = require("Presentation")
local UI = require("urhox-libs/UI")

-- Degrees per second for automatic rotation.
local AUTO_ROTATE_SPEED = 20
-- Longest frame step fed to animation and the presentation, in seconds.
local MAX_TIME_STEP = 0.1
-- Starting character heading in degrees: a slight turn towards the character's right hand.
local START_HEADING = 6

---@class TararaApp
---@field scene Scene
---@field hero TararaActor
---@field studio TararaStage
---@field interface TararaInterface
---@field demo TararaPresentation
---@field paused boolean
---@field heading number Character heading in degrees, [-180, 180).
---@field tilt number Sideways lean in degrees; only the presentation sets a non-zero value.
---@field autoRotate boolean
---@field bones boolean Draw the simulated chains.
---@field outline number Outline width in metres.
---@field visible boolean Interface visibility.
local app = {paused = false, heading = START_HEADING, tilt = 0, autoRotate = false, bones = false, outline = Character.OUTLINE_THICKNESS, visible = true}

---@class TararaLaunchOptions
---@field framing string
---@field character string "prefab" loads the serialized character; "lua" builds it in code.
---@field animation string
---@field expression? string
---@field demo boolean
---@field freezeFrame? integer Freeze the scene after this many updates, for screenshots.
local options = {framing = "full", character = "prefab", animation = "Idle", demo = false}

--- Read -studio-* command-line options; unknown values are reported and ignored.
local function ParseArguments()
    local function accept(kind, value, isValid)
        if isValid then return value end
        log:Write(LOG_WARNING, "Ignoring unknown " .. kind .. ": " .. value)
        return nil
    end
    for _, arg in ipairs(GetArguments()) do
        local key, value = arg:match("^%-studio%-([%a]+)=(.+)$")
        if key == "framing" then
            options.framing = accept("framing", value, value == "full" or value == "face") or options.framing
        elseif key == "character" then
            options.character = accept("character", value, value == "prefab" or value == "lua") or options.character
        elseif key == "animation" then
            options.animation = accept("animation", value, Character.FindClip(value) ~= nil) or options.animation
        elseif key == "expression" then
            options.expression = accept("expression", value, Character.FindExpression(value) ~= nil)
        elseif key == "yaw" then
            app.heading = Utils.WrapAngle(tonumber(value) or 0)
        elseif key == "freeze" then
            options.freezeFrame = math.tointeger(tonumber(value))
        elseif arg == "-studio-rotate" then
            app.autoRotate = true
        elseif arg == "-studio-demo" then
            options.demo = true
        elseif arg == "-studio-bones" then
            app.bones = true
        end
    end
end

-- Height in metres of the point the presentation leans the character about.
local LEAN_PIVOT_HEIGHT = 1.4

--- Turn Tarara while keeping particle history, so dragging exercises inertia.
---@param degrees number Any angle; stored wrapped to [-180, 180).
---@param tilt? number Sideways lean in degrees; omitted means upright.
function app:SetHeading(degrees, tilt)
    self.heading, self.tilt = Utils.WrapAngle(degrees), tilt or 0
    local rotation = Quaternion(self.heading, Vector3.UP) * Quaternion(self.tilt, Vector3.FORWARD)
    -- Lean about the chest so a close-up keeps the face in frame.
    local pivot = Vector3(0, LEAN_PIVOT_HEIGHT, 0)
    self.hero.node.rotation = rotation
    self.hero.node.position = pivot - rotation * pivot
end

--- Reset the camera and simulation; heading, expression, clip and physics strength are kept.
function app:ResetView()
    self.studio:SetFraming(self.studio.framing)
    self.hero:Reset()
end

--- Freeze or resume animation, morph easing, actor rotation and secondary motion together.
---@param value boolean
function app:SetPaused(value)
    self.paused = value
    self.scene:SetTimeScale(value and 0 or 1)
    self.hero:SetPaused(value)
end

--- Set Tarara's outline width.
---@param value number Metres.
function app:SetOutline(value)
    self.outline = value
    self.hero.model:SetOutlineThickness(value)
end

--- Start the presentation from its first stage, or return control without changing the scene.
---@param enabled boolean
function app:SetDemo(enabled)
    if enabled then self.demo:Start() else self.demo:Stop() end
end

local updates = 0

function Start()
    ParseArguments()
    graphics.windowTitle = "嗒啦啦 · Tarara Character Studio"
    engine:SetMaxFps(60)
    renderer:SetHDRRendering(true)
    input.mouseVisible = true
    app.scene = Scene()
    app.studio = Studio.Create(app.scene)
    -- Both entry points produce the same character; the prefab is the serialized Character.Build.
    if options.character == "lua" then
        app.hero = Character.Create(app.scene, "Tarara")
    else
        app.hero = Character.Load(app.scene, "Tarara")
    end
    app:SetHeading(app.heading)
    if options.expression then app.hero:SetExpression(options.expression) end
    app.hero:Play(options.animation)
    app.studio:SetFraming(options.framing)
    app.demo = Presentation.Create(app)
    app.interface = Interface.Create(app)
    if options.demo then app:SetDemo(true) end
    SubscribeToEvent("Update", "HandleStudioUpdate")
    SubscribeToEvent("PostRenderUpdate", "HandleStudioPostRender")
    print("TARARA_STUDIO_READY: character=" .. options.character .. " morphs=" .. app.hero.model.model.numMorphs
        .. " bones=" .. app.hero.model.skeleton.numBones)
end

--- Handle the keyboard shortcuts.
local function HandleKeys()
    if input:GetKeyPress(KEY_SPACE) then app:SetPaused(not app.paused) end
    if input:GetKeyPress(KEY_R) then app.demo:Stop(); app:ResetView() end
    if input:GetKeyPress(KEY_H) then app.visible = not app.visible; app.interface:SetVisible(app.visible) end
    -- The wheel zooms only over the scene, not over a scrolling panel.
    if input.mouseMoveWheel ~= 0 then
        local hovered = UI.GetHoveredWidgetForPointer(0)
        if hovered == app.interface.dragPane or not hovered then app.demo:Stop(); app.studio:Zoom(input.mouseMoveWheel) end
    end
end

function HandleStudioUpdate(_eventType, eventData)
    local dt = math.min(eventData["TimeStep"]:GetFloat(), MAX_TIME_STEP)
    local frozen = options.freezeFrame ~= nil and updates >= options.freezeFrame
    if not frozen then
        updates = updates + 1
        app.demo:Update(dt)
        if app.autoRotate and not app.paused then app:SetHeading(app.heading + dt * AUTO_ROTATE_SPEED) end
        app.hero:Update(dt, app.studio.cameraNode.worldPosition)
    end
    app.studio:Update(dt)
    app.studio:SetContactPoints(app.hero:GetContactPoints())
    HandleKeys()
    app.interface:Update()
end

function HandleStudioPostRender()
    if app.bones then app.hero:DrawBones(app.studio.debug) end
    if options.freezeFrame and updates == options.freezeFrame then
        app.scene:SetTimeScale(0)
        updates = updates + 1
        print("TARARA_STUDIO_CAPTURE: " .. app.studio.framing)
    end
end

function Stop()
    Interface.Shutdown()
end

-- Exposes the live controls to the companion validation scripts.
TararaStudio = app
