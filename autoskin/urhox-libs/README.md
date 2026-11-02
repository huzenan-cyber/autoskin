# UrhoX Lua 库 (urhox-libs)

UrhoX 游戏开发的通用 Lua 库集合。

## 📚 库清单

> 本清单**不完整**（21 个顶层目录里收录了 9 个）。未收录：`Engine/` `FakeAd/` `GameLobby/`
> `Lobby/` `Paint/` `Plugin/` `Profiler/` `Rendering/` `Shop/` `Sprite/` `Testing/` `Video/`
> —— 这些请直接看目录内的 `README.md`/`AGENTS.md` 或模块头部注释（`---@` 标注是最新的真源）。

### 🎮 UI/GameHUD - 虚拟摇杆与游戏 HUD（跨平台必备）

移动端和跨平台游戏的核心控制库，基于 NanoVG 渲染。

| 模块 | 功能 |
|------|------|
| **GameHUD.lua** | 高层 API：一键创建基础 HUD / 射击 HUD |
| **VirtualControls.lua** | 底层库：虚拟摇杆、虚拟按钮、技能轮盘、DPI 自适应 |

```lua
require "urhox-libs/UI/GameHUD"

function Start()
    GameHUD.Initialize()
    GameHUD.SetControls(character.controls)
    
    -- 基础 HUD（平台/冒险游戏）
    GameHUD.CreateBasicHUD()
    
    -- 射击 HUD（TPS/FPS 游戏）
    GameHUD.CreateShooterHUD({
        onShoot = function() stateMachine:SetTrigger("shoot") end,
        onReload = function() stateMachine:SetTrigger("reload") end,
    })
end
```

### 🎨 UI/ - UI 组件库

基于 Yoga 布局引擎和 NanoVG 渲染的完整 UI 解决方案。

| 子目录 | 功能 |
|--------|------|
| **Core/** | 基础框架：Widget、Theme、Style、Input、Gesture 等 |
| **Widgets/** | 40+ 预制组件：Button、Modal、ScrollView、Tabs、Table 等 |
| **Components/** | 游戏专用组件：SkillTree、ItemSlot、ChatWindow、VirtualList 等 |
| **Examples/** | 使用示例 |

详细文档见 [UI/README.md](UI/README.md)

### 🎥 Camera/ - 相机控制

| 模块 | 功能 |
|------|------|
| **ThirdPersonCamera.lua** | 第三人称相机控制（支持碰撞检测） |

### 🌐 Platform/ - 跨平台处理

| 模块 | 功能 |
|------|------|
| **PlatformUtils.lua** | 平台检测和通用工具 |
| **InputManager.lua** | 统一输入初始化（自动平台检测） |
| **MouseLockManager.lua** | 鼠标模式管理（Web 兼容） |

### 🎮 Input/ - 输入处理

| 模块 | 功能 |
|------|------|
| **TouchController.lua** | 双指缩放、相机距离、加速度计（体感）读取 |
| **TouchCamera.lua** | 触摸相机控制（3D） |

### 🎭 Animation/ - 动画资源

| 子目录 | 功能 |
|--------|------|
| **FSM/** | 预制状态机和混合空间配置文件 |

### ⚛️ Physics2D/ - 2D 物理工具

| 模块 | 功能 |
|------|------|
| **TilemapPhysics.lua** | TMX 瓦片地图碰撞生成 |
| **PathFollower.lua** | 路径跟随组件 |

### ✨ Effects/ - 特效工具

| 模块 | 功能 |
|------|------|
| **Effects.lua** | 粒子特效和音效辅助 |

### 🔷 Geometry/ - 几何体生成（⚠️ 已弃用）

| 模块 | 功能 |
|------|------|
| **Primitives.lua** | ⚠️ **已弃用**，改用 C++ 内置的 three.js 兼容几何体 API（`engine-docs/recipes/procedural-geometry.md`）。迁移说明见 [Geometry/Primitives.lua](Geometry/Primitives.lua) 头部注释（唯一真源） |

### 🌐 Network/ - 网络工具

| 模块 | 功能 |
|------|------|
| **CommandLineParser.lua** | 命令行参数解析 |
| **NetworkUtils.lua** | 网络辅助函数（最小封装，不改引擎原生 API 语义） |
| **PlayerSessions.lua** | 玩家会话生命周期编排（服务端单表 + 客户端等权威快照）；详见 [Network/README.md](Network/README.md) |

---

## 🚀 快速开始

### 引用规则

点号与斜杠**都可用，且拿到的是同一份模块表**：引擎的 require 不走 `package.loaded`，而是在
`LuaScript.cpp` 的 `ResolveModulePath()` 里先把 `.` 换成 `/`，再用解析出的**物理文件**做缓存键
（`module_identity_test.lua` 锁定了这条性质）。

```lua
-- 库内部统一用斜杠
require "urhox-libs/UI/GameHUD"
require "urhox-libs/UI/init"

-- 游戏代码按 ai-dev-kit/AGENTS.md 的约定用点号；与上面等价
require "urhox-libs.Platform.PlatformUtils"
```

> ⚠️ 唯一例外是**脱离引擎的独立 Lua 5.4 harness**（自己配 `package.path` 跑纯 Lua 单测）：
> 原版 `require` 按模块名字符串缓存，混用两种写法会把同一文件加载两份，带模块级单例的模块
> （如 `UI/Widgets/Toast.lua` 的 `globalInstance`）会静默分裂。这类 harness 内请只用一种写法。

---

## 🎯 设计原则

1. **模块化** - 每个模块独立可用，最小化依赖
2. **零侵入** - 不污染全局命名空间，使用 require 返回
3. **跨平台** - 自动检测和适配平台

---

## ✅ 测试

使用 `urhox-libs/Testing/luaunit.lua` 测试框架编写单元测试。

详见 [Testing/Tests/README.md](Testing/Tests/README.md)

---

**版本**: v2.0  
**最后更新**: 2026-01-18
