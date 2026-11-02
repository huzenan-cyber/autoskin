# Asset Preview

`AssetPreview` 与 `Editor.CreateEditor` 对齐 Unity 的两层预览范式：列表、选择器使用静态缩略图；需要旋转、缩放、通道检查时创建目标类型的 Editor 并绘制 Preview GUI。

## 静态缩略图

```lua
local material = AssetDatabase.LoadAssetAtPath("Material", "Materials/Stone.xml")
local thumbnail = AssetPreview.GetMiniThumbnail(material)

if thumbnail then
    GUILayout.Image(thumbnail, { width = 64, height = 64, scaleMode = "ScaleToFit" })
elseif AssetPreview.IsLoadingAssetPreview(material) then
    GUILayout.Label("Generating preview...")
else
    GUILayout.Image(AssetPreview.GetMiniTypeThumbnail("Material"), { width = 64, height = 64 })
end
```

| API | 行为 |
|---|---|
| `GetAssetPreview(asset)` | 请求完整预览；纹理直接返回原资源，其它生成式预览最大 256×256 |
| `GetMiniThumbnail(asset)` | 请求 64×64 的紧凑生成式预览；`Texture2D` 直接返回原资源，由布局缩放 |
| `GetMiniTypeThumbnail(typeName)` | 返回类型图标，适合作为加载中或不支持类型的回退 |
| `IsLoadingAssetPreview(asset)` | 查询该资产的完整或 mini 预览是否仍在队列中 |
| `IsLoadingAssetPreviews()` | 查询任意静态预览队列是否仍有任务 |

第一次请求 `Material`、`Model`、`Technique`、`SurfaceShader` 或 Prefab `XMLFile` 时可能返回 `nil`。Editor 每帧推进独立预览队列；后续 `OnGUI` 再次调用同一方法即可取得结果，不要写阻塞等待。资源文件变化、`EditorUtility.SetDirty` 或重新导入后会清除对应缓存。

## 交互式预览

```lua
local model = AssetDatabase.LoadAssetAtPath("Model", "Models/TeaPot.mdl")
local assetEditor = Editor.CreateEditor(model)

function window:OnGUI()
    if assetEditor:HasPreviewGUI() then
        GUILayout.Label(assetEditor:GetPreviewTitle())
        assetEditor:OnPreviewSettings()
        assetEditor:OnInteractivePreviewGUI({ expandWidth = true, height = 420 })
    end
end
```

`Editor.CreateEditor(asset)` 返回由脚本持有的 Editor 对象。它只负责目标资产的预览，不会自动创建顶层窗口。

| API | 行为 |
|---|---|
| `HasPreviewGUI()` | 当前资产类型是否有预览实现 |
| `GetPreviewTitle()` | 面向 UI 的预览标题 |
| `OnPreviewSettings()` | 绘制类型专用工具栏，例如材质球形状、纹理通道和 Fit |
| `OnPreviewGUI(options?)` | 绘制非交互预览 |
| `OnInteractivePreviewGUI(options?)` | 绘制交互预览；3D 资产右键旋转、滚轮缩放，纹理左键平移、滚轮缩放 |
| `RequiresConstantRepaint()` | 是否要求每帧持续重绘；当前内建预览使用变化驱动刷新，因此返回 `false` |

Preview GUI 只能在 `EditorWindow.OnGUI` 或其它 Editor GUI 回调中调用。`options` 使用 `GUILayoutOptions` 的 `width`、`height`、`expandWidth`、`expandHeight`；省略尺寸时占用当前剩余区域。

当前内建支持：

- `Material`、`Technique`、`SurfaceShader`：隔离场景中的 Sphere / Box / Cylinder，复用 Material Editor 的预览视图。
- `Model`：隔离场景中的模型预览。
- `Texture2D`、`Image`：缩放、平移、Fit、通道与棋盘背景，复用 Texture Editor 的预览视图。
- 根元素为 `<node>` 的 `XMLFile`：在隔离场景加载为 Prefab；不会写入当前编辑场景。

完整示例见 [AssetPreviewGallery.lua](../examples/AssetPreviewGallery.lua) 和
[InteractiveAssetPreview.lua](../examples/InteractiveAssetPreview.lua)。
