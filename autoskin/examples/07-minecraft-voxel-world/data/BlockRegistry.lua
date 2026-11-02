-- ====================================================================
-- data/BlockRegistry.lua
-- 方块注册表 - 数据驱动的方块系统
-- ====================================================================

local Atlas = require("rendering.texturepacks.AtlasLayout")
local T = Atlas.tile  -- tile 名称 → {row, col}

-- SLAB_* / STAIRS_* 常量在文件后段按 BUILD_MATERIALS 循环注册，这里给 LSP 声明一下
---@class BlockRegistry
---@field SLAB_COBBLESTONE integer
---@field SLAB_SANDSTONE integer
---@field SLAB_BRICKS integer
---@field SLAB_STONE_BRICKS integer
---@field SLAB_PLANKS integer
---@field STAIRS_STONE integer
---@field STAIRS_COBBLESTONE integer
---@field STAIRS_SANDSTONE integer
---@field STAIRS_BRICKS integer
---@field STAIRS_STONE_BRICKS integer
---@field STAIRS_PLANKS integer
local BlockRegistry = {
    blocks = {},       -- [id] = blockData
    byName = {},       -- [name] = blockData
}

-- ============================================
-- 渲染层常量
-- ============================================
-- ChunkMeshBuilder 按 layer 分派到不同几何体/材质：
--   solid       不透明立方体（DiffVCol）
--   cutout      alpha 裁剪立方体（玻璃：DiffVColAlphaMask，背面剔除照常）
--   translucent alpha 混合立方体（冰：DiffVColUnlitAlpha）
--   liquid      液体（水走 SingleLayerWater，岩浆走 unlit）
--   cross       X 形插片（草/花/树苗）
--   shape       由若干 AABB 盒子组成的非整格方块（半砖/楼梯/栅栏/门/活板门）
--   item        不进 chunk 网格（火把由 TorchDecorator 建独立节点）
BlockRegistry.LAYER_SHAPE = "shape"
BlockRegistry.LAYER_SOLID = "solid"
BlockRegistry.LAYER_CUTOUT = "cutout"
BlockRegistry.LAYER_TRANSLUCENT = "translucent"
BlockRegistry.LAYER_LIQUID = "liquid"
BlockRegistry.LAYER_CROSS = "cross"
BlockRegistry.LAYER_ITEM = "item"

-- ============================================
-- 方块 ID 常量 (保持向后兼容)
-- ============================================
BlockRegistry.AIR = 0
BlockRegistry.GRASS = 1
BlockRegistry.DIRT = 2
BlockRegistry.STONE = 3
BlockRegistry.WOOD = 4
BlockRegistry.LEAVES = 5
BlockRegistry.SAND = 6
BlockRegistry.WATER = 7
BlockRegistry.TALL_GRASS = 8  -- 装饰草
BlockRegistry.TORCH = 9       -- 火把（手持物品，有光源）
BlockRegistry.ROSE = 10
BlockRegistry.FLOWER_YELLOW = 11
BlockRegistry.FLOWER_BLUE = 12

-- 石制 / 建材
BlockRegistry.COBBLESTONE = 13
BlockRegistry.MOSSY_COBBLESTONE = 14
BlockRegistry.STONE_BRICKS = 15
BlockRegistry.SANDSTONE = 16
BlockRegistry.OBSIDIAN = 17
BlockRegistry.BEDROCK = 18
BlockRegistry.PLANKS = 19
BlockRegistry.BRICKS = 20
BlockRegistry.BOOKSHELF = 21
BlockRegistry.CRAFTING_TABLE = 22
BlockRegistry.FURNACE = 23

-- 矿石 / 发光
BlockRegistry.COAL_ORE = 24
BlockRegistry.IRON_ORE = 25
BlockRegistry.GOLD_ORE = 26
BlockRegistry.DIAMOND_ORE = 27
BlockRegistry.REDSTONE_ORE = 28
BlockRegistry.LAPIS_ORE = 29
BlockRegistry.GLOWSTONE = 30

-- 自然
BlockRegistry.GRAVEL = 31
BlockRegistry.CLAY = 32
BlockRegistry.SNOW_BLOCK = 33
BlockRegistry.SNOWY_GRASS = 34
BlockRegistry.ICE = 35
BlockRegistry.LAVA = 36
BlockRegistry.CACTUS = 37

-- 透明
BlockRegistry.GLASS = 38

-- 羊毛
BlockRegistry.WOOL_WHITE = 39
BlockRegistry.WOOL_RED = 40
BlockRegistry.WOOL_YELLOW = 41
BlockRegistry.WOOL_GREEN = 42
BlockRegistry.WOOL_BLUE = 43
BlockRegistry.WOOL_BLACK = 44

-- 植物（交叉网格）
BlockRegistry.SAPLING = 45
BlockRegistry.DEAD_BUSH = 46
BlockRegistry.MUSHROOM_RED = 47
BlockRegistry.MUSHROOM_BROWN = 48

-- ============================================
-- 方块注册方法
-- ============================================

---@param id number 方块 ID
---@param name string 方块内部名称
---@param config table 方块配置
---@return table block 注册的方块数据
function BlockRegistry:register(id, name, config)
    local solid = config.solid ~= false          -- 默认 true
    local crossMesh = config.crossMesh or false
    local liquid = config.liquid or false
    local isItem = config.isItem or false

    -- occludes：是否遮挡邻居的面（决定面剔除与顶点 AO）
    -- ⚠️ 不能从 transparent 推导：leaves 的 transparent=true 是给光照用的（透光），
    --    若据此判定"不遮挡"，树冠内部所有面都会发射 → 顶点数爆炸。
    --    默认规则 = 实心且非交叉网格非液体；玻璃/冰要显式传 false。
    local shape = config.shape          -- 非 nil = 非整格方块（见 data/BlockShapes.lua）
    local occludes = config.occludes
    if occludes == nil then
        -- 非整格方块填不满格子，绝不能遮挡邻面（否则邻居的面被剔掉 → 看穿地形）
        occludes = solid and not crossMesh and not liquid and not shape
    end

    -- layer：渲染层，未显式给出时按老字段推导（保持旧方块行为不变）
    local layer = config.layer
    if not layer then
        if isItem then
            layer = BlockRegistry.LAYER_ITEM
        elseif shape then
            layer = BlockRegistry.LAYER_SHAPE
        elseif crossMesh then
            layer = BlockRegistry.LAYER_CROSS
        elseif liquid then
            layer = BlockRegistry.LAYER_LIQUID
        else
            layer = BlockRegistry.LAYER_SOLID
        end
    end

    -- selfCull：同类方块相邻时互相剔除内部面（玻璃/冰/液体成片时省顶点）
    local selfCull = config.selfCull
    if selfCull == nil then
        selfCull = liquid
    end

    local block = {
        id = id,
        name = name,
        displayName = config.displayName or name,
        color = config.color or Color(0.5, 0.5, 0.5),
        textures = config.textures or { top = T.dirt, side = T.dirt, bottom = T.dirt },
        solid = solid,
        transparent = config.transparent or false,
        liquid = liquid,
        crossMesh = crossMesh,                  -- 使用交叉网格渲染（X形插片）
        isItem = isItem,                        -- 是否为手持物品（不是方块）
        hasLight = config.hasLight or false,    -- 是否有光源
        lightColor = config.lightColor,         -- 光源颜色
        lightRadius = config.lightRadius or 5,  -- 光源范围（同时用作 blockLight 光级 0-15）
        occludes = occludes,                    -- 是否遮挡邻面
        selfCull = selfCull,                    -- 同类相邻是否互相剔除
        layer = layer,                          -- 渲染层
        unbreakable = config.unbreakable or false, -- 是否不可破坏（基岩）
        shape = shape,                          -- 非整格形状类型（BlockShapes.SLAB 等）
        upperTexture = config.upperTexture,     -- 门的上半格贴图
        interactive = config.interactive or false, -- 右键"使用"（门/活板门开关）
        doubleHeight = config.doubleHeight or false, -- 占上下两格（门）
    }

    self.blocks[id] = block
    self.byName[name] = block
    return block
end

---@param id number 方块 ID
---@return table|nil block 方块数据
function BlockRegistry:get(id)
    return self.blocks[id]
end

---@param name string 方块名称
---@return table|nil block 方块数据
function BlockRegistry:getByName(name)
    return self.byName[name]
end

---@param id number 方块 ID
---@return boolean 是否为实心方块
function BlockRegistry:isSolid(id)
    local block = self.blocks[id]
    return block and block.solid
end

---@param id number 方块 ID
---@return boolean 是否为透明方块（光照传播用）
function BlockRegistry:isTransparent(id)
    local block = self.blocks[id]
    return not block or block.transparent
end

---@param id number 方块 ID
---@return boolean 是否为液体
function BlockRegistry:isLiquid(id)
    local block = self.blocks[id]
    return block and block.liquid
end

---@param id number 方块 ID
---@return boolean 是否使用交叉网格渲染
function BlockRegistry:isCrossMesh(id)
    local block = self.blocks[id]
    return block and block.crossMesh
end

---@param id number 方块 ID
---@return boolean 是否为手持物品
function BlockRegistry:isItem(id)
    local block = self.blocks[id]
    return block and block.isItem
end

---@param id number 方块 ID
---@return boolean 是否有光源
function BlockRegistry:hasLight(id)
    local block = self.blocks[id]
    return block and block.hasLight
end

---@param id number 方块 ID
---@return boolean 是否遮挡邻面（不遮挡则邻居的面要照常渲染）
function BlockRegistry:isOccluding(id)
    local block = self.blocks[id]
    return block and block.occludes
end

---@param id number 方块 ID
---@return boolean 同类相邻时是否互相剔除内部面
function BlockRegistry:isSelfCulling(id)
    local block = self.blocks[id]
    return block and block.selfCull
end

---@param id number 方块 ID
---@return string 渲染层
function BlockRegistry:getLayer(id)
    local block = self.blocks[id]
    return block and block.layer or BlockRegistry.LAYER_SOLID
end

---@param id number 方块 ID
---@return string|nil 非整格形状类型（nil = 整格方块）
function BlockRegistry:getShape(id)
    local block = self.blocks[id]
    return block and block.shape
end

---@param id number 方块 ID
---@return boolean 右键是否"使用"（门/活板门开关）而不是放置方块
function BlockRegistry:isInteractive(id)
    local block = self.blocks[id]
    return block and block.interactive
end

---@param id number 方块 ID
---@return boolean 是否占上下两格（门）
function BlockRegistry:isDoubleHeight(id)
    local block = self.blocks[id]
    return block and block.doubleHeight
end

---@param id number 方块 ID
---@return boolean 是否不可破坏
function BlockRegistry:isUnbreakable(id)
    local block = self.blocks[id]
    return block and block.unbreakable
end

---@param id number 方块 ID
---@return Color 方块颜色
function BlockRegistry:getColor(id)
    local block = self.blocks[id]
    return block and block.color or Color(0.5, 0.5, 0.5)
end

---@param id number 方块 ID
---@return string 方块显示名称
function BlockRegistry:getDisplayName(id)
    local block = self.blocks[id]
    return block and block.displayName or "Unknown"
end

---@return table 所有可放置的方块类型列表
function BlockRegistry:getPlaceableBlocks()
    local list = {}
    for id, block in pairs(self.blocks) do
        if id ~= BlockRegistry.AIR and id ~= BlockRegistry.WATER then
            table.insert(list, id)
        end
    end
    table.sort(list)
    return list
end

-- ============================================
-- 注册内置方块
-- ============================================

BlockRegistry:register(0, "air", {
    displayName = "Air",
    solid = false,
    transparent = true
})

BlockRegistry:register(1, "grass", {
    displayName = "Grass",
    color = Color(0.3, 0.8, 0.3),
    textures = { top = T.grass_top, side = T.grass_side, bottom = T.dirt }
})

BlockRegistry:register(2, "dirt", {
    displayName = "Dirt",
    color = Color(0.6, 0.4, 0.2),
    textures = { top = T.dirt, side = T.dirt, bottom = T.dirt }
})

BlockRegistry:register(3, "stone", {
    displayName = "Stone",
    color = Color(0.5, 0.5, 0.5),
    textures = { top = T.stone, side = T.stone, bottom = T.stone }
})

BlockRegistry:register(4, "wood", {
    displayName = "Wood",
    color = Color(0.5, 0.3, 0.1),
    textures = { top = T.wood_top, side = T.wood_side, bottom = T.wood_top }
})

BlockRegistry:register(5, "leaves", {
    displayName = "Leaves",
    color = Color(0.2, 0.6, 0.2),
    textures = { top = T.leaves, side = T.leaves, bottom = T.leaves },
    transparent = true  -- 树叶透光（但仍遮挡邻面，等价原版 Fast 图形）
})

BlockRegistry:register(6, "sand", {
    displayName = "Sand",
    color = Color(0.9, 0.85, 0.6),
    textures = { top = T.sand, side = T.sand, bottom = T.sand }
})

BlockRegistry:register(7, "water", {
    displayName = "Water",
    color = Color(0.2, 0.65, 1.0),
    textures = { top = T.water, side = T.water, bottom = T.water },
    solid = false,
    transparent = true,
    liquid = true
})

BlockRegistry:register(8, "tall_grass", {
    displayName = "Tall Grass",
    color = Color(0.4, 0.8, 0.3),
    textures = { top = T.tall_grass, side = T.tall_grass, bottom = T.tall_grass },
    solid = false,
    transparent = true,
    crossMesh = true  -- 使用交叉网格渲染（X形）
})

BlockRegistry:register(9, "torch", {
    displayName = "Torch",
    color = Color(0.9, 0.7, 0.3),  -- 火把木棍颜色
    textures = { top = T.torch, side = T.torch, bottom = T.torch },
    solid = false,
    transparent = true,
    isItem = true,                 -- 这是一个手持物品，不是方块（由 TorchDecorator 建节点）
    hasLight = true,               -- 有光源效果
    lightColor = Color(1.0, 0.8, 0.4),  -- 暖黄色火光
    lightRadius = 8,               -- 光照范围
})

BlockRegistry:register(10, "rose", {
    displayName = "Rose",
    color = Color(0.8, 0.2, 0.2),
    textures = { top = T.rose, side = T.rose, bottom = T.rose },
    solid = false,
    transparent = true,
    crossMesh = true
})

BlockRegistry:register(11, "flower_yellow", {
    displayName = "Yellow Flower",
    color = Color(0.9, 0.9, 0.2),
    textures = { top = T.flower_yellow, side = T.flower_yellow, bottom = T.flower_yellow },
    solid = false,
    transparent = true,
    crossMesh = true
})

BlockRegistry:register(12, "flower_blue", {
    displayName = "Blue Flower",
    color = Color(0.2, 0.2, 0.9),
    textures = { top = T.flower_blue, side = T.flower_blue, bottom = T.flower_blue },
    solid = false,
    transparent = true,
    crossMesh = true
})

-- ============================================
-- 石制 / 建材
-- ============================================

BlockRegistry:register(13, "cobblestone", {
    displayName = "Cobblestone",
    color = Color(0.45, 0.45, 0.45),
    textures = { top = T.cobblestone, side = T.cobblestone, bottom = T.cobblestone }
})

BlockRegistry:register(14, "mossy_cobblestone", {
    displayName = "Mossy Cobblestone",
    color = Color(0.38, 0.48, 0.35),
    textures = { top = T.mossy_cobblestone, side = T.mossy_cobblestone, bottom = T.mossy_cobblestone }
})

BlockRegistry:register(15, "stone_bricks", {
    displayName = "Stone Bricks",
    color = Color(0.52, 0.52, 0.52),
    textures = { top = T.stone_bricks, side = T.stone_bricks, bottom = T.stone_bricks }
})

BlockRegistry:register(16, "sandstone", {
    displayName = "Sandstone",
    color = Color(0.85, 0.78, 0.55),
    textures = { top = T.sandstone_top, side = T.sandstone_side, bottom = T.sandstone_bottom }
})

BlockRegistry:register(17, "obsidian", {
    displayName = "Obsidian",
    color = Color(0.12, 0.10, 0.18),
    textures = { top = T.obsidian, side = T.obsidian, bottom = T.obsidian }
})

BlockRegistry:register(18, "bedrock", {
    displayName = "Bedrock",
    color = Color(0.28, 0.28, 0.30),
    textures = { top = T.bedrock, side = T.bedrock, bottom = T.bedrock },
    unbreakable = true  -- 世界地板，挖不动
})

BlockRegistry:register(19, "planks", {
    displayName = "Wood Planks",
    color = Color(0.72, 0.57, 0.35),
    textures = { top = T.planks, side = T.planks, bottom = T.planks }
})

BlockRegistry:register(20, "bricks", {
    displayName = "Bricks",
    color = Color(0.66, 0.34, 0.28),
    textures = { top = T.bricks, side = T.bricks, bottom = T.bricks }
})

BlockRegistry:register(21, "bookshelf", {
    displayName = "Bookshelf",
    color = Color(0.60, 0.45, 0.28),
    textures = { top = T.planks, side = T.bookshelf_side, bottom = T.planks }
})

BlockRegistry:register(22, "crafting_table", {
    displayName = "Crafting Table",
    color = Color(0.62, 0.45, 0.28),
    textures = { top = T.crafting_top, side = T.crafting_side, bottom = T.planks }
})

BlockRegistry:register(23, "furnace", {
    displayName = "Furnace",
    color = Color(0.42, 0.42, 0.44),
    textures = { top = T.furnace_top, side = T.furnace_side, bottom = T.furnace_top }
})

-- ============================================
-- 矿石 / 发光
-- ============================================

BlockRegistry:register(24, "coal_ore", {
    displayName = "Coal Ore",
    color = Color(0.22, 0.22, 0.22),
    textures = { top = T.coal_ore, side = T.coal_ore, bottom = T.coal_ore }
})

BlockRegistry:register(25, "iron_ore", {
    displayName = "Iron Ore",
    color = Color(0.78, 0.65, 0.55),
    textures = { top = T.iron_ore, side = T.iron_ore, bottom = T.iron_ore }
})

BlockRegistry:register(26, "gold_ore", {
    displayName = "Gold Ore",
    color = Color(0.95, 0.80, 0.30),
    textures = { top = T.gold_ore, side = T.gold_ore, bottom = T.gold_ore }
})

BlockRegistry:register(27, "diamond_ore", {
    displayName = "Diamond Ore",
    color = Color(0.40, 0.90, 0.92),
    textures = { top = T.diamond_ore, side = T.diamond_ore, bottom = T.diamond_ore }
})

BlockRegistry:register(28, "redstone_ore", {
    displayName = "Redstone Ore",
    color = Color(0.85, 0.15, 0.12),
    textures = { top = T.redstone_ore, side = T.redstone_ore, bottom = T.redstone_ore }
})

BlockRegistry:register(29, "lapis_ore", {
    displayName = "Lapis Ore",
    color = Color(0.18, 0.32, 0.78),
    textures = { top = T.lapis_ore, side = T.lapis_ore, bottom = T.lapis_ore }
})

BlockRegistry:register(30, "glowstone", {
    displayName = "Glowstone",
    color = Color(1.0, 0.88, 0.55),
    textures = { top = T.glowstone, side = T.glowstone, bottom = T.glowstone },
    hasLight = true,
    lightColor = Color(1.0, 0.92, 0.70),
    lightRadius = 15,  -- 满级方块光
})

-- ============================================
-- 自然
-- ============================================

BlockRegistry:register(31, "gravel", {
    displayName = "Gravel",
    color = Color(0.55, 0.53, 0.52),
    textures = { top = T.gravel, side = T.gravel, bottom = T.gravel }
})

BlockRegistry:register(32, "clay", {
    displayName = "Clay",
    color = Color(0.63, 0.65, 0.70),
    textures = { top = T.clay, side = T.clay, bottom = T.clay }
})

BlockRegistry:register(33, "snow_block", {
    displayName = "Snow Block",
    color = Color(0.95, 0.96, 0.98),
    textures = { top = T.snow, side = T.snow, bottom = T.snow }
})

BlockRegistry:register(34, "snowy_grass", {
    displayName = "Snowy Grass",
    color = Color(0.88, 0.92, 0.95),
    textures = { top = T.snow, side = T.grass_snow_side, bottom = T.dirt }
})

BlockRegistry:register(35, "ice", {
    displayName = "Ice",
    color = Color(0.62, 0.82, 0.98),
    textures = { top = T.ice, side = T.ice, bottom = T.ice },
    transparent = true,   -- 透光
    occludes = false,     -- 不遮挡邻面（否则冰后面的方块会被剔出空洞）
    selfCull = true,      -- 成片冰不画内部面
    layer = BlockRegistry.LAYER_TRANSLUCENT,
})

BlockRegistry:register(36, "lava", {
    displayName = "Lava",
    color = Color(1.0, 0.42, 0.10),
    textures = { top = T.lava, side = T.lava, bottom = T.lava },
    solid = false,
    liquid = true,
    transparent = false,  -- 不透光（挡天光）
    hasLight = true,
    lightColor = Color(1.0, 0.55, 0.20),
    lightRadius = 15,
})

BlockRegistry:register(37, "cactus", {
    displayName = "Cactus",
    color = Color(0.24, 0.55, 0.22),
    textures = { top = T.cactus_top, side = T.cactus_side, bottom = T.cactus_bottom }
})

-- ============================================
-- 透明
-- ============================================

BlockRegistry:register(38, "glass", {
    displayName = "Glass",
    color = Color(0.85, 0.94, 0.97),
    textures = { top = T.glass, side = T.glass, bottom = T.glass },
    transparent = true,   -- 透光
    occludes = false,     -- 不遮挡邻面
    selfCull = true,      -- 成片玻璃不画内部面
    layer = BlockRegistry.LAYER_CUTOUT,
})

-- ============================================
-- 羊毛（同一生成器换底色）
-- ============================================

local WOOL_DEFS = {
    { id = 39, name = "wool_white",  display = "White Wool",  tile = "wool_white",  color = Color(0.93, 0.93, 0.93) },
    { id = 40, name = "wool_red",    display = "Red Wool",    tile = "wool_red",    color = Color(0.72, 0.20, 0.18) },
    { id = 41, name = "wool_yellow", display = "Yellow Wool", tile = "wool_yellow", color = Color(0.90, 0.80, 0.24) },
    { id = 42, name = "wool_green",  display = "Green Wool",  tile = "wool_green",  color = Color(0.32, 0.60, 0.24) },
    { id = 43, name = "wool_blue",   display = "Blue Wool",   tile = "wool_blue",   color = Color(0.24, 0.32, 0.70) },
    { id = 44, name = "wool_black",  display = "Black Wool",  tile = "wool_black",  color = Color(0.13, 0.13, 0.14) },
}

for _, def in ipairs(WOOL_DEFS) do
    local tile = T[def.tile]
    BlockRegistry:register(def.id, def.name, {
        displayName = def.display,
        color = def.color,
        textures = { top = tile, side = tile, bottom = tile }
    })
end

-- ============================================
-- 植物（交叉网格）
-- ============================================

local PLANT_DEFS = {
    { id = 45, name = "sapling",        display = "Sapling",        tile = "sapling",        color = Color(0.30, 0.62, 0.22) },
    { id = 46, name = "dead_bush",      display = "Dead Bush",      tile = "dead_bush",      color = Color(0.58, 0.42, 0.20) },
    { id = 47, name = "mushroom_red",   display = "Red Mushroom",   tile = "mushroom_red",   color = Color(0.82, 0.22, 0.20) },
    { id = 48, name = "mushroom_brown", display = "Brown Mushroom", tile = "mushroom_brown", color = Color(0.62, 0.48, 0.36) },
}

for _, def in ipairs(PLANT_DEFS) do
    local tile = T[def.tile]
    BlockRegistry:register(def.id, def.name, {
        displayName = def.display,
        color = def.color,
        textures = { top = tile, side = tile, bottom = tile },
        solid = false,
        transparent = true,
        crossMesh = true
    })
end

-- ============================================
-- 非整格建筑件（半砖 / 楼梯 / 栅栏 / 门 / 活板门）
--
-- 形状由 data/BlockShapes.lua 描述（网格、碰撞、落地高度共用同一份盒子数据），
-- 朝向 / 上下半 / 开关存在 World 的 blockState 平行数组里（data/BlockState.lua）。
--
-- ⚠️ 非整格方块**全部 transparent = true**（透光）。它们只占半格，若被当成挡天光，
--    自己那一格的 skyLight 就是 0，而**紧挨它的整格方块**朝它的那个面在烘焙时取的
--    正是"面外一格"的光值 → shade 掉到 MIN_AMBIENT，那个面会漆黑一片。
--    代价：半砖屋顶不会给下方遮阴（本 demo 的天光只是垂直灌注，本来就很粗糙）。
--    断言 T6.5 盯着这条，别改回 false。
-- ============================================

local Shapes = require("data.BlockShapes")

-- 半砖与楼梯共用的 6 种材质（顺序即 id 顺序）
local BUILD_MATERIALS = {
    { key = "stone", display = "Stone", tile = "stone", color = Color(0.50, 0.50, 0.50) },
    { key = "cobblestone", display = "Cobblestone", tile = "cobblestone", color = Color(0.45, 0.45, 0.45) },
    { key = "sandstone", display = "Sandstone", tile = "sandstone_side", color = Color(0.85, 0.78, 0.55) },
    { key = "bricks", display = "Brick", tile = "bricks", color = Color(0.66, 0.34, 0.28) },
    { key = "stone_bricks", display = "Stone Brick", tile = "stone_bricks", color = Color(0.52, 0.52, 0.52) },
    { key = "planks", display = "Wood", tile = "planks", color = Color(0.72, 0.57, 0.35) },
}

-- 半砖 49-54
BlockRegistry.SLAB_STONE = 49
for i, mat in ipairs(BUILD_MATERIALS) do
    local id = 48 + i
    local tile = T[mat.tile]
    BlockRegistry["SLAB_" .. string.upper(mat.key)] = id
    BlockRegistry:register(id, "slab_" .. mat.key, {
        displayName = mat.display .. " Slab",
        color = mat.color,
        textures = { top = tile, side = tile, bottom = tile },
        shape = Shapes.SLAB,
        transparent = true,   -- 见上方说明：非整格方块不能吃掉天光列
    })
end

-- 楼梯 55-60
for i, mat in ipairs(BUILD_MATERIALS) do
    local id = 54 + i
    local tile = T[mat.tile]
    BlockRegistry["STAIRS_" .. string.upper(mat.key)] = id
    BlockRegistry:register(id, "stairs_" .. mat.key, {
        displayName = mat.display .. " Stairs",
        color = mat.color,
        textures = { top = tile, side = tile, bottom = tile },
        shape = Shapes.STAIRS,
        transparent = true,   -- 见上方说明：非整格方块不能吃掉天光列
    })
end

-- 栅栏 61-62（透光；碰撞挡人但看得穿）
BlockRegistry.FENCE_WOOD = 61
BlockRegistry:register(61, "fence_wood", {
    displayName = "Wood Fence",
    color = Color(0.66, 0.50, 0.30),
    textures = { top = T.planks, side = T.planks, bottom = T.planks },
    shape = Shapes.FENCE,
    transparent = true,
})

-- 圆石墙（不是"石栅栏"）：石质材料上 4/16 的细柱只取到 tile 的一小片，
-- 圆石那种高对比纹理会糊成黑白噪点；8/16 的墙体既是原版做法，纹理也读得出来
BlockRegistry.WALL_COBBLESTONE = 62
BlockRegistry:register(62, "wall_cobblestone", {
    displayName = "Cobblestone Wall",
    color = Color(0.46, 0.46, 0.47),
    textures = { top = T.cobblestone, side = T.cobblestone, bottom = T.cobblestone },
    shape = Shapes.WALL,
    transparent = true,
})

-- 门 63-64（双格高，右键开关）
BlockRegistry.DOOR_WOOD = 63
BlockRegistry:register(63, "door_wood", {
    displayName = "Wood Door",
    color = Color(0.62, 0.45, 0.26),
    textures = { top = T.door_wood_lower, side = T.door_wood_lower, bottom = T.door_wood_lower },
    upperTexture = T.door_wood_upper,
    shape = Shapes.DOOR,
    transparent = true,
    interactive = true,
    doubleHeight = true,
})

BlockRegistry.DOOR_IRON = 64
BlockRegistry:register(64, "door_iron", {
    displayName = "Iron Door",
    color = Color(0.72, 0.73, 0.75),
    textures = { top = T.door_iron_lower, side = T.door_iron_lower, bottom = T.door_iron_lower },
    upperTexture = T.door_iron_upper,
    shape = Shapes.DOOR,
    transparent = true,
    interactive = true,
    doubleHeight = true,
})

-- 活板门 65（右键开关）
BlockRegistry.TRAPDOOR_WOOD = 65
BlockRegistry:register(65, "trapdoor_wood", {
    displayName = "Trapdoor",
    color = Color(0.60, 0.44, 0.24),
    textures = { top = T.trapdoor_wood, side = T.trapdoor_wood, bottom = T.trapdoor_wood },
    shape = Shapes.TRAPDOOR,
    transparent = true,
    interactive = true,
})

-- ============================================
-- 新增方块示例（只需一行注册！）
-- ============================================
-- 1. 在 rendering/texturepacks/AtlasLayout.lua 的 ROWS 里加一个 tile 名字
-- 2. 在 ClassicPack / HDPack 的 tileGenerators 里为该名字写生成器
-- 3. 在这里 register：
--
-- BlockRegistry.MY_BLOCK = 49
-- BlockRegistry:register(49, "my_block", {
--     displayName = "My Block",
--     color = Color(0.2, 0.8, 0.9),
--     textures = { top = T.my_block, side = T.my_block, bottom = T.my_block }
-- })
--
-- 4. 想让它出现在物品栏，加进 data/BlockPalette.lua 的某一页

return BlockRegistry
