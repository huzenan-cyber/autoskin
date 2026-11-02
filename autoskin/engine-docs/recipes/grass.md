# 草地（GrassField）

> 大片可随风摆动、能被角色踩开的 3D 草地。每根草都是 GPU 生成的弯曲草叶，不需要模型、不需要摆放实例。
> 灯光与阴影见 [lights-and-shadows.md](lights-and-shadows.md)，天空与环境光见 [sky-and-environment-lighting.md](sky-and-environment-lighting.md)。

---

## 1. 它做什么、在哪能用

`GrassField` 是一个组件：

- 放在 **Terrain 所在节点**上：自动铺满整块地形，草根贴合地形高度，陡坡自动不长草。
- 放在**普通节点**上：铺一块以节点为中心、`fieldSize` 大小的**平地**草地（节点的 Y 就是地面高度）。

每一帧它按相机视野现场生成草叶（只生成看得见的那部分），近处是细节完整的弯曲草叶，远处逐渐变稀、变宽，保持地面看起来仍被草盖住。草叶参与正常光照：方向光、点光、阴影、环境光、SSAO、雾都生效，前向和延迟管线都支持。

| 环境 | 支持 |
|---|---|
| 桌面（Windows / macOS / Linux），前向或延迟 | ✅ |
| 设备不支持计算着色器或间接绘制（如 WebGL） | ❌ 不显示，`grass.supported` 为 `false` |
| 移动端 | 能运行，但默认参数按 PC 调的，需要降低 `density` / `viewDistance` |

创建后先检查一次：

```lua
if not grass.supported then
    print("当前设备不支持 GrassField，改用贴图地面")
end
```

---

## 2. 最小示例

### 地形上的草

```lua
local terrainNode = scene:CreateChild("Terrain")
local terrain = terrainNode:CreateComponent("Terrain")
terrain.heightMap = cache:GetResource("Image", "Textures/HeightMap.png")
terrain.material = cache:GetResource("Material", "Materials/Terrain.xml")

-- 和 Terrain 放在同一个节点上
local grass = terrainNode:CreateComponent("GrassField")
grass.castShadows = true          -- 近处草叶投影，草丛有层次（默认关）
```

### 平地上的草

```lua
local fieldNode = scene:CreateChild("Lawn")
fieldNode.position = Vector3(0, 0, 0)       -- Y = 地面高度
local grass = fieldNode:CreateComponent("GrassField")
grass.fieldSize = Vector2(40, 40)           -- 40 m × 40 m，以节点为中心
```

平地草地下面仍需要你自己放一个地面（如 `Models/Plane.mdl`）。节点可以平移和缩放，**不能旋转，X、Z 缩放也不能为负**（镜像会让整片草消失）。

---

## 3. 按区域控制草地：密度图与控制图

`densityMap` 是一张覆盖整块草地的贴图，某个通道的值决定该处的草有多密。地形的权重图（`Terrain.xml` 第 0 号贴图，RGB 分别是三层地表的混合权重）可以直接拿来用：

```lua
local weights = terrain.material:GetTexture(0)   -- 地形权重图
grass.densityMap = weights
grass.densityChannel = 0           -- R 通道 = 草地层
grass.densityRange = Vector2(0.2, 0.8)   -- 通道值 ≤0.2 不长草，≥0.8 长满
```

- 贴图北边（+Z）在上方，与地形 UV 一致；平地草地则按 `fieldSize` 覆盖。
- 也可以自己画一张灰度图（小路、空地、花坛轮廓）。
- 陡于 `maxSlope`（默认 50°）的坡面自动不长草。

**草下面的地面颜色很重要。** 草叶之间总会露出地面。顺光时露出的是被太阳照亮的地面，比草根亮得多，草地就会显得稀疏、发白；逆光时露出的是阴影，反而显得浓密。用密度图让草只长在地形的草地层上，再打开地形材质的**草下压暗**（`GROUNDCOVER`），草缝就会变成草丛深处的暗色：

```lua
local m = terrain.material:Clone()                 -- 先克隆，避免改到共享的 Terrain.xml
m.vertexShaderDefines = "GROUNDCOVER"                  -- 顶点和像素都要加
m.pixelShaderDefines = "GROUNDCOVER"
m:SetShaderParameter("GroundCoverColor", Variant(Vector4(0.025, 0.05, 0.01, 0.9)))      -- rgb 草下颜色（线性），w 压暗程度
m:SetShaderParameter("GroundCoverLayers", Variant(Vector4(1, 0, 0, grass.viewDistance))) -- xyz 哪几层长草，w 草的可见距离
m:SetShaderParameter("GroundCoverFar", Variant(Vector4(0.148, 0.184, 0.03, 0.9)))        -- rgb 远看草地的颜色（线性），w 程度
terrain.material = m
```

- `GroundCoverLayers` 的 xyz 对应权重图 RGB 三层，草长在哪层就填 1（与 `densityChannel` 对应）。被覆盖的地面同时去掉高光，否则草缝里会有发白的反光。
- `GroundCoverLayers` 的 w 填草的 `viewDistance`：从一半距离开始，长草的地面由草下暗色渐变成 `GroundCoverFar` 的颜色，即远看整片草地的颜色。草画不到的远处地形保持这个颜色，所以看不出草地在哪里结束，远处地形贴图的平铺纹理也会被压掉。改 `viewDistance` 时一起改。
- `GroundCoverFar` 要和远处草地的颜色一致：在远景截图里取草地区域的平均颜色（转成线性值）。上面的值是默认草材质在下午阳光下的测量结果；换了草的颜色、枯黄比例或光照差别很大时重新取。w 设 0 则远处恢复地形原色。
- 打开了 `GROUNDCOVER` 就必须设置这三个参数，没设的参数值不确定。
- 顶点和像素的宏都要加 `GROUNDCOVER`，只加像素的话，在使用预编译 shader 包的平台（移动端、网页）上地形可能整块不显示。
- 只适用于 `Terrain` 默认的 `TerrainBlend` 材质。平地草地下面的地面自己选一个暗绿/土色的材质即可。

### 按区域改变草的样子：控制图

密度图只决定"长不长、长多密"。院子里是修剪过的矮草坪、外面是齐腰的野草、山坡上枯黄，这类分区用 `controlMap`：一张和密度图同样铺满草地（+Z 在上）的 RGBA 贴图。

| 通道 | 含义 | 不变的值 |
|---|---|---|
| R | 草高缩放：草高 = `bladeHeight` 范围 × R。0.3 是矮草坪，0 不长草 | 1 |
| G | 枯黄度：0 保持材质的枯黄比例，越大枯黄的草簇越多，1 全部枯黄 | 0 |
| B、A | 预留，填 0 | 0 |

R 只能把草变矮，想要局部更高的草，就把 `bladeHeight` 设成最高的那种草，其余地方用 R 压低。被 R 压矮的草叶会略微变窄（R = 0.3 时保留 85% 的宽度），看起来像修剪过的细草。草叶数量不变、变矮后遮住的地面变少，所以修剪过的草坪要另铺一层密草（见本节末尾）。

在 Lua 里按位置生成（与地形权重图的写法相同）：

```lua
local function MakeControlMap(terrain, size)
    local image = Image:new()
    image:SetSize(size, size, 4)
    local half = (terrain.numVertices.x - 1) * terrain.spacing.x * 0.5   -- 正方形地形的半边长
    for y = 0, size - 1 do
        local z = half - (y + 0.5) / size * 2 * half                     -- 第 0 行是 +Z 一侧
        for x = 0, size - 1 do
            local p = Vector3(-half + (x + 0.5) / size * 2 * half, 0, z)
            local lawn = (Vector2(p.x, p.z) - Vector2(0, 10)):Length() < 6         -- 半径 6 米的草坪
            local dry = math.min(1, math.max(0, (terrain:GetHeight(p) - 5) / 9)) * 0.7  -- 越高越枯黄
            image:SetPixel(x, y, Color(lawn and 0.3 or 1.0, dry, 0, 0))
        end
    end
    local texture = Texture2D:new()
    texture:SetData(image, true)
    return texture
end

grass.controlMap = MakeControlMap(terrain, 512)
```

- **分辨率**：一个像素覆盖 `草地边长 / 贴图尺寸` 米。1 km 的地形用 512 的图约 2 米一个像素，草坪边缘会是几米宽的渐变；小路、花坛这类细节需要更高分辨率，或者用 `fieldSize` 较小的平地草地单独覆盖那一块。
- 草坪和野草的边界在图上做几个米的渐变（R 从 0.3 平滑过渡到 1）比硬边自然，上面的例子为了简短用了硬边。
- 生成大图在 Lua 里较慢（512×512 约 0.2 秒），只在加载时生成一次。
- **修剪过的草坪要另铺一层密草**：R 只改变高度，不改变数量。R = 0.3 的草坪每根草遮住的地面只剩约三分之一，站着往脚前看，近处约一半是地面。真实草坪比野草密得多，做法是在草坪上再加一个短而密的 GrassField（第 5 节的多种草写法），密度图只在草坪处为 1：

```lua
-- lawnMask：另一张同样铺满草地的贴图，R 通道在草坪处为 1
local lawn = terrainNode:CreateComponent("GrassField")
lawn.densityMap = lawnMask
lawn.densityChannel = 0
lawn.density = 600                      -- 远密于野草
lawn.bladeHeight = Vector2(0.05, 0.1)   -- 比修剪后的草更矮，铺在它们下面
lawn.bladeWidth = Vector2(0.004, 0.007)
lawn.clumpSize = 0.3
lawn.densityFalloffDistance = 3         -- 3 米外开始变稀
lawn.viewDistance = 40                  -- 只在近处需要
lawn.lodDistance = 4                    -- 这么短的草不需要精细弯曲网格
lawn.farLodDistance = 12
```

  这层的开销按 `density` × 可见距离算，**不按草坪面积算**（见第 7 节），所以一定要把 `viewDistance` 和 `densityFalloffDistance` 设小。参考：桌面 GPU、1080p、站在草坪边上看，这层约 0.35 ms，草坪不在画面里时约 0.1 ms；密度 400 约 0.25 ms，但露出的地面多一些。上面的修剪草（R = 0.3）保留不动，远处这层消失后，草坪仍然有草。

---

## 4. 外观：形状与颜色

形状参数在组件上：

| 属性 | 默认 | 说明 |
|---|---|---|
| `bladeHeight` | (0.35, 0.75) | 草高范围（米），每根随机 |
| `bladeWidth` | (0.007, 0.014) | 草根宽度范围（米） |
| `lean` | 0.5 | 静止时的倾斜/弯垂程度（0 直立） |
| `clumpSize` | 0.8 | 草丛（簇）大小（米）。同一簇的草高度、颜色相近，朝外散开 |
| `clumpHeightVariation` | 0.35 | 簇与簇之间的高度差 |
| `clumpPointing` | 0.5 | 草叶朝簇外侧倾斜的程度 |
| `density` | 200 | 近处每平方米草叶数 |

颜色和光照参数在材质上（默认 `Materials/GrassField.xml`）。改颜色先克隆一份默认材质再改，所有颜色都是**线性**值：

```lua
local m = grass.material:Clone()
m:SetShaderParameter("GrassRootColor", Variant(Vector4(0.018, 0.042, 0.008, 1.2)))  -- 草根色，w = 渐变指数
m:SetShaderParameter("GrassTipColor", Variant(Vector4(0.16, 0.28, 0.05, 0)))       -- 草尖色
m:SetShaderParameter("GrassDryColor", Variant(Vector4(0.30, 0.23, 0.07, 0.25)))    -- 枯黄色，w = 枯黄簇比例
grass.material = m
```

| 材质参数 | 分量含义 |
|---|---|
| `GrassRootColor` | rgb 草根颜色；w 根→尖颜色渐变指数 |
| `GrassTipColor` | rgb 草尖颜色 |
| `GrassDryColor` | rgb 枯草颜色；w 枯黄草簇所占比例（0 = 全绿）。控制图的 G 通道可按区域增加枯黄 |
| `GrassVariation` | x 簇间亮度差；y 单根亮度差；z 根部遮蔽（越小根部越暗）；w 遮蔽从根部渐变到的高度比例 |
| `GrassShape` | x 叶尖开始收窄的位置；y 横向法线圆润度；z 侧对相机时的加宽量 |
| `GrassShading` | x 粗糙度（默认 0.65，不要低于 0.6，见第 7 节）；y 高光强度 |
| `GrassTranslucency` | rgb 逆光透过草叶的颜色；w 强度（逆光时草叶发亮的程度） |
| `GrassFar` | x、y 法线开始/完全偏向地面法线的距离；z 偏向程度；w 高光完全变粗糙的距离 |

自定义材质时，technique 用 `Techniques/GrassField.xml`，**不要**带 `shadow` pass（阴影由组件自己画）。

---

## 5. 多种草、花和三叶草

一个 `GrassField` 只长一种植物。混合草甸用**同一节点上的多个 GrassField**，每个有自己的参数、材质和密度图通道。最方便的是把它们的分布画进一张 RGBA "种类图"，各取一个通道：

```lua
-- weights：RGB 是地形三层权重，A 是花的分布（同一张图也给地形材质用，地形只读 RGB）
grass.densityMap = weights
grass.densityChannel = 0            -- R：草

local flowers = terrainNode:CreateComponent("GrassField")
flowers.plantType = GRASS_PLANT_FLOWER
flowers.densityMap = weights
flowers.densityChannel = 3          -- A：花
flowers.density = 8                 -- 花比草稀得多
flowers.bladeHeight = Vector2(0.5, 0.85)   -- 花茎高度：比周围草高才看得见
flowers.bladeWidth = Vector2(0.003, 0.005) -- 花茎宽度
flowers.flowerSize = 0.035          -- 花头半径（米）
flowers.petalCount = 5              -- 花瓣数 3..8
flowers.flowerCup = 0.35            -- 花瓣上翘程度 0..0.5
```

- 花默认用 `Materials/GrassFlowerField.xml`：白色雏菊和黄色毛茛按草簇混合。改颜色同样先 `Clone()`：

| 材质参数 | 分量含义 |
|---|---|
| `GrassFlowerColor` | rgb 花瓣颜色 |
| `GrassFlowerColor2` | rgb 第二种花瓣颜色；w 用第二种颜色的草簇比例 |
| `GrassFlowerCenter` | rgb 花心颜色；w 花心半径（占花头的比例） |

  花茎用材质里草的颜色参数（`GrassRootColor`、`GrassTipColor` 等）。自定义花材质必须设置这三个参数。
- **三叶草**：`petalCount = 3`，花瓣和花心都设成绿色，花茎很矮（`bladeHeight` 约 0.05–0.12），`flowerCup` 小一些，密度高一些（30–60）。
- 不同种类的草：再加一个 blade 类型的 GrassField，换 `bladeHeight`、`bladeWidth` 和材质颜色，用种类图的另一个通道。
- 每个 GrassField 各自计算和绘制，开销按种类叠加；花这种低密度的植物开销很小。互动体要对每个 GrassField 分别 `SetInteractor`。

---

## 6. 风与互动

```lua
grass.windDirection = Vector2(1, 0.3)  -- 水平风向 (x, z)
grass.windStrength = 0.35              -- 0 = 无风，1 左右是大风
grass.windSpeed = 4                    -- 阵风推进速度（米/秒）
grass.gustSize = 12                    -- 阵风团大小（米）
grass.flutter = 0.4                    -- 每根草自己的抖动
```

风是阵风：一团团更强的风沿风向扫过草地，草叶各自再轻微抖动。`windSpeed` 和 `windDirection` 可以在运行时随时改（比如天气变化时逐渐加大风速或转向），阵风会从当前位置按新的风继续推进，不会跳变。`gustSize` 改的是阵风团的尺度，改动时整片阵风分布会随之变化，离场景原点越远变化越大；需要在运行中调整时，分多帧缓慢渐变。

**角色、车辆、滚动的球把草压开**：每帧把它们的位置传给一个互动槽（最多 `MAX_GRASS_INTERACTORS` = 8 个）：

```lua
function HandleUpdate(eventType, eventData)
    grass:SetInteractor(0, playerNode.worldPosition, 0.8)   -- 槽 0：玩家脚下，半径 0.8 米
    grass:SetInteractor(1, carNode.worldPosition, 2.0)      -- 槽 1：车
end
-- 不用了：半径设 0，或 grass:ClearInteractors()
```

`interactionStrength`（默认 1.4）决定中心处草被推倒的程度。

**压痕**：物体走过的地方，草会保持倒伏一阵再慢慢立起来，身后留下一道痕迹。互动槽里的物体自动留痕，不需要额外调用：

```lua
grass.trampleRecoveryTime = 6    -- 秒：前一半时间保持压倒，后一半逐渐立起；0 = 不留痕，物体离开草立即恢复
grass.trampleAreaSize = 64       -- 米：只在相机周围这么大的正方形范围内保留痕迹（默认 64）
```

- 痕迹只保存在相机周围 `trampleAreaSize` 范围内，走出范围的痕迹会被丢掉；范围越大痕迹越粗糙（固定 512×512 像素，64 米时约 12 厘米一格）。
- 范围跟随每帧第一个渲染这片草地的相机。分屏时两个玩家离得远，只有第一个视口附近的草留痕，另一边仍有实时推开。
- 离地太高的物体（跳起来的角色、飞过的球）不压草，也不留痕。
- 互动槽同一时刻最多 8 个；留下的痕迹不占槽位，所以先后经过的物体可以多于 8 个。

---

## 7. 性能

开销主要随**画面里的草叶数量**增长。参考：桌面 GPU、1080p、默认参数，草地整体约 0.8–1.3 ms；CPU 每个相机每帧约 0.1 ms。

| 想要 | 调整 |
|---|---|
| 更省 | 降低 `density`；减小 `viewDistance`（默认 120 米，最后 15% 渐隐）；`densityFalloffDistance` 调小（远处更早变稀） |
| 近处更茂密而不太贵 | 提高 `density`，同时减小 `densityFalloffDistance`：近处密，远处总数基本不变 |
| 阴影 | `castShadows` 让 `shadowDistance`（默认 25 米）以内的草投影，草丛更有层次；桌面 GPU、1080p 约 0.3 ms。很矮的草层（草坪密草、三叶草）投影几乎看不出，保持默认关闭 |
| 网格精度 | `lodDistance`（默认 18 米）以内是精细弯曲草叶，`farLodDistance`（默认 40 米）以外每根只有一个三角形 |

- 密度图整块不长草的地块（每块 4×4 米，值不超过 `densityRange` 的下限）会被跳过，不生成候选草叶，也不占实例缓冲；只要地块里有一点草，就按该块最高的密度生成。所以只长在一小片区域的高密度草（草坪、花坛）开销主要看它实际铺了多大，`viewDistance` 照常设成看得清它的距离即可。
- 运行中可以随时改密度图（`SetData` 涂抹、渲染到它、计算着色器写它），不用重新赋值：改动的当帧起所有地块照常生成，新涂的草立刻出现；贴图约半秒（30 帧）不再变化后，引擎在后台重新读回，再恢复跳过；如果贴图读回后很快又被改，下一次会等得更久（最长约 10 秒），避免反复读回。一直在变的密度图（每帧都画）就一直不跳过。
- 多个相机（分屏、水面反射相机）会各自生成一遍草叶，开销按相机数叠加。不需要草的相机用 `viewMask` 排除。
- **画质档位**：引擎按画质档位自动缩减草地（见下表），读回的属性仍是你设的值。缩减档把 `lodDistance` 乘 0.55、`densityFalloffDistance` 乘 0.8、`shadowDistance` 乘 0.6，`farLodDistance` 以外的草也稀疏得更快（剩下的草加宽补覆盖）。
- **手机上**：所有手机默认都是 high 档，也就是缩减档，草不投影（`castShadows` 在手机上只有 full / max 档才生效）。开销主要看**画面里有多少株草**，跟分辨率关系不大：横屏比竖屏贵得多（视野宽，草多）。要再省，按收益从大到小：降低 `density`；附加的草层（草坪、三叶草）缩小 `viewDistance`；不需要压痕的草层把 `trampleRecoveryTime` 设为 0（每片草每帧都要更新一张压痕贴图）。参考：中端手机（Mali-G77）横屏 2400×1080、demo 默认参数、high 档，草约占 6.6 ms 的 GPU 工作，大多和 CPU 时间重叠，demo 帧率约 64 FPS（不放草约 72 FPS）；full 档草约占 15 ms，GPU 成为瓶颈，帧率约 47–53 FPS。
- 自定义材质时，粗糙度（`GrassShading` 的 x）保持在 0.6 以上。延迟管线的屏幕空间反射会处理所有粗糙度低于 0.6 的像素，草铺满屏幕时 1080p 约多 1.6 ms，草上却看不出反射效果。

画质档位对草地的影响（“手机”包括手机和平板上的浏览器）：

| 档位 | 桌面 | 手机、平板 |
|---|---|---|
| `full` / `max` | 原样 | 原样 |
| `high` | 原样 | 缩减，草不投影 |
| `medium` | 缩减 | 稀疏，草不投影 |
| `low` | 缩减，草不投影 | 更稀、密度减半，草不投影，不留压痕 |

“稀疏”在缩减的基础上把 `densityFalloffDistance` 再减半（共乘 0.4）：中距离的草更少、更宽，覆盖不变，整屏几乎看不出区别。

手机上的 `low` 面向按 720p 渲染的低端手机，效率优先于画面：`densityFalloffDistance` 共乘 0.2、`density` 减半，近处的草叶更粗，草缝里能看到地面；并且不留压痕（`trampleRecoveryTime` 不起作用，物体经过时草仍会被推开，离开后立即恢复）。参考：低端手机（PowerVR GM9446）720p、demo 默认参数，草约占 6 ms，`medium` 约 28 ms。`low` 档同时会把手机上的 PCF 阴影换成 SIMPLE 质量（不做 PCF，边缘更硬，见 [lights-and-shadows.md](lights-and-shadows.md)），默认地形材质（`TerrainBlend`，任何平台）也不再读法线和粗糙度贴图，地面没有起伏细节，低角度光照下略暗；这台手机 720p 整帧约 17.6 ms。低端手机要在项目 `engine.json` 里把 `rendering.quality` 设成 `low`，引擎不会自动选档。

默认档位：Windows 是 `full`，其他平台（包括所有手机）是 `high`。档位在项目的 `.project/engine.json` 里设置，可以按平台单独写；它同时决定其他着色器的画质，不只影响草。例如只让安卓用 `medium`：

```json
{
  "schema_version": 1,
  "platforms": {
    "android": { "rendering": { "quality": "medium" } }
  }
}
```

---

## 8. 常见问题

| 现象 | 原因 / 解决 |
|---|---|
| 完全看不到草 | `grass.supported` 为 `false`（设备不支持）；或组件没和 Terrain 放在同一节点、平地草地的 `fieldSize`/节点位置不在相机前方 |
| 草地显得稀疏、发白，近处能看到地面 | 草缝里露出了被照亮的地面。打开地形材质的 `GROUNDCOVER`（第 3 节）；草下是浅色岩石/雪时用密度图只在草地层长草 |
| 想要草坪、野草、枯草分区 | 用控制图（第 3 节）：R 控制草高，G 控制枯黄 |
| 修剪过的草坪露出很多地面 | 压矮的草数量不变、遮住的地面变少。在草坪上加一层短而密的 GrassField（第 3 节末尾） |
| 草长在了不想要的地方（路、水下） | 用 `densityMap` 画出来；水下可以在密度图上把水域涂黑 |
| 射线检测/点选打不到草 | 设计如此：草不参与射线检测，不会挡住点击和视线判断 |
| 草漂在地形上方或陷进去（很远处） | 地形远处会降低精度。需要很远的草时调高地形精度：`terrain.lodBias` 调大 |
| 改一块草地的颜色，别的草地也跟着变了 | 默认材质是所有草地共享的。先 `Clone()` 一份再赋给这块草地的 `grass.material` |
