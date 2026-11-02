-- ====================================================================
-- ui/Hotbar.lua
-- 物品栏 UI - 使用 urhox-libs/UI 系统重构
-- 支持分页：方块种类远超一屏的 11 格，按类别分页（[ / ] 或点箭头翻页）
-- 页数/页内容看 data/BlockPalette.lua 的 pages，这里不复述数字
-- ====================================================================

local UI = require("urhox-libs/UI/init")
local Blocks = require("data.BlockRegistry")
local Palette = require("data.BlockPalette")

---@class Hotbar
---@field hotbarBlocks table 当前页的方块列表
---@field pageIndex integer 当前页号
---@field player Player|nil
---@field onBlockSelected function|nil
---@field selectedIndex integer
---@field root Panel|nil
local Hotbar = {}
Hotbar.__index = Hotbar

-- 槽位尺寸配置
local SLOT_SIZE = 48
local SLOT_GAP = 6

-- 槽位数字键提示（对应 KEY_1..KEY_9, KEY_0, KEY_MINUS）
---@type string[]
local SLOT_KEY_LABELS = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-" }

-- 空槽样式（该页方块数不足 11 时）
local EMPTY_SLOT_COLOR = { 0, 0, 0, 90 }

---创建物品栏 UI
---@param player Player|nil Player实例（可选）
---@return Hotbar
function Hotbar.new(player)
    local self = setmetatable({}, Hotbar)
    self.player = player
    self.pageIndex = 1
    self.hotbarBlocks = Palette:getBlocks(self.pageIndex)
    self.root = nil
    self.slots = {}
    self.selectedIndex = 1
    return self
end

---槽位背景色（空槽用暗色）
---@param blockType number|nil
---@return table {r,g,b,a}
local function slotColor(blockType)
    if not blockType then
        return EMPTY_SLOT_COLOR
    end
    return Palette:getSlotColor(blockType)
end

---创建单个物品槽
---@param index number 槽位索引 (1-11)
---@return Widget 槽位 Widget
function Hotbar:createSlot(index)
    local blockType = self.hotbarBlocks[index]
    local isSelected = (index == self.selectedIndex) and blockType ~= nil

    local slot = UI.Panel {
        id = "slot_" .. index,
        width = SLOT_SIZE,
        height = SLOT_SIZE,
        alignItems = "center",
        justifyContent = "center",
        backgroundColor = slotColor(blockType),
        borderRadius = 4,
        -- 选中时白色边框，未选中时深色边框（与底框区分）
        borderWidth = isSelected and 3 or 1,
        borderColor = isSelected and { 255, 255, 255, 255 } or { 0, 0, 0, 60 },

        -- 槽位按键提示（右下角小字）
        UI.Label {
            text = SLOT_KEY_LABELS[index] or tostring(index),
            position = "absolute",
            bottom = 2,
            right = 4,
            fontSize = 10,
            fontColor = isSelected and { 255, 255, 255, 255 } or { 255, 255, 255, 150 },
            textAlign = "right",
        },
    }

    return slot
end

---构建物品栏 UI 树
---@return Widget 物品栏根 Widget
function Hotbar:build()
    local selectedBlock = self.hotbarBlocks[self.selectedIndex]
    local selectedName = selectedBlock and Blocks:getDisplayName(selectedBlock) or "-"

    -- 创建物品栏容器
    self.root = UI.Panel {
        id = "hotbar_container",
        position = "absolute",
        bottom = 20,
        left = 0,
        right = 0,
        -- 分页条 + 方块名 + 槽位行三段，高度不够会被裁掉（引擎会打 Layout Warning）
        height = 170,
        flexDirection = "column",
        alignItems = "center",
        gap = 8,

        -- 分页条：◀ 页号/总数 页名 ▶（箭头可点，移动端也能翻页）
        UI.Row {
            id = "hotbar_pager",
            gap = 8,
            alignItems = "center",
            justifyContent = "center",

            UI.Label {
                id = "page_prev",
                text = "◀",
                fontSize = 16,
                fontColor = { 255, 255, 255, 230 },
                backgroundColor = { 30, 30, 30, 200 },
                borderRadius = 6,
                paddingHorizontal = 10,
                paddingVertical = 4,
                onClick = function()
                    self:prevPage()
                end,
            },
            UI.Label {
                id = "page_label",
                text = self:getPageText(),
                fontSize = 13,
                fontColor = { 255, 255, 255, 230 },
                backgroundColor = { 30, 30, 30, 200 },
                borderRadius = 6,
                paddingHorizontal = 12,
                paddingVertical = 4,
                textAlign = "center",
            },
            UI.Label {
                id = "page_next",
                text = "▶",
                fontSize = 16,
                fontColor = { 255, 255, 255, 230 },
                backgroundColor = { 30, 30, 30, 200 },
                borderRadius = 6,
                paddingHorizontal = 10,
                paddingVertical = 4,
                onClick = function()
                    self:nextPage()
                end,
            },
        },

        -- 选中方块名称（上方浮动显示）
        UI.Label {
            id = "selected_block_name",
            text = selectedName,
            fontSize = 14,
            fontColor = { 255, 255, 255, 240 },
            textAlign = "center",
            backgroundColor = { 30, 30, 30, 200 },
            borderRadius = 8,
            paddingHorizontal = 16,
            paddingVertical = 6,
        },

        -- 物品槽容器（添加半透明底框）
        UI.Row {
            id = "slots_row",
            gap = SLOT_GAP,
            alignItems = "center",
            justifyContent = "center",
            backgroundColor = { 0, 0, 0, 150 },
            borderRadius = 10,
            padding = 8,

            -- 固定创建 MAX_SLOTS 个槽，翻页只改配色（避免增删子节点）
            table.unpack(self:createSlots())
        },
    }

    return self.root
end

---分页条文本
---@return string
function Hotbar:getPageText()
    return string.format("%d/%d  %s", self.pageIndex, Palette:pageCount(),
        Palette:getPageName(self.pageIndex))
end

---创建所有物品槽
---@return table Widget数组
function Hotbar:createSlots()
    local slots = {}
    self.slots = {}

    for i = 1, Palette.MAX_SLOTS do
        local slot = self:createSlot(i)
        slots[i] = slot
        self.slots[i] = slot
    end

    return slots
end

---获取物品栏根 Widget
---@return Widget|nil
function Hotbar:getRoot()
    return self.root
end

---更新物品栏显示
function Hotbar:update()
    if not self.root then return end

    -- 更新选中方块名称
    ---@type Label|nil
    local nameLabel = self.root:FindById("selected_block_name")
    if nameLabel then
        local selectedBlock = self.hotbarBlocks[self.selectedIndex]
        nameLabel:SetText(selectedBlock and Blocks:getDisplayName(selectedBlock) or "-")
    end

    -- 更新分页文本
    local pageLabel = self.root:FindById("page_label")
    if pageLabel then
        pageLabel:SetText(self:getPageText())
    end

    -- 更新槽位样式（配色随页变化）
    for i, slot in ipairs(self.slots) do
        local blockType = self.hotbarBlocks[i]
        local isSelected = (i == self.selectedIndex) and blockType ~= nil

        slot:SetStyle({
            backgroundColor = slotColor(blockType),
            borderWidth = isSelected and 3 or 1,
            borderColor = isSelected and { 255, 255, 255, 255 } or { 0, 0, 0, 60 },
        })
    end
end

---处理槽位选择
---@param index number 槽位索引（1-11）
function Hotbar:selectSlot(index)
    local blockType = self.hotbarBlocks[index]
    if not blockType then
        return  -- 空槽：忽略
    end

    self.selectedIndex = index
    -- 通知 player（如果存在）
    if self.player then
        self.player:selectSlot(index, blockType)
    end
    -- 触发回调（网络模式使用）
    if self.onBlockSelected then
        self.onBlockSelected(blockType)
    end
    self:update()
end

---切换到指定页（越界环绕）
---@param pageIndex number
function Hotbar:setPage(pageIndex)
    self.pageIndex = Palette:wrapPage(pageIndex)
    self.hotbarBlocks = Palette:getBlocks(self.pageIndex)

    -- 选中位置夹到本页范围内，并同步给 player
    if self.selectedIndex > #self.hotbarBlocks then
        self.selectedIndex = #self.hotbarBlocks
    end
    self:selectSlot(self.selectedIndex)
end

---下一页
function Hotbar:nextPage()
    self:setPage(self.pageIndex + 1)
end

---上一页
function Hotbar:prevPage()
    self:setPage(self.pageIndex - 1)
end

---获取选中的方块类型
---@return number 方块类型
function Hotbar:getSelectedBlock()
    return self.hotbarBlocks[self.selectedIndex]
end

return Hotbar
