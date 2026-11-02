---@meta

--- Auto-generated from Graphics/EnvironmentBakeCache

---@class EnvironmentBakeCache
---@field gpuBakeEnabled boolean
EnvironmentBakeCache = {}

--- Enable or disable GPU baking (on by default). When off, baking always runs on the CPU; when on but unsupported by the hardware, it falls back to the CPU.
---@param enabled boolean
---@return nil
function EnvironmentBakeCache:SetGPUBakeEnabled(enabled) end

---@return boolean
function EnvironmentBakeCache:GetGPUBakeEnabled() end

--- Clear the cache; the next SetSourceTexture bakes again.
---@return nil
function EnvironmentBakeCache:ClearCache() end

--- Call after the source texture's content changed (e.g. a runtime sky cubemap was rewritten): drops old results and bakes again.
--- Zones using the texture only pick up the new result after resetting sourceTexture (set it to nil, then back).
---@param sourceTexture Texture
---@return nil
function EnvironmentBakeCache:InvalidateSource(sourceTexture) end

--- Request an IBL + SH bake of the source texture (panorama Texture2D or TextureCube); the result is stored in the cache.
--- Returns whether the result is ready (cache hit).
---@param sourceTexture Texture
---@return boolean
function EnvironmentBakeCache:RequestBake(sourceTexture) end


-- Global functions
---@return EnvironmentBakeCache
function GetEnvironmentBakeCache() end

-- Global variables
---@type EnvironmentBakeCache
environmentBakeCache = nil
