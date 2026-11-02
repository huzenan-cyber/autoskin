local spectrum = require("WaterSpectrum")
local Ocean = {}
Ocean.__index = Ocean
local N, BANDS = 256, 4
local settings = spectrum.settings

local function check(pass, ok) assert(ok, pass:GetLastError()) end

local function compute(name)
    local pass = ComputeDispatch:new()
    check(pass, pass:SetShader("Shaders/WaterExample/" .. name .. ".shader"))
    return pass
end

--- Create one finite, world-aligned FFT water patch. Keep its node at the identity transform.
function Ocean.New(scene)
    local self = setmetatable({}, Ocean)
    self:Init(scene)
    return self
end

--- Initialize the shared simulation resources, mesh and finite camera-query domain.
function Ocean:Init(scene)
    scene:GetWaterWorld()
    assert(graphics:GetComputeShaderSupport(), "This water example requires desktop compute support")
    local initial, modes = spectrum.create(N, settings)
    self.modes, self.settings = modes, settings
    local heightBound = 0.0
    for _, mode in ipairs(modes) do heightBound = heightBound + math.sqrt(mode[1] ^ 2 + mode[2] ^ 2) end
    heightBound = heightBound * 2 / (N * N) * 1.001 + 0.01
    local extent = 64 + heightBound * settings.choppiness
    self.spectrum = compute("OceanSpectrumCS")
    local initialBuffer = self.spectrum:CreateBuffer("initial_spectrum", N * N * BANDS, initial)
    local heightBuffer = self.spectrum:CreateBuffer("height_dx", N * N * BANDS)
    local displacementBuffer = self.spectrum:CreateBuffer("dz", N * N * BANDS)
    if not initialBuffer or not heightBuffer or not displacementBuffer then error(self.spectrum:GetLastError()) end
    self.hx = {heightBuffer, ComputeBuffer:new()}
    self.z = {displacementBuffer, ComputeBuffer:new()}
    assert(self.hx[2]:SetSize("vec4", N * N * BANDS))
    assert(self.z[2]:SetSize("vec4", N * N * BANDS))
    self.fft, self.resolve = compute("OceanFftCS"), compute("OceanResolveCS")
    check(self.spectrum, self.spectrum:SetShaderParameter("patch_length", settings.patchLength))
    check(self.spectrum, self.spectrum:SetShaderParameter("repeat_period", settings.repeatPeriod))
    check(self.resolve, self.resolve:SetShaderParameter("patch_length", settings.patchLength))
    check(self.resolve, self.resolve:SetShaderParameter("choppiness", settings.choppiness))
    ---@type table<integer, {texture: Texture2D, id: integer, time: number}>
    self.slots = {}
    for i = 1, 3 do
        local texture = self.resolve:CreateImage2D("displacement_map", (N + 2) * BANDS, (N + 2) * 2)
        if not texture then error(self.resolve:GetLastError()) end
        self.slots[i] = {
            texture = texture,
            id = 0,
            time = 0
        }
        self:Produce(i, 0, 0)
    end
    self.previous, self.display, self.latest, self.serial = 1, 2, 3, 0
    self.material = Material:new()
    assert(self.material:SetSurfaceShader("Shaders/WaterExample/Water.shader"))
    self.material:SetShaderParameter("patch_length", Variant(settings.patchLength))
    self:Bind()
    self.node = scene:CreateChild("FFTWater")
    self.surface = self.node:CreateComponent("CustomGeometry")
    local mesh = self.surface
    mesh:BeginGeometry(0, TRIANGLE_LIST)
    local function vertex(x, z)
        mesh:DefineVertex(Vector3(x * 0.5 - 64, 0, z * 0.5 - 64))
        mesh:DefineNormal(Vector3.UP)
        mesh:DefineTexCoord(Vector2(x / N, z / N))
    end
    for z = 0, N - 1 do
        for x = 0, N - 1 do
            vertex(x, z);
            vertex(x, z + 1);
            vertex(x + 1, z)
            vertex(x + 1, z);
            vertex(x, z + 1);
            vertex(x + 1, z + 1)
        end
    end
    mesh:Commit()
    local model = Model:new()
    assert(mesh:FillModel(model))
    model.boundingBox = BoundingBox(Vector3(-extent, -heightBound, -extent), Vector3(extent, heightBound, extent))
    self.node:RemoveComponent(mesh)
    self.surface = self.node:CreateComponent("StaticModel")
    self.surface:SetModel(model)
    self.surface:SetMaterial(self.material)
    self.surface:SetOccludee(false)
    self.body = self.node:CreateComponent("WaterBody")
    self.body:SetBounds(Vector3(-extent, -20 - heightBound, -extent), Vector3(extent, heightBound, extent))
end

--- Produce four bands of displacement and derivatives in one padded atlas per snapshot.
--- FFT scratch buffers never serve as display history; the three atlases occupy three sampler slots.
function Ocean:Produce(slot, time, id)
    check(self.spectrum, self.spectrum:SetShaderParameter("elapsed", time % settings.repeatPeriod))
    check(self.spectrum, self.spectrum:DispatchThreads(N, N, BANDS))
    local src, dst = 1, 2
    for axis = 0, 1 do
        check(self.fft, self.fft:SetShaderParameter("vertical", Variant(axis == 1)))
        for power = 0, 7 do
            check(self.fft, self.fft:SetShaderParameter("span", Variant(2 ^ power)))
            check(self.fft, self.fft:SetBuffer("source_hx", assert(self.hx[src])))
            check(self.fft, self.fft:SetBuffer("source_z", assert(self.z[src])))
            check(self.fft, self.fft:SetBuffer("target_hx", assert(self.hx[dst])))
            check(self.fft, self.fft:SetBuffer("target_z", assert(self.z[dst])))
            check(self.fft, self.fft:DispatchThreads(N, N, BANDS))
            src, dst = dst, src
        end
    end
    check(self.resolve, self.resolve:SetBuffer("spatial_hx", assert(self.hx[src])))
    check(self.resolve, self.resolve:SetBuffer("spatial_z", assert(self.z[src])))
    check(self.resolve, self.resolve:SetImage("displacement_map", self.slots[slot].texture))
    check(self.resolve, self.resolve:DispatchThreads(N + 2, N + 2, BANDS))
    self.slots[slot].id, self.slots[slot].time = id, time
end

--- Bind snapshot roles after rotation, before the renderer submits this frame's consumers.
function Ocean:Bind()
    self.material:SetShaderParameter("display_time", Variant(self.slots[self.display].time))
    assert(self.material:SetSurfaceTexture("fft_previous", self.slots[self.previous].texture))
    assert(self.material:SetSurfaceTexture("fft_display", self.slots[self.display].texture))
    assert(self.material:SetSurfaceTexture("fft_query", self.slots[self.latest].texture))
end

--- Call once in each rendering Update; pass nil to pause simulation while preserving display history.
--- A simulation step writes only the slot distinct from both the previous and current display.
function Ocean:Advance(simulationTime)
    self.previous, self.display = self.display, self.latest
    if simulationTime ~= nil then
        local target = 1
        while target == self.previous or target == self.display do target = target + 1 end
        self.serial = self.serial + 1
        self:Produce(target, simulationTime, self.serial)
        self.latest = target
    end
    self:Bind()
end

--- Return immutable metadata for logging; slot numbers alone are not snapshot identities.
function Ocean:Snapshot()
    local p, d, q = self.slots[self.previous], self.slots[self.display], self.slots[self.latest]
    return {
        previous = p.id,
        display = d.id,
        query = q.id,
        previousTime = p.time,
        displayTime = d.time,
        queryTime = q.time
    }
end

return Ocean
