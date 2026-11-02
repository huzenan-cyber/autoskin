# UrhoX 自定义大厅开发手册

> **本手册是 UrhoX 自定义大厅（Custom Lobby）的权威参考文档。**
> 如果你是 AI 助手，在为游戏编写大厅 UI 之前，请先读完[总览](#总览两条路怎么选)，按需要选定其中一条路，再深入对应部分。
>
> 大厅界面一律用 **`urhox-libs/UI`** 搭建（控件目录与详细用法见 `engine-docs/recipes/ui.md`）。本手册有**两条联机入口实现路径**：**模板换皮**（第一部分）和**完全自建**（第二部分）。原有 API、页面模型和联机接口在两条路径中保持不变。

## 目录

**总览**：[两条路怎么选](#总览两条路怎么选)

**第一部分 · 模板换皮（默认联机入口的 UI 换皮）**

1. [快速开始](#1-快速开始)
2. [加载与覆盖机制](#2-加载与覆盖机制)
3. [界面与弹窗注册：`Lobby.DefineScreen` / `Lobby.DefineDialog`](#3-界面与弹窗注册lobbydefinescreen--lobbydefinedialog)
4. [控件代理 · 动作 · 状态 · 数据回调](#4-控件代理--动作--状态--数据回调)
5. [两种玩法：装饰功能控件 / 自建控件树](#5-两种玩法装饰功能控件--自建控件树)
6. [完整示例：全流程换皮](#6-完整示例全流程换皮)
7. [模板 API 边界与常见陷阱](#7-模板-api-边界与常见陷阱)

**第二部分 · 完全自建（完整引擎）**

8. [何时选它 · 入口契约](#8-何时选它--入口契约)
9. [`ctx.client` 平台接口](#9-ctxclient-平台接口)
10. [生命周期 · 错误 · 系统弹窗 · 关键约定](#10-生命周期--错误--系统弹窗--关键约定)
11. [示例走读](#11-示例走读)

**第三部分 · 两条路通用**

12. [用 `urhox-libs/UI` 搭界面](#12-用-urhox-libsui-搭界面)
13. [资源与图片路径](#13-资源与图片路径)

---

## 总览：两条路怎么选

### 先判断项目是否进入联机入口

项目源配置 `.project/settings.json` 中的 `@runtime.multiplayer.enabled` 决定启动路径。构建后，`@runtime` 内容会提升到运行时资源 `settings.json` 的顶层；引擎运行时读取的是后者：

| 配置 | 启动路径 |
|---|---|
| `multiplayer.enabled: true` | 进入联机运行路径，使用默认入口（可由固定的 `scripts/lobby_ui.lua` 换皮）或 `multiplayer.lobby_runtime` |
| `multiplayer.enabled: false` 或缺失 | 进入普通单机脚本，**不会进入 `lobby_runtime`**，也不使用本手册的联机接口 |

纯单机项目不需要为了进入游戏而配置 `lobby_runtime`。本手册后文的“本地游玩”特指：启用联机的项目在自定义大厅中直接运行本地逻辑的单人分支。项目仍然可以设计只有一名玩家的联机房间，但那属于“单人联机玩法”，不是这里所说的“本地游玩”。

人数上限、后台匹配与 `match_info` 的配置及默认值见 [联机与匹配配置](network-game-guide.md#16-联机与匹配配置)。

**冷启动恢复上一局（默认关闭）**：在项目源配置 `.project/settings.json` 中显式开启：

```json
{
  "@runtime": {
    "multiplayer": {
      "enabled": true,
      "startup_reconnect": true
    }
  }
}
```

运行时对应 `settings.json` 的 `multiplayer.startup_reconnect`。仅布尔值 `true` 开启：冷启动发现当前项目的历史会话时，询问玩家继续游戏或放弃上一局；`false` 或未配置时自动放弃当前项目旧会话，继续正常大厅、后台匹配或中途局启动流程。项目 ID 为空时无法隔离会话，不查询或取消跨项目会话，仅继续启动。此开关在新旧大厅均生效，**不影响游戏运行中的断线重连**。

UrhoX 内置一套开箱即用的大厅（快速匹配 / 浏览房间 / 创建房间 / 等待房间 / 连服）。**网络连接、房间数据、匹配逻辑、脚本切换始终由引擎托管**——这一点两条路都一样，制作人不必也不能自己重写网络与匹配。两条路的区别在于**你对界面与流程有多大控制权、跑在什么环境里**：

| 维度 | 模板换皮（第一部分） | 完全自建（第二部分） |
|---|---|---|
| 怎么做 | 写固定的 `scripts/lobby_ui.lua`，用 `Lobby.DefineScreen` / `Lobby.DefineDialog` 在引擎内置的 5 屏 + 系统弹窗上换皮 | 写一个 Runtime 入口脚本，`return function(ctx)`，拿 `ctx.client` 接平台、`ctx.root` 挂 UI |
| 界面用什么搭 | `urhox-libs/UI` 控件（挂到引擎给的控件代理下）| `urhox-libs/UI` 控件（挂到 `ctx.root` 下）|
| 你能控制 | 视觉：背景 / 配色 / 文案 / 布局 / 位置 / 动画 / 弹窗美术 | **整套 UI + 屏的数量与结构 + 导航 + 流程**（自己的屏、自己的进出方式）|
| 屏模型 | 固定 5 屏（main / room_list / room_waiting / quick_match_waiting / connecting）| 无固定屏，全由你定 |
| 运行环境 | 模板 API 环境（`LobbyUI` / `LobbyState` / `Timer` / `Lobby` / `UI`）| 自定义 Runtime 入口（由项目自管 `client` / `root`）|
| 入口选择 | 固定加载 `scripts/lobby_ui.lua`，无需配置 | `multiplayer.lobby_runtime` |
| 起点文件（别只盯一份）| `urhox-libs/GameLobby/Runtime/Template/DefaultLobbyUI.lua`（控件树范式，靠控件 + 配色，无需出图）<br>`urhox-libs/GameLobby/Runtime/Example/Example_lobby_ui.lua`（图片驱动范式，背景图 + 控件）| `urhox-libs/GameLobby/Runtime/Example/Example_Custom_LobbyRuntime.lua`（从零自建）<br>`urhox-libs/GameLobby/Runtime/Template/LobbyRuntimeUI.lua`（默认入口，最简实现）|
| 适合 | 只想修改默认大厅的外观，但沿用引擎联机流程 | 完全自建大厅：自己的首页、屏、导航、本地游玩和联机流程 |

**怎么选**：先看源配置 `.project/settings.json` 的 `@runtime.multiplayer.enabled`。纯单机项目不进入本系统；启用联机后，如果只改默认大厅外观，使用模板换皮；如果要完全自定义大厅、本地游玩分支或不同导航，使用完全自建。不写大厅脚本时，游戏使用引擎默认大厅。

> 🔴 **铁律：背景图只能是纯装饰性场景，UI 组件一律写在 Lua 里。**（两条路都适用）
>
> 生成 / 选用大厅背景图时，背景**只能**包含装饰元素——渐变、氛围、光效、自然 / 场景元素等。
> **严禁**把按钮、文字标签、菜单、进度条、图标、房间卡、头像框等任何**可交互或承载信息的 UI 组件画进背景图**。
> 这些一律用 `urhox-libs/UI` 控件实现。
>
> 为什么：烧进背景图的"按钮 / 文字"**点不动、不能随分辨率与数据变化、无法本地化**，还会和真实功能按钮**位置错位、重叠**。背景与 UI 必须彻底分离——背景管"好看"，控件管"能用"。

---

## 第一部分 · 模板换皮（默认联机入口的 UI 换皮）

> 仅适用于 `multiplayer.enabled: true` 的联机项目：在引擎内置的 5 屏 + 系统弹窗上换外观，脚本使用模板 API，专注"长什么样"。匹配·房间·连服流程全由引擎托管。

制作人能做的、且只能做的，是**自定义大厅长什么样**：

| 归属 | 内容 | 制作人 |
|---|---|---|
| 引擎 | 网络协议、房间创建/加入参数、玩家与房间业务数据、匹配逻辑、脚本切换 | 不可介入 |
| 制作人 | 控件视觉 / 文案 / 布局 / 位置 / 界面切换响应 / 等待动画 / 系统弹窗美术 | **完全自定义** |
| 桥接 | 大厅动作（开始匹配、加入房间……） | 经 `Lobby.*` 预定义动作触发 |

逻辑固定写在项目的 **`scripts/lobby_ui.lua`** 里。脚本使用模板 API（见 [§7](#7-模板-api-边界与常见陷阱)）。界面用 `urhox-libs/UI` 控件搭（见 [§12](#12-用-urhox-libsui-搭界面)）。需要脱离 5 屏模板框架、自己掌控大厅的页面、导航和本地游玩分支时，改走[第二部分 · 完全自建](#第二部分--完全自建完整引擎)。

### 1. 快速开始

**不写任何东西**：游戏自带一套完整可用的默认大厅（引擎模板）。

**只想改主界面背景和按钮**：在项目大厅脚本里写：

```lua
Lobby.DefineScreen("main", {
    enter = function()
        -- 背景：在 background 控件下挂一张铺满的图片面板（缺图时只显示底色，照样能用）
        LobbyUI.main.background:addChild(UI.Panel {
            width = "100%", height = "100%",
            backgroundColor = { 16, 20, 38, 255 },
            backgroundImage = "UI/bg.png", backgroundFit = "cover",
        })

        -- 把"快速匹配"功能按钮定位 + 用控件样式做外观
        local btn = LobbyUI.main.quick_match_button
        btn.style.position = "absolute"
        btn.style.right = 80; btn.style.top = 300; btn.style.width = 460; btn.style.height = 120
        btn.style.background = { 83, 52, 131, 255 }; btn.style.borderRadius = 24
        btn.style.alignItems = "center"; btn.style.justifyContent = "center"
        btn:addChild(UI.Label { text = "快速开战", fontSize = 28, fontColor = { 255, 255, 255, 255 } })
    end,
})
```

主界面变成自定义视觉，**其余四屏自动沿用引擎默认**。点击该按钮照常触发引擎的快速匹配。

### 2. 加载与覆盖机制

`LobbyUI.Show()` 启动大厅时：

1. **默认模板始终先加载**（即 `urhox-libs/GameLobby/Runtime/Template/DefaultLobbyUI.lua`），为全部 5 屏注册默认实现，作为基底兜底。
2. 尝试加载项目固定脚本 `scripts/lobby_ui.lua`；文件不存在时只使用默认模板。
3. 项目脚本**在基底上增量覆盖**：你 `Lobby.DefineScreen` 了哪屏，就接管哪屏；你 `Lobby.DefineDialog` 了哪类弹窗，就接管哪类弹窗；没碰的沿用默认。
4. 制作人脚本出错也**不会整屏黑**——默认基底已就位会回退默认模板；错误写入引擎日志（`log:Write(LOG_ERROR)`）。

> **固定文件名**：模板换皮只加载 `scripts/lobby_ui.lua`。需要使用其他目录结构或自定义整个入口时，请改走 `multiplayer.lobby_runtime` 的完全自建路径。

> **二选一，不混合**：同一屏要么你完全定义，要么完全用默认。`Lobby.DefineScreen("main", ...)` 后，main 这一屏的视觉与回调就完全归你。

### 3. 界面与弹窗注册：`Lobby.DefineScreen` / `Lobby.DefineDialog`

#### 3.1 `Lobby.DefineScreen`

```lua
Lobby.DefineScreen(name, def)
```

- `name`：`"main"` | `"room_list"` | `"room_waiting"` | `"quick_match_waiting"` | `"connecting"`
- `def`：该屏的视觉与回调定义表

| 字段 | 签名 | 说明 |
|---|---|---|
| `enter` | `fun()` | **必填**。进入该屏时构建视觉（在此 `:addChild` 控件）|
| `update` | `fun(dt)` | 可选。每帧调用（动画、计时）|
| `onRoomList` | `fun(rooms)` | 仅 `room_list`：房间列表刷新时 |
| `onRoomPlayers` | `fun(players, masterId)` | 仅 `room_waiting`：房间人员变化时 |
| `onMatchmaking` | `fun(status)` | 仅 `quick_match_waiting`：匹配状态变化时 |
| `onServerProgress` | `fun(progress, status)` | 仅 `connecting`：连接游戏服务器进度变化时 |

`enter` 在每次进入该屏时重新执行（界面被销毁重建），需要跨帧访问的控件引用存到 upvalue 即可。

#### 3.2 `Lobby.DefineDialog`

```lua
Lobby.DefineDialog(kind, def)
```

- `kind`：弹窗类型 / 匹配标签。Host 发出 `"error"`、`"kicked"`、`"dialog"`、`"choice"` 四类业务弹窗；`"system"` 不是业务弹窗，只作部分弹窗的统一兜底皮肤。
- `def`：可以是 `{ show = function(ctx) ... end }`，也可以直接是 `function(ctx) ... end`。
- 未注册、返回 `false` 或回调报错时，会继续尝试该弹窗的 fallback；最后仍未命中才沿用引擎默认弹窗。

**弹窗类型怎么选**

| 玩家看到的情况 | kind | 来源 | 自定义查找顺序 |
|---|---|---|---|
| 操作失败、请求失败、连接失败、重连提示 | `error` | `LobbyControl.ShowError(...)`，以及 Runtime UI 内创建房间、匹配、加载房间、加入房间、启动游戏失败等 | `error` -> 引擎默认错误 Toast |
| 被服务器踢出、账号重复登录、断线后回大厅 | `kicked` | `LobbyControl.ShowKickedDialog(...)` | `kicked` -> `dialog` -> `system` -> 引擎默认被踢弹窗 |
| 系统要求玩家确认的提示，例如版本过低并退出 | `dialog` | `LobbyControl.ShowDialog(...)` | `dialog` -> `system` -> 引擎默认确认弹窗 |
| 必须在两个结果中做选择，例如继续上一局 / 放弃上一局 | `choice` | 交互式 `SystemNotification` | `choice` -> 引擎默认双按钮弹窗 |
| 想统一普通确认弹窗 / 被踢弹窗的兜底外观 | `system` | Host 不主动发出该 kind | 只作为 `dialog` / `kicked` 的 fallback；不会兜底 `error` |

因此：

- 只想统一"确认类弹窗"和"被踢类弹窗"的底色、卡片、按钮风格，可以写 `Lobby.DefineDialog("system", ...)`。
- 想改错误提示，必须写 `Lobby.DefineDialog("error", ...)`；`system` 不会接管错误 Toast。
- 想让被踢提示比普通确认弹窗更醒目，单独写 `Lobby.DefineDialog("kicked", ...)`。
- 想接管双按钮选择弹窗，写 `Lobby.DefineDialog("choice", ...)`，并确保主、次按钮分别调用 `ctx.primary()` / `ctx.secondary()`。

**`ctx` 字段**

| 字段 | 说明 |
|---|---|
| `ctx.kind` | 当前正在匹配的 kind。fallback 时会变化 |
| `ctx.sourceKind` | 原始 kind。fallback 后仍保持原始来源 |
| `ctx.title` | 弹窗标题 |
| `ctx.message` | 弹窗正文 |
| `ctx.buttonText` | 按钮文案 |
| `ctx.secondaryButtonText` | 次按钮文案，仅 `choice` 弹窗提供 |
| `ctx.icon` | 图标文本 |
| `ctx.mount(widget)` | 把自定义弹窗根控件挂到大厅 UI 根节点 |
| `ctx.close()` | 关闭非 `choice` 弹窗并执行可选的专用关闭回调；`choice` 不提供 |
| `ctx.primary()` | 执行主选择并关闭弹窗 |
| `ctx.secondary()` | 执行次选择并关闭弹窗，仅 `choice` 弹窗提供 |

**各 kind 的内容来源**

| kind | 内容来源 |
|---|---|
| `error` | 错误提示内容，由框架传入 `title` / `message` / `buttonText` |
| `kicked` | 被踢 / 断开提示内容，由框架传入 `title` / `message` / `buttonText` / `icon` |
| `dialog` | 系统确认弹窗内容，由调用方传入 `title` / `message` / `buttonText` / `icon` |
| `choice` | 双按钮选择弹窗，比 `dialog` 多 `secondaryButtonText` / `secondary` |
| `system` | 不产生新内容；作为 `dialog` / `kicked` fallback 时沿用原始内容 |

注意：

- `ctx.title` / `ctx.message` / `ctx.buttonText` / `ctx.icon` 是内容数据，不是强制显示内容。自定义 UI 可以不用它们。
- `ctx.onClose` 不开放；`choice` 的关闭入口应按项目语义明确绑定 `ctx.primary()` 或 `ctx.secondary()`。
- 除表内字段外，不要依赖其他 `ctx` 字段。

示例：

```lua
Lobby.DefineDialog("kicked", {
    show = function(ctx)
        local overlay = UI.Panel {
            position = "absolute", top = 0, left = 0, right = 0, bottom = 0,
            alignItems = "center", justifyContent = "center",
            backgroundColor = { 0, 0, 0, 210 },
        }
        local card = UI.Panel { width = 520, padding = 32, flexDirection = "column", gap = 16 }
        card:AddChild(UI.Label { text = ctx.title or "连接已断开", fontSize = 28 })
        card:AddChild(UI.Label { text = ctx.message or "", fontSize = 18 })
        local ok = UI.Button { height = 52, onClick = function() ctx.close() end }
        ok:AddChild(UI.Label { text = ctx.buttonText or "确认" })
        card:AddChild(ok)
        overlay:AddChild(card)
        ctx.mount(overlay)
        return true
    end,
})
```

### 4. 控件代理 · 动作 · 状态 · 数据回调

#### 4.1 五个界面与控件代理

每屏通过 `LobbyUI.<screen>.<control>` 访问引擎提供的控件代理。**输错控件名会立即报错**（不是静默返回 nil）。

| 界面 | 可用控件 |
|---|---|
| `LobbyUI.main` | `background` / `quick_match_button` / `browse_button` / `create_button` / `exit_button` |
| `LobbyUI.quick_match_waiting` | `background` / `cancel_button` / `status_text` |
| `LobbyUI.room_list` | `background` / `back_button` / `refresh_button` |
| `LobbyUI.room_waiting` | `background` / `start_button` / `leave_button` |
| `LobbyUI.connecting` | `background` |

> 功能按钮（`*_button`）由引擎创建为**透明占位**（width/height 为 0，自带 onClick 接好引擎动作）。制作人负责给它定位 + 用控件样式 / 子控件做外观；点击区域与视觉由同一个控件承载，天然对齐、跨分辨率可靠。

**控件代理 API**

| 成员 | 类型 | 说明 |
|---|---|---|
| `.text` | string | 主文案（读写）|
| `.visible` | boolean | 是否可见（读写）|
| `.opacity` | number | 透明度 0~1（读写）|
| `.icon` | string | 图标图片路径（读写，相对 `assets/`，见 [§13](#13-资源与图片路径)）|
| `.style` | StyleProxy | 样式代理（写入触发布局重算）|
| `:addChild(widget)` | — | 挂一个 `urhox-libs/UI` 控件到该控件下 |
| `:clearChildren()` | — | 清空子控件 |

**`style` 可写属性**

`background` `color` `borderColor` `fontSize` `fontWeight` `fontColor` `width` `height`
`padding` `paddingTop/Bottom/Left/Right` `margin` `marginTop/Bottom/Left/Right`
`flexDirection` `alignItems` `justifyContent` `gap` `borderRadius` `borderWidth` `opacity`
`position` `left` `top` `right` `bottom`

> 颜色用 `{r, g, b, a}`（0~255）或十六进制字符串 `'#RRGGBB'`。定位优先用 `right`/`bottom` 锚定屏幕边缘，跨分辨率点击区域始终随布局重算、与视觉对齐。图片背景在控件代理上用 `:addChild` 一个带 `backgroundImage` 的 `UI.Panel` 实现（`.style` 只管底色）。

#### 4.2 `Lobby.*` 动作与数据

`Lobby` 表是制作人与引擎的唯一桥梁：只读数据 + 预定义动作。

**查询**

| 调用 | 返回 | 说明 |
|---|---|---|
| `Lobby.GetMyUserId()` | integer | 本机玩家 ID |
| `Lobby.GetUserNickname(opts)` | — | 异步查昵称，见下 |
| `Lobby.GetMaxPlayers()` | integer | 房间最大人数 |
| `Lobby.GetProjectId()` | string | 项目 ID |
| `Lobby.IsOnline()` | boolean | 在线 |
| `Lobby.IsInRoom()` | boolean | 在房间中 |
| `Lobby.IsMatching()` | boolean | 匹配中 |
| `Lobby.config` | table | 只读配置（`allowQuickMatch` / `allowBrowseRooms` / `allowCreateRoom` / `maxPlayers` / `mapName` / `mode` 等）|

```lua
Lobby.GetUserNickname({
    userIds = { userId },
    onSuccess = function(nicknames) print(nicknames[1].nickname) end,
    onError = function(code) end,
})
```

**动作（触发引擎托管的大厅流程）**

| 调用 | 作用 |
|---|---|
| `Lobby.QuickMatch()` | 开始快速匹配（进入 `quick_match_waiting`）|
| `Lobby.CancelMatch()` | 取消匹配，回主界面 |
| `Lobby.BrowseRooms()` | 进入浏览房间 |
| `Lobby.CreateRoom()` | 创建房间 |
| `Lobby.JoinRoom(roomId, maxPlayers)` | 加入指定房间 |
| `Lobby.LeaveRoom()` | 离开房间，回主界面 |
| `Lobby.StartGame()` | 房主开始游戏 |
| `Lobby.RefreshRoomList()` | 刷新房间列表（结果经 `onRoomList` 回填）|
| `Lobby.GotoMain()` | 回主界面 |
| `Lobby.Exit()` | 退出游戏 |

#### 4.3 `LobbyState` 只读状态

`LobbyState` 是引擎下发的只读快照（**写入会报错**）。在 `enter` / `update` 里随时读。

| 字段 | 类型 | 说明 |
|---|---|---|
| `LobbyState.screen` | string\|nil | 当前界面名 |
| `LobbyState.matchmaking.status` | `"idle"`/`"searching"`/`"found"` | 匹配状态 |
| `LobbyState.matchmaking.elapsed` | number | 当前匹配已等待秒数（仅 `searching` 累加）|
| `LobbyState.room.players` | table[] | 当前房间玩家 |
| `LobbyState.room.title` | string | 房间标题（`#ID 名称`）|
| `LobbyState.self.nickname` | string | 本机昵称 |
| `LobbyState.connecting.progress` | number | 连接游戏服务器进度，范围 0~1 |
| `LobbyState.connecting.status` | string | 连接游戏服务器状态文案 |

> **匹配等待屏的计时由引擎逐帧累加**：`elapsed` 在 `update(dt)` 里直接读它刷新文案即可，不必自己计时。

#### 4.4 数据回调（房间列表 / 玩家 / 匹配 / 连服进度）

动态内容（房间、玩家）由引擎拉取后经回调下发，制作人在回调里重建控件树。

**`onRoomList(rooms)` — 仅 `room_list`**

`Lobby.RefreshRoomList()` 或引擎自动刷新后触发。每个 `room`：

| 字段 | 说明 |
|---|---|
| `room.id` | 房间 ID |
| `room.name` | 房间名 |
| `room.status` | `1`=等待中 `2`=匹配中 `3`=游戏中 |
| `room.ownerId` | 房主 ID |
| `room.playerCount` / `room.maxPlayers` | 当前 / 最大人数 |
| `room.latency` | 延迟（ms）|

**`onRoomPlayers(players, masterId)` — 仅 `room_waiting`**

房间人员变化时触发。`players[i].userId` / `players[i].nickname`；`masterId` 为房主 ID。
典型用法：重建玩家格 + 按 `masterId == Lobby.GetMyUserId()` 决定开始键可见性。

**`onMatchmaking(status)` — 仅 `quick_match_waiting`**

`status` 为 `"searching"` / `"found"` / `"idle"`。多数情况下直接读 `LobbyState.matchmaking` 更方便。

**`onServerProgress(progress, status)` — 仅 `connecting`**

连接游戏服务器时触发。`progress` 为 0~1，`status` 为当前状态文案。多数情况下直接读 `LobbyState.connecting.progress` / `LobbyState.connecting.status` 更方便。

### 5. 两种玩法：装饰功能控件 / 自建控件树

每屏可二选一或混用：

**玩法 A — 装饰引擎功能控件**：把 `*_button` 定位（`style.position/left/top/right/bottom/width/height`）+ 用 `.style`（底色 / 圆角 / 描边）+ `:addChild` 一个 `UI.Label` 做外观。适合固定的功能按钮。需要时先 `:clearChildren()` 清掉占位内容。

**玩法 B — 自建控件树**：用 `urhox-libs/UI` 控件（见 [§12](#12-用-urhox-libsui-搭界面)），在 `background` 上 `:addChild` 自己的控件树，交互绑到 `Lobby.*`。动态列表（房间 / 玩家）必须用此方式，从 `onRoomList` / `onRoomPlayers` 的数据渲染。

### 6. 完整示例：全流程换皮

**可直接复制起步**：`urhox-libs/GameLobby/Runtime/Example/Example_lobby_ui.lua` 是一份接管全部 5 屏和系统弹窗的完整样例——复制其内容到项目大厅脚本，把里面的资源路径换成自己的图片、按需改配色即可。只想改部分界面 / 弹窗时，删掉不需要的 `Lobby.DefineScreen` / `Lobby.DefineDialog`，未覆盖的自动沿用引擎默认模板。不想出图、想要纯控件树写法的，改复制 `urhox-libs/GameLobby/Runtime/Template/DefaultLobbyUI.lua`。

下面是骨架（界面全用 `urhox-libs/UI` 控件搭）：

```lua
-- scripts/lobby_ui.lua

-- 复用工具：给功能按钮定位 + 底色 + 居中文字
local function skinButton(ctrl, pos, label, color)
    ctrl:clearChildren()
    ctrl.style.position = "absolute"
    ctrl.style.background = color or { 83, 52, 131, 255 }
    ctrl.style.borderRadius = 20
    ctrl.style.alignItems = "center"; ctrl.style.justifyContent = "center"
    for k, v in pairs(pos) do ctrl.style[k] = v end
    ctrl:addChild(UI.Label { text = label, fontSize = 26, fontColor = { 255, 255, 255, 255 } })
end

-- 复用工具：给 background 铺一张背景图（缺图只剩底色）
local function skinBackground(ctrl, image)
    ctrl:addChild(UI.Panel {
        width = "100%", height = "100%",
        backgroundColor = { 16, 20, 38, 255 },
        backgroundImage = image, backgroundFit = "cover",
    })
end

-- 主界面：背景图 + 功能按钮
Lobby.DefineScreen("main", {
    enter = function()
        skinBackground(LobbyUI.main.background, "UI/bg.png")
        skinButton(LobbyUI.main.quick_match_button,
            { right = 80, top = 300, width = 460, height = 120 }, "快速开战")
    end,
})

-- 快速匹配等待：背景 + 计时文案（在 update 里刷新，引擎已逐帧累加 elapsed）
Lobby.DefineScreen("quick_match_waiting", {
    enter = function()
        skinBackground(LobbyUI.quick_match_waiting.background, "UI/match_bg.png")
        skinButton(LobbyUI.quick_match_waiting.cancel_button,
            { left = "50%", marginLeft = -150, bottom = 90, width = 300, height = 64 },
            "取消匹配", { 200, 70, 70, 255 })
    end,
    update = function()
        local e = math.floor(LobbyState.matchmaking.elapsed or 0)
        LobbyUI.quick_match_waiting.status_text.text = string.format("匹配中 %02d:%02d", e // 60, e % 60)
    end,
})

-- 浏览房间：背景 + 动态房间卡（滚动列表）
local rl_list
Lobby.DefineScreen("room_list", {
    enter = function()
        skinBackground(LobbyUI.room_list.background, "UI/list_bg.png")
        rl_list = UI.Panel { width = "100%", flexDirection = "row", flexWrap = "wrap",
                             gap = 28, justifyContent = "center" }
        LobbyUI.room_list.background:addChild(UI.ScrollView {
            position = "absolute", left = 40, right = 40, top = 140, bottom = 40,
            scrollY = true, children = { rl_list },
        })
        Lobby.RefreshRoomList()
    end,
    onRoomList = function(rooms)
        rl_list:ClearChildren()
        if not rooms or #rooms == 0 then
            rl_list:AddChild(UI.Label { text = "暂无可用房间", fontSize = 22, fontColor = { 200, 210, 235, 255 } })
            return
        end
        for _, room in ipairs(rooms) do
            local card = UI.Button {
                width = 440, height = 150, backgroundColor = { 30, 38, 66, 235 }, borderRadius = 18,
                alignItems = "center", justifyContent = "center",
                onClick = function() if (room.status or 1) == 1 then Lobby.JoinRoom(room.id, room.maxPlayers) end end,
            }
            card:AddChild(UI.Label {
                text = string.format("#%d %s  %d/%d", room.id, room.name or "房间",
                    room.playerCount or 0, room.maxPlayers or 4),
                fontSize = 24, fontColor = { 255, 255, 255, 255 },
            })
            rl_list:AddChild(card)
        end
    end,
})

-- 等待房间：背景 + 玩家格 + 房主可见的开始键
local rw_grid
Lobby.DefineScreen("room_waiting", {
    enter = function()
        skinBackground(LobbyUI.room_waiting.background, "UI/room_bg.png")
        skinButton(LobbyUI.room_waiting.leave_button, { left = 40, top = 44, width = 130, height = 60 }, "离开")
        skinButton(LobbyUI.room_waiting.start_button,
            { left = "50%", marginLeft = -160, bottom = 80, width = 320, height = 64 },
            "开始游戏", { 80, 200, 120, 255 })
        rw_grid = UI.Panel { position = "absolute", left = 60, right = 60, top = 150, bottom = 170,
                             flexDirection = "row", flexWrap = "wrap", justifyContent = "center",
                             alignItems = "center", gap = 24 }
        LobbyUI.room_waiting.background:addChild(rw_grid)
    end,
    onRoomPlayers = function(players, masterId)
        rw_grid:ClearChildren()
        LobbyUI.room_waiting.start_button.visible = (masterId == nil) or (masterId == Lobby.GetMyUserId())
        for _, p in ipairs(players or {}) do
            local cell = UI.Panel { width = 200, height = 190, alignItems = "center", justifyContent = "center",
                                    backgroundColor = { 30, 38, 66, 235 }, borderRadius = 18, gap = 12 }
            cell:AddChild(UI.Panel { width = 76, height = 76, borderRadius = 38, backgroundColor = { 70, 90, 140, 255 } })
            cell:AddChild(UI.Label { text = p.nickname or ("玩家" .. tostring(p.userId)),
                                     fontSize = 16, fontColor = { 255, 255, 255, 255 } })
            rw_grid:AddChild(cell)
        end
    end,
})

-- 连服进度：背景 + 进度文案 + 进度条（两个面板叠出来，内层宽度 = 百分比）
local cn_status, cn_fill
Lobby.DefineScreen("connecting", {
    enter = function()
        skinBackground(LobbyUI.connecting.background, "UI/connecting_bg.png")
        local box = UI.Panel { position = "absolute", left = 0, right = 0, top = "44%",
                               alignItems = "center", gap = 18 }
        cn_status = UI.Label { text = "正在进入游戏", fontSize = 34, fontColor = { 255, 255, 255, 255 } }
        local barBg = UI.Panel { width = 560, height = 22, backgroundColor = { 20, 24, 44, 235 }, borderRadius = 11 }
        cn_fill = UI.Panel { width = "0%", height = "100%", backgroundColor = { 100, 200, 250, 255 }, borderRadius = 11 }
        barBg:AddChild(cn_fill)
        box:AddChild(cn_status); box:AddChild(barBg)
        LobbyUI.connecting.background:addChild(box)
    end,
    onServerProgress = function(progress, status)
        if cn_status then cn_status:SetText(status ~= "" and status or "正在进入游戏") end
        if cn_fill then cn_fill.style.width = tostring(math.floor((progress or 0) * 100)) .. "%" end
    end,
})
```

### 7. 模板 API 边界与常见陷阱

#### 7.1 模板 API 边界

项目大厅脚本固定写在 `scripts/lobby_ui.lua`，通过模板 API 修改默认大厅的界面和交互表现。

**支持的模板 API**：`LobbyUI` / `LobbyState` / `Lobby` / `Timer` / `UI`（`urhox-libs/UI`）/ `FormatInt` / `CreateTopBar` / `ParseRoomList`，以及控件代理支持的样式、自绘和动画能力。

**使用边界**：平台动作使用 `Lobby` 提供的预定义接口，状态使用 `LobbyState` 读取，配置和状态按只读约定使用。不要依赖未在本节列出的引擎内部对象或未文档化行为；需要自定义页面、导航或本地玩法时，改用第二部分的完全自建入口。

**图片路径**：相对项目 `assets/` 解析（两条路通用），详见 [§13 资源与图片路径](#13-资源与图片路径)。

**错误处理**：脚本编译/运行/回调出错记 `log:Write(LOG_ERROR, …)`（前缀 `[lobby_ui] Lua:`，可在 `logs/` 中查到）。任一屏出错都有默认基底兜底，不会整屏黑。

#### 7.2 常见陷阱

| 陷阱 | 说明 |
|---|---|
| **背景图里画了按钮/文字/图标等 UI** 🔴 | 背景图只能是纯装饰场景（渐变/氛围/光效/自然元素）。按钮、文字、菜单、进度条、图标、房间卡等**一律用控件实现**，绝不能烧进背景图——否则点不动、不随分辨率/数据变化、无法本地化、还会和真实功能按钮错位。详见[总览](#总览两条路怎么选)的🔴铁律 |
| **控件名写错直接报错** | `LobbyUI.main.xxx` 的 `xxx` 不在该屏控件表里会立即 error，不是返回 nil。对照 [§4.1](#41-五个界面与控件代理) |
| **图片全部加载失败** | 路径相对 `assets/` 解析，要写"`assets/` 下的子路径"。文件在 `assets/UI/bg.png` 就写 `"UI/bg.png"`、在 `assets/Foo/x.png` 就写 `"Foo/x.png"`。最常见的错是路径与图片实际所在目录对不上（示例里的 `UI/...` 只是占位，按自己的资源目录改） |
| **功能按钮挂了新控件还露出旧内容** | 引擎功能按钮是透明占位（无可见内容），但保险起见 `:addChild` 前先 `:clearChildren()` |
| **图片背景设在 `.style` 上不生效** | 控件代理的 `.style` 只管底色（`background`）；图片背景要 `:addChild` 一个带 `backgroundImage` 的 `UI.Panel` |
| **写 `LobbyState` 报错** | 它是只读快照，只能读不能写 |
| **动态列表项点击不响应** | 列表项要用 `UI.Button` 并传 `onClick`；内部子 Panel 加 `pointerEvents = "none"` 让点击落到 Button |
| **匹配计时自己又写了一遍** | 直接读 `LobbyState.matchmaking.elapsed` 即可，引擎已逐帧累加 |
| **改完不生效** | 确认文件名和位置严格为项目 `scripts/lobby_ui.lua`，并确认该脚本已进入项目资源。模板脚本路径不能通过 `settings.json` 改名或切换 |

---

## 第二部分 · 完全自建（完整引擎）

> 在 `multiplayer.enabled: true` 的联机项目中，脱离固定的 5 屏模板框架，写一个自定义大厅 Runtime，使用入口提供的 `client` 接平台、`root` 挂 UI，用 `urhox-libs/UI` 自造任意屏、任意布局、任意流程。大厅中可以组织本地游玩和联机游戏两个分支。平台逻辑（网络 / 房间 / 匹配）依旧由引擎托管，你通过 `client` 触发，不必也不能自己重写。

### 8. 何时选它 · 入口契约

当项目启用联机，且需要的**自定义大厅**在结构 / 流程上和内置的 5 屏不同——自己的首页、自己的屏、自己的导航、自己的房间面板进出方式，或大厅中需要本地游玩和其他自定义功能——走完全自建。入口脚本获得 `client` 和 `root`，由项目自己管理页面、导航和流程。

**配置入口脚本**（项目源配置 `.project/settings.json` 的 `@runtime`）：

```json
{
  "@runtime": {
    "multiplayer": {
      "enabled": true,
      "lobby_runtime": "scripts/lobby_runtime.lua"
    }
  }
}
```

> **`lobby_runtime` 路径规则**：可带 `scripts/` 前缀或相对脚本目录、必须是 `.lua` 文件，禁止绝对路径与 `..`。

**入口契约**——脚本返回一个接收 `ctx` 的函数：

```lua
-- scripts/lobby_runtime.lua
local UI = require("urhox-libs.UI")   -- 完全自建入口按需加载 UI；模板换皮直接使用模板提供的 UI

return function(ctx)
    local client, root = ctx.client, ctx.root
    -- client : 平台接口（见 §9），匹配 / 房间 / 连服都走它
    -- root   : 引擎建好的专属大厅 UI 根，把你的界面挂到它下面

    local view = UI.Panel { width = "100%", height = "100%" }
    root:AddChild(view)
    -- ... 自己的屏、导航、房间面板进出、把交互绑到 client ...

    return {
        stop = function()
            -- 可选：主动清理你建的事件订阅 / 定时器；root 由引擎回收，不用你销毁
        end,
    }
end
```

- `ctx = { client, root }`；函数返回 `{ stop = fun()|nil }`。
- 配置缺失 / 文件缺失 / 入口脚本抛错时，引擎回退内置默认大厅，不会整屏黑。

#### 在入口中运行本地游戏

`lobby_runtime.lua` 运行在完整 Runtime 中，可以直接创建本地 Scene、Viewport、输入、HUD 和单人玩法，也可以把这些逻辑拆到项目模块中。引擎不要求必须存在 `local_game.lua`，也不规定项目本地游戏模块的通用接口。

本节说明如何在大厅中选择并运行本地玩法，不保证已发起的匹配 / 连服流程能安全切回本地。下文的“大厅控制层”指引擎内置、独立于项目脚本运行的部分，负责匹配状态、连服与切换游戏脚本；项目代码无法直接访问它，只能通过 `ctx.client` 的回调与状态缓存间接观察。`CancelMatch()` 返回或 `IsMatching() == false` 均不是大厅控制层后续连服与切脚本已终止的确认，不能据此启动本地模块；完整限制见 [匹配失败、取消与本地回落](network-game-guide.md#117-匹配失败取消与本地回落)。

`Example_Custom_LobbyRuntime.lua` 为了让入口示例保持简洁，选择了模块拆分方式，并由该示例明确约定 `scripts/local_game.lua` 必须返回 `stop`：

```lua
-- scripts/local_game.lua
return function(gameCtx)
    -- 创建本地 Scene、Viewport、输入、HUD 和单人玩法。
    -- gameCtx.onExit() 返回自定义大厅。
    -- gameCtx.onOnline() 返回入口的联机分支。
    return {
        stop = function()
            -- 注销 Update / 其他事件，清理本地 Scene、Viewport 和控件。
        end,
    }
end
```

这是该示例自己的代码组织约定，不是 `lobby_runtime` 的标准 API。项目可以直接在 `lobby_runtime.lua` 中实现同样的本地玩法，也可以采用其他模块边界；如果复用这份示例入口，则应遵守其 `stop` 清理契约。按本示例的产品设计，“本地游玩”在入口 Runtime 中直接执行本地逻辑，不通过 `CreateRoom` + `StartGame` 进入房间；这不是引擎对项目玩法的限制。项目可以另外提供只有一名玩家的联机玩法，但应把它作为“单人联机玩法”处理。引擎的 `GameLobby` 模板仍只提供通用入口和联机接口，不放入项目特定玩法。

#### 本地游玩的平台能力

本地分支与大厅使用同一个客户端 Runtime；进入本地玩法本身不会停用 `sdk` 或 `clientCloud`，使用这些能力也不要求先连入多人游戏服。**“本地”描述玩法运行位置，不代表平台服务可以离线使用**：仍须满足各项能力的登录、项目配置、宿主支持和网络条件。

| 能力 | 在本地分支中的可用性 | 使用条件与结果判断 |
|---|---|---|
| 激励视频广告 | 可以调用 `sdk:ShowRewardVideoAd` | 需项目已配置广告、当前宿主支持；同时处理受理返回值和回调，仅 `result.success == true` 时发奖。开发环境可能播放演示视频，不代表正式广告可用；API 用法见 [广告用法](sdk.md#-激励视频广告)，广告配置与接入使用 `setup-ads` Skill |
| 插屏广告 | **当前没有游戏侧公开调用接口** | 不因进入本地分支而增加能力，不要自行假设存在插屏、Banner 或开屏 API |
| `clientCloud` 云变量 / 排行榜 | 可以访问当前登录用户的数据 | 需完成正常登录、项目身份有效且云服务可达；本地分支没有 `serverCloud`。按回调判断读写结果，见 [客户端云变量](client-cloud-score.md) |
| 成就 | 可以调用客户端成就 `sdk` API | 需当前 TapTap 登录用户、应用成就配置和宿主支持；目标为 Android、iOS、PC（Windows/macOS），WebAssembly / Intl 不在当前目标范围。解锁与进度以上报 listener 的异步结果为准；成就配置与接入使用 `setup-achievements` Skill |
| 自定义埋点（TapDB） | 可以调用 `sdk:LogEvent` | 有效环境为 Android / iOS 手机内嵌宿主；本地调试、PC、Web 返回 `false` 与 `1002`。成功回调只表示宿主本地持久化，离线由宿主后续补报，不代表已上传；见 [TapDB 埋点](sdk.md#-tapdb-埋点上报) |

通过当前 Agent 的 Skill 列表或发现机制，按名称加载上述 Skill；安装位置由所在环境决定，不要自行拼接文件路径。

以上以正常登录后进入 `lobby_runtime` 为前提。`-skip_login` / Validate 等跳过平台初始化的调试路径不保证创建真实 `clientCloud` 或具有有效 SDK 登录态，不能据此判断正式环境的能力。平台接口失败时应恢复本地玩法 UI，由项目决定后续处理。

### 9. `ctx.client` 平台接口

自定义大厅通过 `ctx.client` 使用平台能力。完整类型提示见 `urhox-libs/GameLobby/Runtime/lobby_client.d.lua`（IDE 侧生效）。

#### 9.1 同步只读（即时返回）

| 调用 | 返回 | 说明 |
|---|---|---|
| `client:GetMyUserId()` | integer | 本机玩家 ID |
| `client:GetMaxPlayers()` | integer | 房间最大人数 |
| `client:GetProjectId()` | string | 项目 ID |
| `client:IsOnline()` | boolean | 是否在线 |
| `client:IsInRoom()` | boolean | 是否在房间中（大厅控制层推送的状态缓存）|
| `client:IsMatching()` | boolean | 是否匹配中（大厅控制层推送的状态缓存；仅供 UI 展示，可能晚于异步失败 / 取消）|
| `client:GetRoomData()` | table\|nil | 当前房间共享数据（最近一次推送的缓存）|

#### 9.2 动作（发起即返回，结果走 `opts` 回调）

每个动作"发起即返回"，请求回执由 `opts` 里的内联回调接收；全局错误还可能重复广播同一次请求失败，后续流程通知也走独立订阅，处理分工见 [§9.3](#93-全局订阅cbnil-注销)。

| 方法 | `opts` 回调 | 说明 |
|---|---|---|
| `client:StartMatch(opts)` | `onStarted()` · `onError(code, message)` · `onMatchFound(serverInfo)` · `onProgress(progress, status)` | 快速匹配；`onError` 处理请求失败，受理后的异步匹配失败走 `client:OnError`。匹配成功后平台自动连服，进度 0..1 走 `onProgress` |
| `client:StartGame(opts)` | 同 `StartMatch` | 房主开始游戏（链路同 `StartMatch`）|
| `client:CreateRoom(opts)` | `onCreated(roomId)` · `onError(code, message)` · `onPlayersChanged(players, masterId)` · `onRoomDataChanged(data, masterId)` · `onKicked()` | 创建房间。进房后人员变化**持续**走 `onPlayersChanged`，房间共享数据变化走 `onRoomDataChanged`（见 [§10.1](#101-房间共享数据选关同步)）；房间非主动结束走 `onKicked` |
| `client:JoinRoom(opts)` | `opts.roomId`（**必填**）· `onJoined()` · `onError(code, message)` · `onPlayersChanged(...)` · `onRoomDataChanged(...)` · `onKicked()` | 加入指定房间 |
| `client:SetRoomData(data, opts?)` | `onSuccess()` · `onError(code, message)` | 房主设置房间共享数据（如选关），广播给同房间全员 |
| `client:LeaveRoom(opts?)` | `onLeft()` · `onError(code, message)` | 离开房间 |
| `client:CancelMatch()` | 无完成回执 | 发起取消，`IsMatching()` 缓存随后转 false；不确认大厅控制层后续连服 / 切脚本已终止，不能据此进入本地玩法 |
| `client:GetRoomList(opts)` | `onSuccess(rooms)` · `onError(code, message)` | 拉取房间列表（纯查询）|
| `client:GetUserNickname(opts)` | `opts.userIds`（**必填**）· `onSuccess(nicknames)` · `onError(code, message)` | 异步查昵称 |

#### 9.3 全局订阅（`cb=nil` 注销）

| 方法 | 回调签名 | 说明 |
|---|---|---|
| `client:OnError(cb)` | `cb(errorType:string, errorCode:integer)` | 全局错误广播，包括请求失败的重复通知，以及后续匹配 / 开局通知失败 |
| `SystemNotification.RegisterHandler(cb)` | `cb(info) -> boolean` | **推荐**。大厅 / Game 按 `info.id` 换皮，返回 `true` 接管 |
| `client:OnSystemDialog(cb)` | `cb(dialog:LobbySystemDialog)` | 旧接口兼容。未注册新版 handler 时，未接管的弹窗仍会推到这里 |

> ⚠️ **两种 `onError` 签名不同**：动作 `opts` 里的 `onError(code, message)` 给出本次请求的错误码与文案（文案可能为空）；全局 `client:OnError(errorType, errorCode)` 给出错误类型与错误码。两者可能对应同一次失败，不是互斥的两条失败路径。

平台拒绝同一次匹配 / 开局请求时，会同时调用动作的 `opts.onError(code, message)`，并向 `client:OnError` 注册的全局回调广播 `errorType == "START_GAME"` 与相同错误码；创建房间、加入房间被拒绝也会分别重复广播 `CREATE_ROOM`、`JOIN_ROOM`。推荐按以下方式分工：

- 动作的 `opts.onError` 负责本次请求失败的弹窗、重试等业务处理；全局的 `START_GAME` / `CREATE_ROOM` / `JOIN_ROOM` 只记录诊断，避免重复执行相同副作用。
- 全局 `GAME_START` 表示**后续开局通知失败**，与 `START_GAME` 的**请求失败**不同，需单独处理；匹配被受理后的失败 / 取消走全局 `MATCH_STATUS_CHANGED`，仅注册动作的 `opts.onError` 无法覆盖这些通知。
- 按本次尝试的阶段和已处理状态保证业务副作用只执行一次，不要仅按错误码跨次去重。全局回调不携带对应的请求标识，不能把每次广播都当成另一次请求失败。

完整事件、错误码与取消限制见 [匹配失败、取消与本地回落](network-game-guide.md#117-匹配失败取消与本地回落)。

`client:IsMatching()` 不是匹配流程的终态信号。它读取大厅控制层最近一次推送的 `state` 快照；匹配受理后的异步失败 / 取消可能先让大厅控制层内部状态变为非匹配，而 `ctx.client` 的本地缓存仍暂时为 `true`，直到后续状态推送才收敛。不要轮询它判断匹配完成、失败、回落或是否可以进入下一步；项目界面应由动作回调、`client:OnError` 以及显式状态机驱动。项目状态机与错误去重只控制项目自己的业务处理，不能阻止大厅控制层在迟到开局通知后继续连服和切脚本，也不能证明可以安全回落本地。

#### 9.4 数据形状（回调载荷）

| 类型 | 字段 |
|---|---|
| `LobbyPlayer` | `userId:integer` · `nickname:string` · `avatar:string` |
| `LobbyRoomInfo` | `id:integer`（房间号，`JoinRoom` 用它）· `name:string` · `status:integer`（1=等待 2=匹配 3=游戏中）· `ownerId:integer` · `playerCount:integer` · `maxPlayers:integer` · `latency:integer` |
| `LobbyNickname` | `userId:integer` · `nickname:string` |
| `LobbySystemDialog` | `kind:"error"\|"kicked"\|"dialog"` · `title?` · `message?` · `buttonText?` · `icon?` |

### 10. 生命周期 · 错误 · 系统弹窗 · 关键约定

这一节是"高效不出错"的要点，写自建大厅前先过一遍：

- **`root` 由引擎托管**：退出大厅 / 切游戏脚本时引擎**整树回收** `root`，你不用销毁它。`stop` 只用来清你自己建的东西（事件订阅、定时器）；不写 `stop` 也行，但订阅了 `Update` 等事件务必在 `stop` 里 `UnsubscribeFromEvent`，否则切场景后回调还在跑。
- **本地游戏资源清理**：无论本地逻辑直接写在 `lobby_runtime.lua`，还是拆到项目模块，都要在离开本地游玩时清理 Scene、Viewport、输入状态、HUD 和事件订阅。引擎不强制统一的本地模块接口；但复用 `Example_Custom_LobbyRuntime.lua` 时，`stop` 是该示例要求的清理回调。若项目选择单人联机房间，则应按正常房间和连服生命周期处理，不套用本地游戏的清理方式。
- **房间 / 匹配的项目标识不可自定义**：`mapName` 固定为当前项目 ID，无需传入，传入也会被忽略；项目 ID 为空时操作报错且不发送请求，不回退到 `DefaultMap`。创建房间最简使用 `client:CreateRoom{}`；`maxPlayers` 默认取运行时 `settings.json` 的 `multiplayer.max_players`（源配置为 `.project/settings.json` 的 `@runtime.multiplayer.max_players`，未配置时为 4），`mode` 默认 `"default"`，这两个创建房间参数仍可在 `opts` 中显式指定。
- **`JoinRoom` 必须给 `roomId`**：缺失 / 无效时引擎报错（错误码 `-10005`）。房号是否存在引擎**不替你预查**——示例直接 `JoinRoom`，大厅回 `onError`（房间不存在为 `3`）。`GetRoomList` 只用来浏览列表，不要拿它当「房间在不在」的闸。
- **房主判定**：房主由 `onPlayersChanged(players, masterId)` 给出（来自房间 teamStatus），与 `client:GetMyUserId()` 比较即知本人是否房主。`onPlayersChanged` 首次到达前你还不知道房主，这段空窗怎么处理由你定（示例先把本人当房主占位，仅为示例的选择，非引擎语义）。
- **连服进度**：`onMatchFound` 后平台自动连服，进度走 `onProgress(progress, status)`（`progress` 0..1），连服完成后引擎切到游戏脚本。中间进度的下发节奏由平台决定、不保证连续——想要平滑进度条得自己补间（示例用了"平滑爬升 + 真实进度取较大值"的技巧，见 [§11](#11-示例走读)）。
- **系统弹窗**：被踢 / 版本过低等由引擎在顶层渲染，你**什么都不做也有默认弹窗**。换外观请用 `SystemNotification.RegisterHandler`，按 `info.id` 决定怎么画，返回 `true` 即接管。旧项目仍可用 `client:OnSystemDialog`；接管后务必自己保证用户能关闭。
- **错误处理只执行一次**：动作的 `opts.onError` 与全局 `client:OnError` 可能重复通知同一次请求失败；按 [§9.3](#93-全局订阅cbnil-注销) 分工处理请求拒绝与后续通知，避免重复重试、弹窗或回落。
- **匹配失败不会自动启动本地玩法**：项目负责失败提示与既有的重试 / 返回大厅流程；取消或离房并没有确认大厅控制层已可靠终止后续连服 / 切脚本，不能据此立即启动本地玩法。需要安全回落时必须先具备并验证可靠终止机制，见 [匹配失败与回落](network-game-guide.md#117-匹配失败取消与本地回落)。
- **UI 全在你手里**：没有固定 5 屏，屏与导航自己管，全用 `urhox-libs/UI` 控件搭。推荐响应式范式（单一 `state` + 全量重渲，见示例），但不强制——你也可以命令式增删控件。
- **响应式重渲三个坑（若采用示例的范式）**：
  - 全量重渲时先把旧子树 `Destroy()` 再重建，释放 Yoga 布局节点，别只是 detach。
  - `TextField` 的 `onChange` 只静默写缓存、**不要触发重渲**，否则每次输入都重建会丢输入焦点。
  - 想把某个 `state` 字段**清成 `nil`**：Lua 表字面量会丢弃 `nil` 键（`{x=nil}` 是空表），用一个 `NIL = {}` 哨兵显式表达"置空"，在 `setState` 里把 `v == NIL` 还原成 `nil`。

#### 10.1 房间共享数据（选关同步）

房主在房间里选关、选模式这类"全员都要看到同一份"的数据，用 `client:SetRoomData` 写、`onRoomDataChanged` 收。平台负责保存和广播：同房间所有人（包括房主自己、之后才加入的人）都会收到当前值。

```lua
local myId = client:GetMyUserId()
-- 每次进入新房间重新建立这份状态；离房/stop 后应让旧回调失效。
local room = { rev = 0, sentRev = 0 }

local function finishPublish()
    local pending = room.pending
    if pending and pending.accepted and pending.observed then
        room.pending = nil
    end
    render()
end

local function onRoomData(data, masterId)
    room.masterId = masterId
    if data == nil then
        room.selection, room.rev = nil, 0
    elseif type(data.rev) == "number" and data.rev >= room.rev then
        room.selection, room.rev = data.selection, data.rev
        if room.pending and room.pending.rev == data.rev then
            room.pending.observed = true
        end
    end
    finishPublish()
end

client:JoinRoom {
    roomId = inputRoomId,
    onPlayersChanged = function(players, masterId) room.masterId = masterId; render() end,
    onRoomDataChanged = onRoomData,
}

-- 房主串行发布；等待期间禁用改选与开始按钮。
local function selectLevel(levelId, displayName)
    if room.masterId ~= myId or room.pending then return end
    local rev = math.max(room.rev, room.sentRev) + 1
    local pending = { rev = rev }
    room.sentRev, room.pending = rev, pending
    client:SetRoomData({ rev = rev, selection = { levelId = levelId, name = displayName } }, {
        onSuccess = function()
            if room.pending ~= pending then return end
            pending.accepted = true
            finishPublish()
        end,
        onError = function(code, message)
            if room.pending ~= pending then return end
            room.pending = nil
            showToast("选关同步失败：" .. tostring(message or code))
            render()
        end,
    })
end

local function startGame()
    if room.masterId ~= myId or room.pending or room.selection == nil then return end
    client:StartGame { onError = function(code, message) showToast(tostring(message or code)) end }
end
```

要点与易错点：

- **只有房主能写**。非房主或房主身份尚未确认时调用返回 `onError(-10008)`；不在房间里调用返回 `-10007`；数据不是表、无法 JSON 编码、平台房间信息尚未就绪或超限返回 `-10009`。
- **整体替换**：每次 `SetRoomData` 都是完整新值，不做字段级合并。需要保留旧字段就自己带上。
- **大小上限**：编码后和平台内部字段合计不超过 65535 字节。只放选关标识、名称、模式等小数据，不要放存档或场景。
- **`onSuccess` 只表示大厅已接受**。新值经 `onRoomDataChanged` 推送给全员；推送可能早于或晚于回执，房主自己也会收到；UI 以 `onRoomDataChanged` 为准刷新，不要在 `onSuccess` 里自己改显示。
- **平台不提供修订号**。要防迟到旧数据覆盖新数据，在 `data` 里自带 `rev` 并在接收端比较（如上例）。
- **房间号按数值比较**：JSON 回调中的房号可能是浮点数，同一个房间的 `tostring(99.0)` 与输入整数的 `tostring(99)` 不同。若在共享数据中携带字符串 `roomId`，发送前用 `tostring(math.tointeger(roomId))` 统一格式，接收后用 `math.tointeger(tonumber(data.roomId)) == currentRoomId` 判断归属，避免把当前房间的快照误判为其他房间。
- **开局前等回执**：房主改选后立刻开始，可能出现"界面显示 A、实际进 B"。在 `SetRoomData` 成功回执和对应修订的共享快照都到达前禁用开始按钮。
- **只在大厅阶段可用**：进入游戏后不能再读取房间共享数据。游戏服务器需要知道选了哪关时，由游戏脚本自己传递（例如房主客户端连服后上报，服务器校验后广播）。
- **`data` 为 `nil` 表示房间还没有设置过共享数据**。加入房间后第一次推送可能就是 `nil`，界面要能显示"等待房主选择"。
- **房主变更后数据保留**。新房主是否沿用旧选择由你决定，可以在 `onPlayersChanged` 发现 `masterId` 变化后重新 `SetRoomData`。
- **离开房间后缓存自动清空**，进入新房间不会带出上一个房间的数据。

### 11. 示例走读

两份入口实现可参考，别只盯一份：

- **`urhox-libs/GameLobby/Runtime/Example/Example_Custom_LobbyRuntime.lua`** —— 从零完全自建的大厅示例，界面全用 `urhox-libs/UI`。**响应式状态驱动**：单一 `state` + `setState(patch)` + `render(state)` 全量重渲，视图永远是 `state` 的纯投影（零命令式 `SetText`/`SetVisible`）。流程：大厅 → 项目的本地游戏模块，或联机(加入/新建) → 加入(输房号后直接 `JoinRoom`) → 房间(玩家格/房主开始) → 连服进度。顶部资源/文案集中成配置块（图片留 `nil` 走纯色兜底，不出图也能跑），复制后改这里即可。把本地玩法拆到模块并约定 `stop` 是这份示例的设计，不是引擎对 `lobby_runtime` 的标准要求；项目也可以直接在自己的 `lobby_runtime.lua` 中实现本地玩法。按本示例的产品设计，“本地游玩”直接运行本地逻辑；引擎仍允许项目另外设计单人联机玩法。系统弹窗 / 全局错误经 `SystemNotification.RegisterHandler` / `OnError` 投影进 `state`，动画与 toast 计时用一个 `Update` 订阅驱动、在 `stop` 里注销。把它当成“自定义大厅怎样组织、各回调怎么接、怎么不出错”的参考实现通读一遍。
- **`urhox-libs/GameLobby/Runtime/Template/LobbyRuntimeUI.lua`** —— 引擎默认入口本身就是一份最简 `return function(ctx)` 实现（拿 `client` 转交模板框架）。想看入口契约最小怎么落地，读它。

---

## 第三部分 · 两条路通用

> 不管走哪条联机入口实现路径，界面都用 `urhox-libs/UI` 搭。这部分讲两条路共用的东西：UI 控件库、资源路径。

### 12. 用 `urhox-libs/UI` 搭界面

`urhox-libs/UI` 是引擎的声明式控件库，**两条路的界面都用它搭**——模板换皮把控件 `:addChild` 到引擎给的控件代理下，完全自建把控件挂到 `ctx.root` 下。控件目录、样式属性、布局（Flex/Yoga）、自绘与动画等完整用法见 **`engine-docs/recipes/ui.md`**；这里只列大厅常用的：

```lua
local UI = require("urhox-libs.UI")    -- 完全自建入口按需加载 UI；模板换皮直接使用模板提供的 UI

-- 容器 / 文本 / 按钮 / 输入框 / 滚动
local panel = UI.Panel {
    width = "100%", height = "100%",
    flexDirection = "column", alignItems = "center", justifyContent = "center", gap = 20,
    backgroundColor = { 16, 20, 38, 255 },          -- {r,g,b,a} 0~255，或 "#RRGGBB"
    backgroundImage = "ui/bg.png", backgroundFit = "cover",   -- 图片背景：fill / contain / cover
    children = {                                     -- children 声明式挂子控件（也可用 :AddChild）
        UI.Label  { text = "标题", fontSize = 40, fontColor = { 255, 255, 255, 255 } },
        UI.Button { minWidth = 280, height = 76, borderRadius = 38, backgroundColor = { 80, 140, 240, 255 },
                    alignItems = "center", justifyContent = "center",
                    onClick = function() --[[ 绑到 Lobby.* 或 ctx.client ]] end,
                    children = { UI.Label { text = "按钮", fontSize = 26 } } },
        UI.TextField { width = 360, height = 64, placeholder = "输入房间号",
                       onChange = function(self, value) --[[ 静默缓存 ]] end },
        UI.ScrollView { width = "100%", flexGrow = 1, scrollY = true, children = { --[[ 列表项 ]] } },
    },
}
```

常用控件：`UI.Panel` / `UI.Label` / `UI.Button` / `UI.TextField` / `UI.ScrollView`（还有 `Avatar` / `ProgressBar` / `Modal` / `Tabs` 等几十种，见 `ui.md`）。常用做法：

- **布局**：Flex 属性 `flexDirection` / `alignItems` / `justifyContent` / `gap` / `flexGrow` / `flexWrap`，尺寸支持像素或 `"50%"`、`position="absolute"` + `left/top/right/bottom` 定位。
- **图片背景**：`backgroundImage` + `backgroundFit`（`"fill"`/`"contain"`/`"cover"`），缺图只剩 `backgroundColor`，记得给底色兜底。
- **动态更新**：建好的控件可 `:AddChild` / `:ClearChildren` / `:Destroy` / `:SetText`；重建一段子树时先清空再填。
- **自绘 / 动画等进阶定制**：用 `urhox-libs/UI` 自身提供的能力（控件、样式、过渡、自绘钩子），详见 `ui.md`。本手册不再单列绘制库。

> 类型形状（房间 / 玩家 / 昵称 / 系统弹窗）见完全自建的 [§9.4](#94-数据形状回调载荷)；模板换皮的回调数据见 [§4.4](#44-数据回调房间列表--玩家--匹配--连服进度)。

### 13. 资源与图片路径

图片 / 资源路径相对项目 `assets/` 解析（`assets/` 是资源根目录），故 `"UI/bg.png"` 实际找 `assets/UI/bg.png`。**两条路通用**：无论模板换皮还是完全自建，控件的 `backgroundImage` 都按此解析。路径解析与越界防护由引擎资源系统（ResourceCache）统一兜底——写正斜杠相对路径即可。

缺图时 `backgroundImage` 不显示——记得叠一层 `backgroundColor` 兜底（示例把图片路径留 `nil` 时就纯色打底，不出图也能跑）。

---

**相关**：`engine-docs/recipes/ui.md`（urhox-libs/UI 控件体系）· `engine-docs/recipes/network-game-guide.md`（联网流程）
