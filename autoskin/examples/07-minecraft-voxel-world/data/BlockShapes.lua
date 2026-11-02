-- ====================================================================
-- data/BlockShapes.lua
-- 非整格方块的形状 - 一个方块由若干 AABB 盒子组成
--
-- ⚠️ 这份数据被**三处**消费，是它们的唯一真源：
--   1. ChunkMeshBuilder：逐盒子发面（渲染）
--   2. World:isSolidAtPoint：碰撞点测试
--   3. World:getSurfaceTopY：落地高度（半砖只有半格高）
-- 任何一处自己另算一套，就会出现"看起来是半砖、走上去像整格"这类错位。
--
-- 盒子坐标是**格内归一化坐标** 0..1：{x0, y0, z0, x1, y1, z1}
-- 结果按 (shape, state[, fenceMask]) 缓存，热路径零分配 —— 调用方**不要修改**返回的表。
-- ====================================================================

local BlockState = require("data.BlockState")

local BlockShapes = {}

-- 形状类型
BlockShapes.SLAB = "slab"
BlockShapes.STAIRS = "stairs"
BlockShapes.FENCE = "fence"
BlockShapes.WALL = "wall"
BlockShapes.DOOR = "door"
BlockShapes.TRAPDOOR = "trapdoor"

-- 尺寸常量（对齐 MC 的 1/16 网格）
local PANEL = 3 / 16      -- 门 / 活板门厚度
local POST_MIN = 6 / 16   -- 栅栏柱
local POST_MAX = 10 / 16
local RAIL_MIN = 7 / 16   -- 栅栏横杆宽度
local RAIL_MAX = 9 / 16

-- ============================================
-- 各形状的盒子构造
-- ============================================

local function buildSlab(state)
    if BlockState.isTopHalf(state) then
        return { { 0, 0.5, 0, 1, 1, 1 } }
    end
    return { { 0, 0, 0, 1, 0.5, 1 } }
end

---楼梯：一块半高底板 + 一块占半格的台阶
---facing = 低的那一侧朝向（放置时朝玩家），台阶在对侧；topHalf = 倒置楼梯
local function buildStairs(state)
    local facing = BlockState.facing(state)
    local top = BlockState.isTopHalf(state)

    local baseY0, baseY1, stepY0, stepY1
    if top then
        baseY0, baseY1 = 0.5, 1.0      -- 倒置：整板在上
        stepY0, stepY1 = 0.0, 0.5      -- 台阶在下
    else
        baseY0, baseY1 = 0.0, 0.5
        stepY0, stepY1 = 0.5, 1.0
    end

    local step
    if facing == BlockState.FACING_PX then
        step = { 0, stepY0, 0, 0.5, stepY1, 1 }
    elseif facing == BlockState.FACING_NX then
        step = { 0.5, stepY0, 0, 1, stepY1, 1 }
    elseif facing == BlockState.FACING_PZ then
        step = { 0, stepY0, 0, 1, stepY1, 0.5 }
    else -- FACING_NZ
        step = { 0, stepY0, 0.5, 1, stepY1, 1 }
    end

    return { { 0, baseY0, 0, 1, baseY1, 1 }, step }
end

---栅栏：中柱 + 按邻接关系伸出的横杆（两根，上下）
---@param mask number 位掩码：+X=1, -X=2, +Z=4, -Z=8
local function buildFence(mask)
    ---@type number[][]
    local boxes = { { POST_MIN, 0, POST_MIN, POST_MAX, 1, POST_MAX } }

    local function rails(x0, z0, x1, z1)
        boxes[#boxes + 1] = { x0, 6 / 16, z0, x1, 9 / 16, z1 }
        boxes[#boxes + 1] = { x0, 12 / 16, z0, x1, 15 / 16, z1 }
    end

    if (mask % 2) == 1 then rails(POST_MAX, RAIL_MIN, 1, RAIL_MAX) end                     -- +X
    if (math.floor(mask / 2) % 2) == 1 then rails(0, RAIL_MIN, POST_MIN, RAIL_MAX) end      -- -X
    if (math.floor(mask / 4) % 2) == 1 then rails(RAIL_MIN, POST_MAX, RAIL_MAX, 1) end      -- +Z
    if (math.floor(mask / 8) % 2) == 1 then rails(RAIL_MIN, 0, RAIL_MAX, POST_MIN) end      -- -Z

    return boxes
end

---墙（圆石墙）：比栅栏粗一半的柱 + 与邻居相连的实心段
---石质材料不能用栅栏那种 4/16 细柱：贴图只取到 tile 的一小片，圆石那种高对比
---纹理会糊成黑白噪点。8/16 的墙体既是原版做法，纹理也读得出来
---@param mask number 位掩码：+X=1, -X=2, +Z=4, -Z=8
local function buildWall(mask)
    local POST_LO, POST_HI = 4 / 16, 12 / 16
    local SEG_LO, SEG_HI = 5 / 16, 11 / 16   -- 相连段比柱子略窄，看得出层次
    local SEG_TOP = 13 / 16                  -- 段比柱子略矮（原版墙也是这样）

    ---@type number[][]
    local boxes = { { POST_LO, 0, POST_LO, POST_HI, 1, POST_HI } }

    if (mask % 2) == 1 then                                  -- +X
        boxes[#boxes + 1] = { POST_HI, 0, SEG_LO, 1, SEG_TOP, SEG_HI }
    end
    if (math.floor(mask / 2) % 2) == 1 then                  -- -X
        boxes[#boxes + 1] = { 0, 0, SEG_LO, POST_LO, SEG_TOP, SEG_HI }
    end
    if (math.floor(mask / 4) % 2) == 1 then                  -- +Z
        boxes[#boxes + 1] = { SEG_LO, 0, POST_HI, SEG_HI, SEG_TOP, 1 }
    end
    if (math.floor(mask / 8) % 2) == 1 then                  -- -Z
        boxes[#boxes + 1] = { SEG_LO, 0, 0, SEG_HI, SEG_TOP, POST_LO }
    end

    return boxes
end

---门：贴在 facing 那一侧的薄板；开门时绕门轴转 90°，转向由 hinge 决定
local function buildDoor(state)
    local facing = BlockState.facing(state)
    local open = BlockState.isOpen(state)
    local hingeRight = BlockState.isHingeRight(state)

    if not open then
        if facing == BlockState.FACING_PX then
            return { { 1 - PANEL, 0, 0, 1, 1, 1 } }
        elseif facing == BlockState.FACING_NX then
            return { { 0, 0, 0, PANEL, 1, 1 } }
        elseif facing == BlockState.FACING_PZ then
            return { { 0, 0, 1 - PANEL, 1, 1, 1 } }
        else
            return { { 0, 0, 0, 1, 1, PANEL } }
        end
    end

    -- 开门：门板转到与原朝向垂直的一侧；hinge 决定贴哪一头
    -- （双开门就是靠这两个方向互为镜像，从中间往两边开）
    if facing == BlockState.FACING_PX or facing == BlockState.FACING_NX then
        if hingeRight then
            return { { 0, 0, 1 - PANEL, 1, 1, 1 } }
        end
        return { { 0, 0, 0, 1, 1, PANEL } }
    end
    if hingeRight then
        return { { 1 - PANEL, 0, 0, 1, 1, 1 } }
    end
    return { { 0, 0, 0, PANEL, 1, 1 } }
end

---活板门：关=贴地/贴顶的薄板，开=竖起贴在 facing 侧
local function buildTrapdoor(state)
    if BlockState.isOpen(state) then
        local facing = BlockState.facing(state)
        if facing == BlockState.FACING_PX then
            return { { 1 - PANEL, 0, 0, 1, 1, 1 } }
        elseif facing == BlockState.FACING_NX then
            return { { 0, 0, 0, PANEL, 1, 1 } }
        elseif facing == BlockState.FACING_PZ then
            return { { 0, 0, 1 - PANEL, 1, 1, 1 } }
        else
            return { { 0, 0, 0, 1, 1, PANEL } }
        end
    end
    if BlockState.isTopHalf(state) then
        return { { 0, 1 - PANEL, 0, 1, 1, 1 } }
    end
    return { { 0, 0, 0, 1, PANEL, 1 } }
end

local BUILDERS = {
    [BlockShapes.SLAB] = buildSlab,
    [BlockShapes.STAIRS] = buildStairs,
    [BlockShapes.DOOR] = buildDoor,
    [BlockShapes.TRAPDOOR] = buildTrapdoor,
}

-- ============================================
-- 缓存（状态组合有限，构造一次复用）
-- ============================================

local cache = {}         -- cache[shape][state] = boxes
local connectedCache = { [BlockShapes.FENCE] = {}, [BlockShapes.WALL] = {} }  -- [shape][mask] = boxes

---形状是否按邻居连接（栅栏 / 墙）：决定要不要算邻接掩码
---@param shape string|nil
---@return boolean
function BlockShapes.isConnecting(shape)
    return shape == BlockShapes.FENCE or shape == BlockShapes.WALL
end

---取形状盒子列表
---@param shape string|nil 形状类型（nil = 整格方块）
---@param state number|nil 方块状态
---@param fenceMask number|nil 栅栏邻接掩码（仅 FENCE 用，默认 0）
---@return table|nil boxes 只读的盒子数组；shape 为 nil 时返回 nil
function BlockShapes.get(shape, state, fenceMask)
    if not shape then return nil end

    if BlockShapes.isConnecting(shape) then
        local mask = fenceMask or 0
        local byMask = connectedCache[shape]
        local boxes = byMask[mask]
        if not boxes then
            boxes = (shape == BlockShapes.WALL) and buildWall(mask) or buildFence(mask)
            byMask[mask] = boxes
        end
        return boxes
    end

    local builder = BUILDERS[shape]
    if not builder then return nil end

    state = state or 0
    local byState = cache[shape]
    if not byState then
        byState = {}
        cache[shape] = byState
    end
    local boxes = byState[state]
    if not boxes then
        boxes = builder(state)
        byState[state] = boxes
    end
    return boxes
end

-- ============================================
-- 栅栏连接判据（渲染与碰撞共用，避免"看着连上了、走过去没挡"）
-- ============================================

-- 4 个水平方向及其掩码位：+X=1 -X=2 +Z=4 -Z=8
BlockShapes.FENCE_DIRS = {
    { 1, 0, 1 },
    { -1, 0, 2 },
    { 0, 1, 4 },
    { 0, -1, 8 },
}

---栅栏/墙是否与某个邻块相连：相邻的同类连接件，或任何遮挡实体（贴墙时收边）
---调用方各自查表（渲染侧走 LUT、碰撞侧走 BlockRegistry），规则只在这里写一次
---@param selfShape string 自己的形状（栅栏只连栅栏、墙只连墙）
---@param adjShape string|nil 邻块形状
---@param adjOccludes boolean|nil 邻块是否遮挡邻面
---@return boolean
function BlockShapes.fenceConnects(selfShape, adjShape, adjOccludes)
    return adjShape == selfShape or adjOccludes == true
end

-- ============================================
-- 碰撞查询（供 World 复用）
-- ============================================

---点（格内归一化坐标）是否落在任一盒子里
---@param boxes table
---@return boolean
function BlockShapes.pointInside(boxes, fx, fy, fz)
    for i = 1, #boxes do
        local b = boxes[i]
        if fx >= b[1] and fx <= b[4]
            and fy >= b[2] and fy <= b[5]
            and fz >= b[3] and fz <= b[6] then
            return true
        end
    end
    return false
end

---覆盖 (fx, fz) 的盒子里最高的顶面高度（0..1）；没有盒子覆盖则返回 nil
---@param boxes table
---@return number|nil
function BlockShapes.topAt(boxes, fx, fz)
    local best = nil
    for i = 1, #boxes do
        local b = boxes[i]
        if fx >= b[1] and fx <= b[4] and fz >= b[3] and fz <= b[6] then
            if not best or b[5] > best then best = b[5] end
        end
    end
    return best
end

---所有盒子里最高的顶面（不看水平位置，落地扫描的粗略上界用）
---@param boxes table
---@return number
function BlockShapes.maxTop(boxes)
    local best = 0
    for i = 1, #boxes do
        if boxes[i][5] > best then best = boxes[i][5] end
    end
    return best
end

return BlockShapes
