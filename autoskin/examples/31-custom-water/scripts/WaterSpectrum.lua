local M = {}
local tau, gravity = 2 * math.pi, 9.81

-- Match the default engine-water sea, with independent random streams for the four bands.
M.settings = {
    patchLength = 512, windSpeed = 8, fetch = 30, windAngle = 100,
    swell = 0, energy = 1, choppiness = 1.4, seed = 7183, repeatPeriod = 1000
}

local function spreading(s)
    if s < 5 then return -0.000564 * s ^ 4 + 0.00776 * s ^ 3 - 0.044 * s ^ 2 + 0.192 * s + 0.163 end
    return -4.8e-8 * s ^ 4 + 1.07e-5 * s ^ 3 - 0.000953 * s ^ 2 + 0.059 * s + 0.393
end

-- Deep-water directional JONSWAP density per unit angular frequency and heading.
local function sea(wind, fetch, angle, scale, blend, concentration)
    wind = math.max(wind, 0.5)
    local alpha = 0.076 * (gravity * fetch / (wind * wind)) ^ -0.22
    local peak = 22 * (gravity * gravity / (wind * fetch)) ^ (1 / 3)
    local wx, wz = math.sin(angle), math.cos(angle)
    return function(omega, kx, kz, k)
        local sigma = omega <= peak and 0.07 or 0.09
        local offset = (omega - peak) / (sigma * peak)
        local density = scale * alpha * gravity * gravity / omega ^ 5 * math.exp(-1.25 * (peak / omega) ^ 4) *
                            3.3 ^ math.exp(-0.5 * offset * offset)
        local relative = omega / peak
        local s = relative > 1 and 9.77 * relative ^ -2.5 or 6.97 * relative ^ 5
        local e = math.exp(-2 * math.min(relative, 20))
        s = s + 16 * (1 - e) / (1 + e) * concentration * concentration
        local heading = (kx * wx + kz * wz) / k
        local cos2s = spreading(s) * math.max(0.5 * (1 + heading), 1e-6) ^ s
        local cosSquared = heading > 0 and 2 / math.pi * heading * heading or 0
        return density * (cosSquared * (1 - blend) + cos2s * blend)
    end
end

local function high_pass(k, boundary)
    local t = math.max(0, math.min(1, (k - boundary * 0.8) / (boundary * 0.4)))
    return t * t * (3 - 2 * t)
end

--- Build four directional spectra; retain the float32 amplitudes actually uploaded to the GPU.
--- Settings use meters, seconds, m/s, degrees and fetch in kilometers. Each band has n by n modes.
function M.create(n, settings)
    local initial, modes = VectorBuffer(), {}
    local angle = math.rad(settings.windAngle)
    local wind = sea(settings.windSpeed, settings.fetch * 1000, angle, settings.energy, 0.85, 0)
    local swell = sea(6.5, 700000, angle + math.rad(28), settings.energy * settings.swell, 1, 1)
    local split = tau * 8 / settings.patchLength
    for band = 0, 3 do
        local dk = tau / (settings.patchLength * 0.25 ^ band)
        local lower, upper = split * 8 ^ (band - 1), split * 8 ^ band
        local seed = 1 + ((settings.seed > 0 and settings.seed - 1 or 0) + band * 104729) % 2147483646
        local function random()
            seed = seed * 16807 % 2147483647
            return seed / 2147483647
        end
        for y = 0, n - 1 do
            for x = 0, n - 1 do
                local kx = (x > n / 2 and x - n or x) * dk
                local kz = (y > n / 2 and y - n or y) * dk
                local k2 = kx * kx + kz * kz
                local k, power = math.sqrt(k2), 0.0
                -- Smooth complementary windows avoid double-counting energy at band boundaries.
                -- Nyquist axes have no unique signed direction for horizontal displacement.
                if k > 0 and x ~= n / 2 and y ~= n / 2 then
                    local window = band > 0 and high_pass(k, lower) or 1
                    if band < 3 then window = window * (1 - high_pass(k, upper)) end
                    local omega = math.sqrt(gravity * k)
                    local density = wind(omega, kx, kz, k) + swell(omega, kx, kz, k)
                    power = 0.5 * density * (0.5 * omega / k) / k * math.exp(-k2 * 0.012 ^ 2) * window
                end
                local radius, phase = math.sqrt(-2 * math.log(math.max(random(), 1e-9))), tau * random()
                local scale = math.sqrt(power * 0.5) * n * n * dk
                local v = Vector4(radius * math.cos(phase) * scale, radius * math.sin(phase) * scale, 0, 0)
                initial:WriteVector4(v)
                modes[#modes + 1] = {v.x, v.y}
            end
        end
    end
    return initial, modes
end

return M
