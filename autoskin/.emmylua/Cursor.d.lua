---@meta

--- Auto-generated from UI/Cursor

---@alias CursorShape
---| integer # CursorShape enum values

---@type CursorShape
CS_NORMAL = 0
---@type CursorShape
CS_IBEAM = CS_IBEAM
---@type CursorShape
CS_CROSS = CS_CROSS
---@type CursorShape
CS_RESIZEVERTICAL = CS_RESIZEVERTICAL
---@type CursorShape
CS_RESIZEDIAGONAL_TOPRIGHT = CS_RESIZEDIAGONAL_TOPRIGHT
---@type CursorShape
CS_RESIZEHORIZONTAL = CS_RESIZEHORIZONTAL
---@type CursorShape
CS_RESIZEDIAGONAL_TOPLEFT = CS_RESIZEDIAGONAL_TOPLEFT
---@type CursorShape
CS_RESIZE_ALL = CS_RESIZE_ALL
---@type CursorShape
CS_ACCEPTDROP = CS_ACCEPTDROP
---@type CursorShape
CS_REJECTDROP = CS_REJECTDROP
---@type CursorShape
CS_BUSY = CS_BUSY
---@type CursorShape
CS_BUSY_ARROW = CS_BUSY_ARROW
---@type CursorShape
CS_MAX_SHAPES = CS_MAX_SHAPES

---@class Cursor : BorderImage
---@overload fun(): Cursor
---@field shape string
---@field useSystemShapes boolean
Cursor = {}

---@return Cursor
function Cursor.new() end

---@param shape string
---@param image Image
---@param imageRect IntRect
---@param hotSpot IntVector2
---@return nil
function Cursor:DefineShape(shape, image, imageRect, hotSpot) end

---@param shape CursorShape
---@param image Image
---@param imageRect IntRect
---@param hotSpot IntVector2
---@return nil
function Cursor:DefineShape(shape, image, imageRect, hotSpot) end

---@param shape CursorShape
---@return nil
function Cursor:SetShape(shape) end

---@param shape string
---@return nil
function Cursor:SetShape(shape) end

---@param enable boolean
---@return nil
function Cursor:SetUseSystemShapes(enable) end

---@return string
function Cursor:GetShape() end

---@return boolean
function Cursor:GetUseSystemShapes() end

