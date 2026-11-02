-- Tessendorf initial spectrum h0(k) for the GPU FFT ocean.
-- Directional Phillips spectrum with small-wave suppression, deterministic seed.
-- Adapted from Tests/SurfaceShader/fixtures/surface_shader_compute_ocean/scripts/spectrum.lua.
local M = {}
local tau = 2 * math.pi
local GRAVITY = 9.81

--- Build the initial complex amplitudes h0(k) for an n x n grid.
-- @param n            grid resolution (power of two)
-- @param patchLength  world size of one periodic patch in meters
-- @param opts         { windSpeed (m/s), windDir (Vector2), amplitude, suppress (m), seed }
-- @return VectorBuffer of n*n Vector4 (re, im, 0, 0) ready for ComputeDispatch:CreateBuffer
function M.create(n, patchLength, opts)
    opts = opts or {}
    local windSpeed = opts.windSpeed or 11.0
    local wx, wz = 1.0, 0.45
    if opts.windDir then wx, wz = opts.windDir.x, opts.windDir.y end
    local wl = math.sqrt(wx * wx + wz * wz)
    wx, wz = wx / wl, wz / wl
    local amplitude = opts.amplitude or 0.0022
    local suppress = opts.suppress or 0.18
    local seed = opts.seed or 7183

    local initial = VectorBuffer()
    local dk = tau / patchLength
    local windLength = windSpeed * windSpeed / GRAVITY
    local function random()
        seed = seed * 16807 % 2147483647
        return seed / 2147483647
    end
    for y = 0, n - 1 do
        for x = 0, n - 1 do
            local kx = (x > n / 2 and x - n or x) * dk
            local kz = (y > n / 2 and y - n or y) * dk
            local k2 = kx * kx + kz * kz
            local k = math.sqrt(k2)
            local power = 0
            -- Nyquist axes have no unique signed direction for horizontal displacement.
            if k > 0 and x ~= n / 2 and y ~= n / 2 then
                local alignment = (kx * wx + kz * wz) / k
                -- Waves travelling against the wind are strongly damped rather than removed.
                local directional = alignment * alignment
                if alignment < 0 then directional = directional * 0.07 end
                power = amplitude * math.exp(-1 / (k2 * windLength * windLength)) / (k2 * k2)
                    * directional * math.exp(-k2 * suppress * suppress)
            end
            local radius, angle = math.sqrt(-2 * math.log(math.max(random(), 1e-9))), tau * random()
            local scale = math.sqrt(power * 0.5) * n * n * dk
            initial:WriteVector4(Vector4(radius * math.cos(angle) * scale, radius * math.sin(angle) * scale, 0, 0))
        end
    end
    return initial
end

return M
