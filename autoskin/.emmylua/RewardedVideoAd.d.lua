---@meta

---@class RewardedVideoAdCloseResult
---@field isEnded boolean Whether the host confirms a completed rewarded viewing.
---@field extra? string|table Host extension data, when supplied.

---@class RewardedVideoAdError
---@field code integer Host/video error code; -1 denotes a bridge or preview operation failure.
---@field message string Host error description.
---@field errno? integer Original host errno, when supplied.
---@field errCode? integer Original host errCode, when supplied.
---@field errMsg? string Original host errMsg, when supplied.

---@class RewardedVideoAdLoadResult
---@field success boolean Whether this explicit load request succeeded.
---@field code? integer Error code on failure; host/video codes are preserved.
---@field message? string Error description on failure.
---@field errno? integer Original host errno, when supplied.
---@field errCode? integer Original host errCode, when supplied.
---@field errMsg? string Original host errMsg, when supplied.

---@class RewardedVideoAd
local RewardedVideoAd = {}

--- Request a load without showing. The optional callback receives this request's result at most once.
--- Callbacks run on the engine main thread and may run synchronously in preview or unavailable environments.
--- Host automatic loading remains enabled; destroy or game reset cancels pending callbacks.
---@param callback? fun(result: RewardedVideoAdLoadResult) Receives success, or success=false with code/message.
function RewardedVideoAd:load(callback) end

--- Request a show only after load(callback) has reported success; results arrive through events.
function RewardedVideoAd:show() end

--- Release the host/preview object, listeners and pending load callbacks without a close event. A later call creates a new object.
function RewardedVideoAd:destroy() end

--- Set the single persistent close listener, replacing the previous one. Only isEnded == true permits rewarding.
---@param callback fun(result: RewardedVideoAdCloseResult)
function RewardedVideoAd:onClose(callback) end

--- Set the single persistent host error listener, replacing the previous one.
--- Explicit load results arrive through their request callbacks; host error events are forwarded independently.
---@param callback fun(error: RewardedVideoAdError)
function RewardedVideoAd:onError(callback) end

--- Remove the current close listener if it matches callback; omit callback to clear it unconditionally.
---@param callback? fun(result: RewardedVideoAdCloseResult)
function RewardedVideoAd:offClose(callback) end

--- Remove the current error listener if it matches callback; omit callback to clear it unconditionally.
---@param callback? fun(error: RewardedVideoAdError)
function RewardedVideoAd:offError(callback) end
