---@meta

--- Auto-generated from Graphics/Zone

---@alias AmbientSource
---| integer # AmbientSource enum values

---@type AmbientSource
AMBIENT_PREBAKED = 0
---@type AmbientSource
AMBIENT_SKYBOX = AMBIENT_SKYBOX
---@type AmbientSource
AMBIENT_COLOR = AMBIENT_COLOR

---@alias BloomMode
---| integer # BloomMode enum values

---@type BloomMode
BLOOM_MODE_LEGACY = 0
---@type BloomMode
BLOOM_MODE_PLUS = BLOOM_MODE_PLUS
---@type BloomMode
BLOOM_MODE_UE = BLOOM_MODE_UE

---@alias TonemapMode
---| integer # TonemapMode enum values

---@type TonemapMode
TONEMAP_MODE_NONE = 0
---@type TonemapMode
TONEMAP_MODE_ACES = TONEMAP_MODE_ACES
---@type TonemapMode
TONEMAP_MODE_LUT = TONEMAP_MODE_LUT

---@class ToonShadingParams
---@overload fun(): ToonShadingParams
---@field shadowHSV Vector3
---@field skinShadowTint Color
---@field mainLightMaxContribution Color
---@field mainLightMultiplier Color
---@field rimTint Color
---@field rimIntensity number
---@field depthEffectsSimpleOffset number
---@field rimDepthThreshold number
---@field rimDepthFadeRange number
---@field faceDepthEffectsSimpleOffsetMultiplier number
---@field depthShadowInfluence number
---@field depthShadowThreshold number
---@field depthShadowFadeRange number
ToonShadingParams = {}

---@return ToonShadingParams
function ToonShadingParams.new() end


---@class Zone : Drawable
---@field boundingBox BoundingBox
---@field inverseWorldTransform Matrix3x4
---@field ambientColor Color Ambient color. PBR materials use it as their flat ambient term only with the AMBIENT_COLOR ambient source; most scenes keep the default SH + IBL ambient (LightGroup presets, sourceTexture or SkyLightCapture), where it has no effect on PBR materials.
---@field ambientStartColor Color
---@field ambientEndColor Color
---@field fogColor Color
---@field fogDensity number Deprecated: use depthFogDensity (same value).
---@field fogStart number Deprecated: use depthFogStart (same value).
---@field fogEnd number Deprecated: use depthFogEnd (same value).
---@field fogHeight number Deprecated: use heightFogHeight (same value).
---@field fogHeightScale number Deprecated: use heightFogFalloff = fogHeightScale * 100.
---@field priority integer
---@field heightFog boolean Deprecated: use heightFogEnable (same value).
---@field skyFogIntensity number
---@field override boolean
---@field ambientGradient boolean
---@field zoneTexture Texture
---@field ambientSource AmbientSource Ambient source. AMBIENT_PREBAKED (default) and AMBIENT_SKYBOX light PBR materials from SH + IBL; AMBIENT_COLOR uses the flat ambientColor instead of the SH.
---@field sourceTexture Texture
---@field ambientIntensity number
---@field autoExposureEnabled boolean
---@field autoExposurePlusEnabled boolean
---@field autoExposureMinBrightness number
---@field autoExposureMaxBrightness number
---@field autoExposureBias number
---@field autoExposureSpeedUp number
---@field autoExposureSpeedDown number
---@field autoExposureForceTarget boolean
---@field ssrEnabled boolean
---@field ssrUsePrevFrameColor boolean
---@field ssgiEnabled boolean
---@field ssgiQuality integer
---@field ssgiIntensity number
---@field ssaoRadius number
---@field ssaoIntensity number
---@field motionBlurEnabled boolean
---@field motionBlurAmount number
---@field motionBlurMaxDistortion number
---@field tonemapLUTEnabled boolean
---@field tonemapMode TonemapMode
---@field toonShadingParams ToonShadingParams
---@field bloomPlusEnabled boolean
---@field bloomThreshold number
---@field bloomWeight number
---@field bloomPlusIntensity number
---@field bloomMode BloomMode
---@field bloomUEIntensity number
---@field bloomUEThreshold number
---@field bloomUESizeScale number
---@field volumetricFogEnabled boolean
---@field volumetricFogOverrideLightColors boolean
---@field volumetricFogDirectionalInscatteringColor Color
---@field skyLightVolumetricScatteringIntensity number
---@field depthFogDensity number
---@field depthFogStart number
---@field depthFogEnd number
---@field depthFogEnable boolean
---@field heightFogDensity number
---@field heightFogEnable boolean
---@field heightFogFalloff number
---@field heightFogHeight number
---@field volumetricFogDensity number
---@field volumetricFogHeight number
---@field volumetricFogHeightFalloff number
---@field volumetricFogScatteringColor Color
---@field volumetricFogAbsorptionColor Color
---@field volumetricFogAbsorptionIntensity number
---@field volumetricFogPhaseG number
---@field volumetricFogViewDistance number
---@field volumetricFogStartDistance number
---@field volumetricFogMaxOpacity number
---@field volumetricFogShaftContrast number
---@field volumetricFogShaftEdgeThreshold number
---@field volumetricFogShaftEdgeSoftness number
---@field volumetricFogShaftOcclusionThreshold number
---@field volumetricFogShaftGroundFadeHeight number
---@field volumetricFogShaftGroundFadeRange number
---@field volumetricFogShaftDistanceFadeLength number
---@field volumetricFogShaftSurfaceFadeRange number
---@field envSpecTexture Texture
---@field envTextureDiffIntensity number
---@field envTextureSpecIntensity number
---@field envCubeAngle number
---@field envCubeFollowAngle number
---@field fxaaEnabled boolean
---@field vignetteEnabled boolean
---@field vignetteIntensity number
---@field vignetteTexture Texture
Zone = {}

--- Append a GBuffer effect; the zone retains the Material.
---@param material Material Material using render_mode gbuffer_postprocess
---@return integer handle Nonzero zone-local registration handle, or 0 for invalid material
function Zone:AddGBufferPostProcess(material) end

--- Remove the effect identified by handle.
---@param handle integer Registration handle
---@return boolean success False if the handle is unknown
function Zone:RemoveGBufferPostProcess(handle) end

--- Enable or disable an effect while preserving its order.
---@param handle integer Registration handle
---@param enabled boolean Whether the effect executes
---@return boolean success False if the handle is unknown
function Zone:SetGBufferPostProcessEnabled(handle, enabled) end

--- Move an effect to a zero-based position in the chain.
---@param handle integer Registration handle
---@param index integer New zero-based index, less than the number of registrations
---@return boolean success False for an unknown handle or invalid index
function Zone:MoveGBufferPostProcess(handle, index) end

--- Remove all effects and release the zone's Material references.
---@return nil
function Zone:ClearGBufferPostProcesses() end

---@param box BoundingBox
---@return nil
function Zone:SetBoundingBox(box) end

--- Ambient color. PBR materials use it as their flat ambient term only with the AMBIENT_COLOR ambient source; most
--- scenes keep the default SH + IBL ambient (LightGroup presets, sourceTexture or SkyLightCapture), where it has no
--- effect on PBR materials.
---@param color Color
---@return nil
function Zone:SetAmbientColor(color) end

---@param color Color
---@return nil
function Zone:SetFogColor(color) end

--- Deprecated. Use SetDepthFogDensity (same value).
---@deprecated
---@param density number
---@return nil
function Zone:SetFogDensity(density) end

--- Deprecated. Use SetDepthFogStart (same value).
---@deprecated
---@param start number
---@return nil
function Zone:SetFogStart(start) end

--- Deprecated. Use SetDepthFogEnd (same value).
---@deprecated
---@param end_ number
---@return nil
function Zone:SetFogEnd(end_) end

--- Deprecated. Use SetHeightFogHeight (same value).
---@deprecated
---@param height number
---@return nil
function Zone:SetFogHeight(height) end

--- Deprecated. Use SetHeightFogFalloff(scale * 100): heightFogFalloff is 100x fogHeightScale.
---@deprecated
---@param scale number
---@return nil
function Zone:SetFogHeightScale(scale) end

---@param priority integer
---@return nil
function Zone:SetPriority(priority) end

--- Deprecated. Use SetHeightFogEnable (same value).
---@deprecated
---@param enable boolean
---@return nil
function Zone:SetHeightFog(enable) end

---@param value number
---@return nil
function Zone:SetSkyFogIntensity(value) end

---@param enable boolean
---@return nil
function Zone:SetOverride(enable) end

---@param enable boolean
---@return nil
function Zone:SetAmbientGradient(enable) end

---@param texture Texture
---@return nil
function Zone:SetZoneTexture(texture) end

--- Ambient source. AMBIENT_PREBAKED (default) and AMBIENT_SKYBOX light PBR materials from SH + IBL; AMBIENT_COLOR
--- uses the flat ambientColor instead of the SH.
---@param source AmbientSource
---@return nil
function Zone:SetAmbientSource(source) end

---@param texture Texture
---@return nil
function Zone:SetSourceTexture(texture) end

---@param texture Texture
---@return nil
function Zone:SetSourceTextureFromBakeCache(texture) end

--- Drop the environment captured by SkyLightCapture and fall back to the sourceTexture bake or prebaked data.
---@return nil
function Zone:ClearCapturedEnvironment() end

---@param intensity number
---@return nil
function Zone:SetAmbientIntensity(intensity) end

---@param value boolean
---@return nil
function Zone:SetAutoExposureEnabled(value) end

--- Select the UE-style histogram auto exposure path. Requires autoExposureEnabled; the min/max brightness, bias, speed and force-target settings below apply only on this path.
---@param value boolean
---@return nil
function Zone:SetAutoExposurePlusEnabled(value) end

--- Set the auto exposure white point lower limit (EV when extended luminance range is on). Must be below the upper limit, otherwise the target exposure is used directly. Plus path only.
---@param value number
---@return nil
function Zone:SetAutoExposureMinBrightness(value) end

--- Set the auto exposure white point upper limit (EV when extended luminance range is on). Must be above the lower limit, otherwise the target exposure is used directly. Plus path only.
---@param value number
---@return nil
function Zone:SetAutoExposureMaxBrightness(value) end

--- Set exposure compensation in EV; positive values brighten the image. Plus path only.
---@param value number
---@return nil
function Zone:SetAutoExposureBias(value) end

--- Set the adaptation speed when the scene gets brighter; negative values fall back to the target exposure. Plus path only.
---@param value number
---@return nil
function Zone:SetAutoExposureSpeedUp(value) end

--- Set the adaptation speed when the scene gets darker; negative values fall back to the target exposure. Plus path only.
---@param value number
---@return nil
function Zone:SetAutoExposureSpeedDown(value) end

--- Skip temporal adaptation and use the target exposure every frame (useful when the script drives brightness itself). Plus path only.
---@param enable boolean
---@return nil
function Zone:SetAutoExposureForceTarget(enable) end

---@param enable boolean
---@return nil
function Zone:SetSSREnabled(enable) end

---@param enable boolean
---@return nil
function Zone:SetSSRUsePrevFrameColor(enable) end

---@param enable boolean
---@return nil
function Zone:SetSSGIEnabled(enable) end

---@param quality integer
---@return nil
function Zone:SetSSGIQuality(quality) end

---@param intensity number
---@return nil
function Zone:SetSSGIIntensity(intensity) end

---@param radius number
---@return nil
function Zone:SetSSAORadius(radius) end

---@param intensity number
---@return nil
function Zone:SetSSAOIntensity(intensity) end

---@param enable boolean
---@return nil
function Zone:SetMotionBlurEnabled(enable) end

---@param amount number
---@return nil
function Zone:SetMotionBlurAmount(amount) end

---@param percent number
---@return nil
function Zone:SetMotionBlurMaxDistortion(percent) end

---@param enable boolean
---@return nil
function Zone:SetTonemapLUTEnabled(enable) end

---@param mode TonemapMode
---@return nil
function Zone:SetTonemapMode(mode) end

---@param params ToonShadingParams
---@return nil
function Zone:SetToonShadingParams(params) end

---@param value boolean
---@return nil
function Zone:SetBloomPlusEnabled(value) end

---@param value number
---@return nil
function Zone:SetBloomThreshold(value) end

---@param value number
---@return nil
function Zone:SetBloomWeight(value) end

---@param value number
---@return nil
function Zone:SetBloomPlusIntensity(value) end

---@param mode BloomMode
---@return nil
function Zone:SetBloomMode(mode) end

---@param value number
---@return nil
function Zone:SetBloomUEIntensity(value) end

---@param value number
---@return nil
function Zone:SetBloomUEThreshold(value) end

---@param value number
---@return nil
function Zone:SetBloomUESizeScale(value) end

---@param stage integer
---@param size number
---@return nil
function Zone:SetBloomUESize(stage, size) end

---@param stage integer
---@param tint Color
---@return nil
function Zone:SetBloomUETint(stage, tint) end

---@param enable boolean
---@return nil
function Zone:SetVolumetricFogEnabled(enable) end

---@param enable boolean
---@return nil
function Zone:SetVolumetricFogOverrideLightColors(enable) end

---@param color Color
---@return nil
function Zone:SetVolumetricFogDirectionalInscatteringColor(color) end

---@param intensity number
---@return nil
function Zone:SetSkyLightVolumetricScatteringIntensity(intensity) end

--- Set depth (distance) fog density multiplier.
---@param value number
---@return nil
function Zone:SetDepthFogDensity(value) end

--- Set the distance where depth fog starts.
---@param value number
---@return nil
function Zone:SetDepthFogStart(value) end

--- Set the distance where depth fog reaches full density.
---@param value number
---@return nil
function Zone:SetDepthFogEnd(value) end

--- Enable or disable depth fog.
---@param enable boolean
---@return nil
function Zone:SetDepthFogEnable(enable) end

--- Set height fog density.
---@param value number
---@return nil
function Zone:SetHeightFogDensity(value) end

--- Enable or disable height fog.
---@param enable boolean
---@return nil
function Zone:SetHeightFogEnable(enable) end

--- Set height fog falloff; larger values thin the fog faster above the fog height.
---@param value number
---@return nil
function Zone:SetHeightFogFalloff(value) end

--- Set the world height where height fog is densest.
---@param value number
---@return nil
function Zone:SetHeightFogHeight(value) end

--- Set volumetric fog extinction density at the fog height. Typical range 0.002-0.02; clamped to >= 0.
---@param value number
---@return nil
function Zone:SetVolumetricFogDensity(value) end

--- Set the world height where volumetric fog has its base density.
---@param value number
---@return nil
function Zone:SetVolumetricFogHeight(value) end

--- Set how quickly volumetric fog thins with height. Small values keep media high up so tall lights still show beams; clamped to >= 0.
---@param value number
---@return nil
function Zone:SetVolumetricFogHeightFalloff(value) end

--- Set volumetric fog scattering colour.
---@param color Color
---@return nil
function Zone:SetVolumetricFogScatteringColor(color) end

--- Set volumetric fog absorption colour.
---@param color Color
---@return nil
function Zone:SetVolumetricFogAbsorptionColor(color) end

--- Set volumetric fog absorption intensity; clamped to >= 0.
---@param value number
---@return nil
function Zone:SetVolumetricFogAbsorptionIntensity(value) end

--- Set the Henyey-Greenstein phase g; positive values scatter forward (brighter when looking toward lights). Clamped to [-0.95, 0.95].
---@param value number
---@return nil
function Zone:SetVolumetricFogPhaseG(value) end

--- Set the distance covered by the volumetric fog grid; clamped to >= 0.
---@param value number
---@return nil
function Zone:SetVolumetricFogViewDistance(value) end

--- Set the camera distance where volumetric fog starts; clamped to >= 0.
---@param value number
---@return nil
function Zone:SetVolumetricFogStartDistance(value) end

--- Set the maximum volumetric fog opacity; clamped to [0, 1].
---@param value number
---@return nil
function Zone:SetVolumetricFogMaxOpacity(value) end

--- Set light shaft contrast; 0 disables shaft enhancement. Clamped to [0, 1].
---@param value number
---@return nil
function Zone:SetVolumetricFogShaftContrast(value) end

--- Set the shadow edge threshold used by shaft enhancement; clamped to [0, 1].
---@param value number
---@return nil
function Zone:SetVolumetricFogShaftEdgeThreshold(value) end

--- Set the shadow edge softness used by shaft enhancement; clamped to [0, 1].
---@param value number
---@return nil
function Zone:SetVolumetricFogShaftEdgeSoftness(value) end

--- Set the occlusion threshold used by shaft enhancement; clamped to [0, 0.5].
---@param value number
---@return nil
function Zone:SetVolumetricFogShaftOcclusionThreshold(value) end

--- Set the world height below which shaft enhancement fades out.
---@param value number
---@return nil
function Zone:SetVolumetricFogShaftGroundFadeHeight(value) end

--- Set the height range of the shaft ground fade; clamped to >= 0.
---@param value number
---@return nil
function Zone:SetVolumetricFogShaftGroundFadeRange(value) end

--- Set the camera distance over which shaft enhancement fades out; clamped to >= 0.
---@param value number
---@return nil
function Zone:SetVolumetricFogShaftDistanceFadeLength(value) end

--- Set the distance near surfaces where shaft enhancement fades out; clamped to >= 0.
---@param value number
---@return nil
function Zone:SetVolumetricFogShaftSurfaceFadeRange(value) end

--- Set the prefiltered specular IBL cubemap directly. Use SetSourceTexture for raw sky images; a baked source result takes precedence over this texture.
---@param texture Texture
---@return nil
function Zone:SetEnvSpecTexture(texture) end

--- Set the diffuse (SH) environment lighting intensity.
---@param intensity number
---@return nil
function Zone:SetEnvTextureDiffIntensity(intensity) end

--- Set the specular (IBL) environment lighting intensity.
---@param intensity number
---@return nil
function Zone:SetEnvTextureSpecIntensity(intensity) end

--- Set the environment cubemap rotation around the Y axis, in degrees. The applied rotation is envCubeAngle + envCubeFollowAngle.
---@param value number
---@return nil
function Zone:SetEnvCubeAngle(value) end

--- Set the additional environment cubemap rotation that follows the main light, in degrees. Light group presets may set it; reset it to 0 when driving envCubeAngle yourself.
---@param value number
---@return nil
function Zone:SetEnvCubeFollowAngle(value) end

---@param value boolean
---@return nil
function Zone:SetFXAAEnabled(value) end

---@param enable boolean
---@return nil
function Zone:SetVignetteEnabled(enable) end

---@param intensity number
---@return nil
function Zone:SetVignetteIntensity(intensity) end

---@param vignetteTexture Texture
---@return nil
function Zone:SetVignetteTexture(vignetteTexture) end

---@return Matrix3x4
function Zone:GetInverseWorldTransform() end

---@return Color
function Zone:GetAmbientColor() end

---@return Color
function Zone:GetAmbientStartColor() end

---@return Color
function Zone:GetAmbientEndColor() end

---@return Color
function Zone:GetFogColor() end

--- Deprecated. Use GetDepthFogDensity (same value).
---@deprecated
---@return number
function Zone:GetFogDensity() end

--- Deprecated. Use GetDepthFogStart (same value).
---@deprecated
---@return number
function Zone:GetFogStart() end

--- Deprecated. Use GetDepthFogEnd (same value).
---@deprecated
---@return number
function Zone:GetFogEnd() end

--- Deprecated. Use GetHeightFogHeight (same value).
---@deprecated
---@return number
function Zone:GetFogHeight() end

--- Deprecated. Use GetHeightFogFalloff() / 100: heightFogFalloff is 100x fogHeightScale.
---@deprecated
---@return number
function Zone:GetFogHeightScale() end

---@return integer
function Zone:GetPriority() end

--- Deprecated. Use GetHeightFogEnable (same value).
---@deprecated
---@return boolean
function Zone:GetHeightFog() end

---@return number
function Zone:GetSkyFogIntensity() end

---@return boolean
function Zone:GetOverride() end

---@return boolean
function Zone:GetAmbientGradient() end

---@return Texture
function Zone:GetZoneTexture() end

---@return AmbientSource
function Zone:GetAmbientSource() end

---@return Texture
function Zone:GetSourceTexture() end

--- Return whether the zone currently uses an environment captured from the sky (SkyLightCapture).
---@return boolean
function Zone:HasCapturedEnvironment() end

---@return number
function Zone:GetAmbientIntensity() end

---@return boolean
function Zone:GetAutoExposureEnabled() end

---@return boolean
function Zone:GetAutoExposurePlusEnabled() end

---@return number
function Zone:GetAutoExposureMinBrightness() end

---@return number
function Zone:GetAutoExposureMaxBrightness() end

---@return number
function Zone:GetAutoExposureBias() end

---@return number
function Zone:GetAutoExposureSpeedUp() end

---@return number
function Zone:GetAutoExposureSpeedDown() end

---@return boolean
function Zone:GetAutoExposureForceTarget() end

---@return boolean
function Zone:GetSSREnabled() end

---@return boolean
function Zone:GetSSRUsePrevFrameColor() end

---@return boolean
function Zone:GetSSGIEnabled() end

---@return integer
function Zone:GetSSGIQuality() end

---@return number
function Zone:GetSSGIIntensity() end

---@return number
function Zone:GetSSAORadius() end

---@return number
function Zone:GetSSAOIntensity() end

---@return boolean
function Zone:GetMotionBlurEnabled() end

---@return number
function Zone:GetMotionBlurAmount() end

---@return number
function Zone:GetMotionBlurMaxDistortion() end

---@return boolean
function Zone:GetTonemapLUTEnabled() end

---@return TonemapMode
function Zone:GetTonemapMode() end

---@return ToonShadingParams
function Zone:GetToonShadingParams() end

---@return boolean
function Zone:GetBloomPlusEnabled() end

---@return number
function Zone:GetBloomThreshold() end

---@return number
function Zone:GetBloomWeight() end

---@return number
function Zone:GetBloomPlusIntensity() end

---@return BloomMode
function Zone:GetBloomMode() end

---@return number
function Zone:GetBloomUEIntensity() end

---@return number
function Zone:GetBloomUEThreshold() end

---@return number
function Zone:GetBloomUESizeScale() end

---@param stage integer
---@return number
function Zone:GetBloomUESize(stage) end

---@param stage integer
---@return Color
function Zone:GetBloomUETint(stage) end

---@return boolean
function Zone:GetVolumetricFogEnabled() end

---@return boolean
function Zone:GetVolumetricFogOverrideLightColors() end

---@return Color
function Zone:GetVolumetricFogDirectionalInscatteringColor() end

---@return number
function Zone:GetSkyLightVolumetricScatteringIntensity() end

---@return number
function Zone:GetDepthFogDensity() end

---@return number
function Zone:GetDepthFogStart() end

---@return number
function Zone:GetDepthFogEnd() end

---@return boolean
function Zone:GetDepthFogEnable() end

---@return number
function Zone:GetHeightFogDensity() end

---@return boolean
function Zone:GetHeightFogEnable() end

---@return number
function Zone:GetHeightFogFalloff() end

---@return number
function Zone:GetHeightFogHeight() end

---@return number
function Zone:GetVolumetricFogDensity() end

---@return number
function Zone:GetVolumetricFogHeight() end

---@return number
function Zone:GetVolumetricFogHeightFalloff() end

---@return Color
function Zone:GetVolumetricFogScatteringColor() end

---@return Color
function Zone:GetVolumetricFogAbsorptionColor() end

---@return number
function Zone:GetVolumetricFogAbsorptionIntensity() end

---@return number
function Zone:GetVolumetricFogPhaseG() end

---@return number
function Zone:GetVolumetricFogViewDistance() end

---@return number
function Zone:GetVolumetricFogStartDistance() end

---@return number
function Zone:GetVolumetricFogMaxOpacity() end

---@return number
function Zone:GetVolumetricFogShaftContrast() end

---@return number
function Zone:GetVolumetricFogShaftEdgeThreshold() end

---@return number
function Zone:GetVolumetricFogShaftEdgeSoftness() end

---@return number
function Zone:GetVolumetricFogShaftOcclusionThreshold() end

---@return number
function Zone:GetVolumetricFogShaftGroundFadeHeight() end

---@return number
function Zone:GetVolumetricFogShaftGroundFadeRange() end

---@return number
function Zone:GetVolumetricFogShaftDistanceFadeLength() end

---@return number
function Zone:GetVolumetricFogShaftSurfaceFadeRange() end

---@return Texture
function Zone:GetEnvSpecTexture() end

---@return number
function Zone:GetEnvTextureDiffIntensity() end

---@return number
function Zone:GetEnvTextureSpecIntensity() end

---@return number
function Zone:GetEnvCubeAngle() end

---@return number
function Zone:GetEnvCubeFollowAngle() end

---@return boolean
function Zone:GetFXAAEnabled() end

---@return boolean
function Zone:GetVignetteEnabled() end

---@return number
function Zone:GetVignetteIntensity() end

---@return Texture
function Zone:GetVignetteTexture() end

---@param point Vector3
---@return boolean
function Zone:IsInside(point) end

