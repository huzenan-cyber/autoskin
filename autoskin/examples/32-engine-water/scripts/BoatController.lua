--- Example motorboat controls. Propulsion and yaw torque act on the existing floating VoxelVolume; the engine
--- still owns buoyancy, collisions, pitch and roll. Visual wakes follow the solved stern position after physics.
---@class BoatController
---@field demo WaterSceneDemo
---@field swimmer Swimmer
---@field aboard boolean
---@field speed number
---@field orbitYaw number
---@field orbitPitch number
---@field touchingWater boolean
---@field cameraPosition Vector3?
local BoatController = {}
BoatController.__index = BoatController

-- The example hull is 4.4 x 0.9 x 1.8 m, with its bow along local +X and its Node at the minimum grid corner.
local CENTER, SEAT, STERN = Vector3(2.2, 0.4, 0.9), Vector3(1.6, 0.3, 0.9), Vector3(0.1, 0.3, 0.9)
local TARGET_SPEED, REVERSE_SPEED, ACCELERATION = 8.0, 2.5, 8.0

---@param volume VoxelVolume
---@return Node node
---@return Vector3 forward
---@return Vector3 right
local function Frame(volume)
    local node = volume:GetNode()
    local axis = node.worldRotation * Vector3.RIGHT
    local forward = Vector3(axis.x, 0, axis.z):Normalized()
    return node, forward, Vector3(forward.z, 0, -forward.x)
end

---@param sample WaterSurfaceSample
---@return boolean
local function TouchingWater(sample)
    return sample:IsValid() and sample.immersionDepth > -0.45 and sample.immersionDepth < 1.2
end

--- Bind the example scene and swimmer. The current hull is read from demo.boat so resetting the scene is safe.
---@param demo WaterSceneDemo
---@param swimmer Swimmer
---@return BoatController
function BoatController.New(demo, swimmer)
    return setmetatable({demo = demo, swimmer = swimmer, aboard = false, speed = 0,
                         orbitYaw = 25, orbitPitch = 28, touchingWater = false}, BoatController)
end

--- Board immediately for the demo, suspending character collisions while riding. B is a quick mode switch,
--- not a proximity interaction; the third-person view keeps the hull and its trailing foam visible.
function BoatController:Enter()
    self.aboard = true
    self.swimmer.controller.desiredVelocity = Vector3.ZERO
    self.swimmer.controller.enabled = false
    self.demo.water.wake:Remove("swimmer")
    self.orbitYaw, self.orbitPitch = 25, 28
    self:ResetCamera()
    self:Update(0)
end

--- Step out beside the hull and restore the normal walking/swimming controller and first-person view.
function BoatController:Leave()
    if not self.aboard then return end
    self.aboard = false
    local node, forward = Frame(self.demo.boat)
    self.swimmer.controller:Teleport(node:LocalToWorld(Vector3(2.2, 1.2, -1.0)))
    self.swimmer.controller.enabled = true
    self.swimmer.controller.linearVelocity = Vector3.ZERO
    self.swimmer.controller.desiredVelocity = Vector3.ZERO
    self.swimmer.yaw, self.swimmer.pitch = math.deg(math.atan(forward.x, forward.z)), 8
    self.swimmer:UpdateCamera()
end

--- Snap the next chase-camera update after the hull has been recreated or the player has boarded.
function BoatController:ResetCamera()
    self.cameraPosition = nil
end

--- Apply horizontal propulsion/drag and yaw control before physics. Throttle/steer are in [-1, 1]; brake is a
--- boolean. No pose or velocity is overwritten, and a paused scene must not accumulate forces.
function BoatController:Drive(timeStep, throttle, steer, brake)
    if timeStep <= 0 then return end
    local volume = self.demo.boat
    local node, forward, right = Frame(volume)
    local velocity = volume:GetLinearVelocity()
    local speed = velocity:DotProduct(forward)
    self.speed = Vector3(velocity.x, 0, velocity.z):Length()
    local world = self.demo.scene:GetWaterWorld()
    local sample = world:SampleSurface(node:LocalToWorld(CENTER), world:GetTime())
    self.touchingWater = TouchingWater(sample)
    if not self.touchingWater or (node.worldRotation * Vector3.UP).y < 0.3 then return end

    throttle, steer = Clamp(throttle, -1, 1), Clamp(steer, -1, 1)
    local target = throttle * (throttle >= 0 and TARGET_SPEED or REVERSE_SPEED)
    local drive = throttle ~= 0 and Clamp((target - speed) * 3.0, -ACCELERATION, ACCELERATION) or 0
    if brake then drive = 0 end
    local drag = brake and 3.0 or 0.15
    local acceleration = forward * (drive - speed * drag) - right * (velocity:DotProduct(right) * 2.0)
    volume:ApplyForce(acceleration * volume:GetMass())

    -- Approximate the hull's yaw inertia. The rudder reverses when backing up and cannot spin a stationary boat.
    local yawRate = steer * 0.7 * Clamp(speed / 4.0, -1, 1)
    local inertia = volume:GetMass() * (4.4 * 4.4 + 1.8 * 1.8) / 12
    local torque = Clamp((yawRate - volume:GetAngularVelocity().y) * 4.0, -3, 3) * inertia
    volume:ApplyTorque(Vector3(0, torque, 0))
end

--- Read player input before physics. With nobody aboard, keep passive lateral drag and yaw damping.
function BoatController:Control(timeStep)
    local throttle, steer, brake = 0, 0, false
    if self.aboard then
        throttle = (input:GetKeyDown(KEY_W) and 1 or 0) - (input:GetKeyDown(KEY_S) and 1 or 0)
        steer = (input:GetKeyDown(KEY_D) and 1 or 0) - (input:GetKeyDown(KEY_A) and 1 or 0)
        brake = input:GetKeyDown(KEY_SPACE)
        if input:GetMouseButtonDown(MOUSEB_RIGHT) then
            self.orbitYaw = self.orbitYaw - input.mouseMoveX * 0.15
            self.orbitPitch = Clamp(self.orbitPitch + input.mouseMoveY * 0.15, 12, 65)
        end
    end
    self:Drive(timeStep, throttle, steer, brake)
end

--- After physics, emit a wake only where the stern touches this water domain, then update the riding camera.
function BoatController:Update(timeStep)
    local node, forward = Frame(self.demo.boat)
    local world = self.demo.scene:GetWaterWorld()
    local time, stern = world:GetTime(), node:LocalToWorld(STERN)
    local surface = world:SampleSurface(stern, time)
    self.demo.water.wake:Feed("boat", stern, time, 0.85, 1.0, TouchingWater(surface))
    if not self.aboard then return end

    self.swimmer.node.worldPosition = node:LocalToWorld(SEAT)
    local target = node:LocalToWorld(CENTER) + Vector3(0, 0.4, 0)
    local behind = Quaternion(self.orbitYaw, Vector3.UP) * -forward
    local pitch = math.rad(self.orbitPitch)
    local desired = target + behind * (math.cos(pitch) * 10) + Vector3.UP * (math.sin(pitch) * 10)
    local blend = 1 - math.exp(-6 * math.max(timeStep, 0))
    self.cameraPosition = self.cameraPosition and self.cameraPosition:Lerp(desired, blend) or desired
    self.swimmer.cameraNode.worldPosition = self.cameraPosition
    self.swimmer.cameraNode:LookAt(target)
end

return BoatController
