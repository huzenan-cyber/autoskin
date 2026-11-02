-- ====================================================================
-- devtools/BlockShowcase.lua
-- 方块展示台 - 把所有注册方块摆成一排，用来目视/截图检查渲染是否正确
--
-- 专门用于验证特殊渲染层：
--   玻璃（alpha 裁剪，不能剔掉后面方块的面）
--   冰（alpha 混合）
--   水 / 岩浆（液体，岩浆自发光）
--   交叉网格植物
--
-- 用法（Windows 窗口截图）：
--   UrhoXRuntime.exe devtools/BlockShowcase.lua -tapcode_dir=<Minecraft 目录> \
--       -skip_login -screenshot=<out.png> -screenshot-frame=90 -x 1280 -y 720
--
-- 想看 HD PBR 材质：加 -showcase_hd
-- 想验证发光方块（荧石/岩浆）的顶点光照烘焙：加 -showcase_cave
--   露天场景每格 skyLight 都是 15，烘焙出来恒为满亮，测不出方块光；
--   必须建一个有顶的暗室（skyLight=0）才能看出光源照亮一圈。
-- ====================================================================

local Config = require("config.GameConfig")
local Blocks = require("data.BlockRegistry")
local BlockState = require("data.BlockState")
local World = require("world.World")
local ChunkMeshBuilder = require("world.ChunkMeshBuilder")
local TexturePackManager = require("rendering.texturepacks.TexturePackManager")

local scene_ = nil
local world_ = nil
local chunkBuilder_ = nil
local cameraNode_ = nil

-- 展示顺序：**特殊渲染层放第一排**（离相机最近，方便检查玻璃/冰的透视与液体），
-- 后面几排是普通不透明方块
local SHOWCASE_ROWS = {
    -- 特殊渲染层：玻璃/冰后面各放一个红羊毛参照物，检查不会被剔成空洞
    {
        Blocks.GLASS, Blocks.ICE, Blocks.WATER, Blocks.LAVA,
        Blocks.TALL_GRASS, Blocks.ROSE, Blocks.SAPLING, Blocks.DEAD_BUSH,
        Blocks.MUSHROOM_BROWN,
    },
    {
        Blocks.GRASS, Blocks.DIRT, Blocks.STONE, Blocks.COBBLESTONE, Blocks.MOSSY_COBBLESTONE,
        Blocks.STONE_BRICKS, Blocks.SANDSTONE, Blocks.OBSIDIAN, Blocks.BEDROCK,
    },
    {
        Blocks.WOOD, Blocks.PLANKS, Blocks.BRICKS, Blocks.BOOKSHELF, Blocks.CRAFTING_TABLE,
        Blocks.FURNACE, Blocks.LEAVES, Blocks.SAND, Blocks.GRAVEL,
    },
    {
        Blocks.COAL_ORE, Blocks.IRON_ORE, Blocks.GOLD_ORE, Blocks.DIAMOND_ORE,
        Blocks.REDSTONE_ORE, Blocks.LAPIS_ORE, Blocks.GLOWSTONE, Blocks.CLAY, Blocks.CACTUS,
    },
    {
        Blocks.WOOL_WHITE, Blocks.WOOL_RED, Blocks.WOOL_YELLOW, Blocks.WOOL_GREEN,
        Blocks.WOOL_BLUE, Blocks.WOOL_BLACK, Blocks.SNOW_BLOCK, Blocks.SNOWY_GRASS,
        Blocks.MUSHROOM_RED,
    },
}

local BASE_Y = 8
local ROW_SPACING = 3   -- 每排之间空一格，避免互相遮挡

-- 放置时收集的发光方块坐标（setBlockRaw 不触发光照更新，之后统一补 blockLight）
local emitters_ = {}

---放一个方块，顺手记下光源
local function place(x, y, z, blockType)
    world_:setBlockRaw(x, y, z, blockType)
    local block = Blocks:get(blockType)
    if block and block.hasLight then
        emitters_[#emitters_ + 1] = { x, y, z, block.lightRadius }
    end
end

---非整格建筑件展示排：半砖上下半、楼梯 4 朝向、栅栏连一串、门开与关、活板门开与关
---@param z number 这一排的 Z
---@return number 用掉的格子数
local function buildShapeRow(z)
    local items = {
        -- { 方块, 状态 }
        -- 下半砖故意用砖块材质：石半砖摆在石地板上几乎看不出来
        { Blocks.SLAB_BRICKS, BlockState.pack(0, false, false) },       -- 下半砖
        { Blocks.SLAB_PLANKS, BlockState.pack(0, true, false) },        -- 上半砖
        { Blocks.STAIRS_COBBLESTONE, BlockState.pack(BlockState.FACING_PX) },
        { Blocks.STAIRS_COBBLESTONE, BlockState.pack(BlockState.FACING_NZ) },
        { Blocks.STAIRS_BRICKS, BlockState.pack(BlockState.FACING_PZ, true, false) }, -- 倒置楼梯
        { Blocks.FENCE_WOOD, 0 },
        { Blocks.FENCE_WOOD, 0 },      -- 连成一段，验证自动连接
        { Blocks.WALL_COBBLESTONE, 0 },
        { Blocks.WALL_COBBLESTONE, 0 },   -- 两格相连，验证墙体连接段
        { Blocks.TRAPDOOR_WOOD, BlockState.pack(BlockState.FACING_NZ, false, false) },  -- 关
        { Blocks.TRAPDOOR_WOOD, BlockState.pack(BlockState.FACING_NZ, false, true) },   -- 开
    }

    for i, item in ipairs(items) do
        local x = i - 1
        place(x, BASE_Y, z, item[1])
        world_:setBlockState(x, BASE_Y, z, item[2])
    end

    -- 门：一扇关、一扇开；再摆一对双开门（门轴互为镜像，从中间往两边开）
    local doorX = #items
    local doors = {
        { x = doorX,     open = false, hinge = false },
        { x = doorX + 2, open = true,  hinge = false },
        -- 双开门：贴在一起、门轴对称、都开着
        { x = doorX + 5, open = true,  hinge = false },
        { x = doorX + 6, open = true,  hinge = true },
    }

    for _, d in ipairs(doors) do
        local base = BlockState.pack(BlockState.FACING_NZ, false, d.open, d.hinge)
        place(d.x, BASE_Y, z, Blocks.DOOR_WOOD)
        world_:setBlockState(d.x, BASE_Y, z, base)
        place(d.x, BASE_Y + 1, z, Blocks.DOOR_WOOD)
        world_:setBlockState(d.x, BASE_Y + 1, z, BlockState.withTopHalf(base, true))
    end

    return doorX + 8
end

---模式 A：所有方块摆成排（默认）
---@return { pos: Vector3, look: Vector3 } 相机参数
local function buildRowsScene()
    local maxLen = 15   -- 非整格建筑件那一排最长
    for _, row in ipairs(SHOWCASE_ROWS) do
        if #row > maxLen then maxLen = #row end
    end

    -- 地面平台（多留一排给建筑件）
    local rowCount = #SHOWCASE_ROWS + 1
    for x = -2, maxLen + 1 do
        for z = -2, rowCount * ROW_SPACING + 1 do
            place(x, BASE_Y - 1, z, Blocks.STONE)
        end
    end

    -- 最靠相机的一排（z = -2）：非整格建筑件（半砖/楼梯/栅栏/门/活板门）
    buildShapeRow(-2)

    -- 每排一行；玻璃/冰后面放红羊毛做遮挡参照
    for rowIdx, row in ipairs(SHOWCASE_ROWS) do
        local z = (rowIdx - 1) * ROW_SPACING
        for i, blockType in ipairs(row) do
            local x = i - 1
            place(x, BASE_Y, z, blockType)
            if blockType == Blocks.GLASS or blockType == Blocks.ICE then
                -- 正确实现下应能透过玻璃/冰看到它，而不是一个空洞
                place(x, BASE_Y, z + 1, Blocks.WOOL_RED)
            end
        end
    end

    local bs = Config.World.BLOCK_SIZE
    return {
        pos = Vector3((maxLen * 0.5) * bs, (BASE_Y + 2.2) * bs, -6 * bs),
        look = Vector3((maxLen * 0.5) * bs, (BASE_Y + 0.4) * bs, 2 * bs),
    }
end

---模式 C：只摆非整格建筑件（-showcase_shapes），斜俯视看清半砖高度与楼梯台阶
---@return { pos: Vector3, look: Vector3 } 相机参数
local function buildShapeScene()
    local width = 18
    for x = -2, width do
        for z = -3, 3 do
            place(x, BASE_Y - 1, z, Blocks.STONE)
        end
    end

    local used = buildShapeRow(0)

    -- 回归场景：整格方块紧挨半砖 / 楼梯。
    -- 非整格方块若被当成"挡天光"，它那一格 skyLight=0，紧挨它的整格方块的那个面
    -- 会烘焙成 MIN_AMBIENT（几乎全黑）—— 这里专门摆出来盯着
    local rx = 2
    place(rx, BASE_Y, -2, Blocks.SLAB_BRICKS)
    place(rx, BASE_Y, -3, Blocks.BRICKS)          -- 紧挨半砖的整格砖
    place(rx + 1, BASE_Y, -3, Blocks.BRICKS)
    place(rx + 2, BASE_Y, -2, Blocks.STAIRS_BRICKS)
    place(rx + 2, BASE_Y, -3, Blocks.BRICKS)

    local bs = Config.World.BLOCK_SIZE
    return {
        pos = Vector3((used * 0.45) * bs, (BASE_Y + 3.2) * bs, -7 * bs),
        look = Vector3((used * 0.45) * bs, (BASE_Y + 0.5) * bs, 0.5 * bs),
    }
end

---模式 B：带顶暗室（验证发光方块的顶点光照烘焙）
---室内 skyLight=0，只有荧石/岩浆能照亮周围；正面开口给相机看进去
---@return { pos: Vector3, look: Vector3 } 相机参数
local function buildCaveScene()
    local W, D, H = 13, 11, 4   -- 内部尺寸（x, z, y）

    -- 实心石块填满，再挖空内部
    for x = -1, W do
        for z = -1, D do
            for y = BASE_Y - 1, BASE_Y + H do
                place(x, y, z, Blocks.STONE)
            end
        end
    end
    for x = 0, W - 1 do
        for z = 0, D - 1 do
            for y = BASE_Y, BASE_Y + H - 1 do
                world_:setBlockRaw(x, y, z, Blocks.AIR)
            end
        end
    end
    -- 正面（z = -1）开一个门洞给相机看进来
    for x = 3, W - 4 do
        for y = BASE_Y, BASE_Y + H - 2 do
            world_:setBlockRaw(x, y, -1, Blocks.AIR)
        end
    end

    -- 左边荧石、右边岩浆池，中间放几个参照方块看照明衰减
    place(2, BASE_Y, 7, Blocks.GLOWSTONE)
    for x = W - 4, W - 2 do
        for z = 6, 8 do
            place(x, BASE_Y, z, Blocks.LAVA)
        end
    end
    for x = 4, W - 5 do
        place(x, BASE_Y, 8, Blocks.COBBLESTONE)
        place(x, BASE_Y + 1, 8, Blocks.WOOL_WHITE)
    end

    local bs = Config.World.BLOCK_SIZE
    return {
        pos = Vector3((W * 0.5) * bs, (BASE_Y + 1.2) * bs, -5 * bs),
        look = Vector3((W * 0.5) * bs, (BASE_Y + 1.0) * bs, 8 * bs),
    }
end

function Start()
    -- GetArguments() 在本引擎返回的是普通 Lua 表（不是 StringVector）
    local packName = "classic"
    local mode = "rows"
    local args = GetArguments and GetArguments() or nil
    if type(args) == "table" then
        for _, a in ipairs(args) do
            if a == "-showcase_hd" then packName = "hd" end
            if a == "-showcase_cave" then mode = "cave" end
            if a == "-showcase_shapes" then mode = "shapes" end
        end
    end

    scene_ = Scene()
    scene_:CreateComponent("Octree")

    -- 光照预设（与游戏一致）
    local lightGroupFile = cache:GetResource("XMLFile", "LightGroup/Daytime.xml")
    local lightGroup = scene_:CreateChild("LightGroup", LOCAL)
    lightGroup:LoadXML(lightGroupFile:GetRoot())
    local zone = lightGroup:GetComponent("Zone")
    if zone then
        zone.depthFogStart = 200
        zone.depthFogEnd = 800
    end

    TexturePackManager:setCurrent(packName)
    local textures = TexturePackManager:getCurrent():generate()
    print(string.format("[Showcase] texture pack = %s, mode = %s",
        packName, mode))

    world_ = World.new()
    chunkBuilder_ = ChunkMeshBuilder.new(world_, scene_)
    chunkBuilder_:setTextures(textures)

    emitters_ = {}
    local cam
    if mode == "cave" then
        cam = buildCaveScene()
    elseif mode == "shapes" then
        cam = buildShapeScene()
    else
        cam = buildRowsScene()
    end

    world_:computeAllChunkHeightRanges()
    world_:propagateSkyLight()

    -- 光源方块补 blockLight（与 WorldGenerator:seedBlockLights 同理）
    for _, e in ipairs(emitters_) do
        world_:addBlockLight(e[1], e[2], e[3], e[4])
    end
    print(string.format("[Showcase] %d light emitters seeded", #emitters_))

    -- 建网格
    for cx = -2, 2 do
        for cz = -2, 2 do
            chunkBuilder_:buildChunk(cx, cz)
        end
    end
    world_.dirtyChunks = {}

    cameraNode_ = scene_:CreateChild("Camera", LOCAL)
    local camera = cameraNode_:CreateComponent("Camera")
    camera.farClip = 500
    camera.fov = 70
    cameraNode_.position = cam.pos
    cameraNode_:LookAt(cam.look)

    renderer:SetViewport(0, Viewport:new(scene_, camera))

    print("[Showcase] ready")
end

function Stop()
end
