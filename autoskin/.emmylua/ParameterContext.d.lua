---@meta

--- Auto-generated from Animation/ParameterContext

---@alias AnimParamType
---| integer # AnimParamType enum values

---@type AnimParamType
ANIM_PARAM_FLOAT = ANIM_PARAM_FLOAT
---@type AnimParamType
ANIM_PARAM_INT = ANIM_PARAM_INT
---@type AnimParamType
ANIM_PARAM_BOOL = ANIM_PARAM_BOOL
---@type AnimParamType
ANIM_PARAM_TRIGGER = ANIM_PARAM_TRIGGER

---@class ParameterContext : Object
ParameterContext = {}

---@param name string
---@param type AnimParamType
---@param defaultValue? VariantInput
---@param minValue? number
---@param maxValue? number
---@return nil
function ParameterContext:DefineParameter(name, type, defaultValue, minValue, maxValue) end

---@param name string
---@return boolean
function ParameterContext:HasParameter(name) end

---@param name string
---@param value number
---@return nil
function ParameterContext:SetFloat(name, value) end

---@param name string
---@param value integer
---@return nil
function ParameterContext:SetInt(name, value) end

---@param name string
---@param value boolean
---@return nil
function ParameterContext:SetBool(name, value) end

---@param name string
---@return nil
function ParameterContext:SetTrigger(name) end

---@param name string
---@return number
function ParameterContext:GetFloat(name) end

---@param name string
---@return integer
function ParameterContext:GetInt(name) end

---@param name string
---@return boolean
function ParameterContext:GetBool(name) end

---@param name string
---@return boolean
function ParameterContext:IsTriggerActivated(name) end

---@param name string
---@param value VariantInput
---@return nil
function ParameterContext:SetValue(name, value) end

---@param name string
---@return Variant
function ParameterContext:GetValue(name) end

---@return nil
function ParameterContext:Clear() end

---@return nil
function ParameterContext:ResetToDefaults() end

---@return nil
function ParameterContext:ResetTriggers() end

---@return nil
function ParameterContext:DebugPrint() end

