---@meta

--- Auto-generated from UI/Window

---@alias WindowDragMode
---| integer # WindowDragMode enum values

---@type WindowDragMode
DRAG_NONE = DRAG_NONE
---@type WindowDragMode
DRAG_MOVE = DRAG_MOVE
---@type WindowDragMode
DRAG_RESIZE_TOPLEFT = DRAG_RESIZE_TOPLEFT
---@type WindowDragMode
DRAG_RESIZE_TOP = DRAG_RESIZE_TOP
---@type WindowDragMode
DRAG_RESIZE_TOPRIGHT = DRAG_RESIZE_TOPRIGHT
---@type WindowDragMode
DRAG_RESIZE_RIGHT = DRAG_RESIZE_RIGHT
---@type WindowDragMode
DRAG_RESIZE_BOTTOMRIGHT = DRAG_RESIZE_BOTTOMRIGHT
---@type WindowDragMode
DRAG_RESIZE_BOTTOM = DRAG_RESIZE_BOTTOM
---@type WindowDragMode
DRAG_RESIZE_BOTTOMLEFT = DRAG_RESIZE_BOTTOMLEFT
---@type WindowDragMode
DRAG_RESIZE_LEFT = DRAG_RESIZE_LEFT

---@class Window : BorderImage
---@overload fun(): Window
---@field movable boolean
---@field resizable boolean
---@field fixedWidthResizing boolean
---@field fixedHeightResizing boolean
---@field resizeBorder IntRect
---@field modal boolean
---@field modalShadeColor Color
---@field modalFrameColor Color
---@field modalFrameSize IntVector2
---@field modalAutoDismiss boolean
Window = {}

---@return Window
function Window.new() end

---@param enable boolean
---@return nil
function Window:SetMovable(enable) end

---@param enable boolean
---@return nil
function Window:SetResizable(enable) end

---@param enable boolean
---@return nil
function Window:SetFixedWidthResizing(enable) end

---@param enable boolean
---@return nil
function Window:SetFixedHeightResizing(enable) end

---@param rect IntRect
---@return nil
function Window:SetResizeBorder(rect) end

---@param modal boolean
---@return nil
function Window:SetModal(modal) end

---@param color Color
---@return nil
function Window:SetModalShadeColor(color) end

---@param color Color
---@return nil
function Window:SetModalFrameColor(color) end

---@param size IntVector2
---@return nil
function Window:SetModalFrameSize(size) end

---@param enable boolean
---@return nil
function Window:SetModalAutoDismiss(enable) end

---@return boolean
function Window:IsMovable() end

---@return boolean
function Window:IsResizable() end

---@return boolean
function Window:GetFixedWidthResizing() end

---@return boolean
function Window:GetFixedHeightResizing() end

---@return IntRect
function Window:GetResizeBorder() end

---@return boolean
function Window:IsModal() end

---@return Color
function Window:GetModalShadeColor() end

---@return Color
function Window:GetModalFrameColor() end

---@return IntVector2
function Window:GetModalFrameSize() end

---@return boolean
function Window:GetModalAutoDismiss() end

