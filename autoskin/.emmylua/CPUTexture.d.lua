---@meta

--- Auto-generated from Graphics/CPUTexture

---@class CPUTexture : Resource
---@field format integer
---@field width integer
---@field height integer
---@field numMips integer
CPUTexture = {}

--- Return the format of the stored pixels. After a readback this is the GPU storage format, which is BGRA8
--- when the GPU does not support the texture's format.
---@return integer
function CPUTexture:GetFormat() end

--- Return the pixel width of mip zero.
---@return integer
function CPUTexture:GetWidth() end

--- Return the pixel height of mip zero.
---@return integer
function CPUTexture:GetHeight() end

--- Return the number of stored mip levels.
---@return integer
function CPUTexture:GetNumMips() end

--- Save R32F/RGBA16F/RGBA32F bits as NPY (height, width, channels), without conversion or row flipping.
--- Return false for unsupported layout, format, mip or file write failure. Call during the readback callback.
---@param filePath string
---@param level? integer
---@return boolean
function CPUTexture:SaveNPY(filePath, level) end

