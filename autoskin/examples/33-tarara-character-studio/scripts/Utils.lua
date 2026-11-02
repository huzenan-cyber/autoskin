-- Small helpers shared by the scripts.
local Utils = {}

--- Wrap an angle in degrees to [-180, 180), as the actor heading, the presentation and the light controls need.
---@param degrees number
---@return number
function Utils.WrapAngle(degrees)
    return (degrees + 180) % 360 - 180
end

return Utils
