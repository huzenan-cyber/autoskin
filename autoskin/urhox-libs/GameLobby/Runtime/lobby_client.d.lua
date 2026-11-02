---@meta
-- EmmyLua 类型定义：自定义大厅制作人接口（LobbyClient）。
-- 仅在 IDE 侧生效，不在运行时加载。
--
-- 入口约定（完全自建路径）：项目自定义 Runtime 入口脚本（由 settings.json 的
-- multiplayer.lobby_runtime 指定）返回一个函数，引擎引导层注入 ctx 调用它：
--   return function(ctx)
--       local client = ctx.client   -- LobbyClient，本文件全部接口都在它上面
--       local root   = ctx.root     -- 引擎托管的大厅 UI 根：UI 挂这里，退出 / 切游戏自动整树回收
--       return { stop = function() end }   -- stop 可选，主动清理
--   end

-- ============================================================================
-- 数据形状（回调载荷）
-- ============================================================================

---@class LobbyPlayer
---@field userId integer
---@field nickname string
---@field avatar string

---@class LobbyRoomInfo
---@field id integer          房间号（JoinRoom 用它）
---@field name string         房间名
---@field status integer      1=等待中 2=匹配中 3=游戏中
---@field ownerId integer     房主 id
---@field playerCount integer 当前人数
---@field maxPlayers integer  最大人数
---@field latency integer     延迟(ms)

---@class LobbyNickname
---@field userId integer
---@field nickname string

---@class LobbySystemDialog
---@field kind "error"|"kicked"|"dialog" 平台弹窗类型
---@field title string|nil
---@field message string|nil
---@field buttonText string|nil
---@field icon string|nil

-- ============================================================================
-- 动作 opts（内联回调：一个动作会引发的后续事件，回调都写在这里）
-- ============================================================================

---@class LobbyMatchOpts
---@field onStarted fun()|nil                          已开始匹配（回执）
---@field onError fun(code:integer, message:string|nil)|nil                本次请求失败（未受理）；受理后的匹配失败 / 取消走 client:OnError（"MATCH_STATUS_CHANGED"）
---@field onMatchFound fun(serverInfo:table)|nil       匹配成功 → 切「连接中」界面
---@field onProgress fun(progress:number, status:string)|nil  之后平台自动连服的进度，progress 0..1

---@class LobbyStartGameOpts
---@field onStarted fun()|nil                          已开始（回执）
---@field onError fun(code:integer, message:string|nil)|nil
---@field onMatchFound fun(serverInfo:table)|nil
---@field onProgress fun(progress:number, status:string)|nil

---@class LobbyCreateRoomOpts
---@field onCreated fun(roomId:integer)|nil            房间已创建（回执）
---@field onError fun(code:integer, message:string|nil)|nil
---@field onPlayersChanged fun(players:LobbyPlayer[], masterId:integer)|nil 进房后人员变化（持续）
---@field onRoomDataChanged fun(data:table|nil, masterId:integer)|nil 房间共享数据变化（持续；含晚加入时的当前值，nil=未设置）
---@field onKicked fun()|nil                           房间非主动结束（被踢 / 解散）

---@class LobbyJoinRoomOpts
---@field roomId integer                               要加入的房间号
---@field onJoined fun()|nil                           已加入房间（回执）
---@field onError fun(code:integer, message:string|nil)|nil
---@field onPlayersChanged fun(players:LobbyPlayer[], masterId:integer)|nil
---@field onRoomDataChanged fun(data:table|nil, masterId:integer)|nil
---@field onKicked fun()|nil

---@class LobbySetRoomDataOpts
---@field onSuccess fun()|nil                          大厅已接受修改（回执）；共享快照可能早于或晚于回执到达，开局须等两者确认
---@field onError fun(code:integer, message:string|nil)|nil  -10007 不在房间 / -10008 非房主或身份未确认 / -10009 数据无效、平台字段未就绪或超限

---@class LobbyLeaveRoomOpts
---@field onLeft fun()|nil                             已离开房间（回执）
---@field onError fun(code:integer, message:string|nil)|nil

---@class LobbyRoomListOpts
---@field onSuccess fun(rooms:LobbyRoomInfo[])|nil      房间列表返回（纯查询）
---@field onError fun(code:integer, message:string|nil)|nil

---@class LobbyNicknameOpts
---@field userIds integer[]                            要查的 userId 列表
---@field onSuccess fun(nicknames:LobbyNickname[])|nil  昵称返回（纯查询）
---@field onError fun(code:integer, message:string|nil)|nil

-- ============================================================================
-- LobbyClient
-- ============================================================================

---@class LobbyClient
local LobbyClient = {}

-- ---- 同步只读（即时返回）----

---@return integer
function LobbyClient:GetMyUserId() end
---@return integer
function LobbyClient:GetMaxPlayers() end
---@return string
function LobbyClient:GetProjectId() end
---@return boolean
function LobbyClient:IsOnline() end
---@return boolean 缓存（由大厅控制层的状态推送更新）
function LobbyClient:IsInRoom() end
--- 仅供 UI 展示：受理后的异步失败 / 取消可能滞后反映，不能据此判断匹配完成、失败或可以回落本地。
---@return boolean 缓存（由大厅控制层的状态推送更新）
function LobbyClient:IsMatching() end
--- 缓存在同一快照的 onPlayersChanged / onRoomDataChanged 回调前更新。
---@return table|nil 当前房间共享数据（最近一次推送的缓存，勿原地修改）；未设置 / 不在房间为 nil
function LobbyClient:GetRoomData() end

-- ---- 动作（发起即返回，结果走 opts 里的回调）----

--- 快速匹配。
---@param opts LobbyMatchOpts
function LobbyClient:StartMatch(opts) end

--- 房主开始游戏（链路同 StartMatch）。
---@param opts LobbyStartGameOpts
function LobbyClient:StartGame(opts) end

--- 创建房间。
---@param opts LobbyCreateRoomOpts
function LobbyClient:CreateRoom(opts) end

--- 加入房间。
---@param opts LobbyJoinRoomOpts
function LobbyClient:JoinRoom(opts) end

--- 离开房间。
---@param opts LobbyLeaveRoomOpts|nil
function LobbyClient:LeaveRoom(opts) end

--- 房主设置房间共享数据（如选关），整体替换上一份并广播给同房间全员（含晚加入）。
--- 仅房主可调；data 须可 JSON 编码，与平台字段合并后上限 0xFFFF 字节。平台不提供修订号，防乱序请在 data 内自带 rev。
---@param data table
---@param opts LobbySetRoomDataOpts|nil
function LobbyClient:SetRoomData(data, opts) end

--- 取消匹配（无完成回执；IsMatching() 随后转 false）。
--- 不保证终止后续连服 / 切换游戏脚本，不能据此立即启动本地玩法。
function LobbyClient:CancelMatch() end

--- 拉取房间列表。
---@param opts LobbyRoomListOpts
function LobbyClient:GetRoomList(opts) end

--- 异步查询昵称。
---@param opts LobbyNicknameOpts
function LobbyClient:GetUserNickname(opts) end

-- ---- 全局订阅（cb=nil 即注销）----

--- 全局错误广播：受理后的匹配失败 / 取消（"MATCH_STATUS_CHANGED"）、开局通知失败（"GAME_START"）等。
--- 匹配 / 开局请求被拒时也会收到 "START_GAME"，创建 / 加入房间被拒时分别收到 "CREATE_ROOM" / "JOIN_ROOM"。
--- 这些请求失败通知与对应动作的 opts.onError 是同一次失败、错误码相同，注意只处理一次。
---@param cb fun(errorType:string, errorCode:integer)|nil
function LobbyClient:OnError(cb) end

--- 旧版系统弹窗订阅。新项目请优先 `urhox-libs.System.SystemNotification.RegisterHandler`。
--- 未注册新版 handler 时，平台仍会把未接管的弹窗以旧载荷推到这里。
---@param cb fun(dialog:LobbySystemDialog)|nil
function LobbyClient:OnSystemDialog(cb) end

-- ============================================================================
-- 入口 ctx
-- ============================================================================

---@class LobbyCtx
---@field client LobbyClient 大厅客户端
---@field root any          引擎托管的大厅 UI 根（挂 UI；退出 / 切游戏自动回收）

---@class LobbyEntryResult
---@field stop fun()|nil    主动清理（可选；不写引擎也会回收 root）
