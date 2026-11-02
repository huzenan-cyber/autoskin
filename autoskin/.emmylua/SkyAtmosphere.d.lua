---@meta

--- Auto-generated from Graphics/SkyAtmosphere

---@alias SkyAtmosphereTransformMode
---| integer # SkyAtmosphereTransformMode enum values

---@type SkyAtmosphereTransformMode
ATMOSPHERE_TOP_AT_WORLD_ORIGIN = 0
---@type SkyAtmosphereTransformMode
ATMOSPHERE_TOP_AT_COMPONENT = ATMOSPHERE_TOP_AT_COMPONENT
---@type SkyAtmosphereTransformMode
ATMOSPHERE_CENTER_AT_COMPONENT = ATMOSPHERE_CENTER_AT_COMPONENT

---@class SkyAtmosphere : Component
---@field renderSky boolean
---@field bottomRadius number
---@field atmosphereHeight number
---@field groundAlbedo Color
---@field rayleighScattering Color
---@field rayleighScatteringScale number
---@field rayleighScaleHeight number
---@field mieScattering Color
---@field mieScatteringScale number
---@field mieAbsorption Color
---@field mieAbsorptionScale number
---@field mieScaleHeight number
---@field mieAnisotropy number
---@field absorption Color
---@field absorptionScale number
---@field absorptionTipAltitude number
---@field absorptionTipValue number
---@field absorptionWidth number
---@field multiScatteringFactor number
---@field skyLuminanceFactor Color
---@field aerialPerspectiveDistanceScale number
---@field aerialPerspectiveStartDepth number
---@field traceSampleCountScale number
---@field transmittanceMinLightElevation number
---@field transformMode SkyAtmosphereTransformMode
---@field sunLight Light
---@field secondLight Light
---@field planetCenter Vector3
---@field parameterRevision integer
SkyAtmosphere = {}

--- Enable physical background rendering independently of atmosphere lighting, AP and capture.
---@param enable boolean
---@return nil
function SkyAtmosphere:SetRenderSky(enable) end

--- Return the physical background request.
---@return boolean
function SkyAtmosphere:GetRenderSky() end

--- Set the planet ground radius in meters, at least 100.
---@param value number
---@return nil
function SkyAtmosphere:SetBottomRadius(value) end

--- Return the planet ground radius in meters, at least 100.
---@return number
function SkyAtmosphere:GetBottomRadius() end

--- Set the atmosphere thickness in meters, at least 100.
---@param value number
---@return nil
function SkyAtmosphere:SetAtmosphereHeight(value) end

--- Return the atmosphere thickness in meters, at least 100.
---@return number
function SkyAtmosphere:GetAtmosphereHeight() end

--- Set the linear RGB ground albedo in [0, 1].
---@param value Color
---@return nil
function SkyAtmosphere:SetGroundAlbedo(value) end

--- Return the linear RGB ground albedo in [0, 1].
---@return Color
function SkyAtmosphere:GetGroundAlbedo() end

--- Set the nonnegative linear RGB Rayleigh coefficient shape.
---@param value Color
---@return nil
function SkyAtmosphere:SetRayleighScattering(value) end

--- Return the nonnegative linear RGB Rayleigh coefficient shape.
---@return Color
function SkyAtmosphere:GetRayleighScattering() end

--- Set the Rayleigh coefficient scale in inverse kilometers.
---@param value number
---@return nil
function SkyAtmosphere:SetRayleighScatteringScale(value) end

--- Return the Rayleigh coefficient scale in inverse kilometers.
---@return number
function SkyAtmosphere:GetRayleighScatteringScale() end

--- Set the Rayleigh exponential scale height in meters, at least 1.
---@param value number
---@return nil
function SkyAtmosphere:SetRayleighScaleHeight(value) end

--- Return the Rayleigh exponential scale height in meters, at least 1.
---@return number
function SkyAtmosphere:GetRayleighScaleHeight() end

--- Set the nonnegative linear RGB Mie scattering coefficient shape.
---@param value Color
---@return nil
function SkyAtmosphere:SetMieScattering(value) end

--- Return the nonnegative linear RGB Mie scattering coefficient shape.
---@return Color
function SkyAtmosphere:GetMieScattering() end

--- Set the Mie scattering scale in inverse kilometers.
---@param value number
---@return nil
function SkyAtmosphere:SetMieScatteringScale(value) end

--- Return the Mie scattering scale in inverse kilometers.
---@return number
function SkyAtmosphere:GetMieScatteringScale() end

--- Set the nonnegative linear RGB Mie absorption coefficient shape.
---@param value Color
---@return nil
function SkyAtmosphere:SetMieAbsorption(value) end

--- Return the nonnegative linear RGB Mie absorption coefficient shape.
---@return Color
function SkyAtmosphere:GetMieAbsorption() end

--- Set the Mie absorption scale in inverse kilometers.
---@param value number
---@return nil
function SkyAtmosphere:SetMieAbsorptionScale(value) end

--- Return the Mie absorption scale in inverse kilometers.
---@return number
function SkyAtmosphere:GetMieAbsorptionScale() end

--- Set the Mie exponential scale height in meters, at least 1.
---@param value number
---@return nil
function SkyAtmosphere:SetMieScaleHeight(value) end

--- Return the Mie exponential scale height in meters, at least 1.
---@return number
function SkyAtmosphere:GetMieScaleHeight() end

--- Set the Mie Henyey-Greenstein anisotropy in [-0.99, 0.99].
---@param value number
---@return nil
function SkyAtmosphere:SetMieAnisotropy(value) end

--- Return the Mie Henyey-Greenstein anisotropy in [-0.99, 0.99].
---@return number
function SkyAtmosphere:GetMieAnisotropy() end

--- Set the nonnegative linear RGB absorption coefficient shape.
---@param value Color
---@return nil
function SkyAtmosphere:SetAbsorption(value) end

--- Return the nonnegative linear RGB absorption coefficient shape.
---@return Color
function SkyAtmosphere:GetAbsorption() end

--- Set the absorption scale in inverse kilometers.
---@param value number
---@return nil
function SkyAtmosphere:SetAbsorptionScale(value) end

--- Return the absorption scale in inverse kilometers.
---@return number
function SkyAtmosphere:GetAbsorptionScale() end

--- Set the absorption tent peak altitude in meters.
---@param value number
---@return nil
function SkyAtmosphere:SetAbsorptionTipAltitude(value) end

--- Return the absorption tent peak altitude in meters.
---@return number
function SkyAtmosphere:GetAbsorptionTipAltitude() end

--- Set the absorption tent peak density; each layer is saturated to [0, 1].
---@param value number
---@return nil
function SkyAtmosphere:SetAbsorptionTipValue(value) end

--- Return the absorption tent peak density; each layer is saturated to [0, 1].
---@return number
function SkyAtmosphere:GetAbsorptionTipValue() end

--- Set the absorption tent half-width in meters; zero disables this layer.
---@param value number
---@return nil
function SkyAtmosphere:SetAbsorptionWidth(value) end

--- Return the absorption tent half-width in meters; zero disables this layer.
---@return number
function SkyAtmosphere:GetAbsorptionWidth() end

--- Set the atmosphere multiple-scattering multiplier in [0, 100].
---@param value number
---@return nil
function SkyAtmosphere:SetMultiScatteringFactor(value) end

--- Return the atmosphere multiple-scattering multiplier in [0, 100].
---@return number
function SkyAtmosphere:GetMultiScatteringFactor() end

--- Set the nonnegative linear RGB sky luminance multiplier.
---@param value Color
---@return nil
function SkyAtmosphere:SetSkyLuminanceFactor(value) end

--- Return the nonnegative linear RGB sky luminance multiplier.
---@return Color
function SkyAtmosphere:GetSkyLuminanceFactor() end

--- Set the nonnegative optical-depth distance multiplier for aerial perspective.
---@param value number
---@return nil
function SkyAtmosphere:SetAerialPerspectiveDistanceScale(value) end

--- Return the nonnegative optical-depth distance multiplier for aerial perspective.
---@return number
function SkyAtmosphere:GetAerialPerspectiveDistanceScale() end

--- Set the aerial-perspective start distance in meters.
---@param value number
---@return nil
function SkyAtmosphere:SetAerialPerspectiveStartDepth(value) end

--- Return the aerial-perspective start distance in meters.
---@return number
function SkyAtmosphere:GetAerialPerspectiveStartDepth() end

--- Set the view integration sample-count scale in [0.1, 8].
---@param value number
---@return nil
function SkyAtmosphere:SetTraceSampleCountScale(value) end

--- Return the view integration sample-count scale in [0.1, 8].
---@return number
function SkyAtmosphere:GetTraceSampleCountScale() end

--- Set the minimum elevation in degrees for the UE ground-light transmittance approximation.
---@param value number
---@return nil
function SkyAtmosphere:SetTransmittanceMinLightElevation(value) end

--- Return the minimum elevation in degrees for the UE ground-light transmittance approximation.
---@return number
function SkyAtmosphere:GetTransmittanceMinLightElevation() end

--- Set the planet placement policy.
---@param mode SkyAtmosphereTransformMode
---@return nil
function SkyAtmosphere:SetTransformMode(mode) end

--- Return the planet placement policy.
---@return SkyAtmosphereTransformMode
function SkyAtmosphere:GetTransformMode() end

--- Return the resolved planet center in world meters.
---@return Vector3
function SkyAtmosphere:GetPlanetCenter() end

--- Bind the primary directional light; nil disables it.
---@param light Light
---@return nil
function SkyAtmosphere:SetSunLight(light) end

--- Return the primary light.
---@return Light
function SkyAtmosphere:GetSunLight() end

--- Bind an optional second directional light; nil disables it.
---@param light Light
---@return nil
function SkyAtmosphere:SetSecondLight(light) end

--- Return the second light.
---@return Light
function SkyAtmosphere:GetSecondLight() end

--- Return the nonzero parameter revision.
---@return integer
function SkyAtmosphere:GetParameterRevision() end

