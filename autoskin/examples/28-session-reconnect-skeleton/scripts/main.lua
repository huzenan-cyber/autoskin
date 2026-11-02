--[[
SessionReconnectDemo - 断线重连的最小可跑骨架（入口）

演示 urhox-libs/Network/PlayerSessions 的用法：服务端按认证 user_id 单表管理玩家、
掉线只暂存不销毁、重连（含顶号）时重绑并重推权威快照；客户端等服务端权威快照，
而不是自行根据 IsReconnectSession() 判断是恢复还是重建。

单入口 + IsServerMode() 分流，与 Hand-picked/ServerScoreDemo 同形。

跑法（两个终端，路径都要绝对路径）。以下命令**实测跑通过**：

    # 1) dev.json：玩家的 auth_key 必须是空串，见下方 ⚠️
    #    {"dev_mode":true,"dev_mode_script_name":"main.lua",
    #     "tapcode_dir":"<abs 本目录>","session_id":555001,
    #     "players":[{"user_id":6001,"user_name":"a","nick_name":"A",
    #                 "auth_key":"","login_id":1}]}

    # 2) 服务端
    UrhoXServer -headless -port=5053 -config=<abs>/dev.json \
        -script=main.lua -initial_wait=0 -idle_timeout=0

    # 3) 客户端：身份走 -directConnectParams（base64 的 JSON）
    PARAMS=$(printf '{"userId":6001,"connectInfo":{"pod_ip":"127.0.0.1","server_port":5053,"login_key":""}}' | base64 -w0)
    UrhoXRuntime main.lua -editor_debug_tapcode -editor_debug=<abs>/ \
        -graphicsheadless -directConnectParams="$PARAMS"

    # 掉线重连：直接杀掉客户端进程再原样重启一次，宽限期（默认 60s）内会走恢复分支，
    # 客户端应打印「已恢复对局（我是 6001），分数 N」且 N 就是掉线前那个值。

⚠️ **不要用 `-server_address=` / `-server_port=` 跑客户端**：那条路径不带身份，
   identity 里 user_id 恒为 0，服务端认不出来、握手后立刻断开（实测 ~50ms）。
   必须用 `-directConnectParams`。

⚠️ **dev.json 里的 auth_key 必须留空**：`DirectConnectStep.cpp` 目前硬编码
   `identity_["auth_key"] = ""`（真值那行被注释掉了），所以直连客户端送不出 auth_key，
   服务端配置里写了非空值就会对不上。

⚠️ 直连能验完整的「首次进入 / 掉线暂存 / 宽限期内重连 / 权威快照恢复」，但
   IsReconnectSession() / GetSessionId() 在直连下恒为 false / 空串 —— 多人分支要求
   Lobby 子系统存在，而它由 LoginStep 创建，直连不经过。要验大厅级重连，用
   engine/Tests/Integration/lobby/ 的假大厅装置（skill `lobby-e2e`）。
   这不是本示例的缺陷，是路径差异。

不需要真引擎的状态机回归：engine/Tests/Lua/（`run_tests.sh`，毫秒级）。
]]

local Module = nil

function Start()
    if IsServerMode() then
        print("[SessionReconnectDemo] SERVER mode")
        Module = require("network.Server")
    elseif IsNetworkMode() then
        print("[SessionReconnectDemo] CLIENT mode")
        Module = require("network.Client")
    else
        print("[SessionReconnectDemo] 本示例需要联网模式（UrhoXServer + UrhoXRuntime），见文件头跑法")
        return
    end

    Module.Start()
end

function Stop()
    if Module and Module.Stop then
        Module.Stop()
    end
end
