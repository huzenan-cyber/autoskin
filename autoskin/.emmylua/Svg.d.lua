---@meta

--- Auto-generated from UI/Svg

---@class SvgResource : Resource
SvgResource = {}


---@class SvgElement : RefCounted
---@field valid boolean Whether the instance still owns this element generation.
---@field id string Original SVG id; empty for anonymous or invalid elements.
---@field tagName string Parsed SVG tag name; empty after invalidation.
---@field localName string Local SVG tag name; empty after invalidation.
---@field parentElement SvgElement Parent instance element; nil at the root or after invalidation.
---@field transformOrigin Vector2 Local script origin, excluding authored transforms; writes use SetTransformOrigin.
---@field translate Vector2 Local script translation, excluding authored transforms; writes use SetTranslate.
---@field rotate number Script rotation in degrees, excluding authored transforms; writes use SetRotate.
---@field scale Vector2 Script scale, excluding authored transforms; writes use SetScale.
---@field fill string Evaluated CSS paint string; accepts colors, none, currentColor and local url(#id) with fallback. For Color use SetFill.
---@field stroke string Evaluated CSS stroke paint string; same syntax as fill. For Color use SetStroke.
---@field color Color Evaluated currentColor value copied as Color; writes use SetColor. Use SetColor(string) for CSS colors.
---@field stopColor string CSS color or currentColor string; for Color use SetStopColor. Other paint syntax is unsupported.
---@field stopOpacity number Finite stop opacity in [0,1]; invalid writes are ignored.
---@field colorInterpolation "sRGB"|"linearRGB"|"auto"|"" Gradient interpolation only; auto reads as sRGB, empty after invalidation. Invalid writes are ignored.
---@field opacity number Evaluated element opacity; writes use SetOpacity.
---@field display string Evaluated inline/none display eligibility; writes use SetDisplay.
---@field visibility string Evaluated visibility, independent of display; writes use SetVisibility.
---@field pointerEvents "none"|"auto"|"visiblePainted"|"visibleFill"|"visibleStroke"|"visible"|"painted"|"fill"|"stroke"|"all"|"" Hit-test eligibility; bounding-box is unsupported. Writes use SetPointerEvents; invalid writes are ignored.
---@field strokeLinecap "butt"|"round"|"square"|"" Stroke endpoint shape. Writes use SetStrokeLinecap; invalid writes are ignored.
---@field strokeLinejoin "miter"|"round"|"bevel"|"" Stroke corner shape; arcs and miter-clip are unsupported. Writes use SetStrokeLinejoin; invalid writes are ignored.
---@field fillRule "nonzero"|"evenodd"|"" Fill winding rule. Writes use SetFillRule; invalid writes are ignored.
---@field clipRule "nonzero"|"evenodd"|"" Winding rule for geometry inside a clipPath. Writes use SetClipRule; invalid writes are ignored.
---@field paintOrder "normal"|"fill"|"stroke"|"markers"|"fill stroke"|"fill markers"|"stroke fill"|"stroke markers"|"markers fill"|"markers stroke"|"fill stroke markers"|"fill markers stroke"|"stroke fill markers"|"stroke markers fill"|"markers fill stroke"|"markers stroke fill"|"" Paint order; markers tokens are accepted but markers are not rendered. Reads normalize to fill stroke or stroke fill. Writes use SetPaintOrder; invalid writes are ignored.
---@field fillOpacity number Fill opacity in [0,1], excluding group compositing. Writes use SetFillOpacity; invalid writes are ignored.
---@field strokeOpacity number Stroke opacity in [0,1], excluding group compositing. Writes use SetStrokeOpacity; invalid writes are ignored.
---@field strokeMiterlimit number Stroke miter limit, at least 1. Writes use SetStrokeMiterlimit; invalid writes are ignored.
---@field clipPath string Evaluated none/url(#id); writes accept local references and resolve missing/wrong-type targets to none.
---@field strokeWidth number Evaluated nonnegative user-unit width; use SetStrokeWidth(string) for units and percentages.
---@field strokeDashoffset number Evaluated signed user-unit dash offset; use SetStrokeDashoffset(string) for units and percentages.
---@field strokeDasharray number[] Copied user-unit lengths (at most 256 nonnegative values); empty means none. Use SetStrokeDasharray(string) for units.
---@field overflow "visible"|"hidden"|"scroll"|"auto"|"" Viewport overflow; scroll reads as hidden and auto reads as visible. Empty after invalidation; invalid writes are ignored.
---@field cubicPathPoints Vector2[] Normalized cubic points copied into a Lua array; writes use SetCubicPathPoints with fixed topology.
SvgElement = {}

--- Return false after the owning instance is destroyed, unloaded or reloaded.
---@return boolean
function SvgElement:IsValid() end

--- Return the original SVG id.
---@return string
function SvgElement:GetId() end

--- Return the parsed SVG tag name; empty after invalidation.
---@return string
function SvgElement:GetTagName() end

--- Return the local tag name; supported SVG element names have no prefix.
---@return string
function SvgElement:GetLocalName() end

--- Return the containing instance node, or nil at the root.
---@return SvgElement
function SvgElement:GetParentElement() end

--- Find a descendant within this group or use instance.
---@param id string
---@return SvgElement
function SvgElement:GetElementById(id) end

--- Set the local script rotation/scale pivot.
---@param x number
---@param y number
---@return boolean
function SvgElement:SetTransformOrigin(x, y) end

--- Set the local script rotation/scale origin through the scalar setter.
---@param origin Vector2
---@return boolean
function SvgElement:SetTransformOrigin(origin) end

--- Return the local script rotation/scale origin, excluding authored transforms; zero after invalidation.
---@return Vector2
function SvgElement:GetTransformOrigin() end

--- Set the local script translation modifier.
---@param x number
---@param y number
---@return boolean
function SvgElement:SetTranslate(x, y) end

--- Set the local script translation modifier through the scalar setter.
---@param translate Vector2
---@return boolean
function SvgElement:SetTranslate(translate) end

--- Return the local script translation modifier, excluding authored transforms; zero after invalidation.
---@return Vector2
function SvgElement:GetTranslate() end

--- Set clockwise script rotation in degrees.
---@param degrees number
---@return boolean
function SvgElement:SetRotate(degrees) end

--- Return script rotation in degrees, excluding authored transforms; zero after invalidation.
---@return number
function SvgElement:GetRotate() end

--- Set the local script scale modifier.
---@param x number
---@param y number
---@return boolean
function SvgElement:SetScale(x, y) end

--- Set the local script scale modifier through the scalar setter.
---@param scale Vector2
---@return boolean
function SvgElement:SetScale(scale) end

--- Return the local script scale modifier, excluding authored transforms; one after invalidation.
---@return Vector2
function SvgElement:GetScale() end

--- Override the complete local matrix, preserving underlying animation.
---@param a number
---@param b number
---@param c number
---@param d number
---@param e number
---@param f number
---@return boolean
function SvgElement:SetTransformOverride(a, b, c, d, e, f) end

--- Restore the animated matrix times the script modifier.
---@return boolean
function SvgElement:ClearTransformOverride() end

--- Override fill with a solid Color, including descendants that inherit fill.
---@param color Color
---@return boolean
function SvgElement:SetFill(color) end

--- Override fill with a CSS color, none, currentColor or url(#id) with an optional color/none fallback.
--- External paint servers are unsupported. Invalid input or handles return false without changes.
---@param value string
---@return boolean
function SvgElement:SetFill(value) end

--- Return evaluated paint with symbolic values and fallback preserved; empty after invalidation.
---@return string
function SvgElement:GetFill() end

--- Override stroke with a finite solid color; invalid input or handles return false without changes.
---@param color Color
---@return boolean
function SvgElement:SetStroke(color) end

--- Override stroke with the same supported syntax as SetFill(String).
---@param value string
---@return boolean
function SvgElement:SetStroke(value) end

--- Return evaluated stroke paint; empty after invalidation.
---@return string
function SvgElement:GetStroke() end

--- Override inherited currentColor with a finite solid color; return false without changes on failure.
---@param color Color
---@return boolean
function SvgElement:SetColor(color) end

--- Override inherited currentColor with a supported CSS color; CSS-wide keywords are not accepted.
---@param value string
---@return boolean
function SvgElement:SetColor(value) end

--- Return evaluated currentColor, excluding paint opacity; transparent black after invalidation.
---@return Color
function SvgElement:GetColor() end

--- Override stop-color with a finite solid color, clearing currentColor; return false on failure.
---@param color Color
---@return boolean
function SvgElement:SetStopColor(color) end

--- Override stop-color with a supported CSS color or currentColor; invalid values are rejected.
---@param value string
---@return boolean
function SvgElement:SetStopColor(value) end

--- Return evaluated stop-color, preserving currentColor; empty after invalidation.
---@return string
function SvgElement:GetStopColor() end

--- Override stop opacity with a finite value in [0,1]; return false without changes on failure.
---@param value number
---@return boolean
function SvgElement:SetStopOpacity(value) end

--- Return evaluated stop opacity, excluding the color's alpha; zero after invalidation.
---@return number
function SvgElement:GetStopOpacity() end

--- Override inherited gradient interpolation with sRGB, linearRGB or auto (resolved to sRGB).
--- Return false for invalid input or handles; this does not enable other SVG interpolation effects.
---@param value "sRGB"|"linearRGB"|"auto"
---@return boolean
function SvgElement:SetColorInterpolation(value) end

--- Return evaluated sRGB/linearRGB gradient interpolation; empty after invalidation.
---@return "sRGB"|"linearRGB"|""
function SvgElement:GetColorInterpolation() end

--- Remove fill override and restore the current animated/inherited value.
---@return boolean
function SvgElement:ClearFillOverride() end

--- Set element/group opacity in [0,1].
---@param opacity number
---@return boolean
function SvgElement:SetOpacity(opacity) end

--- Return evaluated element opacity, excluding ancestor group compositing; zero after invalidation.
---@return number
function SvgElement:GetOpacity() end

--- Set subtree display eligibility with inline or none; reject invalid values without changes.
---@param display string
---@return boolean
function SvgElement:SetDisplay(display) end

--- Return evaluated subtree display eligibility as inline or none; empty after invalidation.
---@return string
function SvgElement:GetDisplay() end

--- Return evaluated visible/hidden, normalizing collapse to hidden; empty after invalidation.
---@return string
function SvgElement:GetVisibility() end

--- Override inherited/animated visibility with visible, hidden or collapse; reject invalid input/handles.
---@param visibility string
---@return boolean
function SvgElement:SetVisibility(visibility) end

--- Hit-test eligibility; bounding-box is unsupported.
--- Override this instance; invalid input/handles return false without changes.
---@param value "none"|"auto"|"visiblePainted"|"visibleFill"|"visibleStroke"|"visible"|"painted"|"fill"|"stroke"|"all"
---@return boolean
function SvgElement:SetPointerEvents(value) end

--- Return the evaluated value; empty after invalidation.
---@return "none"|"auto"|"visiblePainted"|"visibleFill"|"visibleStroke"|"visible"|"painted"|"fill"|"stroke"|"all"|""
function SvgElement:GetPointerEvents() end

--- Stroke endpoint shape.
--- Override this instance; invalid input/handles return false without changes.
---@param value "butt"|"round"|"square"
---@return boolean
function SvgElement:SetStrokeLinecap(value) end

--- Return the evaluated value; empty after invalidation.
---@return "butt"|"round"|"square"|""
function SvgElement:GetStrokeLinecap() end

--- Stroke corner shape; arcs and miter-clip are unsupported.
--- Override this instance; invalid input/handles return false without changes.
---@param value "miter"|"round"|"bevel"
---@return boolean
function SvgElement:SetStrokeLinejoin(value) end

--- Return the evaluated value; empty after invalidation.
---@return "miter"|"round"|"bevel"|""
function SvgElement:GetStrokeLinejoin() end

--- Fill winding rule.
--- Override this instance; invalid input/handles return false without changes.
---@param value "nonzero"|"evenodd"
---@return boolean
function SvgElement:SetFillRule(value) end

--- Return the evaluated value; empty after invalidation.
---@return "nonzero"|"evenodd"|""
function SvgElement:GetFillRule() end

--- Winding rule for geometry inside a clipPath.
--- Override this instance; invalid input/handles return false without changes.
---@param value "nonzero"|"evenodd"
---@return boolean
function SvgElement:SetClipRule(value) end

--- Return the evaluated value; empty after invalidation.
---@return "nonzero"|"evenodd"|""
function SvgElement:GetClipRule() end

--- Paint order; markers tokens are accepted but markers are not rendered. Reads normalize to fill stroke or stroke fill.
--- Override this instance; invalid input/handles return false without changes.
---@param value "normal"|"fill"|"stroke"|"markers"|"fill stroke"|"fill markers"|"stroke fill"|"stroke markers"|"markers fill"|"markers stroke"|"fill stroke markers"|"fill markers stroke"|"stroke fill markers"|"stroke markers fill"|"markers fill stroke"|"markers stroke fill"
---@return boolean
function SvgElement:SetPaintOrder(value) end

--- Return the evaluated value; empty after invalidation.
---@return "fill stroke"|"stroke fill"|""
function SvgElement:GetPaintOrder() end

--- Fill opacity in [0,1], excluding group compositing.
--- Override this instance; invalid input/handles return false without changes.
---@param value number
---@return boolean
function SvgElement:SetFillOpacity(value) end

--- Return the evaluated value; zero after invalidation.
---@return number
function SvgElement:GetFillOpacity() end

--- Stroke opacity in [0,1], excluding group compositing.
--- Override this instance; invalid input/handles return false without changes.
---@param value number
---@return boolean
function SvgElement:SetStrokeOpacity(value) end

--- Return the evaluated value; zero after invalidation.
---@return number
function SvgElement:GetStrokeOpacity() end

--- Stroke miter limit, at least 1.
--- Override this instance; invalid input/handles return false without changes.
---@param value number
---@return boolean
function SvgElement:SetStrokeMiterlimit(value) end

--- Return the evaluated value; zero after invalidation.
---@return number
function SvgElement:GetStrokeMiterlimit() end

--- Override clipping with none or a local url(#id), accepting optional quotes and whitespace.
--- Missing/non-clipPath targets resolve to none as during loading; malformed/external values are rejected.
---@param value string
---@return boolean
function SvgElement:SetClipPath(value) end

--- Return evaluated none/url(#id), or empty after invalidation; clip-path does not inherit by default.
---@return string
function SvgElement:GetClipPath() end

--- Override stroke width with a nonnegative length. Supports unitless, px/pt/pc/mm/cm/in/em/ex and percent.
--- Percentages follow the current viewport diagonal; em/ex use the declaring element's loaded font size.
---@param value string
---@return boolean
function SvgElement:SetStrokeWidth(value) end

--- Override stroke width with finite nonnegative SVG user units; return false without changes on failure.
---@param value number
---@return boolean
function SvgElement:SetStrokeWidth(value) end

--- Return evaluated stroke width in SVG user units; zero after invalidation.
---@return number
function SvgElement:GetStrokeWidth() end

--- Override dash offset with the same length syntax as stroke width, including negative lengths/percentages.
---@param value string
---@return boolean
function SvgElement:SetStrokeDashoffset(value) end

--- Override dash offset with finite SVG user units, including negative values; return false on failure.
---@param value number
---@return boolean
function SvgElement:SetStrokeDashoffset(value) end

--- Return evaluated dash offset in SVG user units; zero after invalidation.
---@return number
function SvgElement:GetStrokeDashoffset() end

--- Override dashes with none or up to 256 comma/space-separated lengths using stroke width's units.
--- Retain percentages through inheritance and viewport changes; invalid input leaves the override unchanged.
---@param value string
---@return boolean
function SvgElement:SetStrokeDasharray(value) end

--- Override dashes with up to 256 finite nonnegative user-unit lengths; an empty array means none.
--- Odd lists repeat during stroking, and all-zero lists produce a solid stroke. Return false on failure.
---@param values number[]
---@return boolean
function SvgElement:SetStrokeDasharray(values) end

--- Return a copy of evaluated dash lengths in user units; empty for none or after invalidation.
---@return number[]
function SvgElement:GetStrokeDasharray() end

--- Override viewport overflow; scroll clips like hidden and auto resolves to visible. No scrolling UI is created.
--- Invalid input/handles return false without changes; only viewport containers clip.
---@param value "visible"|"hidden"|"scroll"|"auto"
---@return boolean
function SvgElement:SetOverflow(value) end

--- Return evaluated visible/hidden overflow; empty after invalidation.
---@return "visible"|"hidden"|""
function SvgElement:GetOverflow() end

--- Remove one script override by its SVG property name, restoring authored/animated/inherited style.
--- Other overrides are retained; unsupported names or invalid handles return false.
---@param property "fill"|"stroke"|"color"|"opacity"|"fill-opacity"|"stroke-opacity"|"stroke-width"|"stroke-miterlimit"|"stroke-dasharray"|"stroke-dashoffset"|"paint-order"|"stroke-linecap"|"stroke-linejoin"|"fill-rule"|"clip-rule"|"visibility"|"display"|"clip-path"|"pointer-events"|"stop-color"|"stop-opacity"|"overflow"|"color-interpolation"
---@return boolean
function SvgElement:ClearStyleOverride(property) end

--- Replace instance line geometry without changing the shared resource.
---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
---@return boolean
function SvgElement:SetLine(x1, y1, x2, y2) end

--- Return normalized cubic control points in subpath order.
---@return Vector2[]
function SvgElement:GetCubicPathPoints() end

--- Set points using exactly the current normalized subpath layout.
---@param points Vector2[]
---@return boolean
function SvgElement:SetCubicPathPoints(points) end

--- Bind SVG values/keyTimes lists once for native sampling; no per-frame parsing.
---@param property string
---@param values string
---@param keyTimes string
---@param duration number
---@param loop boolean
---@param transformType? string
---@return boolean
function SvgElement:BindKeyframes(property, values, keyTimes, duration, loop, transformType) end


---@class SvgInstance : Object
---@field currentTime number Non-wrapped time in seconds; writes use SetCurrentTime without changing playback state.
---@field playbackRate number Nonnegative timeline multiplier; writes use SetPlaybackRate.
---@field animationsPaused boolean Whether timeline advancement is paused; use PauseAnimations/UnpauseAnimations to change it.
---@field loaded boolean Whether a document is loaded.
---@field error string Most recent load or rendering error.
---@field width number Root viewport width in SVG logical units.
---@field height number Root viewport height in SVG logical units.
SvgInstance = {}

--- Load a .svg resource; failure preserves the previous document and node handles.
---@param path string
---@return boolean
function SvgInstance:Load(path) end

--- Unload and invalidate all existing node handles.
---@return nil
function SvgInstance:Unload() end

--- Advance the playing clock by nonnegative seconds.
---@param dt number
---@return nil
function SvgInstance:Update(dt) end

--- Evaluate an absolute nonnegative time without changing playback state.
---@param seconds number
---@return boolean
function SvgInstance:SetCurrentTime(seconds) end

--- Resume Update-driven playback.
---@return nil
function SvgInstance:UnpauseAnimations() end

--- PauseAnimations clock advancement.
---@return nil
function SvgInstance:PauseAnimations() end

--- Set a finite nonnegative playback multiplier.
---@param speed number
---@return boolean
function SvgInstance:SetPlaybackRate(speed) end

--- Return the nonnegative timeline multiplier.
---@return number
function SvgInstance:GetPlaybackRate() end

--- Return the unwrapped time in seconds.
---@return number
function SvgInstance:GetCurrentTime() end

--- Return whether timeline advancement is paused.
---@return boolean
function SvgInstance:AnimationsPaused() end

--- Return whether a document is loaded.
---@return boolean
function SvgInstance:IsLoaded() end

--- Return the most recent error.
---@return string
function SvgInstance:GetError() end

--- Return the SVG viewport width.
---@return number
function SvgInstance:GetWidth() end

--- Return the SVG viewport height.
---@return number
function SvgInstance:GetHeight() end

--- Find an instance node by SVG id.
---@param id string
---@return SvgElement
function SvgInstance:GetElementById(id) end

--- Pick in SVG viewport coordinates; tolerance is in viewport units and should account for display scale.
--- Return the first ElementsFromPoint result, including an eligible root SVG in blank space, or nil.
--- The viewport's right and bottom edges are excluded.
--- Hits inside a use instance return its outermost use host in the loaded document.
--- pointer-events="bounding-box" is unsupported; that declaration is ignored.
---@param x number
---@param y number
---@param tolerance? number
---@return SvgElement
function SvgInstance:ElementFromPoint(x, y, tolerance) end

--- Return all eligible elements, topmost first and without duplicates, using ElementFromPoint's content hit rules.
--- The root SVG viewport is included last, even in blank space, subject to display, visibility, pointer-events and clipping.
--- The viewport's right and bottom edges are excluded. pointer-events="bounding-box" is unsupported and ignored.
--- Each use instance contributes its outermost use host once, rather than its shadow-tree descendants.
--- Coordinates are in SVG viewport units; tolerance defaults to 0.1. No prior draw is required.
--- Return an empty array for no hits, an unloaded instance or invalid coordinates/tolerance.
---@param x number
---@param y number
---@param tolerance? number
---@return SvgElement[]
function SvgInstance:ElementsFromPoint(x, y, tolerance) end


-- Global functions
--- Create an independent SVG instance, registering its resource type in the canvas's context if needed.
---@param ctx NVGContextWrapper
---@return SvgInstance
function nvgSvgCreate(ctx) end

--- Draw into an active NanoVG frame, preserving state but not an unfinished path.
---@param ctx NVGContextWrapper
---@param instance SvgInstance
---@return boolean
function nvgSvgRender(ctx, instance) end
