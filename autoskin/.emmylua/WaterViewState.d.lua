---@meta

--- Auto-generated from Graphics/WaterViewState

---@alias WaterQueryStatus
---| integer # WaterQueryStatus enum values

---@type WaterQueryStatus
WATER_NO_DOMAIN = WATER_NO_DOMAIN
---@type WaterQueryStatus
WATER_QUERY_UNKNOWN = WATER_QUERY_UNKNOWN
---@type WaterQueryStatus
WATER_ABOVE = WATER_ABOVE
---@type WaterQueryStatus
WATER_UNDERWATER = WATER_UNDERWATER

---@class WaterViewState : Object
WaterViewState = {}

--- Return whether this view supports Water: an enabled water pass, desktop DX11/OpenGL, linear HDR, compute and single sampling or forward 4x MSAA are required.
---@return boolean
function WaterViewState:IsSupported() end

---@return WaterQueryStatus
function WaterViewState:GetStatus() end

---@return boolean
function WaterViewState:IsValid() end

---@return boolean
function WaterViewState:IsUnderwater() end

---@return boolean
function WaterViewState:IsWaterlineActive() end

---@return WaterBody
function WaterViewState:GetBody() end

---@return number
function WaterViewState:GetImmersionDepth() end

---@return Vector3
function WaterViewState:GetQueryPosition() end

---@return number
function WaterViewState:GetQueryTime() end

---@return integer
function WaterViewState:GetLatencyFrames() end

---@return integer
function WaterViewState:GetLatencyMSec() end

---@return string
function WaterViewState:GetLastError() end

