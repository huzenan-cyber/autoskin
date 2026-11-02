# 资产预览窗口

列表和 Gallery 先用 `AssetPreview`，只有需要 orbit、zoom、pan 或纹理通道工具时才创建 `AssetEditor`。这能避免一个资源列表为每一项都分配 Preview Scene 和 RenderTexture。

## 静态 Gallery

```lua
local asset, err = AssetDatabase.LoadAssetAtPath("Material", "Materials/Stone.xml")

function window:OnGUI()
    if not asset then
        EditorGUILayout.HelpBox(err or "Load failed", EditorGUI.MessageType.Error)
        return
    end

    local preview = AssetPreview.GetAssetPreview(asset)
    local fallback = AssetPreview.GetMiniTypeThumbnail("Material")
    GUILayout.Image(preview or fallback, {
        width = 200,
        height = 200,
        scaleMode = "ScaleToFit",
    })
end
```

不要在 `OnGUI` 内循环等待预览。第一次缓存未命中时返回 `nil` 是正常状态；Editor 会在后续帧推进生成队列。

## 交互式 Utility

```lua
local asset = AssetDatabase.LoadAssetAtPath("Model", "Models/TeaPot.mdl")
local assetEditor = Editor.CreateEditor(asset)
local window = Editor.Window("Model Preview", "recipes.model_preview", {
    width = 720,
    height = 620,
})

function window:OnGUI()
    if not assetEditor:HasPreviewGUI() then
        EditorGUILayout.HelpBox("Preview unavailable", EditorGUI.MessageType.Info)
        return
    end

    assetEditor:OnPreviewSettings()
    assetEditor:OnInteractivePreviewGUI({ expandWidth = true, height = 500 })
end

Editor.MenuItem("Tools/Model Preview", function()
    window:ShowUtility()
end)
```

`AssetEditor` 放在窗口字段或脚本 upvalue 中即可维持预览状态。若希望窗口关闭时立即释放 Preview Scene，可在 `OnDisable` 中把引用置为 `nil`，下次 `OnEnable` 再创建。

完整覆盖样例：

- [AssetPreviewGallery.lua](../examples/AssetPreviewGallery.lua)：full / mini / type icon、异步 loading。
- [InteractiveAssetPreview.lua](../examples/InteractiveAssetPreview.lua)：Material / Model / Texture / Prefab 与交互/非交互切换。
- [UtilityWindow.lua](../examples/UtilityWindow.lua)：置顶、焦点和生命周期。
