# Plugin.Environment

`Plugin.Environment` 用于判断当前 UrhoXRuntime 是否由 Plugin 宿主启动。

```lua
local Environment = require "urhox-libs/Plugin/Environment"
```

## 常量

```lua
Environment.RUNTIME -- "runtime"
Environment.PLUGIN  -- "plugin"
```

## Get

```lua
local value = Environment.Get()
```

返回 `"runtime"` 或 `"plugin"`。宿主接口不存在或返回非法值时安全回退为 `"runtime"`。

## IsPlugin

```lua
if Environment.IsPlugin() then
    -- Plugin.Agent 和 Plugin.Files 可以调用
end
```

## IsRuntime

```lua
if Environment.IsRuntime() then
    -- 普通游戏 Runtime
end
```

## RequirePlugin

```lua
local ok, err = Environment.RequirePlugin()
if not ok then
    print(err.code)
end
```

Plugin 环境返回 `true`。普通 Runtime 返回：

```lua
false, {
    code = "PLUGIN_ENVIRONMENT_REQUIRED",
    message = "Plugin API is only available in plugin environment",
    retryable = false,
}
```

通常不需要手动调用；`Plugin.Files` 和 `Plugin.Agent` 已在每次操作前检查。

## 与 GetLuaEnvironment 的区别

```lua
GetApplicationEnvironment() -- "runtime" | "plugin"
GetLuaEnvironment()         -- Lua VM 生命周期类型
```

PluginViewer 仍可以使用 Runtime Lua VM，因此不能用 `GetLuaEnvironment()` 判断 Plugin。
业务代码优先调用 `Environment.IsPlugin()`。
