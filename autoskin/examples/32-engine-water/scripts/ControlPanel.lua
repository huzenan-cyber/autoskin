--- Parameter panel of the engine water example, built with urhox-libs/UI: help and status lines, then environment,
--- wave and water pages. Every control writes the shared settings table and calls the matching callback of actions:
--- environment(), waveKind(), waves() and mirror(). Water material settings need no callback; WaterScene.Update()
--- writes them every frame.
local UI = require("urhox-libs/UI")

---@class ControlPanel
---@field settings WaterSettings
---@field toggles {toggle: Toggle, get: fun(): boolean}[]
---@field choices fun()[]
---@field page string
---@field fftGroup Panel
---@field gerstnerGroup Panel
---@field status Label
---@field panel Panel
local ControlPanel = {}
ControlPanel.__index = ControlPanel

local TITLE, TEXT, DIM = {236, 244, 246, 255}, {214, 226, 230, 255}, {150, 178, 186, 255}

local function Caption(text, size, color)
    return UI.Label {text = text, fontSize = size or 12, fontColor = color or TEXT}
end

-- A slider with its caption; format shows the value after the name.
local function Slider(name, minimum, maximum, step, format, get, set, apply)
    local function describe(value) return name .. "  " .. string.format(format, value) end
    local caption = Caption(describe(get()), 12, DIM)
    local slider = UI.Slider {
        min = minimum, max = maximum, step = step, value = get(), width = "100%",
        onChange = function(_, value)
            set(value)
            caption:SetText(describe(value))
            apply()
        end,
    }
    return UI.Panel {width = "100%", gap = 2, children = {caption, slider}}
end

-- A row of buttons choosing one value; returns the row and a function that restyles it from get().
local function Choice(options, get, set, apply)
    local buttons, row = {}, {}
    local function update()
        for value, button in pairs(buttons) do
            button:SetStyle({variant = get() == value and "primary" or "secondary"})
        end
    end
    for _, option in ipairs(options) do
        local value = option[1]
        local button = UI.Button {
            text = option[2], flexGrow = 1, fontSize = 12, variant = get() == value and "primary" or "secondary",
            onClick = function()
                if get() ~= value then
                    set(value)
                    apply()
                end
                update()
            end,
        }
        buttons[value] = button
        row[#row + 1] = button
    end
    return UI.Panel {flexDirection = "row", width = "100%", gap = 6, children = row}, update
end

local function Page(children)
    return UI.Panel {width = "100%", gap = 8, children = children}
end

local function Nothing() end

--- Build the panel and make it the UI root. settings is read and written in place.
---@param settings WaterSettings
---@param actions {environment: fun(), waveKind: fun(), waves: fun(), mirror: fun()}
---@return ControlPanel
function ControlPanel.Create(settings, actions)
    local self = setmetatable({settings = settings, toggles = {}, choices = {}}, ControlPanel)
    local function Switch(name, get, set, apply)
        local toggle = UI.Toggle {
            label = name, value = get(), width = "100%", fontSize = 12,
            onChange = function(_, value)
                if value ~= get() then
                    set(value)
                    apply()
                end
            end,
        }
        table.insert(self.toggles, {toggle = toggle, get = get})
        return toggle
    end
    local function Pick(options, get, set, apply)
        local row, update = Choice(options, get, set, apply)
        table.insert(self.choices, update)
        return row
    end
    local m, fft, gerstner = settings.material, settings.fft, settings.gerstner

    local environmentPage = Page {
        Pick({{"atmosphere", "物理大气"}, {"procedural", "程序天空"}}, function() return settings.sky end,
             function(v) settings.sky = v end, actions.environment),
        Switch("体积云", function() return settings.clouds end, function(v) settings.clouds = v end, actions.environment),
        Slider("云量", -0.8, 0.5, 0.01, "%+.2f", function() return settings.cloudCoverage end,
               function(v) settings.cloudCoverage = v end, actions.environment),
        Slider("太阳高度", -5, 90, 1, "%.0f°", function() return settings.sunElevation end,
               function(v) settings.sunElevation = v end, actions.environment),
        Slider("太阳方位", 0, 360, 1, "%.0f°", function() return settings.sunAzimuth end,
               function(v) settings.sunAzimuth = v end, actions.environment),
        Switch("距离雾（程序天空用）", function() return settings.depthFog end, function(v) settings.depthFog = v end,
               actions.environment),
    }

    self.fftGroup = Page {
        Slider("风速", 1, 20, 0.1, "%.1f m/s", function() return fft.windSpeed end,
               function(v) fft.windSpeed = v end, actions.waves),
        Slider("吹程", 1, 300, 1, "%.0f km", function() return fft.fetch end,
               function(v) fft.fetch = v end, actions.waves),
        Slider("尖锐度", 0, 2.5, 0.05, "%.2f", function() return fft.choppiness end,
               function(v) fft.choppiness = v end, actions.waves),
        Slider("涌浪", 0, 1, 0.01, "%.2f", function() return fft.swell end,
               function(v) fft.swell = v end, actions.waves),
    }
    self.gerstnerGroup = Page {
        Slider("波数", 1, 32, 1, "%d", function() return gerstner.waveCount end,
               function(v) gerstner.waveCount = math.floor(v + 0.5) end, actions.waves),
        Slider("最长波长", 4, 40, 0.5, "%.1f m", function() return gerstner.maxWavelength end,
               function(v) gerstner.maxWavelength = v end, actions.waves),
        Slider("最大振幅", 0.02, 0.6, 0.01, "%.2f m", function() return gerstner.maxAmplitude end,
               function(v) gerstner.maxAmplitude = v end, actions.waves),
        Slider("方向扩散", 0, 90, 1, "%.0f°", function() return gerstner.spread end,
               function(v) gerstner.spread = v end, actions.waves),
    }
    local wavesPage = Page {
        Pick({{"fft", "FFT 海面"}, {"gerstner", "Gerstner 湖面"}}, function() return settings.waves end,
             function(v) settings.waves = v end, function()
                 actions.waveKind()
                 self:Refresh()
             end),
        Slider("风向（0 吹向 +Z，90 吹向岸边）", -180, 180, 1, "%.0f°", function() return settings.windAngle end,
               function(v) settings.windAngle = v end, actions.waves),
        self.fftGroup,
        self.gerstnerGroup,
    }

    local waterPage = Page {
        Switch("朝下反射：镜像天空（M）", function() return settings.mirror end, function(v) settings.mirror = v end,
               actions.mirror),
        Switch("屏幕空间反射", function() return settings.ssr end, function(v) settings.ssr = v end, actions.environment),
        Switch("水底焦散", function() return m.caustics end, function(v) m.caustics = v end, Nothing),
        Slider("焦散亮度", 0, 3, 0.05, "%.2f", function() return m.causticsBrightness end,
               function(v) m.causticsBrightness = v end, Nothing),
        Slider("浪尖透光", 0, 3, 0.05, "%.2f", function() return m.crestLight end,
               function(v) m.crestLight = v end, Nothing),
        Slider("基础粗糙度", 0, 0.3, 0.005, "%.3f", function() return m.roughness end,
               function(v) m.roughness = v end, Nothing),
        Slider("细节法线", 0, 2, 0.05, "%.2f", function() return m.detail end,
               function(v) m.detail = v end, Nothing),
        Slider("吸收", 0, 3, 0.05, "x%.2f", function() return m.absorption end,
               function(v) m.absorption = v end, Nothing),
        Slider("散射", 0, 3, 0.05, "x%.2f", function() return m.scattering end,
               function(v) m.scattering = v end, Nothing),
        Slider("白浪起始覆盖", 0, 1, 0.01, "%.2f", function() return m.whitecap end,
               function(v) m.whitecap = v end, Nothing),
        Slider("破碎浪峰阈值", 0.3, 1, 0.01, "%.2f", function() return m.breaking end,
               function(v) m.breaking = v end, Nothing),
        Slider("岸边泡沫厚度", 0.05, 2, 0.05, "%.2f m", function() return m.shoreFoam end,
               function(v) m.shoreFoam = v end, Nothing),
    }

    local pages = {environment = environmentPage, waves = wavesPage, water = waterPage}
    self.page = "environment"
    local function ShowPage()
        for name, page in pairs(pages) do page:SetVisible(name == self.page) end
    end
    local tabs = Pick({{"environment", "环境"}, {"waves", "波浪"}, {"water", "水体"}}, function() return self.page end,
                      function(v) self.page = v end, ShowPage)

    self.status = Caption("", 12)
    self.panel = UI.Panel {
        position = "absolute", left = 16, top = 16, width = 430, padding = 14, gap = 8,
        backgroundColor = {12, 34, 39, 215}, borderRadius = 6,
        children = {
            Caption("ENGINE WATER / 引擎水域", 17, TITLE),
            Caption("WASD 移动  Shift 跑  Space 跳/上浮  C 下潜", 12, DIM),
            Caption("B 上/下船  船上 W/S 油门/倒车 A/D 转向 Space 刹车", 12, DIM),
            Caption("右键拖动 转视角  G 切换波浪  R 重置船与浮体", 12, DIM),
            Caption("M 朝下反射  H 隐藏面板  Backspace 回岸", 12, DIM),
            self.status,
            tabs,
            environmentPage,
            wavesPage,
            waterPage,
        },
    }
    UI.SetRoot(UI.Panel {width = "100%", height = "100%", pointerEvents = "box-none", children = {self.panel}})
    ShowPage()
    self:Refresh()
    return self
end

--- Show the status text.
function ControlPanel:SetStatus(text)
    self.status:SetText(text)
end

--- Bring the controls in line with settings changed by keys, and show the parameters of the current wave surface.
function ControlPanel:Refresh()
    for _, entry in ipairs(self.toggles) do
        if entry.toggle.props.value ~= entry.get() then entry.toggle:SetValue(entry.get()) end
    end
    for _, update in ipairs(self.choices) do update() end
    self.fftGroup:SetVisible(self.settings.waves == "fft")
    self.gerstnerGroup:SetVisible(self.settings.waves == "gerstner")
end

--- Show or hide the whole panel.
function ControlPanel:ToggleVisible()
    self.panel:SetVisible(not self.panel:IsVisible())
end

return ControlPanel
