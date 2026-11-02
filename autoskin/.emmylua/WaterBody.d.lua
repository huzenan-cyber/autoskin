---@meta

--- Auto-generated from Scene/WaterBody

---@alias WaterSurfaceStatus
---| integer # WaterSurfaceStatus enum values

---@type WaterSurfaceStatus
WATER_SURFACE_NO_DOMAIN = WATER_SURFACE_NO_DOMAIN
---@type WaterSurfaceStatus
WATER_SURFACE_UNSUPPORTED = WATER_SURFACE_UNSUPPORTED
---@type WaterSurfaceStatus
WATER_SURFACE_INVALID = WATER_SURFACE_INVALID
---@type WaterSurfaceStatus
WATER_SURFACE_VALID = WATER_SURFACE_VALID

---@class WaterSurfaceSample
---@overload fun(): WaterSurfaceSample
---@field status WaterSurfaceStatus
---@field queryPosition Vector3
---@field time number
---@field bodyID integer
---@field position Vector3
---@field normal Vector3
---@field immersionDepth number
---@field velocity Vector3
---@field hasVelocity boolean
---@field density number
WaterSurfaceSample = {}

---@return WaterSurfaceSample
function WaterSurfaceSample.new() end

---@return boolean
function WaterSurfaceSample:IsValid() end


---@class WaterSurface : Component
WaterSurface = {}

---@param worldPosition Vector3
---@param time number
---@return WaterSurfaceSample
function WaterSurface:SampleSurface(worldPosition, time) end


---@class PlaneWaterSurface : WaterSurface
PlaneWaterSurface = {}

---@param height number
---@return nil
function PlaneWaterSurface:SetHeight(height) end

---@return number
function PlaneWaterSurface:GetHeight() end


---@class GerstnerWaterSurface : WaterSurface
GerstnerWaterSurface = {}

---@param height number
---@return nil
function GerstnerWaterSurface:SetHeight(height) end

---@param count integer
---@return nil
function GerstnerWaterSurface:SetWaveCount(count) end

---@param seed integer
---@return nil
function GerstnerWaterSurface:SetSeed(seed) end

---@param randomness number
---@return nil
function GerstnerWaterSurface:SetRandomness(randomness) end

---@param wavelength number
---@return nil
function GerstnerWaterSurface:SetMinWavelength(wavelength) end

---@param wavelength number
---@return nil
function GerstnerWaterSurface:SetMaxWavelength(wavelength) end

---@param falloff number
---@return nil
function GerstnerWaterSurface:SetWavelengthFalloff(falloff) end

---@param amplitude number
---@return nil
function GerstnerWaterSurface:SetMinAmplitude(amplitude) end

---@param amplitude number
---@return nil
function GerstnerWaterSurface:SetMaxAmplitude(amplitude) end

---@param falloff number
---@return nil
function GerstnerWaterSurface:SetAmplitudeFalloff(falloff) end

---@param degrees number
---@return nil
function GerstnerWaterSurface:SetWindAngle(degrees) end

---@param degrees number
---@return nil
function GerstnerWaterSurface:SetDirectionAngularSpread(degrees) end

---@param steepness number
---@return nil
function GerstnerWaterSurface:SetSmallWaveSteepness(steepness) end

---@param steepness number
---@return nil
function GerstnerWaterSurface:SetLargeWaveSteepness(steepness) end

---@param falloff number
---@return nil
function GerstnerWaterSurface:SetSteepnessFalloff(falloff) end

---@param depth number
---@return nil
function GerstnerWaterSurface:SetWaveAttenuationDepth(depth) end

---@return number
function GerstnerWaterSurface:GetHeight() end

---@return integer
function GerstnerWaterSurface:GetWaveCount() end

---@return integer
function GerstnerWaterSurface:GetSeed() end

---@return number
function GerstnerWaterSurface:GetRandomness() end

---@return number
function GerstnerWaterSurface:GetMinWavelength() end

---@return number
function GerstnerWaterSurface:GetMaxWavelength() end

---@return number
function GerstnerWaterSurface:GetWavelengthFalloff() end

---@return number
function GerstnerWaterSurface:GetMinAmplitude() end

---@return number
function GerstnerWaterSurface:GetMaxAmplitude() end

---@return number
function GerstnerWaterSurface:GetAmplitudeFalloff() end

---@return number
function GerstnerWaterSurface:GetWindAngle() end

---@return number
function GerstnerWaterSurface:GetDirectionAngularSpread() end

---@return number
function GerstnerWaterSurface:GetSmallWaveSteepness() end

---@return number
function GerstnerWaterSurface:GetLargeWaveSteepness() end

---@return number
function GerstnerWaterSurface:GetSteepnessFalloff() end

---@return number
function GerstnerWaterSurface:GetWaveAttenuationDepth() end

---@return number
function GerstnerWaterSurface:GetMaxWaveHeight() end


---@class FFTWaterSurface : WaterSurface
FFTWaterSurface = {}

---@param height number
---@return nil
function FFTWaterSurface:SetHeight(height) end

---@param length number
---@return nil
function FFTWaterSurface:SetPatchLength(length) end

---@param speed number
---@return nil
function FFTWaterSurface:SetWindSpeed(speed) end

---@param degrees number
---@return nil
function FFTWaterSurface:SetWindAngle(degrees) end

---@param kilometers number
---@return nil
function FFTWaterSurface:SetFetch(kilometers) end

---@param ratio number
---@return nil
function FFTWaterSurface:SetSwell(ratio) end

---@param scale number
---@return nil
function FFTWaterSurface:SetEnergyScale(scale) end

---@param choppiness number
---@return nil
function FFTWaterSurface:SetChoppiness(choppiness) end

---@param seed integer
---@return nil
function FFTWaterSurface:SetSeed(seed) end

---@param seconds number
---@return nil
function FFTWaterSurface:SetRepeatPeriod(seconds) end

---@param depth number
---@return nil
function FFTWaterSurface:SetWaveAttenuationDepth(depth) end

---@return number
function FFTWaterSurface:GetHeight() end

---@return number
function FFTWaterSurface:GetPatchLength() end

---@return number
function FFTWaterSurface:GetWindSpeed() end

---@return number
function FFTWaterSurface:GetWindAngle() end

---@return number
function FFTWaterSurface:GetFetch() end

---@return number
function FFTWaterSurface:GetSwell() end

---@return number
function FFTWaterSurface:GetEnergyScale() end

---@return number
function FFTWaterSurface:GetChoppiness() end

---@return integer
function FFTWaterSurface:GetSeed() end

---@return number
function FFTWaterSurface:GetRepeatPeriod() end

---@return number
function FFTWaterSurface:GetWaveAttenuationDepth() end

---@param band integer
---@return number
function FFTWaterSurface:GetBandLength(band) end

---@return number
function FFTWaterSurface:GetDisplacementBound() end

---@param worldXZ Vector2
---@param time number
---@return Vector3
function FFTWaterSurface:GetDisplacement(worldXZ, time) end


---@class WaterBody : Component
WaterBody = {}

---@param minimum Vector3
---@param maximum Vector3
---@return nil
function WaterBody:SetBounds(minimum, maximum) end

---@return BoundingBox
function WaterBody:GetBounds() end

---@param slot integer
---@return nil
function WaterBody:SetMaterialSlot(slot) end

---@return integer
function WaterBody:GetMaterialSlot() end

---@param priority integer
---@return nil
function WaterBody:SetPriority(priority) end

---@return integer
function WaterBody:GetPriority() end

---@param density number
---@return nil
function WaterBody:SetDensity(density) end

---@return number
function WaterBody:GetDensity() end

---@param material Material
---@return nil
function WaterBody:SetUnderwaterMaterial(material) end

---@return Material
function WaterBody:GetUnderwaterMaterial() end

---@param worldPosition Vector3
---@return boolean
function WaterBody:Contains(worldPosition) end

---@param worldPosition Vector3
---@param time number
---@return WaterSurfaceSample
function WaterBody:SampleSurface(worldPosition, time) end

---@param mask integer
---@return nil
function WaterBody:SetGroundViewMask(mask) end

---@return integer
function WaterBody:GetGroundViewMask() end

---@param resolution integer
---@return nil
function WaterBody:SetGroundResolution(resolution) end

---@return integer
function WaterBody:GetGroundResolution() end

---@return nil
function WaterBody:CaptureGround() end

---@param worldXZ Rect
---@param width integer
---@param height integer
---@param heights number[]
---@return nil
function WaterBody:SetGroundHeights(worldXZ, width, height, heights) end

---@return nil
function WaterBody:ClearGround() end

---@return boolean
function WaterBody:HasGround() end

---@param worldPosition Vector3
---@param height number
---@return boolean
function WaterBody:GetGroundHeight(worldPosition, height) end


---@class WaterWorld : Component
WaterWorld = {}

---@return number
function WaterWorld:GetTime() end

---@param worldPosition Vector3
---@param time number
---@return WaterSurfaceSample
function WaterWorld:SampleSurface(worldPosition, time) end

---@param positions Vector3[]
---@param time number
---@return WaterSurfaceSample[]
function WaterWorld:SampleSurfaces(positions, time) end

