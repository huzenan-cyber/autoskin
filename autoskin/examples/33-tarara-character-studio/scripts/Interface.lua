-- Responsive controls for animation, expressions, secondary motion, lighting and the presentation.
local UI = require("urhox-libs/UI")
local Theme = require("urhox-libs/UI/Core/Theme")
local Character = require("Character")
local Studio = require("Studio")

---@class TararaInterface
---@field app TararaApp
---@field width number Viewport width the layout was built for.
---@field height number
---@field compact boolean Narrow layout with the panel below the character.
---@field rawMorphs boolean Show one slider per authored morph channel.
---@field syncing boolean True while Refresh writes values back into the controls.
---@field root Widget
---@field dragPane Widget Full-screen layer for actor and light dragging.
---@field scrollView ScrollView
---@field dragButton? number
---@field dragPointerId? number
---@field framingButtons table<string, Button>
---@field expressionButtons table<string, Button>
---@field animationButtons table<string, Button>
---@field blinkButton Button
---@field eyeContactButton Button
---@field bonesButton Button
---@field autoRotateButton Button
---@field resetHeadingButton Button
---@field resetLightButton Button
---@field pauseButton Button
---@field demoButton Button
---@field demoStatusLabel Label
---@field headingSlider Slider
---@field lightYawSlider Slider
---@field lightElevationSlider Slider
---@field sliders table<Slider, fun(): number> Controls whose value can change outside their own input.
local Interface = {}
Interface.__index = Interface

local COLORS = {
    ink = {214, 216, 222, 255}, muted = {122, 126, 140, 255}, accent = {4, 192, 174, 255},
    mint = {4, 192, 174, 255}, surface = {33, 34, 45, 235}, header = {50, 52, 66, 240}, line = {58, 60, 76, 255},
}
-- The built-in dark theme with the TapTap teal accent in place of its steel cyan.
local TEAL, TEAL_HOVER, TEAL_PRESSED = {4, 192, 174, 255}, {38, 214, 196, 255}, {3, 150, 136, 255}
local THEME = Theme.ExtendTheme(Theme.GetRegisteredTheme("default-dark"), {
    colors = {
        primary = TEAL, primaryHover = TEAL_HOVER, primaryPressed = TEAL_PRESSED, primaryDeep = TEAL_PRESSED,
        primaryShadow = TEAL_PRESSED, borderFocus = TEAL,
        secondary = {55, 57, 69, 255}, secondaryHover = {66, 68, 82, 255}, secondaryPressed = {44, 46, 58, 255},
        secondaryDeep = {28, 29, 38, 255}, secondaryShadow = {28, 29, 38, 255},
        text = COLORS.ink, divider = COLORS.line, border = COLORS.line,
    },
    components = {
        Slider = {trackBgColor = {34, 36, 46, 255}, trackFillColor = TEAL, thumbColor = {230, 232, 236, 255},
            thumbBorderColor = TEAL, thumbBorderWidth = 2},
        Card = {borderWidth = 1, borderColor = COLORS.line},
        Divider = {color = COLORS.line, thickness = 1},
    },
})
-- The engine's bundled typeface, in place of the theme's own font files.
local FONTS = {{family = "sans", weights = {normal = "Fonts/MiSans-Regular.ttf", bold = "Fonts/MiSans-Bold.ttf"}}}
local COMPACT_WIDTH = 720 -- Narrower viewports use the compact layout.
local INTRO_WIDTH = 1000 -- Wider viewports show the introduction text.
-- Pointer drag sensitivity in degrees per pixel.
local DRAG_HEADING, DRAG_LIGHT_YAW, DRAG_LIGHT_ELEVATION = 0.35, 0.25, 0.2

--- Copy the caller's extra props over a widget's defaults.
---@param props table
---@param extra? table
---@return table
local function WithProps(props, extra)
    for k, v in pairs(extra or {}) do props[k] = v end
    return props
end

---@param text string
---@param size? number
---@param color? table
---@param extra? table Additional Label props.
---@return Label
local function Label(text, size, color, extra)
    return UI.Label(WithProps({text = text, fontSize = size or 14, fontColor = color or COLORS.ink, flexShrink = 0, lineHeight = 1.4}, extra))
end

---@param text string
---@param onClick fun()
---@param extra? table Additional Button props.
---@return Button
local function Button(text, onClick, extra)
    return UI.Button(WithProps({text = text, height = 36, fontSize = 13, paddingHorizontal = 10, variant = "secondary", flexShrink = 0,
        onClick = onClick}, extra))
end

---@param children Widget[]
---@param gap? number
---@param extra? table Additional Panel props.
---@return Widget
local function Row(children, gap, extra)
    return UI.Panel(WithProps({flexDirection = "row", alignItems = "center", gap = gap or 7, flexShrink = 0, children = children}, extra))
end

---@param index string Two-digit section number.
---@param title string
---@return Widget
local function Section(index, title)
    return UI.Panel {marginTop = 14, marginBottom = 9, gap = 9, flexShrink = 0, children = {
        UI.Divider {},
        Row({Label(index, 10, COLORS.accent), Label(title, 15, COLORS.ink, {fontWeight = "bold"})}),
    }}
end

--- Show a button as selected or not.
---@param button Button
---@param selected boolean
local function SetSelected(button, selected)
    local variant = selected and "primary" or "secondary"
    if button.props.variant ~= variant then button:SetVariant(variant) end
end

--- Change a button or label text only when it differs.
---@param widget Button|Label
---@param text string
local function SetText(widget, text)
    if widget.props.text ~= text then widget:SetText(text) end
end

--- Initialize the shared TapTap UI around the character showcase.
---@param app TararaApp
---@return TararaInterface
function Interface.Create(app)
    UI.Init {theme = THEME, fonts = FONTS, scale = UI.Scale.DEFAULT}
    local self = setmetatable({app = app, rawMorphs = false, syncing = false}, Interface)
    self:Build()
    return self
end

--- Wrap a button callback so the controls reflect its effect immediately.
---@param action fun()
---@return fun()
function Interface:Action(action)
    return function()
        action()
        self:Refresh()
    end
end

--- Like Action, but manual input first stops the presentation.
---@param action fun()
---@return fun()
function Interface:Manual(action)
    return self:Action(function()
        self.app.demo:Stop()
        action()
    end)
end

--- A titled slider with its value readout. User input stops the presentation first; Refresh keeps
--- the slider in sync with getter.
---@param title string
---@param minimum number
---@param maximum number
---@param onChange fun(value: number) Called for user input only.
---@param getter fun(): number Current value.
---@param format? string
---@param step? number
---@return Widget row, Slider slider
function Interface:SliderRow(title, minimum, maximum, onChange, getter, format, step)
    format = format or "%.2f"
    local initial = getter()
    local readout = Label(string.format(format, initial), 12, COLORS.accent)
    local slider = UI.Slider {value = initial, min = minimum, max = maximum, step = step or (maximum - minimum) / 100, height = 24,
        onChange = function(_, v)
            readout:SetText(string.format(format, v))
            if not self.syncing then
                self.app.demo:Stop()
                onChange(v)
            end
        end}
    self.sliders[slider] = getter
    local row = UI.Panel {gap = 3, marginTop = 9, flexShrink = 0, children = {
        Row({Label(title, 12, COLORS.muted), readout}, nil, {justifyContent = "space-between"}),
        slider,
    }}
    return row, slider
end

--- Full-screen layer behind the controls: left drag turns the actor, right drag moves the light.
---@return Widget
function Interface:CreateDragPane()
    local app = self.app
    local function release(event)
        if event.pointerId == self.dragPointerId then self.dragButton, self.dragPointerId = nil, nil end
    end
    return UI.Panel {
        position = "absolute", left = 0, top = 0, right = 0, bottom = 0,
        onPointerDown = function(event)
            if self.dragPointerId ~= nil or (event.button ~= MOUSEB_LEFT and event.button ~= MOUSEB_RIGHT) then return end
            app.demo:Stop()
            app.autoRotate = false
            self.dragButton, self.dragPointerId = event.button, event.pointerId
            app.studio:HoldFraming()
        end,
        onPointerUp = function(event)
            if event.button == self.dragButton then release(event) end
        end,
        onPointerCancel = release,
        onPointerMove = function(event)
            if event.pointerId ~= self.dragPointerId then return end
            local studio = app.studio
            if self.dragButton == MOUSEB_LEFT then
                app:SetHeading(app.heading + event.deltaX * DRAG_HEADING)
            elseif self.dragButton == MOUSEB_RIGHT then
                studio:SetLightAngles(studio.lightYaw + event.deltaX * DRAG_LIGHT_YAW, studio.lightElevation - event.deltaY * DRAG_LIGHT_ELEVATION)
            end
        end,
    }
end

--- Top bar: logo, title and framing buttons.
---@param parent Widget
function Interface:BuildHeader(parent)
    local app, compact = self.app, self.compact
    local barHeight = compact and 56 or 62
    parent:AddChild(UI.Panel {position = "absolute", left = 0, right = 0, top = 0, height = barHeight,
        backgroundColor = COLORS.header, pointerEvents = "none"})
    parent:AddChild(UI.Panel {position = "absolute", left = 0, right = 0, top = barHeight, height = 1,
        backgroundColor = COLORS.line, pointerEvents = "none"})
    -- A plain panel, not a Card: the dark theme gives cards a drop shadow and a border. The UI
    -- library loads images without mipmaps, so the wordmark keeps its size; shrinking it further
    -- makes the letter edges jagged.
    local logo = UI.Panel {width = compact and 94 or 120, height = compact and 38 or 46, backgroundColor = COLORS.mint,
        borderRadius = 10, padding = 10,
        -- Square corners: the theme's default panel radius would clip the wordmark's first T.
        children = {UI.Panel {width = "100%", height = "100%", borderRadius = 0, backgroundImage = "UI/TapTap.png",
            backgroundFit = "contain"}}}
    ---@type Widget[]
    local brand = {logo}
    if not compact then
        brand[#brand + 1] = UI.Panel {children = {Label("嗒啦啦 · 角色研究所", 15, COLORS.ink, {fontWeight = "bold"}),
            Label("CHARACTER STUDIO / URHOX", 8, COLORS.muted, {letterSpacing = 1.4})}}
    end
    self.framingButtons = {}
    local views = {}
    for _, entry in ipairs({{"full", "全身"}, {"face", "面部特写"}}) do
        local framing = entry[1]
        local button = Button(entry[2], self:Manual(function() app.studio:SetFraming(framing) end),
            {width = compact and 76 or 94, height = 32})
        self.framingButtons[framing] = button
        views[#views + 1] = button
    end
    parent:AddChild(UI.Panel {position = "absolute", left = compact and 16 or 40, right = compact and 16 or 40, top = 8,
        flexDirection = "row", alignItems = "center", justifyContent = "space-between", pointerEvents = "box-none",
        children = {Row(brand, 14), Row(views), Label(compact and "" or "TAPTAP ORIGINAL  /  No.01", 10, COLORS.accent, {letterSpacing = 1.4})}})
end

--- Introduction text on wide screens; the counts come from the character definitions.
---@param parent Widget
function Interface:BuildIntro(parent)
    local clipCount = 0
    for _, clip in ipairs(Character.clips) do
        if clip.path then clipCount = clipCount + 1 end
    end
    parent:AddChild(UI.Panel {position = "absolute", left = 48, top = 112, width = 300, pointerEvents = "none", children = {
        Label("HELLO, PLAYER!", 11, COLORS.ink, {letterSpacing = 2.4, marginBottom = 18}),
        Label("嗒啦啦", 56, COLORS.ink, {fontWeight = "bold", letterSpacing = -1}),
        Label("TARARA", 24, COLORS.ink, {fontWeight = "bold", letterSpacing = 4, marginTop = 2}),
        UI.Panel {width = 48, height = 6, backgroundColor = COLORS.mint, marginTop = 24, marginBottom = 22},
        Label("发现，好玩的每一面。", 18, COLORS.ink, {fontWeight = "bold", marginBottom = 10}),
        Label("眨眨眼，打个招呼。\n让发梢与裙摆，跟着心情摇摆。", 12, COLORS.ink, {whiteSpace = "normal", lineHeight = 1.8}),
        UI.Panel {height = 30},
        Row({Label(string.format("%02d", clipCount), 28, COLORS.ink, {fontWeight = "bold"}), Label("段动作", 12, COLORS.ink),
            Label(tostring(#Character.morphs), 28, COLORS.ink, {fontWeight = "bold", marginLeft = 20}), Label("个形态键", 12, COLORS.ink)}, 8),
        Label("卡渲 · 表情 · 骨骼物理，同时呈现", 10, COLORS.ink, {marginTop = 9}),
    }})
end

--- Scrolling control sections: expressions, heading, physics, lighting.
---@param controls Widget
function Interface:BuildControls(controls)
    local app, hero, studio = self.app, self.app.hero, self.app.studio
    local function add(widget) controls:AddChild(widget) end

    add(Section("01", "表情与形态键"))
    self.expressionButtons = {}
    for row = 1, #Character.expressions, 2 do
        local buttons = {}
        for i = row, math.min(row + 1, #Character.expressions) do
            local preset = Character.expressions[i]
            local button = Button(preset.label, self:Manual(function() hero:SetExpression(preset.name) end), {flexGrow = 1, flexBasis = 0})
            self.expressionButtons[preset.name] = button
            buttons[#buttons + 1] = button
        end
        add(Row(buttons, nil, {marginBottom = 6}))
    end
    self.blinkButton = Button("自动眨眼", self:Manual(function() hero.autoBlink = not hero.autoBlink end), {flexGrow = 1, flexBasis = 0})
    self.eyeContactButton = Button("看镜头", self:Manual(function() hero.eyeContact = not hero.eyeContact end),
        {flexGrow = 1, flexBasis = 0})
    local morphButton = Button(self.rawMorphs and "收起形态键" or "全部形态键", self:Manual(function()
        self.rawMorphs = not self.rawMorphs
        self:Build()
    end), {flexGrow = 1, flexBasis = 0, variant = self.rawMorphs and "primary" or "secondary"})
    add(Row({self.blinkButton, self.eyeContactButton}, nil, {marginBottom = 6}))
    add(Row({morphButton}))
    add((self:SliderRow("表情浓度", 0, 1, function(v) hero.intensity = v end, function() return hero.intensity end)))
    if self.rawMorphs then
        for _, morph in ipairs(Character.morphs) do
            add((self:SliderRow(morph.label, 0, 1, function(v) hero:SetMorph(morph.name, v) end,
                function() return hero.targets[morph.name] or 0 end)))
        end
    end

    add(Section("02", "角色朝向"))
    local headingRow
    headingRow, self.headingSlider = self:SliderRow("角色朝向", -180, 180, function(v)
        app.autoRotate = false; app:SetHeading(v)
    end, function() return app.heading end, "%.0f°", 1)
    add(headingRow)
    self.autoRotateButton = Button("自动旋转", self:Manual(function() app.autoRotate = not app.autoRotate end), {flexGrow = 1})
    self.resetHeadingButton = Button("朝向归零", self:Manual(function() app.autoRotate = false; app:SetHeading(0) end), {flexGrow = 1})
    add(Row({self.autoRotateButton, self.resetHeadingButton}))

    add(Section("03", "头发与裙摆"))
    add((self:SliderRow("物理混合", 0, 1, function(v) hero:SetPhysics(v) end, function() return hero.physicsStrength end)))
    self.bonesButton = Button("显示骨链", self:Manual(function() app.bones = not app.bones end), {flexGrow = 1})
    add(Row({Button("重置模拟", self:Manual(function() hero:Reset() end), {flexGrow = 1}), self.bonesButton}))

    add(Section("04", "光影与镜头"))
    local lightRow
    lightRow, self.lightYawSlider = self:SliderRow("主光方位", -180, 180, function(v)
        studio:SetLightAngles(v, studio.lightElevation)
    end, function() return studio.lightYaw end, "%.0f°", 1)
    add(lightRow)
    lightRow, self.lightElevationSlider = self:SliderRow("主光仰角", -Studio.LIGHT_ELEVATION_LIMIT, Studio.LIGHT_ELEVATION_LIMIT, function(v)
        studio:SetLightAngles(studio.lightYaw, v)
    end, function() return studio.lightElevation end, "%.0f°", 1)
    add(lightRow)
    add((self:SliderRow("主光强度", 0, Studio.MAX_LIGHT_BRIGHTNESS, function(v) studio.light.brightness = v end,
        function() return studio.light.brightness end)))
    add((self:SliderRow("背景色相", 0, 359, function(v) studio:SetBackdrop({hue = v}) end,
        function() return studio.backdrop.hue end, "%.0f°", 1)))
    add((self:SliderRow("背景饱和", 0, 1, function(v) studio:SetBackdrop({saturation = v}) end,
        function() return studio.backdrop.saturation end)))
    add((self:SliderRow("背景明度", 0, 1, function(v) studio:SetBackdrop({brightness = v}) end,
        function() return studio.backdrop.brightness end)))
    add((self:SliderRow("描边宽度", 0, 3.5, function(v) app:SetOutline(v / 1000) end, function() return app.outline * 1000 end,
        "%.1f mm", 0.1)))
    add((self:SliderRow("Rim 强度", 0, Character.MAX_RIM_INTENSITY, function(v) hero:SetRim(v) end,
        function() return hero.rim end, "%.1f", 0.1)))
    add((self:SliderRow("不透明度", 0, 1, function(v) hero:SetOpacity(v) end, function() return hero.opacity end)))
    self.resetLightButton = Button("还原默认光照", self:Manual(function() studio:ResetLight() end), {width = "100%"})
    add(self.resetLightButton)
    add(Button("复位视角", self:Manual(function() app:ResetView() end), {width = "100%", marginTop = 6}))
end

--- Bottom bar: pause, clips and playback speed.
---@param parent Widget
function Interface:BuildPlayback(parent)
    local app, hero, compact = self.app, self.app.hero, self.compact
    self.pauseButton = Button("暂停", self:Action(function() app:SetPaused(not app.paused) end),
        {width = compact and 44 or 58, paddingHorizontal = 4, variant = "primary"})
    ---@type Widget[]
    local items = {self.pauseButton}
    self.animationButtons = {}
    for _, clip in ipairs(Character.clips) do
        local width = compact and (clip.path and 42 or 52) or 65
        local button = Button(clip.label, self:Manual(function() hero:Play(clip.name) end), {width = width, paddingHorizontal = 4})
        items[#items + 1] = button
        self.animationButtons[clip.name] = button
    end
    if not compact then
        items[#items + 1] = Label("速度", 11, COLORS.muted, {marginLeft = 10})
        local speed = UI.Slider {width = 80, value = hero.speed, min = 0.25, max = 1.5, step = 0.05,
            onChange = function(_, v) if not self.syncing then app.demo:Stop(); hero:SetSpeed(v) end end}
        self.sliders[speed] = function() return hero.speed end
        items[#items + 1] = speed
    end
    parent:AddChild(UI.Card {position = "absolute", alignSelf = "center", bottom = 22, padding = compact and 8 or 10,
        flexDirection = "row", alignItems = "center", gap = compact and 4 or 8, backgroundColor = COLORS.surface, children = items})
    if not compact then
        parent:AddChild(UI.Panel {position = "absolute", left = 46, bottom = 40, pointerEvents = "none", children = {
            Label("左键转角色 · 右键调光 · 滚轮缩放", 10, COLORS.ink),
            Label("SPACE 暂停    R 复位    H 隐藏界面", 9, COLORS.ink, {marginTop = 4}),
        }})
    end
end

--- Build the layout for the current viewport. Only layout changes need this; Refresh keeps
--- selections and values current.
function Interface:Build()
    local app = self.app
    local scrollX, scrollY = 0, 0
    if self.scrollView then scrollX, scrollY = self.scrollView:GetScroll() end
    self.dragButton, self.dragPointerId = nil, nil
    self.sliders = {}
    local width, height = UI.GetViewportSize()
    self.width, self.height = width, height
    self.compact = width < COMPACT_WIDTH
    app.studio.compact = self.compact
    local compact = self.compact

    local root = UI.Panel {width = "100%", height = "100%", pointerEvents = "box-none"}
    self.dragPane = self:CreateDragPane()
    root:AddChild(self.dragPane)
    local safe = UI.SafeAreaView {width = "100%", height = "100%", pointerEvents = "box-none"}
    root:AddChild(safe)
    self:BuildHeader(safe)
    if width >= INTRO_WIDTH then self:BuildIntro(safe) end

    local panel = UI.Card {
        position = "absolute", right = compact and 16 or 14, top = not compact and 92 or nil,
        bottom = compact and 104 or nil, width = compact and width - 32 or 266,
        height = compact and math.min(310, math.floor(height * 0.37)) or math.min(840, height - 214),
        padding = compact and 14 or 18, backgroundColor = COLORS.surface,
    }
    safe:AddChild(panel)
    panel:AddChild(Label("今天，什么心情？", 20, COLORS.ink, {fontWeight = "bold"}))
    panel:AddChild(Label("表情、物理和光影，一起调一调。", 11, COLORS.muted, {marginTop = 4, marginBottom = 10}))
    self.demoButton = Button("自动演播", self:Action(function() app:SetDemo(not app.demo.active) end), {width = "100%"})
    panel:AddChild(self.demoButton)
    self.demoStatusLabel = Label(app.demo:GetStatus(), 10, COLORS.muted, {marginTop = 5, marginBottom = 8})
    panel:AddChild(self.demoStatusLabel)
    local controls = UI.Panel {paddingBottom = 6}
    -- Extend into the card's right inset and keep a separate gutter for the overlay scrollbar.
    self.scrollView = UI.ScrollView {flexGrow = 1, flexBasis = 0, scrollX = false,
        marginRight = compact and -10 or -14, paddingRight = 20, children = {controls}}
    panel:AddChild(self.scrollView)
    self:BuildControls(controls)
    self:BuildPlayback(safe)

    self.root = root
    UI.SetRoot(root, true)
    root:SetVisible(app.visible)
    self.scrollView:SetScrollDirect(scrollX, scrollY)
    self:Refresh()
end

--- Bring selections, toggle labels and slider values in line with the application state
--- without treating the writes as user input.
function Interface:Refresh()
    local app, hero = self.app, self.app.hero
    for framing, button in pairs(self.framingButtons) do SetSelected(button, app.studio.framing == framing) end
    for name, button in pairs(self.expressionButtons) do SetSelected(button, hero.expression == name) end
    for name, button in pairs(self.animationButtons) do SetSelected(button, hero.animation == name) end
    SetSelected(self.blinkButton, hero.autoBlink)
    SetText(self.blinkButton, hero.autoBlink and "自动眨眼 ✓" or "自动眨眼")
    SetSelected(self.eyeContactButton, hero.eyeContact)
    SetText(self.eyeContactButton, hero.eyeContact and "看镜头 ✓" or "看镜头")
    SetSelected(self.bonesButton, app.bones)
    SetText(self.bonesButton, app.bones and "隐藏骨链" or "显示骨链")
    SetSelected(self.autoRotateButton, app.autoRotate)
    SetText(self.autoRotateButton, app.autoRotate and "停止旋转" or "自动旋转")
    SetText(self.pauseButton, app.paused and "继续" or "暂停")
    SetSelected(self.demoButton, app.demo.active)
    SetText(self.demoButton, app.demo.active and "停止演播" or "自动演播")
    SetText(self.demoStatusLabel, app.demo:GetStatus())
    self.syncing = true
    for slider, getter in pairs(self.sliders) do slider:SetValue(getter()) end
    self.syncing = false
end

--- Rebuild after a viewport change, then refresh; call once per frame.
function Interface:Update()
    local width, height = UI.GetViewportSize()
    if math.abs(width - self.width) > 2 or math.abs(height - self.height) > 2 then self:Build() end
    self:Refresh()
end

--- Show or hide the whole interface.
---@param visible boolean
function Interface:SetVisible(visible)
    self.root:SetVisible(visible)
end

--- Release the shared UI when the example stops.
function Interface.Shutdown()
    UI.Shutdown()
end

return Interface
