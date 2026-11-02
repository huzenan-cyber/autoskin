--- Engine water example scene: a voxel beach and pier around one water domain, with floating voxel bodies.
--- The water node carries the mesh, the WaterBody and one engine wave surface. Rendering, VoxelPhysicsWorld
--- buoyancy, character swimming and the underwater view all read that one surface; nothing tracks a water level.
local WaterScene = {}
local WaterWake = require("WaterWake")

--- The example scene returned by WaterScene.Create.
---@class WaterSceneDemo
---@field scene Scene
---@field world VoxelPhysicsWorld
---@field water WaterSceneWater
---@field floaters VoxelVolume[]
---@field boat VoxelVolume

--- The water node and its parts, created by CreateWater; SetSurface fills surface and kind.
---@class WaterSceneWater
---@field node Node
---@field mesh Model
---@field model StaticModel
---@field material Material
---@field body WaterBody
---@field far CustomGeometry
---@field farMaterial Material
---@field wake WaterWake
---@field surface FFTWaterSurface|GerstnerWaterSurface|nil
---@field kind string|nil

--- The settings table shared by the scene, the environment and the panel: DEFAULTS plus the environment settings.
---@class WaterSettings
---@field waves string "fft" or "gerstner"
---@field windAngle number
---@field fft {windSpeed: number, fetch: number, choppiness: number, swell: number}
---@field gerstner {waveCount: integer, maxWavelength: number, maxAmplitude: number, spread: number}
---@field material WaterMaterialSettings
---@field sky string "atmosphere" or "procedural"
---@field clouds boolean
---@field cloudCoverage number
---@field sunElevation number
---@field sunAzimuth number
---@field depthFog boolean
---@field ssr boolean
---@field mirror boolean

---@class WaterMaterialSettings
---@field roughness number
---@field detail number
---@field absorption number
---@field scattering number
---@field whitecap number
---@field breaking number
---@field shoreFoam number
---@field crestLight number
---@field caustics boolean
---@field causticsBrightness number

-- Rest water level, horizontal half extent of the square sea and the domain floor, in world meters.
local SEA_LEVEL, SEA_HALF, SEA_FLOOR = 0.0, 64.0, -12.0
-- Water mesh: 0.5 m cells over the central 96 m, then each cell 8% longer out to 256 m from the center, beyond the
-- sea itself, so the far mesh seam stays distant. Lines run straight through, so the
-- coarser rows meet the fine ones without cracks.
local MESH_HALF, MESH_FINE_HALF, MESH_CELL, MESH_GROWTH = 256.0, 48.0, 0.5, 1.08
-- Width of the outer mesh ring over which the vertex waves fade out, in meters (see BuildFarMesh).
local MESH_FADE = 64.0
-- Margin added to the wave bound of the surface when sizing the domain and the visibility bounds, in meters.
local WAVE_MARGIN = 0.5
-- Width of the flat water beyond the sea on every side, in meters; the camera far clip covers it.
local FAR_EXTENT = 2500
-- Unscaled water medium coefficients per meter; the absorption and scattering settings scale them. Clear, strongly
-- scattering water shows the bright seabed and hides the wave relief; a darker medium leaves the reflections, where
-- the waves show, in front.
local ABSORPTION, SCATTERING = Vector3(0.70, 0.18, 0.09), Vector3(0.009, 0.036, 0.042)

local MAT_SAND, MAT_ROCK, MAT_WOOD, MAT_LIGHT_WOOD, MAT_STONE, MAT_HULL, MAT_TRIM = 1, 2, 3, 4, 5, 6, 7

-- Floating bodies, recreated by Reset(). density in kg/m3; buoyancy 0 derives it from the density
-- (1000 / density: wood floats, stone sinks), an explicit value models a sealed hull.
local FLOATERS = {
    {name = "LightCrate", position = Vector3(30, 1.5, -6), size = 10, material = MAT_LIGHT_WOOD, density = 350},
    {name = "Crate", position = Vector3(27, 1.5, -2), size = 10, material = MAT_WOOD, density = 650},
    {name = "HeavyCrate", position = Vector3(31, 1.5, 3), size = 8, material = MAT_WOOD, density = 900},
    {name = "Stone", position = Vector3(36, 1.5, -4), size = 6, material = MAT_STONE, density = 2400},
    {name = "Raft", position = Vector3(18, 1.5, 6), size = {24, 3, 16}, material = MAT_LIGHT_WOOD, density = 450},
}
local BOAT = {position = Vector3(14, 1.0, -10), yaw = 180}

--- Default wave and material settings; main.lua copies them into its settings table.
--- windAngle in degrees: 0 blows toward +Z, 90 toward +X (onto the beach). Shared by both wave surfaces and the
--- foam streaks of the material.
WaterScene.DEFAULTS = {
    waves = "fft",
    windAngle = 100,
    -- FFT ocean: about 0.9 m significant height with a 23 m peak wavelength, so several crests fit in the bay. The
    -- swell runs about 165 m crest to crest, longer than the bay: it would only lift the whole bay.
    fft = {windSpeed = 8, fetch = 30, choppiness = 1.4, swell = 0},
    -- Lake: a few analytic Gerstner waves.
    gerstner = {waveCount = 12, maxWavelength = 14, maxAmplitude = 0.18, spread = 60},
    material = {roughness = 0.045, detail = 0.6, absorption = 1.0, scattering = 1.0, whitecap = 0.4,
                breaking = 0.6, shoreFoam = 0.45, crestLight = 1.0, caustics = true, causticsBrightness = 1.0},
}

-- Wave surfaces by kind. Create adds the component; Apply writes the settings, also while it runs.
local SURFACES = {
    fft = {
        Create = function(node)
            local waves = node:CreateComponent("FFTWaterSurface")
            waves:SetHeight(SEA_LEVEL)
            -- The finest of the four bands tiles 512 / 64 = 8 m, about 3 cm per texel close to the camera, and the
            -- largest holds the long waves of a strong wind over a long fetch and the swell.
            waves:SetPatchLength(512)
            return waves
        end,
        Apply = function(waves, settings)
            local fft = settings.fft
            waves:SetWindSpeed(fft.windSpeed)   -- m/s
            waves:SetWindAngle(settings.windAngle)
            waves:SetFetch(fft.fetch)           -- km of open water upwind
            waves:SetSwell(fft.swell)
            waves:SetChoppiness(fft.choppiness) -- sharper crests
        end,
    },
    gerstner = {
        Create = function(node)
            local waves = node:CreateComponent("GerstnerWaterSurface")
            waves:SetHeight(SEA_LEVEL)
            waves:SetMinWavelength(2)
            waves:SetMinAmplitude(0.02)
            return waves
        end,
        Apply = function(waves, settings)
            local gerstner = settings.gerstner
            waves:SetWaveCount(gerstner.waveCount)
            waves:SetMaxWavelength(gerstner.maxWavelength)
            waves:SetMaxAmplitude(gerstner.maxAmplitude)
            waves:SetWindAngle(settings.windAngle)
            waves:SetDirectionAngularSpread(gerstner.spread)
        end,
    },
}

local function CreatePalette(world)
    world:SetPaletteEntry(MAT_SAND, Color(0.80, 0.70, 0.50), 2.0)
    world:SetPaletteEntry(MAT_ROCK, Color(0.38, 0.36, 0.33), 6.0)
    world:SetPaletteEntry(MAT_WOOD, Color(0.45, 0.30, 0.17), 1.2)
    world:SetPaletteEntry(MAT_LIGHT_WOOD, Color(0.72, 0.56, 0.34), 1.2)
    world:SetPaletteEntry(MAT_STONE, Color(0.50, 0.50, 0.52), 6.0)
    world:SetPaletteEntry(MAT_HULL, Color(0.85, 0.85, 0.82), 3.0)
    world:SetPaletteEntry(MAT_TRIM, Color(0.70, 0.15, 0.10), 3.0)
end

-- Seabed and beach: one static volume of 0.5 m voxels. Each X row rises from a 9 m deep sea floor to a dry beach
-- at +1.5 m; the shoreline crosses the rest level near x = 43.
local function CreateBeach(world)
    local voxel, dims = 0.5, IntVector3(256, 28, 256)
    local ground = world:CreateVolume(dims.x, dims.y, dims.z, voxel, Vector3(-SEA_HALF, SEA_FLOOR, -SEA_HALF))
    local grid = ground:GetGrid()
    for ix = 0, dims.x - 1 do
        local x = -SEA_HALF + (ix + 0.5) * voxel
        local top = Clamp(-9.0 + (x - 16.0) * 0.33, -9.0, 1.5)
        local rows = math.floor((top - SEA_FLOOR) / voxel + 0.5)
        grid:FillBox(ix, 0, 0, ix, rows - 1, dims.z - 1, true)
    end
    grid:PaintBox(0, 0, 0, dims.x - 1, 15, dims.z - 1, MAT_ROCK)
    grid:PaintBox(0, 16, 0, dims.x - 1, dims.y - 1, dims.z - 1, MAT_SAND)
    ground.destructible = false
    world:FinalizeVolume(ground)
    ground:RebuildGeometry()
end

-- Pier from the beach into 3 m of water: a 3 m wide deck at +0.75..+1.0 on posts every 4 m.
local function CreatePier(world)
    local pier = world:CreateVolume(84, 26, 12, 0.25, Vector3(34, -5.5, -1.5))
    local grid = pier:GetGrid()
    grid:FillBox(0, 25, 0, 83, 25, 11, true)
    for x = 0, 83, 16 do
        grid:FillBox(x, 0, 0, x + 1, 24, 1, true)
        grid:FillBox(x, 0, 10, x + 1, 24, 11, true)
    end
    grid:PaintBox(0, 0, 0, 83, 25, 11, MAT_WOOD)
    pier.destructible = false
    world:FinalizeVolume(pier)
    pier:RebuildGeometry()
end

local function CreateFloater(world, spec)
    local size = type(spec.size) == "table" and spec.size or {spec.size, spec.size, spec.size}
    local voxel = 0.1
    local half = Vector3(size[1], size[2], size[3]) * (voxel * 0.5)
    local volume = world:CreateVolume(size[1], size[2], size[3], voxel, spec.position - half)
    local grid = volume:GetGrid()
    grid:FillBox(0, 0, 0, size[1] - 1, size[2] - 1, size[3] - 1, true)
    grid:PaintBox(0, 0, 0, size[1] - 1, size[2] - 1, size[3] - 1, spec.material)
    volume:GetNode().name = spec.name
    volume.density = spec.density
    world:FinalizeVolumeAsDynamic(volume)
    volume:RebuildGeometry()
    return volume
end

-- Small motorboat: a 4.4 m hollow hull. Its buoyancy is the displacement of the sealed shell, not of solid wood,
-- and a lowered center of mass keeps it upright in the swell.
local function CreateBoat(world)
    local nx, ny, nz, voxel = 44, 9, 18, 0.1
    local rotation = Quaternion(BOAT.yaw, Vector3.UP)
    local origin = BOAT.position - rotation * Vector3(nx, 0, nz) * (voxel * 0.5)
    local volume = world:CreateVolume(nx, ny, nz, voxel, origin, rotation)
    local grid = volume:GetGrid()
    grid:FillBox(0, 0, 0, nx - 1, ny - 1, nz - 1, true)
    grid:FillBox(2, 2, 2, nx - 3, ny - 1, nz - 3, false)
    grid:PaintBox(0, 0, 0, nx - 1, ny - 1, nz - 1, MAT_HULL)
    grid:PaintBox(0, ny - 2, 0, nx - 1, ny - 1, nz - 1, MAT_TRIM)
    -- A bench and a short bow deck make the heading visible from the chase camera.
    grid:FillBox(13, 3, 2, 15, 4, nz - 3, true)
    grid:PaintBox(13, 3, 2, 15, 4, nz - 3, MAT_WOOD)
    grid:FillBox(nx - 6, 2, 2, nx - 3, 5, nz - 3, true)
    grid:PaintBox(nx - 6, 5, 2, nx - 3, 5, nz - 3, MAT_TRIM)
    volume:GetNode().name = "Boat"
    volume.destructible = false
    volume:SetAngularDamping(0.35)
    volume:SetCcdEnabled(true)
    volume.density = 600
    volume.buoyancy = 2.4
    volume:SetComOffset(Vector3(0, -0.25, 0))
    world:FinalizeVolumeAsDynamic(volume)
    volume:RebuildGeometry()
    return volume
end

-- Water from the sea edge to the horizon: eight flat pieces of 4 x 4 quads around the water mesh, corners FAR_EXTENT
-- square and edges as long as the mesh. It shares the water node, so its material reads the same engine waves;
-- OceanWaterFar.shader leaves out the vertex waves. The near mesh fades its vertex waves out over the outer
-- MESH_FADE, meeting the far mesh at the rest level without a step. This avoids abrupt view depth, fog and normal
-- filtering changes that would otherwise show a seam below the horizon.
local function BuildFarMesh(geometry)
    geometry:BeginGeometry(0, TRIANGLE_LIST)
    local quads = 4
    for ox = -1, 1 do
        for oz = -1, 1 do
            if ox ~= 0 or oz ~= 0 then
                local sizeX = ox == 0 and MESH_HALF * 2 or FAR_EXTENT
                local sizeZ = oz == 0 and MESH_HALF * 2 or FAR_EXTENT
                local minX = ox * (MESH_HALF + FAR_EXTENT * 0.5) - sizeX * 0.5
                local minZ = oz * (MESH_HALF + FAR_EXTENT * 0.5) - sizeZ * 0.5
                local function vertex(i, j)
                    geometry:DefineVertex(Vector3(minX + sizeX * i / quads, 0, minZ + sizeZ * j / quads))
                    geometry:DefineNormal(Vector3.UP)
                    geometry:DefineTexCoord(Vector2(i / quads, j / quads))
                end
                for j = 0, quads - 1 do
                    for i = 0, quads - 1 do
                        vertex(i, j); vertex(i, j + 1); vertex(i + 1, j)
                        vertex(i + 1, j); vertex(i, j + 1); vertex(i + 1, j + 1)
                    end
                end
            end
        end
    end
    geometry:Commit()
end

local function CreateWaterMaterial(shader)
    local material = Material:new()
    assert(material:SetSurfaceShader(shader))
    -- Engine detail map: detail normals, foam density and the variance each mip averages out.
    assert(material:SetSurfaceTexture("detail_map", cache:GetResource("Texture2D", "Textures/Water/DetailNormal.ktx")))
    return material
end

-- The water node: a flat rest-level grid, its material, the domain and the far water. SetSurface adds the waves and
-- sizes the bounds.
local function CreateWater(scene)
    local node = scene:CreateChild("Water")
    node.position = Vector3(0, SEA_LEVEL, 0)
    local geometry = node:CreateComponent("CustomGeometry")
    geometry:BeginGeometry(0, TRIANGLE_LIST)
    -- Line positions along one axis, shared by X and Z.
    local lines, outer, step = {}, {}, MESH_CELL
    local position = MESH_FINE_HALF
    while position < MESH_HALF do
        position = math.min(position + step, MESH_HALF)
        outer[#outer + 1] = position
        step = step * MESH_GROWTH
    end
    for i = #outer, 1, -1 do lines[#lines + 1] = -outer[i] end
    for i = 0, math.floor(MESH_FINE_HALF * 2 / MESH_CELL) do lines[#lines + 1] = -MESH_FINE_HALF + i * MESH_CELL end
    for i = 1, #outer do lines[#lines + 1] = outer[i] end
    local function vertex(x, z)
        geometry:DefineVertex(Vector3(lines[x], 0, lines[z]))
        geometry:DefineNormal(Vector3.UP)
        geometry:DefineTexCoord(Vector2((x - 1) / (#lines - 1), (z - 1) / (#lines - 1)))
    end
    for z = 1, #lines - 1 do
        for x = 1, #lines - 1 do
            vertex(x, z); vertex(x, z + 1); vertex(x + 1, z)
            vertex(x + 1, z); vertex(x, z + 1); vertex(x + 1, z + 1)
        end
    end
    geometry:Commit()
    -- A static model instead of the CustomGeometry, so its bounds can cover the crests above the flat grid.
    local mesh = Model:new()
    assert(geometry:FillModel(mesh))
    node:RemoveComponent(geometry)
    local surface = node:CreateComponent("StaticModel")
    surface.castShadows = false

    local body = node:CreateComponent("WaterBody")
    body:SetDensity(1025) -- sea water: buoyancy scales with density / 1000
    -- Optional underwater tuning; parameters left out keep the engine defaults.
    local underwater = Material:new()
    underwater:SetShaderParameter("UnderwaterFog", Variant(Vector4(2500, 0.05, 0.2, 0.002)))
    body:SetUnderwaterMaterial(underwater)

    -- After the sea model: the domain's surface drawable is the first Drawable of the node.
    local far = node:CreateComponent("CustomGeometry")
    far.castShadows = false
    BuildFarMesh(far)
    local farMaterial = CreateWaterMaterial("Shaders/OceanWaterFar.shader")
    far.material = farMaterial
    return {node = node, mesh = mesh, model = surface, material = CreateWaterMaterial("Shaders/OceanWater.shader"),
            body = body, far = far, farMaterial = farMaterial, wake = WaterWake.New()}
end

-- Cover the displaced surface: FFT reports its bound on |displacement|, Gerstner the sum of its amplitudes (its
-- horizontal motion stays inside the margin). The domain spans the seabed to above the crests; queries, buoyancy and
-- the underwater view stop at its bounds.
local function UpdateBounds(water)
    local surface = water.surface
    local bound = water.kind == "fft" and surface:GetDisplacementBound() or surface:GetMaxWaveHeight()
    local reach = bound + WAVE_MARGIN
    water.body:SetBounds(Vector3(-SEA_HALF, SEA_FLOOR - SEA_LEVEL, -SEA_HALF), Vector3(SEA_HALF, reach, SEA_HALF))
    water.mesh.boundingBox = BoundingBox(Vector3(-MESH_HALF - reach, -reach, -MESH_HALF - reach),
                                         Vector3(MESH_HALF + reach, reach, MESH_HALF + reach))
    -- StaticModel copies the model bounds when the model is assigned.
    water.model.model = water.mesh
    water.model.material = water.material
end

--- Build the scene with the wave settings. Returns a table owning the Scene; keep it alive until Stop.
---@param settings WaterSettings
---@return WaterSceneDemo
function WaterScene.Create(settings)
    renderer.hdrRendering = true
    local scene = Scene()
    scene:CreateComponent("Octree")
    scene:CreateComponent("WaterWorld")
    local world = scene:CreateComponent("VoxelPhysicsWorld")
    world.gravity = Vector3(0, -9.81, 0)
    -- Palette entries come before any volume is created.
    CreatePalette(world)
    CreateBeach(world)
    CreatePier(world)
    local self = {scene = scene, world = world, water = CreateWater(scene), floaters = {}} --[[@as WaterSceneDemo]]
    WaterScene.SetSurface(self, settings.waves, settings)
    WaterScene.Reset(self)
    return self
end

--- Replace the wave surface: "fft" or "gerstner". Remove the old component instead of disabling it; a domain uses
--- the first wave surface on its node, and a disabled one stops its buoyancy.
function WaterScene.SetSurface(self, kind, settings)
    local water = self.water
    if water.surface ~= nil then water.node:RemoveComponent(water.surface) end
    water.wake:Clear()
    water.surface, water.kind = SURFACES[kind].Create(water.node), kind
    WaterScene.ApplyWaves(self, settings)
end

--- Write the wave settings to the current surface and resize the bounds to the new wave height.
function WaterScene.ApplyWaves(self, settings)
    local water = self.water
    SURFACES[water.kind].Apply(water.surface, settings)
    UpdateBounds(water)
end

--- Feed the time, wind, sun and material settings to both water materials; call once per frame. SurfaceShader
--- materials restore their declared defaults when the shader is rebuilt (an asynchronous compile, a reload), so
--- runtime parameters are written every frame instead of once.
function WaterScene.Update(self, settings, toSun, sunColor)
    local m = settings.material
    local wind = math.rad(settings.windAngle)
    local values = {
        scroll_time = Variant(self.scene:GetWaterWorld():GetTime()),
        wind_direction = Variant(Vector2(math.sin(wind), math.cos(wind))),
        wind_speed = Variant(settings.fft.windSpeed),
        sun_direction = Variant(toSun),
        sun_color = Variant(sunColor),
        roughness_base = Variant(m.roughness),
        detail_strength = Variant(m.detail),
        absorption = Variant(ABSORPTION * m.absorption),
        scattering = Variant(SCATTERING * m.scattering),
        whitecap_threshold = Variant(m.whitecap),
        breaking_jacobian = Variant(m.breaking),
        shore_foam_depth = Variant(m.shoreFoam),
        sss_strength = Variant(m.crestLight),
        caustics_enabled = Variant(m.caustics and 1.0 or 0.0),
        caustics_brightness = Variant(m.causticsBrightness),
        -- Vertex waves fade out over the outer ring of the water mesh, centered on the node.
        wave_fade = Variant(Vector4(0, 0, MESH_HALF - MESH_FADE, MESH_HALF)),
    }
    self.water.wake:Apply({self.water.material, self.water.farMaterial}, self.scene:GetWaterWorld():GetTime())
    for _, material in ipairs({self.water.material, self.water.farMaterial}) do
        for name, value in pairs(values) do material:SetShaderParameter(name, value) end
    end
end

--- Recreate the floating bodies at their start positions.
function WaterScene.Reset(self)
    for _, volume in ipairs(self.floaters) do self.world:RemoveVolume(volume) end
    self.floaters = {}
    self.water.wake:Clear()
    for _, spec in ipairs(FLOATERS) do table.insert(self.floaters, CreateFloater(self.world, spec)) end
    self.boat = CreateBoat(self.world)
    table.insert(self.floaters, self.boat)
end

WaterScene.SEA_LEVEL = SEA_LEVEL
return WaterScene
