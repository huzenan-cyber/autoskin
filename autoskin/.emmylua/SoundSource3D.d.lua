---@meta

--- Auto-generated from Audio/SoundSource3D

---@class SoundSource3D : SoundSource
---@field nearDistance number Near distance in world units.
---@field farDistance number Far distance in world units; outside it the source is silent.
---@field innerAngle number Inner cone angle in degrees.
---@field outerAngle number Outer cone angle in degrees.
---@field rolloffFactor number Positive distance rolloff exponent.
SoundSource3D = {}

--- Set near/far distance attenuation in world units. Outside farDistance the source is silent.
--- rolloffFactor controls the curve and is clamped to a positive minimum.
---@param nearDistance number
---@param farDistance number
---@param rolloffFactor number
---@return nil
function SoundSource3D:SetDistanceAttenuation(nearDistance, farDistance, rolloffFactor) end

--- Set directional attenuation angles in degrees. 360 degrees disables directional attenuation.
---@param innerAngle number
---@param outerAngle number
---@return nil
function SoundSource3D:SetAngleAttenuation(innerAngle, outerAngle) end

--- Set the distance inside which the source is not attenuated.
---@param distance number
---@return nil
function SoundSource3D:SetNearDistance(distance) end

--- Set the distance outside which the source is fully attenuated.
---@param distance number
---@return nil
function SoundSource3D:SetFarDistance(distance) end

--- Set the inner cone angle in degrees. The default 360 is omnidirectional.
---@param angle number
---@return nil
function SoundSource3D:SetInnerAngle(angle) end

--- Set the outer cone angle in degrees. Outside this cone the source is fully attenuated.
---@param angle number
---@return nil
function SoundSource3D:SetOuterAngle(angle) end

--- Set the positive distance rolloff exponent.
---@param factor number
---@return nil
function SoundSource3D:SetRolloffFactor(factor) end

--- Recalculate attenuation and panning from the current source and listener transforms.
--- SoundSource3D::Update calls this automatically; manual calls are only needed after immediate custom changes.
---@return nil
function SoundSource3D:CalculateAttenuation() end

--- Return the near distance in world units.
---@return number
function SoundSource3D:GetNearDistance() end

--- Return the far distance in world units.
---@return number
function SoundSource3D:GetFarDistance() end

--- Return the inner cone angle in degrees.
---@return number
function SoundSource3D:GetInnerAngle() end

--- Return the outer cone angle in degrees.
---@return number
function SoundSource3D:GetOuterAngle() end

--- Return the rolloff exponent. The historical method name contains a spelling error.
---@return number
function SoundSource3D:RollAngleoffFactor() end

