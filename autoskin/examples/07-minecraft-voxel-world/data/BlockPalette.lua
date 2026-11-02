-- ====================================================================
-- data/BlockPalette.lua
-- 物品栏调色板 - 分页的可放置方块清单
--
-- 方块种类早就超过一屏能放的 11 格（键位 1..0 与 -），所以按类别分页。
-- 页数与页内容以下面的 pages 为唯一真源，别在别处复述数字（会漏改）。
-- Hotbar 与 Player 都从这里读，避免以前"两个文件各抄一份方块列表"的漂移。
-- ====================================================================

local Blocks = require("data.BlockRegistry")

local BlockPalette = {}

-- 每页最多的槽位数（对应键位 1,2,...,9,0,-）
BlockPalette.MAX_SLOTS = 11

---@type { name: string, blocks: number[] }[]
BlockPalette.pages = {
    {
        name = "基础",
        blocks = {
            Blocks.GRASS, Blocks.DIRT, Blocks.STONE, Blocks.COBBLESTONE,
            Blocks.WOOD, Blocks.PLANKS, Blocks.LEAVES, Blocks.SAND,
            Blocks.SANDSTONE, Blocks.GRAVEL, Blocks.CLAY,
        },
    },
    {
        name = "建材",
        blocks = {
            Blocks.BRICKS, Blocks.STONE_BRICKS, Blocks.MOSSY_COBBLESTONE,
            Blocks.OBSIDIAN, Blocks.BEDROCK, Blocks.BOOKSHELF,
            Blocks.CRAFTING_TABLE, Blocks.FURNACE,
            Blocks.GLASS, Blocks.ICE, Blocks.SNOW_BLOCK,
        },
    },
    {
        name = "矿石与光",
        blocks = {
            Blocks.COAL_ORE, Blocks.IRON_ORE, Blocks.GOLD_ORE,
            Blocks.DIAMOND_ORE, Blocks.REDSTONE_ORE, Blocks.LAPIS_ORE,
            Blocks.GLOWSTONE, Blocks.TORCH, Blocks.LAVA, Blocks.WATER,
            Blocks.CACTUS,
        },
    },
    {
        name = "羊毛",
        blocks = {
            Blocks.WOOL_WHITE, Blocks.WOOL_RED, Blocks.WOOL_YELLOW,
            Blocks.WOOL_GREEN, Blocks.WOOL_BLUE, Blocks.WOOL_BLACK,
        },
    },
    {
        name = "植物",
        blocks = {
            Blocks.TALL_GRASS, Blocks.ROSE, Blocks.FLOWER_YELLOW, Blocks.FLOWER_BLUE,
            Blocks.SAPLING, Blocks.DEAD_BUSH, Blocks.MUSHROOM_RED, Blocks.MUSHROOM_BROWN,
            Blocks.SNOWY_GRASS,
        },
    },
    {
        name = "半砖",
        blocks = {
            Blocks.SLAB_STONE, Blocks.SLAB_COBBLESTONE, Blocks.SLAB_SANDSTONE,
            Blocks.SLAB_BRICKS, Blocks.SLAB_STONE_BRICKS, Blocks.SLAB_PLANKS,
        },
    },
    {
        name = "楼梯",
        blocks = {
            Blocks.STAIRS_STONE, Blocks.STAIRS_COBBLESTONE, Blocks.STAIRS_SANDSTONE,
            Blocks.STAIRS_BRICKS, Blocks.STAIRS_STONE_BRICKS, Blocks.STAIRS_PLANKS,
        },
    },
    {
        name = "门窗栅栏",
        blocks = {
            Blocks.FENCE_WOOD, Blocks.WALL_COBBLESTONE,
            Blocks.DOOR_WOOD, Blocks.DOOR_IRON, Blocks.TRAPDOOR_WOOD,
        },
    },
}

---@return number 页数
function BlockPalette:pageCount()
    return #self.pages
end

---把页号夹到有效范围（越界时环绕，翻页手感更好）
---@param pageIndex number
---@return number
function BlockPalette:wrapPage(pageIndex)
    local count = self:pageCount()
    if count == 0 then return 1 end
    return ((pageIndex - 1) % count) + 1
end

---@param pageIndex number
---@return table|nil { name, blocks }
function BlockPalette:getPage(pageIndex)
    return self.pages[self:wrapPage(pageIndex)]
end

---@param pageIndex number
---@return table 方块 id 数组
function BlockPalette:getBlocks(pageIndex)
    return self:getPage(pageIndex).blocks
end

---@param pageIndex number
---@return string 页名（显示用）
function BlockPalette:getPageName(pageIndex)
    return self:getPage(pageIndex).name
end

---@param pageIndex number
---@param slotIndex number
---@return number|nil 方块 id（空槽返回 nil）
function BlockPalette:getBlock(pageIndex, slotIndex)
    return self:getBlocks(pageIndex)[slotIndex]
end

---方块颜色 → UI 用的 0-255 RGBA（直接取注册表颜色，不再维护第二份颜色表）
---@param blockType number
---@return table {r, g, b, a}
function BlockPalette:getSlotColor(blockType)
    local c = Blocks:getColor(blockType)
    return {
        math.floor(math.min(1, math.max(0, c.r)) * 255),
        math.floor(math.min(1, math.max(0, c.g)) * 255),
        math.floor(math.min(1, math.max(0, c.b)) * 255),
        255,
    }
end

return BlockPalette
