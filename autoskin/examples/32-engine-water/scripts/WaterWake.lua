--- Visual wake histories, independent of WaterWorld and FFT simulation. Feed source positions after gameplay has
--- decided that they touch this water domain. Each source has its own width and strength; Remove releases it.
--- The example shader accepts 32 recent segments in total, not a fixed number of emitters. Older segments fade out
--- over four seconds. Raising the upload budget requires changing the shader array size too.
---@class WaterWakePoint
---@field x number
---@field z number
---@field time number
---@field intensity number
---@field serial integer

---@class WaterWakeSource
---@field points WaterWakePoint[]
---@field width number
---@field strength number
---@field previous WaterWakePoint?
---@field head WaterWakePoint?
---@field tip WaterWakePoint?

---@class WaterWake
---@field sources table<any, WaterWakeSource>
---@field serial integer
---@field buffer VectorBuffer
---@field time number?
local WaterWake = {}
WaterWake.__index = WaterWake
local SEGMENTS, LIFETIME, RADIUS = 32, 4.0, 9.0

local function Finite(value)
    return value == value and math.abs(value) < math.huge
end

--- Create an empty tracker. Positions and widths are world meters; time is WaterWorld:GetTime().
---@return WaterWake
function WaterWake.New()
    return setmetatable({sources = {}, serial = 0, buffer = VectorBuffer()}, WaterWake)
end

--- Drop every source and all old trails, for scene reset or a wave/domain replacement.
function WaterWake:Clear()
    self.sources = {}
    self.time = nil
end

--- Stop a source and immediately release its history, for removal/teleport/destruction.
function WaterWake:Remove(id)
    self.sources[id] = nil
end

--- Feed a source once per scene update. A false contact or an invalid position breaks the trail without joining
--- across land or a dive. Paused time freezes it. A time rewind, gap over one second or jump over 5.5 m resets it.
function WaterWake:Feed(id, position, time, width, strength, contact)
    assert(id ~= nil and Finite(time) and Finite(width) and Finite(strength))
    if self.time and time < self.time then self:Clear() end
    self.time = time
    local source = self.sources[id]
    if not source then
        source = {points = {}, width = math.max(width, 0), strength = math.max(strength, 0)}
        self.sources[id] = source
    end
    source.width, source.strength = math.max(width, 0), math.max(strength, 0)
    if not contact or not position or not Finite(position.x) or not Finite(position.z) then
        source.previous, source.head, source.tip = nil, nil, nil
        return
    end
    local current = {x = position.x, z = position.z, time = time, intensity = 0}
    local previous = source.previous
    if previous then
        local dt = time - previous.time
        if dt == 0 then return end
        local dx, dz = current.x - previous.x, current.z - previous.z
        local distance = math.sqrt(dx * dx + dz * dz)
        if dt > 1 or distance > 5.5 then
            source.points, source.head, source.tip = {}, nil, nil
        else
            current.intensity = math.max(0, math.min(1, (distance / dt - 0.2) / 3)) * source.strength
        end
    end
    -- Only committed points form segments. A separate live head lets a moving source leave a continuous trail
    -- between samples, without emitting a stationary bright spot after it stops.
    local head = source.head
    if not head then
        self.serial = self.serial + 1
        current.serial = self.serial
        source.points[#source.points + 1] = current
        source.head = current
    else
        current.serial = head.serial
        source.tip = current
        local dx, dz = current.x - head.x, current.z - head.z
        if time - head.time >= 0.12 and dx * dx + dz * dz >= 0.16 then
            self.serial = self.serial + 1
            current.serial = self.serial
            source.points[#source.points + 1] = current
            source.head, source.tip = current, nil
        end
    end
    source.previous = current
end

--- Return at most 32 newest live segments and their conservative XZ bounds. Also expires unused histories.
--- Stable serial ordering makes identical input sequences deterministic across views.
function WaterWake:GetSegments(time)
    assert(Finite(time))
    if self.time and time < self.time then self:Clear() end
    self.time = time
    local segments = {}
    for _, source in pairs(self.sources) do
        local points = source.points
        while #points > 0 and time - points[1].time >= LIFETIME do table.remove(points, 1) end
        local function Add(a, b)
            if a and b and a.intensity > 0 and b.intensity > 0 and source.width > 0 then
                local dx, dz = b.x - a.x, b.z - a.z
                if dx * dx + dz * dz >= 0.0001 and dx * dx + dz * dz <= 36 then
                    segments[#segments + 1] = {a = a, b = b, width = source.width}
                end
            end
        end
        for i = 2, #points do Add(points[i - 1], points[i]) end
        Add(points[#points], source.tip)
    end
    table.sort(segments, function(a, b)
        if a.b.time ~= b.b.time then return a.b.time > b.b.time end
        return a.b.serial > b.b.serial
    end)
    while #segments > SEGMENTS do table.remove(segments) end
    local minX, minZ, maxX, maxZ = math.huge, math.huge, -math.huge, -math.huge
    for _, segment in ipairs(segments) do
        for _, p in ipairs({segment.a, segment.b}) do
            minX, minZ = math.min(minX, p.x - RADIUS), math.min(minZ, p.z - RADIUS)
            maxX, maxZ = math.max(maxX, p.x + RADIUS), math.max(maxZ, p.z + RADIUS)
        end
    end
    return segments, #segments > 0 and Vector4(minX, minZ, maxX, maxZ) or Vector4.ZERO
end

--- Upload the same immutable visual field to all water materials; reapply after shader reloads as other parameters.
function WaterWake:Apply(materials, time)
    local segments, bounds = self:GetSegments(time)
    local buffer = self.buffer
    buffer:Clear()
    local function Point(p)
        local age = math.max(time - p.time, 0)
        local fade = math.max(0, math.min(1, LIFETIME - age))
        buffer:WriteVector4(Vector4(p.x, p.z, age, p.intensity * fade))
    end
    for _, segment in ipairs(segments) do
        Point(segment.a)
        Point(segment.b)
        buffer:WriteVector4(Vector4(segment.width, 0, 0, 0))
    end
    for i = #segments + 1, SEGMENTS do
        for j = 1, 3 do buffer:WriteVector4(Vector4.ZERO) end
    end
    for _, material in ipairs(materials) do
        material:SetShaderParameter("wake_count", Variant(#segments))
        material:SetShaderParameter("wake_bounds", Variant(bounds))
        material:SetShaderParameter("wake_segments", Variant(buffer))
    end
end

return WaterWake
