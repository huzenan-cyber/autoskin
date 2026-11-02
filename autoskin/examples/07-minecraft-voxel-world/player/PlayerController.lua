-- ====================================================================
-- player/PlayerController.lua
-- 玩家控制器 - 移动和碰撞检测
-- ====================================================================

local Config = require("config.GameConfig")
local Blocks = require("data.BlockRegistry")

local BLOCK_SIZE_M = Config.World.BLOCK_SIZE
local floor = math.floor

-- 能自动迈上去的最大高度（半砖 0.5 格、楼梯每阶 0.5 格都在范围内）
local STEP_MAX = 0.65 * BLOCK_SIZE_M

---扫一列采样点看是否撞到实体，并返回撞到的障碍里最高的顶面
---固定的那个轴传坐标、要扫的那个轴传 nil（X 位移时固定 X 扫 Z，反之亦然）
---模块级函数而非闭包：这是每帧都跑的路径，避免每帧新建闭包
---@return boolean collided
---@return number|nil obstacleTop 障碍顶面世界 Y
local function probeColumn(world, currentPos, fixedX, fixedZ, testRadius, playerHeightWorld)
    local collided = false
    local obstacleTop = nil

    for offset = -testRadius, testRadius, testRadius * 2 do
        for offsetY = 0.3 * BLOCK_SIZE_M, playerHeightWorld - 0.3 * BLOCK_SIZE_M,
            (playerHeightWorld - 0.6 * BLOCK_SIZE_M) / 2 do
            local wx = fixedX or (currentPos.x + offset)
            local wz = fixedZ or (currentPos.z + offset)
            local wy = currentPos.y + offsetY

            if world:isSolidAtPoint(wx, wy, wz) then
                collided = true
                local bx, by, bz = floor(wx / BLOCK_SIZE_M), floor(wy / BLOCK_SIZE_M), floor(wz / BLOCK_SIZE_M)
                local top = world:getSurfaceTopY(bx, by, bz, wx / BLOCK_SIZE_M - bx, wz / BLOCK_SIZE_M - bz)
                if top and (not obstacleTop or top > obstacleTop) then
                    obstacleTop = top
                end
            end
        end
    end

    return collided, obstacleTop
end

---自动上台阶：障碍顶面只高出脚底一点、且抬上去后身体有净空，就直接抬上去。
---半砖与楼梯要能"走上去"就必须有这一步（原来的控制器完全没有台阶逻辑）。
---
---⚠️ 三条约束，少一条就会出怪事：
---  1. **只在地面上生效**（原版 MC 也是）。否则下落时贴着墙按方向键，脚底一进入某个
---     台面 0.65 格范围就会被"吸"上去（跳进坑里会被弹回坑沿、沿竖井下落会被侧面挂住）；
---     上升段则等于凭空多半格跳跃高度。
---  2. 净空检测要覆盖**自由轴的两侧**（与 probeColumn 一致采 ±testRadius），只测中心线
---     会漏掉半个身位上的方块。
---  3. 采样必须取到 `playerHeightWorld - 0.1` 这个上界，否则身体最上面约 0.4 格是盲区，
---     正好能塞进一块贴顶半砖 / 上半门板。
---@param freeAxis string "x" | "z" 位移时需要在其上左右探的那个轴
---@return boolean 是否成功抬升（成功则视为不碰撞）
local function tryStepUp(world, player, currentPos, obstacleTop, atX, atZ, testRadius,
                         playerHeightWorld, freeAxis)
    if not obstacleTop then return false end
    -- 只有站在地面上才允许迈台阶（空中不吸附）
    if not player:getOnGround() then return false end

    local rise = obstacleTop - currentPos.y
    if rise <= 0.01 or rise > STEP_MAX then return false end

    local newFeet = obstacleTop + 0.02
    local yStart = 0.1 * BLOCK_SIZE_M
    local yEnd = playerHeightWorld - 0.1 * BLOCK_SIZE_M
    local yStep = (yEnd - yStart) / 3    -- 保证最后一个采样点正好落在 yEnd

    for _, side in ipairs({ -testRadius, 0, testRadius }) do
        local px = (freeAxis == "x") and (atX + side) or atX
        local pz = (freeAxis == "z") and (atZ + side) or atZ
        for offsetY = yStart, yEnd + 1e-6, yStep do
            if world:isSolidAtPoint(px, newFeet + offsetY, pz) then
                return false
            end
        end
    end

    currentPos.y = newFeet
    return true
end

---@class PlayerController
---@field player Player
---@field world World
local PlayerController = {}
PlayerController.__index = PlayerController

---创建新的玩家控制器
---@param player table Player实例
---@param world table World实例
---@return PlayerController PlayerController实例
function PlayerController.new(player, world)
    local self = setmetatable({}, PlayerController)
    self.player = player
    self.world = world
    self.joystick = nil
    self.jumpButton = nil
    self.mouseLocked = true
    self.flyMode = false  -- 飞行模式
    -- 输入适配器（默认使用本地 input，联网模式可替换）
    self.inputAdapter = nil
    return self
end

---设置输入适配器（联网模式使用）
---@param adapter table { getKeyPress: function(key), getKeyDown: function(key) }
function PlayerController:setInputAdapter(adapter)
    self.inputAdapter = adapter
end

---获取按键按下状态（兼容本地和网络输入）
---@param key Key 按键码
---@return boolean
function PlayerController:isKeyDown(key)
    if self.inputAdapter and self.inputAdapter.getKeyDown then
        return self.inputAdapter:getKeyDown(key)
    end
    return input:GetKeyDown(key)
end

---获取按键刚按下状态（兼容本地和网络输入）
---@param key Key 按键码
---@return boolean
function PlayerController:isKeyPress(key)
    if self.inputAdapter and self.inputAdapter.getKeyPress then
        return self.inputAdapter:getKeyPress(key)
    end
    return input:GetKeyPress(key)
end

---设置虚拟摇杆
---@param joystick table|nil 虚拟摇杆对象
function PlayerController:setJoystick(joystick)
    self.joystick = joystick
end

---设置跳跃按钮
---@param jumpButton table 跳跃按钮对象
function PlayerController:setJumpButton(jumpButton)
    self.jumpButton = jumpButton
end

---设置鼠标锁定状态
---@param locked boolean 是否锁定
function PlayerController:setMouseLocked(locked)
    self.mouseLocked = locked
end

---更新玩家移动
---@param timeStep number 时间步长
function PlayerController:updateMovement(timeStep)
    local player = self.player
    local world = self.world
    local moveDir = Vector3(0, 0, 0)
    
    -- 切换飞行模式（按 F 键）
    if self:isKeyPress(KEY_F) then
        self.flyMode = not self.flyMode
        if self.flyMode then
            print("[Player] 飞行模式开启")
            -- 清除垂直速度
            local velocity = player:getVelocity()
            velocity.y = 0
            player:setVelocity(velocity)
        else
            print("[Player] 飞行模式关闭")
        end
    end
    
    -- ============================================================
    -- 输入处理：统一使用摇杆的 getMovement() 方法
    -- ============================================================
    if self.joystick then
        local moveX, moveY = self.joystick:getMovement()
        moveDir.x = moveX  -- 左右移动
        moveDir.z = moveY  -- 前后移动
    end
    
    -- 根据相机偏航角变换移动方向
    if moveDir:Length() > 0 then
        moveDir = moveDir:Normalized()
        local yawRotation = Quaternion(player:getYaw(), Vector3(0, 1, 0))
        moveDir = yawRotation * moveDir
    end
    
    local velocity = player:getVelocity()
    
    if self.flyMode then
        -- ============================================================
        -- 飞行模式：无重力，Space上升，Shift下降
        -- ============================================================
        local flyVerticalSpeed = Config.Player.FLY_VERTICAL_SPEED

        -- 上升（Space）
        if self:isKeyDown(KEY_SPACE) then
            velocity.y = flyVerticalSpeed
        -- 下降（Shift）
        elseif self:isKeyDown(KEY_SHIFT) then
            velocity.y = -flyVerticalSpeed
        else
            velocity.y = 0  -- 悬停
        end
        player:setVelocity(velocity)
        
        -- 飞行模式移动（无碰撞）
        self:applyFlyMovement(moveDir, timeStep)
    else
        -- ============================================================
        -- 正常模式：有重力，可跳跃
        -- ============================================================
        -- 应用重力
        velocity.y = velocity.y + Config.Player.GRAVITY * timeStep
        player:setVelocity(velocity)
        
        -- 跳跃
        local jumpPressed = self:isKeyPress(KEY_SPACE)
        if self.jumpButton and self.jumpButton.isPressed then
            jumpPressed = true
        end
        if jumpPressed and player:getOnGround() then
            velocity.y = Config.Player.JUMP_SPEED
            player:setVelocity(velocity)
            player:setOnGround(false)
        end
        
        -- 碰撞检测和移动
        self:applyMovement(moveDir, timeStep)
    end
end

---应用移动（带碰撞检测）
---@param moveDir Vector3 移动方向
---@param timeStep number 时间步长
function PlayerController:applyMovement(moveDir, timeStep)
    local player = self.player
    local world = self.world
    local velocity = player:getVelocity()
    local currentPos = player:getPosition()
    
    local BLOCK_SIZE = Config.World.BLOCK_SIZE
    local PLAYER_SPEED = Config.Player.SPEED

    -- 更新水平速度（用于动画检测）
    velocity.x = moveDir.x * PLAYER_SPEED
    velocity.z = moveDir.z * PLAYER_SPEED
    player:setVelocity(velocity)
    local PLAYER_HEIGHT = Config.Player.HEIGHT
    local playerRadius = Config.Player.COLLISION_RADIUS * BLOCK_SIZE
    local playerHeightWorld = PLAYER_HEIGHT * BLOCK_SIZE
    
    -- 碰撞检测容差：避免浮点精度问题导致的"卡墙"
    local SKIN_WIDTH = 0.05
    -- 缩小检测用的半径，避免贴墙时其他轴的检测点进入方块
    local testRadius = playerRadius - SKIN_WIDTH
    
    -- ============================================================
    -- 水平碰撞：走 world:isSolidAtPoint（按半砖/楼梯/栅栏/门的实际盒子测点），
    -- 撞上了先试自动上台阶，迈得上去就不算碰撞
    -- ============================================================

    -- X轴移动碰撞检测
    local newX = currentPos.x + moveDir.x * PLAYER_SPEED * timeStep
    local testX = newX + (moveDir.x > 0 and playerRadius or (moveDir.x < 0 and -playerRadius or 0))
    local collideX, topX = probeColumn(world, currentPos, testX, nil, testRadius, playerHeightWorld)

    -- X 位移时固定 X、在 Z 上左右探（与 probeColumn 的采样面一致）
    if collideX and tryStepUp(world, player, currentPos, topX, testX, currentPos.z,
        testRadius, playerHeightWorld, "z") then
        collideX = false
    end
    if not collideX then
        currentPos.x = newX
    end

    -- Z轴移动碰撞检测（使用更新后的 X 位置）
    local newZ = currentPos.z + moveDir.z * PLAYER_SPEED * timeStep
    local testZ = newZ + (moveDir.z > 0 and playerRadius or (moveDir.z < 0 and -playerRadius or 0))
    local collideZ, topZ = probeColumn(world, currentPos, nil, testZ, testRadius, playerHeightWorld)

    if collideZ and tryStepUp(world, player, currentPos, topZ, currentPos.x, testZ,
        testRadius, playerHeightWorld, "x") then
        collideZ = false
    end
    if not collideZ then
        currentPos.z = newZ
    end
    
    -- Y轴移动（重力/跳跃）碰撞检测
    local newY = currentPos.y + velocity.y * timeStep
    player:setOnGround(false)
    
    -- 下落碰撞检测
    if velocity.y <= 0 then
        local blockBelowBx = math.floor(currentPos.x / BLOCK_SIZE)
        local blockBelowBz = math.floor(currentPos.z / BLOCK_SIZE)
        
        local maxScanDown = 200
        local scanStartY = math.floor(newY / BLOCK_SIZE) + 1
        
        -- 落脚点在格内的比例（半砖/楼梯的顶面按位置不同，栅栏柱只占中间一小块）
        local footFx = currentPos.x / BLOCK_SIZE - blockBelowBx
        local footFz = currentPos.z / BLOCK_SIZE - blockBelowBz

        for scanY = scanStartY, scanStartY - maxScanDown, -1 do
            -- 顶面高度交给 World:getSurfaceTopY：整格返回 (scanY+1)，半砖返回半格，
            -- 该处没有盒子（如栅栏的空隙）返回 nil → 继续往下找
            local blockTopY = world:getSurfaceTopY(blockBelowBx, scanY, blockBelowBz, footFx, footFz)

            if blockTopY then
                if newY <= blockTopY + 0.5 then
                    currentPos.y = blockTopY + 0.01
                    velocity.y = 0
                    player:setVelocity(velocity)
                    player:setOnGround(true)
                    break
                end
            end
        end
        
        if not player:getOnGround() then
            currentPos.y = newY
        end
    -- 上升碰撞检测（撞头）
    elseif velocity.y > 0 then
        local headY = newY + playerHeightWorld
        local headBlockY = math.floor(headY / BLOCK_SIZE)

        -- 撞头也按形状测点：开着的活板门/门不挡头，半砖天花板要撞
        -- （已知取舍：撞到的天花板底面仍按整格算，半砖天花板会早停半格）
        if world:isSolidAtPoint(currentPos.x, headY, currentPos.z) then
            local blockBottomY = headBlockY * BLOCK_SIZE
            currentPos.y = blockBottomY - playerHeightWorld
            velocity.y = 0
            player:setVelocity(velocity)
        else
            currentPos.y = newY
        end
    else
        currentPos.y = newY
    end
    
    player:setPosition(currentPos)
end

---应用飞行移动（无碰撞检测）
---@param moveDir Vector3 移动方向
---@param timeStep number 时间步长
function PlayerController:applyFlyMovement(moveDir, timeStep)
    local player = self.player
    local velocity = player:getVelocity()
    local currentPos = player:getPosition()
    
    local FLY_SPEED = Config.Player.FLY_SPEED

    -- 更新水平速度（用于动画检测）
    velocity.x = moveDir.x * FLY_SPEED
    velocity.z = moveDir.z * FLY_SPEED
    player:setVelocity(velocity)
    
    -- 水平移动
    currentPos.x = currentPos.x + moveDir.x * FLY_SPEED * timeStep
    currentPos.z = currentPos.z + moveDir.z * FLY_SPEED * timeStep
    
    -- 垂直移动
    currentPos.y = currentPos.y + velocity.y * timeStep
    
    player:setPosition(currentPos)
end

---获取飞行模式状态
---@return boolean 是否处于飞行模式
function PlayerController:isFlyMode()
    return self.flyMode
end

---设置飞行模式
---@param enabled boolean 是否开启飞行模式
function PlayerController:setFlyMode(enabled)
    self.flyMode = enabled
    if enabled then
        local velocity = self.player:getVelocity()
        velocity.y = 0
        self.player:setVelocity(velocity)
    end
end

---更新鼠标视角
---@param timeStep number 时间步长
function PlayerController:updateMouseLook(timeStep)
    local player = self.player

    if self.mouseLocked then
        local mouseMove = input.mouseMove
        local sensitivity = Config.Controls.MOUSE_SENSITIVITY
        player:setYaw(player:getYaw() + mouseMove.x * sensitivity)
        player:setPitch(player:getPitch() + mouseMove.y * sensitivity)
    end

    player:updateCamera()
end

---更新外部视角控制（触摸等）
---@param deltaYaw number 偏航角变化
---@param deltaPitch number 俯仰角变化
function PlayerController:applyLookDelta(deltaYaw, deltaPitch)
    local player = self.player
    player:setYaw(player:getYaw() + deltaYaw)
    player:setPitch(player:getPitch() + deltaPitch)
end

return PlayerController
