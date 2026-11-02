-- ============================================================================
-- UrhoX 3D Scene Scaffold (3D 场景展示脚手架)
-- 版本: 1.1
-- 用途: 3D 场景展示、可视化、自由相机漫游（不含角色控制）
-- 分辨率缩放: UI.Scale.DEFAULT (DPR + 小屏密度自适应)
--             尺寸遵循 CSS/Web 常识: 按钮 40-48px, 字体 14-16px, 间距 8/16/24px
-- 
-- ⚠️ 注意：如果你要做角色游戏（如 Fall Guys、Roblox、马里奥3D），
--          请使用 scaffold-3d-character.lua 而不是这个文件！
-- 
-- 适用场景：
--   ✅ 建筑漫游、3D 可视化
--   ✅ 产品展示、教育展示
--   ✅ 静态场景、自由视角游戏
--   ❌ 不适合需要角色控制的游戏（请用 scaffold-3d-character.lua）
--
-- 📖 必读文档（做3D游戏前必须阅读）：
--   1. engine-docs/recipes/materials.md - PBR材质参数详解
--   2. engine-docs/recipes/rendering.md - 光照配置和LightGroup预设
--   3. engine-docs/recipes/built-in-models.md - 内置模型尺寸参考
-- ============================================================================

-- 引入 UI 系统 (Yoga Flexbox + NanoVG, 40+ 内置控件)
local UI = require("urhox-libs/UI")

-- ============================================================================
-- 1. 全局变量声明 (Global Variables)
-- ============================================================================
---@type Scene
local scene_
---@type Node
local cameraNode_
local yaw_ = 0.0
local pitch_ = 0.0
local debugDraw_ = false

-- HUD 控件引用：事后更新有两种合法模式 (详见 engine-docs/recipes/ui.md「事后更新控件」)
--   模式 A: 保留 local 引用 (本脚手架: 只有一个 fpsLabel_, 类型推导友好)
--   模式 B: id + parent:FindById("id") (HUD 元素多/跨函数时更可扩展, 见 scaffold-2d.lua)
---@type Label
local fpsLabel_
local fpsTimer_ = 0

-- 游戏配置
local CONFIG = {
    Title = "AI Generated 3D Game",
    Width = 1280,
    Height = 720,
    CameraSpeed = 20.0,      -- 相机移动速度
    MouseSensitivity = 0.1,  -- 鼠标灵敏度
    CameraNearClip = 0.1,    -- 近裁剪面
    CameraFarClip = 1000.0,  -- 远裁剪面
}

-- ============================================================================
-- 2. 生命周期函数 (Lifecycle Functions)
-- ============================================================================

function Start()
    -- 设置窗口标题
    graphics.windowTitle = CONFIG.Title
    
    -- 1. 初始化 UI 系统 (自动处理 NanoVG、事件订阅和渲染)
    InitUI()
    
    -- 2. 创建场景
    CreateScene()
    
    -- 3. 设置摄像机和视口
    SetupCameraAndViewport()
    
    -- 4. 创建游戏内容 (AI 在这里填充)
    CreateGameContent()
    
    -- 5. 创建 UI (使用 urhox-libs/UI 控件库)
    CreateUI()
    
    -- 6. 订阅事件
    SubscribeToEvents()
    
    print("=== 3D Game Started: " .. CONFIG.Title .. " ===")
end

function Stop()
    -- 清理 UI 系统 (自动清理 NanoVG 上下文和所有控件)
    UI.Shutdown()
end

-- ============================================================================
-- 3. 初始化辅助函数 (Initialization Helpers)
-- ============================================================================

function CreateScene()
    scene_ = Scene()
    
    -- 创建八叉树 (用于渲染优化)
    scene_:CreateComponent("Octree")
    
    -- 创建调试渲染器 (用于调试可视化)
    scene_:CreateComponent("DebugRenderer")
    
    -- ✅ 最佳实践：使用 LightGroup 加载预设光照环境
    -- LightGroup 包含完整的光照配置（定向光、环境光、雾效等）
    local lightGroupFile = cache:GetResource("XMLFile", "LightGroup/Daytime.xml")
    local lightGroup = scene_:CreateChild("LightGroup")
    lightGroup:LoadXML(lightGroupFile:GetRoot())
    
    -- 可选：如果需要物理系统，取消下面的注释
    -- local physicsWorld = scene_:CreateComponent("PhysicsWorld")
    -- physicsWorld:SetGravity(Vector3(0, -9.81, 0))
end

function SetupCameraAndViewport()
    -- 创建摄像机节点
    cameraNode_ = scene_:CreateChild("Camera")
    cameraNode_.position = Vector3(0, 2, -10)  -- 初始位置
    
    -- 添加摄像机组件
    local camera = cameraNode_:CreateComponent("Camera")
    camera.nearClip = CONFIG.CameraNearClip
    camera.farClip = CONFIG.CameraFarClip
    camera.fov = 75.0  -- 视野角度
    
    -- 设置视口
    local viewport = Viewport:new(scene_, camera)
    renderer:SetViewport(0, viewport)
    
    -- ✅ 最佳实践：开启 HDR 渲染（用于 PBR 材质）
    renderer.hdrRendering = true
    
    -- 初始化相机朝向
    yaw_ = 0.0
    pitch_ = 0.0
end

-- ============================================================================
-- 4. 游戏内容创建 (Game Content - AI 填充区域)
-- ============================================================================

function CreateGameContent()
    -- ⚠️ AI 提示: 在这里创建游戏对象
    -- 
    -- ✅ 最佳实践：PBR 材质（写法见下方示例代码与 CreateSampleBox）
    --
    -- 常见材质参数：
    -- 金属：   Metallic = 0.9,  Roughness = 0.2  (光滑金属)
    -- 塑料：   Metallic = 0.0,  Roughness = 0.5  (塑料感)
    -- 橡胶：   Metallic = 0.0,  Roughness = 0.8  (粗糙橡胶)
    -- 木头：   Metallic = 0.0,  Roughness = 0.7  (木质感)
    -- 发光：   额外设置 MatEmissiveColor 参数
    
    -- ============================================================
    -- 下面是示例代码（可删除）
    -- ============================================================
    
    -- 1. 创建地面（粗糙的深灰色）
    local floorNode = scene_:CreateChild("Floor")
    floorNode.position = Vector3(0, -0.5, 0)
    floorNode.scale = Vector3(100, 1, 100)
    local floorModel = floorNode:CreateComponent("StaticModel")
    floorModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    
    local floorMat = Material:new()
    floorMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    floorMat:SetShaderParameter("MatDiffColor", Variant(Color(0.2, 0.2, 0.25, 1.0)))
    floorMat:SetShaderParameter("MatSpecColor", Variant(Color(0.3, 0.3, 0.3, 1.0)))
    floorMat:SetShaderParameter("Metallic", Variant(0.0))
    floorMat:SetShaderParameter("Roughness", Variant(0.9))
    floorModel:SetMaterial(floorMat)
    floorModel.castShadows = false
    
    -- 2. 创建示例方块（不同材质）
    CreateSampleBox(Vector3(-3, 0.5, 0), Color(0.8, 0.3, 0.2), 0.1, 0.6, "Box1")  -- 塑料质感
    CreateSampleBox(Vector3(0, 0.5, 0), Color(0.9, 0.7, 0.3), 0.95, 0.1, "Box2")  -- 金属质感
    CreateSampleBox(Vector3(3, 0.5, 0), Color(0.3, 0.6, 0.9), 0.0, 0.8, "Box3")   -- 橡胶质感
    
    -- 3. 创建示例球体（光滑金属）
    local sphereNode = scene_:CreateChild("Sphere")
    sphereNode.position = Vector3(0, 2, 5)
    local sphereModel = sphereNode:CreateComponent("StaticModel")
    sphereModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    
    local sphereMat = Material:new()
    sphereMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    sphereMat:SetShaderParameter("MatDiffColor", Variant(Color(0.8, 0.6, 0.2, 1.0)))
    sphereMat:SetShaderParameter("MatSpecColor", Variant(Color(0.8, 0.8, 0.8, 1.0)))
    sphereMat:SetShaderParameter("Metallic", Variant(0.9))
    sphereMat:SetShaderParameter("Roughness", Variant(0.2))
    sphereModel:SetMaterial(sphereMat)
    sphereModel.castShadows = true
    
    print("✅ Scene created with PBR materials and lighting")
end

-- 辅助函数：创建带 PBR 材质的方块
function CreateSampleBox(position, color, metallic, roughness, name)
    local boxNode = scene_:CreateChild(name)
    boxNode.position = position
    local boxModel = boxNode:CreateComponent("StaticModel")
    boxModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    
    local material = Material:new()
    material:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    material:SetShaderParameter("MatDiffColor", Variant(color))
    material:SetShaderParameter("MatSpecColor", Variant(Color(0.5, 0.5, 0.5, 1.0)))
    material:SetShaderParameter("Metallic", Variant(metallic))
    material:SetShaderParameter("Roughness", Variant(roughness))
    boxModel:SetMaterial(material)
    boxModel.castShadows = true
end

-- ============================================================================
-- 5. UI 创建 (UI Creation)
-- ============================================================================

local uiRoot_ = nil  -- UI 根控件引用

function InitUI()
    UI.Init({
        fonts = {
            { family = "sans", weights = {
                normal = "Fonts/MiSans-Regular.ttf",
                -- bold = "Fonts/MiSans-Bold.ttf",  -- 取消注释后可在 Label 中使用 fontWeight = "bold"
            } }
        },
        -- 推荐! DPR 缩放 + 小屏密度自适应（见 engine-docs/recipes/ui.md「分辨率缩放（scale）」）
        -- 1 基准像素 ≈ 1 CSS 像素，尺寸遵循 CSS/Web 常识
        scale = UI.Scale.DEFAULT,
    })
end

function CreateUI()
    -- ⚠️ 关键三步: UI.Init() → 构建控件树 → UI.SetRoot()

    -- 需要事后更新的控件: 创建时赋给 local 变量, 后续直接调方法 (见 HandleUpdate)
    fpsLabel_ = UI.Label {
        text = "FPS: --",
        fontSize = 12,
        fontColor = { 255, 255, 200, 200 },
        position = "absolute",
        top = 10,
        right = 10,
    }

    uiRoot_ = UI.Panel {
        id = "gameUI",
        width = "100%",
        height = "100%",
        pointerEvents = "box-none",  -- SetRoot 会自动设置，这里显式写出便于理解
        children = {
            -- 静态文字: 不需要事后更新, 可以匿名创建
            UI.Label {
                text = "WASD: Move | Mouse Right: Look | Space: Up | C: Down | Tab: Debug",
                fontSize = 12,
                fontColor = { 255, 255, 200, 200 },
                position = "absolute",
                top = 10,
                left = 0,
                right = 0,
                textAlign = "center",
            },
            -- 动态文字: 引用本身作为 children
            fpsLabel_,
        }
    }

    UI.SetRoot(uiRoot_)
end

-- ============================================================================
-- 6. 事件处理 (Event Handlers)
-- ============================================================================

function SubscribeToEvents()
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("PostRenderUpdate", "HandlePostRenderUpdate")
end

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    
    -- 相机控制
    HandleCameraMovement(dt)
    
    -- 游戏逻辑更新 (AI 填充)
    UpdateGameLogic(dt)
    
    -- 调试开关
    if input:GetKeyPress(KEY_TAB) then
        debugDraw_ = not debugDraw_
    end

    -- HUD 动态更新: 保留 local 引用 → 直接调方法
    -- 注意: 节流到 0.25s 更新一次, 避免每帧 SetText 触发文本测量开销
    -- fpsTimer_ 用减法 (不归零), 保留余量避免间隔偏长
    fpsTimer_ = fpsTimer_ + dt
    if fpsLabel_ ~= nil and fpsTimer_ >= 0.25 and dt > 0 then
        fpsLabel_:SetText(string.format("FPS: %d", math.floor(1.0 / dt)))
        fpsTimer_ = fpsTimer_ - 0.25
    end
end

---@param eventType string
---@param eventData PostRenderUpdateEventData
function HandlePostRenderUpdate(eventType, eventData)
    if debugDraw_ then
        -- 绘制调试信息
        local debugRenderer = scene_:GetComponent("DebugRenderer")
        if debugRenderer ~= nil then
            -- 绘制八叉树边界
            debugRenderer:AddBoundingBox(
                BoundingBox(Vector3(-50, -50, -50), Vector3(50, 50, 50)),
                Color(0, 1, 0),
                false
            )
            
            -- 绘制坐标轴
            debugRenderer:AddLine(
                Vector3(0, 0, 0),
                Vector3(5, 0, 0),
                Color(1, 0, 0),  -- X轴 红色
                false
            )
            debugRenderer:AddLine(
                Vector3(0, 0, 0),
                Vector3(0, 5, 0),
                Color(0, 1, 0),  -- Y轴 绿色
                false
            )
            debugRenderer:AddLine(
                Vector3(0, 0, 0),
                Vector3(0, 0, 5),
                Color(0, 0, 1),  -- Z轴 蓝色
                false
            )
        end
    end
end

-- ============================================================================
-- 7. 游戏逻辑 (Game Logic - AI 填充区域)
-- ============================================================================

function UpdateGameLogic(dt)
    -- 示例: 让球体缓慢旋转
    local sphereNode = scene_:GetChild("Sphere")
    if sphereNode ~= nil then
        sphereNode:Rotate(Quaternion(0, 30 * dt, 0))  -- 每秒旋转30度
    end
    
    -- ⚠️ AI 提示: 在这里添加更多游戏逻辑
end

-- ============================================================================
-- 8. 相机控制 (Camera Control)
-- ============================================================================

function HandleCameraMovement(dt)
    -- 鼠标控制视角（右键按下时）
    if input:GetMouseButtonDown(MOUSEB_RIGHT) then
        local mouseMoveX = input.mouseMoveX
        local mouseMoveY = input.mouseMoveY
        
        yaw_ = yaw_ + mouseMoveX * CONFIG.MouseSensitivity
        pitch_ = pitch_ + mouseMoveY * CONFIG.MouseSensitivity
        pitch_ = Clamp(pitch_, -90.0, 90.0)
        
        cameraNode_.rotation = Quaternion(pitch_, yaw_, 0)
    end
    
    -- 键盘控制移动
    local moveSpeed = CONFIG.CameraSpeed
    if input:GetKeyDown(KEY_SHIFT) then
        moveSpeed = moveSpeed * 2.0  -- 加速
    end
    
    if input:GetKeyDown(KEY_W) then
        cameraNode_:Translate(Vector3(0, 0, 1) * dt * moveSpeed)
    end
    if input:GetKeyDown(KEY_S) then
        cameraNode_:Translate(Vector3(0, 0, -1) * dt * moveSpeed)
    end
    if input:GetKeyDown(KEY_A) then
        cameraNode_:Translate(Vector3(-1, 0, 0) * dt * moveSpeed)
    end
    if input:GetKeyDown(KEY_D) then
        cameraNode_:Translate(Vector3(1, 0, 0) * dt * moveSpeed)
    end
    if input:GetKeyDown(KEY_SPACE) then
        cameraNode_:Translate(Vector3(0, 1, 0) * dt * moveSpeed, TS_WORLD)
    end
    if input:GetKeyDown(KEY_C) then
        cameraNode_:Translate(Vector3(0, -1, 0) * dt * moveSpeed, TS_WORLD)
    end
end

-- ============================================================================
-- 使用说明 (Usage Instructions)
-- ============================================================================
--[[
    AI 需要填充的区域：
    1. CreateGameContent() - 创建游戏对象、材质等
    2. UpdateGameLogic() - 更新游戏逻辑

    LightGroup 光照预设（换 CreateScene 里的路径即可）：
    "LightGroup/Daytime.xml"（白天）、"LightGroup/Dusk.xml"（黄昏）、"LightGroup/Night.xml"（夜晚），
    完整列表见 engine-docs/recipes/rendering.md

    内置模型（Box/Sphere/Cylinder/Cone/Plane/Torus/Pyramid）尺寸各不相同，
    用 staticModel.boundingBox.size 读取或查 engine-docs/recipes/built-in-models.md，不要假设都是 1×1×1。

    控制：WASD 移动、鼠标右键拖动旋转视角、Space 上升、C 下降、Shift 加速、Tab 切换调试渲染
]]

