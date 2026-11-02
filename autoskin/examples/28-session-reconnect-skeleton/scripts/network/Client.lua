--[[
SessionReconnectDemo - 客户端

等服务端权威快照 → 应用 → 恢复交互。这一半在 helper 出现之前全仓没有任何示例。

核心纪律：**不要用 IsReconnectSession() 决定是恢复还是重建**。它是大厅的本地推断，
只能驱动 UI 文案；客户端以为在重连、而服务端宽限期已过时，服务端发的是 Joined。
权威判定看 helper 调的是 onApplySnapshot（恢复）还是 onFreshStart（首次）。
]]

local PlayerSessions = require("urhox-libs.Network.PlayerSessions")

local Client = {}

local scene_ = nil
local score_ = 0
local scores_ = {}          -- [userId:string] = score，演示广播的归属判断
local statusText_ = nil
local lastAddAt_ = 0
local ADD_INTERVAL = 1.5    -- 秒。真实游戏里这一步由玩家输入驱动，见 TryAddScore

local function SetStatus(text)
    print("[Client] " .. text)
    if statusText_ then
        statusText_.text = text
    end
end

--- 周期性请求加分，用来产生「可观测的状态」——否则分数恒为 0，
--- 首次快照与恢复快照完全一样，这个示例就证明不了它要证明的那件事。
--- 文件头的跑法用 -graphicsheadless（无窗口即无输入），所以这里用定时器而不是按键；
--- 有窗口的场合把下面这个 if 换成 KeyDown 订阅即可。
local function TryAddScore()
    -- 还在等权威快照时不发：此刻服务端可能尚未激活本连接，加分会被丢弃。
    if PlayerSessions.Client.IsWaiting() then
        return
    end
    local now = time.elapsedTime
    if now - lastAddAt_ < ADD_INTERVAL then
        return
    end
    lastAddAt_ = now
    local connection = network:GetServerConnection()
    if connection then
        connection:SendRemoteEvent("DemoAddScore", true)
    end
end

function Client.Start()
    -- 客户端必须有自己的 Scene 并 assign 给服务器连接，否则服务端激活时发来的
    -- LoadScene 无处安放（"Can not handle LoadScene message without an assigned scene"）。
    -- 这里把 scene 交给 helper，由它在上报就绪之前完成 assign，顺序不会写错。
    scene_ = Scene()
    scene_:CreateComponent("Octree", LOCAL)

    local font = cache:GetResource("Font", "Fonts/Anonymous Pro.ttf")
    if font then
        statusText_ = ui.root:CreateChild("Text")
        statusText_:SetFont(font, 18)
        statusText_:SetPosition(12, 12)
    end

    network:RegisterRemoteEvent("DemoScoreChanged")
    SubscribeToEvent("DemoScoreChanged", "HandleDemoScoreChanged")
    -- 游戏自己的 Update 用全局订阅没问题：helper 的 Update 挂在它自己持有的接收者上，
    -- 两者不同 receiver，不会因 SubscribeToEvent 的替换语义互相顶掉。
    SubscribeToEvent("Update", "HandleClientUpdate")

    PlayerSessions.Client.Setup({
        scene = scene_,

        -- 仅 UI 提示。可能与服务端最终判定相反，这是允许的。
        onRestoreBegin = function()
            SetStatus("正在恢复对局……")
        end,

        -- 服务端说这是首次进入。首次也会收到快照载荷（isRestore=false 时服务端同样
        -- 跑了 onBuildSnapshot），里面可以带首次才需要的权威分配——这里是初始分数与身份。
        onFreshStart = function(data)
            -- 「我是谁」由 helper 提供（服务端在每份快照里下发认证 user_id）
            score_ = data["Score"]:GetInt()
            scores_[PlayerSessions.Client.GetUserId()] = score_
            SetStatus(string.format("已进入对局（我是 %s），分数 %d",
                PlayerSessions.Client.GetUserId(), score_))
        end,

        -- 服务端说这是恢复：data 是原始 VariantMap，按自己的约定解。
        -- 这里的 score_ 是重连前累计的值，不是 0 —— 这就是重连确实恢复了状态的证据。
        onApplySnapshot = function(data)
            score_ = data["Score"]:GetInt()
            scores_[PlayerSessions.Client.GetUserId()] = score_
            SetStatus(string.format("已恢复对局（我是 %s），分数 %d，位置 (%.1f, %.1f)",
                PlayerSessions.Client.GetUserId(), score_,
                data["PosX"]:GetFloat(), data["PosZ"]:GetFloat()))
        end,

        -- 超时兜底：helper 不会自行重建局面，交给游戏决定
        onRestoreTimeout = function(elapsed)
            SetStatus(string.format("等待服务端快照超时（%.0fs），建议退出重进", elapsed))
        end,
    })
end

function HandleClientUpdate(eventType, eventData)
    TryAddScore()
end

function HandleDemoScoreChanged(eventType, eventData)
    -- 还在等权威快照时忽略增量：否则会把增量应用到一个尚未初始化的局面上
    if PlayerSessions.Client.IsWaiting() then
        return
    end

    -- 这是**广播**：服务端把任意玩家的加分发给所有在线玩家，所以必须按 UserId 归属，
    -- 不能无条件写进自己的显示。服务端特意把 UserId 上了 wire 就是为了这一步。
    local userId = eventData["UserId"]:GetString()
    local selfId = PlayerSessions.Client.GetUserId()
    scores_[userId] = eventData["Score"]:GetInt()
    if userId ~= selfId then
        return
    end

    score_ = scores_[userId]
    local others = 0
    for id in pairs(scores_) do
        if id ~= selfId then
            others = others + 1
        end
    end
    SetStatus(string.format("分数 %d（其他玩家 %d 人）", score_, others))
end

function Client.Stop()
    PlayerSessions.Client.Shutdown()
end

return Client
