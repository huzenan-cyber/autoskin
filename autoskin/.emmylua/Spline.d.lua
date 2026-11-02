---@meta

--- Auto-generated from Core/Spline

---@alias InterpolationMode
---| integer # InterpolationMode enum values

---@type InterpolationMode
BEZIER_CURVE = BEZIER_CURVE
---@type InterpolationMode
CATMULL_ROM_CURVE = CATMULL_ROM_CURVE
---@type InterpolationMode
LINEAR_CURVE = LINEAR_CURVE
---@type InterpolationMode
CATMULL_ROM_FULL_CURVE = CATMULL_ROM_FULL_CURVE

---@class Spline
---@overload fun(mode: InterpolationMode): Spline
---@overload fun(rhs: Spline): Spline
---@overload fun(): Spline
---@field interpolationMode InterpolationMode
---@operator eq(Spline): boolean
Spline = {}

---@overload fun(self: Spline, mode: InterpolationMode): Spline
---@overload fun(mode: InterpolationMode): Spline
---@overload fun(self: Spline, rhs: Spline): Spline
---@overload fun(rhs: Spline): Spline
---@return Spline
function Spline.new() end

---@param f number
---@return Variant
function Spline:GetPoint(f) end

---@param index integer
---@return Variant
function Spline:GetKnot(index) end

---@param knot VariantInput
---@param param1 integer
---@return nil
function Spline:SetKnot(knot, param1) end

---@param knot VariantInput
---@return nil
function Spline:AddKnot(knot) end

---@param knot VariantInput
---@param index integer
---@return nil
function Spline:AddKnot(knot, index) end

---@return nil
function Spline:RemoveKnot() end

---@param index integer
---@return nil
function Spline:RemoveKnot(index) end

---@return nil
function Spline:Clear() end

