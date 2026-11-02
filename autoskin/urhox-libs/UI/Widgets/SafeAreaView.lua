-- ============================================================================
-- SafeAreaView Widget
-- UrhoX UI Library - Yoga + NanoVG
-- Container that applies safe area insets as padding
-- ============================================================================
--
-- Usage:
--   local root = SafeAreaView({
--       edges = "all",  -- or { "top", "bottom" }
--       children = { ... }
--   })
--
-- Props:
--   edges: "all" (default) | "none" | { "top", "bottom", "left", "right" }
--   mode: "padding" (default) | "margin"
--   nativeMenuInset: false (default) | true — 是否将 TapTap 胶囊合并进 top inset
--   ... all other Widget/Panel props
--
-- ============================================================================

local Widget = require("urhox-libs/UI/Core/Widget")
local Theme = require("urhox-libs/UI/Core/Theme")
local Style = require("urhox-libs/UI/Core/Style")

---@class SafeAreaViewProps : WidgetProps
---@field edges? string|string[] Which edges to apply safe area: "all" | "none" | "horizontal" | "vertical" | array of "top"/"bottom"/"left"/"right" (default: "all")
---@field mode? string "padding" | "margin" (default: "padding")
---@field nativeMenuInset? boolean 是否将 TapTap 胶囊合并进 top inset (default: false)

---@class SafeAreaView : Widget
---@overload fun(props?: SafeAreaViewProps): SafeAreaView
---@field props SafeAreaViewProps
---@field new fun(self, props?: SafeAreaViewProps): SafeAreaView
local SafeAreaView = Widget:Extend("SafeAreaView")

-- ============================================================================
-- Internal: Get safe area insets
-- ============================================================================

local function getSafeAreaInsets(includeNativeMenuInset)
    -- calcScale=false: 返回物理像素，与 menuRect 归一化 * graphics.height 的坐标空间一致
    local rect = GetSafeAreaInsets(false)
    -- Get UI scale for conversion to base pixels
    local scale = Theme.GetScale()
    local insets = {
        left = rect.min.x / scale,
        top = rect.min.y / scale,
        right = rect.max.x / scale,
        bottom = rect.max.y / scale
    }

    if includeNativeMenuInset and sdk and sdk.GetNativeExitMenuRect then
        local menuRect = sdk:GetNativeExitMenuRect()
        if menuRect then
            local menuBottom = menuRect.bottom * graphics.height / scale
            if menuBottom > insets.top then
                insets.top = menuBottom
            end
        end
    end

    return insets
end

-- ============================================================================
-- Internal: Parse edges configuration
-- ============================================================================

local function parseEdges(edges)
    if edges == "all" or edges == nil then
        return { top = true, bottom = true, left = true, right = true }
    elseif edges == "none" then
        return { top = false, bottom = false, left = false, right = false }
    elseif edges == "horizontal" then
        return { top = false, bottom = false, left = true, right = true }
    elseif edges == "vertical" then
        return { top = true, bottom = true, left = false, right = false }
    elseif type(edges) == "table" then
        local result = { top = false, bottom = false, left = false, right = false }
        for _, edge in ipairs(edges) do
            result[edge] = true
        end
        return result
    end
    return { top = true, bottom = true, left = true, right = true }
end

-- Per-side edge key suffixes, shared by the inset-injection logic below.
local EDGE_SUFFIX = { left = "Left", top = "Top", right = "Right", bottom = "Bottom" }
-- Axis key suffix covering each edge (marginHorizontal / paddingVertical ...).
local EDGE_AXIS = { left = "Horizontal", right = "Horizontal", top = "Vertical", bottom = "Vertical" }
-- Position of each edge in a CSS-style 4-value array { top, right, bottom, left }.
local EDGE_INDEX = { top = 1, right = 2, bottom = 3, left = 4 }

--- Split one edge of a shorthand value into the Yoga slot tiers it writes to,
--- mirroring Widget:ApplyStyleToYoga: number / string / {a} -> all;
--- {v, h} -> axis; {t, h, b} -> per-side top/bottom + axis horizontal;
--- {t, r, b, l} and named top/right/bottom/left -> per-side;
--- named horizontal / vertical -> axis. Named keys override array values.
---@param value any Shorthand value (e.g. props.margin)
---@param edge string "top" | "right" | "bottom" | "left"
---@return any side, any axis, any all
local function splitShorthandEdge(value, edge)
    if type(value) ~= "table" then return nil, nil, value end
    local isVertical = edge == "top" or edge == "bottom"
    local side, axis, all
    local n = #value
    if n == 1 then
        all = value[1]
    elseif n == 2 then
        axis = isVertical and value[1] or value[2]
    elseif n == 3 then
        if edge == "top" then side = value[1]
        elseif edge == "bottom" then side = value[3]
        else axis = value[2] end
    elseif n >= 4 then
        side = value[EDGE_INDEX[edge]]
    end
    if value[edge] ~= nil then side = value[edge] end
    local axisKey = isVertical and "vertical" or "horizontal"
    if value[axisKey] ~= nil then axis = value[axisKey] end
    return side, axis, all
end

--- Resolve the user's effective spacing for one edge exactly as Yoga would for
--- a plain widget: per-side slot > axis slot > all slot. Within a slot the
--- standalone key (marginLeft / marginHorizontal) wins over the shorthand
--- table, because Widget:ApplyStyleToYoga writes it after the table.
--- `get` reads the merged style view.
---@param get fun(key: string): any
---@param prefix string "padding" | "margin"
---@param edge string "top" | "right" | "bottom" | "left"
---@return any
local function resolveUserEdge(get, prefix, edge)
    local tableSide, tableAxis, all = splitShorthandEdge(get(prefix), edge)
    local side = get(prefix .. EDGE_SUFFIX[edge])
    if side == nil then side = tableSide end
    if side ~= nil then return side end
    local axis = get(prefix .. EDGE_AXIS[edge])
    if axis == nil then axis = tableAxis end
    if axis ~= nil then return axis end
    return all
end

--- Whether `style` touches any spacing key of the given family
--- (shorthand, axis or per-side), i.e. whether edge values must be re-resolved.
---@param style table
---@param prefix string "padding" | "margin"
---@return boolean
local function touchesSpacing(style, prefix)
    if style[prefix] ~= nil or style[prefix .. "Horizontal"] ~= nil
        or style[prefix .. "Vertical"] ~= nil then
        return true
    end
    for _, suffix in pairs(EDGE_SUFFIX) do
        if style[prefix .. suffix] ~= nil then return true end
    end
    return false
end

--- Combine a user spacing value with a safe-area inset.
--- Only numeric point values can be summed with the pixel inset; percentage and
--- "auto" cannot be added to a pixel inset, so the inset takes over on that edge.
---@param value any User-provided per-side value (number/string/nil)
---@param inset number Safe-area inset in base pixels
---@return number|string|nil
local function mergeInset(value, inset)
    if type(value) == "number" then return value + inset end
    if inset ~= 0 then return inset end
    -- inset == 0: keep the user's original value (including percentage / "auto" / nil)
    return value
end

-- ============================================================================
-- Constructor
-- ============================================================================

---@param props SafeAreaViewProps?
function SafeAreaView:Init(props)
    props = props or {}

    -- Store edges configuration for later updates
    self.edgesConfig_ = parseEdges(props.edges)
    self.mode_ = props.mode or "padding"
    self.nativeMenuInset_ = props.nativeMenuInset == true
    -- wasm 胶囊显隐可通过 postMessage 随时切换，低频轮询检测变化（0.5s）
    self.pollInterval_ = (self.nativeMenuInset_ and GetPlatform and GetPlatform() == "Web") and 0.5 or nil
    self.pollTimer_ = 0

    -- Cache screen size for change detection
    self.lastScreenWidth_ = graphics.width
    self.lastScreenHeight_ = graphics.height

    -- Apply theme defaults for Panel-like appearance
    local themeStyle = Theme.ComponentStyle("SafeAreaView") or {}
    Style.ApplyDefaults(props, themeStyle)

    -- Cache the current insets BEFORE Widget.Init runs. Widget.Init calls
    -- ApplyStyleToYoga(props); our override below reads lastInsets_ to fold the
    -- safe-area inset into the Yoga node.
    self.lastInsets_ = getSafeAreaInsets(self.nativeMenuInset_)

    -- self.props keeps pure user values; insets are injected only at the Yoga
    -- layer (see ApplyStyleToYoga override), so repeated applies stay idempotent.
    Widget.Init(self, props)
end

-- ============================================================================
-- Inset injection (single funnel for Init / SetStyle / scale reapply / updates)
-- ============================================================================

--- Apply styles to the Yoga node, folding the current safe-area inset into the
--- active spacing mode's edges. self.props is never mutated: insets live only on
--- the Yoga node, so re-applying props (scale change, inset change, SetStyle
--- round-trips through props) never stacks the inset more than once.
---
--- Each enabled edge's user value is resolved with Yoga precedence (per-side >
--- axis > shorthand) from the merged view of self.props and `style`, and the
--- resolved value plus the edge's inset is written as a per-side Yoga value.
--- Disabled edges get no per-side override: shorthand, axis and per-side keys
--- keep their own slots (copied from `style`), so Yoga resolves them exactly as
--- for any other widget and an explicit marginLeft keeps winning over a later
--- SetStyle({margin = N}).
---
--- Full applies (Init / reapplyStyles / UpdateSafeAreaPadding pass self.props)
--- always re-resolve every edge; partial SetStyle updates re-resolve only when
--- `style` touches the active spacing family. Enabled edges always receive a
--- value (the bare inset when the user set none, including 0) so a shrinking
--- inset resets the Yoga node instead of keeping the previously larger value.
---@param style table Style/props table to apply
function SafeAreaView:ApplyStyleToYoga(style)
    if not style or not self.lastInsets_ then
        return Widget.ApplyStyleToYoga(self, style)
    end

    local insets = self.lastInsets_
    local edges = self.edgesConfig_
    local prefix = self.mode_ == "padding" and "padding" or "margin"
    local props = self.props
    local isFullApply = (style == props)

    -- Shallow copy so the caller's table (and self.props on a full apply) stays
    -- a pure user-value table; we only ever add insets onto the copy.
    local resolved = {}
    for k, v in pairs(style) do resolved[k] = v end

    if isFullApply or touchesSpacing(style, prefix) then
        -- Base SetStyle merges `style` into props only after this call, so read
        -- the incoming value first and fall back to the current props.
        local function get(key)
            local value = style[key]
            if value == nil and not isFullApply then value = props[key] end
            return value
        end
        for edge, suffix in pairs(EDGE_SUFFIX) do
            -- Only enabled edges need a per-side override (user value + inset).
            -- Disabled edges are left to the shorthand / axis / per-side slots
            -- copied from `style`, so the Yoga node stays consistent with props
            -- and clearing a shorthand slot falls back correctly.
            if edges[edge] then
                local inset = insets[edge] or 0
                local value = mergeInset(resolveUserEdge(get, prefix, edge), inset)
                if value == nil then value = inset end
                resolved[prefix .. suffix] = value
            end
        end
    end

    Widget.ApplyStyleToYoga(self, resolved)
end

-- ============================================================================
-- Update: Check for safe area changes
-- ============================================================================

function SafeAreaView:Update(dt)
    local shouldCheck = false
    local w, h = graphics.width, graphics.height
    if w ~= self.lastScreenWidth_ or h ~= self.lastScreenHeight_ then
        self.lastScreenWidth_ = w
        self.lastScreenHeight_ = h
        shouldCheck = true
    elseif self.pollInterval_ then
        self.pollTimer_ = self.pollTimer_ + dt
        if self.pollTimer_ >= self.pollInterval_ then
            self.pollTimer_ = 0
            shouldCheck = true
        end
    end

    if shouldCheck then
        local insets = getSafeAreaInsets(self.nativeMenuInset_)
        local last = self.lastInsets_
        if insets.left ~= last.left or insets.top ~= last.top or
           insets.right ~= last.right or insets.bottom ~= last.bottom then
            self:UpdateSafeAreaPadding(insets)
        end
    end
end

--- Update the cached safe-area inset and recompute the Yoga spacing from the
--- pure user values in self.props. Because insets are folded in during
--- ApplyStyleToYoga rather than stored in props, this fully recomputes the
--- node spacing (user value + new inset) without any fragile delta math, and
--- works regardless of whether the user spacing is a number, percentage or auto.
---@param insets table { left, top, right, bottom } in base pixels
function SafeAreaView:UpdateSafeAreaPadding(insets)
    self.lastInsets_ = insets
    self:ApplyStyleToYoga(self.props)
end

-- ============================================================================
-- Rendering
-- ============================================================================

function SafeAreaView:Render(nvg)
    -- Render background if specified
    self:RenderFullBackground(nvg)
end

-- ============================================================================
-- Stateless
-- ============================================================================

function SafeAreaView:IsStateful()
    return false
end

return SafeAreaView
