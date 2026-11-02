-- ====================================================================
-- world/ChunkMeshBuilder.lua
-- 区块网格构建器 - 生成区块的可视网格（优化版）
-- 使用高度范围优化，只遍历有方块的高度层
-- ====================================================================

local Config = require("config.GameConfig")
local Blocks = require("data.BlockRegistry")
local BlockShapes = require("data.BlockShapes")
local BlockState = require("data.BlockState")
local TexturePackManager = require("rendering.texturepacks.TexturePackManager")
local TempPool = require("utils.TempPool")

-- 常量本地化（热路径优化）
local CHUNK_SIZE = Config.World.CHUNK_SIZE
local WORLD_HEIGHT = Config.World.WORLD_HEIGHT
local BLOCK_SIZE = Config.World.BLOCK_SIZE
local AIR = Blocks.AIR
local WATER = Blocks.WATER

-- 函数本地化
local pairs = pairs
local floor = math.floor
local tempVec3 = TempPool.tempVec3
local tempVec2 = TempPool.tempVec2

-- ====================================================================
-- 方块属性查找表（模块加载时从 registry 建一次，避免热路径调 Blocks:xxx）
--
-- occludesLUT  是否遮挡邻面 —— 面剔除与顶点 AO 的唯一判据
--              （旧代码在两处硬编码 `~= AIR and ~= WATER and not crossMesh`，
--                玻璃/冰/岩浆这类"实心但不遮挡"的方块无法表达）
-- selfCullLUT  同类相邻是否互相剔除（成片玻璃/冰/水不画内部面）
-- layerLUT     渲染层 → 决定发射到哪个几何体
-- ====================================================================
local occludesLUT = {}
local selfCullLUT = {}
local layerLUT = {}
local shapeLUT = {}      -- 非整格形状类型（半砖/楼梯/栅栏/门/活板门）
local liquidTypes = {}   -- 有序液体方块列表（每种液体一个几何体 + 材质）

for id, block in pairs(Blocks.blocks) do
    shapeLUT[id] = block.shape
    occludesLUT[id] = block.occludes or false
    selfCullLUT[id] = block.selfCull or false
    layerLUT[id] = block.layer
    if block.layer == Blocks.LAYER_LIQUID then
        liquidTypes[#liquidTypes + 1] = id
    end
end
table.sort(liquidTypes)  -- 固定顺序，保证节点创建顺序稳定

local LAYER_SOLID = Blocks.LAYER_SOLID
local LAYER_SHAPE = Blocks.LAYER_SHAPE
local LAYER_CUTOUT = Blocks.LAYER_CUTOUT
local LAYER_TRANSLUCENT = Blocks.LAYER_TRANSLUCENT
local LAYER_LIQUID = Blocks.LAYER_LIQUID
local LAYER_CROSS = Blocks.LAYER_CROSS

-- 本地化 Blocks.blocks 用于快速查找
local BlocksData = Blocks.blocks

-- UV 缓存（在 refreshTexturePack 时重建）
-- uvCache[blockType][faceType] = { u0, v0, u1, v1 }
---@type table<number, table<string, [number, number, number, number]>>
local uvCache = {}
-- 门上半格的贴图（block.upperTexture）：uvCacheUpper[blockType][faceType]
---@type table<number, table<string, [number, number, number, number]>>
local uvCacheUpper = {}
local uvCacheBuilt = false

---@class ChunkMeshBuilder
---@field world World
---@field scene Scene
---@field chunkMaterial Material|nil
---@field waterMaterial Material
---@field crossMeshMaterial Material|nil
---@field textures table
local ChunkMeshBuilder = {}
ChunkMeshBuilder.__index = ChunkMeshBuilder

-- 预分配的颜色常量（避免在循环中创建）
local COLOR_WHITE = Color(1, 1, 1, 1)
local COLOR_WATER = Color(1, 1, 1, 0.7)

-- 立方体面定义（包含切线用于 PBR 法线贴图）
-- tangent.w = 1 表示副切线方向（bitangent = cross(normal, tangent) * tangent.w）
local CUBE_FACES = {
    -- +X 面 (右) - side 纹理
    { normal = Vector3(1, 0, 0), tangent = Vector4(0, 0, -1, 1), faceType = "side", check = {1, 0, 0}, vertices = {
        { pos = { 1, 0, 0 }, uv = { 1, 1 } },
        { pos = { 1, 1, 0 }, uv = { 1, 0 } },
        { pos = { 1, 1, 1 }, uv = { 0, 0 } },
        { pos = { 1, 0, 0 }, uv = { 1, 1 } },
        { pos = { 1, 1, 1 }, uv = { 0, 0 } },
        { pos = { 1, 0, 1 }, uv = { 0, 1 } }
    }},
    -- -X 面 (左)
    { normal = Vector3(-1, 0, 0), tangent = Vector4(0, 0, 1, 1), faceType = "side", check = {-1, 0, 0}, vertices = {
        { pos = { 0, 0, 1 }, uv = { 1, 1 } },
        { pos = { 0, 1, 1 }, uv = { 1, 0 } },
        { pos = { 0, 1, 0 }, uv = { 0, 0 } },
        { pos = { 0, 0, 1 }, uv = { 1, 1 } },
        { pos = { 0, 1, 0 }, uv = { 0, 0 } },
        { pos = { 0, 0, 0 }, uv = { 0, 1 } }
    }},
    -- +Y 面 (顶) - top 纹理
    { normal = Vector3(0, 1, 0), tangent = Vector4(1, 0, 0, 1), faceType = "top", check = {0, 1, 0}, vertices = {
        { pos = { 0, 1, 0 }, uv = { 0, 0 } },
        { pos = { 0, 1, 1 }, uv = { 0, 1 } },
        { pos = { 1, 1, 1 }, uv = { 1, 1 } },
        { pos = { 0, 1, 0 }, uv = { 0, 0 } },
        { pos = { 1, 1, 1 }, uv = { 1, 1 } },
        { pos = { 1, 1, 0 }, uv = { 1, 0 } }
    }},
    -- -Y 面 (底) - bottom 纹理
    { normal = Vector3(0, -1, 0), tangent = Vector4(1, 0, 0, 1), faceType = "bottom", check = {0, -1, 0}, vertices = {
        { pos = { 0, 0, 1 }, uv = { 0, 1 } },
        { pos = { 0, 0, 0 }, uv = { 0, 0 } },
        { pos = { 1, 0, 0 }, uv = { 1, 0 } },
        { pos = { 0, 0, 1 }, uv = { 0, 1 } },
        { pos = { 1, 0, 0 }, uv = { 1, 0 } },
        { pos = { 1, 0, 1 }, uv = { 1, 1 } }
    }},
    -- +Z 面 (前)
    { normal = Vector3(0, 0, 1), tangent = Vector4(1, 0, 0, 1), faceType = "side", check = {0, 0, 1}, vertices = {
        { pos = { 0, 0, 1 }, uv = { 0, 1 } },
        { pos = { 1, 0, 1 }, uv = { 1, 1 } },
        { pos = { 1, 1, 1 }, uv = { 1, 0 } },
        { pos = { 0, 0, 1 }, uv = { 0, 1 } },
        { pos = { 1, 1, 1 }, uv = { 1, 0 } },
        { pos = { 0, 1, 1 }, uv = { 0, 0 } }
    }},
    -- -Z 面 (后)
    { normal = Vector3(0, 0, -1), tangent = Vector4(-1, 0, 0, 1), faceType = "side", check = {0, 0, -1}, vertices = {
        { pos = { 1, 0, 0 }, uv = { 0, 1 } },
        { pos = { 0, 0, 0 }, uv = { 1, 1 } },
        { pos = { 0, 1, 0 }, uv = { 1, 0 } },
        { pos = { 1, 0, 0 }, uv = { 0, 1 } },
        { pos = { 0, 1, 0 }, uv = { 1, 0 } },
        { pos = { 1, 1, 0 }, uv = { 0, 0 } }
    }}
}

-- 交叉网格面定义（X形，用于装饰草等）
-- 两个对角交叉的面片，材质使用 CULL_NONE 实现双面渲染
-- 只需要2个面，不需要正反面（避免 Z-fighting 闪烁）
local CROSS_HEIGHT = 0.7 -- 草/花的高度

-- 正确的交叉网格：两个面从方块对角穿过，在中心 (0.5, y, 0.5) 相交
local CROSS_MESH_FACES = {
    -- 对角面1 (从 (0,0) 到 (1,1)) - 穿过方块中心
    { normal = Vector3(0.707, 0, 0.707), tangent = Vector4(0.707, 0, -0.707, 1), faceType = "side", vertices = {
        { pos = { 0, 0, 0 }, uv = { 0, 1 } },
        { pos = { 1, 0, 1 }, uv = { 1, 1 } },
        { pos = { 1, CROSS_HEIGHT, 1 }, uv = { 1, 0 } },
        { pos = { 0, 0, 0 }, uv = { 0, 1 } },
        { pos = { 1, CROSS_HEIGHT, 1 }, uv = { 1, 0 } },
        { pos = { 0, CROSS_HEIGHT, 0 }, uv = { 0, 0 } }
    }},
    -- 对角面2 (从 (1,0) 到 (0,1)) - 与面1在中心相交
    { normal = Vector3(0.707, 0, -0.707), tangent = Vector4(0.707, 0, 0.707, 1), faceType = "side", vertices = {
        { pos = { 1, 0, 0 }, uv = { 0, 1 } },
        { pos = { 0, 0, 1 }, uv = { 1, 1 } },
        { pos = { 0, CROSS_HEIGHT, 1 }, uv = { 1, 0 } },
        { pos = { 1, 0, 0 }, uv = { 0, 1 } },
        { pos = { 0, CROSS_HEIGHT, 1 }, uv = { 1, 0 } },
        { pos = { 1, CROSS_HEIGHT, 0 }, uv = { 0, 0 } }
    }}
}

-- 预计算数组长度（避免循环中重复计算）
local CUBE_FACES_COUNT = #CUBE_FACES
local CROSS_MESH_FACES_COUNT = #CROSS_MESH_FACES
local VERTICES_PER_FACE = 6  -- 每个面固定 6 个顶点

-- ====================================================================
-- 顶点环境光遮蔽 (Ambient Occlusion)
-- 经典 Minecraft 风格：每个面的角顶点按"面外一层"相邻 3 个方块（2 边 + 1 对角）
-- 的遮挡算 0-3 档，烘焙进顶点色。LitSolid.glsl 中顶点色乘 albedo，故同时调制
-- 环境光与直射光。不增加顶点数 / draw call，纯改顶点色。
-- ====================================================================
local AO_ENABLED = true

-- AO 档位 → 亮度系数（留最低值，避免凹角纯黑）。0=完全夹角最暗，3=无遮挡
local AO_COLORS = {
    [0] = Color(0.25, 0.25, 0.25, 1),
    [1] = Color(0.50, 0.50, 0.50, 1),
    [2] = Color(0.75, 0.75, 0.75, 1),
    [3] = Color(1.00, 1.00, 1.00, 1),
}

-- 为每个立方体面预计算 AO 采样轴：面内两个切向轴的单位偏移 {dx,dy,dz} 及其在 pos 中的分量下标(1=x,2=y,3=z)
for _, face in ipairs(CUBE_FACES) do
    local c = face.check
    if c[1] ~= 0 then          -- 法线沿 X → 切向 Y,Z
        face.aoTanA = { 0, 1, 0 }; face.aoAxisA = 2
        face.aoTanB = { 0, 0, 1 }; face.aoAxisB = 3
    elseif c[2] ~= 0 then      -- 法线沿 Y → 切向 X,Z
        face.aoTanA = { 1, 0, 0 }; face.aoAxisA = 1
        face.aoTanB = { 0, 0, 1 }; face.aoAxisB = 3
    else                       -- 法线沿 Z → 切向 X,Y
        face.aoTanA = { 1, 0, 0 }; face.aoAxisA = 1
        face.aoTanB = { 0, 1, 0 }; face.aoAxisB = 2
    end
end

-- ====================================================================
-- 非整格方块（半砖/楼梯/栅栏/门/活板门）发面用的两张附表
--
-- FACE_UV_MAP: 该面的 UV 是格内坐标的哪两个轴（1=x 2=y 3=z）以及是否翻转。
--   整格方块的 UV 直接写在 CUBE_FACES 的顶点上；盒子只占格子一部分时必须按
--   盒子在这两个轴上的范围取 tile 的**子矩形**，否则贴图会被拉伸成整块。
-- FACE_FLUSH: 该面贴在格子的哪个边界上（轴 + 是否是最大侧）。
--   与格边界齐平的面才参与邻块剔除；盒子内部的面恒发射。
-- ====================================================================
local FACE_UV_MAP = {
    { 3, true, 2, true },    -- +X: u = 1-z, v = 1-y
    { 3, false, 2, true },   -- -X: u = z,   v = 1-y
    { 1, false, 3, false },  -- +Y: u = x,   v = z
    { 1, false, 3, false },  -- -Y: u = x,   v = z
    { 1, false, 2, true },   -- +Z: u = x,   v = 1-y
    { 1, true, 2, true },    -- -Z: u = 1-x, v = 1-y
}
local FACE_FLUSH = {
    { 1, true }, { 1, false },   -- +X / -X
    { 2, true }, { 2, false },   -- +Y / -Y
    { 3, true }, { 3, false },   -- +Z / -Z
}

-- 每个面 6 顶点 AO 颜色的复用缓冲（避免每面分配 table；单线程顺序消费，安全）
local _aoColorBuf = { COLOR_WHITE, COLOR_WHITE, COLOR_WHITE, COLOR_WHITE, COLOR_WHITE, COLOR_WHITE }

local CHUNK_SIZE_M1_AO = CHUNK_SIZE - 1

---采样 (lx,lz,y) 处方块类型，封装跨 chunk 边界寻址（替代各处内联 seam 逻辑）。
---lx/lz 可越界 -1..CHUNK_SIZE：单边界访问邻接 chunk；对角同时越界则近似为 AIR（不预加载对角 chunk）。
---@return number blockType
local function sampleBlock(blocks, blocksNX, blocksPX, blocksNZ, blocksPZ, lx, lz, y)
    if y < 0 or y >= WORLD_HEIGHT then return AIR end
    local xOut = (lx < 0) and -1 or ((lx > CHUNK_SIZE_M1_AO) and 1 or 0)
    local zOut = (lz < 0) and -1 or ((lz > CHUNK_SIZE_M1_AO) and 1 or 0)
    if xOut ~= 0 and zOut ~= 0 then
        return AIR  -- 对角跨界：近似不遮挡（边界角 AO 的可接受误差）
    elseif xOut < 0 then
        return blocksNX and (blocksNX[y * 256 + lz * 16 + CHUNK_SIZE_M1_AO] or AIR) or AIR
    elseif xOut > 0 then
        return blocksPX and (blocksPX[y * 256 + lz * 16] or AIR) or AIR
    elseif zOut < 0 then
        return blocksNZ and (blocksNZ[y * 256 + CHUNK_SIZE_M1_AO * 16 + lx] or AIR) or AIR
    elseif zOut > 0 then
        return blocksPZ and (blocksPZ[y * 256 + lx] or AIR) or AIR
    else
        return blocks[y * 256 + lz * 16 + lx] or AIR
    end
end

---方块是否构成 AO 遮挡（空气/液体/交叉网格草/玻璃/冰都不遮挡，与原版一致）
local function isAOOccluder(blockType)
    return occludesLUT[blockType] == true
end

---面是否需要发射：邻块不遮挡，且不是"同类自剔除"（成片玻璃/冰/水的内部面）
---统一了旧代码里 solid 面（AIR/WATER/cross）与水面（仅 AIR）两套不同判据
---@param blockType number 当前方块
---@param adjBlock number 邻块
---@return boolean
local function faceVisible(blockType, adjBlock)
    if occludesLUT[adjBlock] then return false end
    if adjBlock == blockType and selfCullLUT[blockType] then return false end
    return true
end

---经典顶点 AO：s1/s2=两条边邻居遮挡，cnr=对角邻居遮挡 → 0(最暗)..3(无遮挡)
local function vertexAOLevel(s1, s2, cnr)
    if s1 and s2 then return 0 end
    return 3 - ((s1 and 1 or 0) + (s2 and 1 or 0) + (cnr and 1 or 0))
end

---计算一个 solid 面 6 个顶点的 AO 颜色，填入复用缓冲并返回。两条 build 路径共用，避免逻辑分叉。
---优化：面外一层的 8 个邻居（4 边 + 4 角）只采样一次，各角复用 —— 与逐顶点采样 bit 等价，采样 18→8。
local function computeFaceAO(face, lx, lz, y, blocks, blocksNX, blocksPX, blocksNZ, blocksPZ)
    local c = face.check
    local cx, cy, cz = lx + c[1], y + c[2], lz + c[3]   -- 面外一层中心（正对面的那一格，恒为空气）
    local tA, tB = face.aoTanA, face.aoTanB
    local axisA, axisB = face.aoAxisA, face.aoAxisB
    -- 8 邻居遮挡（沿切向 A/B 的 +/-）；注意 sampleBlock 形参顺序为 (.., lx, lz, y)
    local eAp = isAOOccluder(sampleBlock(blocks, blocksNX, blocksPX, blocksNZ, blocksPZ, cx + tA[1], cz + tA[3], cy + tA[2]))
    local eAn = isAOOccluder(sampleBlock(blocks, blocksNX, blocksPX, blocksNZ, blocksPZ, cx - tA[1], cz - tA[3], cy - tA[2]))
    local eBp = isAOOccluder(sampleBlock(blocks, blocksNX, blocksPX, blocksNZ, blocksPZ, cx + tB[1], cz + tB[3], cy + tB[2]))
    local eBn = isAOOccluder(sampleBlock(blocks, blocksNX, blocksPX, blocksNZ, blocksPZ, cx - tB[1], cz - tB[3], cy - tB[2]))
    local cPP = isAOOccluder(sampleBlock(blocks, blocksNX, blocksPX, blocksNZ, blocksPZ, cx + tA[1] + tB[1], cz + tA[3] + tB[3], cy + tA[2] + tB[2]))
    local cPN = isAOOccluder(sampleBlock(blocks, blocksNX, blocksPX, blocksNZ, blocksPZ, cx + tA[1] - tB[1], cz + tA[3] - tB[3], cy + tA[2] - tB[2]))
    local cNP = isAOOccluder(sampleBlock(blocks, blocksNX, blocksPX, blocksNZ, blocksPZ, cx - tA[1] + tB[1], cz - tA[3] + tB[3], cy - tA[2] + tB[2]))
    local cNN = isAOOccluder(sampleBlock(blocks, blocksNX, blocksPX, blocksNZ, blocksPZ, cx - tA[1] - tB[1], cz - tA[3] - tB[3], cy - tA[2] - tB[2]))
    local vertices = face.vertices
    for vi = 1, VERTICES_PER_FACE do
        local vpos = vertices[vi].pos
        -- 用 if/else 直接选（邻居是 boolean，不能用 and/or 三元，否则 false 邻居会被误判）
        local s1, s2, cnr
        if vpos[axisA] == 1 then
            s1 = eAp
            if vpos[axisB] == 1 then s2 = eBp; cnr = cPP else s2 = eBn; cnr = cPN end
        else
            s1 = eAn
            if vpos[axisB] == 1 then s2 = eBp; cnr = cNP else s2 = eBn; cnr = cNN end
        end
        _aoColorBuf[vi] = AO_COLORS[vertexAOLevel(s1, s2, cnr)]
    end
    return _aoColorBuf
end

---发射一个 solid 面（6 顶点，含 AO 顶点色），返回新增顶点数。
---F1：sync / async 两条路径共用同一发射逻辑（现已统一走 buildRange → emitBlockAt），
---后续 Phase B 接入光照只需改这一处，消除双副本分叉风险。
-- L2 光照：最低环境光系数，防止凹处/地下全黑（无昼夜时白天 sky=15→shade=1，地下 sky=0→MIN_AMBIENT）
local MIN_AMBIENT = 0.05

local function emitSolidFace(geometry, face, worldBaseX, worldBaseY, worldBaseZ,
                            blockType, lx, lz, y, blocks, blocksNX, blocksPX, blocksNZ, blocksPZ,
                            world, startX, startZ)
    local uv = uvCache[blockType][face.faceType]
    local u0, v0, u1, v1 = uv[1], uv[2], uv[3], uv[4]
    local vertices = face.vertices
    local faceNormal = face.normal
    local faceTangent = face.tangent
    -- 顶点 AO：按相邻方块算每个角的遮挡，烘焙进顶点色
    local aoCols = AO_ENABLED
        and computeFaceAO(face, lx, lz, y, blocks, blocksNX, blocksPX, blocksNZ, blocksPZ)
        or nil
    -- L2 光照：取面外一层格的 skyLight/blockLight 作面级亮度（avg4 平滑留待后续）
    local c = face.check
    local nbx, nby, nbz = startX + lx + c[1], y + c[2], startZ + lz + c[3]
    local lv = world:getSkyLight(nbx, nby, nbz) * (world.sunFactor or 1)  -- L5: 天光随昼夜缩放
    local bl = world:getBlockLight(nbx, nby, nbz)                         -- 方块光(火把)不随昼夜
    if bl > lv then lv = bl end                 -- max(sky×sun, block)
    if lv > 15 then lv = 15 end                 -- sunFactor>1 时钳制，防顶点色分量溢出/过曝
    local shade = lv / 15
    if shade < MIN_AMBIENT then shade = MIN_AMBIENT end
    -- 无 AO 时预算一个 shaded white 常量，避免顶点循环内每顶点分配 Color
    -- （AO 开启时各顶点档色不同，无法预算，仍需逐顶点构造）
    local shadedWhite = (not aoCols) and Color(shade, shade, shade, 1) or nil
    for vi = 1, VERTICES_PER_FACE do
        local v = vertices[vi]
        local vpos, vuv = v.pos, v.uv
        geometry:DefineVertex(tempVec3(
            worldBaseX + vpos[1] * BLOCK_SIZE,
            worldBaseY + vpos[2] * BLOCK_SIZE,
            worldBaseZ + vpos[3] * BLOCK_SIZE
        ))
        geometry:DefineNormal(faceNormal)
        geometry:DefineTangent(faceTangent)
        geometry:DefineTexCoord(tempVec2(
            u0 + vuv[1] * (u1 - u0),
            v0 + vuv[2] * (v1 - v0)
        ))
        -- AO 档色 × 光照 shade（合流：LitSolid 顶点色乘 albedo，等价同时调制环境光+直射光）
        if aoCols then
            local ao = aoCols[vi]
            geometry:DefineColor(Color(ao.r * shade, ao.g * shade, ao.b * shade, 1))
        else
            geometry:DefineColor(shadedWhite)
        end
    end
    return VERTICES_PER_FACE
end

-- ====================================================================
-- 几何体槽位（渲染层 → 节点 / 材质 / 阴影）
--
-- 每个 chunk 按需创建这些几何体；空的在提交阶段 Remove()。
-- solid 直接挂在 chunk 节点上（沿用旧结构），其余各占一个子节点。
-- ====================================================================

-- 液体方块 → 槽位 key（预计算，避免热路径拼字符串）
local LIQUID_SLOT_KEY = {}
for _, id in ipairs(liquidTypes) do
    LIQUID_SLOT_KEY[id] = "liquid_" .. id
end

local GEOMETRY_SLOTS = {
    { key = "solid",       nodeName = nil,           material = "chunk",       castShadows = true },
    { key = "cutout",      nodeName = "Cutout",      material = "cutout",      castShadows = true },
    { key = "translucent", nodeName = "Translucent", material = "translucent", castShadows = false },
    { key = "cross",       nodeName = "CrossMesh",   material = "cross",       castShadows = false },
}
for _, id in ipairs(liquidTypes) do
    GEOMETRY_SLOTS[#GEOMETRY_SLOTS + 1] = {
        key = LIQUID_SLOT_KEY[id],
        nodeName = "Liquid_" .. (BlocksData[id] and BlocksData[id].name or tostring(id)),
        material = "liquid",
        blockType = id,
        castShadows = false,
    }
end

-- 液体渲染风格：
--   水：固定顶点色 + 顶面下沉 0.1，光影交给 SingleLayerWater 材质
--   岩浆：unlit 满亮 + 轻微过曝。**不能走受光材质 + 烘焙顶点色**——露天白天
--         skyLight=15、shade 恒为 1，岩浆和旁边的普通方块一样亮，"自发光"看不出来；
--         unlit 让它不吃太阳光与 AO，夜里/洞里/阴影里都保持同一亮度，才读得出在发光
--   未来新增的液体不给 style 时，退回受光的图集材质（旧行为）
local LAVA = Blocks.LAVA
local LIQUID_STYLE = {
    [WATER] = { flatColor = COLOR_WATER, surfaceDrop = 0.1, material = "water" },
    [LAVA] = { flatColor = COLOR_WHITE, surfaceDrop = 0.0, material = "unlit", overBright = 1.45 },
}
local LIQUID_STYLE_DEFAULT = {}

---发射一个交叉网格方块（X 形插片），返回新增顶点数
local function emitCrossBlock(ctx, geometry, blockType, worldBaseX, worldBaseY, worldBaseZ)
    local uv = uvCache[blockType]["side"]
    local u0, v0, u1, v1 = uv[1], uv[2], uv[3], uv[4]
    local added = 0

    for fi = 1, CROSS_MESH_FACES_COUNT do
        local face = CROSS_MESH_FACES[fi]
        local vertices = face.vertices
        local faceNormal = face.normal
        local faceTangent = face.tangent
        for vi = 1, VERTICES_PER_FACE do
            local v = vertices[vi]
            local vpos, vuv = v.pos, v.uv
            geometry:DefineVertex(tempVec3(
                worldBaseX + vpos[1] * BLOCK_SIZE,
                worldBaseY + vpos[2] * BLOCK_SIZE,
                worldBaseZ + vpos[3] * BLOCK_SIZE
            ))
            geometry:DefineNormal(faceNormal)
            geometry:DefineTangent(faceTangent)
            geometry:DefineTexCoord(tempVec2(
                u0 + vuv[1] * (u1 - u0),
                v0 + vuv[2] * (v1 - v0)
            ))
            geometry:DefineColor(COLOR_WHITE)
            added = added + 1
        end
    end
    return added
end

---区块内部格的邻块直查（热路径：避免每面一次 sampleBlock 调用）
---仅当 lx/lz 都不在边界、且 y±1 不越界时可用，其余情况回退 sampleBlock
local INTERIOR_MAX = CHUNK_SIZE - 2

---发射一个立方体方块（solid / cutout / translucent 共用；顶点色含 AO + 光照）
local function emitCubeBlock(ctx, geometry, blockType, lx, lz, y, worldBaseX, worldBaseY, worldBaseZ)
    local blocks, bNX, bPX, bNZ, bPZ = ctx.blocks, ctx.blocksNX, ctx.blocksPX, ctx.blocksNZ, ctx.blocksPZ
    local world, startX, startZ = ctx.world, ctx.startX, ctx.startZ
    local added = 0
    local interior = lx >= 1 and lx <= INTERIOR_MAX and lz >= 1 and lz <= INTERIOR_MAX
        and y >= 1 and y < WORLD_HEIGHT - 1

    for fi = 1, CUBE_FACES_COUNT do
        local face = CUBE_FACES[fi]
        local c = face.check
        local adjBlock
        if interior then
            adjBlock = blocks[(y + c[2]) * 256 + (lz + c[3]) * 16 + (lx + c[1])] or AIR
        else
            adjBlock = sampleBlock(blocks, bNX, bPX, bNZ, bPZ, lx + c[1], lz + c[3], y + c[2])
        end
        if faceVisible(blockType, adjBlock) then
            added = added + emitSolidFace(geometry, face, worldBaseX, worldBaseY, worldBaseZ,
                blockType, lx, lz, y, blocks, bNX, bPX, bNZ, bPZ, world, startX, startZ)
        end
    end
    return added
end

---发射一个液体方块，返回新增顶点数
local function emitLiquidBlock(ctx, geometry, blockType, lx, lz, y, worldBaseX, worldBaseY, worldBaseZ)
    local style = LIQUID_STYLE[blockType] or LIQUID_STYLE_DEFAULT
    local flatColor = style.flatColor
    local surfaceDrop = style.surfaceDrop or 0
    local blocks, bNX, bPX, bNZ, bPZ = ctx.blocks, ctx.blocksNX, ctx.blocksPX, ctx.blocksNZ, ctx.blocksPZ
    local added = 0
    local interior = lx >= 1 and lx <= INTERIOR_MAX and lz >= 1 and lz <= INTERIOR_MAX
        and y >= 1 and y < WORLD_HEIGHT - 1

    for fi = 1, CUBE_FACES_COUNT do
        local face = CUBE_FACES[fi]
        local c = face.check
        local adjBlock
        if interior then
            adjBlock = blocks[(y + c[2]) * 256 + (lz + c[3]) * 16 + (lx + c[1])] or AIR
        else
            adjBlock = sampleBlock(blocks, bNX, bPX, bNZ, bPZ, lx + c[1], lz + c[3], y + c[2])
        end
        if faceVisible(blockType, adjBlock) then
            if flatColor then
                -- 固定顶点色路径（注意：不发 tangent，与水几何体的顶点布局保持一致）
                local uv = uvCache[blockType][face.faceType]
                local u0, v0, u1, v1 = uv[1], uv[2], uv[3], uv[4]
                local vertices = face.vertices
                local faceNormal = face.normal
                local isTopFace = c[2] == 1

                for vi = 1, VERTICES_PER_FACE do
                    local v = vertices[vi]
                    local vpos, vuv = v.pos, v.uv
                    local wy = worldBaseY + vpos[2] * BLOCK_SIZE
                    if isTopFace then
                        wy = wy - surfaceDrop
                    end

                    geometry:DefineVertex(tempVec3(
                        worldBaseX + vpos[1] * BLOCK_SIZE,
                        wy,
                        worldBaseZ + vpos[3] * BLOCK_SIZE
                    ))
                    geometry:DefineNormal(faceNormal)
                    geometry:DefineTexCoord(tempVec2(
                        u0 + vuv[1] * (u1 - u0),
                        v0 + vuv[2] * (v1 - v0)
                    ))
                    geometry:DefineColor(flatColor)
                    added = added + 1
                end
            else
                added = added + emitSolidFace(geometry, face, worldBaseX, worldBaseY, worldBaseZ,
                    blockType, lx, lz, y, blocks, bNX, bPX, bNZ, bPZ, ctx.world, ctx.startX, ctx.startZ)
            end
        end
    end
    return added
end

-- ====================================================================
-- 非整格方块的发射
-- ====================================================================

---形状方块的整块亮度：取 6 邻格里最亮的一格
---（不能像整格方块那样"取面外一格"——盒子内部面的面外就是自己所在的不透明格，
---  光值 0，会把内部面渲成全黑）
---@return number shade 0..1
local function shapeShade(ctx, lx, lz, y)
    local world = ctx.world
    local wx, wz = ctx.startX + lx, ctx.startZ + lz
    local sun = world.sunFactor or 1
    local best = 0

    for fi = 1, CUBE_FACES_COUNT do
        local c = CUBE_FACES[fi].check
        local nx, ny, nz = wx + c[1], y + c[2], wz + c[3]
        local lv = world:getSkyLight(nx, ny, nz) * sun
        local bl = world:getBlockLight(nx, ny, nz)
        if bl > lv then lv = bl end
        if lv > best then best = lv end
    end

    if best > 15 then best = 15 end
    local shade = best / 15
    if shade < MIN_AMBIENT then shade = MIN_AMBIENT end
    return shade
end

---栅栏的邻接掩码（+X=1 -X=2 +Z=4 -Z=8）
---连接规则在 BlockShapes.fenceConnects 单点定义，这里只负责快速查表
local FENCE_DIRS = BlockShapes.FENCE_DIRS

local function fenceMaskAt(ctx, shape, lx, lz, y)
    local blocks, bNX, bPX, bNZ, bPZ = ctx.blocks, ctx.blocksNX, ctx.blocksPX, ctx.blocksNZ, ctx.blocksPZ
    local mask = 0

    for i = 1, 4 do
        local d = FENCE_DIRS[i]
        local adj = sampleBlock(blocks, bNX, bPX, bNZ, bPZ, lx + d[1], lz + d[2], y)
        if BlockShapes.fenceConnects(shape, shapeLUT[adj], occludesLUT[adj]) then
            mask = mask + d[3]
        end
    end
    return mask
end

---发射一个非整格方块（逐 AABB 盒子发面），返回新增顶点数
local function emitShapeBlock(ctx, geometry, blockType, lx, lz, y, worldBaseX, worldBaseY, worldBaseZ)
    local shape = shapeLUT[blockType]
    if not shape then return 0 end

    local world = ctx.world
    local state = world:getBlockState(ctx.startX + lx, y, ctx.startZ + lz)

    local fenceMask = nil
    if BlockShapes.isConnecting(shape) then
        fenceMask = fenceMaskAt(ctx, shape, lx, lz, y)
    end

    local boxes = BlockShapes.get(shape, state, fenceMask)
    if not boxes then return 0 end

    -- 门的上半格换用 upper 贴图
    local uvSet = uvCache[blockType]
    if shape == BlockShapes.DOOR and BlockState.isTopHalf(state) then
        uvSet = uvCacheUpper[blockType] or uvSet
    end

    local shade = shapeShade(ctx, lx, lz, y)
    local color = Color(shade, shade, shade, 1)

    -- 左右不对称的薄板（门/活板门）：正反面不能各自镜像 u，否则把手会跳边。
    -- 统一按一个固定值决定翻不翻：门用 hinge 位（把手在门轴的对侧），活板门恒不翻。
    local isDoor = (shape == BlockShapes.DOOR)
    local asymmetric = isDoor or (shape == BlockShapes.TRAPDOOR)
    local forceFlipU = isDoor and BlockState.isHingeRight(state) or false

    local blocks, bNX, bPX, bNZ, bPZ = ctx.blocks, ctx.blocksNX, ctx.blocksPX, ctx.blocksNZ, ctx.blocksPZ
    local added = 0

    for bi = 1, #boxes do
        local box = boxes[bi]
        -- box = {x0,y0,z0,x1,y1,z1}：按轴下标寻址 → 最小面 box[axis]、最大面 box[axis+3]
        -- （刻意不建 lo/hi 临时表：这是每方块每面都跑的热路径）

        for fi = 1, CUBE_FACES_COUNT do
            local face = CUBE_FACES[fi]
            local flush = FACE_FLUSH[fi]
            local flushAxis, flushAtMax = flush[1], flush[2]

            -- 该面是否贴在格边界上：贴着才参与邻块剔除，盒子内部面恒发射
            local onCellBoundary
            if flushAtMax then
                onCellBoundary = box[flushAxis + 3] >= 1
            else
                onCellBoundary = box[flushAxis] <= 0
            end

            local emit = true
            if onCellBoundary then
                local c = face.check
                local adj = sampleBlock(blocks, bNX, bPX, bNZ, bPZ, lx + c[1], lz + c[3], y + c[2])
                emit = faceVisible(blockType, adj)
            end

            if emit then
                local uv = uvSet[face.faceType]
                local u0, v0, u1, v1 = uv[1], uv[2], uv[3], uv[4]
                local map = FACE_UV_MAP[fi]
                local axisU, flipU, axisV, flipV = map[1], map[2], map[3], map[4]
                -- 门/活板门的贴图左右不对称（把手、门板轮廓）。立方体的 UV 约定让
                -- 正面与背面的 u 互为镜像，于是同一扇门"正面把手在右、背面把手在左"，
                -- 绕到门后面会看到把手跳到另一侧。这里对这类薄板关掉 u 翻转，
                -- 让贴图的 u 恒定映射到同一个物理轴（代价是背面看到的图是镜像的，
                -- 与原版门的处理一致）
                if asymmetric then flipU = forceFlipU end
                local vertices = face.vertices

                for vi = 1, VERTICES_PER_FACE do
                    local vpos = vertices[vi].pos
                    -- 单位立方体顶点 → 盒子顶点（分量 0 取盒子最小面、1 取最大面）
                    local cx = (vpos[1] == 1) and box[4] or box[1]
                    local cy = (vpos[2] == 1) and box[5] or box[2]
                    local cz = (vpos[3] == 1) and box[6] or box[3]

                    -- UV 取 tile 子矩形：按该面的两个切向轴上的盒子坐标插值
                    local uu = (axisU == 1) and cx or ((axisU == 2) and cy or cz)
                    if flipU then uu = 1 - uu end
                    local vv = (axisV == 1) and cx or ((axisV == 2) and cy or cz)
                    if flipV then vv = 1 - vv end

                    geometry:DefineVertex(tempVec3(
                        worldBaseX + cx * BLOCK_SIZE,
                        worldBaseY + cy * BLOCK_SIZE,
                        worldBaseZ + cz * BLOCK_SIZE
                    ))
                    geometry:DefineNormal(face.normal)
                    geometry:DefineTangent(face.tangent)
                    geometry:DefineTexCoord(tempVec2(
                        u0 + uu * (u1 - u0),
                        v0 + vv * (v1 - v0)
                    ))
                    geometry:DefineColor(color)
                    added = added + 1
                end
            end
        end
    end

    return added
end

---按渲染层把一个方块发射到对应几何体（sync / async 两条构建路径共用的唯一发射入口）
---@param ctx table 区块构建上下文（createChunkGeometries 产出）
---@param blockType number 方块类型（调用方保证 ~= AIR）
---@param lx number 区块内 X
---@param lz number 区块内 Z
---@param y number 高度
local function emitBlockAt(ctx, blockType, lx, lz, y)
    local layer = layerLUT[blockType]
    -- 未注册的方块 id 与 item 层（火把由 TorchDecorator 建独立节点）都不进 chunk 网格
    if layer == nil or layer == Blocks.LAYER_ITEM then
        return
    end

    local worldBaseX = (ctx.startX + lx) * BLOCK_SIZE
    local worldBaseY = y * BLOCK_SIZE
    local worldBaseZ = (ctx.startZ + lz) * BLOCK_SIZE
    local geo, count = ctx.geo, ctx.count

    if layer == LAYER_SOLID then
        count.solid = count.solid + emitCubeBlock(ctx, geo.solid, blockType, lx, lz, y,
            worldBaseX, worldBaseY, worldBaseZ)
    elseif layer == LAYER_SHAPE then
        -- 非整格方块也进 solid 几何体（不透明、受光），只是逐盒子发面
        count.solid = count.solid + emitShapeBlock(ctx, geo.solid, blockType, lx, lz, y,
            worldBaseX, worldBaseY, worldBaseZ)
    elseif layer == LAYER_CROSS then
        count.cross = count.cross + emitCrossBlock(ctx, geo.cross, blockType,
            worldBaseX, worldBaseY, worldBaseZ)
    elseif layer == LAYER_LIQUID then
        local key = LIQUID_SLOT_KEY[blockType]
        if key and geo[key] then
            count[key] = count[key] + emitLiquidBlock(ctx, geo[key], blockType, lx, lz, y,
                worldBaseX, worldBaseY, worldBaseZ)
        end
    elseif layer == LAYER_CUTOUT then
        count.cutout = count.cutout + emitCubeBlock(ctx, geo.cutout, blockType, lx, lz, y,
            worldBaseX, worldBaseY, worldBaseZ)
    elseif layer == LAYER_TRANSLUCENT then
        count.translucent = count.translucent + emitCubeBlock(ctx, geo.translucent, blockType,
            lx, lz, y, worldBaseX, worldBaseY, worldBaseZ)
    end
end

---创建区块网格构建器
---@param world table World实例
---@param scene Node 场景节点
---@return table ChunkMeshBuilder实例
function ChunkMeshBuilder.new(world, scene)
    local self = setmetatable({}, ChunkMeshBuilder)
    self.world = world
    self.scene = scene
    self.chunkMaterial = nil
    self.waterMaterial = nil
    self.crossMeshMaterial = nil    -- 交叉网格材质（支持透明）
    self.cutoutMaterial = nil       -- alpha 裁剪立方体材质（玻璃）
    self.translucentMaterial = nil  -- alpha 混合立方体材质（冰）
    self.liquidMaterials = {}       -- [blockType] = Material（水/岩浆各一份）
    self.textures = nil  -- { diffuse, normal, specular }
    return self
end

---获取纹理图集UV坐标（从当前材质包获取）
---@param row number 行
---@param col number 列
---@return number u0
---@return number v0
---@return number u1
---@return number v1
function ChunkMeshBuilder:getTileUV(row, col)
    return TexturePackManager:getCurrent():getTileUV(row, col)
end

---获取方块面的UV坐标
---@param blockType number 方块类型
---@param faceType string 面类型 ("top", "side", "bottom")
---@return number u0
---@return number v0
---@return number u1
---@return number v1
function ChunkMeshBuilder:getBlockFaceUV(blockType, faceType)
    local block = Blocks:get(blockType)
    if not block or not block.textures then
        return self:getTileUV(0, 2)  -- 默认泥土纹理
    end

    local tilePos = block.textures[faceType] or block.textures.side
    return self:getTileUV(tilePos[1], tilePos[2])
end

---构建 UV 缓存（材质包加载后调用一次）
function ChunkMeshBuilder:buildUVCache()
    uvCache = {}
    uvCacheUpper = {}
    local faceTypes = { "top", "side", "bottom" }

    for id, block in pairs(Blocks.blocks) do
        uvCache[id] = {}
        for _, faceType in ipairs(faceTypes) do
            local u0, v0, u1, v1 = self:getBlockFaceUV(id, faceType)
            uvCache[id][faceType] = { u0, v0, u1, v1 }
        end

        -- 门的上半格用另一张 tile（下半是门板下段、上半带窗）
        if block.upperTexture then
            local u0, v0, u1, v1 = self:getTileUV(block.upperTexture[1], block.upperTexture[2])
            local uv = { u0, v0, u1, v1 }
            uvCacheUpper[id] = { top = uv, side = uv, bottom = uv }
        end
    end

    uvCacheBuilt = true
    print("[ChunkMeshBuilder] UV cache built for " .. #Blocks.blocks .. " block types")
end

---从缓存获取 UV（快速路径）
---@param blockType number 方块类型
---@param faceType string 面类型
---@return number u0
---@return number v0
---@return number u1
---@return number v1
function ChunkMeshBuilder:getCachedUV(blockType, faceType)
    local blockUV = uvCache[blockType]
    if blockUV then
        local uv = blockUV[faceType]
        if uv then
            return uv[1], uv[2], uv[3], uv[4]
        end
    end
    -- 回退到原始方法
    return self:getBlockFaceUV(blockType, faceType)
end

---设置贴图集合
---@param textures table { diffuse: Texture2D, normal: Texture2D|nil, specular: Texture2D|nil }
function ChunkMeshBuilder:setTextures(textures)
    self.textures = textures
end

---获取或创建区块材质
---@return Material 区块材质
function ChunkMeshBuilder:getChunkMaterial()
    if self.chunkMaterial then
        return self.chunkMaterial
    end
    
    self.chunkMaterial = Material:new()
    
    -- 根据是否有 normal 贴图选择 technique
    local isPBR = self.textures and self.textures.normal
    local techniquePath = isPBR 
        and "Techniques/PBR/PBRMetallicRoughDiffNormalSpecVCol.xml"
        or "Techniques/DiffVCol.xml"
    
    local technique = cache:GetResource("Technique", techniquePath)
    if not technique then
        technique = cache:GetResource("Technique", "Techniques/Diff.xml")
    end
    self.chunkMaterial:SetTechnique(0, technique)
    
    -- 绑定贴图
    if self.textures then
        self.chunkMaterial:SetTexture(TU_DIFFUSE, self.textures.diffuse)
        if isPBR then
            self.chunkMaterial:SetTexture(TU_NORMAL, self.textures.normal)
            self.chunkMaterial:SetTexture(TU_SPECULAR, self.textures.specular)
        end
    end
    
    -- 基础颜色
    self.chunkMaterial:SetShaderParameter("MatDiffColor", Variant(Color(1, 1, 1, 1)))
    
    -- PBR 参数
    if isPBR then
        self.chunkMaterial:SetShaderParameter("MatSpecColor", Variant(Color(1, 1, 1, 1)))
        -- 注意：METALLIC technique 下 roughness/metallic 取自 specular 纹理 × TextureRoughness/MetallicFactor，
        --       Roughness/Metallic 这两个材质参数（cRoughness/cMetallic）走的是 #else 死分支，从不被读取
    end
    
    return self.chunkMaterial
end

---获取或创建水材质
---@return Material 水材质
function ChunkMeshBuilder:getWaterMaterial()
    if self.waterMaterial then
        return self.waterMaterial
    end
    
    local sharedWater = cache:GetResource("Material", "Materials/SingleLayerWater.xml")
    if not sharedWater then
        self.waterMaterial = Material:new()
        local technique = cache:GetResource("Technique", "Techniques/DiffAlpha.xml")
        self.waterMaterial:SetTechnique(0, technique)
        self.waterMaterial:SetShaderParameter("MatDiffColor", Variant(Color(0.0, 0.6, 1.0)))
    else
        -- Clone 后再改：cache:GetResource 返回的是共享实例，原地 mutate 会污染所有用到该材质的对象
        self.waterMaterial = sharedWater:Clone()
        self.waterMaterial:SetShaderParameter("WaterTint", Variant(Blocks:getColor(WATER)))
    end
    
    return self.waterMaterial
end

---获取或创建液体材质
---水沿用引擎自带的 SingleLayerWater；岩浆用 unlit 满亮 + 过曝的图集材质
---（受光材质在白天露天会和普通方块一样亮，看不出自发光，见 LIQUID_STYLE 注释）；
---其余液体退回受光的图集材质
---@param blockType number 液体方块类型
---@return Material 液体材质
function ChunkMeshBuilder:getLiquidMaterial(blockType)
    local cached = self.liquidMaterials[blockType]
    if cached then
        return cached
    end

    local style = LIQUID_STYLE[blockType] or LIQUID_STYLE_DEFAULT
    local material
    if style.material == "water" then
        material = self:getWaterMaterial()
    elseif style.material == "unlit" then
        material = Material:new()
        local technique = cache:GetResource("Technique", "Techniques/DiffUnlit.xml")
        if not technique then
            technique = cache:GetResource("Technique", "Techniques/DiffVCol.xml")
        end
        material:SetTechnique(0, technique)
        if self.textures then
            material:SetTexture(TU_DIFFUSE, self.textures.diffuse)
        end
        -- MatDiffColor > 1 让它冲进 HDR 再过 tonemap，出"烫"的观感；
        -- 同时必须覆盖 technique 自带的 0.6 灰默认值
        local k = style.overBright or 1.0
        material:SetShaderParameter("MatDiffColor", Variant(Color(k, k, k, 1)))
    else
        material = Material:new()
        local isPBR = self.textures and self.textures.normal
        local techniquePath = isPBR
            and "Techniques/PBR/PBRMetallicRoughDiffNormalSpecVCol.xml"
            or "Techniques/DiffVCol.xml"
        local technique = cache:GetResource("Technique", techniquePath)
        if not technique then
            technique = cache:GetResource("Technique", "Techniques/Diff.xml")
        end
        material:SetTechnique(0, technique)

        if self.textures then
            material:SetTexture(TU_DIFFUSE, self.textures.diffuse)
            if isPBR then
                material:SetTexture(TU_NORMAL, self.textures.normal)
                material:SetTexture(TU_SPECULAR, self.textures.specular)
            end
        end
        material:SetShaderParameter("MatDiffColor", Variant(Color(1, 1, 1, 1)))
        if isPBR then
            material:SetShaderParameter("MatSpecColor", Variant(Color(1, 1, 1, 1)))
        end
    end

    self.liquidMaterials[blockType] = material
    return material
end

---获取或创建 alpha 裁剪立方体材质（玻璃）
---与交叉网格同 technique（DiffVColAlphaMask），但**保留背面剔除**——
---立方体是闭合的，用 CULL_NONE 会白发一倍面数并在内壁产生 z-fighting
---@return Material 裁剪材质
function ChunkMeshBuilder:getCutoutMaterial()
    if self.cutoutMaterial then
        return self.cutoutMaterial
    end

    self.cutoutMaterial = Material:new()

    local isPBR = self.textures and self.textures.normal
    local techniquePath = isPBR
        and "Techniques/PBR/PBRMetallicRoughDiffNormalSpecVColMask.xml"
        or "Techniques/DiffVColAlphaMask.xml"

    local technique = cache:GetResource("Technique", techniquePath)
    if not technique then
        technique = cache:GetResource("Technique", "Techniques/DiffVCol.xml")
    end
    self.cutoutMaterial:SetTechnique(0, technique)

    if self.textures then
        self.cutoutMaterial:SetTexture(TU_DIFFUSE, self.textures.diffuse)
        if isPBR then
            self.cutoutMaterial:SetTexture(TU_NORMAL, self.textures.normal)
            self.cutoutMaterial:SetTexture(TU_SPECULAR, self.textures.specular)
        end
    end

    self.cutoutMaterial:SetShaderParameter("MatDiffColor", Variant(Color(1, 1, 1, 1)))
    if isPBR then
        self.cutoutMaterial:SetShaderParameter("MatSpecColor", Variant(Color(1, 1, 1, 1)))
    end

    return self.cutoutMaterial
end

---获取或创建 alpha 混合立方体材质（冰）
---用 DiffVColUnlitAlpha：alpha 来自纹理，顶点色仍带 AO + 光照烘焙。
---注意 unlit 系列**没有 PBR 变体**，HD 包下冰不吃法线贴图（冰本身低频，可接受）
---@return Material 半透材质
function ChunkMeshBuilder:getTranslucentMaterial()
    if self.translucentMaterial then
        return self.translucentMaterial
    end

    self.translucentMaterial = Material:new()

    local technique = cache:GetResource("Technique", "Techniques/DiffVColUnlitAlpha.xml")
    if not technique then
        technique = cache:GetResource("Technique", "Techniques/DiffAlpha.xml")
    end
    self.translucentMaterial:SetTechnique(0, technique)

    if self.textures then
        self.translucentMaterial:SetTexture(TU_DIFFUSE, self.textures.diffuse)
    end

    -- technique 默认 MatDiffColor 是 0.6 灰，必须显式设满，否则冰会发暗
    self.translucentMaterial:SetShaderParameter("MatDiffColor", Variant(Color(1, 1, 1, 1)))

    return self.translucentMaterial
end

---获取槽位对应的材质
---@param slot table GEOMETRY_SLOTS 中的槽位定义
---@return Material
function ChunkMeshBuilder:getMaterialForSlot(slot)
    local kind = slot.material
    if kind == "chunk" then
        return self:getChunkMaterial()
    elseif kind == "cutout" then
        return self:getCutoutMaterial()
    elseif kind == "translucent" then
        return self:getTranslucentMaterial()
    elseif kind == "cross" then
        return self:getCrossMeshMaterial()
    elseif kind == "liquid" then
        return self:getLiquidMaterial(slot.blockType)
    end
    return self:getChunkMaterial()
end

---为一个区块节点创建全部渲染层几何体，返回构建上下文
---sync（buildChunk）与 async（prepareAsyncChunk）共用，避免槽位在两处各写一遍
---@param parentNode Node 区块节点（或异步构建的临时节点）
---@param chunkX number 区块 X
---@param chunkZ number 区块 Z
---@return table ctx 构建上下文
function ChunkMeshBuilder:createChunkGeometries(parentNode, chunkX, chunkZ)
    local ctx = {
        geo = {},
        node = {},
        count = {},
        world = self.world,
        chunkX = chunkX,
        chunkZ = chunkZ,
        startX = chunkX * CHUNK_SIZE,
        startZ = chunkZ * CHUNK_SIZE,
        rootNode = parentNode,
        -- 实际高度范围（用于删除方块后收缩区块范围）
        actualMinY = WORLD_HEIGHT,
        actualMaxY = 0,
    }

    for _, slot in ipairs(GEOMETRY_SLOTS) do
        local owner = parentNode
        if slot.nodeName then
            owner = parentNode:CreateChild(slot.nodeName, LOCAL)
            ctx.node[slot.key] = owner
        end
        local geometry = owner:CreateComponent("CustomGeometry", LOCAL)
        geometry:BeginGeometry(0, TRIANGLE_LIST)
        ctx.geo[slot.key] = geometry
        ctx.count[slot.key] = 0
    end

    return ctx
end

---提交区块的全部几何体（空的子节点直接移除，省 draw call）
---@param ctx table 构建上下文
function ChunkMeshBuilder:commitChunkGeometries(ctx)
    for _, slot in ipairs(GEOMETRY_SLOTS) do
        local key = slot.key
        local count = ctx.count[key] or 0
        if count > 0 then
            local geometry = ctx.geo[key]
            geometry:Commit()
            geometry.material = self:getMaterialForSlot(slot)
            geometry.castShadows = slot.castShadows
        elseif ctx.node[key] then
            ctx.node[key]:Remove()
            ctx.node[key] = nil
        end
    end
end

---构建区块指定高度区间的顶点（sync 一次跑完整区间，async 每帧跑一片）
---@param ctx table 构建上下文
---@param startY number 起始高度
---@param endY number 结束高度
function ChunkMeshBuilder:buildRange(ctx, startY, endY)
    local world = self.world
    local chunkX, chunkZ = ctx.chunkX, ctx.chunkZ
    local numericChunkKey = chunkX * 65536 + chunkZ
    local chunkData = world.chunkData[numericChunkKey]

    -- 每次进入都重取邻块数组：异步构建期间邻块可能刚被创建/替换
    ctx.blocks = chunkData and chunkData.blocks or {}
    local chunkDataPX = world.chunkData[(chunkX + 1) * 65536 + chunkZ]
    local chunkDataNX = world.chunkData[(chunkX - 1) * 65536 + chunkZ]
    local chunkDataPZ = world.chunkData[chunkX * 65536 + (chunkZ + 1)]
    local chunkDataNZ = world.chunkData[chunkX * 65536 + (chunkZ - 1)]
    ctx.blocksPX = chunkDataPX and chunkDataPX.blocks or nil
    ctx.blocksNX = chunkDataNX and chunkDataNX.blocks or nil
    ctx.blocksPZ = chunkDataPZ and chunkDataPZ.blocks or nil
    ctx.blocksNZ = chunkDataNZ and chunkDataNZ.blocks or nil

    local blocks = ctx.blocks
    local CHUNK_SIZE_M1 = CHUNK_SIZE - 1
    local actualMinY, actualMaxY = ctx.actualMinY, ctx.actualMaxY

    for lx = 0, CHUNK_SIZE_M1 do
        for lz = 0, CHUNK_SIZE_M1 do
            for y = startY, endY do
                local blockType = blocks[y * 256 + lz * 16 + lx] or AIR
                if blockType ~= AIR then
                    if y < actualMinY then actualMinY = y end
                    if y > actualMaxY then actualMaxY = y end
                    emitBlockAt(ctx, blockType, lx, lz, y)
                end
            end
        end
    end

    ctx.actualMinY, ctx.actualMaxY = actualMinY, actualMaxY
end

---获取或创建交叉网格材质（支持透明度 + PBR）
---@return Material 交叉网格材质
function ChunkMeshBuilder:getCrossMeshMaterial()
    if self.crossMeshMaterial then
        return self.crossMeshMaterial
    end
    
    self.crossMeshMaterial = Material:new()
    
    -- 根据是否有 normal 贴图选择 PBR 或普通技术
    -- 使用带 VCol + AlphaMask 的 technique，确保：
    -- 1. 有完整的渲染 pass（base, light 等）
    -- 2. 支持 alpha test（裁剪透明像素）
    local isPBR = self.textures and self.textures.normal
    local techniquePath = isPBR
        and "Techniques/PBR/PBRMetallicRoughDiffNormalSpecVColMask.xml"  -- PBR + VCol + AlphaMask
        or "Techniques/DiffVColAlphaMask.xml"
    
    local technique = cache:GetResource("Technique", techniquePath)
    if not technique then
        technique = cache:GetResource("Technique", "Techniques/DiffVCol.xml")
    end
    self.crossMeshMaterial:SetTechnique(0, technique)
    
    -- 绑定贴图
    if self.textures then
        self.crossMeshMaterial:SetTexture(TU_DIFFUSE, self.textures.diffuse)
        if isPBR then
            self.crossMeshMaterial:SetTexture(TU_NORMAL, self.textures.normal)
            self.crossMeshMaterial:SetTexture(TU_SPECULAR, self.textures.specular)
        end
    end
    
    -- 禁用背面剔除（双面渲染）
    self.crossMeshMaterial:SetCullMode(CULL_NONE)
    
    -- 基础颜色
    self.crossMeshMaterial:SetShaderParameter("MatDiffColor", Variant(Color(1, 1, 1, 1)))
    
    -- PBR 参数
    if isPBR then
        self.crossMeshMaterial:SetShaderParameter("MatSpecColor", Variant(Color(1, 1, 1, 1)))
        -- (同 getChunkMaterial：METALLIC technique 下 Roughness/Metallic 参数从不被读取，无需设置)
    end
    
    return self.crossMeshMaterial
end

---检查是否应该渲染面（邻块不遮挡即渲染）
---便利方法：热路径不用它（构建循环直接走 faceVisible + 数组索引）
---@param bx number 方块X
---@param by number 方块Y
---@param bz number 方块Z
---@param dx number X偏移
---@param dy number Y偏移
---@param dz number Z偏移
---@return boolean 是否渲染
function ChunkMeshBuilder:shouldRenderFace(bx, by, bz, dx, dy, dz)
    local adjacentBlock = self.world:getBlock(bx + dx, by + dy, bz + dz)
    return not occludesLUT[adjacentBlock]
end

---检查是否应该渲染液体面（邻块不遮挡、且不是同种液体）
---@param blockType number 液体方块类型
---@param bx number 方块X
---@param by number 方块Y
---@param bz number 方块Z
---@param dx number X偏移
---@param dy number Y偏移
---@param dz number Z偏移
---@return boolean 是否渲染
function ChunkMeshBuilder:shouldRenderLiquidFace(blockType, bx, by, bz, dx, dy, dz)
    local adjacentBlock = self.world:getBlock(bx + dx, by + dy, bz + dz)
    return faceVisible(blockType, adjacentBlock)
end

---检查是否应该渲染水面（等价 shouldRenderLiquidFace(WATER, ...)，保留旧签名）
---@return boolean 是否渲染
function ChunkMeshBuilder:shouldRenderWaterFace(bx, by, bz, dx, dy, dz)
    return self:shouldRenderLiquidFace(WATER, bx, by, bz, dx, dy, dz)
end

---构建区块网格（同步版本）
---@param chunkX number 区块X坐标
---@param chunkZ number 区块Z坐标
function ChunkMeshBuilder:buildChunk(chunkX, chunkZ)
    -- 确保 UV 缓存已建立
    if not uvCacheBuilt then
        self:buildUVCache()
    end

    local chunkKey = chunkX .. "," .. chunkZ
    local world = self.world

    -- 移除现有区块
    world:removeChunk(chunkKey)

    -- 创建区块节点（使用 LOCAL 模式，单机和客户端都适用）
    local chunkNode = self.scene:CreateChild("Chunk_" .. chunkKey, LOCAL)
    world:registerChunk(chunkKey, chunkNode)

    -- 各渲染层几何体（solid / cutout / translucent / cross / 每种液体一个）
    local ctx = self:createChunkGeometries(chunkNode, chunkX, chunkZ)

    -- 优化：只遍历有方块的高度范围
    local chunkData = world.chunkData[chunkX * 65536 + chunkZ]
    local minY = chunkData and chunkData.minY or 0
    local maxY = chunkData and chunkData.maxY or (WORLD_HEIGHT - 1)
    self:buildRange(ctx, minY, maxY)

    self:commitChunkGeometries(ctx)

    -- 修正区块高度范围（解决删除方块后范围不收缩的问题）
    if ctx.actualMinY <= ctx.actualMaxY then
        world:updateChunkHeightRange(chunkX, chunkZ, ctx.actualMinY, ctx.actualMaxY)
    else
        -- 区块变为全空气
        world:updateChunkHeightRange(chunkX, chunkZ, WORLD_HEIGHT, 0)
    end
end

-- ====================================================================
-- 异步区块重建系统（类 Minecraft 实现）
-- 
-- 核心思想：
-- 1. 分帧构建顶点数据（每帧处理部分 Y 层，不阻塞）
-- 2. 保留旧 Mesh 直到新 Mesh 完成（避免闪烁）
-- 3. 相关区块（边界敲击产生的相邻区块）在同一帧 Commit（避免漏洞）
-- ====================================================================

-- 异步重建状态
---@class AsyncRebuildState
---@field batch table<string, { x: number, z: number, tempNode: Node|nil, ctx: table|nil, completed: boolean }>
local asyncRebuildState = {
    active = false,           -- 是否有异步重建进行中
    batch = {},               -- 当前批次的区块 { chunkKey = { x, z, tempNode, geometry, ... } }
    currentChunk = nil,       -- 当前正在构建的区块 key
    currentY = 0,             -- 当前构建到的 Y 层
    rowsPerFrame = 16,        -- 每帧处理的 Y 层数（可调整）
}

---重建脏区块（异步版本）
---@param maxRebuilds number|nil 最大重建数（默认从配置读取）
function ChunkMeshBuilder:rebuildDirtyChunks(maxRebuilds)
    local state = asyncRebuildState
    
    -- ====================================================================
    -- 阶段 1：如果有进行中的异步重建，继续处理
    -- ====================================================================
    if state.active then
        self:continueAsyncRebuild()
        return
    end
    
    -- ====================================================================
    -- 阶段 2：收集新的脏区块批次
    -- ====================================================================
    local dirtyChunks = self.world:getDirtyChunks()
    local count = 0
    for _ in pairs(dirtyChunks) do
        count = count + 1
    end
    
    if count == 0 then
        return
    end
    
    -- 收集本批次所有脏区块（边界敲击会产生 2-3 个相关区块）
    state.batch = {}
    for chunkKey, chunk in pairs(dirtyChunks) do
        state.batch[chunkKey] = {
            x = chunk.x,
            z = chunk.z,
            tempNode = nil,       -- 临时节点（构建中）
            ctx = nil,            -- 构建上下文（几何体 / 计数 / 实际高度范围）
            completed = false,    -- 是否构建完成
        }
        self.world:clearDirtyChunk(chunkKey)
    end
    
    -- 开始异步重建
    state.active = true
    state.currentChunk = nil
    state.currentY = 0
    
    -- 为每个区块创建临时节点和几何体（准备阶段）
    for chunkKey, chunkInfo in pairs(state.batch) do
        self:prepareAsyncChunk(chunkKey, chunkInfo)
    end
    
    -- 选择第一个区块开始构建
    for chunkKey, _ in pairs(state.batch) do
        state.currentChunk = chunkKey
        local chunkData = self.world.chunkData[state.batch[chunkKey].x * 65536 + state.batch[chunkKey].z]
        state.currentY = chunkData and chunkData.minY or 0
        break
    end
end

---准备异步区块构建（创建临时节点 + 各层几何体）
---@param chunkKey string
---@param chunkInfo table
function ChunkMeshBuilder:prepareAsyncChunk(chunkKey, chunkInfo)
    -- 确保 UV 缓存已建立
    if not uvCacheBuilt then
        self:buildUVCache()
    end

    -- 创建临时区块节点（不替换旧的，构建完成后再替换）
    local tempNode = self.scene:CreateChild("Chunk_Temp_" .. chunkKey, LOCAL)
    chunkInfo.tempNode = tempNode
    chunkInfo.ctx = self:createChunkGeometries(tempNode, chunkInfo.x, chunkInfo.z)
end

---继续异步重建（每帧调用）
function ChunkMeshBuilder:continueAsyncRebuild()
    local state = asyncRebuildState

    if not state.currentChunk then
        -- 所有区块构建完成，执行批量提交
        self:commitAsyncBatch()
        return
    end

    local chunkInfo = state.batch[state.currentChunk]

    -- 获取区块数据（只需要 maxY 决定切片边界，blocks 由 buildRange 自取）
    local numericKey = chunkInfo.x * 65536 + chunkInfo.z
    local chunkData = self.world.chunkData[numericKey]
    local maxY = chunkData and chunkData.maxY or (WORLD_HEIGHT - 1)

    -- 计算本帧处理的 Y 范围
    local startY = state.currentY
    local endY = math.min(startY + state.rowsPerFrame - 1, maxY)

    -- 构建这几层的顶点（与同步路径共用 buildRange → emitBlockAt，不再有双副本）
    self:buildRange(chunkInfo.ctx, startY, endY)

    -- 更新进度
    state.currentY = endY + 1

    -- 检查当前区块是否完成
    if state.currentY > maxY then
        chunkInfo.completed = true

        -- 选择下一个未完成的区块
        state.currentChunk = nil
        for chunkKey, info in pairs(state.batch) do
            if not info.completed then
                state.currentChunk = chunkKey
                local nextChunkData = self.world.chunkData[info.x * 65536 + info.z]
                state.currentY = nextChunkData and nextChunkData.minY or 0
                break
            end
        end
    end
end

---批量提交所有异步构建的区块（同帧替换，避免漏洞）
function ChunkMeshBuilder:commitAsyncBatch()
    local state = asyncRebuildState
    local world = self.world

    -- 同帧提交所有区块
    for chunkKey, chunkInfo in pairs(state.batch) do
        local ctx = chunkInfo.ctx

        -- 1. 提交几何体（空层的子节点会被移除）
        self:commitChunkGeometries(ctx)

        -- 2. 原子替换：删除旧节点，注册新节点
        world:removeChunk(chunkKey)
        chunkInfo.tempNode.name = "Chunk_" .. chunkKey
        world:registerChunk(chunkKey, chunkInfo.tempNode)

        -- 3. 更新高度范围
        if ctx.actualMinY <= ctx.actualMaxY then
            world:updateChunkHeightRange(chunkInfo.x, chunkInfo.z, ctx.actualMinY, ctx.actualMaxY)
        else
            world:updateChunkHeightRange(chunkInfo.x, chunkInfo.z, WORLD_HEIGHT, 0)
        end
    end

    -- 重置状态
    state.active = false
    state.batch = {}
    state.currentChunk = nil
end

---检查是否有异步重建进行中
---@return boolean
function ChunkMeshBuilder:isAsyncRebuildActive()
    return asyncRebuildState.active
end

---获取异步重建进度信息（调试用）
---@return table { active, batchSize, currentChunk, currentY }
function ChunkMeshBuilder:getAsyncRebuildStatus()
    local state = asyncRebuildState
    local batchSize = 0
    for _ in pairs(state.batch) do
        batchSize = batchSize + 1
    end
    return {
        active = state.active,
        batchSize = batchSize,
        currentChunk = state.currentChunk,
        currentY = state.currentY,
    }
end

---渲染可见区块
---@param playerPos Vector3 玩家位置
function ChunkMeshBuilder:renderVisibleChunks(playerPos)
    local RENDER_DISTANCE = Config.World.RENDER_DISTANCE

    local playerChunkX = math.floor(playerPos.x / (CHUNK_SIZE * BLOCK_SIZE))
    local playerChunkZ = math.floor(playerPos.z / (CHUNK_SIZE * BLOCK_SIZE))

    for cx = playerChunkX - RENDER_DISTANCE, playerChunkX + RENDER_DISTANCE do
        for cz = playerChunkZ - RENDER_DISTANCE, playerChunkZ + RENDER_DISTANCE do
            local chunkKey = cx .. "," .. cz
            if not self.world:getChunk(chunkKey) then
                self:buildChunk(cx, cz)
            end
        end
    end
end

---异步渲染可见区块（协程版本）
---每构建若干个区块后 yield，让主线程可以刷新 UI
---@param playerPos Vector3 玩家位置
---@param onProgress function|nil 进度回调 function(current, total)
---@return thread 协程对象
function ChunkMeshBuilder:renderVisibleChunksAsync(playerPos, onProgress)
    return coroutine.create(function()
        local RENDER_DISTANCE = Config.World.RENDER_DISTANCE
        local CHUNKS_PER_FRAME = 2  -- 每帧构建区块数

        local playerChunkX = math.floor(playerPos.x / (CHUNK_SIZE * BLOCK_SIZE))
        local playerChunkZ = math.floor(playerPos.z / (CHUNK_SIZE * BLOCK_SIZE))

        -- 收集需要构建的区块
        local chunksToBuild = {}
        for cx = playerChunkX - RENDER_DISTANCE, playerChunkX + RENDER_DISTANCE do
            for cz = playerChunkZ - RENDER_DISTANCE, playerChunkZ + RENDER_DISTANCE do
                local chunkKey = cx .. "," .. cz
                if not self.world:getChunk(chunkKey) then
                    table.insert(chunksToBuild, { x = cx, z = cz })
                end
            end
        end

        local totalChunks = #chunksToBuild
        local builtCount = 0

        print(string.format("[ChunkMeshBuilder] Building %d chunks (async)...", totalChunks))

        for i, chunk in ipairs(chunksToBuild) do
            self:buildChunk(chunk.x, chunk.z)
            builtCount = builtCount + 1

            if builtCount % CHUNKS_PER_FRAME == 0 then
                if onProgress then
                    onProgress(builtCount, totalChunks)
                end
                coroutine.yield()
            end
        end

        -- 确保最终进度报告
        if onProgress then
            onProgress(totalChunks, totalChunks)
        end

        print("[ChunkMeshBuilder] Chunk building complete (async)!")
    end)
end

---刷新材质包（切换材质包时调用）
function ChunkMeshBuilder:refreshTexturePack()
    local pack = TexturePackManager:getCurrent()
    self.textures = pack:generate()

    -- 重新创建材质（technique 可能不同：PBR ↔ Diffuse）
    self.chunkMaterial = nil
    self.crossMeshMaterial = nil
    self.cutoutMaterial = nil
    self.translucentMaterial = nil
    self.waterMaterial = nil
    self.liquidMaterials = {}
    self:getChunkMaterial()
    self:getCrossMeshMaterial()

    -- 重建 UV 缓存
    self:buildUVCache()

    -- 标记所有区块为脏，触发重建
    self.world:markAllChunksDirty()

    local packType = self.textures.normal and "PBR" or "Diffuse"
    print("[ChunkMeshBuilder] Texture pack refreshed: " .. pack.displayName .. " (" .. packType .. ")")
end

return ChunkMeshBuilder
