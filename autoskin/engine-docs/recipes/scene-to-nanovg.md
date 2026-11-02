# 在界面中显示 3D 场景预览

将 3D 场景渲染为纹理，并显示到界面上。普通按钮、菜单、HUD 和布局见 [UI 系统指南](ui.md)。

## 接入方式

准备独立的预览场景和相机，按下面的示例生成预览图片，再通过 NanoVG 绘制。

`nvgCreateVideo(nvg, texture)` 将已有的 `Texture2D` 用于 NanoVG 绘制，返回图像句柄，失败时返回 `0`。虽然名字含有 Video，这个函数也可用于 3D 预览。

## 画面方向

`nvgCreateVideo` 已处理预览纹理的上下方向，按普通图片绘制即可，不需要额外翻转 Y。

## 创建预览

先创建 `previewScene` 和 `previewCamera`，在预览场景中放置模型与灯光。下面使用独立的 `Forward.xml` 渲染配置和透明背景，适合叠在界面上；需要其他光照与后效时可换用项目的配置。

```lua
local texture = Texture2D:new()
texture:SetNumLevels(1)
assert(texture:SetSize(512, 512, Graphics:GetRGBAFormat(), TEXTURE_RENDERTARGET))
texture:SetFilterMode(FILTER_BILINEAR)

local viewport = Viewport:new(previewScene, previewCamera)
viewport:SetRenderPath(assert(cache:GetResource("XMLFile", "RenderPaths/Forward.xml")))
do
    local path = viewport:GetRenderPath()
    for i = 0, path:GetNumCommands() - 1 do
        local command = path:GetCommand(i)
        if command.type == CMD_CLEAR then
            command.useFogColor = false
            command.clearColor = Color(0, 0, 0, 0)
        end
    end
end

local surface = texture:GetRenderSurface()
surface:SetViewport(0, viewport)
surface:SetUpdateMode(SURFACE_MANUALUPDATE)
surface:QueueUpdate()
```

预览显示期间保留场景、相机和上述变量。模型加载完成、姿态或相机变化后，调用 `surface:QueueUpdate()`，等待画面更新后再检查结果。

## 绘制与关闭

将下面三个函数与创建代码放在同一作用域。每个预览创建一次，绘制时复用。

```lua
local image, imageContext
local createFailed = false

local function DrawScenePreview(nvg, x, y, size)
    if size <= 0 or not texture or createFailed then return end
    if not image then
        image = nvgCreateVideo(nvg, texture)
        imageContext = nvg
        if image == 0 then
            createFailed = true
            return
        end
    end

    nvgSave(nvg)
    nvgIntersectScissor(nvg, x, y, size, size)
    nvgTranslate(nvg, x, y)
    nvgBeginPath(nvg)
    nvgRect(nvg, 0, 0, size, size)
    nvgFillPaint(nvg, nvgImagePattern(nvg, 0, 0, size, size, 0, image, 1))
    nvgFill(nvg)
    nvgRestore(nvg)
end

local function ReleasePreviewImage()
    if image and image ~= 0 then nvgDeleteVideo(imageContext, image) end
    image, imageContext = nil, nil
    createFailed = false
end

local function DestroyScenePreview()
    ReleasePreviewImage()
    if surface then surface:SetNumViewports(0) end
    if texture then texture:Dispose() end
    surface, viewport, texture = nil, nil, nil
end
```

- **绘制示例**：接入自定义 Widget 时，在 `Render(nvg)` 中取得 `l = self:GetAbsoluteLayout()`，调用 `DrawScenePreview(nvg, l.x, l.y, math.min(l.w, l.h))`。
- **关闭**：停止绘制与更新，调用 `DestroyScenePreview()`，再关闭 UI；独立场景由创建它的代码释放。不要释放其他模块共享的资源。
- **重建图片**：更换纹理、修改尺寸或更换绘制 context 前，调用 `ReleasePreviewImage()`。更换 context 时，在旧 context 仍可用时调用；准备好新资源后再恢复绘制。
- **创建失败**：示例会停止重试。解决原因后调用 `ReleasePreviewImage()`，允许下次绘制重新创建。

用上下、左右容易辨认的模型，检查方向、透明背景、裁剪，以及关闭后重新打开的效果。
