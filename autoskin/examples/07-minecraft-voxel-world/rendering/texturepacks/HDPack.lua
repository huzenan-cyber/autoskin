-- ====================================================================
-- rendering/texturepacks/HDPack.lua
-- HD 高清材质包 - PBR 渲染支持
-- 采用合并生成方案：一次遍历同时生成 Diffuse + Normal + Specular
-- ====================================================================

local TexturePackBase = require("rendering.texturepacks.TexturePackBase")
local Atlas = require("rendering.texturepacks.AtlasLayout")

---@class HDPack : TexturePackBase
local HDPack = TexturePackBase.new({
    name = "hd",
    displayName = "HD PBR (32x32)",
    tileSize = 32,
    atlasSize = 512,
    tilesPerRow = 16,
    isPBR = true,  -- 标记为 PBR 材质包
})

-- 纹理缓存（避免重复生成）
HDPack._cachedTextures = nil

---重写 getFilterMode
---使用 FILTER_BILINEAR（不启用 mipmap）避免采样到相邻 tile
---FILTER_TRILINEAR 会在远处 mipmap 采样时扩展到相邻纹理
---@return TextureFilterMode 滤波模式
function HDPack:getFilterMode()
    return FILTER_BILINEAR
end

---生成三张图集 Image（不建 Texture，供 generate() 与 devtools/DumpAtlas.lua 共用）
---tile 摆放由 AtlasLayout 单点决定，这里只负责按名字派发到生成器
---@return table { diffuse: Image, normal: Image, specular: Image }
function HDPack:createImages()
    print("[HDPack] Creating HD PBR texture atlas...")

    -- 创建三张 Image
    local images = {
        diffuse = Image(),
        normal = Image(),
        specular = Image(),
    }
    images.diffuse:SetSize(self.atlasSize, self.atlasSize, 4)
    images.normal:SetSize(self.atlasSize, self.atlasSize, 4)
    images.specular:SetSize(self.atlasSize, self.atlasSize, 4)

    local tileSize = self.tileSize

    -- 先填充未使用区域（用中性色）
    self:fillUnusedTiles(images)

    local missing = 0
    for _, entry in ipairs(Atlas.order) do
        local generator = self.tileGenerators[entry.name]
        if generator then
            generator(self, images, entry.col * tileSize, entry.row * tileSize, tileSize)
        else
            missing = missing + 1
            print("[HDPack] WARNING: no generator for tile '" .. entry.name .. "'")
        end
    end

    -- 不使用边缘挤出（会覆盖相邻 tile），改用 UV padding 方案

    print(string.format("[HDPack] HD PBR texture atlas created! (%d tiles, %d missing)",
        Atlas.count(), missing))
    return images
end

---重写 generate()，合并生成三张贴图
---使用缓存避免重复生成
---@return table { diffuse: Texture2D, normal: Texture2D, specular: Texture2D }
function HDPack:generate()
    -- 检查缓存，避免重复生成纹理图集
    if self._cachedTextures then
        return self._cachedTextures
    end

    local images = self:createImages()

    -- 缓存生成的纹理，避免重复生成
    self._cachedTextures = {
        diffuse = self:createTexture(images.diffuse, true),
        normal = self:createTexture(images.normal, false),
        specular = self:createTexture(images.specular, false),
    }

    return self._cachedTextures
end

-- ============================================
-- PBR 方块生成方法
-- 合并生成 Diffuse + Normal + Specular
-- ============================================

---生成草地顶部 - PBR（四方连续）
function HDPack:generateGrassTop(images, startX, startY, tileSize)
    local heightMap = {}
    local metallic, roughness = 0.0, 0.9
    local normalStrength = 0.3
    
    -- 第一遍：生成 Diffuse + 记录高度 + 写 Specular
    for y = 0, tileSize - 1 do
        heightMap[y] = {}
        for x = 0, tileSize - 1 do
            -- 使用周期性噪声，确保边缘连续
            local noise = self:periodicSmoothNoise(x, y, tileSize, 42) * 0.08
            
            local r = 0.32 + noise
            local g = 0.72 + noise * 0.5
            local b = 0.22 + noise * 0.3
            
            images.diffuse:SetPixel(startX + x, startY + y, Color(r, g, b, 1.0))
            images.specular:SetPixel(startX + x, startY + y, Color(roughness, metallic, 1.0, 1.0))
            heightMap[y][x] = (r + g + b) / 3
        end
    end
    
    -- 第二遍：从高度图计算法线（已支持周期性边界）
    for y = 0, tileSize - 1 do
        for x = 0, tileSize - 1 do
            local nx, ny, nz = self:computeNormalFromHeight(heightMap, x, y, tileSize, normalStrength)
            images.normal:SetPixel(startX + x, startY + y, Color(nx, ny, nz, 1.0))
        end
    end
end

---生成草地侧面 - PBR（带垂挂草叶装饰）
function HDPack:generateGrassSide(images, startX, startY, tileSize)
    local heightMap = {}
    local metallic, roughness = 0.0, 0.9
    local normalStrength = 0.4
    local grassHeight = math.floor(tileSize * 0.15)  -- 顶部 15% 是草地层
    
    -- 生成草叶位置和长度（周期性，确保 X 轴连续）
    local grassBlades = {}
    local numBlades = math.floor(tileSize * 0.6)  -- 约 60% 密度的草叶
    for i = 1, numBlades do
        local bladeX = (i * 2 + math.floor(self:periodicNoise(i, 1, numBlades, 888) * 3)) % tileSize
        local bladeLength = math.floor(2 + self:periodicNoise(i, 2, numBlades, 999) * 0.5 * tileSize * 0.2)
        grassBlades[bladeX] = grassBlades[bladeX] or {}
        table.insert(grassBlades[bladeX], bladeLength)
    end
    
    for y = 0, tileSize - 1 do
        heightMap[y] = {}
        for x = 0, tileSize - 1 do
            -- X轴使用周期性噪声
            local noise = self:periodicSmoothNoise(x, 0, tileSize, 43 + y) * 0.06
            local r, g, b
            local isGrassBlade = false
            
            -- 检查是否是草叶位置
            if grassBlades[x] then
                for _, bladeLen in ipairs(grassBlades[x]) do
                    if y >= grassHeight and y < grassHeight + bladeLen then
                        isGrassBlade = true
                        break
                    end
                end
            end
            
            if y < grassHeight then
                -- 顶部草地层
                local fade = y / grassHeight
                r = 0.30 + fade * 0.05 + noise
                g = 0.70 - fade * 0.05 + noise * 0.3
                b = 0.20 + noise * 0.2
            elseif isGrassBlade then
                -- 垂挂的草叶（绿色，稍暗）
                local bladeDepth = (y - grassHeight) / (tileSize * 0.3)
                r = 0.25 + noise * 0.5
                g = 0.55 - bladeDepth * 0.15 + noise * 0.3
                b = 0.15 + noise * 0.2
            else
                -- 泥土层
                local depth = (y - grassHeight) / (tileSize - grassHeight)
                r = 0.52 - depth * 0.08 + noise
                g = 0.36 - depth * 0.06 + noise * 0.5
                b = 0.20 - depth * 0.04 + noise * 0.3
            end
            
            images.diffuse:SetPixel(startX + x, startY + y, Color(r, g, b, 1.0))
            images.specular:SetPixel(startX + x, startY + y, Color(roughness, metallic, 1.0, 1.0))
            heightMap[y][x] = (r + g + b) / 3
        end
    end
    
    for y = 0, tileSize - 1 do
        for x = 0, tileSize - 1 do
            local nx, ny, nz = self:computeNormalFromHeight(heightMap, x, y, tileSize, normalStrength)
            images.normal:SetPixel(startX + x, startY + y, Color(nx, ny, nz, 1.0))
        end
    end
end

---生成泥土 - PBR（四方连续）
function HDPack:generateDirt(images, startX, startY, tileSize)
    local heightMap = {}
    local metallic, roughness = 0.0, 0.95
    local normalStrength = 0.5
    
    for y = 0, tileSize - 1 do
        heightMap[y] = {}
        for x = 0, tileSize - 1 do
            -- 使用周期性噪声
            local noise = self:periodicSmoothNoise(x, y, tileSize, 123) * 0.1
            
            local r = 0.52 + noise
            local g = 0.36 + noise * 0.6
            local b = 0.20 + noise * 0.4
            
            images.diffuse:SetPixel(startX + x, startY + y, Color(r, g, b, 1.0))
            images.specular:SetPixel(startX + x, startY + y, Color(roughness, metallic, 1.0, 1.0))
            heightMap[y][x] = (r + g + b) / 3
        end
    end
    
    for y = 0, tileSize - 1 do
        for x = 0, tileSize - 1 do
            local nx, ny, nz = self:computeNormalFromHeight(heightMap, x, y, tileSize, normalStrength)
            images.normal:SetPixel(startX + x, startY + y, Color(nx, ny, nz, 1.0))
        end
    end
end

---生成石头 - PBR（四方连续，明显凹凸）
function HDPack:generateStone(images, startX, startY, tileSize)
    local heightMap = {}
    local metallic, roughness = 0.0, 0.7
    local normalStrength = 2.0
    
    for y = 0, tileSize - 1 do
        heightMap[y] = {}
        for x = 0, tileSize - 1 do
            -- 使用周期性噪声
            local noise = self:periodicSmoothNoise(x, y, tileSize, 456) * 0.08
            local baseGray = 0.55 + noise
            
            -- 周期性裂缝（使用周期为 tileSize 的 sin/cos）
            local crack = 0
            local px = (x / tileSize) * 2 * math.pi * 2  -- 2 个周期
            local py = (y / tileSize) * 2 * math.pi * 2
            local crackPattern = math.sin(px) * math.cos(py)
            if math.abs(crackPattern) > 0.9 then
                crack = -0.05
            end
            
            local brightness = baseGray + crack
            images.diffuse:SetPixel(startX + x, startY + y, Color(brightness, brightness, brightness + 0.02, 1.0))
            images.specular:SetPixel(startX + x, startY + y, Color(roughness, metallic, 1.0, 1.0))
            heightMap[y][x] = brightness
        end
    end
    
    for y = 0, tileSize - 1 do
        for x = 0, tileSize - 1 do
            local nx, ny, nz = self:computeNormalFromHeight(heightMap, x, y, tileSize, normalStrength)
            images.normal:SetPixel(startX + x, startY + y, Color(nx, ny, nz, 1.0))
        end
    end
end

---生成木头顶部（年轮） - PBR（年轮本身是圆心对称的）
function HDPack:generateWoodTop(images, startX, startY, tileSize)
    local heightMap = {}
    local metallic, roughness = 0.0, 0.6
    local normalStrength = 0.5
    
    for y = 0, tileSize - 1 do
        heightMap[y] = {}
        for x = 0, tileSize - 1 do
            local centerX, centerY = tileSize / 2, tileSize / 2
            local dx, dy = x - centerX, y - centerY
            local dist = math.sqrt(dx * dx + dy * dy)
            
            local ringDist = dist % 6
            local ringIntensity = math.sin(ringDist * math.pi / 3) * 0.5 + 0.5
            
            local r = self:lerp(0.55, 0.70, ringIntensity)
            local g = self:lerp(0.40, 0.55, ringIntensity)
            local b = self:lerp(0.25, 0.35, ringIntensity)
            
            -- 使用周期性噪声添加细节
            local noise = self:periodicSmoothNoise(x, y, tileSize, 150) * 0.04
            images.diffuse:SetPixel(startX + x, startY + y, Color(r + noise, g + noise, b + noise, 1.0))
            images.specular:SetPixel(startX + x, startY + y, Color(roughness, metallic, 1.0, 1.0))
            heightMap[y][x] = ringIntensity
        end
    end
    
    for y = 0, tileSize - 1 do
        for x = 0, tileSize - 1 do
            local nx, ny, nz = self:computeNormalFromHeight(heightMap, x, y, tileSize, normalStrength)
            images.normal:SetPixel(startX + x, startY + y, Color(nx, ny, nz, 1.0))
        end
    end
end

---生成木头侧面（木纹） - PBR（X轴四方连续）
function HDPack:generateWoodSide(images, startX, startY, tileSize)
    local heightMap = {}
    local metallic, roughness = 0.0, 0.6
    local normalStrength = 0.8
    
    for y = 0, tileSize - 1 do
        heightMap[y] = {}
        for x = 0, tileSize - 1 do
            -- 使用周期性条纹（确保 X 轴连续）
            local px = (x / tileSize) * 2 * math.pi * 4  -- 4 个完整周期
            local stripePhase = math.sin(px) * 0.5 + 0.5
            -- X轴周期性噪声
            local noise = self:periodicSmoothNoise(x, 0, tileSize, 789 + y) * 0.05
            
            local r = self:lerp(0.38, 0.48, stripePhase) + noise
            local g = self:lerp(0.26, 0.34, stripePhase) + noise * 0.7
            local b = self:lerp(0.14, 0.20, stripePhase) + noise * 0.5
            
            images.diffuse:SetPixel(startX + x, startY + y, Color(r, g, b, 1.0))
            images.specular:SetPixel(startX + x, startY + y, Color(roughness, metallic, 1.0, 1.0))
            heightMap[y][x] = stripePhase
        end
    end
    
    for y = 0, tileSize - 1 do
        for x = 0, tileSize - 1 do
            local nx, ny, nz = self:computeNormalFromHeight(heightMap, x, y, tileSize, normalStrength)
            images.normal:SetPixel(startX + x, startY + y, Color(nx, ny, nz, 1.0))
        end
    end
end

---生成树叶 - PBR（四方连续）
function HDPack:generateLeaves(images, startX, startY, tileSize)
    local heightMap = {}
    local metallic, roughness = 0.0, 0.85
    local normalStrength = 0.2
    
    for y = 0, tileSize - 1 do
        heightMap[y] = {}
        for x = 0, tileSize - 1 do
            -- 周期性噪声
            local noise = self:periodicSmoothNoise(x, y, tileSize, 101112) * 0.15
            -- 周期性图案
            local px = (x / tileSize) * 2 * math.pi * 3
            local py = (y / tileSize) * 2 * math.pi * 3
            local pattern = math.sin(px) * math.cos(py) * 0.1
            
            local r = 0.18 + pattern + noise * 0.2
            local g = 0.52 + pattern + noise * 0.1
            local b = 0.14 + pattern + noise * 0.15
            
            images.diffuse:SetPixel(startX + x, startY + y, Color(r, g, b, 1.0))
            images.specular:SetPixel(startX + x, startY + y, Color(roughness, metallic, 1.0, 1.0))
            heightMap[y][x] = (r + g + b) / 3
        end
    end
    
    for y = 0, tileSize - 1 do
        for x = 0, tileSize - 1 do
            local nx, ny, nz = self:computeNormalFromHeight(heightMap, x, y, tileSize, normalStrength)
            images.normal:SetPixel(startX + x, startY + y, Color(nx, ny, nz, 1.0))
        end
    end
end

---生成沙子 - PBR（四方连续）
function HDPack:generateSand(images, startX, startY, tileSize)
    local heightMap = {}
    local metallic, roughness = 0.0, 0.95
    local normalStrength = 0.4
    
    for y = 0, tileSize - 1 do
        heightMap[y] = {}
        for x = 0, tileSize - 1 do
            -- 周期性噪声
            local noise = self:periodicSmoothNoise(x, y, tileSize, 131415) * 0.08
            
            local r = 0.88 + noise
            local g = 0.80 + noise * 0.8
            local b = 0.58 + noise * 0.5
            
            images.diffuse:SetPixel(startX + x, startY + y, Color(r, g, b, 1.0))
            images.specular:SetPixel(startX + x, startY + y, Color(roughness, metallic, 1.0, 1.0))
            heightMap[y][x] = (r + g + b) / 3
        end
    end
    
    for y = 0, tileSize - 1 do
        for x = 0, tileSize - 1 do
            local nx, ny, nz = self:computeNormalFromHeight(heightMap, x, y, tileSize, normalStrength)
            images.normal:SetPixel(startX + x, startY + y, Color(nx, ny, nz, 1.0))
        end
    end
end

---生成水 - PBR（四方连续，低粗糙度，反光）
function HDPack:generateWater(images, startX, startY, tileSize)
    local heightMap = {}
    local metallic, roughness = 0.0, 0.1
    local normalStrength = 0.1
    
    for y = 0, tileSize - 1 do
        heightMap[y] = {}
        for x = 0, tileSize - 1 do
            -- 周期性波纹
            local px = (x / tileSize) * 2 * math.pi * 2
            local py = (y / tileSize) * 2 * math.pi * 2
            local wave = math.sin(px + py * 0.5) * 0.05
            -- 周期性噪声
            local noise = self:periodicSmoothNoise(x, y, tileSize, 200) * 0.03
            
            local r = 0.18 + wave + noise
            local g = 0.42 + wave + noise
            local b = 0.78 + wave * 0.3
            
            images.diffuse:SetPixel(startX + x, startY + y, Color(r, g, b, 0.85))
            images.specular:SetPixel(startX + x, startY + y, Color(roughness, metallic, 1.0, 1.0))
            heightMap[y][x] = wave + 0.5
        end
    end
    
    for y = 0, tileSize - 1 do
        for x = 0, tileSize - 1 do
            local nx, ny, nz = self:computeNormalFromHeight(heightMap, x, y, tileSize, normalStrength)
            images.normal:SetPixel(startX + x, startY + y, Color(nx, ny, nz, 1.0))
        end
    end
end

---生成装饰草 - PBR（交叉网格用，带透明通道）
---经典 Minecraft 风格：模仿原版像素布局，适配 32x32 分辨率
function HDPack:generateTallGrass(images, startX, startY, tileSize)
    local metallic, roughness = 0.0, 0.85
    
    -- 先填充透明背景
    for y = 0, tileSize - 1 do
        for x = 0, tileSize - 1 do
            images.diffuse:SetPixel(startX + x, startY + y, Color(0, 0, 0, 0))
            images.normal:SetPixel(startX + x, startY + y, Color(0.5, 0.5, 1.0, 0.0))
            images.specular:SetPixel(startX + x, startY + y, Color(roughness, metallic, 1.0, 0.0))
        end
    end
    
    -- 高度图
    local heightMap = {}
    for y = 0, tileSize - 1 do
        heightMap[y] = {}
        for x = 0, tileSize - 1 do
            heightMap[y][x] = 0.5
        end
    end
    
    -- 颜色调色板 (基于草地顶部颜色优化，更清爽，匹配 HD 草地)
    local colors = {
        [1] = { r = 0.25, g = 0.60, b = 0.18 }, -- 深绿 (阴影)
        [2] = { r = 0.32, g = 0.72, b = 0.22 }, -- 基底绿 (匹配草地)
        [3] = { r = 0.40, g = 0.80, b = 0.28 }, -- 亮绿 (高光)
        [4] = { r = 0.48, g = 0.88, b = 0.35 }, -- 顶端嫩绿
    }
    
    -- 定义像素图案 (16x16网格，会自动放大到32x32)
    -- 0=空, 1-4=颜色索引
    -- 模仿原版草的杂乱像素分布
    local pattern16x16 = {
        {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}, -- Row 0 (Top)
        {0,0,0,4,0,0,0,0,0,0,0,0,0,0,0,0},
        {0,0,0,4,0,0,4,0,0,0,0,0,0,0,0,0},
        {4,0,0,3,0,0,4,0,0,0,0,4,0,4,0,0},
        {4,0,4,3,0,0,3,4,0,0,0,4,0,4,0,0}, -- Row 4
        {3,0,3,2,0,4,3,3,0,0,4,3,0,3,0,0},
        {3,0,3,2,0,3,2,3,0,0,3,3,0,3,0,0},
        {3,0,3,2,0,3,2,3,4,0,3,2,0,2,0,0},
        {3,0,2,1,0,3,2,2,3,4,2,2,0,2,0,0}, -- Row 8
        {2,0,2,1,0,3,2,2,3,3,2,1,0,2,4,0},
        {2,0,2,1,4,2,1,2,3,3,2,1,0,2,3,0},
        {2,0,2,1,3,2,1,2,2,3,2,1,0,2,3,0},
        {2,0,1,1,2,2,1,1,2,2,1,1,0,1,2,0}, -- Row 12
        {2,0,1,1,2,2,1,1,2,2,1,1,0,1,2,0},
        {1,0,1,1,2,1,1,1,1,2,1,1,0,1,1,4},
        {1,0,1,1,1,1,1,1,1,1,1,1,0,1,1,3}, -- Row 15 (Bottom)
    }
    
    -- 缩放因子 (32/16 = 2)
    local scale = math.floor(tileSize / 16)
    
    -- 绘制像素
    for py = 0, 15 do
        for px = 0, 15 do
            local colorIdx = pattern16x16[py + 1][px + 1]
            if colorIdx > 0 then
                local color = colors[colorIdx]
                
                -- 在 32x32 图上绘制 2x2 的块
                for dy = 0, scale - 1 do
                    for dx = 0, scale - 1 do
                        local x = px * scale + dx
                        local y = py * scale + dy
                        
                        -- 添加一点点随机杂色，让大像素不那么单调
                        local noise = (math.random() - 0.5) * 0.05
                        local r = math.max(0, math.min(1, color.r + noise))
                        local g = math.max(0, math.min(1, color.g + noise))
                        local b = math.max(0, math.min(1, color.b + noise))
                        
                        -- 边缘像素稍微暗一点点
                        if dx == 0 or dx == scale - 1 or dy == 0 or dy == scale - 1 then
                            r = r * 0.95
                            g = g * 0.95
                            b = b * 0.95
                        end
                        
                        if x >= 0 and x < tileSize and y >= 0 and y < tileSize then
                            images.diffuse:SetPixel(startX + x, startY + y, Color(r, g, b, 1.0))
                            images.specular:SetPixel(startX + x, startY + y, Color(roughness, metallic, 1.0, 1.0))
                            
                            -- 高度图：根据颜色索引决定高度（越亮越高）
                            heightMap[y][x] = 0.4 + colorIdx * 0.1
                        end
                    end
                end
            end
        end
    end
    
    -- 计算法线
    local normalStrength = 0.3
    for y = 0, tileSize - 1 do
        for x = 0, tileSize - 1 do
            local diffuseColor = images.diffuse:GetPixel(startX + x, startY + y)
            if diffuseColor.a > 0.5 then
                local nx, ny, nz = self:computeNormalFromHeight(heightMap, x, y, tileSize, normalStrength)
                images.normal:SetPixel(startX + x, startY + y, Color(nx, ny, nz, 1.0))
            end
        end
    end
end

---生成火把纹理 - PBR（用于纹理图集，实际手持渲染使用模型）
function HDPack:generateTorch(images, startX, startY, tileSize)
    local metallic, roughness = 0.0, 0.85
    
    -- 先填充透明背景
    for y = 0, tileSize - 1 do
        for x = 0, tileSize - 1 do
            images.diffuse:SetPixel(startX + x, startY + y, Color(0, 0, 0, 0))
            images.normal:SetPixel(startX + x, startY + y, Color(0.5, 0.5, 1.0, 0.0))
            images.specular:SetPixel(startX + x, startY + y, Color(roughness, metallic, 1.0, 0.0))
        end
    end
    
    -- 火把参数
    local centerX = math.floor(tileSize / 2)
    local stickWidth = math.max(2, math.floor(tileSize / 6))
    local stickHeight = math.floor(tileSize * 0.55)
    local flameHeight = math.floor(tileSize * 0.35)
    
    -- 木棍颜色
    local stickColor = { r = 0.5, g = 0.3, b = 0.15 }
    -- 火焰颜色
    ---@type { r: number, g: number, b: number }[]
    local flameColors = {
        { r = 1.0, g = 0.3, b = 0.05 },  -- 外焰（橙红）
        { r = 1.0, g = 0.6, b = 0.1 },   -- 中焰（橙）
        { r = 1.0, g = 0.9, b = 0.3 },   -- 内焰（黄）
    }
    
    -- 绘制木棍（从底部往上）
    local stickStartY = tileSize - 1
    local stickEndY = tileSize - stickHeight
    for y = stickStartY, stickEndY, -1 do
        for dx = -stickWidth/2, stickWidth/2 do
            local px = centerX + math.floor(dx)
            if px >= 0 and px < tileSize then
                math.randomseed(px * 1234 + y * 5678)
                local noise = (math.random() - 0.5) * 0.1
                images.diffuse:SetPixel(startX + px, startY + y, Color(
                    stickColor.r + noise,
                    stickColor.g + noise * 0.5,
                    stickColor.b + noise * 0.3,
                    1.0
                ))
                images.normal:SetPixel(startX + px, startY + y, Color(0.5, 0.5, 1.0, 1.0))
                images.specular:SetPixel(startX + px, startY + y, Color(0.9, 0.0, 1.0, 1.0))
            end
        end
    end
    
    -- 绘制火焰（从木棍顶部往上）
    local flameStartY = stickEndY
    local flameEndY = stickEndY - flameHeight
    local flameMaxWidth = math.floor(tileSize / 3)
    
    for y = flameStartY, flameEndY, -1 do
        local progress = (flameStartY - y) / flameHeight
        -- 火焰逐渐变细
        local currentWidth = math.floor(flameMaxWidth * (1 - progress * 0.7))
        
        for dx = -currentWidth, currentWidth do
            local px = centerX + dx
            if px >= 0 and px < tileSize then
                -- 根据到中心的距离选择颜色
                local distFromCenter = math.abs(dx) / math.max(1, currentWidth)
                local colorIdx
                if distFromCenter > 0.6 then
                    colorIdx = 1  -- 外焰
                elseif distFromCenter > 0.3 then
                    colorIdx = 2  -- 中焰
                else
                    colorIdx = 3  -- 内焰
                end
                
                local fc = flameColors[colorIdx]
                images.diffuse:SetPixel(startX + px, startY + y, Color(fc.r, fc.g, fc.b, 1.0))
                images.normal:SetPixel(startX + px, startY + y, Color(0.5, 0.5, 1.0, 1.0))
                -- 火焰是自发光的，设置高发光
                images.specular:SetPixel(startX + px, startY + y, Color(0.2, 0.0, 1.0, 1.0))
            end
        end
    end
end

---生成花朵 - PBR
---@param baseColor table {r,g,b} 花朵主色调
---@param shape string 花朵形状 "rose", "simple", "bulb"
function HDPack:generateFlower(images, startX, startY, tileSize, baseColor, shape)
    local metallic, roughness = 0.0, 0.8
    
    -- 先填充透明背景
    for y = 0, tileSize - 1 do
        for x = 0, tileSize - 1 do
            images.diffuse:SetPixel(startX + x, startY + y, Color(0, 0, 0, 0))
            images.normal:SetPixel(startX + x, startY + y, Color(0.5, 0.5, 1.0, 0.0))
            images.specular:SetPixel(startX + x, startY + y, Color(roughness, metallic, 1.0, 0.0))
        end
    end

    local heightMap = {}
    for y = 0, tileSize - 1 do
        heightMap[y] = {}
        for x = 0, tileSize - 1 do
            heightMap[y][x] = 0.5
        end
    end

    -- 调色板 - 使用纯色，不做暗化处理
    local colors = {
        [1] = { r = 0.20, g = 0.55, b = 0.15 }, -- 茎绿色
        [2] = { r = 0.30, g = 0.70, b = 0.20 }, -- 叶亮绿
        [3] = { r = baseColor.r, g = baseColor.g, b = baseColor.b }, -- 花瓣主色
        [4] = { r = baseColor.r, g = baseColor.g, b = baseColor.b }, -- 花瓣主色
        [5] = { r = math.min(1, baseColor.r + 0.15), g = math.min(1, baseColor.g + 0.15), b = math.min(1, baseColor.b + 0.15) }, -- 花瓣高光（稍亮）
    }

    -- 图案定义 (16x16) - 所有图案以 px=7-8 为中心（16像素纹理的正中心）
    local pattern16x16 = {}
    
    if shape == "rose" then
        -- 玫瑰：居中版本，花瓣和茎都以 px=7-8 为中心
        pattern16x16 = {
            {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,3,4,4,3,0,0,0,0,0,0},
            {0,0,0,0,0,3,4,5,5,4,3,0,0,0,0,0},
            {0,0,0,0,0,4,5,5,5,5,4,0,0,0,0,0},
            {0,0,0,0,0,3,4,5,5,4,3,0,0,0,0,0},
            {0,0,0,0,0,0,3,4,4,3,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,2,1,1,2,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,2,1,1,2,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0},
        }
    elseif shape == "simple" then
        -- 简单花：居中版本，四瓣花以 px=7-8 为中心
        pattern16x16 = {
            {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,4,4,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,4,5,5,4,0,0,0,0,0,0},
            {0,0,0,0,0,4,5,4,4,5,4,0,0,0,0,0},
            {0,0,0,0,0,4,5,4,4,5,4,0,0,0,0,0},
            {0,0,0,0,0,0,4,5,5,4,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,4,4,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,2,1,1,2,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,2,1,1,2,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0},
        }
    else -- bulb
        -- 花苞：居中版本，以 px=7-8 为中心
        pattern16x16 = {
            {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,4,4,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,4,5,5,4,0,0,0,0,0,0},
            {0,0,0,0,0,4,5,5,5,5,4,0,0,0,0,0},
            {0,0,0,0,0,4,4,3,3,4,4,0,0,0,0,0},
            {0,0,0,0,0,0,4,3,3,4,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,2,1,1,2,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0},
        }
    end

    -- 缩放因子
    local scale = math.floor(tileSize / 16)
    
    -- 绘制像素
    for py = 0, 15 do
        for px = 0, 15 do
            local colorIdx = pattern16x16[py + 1][px + 1]
            if colorIdx > 0 then
                local color = colors[colorIdx]
                
                -- 在 32x32 图上绘制 2x2 的块
                for dy = 0, scale - 1 do
                    for dx = 0, scale - 1 do
                        local x = px * scale + dx
                        local y = py * scale + dy
                        
                        -- 直接使用纯色，不添加噪声
                        local r = color.r
                        local g = color.g
                        local b = color.b
                        
                        if x >= 0 and x < tileSize and y >= 0 and y < tileSize then
                            images.diffuse:SetPixel(startX + x, startY + y, Color(r, g, b, 1.0))
                            images.specular:SetPixel(startX + x, startY + y, Color(roughness, metallic, 1.0, 1.0))
                            heightMap[y][x] = 0.4 + colorIdx * 0.1
                        end
                    end
                end
            end
        end
    end
    
    -- 计算法线
    local normalStrength = 0.3
    for y = 0, tileSize - 1 do
        for x = 0, tileSize - 1 do
            local diffuseColor = images.diffuse:GetPixel(startX + x, startY + y)
            if diffuseColor.a > 0.5 then
                local nx, ny, nz = self:computeNormalFromHeight(heightMap, x, y, tileSize, normalStrength)
                images.normal:SetPixel(startX + x, startY + y, Color(nx, ny, nz, 1.0))
            end
        end
    end
end

---填充未使用的格子（使用中性色而非紫色）
---已用格子从 AtlasLayout 反推（以前写死行列范围，加新 tile 会被灰色覆盖）
function HDPack:fillUnusedTiles(images)
    local tileSize = self.tileSize
    for row = 0, self.tilesPerRow - 1 do
        for col = 0, self.tilesPerRow - 1 do
            if not Atlas.isUsed(row, col) then
                local startX = col * tileSize
                local startY = row * tileSize
                for y = 0, tileSize - 1 do
                    for x = 0, tileSize - 1 do
                        -- 使用中性灰色而非紫色（防止 mipmap 采样问题）
                        images.diffuse:SetPixel(startX + x, startY + y, Color(0.5, 0.5, 0.5, 1.0))
                        -- 默认平面法线
                        images.normal:SetPixel(startX + x, startY + y, Color(0.5, 0.5, 1.0, 1.0))
                        -- 默认粗糙度 1.0
                        images.specular:SetPixel(startX + x, startY + y, Color(1.0, 0.0, 1.0, 1.0))
                    end
                end
            end
        end
    end
end

-- ====================================================================
-- 通用 PBR tile 生成器
--
-- 新方块只需写一个"逐像素着色函数"，diffuse / normal / specular 三张图
-- 由这里统一产出：normal 从亮度高度图算（周期性边界），specular 写 R=粗糙度 G=金属度
-- （与 PBRLitSolid.glsl 约定一致）
-- ====================================================================

---@param shade function (x, y, size) -> r, g, b, a?, height?, roughness?, metallic?
---@param opts table|nil { roughness, metallic, normalStrength }
function HDPack:generatePBRTile(images, sx, sy, size, shade, opts)
    opts = opts or {}
    local baseRough = opts.roughness or 0.85
    local baseMetal = opts.metallic or 0.0
    local normalStrength = opts.normalStrength or 0.5

    local heightMap = {}
    for y = 0, size - 1 do
        heightMap[y] = {}
        for x = 0, size - 1 do
            local r, g, b, a, h, rough, metal = shade(x, y, size)
            a = a or 1.0
            images.diffuse:SetPixel(sx + x, sy + y, Color(r, g, b, a))
            images.specular:SetPixel(sx + x, sy + y, Color(rough or baseRough, metal or baseMetal, 1.0, a))
            heightMap[y][x] = h or ((r + g + b) / 3)
        end
    end

    for y = 0, size - 1 do
        for x = 0, size - 1 do
            local nx, ny, nz = self:computeNormalFromHeight(heightMap, x, y, size, normalStrength)
            images.normal:SetPixel(sx + x, sy + y, Color(nx, ny, nz, 1.0))
        end
    end
end

-- ====================================================================
-- 参数化生成器（矿石 / 卵石 / 砖 / 羊毛 / 交叉网格植物）
-- ====================================================================

---矿石：石头底 + 矿斑（金属矿石给低粗糙 + 高金属度，钻石给玻璃质感）
function HDPack:generateOre(images, sx, sy, size, ore, blobCount, seed, oreRough, oreMetal)
    -- 预生成矿斑掩码（1=边缘, 2=中心）
    math.randomseed(seed)
    local radius = math.max(1, math.floor(size / 11))
    local mask = {}
    for y = 0, size - 1 do mask[y] = {} end

    for _ = 1, blobCount do
        local cx = math.random(radius, size - 1 - radius)
        local cy = math.random(radius, size - 1 - radius)
        local r = radius + (math.random() < 0.35 and 1 or 0)
        for dy = -r, r do
            for dx = -r, r do
                local d2 = dx * dx + dy * dy
                if d2 <= r * r then
                    local px, py = cx + dx, cy + dy
                    if px >= 0 and px < size and py >= 0 and py < size then
                        mask[py][px] = (d2 >= (r - 1) * (r - 1)) and 1 or 2
                    end
                end
            end
        end
    end

    local pack = self
    self:generatePBRTile(images, sx, sy, size, function(x, y, s)
        local noise = pack:periodicSmoothNoise(x, y, s, 456) * 0.08
        local base = 0.55 + noise
        local m = mask[y][x]
        if not m then
            return base, base, base + 0.02, 1.0, base, 0.7, 0.0
        end
        -- 矿斑：边缘压暗 + 抬高高度图（凸起感）
        local shadeMul = (m == 1) and 0.74 or 1.0
        return ore.r * shadeMul + noise * 0.4,
               ore.g * shadeMul + noise * 0.4,
               ore.b * shadeMul + noise * 0.4,
               1.0, base + 0.22, oreRough or 0.45, oreMetal or 0.0
    end, { roughness = 0.7, normalStrength = 1.6 })
end

---卵石类（圆石 / 苔石）：Voronoi 分块 + 缝隙压暗压低
function HDPack:generateCobble(images, sx, sy, size, base, seed, mossy)
    math.randomseed(seed)
    local pointCount = 7
    local pts = {}
    for i = 1, pointCount do
        pts[i] = {
            x = math.random(0, size - 1),
            y = math.random(0, size - 1),
            v = 0.85 + math.random() * 0.30,
            moss = math.random() < 0.45,
        }
    end

    local pack = self
    local half = size / 2
    self:generatePBRTile(images, sx, sy, size, function(x, y, s)
        local best, second, bi = 1e9, 1e9, 1
        for i = 1, pointCount do
            -- 周期性距离，保证四方连续
            local dx = math.abs(x - pts[i].x); if dx > half then dx = s - dx end
            local dy = math.abs(y - pts[i].y); if dy > half then dy = s - dy end
            local d = dx * dx + dy * dy
            if d < best then second = best; best = d; bi = i
            elseif d < second then second = d end
        end

        local noise = pack:periodicSmoothNoise(x, y, s, seed) * 0.06
        local isGap = (math.sqrt(second) - math.sqrt(best)) < 1.2
        if isGap then
            local v = base.r * 0.5 + noise
            return v, base.g * 0.5 + noise, base.b * 0.5 + noise, 1.0, 0.15, 0.9, 0.0
        end

        local v = pts[bi].v
        local r, g, b = base.r * v + noise, base.g * v + noise, base.b * v + noise
        if mossy and pts[bi].moss then
            r = r * 0.45 + 0.10
            g = g * 0.60 + 0.26
            b = b * 0.40 + 0.08
        end
        -- 石块中心略高，边缘略低 → 鹅卵石凸起
        local bulge = 0.55 + math.min(0.35, math.sqrt(best) * 0.06)
        return r, g, b, 1.0, bulge, 0.75, 0.0
    end, { normalStrength = 2.2 })
end

---砖石类（红砖 / 石砖）：错缝砖块 + 凹陷灰缝
function HDPack:generateBrickPattern(images, sx, sy, size, brick, mortar, rows, seed)
    local pack = self
    local rowH = math.max(3, math.floor(size / rows))
    local brickW = math.max(4, math.floor(size / 2))

    self:generatePBRTile(images, sx, sy, size, function(x, y, s)
        local rowIdx = math.floor(y / rowH)
        local offset = (rowIdx % 2 == 0) and 0 or math.floor(brickW / 2)
        local onMortar = (y % rowH) == 0 or ((x + offset) % brickW) == 0
        local noise = pack:periodicSmoothNoise(x, y, s, seed) * 0.06

        if onMortar then
            return mortar.r + noise, mortar.g + noise, mortar.b + noise, 1.0, 0.2, 0.95, 0.0
        end
        local inRow = (y % rowH) / rowH
        local shade = 1.05 - inRow * 0.14
        return brick.r * shade + noise, brick.g * shade + noise, brick.b * shade + noise,
               1.0, 0.75, 0.8, 0.0
    end, { normalStrength = 2.0 })
end

---羊毛：底色 + 针织交错纹理（高粗糙、无金属）
function HDPack:generateWool(images, sx, sy, size, base, seed)
    local pack = self
    self:generatePBRTile(images, sx, sy, size, function(x, y, s)
        local noise = pack:periodicSmoothNoise(x, y, s, seed) * 0.08
        -- 周期性针织纹：4 像素一组、幅度压到刚好看得见
        -- （幅度大 + 2 像素周期时，浅色羊毛会读成"透明棋盘格"）
        local knit = (((math.floor(x / 4) + math.floor(y / 4)) % 2) == 0) and 0.014 or -0.014
        local v = noise + knit
        return base.r + v, base.g + v, base.b + v, 1.0, 0.5 + knit * 6, 0.95, 0.0
    end, { normalStrength = 0.8 })
end

---交叉网格植物（树苗 / 枯灌木 / 蘑菇）：先算掩码再着色，掩码外 alpha=0
---@param opts table 与 ClassicPack:generateCrossPlant 同构
function HDPack:generateCrossPlant(images, sx, sy, size, opts, seed)
    math.randomseed(seed)

    -- mask[y][x] = 颜色 table
    ---@type table<number, table<number, { r: number, g: number, b: number }>>
    local mask = {}
    for y = 0, size - 1 do mask[y] = {} end

    local centerX = math.floor(size / 2)
    local stem = opts.stem
    local stemW = math.max(2, math.floor(size / 10))
    local stemHeight = math.floor(size * (opts.stemHeightRatio or 0.55))

    local function put(x, y, color)
        if x >= 0 and x < size and y >= 0 and y < size then
            mask[y][x] = color
        end
    end

    if opts.twigs then
        -- 枯灌木：底部散开的枯枝
        for i = 1, 6 do
            local dir = (i % 2 == 0) and 1 or -1
            local lean = dir * (i * size / 18)
            local h = math.floor(size * (0.45 + 0.30 * math.random()))
            for step = 0, h do
                local px = centerX + math.floor(lean * step / math.max(1, h))
                put(px, size - 1 - step, stem)
                if size >= 32 then put(px + 1, size - 1 - step, stem) end
            end
        end
    else
        -- 茎
        for y = size - 1, size - stemHeight, -1 do
            for dx = 0, stemW - 1 do
                put(centerX - math.floor(stemW / 2) + dx, y, stem)
            end
        end

        local cap = opts.cap
        if cap then
            if opts.mushroom then
                local capR = math.max(4, math.floor(size * 0.32))
                local capY = size - stemHeight
                for dy = -capR, 0 do
                    for dx = -capR, capR do
                        if dx * dx + dy * dy <= capR * capR then
                            put(centerX + dx, capY + dy, cap)
                        end
                    end
                end
                if opts.capDots then
                    local dot = { r = 0.95, g = 0.95, b = 0.92 }
                    for _ = 1, 5 do
                        local px = centerX + math.random(-capR + 1, capR - 1)
                        local py = capY - math.random(0, capR - 1)
                        put(px, py, dot)
                        put(px + 1, py, dot)
                    end
                end
            else
                -- 树苗叶片
                local leafR = math.max(4, math.floor(size * 0.30))
                local leafY = size - stemHeight - leafR + 1
                for dy = -leafR, leafR do
                    for dx = -leafR, leafR do
                        local d2 = dx * dx + dy * dy
                        if d2 <= leafR * leafR and not (dy > 1 and math.abs(dx) < 2) then
                            local edge = (d2 >= (leafR - 1) * (leafR - 1))
                            put(centerX + dx, leafY + dy, edge
                                and { r = cap.r * 0.82, g = cap.g * 0.82, b = cap.b * 0.82 }
                                or cap)
                        end
                    end
                end
            end
        end
    end

    local pack = self
    self:generatePBRTile(images, sx, sy, size, function(x, y, s)
        local c = mask[y][x]
        if not c then
            -- 透明像素：法线给平面、specular alpha 也置 0
            return 0, 0, 0, 0.0, 0.5, 1.0, 0.0
        end
        local noise = pack:periodicSmoothNoise(x, y, s, seed + 7) * 0.06
        return c.r + noise, c.g + noise, c.b + noise, 1.0, 0.6, 0.85, 0.0
    end, { normalStrength = 0.4 })
end

-- ====================================================================
-- 新增方块的专用生成器
-- ====================================================================

---砂岩顶：细沙面
function HDPack:generateSandstoneTop(images, sx, sy, size)
    local pack = self
    self:generatePBRTile(images, sx, sy, size, function(x, y, s)
        local n = pack:periodicSmoothNoise(x, y, s, 5101) * 0.06
        return 0.87 + n, 0.80 + n, 0.58 + n, 1.0, nil, 0.9, 0.0
    end, { normalStrength = 0.5 })
end

---砂岩侧：水平沉积层
function HDPack:generateSandstoneSide(images, sx, sy, size)
    local pack = self
    local bandH = math.max(3, math.floor(size / 5))
    self:generatePBRTile(images, sx, sy, size, function(x, y, s)
        local band = math.floor(y / bandH)
        local isSeam = (y % bandH) == 0
        local shade = isSeam and 0.74 or ((band % 2 == 0) and 1.02 or 0.88)
        local n = pack:periodicSmoothNoise(x, y, s, 5102) * 0.05
        return 0.86 * shade + n, 0.79 * shade + n, 0.57 * shade + n,
               1.0, isSeam and 0.25 or 0.7, 0.9, 0.0
    end, { normalStrength = 1.4 })
end

---砂岩底：粗糙压实沙
function HDPack:generateSandstoneBottom(images, sx, sy, size)
    local pack = self
    self:generatePBRTile(images, sx, sy, size, function(x, y, s)
        local n = pack:periodicSmoothNoise(x, y, s, 5103) * 0.12
        return 0.74 + n, 0.66 + n, 0.45 + n, 1.0, nil, 0.95, 0.0
    end, { normalStrength = 0.9 })
end

---黑曜石：近黑玻璃质 + 紫色反光
function HDPack:generateObsidian(images, sx, sy, size)
    local pack = self
    self:generatePBRTile(images, sx, sy, size, function(x, y, s)
        local n = pack:periodicSmoothNoise(x, y, s, 5104) * 0.05
        local sheen = math.max(0, pack:periodicSmoothNoise(x, y, s, 5114)) * 0.22
        return 0.10 + n + sheen * 0.7, 0.08 + n + sheen * 0.2, 0.17 + n + sheen,
               1.0, nil, 0.18, 0.15  -- 低粗糙 = 黑曜石玻璃光泽
    end, { normalStrength = 0.6 })
end

---基岩：不规则深浅灰块
function HDPack:generateBedrock(images, sx, sy, size)
    math.randomseed(5105)
    local blockSize = math.max(3, math.floor(size / 6))
    local cells = {}
    local cellCount = math.ceil(size / blockSize)
    for by = 0, cellCount - 1 do
        cells[by] = {}
        for bx = 0, cellCount - 1 do
            cells[by][bx] = 0.20 + math.random() * 0.24
        end
    end

    local pack = self
    self:generatePBRTile(images, sx, sy, size, function(x, y, s)
        local v = cells[math.floor(y / blockSize)][math.floor(x / blockSize)]
        local n = pack:periodicSmoothNoise(x, y, s, 5115) * 0.04
        return v + n, v + n, v + n + 0.01, 1.0, v, 0.85, 0.0
    end, { normalStrength = 1.8 })
end

---木板：横向木板 + 板缝
function HDPack:generatePlanks(images, sx, sy, size)
    local pack = self
    local plankH = math.max(4, math.floor(size / 4))
    self:generatePBRTile(images, sx, sy, size, function(x, y, s)
        local isGroove = (y % plankH) == 0
        local plankIdx = math.floor(y / plankH)
        -- 周期性木纹（X 轴整数个周期，保证左右接缝连续）
        local grain = math.sin((x / s) * 2 * math.pi * 3 + plankIdx * 2.1) * 0.03
        local n = pack:periodicSmoothNoise(x, y, s, 5106) * 0.04
        if isGroove then
            return 0.46 + n, 0.33 + n, 0.18 + n, 1.0, 0.2, 0.75, 0.0
        end
        return 0.72 + grain + n, 0.56 + grain + n, 0.34 + grain + n, 1.0, 0.7 + grain, 0.6, 0.0
    end, { normalStrength = 1.6 })
end

---书架侧面：上下木板边框 + 中间书脊
function HDPack:generateBookshelfSide(images, sx, sy, size)
    self:generatePlanks(images, sx, sy, size)

    math.randomseed(5107)
    local border = math.max(3, math.floor(size * 0.18))
    local palette = {
        { r = 0.62, g = 0.20, b = 0.18 },
        { r = 0.20, g = 0.34, b = 0.60 },
        { r = 0.24, g = 0.48, b = 0.26 },
        { r = 0.58, g = 0.48, b = 0.18 },
        { r = 0.45, g = 0.24, b = 0.50 },
    }
    -- 预分配书脊列
    local columns = {}
    local x = 0
    while x < size do
        local w = math.random(2, math.max(2, math.floor(size / 8)))
        local isGap = math.random() < 0.22
        local c = palette[math.random(1, #palette)]
        for dx = 0, w - 1 do
            columns[x + dx] = isGap and false or c
        end
        x = x + w
    end

    -- 只覆盖中间区域（边框保留木板）
    local pack = self
    local heightMap = {}
    for y = border, size - 1 - border do
        for px = 0, size - 1 do
            local c = columns[px]
            local n = pack:periodicSmoothNoise(px, y, size, 5117) * 0.05
            local r, g, b, rough, h
            if not c then
                r, g, b, rough, h = 0.18 + n, 0.13 + n, 0.09 + n, 0.9, 0.2
            else
                local edge = (y == border or y == size - 1 - border) and 0.8 or 1.0
                r, g, b, rough, h = c.r * edge + n, c.g * edge + n, c.b * edge + n, 0.7, 0.8
            end
            images.diffuse:SetPixel(sx + px, sy + y, Color(r, g, b, 1.0))
            images.specular:SetPixel(sx + px, sy + y, Color(rough, 0.0, 1.0, 1.0))
            heightMap[y] = heightMap[y] or {}
            heightMap[y][px] = h
        end
    end
    -- 书脊区域重算法线（边框沿用 generatePlanks 的结果）
    for y = border + 1, size - 2 - border do
        for px = 0, size - 1 do
            local left = heightMap[y][(px - 1 + size) % size]
            local right = heightMap[y][(px + 1) % size]
            local dx = (left - right) * 2.0
            local len = math.sqrt(dx * dx + 1)
            images.normal:SetPixel(sx + px, sy + y,
                Color((dx / len) * 0.5 + 0.5, 0.5, (1 / len) * 0.5 + 0.5, 1.0))
        end
    end
end

---工作台顶面：木板 + 3x3 格线
function HDPack:generateCraftingTop(images, sx, sy, size)
    self:generatePlanks(images, sx, sy, size)
    local third = size / 3
    for y = 0, size - 1 do
        for x = 0, size - 1 do
            local onGrid = (x % third) < 1 or (y % third) < 1 or x == 0 or y == 0
            if onGrid then
                images.diffuse:SetPixel(sx + x, sy + y, Color(0.34, 0.24, 0.13, 1.0))
                images.specular:SetPixel(sx + x, sy + y, Color(0.85, 0.0, 1.0, 1.0))
            end
        end
    end
end

---工作台侧面：木板 + 下方工具板
function HDPack:generateCraftingSide(images, sx, sy, size)
    self:generatePlanks(images, sx, sy, size)
    local panelTop = math.floor(size * 0.45)
    local pack = self
    for y = panelTop, size - 1 do
        for x = 1, size - 2 do
            local n = pack:periodicSmoothNoise(x, y, size, 5108) * 0.04
            images.diffuse:SetPixel(sx + x, sy + y, Color(0.42 + n, 0.30 + n, 0.17 + n, 1.0))
            images.specular:SetPixel(sx + x, sy + y, Color(0.7, 0.0, 1.0, 1.0))
        end
    end
    for y = panelTop + 1, size - 3 do
        images.diffuse:SetPixel(sx + math.floor(size * 0.3), sy + y, Color(0.70, 0.66, 0.60, 1.0))
        images.specular:SetPixel(sx + math.floor(size * 0.3), sy + y, Color(0.25, 0.8, 1.0, 1.0))
        images.diffuse:SetPixel(sx + math.floor(size * 0.7), sy + y, Color(0.58, 0.44, 0.24, 1.0))
    end
end

---熔炉顶面：石头 + 中央圆孔
function HDPack:generateFurnaceTop(images, sx, sy, size)
    self:generateStone(images, sx, sy, size)
    local cx, cy = size / 2, size / 2
    local r = math.max(3, math.floor(size * 0.22))
    for y = 0, size - 1 do
        for x = 0, size - 1 do
            local dx, dy = x - cx + 0.5, y - cy + 0.5
            local d = math.sqrt(dx * dx + dy * dy)
            if d <= r then
                local v = (d > r - 1.5) and 0.30 or 0.13
                images.diffuse:SetPixel(sx + x, sy + y, Color(v, v, v, 1.0))
                images.specular:SetPixel(sx + x, sy + y, Color(0.6, 0.1, 1.0, 1.0))
            end
        end
    end
end

---熔炉侧面：石头 + 下方炉口
function HDPack:generateFurnaceSide(images, sx, sy, size)
    self:generateStone(images, sx, sy, size)
    local left = math.floor(size * 0.22)
    local right = size - 1 - left
    local top = math.floor(size * 0.45)
    for y = top, size - 2 do
        for x = left, right do
            local isBorder = (y == top) or (x == left) or (x == right)
            local v = isBorder and 0.34 or 0.09
            images.diffuse:SetPixel(sx + x, sy + y, Color(v, v * 0.98, v * 0.95, 1.0))
            images.specular:SetPixel(sx + x, sy + y, Color(isBorder and 0.5 or 0.9, 0.1, 1.0, 1.0))
        end
    end
    local grateY = math.floor(size * 0.72)
    for x = left + 1, right - 1 do
        images.diffuse:SetPixel(sx + x, sy + grateY, Color(0.30, 0.28, 0.27, 1.0))
    end
end

---荧石：暖黄发光颗粒（贴图本身偏亮，实际发光靠 blockLight）
function HDPack:generateGlowstone(images, sx, sy, size)
    local pack = self
    self:generatePBRTile(images, sx, sy, size, function(x, y, s)
        local n = pack:periodicSmoothNoise(x, y, s, 5109) * 0.14
        local grain = pack:periodicSmoothNoise(x * 2, y * 2, s, 5119)
        local hot = (grain > 0.25) and 0.18 or 0.0
        return 0.84 + n + hot, 0.68 + n + hot * 0.9, 0.34 + n + hot * 0.5,
               1.0, nil, 0.55, 0.0
    end, { normalStrength = 1.2 })
end

---砂砾：杂色碎石
function HDPack:generateGravel(images, sx, sy, size)
    local pack = self
    self:generatePBRTile(images, sx, sy, size, function(x, y, s)
        local coarse = pack:periodicSmoothNoise(x * 2, y * 2, s, 5110)
        local fine = pack:periodicSmoothNoise(x * 4, y * 4, s, 5120) * 0.5
        local v = 0.52 + coarse * 0.22 + fine * 0.1
        local warm = (coarse > 0.2) and 0.03 or 0.0
        return v + warm, v + warm * 0.6, v, 1.0, v, 0.92, 0.0
    end, { normalStrength = 2.4 })
end

---黏土：细腻灰蓝
function HDPack:generateClay(images, sx, sy, size)
    local pack = self
    self:generatePBRTile(images, sx, sy, size, function(x, y, s)
        local n = pack:periodicSmoothNoise(x, y, s, 5111) * 0.05
        return 0.63 + n, 0.65 + n, 0.70 + n, 1.0, nil, 0.75, 0.0
    end, { normalStrength = 0.4 })
end

---雪：近白 + 细颗粒
function HDPack:generateSnow(images, sx, sy, size)
    local pack = self
    self:generatePBRTile(images, sx, sy, size, function(x, y, s)
        local n = pack:periodicSmoothNoise(x * 2, y * 2, s, 5112) * 0.05
        return 0.94 + n, 0.96 + n, 0.99 + n * 0.5, 1.0, nil, 0.55, 0.0
    end, { normalStrength = 0.7 })
end

---带雪草地侧面：上部积雪 + 下部泥土
function HDPack:generateGrassSnowSide(images, sx, sy, size)
    self:generateDirt(images, sx, sy, size)
    local pack = self
    local snowDepth = math.max(3, math.floor(size * 0.28))
    for x = 0, size - 1 do
        -- 雪线参差（X 轴周期噪声，保证接缝连续）
        local jitter = math.floor(pack:periodicSmoothNoise(x, 0, size, 5113) * 3)
        for y = 0, snowDepth + jitter - 1 do
            if y >= 0 and y < size then
                local n = pack:periodicSmoothNoise(x, y, size, 5123) * 0.04
                images.diffuse:SetPixel(sx + x, sy + y, Color(0.93 + n, 0.95 + n, 0.99 + n, 1.0))
                images.specular:SetPixel(sx + x, sy + y, Color(0.55, 0.0, 1.0, 1.0))
            end
        end
    end
end

---冰：半透明淡蓝（alpha 由 translucent 材质混合）
function HDPack:generateIce(images, sx, sy, size)
    local pack = self
    local ICE_ALPHA = 0.62
    self:generatePBRTile(images, sx, sy, size, function(x, y, s)
        local n = pack:periodicSmoothNoise(x, y, s, 5114) * 0.05
        -- 低频裂纹：噪声接近 0 的等值线附近提亮
        local crackNoise = pack:periodicSmoothNoise(x, y, s, 5124)
        local crack = (math.abs(crackNoise) < 0.06) and 0.16 or 0.0
        return 0.58 + n + crack, 0.78 + n + crack, 0.96 + n * 0.5 + crack * 0.5,
               ICE_ALPHA + crack * 0.5, nil, 0.08, 0.0
    end, { normalStrength = 0.5 })
end

---岩浆：暗红底 + 明黄熔流
function HDPack:generateLava(images, sx, sy, size)
    local pack = self
    self:generatePBRTile(images, sx, sy, size, function(x, y, s)
        -- 周期性"流动"图案（整数周期，四方连续）
        local u = (x / s) * 2 * math.pi
        local v = (y / s) * 2 * math.pi
        local flow = math.sin(u * 2 + v) * 0.5 + math.sin(v * 3) * 0.3
        local n = pack:periodicSmoothNoise(x, y, s, 5115) * 0.06
        local hot = math.max(0, flow) * 0.35
        return 0.78 + hot + n, 0.24 + hot * 0.95 + n * 0.6, 0.06 + hot * 0.25,
               1.0, nil, 0.65, 0.0
    end, { normalStrength = 1.0 })
end

---仙人掌顶面
function HDPack:generateCactusTop(images, sx, sy, size)
    local pack = self
    local inset = math.max(3, math.floor(size * 0.22))
    self:generatePBRTile(images, sx, sy, size, function(x, y, s)
        local n = pack:periodicSmoothNoise(x, y, s, 5116) * 0.05
        local inner = (x >= inset and x < s - inset and y >= inset and y < s - inset)
        if inner then
            return 0.30 + n, 0.60 + n, 0.26 + n, 1.0, 0.75, 0.8, 0.0
        end
        return 0.24 + n, 0.52 + n, 0.22 + n, 1.0, 0.55, 0.8, 0.0
    end, { normalStrength = 1.2 })
end

---仙人掌侧面：竖棱 + 尖刺
function HDPack:generateCactusSide(images, sx, sy, size)
    local pack = self
    local ribCount = 5
    self:generatePBRTile(images, sx, sy, size, function(x, y, s)
        -- 周期性竖棱
        local rib = math.sin((x / s) * 2 * math.pi * ribCount)
        local shade = 0.88 + rib * 0.14
        local n = pack:periodicSmoothNoise(x, y, s, 5117) * 0.05
        -- 尖刺：稀疏亮点
        local spine = pack:periodicSmoothNoise(x * 3, y * 3, s, 5127)
        if spine > 0.42 then
            return 0.86, 0.86, 0.60, 1.0, 0.95, 0.7, 0.0
        end
        return 0.24 * shade + n, 0.56 * shade + n, 0.22 * shade + n, 1.0, 0.5 + rib * 0.3, 0.8, 0.0
    end, { normalStrength = 1.6 })
end

---仙人掌底面
function HDPack:generateCactusBottom(images, sx, sy, size)
    local pack = self
    self:generatePBRTile(images, sx, sy, size, function(x, y, s)
        local n = pack:periodicSmoothNoise(x, y, s, 5118) * 0.06
        return 0.20 + n, 0.44 + n, 0.19 + n, 1.0, nil, 0.85, 0.0
    end, { normalStrength = 0.8 })
end

---玻璃：中间全透明 + 边框与高光（alpha 裁剪：alpha < 0.5 被丢弃）
function HDPack:generateGlass(images, sx, sy, size)
    -- 斜向高光的像素集合
    local streak = {}
    local streakLen = math.max(3, math.floor(size * 0.28))
    for i = 0, streakLen do
        local x = 3 + i
        local y = 3 + math.floor(i * 0.6)
        streak[y * size + x] = true
        streak[y * size + x + 1] = true
    end

    self:generatePBRTile(images, sx, sy, size, function(x, y, s)
        local onBorder = (x <= 0 or y <= 0 or x >= s - 1 or y >= s - 1)
        if onBorder then
            return 0.80, 0.90, 0.95, 1.0, 0.6, 0.1, 0.0
        end
        if streak[y * s + x] then
            return 0.95, 0.99, 1.0, 1.0, 0.65, 0.05, 0.0
        end
        return 0.85, 0.94, 0.98, 0.0, 0.5, 0.1, 0.0
    end, { normalStrength = 0.3 })
end

---门板 - PBR（木门偏棕、铁门偏灰；上半格开窗）
function HDPack:generateDoor(images, sx, sy, size, base, upper, window, metal)
    local pack = self
    local x0, x1 = math.floor(size * 0.22), size - 1 - math.floor(size * 0.22)
    local y0, y1 = math.floor(size * 0.22), math.floor(size * 0.62)
    -- 竖缝偏离正中：在正中时会和上下两格的交界横线交成十字（见 ClassicPack 同处注释）
    local seamX = math.floor(size * 0.34)
    -- 把手只画在下半格（上下格各画会出现两个点，见 ClassicPack 同处注释）
    local handleX = math.floor(size * 0.80)
    local handleY = upper and -10 or math.floor(size * 0.22)

    -- 下半格的内嵌门板轮廓（不贯通到边，避免与任何横向接缝连成整条线）
    local px0, px1 = math.floor(size * 0.20), math.floor(size * 0.80)
    local py0, py1 = math.floor(size * 0.34), math.floor(size * 0.88)

    self:generatePBRTile(images, sx, sy, size, function(x, y, s)
        -- 把手（金色，低粗糙）
        if x >= handleX and x <= handleX + 1 and y >= handleY and y <= handleY + 1 then
            return 0.85, 0.80, 0.45, 1.0, 0.9, 0.25, 0.8
        end
        -- 门板轮廓
        if not upper and x >= px0 and x <= px1 and y >= py0 and y <= py1 then
            local onOutline = (x == px0 or x == px1 or y == py0 or y == py1)
            if onOutline then
                return base.r * 0.72, base.g * 0.72, base.b * 0.72, 1.0, 0.35, 0.7, metal
            end
        end
        -- 上半格的窗
        if upper and window and x >= x0 and x <= x1 and y >= y0 and y <= y1 then
            local onFrame = (x == x0 or x == x1 or y == y0 or y == y1)
            if onFrame then
                return base.r * 0.6, base.g * 0.6, base.b * 0.6, 1.0, 0.7, 0.6, metal
            end
            -- 竖向格栅：把窗分成三格（只在 HD 做，16px 的 Classic 画格栅会糊）
            local barA = x0 + math.floor((x1 - x0) / 3)
            local barB = x0 + math.floor((x1 - x0) * 2 / 3)
            if x == barA or x == barB then
                return base.r * 0.62, base.g * 0.62, base.b * 0.62, 1.0, 0.72, 0.55, metal
            end
            return 0.62, 0.78, 0.88, 1.0, 0.35, 0.08, 0.0   -- 玻璃窗
        end

        local n = pack:periodicSmoothNoise(x, y, s, 6401) * 0.06
        local seam = (x == seamX) and -0.16 or 0
        -- 只压暗门的外轮廓；上下两格交界那条边不压（否则两张 tile 拼出一条假横线）
        local onSide = (x <= 0 or x >= s - 1)
        local onOuterEnd = (upper and y <= 0) or ((not upper) and y >= s - 1)
        local edge = (onSide or onOuterEnd) and -0.10 or 0
        local k = 1.0 + n + seam + edge
        return base.r * k, base.g * k, base.b * k, 1.0,
               0.7 + seam * 2, metal > 0 and 0.35 or 0.6, metal
    end, { normalStrength = 1.4 })
end

---活板门 - PBR（横向木条 + 铰链）
function HDPack:generateTrapdoor(images, sx, sy, size)
    local pack = self
    local plankH = math.max(4, math.floor(size / 4))
    self:generatePBRTile(images, sx, sy, size, function(x, y, s)
        if x <= 1 or x >= s - 2 then
            if y >= math.floor(s * 0.2) and y <= math.floor(s * 0.8) then
                return 0.32, 0.32, 0.34, 1.0, 0.55, 0.3, 0.7   -- 铁铰链
            end
        end
        local isSeam = (y % plankH) == 0
        local n = pack:periodicSmoothNoise(x, y, s, 6402) * 0.05
        local k = isSeam and 0.62 or 1.0
        return 0.60 * k + n, 0.44 * k + n, 0.24 * k + n, 1.0,
               isSeam and 0.25 or 0.7, 0.65, 0.0
    end, { normalStrength = 1.6 })
end

-- ====================================================================
-- tile 名称 → 生成器（createImages 按 AtlasLayout.order 派发）
-- ====================================================================

local function oreGen(color, blobCount, seed, rough, metal)
    return function(self, images, sx, sy, size)
        self:generateOre(images, sx, sy, size, color, blobCount, seed, rough, metal)
    end
end

local function woolGen(color, seed)
    return function(self, images, sx, sy, size)
        self:generateWool(images, sx, sy, size, color, seed)
    end
end

local function plantGen(opts, seed)
    return function(self, images, sx, sy, size)
        self:generateCrossPlant(images, sx, sy, size, opts, seed)
    end
end

HDPack.tileGenerators = {
    -- Row 0-2：原有
    grass_top     = HDPack.generateGrassTop,
    grass_side    = HDPack.generateGrassSide,
    dirt          = HDPack.generateDirt,
    stone         = HDPack.generateStone,
    wood_top      = HDPack.generateWoodTop,
    wood_side     = HDPack.generateWoodSide,
    leaves        = HDPack.generateLeaves,
    sand          = HDPack.generateSand,
    water         = HDPack.generateWater,
    tall_grass    = HDPack.generateTallGrass,
    torch         = HDPack.generateTorch,
    rose = function(self, images, sx, sy, size)
        self:generateFlower(images, sx, sy, size, { r = 1.0, g = 0.15, b = 0.15 }, "rose")
    end,
    flower_yellow = function(self, images, sx, sy, size)
        self:generateFlower(images, sx, sy, size, { r = 1.0, g = 0.9, b = 0.1 }, "simple")
    end,
    flower_blue = function(self, images, sx, sy, size)
        self:generateFlower(images, sx, sy, size, { r = 0.2, g = 0.4, b = 1.0 }, "bulb")
    end,

    -- Row 3：石制 + 建材
    cobblestone = function(self, images, sx, sy, size)
        self:generateCobble(images, sx, sy, size, { r = 0.52, g = 0.52, b = 0.53 }, 5201, false)
    end,
    mossy_cobblestone = function(self, images, sx, sy, size)
        self:generateCobble(images, sx, sy, size, { r = 0.50, g = 0.51, b = 0.50 }, 5202, true)
    end,
    stone_bricks = function(self, images, sx, sy, size)
        self:generateBrickPattern(images, sx, sy, size,
            { r = 0.56, g = 0.56, b = 0.57 }, { r = 0.38, g = 0.38, b = 0.39 }, 4, 5203)
    end,
    sandstone_top    = HDPack.generateSandstoneTop,
    sandstone_side   = HDPack.generateSandstoneSide,
    sandstone_bottom = HDPack.generateSandstoneBottom,
    obsidian         = HDPack.generateObsidian,
    bedrock          = HDPack.generateBedrock,
    planks           = HDPack.generatePlanks,
    bricks = function(self, images, sx, sy, size)
        self:generateBrickPattern(images, sx, sy, size,
            { r = 0.66, g = 0.34, b = 0.28 }, { r = 0.76, g = 0.72, b = 0.68 }, 4, 5204)
    end,
    bookshelf_side = HDPack.generateBookshelfSide,
    crafting_top   = HDPack.generateCraftingTop,
    crafting_side  = HDPack.generateCraftingSide,
    furnace_top    = HDPack.generateFurnaceTop,
    furnace_side   = HDPack.generateFurnaceSide,

    -- Row 4：矿石 + 自然（金属矿石低粗糙 + 有金属度，钻石/青金给宝石质感）
    coal_ore     = oreGen({ r = 0.14, g = 0.14, b = 0.15 }, 7, 5301, 0.85, 0.0),
    iron_ore     = oreGen({ r = 0.78, g = 0.62, b = 0.50 }, 7, 5302, 0.35, 0.55),
    gold_ore     = oreGen({ r = 0.96, g = 0.80, b = 0.28 }, 6, 5303, 0.20, 0.85),
    diamond_ore  = oreGen({ r = 0.42, g = 0.90, b = 0.92 }, 5, 5304, 0.10, 0.10),
    redstone_ore = oreGen({ r = 0.82, g = 0.14, b = 0.12 }, 8, 5305, 0.45, 0.0),
    lapis_ore    = oreGen({ r = 0.16, g = 0.30, b = 0.76 }, 7, 5306, 0.25, 0.10),
    glowstone       = HDPack.generateGlowstone,
    gravel          = HDPack.generateGravel,
    clay            = HDPack.generateClay,
    snow            = HDPack.generateSnow,
    grass_snow_side = HDPack.generateGrassSnowSide,
    ice             = HDPack.generateIce,
    lava            = HDPack.generateLava,
    cactus_top      = HDPack.generateCactusTop,
    cactus_side     = HDPack.generateCactusSide,
    cactus_bottom   = HDPack.generateCactusBottom,

    -- Row 5：透明 + 羊毛 + 植物
    glass       = HDPack.generateGlass,
    wool_white  = woolGen({ r = 0.93, g = 0.93, b = 0.93 }, 5401),
    wool_red    = woolGen({ r = 0.70, g = 0.20, b = 0.18 }, 5402),
    wool_yellow = woolGen({ r = 0.88, g = 0.78, b = 0.24 }, 5403),
    wool_green  = woolGen({ r = 0.32, g = 0.58, b = 0.24 }, 5404),
    wool_blue   = woolGen({ r = 0.24, g = 0.32, b = 0.70 }, 5405),
    wool_black  = woolGen({ r = 0.14, g = 0.14, b = 0.15 }, 5406),

    sapling = plantGen({
        stem = { r = 0.45, g = 0.32, b = 0.16 },
        cap = { r = 0.28, g = 0.60, b = 0.22 },
        stemHeightRatio = 0.42,
    }, 5501),
    dead_bush = plantGen({
        stem = { r = 0.55, g = 0.40, b = 0.18 },
        twigs = true,
    }, 5502),
    mushroom_red = plantGen({
        stem = { r = 0.92, g = 0.90, b = 0.86 },
        cap = { r = 0.78, g = 0.18, b = 0.16 },
        mushroom = true,
        capDots = true,
        stemHeightRatio = 0.35,
    }, 5503),
    mushroom_brown = plantGen({
        stem = { r = 0.86, g = 0.82, b = 0.74 },
        cap = { r = 0.58, g = 0.44, b = 0.32 },
        mushroom = true,
        stemHeightRatio = 0.35,
    }, 5504),

    -- Row 6：门 / 活板门
    door_wood_lower = function(self, images, sx, sy, size)
        self:generateDoor(images, sx, sy, size, { r = 0.62, g = 0.45, b = 0.26 }, false, false, 0.0)
    end,
    door_wood_upper = function(self, images, sx, sy, size)
        self:generateDoor(images, sx, sy, size, { r = 0.62, g = 0.45, b = 0.26 }, true, true, 0.0)
    end,
    door_iron_lower = function(self, images, sx, sy, size)
        self:generateDoor(images, sx, sy, size, { r = 0.72, g = 0.73, b = 0.75 }, false, false, 0.75)
    end,
    door_iron_upper = function(self, images, sx, sy, size)
        self:generateDoor(images, sx, sy, size, { r = 0.72, g = 0.73, b = 0.75 }, true, true, 0.75)
    end,
    trapdoor_wood = HDPack.generateTrapdoor,
}

return HDPack
