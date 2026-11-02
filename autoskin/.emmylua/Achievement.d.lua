---@meta

---@alias AchievementOperation "unlock"|"increment"
---@alias AchievementType "normal"|"platinum"

---@class AchievementResult 成就写入成功结果
---@field operation AchievementOperation 本次完成的操作
---@field achievementId string 普通成就 achievementId；白金成就透传宿主值，可能为空字符串
---@field achievementName string 成就展示名称
---@field achievementType AchievementType 成就类型
---@field currentStep integer 当前累计步数；unlock 固定为 0，increment 为当前累计进度

---@class AchievementError 成就写入失败信息
---@field achievementId string 失败请求对应的普通成就 achievementId
---@field message string 错误描述

---@class AchievementCallbacks 成就异步回调
---@field onSuccess? fun(result: AchievementResult)
---@field onFailure? fun(code: integer, error: AchievementError)

---@class SDK 客户端 SDK 全局对象
local SDK = {}

--- 控制宿主原生成就解锁提示。
---@param enabled boolean
function SDK:SetAchievementToastEnabled(enabled) end

--- 打开当前登录用户的原生成就页面。
function SDK:ShowAchievements() end

--- 解锁一个单步普通成就。
---@param achievementId string 长度 1..40，仅允许字母、数字、- 和 _
function SDK:UnlockAchievement(achievementId) end

--- 增加普通进度成就的步数。
---@param achievementId string 长度 1..40，仅允许字母、数字、- 和 _
---@param steps integer 本次增加步数，范围 1..INT_MAX（客户端 Native 接口使用 int）
function SDK:IncrementAchievement(achievementId, steps) end

--- 注册当前 Lua 状态的成就 listener；再次注册会替换已有 listener。
---@param listener AchievementCallbacks
function SDK:RegisterAchievementListener(listener) end

--- 移除当前成就 listener。
function SDK:UnregisterAchievementListener() end

---@class RewardVideoAdResult 激励视频广告结果
---@field success boolean 广告是否完整播放
---@field msg string 结果消息
---@field extra string 广告 SDK 返回的扩展信息 JSON，未返回时为空字符串

---@class NativeExitMenuRect 宿主退出胶囊位置，归一化坐标 (0~1)，左上角为原点
---@field left number
---@field top number
---@field right number
---@field bottom number

--- 播放激励视频广告。返回 true 只表示请求已受理，是否发奖以回调的 result.success 为准。
---@param callback fun(result: RewardVideoAdResult)
---@return boolean
function SDK:ShowRewardVideoAd(callback) end

--- 短震动；type 省略时为 "medium"。不支持的平台返回 false。
---@param type? "light"|"medium"|"heavy"
---@return boolean
function SDK:VibrateShort(type) end

--- 长震动。不支持的平台返回 false。
---@return boolean
function SDK:VibrateLong() end

--- 宿主退出胶囊的位置；没有胶囊时返回 nil。
---@return NativeExitMenuRect|nil
function SDK:GetNativeExitMenuRect() end

--- 上报 TapDB 埋点，只在手机内嵌宿主有效。返回 true 只表示已转给宿主，结果以回调为准。
---@param name string 事件名，非空 UTF-8 字符串
---@param properties? table<string, string|number|boolean> 可选属性，值只能是字符串、有限数字或布尔
---@param callback? fun(code: integer, message: string) 最多触发一次；0 表示本地持久化成功
---@return boolean
---@overload fun(self: SDK, name: string, callback: fun(code: integer, message: string)): boolean
function SDK:LogEvent(name, properties, callback) end

---@type SDK
sdk = {}
