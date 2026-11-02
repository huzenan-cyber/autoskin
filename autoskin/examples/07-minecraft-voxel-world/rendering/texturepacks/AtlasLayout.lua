-- ====================================================================
-- rendering/texturepacks/AtlasLayout.lua
-- 图集布局 - tile 名称 → {row, col} 的单点定义
--
-- 材质包（ClassicPack / HDPack）与 BlockRegistry 都从这里取坐标：
-- 以前三处各自硬编码 {row, col}，加一个方块要改三处、漏一处就错位。
-- 新增 tile 只需在下面 ROWS 里加名字，两个材质包按 order 自动排布。
-- ====================================================================

local AtlasLayout = {}

-- 每行 tile 数（= atlasSize / tileSize，Classic 256/16、HD 512/32 都是 16）
AtlasLayout.TILES_PER_ROW = 16

-- ============================================
-- 布局声明（行内顺序 = 列号 0,1,2...）
-- ============================================
-- 注意：图集禁用了 mipmap 且 UV 带半像素 padding，tile 内容不要依赖边界像素。
local ROWS = {
    -- Row 0-2：原有 tile，位置不能变（存档/联机无关，但改了老截图全部失效）
    [0] = { "grass_top", "grass_side", "dirt", "stone" },
    [1] = { "wood_top", "wood_side", "leaves", "sand" },
    [2] = { "water", "tall_grass", "torch", "rose", "flower_yellow", "flower_blue" },

    -- Row 3：石制 + 建材
    [3] = {
        "cobblestone", "mossy_cobblestone", "stone_bricks",
        "sandstone_top", "sandstone_side", "sandstone_bottom",
        "obsidian", "bedrock",
        "planks", "bricks", "bookshelf_side",
        "crafting_top", "crafting_side",
        "furnace_top", "furnace_side",
    },

    -- Row 4：矿石 + 自然
    [4] = {
        "coal_ore", "iron_ore", "gold_ore", "diamond_ore", "redstone_ore", "lapis_ore",
        "glowstone",
        "gravel", "clay", "snow", "grass_snow_side", "ice", "lava",
        "cactus_top", "cactus_side", "cactus_bottom",
    },

    -- Row 5：透明 + 羊毛 + 植物
    [5] = {
        "glass",
        "wool_white", "wool_red", "wool_yellow", "wool_green", "wool_blue", "wool_black",
        "sapling", "dead_bush", "mushroom_red", "mushroom_brown",
    },

    -- Row 6：门 / 活板门（半砖、楼梯、栅栏复用各自材质的 tile，不占新格子）
    [6] = {
        "door_wood_lower", "door_wood_upper",
        "door_iron_lower", "door_iron_upper",
        "trapdoor_wood",
    },
}

AtlasLayout.ROW_COUNT = 7

-- ============================================
-- 派生数据（模块加载时构建一次）
-- ============================================

---name → {row, col}
AtlasLayout.tile = {}

---按声明顺序排列的 { name, row, col }，材质包遍历它生成纹理
AtlasLayout.order = {}

---已占用格子集合，键为 row * TILES_PER_ROW + col
AtlasLayout.used = {}

for row = 0, AtlasLayout.ROW_COUNT - 1 do
    local names = ROWS[row]
    if names then
        for i, name in ipairs(names) do
            local col = i - 1
            assert(col < AtlasLayout.TILES_PER_ROW,
                string.format("[AtlasLayout] row %d overflow at tile '%s'", row, name))
            assert(not AtlasLayout.tile[name],
                string.format("[AtlasLayout] duplicate tile name '%s'", name))

            AtlasLayout.tile[name] = { row, col }
            AtlasLayout.order[#AtlasLayout.order + 1] = { name = name, row = row, col = col }
            AtlasLayout.used[row * AtlasLayout.TILES_PER_ROW + col] = name
        end
    end
end

-- ============================================
-- 查询接口
-- ============================================

---取 tile 坐标（名字写错时直接报错，避免 nil 一路传到 UV 计算才崩）
---@param name string tile 名称
---@return table {row, col}
function AtlasLayout.get(name)
    local pos = AtlasLayout.tile[name]
    if not pos then
        error("[AtlasLayout] unknown tile name: " .. tostring(name), 2)
    end
    return pos
end

---格子是否已被占用（fillUnusedTiles 用它反推空位）
---@param row number 行
---@param col number 列
---@return boolean
function AtlasLayout.isUsed(row, col)
    return AtlasLayout.used[row * AtlasLayout.TILES_PER_ROW + col] ~= nil
end

---占用格子数（调试用）
---@return number
function AtlasLayout.count()
    return #AtlasLayout.order
end

return AtlasLayout
