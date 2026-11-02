---@meta

--- Auto-generated from Graphics/Renderer

---@class Renderer
---@field numViewports integer
---@field defaultRenderPath RenderPath
---@field defaultTechnique Technique
---@field hdrRendering boolean
---@field specularLighting boolean
---@field drawShadows boolean
---@field textureAnisotropy integer
---@field textureFilterMode TextureFilterMode
---@field textureQuality MaterialQuality
---@field materialQuality MaterialQuality
---@field shadowMapSize integer
---@field shadowQuality ShadowQuality
---@field shadowPCFSamples integer
---@field shadowSoftness number
---@field vsmMultiSample integer
---@field reuseShadowMaps boolean
---@field temporalShadows boolean
---@field temporalShadowMaxAtlases integer
---@field temporalShadowMaxBytes integer
---@field temporalShadowFarUpdates integer
---@field maxShadowMaps integer
---@field dynamicInstancing boolean
---@field numExtraInstancingBufferElements integer
---@field minInstances integer
---@field maxSortedInstances integer
---@field maxOccluderTriangles integer
---@field occlusionBufferSize integer
---@field occluderSizeThreshold number
---@field threadedOcclusion boolean
---@field mobileShadowBiasMul number
---@field mobileShadowBiasAdd number
---@field mobileNormalOffsetMul number
---@field numViews integer
---@field numPrimitives integer
---@field numBatches integer
---@field defaultZone Zone
---@field defaultMaterial Material
---@field defaultLightRamp Texture2D
---@field defaultLightSpot Texture2D
Renderer = {}

--- Dump ready atmosphere LUTs as raw float DDS files asynchronously; the output directory must exist.
--- Returns false while the scene has no matching ready atmosphere version.
---@param scene Scene
---@param pathPrefix string
---@return boolean
function Renderer:DumpSkyAtmosphereLuts(scene, pathPrefix) end

---@param num integer
---@return nil
function Renderer:SetNumViewports(num) end

---@param index integer
---@param viewport Viewport
---@return nil
function Renderer:SetViewport(index, viewport) end

---@param renderPath RenderPath
---@return nil
function Renderer:SetDefaultRenderPath(renderPath) end

---@param file XMLFile
---@return nil
function Renderer:SetDefaultRenderPath(file) end

---@param technique Technique
---@return nil
function Renderer:SetDefaultTechnique(technique) end

---@param enable boolean
---@return nil
function Renderer:SetHDRRendering(enable) end

---@param enable boolean
---@return nil
function Renderer:SetSpecularLighting(enable) end

---@param level integer
---@return nil
function Renderer:SetTextureAnisotropy(level) end

---@param mode TextureFilterMode
---@return nil
function Renderer:SetTextureFilterMode(mode) end

---@param quality MaterialQuality
---@return nil
function Renderer:SetTextureQuality(quality) end

---@param quality MaterialQuality
---@return nil
function Renderer:SetMaterialQuality(quality) end

---@param enable boolean
---@return nil
function Renderer:SetDrawShadows(enable) end

--- Enable clustered spot/point shadows for surfaces and froxel fog. Defaults on for desktop and off for mobile.
--- The global shadow setting and backend capabilities also determine whether shadows are generated.
--- Changes take effect during the next View update; queue shader keys and froxel history follow the effective state.
---@param enable boolean
---@return nil
function Renderer:SetClusterLocalShadowsEnabled(enable) end

--- Enable reuse of unchanged clustered local shadow maps. Defaults to true on all platforms.
--- Changes take effect during the next View update. Disabling forces depth redraws without disabling shadow sampling.
---@param enable boolean
---@return nil
function Renderer:SetClusterLocalShadowCacheEnabled(enable) end

--- Set the per-View clustered local shadow light limit. Defaults to 8 on desktop and 4 on mobile.
--- Negative values clamp to zero; zero selects no local shadows. Cached lights also count toward the limit.
--- Changes take effect during the next View update without resizing the atlas or discarding cached depth.
---@param maxLights integer
---@return nil
function Renderer:SetClusterLocalShadowMaxLights(maxLights) end

--- Set the per-View clustered local shadow face limit. Defaults to 48 on desktop and 6 on mobile.
--- Spot lights cost one face; point and rect lights cost six. Negative values clamp to zero.
--- Changes take effect during the next View update; actual selection also depends on the light limit and atlas space.
---@param maxFaces integer
---@return nil
function Renderer:SetClusterLocalShadowMaxFaces(maxFaces) end

---@param size integer
---@return nil
function Renderer:SetShadowMapSize(size) end

---@param quality ShadowQuality
---@return nil
function Renderer:SetShadowQuality(quality) end

---@param samples integer
---@return nil
function Renderer:SetShadowPCFSamples(samples) end

---@param shadowSoftness number
---@return nil
function Renderer:SetShadowSoftness(shadowSoftness) end

---@param minVariance number
---@param lightBleedingReduction number
---@return nil
function Renderer:SetVSMShadowParameters(minVariance, lightBleedingReduction) end

---@param multiSample integer
---@return nil
function Renderer:SetVSMMultiSample(multiSample) end

---@param enable boolean
---@return nil
function Renderer:SetReuseShadowMaps(enable) end

--- Set the global temporal-shadow kill switch; lights remain opt-in.
---@param enable boolean
---@return nil
function Renderer:SetTemporalShadows(enable) end

--- Return the current temporal shadows setting.
---@return boolean
function Renderer:GetTemporalShadows() end

--- Set the persistent atlas limit in 0..2, effective at the next frame boundary.
---@param count integer
---@return nil
function Renderer:SetTemporalShadowMaxAtlases(count) end

--- Return the current temporal shadow max atlases setting.
---@return integer
function Renderer:GetTemporalShadowMaxAtlases() end

--- Set the persistent atlas budget in 0..268435456 bytes. Defaults to 134217728 bytes, excluding screen history and ordinary shadow maps.
---@param bytes integer
---@return nil
function Renderer:SetTemporalShadowMaxBytes(bytes) end

--- Return the current temporal shadow max bytes setting.
---@return integer
function Renderer:GetTemporalShadowMaxBytes() end

--- Return the resident persistent directional atlas count.
---@return integer
function Renderer:GetNumTemporalShadowAtlases() end

--- Return accounted persistent atlas bytes, excluding ordinary maps and screen history.
---@return integer
function Renderer:GetTemporalShadowMemoryUse() end

--- Return scheduled, reused, hard-required tile counts and executed caster queries for this renderer frame.
---@return Vector4
function Renderer:GetTemporalShadowStatistics() end

--- Return examined dirty regions per atlas, marked cascades, dirty-priority selections, and overflowed atlas snapshots.
---@return Vector4
function Renderer:GetTemporalShadowDirtyStatistics() end

--- Set the shared normal far-cascade update budget per prepared view in 0..8.
---@param count integer
---@return nil
function Renderer:SetTemporalShadowFarUpdates(count) end

--- Return the current temporal shadow far updates setting.
---@return integer
function Renderer:GetTemporalShadowFarUpdates() end

--- Enable independent full-resolution temporal PCF visibility for each eligible shading View. Defaults to false.
--- Requires deferred depth, normals and object velocity; unsupported paths keep sampling the atlas directly.
---@param enable boolean
---@return nil
function Renderer:SetTemporalShadowFilter(enable) end

--- Return whether the independent deferred visibility filter is requested.
---@return boolean
function Renderer:GetTemporalShadowFilter() end

--- Set the total screen-history budget shared by all Views in 0..268435456 bytes. Defaults to 67108864 bytes.
--- Over-budget Views fall back without lowering resolution or consuming the depth-atlas budget.
---@param bytes integer
---@return nil
function Renderer:SetTemporalShadowHistoryBytes(bytes) end

--- Return the total full-resolution screen-history byte budget shared by all Views.
---@return integer
function Renderer:GetTemporalShadowHistoryBytes() end

--- Return total allocated bytes, successful resolves, resets and fallbacks across all Views this renderer frame.
---@return Vector4
function Renderer:GetTemporalShadowFilterStatistics() end

---@param shadowMaps integer
---@return nil
function Renderer:SetMaxShadowMaps(shadowMaps) end

---@param enable boolean
---@return nil
function Renderer:SetDynamicInstancing(enable) end

---@param elements integer
---@return nil
function Renderer:SetNumExtraInstancingBufferElements(elements) end

---@param instances integer
---@return nil
function Renderer:SetMinInstances(instances) end

---@param instances integer
---@return nil
function Renderer:SetMaxSortedInstances(instances) end

---@param triangles integer
---@return nil
function Renderer:SetMaxOccluderTriangles(triangles) end

---@param size integer
---@return nil
function Renderer:SetOcclusionBufferSize(size) end

---@param screenSize number
---@return nil
function Renderer:SetOccluderSizeThreshold(screenSize) end

---@param enable boolean
---@return nil
function Renderer:SetThreadedOcclusion(enable) end

---@param mul number
---@return nil
function Renderer:SetMobileShadowBiasMul(mul) end

---@param add number
---@return nil
function Renderer:SetMobileShadowBiasAdd(add) end

---@param mul number
---@return nil
function Renderer:SetMobileNormalOffsetMul(mul) end

---@param enable boolean
---@return nil
function Renderer:SetVolumetricFogFroxelEnabled(enable) end

---@param enable boolean
---@return nil
function Renderer:SetVolumetricFogConservativeDepthEnabled(enable) end

---@param mode integer
---@return nil
function Renderer:SetVolumetricFogDebugMode(mode) end

---@param pixels integer
---@return nil
function Renderer:SetVolumetricFogGridPixelSize(pixels) end

---@param slices integer
---@return nil
function Renderer:SetVolumetricFogGridSizeZ(slices) end

---@param quality VolumetricFogQuality
---@return nil
function Renderer:SetVolumetricFogQuality(quality) end

---@param weight number
---@return nil
function Renderer:SetVolumetricFogHistoryWeight(weight) end

---@param value number
---@return nil
function Renderer:SetVolumetricFogLightSoftFading(value) end

---@return nil
function Renderer:ReloadShaders() end

---@return integer
function Renderer:GetNumViewports() end

---@param index integer
---@return Viewport
function Renderer:GetViewport(index) end

---@param scene Scene
---@param index integer
---@return Viewport
function Renderer:GetViewportForScene(scene, index) end

---@return RenderPath
function Renderer:GetDefaultRenderPath() end

---@return Technique
function Renderer:GetDefaultTechnique() end

---@return boolean
function Renderer:GetHDRRendering() end

---@return boolean
function Renderer:GetSpecularLighting() end

---@return boolean
function Renderer:GetDrawShadows() end

--- Return the requested clustered local shadow setting, before global and backend capability checks.
---@return boolean
function Renderer:GetClusterLocalShadowsEnabled() end

--- Return whether reuse of unchanged clustered local shadow maps is enabled.
---@return boolean
function Renderer:GetClusterLocalShadowCacheEnabled() end

--- Return the requested per-View clustered local shadow light limit, before atlas capacity checks.
---@return integer
function Renderer:GetClusterLocalShadowMaxLights() end

--- Return the requested per-View clustered local shadow face limit, including cached faces.
---@return integer
function Renderer:GetClusterLocalShadowMaxFaces() end

---@return integer
function Renderer:GetTextureAnisotropy() end

---@return TextureFilterMode
function Renderer:GetTextureFilterMode() end

---@return MaterialQuality
function Renderer:GetTextureQuality() end

---@return MaterialQuality
function Renderer:GetMaterialQuality() end

---@return integer
function Renderer:GetShadowMapSize() end

---@return ShadowQuality
function Renderer:GetShadowQuality() end

---@return integer
function Renderer:GetShadowPCFSamples() end

---@return boolean
function Renderer:GetVolumetricFogFroxelEnabled() end

---@return boolean
function Renderer:GetVolumetricFogConservativeDepthEnabled() end

---@return integer
function Renderer:GetVolumetricFogDebugMode() end

---@return integer
function Renderer:GetVolumetricFogGridPixelSize() end

---@return integer
function Renderer:GetVolumetricFogGridSizeZ() end

---@return VolumetricFogQuality
function Renderer:GetVolumetricFogQuality() end

---@return number
function Renderer:GetVolumetricFogHistoryWeight() end

---@return number
function Renderer:GetVolumetricFogLightSoftFading() end

---@return number
function Renderer:GetShadowSoftness() end

---@return Vector2
function Renderer:GetVSMShadowParameters() end

---@return integer
function Renderer:GetVSMMultiSample() end

---@return boolean
function Renderer:GetReuseShadowMaps() end

---@return integer
function Renderer:GetMaxShadowMaps() end

---@return boolean
function Renderer:GetDynamicInstancing() end

---@return integer
function Renderer:GetNumExtraInstancingBufferElements() end

---@return integer
function Renderer:GetMinInstances() end

---@return integer
function Renderer:GetMaxSortedInstances() end

---@return integer
function Renderer:GetMaxOccluderTriangles() end

---@return integer
function Renderer:GetOcclusionBufferSize() end

---@return number
function Renderer:GetOccluderSizeThreshold() end

---@return boolean
function Renderer:GetThreadedOcclusion() end

---@return number
function Renderer:GetMobileShadowBiasMul() end

---@return number
function Renderer:GetMobileShadowBiasAdd() end

---@return number
function Renderer:GetMobileNormalOffsetMul() end

---@return integer
function Renderer:GetNumViews() end

---@return integer
function Renderer:GetNumPrimitives() end

---@return integer
function Renderer:GetNumBatches() end

---@param allViews? boolean
---@return integer
function Renderer:GetNumGeometries(allViews) end

---@param allViews? boolean
---@return integer
function Renderer:GetNumLights(allViews) end

---@param allViews? boolean
---@return integer
function Renderer:GetNumShadowMaps(allViews) end

---@param allViews? boolean
---@return integer
function Renderer:GetNumOccluders(allViews) end

---@return Zone
function Renderer:GetDefaultZone() end

---@return Material
function Renderer:GetDefaultMaterial() end

---@return Texture2D
function Renderer:GetDefaultLightRamp() end

---@return Texture2D
function Renderer:GetDefaultLightSpot() end

---@param depthTest boolean
---@return nil
function Renderer:DrawDebugGeometry(depthTest) end


-- Global functions
---@return Renderer
function GetRenderer() end

-- Global variables
---@type Renderer
renderer = nil
