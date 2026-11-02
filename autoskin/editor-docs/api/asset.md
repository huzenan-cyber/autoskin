# AssetDatabase

`AssetDatabase` 对齐 Unity 的静态入口，但 Lua 参数顺序沿用 UrhoX `ResourceCache:GetResource`：
资产类型在前，工程相对路径在后。

```lua
local material, err = AssetDatabase.LoadAssetAtPath("Material", "assets/Materials/Hero.material")
if not material then
    Editor.Error(err)
end

local copy, cloneErr = Object.Instantiate(material)
if copy then
    copy:SetShaderParameter("Roughness", Variant(0.5))
    local created, createErr = AssetDatabase.CreateAsset(
        copy, "Generated/Materials/HeroCopy.material", { overwrite = false })
end
```

## API

| API | 说明 |
|---|---|
| `LoadAssetAtPath(typeName, path) -> asset, err` | 从 Project 或已挂载 Package 加载 Resource |
| `AssetPathExists(path) -> bool` | 按 ResourceCache 可见性判断路径 |
| `CreateAsset(asset, path, options?) -> asset, err` | 原子写入 UrhoX Resource，默认不覆盖 |
| `CopyAsset(source, destination, options?) -> ok, err` | 可从 Package 读取，目标必须在 Project 内 |
| `SaveAssetIfDirty(asset) -> ok, err` | 保存已由 `EditorUtility.SetDirty` 标记的 Project asset |
| `ImportAsset(path) -> ok, err` | 生成/校验 meta、刷新 cache 和 Resource Browser |
| `Refresh()` | 批量外部变化后刷新 |

`options.overwrite` 默认 `false`。支持 Model、Material、Image/Texture2D、Animation、XMLFile 和 JSONFile
对应的原生扩展名。

所有路径都是 Project-relative Resource path，不暴露也不要求绝对路径。UrhoX 允许资产放在工程任意目录，
因此不强制 `assets/`；`scripts/`、`Generated/` 或自定义目录都合法。拒绝盘符、UNC、URI、NUL、`..`
和工程逃逸。

Package 始终只读，即使它是工程内的本地目录。派生资产请先 `Object.Instantiate`，再写到 Project 新路径。
创建/复制成功会生成 `.meta`、刷新 Resource Browser 并通知 ResourceCache。

常见错误：`EDITOR_SCRIPT_ASSET_EXISTS`、`EDITOR_SCRIPT_ASSET_READ_ONLY`、
`EDITOR_SCRIPT_ASSET_EXTENSION_MISMATCH`、`EDITOR_SCRIPT_ASSET_TYPE_UNSUPPORTED`、
`EDITOR_SCRIPT_ASSET_NOT_PERSISTENT`、`EDITOR_SCRIPT_PATH_DENIED`。
