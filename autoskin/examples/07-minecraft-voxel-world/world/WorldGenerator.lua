-- ====================================================================
-- world/WorldGenerator.lua
-- 世界生成器 - 生成地形、树木等
-- ====================================================================

local Config = require("config.GameConfig")
local Blocks = require("data.BlockRegistry")
local BiomeGenerator = require("terrain.BiomeGenerator")
local TreeDecorator = require("terrain.TreeDecorator")
local HouseGenerator = require("terrain.HouseGenerator")

-- ============================================================================
-- 地质特征（Features.RICH_TERRAIN）
--
-- NoiseGenerator 只有 2D 柏林噪声，做不出竖向连贯的 3D 矿脉，所以这里用
-- 「空间格哈希 + 确定性随机行走」：把世界切成 FEATURE_CELL³ 的格子，每格按
-- 概率决定是否投放一条矿脉，再从格内随机起点随机游走 N 步替换石头。
-- 好处：天然跨 chunk 连贯、同种子必复现、不需要额外噪声实现。
-- ============================================================================

-- 六邻方向（矿脉游走用）
local WALK_DIRS = {
    { 1, 0, 0 }, { -1, 0, 0 },
    { 0, 1, 0 }, { 0, -1, 0 },
    { 0, 0, 1 }, { 0, 0, -1 },
}

---空间格哈希（只用乘加取模，避免位运算的跨平台差异，与 NoiseGenerator 同思路）
---@return number 非负整数种子
local function hashCell(cx, cy, cz, salt)
    local h = (cx * 73856093 + cy * 19349663 + cz * 83492791 + salt * 26943571) % 2147483647
    if h < 0 then h = h + 2147483647 end
    return h
end

---最小 LCG，返回一个 [0,1) 取值的确定性随机函数
---@param seed number
---@return function
local function makeRng(seed)
    local state = seed % 2147483647
    if state <= 0 then state = state + 2147483646 end
    return function()
        state = (state * 48271) % 2147483647
        return state / 2147483647
    end
end

-- 矿脉 / 地质团定义：depth 用绝对 y，按 WORLD_HEIGHT=80（medium 预设）标定
-- chance = 每个空间格的投放概率，size = 游走步数区间
local GEO_FEATURES = {
    { name = "coal",     block = Blocks.COAL_ORE,     minY = 6, maxY = 52, chance = 0.55, sizeMin = 6, sizeMax = 14, salt = 101 },
    { name = "iron",     block = Blocks.IRON_ORE,     minY = 4, maxY = 40, chance = 0.40, sizeMin = 4, sizeMax = 9,  salt = 102 },
    { name = "gold",     block = Blocks.GOLD_ORE,     minY = 2, maxY = 22, chance = 0.18, sizeMin = 3, sizeMax = 7,  salt = 103 },
    { name = "lapis",    block = Blocks.LAPIS_ORE,    minY = 2, maxY = 26, chance = 0.14, sizeMin = 3, sizeMax = 6,  salt = 104 },
    { name = "redstone", block = Blocks.REDSTONE_ORE, minY = 2, maxY = 14, chance = 0.20, sizeMin = 4, sizeMax = 8,  salt = 105 },
    { name = "diamond",  block = Blocks.DIAMOND_ORE,  minY = 1, maxY = 13, chance = 0.10, sizeMin = 2, sizeMax = 5,  salt = 106 },
    { name = "gravel",   block = Blocks.GRAVEL,       minY = 8, maxY = 56, chance = 0.30, sizeMin = 8, sizeMax = 20, salt = 107 },
    -- 岩浆池：发光方块，坐标要记下来在天光灌注后补 blockLight
    { name = "lava",     block = Blocks.LAVA,         minY = 1, maxY = 8,  chance = 0.22, sizeMin = 4, sizeMax = 12, salt = 108, emitsLight = true },
}

---@class WorldGenerator
---@field biome BiomeGenerator
---@field tree TreeDecorator
---@field house HouseGenerator
---@field pendingLights table 生成期发现的发光方块坐标（等天光灌完再补 blockLight）
local WorldGenerator = {}
WorldGenerator.__index = WorldGenerator

---创建新的世界生成器
---@return table WorldGenerator实例
function WorldGenerator.new()
    local self = setmetatable({}, WorldGenerator)
    self.biome = BiomeGenerator.new()
    self.tree = TreeDecorator.new()
    self.house = HouseGenerator.new()  -- 预留：可在 generate() 末尾调用 self.house:generateAtSpawn(world, 8, 8)
    self.pendingLights = {}
    return self
end

---生成世界
---@param world table World实例
---@param centerX number|nil 中心X坐标（默认0）
---@param centerZ number|nil 中心Z坐标（默认0）
function WorldGenerator:generate(world, centerX, centerZ)
    centerX = centerX or 0
    centerZ = centerZ or 0

    local CHUNK_SIZE = Config.World.CHUNK_SIZE
    local RENDER_DISTANCE = Config.World.RENDER_DISTANCE
    local WATER_LEVEL = Config.World.WATER_LEVEL
    local radius = CHUNK_SIZE * RENDER_DISTANCE

    print("Generating world...")

    -- 第一遍：生成地形
    for x = centerX - radius, centerX + radius do
        for z = centerZ - radius, centerZ + radius do
            -- 检查是否在圆形范围内
            local dx = x - centerX
            local dz = z - centerZ
            if dx*dx + dz*dz <= radius*radius then
                self:generateColumn(world, x, z)
            end
        end
    end

    -- 第 1.5 遍：地质特征（矿脉 / 砂砾 / 岩浆池），必须在地形之后、光照之前
    self:generateGeologicalFeatures(world, centerX, centerZ, radius)

    -- 第二遍：添加树木（可选功能）
    if Config.Features and Config.Features.GENERATE_TREES then
        print("Adding trees...")
        local treeCount = 0
        local checkedCount = 0
        for x = centerX - radius + 3, centerX + radius - 3 do
            for z = centerZ - radius + 3, centerZ + radius - 3 do
                local dx = x - centerX
                local dz = z - centerZ
                if dx*dx + dz*dz <= (radius-3)*(radius-3) then
                    checkedCount = checkedCount + 1
                    if self:tryPlaceTree(world, x, z) then
                        treeCount = treeCount + 1
                    end
                end
            end
        end
        print(string.format("[Trees] Checked %d positions, placed %d trees", checkedCount, treeCount))
        self:printTreeStats()
        self.biome:printBiomeStats()
    else
        print("[Trees] Skipped (GENERATE_TREES = false)")
    end

    -- 第三遍：添加植被（草和花）（可选功能）
    if Config.Features and Config.Features.GENERATE_VEGETATION then
        print("Adding vegetation...")
        for x = centerX - radius, centerX + radius do
            for z = centerZ - radius, centerZ + radius do
                local dx = x - centerX
                local dz = z - centerZ
                if dx*dx + dz*dz <= radius*radius then
                    self:tryPlaceVegetation(world, x, z)
                end
            end
        end
    else
        print("[Vegetation] Skipped (GENERATE_VEGETATION = false)")
    end

    -- 计算所有区块的高度范围（用于 ChunkMeshBuilder 优化）
    world:computeAllChunkHeightRanges()

    -- L1: 天光垂直灌注（必须在 mesh 构建前完成，供 emitSolidFace 烘焙读取）
    world:propagateSkyLight()

    -- 光源方块（岩浆池等）补 blockLight，必须在天光之后
    self:seedBlockLights(world)

    print("World generation complete!")
end

---生成单列方块
---@param world table World实例
---@param x number X坐标
---@param z number Z坐标
function WorldGenerator:generateColumn(world, x, z)
    local height = self.biome:getTerrainHeight(x, z)
    local biome = self.biome:getBiome(x, z)
    local WATER_LEVEL = Config.World.WATER_LEVEL
    local WORLD_HEIGHT = Config.World.WORLD_HEIGHT
    local rich = Config.Features and Config.Features.RICH_TERRAIN
    local terrainCfg = Config.Terrain or {}

    -- 雪线：高过这条线的山顶积雪，再高一截直接是雪块
    local snowLine = math.floor(WORLD_HEIGHT * (terrainCfg.SNOW_LINE_RATIO or 0.70))
    local snowBlockLine = snowLine + (terrainCfg.SNOW_BLOCK_EXTRA or 6)

    -- 浅水黏土：用低频噪声成片，而不是逐列随机（否则是胡椒盐点）
    local clayPatch = false
    if rich and height <= WATER_LEVEL and height >= WATER_LEVEL - 3 then
        clayPatch = self.biome.noise:fbm(x * 0.12 + 700, z * 0.12 + 700, 2, 2.0, 0.5) > 0.20
    end

    -- 基岩第二层是否补齐（确定性，同种子必复现）
    local bedrockRng = rich and makeRng(hashCell(x, 0, z, 201)) or nil

    -- 生成垂直方块列
    for y = 0, height do
        local blockType = Blocks.STONE

        if rich and y == 0 then
            -- 世界地板：不可破坏
            blockType = Blocks.BEDROCK
        elseif rich and y == 1 and y < height and bedrockRng() < 0.5 then
            blockType = Blocks.BEDROCK
        elseif y == height then
            -- 顶层方块基于生物群系 / 海拔
            if height <= WATER_LEVEL then
                blockType = clayPatch and Blocks.CLAY or Blocks.SAND  -- 水下
            elseif height == WATER_LEVEL + 1 then
                blockType = Blocks.SAND  -- 海滩（仅水面上1格）
            elseif biome == BiomeGenerator.DESERT then
                blockType = Blocks.SAND  -- 沙漠
            elseif rich and height > snowBlockLine then
                blockType = Blocks.SNOW_BLOCK  -- 高山雪顶
            elseif rich and height > snowLine then
                blockType = Blocks.SNOWY_GRASS  -- 雪线附近：草上覆雪
            else
                blockType = Blocks.GRASS  -- 普通草地
            end
        elseif y > height - 4 then
            -- 近表面
            if biome == BiomeGenerator.DESERT then
                -- 沙漠：表层沙、往下压实成砂岩
                blockType = (rich and y < height - 1) and Blocks.SANDSTONE or Blocks.SAND
            elseif height <= WATER_LEVEL + 1 then
                blockType = Blocks.SAND
            else
                blockType = Blocks.DIRT
            end
        else
            -- 深层地下 - 石头
            blockType = Blocks.STONE
        end

        world:setBlockRaw(x, y, z, blockType)
    end

    -- 添加水到水平面
    if height < WATER_LEVEL then
        for y = height + 1, WATER_LEVEL do
            world:setBlockRaw(x, y, z, Blocks.WATER)
        end
    end
end

-- ============================================================================
-- 地质特征投放（矿脉 / 砂砾团 / 岩浆池）
-- ============================================================================

---从一点开始随机游走生长一条矿脉，只替换石头
---@return number 实际放置的方块数
function WorldGenerator:growVein(world, x, y, z, def, rng)
    local steps = def.sizeMin + math.floor(rng() * (def.sizeMax - def.sizeMin + 1))
    local cx, cy, cz = x, y, z
    local placed = 0

    for _ = 1, steps do
        -- 只吃石头：不破坏地表、不在空气里悬空生成
        if world:getBlock(cx, cy, cz) == Blocks.STONE then
            world:setBlockRaw(cx, cy, cz, def.block)
            placed = placed + 1
            if def.emitsLight then
                self.pendingLights[#self.pendingLights + 1] = { cx, cy, cz }
            end
        end

        local d = WALK_DIRS[1 + math.floor(rng() * 6)]
        cx, cy, cz = cx + d[1], cy + d[2], cz + d[3]
        -- 越出该特征的深度带就回到起点重新走，避免矿脉爬到地表
        if cy < def.minY or cy > def.maxY then
            cx, cy, cz = x, y, z
        end
    end

    return placed
end

---投放全部地质特征
---@param world table World实例
---@param centerX number 中心X
---@param centerZ number 中心Z
---@param radius number 半径（方块）
---@param yieldEvery number|nil 每处理多少个空间格列 coroutine.yield 一次（异步生成用）
function WorldGenerator:generateGeologicalFeatures(world, centerX, centerZ, radius, yieldEvery)
    if not (Config.Features and Config.Features.RICH_TERRAIN) then
        print("[Geology] Skipped (RICH_TERRAIN = false)")
        return
    end

    local CELL = (Config.Terrain and Config.Terrain.FEATURE_CELL) or 8
    local WORLD_HEIGHT = Config.World.WORLD_HEIGHT
    local seed = Config.Noise.SEED

    local cellMinX = math.floor((centerX - radius) / CELL)
    local cellMaxX = math.floor((centerX + radius) / CELL)
    local cellMinZ = math.floor((centerZ - radius) / CELL)
    local cellMaxZ = math.floor((centerZ + radius) / CELL)
    local cellMaxY = math.floor((WORLD_HEIGHT - 1) / CELL)

    local stats = {}
    local processed = 0

    for cx = cellMinX, cellMaxX do
        for cz = cellMinZ, cellMaxZ do
            -- 只处理与生成圆盘有交集的格（格中心到圆心距离留一个格的余量）
            local wx = cx * CELL + CELL * 0.5 - centerX
            local wz = cz * CELL + CELL * 0.5 - centerZ
            if wx * wx + wz * wz <= (radius + CELL) * (radius + CELL) then
                for cy = 0, cellMaxY do
                    for _, def in ipairs(GEO_FEATURES) do
                        local rng = makeRng(hashCell(cx, cy, cz, def.salt + seed))
                        if rng() < def.chance then
                            local x = cx * CELL + math.floor(rng() * CELL)
                            local y = cy * CELL + math.floor(rng() * CELL)
                            local z = cz * CELL + math.floor(rng() * CELL)
                            if y >= def.minY and y <= def.maxY then
                                local placed = self:growVein(world, x, y, z, def, rng)
                                if placed > 0 then
                                    stats[def.name] = (stats[def.name] or 0) + placed
                                end
                            end
                        end
                    end
                end

                processed = processed + 1
                if yieldEvery and (processed % yieldEvery) == 0 then
                    coroutine.yield()
                end
            end
        end
    end

    local parts = {}
    for _, def in ipairs(GEO_FEATURES) do
        parts[#parts + 1] = string.format("%s=%d", def.name, stats[def.name] or 0)
    end
    print("[Geology] placed blocks: " .. table.concat(parts, ", "))
end

---把生成期收集到的发光方块灌进 blockLight 场
---setBlockRaw 不触发光照更新（只有 setBlock 会），所以岩浆/荧石这类光源必须在
---天光灌注之后统一补一遍，否则地下岩浆池周围是纯黑的
---@param world table World实例
function WorldGenerator:seedBlockLights(world)
    local count = 0
    for _, pos in ipairs(self.pendingLights) do
        local block = Blocks:get(world:getBlock(pos[1], pos[2], pos[3]))
        if block and block.hasLight then
            world:addBlockLight(pos[1], pos[2], pos[3], block.lightRadius)
            count = count + 1
        end
    end
    self.pendingLights = {}

    -- addBlockLight 会顺手标脏区块；此刻区块还没建，这些脏标记只会让首帧白重建一遍
    world.dirtyChunks = {}

    print(string.format("[Geology] seeded %d block lights", count))
end

-- 调试计数器（用于限制日志输出）
local debugLogCount = 0
local debugStats = { notGrass = 0, noTreeChance = 0, noSpace = 0, placed = 0 }

---尝试在位置放置树
---@param world table World实例
---@param x number X坐标
---@param z number Z坐标
---@return boolean 是否成功放置
function WorldGenerator:tryPlaceTree(world, x, z)
    -- ========================================================================
    -- TODO: 实现树木生成逻辑
    -- ========================================================================
    -- 
    -- 可用 API：
    --   self.biome:getTerrainHeight(x, z)        -- 获取地面高度
    --   self.biome:getBiome(x, z)                -- 获取生物群系类型
    --   self.biome:shouldPlaceTree(x, z, biome)  -- 基于噪声判断是否放树（控制密度）
    --   world:getBlock(x, y, z)                  -- 获取方块类型
    --   self.tree:canPlaceTree(world, x, y, z)   -- 检查周围是否有空间
    --   self.tree:generateTree(world, x, y, z)   -- 生成一棵树
    --
    -- 常用方块：Blocks.GRASS, Blocks.AIR, Blocks.WOOD, Blocks.LEAVES
    --
    -- 生成步骤：
    --   1. 获取地面高度和生物群系
    --   2. 检查地面是否是草地（只在草地种树）
    --   3. 用 shouldPlaceTree 控制密度（返回 true 才种）
    --   4. 用 canPlaceTree 检查空间（避免树木重叠）
    --   5. 调用 generateTree 生成树
    --
    -- 示例：
    --   local height = self.biome:getTerrainHeight(x, z)
    --   local biome = self.biome:getBiome(x, z)
    --   if world:getBlock(x, height, z) ~= Blocks.GRASS then return false end
    --   if not self.biome:shouldPlaceTree(x, z, biome) then return false end
    --   if not self.tree:canPlaceTree(world, x, height, z) then return false end
    --   self.tree:generateTree(world, x, height, z)
    --   return true
    -- ========================================================================
    
    return false  -- 默认不生成，等待 AI 实现
end

---打印树木生成统计
function WorldGenerator:printTreeStats()
    print(string.format("[Tree Stats] notGrass=%d, noTreeChance=%d, noSpace=%d, placed=%d",
        debugStats.notGrass, debugStats.noTreeChance, debugStats.noSpace, debugStats.placed))
end

---尝试在位置放置植被（草或花）
---@param world table World实例
---@param x number X坐标
---@param z number Z坐标
function WorldGenerator:tryPlaceVegetation(world, x, z)
    -- ========================================================================
    -- TODO: 实现植被生成逻辑（花草装饰）
    -- ========================================================================
    -- 
    -- 可用 API：
    --   self.biome:getTerrainHeight(x, z)       -- 获取地面高度
    --   world:getBlock(x, y, z)                 -- 获取方块类型
    --   world:setBlockRaw(x, y, z, blockType)   -- 放置方块
    --
    -- 植被方块：
    --   Blocks.TALL_GRASS    -- 装饰草（最常见）
    --   Blocks.ROSE          -- 玫瑰（红色）
    --   Blocks.FLOWER_YELLOW -- 黄花
    --   Blocks.FLOWER_BLUE   -- 蓝花（稀有）
    --
    -- 常用方块：Blocks.GRASS, Blocks.AIR
    --
    -- 生成步骤：
    --   1. 获取地面高度
    --   2. 检查地面是草地、上方是空气
    --   3. 用确定性随机控制概率：math.randomseed(x * 12345 + z * 67890)
    --   4. 放置植被方块（花比草稀有）
    --
    -- 示例：
    --   local height = self.biome:getTerrainHeight(x, z)
    --   if world:getBlock(x, height, z) ~= Blocks.GRASS then return end
    --   if world:getBlock(x, height + 1, z) ~= Blocks.AIR then return end
    --   math.randomseed(x * 12345 + z * 67890)
    --   if math.random() < 0.25 then
    --       world:setBlockRaw(x, height + 1, z, Blocks.TALL_GRASS)
    --   end
    -- ========================================================================
    
    -- 默认不生成，等待 AI 实现
end

-- ============================================================================
-- 协程化生成（异步分帧执行）
-- ============================================================================

---异步生成世界（协程版本）
---每帧执行一定量的工作后 yield，让主线程可以刷新 UI
---@param world table World实例
---@param centerX number|nil 中心X坐标（默认0）
---@param centerZ number|nil 中心Z坐标（默认0）
---@param onProgress function|nil 进度回调 function(phase, current, total)
---@return thread 协程对象
function WorldGenerator:generateAsync(world, centerX, centerZ, onProgress)
    return coroutine.create(function()
        centerX = centerX or 0
        centerZ = centerZ or 0

        local CHUNK_SIZE = Config.World.CHUNK_SIZE
        local RENDER_DISTANCE = Config.World.RENDER_DISTANCE
        local radius = CHUNK_SIZE * RENDER_DISTANCE


        -- 计算总工作量（圆形区域内的列数）
        local totalColumns = 0
        for x = centerX - radius, centerX + radius do
            for z = centerZ - radius, centerZ + radius do
                local dx, dz = x - centerX, z - centerZ
                if dx*dx + dz*dz <= radius*radius then
                    totalColumns = totalColumns + 1
                end
            end
        end

        -- 配置参数
        local COLUMNS_PER_FRAME = 500   -- 地形生成每帧处理列数
        local TREES_PER_FRAME = 200     -- 树木检查每帧处理数
        local VEGETATION_PER_FRAME = 500 -- 植被每帧处理数

        print("Generating world (async)...")

        -- ========================================
        -- 第一阶段：生成地形 (60%)
        -- ========================================
        local currentColumn = 0

        for x = centerX - radius, centerX + radius do
            for z = centerZ - radius, centerZ + radius do
                local dx, dz = x - centerX, z - centerZ
                if dx*dx + dz*dz <= radius*radius then
                    self:generateColumn(world, x, z)
                    currentColumn = currentColumn + 1

                    if currentColumn % COLUMNS_PER_FRAME == 0 then
                        if onProgress then
                            onProgress("terrain", currentColumn, totalColumns)
                        end
                        coroutine.yield()
                    end
                end
            end
        end

        -- 确保地形阶段完成后报告
        if onProgress then
            onProgress("terrain", totalColumns, totalColumns)
        end
        coroutine.yield()

        -- ========================================
        -- 第一阶段补充：地质特征（矿脉 / 砂砾 / 岩浆池）
        -- 与同步路径同一份实现，分帧靠 yieldEvery
        -- ========================================
        self:generateGeologicalFeatures(world, centerX, centerZ, radius, 24)
        if onProgress then
            onProgress("terrain", totalColumns, totalColumns)
        end
        coroutine.yield()

        -- ========================================
        -- 第二阶段：添加树木 (15%)（可选功能）
        -- ========================================
        if Config.Features and Config.Features.GENERATE_TREES then
            print("Adding trees (async)...")
            local treeCount = 0
            local checkedCount = 0
            local treeRadius = radius - 3

            -- 计算树木检查总数
            local totalTreeChecks = 0
            for x = centerX - treeRadius, centerX + treeRadius do
                for z = centerZ - treeRadius, centerZ + treeRadius do
                    local dx, dz = x - centerX, z - centerZ
                    if dx*dx + dz*dz <= treeRadius*treeRadius then
                        totalTreeChecks = totalTreeChecks + 1
                    end
                end
            end

            for x = centerX - treeRadius, centerX + treeRadius do
                for z = centerZ - treeRadius, centerZ + treeRadius do
                    local dx, dz = x - centerX, z - centerZ
                    if dx*dx + dz*dz <= treeRadius*treeRadius then
                        checkedCount = checkedCount + 1
                        if self:tryPlaceTree(world, x, z) then
                            treeCount = treeCount + 1
                        end

                        if checkedCount % TREES_PER_FRAME == 0 then
                            if onProgress then
                                onProgress("trees", checkedCount, totalTreeChecks)
                            end
                            coroutine.yield()
                        end
                    end
                end
            end

            print(string.format("[Trees] Checked %d positions, placed %d trees", checkedCount, treeCount))
            self:printTreeStats()
            self.biome:printBiomeStats()

            if onProgress then
                onProgress("trees", 1, 1)
            end
            coroutine.yield()
        else
            print("[Trees] Skipped (GENERATE_TREES = false)")
            if onProgress then
                onProgress("trees", 1, 1)
            end
            coroutine.yield()
        end

        -- ========================================
        -- 第三阶段：添加植被 (10%)（可选功能）
        -- ========================================
        if Config.Features and Config.Features.GENERATE_VEGETATION then
            print("Adding vegetation (async)...")
            local vegetationCount = 0

            for x = centerX - radius, centerX + radius do
                for z = centerZ - radius, centerZ + radius do
                    local dx, dz = x - centerX, z - centerZ
                    if dx*dx + dz*dz <= radius*radius then
                        self:tryPlaceVegetation(world, x, z)
                        vegetationCount = vegetationCount + 1

                        if vegetationCount % VEGETATION_PER_FRAME == 0 then
                            if onProgress then
                                onProgress("vegetation", vegetationCount, totalColumns)
                            end
                            coroutine.yield()
                        end
                    end
                end
            end

            if onProgress then
                onProgress("vegetation", 1, 1)
            end
            coroutine.yield()
        else
            print("[Vegetation] Skipped (GENERATE_VEGETATION = false)")
            if onProgress then
                onProgress("vegetation", 1, 1)
            end
            coroutine.yield()
        end

        -- ========================================
        -- 第四阶段：计算高度范围 (20%)
        -- ========================================
        local CHUNKS_PER_FRAME = 5  -- 每帧计算的 chunk 数

        -- 收集所有 chunk
        local chunkKeys = {}
        for numericKey, _ in pairs(world.chunkData) do
            table.insert(chunkKeys, numericKey)
        end
        local totalChunks = #chunkKeys

        -- 先 yield 一次让 UI 更新
        if onProgress then
            onProgress("heights", 0, totalChunks)
        end
        coroutine.yield()

        -- 分帧处理每个 chunk
        local processedInFrame = 0
        for i, numericKey in ipairs(chunkKeys) do
            local chunkData = world.chunkData[numericKey]
            if chunkData and chunkData.blocks then
                chunkData.minY, chunkData.maxY = world:computeHeightRange(chunkData)
                world:propagateSkyLightChunk(chunkData)  -- L1: 顺便灌天光（复用此处分帧）
            end
            processedInFrame = processedInFrame + 1

            -- 每处理 CHUNKS_PER_FRAME 个就 yield
            if processedInFrame >= CHUNKS_PER_FRAME then
                if onProgress then
                    onProgress("heights", i, totalChunks)
                end
                coroutine.yield()
                processedInFrame = 0
            end
        end

        -- 确保最后报告完成
        if onProgress then
            onProgress("heights", totalChunks, totalChunks)
        end
        coroutine.yield()

        -- ========================================
        -- 光源方块补 blockLight（天光已在上一阶段逐 chunk 灌完）
        -- ========================================
        self:seedBlockLights(world)
        coroutine.yield()

        -- ========================================
        -- 完成
        -- ========================================
        print("World generation complete (async)!")
        if onProgress then
            onProgress("complete", 1, 1)
        end
    end)
end

return WorldGenerator
