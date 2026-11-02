-- A restrained photographic stage keeps the character and its shading readable.
local Utils = require("Utils")

---@class TararaStage
---@field scene Scene
---@field zone Zone
---@field debug DebugRenderer
---@field camera Camera
---@field cameraNode Node
---@field stageNode Node
---@field stageMaterial Material
---@field contactNode Node Floor patch under the feet; see SetContactPoints.
---@field contactMaterial Material
---@field backdrop {hue: number, saturation: number, brightness: number} Backdrop tint; see SetBackdrop.
---@field light Light
---@field focus Vector3
---@field targetFocus Vector3
---@field yaw number Camera yaw in degrees.
---@field pitch number Camera pitch in degrees.
---@field distance number
---@field targetDistance number
---@field lightYaw number Degrees in [-180, 180).
---@field lightElevation number Degrees in [-80, 80].
---@field framing string "full" or "face".
---@field followNode? Node Node the focus follows, if any.
---@field followOffset Vector3
---@field compact boolean Narrow layout: the camera backs off and shifts up for the bottom panel.
local Studio = {}
Studio.__index = Studio

Studio.DEFAULT_LIGHT = {color = Color(1, 242 / 255, 232 / 255), brightness = 1, yaw = 50, elevation = 25}
-- Stage color multiplier as hue (degrees), saturation and brightness. Zero saturation and full
-- brightness keep the painted stage colors.
Studio.DEFAULT_BACKDROP = {hue = 0, saturation = 0, brightness = 1}
Studio.MAX_LIGHT_BRIGHTNESS = 3
Studio.LIGHT_ELEVATION_LIMIT = 80

-- Metres from the character to the back wall, and the width and height of the stage.
local STAGE_WALL_DISTANCE, STAGE_SIZE = 3.0, 40
-- Radius in metres of the curve joining floor and wall, and the steps it is built from.
local STAGE_COVE_RADIUS, STAGE_COVE_SEGMENTS = 1.5, 24
-- The contact patch reaches three sheen radii (0.22 m in StudioContact.shader) past the feet,
-- where the sheen has faded below 0.02%, and floats just above the floor to avoid z-fighting.
local CONTACT_MARGIN, CONTACT_LIFT = 0.66, 0.002

-- Camera targets for each framing: focus point, distance, yaw and pitch. Both look straight at the
-- character's front, so the default heading of 0 faces the camera.
local FRAMINGS = {
    full = {focus = Vector3(0, 1.1, 0), distance = 5.4, yaw = 0, pitch = 6},
    face = {focus = Vector3(0, 1.73, 0), distance = 1.7, yaw = 0, pitch = 1},
}
-- In the compact layout the camera backs off and shifts the image up, clear of the bottom panel.
local COMPACT_DISTANCE_SCALE = 1.5
local COMPACT_PROJECTION_OFFSET = {full = 0.18, face = 0.12}
local CAMERA_EASE_RATE = 7
local MIN_DISTANCE, MAX_DISTANCE, ZOOM_STEP = 0.8, 7, 0.25

--- Create the dark infinity cove: one mesh running from the floor, round a curved corner and up
--- the back wall, so no crease shows where they meet. The texture V coordinate is the distance
--- along the surface from the middle of the curve (up the wall positive, out across the floor
--- negative) and U is the distance across, both in metres; the stage shader lays its glows out
--- in these coordinates. It is unlit, so it does not change the character lighting.
---@param scene Scene
---@return Node node Stage root; Update turns it to face the camera.
---@return Material material Stage material; see SetBackdrop.
local function CreateStage(scene)
    local material = Material()
    assert(material:SetSurfaceShader("Shaders/BLGL/StudioStage.shader"))
    -- Profile in the stage's local (z, y) plane: floor towards the camera, quarter circle, wall.
    local radius = STAGE_COVE_RADIUS
    local cornerZ = -STAGE_WALL_DISTANCE + radius
    local profile = {{z = STAGE_SIZE * 0.5, y = 0, normal = Vector3.UP}}
    for i = 0, STAGE_COVE_SEGMENTS do
        local angle = i / STAGE_COVE_SEGMENTS * math.pi * 0.5
        local z, y = cornerZ - radius * math.sin(angle), radius - radius * math.cos(angle)
        profile[#profile + 1] = {z = z, y = y, normal = Vector3(0, math.cos(angle), math.sin(angle))}
    end
    profile[#profile + 1] = {z = -STAGE_WALL_DISTANCE, y = STAGE_SIZE * 0.5, normal = Vector3(0, 0, 1)}
    -- Distance along the surface, then shifted so the middle of the curve is zero.
    local length = 0
    profile[1].v = 0
    for i = 2, #profile do
        length = length + Vector2(profile[i].z - profile[i - 1].z, profile[i].y - profile[i - 1].y):Length()
        profile[i].v = length
    end
    -- Profile entries 2 onwards are the curve, so this is its middle point.
    local middle = profile[STAGE_COVE_SEGMENTS // 2 + 2].v
    local stage = scene:CreateChild("Stage")
    local geometry = stage:CreateComponent("CustomGeometry")
    geometry:BeginGeometry(0, TRIANGLE_LIST)
    local halfWidth = STAGE_SIZE * 0.5
    local function Vertex(point, x)
        geometry:DefineVertex(Vector3(x, point.y, point.z))
        geometry:DefineNormal(point.normal)
        geometry:DefineTexCoord(Vector2(x, point.v - middle))
    end
    for i = 1, #profile - 1 do
        local near, far = profile[i], profile[i + 1]
        -- Two triangles per profile step, wound so their front faces the camera side.
        Vertex(near, -halfWidth); Vertex(far, halfWidth); Vertex(far, -halfWidth)
        Vertex(near, -halfWidth); Vertex(near, halfWidth); Vertex(far, halfWidth)
    end
    geometry:Commit()
    geometry:SetMaterial(material)
    geometry.castShadows = false
    return stage, material
end

--- Create the floor patch that carries the contact shadow and sheen: a unit square in the world
--- XZ plane that SetContactPoints moves and scales to cover the feet each frame.
---@param scene Scene
---@return Node node, Material material
local function CreateContactPatch(scene)
    local material = Material()
    assert(material:SetSurfaceShader("Shaders/BLGL/StudioContact.shader"))
    local node = scene:CreateChild("ContactPatch")
    local geometry = node:CreateComponent("CustomGeometry")
    geometry:BeginGeometry(0, TRIANGLE_LIST)
    local corners = {Vector3(-0.5, 0, 0.5), Vector3(0.5, 0, -0.5), Vector3(-0.5, 0, -0.5),
        Vector3(-0.5, 0, 0.5), Vector3(0.5, 0, 0.5), Vector3(0.5, 0, -0.5)}
    for _, corner in ipairs(corners) do
        geometry:DefineVertex(corner)
        geometry:DefineNormal(Vector3.UP)
    end
    geometry:Commit()
    geometry:SetMaterial(material)
    geometry.castShadows = false
    return node, material
end

--- Load the built-in daytime environment and tune it for the Toon character.
---@param scene Scene
---@return Zone zone, Light light
local function CreateEnvironment(scene)
    local environment = scene:CreateChild("Environment")
    environment:LoadXML(cache:GetResource("XMLFile", "LightGroup/Daytime.xml"):GetRoot())
    local zone = environment:GetComponent("Zone")
    -- The Toon main-light cap is stored in gamma space; match the linear brightness slider range.
    local toon = zone:GetToonShadingParams()
    local mainLightLimit = Studio.MAX_LIGHT_BRIGHTNESS ^ (1 / 2.2)
    toon.mainLightMaxContribution = Color(mainLightLimit, mainLightLimit, mainLightLimit)
    zone:SetToonShadingParams(toon)
    -- The horizon haze is painted into the backdrop cubemap, so it looks the same on both pipelines.
    zone.depthFogEnable = false
    zone:SetTonemapMode(TONEMAP_MODE_NONE)
    zone.envTextureDiffIntensity = 0.3
    zone:SetAttribute("Bloom Enable", Variant(true))
    zone:SetBloomPlusEnabled(true)
    zone:SetBloomPlusIntensity(1)
    zone:SetBloomThreshold(1)
    zone:SetBloomWeight(0.25)
    local light = environment:GetComponent("Light", true)
    -- Plain brightness units and an explicit color, without physical units or temperature.
    -- "Light Units" has no Lua property; an integer attribute needs a typed Variant.
    light:SetAttribute("Light Units", Variant(VAR_INT, "0"))
    light.useTemperature = false
    light.castShadows = false
    return zone, light
end

--- Create the stage, environment and active viewport in the supplied scene.
---@param scene Scene
---@return TararaStage
function Studio.Create(scene)
    local self = setmetatable({}, Studio)
    self.scene = scene
    scene:CreateComponent("Octree")
    self.debug = scene:CreateComponent("DebugRenderer")
    self.zone, self.light = CreateEnvironment(scene)
    self.stageNode, self.stageMaterial = CreateStage(scene)
    self.contactNode, self.contactMaterial = CreateContactPatch(scene)
    self:ResetLight()

    self.cameraNode = scene:CreateChild("Camera")
    self.camera = self.cameraNode:CreateComponent("Camera")
    self.camera.fov = 30
    self.camera.nearClip, self.camera.farClip = 0.05, 60
    renderer:SetViewport(0, Viewport(scene, self.camera))
    self.compact = false
    self:SetFraming("full")
    self.focus, self.distance = self.targetFocus, self.targetDistance
    self:Update(0)
    return self
end

--- Restore the default main light (color, intensity and both angles) and stage tint.
function Studio:ResetLight()
    local preset = Studio.DEFAULT_LIGHT
    self.light.color = preset.color
    self.light.brightness = preset.brightness
    self:SetLightAngles(preset.yaw, preset.elevation)
    self:SetBackdrop(Studio.DEFAULT_BACKDROP)
end

--- Tint the whole stage by multiplying its colors with one HSV color; omitted fields keep their values.
---@param backdrop {hue?: number, saturation?: number, brightness?: number} Hue in degrees, the rest in [0, 1].
function Studio:SetBackdrop(backdrop)
    local current = self.backdrop or Studio.DEFAULT_BACKDROP
    local function Unit(value) return math.min(math.max(value, 0), 1) end
    self.backdrop = {
        hue = (backdrop.hue or current.hue) % 360,
        saturation = Unit(backdrop.saturation or current.saturation),
        brightness = Unit(backdrop.brightness or current.brightness),
    }
    local tint = Color()
    tint:FromHSV(self.backdrop.hue / 360, self.backdrop.saturation, self.backdrop.brightness, 1)
    self.stageMaterial:SetShaderParameter("backdrop_tint", Variant(tint))
    self.contactMaterial:SetShaderParameter("backdrop_tint", Variant(tint))
end

--- Place the floor contact shadow under the feet; call once per frame.
---@param feet {heel: Vector3, toe: Vector3}[] Left then right foot, world positions on the sole.
function Studio:SetContactPoints(feet)
    local material = self.contactMaterial
    material:SetShaderParameter("left_heel", Variant(feet[1].heel))
    material:SetShaderParameter("left_toe", Variant(feet[1].toe))
    material:SetShaderParameter("right_heel", Variant(feet[2].heel))
    material:SetShaderParameter("right_toe", Variant(feet[2].toe))
    -- Cover both feet in the floor plane, plus the reach of the sheen.
    local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
    for _, foot in ipairs(feet) do
        for _, point in ipairs({foot.heel, foot.toe}) do
            minX, maxX = math.min(minX, point.x), math.max(maxX, point.x)
            minZ, maxZ = math.min(minZ, point.z), math.max(maxZ, point.z)
        end
    end
    self.contactNode.position = Vector3((minX + maxX) * 0.5, CONTACT_LIFT, (minZ + maxZ) * 0.5)
    self.contactNode.scale = Vector3(maxX - minX + 2 * CONTACT_MARGIN, 1, maxZ - minZ + 2 * CONTACT_MARGIN)
end

--- Point the main directional light; yaw wraps and elevation is clamped.
---@param yaw number Degrees around the vertical axis.
---@param elevation number Degrees above the horizon.
function Studio:SetLightAngles(yaw, elevation)
    local limit = Studio.LIGHT_ELEVATION_LIMIT
    self.lightYaw = Utils.WrapAngle(yaw)
    self.lightElevation = math.max(-limit, math.min(limit, elevation))
    local y, e = math.rad(self.lightYaw), math.rad(self.lightElevation)
    self.light.node:SetWorldDirection(Vector3(-math.sin(y) * math.cos(e), -math.sin(e), -math.cos(y) * math.cos(e)))
end

--- Ease the camera towards a framing without changing animation, morphs or physics.
---@param framing string "full" or "face".
function Studio:SetFraming(framing)
    local target = assert(FRAMINGS[framing], "Unknown framing: " .. tostring(framing))
    self.framing = framing
    self.targetFocus, self.targetDistance = Vector3(target.focus), target.distance
    self.yaw, self.pitch = target.yaw, target.pitch
    self.followNode = nil
end

--- Keep easing the focus towards a moving node, such as the head during a close-up.
---@param node? Node Followed node; nil returns to the framing's fixed focus.
---@param offset? Vector3 World-space offset from the node, in metres.
function Studio:Follow(node, offset)
    self.followNode, self.followOffset = node, offset or Vector3.ZERO
    if not node then self.targetFocus = Vector3(FRAMINGS[self.framing].focus) end
end

--- Stop an in-progress framing blend at the currently visible camera position.
function Studio:HoldFraming()
    self.followNode = nil
    self.targetFocus = self.focus
    self.targetDistance = self.distance / (self.compact and COMPACT_DISTANCE_SCALE or 1)
end

--- Ease the camera towards a distance from the current framing's focus.
---@param distance? number Metres; nil returns to the framing's own distance.
function Studio:SetDistance(distance)
    self.targetDistance = distance or FRAMINGS[self.framing].distance
end

--- Move the target distance by mouse-wheel steps.
---@param delta number Positive values move closer.
function Studio:Zoom(delta)
    self.targetDistance = math.max(MIN_DISTANCE, math.min(MAX_DISTANCE, self.targetDistance - delta * ZOOM_STEP))
end

--- Ease the camera towards its targets and apply the viewport layout.
---@param dt number Elapsed seconds; zero keeps the camera and only reapplies the layout.
function Studio:Update(dt)
    if self.followNode then self.targetFocus = self.followNode.worldPosition + self.followOffset end
    local alpha = 1 - math.exp(-dt * CAMERA_EASE_RATE)
    self.focus = self.focus:Lerp(self.targetFocus, alpha)
    local desiredDistance = self.targetDistance * (self.compact and COMPACT_DISTANCE_SCALE or 1)
    self.distance = self.distance + (desiredDistance - self.distance) * alpha
    self.camera:SetProjectionOffset(Vector2(0, self.compact and COMPACT_PROJECTION_OFFSET[self.framing] or 0))
    local yaw, pitch = math.rad(self.yaw), math.rad(self.pitch)
    local direction = Vector3(math.sin(yaw) * math.cos(pitch), math.sin(pitch), math.cos(yaw) * math.cos(pitch))
    self.cameraNode.position = self.focus + direction * self.distance
    self.cameraNode:LookAt(self.focus)
    -- The stage faces the camera, so the back wall always sits square behind the character.
    self.stageNode.rotation = Quaternion(self.yaw, Vector3.UP)
end

return Studio
