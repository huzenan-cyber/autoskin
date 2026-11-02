-- ====================================================================
-- rendering/texturepacks/ClassicPack.lua
-- 经典材质包 - 像素化 Minecraft 风格纹理
-- ====================================================================

local TexturePackBase = require("rendering.texturepacks.TexturePackBase")
local Atlas = require("rendering.texturepacks.AtlasLayout")

---@class ClassicPack : TexturePackBase
local ClassicPack = TexturePackBase.new({
    name = "classic",
    displayName = "Classic (16x16)",
    tileSize = 16,
    atlasSize = 256,
    tilesPerRow = 16,
})

---重写 getFilterMode，使用 FILTER_NEAREST 保持像素锐利
---@return TextureFilterMode 滤波模式
function ClassicPack:getFilterMode()
    return FILTER_NEAREST
end

---创建图像（重写基类方法）
---tile 摆放由 AtlasLayout 单点决定，这里只负责按名字派发到生成器
---@return Image 生成的图像
function ClassicPack:createImage()
    print("[ClassicPack] Creating texture atlas...")

    local image = Image()
    image:SetSize(self.atlasSize, self.atlasSize, 4)  -- RGBA

    local tileSize = self.tileSize

    -- 先填未使用格子（占位灰），再逐个生成已声明的 tile
    self:fillUnusedTiles(image, tileSize)

    local missing = 0
    for _, entry in ipairs(Atlas.order) do
        local generator = self.tileGenerators[entry.name]
        if generator then
            generator(self, image, entry.col * tileSize, entry.row * tileSize, tileSize)
        else
            missing = missing + 1
            print("[ClassicPack] WARNING: no generator for tile '" .. entry.name .. "'")
        end
    end

    print(string.format("[ClassicPack] Texture atlas created! (%d tiles, %d missing)",
        Atlas.count(), missing))
    return image
end

-- ============================================
-- 纹理生成方法（从 TextureAtlas.lua 迁移）
-- ============================================

---生成草地顶部纹理
function ClassicPack:generateGrassTop(image, startX, startY, tileSize)
    math.randomseed(42)
    for y = 0, tileSize - 1 do
        for x = 0, tileSize - 1 do
            local noise = (math.random() - 0.5) * 0.3
            local r = 0.35 + noise * 0.2
            local g = 0.75 + noise * 0.1
            local b = 0.25 + noise * 0.15
            image:SetPixel(startX + x, startY + y, Color(r, g, b, 1.0))
        end
    end
end

---生成草地侧面纹理
function ClassicPack:generateGrassSide(image, startX, startY, tileSize)
    math.randomseed(43)
    for y = 0, tileSize - 1 do
        for x = 0, tileSize - 1 do
            if y < 4 then
                local grassHeight = 3 + (math.sin(x * 0.8) > 0.3 and 1 or 0)
                if y < grassHeight then
                    local noise = (math.random() - 0.5) * 0.2
                    image:SetPixel(startX + x, startY + y, Color(0.35 + noise, 0.75 + noise * 0.5, 0.25 + noise * 0.3, 1.0))
                else
                    local noise = (math.random() - 0.5) * 0.25
                    image:SetPixel(startX + x, startY + y, Color(0.55 + noise, 0.38 + noise * 0.7, 0.22 + noise * 0.5, 1.0))
                end
            else
                local noise = (math.random() - 0.5) * 0.25
                image:SetPixel(startX + x, startY + y, Color(0.55 + noise, 0.38 + noise * 0.7, 0.22 + noise * 0.5, 1.0))
            end
        end
    end
end

---生成泥土纹理
function ClassicPack:generateDirt(image, startX, startY, tileSize)
    math.randomseed(123)
    for y = 0, tileSize - 1 do
        for x = 0, tileSize - 1 do
            local noise = (math.random() - 0.5) * 0.3
            image:SetPixel(startX + x, startY + y, Color(0.55 + noise, 0.38 + noise * 0.7, 0.22 + noise * 0.5, 1.0))
        end
    end
end

---生成石头纹理
function ClassicPack:generateStone(image, startX, startY, tileSize)
    math.randomseed(456)
    for y = 0, tileSize - 1 do
        for x = 0, tileSize - 1 do
            local noise = (math.random() - 0.5) * 0.25
            local baseGray = 0.5 + noise
            local crack = 0
            if (x + y) % 7 == 0 or (x * 2 + y) % 11 == 0 then
                crack = -0.1
            end
            image:SetPixel(startX + x, startY + y, Color(baseGray + crack, baseGray + crack, baseGray + crack + 0.02, 1.0))
        end
    end
end

---生成木头顶部纹理（年轮）
function ClassicPack:generateWoodTop(image, startX, startY, tileSize)
    for y = 0, tileSize - 1 do
        for x = 0, tileSize - 1 do
            local centerX, centerY = tileSize / 2, tileSize / 2
            local dx, dy = x - centerX, y - centerY
            local dist = math.sqrt(dx * dx + dy * dy)
            local ringDist = dist % 4
            
            local baseColor = Color(0.65, 0.52, 0.32)
            if ringDist < 1.2 and dist > 2 then
                baseColor = Color(0.45, 0.32, 0.18)
            end
            
            local noise = (math.random() - 0.5) * 0.1
            image:SetPixel(startX + x, startY + y, Color(baseColor.r + noise, baseColor.g + noise, baseColor.b + noise, 1.0))
        end
    end
end

---生成木头侧面纹理（树皮）
function ClassicPack:generateWoodSide(image, startX, startY, tileSize)
    math.randomseed(789)
    for y = 0, tileSize - 1 do
        for x = 0, tileSize - 1 do
            local stripeIntensity = (x % 4 < 2) and 0.0 or 0.08
            local noise = (math.random() - 0.5) * 0.15
            image:SetPixel(startX + x, startY + y, Color(
                0.4 + stripeIntensity + noise,
                0.28 + stripeIntensity * 0.7 + noise * 0.7,
                0.15 + stripeIntensity * 0.5 + noise * 0.5,
                1.0
            ))
        end
    end
end

---生成树叶纹理（改进版：减少密集感，使用更大的色块）
function ClassicPack:generateLeaves(image, startX, startY, tileSize)
    math.randomseed(101112)
    
    -- 基础绿色
    local baseR, baseG, baseB = 0.22, 0.58, 0.18
    
    -- 第一遍：用 2x2 或 3x3 的块来生成基础变化，避免逐像素噪点
    local blockSize = 2  -- 2x2 像素块
    for by = 0, math.ceil(tileSize / blockSize) - 1 do
        for bx = 0, math.ceil(tileSize / blockSize) - 1 do
            -- 每个块有一个基础变化值
            local blockNoise = (math.random() - 0.5) * 0.15
            -- 10% 概率是暗块（而不是15%的单像素）
            local isDark = math.random() < 0.10
            local darkAmount = isDark and -0.12 or 0
            
            -- 填充整个块
            for dy = 0, blockSize - 1 do
                for dx = 0, blockSize - 1 do
                    local px = bx * blockSize + dx
                    local py = by * blockSize + dy
                    if px < tileSize and py < tileSize then
                        -- 块内部微小变化
                        local microNoise = (math.random() - 0.5) * 0.05
                        local r = baseR + blockNoise * 0.3 + darkAmount + microNoise
                        local g = baseG + blockNoise * 0.2 + darkAmount + microNoise
                        local b = baseB + blockNoise * 0.2 + darkAmount + microNoise
                        image:SetPixel(startX + px, startY + py, Color(r, g, b, 1.0))
                    end
                end
            end
        end
    end
    
    -- 第二遍：添加一些亮点（高光），让树叶更有层次感
    for i = 1, math.floor(tileSize * 0.8) do
        local hx = math.random(0, tileSize - 2)
        local hy = math.random(0, tileSize - 2)
        -- 1x1 或 2x1 的亮点
        local highlightR = baseR + 0.15
        local highlightG = baseG + 0.12
        local highlightB = baseB + 0.08
        image:SetPixel(startX + hx, startY + hy, Color(highlightR, highlightG, highlightB, 1.0))
    end
end

---生成沙子纹理
function ClassicPack:generateSand(image, startX, startY, tileSize)
    math.randomseed(131415)
    for y = 0, tileSize - 1 do
        for x = 0, tileSize - 1 do
            local noise = (math.random() - 0.5) * 0.2
            local grain = math.random() > 0.9 and -0.1 or 0
            image:SetPixel(startX + x, startY + y, Color(
                0.85 + noise + grain,
                0.78 + noise * 0.9 + grain,
                0.55 + noise * 0.7 + grain,
                1.0
            ))
        end
    end
end

---生成水纹理
function ClassicPack:generateWater(image, startX, startY, tileSize)
    for y = 0, tileSize - 1 do
        for x = 0, tileSize - 1 do
            local wave = math.sin(x * 0.4 + y * 0.2) * 0.1
            local noise = (math.random() - 0.5) * 0.1
            image:SetPixel(startX + x, startY + y, Color(
                0.2 + wave + noise,
                0.4 + wave + noise,
                0.8 + wave * 0.5,
                0.8  -- 半透明
            ))
        end
    end
end

---生成装饰草纹理（交叉网格用）
---像素风格：底部连接，向上分叉的草丛
function ClassicPack:generateTallGrass(image, startX, startY, tileSize)
    -- 先填充透明背景
    for y = 0, tileSize - 1 do
        for x = 0, tileSize - 1 do
            image:SetPixel(startX + x, startY + y, Color(0, 0, 0, 0))
        end
    end
    
    -- 草的颜色
    local darkGreen = { r = 0.28, g = 0.65, b = 0.20 }   -- 底部深绿
    local midGreen = { r = 0.35, g = 0.75, b = 0.25 }    -- 中间绿
    local lightGreen = { r = 0.42, g = 0.85, b = 0.30 }  -- 顶部亮绿
    
    -- 底部连接的高度（占总高度的比例）
    local baseHeight = math.floor(tileSize * 0.25)  -- 底部25%是连接的
    local totalHeight = math.floor(tileSize * 0.85) -- 总高度85%
    
    -- 草叶宽度
    local bladeWidth = math.max(2, math.floor(tileSize / 8))
    
    -- 定义草叶（从底部连接处分叉出去）
    local bladeCount = 4
    local blades = {}
    for i = 1, bladeCount do
        local centerX = math.floor((i - 0.5) * tileSize / bladeCount)
        -- 高度交错：两边稍矮
        local heightMult = 1 - math.abs(i - (bladeCount + 1) / 2) / bladeCount * 0.4
        local height = math.floor((totalHeight - baseHeight) * heightMult)
        table.insert(blades, { x = centerX, height = height })
    end
    
    -- 1. 绘制底部连接部分（横向连续）
    local baseLeft = blades[1].x - 1
    local baseRight = blades[#blades].x + bladeWidth
    for y = tileSize - 1, tileSize - baseHeight, -1 do
        local heightRatio = (tileSize - 1 - y) / baseHeight
        -- 颜色从深到中
        local r = darkGreen.r + (midGreen.r - darkGreen.r) * heightRatio
        local g = darkGreen.g + (midGreen.g - darkGreen.g) * heightRatio
        local b = darkGreen.b + (midGreen.b - darkGreen.b) * heightRatio
        
        for x = baseLeft, baseRight do
            if x >= 0 and x < tileSize then
                image:SetPixel(startX + x, startY + y, Color(r, g, b, 1.0))
            end
        end
    end
    
    -- 2. 绘制每根草叶（从底部连接处向上延伸）
    for i, blade in ipairs(blades) do
        for y = tileSize - baseHeight - 1, tileSize - baseHeight - blade.height, -1 do
            local heightRatio = (tileSize - baseHeight - 1 - y) / blade.height
            
            -- 颜色从中绿到亮绿
            local r = midGreen.r + (lightGreen.r - midGreen.r) * heightRatio
            local g = midGreen.g + (lightGreen.g - midGreen.g) * heightRatio
            local b = midGreen.b + (lightGreen.b - midGreen.b) * heightRatio
            
            -- 草叶宽度（顶部变尖）
            local currentWidth = bladeWidth
            if heightRatio > 0.7 then
                currentWidth = math.max(1, bladeWidth - 1)
            end
            
            -- 绘制草叶
            for w = 0, currentWidth - 1 do
                local px = blade.x + w
                if px >= 0 and px < tileSize then
                    -- 边缘稍暗
                    local edgeDark = (w == 0 or w == currentWidth - 1) and 0.92 or 1.0
                    image:SetPixel(startX + px, startY + y, Color(r * edgeDark, g * edgeDark, b * edgeDark, 1.0))
                end
            end
        end
    end
end

---生成花纹理（用于交叉网格渲染）
---@param baseColor table {r, g, b} 花朵主色调
function ClassicPack:generateFlower(image, startX, startY, tileSize, baseColor)
    -- 先填充透明背景
    for y = 0, tileSize - 1 do
        for x = 0, tileSize - 1 do
            image:SetPixel(startX + x, startY + y, Color(0, 0, 0, 0))
        end
    end
    
    -- 颜色定义
    local stemColor = { r = 0.25, g = 0.60, b = 0.18 }   -- 茎绿色
    local leafColor = { r = 0.35, g = 0.75, b = 0.22 }   -- 叶子亮绿
    
    -- 花朵尺寸
    local flowerSize = math.max(4, math.floor(tileSize * 0.4))
    local stemWidth = math.max(1, math.floor(tileSize / 8))
    local stemHeight = math.floor(tileSize * 0.6)
    local centerX = math.floor(tileSize / 2)
    
    -- 绘制茎（从底部往上）
    local stemStartY = tileSize - 1
    local stemEndY = tileSize - stemHeight
    for y = stemStartY, stemEndY, -1 do
        for dx = 0, stemWidth - 1 do
            local px = centerX - math.floor(stemWidth / 2) + dx
            if px >= 0 and px < tileSize then
                local noise = (math.random() - 0.5) * 0.05
                image:SetPixel(startX + px, startY + y, Color(
                    stemColor.r + noise,
                    stemColor.g + noise,
                    stemColor.b + noise,
                    1.0
                ))
            end
        end
        
        -- 添加叶子（茎的中部两侧）
        local midStem = (stemStartY + stemEndY) / 2
        if math.abs(y - midStem) < 2 then
            -- 左叶
            local lx = centerX - math.floor(stemWidth / 2) - 1
            if lx >= 0 then
                image:SetPixel(startX + lx, startY + y, Color(leafColor.r, leafColor.g, leafColor.b, 1.0))
            end
            -- 右叶
            local rx = centerX + math.floor(stemWidth / 2) + 1
            if rx < tileSize then
                image:SetPixel(startX + rx, startY + y, Color(leafColor.r, leafColor.g, leafColor.b, 1.0))
            end
        end
    end
    
    -- 绘制花朵（简单圆形）
    local flowerCenterY = stemEndY - math.floor(flowerSize / 2)
    local radius = math.floor(flowerSize / 2)
    
    for dy = -radius, radius do
        for dx = -radius, radius do
            local distSq = dx * dx + dy * dy
            if distSq <= radius * radius then
                local px = centerX + dx
                local py = flowerCenterY + dy
                if px >= 0 and px < tileSize and py >= 0 and py < tileSize then
                    -- 中心稍亮
                    local distFactor = math.sqrt(distSq) / radius
                    local brightness = 1.0 - distFactor * 0.2
                    image:SetPixel(startX + px, startY + py, Color(
                        baseColor.r * brightness,
                        baseColor.g * brightness,
                        baseColor.b * brightness,
                        1.0
                    ))
                end
            end
        end
    end
end

---生成火把纹理（用于纹理图集，实际手持渲染使用顶点色）
function ClassicPack:generateTorch(image, startX, startY, tileSize)
    -- 先填充透明背景
    for y = 0, tileSize - 1 do
        for x = 0, tileSize - 1 do
            image:SetPixel(startX + x, startY + y, Color(0, 0, 0, 0))
        end
    end
    
    -- 火把参数
    local centerX = math.floor(tileSize / 2)
    local stickWidth = math.max(2, math.floor(tileSize / 8))
    local stickHeight = math.floor(tileSize * 0.6)
    local flameHeight = math.floor(tileSize * 0.35)
    
    -- 木棍颜色
    local stickColor = Color(0.5, 0.3, 0.15, 1.0)
    -- 火焰颜色
    local flameOrange = Color(1.0, 0.6, 0.1, 1.0)
    local flameYellow = Color(1.0, 0.9, 0.3, 1.0)
    
    -- 绘制木棍（从底部往上）
    local stickStartY = tileSize - 1
    local stickEndY = tileSize - stickHeight
    for y = stickStartY, stickEndY, -1 do
        for dx = -stickWidth/2, stickWidth/2 do
            local px = centerX + math.floor(dx)
            if px >= 0 and px < tileSize then
                -- 木棍颜色有轻微变化
                local noise = (math.random() - 0.5) * 0.1
                image:SetPixel(startX + px, startY + y, Color(
                    stickColor.r + noise,
                    stickColor.g + noise * 0.5,
                    stickColor.b + noise * 0.3,
                    1.0
                ))
            end
        end
    end
    
    -- 绘制火焰（从木棍顶部往上）
    local flameStartY = stickEndY
    local flameEndY = stickEndY - flameHeight
    local flameMaxWidth = math.floor(tileSize / 4)
    
    for y = flameStartY, flameEndY, -1 do
        local progress = (flameStartY - y) / flameHeight
        -- 火焰逐渐变细
        local currentWidth = math.max(1, math.floor(flameMaxWidth * (1 - progress * 0.7)))
        
        -- 颜色从橙色渐变到黄色
        local r = flameOrange.r + (flameYellow.r - flameOrange.r) * progress
        local g = flameOrange.g + (flameYellow.g - flameOrange.g) * progress
        local b = flameOrange.b + (flameYellow.b - flameOrange.b) * progress
        
        for dx = -currentWidth, currentWidth do
            local px = centerX + dx
            if px >= 0 and px < tileSize then
                -- 添加一些随机性使火焰更自然
                local noise = (math.random() - 0.5) * 0.1
                image:SetPixel(startX + px, startY + y, Color(
                    math.min(1, r + noise),
                    math.min(1, g + noise * 0.5),
                    b,
                    1.0
                ))
            end
        end
    end
end

---填充未使用的格子
---已用格子从 AtlasLayout 反推（以前是写死的行列范围，加新 tile 会被灰色覆盖）
function ClassicPack:fillUnusedTiles(image, tileSize)
    for row = 0, self.tilesPerRow - 1 do
        for col = 0, self.tilesPerRow - 1 do
            if not Atlas.isUsed(row, col) then
                local startX = col * tileSize
                local startY = row * tileSize
                for y = 0, tileSize - 1 do
                    for x = 0, tileSize - 1 do
                        image:SetPixel(startX + x, startY + y, Color(0.3, 0.3, 0.3, 1.0))
                    end
                end
            end
        end
    end
end

-- ====================================================================
-- 通用像素绘制助手（参数化，一份代码出多个 tile）
-- ====================================================================

---实心噪声填充
---@param amount number|nil 噪声幅度（默认 0.12）
function ClassicPack:fillNoise(image, sx, sy, size, r, g, b, amount, seed)
    math.randomseed(seed or 1)
    amount = amount or 0.12
    for y = 0, size - 1 do
        for x = 0, size - 1 do
            local n = (math.random() - 0.5) * amount
            image:SetPixel(sx + x, sy + y, Color(r + n, g + n, b + n, 1.0))
        end
    end
end

---矿石：石头底 + 矿斑（6 种矿石共用，只换矿斑色与数量）
---@param ore table {r,g,b} 矿斑颜色
---@param blobCount number 矿斑数量
function ClassicPack:generateOre(image, sx, sy, size, ore, blobCount, seed)
    -- 先铺石头底（generateStone 自带 randomseed，必须在它之后再设种子）
    self:generateStone(image, sx, sy, size)
    math.randomseed(seed)

    -- 矿斑偏小、颗数偏多，像原版那样散落而不是糊成一团
    local radius = math.max(1, math.floor(size / 11))
    for _ = 1, blobCount do
        local cx = math.random(radius, size - 1 - radius)
        local cy = math.random(radius, size - 1 - radius)
        local r = radius + (math.random() < 0.35 and 1 or 0)
        local rr = r * r
        for dy = -r, r do
            for dx = -r, r do
                local d2 = dx * dx + dy * dy
                if d2 <= rr then
                    local px, py = cx + dx, cy + dy
                    if px >= 0 and px < size and py >= 0 and py < size then
                        -- 边缘压暗，让矿斑有体积感
                        local shade = (d2 >= (r - 1) * (r - 1)) and 0.72 or 1.0
                        local n = (math.random() - 0.5) * 0.08
                        image:SetPixel(sx + px, sy + py, Color(
                            ore.r * shade + n, ore.g * shade + n, ore.b * shade + n, 1.0))
                    end
                end
            end
        end
    end
end

---卵石类（圆石 / 苔石）：Voronoi 分块 + 缝隙压暗
---@param mossy boolean|nil 是否长苔（整块石头变绿，比逐像素更像原版）
function ClassicPack:generateCobble(image, sx, sy, size, base, seed, mossy)
    math.randomseed(seed)

    local pointCount = 7
    local pts = {}
    for i = 1, pointCount do
        pts[i] = {
            x = math.random(0, size - 1),
            y = math.random(0, size - 1),
            v = 0.85 + math.random() * 0.32,     -- 每块石头的明度
            moss = math.random() < 0.45,          -- 这块是否长苔
        }
    end

    local half = size / 2
    for y = 0, size - 1 do
        for x = 0, size - 1 do
            local best, second, bi = 1e9, 1e9, 1
            for i = 1, pointCount do
                -- 周期性距离：贴图四方连续，接缝处不会突变
                local dx = math.abs(x - pts[i].x); if dx > half then dx = size - dx end
                local dy = math.abs(y - pts[i].y); if dy > half then dy = size - dy end
                local d = dx * dx + dy * dy
                if d < best then
                    second = best; best = d; bi = i
                elseif d < second then
                    second = d
                end
            end

            local n = (math.random() - 0.5) * 0.07
            local r, g, b
            if (math.sqrt(second) - math.sqrt(best)) < 1.0 then
                -- 石块之间的缝
                r, g, b = base.r * 0.5, base.g * 0.5, base.b * 0.5
            else
                local v = pts[bi].v
                r, g, b = base.r * v + n, base.g * v + n, base.b * v + n
                if mossy and pts[bi].moss then
                    r = r * 0.45 + 0.10
                    g = g * 0.60 + 0.26
                    b = b * 0.40 + 0.08
                end
            end
            image:SetPixel(sx + x, sy + y, Color(r, g, b, 1.0))
        end
    end
end

---砖石类（红砖 / 石砖）：错缝砖块 + 灰缝
---@param rows number 砖行数
function ClassicPack:generateBrickPattern(image, sx, sy, size, brick, mortar, rows, seed)
    math.randomseed(seed)

    local rowH = math.max(2, math.floor(size / rows))
    local brickW = math.max(3, math.floor(size / 2))

    for y = 0, size - 1 do
        local rowIdx = math.floor(y / rowH)
        local offset = (rowIdx % 2 == 0) and 0 or math.floor(brickW / 2)
        for x = 0, size - 1 do
            local onHorizontalMortar = (y % rowH) == 0
            local onVerticalMortar = ((x + offset) % brickW) == 0
            local n = (math.random() - 0.5) * 0.09
            local c
            if onHorizontalMortar or onVerticalMortar then
                c = Color(mortar.r + n, mortar.g + n, mortar.b + n, 1.0)
            else
                -- 砖面：上沿略亮、下沿略暗
                local inRow = (y % rowH) / rowH
                local shade = 1.06 - inRow * 0.16
                c = Color(brick.r * shade + n, brick.g * shade + n, brick.b * shade + n, 1.0)
            end
            image:SetPixel(sx + x, sy + y, c)
        end
    end
end

---羊毛：底色 + 短纤维噪点（6 色共用）
function ClassicPack:generateWool(image, sx, sy, size, base, seed)
    math.randomseed(seed)
    for y = 0, size - 1 do
        for x = 0, size - 1 do
            local n = (math.random() - 0.5) * 0.10
            -- 交错的针织感：奇偶行/列略有明暗差
            local knit = ((x + y) % 4 < 2) and 0.03 or -0.03
            image:SetPixel(sx + x, sy + y, Color(
                base.r + n + knit, base.g + n + knit, base.b + n + knit, 1.0))
        end
    end
    -- 少量亮纤维
    for _ = 1, math.floor(size * 0.7) do
        local x = math.random(0, size - 1)
        local y = math.random(0, size - 1)
        image:SetPixel(sx + x, sy + y, Color(
            math.min(1, base.r + 0.12), math.min(1, base.g + 0.12), math.min(1, base.b + 0.12), 1.0))
    end
end

---交叉网格植物通用绘制（树苗 / 枯灌木 / 蘑菇）
---@param opts table { stem={r,g,b}, cap={r,g,b}|nil, capDots=boolean|nil, twigs=boolean|nil }
function ClassicPack:generateCrossPlant(image, sx, sy, size, opts, seed)
    math.randomseed(seed)

    -- 透明底
    for y = 0, size - 1 do
        for x = 0, size - 1 do
            image:SetPixel(sx + x, sy + y, Color(0, 0, 0, 0))
        end
    end

    local centerX = math.floor(size / 2)
    local stem = opts.stem
    local stemW = math.max(1, math.floor(size / 10))

    if opts.twigs then
        -- 枯灌木：从底部散开的枯枝
        local branches = 5
        for i = 1, branches do
            local dir = (i % 2 == 0) and 1 or -1
            local lean = dir * (i * size / (branches * 3))
            local h = math.floor(size * (0.45 + 0.30 * math.random()))
            for step = 0, h do
                local px = centerX + math.floor(lean * step / math.max(1, h))
                local py = size - 1 - step
                if px >= 0 and px < size and py >= 0 then
                    local n = (math.random() - 0.5) * 0.08
                    image:SetPixel(sx + px, sy + py, Color(stem.r + n, stem.g + n, stem.b + n, 1.0))
                end
            end
        end
        return
    end

    -- 茎
    local stemHeight = opts.stemHeight or math.floor(size * 0.55)
    for y = size - 1, size - stemHeight, -1 do
        for dx = 0, stemW - 1 do
            local px = centerX - math.floor(stemW / 2) + dx
            if px >= 0 and px < size then
                local n = (math.random() - 0.5) * 0.06
                image:SetPixel(sx + px, sy + y, Color(stem.r + n, stem.g + n, stem.b + n, 1.0))
            end
        end
    end

    local cap = opts.cap
    if not cap then return end

    if opts.mushroom then
        -- 蘑菇：半圆伞盖
        local capR = math.max(3, math.floor(size * 0.32))
        local capY = size - stemHeight
        for dy = -capR, 0 do
            for dx = -capR, capR do
                if dx * dx + dy * dy <= capR * capR then
                    local px, py = centerX + dx, capY + dy
                    if px >= 0 and px < size and py >= 0 and py < size then
                        local n = (math.random() - 0.5) * 0.06
                        image:SetPixel(sx + px, sy + py, Color(cap.r + n, cap.g + n, cap.b + n, 1.0))
                    end
                end
            end
        end
        if opts.capDots then
            for _ = 1, 4 do
                local px = centerX + math.random(-capR + 1, capR - 1)
                local py = capY - math.random(0, capR - 1)
                if px >= 0 and px < size and py >= 0 then
                    image:SetPixel(sx + px, sy + py, Color(0.95, 0.95, 0.92, 1.0))
                end
            end
        end
    else
        -- 树苗：茎顶两侧的叶片
        local leafR = math.max(3, math.floor(size * 0.30))
        local leafY = size - stemHeight - leafR + 1
        for dy = -leafR, leafR do
            for dx = -leafR, leafR do
                local d2 = dx * dx + dy * dy
                if d2 <= leafR * leafR and not (dy > 0 and math.abs(dx) < 1) then
                    local px, py = centerX + dx, leafY + dy
                    if px >= 0 and px < size and py >= 0 and py < size then
                        local n = (math.random() - 0.5) * 0.10
                        local shade = (d2 >= (leafR - 1) * (leafR - 1)) and 0.85 or 1.0
                        image:SetPixel(sx + px, sy + py, Color(
                            cap.r * shade + n, cap.g * shade + n, cap.b * shade + n, 1.0))
                    end
                end
            end
        end
    end
end

-- ====================================================================
-- 新增方块的专用生成器
-- ====================================================================

---砂岩顶：细沙面
function ClassicPack:generateSandstoneTop(image, sx, sy, size)
    self:fillNoise(image, sx, sy, size, 0.87, 0.80, 0.58, 0.09, 3101)
end

---砂岩侧：水平沉积层
function ClassicPack:generateSandstoneSide(image, sx, sy, size)
    math.randomseed(3102)
    local bandH = math.max(2, math.floor(size / 5))
    for y = 0, size - 1 do
        local band = math.floor(y / bandH)
        local bandShade = (band % 2 == 0) and 1.02 or 0.88
        -- 层与层之间一条深色分界线
        local isSeam = (y % bandH) == 0
        for x = 0, size - 1 do
            local n = (math.random() - 0.5) * 0.07
            local shade = isSeam and 0.74 or bandShade
            image:SetPixel(sx + x, sy + y, Color(
                0.86 * shade + n, 0.79 * shade + n, 0.57 * shade + n, 1.0))
        end
    end
end

---砂岩底：更暗更粗糙的压实沙（与顶面拉开区分度）
function ClassicPack:generateSandstoneBottom(image, sx, sy, size)
    self:fillNoise(image, sx, sy, size, 0.74, 0.66, 0.45, 0.20, 3103)
end

---黑曜石：近黑底 + 紫色反光点
function ClassicPack:generateObsidian(image, sx, sy, size)
    math.randomseed(3104)
    for y = 0, size - 1 do
        for x = 0, size - 1 do
            local n = (math.random() - 0.5) * 0.05
            local purple = (math.random() < 0.10) and 0.12 or 0.0
            image:SetPixel(sx + x, sy + y, Color(
                0.10 + n + purple * 0.8, 0.08 + n + purple * 0.2, 0.16 + n + purple, 1.0))
        end
    end
end

---基岩：不规则深浅灰块
function ClassicPack:generateBedrock(image, sx, sy, size)
    math.randomseed(3105)
    local blockSize = math.max(2, math.floor(size / 6))
    for by = 0, math.ceil(size / blockSize) - 1 do
        for bx = 0, math.ceil(size / blockSize) - 1 do
            local v = 0.20 + math.random() * 0.24
            for dy = 0, blockSize - 1 do
                for dx = 0, blockSize - 1 do
                    local px, py = bx * blockSize + dx, by * blockSize + dy
                    if px < size and py < size then
                        local n = (math.random() - 0.5) * 0.05
                        image:SetPixel(sx + px, sy + py, Color(v + n, v + n, v + n + 0.01, 1.0))
                    end
                end
            end
        end
    end
end

---木板：横向木板 + 板缝
function ClassicPack:generatePlanks(image, sx, sy, size)
    math.randomseed(3106)
    local plankH = math.max(3, math.floor(size / 4))
    for y = 0, size - 1 do
        local isGroove = (y % plankH) == 0
        local plankIdx = math.floor(y / plankH)
        for x = 0, size - 1 do
            local grain = math.sin(x * 0.9 + plankIdx * 2.7) * 0.035
            local n = (math.random() - 0.5) * 0.05
            local r, g, b
            if isGroove then
                r, g, b = 0.46, 0.33, 0.18
            else
                r, g, b = 0.72 + grain, 0.56 + grain, 0.34 + grain
            end
            image:SetPixel(sx + x, sy + y, Color(r + n, g + n, b + n, 1.0))
        end
    end
end

---书架侧面：上下木板边框 + 中间书脊
function ClassicPack:generateBookshelfSide(image, sx, sy, size)
    self:generatePlanks(image, sx, sy, size)
    math.randomseed(3107)

    local border = math.max(2, math.floor(size * 0.18))
    local bookColors = {
        { r = 0.62, g = 0.20, b = 0.18 },
        { r = 0.20, g = 0.34, b = 0.60 },
        { r = 0.24, g = 0.48, b = 0.26 },
        { r = 0.58, g = 0.48, b = 0.18 },
        { r = 0.45, g = 0.24, b = 0.50 },
    }

    -- 中间区域画竖向书脊
    local x = 0
    while x < size do
        local w = math.random(1, math.max(1, math.floor(size / 8)))
        local c = bookColors[math.random(1, #bookColors)]
        local gap = math.random() < 0.25
        for dx = 0, w - 1 do
            local px = x + dx
            if px < size then
                for y = border, size - 1 - border do
                    if gap then
                        -- 书之间的暗缝
                        image:SetPixel(sx + px, sy + y, Color(0.18, 0.13, 0.09, 1.0))
                    else
                        local n = (math.random() - 0.5) * 0.06
                        -- 书脊上下端略暗
                        local edge = (y == border or y == size - 1 - border) and 0.8 or 1.0
                        image:SetPixel(sx + px, sy + y, Color(
                            c.r * edge + n, c.g * edge + n, c.b * edge + n, 1.0))
                    end
                end
            end
        end
        x = x + w
    end
end

---工作台顶面：木板 + 3x3 格线
function ClassicPack:generateCraftingTop(image, sx, sy, size)
    self:generatePlanks(image, sx, sy, size)
    local third = size / 3
    for y = 0, size - 1 do
        for x = 0, size - 1 do
            local onGrid = (math.abs(x % third) < 1) or (math.abs(y % third) < 1)
                or x == 0 or y == 0
            if onGrid then
                image:SetPixel(sx + x, sy + y, Color(0.34, 0.24, 0.13, 1.0))
            end
        end
    end
end

---工作台侧面：木板 + 下方深色工具板
function ClassicPack:generateCraftingSide(image, sx, sy, size)
    self:generatePlanks(image, sx, sy, size)
    math.randomseed(3108)
    local panelTop = math.floor(size * 0.45)
    for y = panelTop, size - 1 do
        for x = 1, size - 2 do
            local n = (math.random() - 0.5) * 0.05
            image:SetPixel(sx + x, sy + y, Color(0.42 + n, 0.30 + n, 0.17 + n, 1.0))
        end
    end
    -- 工具挂钩（两道浅色竖线）
    for y = panelTop + 1, size - 3 do
        image:SetPixel(sx + math.floor(size * 0.3), sy + y, Color(0.70, 0.66, 0.60, 1.0))
        image:SetPixel(sx + math.floor(size * 0.7), sy + y, Color(0.58, 0.44, 0.24, 1.0))
    end
end

---熔炉顶面：石头 + 中央圆孔
function ClassicPack:generateFurnaceTop(image, sx, sy, size)
    self:generateStone(image, sx, sy, size)
    local cx, cy = size / 2, size / 2
    local r = math.max(2, math.floor(size * 0.22))
    for y = 0, size - 1 do
        for x = 0, size - 1 do
            local dx, dy = x - cx + 0.5, y - cy + 0.5
            local d = math.sqrt(dx * dx + dy * dy)
            if d <= r then
                local v = (d > r - 1) and 0.30 or 0.14
                image:SetPixel(sx + x, sy + y, Color(v, v, v, 1.0))
            end
        end
    end
end

---熔炉侧面：石头 + 下方炉口
function ClassicPack:generateFurnaceSide(image, sx, sy, size)
    self:generateStone(image, sx, sy, size)
    local left = math.floor(size * 0.22)
    local right = size - 1 - left
    local top = math.floor(size * 0.45)
    for y = top, size - 2 do
        for x = left, right do
            -- 炉口边框亮一点，内部近黑
            local isBorder = (y == top) or (x == left) or (x == right)
            local v = isBorder and 0.34 or 0.10
            image:SetPixel(sx + x, sy + y, Color(v, v * 0.98, v * 0.95, 1.0))
        end
    end
    -- 炉栅（两道横线）
    local grateY = math.floor(size * 0.72)
    for x = left + 1, right - 1 do
        image:SetPixel(sx + x, sy + grateY, Color(0.30, 0.28, 0.27, 1.0))
    end
end

---荧石：暖黄发光颗粒
function ClassicPack:generateGlowstone(image, sx, sy, size)
    math.randomseed(3109)
    for y = 0, size - 1 do
        for x = 0, size - 1 do
            local n = (math.random() - 0.5) * 0.10
            image:SetPixel(sx + x, sy + y, Color(0.82 + n, 0.66 + n, 0.32 + n, 1.0))
        end
    end
    -- 高亮颗粒
    for _ = 1, math.floor(size * 1.2) do
        local x = math.random(0, size - 1)
        local y = math.random(0, size - 1)
        image:SetPixel(sx + x, sy + y, Color(1.0, 0.94, 0.62, 1.0))
    end
end

---砂砾：杂色碎石
function ClassicPack:generateGravel(image, sx, sy, size)
    math.randomseed(3110)
    for y = 0, size - 1 do
        for x = 0, size - 1 do
            local v = 0.42 + math.random() * 0.28
            local warm = (math.random() < 0.25) and 0.04 or 0.0
            image:SetPixel(sx + x, sy + y, Color(v + warm, v + warm * 0.6, v, 1.0))
        end
    end
end

---黏土：细腻灰蓝
function ClassicPack:generateClay(image, sx, sy, size)
    self:fillNoise(image, sx, sy, size, 0.63, 0.65, 0.70, 0.07, 3111)
end

---雪：近白 + 极淡蓝噪声
function ClassicPack:generateSnow(image, sx, sy, size)
    math.randomseed(3112)
    for y = 0, size - 1 do
        for x = 0, size - 1 do
            local n = (math.random() - 0.5) * 0.05
            image:SetPixel(sx + x, sy + y, Color(0.94 + n, 0.96 + n, 0.99 + n * 0.5, 1.0))
        end
    end
end

---带雪草地的侧面：上部积雪 + 下部泥土
function ClassicPack:generateGrassSnowSide(image, sx, sy, size)
    self:generateDirt(image, sx, sy, size)
    math.randomseed(3113)
    local snowDepth = math.max(2, math.floor(size * 0.28))
    for x = 0, size - 1 do
        -- 雪线参差不齐
        local jitter = (math.random() < 0.4) and 1 or 0
        for y = 0, snowDepth + jitter - 1 do
            local n = (math.random() - 0.5) * 0.05
            image:SetPixel(sx + x, sy + y, Color(0.93 + n, 0.95 + n, 0.99 + n * 0.5, 1.0))
        end
    end
end

---冰：半透明淡蓝 + 裂纹（alpha 走 translucent 材质的混合）
function ClassicPack:generateIce(image, sx, sy, size)
    math.randomseed(3114)
    local ICE_ALPHA = 0.62
    for y = 0, size - 1 do
        for x = 0, size - 1 do
            local n = (math.random() - 0.5) * 0.05
            image:SetPixel(sx + x, sy + y, Color(0.58 + n, 0.78 + n, 0.96 + n * 0.5, ICE_ALPHA))
        end
    end
    -- 几道浅色裂纹
    for _ = 1, 3 do
        local x = math.random(0, size - 1)
        local y = math.random(0, size - 1)
        local dirX = (math.random() < 0.5) and 1 or 0
        for step = 0, math.floor(size * 0.6) do
            local px = (x + (dirX == 1 and step or math.floor(step * 0.3))) % size
            local py = (y + (dirX == 1 and math.floor(step * 0.3) or step)) % size
            image:SetPixel(sx + px, sy + py, Color(0.80, 0.92, 1.0, ICE_ALPHA + 0.12))
        end
    end
end

---岩浆：暗红底 + 明黄熔流
function ClassicPack:generateLava(image, sx, sy, size)
    math.randomseed(3115)
    for y = 0, size - 1 do
        for x = 0, size - 1 do
            -- 低频"流动"图案 + 噪声
            local flow = math.sin(x * 0.5 + y * 0.3) * 0.5 + math.sin(y * 0.7) * 0.3
            local n = (math.random() - 0.5) * 0.08
            local hot = math.max(0, flow) * 0.35
            image:SetPixel(sx + x, sy + y, Color(
                0.78 + hot + n, 0.24 + hot * 0.9 + n * 0.6, 0.06 + hot * 0.2, 1.0))
        end
    end
    -- 最亮的熔核
    for _ = 1, math.floor(size * 0.6) do
        local x = math.random(0, size - 1)
        local y = math.random(0, size - 1)
        image:SetPixel(sx + x, sy + y, Color(1.0, 0.78, 0.28, 1.0))
    end
end

---仙人掌顶面
function ClassicPack:generateCactusTop(image, sx, sy, size)
    self:fillNoise(image, sx, sy, size, 0.24, 0.52, 0.22, 0.07, 3116)
    -- 内圈略亮
    local inset = math.max(2, math.floor(size * 0.22))
    for y = inset, size - 1 - inset do
        for x = inset, size - 1 - inset do
            local n = (math.random() - 0.5) * 0.05
            image:SetPixel(sx + x, sy + y, Color(0.30 + n, 0.60 + n, 0.26 + n, 1.0))
        end
    end
end

---仙人掌侧面：竖棱 + 尖刺
function ClassicPack:generateCactusSide(image, sx, sy, size)
    math.randomseed(3117)
    local ribW = math.max(2, math.floor(size / 5))
    for y = 0, size - 1 do
        for x = 0, size - 1 do
            local inRib = (x % ribW) == 0
            local n = (math.random() - 0.5) * 0.06
            local shade = inRib and 0.75 or 1.0
            image:SetPixel(sx + x, sy + y, Color(
                0.24 * shade + n, 0.54 * shade + n, 0.22 * shade + n, 1.0))
        end
    end
    -- 尖刺（浅黄点）
    for _ = 1, math.floor(size * 0.5) do
        local x = math.random(0, size - 1)
        local y = math.random(0, size - 1)
        image:SetPixel(sx + x, sy + y, Color(0.86, 0.86, 0.60, 1.0))
    end
end

---仙人掌底面
function ClassicPack:generateCactusBottom(image, sx, sy, size)
    self:fillNoise(image, sx, sy, size, 0.20, 0.44, 0.19, 0.08, 3118)
end

---玻璃：中间全透明 + 边框与高光（走 alpha 裁剪，alpha < 0.5 被丢弃）
function ClassicPack:generateGlass(image, sx, sy, size)
    for y = 0, size - 1 do
        for x = 0, size - 1 do
            local onBorder = (x == 0 or y == 0 or x == size - 1 or y == size - 1)
            if onBorder then
                image:SetPixel(sx + x, sy + y, Color(0.80, 0.90, 0.95, 1.0))
            else
                image:SetPixel(sx + x, sy + y, Color(0.85, 0.94, 0.98, 0.0))
            end
        end
    end
    -- 左上角一道斜向高光，让玻璃看得出存在
    local streak = math.max(2, math.floor(size * 0.28))
    for i = 0, streak do
        local x = 2 + i
        local y = 2 + math.floor(i * 0.6)
        if x < size - 2 and y < size - 2 then
            image:SetPixel(sx + x, sy + y, Color(0.95, 0.99, 1.0, 1.0))
            if x + 1 < size - 2 then
                image:SetPixel(sx + x + 1, sy + y, Color(0.90, 0.96, 1.0, 1.0))
            end
        end
    end
end

---门板：木纹底 + 竖向门缝 + 把手；upper=true 时上部开一个窗格
---@param base table {r,g,b} 门板底色（木门偏棕、铁门偏灰）
---@param upper boolean 是否为门的上半格
---@param window boolean 上半格是否开窗
function ClassicPack:generateDoor(image, sx, sy, size, base, upper, window, seed)
    math.randomseed(seed)

    -- 竖向木板缝：**故意偏离正中**。放在正中时会和下面那条横向接缝交成一个十字，
    -- 整扇门看起来像被画了个加号
    local seamX = math.floor(size * 0.34)

    for y = 0, size - 1 do
        for x = 0, size - 1 do
            local n = (math.random() - 0.5) * 0.07
            local seam = (x == seamX) and -0.16 or 0
            -- 包边只压暗"门的外轮廓"：左右两侧，以及上半格的顶边 / 下半格的底边。
            -- ⚠️ 上下两格交界的那条边不能压暗 —— 两张 tile 各压一条拼起来就是一条横线，
            --    那条横线并不存在于真实的门上（tile 的 y=0 是方块顶部，见 UV 映射）
            local onSide = (x == 0 or x == size - 1)
            local onOuterEnd = (upper and y == 0) or ((not upper) and y == size - 1)
            local edge = (onSide or onOuterEnd) and -0.10 or 0
            local k = 1.0 + n + seam + edge
            image:SetPixel(sx + x, sy + y, Color(base.r * k, base.g * k, base.b * k, 1.0))
        end
    end

    -- 下半格画一个内嵌门板轮廓：这是 MC 门的"面板感"来源。
    -- 故意做成**不贯通到边**的短线，避免又拼出一条横跨整扇门的直线
    if not upper then
        local px0, px1 = math.floor(size * 0.20), math.floor(size * 0.80)
        local py0, py1 = math.floor(size * 0.34), math.floor(size * 0.88)
        for x = px0, px1 do
            for _, y in ipairs({ py0, py1 }) do
                image:SetPixel(sx + x, sy + y, Color(base.r * 0.72, base.g * 0.72, base.b * 0.72, 1.0))
            end
        end
        for y = py0, py1 do
            for _, x in ipairs({ px0, px1 }) do
                image:SetPixel(sx + x, sy + y, Color(base.r * 0.72, base.g * 0.72, base.b * 0.72, 1.0))
            end
        end
    end

    if upper and window then
        -- 上半格的窗：中间挖一块（透明由 cutout 层裁掉，配合窗框）
        local x0 = math.floor(size * 0.22)
        local x1 = size - 1 - x0
        local y0 = math.floor(size * 0.22)
        local y1 = math.floor(size * 0.62)
        for y = y0, y1 do
            for x = x0, x1 do
                local onFrame = (x == x0 or x == x1 or y == y0 or y == y1)
                if onFrame then
                    image:SetPixel(sx + x, sy + y, Color(base.r * 0.6, base.g * 0.6, base.b * 0.6, 1.0))
                else
                    -- 玻璃窗：淡蓝半亮（不透明，避免和 cutout 层混在一起）
                    image:SetPixel(sx + x, sy + y, Color(0.62, 0.78, 0.88, 1.0))
                end
            end
        end
    end

    -- 门把手：只画在**下半格**的靠上位置（大约整扇门的中间高度）。
    -- 上下格各画一个会在门中部出现两个点，像两个把手
    if not upper then
        local hx = math.floor(size * 0.80)
        local hy = math.floor(size * 0.22)
        for dy = 0, 1 do
            for dx = 0, 1 do
                local px, py = hx + dx, hy + dy
                if px < size and py < size then
                    image:SetPixel(sx + px, sy + py, Color(0.85, 0.80, 0.45, 1.0))
                end
            end
        end
    end
end

---活板门：横向木条 + 铰链钉
function ClassicPack:generateTrapdoor(image, sx, sy, size)
    math.randomseed(6301)
    local plankH = math.max(3, math.floor(size / 4))
    for y = 0, size - 1 do
        local isSeam = (y % plankH) == 0
        for x = 0, size - 1 do
            local n = (math.random() - 0.5) * 0.06
            local k = isSeam and 0.62 or 1.0
            image:SetPixel(sx + x, sy + y, Color(
                0.60 * k + n, 0.44 * k + n, 0.24 * k + n, 1.0))
        end
    end
    -- 两侧铰链
    for _, hx in ipairs({ 1, size - 2 }) do
        for y = math.floor(size * 0.2), math.floor(size * 0.8) do
            image:SetPixel(sx + hx, sy + y, Color(0.32, 0.32, 0.34, 1.0))
        end
    end
end

-- ====================================================================
-- tile 名称 → 生成器（createImage 按 AtlasLayout.order 派发）
-- ====================================================================

---构造矿石生成器
local function oreGen(color, blobCount, seed)
    return function(self, image, sx, sy, size)
        self:generateOre(image, sx, sy, size, color, blobCount, seed)
    end
end

---构造羊毛生成器
local function woolGen(color, seed)
    return function(self, image, sx, sy, size)
        self:generateWool(image, sx, sy, size, color, seed)
    end
end

---构造交叉网格植物生成器
local function plantGen(opts, seed)
    return function(self, image, sx, sy, size)
        self:generateCrossPlant(image, sx, sy, size, opts, seed)
    end
end

ClassicPack.tileGenerators = {
    -- Row 0-2：原有
    grass_top     = ClassicPack.generateGrassTop,
    grass_side    = ClassicPack.generateGrassSide,
    dirt          = ClassicPack.generateDirt,
    stone         = ClassicPack.generateStone,
    wood_top      = ClassicPack.generateWoodTop,
    wood_side     = ClassicPack.generateWoodSide,
    leaves        = ClassicPack.generateLeaves,
    sand          = ClassicPack.generateSand,
    water         = ClassicPack.generateWater,
    tall_grass    = ClassicPack.generateTallGrass,
    torch         = ClassicPack.generateTorch,
    rose          = function(self, image, sx, sy, size)
        self:generateFlower(image, sx, sy, size, { r = 0.9, g = 0.15, b = 0.15 })
    end,
    flower_yellow = function(self, image, sx, sy, size)
        self:generateFlower(image, sx, sy, size, { r = 1.0, g = 0.9, b = 0.1 })
    end,
    flower_blue   = function(self, image, sx, sy, size)
        self:generateFlower(image, sx, sy, size, { r = 0.2, g = 0.4, b = 1.0 })
    end,

    -- Row 3：石制 + 建材
    cobblestone = function(self, image, sx, sy, size)
        self:generateCobble(image, sx, sy, size, { r = 0.52, g = 0.52, b = 0.53 }, 3201, false)
    end,
    mossy_cobblestone = function(self, image, sx, sy, size)
        self:generateCobble(image, sx, sy, size, { r = 0.50, g = 0.51, b = 0.50 }, 3202, true)
    end,
    stone_bricks = function(self, image, sx, sy, size)
        self:generateBrickPattern(image, sx, sy, size,
            { r = 0.56, g = 0.56, b = 0.57 }, { r = 0.38, g = 0.38, b = 0.39 }, 4, 3203)
    end,
    sandstone_top    = ClassicPack.generateSandstoneTop,
    sandstone_side   = ClassicPack.generateSandstoneSide,
    sandstone_bottom = ClassicPack.generateSandstoneBottom,
    obsidian         = ClassicPack.generateObsidian,
    bedrock          = ClassicPack.generateBedrock,
    planks           = ClassicPack.generatePlanks,
    bricks = function(self, image, sx, sy, size)
        self:generateBrickPattern(image, sx, sy, size,
            { r = 0.66, g = 0.34, b = 0.28 }, { r = 0.76, g = 0.72, b = 0.68 }, 4, 3204)
    end,
    bookshelf_side = ClassicPack.generateBookshelfSide,
    crafting_top   = ClassicPack.generateCraftingTop,
    crafting_side  = ClassicPack.generateCraftingSide,
    furnace_top    = ClassicPack.generateFurnaceTop,
    furnace_side   = ClassicPack.generateFurnaceSide,

    -- Row 4：矿石 + 自然
    coal_ore     = oreGen({ r = 0.14, g = 0.14, b = 0.15 }, 7, 3301),
    iron_ore     = oreGen({ r = 0.78, g = 0.62, b = 0.50 }, 7, 3302),
    gold_ore     = oreGen({ r = 0.96, g = 0.80, b = 0.28 }, 6, 3303),
    diamond_ore  = oreGen({ r = 0.42, g = 0.90, b = 0.92 }, 5, 3304),
    redstone_ore = oreGen({ r = 0.82, g = 0.14, b = 0.12 }, 8, 3305),
    lapis_ore    = oreGen({ r = 0.16, g = 0.30, b = 0.76 }, 7, 3306),
    glowstone    = ClassicPack.generateGlowstone,
    gravel       = ClassicPack.generateGravel,
    clay         = ClassicPack.generateClay,
    snow         = ClassicPack.generateSnow,
    grass_snow_side = ClassicPack.generateGrassSnowSide,
    ice          = ClassicPack.generateIce,
    lava         = ClassicPack.generateLava,
    cactus_top    = ClassicPack.generateCactusTop,
    cactus_side   = ClassicPack.generateCactusSide,
    cactus_bottom = ClassicPack.generateCactusBottom,

    -- Row 5：透明 + 羊毛 + 植物
    glass       = ClassicPack.generateGlass,
    wool_white  = woolGen({ r = 0.93, g = 0.93, b = 0.93 }, 3401),
    wool_red    = woolGen({ r = 0.70, g = 0.20, b = 0.18 }, 3402),
    wool_yellow = woolGen({ r = 0.88, g = 0.78, b = 0.24 }, 3403),
    wool_green  = woolGen({ r = 0.32, g = 0.58, b = 0.24 }, 3404),
    wool_blue   = woolGen({ r = 0.24, g = 0.32, b = 0.70 }, 3405),
    wool_black  = woolGen({ r = 0.14, g = 0.14, b = 0.15 }, 3406),

    sapling = plantGen({
        stem = { r = 0.45, g = 0.32, b = 0.16 },
        cap = { r = 0.28, g = 0.60, b = 0.22 },
        stemHeight = 6,
    }, 3501),
    dead_bush = plantGen({
        stem = { r = 0.55, g = 0.40, b = 0.18 },
        twigs = true,
    }, 3502),
    mushroom_red = plantGen({
        stem = { r = 0.92, g = 0.90, b = 0.86 },
        cap = { r = 0.78, g = 0.18, b = 0.16 },
        mushroom = true,
        capDots = true,
        stemHeight = 5,
    }, 3503),
    mushroom_brown = plantGen({
        stem = { r = 0.86, g = 0.82, b = 0.74 },
        cap = { r = 0.58, g = 0.44, b = 0.32 },
        mushroom = true,
        stemHeight = 5,
    }, 3504),

    -- Row 6：门 / 活板门
    door_wood_lower = function(self, image, sx, sy, size)
        self:generateDoor(image, sx, sy, size, { r = 0.62, g = 0.45, b = 0.26 }, false, false, 3601)
    end,
    door_wood_upper = function(self, image, sx, sy, size)
        self:generateDoor(image, sx, sy, size, { r = 0.62, g = 0.45, b = 0.26 }, true, true, 3602)
    end,
    door_iron_lower = function(self, image, sx, sy, size)
        self:generateDoor(image, sx, sy, size, { r = 0.72, g = 0.73, b = 0.75 }, false, false, 3603)
    end,
    door_iron_upper = function(self, image, sx, sy, size)
        self:generateDoor(image, sx, sy, size, { r = 0.72, g = 0.73, b = 0.75 }, true, true, 3604)
    end,
    trapdoor_wood = ClassicPack.generateTrapdoor,
}

return ClassicPack
