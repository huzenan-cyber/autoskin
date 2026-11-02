---@meta

--- Auto-generated from Math/FloatCurve

---@alias FloatCurveInterpolation
---| integer # FloatCurveInterpolation enum values

---@type FloatCurveInterpolation
--- Serialized as "Constant".
FLOAT_CURVE_CONSTANT = FLOAT_CURVE_CONSTANT
---@type FloatCurveInterpolation
--- Serialized as "Linear".
FLOAT_CURVE_LINEAR = FLOAT_CURVE_LINEAR
---@type FloatCurveInterpolation
--- Serialized as "Cubic".
FLOAT_CURVE_CUBIC = FLOAT_CURVE_CUBIC

---@alias FloatCurveTangentMode
---| integer # FloatCurveTangentMode enum values

---@type FloatCurveTangentMode
--- Serialized as "Auto".
FLOAT_CURVE_TANGENT_AUTO = FLOAT_CURVE_TANGENT_AUTO
---@type FloatCurveTangentMode
--- Serialized as "User".
FLOAT_CURVE_TANGENT_USER = FLOAT_CURVE_TANGENT_USER
---@type FloatCurveTangentMode
--- Serialized as "Break".
FLOAT_CURVE_TANGENT_BREAK = FLOAT_CURVE_TANGENT_BREAK

---@alias FloatCurveTangentWeightMode
---| integer # FloatCurveTangentWeightMode enum values

---@type FloatCurveTangentWeightMode
--- Serialized as "None".
FLOAT_CURVE_WEIGHT_NONE = FLOAT_CURVE_WEIGHT_NONE
---@type FloatCurveTangentWeightMode
--- Serialized as "Arrive".
FLOAT_CURVE_WEIGHT_ARRIVE = FLOAT_CURVE_WEIGHT_ARRIVE
---@type FloatCurveTangentWeightMode
--- Serialized as "Leave".
FLOAT_CURVE_WEIGHT_LEAVE = FLOAT_CURVE_WEIGHT_LEAVE
---@type FloatCurveTangentWeightMode
--- Serialized as "Both".
FLOAT_CURVE_WEIGHT_BOTH = FLOAT_CURVE_WEIGHT_BOTH

---@alias FloatCurveExtrapolation
---| integer # FloatCurveExtrapolation enum values

---@type FloatCurveExtrapolation
--- Serialized as "Constant".
FLOAT_CURVE_EXTRAPOLATE_CONSTANT = FLOAT_CURVE_EXTRAPOLATE_CONSTANT
---@type FloatCurveExtrapolation
--- Serialized as "Linear".
FLOAT_CURVE_EXTRAPOLATE_LINEAR = FLOAT_CURVE_EXTRAPOLATE_LINEAR
---@type FloatCurveExtrapolation
--- Serialized as "Cycle".
FLOAT_CURVE_EXTRAPOLATE_CYCLE = FLOAT_CURVE_EXTRAPOLATE_CYCLE
---@type FloatCurveExtrapolation
--- Serialized as "CycleWithOffset".
FLOAT_CURVE_EXTRAPOLATE_CYCLE_OFFSET = FLOAT_CURVE_EXTRAPOLATE_CYCLE_OFFSET
---@type FloatCurveExtrapolation
--- Serialized as "Oscillate".
FLOAT_CURVE_EXTRAPOLATE_OSCILLATE = FLOAT_CURVE_EXTRAPOLATE_OSCILLATE

---@class FloatCurveKey
---@overload fun(time: number, value: number, interpMode?: FloatCurveInterpolation): FloatCurveKey
---@overload fun(): FloatCurveKey
---@field time number Serialized as "Time".
---@field value number Serialized as "Value".
---@field interpMode FloatCurveInterpolation Serialized as "Interp Mode".
---@field tangentMode FloatCurveTangentMode Serialized as "Tangent Mode".
---@field arriveTangent number Serialized as "Arrive Tangent".
---@field leaveTangent number Serialized as "Leave Tangent".
---@field tangentWeightMode FloatCurveTangentWeightMode Serialized as "Tangent Weight Mode".
---@field arriveTangentWeight number Serialized as "Arrive Tangent Weight".
---@field leaveTangentWeight number Serialized as "Leave Tangent Weight".
FloatCurveKey = {}

---@overload fun(self: FloatCurveKey, time: number, value: number, interpMode?: FloatCurveInterpolation): FloatCurveKey
---@overload fun(time: number, value: number, interpMode?: FloatCurveInterpolation): FloatCurveKey
---@return FloatCurveKey
function FloatCurveKey.new() end


---@class FloatCurve
---@overload fun(other: FloatCurve): FloatCurve
---@overload fun(): FloatCurve
---@field numKeys integer
---@field preInfinityExtrap FloatCurveExtrapolation
---@field postInfinityExtrap FloatCurveExtrapolation
---@field tension number
FloatCurve = {}

---@overload fun(self: FloatCurve, other: FloatCurve): FloatCurve
---@overload fun(other: FloatCurve): FloatCurve
---@return FloatCurve
function FloatCurve.new() end

--- Empty curves and non-finite time return defaultValue.
---@param time number
---@param defaultValue? number
---@return number
function FloatCurve:Eval(time, defaultValue) end

--- Add or replace by time; returns the sorted zero-based index. Out-of-range enums and negative weights are clamped; a non-finite time is rejected and returns M_MAX_UNSIGNED. Serialized as "Keys".
---@param key FloatCurveKey
---@return integer
function FloatCurve:AddKey(key) end

---@param index integer
---@param key FloatCurveKey
---@return boolean
function FloatCurve:SetKey(index, key) end

---@param index integer
---@return FloatCurveKey
function FloatCurve:GetKey(index) end

---@param index integer
---@return boolean
function FloatCurve:RemoveKey(index) end

---@return nil
function FloatCurve:ClearKeys() end

---@return integer
function FloatCurve:GetNumKeys() end

--- Serialized as "Pre Infinity Extrap".
---@param mode FloatCurveExtrapolation
---@return nil
function FloatCurve:SetPreInfinityExtrap(mode) end

---@return FloatCurveExtrapolation
function FloatCurve:GetPreInfinityExtrap() end

--- Serialized as "Post Infinity Extrap".
---@param mode FloatCurveExtrapolation
---@return nil
function FloatCurve:SetPostInfinityExtrap(mode) end

---@return FloatCurveExtrapolation
function FloatCurve:GetPostInfinityExtrap() end

--- Serialized as "Tension".
---@param tension number
---@return nil
function FloatCurve:SetTension(tension) end

---@return number
function FloatCurve:GetTension() end

