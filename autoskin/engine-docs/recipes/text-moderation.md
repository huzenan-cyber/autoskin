# 客户端文本审核（CheckText）

> 🎮 **适用范围：客户端 Lua（Runtime）**
> 在发布聊天、昵称、玩家创作内容等玩家输入前调用。服务端 Lua 与 Host Sandbox 中没有 `CheckText`。

`CheckText(text)` 使用玩家当前的登录状态审核文本。审核所需的身份与项目信息由引擎自动处理，游戏脚本无需也无法传入。

```lua
coroutine.start(function()
    local allowed, reason = CheckText("hello")
    if allowed then
        -- 发布或使用这段原文。
    elseif reason == "reject" or reason == "review" then
        -- 提示玩家修改文本。
    elseif reason == "UNSUPPORTED_ENVIRONMENT" then
        -- 不发布，并在当前环境禁用提交入口。
        print("当前环境不支持文本审核")
    else
        -- 请求失败：不发布，提示玩家稍后重试。
        print("文本审核失败: " .. reason)
    end
end)
```

## 调用约束

- 只挂起所在协程，渲染和其他脚本照常运行。在不可 yield 的事件回调里直接调用会抛出用法错误；把异步逻辑包进 `coroutine.start`。
- 每个 Lua VM 同时最多 1 个审核请求；多余的调用立即返回 `false, "BUSY"`，不排队。只在玩家提交时调用一次，不要每帧调用，也不要连续快速提交。
- 协程被关闭后不会再被恢复；Lua VM 销毁（如切换脚本）后到达的结果会被忽略。
- 恢复后的协程如果出错，日志会包含该协程自己的调用栈。
- 游戏须先完成正常的账号登录。

## 返回值

只有 `allowed == true` 才允许使用该文本。`reason` 为 `pass`、`reject`、`review`，或以下错误码：

| 错误码 | 含义 / 处理 |
| --- | --- |
| `NOT_LOGGED_IN`、`NO_PROJECT_ID` | 未登录或缺少项目信息；登录后再试 |
| `EMPTY_TEXT` | 空字符串 |
| `INVALID_TEXT` | 文本无效：非法 UTF-8、内嵌 NUL 或只有空白字符；提示玩家修改 |
| `TEXT_TOO_LARGE` | 超出长度上限；提示玩家缩短 |
| `BUSY` | 本 VM 上一次审核尚未返回；等它完成后再提交 |
| `RATE_LIMITED` | 提交过于频繁；稍后再试 |
| `UNAUTHORIZED` | 登录状态无效或已过期 |
| `UNAVAILABLE`、`TIMEOUT`、`NETWORK_ERROR`、`INVALID_RESPONSE` | 审核暂不可用或没有可信结论；不发布，可提示重试 |
| `HTTP_<status>` | 其他服务错误；不发布 |
| `UNSUPPORTED_ENVIRONMENT` | 当前环境不支持，重试无效（见下文） |

文本最多 4096 个 UTF-8 字节；字符数上限由审核服务决定，当前为 1000 个字符（Unicode 码点），以后可能调整。超出任一上限返回 `TEXT_TOO_LARGE`，不会截断。输入框长度不要依赖固定字符数，以 `CheckText` 的返回结果为准。

## 可用环境

审核服务由引擎根据当前运行环境自动选择，游戏无需配置，也不能指定。国际版与审核包暂不支持，返回 `UNSUPPORTED_ENVIRONMENT`。遇到该错误时不要反复重试：保持内容不发布、禁用提交入口并提示不可用。

## 安全边界

`CheckText` 是客户端的建议性检查：结果只在客户端判定，没有和发布动作绑定，被修改的客户端可以跳过它。如果内容必须经过审核才能对其他玩家可见，接收和转发这些内容的服务端（如联网游戏服务器）还需要自行把关，不能只信任客户端上报的审核结果。
