-- One Tarara actor: animation, authored morph targets and secondary motion as independent controls.

-- Material per geometry slot, in the imported merged model's slot order.
local MATERIALS = {
    "Materials/Face.xml", "Materials/Face.xml", "Materials/Eyes.xml", "Materials/EyeWhite.xml",
    "Materials/Hair.xml", "Materials/Hair.xml", "Materials/Hair.xml", "Materials/Hair.xml",
    "Materials/Skin.xml", "Materials/LeatherUpper.xml", "Materials/ClothUpper.xml", "Materials/ClothUpper.xml",
    "Materials/ClothUpper.xml", "Materials/ClothUpper.xml", "Materials/MetalUpper.xml", "Materials/ClothUpper.xml",
    "Materials/LeatherLower.xml", "Materials/MetalLower.xml", "Materials/SkinLower.xml", "Materials/MetalLower.xml",
    "Materials/ClothLower.xml", "Materials/ClothLower.xml", "Materials/LeatherLower.xml", "Materials/InnerCloth.xml",
    "Materials/Ribbon.xml", "Materials/ClothLower.xml", "Materials/ClothLower.xml",
}

---@class TararaMorph
---@field name string Authored channel name in the model.
---@field label string Display name.

---@class TararaExpression
---@field name string
---@field label string
---@field weights table<string, number> Morph channel weights in [0, 1].

---@class TararaClip
---@field name string
---@field label string
---@field path? string Animation resource; nil for the bind pose.

---@class TararaEyes
---@field head Node Parent of both eye bones.
---@field bones Bone[] Eye bones; their animation tracks are disabled so the gaze can drive them.
---@field forward Vector3 Straight ahead in head space.
---@field up Vector3 Character up in head space, at the bind pose.
---@field yaw number Current gaze in degrees.
---@field pitch number

---@class TararaActor
---@field node Node
---@field model AnimatedModel
---@field controller AnimationController
---@field materials Material[]
---@field physics table<string, KawaiiPhysics> Secondary-motion groups by name; empty without simulation.
---@field targets table<string, number> Manual morph targets before intensity.
---@field weights table<string, number> Eased morph weights sent to the model.
---@field autoBlink boolean
---@field eyeContact boolean Whether the eyes follow the viewer passed to Update.
---@field eyes TararaEyes
---@field feet {ankle: Node, toe: Node, ankleHeight: number, toeHeight: number}[] Left then right; heights at the bind pose.
---@field intensity number Expression intensity in [0, 1].
---@field clock number Blink clock in seconds.
---@field speed number Playback multiplier.
---@field animation string Current clip name.
---@field expression string Current preset name, or "custom".
---@field paused boolean
---@field physicsStrength number
---@field rim number Rim-light strength shared by all materials.
---@field opacity number Dithered opacity shared by all materials, in [0, 1].
local Character = {}
Character.__index = Character

Character.OUTLINE_THICKNESS = 0.0025
-- Rim-light strength stored in the w component of every material's toon_rim_color.
Character.RIM_INTENSITY = 4
Character.MAX_RIM_INTENSITY = 12
-- Serialized character: the components Character.Build creates, saved with Character.SavePrefab.
Character.PREFAB = "Prefabs/Tarara.xml"
-- Metres the outline is pushed behind the surface in front of it. It hides the eyebrow outline
-- under the fringe while keeping the outline where an arm crosses the body.
Character.OUTLINE_DEPTH_PUSH = 0.02

---@type TararaMorph[]
Character.morphs = {
    {name = "笑い", label = "笑眼"}, {name = "ウィンク右", label = "右眼俏皮"}, {name = "ウィンク", label = "左眼俏皮"},
    {name = "ワ", label = "开心嘴"}, {name = "まばたき", label = "眨眼"}, {name = "ウィンク２右", label = "右眼闭合"},
    {name = "ウィンク２", label = "左眼闭合"}, {name = "びっくり", label = "惊讶"}, {name = "上", label = "眉毛上扬"},
    {name = "下", label = "眉毛下压"}, {name = "あ", label = "口型 · A"}, {name = "い", label = "口型 · I"},
    {name = "う", label = "口型 · U"}, {name = "え", label = "口型 · E"}, {name = "お", label = "口型 · O"},
}

---@type TararaExpression[]
Character.expressions = {
    {name = "neutral", label = "自然", weights = {}},
    {name = "smile", label = "微笑", weights = {["笑い"] = 0.48, ["ワ"] = 0.5}},
    {name = "wink", label = "俏皮", weights = {["ウィンク"] = 1, ["ワ"] = 0.35}},
    {name = "surprised", label = "惊讶", weights = {["びっくり"] = 0.7, ["お"] = 0.55, ["上"] = 0.35}},
    {name = "happy", label = "元气", weights = {["笑い"] = 1, ["ワ"] = 0.8}},
    {name = "speaking", label = "说话", weights = {["あ"] = 0.55, ["上"] = 0.15}},
    {name = "sad", label = "难过", weights = {["下"] = 0.8, ["え"] = 0.3}},
    {name = "thinking", label = "思考", weights = {["下"] = 0.35, ["う"] = 0.45}},
}

---@type TararaClip[]
Character.clips = {
    {name = "Pose", label = "A-pose"},
    {name = "Idle", label = "待机", path = "Animations/Idle.ani"},
    {name = "Walk", label = "漫步", path = "Animations/Walk.ani"},
    {name = "Run", label = "奔跑", path = "Animations/Run.ani"},
    {name = "Happy", label = "开心", path = "Animations/Happy.ani"},
    {name = "Sad", label = "难过", path = "Animations/Sad.ani"},
    {name = "Think", label = "思考", path = "Animations/Think.ani"},
}

-- Automatic blink: a triangular pulse once per period, damped while the smiling-eyes morph is active.
local BLINK = {channel = "まばたき", suppressedBy = "笑い", period = 3.8, peak = 3.3, halfWidth = 0.09}
-- Morph easing rate; 1 - exp(-dt * rate) of the remaining difference is applied per update.
local MORPH_EASE_RATE = 16
-- Eye contact: both eye bones turn towards the viewer, within degrees of yaw and pitch from straight
-- ahead, easing at the same exponential rate form as the morphs. The limits stay small: past them the
-- iris slides into the corner and reads as a sideways glance. A viewer behind the head recentres them.
local EYES = {head = "Bip001 Head", bones = {"eye_l", "eye_r"}, maxYaw = 16, maxPitch = 8, easeRate = 10}

--- Find an entry by name in one of the definition lists above.
---@generic T
---@param list T[]
---@param name string
---@return T?
local function FindByName(list, name)
    for _, entry in ipairs(list) do
        if entry.name == name then return entry end
    end
    return nil
end

--- Return the expression preset with this name, or nil.
---@param name string
---@return TararaExpression?
function Character.FindExpression(name)
    return FindByName(Character.expressions, name)
end

--- Return the clip with this name, or nil.
---@param name string
---@return TararaClip?
function Character.FindClip(name)
    return FindByName(Character.clips, name)
end

---@class TararaPhysicsGroup
---@field name string
---@field roots string[] Main root first, then additional roots.
---@field damping number
---@field stiffness number
---@field gravity number m/s², applied downwards.
---@field radius number Metres.
---@field limitAngle number Degrees.
---@field dummyBoneLength? number Metres; virtual tip length for chain ends.
---@field stiffnessCurve number[] Stiffness multiplier at the chain root and tip.
---@field worldDamping number[] Share of character movement and rotation ignored.

-- Every skirt sector except the two long ribbons (a and i), each an independent chain.
local SKIRT_ROOTS = {}
for letter = string.byte("b"), string.byte("v") do
    if letter ~= string.byte("i") then SKIRT_ROOTS[#SKIRT_ROOTS + 1] = "skirt_" .. string.char(letter) .. "_01" end
end

-- Secondary-motion groups. Damping, stiffness and radius are the KawaiiPhysics base values.
-- Radius is the particle thickness that collides with the body proxies.
---@type TararaPhysicsGroup[]
local PHYSICS_GROUPS = {
    -- The ponytail holds firm near the head and softens steadily towards the tip.
    {name = "hair", roots = {"hair_h_01"}, damping = 0.17, stiffness = 0.2, gravity = 1.5, radius = 0.026, limitAngle = 45,
        stiffnessCurve = {1, 0.2}, worldDamping = {0.5, 0.25},
        -- The last bone has no child, so without a virtual tip it keeps its animated rotation and the end stays rigid.
        dummyBoneLength = 0.12},
    {name = "locks", roots = {"hair_a_01", "hair_b_01", "hair_c_01", "hair_d_01", "hair_e_01", "hair_f_01", "hair_g_01"},
        damping = 0.2, stiffness = 0.3, gravity = 0.5, radius = 0.015, limitAngle = 22, dummyBoneLength = 0.025,
        stiffnessCurve = {1, 0.55}, worldDamping = {0.5, 0.35}},
    -- The authored ribbon mesh extends about 20 cm beyond its last real bone.
    {name = "ribbons", roots = {"skirt_a_01", "skirt_i_01"}, damping = 0.12, stiffness = 0.055, gravity = 0.6, radius = 0.04,
        limitAngle = 65, dummyBoneLength = 0.20, stiffnessCurve = {1, 0.55}, worldDamping = {0.7, 0.65}},
    -- Short panels: a soft pose pull with light damping lets them bounce when the body turns,
    -- and a 45° limit stops an arm from flicking them away.
    {name = "skirt", roots = SKIRT_ROOTS, damping = 0.3, stiffness = 0.12, gravity = 1.5, radius = 0.03, limitAngle = 45,
        dummyBoneLength = 0.10, stiffnessCurve = {1, 0.6}, worldDamping = {0.5, 0.25}},
}

-- Collision proxies. The skeleton root carries the source 0.01 scale, so offsets are in the
-- driving bone's local centimetres while radius and length are in metres.
local THIGH_RADIUS = 0.11 -- Measured skin radius 10.2 cm plus clothing clearance.
local THIGH_LENGTH_SCALE = 0.68 -- Covers the thigh between hip and knee joints.
-- Upper arm, forearm and palm per side: {bone, tip bone, radius, reach beyond the tip bone}.
-- Radii follow the skin; the right forearm adds its sleeve. The palm proxy reaches towards the fingers.
local ARM_SEGMENTS = {
    L = {{"UpperArm", "Forearm", 0.04, 1}, {"Forearm", "Hand", 0.03, 1}, {"Hand", "Finger2", 0.03, 1.3}},
    R = {{"UpperArm", "Forearm", 0.04, 1}, {"Forearm", "Hand", 0.045, 1}, {"Hand", "Finger2", 0.03, 1.3}},
}
-- Head sphere for the hair, 10 cm along the head bone's local X axis.
local HEAD_SPHERE = {bone = "Bip001 Head", offset = Vector3(-10, 0, 0), radius = 0.10}
-- Front skirt panels follow the knees: forward knee movement moves them before the thigh capsules
-- have to push. The centre panels follow both knees.
local FRONT_SKIRT_SYNC = {
    {source = "Bip001 L Calf", targets = {"skirt_f_01", "skirt_q_01", "skirt_o_01", "skirt_v_01"}},
    {source = "Bip001 R Calf", targets = {"skirt_d_01", "skirt_m_01", "skirt_o_01", "skirt_v_01"}},
}
local FRONT_SKIRT_SYNC_SCALE = 0.3
-- Simulation iterations used when the dynamics warm up after a reset or teleport.
local PHYSICS_WARM_UP_FRAMES = 12
-- Per-frame character movement and rotation (degrees) treated as a teleport rather than motion.
local TELEPORT_DISTANCE, TELEPORT_ANGLE = 2, 65

---@param root number Curve value at the chain root.
---@param tip number Curve value at the chain tip.
---@return FloatCurve
local function LinearRamp(root, tip)
    local curve = FloatCurve()
    curve:AddKey(FloatCurveKey(0, root, FLOAT_CURVE_CUBIC))
    curve:AddKey(FloatCurveKey(1, tip, FLOAT_CURVE_CUBIC))
    return curve
end

--- Create one KawaiiPhysics component from a PHYSICS_GROUPS entry.
---@param node Node
---@param group TararaPhysicsGroup
---@return KawaiiPhysics
local function CreatePhysics(node, group)
    local physics = node:CreateComponent("KawaiiPhysics")
    physics:SetRootBoneName(group.roots[1])
    for i = 2, #group.roots do
        local root = KawaiiPhysicsRootBoneSetting()
        root.rootBone = group.roots[i]
        physics:AddAdditionalRootBone(root)
    end
    local settings = physics:GetPhysicsSettings()
    settings.damping, settings.stiffness = group.damping, group.stiffness
    settings.worldDampingLocation, settings.worldDampingRotation = group.worldDamping[1], group.worldDamping[2]
    settings.radius, settings.limitAngle = group.radius, group.limitAngle
    physics:SetPhysicsSettings(settings)
    physics:SetBoneForwardAxis(KAWAII_PHYSICS_BONE_FORWARD_X_NEGATIVE)
    physics:SetStiffnessCurveData(LinearRamp(group.stiffnessCurve[1], group.stiffnessCurve[2]))
    physics:SetGravity(Vector3(0, -group.gravity, 0))
    physics:SetDummyBoneLength(group.dummyBoneLength or 0)
    physics:SetWarmUpFrames(PHYSICS_WARM_UP_FRAMES)
    physics:SetTeleportDistanceThreshold(TELEPORT_DISTANCE)
    physics:SetTeleportRotationThreshold(TELEPORT_ANGLE)
    return physics
end

--- Build a capsule along a driving bone towards a local offset.
---@param bone Bone
---@param offset Vector3 Capsule end in the bone's local units.
---@param radius number Metres.
---@param length number Metres between the cap centres.
---@return KawaiiPhysicsCapsuleLimit
local function BoneCapsule(bone, offset, radius, length)
    local limit = KawaiiPhysicsCapsuleLimit()
    limit.drivingBone = bone.name
    limit.offsetLocation = offset * 0.5
    limit.offsetRotation = Quaternion(Vector3.FORWARD, offset:Normalized())
    limit.radius, limit.length = radius, length
    return limit
end

--- Add thigh and arm capsules to the skirt and ribbon groups and the head sphere to both hair groups.
--- Capsules are added in a fixed order: both thighs, then the six arm proxies.
---@param skeleton Skeleton
---@param physics table<string, KawaiiPhysics>
local function AddCollision(skeleton, physics)
    local limits = {}
    for _, side in ipairs({"L", "R"}) do
        local prefix = "Bip001 " .. side .. " "
        local thigh, calf = skeleton:GetBone(prefix .. "Thigh"), skeleton:GetBone(prefix .. "Calf")
        local thighLength = (calf.node.worldPosition - thigh.node.worldPosition):Length()
        limits[#limits + 1] = BoneCapsule(thigh, calf.initialPosition, THIGH_RADIUS, thighLength * THIGH_LENGTH_SCALE)
    end
    -- Arm proxies follow the authored animation, so only the skirt yields.
    for _, side in ipairs({"L", "R"}) do
        local prefix = "Bip001 " .. side .. " "
        for _, segment in ipairs(ARM_SEGMENTS[side]) do
            local bone, tip = skeleton:GetBone(prefix .. segment[1]), skeleton:GetBone(prefix .. segment[2])
            local radius, offset = segment[3], tip.initialPosition * segment[4]
            local length = (bone.node.worldTransform * offset - bone.node.worldPosition):Length()
            limits[#limits + 1] = BoneCapsule(bone, offset, radius, math.max(0.01, length - radius))
        end
    end
    for _, group in ipairs({physics.ribbons, physics.skirt}) do
        for _, limit in ipairs(limits) do group:AddCapsuleLimit(limit) end
    end
    local head = KawaiiPhysicsSphericalLimit()
    head.drivingBone, head.offsetLocation, head.radius = HEAD_SPHERE.bone, HEAD_SPHERE.offset, HEAD_SPHERE.radius
    physics.hair:AddSphericalLimit(head)
    physics.locks:AddSphericalLimit(head)
end

--- Let the front skirt panels follow the knees. Movement is taken in component space against the
--- bind pose; only forward (+Z) movement is applied, so the panels do not float upwards.
---@param skirt KawaiiPhysics
local function AddFrontSkirtSync(skirt)
    for _, entry in ipairs(FRONT_SKIRT_SYNC) do
        local sync = KawaiiPhysicsSyncBone()
        sync.bone = entry.source
        sync.globalScale = Vector3(1, 1, 1) * FRONT_SKIRT_SYNC_SCALE
        sync.applyDirectionX = KAWAII_PHYSICS_SYNC_BONE_DIRECTION_NONE
        sync.applyDirectionY = KAWAII_PHYSICS_SYNC_BONE_DIRECTION_NONE
        sync.applyDirectionZ = KAWAII_PHYSICS_SYNC_BONE_DIRECTION_POSITIVE
        for _, bone in ipairs(entry.targets) do
            local target = KawaiiPhysicsSyncTargetRoot()
            target.bone = bone
            sync:AddTargetRoot(target)
        end
        skirt:AddSyncBone(sync)
    end
end

--- Take the eye bones off the animation and record the head-space axes the gaze turns about.
--- Call while the skeleton is still in its bind pose.
---@param node Node Character root; the model faces its +Z axis.
---@param skeleton Skeleton
---@return TararaEyes
local function CreateEyes(node, skeleton)
    local head = skeleton:GetBone(EYES.head).node
    local toHead = head.worldRotation:Inverse() * node.worldRotation
    local bones = {}
    for _, name in ipairs(EYES.bones) do
        local bone = assert(skeleton:GetBone(name), "Missing eye bone: " .. name)
        bone.animated = false
        bones[#bones + 1] = bone
    end
    return {head = head, bones = bones, forward = toHead * Vector3.FORWARD, up = toHead * Vector3.UP, yaw = 0, pitch = 0}
end

--- Find the ankle and toe bones of both feet and record their bind-pose heights above the sole.
--- Call while the skeleton is still in its bind pose with the character on the ground.
---@param skeleton Skeleton
---@return {ankle: Node, toe: Node, ankleHeight: number, toeHeight: number}[] feet Left then right.
local function FindFeet(skeleton)
    local feet = {}
    for _, side in ipairs({"L", "R"}) do
        local ankle = assert(skeleton:GetBone("Bip001 " .. side .. " Foot"), "Missing foot bone").node
        local toe = assert(skeleton:GetBone("Bip001 " .. side .. " Toe0"), "Missing toe bone").node
        feet[#feet + 1] = {ankle = ankle, toe = toe, ankleHeight = ankle.worldPosition.y, toeHeight = toe.worldPosition.y}
    end
    return feet
end

--- Head-space rotation of the current gaze: yaw about up, then pitch about the turned right axis.
---@param eyes TararaEyes
---@return Quaternion
local function GazeTurn(eyes)
    return Quaternion(eyes.yaw, eyes.up) * Quaternion(-eyes.pitch, eyes.up:CrossProduct(eyes.forward))
end

--- Build the character node in Lua: model, materials, animation controller and secondary motion.
--- This is the construction that assets/Prefabs/Tarara.xml stores (see Character.SavePrefab).
---@param scene Scene
---@param name string Node name.
---@return Node
function Character.Build(scene, name)
    local node = scene:CreateChild(name)
    local model = node:CreateComponent("AnimatedModel")
    -- Bone nodes copy the model's temporary flag, so the prefab omits them; loading recreates them.
    model.temporary = true
    model.model = cache:GetResource("Model", "Models/Tarara.mdl")
    model.temporary = false
    assert(model.model ~= nil, "Tarara model is missing")
    model.castShadows = false
    model:SetUpdateInvisible(true)
    for i, path in ipairs(MATERIALS) do
        local material = cache:GetResource("Material", path)
        assert(material ~= nil, "Missing material: " .. path)
        model:SetMaterial(i - 1, material)
    end
    node:CreateComponent("AnimationController")
    local physics = {}
    for _, group in ipairs(PHYSICS_GROUPS) do physics[group.name] = CreatePhysics(node, group) end
    AddCollision(model.skeleton, physics)
    AddFrontSkirtSync(physics.skirt)
    return node
end

--- Write a node made by Character.Build as prefab XML into the script's save data.
---@param node Node
---@param path string Path relative to save data; scripts cannot write elsewhere.
---@return string? fileName The file written, or nil on failure.
function Character.SavePrefab(node, path)
    local file = File(path, FILE_WRITE)
    if not file or not file:IsOpen() then return nil end
    local saved, fileName = node:SaveXML(file), file:GetName()
    file:Close()
    return saved and fileName or nil
end

--- Create the character from Lua code; see Character.Build.
---@param scene Scene
---@param name string Node name.
---@return TararaActor
function Character.Create(scene, name)
    return Character.Attach(Character.Build(scene, name))
end

--- Create the character from the serialized prefab, which holds the same components as Character.Build.
---@param scene Scene
---@param name string Node name.
---@return TararaActor
function Character.Load(scene, name)
    local node = scene:InstantiateXML(Character.PREFAB, Vector3.ZERO, Quaternion.IDENTITY, LOCAL)
    assert(node ~= nil, "Missing prefab: " .. Character.PREFAB)
    node.name = name
    return Character.Attach(node)
end

--- Drive a node made by Character.Build or loaded from the prefab. The outline is not serialized,
--- so it is applied here; eye contact, blinking and morph easing are runtime state.
---@param node Node Character root in its bind pose.
---@return TararaActor
function Character.Attach(node)
    local self = setmetatable({}, Character)
    self.node = node
    self.model = assert(node:GetComponent("AnimatedModel"), "Character node has no AnimatedModel")
    self.controller = assert(node:GetComponent("AnimationController"), "Character node has no AnimationController")
    self.model:SetOutlineEnabled(true)
    self.model:SetOutlineThickness(Character.OUTLINE_THICKNESS)
    self.model:SetOutlineZBias(Character.OUTLINE_DEPTH_PUSH)
    self.model:SetOutlineColor(Color(0, 0, 0, 0.4))
    -- Each character gets its own material copies, so fading or rim changes stay on it; slots that
    -- shared a material share its copy. A copy keeps its source name, so a saved node still
    -- references the material file.
    self.materials = {}
    local copies = {}
    for i = 1, self.model.numGeometries do
        local source = self.model:GetMaterial(i - 1)
        copies[source] = copies[source] or source:Clone(source.name)
        self.materials[i] = copies[source]
        self.model:SetMaterial(i - 1, copies[source])
    end
    self.rim = Character.RIM_INTENSITY
    self.opacity = 1
    -- Components keep their creation order, so the groups match PHYSICS_GROUPS one to one.
    self.physics = {}
    local components = node:GetComponents("KawaiiPhysics")
    for i, group in ipairs(PHYSICS_GROUPS) do self.physics[group.name] = components[i] end
    -- Start from the bind pose; the caller selects a clip.
    self.animation = "Pose"
    self.targets, self.weights = {}, {}
    self.expression = "neutral"
    self.intensity, self.speed, self.physicsStrength = 1, 1, 1
    self.autoBlink, self.paused = true, false
    self.eyeContact = true
    self.eyes = CreateEyes(node, self.model.skeleton)
    self.feet = FindFeet(self.model.skeleton)
    self.clock = 0
    self:Reset()
    return self
end

--- Return the physics groups in creation order.
---@return KawaiiPhysics[]
function Character:GetPhysicsGroups()
    local groups = {}
    for _, group in ipairs(PHYSICS_GROUPS) do groups[#groups + 1] = self.physics[group.name] end
    return groups
end

--- Restore the bind pose, or cross-fade a clip from Character.clips.
---@param name string Clip name.
function Character:Play(name)
    local clip = assert(Character.FindClip(name), "Unknown clip: " .. tostring(name))
    self.animation = name
    if not clip.path then
        self.controller:StopAll(0)
        self.model:RemoveAllAnimationStates()
        local skeleton = self.model.skeleton
        for i = 0, skeleton.numBones - 1 do
            local bone = skeleton:GetBone(i)
            bone.node:SetTransform(bone.initialPosition, bone.initialRotation, bone.initialScale)
        end
        self:Reset()
        return
    end
    assert(cache:GetResource("Animation", clip.path) ~= nil, "Missing animation: " .. clip.path)
    self.controller:PlayExclusive(clip.path, 0, true, self.paused and 0 or 0.25)
    self.controller:SetTime(clip.path, 0)
    self:SetSpeed(self.speed)
end

--- Set the playback multiplier; a paused actor keeps speed zero until resumed.
---@param value number
function Character:SetSpeed(value)
    self.speed = value
    local clip = Character.FindClip(self.animation)
    if clip and clip.path then self.controller:SetSpeed(clip.path, self.paused and 0 or value) end
end

--- Freeze or resume animation playback, morph easing and the blink clock. Scene time scale
--- pauses the physics separately.
---@param value boolean
function Character:SetPaused(value)
    self.paused = value
    self:SetSpeed(self.speed)
end

--- Replace all manual morph targets with a preset; Update eases the change.
---@param name string Preset name from Character.expressions.
function Character:SetExpression(name)
    local preset = assert(Character.FindExpression(name), "Unknown expression: " .. tostring(name))
    self.expression = name
    self.targets = {}
    for channel, weight in pairs(preset.weights) do self.targets[channel] = weight end
end

--- Set one channel without clearing the other morph targets.
---@param name string Authored channel name from Character.morphs.
---@param value number Target weight in [0, 1], before expression intensity.
function Character:SetMorph(name, value)
    self.expression = "custom"
    self.targets[name] = value
end

--- Blend every secondary-motion group with the animation pose.
---@param value number Alpha in [0, 1]; zero restores the animation output.
function Character:SetPhysics(value)
    self.physicsStrength = value
    for _, physics in pairs(self.physics) do physics:SetAlpha(value) end
end

--- Reinitialize particle history from the animation on the next evaluation.
function Character:Reset()
    for _, physics in pairs(self.physics) do physics:ResetDynamics() end
end

--- Ease the gaze towards the viewer, or back to straight ahead, and pose both eye bones.
---@param dt number Elapsed seconds.
---@param viewer? Vector3 World position to look at; nil recentres the eyes.
function Character:UpdateEyes(dt, viewer)
    local eyes = self.eyes
    local yaw, pitch = 0, 0
    if viewer then
        -- Gaze in head space from the midpoint between the eyes.
        local between = eyes.bones[1].node.worldPosition:Lerp(eyes.bones[2].node.worldPosition, 0.5)
        local gaze = (eyes.head.worldRotation:Inverse() * (viewer - between)):Normalized()
        local right = eyes.up:CrossProduct(eyes.forward)
        local ahead = gaze:DotProduct(eyes.forward)
        if ahead > 0 then
            yaw = math.max(-EYES.maxYaw, math.min(EYES.maxYaw, math.deg(math.atan(gaze:DotProduct(right), ahead))))
            pitch = math.max(-EYES.maxPitch, math.min(EYES.maxPitch, math.deg(math.asin(gaze:DotProduct(eyes.up)))))
        end
    end
    local blend = 1 - math.exp(-dt * EYES.easeRate)
    eyes.yaw = eyes.yaw + (yaw - eyes.yaw) * blend
    eyes.pitch = eyes.pitch + (pitch - eyes.pitch) * blend
    -- Yaw about the head's up axis, then pitch about the turned right axis; applied in head space.
    local turn = GazeTurn(eyes)
    for _, bone in ipairs(eyes.bones) do bone.node.rotation = turn * bone.initialRotation end
end

--- Return the current gaze direction in world space.
---@return Vector3
function Character:GetGaze()
    return self.eyes.head.worldRotation * (GazeTurn(self.eyes) * self.eyes.forward)
end

--- Return the animated head bone node, for cameras that frame the face.
---@return Node
function Character:GetHead()
    return self.eyes.head
end

--- Return where each foot meets the ground, for a floor contact shadow. Heights are relative to
--- the sole, so a planted foot reads zero.
---@return {heel: Vector3, toe: Vector3}[] feet Left then right foot, world positions.
function Character:GetContactPoints()
    local feet = {}
    for i, foot in ipairs(self.feet) do
        feet[i] = {
            heel = foot.ankle.worldPosition - Vector3(0, foot.ankleHeight, 0),
            toe = foot.toe.worldPosition - Vector3(0, foot.toeHeight, 0),
        }
    end
    return feet
end

--- Ease morph weights and add the automatic blink; call once per scene Update.
---@param dt number Elapsed seconds.
---@param viewer? Vector3 World position the eyes follow while eyeContact is on.
function Character:Update(dt, viewer)
    if self.paused then return end
    self:UpdateEyes(dt, self.eyeContact and viewer or nil)
    self.clock = self.clock + dt
    local blink = 0
    if self.autoBlink then
        local phase = self.clock % BLINK.period
        blink = math.max(0, 1 - math.abs(phase - BLINK.peak) / BLINK.halfWidth) * (1 - (self.targets[BLINK.suppressedBy] or 0))
    end
    local blend = 1 - math.exp(-dt * MORPH_EASE_RATE)
    for _, morph in ipairs(Character.morphs) do
        local target = (self.targets[morph.name] or 0) * self.intensity
        if morph.name == BLINK.channel then target = math.max(target, blink) end
        local weight = self.weights[morph.name] or 0
        weight = weight + (target - weight) * blend
        self.weights[morph.name] = weight
        self.model:SetMorphWeight(morph.name, weight)
    end
end

--- Set the rim-light strength on every material, keeping each rim color. Face materials have no rim.
---@param value number Strength in [0, Character.MAX_RIM_INTENSITY].
function Character:SetRim(value)
    self.rim = math.min(math.max(value, 0), Character.MAX_RIM_INTENSITY)
    for _, material in ipairs(self.materials) do
        local rim = material:GetShaderParameter("toon_rim_color"):GetVector4()
        material:SetShaderParameter("toon_rim_color", Variant(Vector4(rim.x, rim.y, rim.z, self.rim)))
    end
end

--- Fade the character by dithering every material; 1 is opaque, 0 is invisible.
---@param value number Opacity in [0, 1].
function Character:SetOpacity(value)
    self.opacity = math.min(math.max(value, 0), 1)
    for _, material in ipairs(self.materials) do
        material:SetShaderParameter("dither_opacity", Variant(self.opacity))
    end
end

--- Map each hair and skirt chain end to its group's virtual tip length.
---@param character TararaActor
---@return table<integer, number> tipLengths Metres, keyed by bone index.
local function ChainTipLengths(character)
    local skeleton = character.model.skeleton
    local rootLength, hasChild = {}, {}
    for _, group in ipairs(PHYSICS_GROUPS) do
        local length = character.physics[group.name]:GetDummyBoneLength()
        for _, root in ipairs(group.roots) do rootLength[root] = length end
    end
    for i = 0, skeleton.numBones - 1 do hasChild[skeleton:GetBone(i).parentIndex] = true end
    local tips = {}
    for i = 0, skeleton.numBones - 1 do
        local index = i
        if not hasChild[i] then
            -- Walk up from the chain end until a group root is found.
            while index ~= nil do
                local bone = skeleton:GetBone(index)
                local length = rootLength[bone.name]
                if length then
                    if length > 0 then tips[i] = length end
                    break
                end
                index = bone.parentIndex ~= index and bone.parentIndex or nil
            end
        end
    end
    return tips
end

--- Draw the simulated hair and skirt chains as they are skinned, including each virtual tip;
--- call from PostRenderUpdate.
---@param debug DebugRenderer
function Character:DrawBones(debug)
    local skeleton = self.model.skeleton
    local color, tipColor = Color(0.0, 0.85, 0.8), Color(1.0, 0.75, 0.2)
    self.chainTips = self.chainTips or ChainTipLengths(self)
    local function IsChain(bone)
        return bone.name:find("hair_", 1, true) or bone.name:find("skirt_", 1, true)
    end
    for i = 0, skeleton.numBones - 1 do
        local bone = skeleton:GetBone(i)
        if IsChain(bone) then
            local transform = bone:GetFinalWorldTransform()
            local position = transform:Translation()
            local parent = skeleton:GetBone(bone.parentIndex)
            -- The link from the pelvis or head to a chain root is not part of the chain.
            if IsChain(parent) then debug:AddLine(parent:GetFinalWorldTransform():Translation(), position, color, false) end
            local tip = self.chainTips[i]
            if tip then
                -- The virtual tip extends along the bone's forward axis, -X.
                local forward = (transform * Vector3(-1, 0, 0) - position):Normalized()
                debug:AddLine(position, position + forward * tip, tipColor, false)
            end
        end
    end
end

return Character
