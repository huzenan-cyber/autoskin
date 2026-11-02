# 服务端云变量指南（联网游戏服务器专用）

> **serverCloud API 快速参考**
>
> ⚠️ **仅限联网游戏的服务端脚本使用**（UrhoXServer 进程中）。客户端请使用 `clientCloud`。

---

## 与 clientCloud 的区别

| | clientCloud | serverCloud |
|---|---|---|
| **运行环境** | 客户端（UrhoXRuntime） | 服务端（UrhoXServer） |
| **操作对象** | 当前用户自己的数据 | **任意用户**的数据（需传 userId） |
| **API 范围** | Score + Rank + 场景存档 | Score + Rank + Money + List + Item + Message + Quota + 场景存档 |
| **事务** | 无 | BatchCommit（跨域原子操作） |

---

## API 概览

### 场景存档与读档

`serverCloud:SaveScene` / `serverCloud:LoadScene` 保存、读取服务端权威场景，使用 `target` 指定玩家个人存档或持久世界存档。房主下次建房继续进度可使用玩家存档，不需要用临时房间 ID 伪造世界 ID。

调用示例、归属选择、回调处理与玩家在线时的场景切换见 [场景云存档与读档](scene-cloud-save.md)。读取返回新的 `Scene`，不会自动替换连接场景或恢复玩家会话。

### Score — 顶层操作

| 方法 | 用途 | 数据存储 |
|------|------|---------|
| `serverCloud:Get(uid, key, events)` | 读取 | ← (scores, iscores, sscores) |
| `serverCloud:Set(uid, key, value, events)` | 写入任意类型 | → scores |
| `serverCloud:SetInt(uid, key, value, events)` | 写入整数 | → iscores |
| `serverCloud:Add(uid, key, delta, events)` | 整数增量 | → iscores |
| `serverCloud:Delete(uid, key, events)` | 删除 | - |

### 批量操作（链式调用）

| 方法 | 用途 |
|------|------|
| `serverCloud:BatchGet(uid)` | 单人批量读取 |
| `serverCloud:BatchGet():Player(uid1):Player(uid2)` | 多人批量读取 |
| `:Key(key)` | 追加要读取的 key |
| `:Fetch(events)` | 执行读取 |
| `serverCloud:BatchSet(uid)` | 批量写入 |
| `:Set(key, value)` / `:SetInt(key, value)` / `:Add(key, delta)` / `:Delete(key)` | 链式追加 |
| `:Save(description, events?)` | 提交写入 |

### 排行榜 — 顶层操作

| 方法 | 用途 |
|------|------|
| `serverCloud:GetRankList(key, start, count, [orderAsc,] events)` | 排行榜列表 |
| `serverCloud:GetUserRank(uid, key, events)` | 用户排名 |
| `serverCloud:GetRankTotal(key, events)` | 排行榜总人数 |

### 子对象

| 子对象 | 方法 | 用途 |
|--------|------|------|
| `serverCloud.money` | `Get`, `Add`, `Cost` | 货币系统 |
| `serverCloud.list` | `Get`, `GetById`, `Add`, `Modify`, `ModifyKey`, `Delete` | 列表存储 |
| `serverCloud.item` | `Get`, `Add`, `Use` | 道具系统 |
| `serverCloud.message` | `Send`, `Get`, `MarkRead`, `Delete` | 消息系统 |
| `serverCloud.quota` | `Get`, `Add`, `Reset` | 配额计数器（限次操作） |

### 事务 — BatchCommit

| 方法 | 用途 |
|------|------|
| `serverCloud:BatchCommit(description)` | 创建跨域事务 |
| `:ScoreSet(uid, key, value)` | Score 写入 |
| `:ScoreSetInt(uid, key, value)` / `:ScoreAddInt(uid, key, delta)` | Score 整数 |
| `:MoneyAdd(uid, key, amount)` / `:MoneyCost(uid, key, amount)` | 货币 |
| `:ListAdd(uid, key, value)` / `:ListModify(id, value)` / `:ListDelete(id)` | 列表 |
| `:QuotaAdd(uid, key, value, limit, ...)` / `:QuotaReset(uid, key)` | 配额 |
| `:Commit(events?)` | 提交事务 |

---

## 快速开始

### Score CRUD

```lua
local uid = connection.identity["user_id"]:GetInt64()

-- 写入
serverCloud:Set(uid, "game_config", { difficulty = "hard" })
serverCloud:SetInt(uid, "high_score", 9999)
serverCloud:Add(uid, "kills", 1)

-- 读取
serverCloud:Get(uid, "high_score", {
    ok = function(scores, iscores)
        print("最高分:", iscores.high_score or 0)
    end,
    error = function(code, reason)
        print("错误:", code, reason)
    end
})

-- 删除
serverCloud:Delete(uid, "temp_data")
```

### 批量读取

```lua
-- 单人
serverCloud:BatchGet(uid)
    :Key("high_score")
    :Key("kills")
    :Fetch({
        ok = function(scores, iscores)
            print("分数:", iscores.high_score, "击杀:", iscores.kills)
        end
    })

-- 多人（查询多个玩家的同一组 key）
serverCloud:BatchGet()
    :Player(uid1)
    :Player(uid2)
    :Key("high_score")
    :Fetch({
        ok = function(results)
            for _, r in ipairs(results) do
                print("玩家:", r.userId, "分数:", r.iscore.high_score or 0)
            end
        end
    })
```

### 批量写入

```lua
serverCloud:BatchSet(uid)
    :Set("config", { music = true })
    :SetInt("gold", 500)
    :Add("play_count", 1)
    :Save("游戏奖励", {
        ok = function() print("保存成功") end
    })
```

---

## 子对象

### Money — 货币

```lua
-- 查询余额
serverCloud.money:Get(uid, {
    ok = function(moneys)
        print("金币:", moneys.gold or 0)
        print("钻石:", moneys.diamond or 0)
    end
})

-- 增加货币
serverCloud.money:Add(uid, "gold", 100)

-- 扣除货币（amount 必须 > 0）
serverCloud.money:Cost(uid, "gold", 50, {
    ok = function() print("扣除成功") end,
    error = function(code, reason) print("余额不足?", reason) end
})
```

### List — 列表存储

```lua
-- 添加列表项（返回 listId）
local listId = serverCloud.list:Add(uid, "inventory", { name = "sword", level = 5 })

-- 查询列表
serverCloud.list:Get(uid, "inventory", {
    ok = function(list)
        for _, item in ipairs(list) do
            print(item.list_id, item.key, item.value)
        end
    end
})

-- 通过 ID 查询
serverCloud.list:GetById(listId, {
    ok = function(items) ... end
})

-- 修改
serverCloud.list:Modify(listId, { name = "sword", level = 10 })

-- 删除
serverCloud.list:Delete(listId)
```

### Item — 道具

```lua
-- 添加道具
local itemId = serverCloud.item:Add(uid, "weapon", "火焰剑", 1, { damage = 100 })

-- 查询道具（key 可选，不传则查全部）
serverCloud.item:Get(uid, "weapon", {
    ok = function(items)
        for _, item in ipairs(items) do
            print(item.name, item.count)
        end
    end
})

-- 使用道具（消耗数量，默认 1）
serverCloud.item:Use(uid, itemId, 1)
```

### Message — 消息

```lua
-- 发送消息
serverCloud.message:Send(senderUid, "gift", targetUid, { item = "sword" }, {
    ok = function(errorCode, errorDesc)
        if errorCode == 0 or errorCode == nil then
            print("发送成功")
        end
    end
})

-- 查询消息（read=false 查未读）
serverCloud.message:Get(uid, "gift", false, {
    ok = function(messages)
        for _, msg in ipairs(messages) do
            print(msg.message_id, msg.value, msg.time)
            -- time: 消息发送时间（字符串，由积分服返回）
        end
    end
})

-- 标记已读
serverCloud.message:MarkRead(messageId)

-- 删除消息
serverCloud.message:Delete(messageId)
```

### Quota — 配额计数器

用于限次操作（如每日签到、每周挑战）。

```lua
-- 查询配额
serverCloud.quota:Get(uid, "daily_reward", {
    ok = function(datas)
        if #datas > 0 then
            print("已使用:", datas[1].value, "/", datas[1].limit)
        end
    end
})

-- 增加计数（每日刷新，上限 3 次）
serverCloud.quota:Add(uid, "daily_reward", 1, 3, "day", 1, {
    ok = function() print("领取成功") end,
    error = function(code, reason) print("已达上限?", reason) end
})

-- 重置计数器
serverCloud.quota:Reset(uid, "daily_reward")
```

---

## 排行榜

排行榜基于 **iscores 中的整数** 排序（通过 `SetInt` / `Add` 写入）。

```lua
-- 获取排行榜（前 10 名，默认降序）
serverCloud:GetRankList("high_score", 1, 10, {
    ok = function(rankList)
        for i, item in ipairs(rankList) do
            print(string.format("#%d 用户:%s 分数:%d",
                i, tostring(item.userId), item.iscore.high_score or 0))
        end
    end
})

-- 获取排行榜（升序排列）
serverCloud:GetRankList("high_score", 1, 10, true, {
    ok = function(rankList)
        -- orderAsc=true 时按分数从低到高排列
    end
})

-- 获取用户排名
serverCloud:GetUserRank(uid, "high_score", {
    ok = function(rank, score)
        if rank then
            print("排名:", rank, "分数:", score)
        else
            print("未上榜")
        end
    end
})

-- 获取排行榜总人数
serverCloud:GetRankTotal("high_score", {
    ok = function(total) print("共", total, "人上榜") end
})
```

### 排行榜 + 昵称（完整示例）

> ⚠️ **排行榜不包含昵称！** 需要用全局函数 `GetUserNickname()` 单独查询。
> 该函数服务端和客户端通用，服务端从 `SERVER_PLAYER_AUTH_INFOS` 同步读取（无需网络请求）。

```lua
-- 服务端：查询排行榜并填充昵称，转发给客户端
function HandleLeaderboardRequest(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local uid = connection.identity["user_id"]:GetInt64()

    serverCloud:GetRankList("high_score", 1, 10, {
        ok = function(rankList)
            -- 1. 收集所有 userId
            local userIds = {}
            local results = {}
            for i, item in ipairs(rankList) do
                userIds[#userIds + 1] = item.userId
                results[#results + 1] = {
                    rank = i,
                    userId = item.userId,
                    score = item.iscore.high_score or 0,
                    nickname = "",  -- 待填充
                }
            end

            -- 2. 批量查询昵称（服务端同步，回调立即执行）
            if #userIds > 0 then
                GetUserNickname({
                    userIds = userIds,
                    onSuccess = function(nicknames)
                        local map = {}
                        for _, info in ipairs(nicknames) do
                            map[info.userId] = info.nickname or ""
                        end
                        for _, entry in ipairs(results) do
                            entry.nickname = map[entry.userId] or ""
                        end
                    end,
                })
            end

            -- 3. 转发给客户端
            local resData = VariantMap()
            resData["Data"] = Variant(cjson.encode({ success = true, list = results, myUid = uid }))
            connection:SendRemoteEvent("LeaderboardResponse", true, resData)
        end,
        error = function(code, reason)
            print("[Server] 排行榜查询失败:", reason)
        end
    })
end
```

---

## 事务 — BatchCommit

`BatchCommit` 可以在一次提交中混合 Score、Money、List、Quota 等多种操作，保证原子性。

```lua
local c = serverCloud:BatchCommit("击杀奖励")
c:ScoreAddInt(uid, "kills", 1)
c:MoneyAdd(uid, "gold", 100)
c:ListAdd(uid, "kill_log", { target = "monster_01", time = os.time() })
c:Commit({
    ok = function() print("事务提交成功") end,
    error = function(code, reason) print("事务失败:", reason) end
})
```

### Commit 操作一览

| 方法 | 说明 |
|------|------|
| `ScoreSet(uid, key, value)` | 写任意类型到 scores |
| `ScoreSetInt(uid, key, value)` | 写整数到 iscores |
| `ScoreAddInt(uid, key, delta)` | 整数增量到 iscores |
| `ScoreSetStr(uid, key, value)` | 写字符串（已废弃） |
| `ScoreDelete(uid, key)` | 删除 scores key |
| `ScoreDeleteInt(uid, key)` | 删除 iscores key |
| `ScoreDeleteStr(uid, key)` | 删除（已废弃） |
| `MoneyAdd(uid, key, amount)` | 增加货币 |
| `MoneyCost(uid, key, amount)` | 扣除货币 |
| `ListAdd(uid, key, value)` | 添加列表项，返回 listId |
| `ListModify(listId, value)` | 修改列表项 |
| `ListModifyKey(listId, key)` | 修改列表项 key |
| `ListDelete(listId)` | 删除列表项 |
| `QuotaAdd(uid, key, value, limit, refreshType?, refreshCount?)` | 配额增加 |
| `QuotaReset(uid, key)` | 配额重置 |

---

## 回调结构

普通云变量 API 的 `events` 参数结构；场景存档的成功参数和字符串错误码见 [场景存档回调](scene-cloud-save.md#先区分入队与完成)：

```lua
{
    ok = function(...)      -- 成功回调（参数因 API 而异）
    end,
    error = function(code, reason)  -- 错误回调
    end,
}
```

---

## 常见场景

### 玩家加入时加载数据

```lua
function OnPlayerJoined(uid, connection)
    serverCloud:BatchGet(uid)
        :Key("gold")
        :Key("kills")
        :Key("level")
        :Fetch({
            ok = function(scores, iscores)
                local playerData = {
                    gold = iscores.gold or 0,
                    kills = iscores.kills or 0,
                    level = iscores.level or 1,
                }
                -- 缓存到内存，后续操作直接读内存
                playerCache[uid] = playerData
                SendDataToClient(connection, playerData)
            end
        })
end
```

### 击杀奖励（事务保证原子性）

```lua
function OnPlayerKill(killerUid, victimUid)
    local c = serverCloud:BatchCommit("击杀奖励")
    c:ScoreAddInt(killerUid, "kills", 1)
    c:MoneyAdd(killerUid, "gold", 50)
    c:Commit()
end
```

### 商店购买（先扣货币，再发道具）

```lua
function BuyItem(uid, itemKey, itemName, price)
    local c = serverCloud:BatchCommit("购买道具")
    c:MoneyCost(uid, "gold", price)
    c:ListAdd(uid, "inventory", { key = itemKey, name = itemName })
    c:Commit({
        ok = function() print("购买成功") end,
        error = function(code, reason)
            print("购买失败:", reason)  -- 余额不足等
        end
    })
end
```

### 每日签到（配额限次）

```lua
function DailyCheckIn(uid)
    serverCloud.quota:Add(uid, "daily_checkin", 1, 1, "day", 1, {
        ok = function()
            serverCloud.money:Add(uid, "gold", 200)
            print("签到成功，+200金币")
        end,
        error = function(code, reason)
            print("今日已签到")
        end
    })
end
```

---

## 使用限制

### 配额与限流

以下额度由**同一个游戏服实例（同房间）的所有玩家共享**，不是每个 `userId` 各有一份。读、写次数分别计数；60 秒计数窗口结束后，在后续请求到来时重置，不是每秒固定可调用 5 次。场景存档和普通云变量共用额度，但存档使用专用调度及回调；见 [场景存档的运行约束](scene-cloud-save.md#时机失败与运行条件)。

| 限制项 | 值 | 超限行为 |
|--------|-----|---------|
| 读请求频率 | **300 次 / 60 秒** | 拒绝发送，`error(-429, "read rate limit exceeded")` |
| 写请求频率 | **300 次 / 60 秒** | 拒绝发送，`error(-429, "write rate limit exceeded")` |
| 写入数据量 | **48 MB / 60 秒**（`48 × 1024 × 1024` 字节） | 按请求序列化后的大小累计；超限拒绝发送，`error(-429, "data size limit exceeded")` |
| 单次 `BatchCommit` / `BatchSet` 操作数 | **最多 1000 个操作** | 整批拒绝，不会提交前 1000 项；`error(-429, "commit operations exceed limit: … (max 1000)")` |

**计数单位是请求**：构建器的 `:Key()`、`:Set()` 等调用不单独发请求，执行 `:Fetch()`、`:Save()` 或 `:Commit()` 时才提交。一次批量读记一次读请求，一次批量写 / 事务记一次写请求；批量操作仍受写入字节数、单批操作数和其他查询保护约束。`serverCloud.quota` 是游戏业务的配额计数器，不是这套 API 限额的查询或扩容接口。

### 超限、回调与重试

- 上表的硬限额命中后**直接拒绝，不自动排队、不自动重试**。需要 `error(code, reason)` 回调才能在项目逻辑中处理失败；不要依赖错误码推断写入成功。
- 读 / 写次数和写入大小超限的错误回调延迟到下一帧；单批操作数超限的回调可能在 `Commit()` / `Save()` 调用栈内同步执行。不要在 `error` 中立即递归调用同一 API。
- 若平台启用了额外的云查询保护，请求也可能暂缓发送或被拒绝；拒绝 / 排队超时同样为 `-429`，原因以 `score guard rejected:` 开头（如 `queue_wait`）。这与上表硬限额直接拒绝的路径不同。
- `-429` 时保留待保存状态，合并重复读写，延后、限次重试；单批超过 1000 项需先缩小批次，重复原请求不会成功。拆成多个事务后不再具有跨批原子性。
- 只在 `ok` 后把云端保存标为成功。网络错误或超时不等于云端一定未执行，`Add`、扣款、发奖等非幂等写入不要盲目重发，应先核对结果。

例如 4 位玩家各自每秒发一次单独的读和写，会在 60 秒内消耗约 240 次读、240 次写；剩余额度还要留给排行榜、其他玩家操作和场景存档。建议玩家加入时批量加载到内存，玩法过程中更新内存，在检查点或结算时合并提交。

---

## 要点速记

1. **玩家数据操作需传 userId** — 场景存档改用 `target` 指定玩家或世界归属
2. **Score 在顶层** — `serverCloud:Get/Set/SetInt/Add/Delete`
3. **其他域在子对象** — `serverCloud.money/list/item/message/quota`
4. **BatchCommit** = 跨域原子事务，混合 Score + Money + List + Quota
5. **BatchGet 支持多人** — `:Player(uid1):Player(uid2)` 一次查多个玩家
6. **排行榜在顶层** — `serverCloud:GetRankList/GetUserRank/GetRankTotal`
7. **排行榜只排 iscores** — 通过 `SetInt` / `Add` 写入的整数
8. **排行榜不含昵称** — 查完排行榜后用 `GetUserNickname()` 批量查询昵称（服务端同步，无需网络请求）

---
