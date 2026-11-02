-- Shared primitive / material helpers for procedural props.
local Parts = {}

local PBR = nil
local models = {}

local UP = Vector3(0, 1, 0)

--- Get a cached built-in model ("Box", "Sphere", "Cylinder", "Cone").
function Parts.Model(name)
    if models[name] == nil then
        models[name] = cache:GetResource("Model", "Models/" .. name .. ".mdl")
    end
    return models[name]
end

--- Create an untextured PBR material.
-- @param color    Color base colour
-- @param rough    roughness 0..1
-- @param metal    metallic 0..1
-- @param emissive optional Vector3 emissive colour (HDR)
function Parts.Material(color, rough, metal, emissive)
    PBR = PBR or cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml")
    local m = Material:new()
    m:SetTechnique(0, PBR)
    m:SetShaderParameter("MatDiffColor", Variant(color))
    m:SetShaderParameter("Roughness", Variant(rough or 0.6))
    m:SetShaderParameter("Metallic", Variant(metal or 0.0))
    m:SetShaderParameter("MatEmissiveColor", Variant(emissive or Vector3(0, 0, 0)))
    return m
end

--- Create a child node with a StaticModel.
-- @param model Model resource or built-in name
---@param parent Node
function Parts.Add(parent, model, material, position, scale, rotation, castShadows)
    local n = parent:CreateChild()
    n.position = position or Vector3(0, 0, 0)
    if scale then
        if type(scale) == "number" then n:SetScale(scale) else n.scale = scale end
    end
    if rotation then n.rotation = rotation end
    local sm = n:CreateComponent("StaticModel")
    sm.model = type(model) == "string" and Parts.Model(model) or model
    sm.material = material
    sm.castShadows = castShadows ~= false
    return n
end

--- Place a unit-height Y-aligned model so it spans from a to b (local space of its parent).
-- @param thickness Vector2(x, z) cross-section scale or a number for round sections
---@param n Node
---@param a Vector3
---@param b Vector3
function Parts.Span(n, a, b, thickness)
    local d = b - a
    local len = d:Length()
    local tx, tz = thickness, thickness
    if type(thickness) ~= "number" then tx, tz = thickness.x, thickness.y end
    n.position = (a + b) * 0.5
    if len > 1e-5 then n.rotation = Quaternion(UP, d / len) end
    n.scale = Vector3(tx, math.max(len, 1e-4), tz)
end

--- Create a cylinder (or other Y-aligned unit model) between two points.
function Parts.Segment(parent, material, a, b, radius, model)
    local n = Parts.Add(parent, model or "Cylinder", material)
    Parts.Span(n, a, b, radius * 2)
    return n
end

--- Rounded limb: cylinder plus a sphere at each end. Returns a handle for Parts.SetLimb.
function Parts.Limb(parent, material, a, b, radius)
    local limb = {
        radius = radius,
        body = Parts.Segment(parent, material, a, b, radius),
        j0 = Parts.Add(parent, "Sphere", material, a, radius * 2),
        j1 = Parts.Add(parent, "Sphere", material, b, radius * 2),
    }
    return limb
end

--- Move an existing limb to new end points.
function Parts.SetLimb(limb, a, b)
    Parts.Span(limb.body, a, b, limb.radius * 2)
    limb.j0.position = a
    limb.j1.position = b
end

--- Ellipsoid whose local Z axis points from a to b.
-- @param width  Vector2(x, y) cross-section diameters
function Parts.Ellipsoid(parent, material, a, b, width)
    local n = Parts.Add(parent, "Sphere", material)
    Parts.SetEllipsoid(n, a, b, width)
    return n
end

---@param n Node
---@param a Vector3
---@param b Vector3
---@param width Vector2
function Parts.SetEllipsoid(n, a, b, width)
    local d = b - a
    local len = d:Length()
    n.position = (a + b) * 0.5
    if len > 1e-5 then n.rotation = Quaternion(Vector3(0, 0, 1), d / len) end
    n.scale = Vector3(width.x, width.y, len)
end

--- Two-bone IK: returns the knee/elbow position.
-- @param hint direction the joint should bend toward
---@param root Vector3
---@param target Vector3
---@param lenA number
---@param lenB number
---@param hint Vector3
---@return Vector3
function Parts.SolveTwoBone(root, target, lenA, lenB, hint)
    local d = target - root
    local dist = math.max(math.min(d:Length(), lenA + lenB - 0.001), math.abs(lenA - lenB) + 0.001)
    local dir = d:Normalized()
    local cosA = (lenA * lenA + dist * dist - lenB * lenB) / (2 * lenA * dist)
    cosA = math.max(-1, math.min(1, cosA))
    local sinA = math.sqrt(1 - cosA * cosA)
    local perp = hint - dir * hint:DotProduct(dir)
    if perp:Length() < 1e-5 then perp = Vector3(0, 0, 1) end
    perp = perp:Normalized()
    return root + dir * (lenA * cosA) + perp * (lenA * sinA)
end

--- Linear interpolation helpers for numbers and colours.
function Parts.Lerp(a, b, t) return a + (b - a) * t end

function Parts.LerpColor(a, b, t)
    return Color(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1.0)
end

function Parts.Smoothstep(e0, e1, x)
    local t = math.max(0, math.min(1, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)
end

return Parts
