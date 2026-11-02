-- GPU FFT ocean (Tessendorf): spectrum evolution, 2x8 Stockham inverse FFT
-- stages, displacement/normal resolve, then a deferred PBR surface.
-- Pipeline adapted from Tests/SurfaceShader/fixtures/surface_shader_compute_ocean.
local spectrum = require("spectrum")

local Ocean = {}

local N, LENGTH = 256, 128
local GRID_SEGMENTS = 512
local SEA_LEVEL = 0.0

local pipeline = {}
---@type Material
local material
---@type Node
local node
Ocean.heightScale = 0.6
Ocean.choppiness = 1.1
Ocean.failed = false

local function check(pass, ok)
    if not ok then error(pass:GetLastError()) end
end

local function createPass(name)
    local pass = ComputeDispatch:new()
    check(pass, pass:SetShader("Shaders/BLGL/" .. name .. ".shader"))
    return pass
end

local function createPipeline()
    local initial = spectrum.create(N, LENGTH, { windSpeed = 11.0, windDir = Vector2(1.0, 0.45) })
    pipeline.spectrum = createPass("OceanSpectrumCS")
    assert(pipeline.spectrum:CreateBuffer("initial_spectrum", N * N, initial), pipeline.spectrum:GetLastError())
    pipeline.hx = { pipeline.spectrum:CreateBuffer("height_dx", N * N), ComputeBuffer:new() }
    pipeline.z = { pipeline.spectrum:CreateBuffer("dz", N * N), ComputeBuffer:new() }
    assert(pipeline.hx[1] and pipeline.z[1], pipeline.spectrum:GetLastError())
    assert(pipeline.hx[2]:SetSize("vec4", N * N), pipeline.hx[2]:GetLastError())
    assert(pipeline.z[2]:SetSize("vec4", N * N), pipeline.z[2]:GetLastError())
    pipeline.fft = createPass("OceanFftCS")
    pipeline.resolve = createPass("OceanResolveCS")
    pipeline.displacement = pipeline.resolve:CreateImage2D("displacement_map", N, N)
    pipeline.normal = pipeline.resolve:CreateImage2D("normal_map", N, N)
    assert(pipeline.displacement and pipeline.normal, pipeline.resolve:GetLastError())
end

local function dispatch(time)
    local sp = pipeline.spectrum
    check(sp, sp:SetShaderParameter("elapsed", time))
    check(sp, sp:DispatchThreads(N, N))
    local src, dst = 1, 2
    local fft = pipeline.fft
    for axis = 0, 1 do
        check(fft, fft:SetShaderParameter("vertical", axis == 1))
        local span = 1
        while span < N do
            check(fft, fft:SetShaderParameter("span", span))
            check(fft, fft:SetBuffer("source_hx", pipeline.hx[src]))
            check(fft, fft:SetBuffer("source_z", pipeline.z[src]))
            check(fft, fft:SetBuffer("target_hx", pipeline.hx[dst]))
            check(fft, fft:SetBuffer("target_z", pipeline.z[dst]))
            check(fft, fft:DispatchThreads(N, N))
            src, dst, span = dst, src, span * 2
        end
    end
    local rs = pipeline.resolve
    check(rs, rs:SetShaderParameter("choppiness", Ocean.choppiness))
    check(rs, rs:SetShaderParameter("height_scale", Ocean.heightScale))
    check(rs, rs:SetBuffer("spatial_hx", pipeline.hx[src]))
    check(rs, rs:SetBuffer("spatial_z", pipeline.z[src]))
    check(rs, rs:DispatchThreads(N, N))
end

local function createSurface(scene)
    material = Material:new()
    assert(material:SetSurfaceShader("Shaders/BLGL/Ocean.shader"), "Ocean.shader failed to load")

    -- Unit plane; the vertex shader remaps it, so only the bounds need to be huge.
    local model = PlaneGeometry(1, 1, GRID_SEGMENTS, GRID_SEGMENTS):ToModel()
    model.boundingBox = BoundingBox(Vector3(-5000, -20, -5000), Vector3(5000, 20, 5000))
    node = scene:CreateChild("Ocean")
    local sm = node:CreateComponent("StaticModel")
    sm.model = model
    sm.material = material
    sm.castShadows = false
    sm:SetOccludee(false)
end

function PelicanOceanComputeFailed()
    if not Ocean.failed then print("[PelicanBike] ComputeDispatchFailed: FFT ocean stopped") end
    Ocean.failed = true
end

--- Create compute pipeline and ocean surface. Returns false when compute is unavailable.
function Ocean.Create(scene)
    if ComputeDispatch == nil or (graphics.GetComputeShaderSupport ~= nil and not graphics:GetComputeShaderSupport()) then
        print("[PelicanBike] Compute shaders are not supported; FFT ocean disabled")
        Ocean.failed = true
        return false
    end
    createPipeline()
    createSurface(scene)
    SubscribeToEvent("ComputeDispatchFailed", "PelicanOceanComputeFailed")
    dispatch(0)
    return true
end

--- Advance the simulation and push per-frame material state.
-- @param time   simulation time in seconds
-- @param camPos camera world position (grid follows it)
-- @param params table of material uniforms (Variant-ready values)
function Ocean.Update(time, camPos, params)
    if Ocean.failed or material == nil then return end
    dispatch(time)
    -- Snap to the finest grid spacing so near vertices stay on the same texels.
    local step = LENGTH / N
    local cx = math.floor(camPos.x / step + 0.5) * step
    local cz = math.floor(camPos.z / step + 0.5) * step
    -- SurfaceShader async compile/reload may reset overrides; re-apply every frame.
    material:SetSurfaceTexture("displacement_map", pipeline.displacement)
    material:SetSurfaceTexture("normal_map", pipeline.normal)
    material:SetShaderParameter("ocean_center", Variant(Vector3(cx, SEA_LEVEL, cz)))
    material:SetShaderParameter("patch_length", Variant(LENGTH))
    material:SetShaderParameter("time_s", Variant(time))
    for name, value in pairs(params) do
        material:SetShaderParameter(name, Variant(value))
    end
end

Ocean.SEA_LEVEL = SEA_LEVEL
return Ocean
