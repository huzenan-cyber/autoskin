--- First-person walker that swims. VoxelCharacterController samples the same water domain as buoyancy: past chest
--- depth it switches to swimming and floats at the wave surface, so the script only writes movement intent.
---@class Swimmer
---@field node Node
---@field controller VoxelCharacterController
---@field cameraNode Node
---@field camera Camera
---@field yaw number
---@field pitch number
---@field start Vector3
---@field startYaw number
local Swimmer = {}
Swimmer.__index = Swimmer

local EYE_HEIGHT, WALK_SPEED, RUN_SPEED, SWIM_SPEED, JUMP_SPEED = 1.6, 4.5, 8.0, 3.0, 6.0
local LOOK_SENSITIVITY = 0.1

--- Create the character with its feet at position, looking along yaw degrees, and the view camera.
---@param scene Scene
---@param position Vector3
---@param yaw number
---@return Swimmer
function Swimmer.New(scene, position, yaw)
    local self = setmetatable({}, Swimmer)
    self.node = scene:CreateChild("Swimmer")
    self.node.worldPosition = position
    self.controller = self.node:CreateComponent("VoxelCharacterController")
    self.controller.height = 1.7
    self.controller.radius = 0.35
    self.cameraNode = scene:CreateChild("Camera")
    self.camera = self.cameraNode:CreateComponent("Camera")
    -- The far clip covers the far water to the horizon.
    self.camera.nearClip, self.camera.farClip, self.camera.fov = 0.05, 3000, 70
    self.yaw, self.pitch = yaw, 8
    self.start, self.startYaw = position, yaw
    self:UpdateCamera()
    return self
end

--- Write this frame's movement intent. Call from SceneUpdate, which runs before the physics step of the frame.
--- The view turns while the right mouse button is held; the cursor stays free for the parameter panel.
function Swimmer:Control()
    if input:GetMouseButtonDown(MOUSEB_RIGHT) then
        self.yaw = self.yaw + input.mouseMoveX * LOOK_SENSITIVITY
        self.pitch = Clamp(self.pitch + input.mouseMoveY * LOOK_SENSITIVITY, -85, 85)
    end
    local move = Vector3.ZERO
    if input:GetKeyDown(KEY_W) then move = move + Vector3.FORWARD end
    if input:GetKeyDown(KEY_S) then move = move + Vector3.BACK end
    if input:GetKeyDown(KEY_A) then move = move + Vector3.LEFT end
    if input:GetKeyDown(KEY_D) then move = move + Vector3.RIGHT end
    if move:LengthSquared() > 1 then move = move:Normalized() end
    local controller = self.controller
    if controller.swimming then
        -- Swim where the camera looks; desiredVelocity.y is the rise/dive intent.
        local velocity = Quaternion(self.pitch, self.yaw, 0) * move * SWIM_SPEED
        local vertical = velocity.y
        if input:GetKeyDown(KEY_SPACE) then vertical = SWIM_SPEED end
        if input:GetKeyDown(KEY_C) then vertical = -SWIM_SPEED end
        controller.desiredVelocity = Vector3(velocity.x, vertical, velocity.z)
    else
        local speed = input:GetKeyDown(KEY_SHIFT) and RUN_SPEED or WALK_SPEED
        local velocity = Quaternion(self.yaw, Vector3.UP) * move * speed
        controller.desiredVelocity = Vector3(velocity.x, 0, velocity.z)
        if input:GetKeyPress(KEY_SPACE) and controller.onGround then controller:Jump(JUMP_SPEED) end
    end
    self.node.worldRotation = Quaternion(self.yaw, Vector3.UP)
end

--- Put the camera at the eyes. Call after the physics step (PostUpdate) so it follows the solved position.
function Swimmer:UpdateCamera()
    self.cameraNode.worldPosition = self.node.worldPosition + Vector3(0, EYE_HEIGHT, 0)
    self.cameraNode.worldRotation = Quaternion(self.pitch, self.yaw, 0)
end

--- Return to the start point.
function Swimmer:Respawn()
    self.controller:Teleport(self.start)
    self.yaw, self.pitch = self.startYaw, 8
end

return Swimmer
