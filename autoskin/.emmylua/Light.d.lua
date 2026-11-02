---@meta

--- Auto-generated from Graphics/Light

---@alias LightType
---| integer # LightType enum values

---@type LightType
LIGHT_DIRECTIONAL = 0
---@type LightType
LIGHT_SPOT = LIGHT_SPOT
---@type LightType
LIGHT_POINT = LIGHT_POINT
---@type LightType
LIGHT_RECT = LIGHT_RECT

---@class BiasParameters
---@overload fun(constantBias: number, slopeScaledBias: number, normalOffset?: number): BiasParameters
---@overload fun(): BiasParameters
---@field constantBias number
---@field slopeScaledBias number
---@field normalOffset number
BiasParameters = {}

---@overload fun(self: BiasParameters, constantBias: number, slopeScaledBias: number, normalOffset?: number): BiasParameters
---@overload fun(constantBias: number, slopeScaledBias: number, normalOffset?: number): BiasParameters
---@return BiasParameters
function BiasParameters.new() end


---@class CascadeParameters
---@overload fun(split1: number, split2: number, split3: number, split4: number, fadeStart: number, biasAutoAdjust?: number): CascadeParameters
---@overload fun(): CascadeParameters
---@field fadeStart number
---@field biasAutoAdjust number
CascadeParameters = {}

---@overload fun(self: CascadeParameters, split1: number, split2: number, split3: number, split4: number, fadeStart: number, biasAutoAdjust?: number): CascadeParameters
---@overload fun(split1: number, split2: number, split3: number, split4: number, fadeStart: number, biasAutoAdjust?: number): CascadeParameters
---@return CascadeParameters
function CascadeParameters.new() end


---@class FocusParameters
---@overload fun(focus: boolean, nonUniform: boolean, autoSize: boolean, quantize: number, minView: number): FocusParameters
---@overload fun(): FocusParameters
---@field focus boolean
---@field nonUniform boolean
---@field autoSize boolean
---@field quantize number
---@field minView number
FocusParameters = {}

---@overload fun(self: FocusParameters, focus: boolean, nonUniform: boolean, autoSize: boolean, quantize: number, minView: number): FocusParameters
---@overload fun(focus: boolean, nonUniform: boolean, autoSize: boolean, quantize: number, minView: number): FocusParameters
---@return FocusParameters
function FocusParameters.new() end


---@class Light : Drawable
---@field lightType LightType
---@field perVertex boolean
---@field color Color
---@field temperature number
---@field useTemperature boolean
---@field perPixelAtmosphereTransmittance boolean
---@field atmosphereSunDiskColorScale Color
---@field radius number
---@field softRadius number
---@field length number
---@field sourceAngle number
---@field sourceWidth number
---@field sourceHeight number
---@field barnDoorAngle number
---@field barnDoorLength number
---@field usePhysicalValues boolean
---@field specularIntensity number
---@field brightness number
---@field range number
---@field fov number Legacy full spotlight cone angle in degrees, derived from outerConeAngle.
---@field aspectRatio number
---@field fadeDistance number
---@field shadowFadeDistance number
---@field shadowBias BiasParameters
---@field shadowCascade CascadeParameters
---@field temporalShadows boolean
---@field temporalShadowIntervals Vector4
---@field temporalShadowPadding number
---@field temporalShadowBlend number
---@field temporalShadowDynamicDirty boolean
---@field affectVolumetricFog boolean
---@field volumetricFogIntensity number
---@field volumetricFogShadows boolean
---@field shadowFocus FocusParameters
---@field shadowIntensity number
---@field shadowResolution number
---@field shadowNearFarRatio number
---@field shadowMaxExtrusion number
---@field rampTexture Texture
---@field shapeTexture Texture
---@field frustum Frustum
---@field numShadowSplits integer
---@field negative boolean
---@field effectiveColor Color
---@field effectiveSpecularIntensity number
---@field punctualLight boolean
---@field innerConeAngle number
---@field outerConeAngle number
Light = {}

---@param type LightType
---@return nil
function Light:SetLightType(type) end

---@param enable boolean
---@return nil
function Light:SetPerVertex(enable) end

---@param color Color
---@return nil
function Light:SetColor(color) end

---@param temperature number
---@return nil
function Light:SetTemperature(temperature) end

---@param enable boolean
---@return nil
function Light:SetUseTemperature(enable) end

--- Enable per-pixel atmosphere sunlight for opaque deferred receivers; otherwise use ground transmittance.
---@param enable boolean
---@return nil
function Light:SetPerPixelAtmosphereTransmittance(enable) end

--- Set the linear atmosphere disk radiance multiplier, independent of surface lighting.
---@param color Color
---@return nil
function Light:SetAtmosphereSunDiskColorScale(color) end

---@param redius number
---@return nil
function Light:SetRadius(redius) end

---@param radius number
---@return nil
function Light:SetSoftRadius(radius) end

---@param length number
---@return nil
function Light:SetLength(length) end

--- Set the directional source angular diameter in degrees [0, 20].
---@param angle number
---@return nil
function Light:SetSourceAngle(angle) end

---@param width number
---@return nil
function Light:SetSourceWidth(width) end

---@param height number
---@return nil
function Light:SetSourceHeight(height) end

---@param angle number
---@return nil
function Light:SetBarnDoorAngle(angle) end

---@param length number
---@return nil
function Light:SetBarnDoorLength(length) end

---@param enable boolean
---@return nil
function Light:SetUsePhysicalValues(enable) end

---@param intensity number
---@return nil
function Light:SetSpecularIntensity(intensity) end

---@param brightness number
---@return nil
function Light:SetBrightness(brightness) end

---@param range number
---@return nil
function Light:SetRange(range) end

--- Set legacy full spotlight field of view in degrees; the value is backed by the clustered-light outer cone.
---@param fov number
---@return nil
function Light:SetFov(fov) end

---@param aspectRatio number
---@return nil
function Light:SetAspectRatio(aspectRatio) end

---@param distance number
---@return nil
function Light:SetFadeDistance(distance) end

---@param distance number
---@return nil
function Light:SetShadowFadeDistance(distance) end

---@param parameters BiasParameters
---@return nil
function Light:SetShadowBias(parameters) end

---@param parameters CascadeParameters
---@return nil
function Light:SetShadowCascade(parameters) end

--- Enable directional temporal shadows; unsupported views keep ordinary PCF shadows.
---@param enable boolean
---@return nil
function Light:SetTemporalShadows(enable) end

--- Return the current temporal shadows setting.
---@return boolean
function Light:GetTemporalShadows() end

--- Set integer frame intervals in 1..64; the first cascade always updates each frame.
---@param intervals Vector4
---@return nil
function Light:SetTemporalShadowIntervals(intervals) end

--- Return the current temporal shadow intervals setting.
---@return Vector4
function Light:GetTemporalShadowIntervals() end

--- Set far-cascade radius padding in 0..0.5; the default is 0.05.
---@param padding number
---@return nil
function Light:SetTemporalShadowPadding(padding) end

--- Return the current temporal shadow padding setting.
---@return number
function Light:GetTemporalShadowPadding() end

--- Set total relative cascade blend width in 0..0.2; zero disables blending.
---@param blend number
---@return nil
function Light:SetTemporalShadowBlend(blend) end

--- Return the current temporal shadow blend setting.
---@return number
function Light:GetTemporalShadowBlend() end

--- Enable budget-limited caster-change priority; disabled by default.
---@param enable boolean
---@return nil
function Light:SetTemporalShadowDynamicDirty(enable) end

--- Return the current temporal shadow dynamic dirty setting.
---@return boolean
function Light:GetTemporalShadowDynamicDirty() end

--- Force cached shadow invalidation at the next prepared view.
---@return nil
function Light:InvalidateTemporalShadows() end

--- Set whether this light injects into volumetric fog (directional, point, spot and rect lights). Default true; has no effect unless the zone enables volumetric fog.
---@param enable boolean
---@return nil
function Light:SetAffectVolumetricFog(enable) end

--- Return whether this light injects into volumetric fog.
---@return boolean
function Light:GetAffectVolumetricFog() end

--- Set the volumetric fog in-scattering multiplier; the default is 1.
---@param intensity number
---@return nil
function Light:SetVolumetricFogIntensity(intensity) end

--- Return the volumetric fog in-scattering multiplier.
---@return number
function Light:GetVolumetricFogIntensity() end

--- Set whether the light's shadow map occludes its volumetric fog contribution (light shafts); the default is true.
---@param enable boolean
---@return nil
function Light:SetVolumetricFogShadows(enable) end

--- Return whether the light's shadow map occludes its volumetric fog contribution.
---@return boolean
function Light:GetVolumetricFogShadows() end

---@param parameters FocusParameters
---@return nil
function Light:SetShadowFocus(parameters) end

---@param intensity number
---@return nil
function Light:SetShadowIntensity(intensity) end

---@param resolution number
---@return nil
function Light:SetShadowResolution(resolution) end

---@param nearFarRatio number
---@return nil
function Light:SetShadowNearFarRatio(nearFarRatio) end

---@param extrusion number
---@return nil
function Light:SetShadowMaxExtrusion(extrusion) end

---@param texture Texture
---@return nil
function Light:SetRampTexture(texture) end

---@param texture Texture
---@return nil
function Light:SetShapeTexture(texture) end

---@return LightType
function Light:GetLightType() end

---@return boolean
function Light:GetPerVertex() end

---@return Color
function Light:GetColor() end

---@return number
function Light:GetTemperature() end

---@return boolean
function Light:GetUseTemperature() end

--- Return the per-pixel atmospheric sunlight option.
---@return boolean
function Light:GetPerPixelAtmosphereTransmittance() end

--- Return the atmosphere disk radiance multiplier.
---@return Color
function Light:GetAtmosphereSunDiskColorScale() end

---@return number
function Light:GetRadius() end

---@return number
function Light:GetSoftRadius() end

---@return number
function Light:GetLength() end

--- Return the directional source angular diameter in degrees.
---@return number
function Light:GetSourceAngle() end

---@return number
function Light:GetSourceWidth() end

---@return number
function Light:GetSourceHeight() end

---@return number
function Light:GetBarnDoorAngle() end

---@return number
function Light:GetBarnDoorLength() end

---@return boolean
function Light:GetUsePhysicalValues() end

---@return number
function Light:GetSpecularIntensity() end

---@return number
function Light:GetBrightness() end

---@return Color
function Light:GetEffectiveColor() end

---@return Color
function Light:GetColorFromTemperature() end

---@return number
function Light:GetEffectiveSpecularIntensity() end

---@return number
function Light:GetRange() end

---@return number
function Light:GetFov() end

---@return number
function Light:GetAspectRatio() end

---@return number
function Light:GetFadeDistance() end

---@return number
function Light:GetShadowFadeDistance() end

---@return BiasParameters
function Light:GetShadowBias() end

---@return CascadeParameters
function Light:GetShadowCascade() end

---@return FocusParameters
function Light:GetShadowFocus() end

---@return number
function Light:GetShadowIntensity() end

---@return number
function Light:GetShadowResolution() end

---@return number
function Light:GetShadowNearFarRatio() end

---@return number
function Light:GetShadowMaxExtrusion() end

---@return Texture
function Light:GetRampTexture() end

---@return Texture
function Light:GetShapeTexture() end

---@return Frustum
function Light:GetFrustum() end

---@return integer
function Light:GetNumShadowSplits() end

---@return boolean
function Light:IsNegative() end

---@param flag boolean
---@return nil
function Light:SetStatic(flag) end

---@param f boolean
---@return nil
function Light:SetPunctualLight(f) end

---@return boolean
function Light:GetPunctualLight() end

---@param angle number
---@return nil
function Light:SetInnerConeAngle(angle) end

---@param angle number
---@return nil
function Light:SetOuterConeAngle(angle) end

---@return number
function Light:GetInnerConeAngle() end

---@return number
function Light:GetOuterConeAngle() end

