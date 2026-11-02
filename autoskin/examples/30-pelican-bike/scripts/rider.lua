-- The pelican and its bicycle, built from primitives and animated procedurally:
-- wheels and cranks spin with speed, feet follow the pedals through two-bone IK,
-- wing tips hold the handlebar, the head bobs and the pouch jiggles.
local Parts = require("parts")
local World = require("world")

local Rider = {}

local V = Vector3
local WHEEL_R = 0.345
local HEAD_TOP = V(0, 0.90, 0.36)
local HEAD_BOT = V(0, 0.72, 0.41)
local BB = V(0, 0.30, -0.06)
local CRANK = 0.16
local THIGH, SHIN = 0.42, 0.48

---@type Node, Node, Node, Node, Node, Node
local root, rider, steer, frontWheel, rearWheel, crank
local pedals = {}
local legs = {}
local wings = {}
local neck = {}
---@type Node, Node, Node[]
local head, pouch, scarfTails
local mats = {}
local steerAxis
local rollSign = 1

Rider.angle = 0.0
Rider.speed = 5.0
Rider.distance = 0.0
local wheelAngle, crankAngle, time = 0, 0, 0

local function buildWheel(parent, pos)
    local w = parent:CreateChild("Wheel")
    w.position = pos
    local axisX = Quaternion(0, 90, 0)
    Parts.Add(w, TorusGeometry(WHEEL_R - 0.03, 0.032, 12, 48):ToModel(), mats.tire, nil, nil, axisX)
    Parts.Add(w, TorusGeometry(WHEEL_R - 0.065, 0.012, 8, 48):ToModel(), mats.chrome, nil, nil, axisX)
    Parts.Segment(w, mats.chrome, V(-0.06, 0, 0), V(0.06, 0, 0), 0.028)
    for i = 0, 15 do
        local a = i / 16 * math.pi * 2
        local side = (i % 2 == 0) and 0.045 or -0.045
        Parts.Segment(w, mats.chrome, V(side, 0, 0), V(0, math.sin(a) * (WHEEL_R - 0.07), math.cos(a) * (WHEEL_R - 0.07)), 0.004)
    end
    return w
end

local function buildBike()
    local b = root:CreateChild("Bike")
    local frame = mats.paint
    local rear = V(0, WHEEL_R, -0.52)
    local seatTop = V(0, 0.86, -0.24)
    -- Frame tubes
    Parts.Segment(b, frame, seatTop, HEAD_TOP, 0.022)
    Parts.Segment(b, frame, BB, HEAD_BOT, 0.026)
    Parts.Segment(b, frame, BB, seatTop + V(0, 0.04, -0.015), 0.024)
    Parts.Segment(b, frame, HEAD_TOP + V(0, 0.02, 0), HEAD_BOT - V(0, 0.03, -0.012), 0.03)
    for side = -1, 1, 2 do
        Parts.Segment(b, frame, BB + V(side * 0.03, 0, 0), rear + V(side * 0.06, 0, 0), 0.013)
        Parts.Segment(b, frame, seatTop + V(side * 0.02, -0.03, 0), rear + V(side * 0.06, 0, 0), 0.012)
    end
    -- Seat post and saddle
    Parts.Segment(b, mats.chrome, seatTop, seatTop + V(0, 0.12, -0.02), 0.014)
    Parts.Add(b, "Sphere", mats.leather, seatTop + V(0, 0.15, -0.02), V(0.17, 0.06, 0.28))
    -- Rear rack + tail light
    Parts.Segment(b, mats.chrome, seatTop + V(0, -0.02, -0.02), V(0, 0.64, -0.62), 0.008)
    Parts.Add(b, "Box", mats.chrome, V(0, 0.64, -0.55), V(0.14, 0.012, 0.22))
    mats.tailLens = Parts.Material(Color(0.5, 0.02, 0.02), 0.3, 0.0, V(0, 0, 0))
    Parts.Add(b, "Box", mats.tailLens, V(0, 0.61, -0.67), V(0.06, 0.04, 0.02), nil, false)
    local tl = b:CreateChild("TailLight")
    tl.position = V(0, 0.61, -0.72)
    Rider.tailLight = tl:CreateComponent("Light")
    Rider.tailLight.lightType = LIGHT_POINT
    Rider.tailLight.color = Color(1.0, 0.05, 0.02)
    Rider.tailLight.range = 3.0
    Rider.tailLight.brightness = 0
    -- Fenders
    Parts.Add(b, TorusGeometry(WHEEL_R + 0.03, 0.03, 6, 24, math.pi * 0.55):ToModel(), frame, rear,
        nil, Quaternion(0, 90, 0) * Quaternion(0, 0, 100))

    rearWheel = buildWheel(b, rear)

    -- Crankset
    crank = b:CreateChild("Crank")
    crank.position = BB
    Parts.Add(crank, TorusGeometry(0.1, 0.012, 6, 32):ToModel(), mats.chrome, V(0.07, 0, 0), nil, Quaternion(0, 90, 0))
    Parts.Segment(crank, mats.chrome, V(-0.1, 0, 0), V(0.1, 0, 0), 0.02)
    for side = -1, 1, 2 do
        local dir = V(0, -CRANK * side, 0)
        Parts.Segment(crank, mats.chrome, V(side * 0.09, 0, 0), V(side * 0.09, 0, 0) + dir, 0.012, "Box")
        local p = b:CreateChild("Pedal")
        Parts.Add(p, "Box", mats.rubber, V(0, 0, 0), V(0.1, 0.022, 0.08))
        pedals[side] = { node = p, offset = dir, x = side * 0.12 }
    end
    -- Chain (upper and lower runs)
    Parts.Segment(b, mats.rubber, BB + V(0.07, 0.1, 0), rear + V(0.07, 0.045, 0), 0.006)
    Parts.Segment(b, mats.rubber, BB + V(0.07, -0.1, 0), rear + V(0.07, -0.045, 0), 0.006)

    -- Steering assembly pivots around the head tube axis.
    steer = b:CreateChild("Steer")
    steer.position = HEAD_TOP
    steerAxis = (HEAD_BOT - HEAD_TOP):Normalized()
    local function local_(p) return p - HEAD_TOP end
    local front = V(0, WHEEL_R, 0.52)
    for side = -1, 1, 2 do
        Parts.Segment(steer, frame, local_(HEAD_BOT + V(side * 0.05, 0, 0)), local_(front + V(side * 0.055, 0, 0)), 0.014)
    end
    Parts.Segment(steer, mats.chrome, V(0, 0, 0), V(0, 0.1, -0.03), 0.016)
    Parts.Segment(steer, mats.chrome, V(-0.28, 0.1, -0.07), V(0.28, 0.1, -0.07), 0.013)
    for side = -1, 1, 2 do
        Parts.Segment(steer, mats.rubber, V(side * 0.2, 0.1, -0.07), V(side * 0.3, 0.1, -0.07), 0.02)
    end
    frontWheel = buildWheel(steer, local_(front))
    Parts.Add(steer, TorusGeometry(WHEEL_R + 0.03, 0.03, 6, 24, math.pi * 0.45):ToModel(), frame, local_(front),
        nil, Quaternion(0, 90, 0) * Quaternion(0, 0, 60))
    -- Wicker basket with the catch of the day
    Parts.Add(steer, "Box", mats.wicker, V(0, 0.02, 0.17), V(0.34, 0.2, 0.26))
    Parts.Add(steer, "Box", mats.leather, V(0, 0.125, 0.17), V(0.36, 0.02, 0.28))
    Parts.Ellipsoid(steer, mats.fish, V(-0.05, 0.1, 0.06), V(0.08, 0.2, 0.33), Vector2(0.08, 0.12))
    Parts.Add(steer, ConeGeometry(0.06, 0.1, 8):ToModel(), mats.fish, V(-0.08, 0.06, 0.02), nil, Quaternion(0, 0, 150))
    -- Headlight
    mats.headLens = Parts.Material(Color(1.0, 0.95, 0.85), 0.2, 0.0, V(0, 0, 0))
    Parts.Segment(steer, mats.chrome, V(0, -0.12, 0.05), V(0, -0.12, 0.12), 0.035)
    Parts.Add(steer, CylinderGeometry(0.032, 0.032, 0.01, 16):ToModel(), mats.headLens, V(0, -0.12, 0.125),
        nil, Quaternion(90, 0, 0), false)
    local hl = steer:CreateChild("HeadLight")
    hl.position = V(0, -0.12, 0.16)
    hl.rotation = Quaternion(8, 0, 0)
    local light = hl:CreateComponent("Light")
    light.lightType = LIGHT_SPOT
    light.color = Color(1.0, 0.93, 0.82)
    light.fov = 42
    light.range = 28
    light.brightness = 0
    light.castShadows = true
    World.Volumetric(light, 3.0, true)
    Rider.headLight = light
end

local function buildPelican()
    rider = root:CreateChild("Pelican")
    local white, black = mats.feather, mats.blackFeather
    -- Body: plump belly plus a longer back ellipsoid.
    Parts.Ellipsoid(rider, white, V(0, 1.16, -0.47), V(0, 1.28, 0.30), Vector2(0.50, 0.46))
    Parts.Add(rider, "Sphere", white, V(0, 1.12, -0.03), V(0.46, 0.40, 0.58))
    Parts.Ellipsoid(rider, white, V(0, 1.19, -0.42), V(0, 1.14, -0.72), Vector2(0.24, 0.08))
    -- Folded secondaries with black primaries along each flank.
    for side = -1, 1, 2 do
        Parts.Ellipsoid(rider, white, V(side * 0.22, 1.28, 0.12), V(side * 0.2, 1.17, -0.48), Vector2(0.10, 0.30))
        Parts.Ellipsoid(rider, black, V(side * 0.19, 1.19, -0.34), V(side * 0.15, 1.15, -0.76), Vector2(0.08, 0.18))
    end
    -- Neck (S-curve) of overlapping limbs
    local pts = { V(0, 1.36, 0.20), V(0, 1.56, 0.17), V(0, 1.72, 0.13), V(0, 1.84, 0.19) }
    neck.rest = pts
    neck.limbs = {}
    for i = 1, #pts - 1 do
        neck.limbs[i] = Parts.Limb(rider, white, pts[i], pts[i + 1], 0.075 - i * 0.008)
    end
    -- Red scarf with two fluttering tails
    Parts.Add(rider, TorusGeometry(0.085, 0.035, 8, 24):ToModel(), mats.scarf, V(0, 1.44, 0.19), nil, Quaternion(80, 0, 0))
    scarfTails = {}
    for i = 1, 2 do
        scarfTails[i] = Parts.Add(rider, "Box", mats.scarf, V(0, 1.4, 0.0), V(0.08, 0.02, 0.3))
    end

    head = rider:CreateChild("Head")
    Parts.Add(head, "Sphere", white, V(0, 0, 0), V(0.17, 0.17, 0.23))
    Parts.Add(head, "Sphere", white, V(0, 0.07, -0.08), V(0.05, 0.08, 0.1))
    for side = -1, 1, 2 do
        Parts.Add(head, "Sphere", mats.eyeSkin, V(side * 0.068, 0.025, 0.04), 0.05)
        Parts.Add(head, "Sphere", mats.iris, V(side * 0.08, 0.028, 0.048), 0.03)
        Parts.Add(head, "Sphere", mats.pupil, V(side * 0.089, 0.03, 0.05), 0.016)
    end
    Parts.Ellipsoid(head, mats.beak, V(0, 0.0, 0.07), V(0, -0.14, 0.55), Vector2(0.075, 0.04))
    Parts.Add(head, "Sphere", mats.beakTip, V(0, -0.15, 0.555), V(0.04, 0.04, 0.05))
    pouch = Parts.Ellipsoid(head, mats.pouch, V(0, -0.06, 0.1), V(0, -0.16, 0.5), Vector2(0.08, 0.13))

    -- Wings reaching forward to the handlebar grips
    for side = -1, 1, 2 do
        local w = {}
        w.shoulder = V(side * 0.22, 1.33, 0.12)
        w.arm = Parts.Ellipsoid(rider, white, w.shoulder, w.shoulder + V(0, -0.1, 0.3), Vector2(0.2, 0.07))
        w.tip = Parts.Ellipsoid(rider, black, w.shoulder, w.shoulder + V(0, -0.1, 0.3), Vector2(0.15, 0.05))
        wings[side] = w
    end
    -- Legs: feathered thigh, orange shin, webbed foot on the pedal
    for side = -1, 1, 2 do
        local hip = V(side * 0.11, 1.02, -0.16)
        local l = { hip = hip }
        l.thigh = Parts.Limb(rider, white, hip, hip + V(0, -0.3, 0.2), 0.06)
        l.shin = Parts.Limb(rider, mats.leg, hip, hip + V(0, -0.5, 0), 0.028)
        l.foot = Parts.Add(rider, ConeGeometry(0.07, 0.2, 3):ToModel(), mats.leg, V(0, 0, 0), V(1, 1, 0.35))
        legs[side] = l
    end
end

local function createMaterials()
    mats.paint = Parts.Material(Color(0.02, 0.42, 0.47), 0.22, 0.55)
    mats.chrome = Parts.Material(Color(0.85, 0.85, 0.87), 0.12, 1.0)
    mats.tire = Parts.Material(Color(0.025, 0.025, 0.025), 0.85, 0.0)
    mats.rubber = Parts.Material(Color(0.05, 0.05, 0.05), 0.7, 0.0)
    mats.leather = Parts.Material(Color(0.20, 0.09, 0.04), 0.45, 0.0)
    mats.wicker = Parts.Material(Color(0.55, 0.40, 0.22), 0.8, 0.0)
    mats.fish = Parts.Material(Color(0.55, 0.62, 0.70), 0.2, 0.7)
    mats.feather = Parts.Material(Color(0.90, 0.89, 0.86), 0.85, 0.0)
    mats.blackFeather = Parts.Material(Color(0.03, 0.03, 0.035), 0.75, 0.0)
    mats.beak = Parts.Material(Color(0.95, 0.70, 0.22), 0.4, 0.0)
    mats.beakTip = Parts.Material(Color(0.85, 0.25, 0.12), 0.4, 0.0)
    mats.pouch = Parts.Material(Color(0.95, 0.55, 0.36), 0.5, 0.0)
    mats.leg = Parts.Material(Color(0.95, 0.52, 0.18), 0.6, 0.0)
    mats.eyeSkin = Parts.Material(Color(0.95, 0.75, 0.55), 0.5, 0.0)
    mats.iris = Parts.Material(Color(0.95, 0.88, 0.45), 0.2, 0.0)
    mats.pupil = Parts.Material(Color(0.01, 0.01, 0.01), 0.1, 0.0)
    mats.scarf = Parts.Material(Color(0.75, 0.05, 0.06), 0.7, 0.0)
end

---@param scene Scene
function Rider.Create(scene)
    createMaterials()
    root = scene:CreateChild("Rider")
    buildBike()
    buildPelican()
    -- Which roll sign tilts +Y toward +X in this coordinate system?
    rollSign = ((Quaternion(0, 0, 10) * V(0, 1, 0)).x > 0) and 1 or -1
    Rider.node = root
    Rider.Update(0)
    return root
end

--- Advance the ride.
-- @param dt time step
function Rider.Update(dt)
    time = time + dt
    local R = World.RING_RADIUS
    Rider.angle = Rider.angle + Rider.speed / R * dt
    Rider.distance = Rider.distance + Rider.speed * dt
    local a = Rider.angle
    local pos = World.RingPoint(a)
    local tangent = V(-math.sin(a), 0, math.cos(a))
    local yaw = math.deg(math.atan(tangent.x, tangent.z))
    local yawQ = Quaternion(0, yaw, 0)
    -- Lean into the turn (tan(lean) = v^2 / (g R)) plus a gentle pedalling sway.
    local toCenter = V(-pos.x, 0, -pos.z):Normalized()
    local side = ((yawQ * V(1, 0, 0)):DotProduct(toCenter) > 0) and 1 or -1
    local lean = math.deg(math.atan(Rider.speed * Rider.speed / (9.81 * R)))
    local sway = math.sin(crankAngle) * 1.6
    root.position = pos
    root.rotation = yawQ * Quaternion(0, 0, (lean * side + sway) * rollSign)

    -- Steering: constant turn angle plus small corrections.
    local steerDeg = math.deg(math.atan(1.04 / R)) * side * rollSign + math.sin(time * 1.3) * 1.5
    steer.rotation = Quaternion(steerDeg * -rollSign, steerAxis)

    wheelAngle = wheelAngle + Rider.speed / WHEEL_R * dt
    crankAngle = crankAngle + Rider.speed / WHEEL_R / 2.4 * dt
    local wq = Quaternion(math.deg(wheelAngle), 0, 0)
    rearWheel.rotation = wq
    frontWheel.rotation = wq
    local cq = Quaternion(math.deg(crankAngle), 0, 0)
    crank.rotation = cq

    -- Pedalling bob
    local bob = math.abs(math.sin(crankAngle)) * 0.02
    rider.position = V(0, bob, 0)

    for s = -1, 1, 2 do
        local p = pedals[s]
        local pp = BB + cq * p.offset + V(p.x, 0, 0)
        p.node.position = pp
        local l = legs[s]
        local target = pp - V(0, bob, 0) + V(0, 0.03, 0)
        local knee = Parts.SolveTwoBone(l.hip, target, THIGH, SHIN, V(s * 0.25, 0.3, 1))
        local thighEnd = l.hip + (knee - l.hip) * 0.55
        Parts.SetLimb(l.thigh, l.hip, thighEnd)
        Parts.SetLimb(l.shin, knee, target)
        l.foot.position = target + V(0, 0.01, 0.05)
        l.foot.rotation = Quaternion(90, 0, 0)
    end

    -- Wing tips follow the grips on the steered handlebar.
    for s = -1, 1, 2 do
        local w = wings[s]
        local grip = HEAD_TOP + steer.rotation * V(s * 0.26, 0.1, -0.07) - V(0, bob, 0)
        Parts.SetEllipsoid(w.arm, w.shoulder, grip + V(0, 0.03, 0), Vector2(0.20, 0.07))
        local mid = w.shoulder + (grip - w.shoulder) * 0.55
        Parts.SetEllipsoid(w.tip, mid + V(0, 0.01, 0), grip + V(s * 0.02, 0.02, 0.06), Vector2(0.16, 0.05))
    end

    -- Head bobs forward on each pedal stroke like a pigeon on a mission.
    local nod = math.sin(crankAngle * 2) * 0.025
    local rest = neck.rest
    local pts = {}
    for i = 1, #rest do
        local t = (i - 1) / (#rest - 1)
        pts[i] = rest[i] + V(0, 0, nod * t * t)
    end
    for i = 1, #pts - 1 do Parts.SetLimb(neck.limbs[i], pts[i], pts[i + 1]) end
    head.position = pts[#pts] + V(0, 0.05, 0.09)
    head.rotation = Quaternion(12 + nod * 60, 0, 0)
    local jiggle = 1.0 + math.sin(time * 9.0) * 0.06 * math.min(Rider.speed / 5, 1)
    pouch.scale = V(0.08, 0.13 * jiggle, pouch.scale.z)

    -- Scarf tails flutter behind the neck.
    for i = 1, 2 do
        local t = scarfTails[i]
        local flap = math.sin(time * 11 + i * 1.7) * 12
        t.position = V((i - 1.5) * 0.08, 1.40 - i * 0.03, 0.02)
        t.rotation = Quaternion(-8 + flap, (i - 1.5) * 25, 0)
        t.scale = V(0.07, 0.015, 0.34)
        t.position = t.position + t.rotation * V(0, 0, -0.17)
    end
end

--- Bike world position (for the camera).
---@return Vector3
function Rider.GetFocus()
    return root.worldPosition + V(0, 1.2, 0)
end

--- Toggle bike lamps.
function Rider.SetLights(level)
    Rider.headLight.brightness = 4.0 * level
    Rider.tailLight.brightness = 0.5 * level
    mats.headLens:SetShaderParameter("MatEmissiveColor", Variant(V(6, 5.6, 5) * level))
    mats.tailLens:SetShaderParameter("MatEmissiveColor", Variant(V(4, 0.2, 0.1) * level))
end

return Rider
