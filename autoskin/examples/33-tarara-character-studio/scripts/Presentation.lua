-- A short, data-driven presentation that drives the same controls as the user.
local Utils = require("Utils")
local Character = require("Character")

---@class TararaPresentationStage
---@field title string
---@field duration? number Seconds; derived from the clip length when plays is set.
---@field plays? integer Times the clip plays; the stage lasts exactly that long.
---@field animation string Clip name.
---@field framing string
---@field expressions string[] Presets shown in equal slices of the stage.
---@field turn? number Degrees turned over the whole stage.
---@field heading? number Heading eased to at the start of the stage; used when turn is nil.
---@field poses? TararaPresentationPose[] Shots in equal slices of the stage; each shows an equal share of expressions.

---@class TararaPresentationPose
---@field heading number Character heading in degrees.
---@field tilt? number Sideways roll in degrees, positive towards the character's left.
---@field distance? number Camera distance in metres; set for a close-up that follows the head.
---@field yaw? number Camera yaw in degrees; nil keeps the framing's.
---@field pitch? number Camera pitch in degrees; positive looks down from above.

---@class TararaPresentation
---@field app TararaApp
---@field active boolean
---@field stageIndex integer
---@field elapsed number Seconds into the current stage.
---@field cycles integer Completed loops.
---@field expressionIndex integer
---@field startHeading number
---@field startTilt number
---@field turn number
---@field startYaw number
---@field startPitch number
---@field targetYaw number
---@field targetPitch number
local Presentation = {}
Presentation.__index = Presentation

-- Seconds over which the camera and heading ease into a new stage.
local TRANSITION_TIME = 0.8
-- Seconds of the quick, overshooting body turn that accompanies each new expression.
local POSE_TIME = 0.4
-- Seconds the camera takes to swing to a new close-up angle.
local CAMERA_POSE_TIME = 0.45
-- Close-ups follow the head bone, offset up between the eyes and the crown, so a tilt never pushes
-- the face out of frame and the top of the head stays in view.
local HEAD_TO_EYES = Vector3(0, 0.11, 0)

---@type TararaPresentationStage[]
Presentation.stages = {
    {title = "卡渲与轮廓", duration = 8, animation = "Walk", framing = "full", expressions = {"neutral"}, turn = 360},
    -- The run makes a full turn, so the hem and ribbons are seen from every side.
    {title = "发梢与裙摆", duration = 3.5, animation = "Run", framing = "full", expressions = {"neutral"}, turn = 360},
    -- Four close-ups with two expressions each: front, tilted left, tilted right, then a nearer front shot.
    {title = "表情与形态键", duration = 10, animation = "Idle", framing = "face",
        expressions = {"speaking", "smile", "wink", "happy", "surprised", "thinking", "sad", "happy"},
        poses = {
            {heading = 0, distance = 1.15},
            {heading = -12, tilt = 14, distance = 1.05},
            {heading = 12, tilt = -14, distance = 1.05},
            {heading = 8, distance = 0.9, yaw = 0, pitch = 0},
        }},
    -- Each action plays once with the expression that suits it.
    {title = "开心", plays = 1, animation = "Happy", framing = "full", expressions = {"happy"}, heading = 0},
    {title = "难过", plays = 1, animation = "Sad", framing = "full", expressions = {"sad"}, heading = 0},
    {title = "思考", plays = 1, animation = "Think", framing = "full", expressions = {"thinking"}, heading = 0},
}

---@type number Total loop length in seconds; set by Presentation.Create once clip lengths are known.
Presentation.duration = 0

--- Give stages that play their clip a whole number of times the matching duration.
local function ResolveDurations()
    Presentation.duration = 0
    for _, stage in ipairs(Presentation.stages) do
        if stage.plays then
            local clip = assert(Character.FindClip(stage.animation))
            local animation = assert(cache:GetResource("Animation", assert(clip.path)), "Missing animation: " .. clip.path)
            stage.duration = animation.length * stage.plays
        end
        Presentation.duration = Presentation.duration + stage.duration
    end
end

--- Ease out past the target and settle back, so the body turn jolts the hair and skirt.
---@param t number Progress in [0, 1].
---@return number
local function Overshoot(t)
    local back = 1.70158
    local u = math.min(math.max(t, 0), 1) - 1
    return 1 + (back + 1) * u * u * u + back * u * u
end

--- Smoothstep over [0, 1]; inputs past 1 hold the end.
---@param t number
---@return number
local function Smooth(t)
    t = math.min(t, 1)
    return t * t * (3 - 2 * t)
end

--- Return which close-up of a posed stage is showing, and the seconds since it began.
---@param stage TararaPresentationStage A stage with poses.
---@param elapsed number Seconds into the stage.
---@return integer index, number since
local function ShotAt(stage, elapsed)
    local slot = stage.duration / #stage.poses
    local index = math.min(#stage.poses, math.floor(elapsed / slot) + 1)
    return index, elapsed - (index - 1) * slot
end

--- Create an inactive presentation.
---@param app TararaApp
---@return TararaPresentation
function Presentation.Create(app)
    ResolveDurations()
    return setmetatable({app = app, active = false, stageIndex = 1, elapsed = 0, cycles = 0, expressionIndex = 1,
        startHeading = 0, startTilt = 0, turn = 0, startYaw = 0, startPitch = 0, targetYaw = 0, targetPitch = 0}, Presentation)
end

--- Start a stage from the current camera angle so the transition stays smooth.
---@param index integer One-based stage index; wraps at the end of the sequence.
function Presentation:EnterStage(index)
    self.stageIndex = (index - 1) % #Presentation.stages + 1
    self.elapsed = 0
    local stage = assert(Presentation.stages[self.stageIndex])
    local app, studio = self.app, self.app.studio
    if app.hero.animation ~= stage.animation then app.hero:Play(stage.animation) end
    self.startHeading, self.startTilt = app.heading, app.tilt
    local heading = stage.poses and stage.poses[1].heading or stage.heading or 0
    self.turn = stage.turn or Utils.WrapAngle(heading - self.startHeading)
    self.startYaw, self.startPitch = studio.yaw, studio.pitch
    studio:SetFraming(stage.framing)
    self.targetYaw, self.targetPitch = studio.yaw, studio.pitch
    studio.yaw, studio.pitch = self.startYaw, self.startPitch
    self:ApplyShot(stage, 1)
    print("TARARA_DEMO_STAGE: " .. self.stageIndex .. " " .. stage.title)
end

--- Show one expression of a stage; a close-up also sets its distance and follows the head.
---@param stage TararaPresentationStage
---@param index integer One-based entry of stage.expressions.
function Presentation:ApplyShot(stage, index)
    self.expressionIndex = index
    self.app.hero:SetExpression(assert(stage.expressions[index]))
    if not stage.poses then return end
    local pose = assert(stage.poses[(ShotAt(stage, self.elapsed))])
    self.app.studio:SetDistance(pose.distance)
    self.app.studio:Follow(pose.distance and self.app.hero:GetHead() or nil, HEAD_TO_EYES)
end

--- Begin the loop with animation, blinking and physics enabled. Light and material settings stay
--- under user control.
function Presentation:Start()
    local app = self.app
    self.active, self.cycles = true, 0
    app.autoRotate = false
    app:SetPaused(false)
    app.hero.autoBlink, app.hero.intensity = true, 1
    app.hero:SetSpeed(1)
    app.hero:SetPhysics(1)
    self:EnterStage(1)
end

--- Yield control immediately, keeping the visible pose and camera.
function Presentation:Stop()
    if self.active then self.app.studio:HoldFraming() end
    self.active = false
end

--- Return the character heading and sideways tilt for a stage at a given time.
---@param stage TararaPresentationStage
---@param elapsed number Seconds into the stage.
---@return number heading, number tilt
function Presentation:PoseAt(stage, elapsed)
    local blend = Smooth(elapsed / TRANSITION_TIME)
    -- A full turn runs at constant speed over the stage; a target heading eases in with the camera.
    local turnBlend = stage.turn and math.min(elapsed / stage.duration, 1) or blend
    local heading = self.startHeading + self.turn * turnBlend
    -- A tilt left by the previous stage straightens out with the camera blend.
    local tilt = self.startTilt * (1 - blend)
    if stage.poses then
        local index, since = ShotAt(stage, elapsed)
        if index > 1 then
            local from, to = stage.poses[index - 1], stage.poses[index]
            local t = Overshoot(since / POSE_TIME)
            heading = from.heading + Utils.WrapAngle(to.heading - from.heading) * t
            tilt = (from.tilt or 0) + ((to.tilt or 0) - (from.tilt or 0)) * t
        end
    end
    return heading, tilt
end

--- Return the camera yaw and pitch for a stage at a given time.
---@param stage TararaPresentationStage
---@param elapsed number Seconds into the stage.
---@param blend number Smoothed progress of the stage transition in [0, 1].
---@return number yaw, number pitch
function Presentation:CameraAt(stage, elapsed, blend)
    local yaw = self.startYaw + Utils.WrapAngle(self.targetYaw - self.startYaw) * blend
    local pitch = self.startPitch + (self.targetPitch - self.startPitch) * blend
    if stage.poses then
        local index, since = ShotAt(stage, elapsed)
        if index > 1 then
            local from, to = stage.poses[index - 1], stage.poses[index]
            local fromYaw, fromPitch = from.yaw or self.targetYaw, from.pitch or self.targetPitch
            local t = Smooth(since / CAMERA_POSE_TIME)
            yaw = fromYaw + Utils.WrapAngle((to.yaw or self.targetYaw) - fromYaw) * t
            pitch = fromPitch + ((to.pitch or self.targetPitch) - fromPitch) * t
        end
    end
    return yaw, pitch
end

--- Advance with scene time; pausing freezes the clock and the character turn.
---@param dt number Elapsed seconds; negative values are ignored.
function Presentation:Update(dt)
    if not self.active or self.app.paused then return end
    self.elapsed = self.elapsed + math.max(dt, 0)
    local stage = assert(Presentation.stages[self.stageIndex])
    while self.elapsed >= stage.duration do
        local remaining = self.elapsed - stage.duration
        self.app:SetHeading(self:PoseAt(stage, stage.duration))
        if self.stageIndex == #Presentation.stages then self.cycles = self.cycles + 1 end
        self:EnterStage(self.stageIndex + 1)
        self.elapsed = remaining
        stage = assert(Presentation.stages[self.stageIndex])
    end
    self.app:SetHeading(self:PoseAt(stage, self.elapsed))
    local studio = self.app.studio
    studio.yaw, studio.pitch = self:CameraAt(stage, self.elapsed, Smooth(self.elapsed / TRANSITION_TIME))
    local expressionIndex = math.min(#stage.expressions, math.floor(self.elapsed / stage.duration * #stage.expressions) + 1)
    if expressionIndex ~= self.expressionIndex then self:ApplyShot(stage, expressionIndex) end
end

--- Describe the current stage for the presentation controls.
---@return string
function Presentation:GetStatus()
    if not self.active then return string.format("%.0f 秒循环 · 手动操作可随时接管", Presentation.duration) end
    return string.format("%s%d / %d · %s", self.app.paused and "已暂停 · " or "", self.stageIndex, #Presentation.stages,
        assert(Presentation.stages[self.stageIndex]).title)
end

return Presentation
