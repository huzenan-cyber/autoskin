--[[
SessionReconnectDemo - 服务端

全部玩家生命周期交给 urhox-libs/Network/PlayerSessions 编排，本文件只提供三件
游戏特定的东西：建玩家、填快照、销毁玩家。

对照着看会更清楚 helper 替你挡掉了什么：
  - 玩家主键是认证 user_id，不是 Connection 指针、不是 address:port
  - 掉线只暂存（onDisconnected），到期由引擎发 Left 才真正销毁
  - 重连与顶号走同一条路径，都会重绑连接并重推快照
  - connection.scene 与快照都等客户端就绪后才发（过早会得到
    "Can not handle LoadScene message without an assigned scene"）
]]

local PlayerSessions = require("urhox-libs.Network.PlayerSessions")

local Server = {}

local scene_ = nil

local function CreatePlayerNode(userId)
    local node = scene_:CreateChild("Player_" .. tostring(userId), REPLICATED)
    node.position = Vector3(math.random(-5, 5), 1.0, math.random(-5, 5))
    return node
end

function Server.Start()
    scene_ = Scene()
    scene_:CreateComponent("Octree", LOCAL)

    PlayerSessions.Server.Setup({
        -- 给了 scene，helper 会在客户端就绪后自动赋 connection.scene
        scene = scene_,

        -- 首次加入：只建业务状态。此刻**不要**碰 connection.scene。
        onCreatePlayer = function(userId, connection)
            print(string.format("[Server] 玩家 %s 首次加入", tostring(userId)))
            return { node = CreatePlayerNode(userId), score = 0 }
        end,

        -- 首次激活与重连恢复共用同一个快照构建器。
        -- 注意是「往传入的 snapshot 里填」，不是返回一个新 map。
        onBuildSnapshot = function(entry, isRestore, snapshot)
            snapshot["Score"] = Variant(entry.state.score)
            snapshot["PosX"] = Variant(entry.state.node.position.x)
            snapshot["PosZ"] = Variant(entry.state.node.position.z)
            -- 不需要自己塞 user_id：helper 会在每份快照里下发，客户端用
            -- PlayerSessions.Client.GetUserId() 取。
        end,

        -- 掉线：只暂存。timeout 仅供展示，到期判定归引擎。
        onDisconnected = function(entry, timeout)
            print(string.format("[Server] 玩家 %s 掉线，宽限 %.0f 秒（状态已暂存）",
                tostring(entry.userId), timeout))
        end,

        -- 终态：宽限超时 / 主动退出 / 被踢都走这里，reason 由引擎给出。
        onDisposePlayer = function(entry, reason)
            if entry.state and entry.state.node then
                entry.state.node:Dispose()
            end
            print(string.format("[Server] 玩家 %s 离开：%s", tostring(entry.userId), reason))
        end,

        onActivated = function(entry, isRestore)
            print(string.format("[Server] 玩家 %s 已激活（%s），在线 %d / 共 %d",
                tostring(entry.userId), isRestore and "恢复" or "首次",
                PlayerSessions.Server.CountOnline(), PlayerSessions.Server.Count()))
        end,
    })

    -- 一个最小的业务事件，用来证明重连后状态确实恢复了
    network:RegisterRemoteEvent("DemoAddScore")
    SubscribeToEvent("DemoAddScore", "HandleDemoAddScore")
end

function HandleDemoAddScore(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")

    -- 用连接反查玩家。查不到就忽略：可能是未认证连接，也可能玩家已离开。
    -- 不要拿 identity 里的 user_id 去「创建」玩家 —— 那是客户端上报值。
    local entry = PlayerSessions.Server.FromConnection(connection)
    if not entry then
        return
    end

    entry.state.score = entry.state.score + 1

    -- 广播用 ForEachOnline：宽限期内的玩家 connection 是 nil，用 ForEach 会崩。
    PlayerSessions.Server.ForEachOnline(function(_, conn)
        local vm = VariantMap()
        vm["UserId"] = Variant(tostring(entry.userId))  -- userId 上 wire 用字符串，避免 int64 精度损失
        vm["Score"] = Variant(entry.state.score)
        conn:SendRemoteEvent("DemoScoreChanged", true, vm)
    end)
end

function Server.Stop()
    PlayerSessions.Server.Shutdown()
end

return Server
