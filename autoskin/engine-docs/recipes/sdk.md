# SDK 接口使用指南

全局对象 `sdk` 由运行时注册，类型声明见 `.emmylua/Achievement.d.lua`（类名 `SDK`）。

## 📢 激励视频广告

### API

```lua
sdk:ShowRewardVideoAd(callback) -> boolean
```

**回调参数 `result`：**
- `success` (boolean): 广告播放是否成功
- `msg` (string): 结果消息
- `extra` (string): 广告 SDK 返回的扩展信息 JSON，未返回时为空字符串

**返回值：**
- `true`：本次广告展示请求已被受理，最终结果以回调的 `result.success` 为准
- `false`：请求未被受理，例如命中 3 秒防抖、冷却未结束、已有广告请求进行中、
  宿主/JNI/SDK 不可用或缺少广告位配置

返回值不代表广告是否完整观看。返回 `false` 时，失败回调可能在当前调用栈内同步触发，
也可能完全不触发；调用方必须同时处理返回值和回调，并用一次性完成状态避免重复恢复 UI
或重复发奖。

### 示例

```lua
local function watchAdForReward()
    local completed = false
    local callbackFired = false

    local function finish(result)
        if completed then
            return
        end
        completed = true

        if result and result.success then
            playerCoins = playerCoins + 100
            showMessage("获得 100 金币！")
        else
            showMessage("广告播放失败: " ..
                tostring(result and result.msg or "广告暂不可用"))
        end
    end

    local accepted = sdk:ShowRewardVideoAd(function(result)
        callbackFired = true
        finish(result)
    end)

    if accepted == false and not callbackFired then
        finish({ success = false, msg = "广告暂不可用，请稍后重试" })
    end
end
```

### 回调 `result.msg` 取值说明

| msg | success | 含义 |
|-----|---------|------|
| `"embed success"` | `true` | 广告完整观看，可发放奖励 |
| `"embed manual close"` | `false` | 用户在广告播放完成前**主动关闭**，不应发放奖励 |
| `"unsupported platform"` | `false` | 非嵌入式环境或平台不支持广告 |
| 其他字符串 | `false` | TapSDK 内部错误，值为错误描述 |

> **`embed manual close`**：仅出现在 iOS Embed 模式下。表示广告 `onClose` 回调触发时 `finished = false`，即用户未完整观看即手动关闭。此时**不应给予奖励**，可提示用户"需完整观看广告才能获得奖励"。

### 注意事项
- 只有在 `result.success` 为 `true` 时才给予玩家奖励
- 遵循平台广告约束：
  - 用户体验优先，禁止生成用户在无预期下需要强制观看的广告
  - 尽可能贴合游戏原本的设计，较为自然地接入广告
  - 鼓励使用激励形式，用户观看广告后可以获得一些奖励

---

## 📳 设备震动

在移动端宿主环境中运行时，可以通过 `sdk` 触发短震动或长震动。非支持平台会静默返回 `false`，不会抛错。

### API

```lua
sdk:VibrateShort(type) -> boolean
sdk:VibrateLong() -> boolean
```

`VibrateShort` 的 `type` 可省略，默认 `"medium"`：

| type | 说明 |
|------|------|
| `"light"` | 轻震 |
| `"medium"` | 中震 |
| `"heavy"` | 重震 |

> Web/WASM 当前会忽略 `type`，三种取值均使用相同的震动时长。

### 示例

```lua
sdk:VibrateShort()
sdk:VibrateShort("light")
sdk:VibrateLong()
```

### 返回值

- `true`：当前平台/宿主已接受震动请求
- `false`：参数非法、平台不支持、宿主未提供震动能力，或浏览器拒绝震动

### 注意事项

- `sdk:VibrateShort("bad")`、`sdk:VibrateShort(1)` 会返回 `false`
- Web/WASM 使用浏览器 `navigator.vibrate`，支持情况由浏览器决定
- Windows/macOS 等桌面环境默认返回 `false`

---

## 🚪 宿主退出按钮位置

在 TapTap 宿主环境中运行时，平台会在屏幕上显示一个退出胶囊。游戏可以通过此接口获取胶囊位置，避免自身 UI 与之重叠（`urhox-libs/UI` 的 `SafeAreaView` 已自动避让，直接用即可）。

### API

```lua
sdk:GetNativeExitMenuRect() -> table | nil
```

**返回值：**
- 有胶囊：`table { left, top, right, bottom }` — 归一化坐标 (0~1)，左上角为原点
- 无胶囊：`nil`

| 字段 | 类型 | 说明 |
|------|------|------|
| `left` | number | 矩形左边缘 x (0~1) |
| `top` | number | 矩形上边缘 y (0~1) |
| `right` | number | 矩形右边缘 x (0~1) |
| `bottom` | number | 矩形下边缘 y (0~1) |

### 示例

```lua
local rect = sdk:GetNativeExitMenuRect()
if rect then
    -- rect ≈ {left=0.92, top=0.01, right=0.99, bottom=0.05}
    -- 避免在该区域放置游戏 UI
end
```

### 注意事项
- 坐标为 **归一化值 (0~1)**，与设备分辨率无关
- 调用方应统一按"返回 nil = 没有胶囊"处理，不需要做平台分支
- 建议在 `Start()` 中调用一次并缓存结果，胶囊位置在运行期间不会变化

---

## 📊 TapDB 埋点上报

在 TapTap **手机内嵌宿主**环境中，可以通过 `sdk` 上报 TapDB 埋点事件。初始化、用户身份与公共属性由宿主容器维护，游戏侧只需调用上报接口。

### API

```lua
sdk:LogEvent(name [, properties] [, callback]) -> boolean
```

**参数：**

| 参数 | 类型 | 说明 |
|------|------|------|
| `name` | string | 事件名，非空 UTF-8 字符串 |
| `properties` | table | 可选属性；省略或 `nil` 表示无属性，`{}` 表示显式传入空对象 |
| `callback` | function | 可选，形如 `callback(code, message)` |

**properties 取值限制：**

- key 必须是 UTF-8 字符串
- value 支持：字符串（UTF-8）、有限数字（整数按 64 位整数序列化）、布尔
- 嵌套 table、函数等类型会被拒绝，返回 `false` + 错误码 `1003`

**返回值：**

- `true`：上报请求已被转给宿主，最终结果以回调为准
- `false`：请求未被受理（参数非法、非内嵌环境、SDK 不可用、iOS 宿主桥缺失）；此时回调**在当前调用栈内同步触发**
- Android 上宿主 `TapDBDataAnalysisManager` 要到 UI 线程才能确认。引擎对象已创建时先返回 `true`，若随后发现桥不可用，会异步回调 `1001`

### 回调

```lua
local accepted = sdk:LogEvent("player_level_up", {
    level = 10,
    durationSeconds = 42.5,
    isVip = true,
}, function(code, message)
    if code == 0 then
        -- 本地持久化成功（不代表已上传到 TapDB 服务器）
    else
        print("埋点失败: " .. code .. " " .. tostring(message))
    end
end)
```

回调保证**最多触发一次**，且在引擎主线程执行。

### 错误码

| code | 含义 | 常见场景 |
|------|------|---------|
| `0` | 成功 | 事件已本地持久化，由宿主 SDK 择机上报（离线会积压补报） |
| `1001` | TapDB 上下文不可用 | TapOpenSDK 未初始化、宿主未实现 TapDB 桥 |
| `1002` | TapDB 已禁用 | 非内嵌环境（本地调试、PC、Web）、平台不支持 |
| `1003` | 参数校验失败 | 空事件名、非法 UTF-8、properties 类型不符 |
| `1004` | 持久化失败 | 宿主写入失败、回调超时（30 秒未回调）、SDK 销毁或脚本重载时未完成的回调被结算 |

### 示例

```lua
-- 通用事件（不带属性、不带回调）
sdk:LogEvent("open_shop")

-- 带属性
sdk:LogEvent("battle_end", { result = "win", duration = 125, isFull = false })

-- 带回调
sdk:LogEvent("player_level_up", { level = 10 }, function(code, message)
    if code ~= 0 then
        print("埋点失败: " .. code .. " " .. tostring(message))
    end
end)
```

### 注意事项

- 埋点只在**手机内嵌宿主**（Android/iOS embed）环境有效；本地调试、PC、Web 会返回 `false` + `1002`，开发期不要依赖回调成功
- 回调成功（`code == 0`）只代表**本地持久化成功**，不代表已上报到 TapDB 服务器
- 返回 `false` 时回调通常在当前调用栈内同步触发（若传了回调）；返回 `true` 时回调异步触发。SDK 正在销毁/结算时，重试请求仍返回 `false`，但回调改到下一帧，避免析构栈递归
- 两者都不会重复触发同一个回调
- 引擎不做去重；同一事件是否需要上报多次由业务自行控制
- 宿主失败不会占用 `1001`–`1003`。非 0 宿主 errno 一律映射为 `1004`，原始码写在 `message`（如 `host errno=1002: ...`）
- SDK 销毁 / 脚本重载导致的 `1004`（`TapDB context was destroyed`）不要重试

