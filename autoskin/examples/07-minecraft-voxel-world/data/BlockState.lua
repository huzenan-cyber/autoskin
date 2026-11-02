-- ====================================================================
-- data/BlockState.lua
-- 方块状态位域 - 朝向 / 上下半 / 开关
--
-- 每格的状态是一个小整数（当前用到 5 位、最大 31；World:setBlockState 的上限是 255），
-- 存在 World 的 blockState 平行稀疏数组里
-- （与 skyLight / blockLight 同款存储，不动 blocks[idx]，对现有代码零侵入）。
--
--   bit 0-1  facing     朝向：0=+X 1=-X 2=+Z 3=-Z
--   bit 2    topHalf    上半：上半砖 / 倒置楼梯 / 贴顶活板门 / 门的上格
--   bit 3    open       开：门 / 活板门
--   bit 4    hingeRight 门轴在右侧（决定开门往哪边转、把手在哪一侧；双开门靠它镜像）
--
-- 用乘除取模而不是位运算：与 NoiseGenerator 同思路，避开 WASM/PC 的位运算差异。
-- ====================================================================

local BlockState = {}

-- 朝向常量（与 6 邻方向里的水平 4 向对应）
BlockState.FACING_PX = 0
BlockState.FACING_NX = 1
BlockState.FACING_PZ = 2
BlockState.FACING_NZ = 3

-- 朝向 → 单位向量（网格与碰撞都用它，避免各处再写一遍 if）
BlockState.FACING_VEC = {
    [0] = { 1, 0 },
    [1] = { -1, 0 },
    [2] = { 0, 1 },
    [3] = { 0, -1 },
}

local TOP_BIT = 4     -- bit 2
local OPEN_BIT = 8    -- bit 3
local HINGE_BIT = 16  -- bit 4

---组装状态值
---@param facing number|nil 0-3，默认 0
---@param topHalf boolean|nil
---@param open boolean|nil
---@param hingeRight boolean|nil 门轴在右侧
---@return number 0-31
function BlockState.pack(facing, topHalf, open, hingeRight)
    local v = (facing or 0) % 4
    if topHalf then v = v + TOP_BIT end
    if open then v = v + OPEN_BIT end
    if hingeRight then v = v + HINGE_BIT end
    return v
end

---@param state number|nil
---@return number 0-3
function BlockState.facing(state)
    return (state or 0) % 4
end

---@param state number|nil
---@return boolean
function BlockState.isTopHalf(state)
    return (math.floor((state or 0) / TOP_BIT) % 2) == 1
end

---@param state number|nil
---@return boolean
function BlockState.isOpen(state)
    return (math.floor((state or 0) / OPEN_BIT) % 2) == 1
end

---@param state number|nil
---@return boolean 门轴是否在右侧
function BlockState.isHingeRight(state)
    return (math.floor((state or 0) / HINGE_BIT) % 2) == 1
end

---设/清 hinge 位，保留其它位
---@param state number|nil
---@param hingeRight boolean
---@return number
function BlockState.withHinge(state, hingeRight)
    state = state or 0
    local has = BlockState.isHingeRight(state)
    if hingeRight and not has then return state + HINGE_BIT end
    if (not hingeRight) and has then return state - HINGE_BIT end
    return state
end

---翻转 open 位（门/活板门的"使用"）
---@param state number|nil
---@return number 新状态
function BlockState.toggleOpen(state)
    state = state or 0
    if BlockState.isOpen(state) then
        return state - OPEN_BIT
    end
    return state + OPEN_BIT
end

---改朝向、保留其它位
---@param state number|nil
---@param facing number 0-3
---@return number
function BlockState.withFacing(state, facing)
    state = state or 0
    return state - BlockState.facing(state) + (facing % 4)
end

---设/清 topHalf 位，保留其它位
---@param state number|nil
---@param topHalf boolean
---@return number
function BlockState.withTopHalf(state, topHalf)
    state = state or 0
    local has = BlockState.isTopHalf(state)
    if topHalf and not has then return state + TOP_BIT end
    if (not topHalf) and has then return state - TOP_BIT end
    return state
end

---玩家 yaw（度）→ 朝向。放置门/楼梯时用"面向玩家"的 MC 规则：
---取玩家视线的主轴，方块朝向玩家所在的那一侧。
---@param yaw number 玩家 yaw（度，0 = +Z）
---@return number facing 0-3
function BlockState.facingFromYaw(yaw)
    -- 归一到 [0, 360)
    local a = yaw % 360
    if a < 0 then a = a + 360 end
    -- 引擎 yaw=0 看向 +Z；顺时针增大
    if a < 45 or a >= 315 then
        return BlockState.FACING_NZ    -- 玩家看向 +Z → 方块正面朝 -Z（朝玩家）
    elseif a < 135 then
        return BlockState.FACING_NX
    elseif a < 225 then
        return BlockState.FACING_PZ
    else
        return BlockState.FACING_PX
    end
end

return BlockState
