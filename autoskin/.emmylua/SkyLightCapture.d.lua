---@meta

--- Auto-generated from Graphics/SkyLightCapture

---@alias SkyCaptureUpdateMode
---| integer # SkyCaptureUpdateMode enum values

---@type SkyCaptureUpdateMode
SKY_CAPTURE_MANUAL = 0
---@type SkyCaptureUpdateMode
SKY_CAPTURE_ON_CHANGE = SKY_CAPTURE_ON_CHANGE
---@type SkyCaptureUpdateMode
SKY_CAPTURE_CONTINUOUS = SKY_CAPTURE_CONTINUOUS

---@alias SkyCaptureSource
---| integer # SkyCaptureSource enum values

---@type SkyCaptureSource
SKY_CAPTURE_SKYBOX = 0
---@type SkyCaptureSource
SKY_CAPTURE_ATMOSPHERE = SKY_CAPTURE_ATMOSPHERE

---@class SkyLightCapture : Component
---@field includeClouds boolean
---@field skybox Skybox
---@field captureSource SkyCaptureSource
---@field resolution integer
---@field timeSliced boolean
---@field updateMode SkyCaptureUpdateMode
---@field minCaptureInterval number
---@field viewMask integer
---@field capturedCubemap TextureCube
---@field ready boolean
---@field capturing boolean
---@field completedCaptures integer
---@field supported boolean
SkyLightCapture = {}

--- Include frozen scene clouds in atmosphere-source sky captures; default false.
---@param enable boolean
---@return nil
function SkyLightCapture:SetIncludeClouds(enable) end

--- Return whether atmosphere-source captures include clouds.
---@return boolean
function SkyLightCapture:GetIncludeClouds() end

--- Select skybox (default) or active atmosphere. Atmosphere freezes its parameters, lights, LUTs and node
--- position for each capture. It excludes solar disks and local fog; clouds are included only when IncludeClouds is enabled.
--- A missing source never falls back.
---@param source SkyCaptureSource Radiance source
---@return nil
function SkyLightCapture:SetCaptureSource(source) end

--- Return the explicit radiance source.
---@return SkyCaptureSource
function SkyLightCapture:GetCaptureSource() end

--- Set the skybox to capture; nil captures the enabled Skybox in the scene inside the view mask.
--- Keep exactly one enabled skybox inside the view mask: with more, all of them are drawn into the capture,
--- only one (unspecified which) is watched for changes, and a warning is logged.
---@param skybox Skybox|nil Skybox to capture
---@return nil
function SkyLightCapture:SetSkybox(skybox) end

--- Set the capture face size: a power of two in 16..256, rounded up and clamped. Default 128 (64 on mobile).
---@param resolution integer Face size in pixels
---@return nil
function SkyLightCapture:SetResolution(resolution) end

--- Spread a capture over several frames (default true) or finish it as soon as the sky has rendered.
---@param enable boolean Whether captures are time-sliced
---@return nil
function SkyLightCapture:SetTimeSliced(enable) end

--- Set when captures start. Default SKY_CAPTURE_ON_CHANGE: captures when the sky material, its
--- parameters or textures change (skies whose shader reads TIME count as always changing), at most every
--- minCaptureInterval seconds.
---@param mode SkyCaptureUpdateMode Update mode
---@return nil
function SkyLightCapture:SetUpdateMode(mode) end

--- Set the minimum seconds between capture starts in ON_CHANGE mode (>= 0, default 0.25). Throttles skies
--- that change every frame; changes made while waiting are not lost. 0 recaptures back to back.
---@param seconds number Minimum interval in seconds
---@return nil
function SkyLightCapture:SetMinCaptureInterval(seconds) end

--- Set the view mask of the capture cameras (default all bits). Only skyboxes whose viewMask intersects it
--- are captured; use the main camera's viewMask to capture the sky that camera sees.
---@param mask integer View mask
---@return nil
function SkyLightCapture:SetViewMask(mask) end

--- Request a capture, e.g. after rewriting a sky texture with SetData. Ignores the minimum interval;
--- starts after a running capture. A failed capture (e.g. a sky shader that does not compile) is not retried
--- automatically until the sky changes; call this to retry.
---@return nil
function SkyLightCapture:RequestCapture() end

---@return Skybox
function SkyLightCapture:GetSkybox() end

---@return integer
function SkyLightCapture:GetResolution() end

---@return boolean
function SkyLightCapture:GetTimeSliced() end

---@return SkyCaptureUpdateMode
function SkyLightCapture:GetUpdateMode() end

---@return number
function SkyLightCapture:GetMinCaptureInterval() end

---@return integer
function SkyLightCapture:GetViewMask() end

--- Latest published prefiltered cubemap, or nil before the first capture completes.
---@return TextureCube|nil cubemap Published cubemap
function SkyLightCapture:GetCapturedCubemap() end

--- Whether the diffuse SH comes from the capture (false when the device cannot read textures back).
---@return boolean
function SkyLightCapture:HasCapturedSH() end

---@return boolean
function SkyLightCapture:IsReady() end

---@return boolean
function SkyLightCapture:IsCapturing() end

---@return integer
function SkyLightCapture:GetCompletedCaptures() end

---@return boolean
function SkyLightCapture:IsSupported() end

