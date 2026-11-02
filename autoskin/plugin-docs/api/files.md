# Plugin.Files

`Plugin.Files` 异步访问插件正在编辑的目标项目，不访问插件包目录，也不访问 Agent Session。

```lua
local Files = require "urhox-libs/Plugin/Files"
```

## 路径模型

当前公开命名空间：

```text
assets/<path>
docs/<path>
```

本地 `Maker-Plugin` 映射规则：

```text
Files.ReadBinary("assets/demo.jpg")
    -> <projectRoot>/assets/demo.jpg
```

本地 `Maker-Plugin` 还会把 `<projectRoot>/assets/` 注册到 Runtime 的 `ResourceCache`。引擎资源
路径相对于 `assets/`，而 `Plugin.Files` 路径仍然以项目根目录的虚拟路径表示：

```lua
local texture = cache:GetResource("Texture2D", "demo.jpg")
local prefab = cache:GetResource("XMLFile", "generated/room.xml")
```

`Plugin.Files` 负责项目文件读写，`ResourceCache` 负责将这些文件作为纹理、模型、材质、
Prefab 等引擎资源加载。两者都指向正在编辑的目标项目，但路径基准不同：

- `Files.ReadBinary("assets/demo.jpg")` -> `<projectRoot>/assets/demo.jpg`
- `cache:GetResource("Texture2D", "demo.jpg")` -> `<projectRoot>/assets/demo.jpg`

资源目录不指向插件包目录。

路径必须：

- 使用 `/` 分隔。
- 是相对虚拟路径。
- 位于 `assets/` 或 `docs/`。
- 不以 `/`、`~`、盘符或 URI 开头。
- 不包含 `\`、`//`、NUL、`.` 或 `..` 路径段。

合法：

```text
assets/demo.jpg
assets/generated/room.glb
docs/my-plugin/scene.json
```

非法：

```text
C:/tmp/demo.jpg
/assets/demo.jpg
assets\demo.jpg
assets/../docs/a.md
file://assets/demo.jpg
```

绝对路径始终返回 `INVALID_PATH`。本地 Backend 还会拒绝通过符号链接、junction 或
reparse point 逃逸项目根。

## GetCapabilities

```lua
Files.GetCapabilities(function(capabilities, err)
    -- 本地结果：
    -- {
    --     read = true,
    --     writeNamespaces = { "assets", "docs" },
    -- }
end)
```

插件需要适配不同宿主能力时，应查询 capabilities，不要检测操作系统或 Backend 类型。

## 同步模式（预留）

同步模式 API 已预留，默认模式为 `Files.REMOTE`：

```lua
Files.SetMode(Files.LOCAL, function(result, err)
    -- result.mode == Files.LOCAL
end)

Files.GetMode(function(result, err)
    -- result.mode == Files.LOCAL / Files.REMOTE
end)
```

未来 Web/WASM Backend 的语义：

- `Files.REMOTE`：默认模式，文件操作直接访问云端项目。
- `Files.LOCAL`：文件操作直接访问宿主挂载的本地项目目录，供需要实时加载项目资源的插件使用。
- `Files.SyncToRemote`：把本地变更显式同步到云端。
- `Files.SyncToLocal`：把云端内容显式同步到本地挂载目录。

同步接口可以同步整个项目，也可以传入一个虚拟路径：

```lua
Files.SyncToRemote(function(result, err)
end)

Files.SyncToLocal("assets/generated", function(result, err)
end)
```

当前版本仅预留上述接口，不执行文件传输。返回值带有 `supported = false`；同步方法还返回
`synced = false`。Windows 本地 `Maker-Plugin` 的 Files Backend 仍直接读写配置的
`projectRoot`，模式值暂不改变其行为。宿主 Backend 将来提供同名方法后，Lua API 会自动
转发给 Backend，不需要插件业务代码切换接口。

## List

```lua
Files.List("assets", function(entries, err)
    if err then return end
    for _, entry in ipairs(entries) do
        print(entry.name, entry.directory)
    end
end)
```

结果项：

```lua
{
    name = "demo.jpg",
    directory = false,
}
```

`Files.List(nil, callback)` 或 `Files.List("", callback)` 列出虚拟根 `assets`、`docs`。
当前接口只列一层，不递归。

## Exists

```lua
Files.Exists("docs/config.json", function(exists, err)
end)
```

成功结果是 boolean。

## ReadText

```lua
Files.ReadText("docs/config.json", function(text, err)
end)
```

成功结果是 Lua string。该方法不解析 JSON；需要时使用 `cjson.decode`。

## ReadBinary

```lua
Files.ReadBinary("assets/demo.jpg", function(bytes, err)
end)
```

成功结果是包含原始字节的 Lua string，可直接放入 `Agent.CreateSession.references[].data`。
业务 Lua 不需要 Base64。

## WriteText

```lua
Files.WriteText("docs/my-plugin/scene.json", jsonText, function(result, err)
    if not err then
        print(result.written)
    end
end)
```

父目录不存在时自动创建。已有文件会覆盖。当前本地结果：

```lua
{ written = 123 }
```

## WriteBinary

```lua
Files.WriteBinary(
    "assets/generated/preview.png",
    pngBytes,
    "image/png",
    function(result, err)
    end
)
```

`bytes` 是 binary string；`mime` 可为 string 或 `nil`。文件大小和 MIME 限制由 Backend
执行。

## Mkdir

```lua
Files.Mkdir("docs/my-plugin", function(result, err)
    -- result.created == true
end)
```

只允许在 `assets/` 或 `docs/` 下创建目录，不能对命名空间根本身执行变更操作。

## Remove

```lua
Files.Remove("docs/my-plugin/old", function(result, err)
    -- result.removed == true / false
end)
```

当前本地 Backend 会递归删除目录。调用前应由业务确认目标路径，不能把未校验的 Agent
文本直接作为删除路径。

## Rename

```lua
Files.Rename(
    "docs/my-plugin/scene.tmp",
    "docs/my-plugin/scene.json",
    function(result, err)
        -- result.renamed == true
    end
)
```

目标父目录不存在时自动创建。源和目标都必须位于可写命名空间。

## 取消与回调

所有方法立即返回：

```lua
---@class PluginRequestHandle
local handle = {
    Cancel = function() end,
}
```

取消只保证不再向当前调用方投递 callback。不要假设取消能回滚已经完成的文件写入。

## 错误码

| code | 含义 |
|---|---|
| `PLUGIN_ENVIRONMENT_REQUIRED` | 未使用 Plugin 环境启动 |
| `INVALID_REQUEST` | 内容、MIME 或参数类型错误 |
| `INVALID_PATH` | 路径语法非法或越界 |
| `PERMISSION_DENIED` | 操作被文件系统或宿主权限拒绝 |
| `NOT_FOUND` | 文件或目录不存在 |
| `FILE_TOO_LARGE` | 超过宿主配置大小 |
| `BACKEND_UNAVAILABLE` | 文件 Backend 未安装或初始化失败 |
