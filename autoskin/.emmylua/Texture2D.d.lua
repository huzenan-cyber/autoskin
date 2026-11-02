---@meta

--- Auto-generated from Graphics/Texture2D


---@class Texture2D : Texture
---@overload fun(): Texture2D
---@field renderSurface RenderSurface
Texture2D = {}

---@return Texture2D
function Texture2D.new() end

---@param width integer
---@param height integer
---@param format integer
---@param usage? TextureUsage
---@param multiSample? integer
---@param autoResolve? boolean
---@return boolean
function Texture2D:SetSize(width, height, format, usage, multiSample, autoResolve) end

---@param image Image
---@param useAlpha? boolean
---@return boolean
function Texture2D:SetData(image, useAlpha) end

--- Read mip zero synchronously.
--- Renderers without synchronous texture readback (such as WebGPU) log an Error and return nil immediately without blocking.
--- On those renderers, use GetImageAsync(callback) and process the image in the callback.
---@return Image|nil Image owned by the caller; nil on readback failure.
function Texture2D:GetImage() end

--- Asynchronous counterpart of GetImage(): the callback receives the Image GetImage() would return.
--- Works on every renderer, including WebGPU where GetImage() is unavailable.
--- The image arrives from a later frame; a request the renderer rejects outright calls back with nil before returning.
---@param callback fun(image: Image|nil):nil Image owned by the caller like GetImage(); may be kept or disposed. nil on readback failure.
---@return nil
function Texture2D:GetImageAsync(callback) end

---@return RenderSurface
function Texture2D:GetRenderSurface() end

