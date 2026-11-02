-- Island, lighthouse, ring boardwalk on stilts, lamps and buoys.
local Parts = require("parts")

local World = {}

World.RING_RADIUS = 40.0
World.DECK_Y = 3.0
local DECK_WIDTH = 3.4
local SEGMENTS = 96

local function ringPoint(radius, angle, y)
    return Vector3(radius * math.cos(angle), y, radius * math.sin(angle))
end

local function tangentRotation(angle)
    return Quaternion(Vector3(0, 0, 1), Vector3(-math.sin(angle), 0, math.cos(angle)))
end

-- Every light injects into volumetric fog by default; this sets the strength and
-- whether the light's shadow map carves shafts into the fog (needs castShadows).
local function volumetric(light, intensity, shadows)
    light.affectVolumetricFog = true
    light.volumetricFogIntensity = intensity
    light.volumetricFogShadows = shadows == true
end
World.Volumetric = volumetric

local function buildIsland(root)
    local sand = Parts.Material(Color(0.62, 0.53, 0.40), 0.9, 0.0)
    local grass = Parts.Material(Color(0.20, 0.33, 0.12), 0.85, 0.0)
    local rock = Parts.Material(Color(0.30, 0.29, 0.28), 0.75, 0.0)
    Parts.Add(root, "Sphere", sand, Vector3(0, -1.5, 0), Vector3(48, 10, 48))
    Parts.Add(root, "Sphere", grass, Vector3(0, 0.9, 0), Vector3(36, 5.4, 36))
    math.randomseed(20260924)
    for i = 1, 26 do
        local a = math.random() * math.pi * 2
        local r = 18 + math.random() * 6
        local s = 1.2 + math.random() * 2.4
        Parts.Add(root, "Sphere", rock, Vector3(r * math.cos(a), 0.2 + math.random() * 0.8, r * math.sin(a)),
            Vector3(s * (1 + math.random() * 0.6), s * 0.7, s), Quaternion(math.random() * 360, math.random() * 360, 0))
    end
    -- A few rocks out in the surf between the island and the boardwalk.
    for i = 1, 10 do
        local a = math.random() * math.pi * 2
        local r = 27 + math.random() * 7
        local s = 0.8 + math.random() * 1.6
        Parts.Add(root, "Sphere", rock, Vector3(r * math.cos(a), -0.3, r * math.sin(a)),
            Vector3(s * 1.3, s * 1.1, s), Quaternion(math.random() * 360, math.random() * 360, 0))
    end
end

local function buildLighthouse(root, handles)
    local white = Parts.Material(Color(0.86, 0.85, 0.82), 0.55, 0.0)
    local red = Parts.Material(Color(0.62, 0.07, 0.05), 0.5, 0.0)
    local iron = Parts.Material(Color(0.08, 0.09, 0.10), 0.35, 0.9)
    local stone = Parts.Material(Color(0.42, 0.40, 0.37), 0.8, 0.0)
    handles.lanternMat = Parts.Material(Color(1.0, 0.95, 0.8), 0.1, 0.0, Vector3(0, 0, 0))

    local base = 3.3
    Parts.Add(root, CylinderGeometry(3.2, 3.6, 1.6, 32):ToModel(), stone, Vector3(0, base + 0.8, 0))
    local towerH, bands = 16.0, 5
    local r0, r1 = 2.3, 1.5
    for i = 0, bands - 1 do
        local t0, t1 = i / bands, (i + 1) / bands
        local h = towerH / bands
        local geo = CylinderGeometry(Parts.Lerp(r0, r1, t1), Parts.Lerp(r0, r1, t0), h, 40)
        Parts.Add(root, geo:ToModel(), (i % 2 == 0) and white or red,
            Vector3(0, base + 1.6 + (i + 0.5) * h, 0))
    end
    local top = base + 1.6 + towerH
    -- Door and windows
    Parts.Add(root, "Box", iron, Vector3(0, base + 2.6, -2.2), Vector3(1.0, 1.9, 0.3))
    for i = 1, 3 do
        Parts.Add(root, "Box", iron, Vector3(0, base + 1.6 + i * 4.3, 1.62 + (3 - i) * 0.16),
            Vector3(0.5, 0.9, 0.3))
    end
    -- Gallery deck + railing
    Parts.Add(root, CylinderGeometry(2.4, 2.4, 0.3, 40):ToModel(), iron, Vector3(0, top + 0.15, 0))
    Parts.Add(root, TorusGeometry(2.3, 0.04, 8, 48):ToModel(), iron, Vector3(0, top + 1.2, 0),
        nil, Quaternion(90, 0, 0))
    for i = 0, 23 do
        local a = i / 24 * math.pi * 2
        Parts.Segment(root, iron, Vector3(2.3 * math.cos(a), top + 0.3, 2.3 * math.sin(a)),
            Vector3(2.3 * math.cos(a), top + 1.2, 2.3 * math.sin(a)), 0.03)
    end
    -- Lantern room: glowing glass drum, frame, red roof
    local glass = Parts.Add(root, CylinderGeometry(1.15, 1.15, 2.3, 32):ToModel(), handles.lanternMat,
        Vector3(0, top + 1.45, 0))
    glass:GetComponent("StaticModel").castShadows = false
    for i = 0, 7 do
        local a = i / 8 * math.pi * 2
        Parts.Segment(root, iron, Vector3(1.18 * math.cos(a), top + 0.3, 1.18 * math.sin(a)),
            Vector3(1.18 * math.cos(a), top + 2.6, 1.18 * math.sin(a)), 0.05)
    end
    Parts.Add(root, ConeGeometry(1.6, 1.6, 32):ToModel(), red, Vector3(0, top + 3.4, 0))
    Parts.Add(root, "Sphere", iron, Vector3(0, top + 4.3, 0), 0.35)

    -- Lamp glow inside the lantern
    local lampNode = root:CreateChild("LanternLight")
    lampNode.position = Vector3(0, top + 1.45, 0)
    local lamp = lampNode:CreateComponent("Light")
    lamp.lightType = LIGHT_POINT
    lamp.color = Color(1.0, 0.85, 0.6)
    lamp.range = 14
    lamp.brightness = 0
    volumetric(lamp, 1.5, false)
    handles.lanternLight = lamp

    -- Two opposite rotating beams: narrow spot lights injected into volumetric fog.
    local rotor = root:CreateChild("BeamRotor")
    rotor.position = Vector3(0, top + 1.45, 0)
    handles.beamRotor = rotor
    handles.beams = {}
    for i = 0, 1 do
        local bn = rotor:CreateChild("Beam")
        bn.rotation = Quaternion(0, i * 180, 0) * Quaternion(4, 0, 0)
        local beam = bn:CreateComponent("Light")
        beam.lightType = LIGHT_SPOT
        beam.color = Color(1.0, 0.92, 0.75)
        beam.fov = 9
        beam.range = 220
        beam.brightness = 0
        volumetric(beam, 25.0, false)
        handles.beams[#handles.beams + 1] = beam
    end
    handles.lighthouseTop = top
end

local function buildBoardwalk(root, handles)
    local woods = {
        Parts.Material(Color(0.42, 0.28, 0.17), 0.72, 0.0),
        Parts.Material(Color(0.38, 0.25, 0.15), 0.78, 0.0),
        Parts.Material(Color(0.46, 0.32, 0.20), 0.68, 0.0),
    }
    local pile = Parts.Material(Color(0.22, 0.17, 0.12), 0.9, 0.0)
    local rail = Parts.Material(Color(0.33, 0.22, 0.14), 0.6, 0.0)
    local metal = Parts.Material(Color(0.05, 0.06, 0.07), 0.35, 0.85)
    handles.bulbMat = Parts.Material(Color(1.0, 0.9, 0.7), 0.3, 0.0, Vector3(0, 0, 0))

    local R, Y = World.RING_RADIUS, World.DECK_Y
    local segLen = 2 * math.pi * R / SEGMENTS
    for i = 0, SEGMENTS - 1 do
        local a = (i + 0.5) / SEGMENTS * math.pi * 2
        -- Deck: three planks across per segment for visible board lines.
        for k = -1, 1 do
            local r = R + k * DECK_WIDTH / 3
            Parts.Add(root, "Box", woods[(i + k) % 3 + 1], ringPoint(r, a, Y - 0.08),
                Vector3(DECK_WIDTH / 3 - 0.04, 0.16, segLen * (r / R) + 0.02), tangentRotation(a))
        end
        -- Rails
        for side = -1, 1, 2 do
            local r = R + side * (DECK_WIDTH / 2 - 0.08)
            Parts.Add(root, "Box", rail, ringPoint(r, a, Y + 1.0),
                Vector3(0.1, 0.08, segLen * (r / R) + 0.03), tangentRotation(a))
            Parts.Add(root, "Box", rail, ringPoint(r, a, Y + 0.5),
                Vector3(0.05, 0.05, segLen * (r / R) + 0.03), tangentRotation(a))
        end
        if i % 2 == 0 then
            local ap = i / SEGMENTS * math.pi * 2
            for side = -1, 1, 2 do
                local r = R + side * (DECK_WIDTH / 2 - 0.08)
                Parts.Segment(root, rail, ringPoint(r, ap, Y), ringPoint(r, ap, Y + 1.05), 0.05, "Box")
                Parts.Segment(root, pile, ringPoint(r, ap, -6.0), ringPoint(r, ap, Y - 0.16), 0.16)
            end
        end
    end

    -- Four walkways connecting the boardwalk to the island.
    for q = 0, 3 do
        local a = (q + 0.5) * math.pi / 2
        local r0, r1 = 13.0, R - DECK_WIDTH / 2
        local steps = 10
        for s = 0, steps - 1 do
            local t = (s + 0.5) / steps
            local r = Parts.Lerp(r0, r1, t)
            local y = Parts.Lerp(2.9, Y, t) - 0.08
            Parts.Add(root, "Box", woods[s % 3 + 1], ringPoint(r, a, y),
                Vector3(2.2, 0.16, (r1 - r0) / steps + 0.02), Quaternion(Vector3(0, 0, 1), Vector3(math.cos(a), 0, math.sin(a))))
            if s % 2 == 0 then
                local side = Vector3(-math.sin(a), 0, math.cos(a)) * 1.05
                Parts.Segment(root, pile, ringPoint(r, a, -5) + side, ringPoint(r, a, y) + side, 0.13)
                Parts.Segment(root, pile, ringPoint(r, a, -5) - side, ringPoint(r, a, y) - side, 0.13)
            end
        end
    end

    -- Lamp posts on the outer rail
    handles.lamps = {}
    local LAMPS = 16
    for i = 0, LAMPS - 1 do
        local a = (i + 0.25) / LAMPS * math.pi * 2
        local base = ringPoint(R + DECK_WIDTH / 2 - 0.1, a, Y)
        local inward = Vector3(-math.cos(a), 0, -math.sin(a))
        Parts.Segment(root, metal, base, base + Vector3(0, 3.6, 0), 0.06)
        Parts.Add(root, CylinderGeometry(0.16, 0.2, 0.3, 12):ToModel(), metal, base + Vector3(0, 0.15, 0))
        local armEnd = base + Vector3(0, 3.55, 0) + inward * 0.7
        Parts.Segment(root, metal, base + Vector3(0, 3.6, 0), armEnd, 0.035)
        Parts.Add(root, ConeGeometry(0.26, 0.28, 12):ToModel(), metal, armEnd + Vector3(0, -0.02, 0))
        local bulb = Parts.Add(root, "Sphere", handles.bulbMat, armEnd + Vector3(0, -0.2, 0), 0.2)
        bulb:GetComponent("StaticModel").castShadows = false
        local ln = root:CreateChild("LampLight")
        ln.position = armEnd + Vector3(0, -0.35, 0)
        local light = ln:CreateComponent("Light")
        light.lightType = LIGHT_POINT
        light.color = Color(1.0, 0.72, 0.42)
        light.range = 11
        light.brightness = 0
        volumetric(light, 6.0, false)
        handles.lamps[#handles.lamps + 1] = light
    end
end

local function buildBuoys(root, handles)
    local red = Parts.Material(Color(0.7, 0.08, 0.05), 0.45, 0.0)
    local metal = Parts.Material(Color(0.1, 0.1, 0.1), 0.4, 0.8)
    handles.buoyMat = Parts.Material(Color(1.0, 0.2, 0.1), 0.3, 0.0, Vector3(0, 0, 0))
    handles.buoys = {}
    local spots = { { 70, 0.4 }, { 85, 2.1 }, { 64, 3.6 }, { 95, 4.9 }, { 110, 1.2 } }
    for i, s in ipairs(spots) do
        local n = root:CreateChild("Buoy")
        n.position = Vector3(s[1] * math.cos(s[2]), 0, s[1] * math.sin(s[2]))
        Parts.Add(n, CylinderGeometry(0.5, 0.75, 1.4, 16):ToModel(), red, Vector3(0, 0.2, 0))
        Parts.Add(n, ConeGeometry(0.45, 1.6, 16):ToModel(), red, Vector3(0, 1.7, 0))
        Parts.Segment(n, metal, Vector3(0, 2.4, 0), Vector3(0, 3.1, 0), 0.05)
        local lampModel = Parts.Add(n, "Sphere", handles.buoyMat, Vector3(0, 3.2, 0), 0.22)
        lampModel:GetComponent("StaticModel").castShadows = false
        local ln = n:CreateChild("BuoyLight")
        ln.position = Vector3(0, 3.35, 0)
        local light = ln:CreateComponent("Light")
        light.lightType = LIGHT_POINT
        light.color = Color(1.0, 0.15, 0.08)
        light.range = 9
        light.brightness = 0
        volumetric(light, 3.0, false)
        handles.buoys[#handles.buoys + 1] = { node = n, light = light, phase = i * 1.37, base = n.position }
    end
end

---@class WorldHandles
---@field lanternMat Material
---@field lanternLight Light
---@field beamRotor Node
---@field beams Light[]
---@field lighthouseTop number
---@field bulbMat Material
---@field lamps Light[]
---@field buoyMat Material
---@field buoys { node: Node, light: Light, phase: number, base: Vector3 }[]

--- Build all static scenery. Returns handles for animated/lit elements.
---@return WorldHandles
function World.Create(scene)
    local root = scene:CreateChild("World")
    ---@type WorldHandles
    local handles = {}
    buildIsland(root)
    buildLighthouse(root, handles)
    buildBoardwalk(root, handles)
    buildBuoys(root, handles)
    return handles
end

--- Point on the ring centreline used by the rider.
function World.RingPoint(angle)
    return ringPoint(World.RING_RADIUS, angle, World.DECK_Y)
end

return World
