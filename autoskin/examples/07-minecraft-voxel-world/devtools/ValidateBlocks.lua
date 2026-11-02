-- ====================================================================
-- devtools/ValidateBlocks.lua
-- 方块系统断言测试（Phase 3 Lua 断言，配合 -validate-test 使用）
--
-- 覆盖那些"只写了代码、手点很难验"的运行时路径：
--   T1 注册表 / 调色板一致性（tile 坐标、渲染层字段、分页无重复）
--   T2 天光：玻璃透光、石头与岩浆挡光
--   T3 方块光：运行时放置发光方块照亮一圈、破坏后熄灭
--   T4 地质：矿脉深度分带、只替换石头不吃其它方块
--   T5 渲染层：各层几何体按需创建、空层被移除
--
-- 用法：
--   UrhoXRuntime.exe main.lua -tapcode_dir=<Minecraft 目录> -skip_login \
--       -graphicsheadless -validate -validate-frames=400 \
--       -validate-test=devtools/ValidateBlocks.lua
--
-- 测试自建 World 实例、并把网格建到远离出生点的区块，不依赖游戏暴露全局、
-- 也不会干扰正在跑的世界。
-- ====================================================================

-- V 是 -validate-test 加载的 Validate/validate_helpers.lua 注册的全局断言表，.emmylua 里没有它的声明
---@diagnostic disable: undefined-global

local Config = require("config.GameConfig")
local Blocks = require("data.BlockRegistry")
local BlockState = require("data.BlockState")
local BlockShapes = require("data.BlockShapes")
local Palette = require("data.BlockPalette")
local Atlas = require("rendering.texturepacks.AtlasLayout")
local World = require("world.World")
local WorldGenerator = require("world.WorldGenerator")
local ChunkMeshBuilder = require("world.ChunkMeshBuilder")
local TexturePackManager = require("rendering.texturepacks.TexturePackManager")

-- 远离出生点的测试区块（避免与游戏世界互相干扰）
local TEST_CX, TEST_CZ = 100, 100
local TEST_X, TEST_Z = TEST_CX * 16, TEST_CZ * 16

local VALID_LAYERS = {
    [Blocks.LAYER_SOLID] = true,
    [Blocks.LAYER_SHAPE] = true,
    [Blocks.LAYER_CUTOUT] = true,
    [Blocks.LAYER_TRANSLUCENT] = true,
    [Blocks.LAYER_LIQUID] = true,
    [Blocks.LAYER_CROSS] = true,
    [Blocks.LAYER_ITEM] = true,
}

-- ====================================================================
-- T1 注册表 / 调色板一致性
-- ====================================================================
local function testRegistry()
    local count = 0
    for id, block in pairs(Blocks.blocks) do
        if id ~= Blocks.AIR then count = count + 1 end

        -- 每个面的 tile 坐标都必须落在 AtlasLayout 声明过的格子里
        for _, face in ipairs({ "top", "side", "bottom" }) do
            local pos = block.textures and block.textures[face]
            if V.assert(type(pos) == "table" and #pos == 2,
                string.format("T1 %s.%s 缺少 tile 坐标", block.name, face)) then
                V.assert(Atlas.isUsed(pos[1], pos[2]),
                    string.format("T1 %s.%s 的 tile (%d,%d) 不在 AtlasLayout 中",
                        block.name, face, pos[1], pos[2]))
            end
        end

        V.assert(VALID_LAYERS[block.layer] == true,
            string.format("T1 %s 的 layer 非法: %s", block.name, tostring(block.layer)))
    end
    V.assert(count == 65, "T1 可用方块数应为 65，实际 " .. count)

    -- 非整格方块（半砖/楼梯/栅栏/门/活板门）绝不能遮挡邻面，否则邻居的面被剔掉→看穿地形
    for id, block in pairs(Blocks.blocks) do
        if block.shape then
            V.assert(block.occludes == false,
                "T1 " .. block.name .. " 是非整格方块，occludes 必须为 false")
            V.assert(block.layer == Blocks.LAYER_SHAPE,
                "T1 " .. block.name .. " 的 layer 应为 shape")
        end
    end

    -- 透明方块必须显式不遮挡 + 自剔除，否则后面的方块会被剔成空洞
    for _, name in ipairs({ "glass", "ice" }) do
        local b = Blocks:getByName(name)
        V.assert(b ~= nil, "T1 缺少方块 " .. name)
        if b then
            V.assert(b.transparent == true, "T1 " .. name .. " 应透光")
            V.assert(b.occludes == false, "T1 " .. name .. " 不应遮挡邻面")
            V.assert(b.selfCull == true, "T1 " .. name .. " 应同类自剔除")
        end
    end

    -- 树叶透光但**必须**继续遮挡邻面（否则树冠内部所有面都发射，顶点数爆炸）
    local leaves = Blocks:getByName("leaves")
    V.assert(leaves.transparent == true and leaves.occludes == true,
        "T1 leaves 应 transparent=true 且 occludes=true")

    -- 光源与不可破坏
    V.assert(Blocks:isUnbreakable(Blocks.BEDROCK) == true, "T1 基岩应不可破坏")
    V.assert(Blocks:isUnbreakable(Blocks.STONE) == false, "T1 石头应可破坏")
    for _, id in ipairs({ Blocks.GLOWSTONE, Blocks.LAVA }) do
        local b = Blocks:get(id)
        V.assert(b.hasLight == true, "T1 " .. b.name .. " 应有光源")
        V.assert(b.lightRadius == 15, "T1 " .. b.name .. " 光级应为 15")
    end
    -- 岩浆挡天光（不透光），水透光
    V.assert(Blocks:get(Blocks.LAVA).transparent == false, "T1 岩浆应挡天光")
    V.assert(Blocks:get(Blocks.WATER).transparent == true, "T1 水应透光")

    -- 调色板：页容量、方块已注册、跨页不重复
    local seen = {}
    local total = 0
    for p = 1, Palette:pageCount() do
        local page = Palette:getPage(p)
        V.assert(#page.blocks <= Palette.MAX_SLOTS,
            string.format("T1 第 %d 页有 %d 格，超过上限 %d", p, #page.blocks, Palette.MAX_SLOTS))
        for _, id in ipairs(page.blocks) do
            V.assert(Blocks:get(id) ~= nil,
                string.format("T1 第 %d 页的方块 id %d 未注册", p, id))
            V.assert(seen[id] == nil,
                string.format("T1 方块 id %d 在多页重复出现", id))
            seen[id] = true
            total = total + 1
        end
    end
    V.assert(Palette:pageCount() == 8, "T1 调色板应有 8 页")
    V.assert(total >= 60, "T1 调色板收录方块数偏少: " .. total)
end

-- ====================================================================
-- T2 天光：玻璃透光、石头/岩浆挡光
-- ====================================================================
local function testSkyLight()
    local w = World.new()
    local roofY = 20
    local cases = {
        { name = "glass", block = Blocks.GLASS, expect = 15 },
        { name = "stone", block = Blocks.STONE, expect = 0 },
        { name = "lava", block = Blocks.LAVA, expect = 0 },
    }

    for i, case in ipairs(cases) do
        local x = TEST_X + i
        w:setBlockRaw(x, roofY, TEST_Z, case.block)
    end
    w:propagateSkyLight()

    for i, case in ipairs(cases) do
        local x = TEST_X + i
        -- 屋顶正下方一格
        local below = w:getSkyLight(x, roofY - 1, TEST_Z)
        V.assert(below == case.expect,
            string.format("T2 %s 屋顶下方天光应为 %d，实际 %d", case.name, case.expect, below))
        -- 屋顶上方永远见天
        V.assert(w:getSkyLight(x, roofY + 1, TEST_Z) == 15,
            "T2 " .. case.name .. " 屋顶上方应见天")
    end
end

-- ====================================================================
-- T3 方块光：运行时放置 / 破坏发光方块
-- ====================================================================
local function testBlockLight()
    local w = World.new()
    local x, y, z = TEST_X + 8, 30, TEST_Z + 8

    -- setBlock（不是 setBlockRaw）才会触发增量光照
    w:setBlock(x, y, z, Blocks.GLOWSTONE)

    V.assert(w:getBlockLight(x + 1, y, z) == 14,
        "T3 荧石相邻格光值应为 14，实际 " .. w:getBlockLight(x + 1, y, z))
    V.assert(w:getBlockLight(x + 5, y, z) == 10,
        "T3 荧石 5 格外光值应为 10，实际 " .. w:getBlockLight(x + 5, y, z))
    V.assert(w:getBlockLight(x, y + 3, z) == 12,
        "T3 荧石上方 3 格光值应为 12，实际 " .. w:getBlockLight(x, y + 3, z))
    V.assert(w:getBlockLight(x + 15, y, z) == 0,
        "T3 荧石 15 格外应无光，实际 " .. w:getBlockLight(x + 15, y, z))

    -- 破坏光源 → 整片光应熄灭
    w:setBlock(x, y, z, Blocks.AIR)
    V.assert(w:getBlockLight(x + 1, y, z) == 0,
        "T3 破坏荧石后相邻格应熄灭，实际 " .. w:getBlockLight(x + 1, y, z))
    V.assert(w:getBlockLight(x + 5, y, z) == 0,
        "T3 破坏荧石后 5 格外应熄灭，实际 " .. w:getBlockLight(x + 5, y, z))

    -- 岩浆同样是光源（世界生成期靠 seedBlockLights 补，这里验运行时放置这条路径）
    w:setBlock(x, y, z, Blocks.LAVA)
    V.assert(w:getBlockLight(x + 2, y, z) == 13,
        "T3 岩浆 2 格外光值应为 13，实际 " .. w:getBlockLight(x + 2, y, z))
end

-- ====================================================================
-- T4 地质特征：深度分带 + 只替换石头
-- ====================================================================
local function testGeology()
    if not (Config.Features and Config.Features.RICH_TERRAIN) then
        print("[ValidateBlocks] RICH_TERRAIN=false，跳过 T4")
        return
    end

    local w = World.new()
    local wg = WorldGenerator.new()
    local R = 16
    local TOP = 58
    local MARKER_Y = 30   -- 这一层铺泥土，用来验证矿脉不吃非石头方块

    for x = TEST_X - R, TEST_X + R do
        for z = TEST_Z - R, TEST_Z + R do
            for y = 1, TOP do
                w:setBlockRaw(x, y, z, (y == MARKER_Y) and Blocks.DIRT or Blocks.STONE)
            end
        end
    end

    wg:generateGeologicalFeatures(w, TEST_X, TEST_Z, R)

    -- 深度带（与 WorldGenerator.GEO_FEATURES 对齐）
    local bands = {
        [Blocks.COAL_ORE]     = { 6, 52, "coal" },
        [Blocks.IRON_ORE]     = { 4, 40, "iron" },
        [Blocks.GOLD_ORE]     = { 2, 22, "gold" },
        [Blocks.LAPIS_ORE]    = { 2, 26, "lapis" },
        [Blocks.REDSTONE_ORE] = { 2, 14, "redstone" },
        [Blocks.DIAMOND_ORE]  = { 1, 13, "diamond" },
        [Blocks.GRAVEL]       = { 8, 56, "gravel" },
        [Blocks.LAVA]         = { 1, 8, "lava" },
    }

    local counts = {}
    local markerIntact = 0
    local markerBroken = 0

    for x = TEST_X - R, TEST_X + R do
        for z = TEST_Z - R, TEST_Z + R do
            for y = 1, TOP do
                local b = w:getBlock(x, y, z)
                local band = bands[b]
                if band then
                    counts[b] = (counts[b] or 0) + 1
                    if y < band[1] or y > band[2] then
                        V.fail(string.format("T4 %s 出现在深度带 [%d,%d] 之外: y=%d",
                            band[3], band[1], band[2], y))
                        return
                    end
                end
                if y == MARKER_Y then
                    if b == Blocks.DIRT then
                        markerIntact = markerIntact + 1
                    else
                        markerBroken = markerBroken + 1
                    end
                end
            end
        end
    end

    -- 深度带全部合法（上面任一越界都会 return，走到这里说明通过）
    V.assert(true, "T4 矿脉深度分带")

    V.assert(markerBroken == 0,
        string.format("T4 矿脉吃掉了 %d 个非石头方块（应只替换石头）", markerBroken))
    V.assert(markerIntact > 0, "T4 标记层没铺上，测试本身有问题")

    -- 常见矿必须有产出，否则说明投放概率或深度带写错了
    for _, id in ipairs({ Blocks.COAL_ORE, Blocks.IRON_ORE, Blocks.GRAVEL }) do
        V.assert((counts[id] or 0) > 0,
            "T4 " .. Blocks:get(id).name .. " 在测试区域内产出为 0")
    end

    local summary = {}
    for id, band in pairs(bands) do
        summary[#summary + 1] = string.format("%s=%d", band[3], counts[id] or 0)
    end
    table.sort(summary)
    print("[ValidateBlocks] T4 产出: " .. table.concat(summary, ", "))
end

-- ====================================================================
-- T5 渲染层几何体：按需创建 + 空层移除
-- ====================================================================
local function testRenderLayers()
    local scene = V.scene()
    if not V.assert(scene ~= nil, "T5 拿不到场景，跳过渲染层检查") then
        return
    end

    local w = World.new()
    local builder = ChunkMeshBuilder.new(w, scene)
    builder:setTextures(TexturePackManager:getCurrent():generate())

    -- 混合区块：各渲染层都有料
    local y = 20
    for lx = 0, 5 do
        w:setBlockRaw(TEST_X + lx, y - 1, TEST_Z, Blocks.STONE)
    end
    w:setBlockRaw(TEST_X + 0, y, TEST_Z, Blocks.STONE)
    w:setBlockRaw(TEST_X + 1, y, TEST_Z, Blocks.GLASS)
    w:setBlockRaw(TEST_X + 2, y, TEST_Z, Blocks.ICE)
    w:setBlockRaw(TEST_X + 3, y, TEST_Z, Blocks.WATER)
    w:setBlockRaw(TEST_X + 4, y, TEST_Z, Blocks.LAVA)
    w:setBlockRaw(TEST_X + 5, y, TEST_Z, Blocks.TALL_GRASS)

    -- 纯石头区块：用来验证空层的子节点会被移除
    local plainCX, plainCZ = TEST_CX + 1, TEST_CZ
    for lx = 0, 3 do
        w:setBlockRaw(plainCX * 16 + lx, y, TEST_Z, Blocks.STONE)
    end

    w:computeAllChunkHeightRanges()
    w:propagateSkyLight()
    builder:buildChunk(TEST_CX, TEST_CZ)
    builder:buildChunk(plainCX, plainCZ)

    local mixed = scene:GetChild("Chunk_" .. TEST_CX .. "," .. TEST_CZ, true)
    if V.assert(mixed ~= nil, "T5 混合区块节点未创建") then
        for _, layerNode in ipairs({ "Cutout", "Translucent", "CrossMesh", "Liquid_water", "Liquid_lava" }) do
            V.assert(mixed:GetChild(layerNode, false) ~= nil,
                "T5 缺少渲染层节点 " .. layerNode)
        end
    end

    local plain = scene:GetChild("Chunk_" .. plainCX .. "," .. plainCZ, true)
    if V.assert(plain ~= nil, "T5 纯石头区块节点未创建") then
        for _, layerNode in ipairs({ "Cutout", "Translucent", "CrossMesh", "Liquid_water", "Liquid_lava" }) do
            V.assert(plain:GetChild(layerNode, false) == nil,
                "T5 空渲染层 " .. layerNode .. " 应被移除（省 draw call）")
        end
    end

    -- 清掉测试节点，别把它们留在场景里影响 census
    if mixed then mixed:Remove() end
    if plain then plain:Remove() end
end

-- ====================================================================
-- T6 方块状态存取（M2 block-states）
-- ====================================================================
local function testBlockState()
    local w = World.new()
    local x, y, z = TEST_X + 20, 30, TEST_Z + 20

    -- 带状态放置 → 回读一致
    local st = BlockState.pack(BlockState.FACING_PZ, true, false)
    w:setBlock(x, y, z, Blocks.STAIRS_STONE, st)
    V.assert(w:getBlockState(x, y, z) == st,
        "T6 带状态放置后回读不一致: " .. w:getBlockState(x, y, z) .. " vs " .. st)
    V.assert(BlockState.facing(w:getBlockState(x, y, z)) == BlockState.FACING_PZ, "T6 朝向丢了")
    V.assert(BlockState.isTopHalf(w:getBlockState(x, y, z)) == true, "T6 topHalf 丢了")

    -- 不带状态放置 → 必须清掉上一任方块的状态（否则残留朝向）
    w:setBlock(x, y, z, Blocks.STONE)
    V.assert(w:getBlockState(x, y, z) == 0,
        "T6 换方块后状态应清零，实际 " .. w:getBlockState(x, y, z))

    -- 挖空同样清零
    w:setBlock(x, y, z, Blocks.SLAB_PLANKS, BlockState.pack(0, true, false))
    w:setBlock(x, y, z, Blocks.AIR)
    V.assert(w:getBlockState(x, y, z) == 0, "T6 挖空后状态应清零")

    -- 位域互不干扰
    local full = BlockState.pack(BlockState.FACING_NX, true, true)
    V.assert(BlockState.facing(full) == BlockState.FACING_NX, "T6 facing 位被污染")
    V.assert(BlockState.isTopHalf(full) and BlockState.isOpen(full), "T6 top/open 位被污染")
    V.assert(BlockState.isOpen(BlockState.toggleOpen(full)) == false, "T6 toggleOpen 没翻转")
    V.assert(BlockState.facing(BlockState.toggleOpen(full)) == BlockState.FACING_NX,
        "T6 toggleOpen 动到了 facing")
end

-- ====================================================================
-- T6.5 非整格方块不能吃掉天光列
--
-- 天光是"从顶向下灌，遇第一个不透明方块停"。如果半砖/楼梯这类只占半格的方块被
-- 当成不透明，它那一格的 skyLight 就是 0；而**紧挨它的整格方块**朝它的那个面，
-- 烘焙时取的正是"面外一格"的光值 → shade 掉到 MIN_AMBIENT，那个面直接变全黑。
-- 用户实测到的就是这个（半砖旁边的砖块侧面漆黑）。
-- ====================================================================
local function testPartialBlocksPassSkyLight()
    local w = World.new()
    local x, y, z = TEST_X + 50, 30, TEST_Z + 50

    for _, id in ipairs({ Blocks.SLAB_BRICKS, Blocks.STAIRS_BRICKS, Blocks.FENCE_WOOD,
                          Blocks.WALL_COBBLESTONE, Blocks.DOOR_WOOD, Blocks.TRAPDOOR_WOOD }) do
        local w2 = World.new()
        w2:setBlockRaw(x, y, z, id)
        w2:propagateSkyLight()
        local name = Blocks:get(id).name
        V.assert(w2:getSkyLight(x, y, z) == 15,
            string.format("T6.5 %s 吃掉了天光列（skyLight=%d）→ 紧挨它的方块侧面会烘焙成全黑",
                name, w2:getSkyLight(x, y, z)))
        V.assert(Blocks:get(id).transparent == true,
            "T6.5 " .. name .. " 是非整格方块，必须透光")
    end

    -- 对照：整格方块本来就该挡住天光
    w:setBlockRaw(x, y, z, Blocks.BRICKS)
    w:propagateSkyLight()
    V.assert(w:getSkyLight(x, y - 1, z) == 0, "T6.5 整格方块下方仍应无天光")
end

-- ====================================================================
-- T7 形状盒子
-- ====================================================================
local function boxesValid(boxes, label)
    if not V.assert(boxes ~= nil and #boxes > 0, "T7 " .. label .. " 没有盒子") then
        return false
    end
    for i, b in ipairs(boxes) do
        for k = 1, 3 do
            if not V.assert(b[k] >= 0 and b[k] <= 1 and b[k + 3] >= 0 and b[k + 3] <= 1,
                string.format("T7 %s 第 %d 个盒子越出格子: %.3f..%.3f", label, i, b[k], b[k + 3])) then
                return false
            end
            if not V.assert(b[k + 3] > b[k],
                string.format("T7 %s 第 %d 个盒子在轴 %d 上是空的", label, i, k)) then
                return false
            end
        end
    end
    return true
end

local function testShapes()
    -- 半砖：下半在 0..0.5，上半在 0.5..1
    local bottom = BlockShapes.get(BlockShapes.SLAB, 0)
    local top = BlockShapes.get(BlockShapes.SLAB, BlockState.pack(0, true, false))
    boxesValid(bottom, "slab bottom")
    boxesValid(top, "slab top")
    V.assert(bottom[1][5] == 0.5, "T7 下半砖顶面应为 0.5")
    V.assert(top[1][2] == 0.5 and top[1][5] == 1, "T7 上半砖应占 0.5..1")

    -- 楼梯：两个盒子，4 个朝向的台阶位置互不相同
    local seen = {}
    for facing = 0, 3 do
        local boxes = BlockShapes.get(BlockShapes.STAIRS, BlockState.pack(facing, false, false))
        boxesValid(boxes, "stairs facing " .. facing)
        V.assert(#boxes == 2, "T7 楼梯应由 2 个盒子组成")
        local key = string.format("%.2f,%.2f,%.2f,%.2f", boxes[2][1], boxes[2][3], boxes[2][4], boxes[2][6])
        V.assert(seen[key] == nil, "T7 楼梯朝向 " .. facing .. " 的台阶位置与别的朝向重复")
        seen[key] = true
    end
    -- 倒置楼梯：整板跑到上半
    local upside = BlockShapes.get(BlockShapes.STAIRS, BlockState.pack(0, true, false))
    V.assert(upside[1][2] == 0.5, "T7 倒置楼梯的整板应在上半")

    -- 栅栏：无邻接只有柱子，每多一个邻接多两根横杆
    local lone = BlockShapes.get(BlockShapes.FENCE, 0, 0)
    local oneSide = BlockShapes.get(BlockShapes.FENCE, 0, 1)
    local fourSides = BlockShapes.get(BlockShapes.FENCE, 0, 15)
    boxesValid(lone, "fence lone")
    boxesValid(fourSides, "fence 4-way")
    V.assert(#lone == 1, "T7 孤立栅栏应只有中柱")
    V.assert(#oneSide == 3, "T7 单侧连接应是 1 柱 + 2 横杆，实际 " .. #oneSide)
    V.assert(#fourSides == 9, "T7 四面连接应是 1 柱 + 8 横杆，实际 " .. #fourSides)

    -- 连接判据：只连同类连接件 + 任何实心方块；栅栏不该连到墙上（反之亦然）
    local F, W = BlockShapes.FENCE, BlockShapes.WALL
    V.assert(BlockShapes.fenceConnects(F, F, false) == true, "T7 栅栏应与栅栏相连")
    V.assert(BlockShapes.fenceConnects(F, nil, true) == true, "T7 栅栏应与实心方块相连")
    V.assert(BlockShapes.fenceConnects(F, nil, false) == false, "T7 栅栏不该与空气相连")
    V.assert(BlockShapes.fenceConnects(F, W, false) == false, "T7 栅栏不该连到墙上")
    V.assert(BlockShapes.fenceConnects(W, W, false) == true, "T7 墙应与墙相连")

    -- 墙：比栅栏粗（石质细柱贴图会糊），连接段是实心块而不是横杆
    local wallLone = BlockShapes.get(W, 0, 0)
    local wallOne = BlockShapes.get(W, 0, 1)
    boxesValid(wallLone, "wall lone")
    boxesValid(wallOne, "wall one side")
    V.assert(#wallLone == 1, "T7 孤立墙应只有柱体")
    V.assert(#wallOne == 2, "T7 单侧连接的墙应是柱体 + 1 段，实际 " .. #wallOne)
    local wallWidth = wallLone[1][4] - wallLone[1][1]
    local fenceWidth = lone[1][4] - lone[1][1]
    V.assert(wallWidth > fenceWidth,
        string.format("T7 墙体应比栅栏柱粗（墙 %.3f vs 栅栏 %.3f）", wallWidth, fenceWidth))
    V.assert(BlockShapes.isConnecting(W) and BlockShapes.isConnecting(F),
        "T7 墙与栅栏都应被认作按邻接连接的形状")
    V.assert(BlockShapes.isConnecting(BlockShapes.SLAB) == false, "T7 半砖不该按邻接连接")

    -- 门：开与关的盒子朝向必须不同（否则"开门"看不出来）
    local closed = BlockShapes.get(BlockShapes.DOOR, BlockState.pack(BlockState.FACING_NZ, false, false))
    local opened = BlockShapes.get(BlockShapes.DOOR, BlockState.pack(BlockState.FACING_NZ, false, true))
    boxesValid(closed, "door closed")
    boxesValid(opened, "door open")
    local closedThinZ = (closed[1][6] - closed[1][3]) < 0.5
    local openThinX = (opened[1][4] - opened[1][1]) < 0.5
    V.assert(closedThinZ, "T7 关门时门板应薄在 Z 轴")
    V.assert(openThinX, "T7 开门时门板应转到薄在 X 轴")

    -- 门轴左右：开门时必须转向不同的一侧（双开门靠这个互为镜像）
    local openLeft = BlockShapes.get(BlockShapes.DOOR,
        BlockState.pack(BlockState.FACING_NZ, false, true, false))
    local openRight = BlockShapes.get(BlockShapes.DOOR,
        BlockState.pack(BlockState.FACING_NZ, false, true, true))
    V.assert(openLeft[1][1] ~= openRight[1][1] or openLeft[1][4] ~= openRight[1][4],
        "T7 左轴与右轴开门后应转到不同的一侧")
    V.assert(openLeft[1][1] < 0.5 and openRight[1][4] > 0.5,
        "T7 左轴门应贴到低侧、右轴门应贴到高侧")
    -- 关着时门轴不影响门板位置
    local closedLeft = BlockShapes.get(BlockShapes.DOOR, BlockState.pack(BlockState.FACING_NZ))
    local closedRight = BlockShapes.get(BlockShapes.DOOR,
        BlockState.pack(BlockState.FACING_NZ, false, false, true))
    V.assert(closedLeft[1][6] == closedRight[1][6], "T7 关门时门轴不该改变门板位置")

    -- 活板门：关=贴地薄板，开=竖起
    local tdClosed = BlockShapes.get(BlockShapes.TRAPDOOR, 0)
    local tdOpen = BlockShapes.get(BlockShapes.TRAPDOOR, BlockState.pack(0, false, true))
    V.assert(tdClosed[1][5] < 0.3, "T7 关闭的活板门应是贴地薄板")
    V.assert(tdOpen[1][5] == 1, "T7 打开的活板门应竖起到满高")
end

-- ====================================================================
-- T8 逐形状碰撞（与渲染共用盒子数据）
-- ====================================================================
local function testShapeCollision()
    local w = World.new()
    local BS = Config.World.BLOCK_SIZE
    local bx, by, bz = TEST_X + 30, 30, TEST_Z + 30

    -- 下半砖：脚踝高度实心、腰部高度是空的，站立面在半格
    w:setBlock(bx, by, bz, Blocks.SLAB_STONE, 0)
    local cx = (bx + 0.5) * BS
    local cz = (bz + 0.5) * BS
    V.assert(w:isSolidAtPoint(cx, (by + 0.25) * BS, cz) == true, "T8 下半砖 y=0.25 处应是实心")
    V.assert(w:isSolidAtPoint(cx, (by + 0.75) * BS, cz) == false, "T8 下半砖 y=0.75 处应是空的")
    local top = w:getSurfaceTopY(bx, by, bz, 0.5, 0.5)
    V.assert(top ~= nil and math.abs(top - (by + 0.5) * BS) < 0.001,
        "T8 下半砖站立面应在半格高")

    -- 上半砖：反过来
    w:setBlock(bx, by, bz, Blocks.SLAB_STONE, BlockState.pack(0, true, false))
    V.assert(w:isSolidAtPoint(cx, (by + 0.25) * BS, cz) == false, "T8 上半砖 y=0.25 处应是空的")
    V.assert(w:isSolidAtPoint(cx, (by + 0.75) * BS, cz) == true, "T8 上半砖 y=0.75 处应是实心")

    -- 整格方块仍走快路径
    w:setBlock(bx, by, bz, Blocks.STONE)
    V.assert(w:isSolidAtPoint(cx, (by + 0.9) * BS, cz) == true, "T8 整格石头应处处实心")
    local stoneTop = w:getSurfaceTopY(bx, by, bz, 0.5, 0.5)
    V.assert(math.abs(stoneTop - (by + 1) * BS) < 0.001, "T8 整格石头站立面应在整格高")

    -- 门：关着挡人、开着能穿过（同一格、只差 open 位）
    local closedState = BlockState.pack(BlockState.FACING_NZ, false, false)
    w:setBlock(bx, by, bz, Blocks.DOOR_WOOD, closedState)
    -- 关门时门板贴在 -Z 侧，取该侧的点
    V.assert(w:isSolidAtPoint(cx, (by + 0.5) * BS, (bz + 0.05) * BS) == true,
        "T8 关着的门应挡住门板所在位置")
    w:setBlock(bx, by, bz, Blocks.DOOR_WOOD, BlockState.toggleOpen(closedState))
    V.assert(w:isSolidAtPoint(cx, (by + 0.5) * BS, (bz + 0.05) * BS) == false,
        "T8 开门后原门板位置应能穿过")

    -- 栅栏：中柱挡人，格子边缘的空隙不挡（无邻接时）
    w:setBlock(bx, by, bz, Blocks.FENCE_WOOD, 0)
    V.assert(w:isSolidAtPoint(cx, (by + 0.5) * BS, cz) == true, "T8 栅栏中柱应挡人")
    V.assert(w:isSolidAtPoint((bx + 0.05) * BS, (by + 0.5) * BS, cz) == false,
        "T8 孤立栅栏的格子边缘不该挡人")
end

-- ====================================================================
-- T9 门的双格配对（放置 / 破坏 / 开关）
-- ====================================================================
local function testDoorPairing()
    local BlockInteraction = require("player.BlockInteraction")
    local w = World.new()
    local bx, by, bz = TEST_X + 40, 30, TEST_Z + 40

    -- 造一个只带必要字段的假 player：门只用到 yaw 与 getSelectedBlockType
    local fakePlayer = {
        yaw = 0,
        getSelectedBlockType = function() return Blocks.DOOR_WOOD end,
    }
    local bi = BlockInteraction.new(fakePlayer, w)

    -- 放置：下格 lower、上格 upper，朝向一致
    local placed = bi:placeBlockLocal(bx, by, bz, Blocks.DOOR_WOOD,
        BlockState.pack(BlockState.FACING_PX, false, false))
    V.assert(placed == true, "T9 门应能放置")
    V.assert(w:getBlock(bx, by, bz) == Blocks.DOOR_WOOD, "T9 门下格没放上")
    V.assert(w:getBlock(bx, by + 1, bz) == Blocks.DOOR_WOOD, "T9 门上格没放上")
    V.assert(BlockState.isTopHalf(w:getBlockState(bx, by, bz)) == false, "T9 下格不该是 topHalf")
    V.assert(BlockState.isTopHalf(w:getBlockState(bx, by + 1, bz)) == true, "T9 上格应是 topHalf")
    V.assert(BlockState.facing(w:getBlockState(bx, by + 1, bz)) == BlockState.FACING_PX,
        "T9 上下格朝向应一致")

    -- 上方被占时放不下
    w:setBlock(bx + 2, by + 1, bz, Blocks.STONE)
    V.assert(bi:placeBlockLocal(bx + 2, by, bz, Blocks.DOOR_WOOD, 0) == false,
        "T9 上方被占时门不该放得下")

    -- 开关：两格同步
    V.assert(bi:useBlockLocal(bx, by, bz) == true, "T9 门应可使用")
    V.assert(BlockState.isOpen(w:getBlockState(bx, by, bz)) == true, "T9 下格没开")
    V.assert(BlockState.isOpen(w:getBlockState(bx, by + 1, bz)) == true, "T9 上格没跟着开")
    bi:useBlockLocal(bx, by + 1, bz)   -- 从上格再关一次
    V.assert(BlockState.isOpen(w:getBlockState(bx, by, bz)) == false, "T9 从上格关门时下格没跟上")

    -- 破坏一半 → 另一半连带消失
    bi:destroyBlockLocal(bx, by, bz)
    V.assert(w:getBlock(bx, by, bz) == Blocks.AIR, "T9 门下格没破坏")
    V.assert(w:getBlock(bx, by + 1, bz) == Blocks.AIR, "T9 破坏下格后上格应连带消失")

    -- 非交互方块右键不应被"使用"吞掉
    w:setBlock(bx, by, bz, Blocks.STONE)
    V.assert(bi:useBlockLocal(bx, by, bz) == false, "T9 石头不该能被使用")

    -- 双开门：挨着同朝向的门放第二扇 → 门轴自动放到对侧
    local dx, dy, dz = TEST_X + 44, 30, TEST_Z + 44
    local facing = BlockState.FACING_NZ
    bi:placeBlockLocal(dx, dy, dz, Blocks.DOOR_WOOD, BlockState.pack(facing))
    local firstHinge = BlockState.isHingeRight(w:getBlockState(dx, dy, dz))
    -- 朝向 ±Z 的门横向是 X 轴，所以第二扇放在 x+1
    bi:placeBlockLocal(dx + 1, dy, dz, Blocks.DOOR_WOOD, BlockState.pack(facing))
    local secondHinge = BlockState.isHingeRight(w:getBlockState(dx + 1, dy, dz))
    V.assert(firstHinge ~= secondHinge,
        "T9 相邻同朝向的门应互为镜像门轴（双开门）")
    -- 上格要跟下格一致，否则上下两半会朝不同方向开
    V.assert(BlockState.isHingeRight(w:getBlockState(dx + 1, dy + 1, dz)) == secondHinge,
        "T9 门的上下格门轴应一致")

    -- 隔开一格（不相邻）时不镜像
    bi:placeBlockLocal(dx + 4, dy, dz, Blocks.DOOR_WOOD, BlockState.pack(facing))
    V.assert(BlockState.isHingeRight(w:getBlockState(dx + 4, dy, dz)) == firstHinge,
        "T9 不相邻的门不该被镜像")

    -- 世界顶那一格放不下双格门：getBlock 对越界 y 返回空气，光看"上方是空气"会让
    -- 空间检查通过，随后上半格写入静默失败 → 留下半扇配不上对的门
    local topY = Config.World.WORLD_HEIGHT - 1
    V.assert(bi:placeBlockLocal(dx + 8, topY, dz, Blocks.DOOR_WOOD, 0) == false,
        "T9 世界顶那一格不该放得下双格门")
    V.assert(w:getBlock(dx + 8, topY, dz) == Blocks.AIR,
        "T9 放置失败却写入了下半格（半扇门）")

    -- 负 Y 同理：下半格写不进去，上半格会落到 y=0，留下带 topHalf 的孤立门块
    V.assert(bi:placeBlockLocal(dx + 8, -1, dz, Blocks.DOOR_WOOD, 0) == false,
        "T9 负 Y 不该放得下方块")
    V.assert(w:getBlock(dx + 8, 0, dz) == Blocks.AIR,
        "T9 负 Y 放置把上半格写到了 y=0")

    -- 状态值现在有 5 位（含 hinge），必须能原样存下来（光照那套 setter 会夹到 15）
    local wide = BlockState.pack(BlockState.FACING_NZ, true, true, true)  -- = 27
    V.assert(wide > 15, "T9 测试用例本身失效：状态值应超过 15")
    w:setBlock(dx, dy + 3, dz, Blocks.DOOR_WOOD, wide)
    V.assert(w:getBlockState(dx, dy + 3, dz) == wide,
        "T9 超过 15 的状态值被截断了: " .. w:getBlockState(dx, dy + 3, dz) .. " vs " .. wide)
end

-- ====================================================================
-- T10 形状方块进网格（顶点数 / 栅栏连接影响几何）
-- ====================================================================
local function testShapeMesh()
    local scene = V.scene()
    if not V.assert(scene ~= nil, "T10 拿不到场景，跳过") then
        return
    end

    ---建一个只含指定内容的区块，返回 solid 几何体顶点数
    local function buildAndCount(cx, cz, fill)
        local w = World.new()
        local builder = ChunkMeshBuilder.new(w, scene)
        builder:setTextures(TexturePackManager:getCurrent():generate())
        fill(w, cx * 16, cz * 16)
        w:computeAllChunkHeightRanges()
        w:propagateSkyLight()
        builder:buildChunk(cx, cz)

        local node = scene:GetChild("Chunk_" .. cx .. "," .. cz, true)
        local count = 0
        if node then
            local geo = node:GetComponent("CustomGeometry")
            if geo then count = geo:GetNumVertices(0) end
            node:Remove()
        end
        w.dirtyChunks = {}
        return count
    end

    -- 半砖 / 楼梯 / 门都必须真的产生顶点
    local slabVerts = buildAndCount(TEST_CX + 3, TEST_CZ, function(w, ox, oz)
        w:setBlock(ox + 4, 20, oz + 4, Blocks.SLAB_STONE, 0)
    end)
    V.assert(slabVerts > 0, "T10 半砖没有产生顶点")

    local stairVerts = buildAndCount(TEST_CX + 4, TEST_CZ, function(w, ox, oz)
        w:setBlock(ox + 4, 20, oz + 4, Blocks.STAIRS_STONE, 0)
    end)
    V.assert(stairVerts > slabVerts, "T10 楼梯（2 个盒子）顶点数应多于半砖（1 个盒子）")

    -- 栅栏：连成一排时会多出横杆 → 顶点数必须变多
    local loneFence = buildAndCount(TEST_CX + 5, TEST_CZ, function(w, ox, oz)
        w:setBlock(ox + 4, 20, oz + 4, Blocks.FENCE_WOOD, 0)
    end)
    local pairFence = buildAndCount(TEST_CX + 6, TEST_CZ, function(w, ox, oz)
        w:setBlock(ox + 4, 20, oz + 4, Blocks.FENCE_WOOD, 0)
        w:setBlock(ox + 5, 20, oz + 4, Blocks.FENCE_WOOD, 0)
    end)
    V.assert(pairFence > loneFence * 2,
        string.format("T10 相邻栅栏应长出横杆（1 个=%d 顶点，2 个=%d）", loneFence, pairFence))
end

-- ====================================================================
-- 调度：纯逻辑测试早跑，依赖场景的等世界就绪
-- ====================================================================
V.atFrame(120, function()
    testRegistry()
    testSkyLight()
    testBlockLight()
    testGeology()
    testBlockState()
    testPartialBlocksPassSkyLight()
    testShapes()
    testShapeCollision()
    testDoorPairing()
end)

V.atFrame(320, function()
    testRenderLayers()
    testShapeMesh()
    V.finish()
end)
