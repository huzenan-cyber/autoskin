---@meta

--- Auto-generated from Graphics/VolumetricCloud

---@alias VolumetricCloudSkyLightingMode
---| integer # VolumetricCloudSkyLightingMode enum values

---@type VolumetricCloudSkyLightingMode
CLOUD_SKY_ZONE_CAPTURED = 0
---@type VolumetricCloudSkyLightingMode
CLOUD_SKY_DIRECTIONAL_ONLY = CLOUD_SKY_DIRECTIONAL_ONLY
---@type VolumetricCloudSkyLightingMode
CLOUD_SKY_AUTO = CLOUD_SKY_AUTO

---@class VolumetricCloud : Component
---@field layerBottomAltitude number
---@field layerHeight number
---@field planetRadius number
---@field planetCenter Vector3
---@field tracingStartDistance number
---@field tracingMaxDistance number
---@field groundAlbedo Color
---@field skyLightBottomOcclusion number
---@field densityScale number
---@field albedo Color
---@field emissive Color
---@field phaseG number
---@field phaseG2 number
---@field phaseBlend number
---@field multiScattering number
---@field multiScatteringOcclusion number
---@field multiScatteringEccentricity number
---@field multiScatteringOctaves integer
---@field groundContribution boolean
---@field cloudGlobalScale number
---@field cloudGlobalCoverage number
---@field viewSampleCountScale number
---@field shadowSampleCountScale number
---@field shadowTracingDistance number
---@field tracingStartMaxDistance number
---@field tracingMaxDistanceFromCamera boolean
---@field conservativeDensity number
---@field grayscaleLighting boolean
---@field windVelocity Vector2
---@field weatherTime number
---@field perSampleAtmosphereTransmittance boolean
---@field aerialPerspectiveEnabled boolean
---@field cloudShadowEnabled boolean
---@field cloudShadowExtent number UE CloudShadowExtent in meters for the primary sun (default 150000).
---@field skyAOEnabled boolean
---@field renderInMainPass boolean
---@field stopTracingTransmittance number
---@field skyLightingMode VolumetricCloudSkyLightingMode
---@field heightProfile Texture2D
---@field weatherMap Texture2D
---@field shapeNoise Texture3D
---@field material Material Custom shader_type cloud material; nil uses the built-in cloud.
VolumetricCloud = {}

---@param altitude number
---@return nil
function VolumetricCloud:SetLayerBottomAltitude(altitude) end

---@return number
function VolumetricCloud:GetLayerBottomAltitude() end

---@param height number
---@return nil
function VolumetricCloud:SetLayerHeight(height) end

---@return number
function VolumetricCloud:GetLayerHeight() end

---@param radius number
---@return nil
function VolumetricCloud:SetPlanetRadius(radius) end

---@return number
function VolumetricCloud:GetPlanetRadius() end

---@param center Vector3
---@return nil
function VolumetricCloud:SetPlanetCenter(center) end

---@return Vector3
function VolumetricCloud:GetPlanetCenter() end

---@param distance number
---@return nil
function VolumetricCloud:SetTracingStartDistance(distance) end

---@return number
function VolumetricCloud:GetTracingStartDistance() end

---@param distance number
---@return nil
function VolumetricCloud:SetTracingMaxDistance(distance) end

---@return number
function VolumetricCloud:GetTracingMaxDistance() end

---@param color Color
---@return nil
function VolumetricCloud:SetGroundAlbedo(color) end

---@return Color
function VolumetricCloud:GetGroundAlbedo() end

---@param value number
---@return nil
function VolumetricCloud:SetSkyLightBottomOcclusion(value) end

---@return number
function VolumetricCloud:GetSkyLightBottomOcclusion() end

---@param value number
---@return nil
function VolumetricCloud:SetDensityScale(value) end

---@return number
function VolumetricCloud:GetDensityScale() end

---@param color Color
---@return nil
function VolumetricCloud:SetAlbedo(color) end

---@return Color
function VolumetricCloud:GetAlbedo() end

---@param color Color
---@return nil
function VolumetricCloud:SetEmissive(color) end

---@return Color
function VolumetricCloud:GetEmissive() end

---@param value number
---@return nil
function VolumetricCloud:SetPhaseG(value) end

---@return number
function VolumetricCloud:GetPhaseG() end

---@param value number
---@return nil
function VolumetricCloud:SetPhaseG2(value) end

---@return number
function VolumetricCloud:GetPhaseG2() end

---@param value number
---@return nil
function VolumetricCloud:SetPhaseBlend(value) end

---@return number
function VolumetricCloud:GetPhaseBlend() end

---@param value number
---@return nil
function VolumetricCloud:SetMultiScattering(value) end

---@return number
function VolumetricCloud:GetMultiScattering() end

---@param value number
---@return nil
function VolumetricCloud:SetMultiScatteringOcclusion(value) end

---@return number
function VolumetricCloud:GetMultiScatteringOcclusion() end

---@param value number
---@return nil
function VolumetricCloud:SetMultiScatteringEccentricity(value) end

---@return number
function VolumetricCloud:GetMultiScatteringEccentricity() end

---@param value integer
---@return nil
function VolumetricCloud:SetMultiScatteringOctaves(value) end

---@return integer
function VolumetricCloud:GetMultiScatteringOctaves() end

---@param value boolean
---@return nil
function VolumetricCloud:SetGroundContribution(value) end

---@return boolean
function VolumetricCloud:GetGroundContribution() end

---@param value number
---@return nil
function VolumetricCloud:SetCloudGlobalScale(value) end

---@return number
function VolumetricCloud:GetCloudGlobalScale() end

---@param value number
---@return nil
function VolumetricCloud:SetCloudGlobalCoverage(value) end

---@return number
function VolumetricCloud:GetCloudGlobalCoverage() end

---@param value number
---@return nil
function VolumetricCloud:SetViewSampleCountScale(value) end

---@return number
function VolumetricCloud:GetViewSampleCountScale() end

---@param value number
---@return nil
function VolumetricCloud:SetShadowSampleCountScale(value) end

---@return number
function VolumetricCloud:GetShadowSampleCountScale() end

---@param value number
---@return nil
function VolumetricCloud:SetShadowTracingDistance(value) end

---@return number
function VolumetricCloud:GetShadowTracingDistance() end

---@param value number
---@return nil
function VolumetricCloud:SetTracingStartMaxDistance(value) end

---@return number
function VolumetricCloud:GetTracingStartMaxDistance() end

---@param value boolean
---@return nil
function VolumetricCloud:SetTracingMaxDistanceFromCamera(value) end

---@return boolean
function VolumetricCloud:GetTracingMaxDistanceFromCamera() end

---@param value number
---@return nil
function VolumetricCloud:SetConservativeDensity(value) end

---@return number
function VolumetricCloud:GetConservativeDensity() end

---@param enable boolean
---@return nil
function VolumetricCloud:SetGrayscaleLighting(enable) end

---@return boolean
function VolumetricCloud:GetGrayscaleLighting() end

---@param velocity Vector2
---@return nil
function VolumetricCloud:SetWindVelocity(velocity) end

---@return Vector2
function VolumetricCloud:GetWindVelocity() end

---@param time number
---@return nil
function VolumetricCloud:SetWeatherTime(time) end

---@return number
function VolumetricCloud:GetWeatherTime() end

---@param enable boolean
---@return nil
function VolumetricCloud:SetPerSampleAtmosphereTransmittance(enable) end

---@return boolean
function VolumetricCloud:GetPerSampleAtmosphereTransmittance() end

---@param enable boolean
---@return nil
function VolumetricCloud:SetAerialPerspectiveEnabled(enable) end

---@return boolean
function VolumetricCloud:GetAerialPerspectiveEnabled() end

---@param enable boolean
---@return nil
function VolumetricCloud:SetCloudShadowEnabled(enable) end

---@return boolean
function VolumetricCloud:GetCloudShadowEnabled() end

--- Set the primary sun shadow extent in meters, clamped to at least 1000 meters.
---@param extent number
---@return nil
function VolumetricCloud:SetCloudShadowExtent(extent) end

--- Return the primary sun shadow extent in meters; smaller values improve local detail.
---@return number
function VolumetricCloud:GetCloudShadowExtent() end

---@param enable boolean
---@return nil
function VolumetricCloud:SetSkyAOEnabled(enable) end

---@return boolean
function VolumetricCloud:GetSkyAOEnabled() end

---@param enable boolean
---@return nil
function VolumetricCloud:SetRenderInMainPass(enable) end

---@return boolean
function VolumetricCloud:GetRenderInMainPass() end

---@param value number
---@return nil
function VolumetricCloud:SetStopTracingTransmittance(value) end

---@return number
function VolumetricCloud:GetStopTracingTransmittance() end

---@param mode VolumetricCloudSkyLightingMode
---@return nil
function VolumetricCloud:SetSkyLightingMode(mode) end

---@return VolumetricCloudSkyLightingMode
function VolumetricCloud:GetSkyLightingMode() end

---@param texture Texture2D
---@return nil
function VolumetricCloud:SetHeightProfile(texture) end

---@return Texture2D
function VolumetricCloud:GetHeightProfile() end

---@param texture Texture2D
---@return nil
function VolumetricCloud:SetWeatherMap(texture) end

---@return Texture2D
function VolumetricCloud:GetWeatherMap() end

---@param texture Texture3D
---@return nil
function VolumetricCloud:SetShapeNoise(texture) end

---@return Texture3D
function VolumetricCloud:GetShapeNoise() end

--- Replace the built-in cloud with a Material bound to a shader_type cloud SurfaceShader; nil restores it.
---@param material Material
---@return nil
function VolumetricCloud:SetMaterial(material) end

--- Return the assigned cloud material, or nil for the built-in cloud.
---@return Material
function VolumetricCloud:GetMaterial() end

