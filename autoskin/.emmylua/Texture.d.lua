---@meta

--- Auto-generated from Graphics/Texture

---@class Texture : ResourceWithMetadata
---@field format integer
---@field compressed boolean
---@field levels integer
---@field width integer
---@field height integer
---@field components integer
---@field filterMode TextureFilterMode
---@field anisotropy integer
---@field borderColor Color
---@field sRGB boolean
---@field multiSample integer
---@field autoResolve boolean
---@field resolveDirty boolean
---@field levelsDirty boolean
---@field backupTexture Texture
---@field usage TextureUsage
Texture = {}

--- Enable storage-image writes before allocating the texture.
---@param enabled boolean
---@return nil
function Texture:SetComputeWrite(enabled) end

--- Return the requested allocation flag; set it before SetSize to enable storage-image writes.
---@return boolean
function Texture:IsComputeWrite() end

---@param levels integer
---@return nil
function Texture:SetNumLevels(levels) end

---@param filter TextureFilterMode
---@return nil
function Texture:SetFilterMode(filter) end

---@param coord TextureCoordinate
---@param address TextureAddressMode
---@return nil
function Texture:SetAddressMode(coord, address) end

---@param level integer
---@return nil
function Texture:SetAnisotropy(level) end

---@param color Color
---@return nil
function Texture:SetBorderColor(color) end

--- Enable depth comparison sampling for a shadow texture.
---@param enable boolean
---@return nil
function Texture:SetShadowCompare(enable) end

---@param enable boolean
---@return nil
function Texture:SetSRGB(enable) end

---@param texture Texture
---@return nil
function Texture:SetBackupTexture(texture) end

---@param quality MaterialQuality
---@param toSkip integer
---@return nil
function Texture:SetMipsToSkip(quality, toSkip) end

---@return integer
function Texture:GetFormat() end

---@return boolean
function Texture:IsCompressed() end

---@return integer
function Texture:GetLevels() end

---@return integer
function Texture:GetWidth() end

---@return integer
function Texture:GetHeight() end

---@return TextureFilterMode
function Texture:GetFilterMode() end

---@param coord TextureCoordinate
---@return TextureAddressMode
function Texture:GetAddressMode(coord) end

---@return integer
function Texture:GetAnisotropy() end

---@return Color
function Texture:GetBorderColor() end

--- Return whether depth comparison sampling is enabled.
---@return boolean
function Texture:GetShadowCompare() end

---@return boolean
function Texture:GetSRGB() end

---@return integer
function Texture:GetMultiSample() end

---@return boolean
function Texture:GetAutoResolve() end

---@return boolean
function Texture:IsResolveDirty() end

---@return boolean
function Texture:GetLevelsDirty() end

---@return Texture
function Texture:GetBackupTexture() end

---@param quality MaterialQuality
---@return integer
function Texture:GetMipsToSkip(quality) end

---@param level integer
---@return integer
function Texture:GetLevelWidth(level) end

---@param level integer
---@return integer
function Texture:GetLevelHeight(level) end

---@return TextureUsage
function Texture:GetUsage() end

---@param width integer
---@param height integer
---@return integer
function Texture:GetDataSize(width, height) end

---@param width integer
---@return integer
function Texture:GetRowDataSize(width) end

---@return integer
function Texture:GetComponents() end

--- Read a mip asynchronously as an RGBA8 Image. Texture types without asynchronous readback (only Texture2D has it)
--- log an error and call back with failure.
---@param level integer Mip level, starting at zero
---@param callback fun(success: boolean, image: Image):nil RGBA8 pixels, valid only during callback and raises an error if used afterwards; nil on failure
---@return nil
function Texture:GetDataAsync(level, callback) end

--- Read a mip asynchronously in the GPU storage format, without conversion. The storage format is BGRA8 when the GPU
--- does not support this texture's format; compare texture.format with self.format when the original format is required.
--- Texture types without asynchronous readback (only Texture2D has it) log an error and call back with failure.
---@param level integer Mip level, starting at zero
---@param callback fun(success: boolean, texture: CPUTexture):nil Storage-format pixels, valid only during callback and raises an error if used afterwards; nil on failure
---@return nil
function Texture:GetDataAsyncCPU(level, callback) end

