-- E5: draw a SplinePath and drag its child control points with Handles.
-- Copy into the game project's Editor/ folder.

local CP_PREFIX = "SplineCP_"
local DEMO_NAME = "SplinePathDemo"
local CURVE_COLOR = Color(1, 0.55, 0.08, 1)

local function FrontOfCamera(distance)
    local ray = Editor.SceneView.MouseRay()
    if ray and ray.direction then
        local dir = ray.direction
        if dir:Length() > 0.001 then
            return ray.origin + dir:Normalized() * distance
        end
    end
    return Vector3(0, 2, 0)
end

local function CollectControlPoints(root)
    local cps = {}
    if not root then
        return cps
    end
    for i = 0, root:GetNumChildren() - 1 do
        local child = root:GetChild(i)
        if child then
            local name = child:GetName() or ""
            if string.sub(name, 1, #CP_PREFIX) == CP_PREFIX then
                cps[#cps + 1] = child
            end
        end
    end
    table.sort(cps, function(a, b)
        return (a:GetName() or "") < (b:GetName() or "")
    end)
    return cps
end

local function FindSpline()
    local scene = Editor.Scene.Get()
    if not scene then
        return nil
    end
    local demo = scene:GetChild(DEMO_NAME, true)
    if demo then
        local spline = demo:GetComponent("SplinePath")
        if spline then
            return spline
        end
    end
    return scene:GetComponent("SplinePath", true)
end

local function SampleCurve(spline, fallbackPoints)
    local poly = {}
    local steps = 32
    local first = nil
    local spread = 0
    for i = 0, steps do
        local p = spline:GetPoint(i / steps)
        if p then
            poly[#poly + 1] = p
            if not first then
                first = p
            else
                local dx = (p.x or p.x_ or 0) - (first.x or first.x_ or 0)
                local dy = (p.y or p.y_ or 0) - (first.y or first.y_ or 0)
                local dz = (p.z or p.z_ or 0) - (first.z or first.z_ or 0)
                spread = math.max(spread, dx * dx + dy * dy + dz * dz)
            end
        end
    end
    if spread > 0.0001 then
        return poly
    end
    return fallbackPoints
end

Editor.MenuItem("Tools/SplinePath/Create Demo", function()
    local scene = Editor.Scene.Get()
    if not scene then
        Editor.Dialog.Info("SplinePath", "No scene is open.")
        return
    end
    local origin = FrontOfCamera(10)
    local offsets = {
        Vector3(0, 0, 0),
        Vector3(3, 1.4, 2),
        Vector3(6, -0.2, 0.5),
        Vector3(9, 1.1, -1.5),
    }
    Editor.Undo.Begin("Create SplinePath Demo")
    local root = scene:CreateChild(DEMO_NAME)
    root:SetWorldPosition(origin)
    local spline = root:CreateComponent("SplinePath")
    if spline.SetInterpolationMode then
        spline:SetInterpolationMode(CATMULL_ROM_FULL_CURVE or 3)
    end
    for i = 1, #offsets do
        local cp = root:CreateChild(CP_PREFIX .. i)
        cp:SetWorldPosition(origin + offsets[i])
        spline:AddControlPoint(cp)
    end
    Editor.Undo.End()
    Editor.Selection.SetActiveNode(root)
    Editor.SceneView.Focus(root)
    Editor.Log("Created SplinePathDemo in front of the camera. Orange curve + 4 drag points.")
    Editor.Dialog.Info("SplinePath",
        "Created in front of the camera.\nYou should see an orange curve and 4 cyan points.\nDrag the points to reshape.")
end, {
    description = "Create a SplinePath with child control points",
})

local function DuringSceneGUI(sceneView)
    local spline = FindSpline()
    if not spline then
        return
    end
    local root = spline:GetNode()
    local cps = CollectControlPoints(root)
    local fallback = {}
    for i = 1, #cps do
        fallback[i] = cps[i]:GetWorldPosition()
    end
    local poly = SampleCurve(spline, fallback)
    if #poly >= 2 then
        Editor.Handles.DrawPolyline(poly, CURVE_COLOR)
        -- Spheres already have a 2D overlay; keep a few so the path is visible
        -- even before the editor binary picks up line overlay.
        for i = 1, #poly, 2 do
            Editor.Handles.DrawSphere(poly[i], 0.05, CURVE_COLOR)
        end
    end

    for i = 1, #cps do
        local child = cps[i]
        local pos = child:GetWorldPosition()
        local newPos, changed = Editor.Handles.PositionHandle(
            "spline_cp_" .. child:GetID(), pos, child:GetWorldRotation())
        if changed then
            Editor.Undo.Record(child)
            child:SetWorldPosition(newPos)
        end
    end
end


Editor.SceneView.duringSceneGui:AddListener(DuringSceneGUI)
