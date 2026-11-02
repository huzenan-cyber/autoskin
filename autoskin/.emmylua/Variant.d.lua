---@meta

--- Auto-generated from Core/Variant

---@alias VariantType
---| integer # VariantType enum values

---@type VariantType
VAR_NONE = 0
---@type VariantType
VAR_INT = VAR_INT
---@type VariantType
VAR_BOOL = VAR_BOOL
---@type VariantType
VAR_FLOAT = VAR_FLOAT
---@type VariantType
VAR_VECTOR2 = VAR_VECTOR2
---@type VariantType
VAR_VECTOR3 = VAR_VECTOR3
---@type VariantType
VAR_VECTOR4 = VAR_VECTOR4
---@type VariantType
VAR_QUATERNION = VAR_QUATERNION
---@type VariantType
VAR_COLOR = VAR_COLOR
---@type VariantType
VAR_STRING = VAR_STRING
---@type VariantType
VAR_BUFFER = VAR_BUFFER
---@type VariantType
VAR_VOIDPTR = VAR_VOIDPTR
---@type VariantType
VAR_RESOURCEREF = VAR_RESOURCEREF
---@type VariantType
VAR_RESOURCEREFLIST = VAR_RESOURCEREFLIST
---@type VariantType
VAR_VARIANTVECTOR = VAR_VARIANTVECTOR
---@type VariantType
VAR_VARIANTMAP = VAR_VARIANTMAP
---@type VariantType
VAR_INTRECT = VAR_INTRECT
---@type VariantType
VAR_INTVECTOR2 = VAR_INTVECTOR2
---@type VariantType
VAR_PTR = VAR_PTR
---@type VariantType
VAR_MATRIX3 = VAR_MATRIX3
---@type VariantType
VAR_MATRIX3X4 = VAR_MATRIX3X4
---@type VariantType
VAR_MATRIX4 = VAR_MATRIX4
---@type VariantType
VAR_DOUBLE = VAR_DOUBLE
---@type VariantType
VAR_STRINGVECTOR = VAR_STRINGVECTOR
---@type VariantType
VAR_RECT = VAR_RECT
---@type VariantType
VAR_INTVECTOR3 = VAR_INTVECTOR3
---@type VariantType
VAR_INT64 = VAR_INT64
---@type VariantType
VAR_CUSTOM_HEAP = VAR_CUSTOM_HEAP
---@type VariantType
VAR_CUSTOM_STACK = VAR_CUSTOM_STACK
---@type VariantType
VAR_STRINGVARIANTMAP = VAR_STRINGVARIANTMAP
---@type VariantType
MAX_VAR_TYPES = MAX_VAR_TYPES

---@class ResourceRef
---@overload fun(type: StringHash|string): ResourceRef
---@overload fun(type: StringHash|string, name: string): ResourceRef
---@overload fun(type: string, name: string): ResourceRef
---@overload fun(rhs: ResourceRef): ResourceRef
---@overload fun(): ResourceRef
---@field type StringHash|string
---@field name string
---@operator eq(ResourceRef): boolean
ResourceRef = {}

---@overload fun(self: ResourceRef, type: StringHash|string): ResourceRef
---@overload fun(type: StringHash|string): ResourceRef
---@overload fun(self: ResourceRef, type: StringHash|string, name: string): ResourceRef
---@overload fun(type: StringHash|string, name: string): ResourceRef
---@overload fun(self: ResourceRef, type: string, name: string): ResourceRef
---@overload fun(type: string, name: string): ResourceRef
---@overload fun(self: ResourceRef, rhs: ResourceRef): ResourceRef
---@overload fun(rhs: ResourceRef): ResourceRef
---@return ResourceRef
function ResourceRef.new() end


---@class ResourceRefList
---@overload fun(type: StringHash|string): ResourceRefList
---@overload fun(): ResourceRefList
---@field type StringHash|string
---@operator eq(ResourceRefList): boolean
ResourceRefList = {}

---@overload fun(self: ResourceRefList, type: StringHash|string): ResourceRefList
---@overload fun(type: StringHash|string): ResourceRefList
---@return ResourceRefList
function ResourceRefList.new() end


---@class Variant
---@overload fun(value: boolean): Variant
---@overload fun(value: number): Variant
---@overload fun(value: string): Variant
---@overload fun(value: Vector2): Variant
---@overload fun(value: Vector3): Variant
---@overload fun(value: Vector4): Variant
---@overload fun(value: Quaternion): Variant
---@overload fun(value: Color): Variant
---@overload fun(value: IntRect): Variant
---@overload fun(value: IntVector2): Variant
---@overload fun(value: IntVector3): Variant
---@overload fun(value: any): Variant
---@overload fun(value: VariantInput): Variant
---@overload fun(type: string, value: string): Variant
---@overload fun(type: VariantType, value: string): Variant
---@overload fun(): Variant
---@field type VariantType
---@field typeName string
---@field zero boolean
---@field empty boolean
---@operator eq(Variant): boolean
---@field GetPtr __union_func__type_str__ret_RefCountedT
Variant = {}

---@overload fun(value: boolean): Variant
---@overload fun(value: number): Variant
---@overload fun(value: string): Variant
---@overload fun(value: Vector2): Variant
---@overload fun(value: Vector3): Variant
---@overload fun(value: Vector4): Variant
---@overload fun(value: Quaternion): Variant
---@overload fun(value: Color): Variant
---@overload fun(value: IntRect): Variant
---@overload fun(value: IntVector2): Variant
---@overload fun(value: IntVector3): Variant
---@overload fun(value: any): Variant
---@overload fun(self: Variant, value: VariantInput): Variant
---@overload fun(value: VariantInput): Variant
---@overload fun(self: Variant, type: string, value: string): Variant
---@overload fun(type: string, value: string): Variant
---@overload fun(self: Variant, type: VariantType, value: string): Variant
---@overload fun(type: VariantType, value: string): Variant
---@return Variant
function Variant.new() end

---@param type string
---@return nil
function Variant:_Setup(type) end

---@return nil
function Variant:Clear() end

---@param rhs VariantInput
---@return nil
function Variant:Set(rhs) end

---@param type? string
---@return any
function Variant:Get(type) end

---@return integer
function Variant:GetInt() end

---@return integer
function Variant:GetUInt() end

---@return integer
function Variant:GetInt64() end

---@return integer
function Variant:GetUInt64() end

---@return StringHash|string
function Variant:GetStringHash() end

---@return boolean
function Variant:GetBool() end

---@return number
function Variant:GetFloat() end

---@return number
function Variant:GetDouble() end

---@return Vector2
function Variant:GetVector2() end

---@return Vector3
function Variant:GetVector3() end

---@return Vector4
function Variant:GetVector4() end

---@return Quaternion
function Variant:GetQuaternion() end

---@return Color
function Variant:GetColor() end

---@return string
function Variant:GetString() end

---@return number[]
function Variant:GetRawBuffer() end

---@return VectorBuffer
function Variant:GetBuffer() end

---@param type string
---@return any
function Variant:GetVoidPtr(type) end

---@return ResourceRef
function Variant:GetResourceRef() end

---@return ResourceRefList
function Variant:GetResourceRefList() end

---@return Variant[]
function Variant:GetVariantVector() end

---@return VariantMap
function Variant:GetVariantMap() end

---@return string[]
function Variant:GetStringVector() end

---@return Rect
function Variant:GetRect() end

---@return IntRect
function Variant:GetIntRect() end

---@return IntVector2
function Variant:GetIntVector2() end

---@return IntVector3
function Variant:GetIntVector3() end

---@return Matrix3
function Variant:GetMatrix3() end

---@return Matrix3x4
function Variant:GetMatrix3x4() end

---@return Matrix4
function Variant:GetMatrix4() end

---@return VariantType
function Variant:GetType() end

---@return string
function Variant:GetTypeName() end

---@return string
function Variant:ToString() end

---@return boolean
function Variant:IsZero() end

---@return boolean
function Variant:IsEmpty() end


---@class VariantMap
---@overload fun(): VariantMap
VariantMap = {}

---@return VariantMap
function VariantMap.new() end

---@param type string
---@return nil
function VariantMap:_Setup(type) end

