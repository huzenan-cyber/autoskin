# 动画状态机 (AnimationStateMachine)

> **让角色根据移动/跳跃等状态自动切换动画**

多个同骨架、不同体型角色共用动画与 FSM，见 [共享骨架动画](shared-skeleton-animation.md)。旧资产及配置继续使用原行为，新格式需要资产工具显式生成。

---

## 概念速览

- **动画状态机与游戏逻辑是分离的**——它只是一种数据驱动角色动画的机制，不包含任何游戏逻辑（移动、物理、输入等）。游戏逻辑负责计算角色状态，然后把结果（速度、是否着地等）作为参数喂给状态机，状态机只负责据此播放正确的动画。
- **AnimationStateMachine** 组件根据参数自动切换动画状态，并作为 `AnimatedModel` 的独占 Pose Provider 求值最终骨骼姿势
- 配置写在 `.fsm` JSON 文件，动画混合配置写在 `.blendspace` JSON 文件
- 参数由 Lua 脚本每帧喂入（`SetFloat` / `SetBool` / `SetTrigger`）
- 节点或其子节点必须有 **AnimatedModel**，但状态机路径**不需要 AnimationController**。旧 prefab 可以暂时保留 AnimationController；状态机运行时它不参与该模型的 Pose 求值
- **禁止**对状态机占用的同一个 `AnimatedModel` 调用 AnimationController 的 `Play` / `PlayExclusive` 等播放接口；引擎会拒绝调用并记录警告。一次性攻击、换弹等动画应配置成 FSM layer/state
- 状态机内部使用 Pose Graph 语义处理 Animation、BlendSpace、层混合、Additive、AimOffset 和 Root Motion，状态切换被连续打断时也会从当前可见姿势继续混合

---

## 快速开始

### 最小示例：角色移动 + 跳跃

**1. 创建 BlendSpace1D**（`scripts/FSM/MovementBlendSpace.blendspace`）：

```json
{
    "type": "BlendSpace1D",
    "name": "MovementBlendSpace",
    "parameter": "moveSpeed",
    "points": [
        { "value": 0, "animation": "Idle.ani", "speed": 1.0 },
        { "value": 2, "animation": "Walk.ani", "speed": 1.0 },
        { "value": 5, "animation": "Run.ani", "speed": 1.0 }
    ]
}
```

**2. 创建 FSM**（`scripts/FSM/Character.fsm`）：

```json
{
    "name": "CharacterFSM",
    "defaultBlendTime": 0.2,

    "parameters": {
        "moveSpeed": { "type": "float", "default": 0.0, "min": 0.0, "max": 10.0 },
        "isGrounded": { "type": "bool", "default": true },
        "jump": { "type": "trigger" }
    },

    "layers": [
        {
            "name": "Base",
            "defaultState": "Locomotion",
            "states": {
                "Locomotion": {
                    "blendSpace": "FSM/MovementBlendSpace.blendspace",
                    "loop": true
                },
                "JumpStart": {
                    "animation": "JumpStart.ani",
                    "loop": false,
                    "speed": 1.0,
                    "blendTime": 0.1
                },
                "JumpAir": {
                    "animation": "JumpAir.ani",
                    "loop": true,
                    "speed": 1.0
                },
                "JumpLanding": {
                    "animation": "JumpLanding.ani",
                    "loop": false,
                    "speed": 1.0
                }
            },
            "transitions": [
                { "from": "*", "to": "JumpStart", "condition": "jump", "priority": 10, "blendTime": 0.1 },
                { "from": "JumpStart", "to": "JumpAir", "condition": "animationFinished and not isGrounded", "blendTime": 0.15 },
                { "from": "JumpStart", "to": "Locomotion", "condition": "isGrounded", "blendTime": 0.2 },
                { "from": "Locomotion", "to": "JumpAir", "condition": "not isGrounded", "priority": 5, "blendTime": 0.2 },
                { "from": "JumpAir", "to": "JumpLanding", "condition": "isGrounded and stateTime > 0.5", "priority": 2, "blendTime": 0.1 },
                { "from": "JumpAir", "to": "Locomotion", "condition": "isGrounded", "priority": 1, "blendTime": 0.2 },
                { "from": "JumpLanding", "to": "Locomotion", "condition": "animationFinished or moveSpeed > 0.5", "blendTime": 0.2 }
            ]
        }
    ]
}
```

BlendSpace 状态同样可以写 `speed`，它会乘到每个采样点自身的 `speed` 上，同一个 `.blendspace` 可被不同速率的状态复用。

**3. Lua 驱动代码**：

```lua
-- 获取组件（节点上必须已有 AnimatedModel）
local fsm = node:GetOrCreateComponent("AnimationStateMachine")

-- 加载 FSM
local jsonFile = cache:GetResource("JSONFile", "FSM/Character.fsm")
fsm:LoadFromJSONFile(jsonFile)
fsm:Start()

-- 每帧更新参数（在 Update 中）
-- 方式一：使用引擎物理（配合 CharacterComponent，参考 examples/22-third-person-shooter）
local character = node:GetComponent("CharacterComponent")
fsm:SetFloat("moveSpeed", character:GetMoveSpeed())
fsm:SetBool("isGrounded", character:IsOnGround() and not character:IsJumping())
if character:IsJumpStarted() then
    fsm:SetTrigger("jump")
end

-- 方式二：自定义物理（自己维护状态）
fsm:SetFloat("moveSpeed", currentSpeed)
fsm:SetBool("isGrounded", isOnGround)
if jumpPressed then
    fsm:SetTrigger("jump")
end

-- 查询当前状态
local state = fsm:GetCurrentState(0)  -- 层 0
```

---

## .fsm 文件格式

### 顶层结构

```json
{
    "name": "FSM 名称",
    "defaultBlendTime": 0.2,
    "_animationPaths": { },
    "boneMasks": { },
    "aimOffset": { },
    "parameters": { },
    "layers": [ ]
}
```

| 字段 | 说明 |
|------|------|
| `name` | FSM 名称 |
| `defaultBlendTime` | 默认动画过渡时间（秒） |
| `_animationPaths` | 可选，**纯注释，引擎不解析此字段**。仅供人类阅读，记录 uuid 对应的动画名称，可省略 |
| `boneMasks` | 骨骼遮罩定义（多层 FSM 用） |
| `aimOffset` | 可选，全局 AimOffset 绑定；layer/state 可覆盖 |
| `parameters` | 参数定义 |
| `layers` | 动画层数组 |

### parameters（参数）

参数名完全由开发者自定义，状态机不关心它们的语义。游戏逻辑通过 `SetFloat`/`SetBool`/`SetTrigger` 喂入值，状态机只根据 `transitions` 中的条件表达式评估这些值来决定状态切换——这正是表现与逻辑分离的体现。

```json
"parameters": {
    "moveSpeed":  { "type": "float", "default": 0.0, "min": 0.0, "max": 10.0 },
    "direction":  { "type": "float", "default": 0.0, "min": -180.0, "max": 180.0 },
    "isGrounded": { "type": "bool",  "default": true },
    "weaponType": { "type": "int",   "default": 0, "min": 0, "max": 10 },
    "jump":       { "type": "trigger" }
}
```

| 类型 | 说明 | Lua 设置方式 |
|------|------|-------------|
| `float` | 浮点数，可选 min/max | `fsm:SetFloat("name", value)` |
| `int` | 整数，可选 min/max | `fsm:SetInt("name", value)` |
| `bool` | 布尔值 | `fsm:SetBool("name", value)` |
| `trigger` | 触发器，触发后自动重置 | `fsm:SetTrigger("name")` |

### layers（动画层）

```json
"layers": [
    {
        "name": "Base",
        "defaultState": "Locomotion",
        "boneMask": "UpperBody",
        "weight": 1.0,
        "blendMode": "lerp",
        "states": { },
        "transitions": [ ]
    }
]
```

| 字段 | 必填 | 说明 |
|------|------|------|
| `name` | 是 | 层名称 |
| `defaultState` | 是 | 初始状态 |
| `boneMask` | 否 | 引用 boneMasks 中定义的遮罩名 |
| `weight` | 否 | 层权重，默认 1.0 |
| `blendMode` | 否 | `"lerp"`（替换，默认）或 `"additive"`（叠加） |
| `aimOffset` | 否 | layer 级 AimOffset 绑定，优先于顶层配置 |

### states（状态）

三种状态类型：

```json
"states": {
    "Locomotion": {
        "blendSpace": "FSM/MovementBlendSpace.blendspace",
        "loop": true
    },
    "JumpStart": {
        "animation": "Animations/JumpStart.ani",
        "loop": false,
        "speed": 1.0,
        "blendTime": 0.1
    },
    "Empty": {
        "empty": true
    }
}
```

| 字段 | 说明 |
|------|------|
| `animation` | 单动画路径（支持 `uuid://` 或相对路径） |
| `blendSpace` | BlendSpace 文件路径 |
| `empty` | 空状态，该层不播放动画 |
| `loop` | 是否循环 |
| `speed` | 播放速度，默认 1.0 |
| `blendTime` | `blendInTime` 的兼容写法；进入此状态时覆盖 transition/defaultBlendTime |
| `blendInTime` | 进入此状态的过渡时间，优先于 transition/defaultBlendTime |
| `blendOutTime` | 保留字段；当前运行时会解析和回写，但离开状态仍使用目标状态/transition/defaultBlendTime，不要依赖此字段 |
| `boneMask` | 状态级骨骼遮罩（覆盖层级设置） |
| `syncGroup` | 循环动画同步组名；同组状态切换时继承归一化播放相位 |
| `aimOffset` | 状态级 AimOffset 绑定，优先于 layer 和顶层配置 |
| `rootMotion` | 状态级根骨处理与 Root Motion 提取配置 |
| `events` | 动画事件数组（见下文） |
| `startFrame` / `endFrame` / `frameRate` | 按帧裁剪播放窗口。用帧时状态中**必须**显式写 `frameRate`。时长 `(endFrame - startFrame) / frameRate`。与秒字段互斥 |
| `startTime` / `endTime` | 按秒裁剪。与帧字段互斥。只写一端则另一端落到 0 或动画全长 |

不写裁剪字段则整段播放。帧和秒不能写在同一状态里，混写会解析报错。越界（负数、`start >= end`、超出 clip 长度）会打错误日志并 clamp。`frameRate` 只用来把帧号换成秒，不会按第 N 个关键帧去切。裁剪字段只支持单 Animation 状态，BlendSpace 状态配置这些字段会报错；需要先在资产侧裁好 BlendSpace 样本。

新 `.ani` 资源会保存导入时的 `FrameRate`；没有该字段的旧动画按 30 FPS 读取，保持兼容。FSM 的按帧裁剪仍要求状态里显式写 `frameRate`，这样加载配置时不必同步加载动画资源；通常填写与源 `.ani` 相同的帧率。

```json
"JumpStart": {
    "animation": "Art/Animations/Jump_B_Start.ani",
    "loop": false,
    "blendTime": 0.1,
    "startFrame": 14,
    "endFrame": 33,
    "frameRate": 30
}
```

上面这段从第 14 帧播到第 33 帧，时长 `(33-14)/30 = 0.633s`。等价写法：`"startTime": 0.466, "endTime": 1.1`。`animationFinished` / `normalizedTime` / `loop` 都按裁剪后的短 clip 计算。同一份 `.ani` 可以在多个状态里取不同窗口。

不要改 `AnimationController:Play` 的参数来裁剪；状态机动画的切片只写在 `.fsm` 上。

**动画事件**：

```json
"events": [
    { "name": "FootStep", "time": 0.3 },
    { "name": "AttackHit", "time": 0.5, "normalized": true, "data": { "damage": 10 } }
]
```

| 字段 | 说明 |
|------|------|
| `name` | 事件名 |
| `time` | 触发时间 |
| `normalized` | 可选，true 时 time 为 0-1 归一化值 |
| `data` | 可选，自定义数据 |

### transitions（过渡）

```json
"transitions": [
    {
        "from": "*",
        "to": "JumpStart",
        "condition": "jump",
        "priority": 10,
        "blendTime": 0.1
    }
]
```

| 字段 | 必填 | 说明 |
|------|------|------|
| `from` | 是 | 源状态名，`"*"` 匹配任意状态，也支持数组 `["StateA", "StateB"]` |
| `to` | 是 | 目标状态名 |
| `condition` | 否 | 条件表达式（见下文）；省略或空字符串视为恒真，常与 `exitTime` 组合 |
| `priority` | 否 | 优先级，越高越先评估，默认 0 |
| `blendTime` | 否 | 过渡时间（覆盖 defaultBlendTime） |
| `exitTime` | 否 | 归一化退出时间 (0-1) |
| `interruptible` | 否 | 保留字段，默认 true；当前运行时会解析和回写，但尚未据此阻止过渡打断，不要依赖它控制行为 |

### boneMasks（骨骼遮罩）

用于多层 FSM，让不同层控制不同身体部位：

```json
"boneMasks": {
    "UpperBody": {
        "startBone": "Bip001 Spine"
    },
    "LowerBody": {
        "bones": ["Root", "Bip001", "Bip001 Pelvis", "Bip001 L Thigh", "Bip001 R Thigh"]
    }
}
```

| 方式 | 说明 |
|------|------|
| `startBone` | 指定根骨骼，所有子骨骼自动包含 |
| `bones` | 显式列出骨骼名列表 |

### condition 表达式语法

**运算符**：`and`, `or`, `not`, `>`, `<`, `>=`, `<=`, `==`, `!=`, `()`

**内置变量**（每层独立）：

| 变量 | 类型 | 说明 |
|------|------|------|
| `stateTime` | float | 当前状态已播放时间（秒） |
| `normalizedTime` | float | 当前 Animation 或 BlendSpace 主导样本的归一化时间（0-1） |
| `animationFinished` | bool | 非循环 Animation 或 BlendSpace 是否播放完毕 |

BlendSpace 状态的进度取当前实际贡献最大的主导样本，不使用固定状态计时器冒充动画进度。非循环 BlendSpace 到达末帧后会停在末帧并令 `animationFinished` 为 true；由于采样精度导致 `normalizedTime` 略小于 1 时，末帧判定仍会满足 `exitTime: 1`。Lua 的 `GetNormalizedTime()` 和 `IsAnimationFinished()` 使用相同语义。

**函数**：`abs(x)`, `min(x, y)`, `max(x, y)`, `clamp(x, min, max)`

**示例**：

```
"moveSpeed > 0.5"
"animationFinished and isGrounded"
"jump and weaponType == 0"
"isGrounded and stateTime > 0.5"
"not isGrounded and stateTime > 0.1"
"(animationFinished or moveSpeed > 0.5) and not isCrouching"
```

---

## .blendspace 文件格式

### BlendSpace1D — 单参数混合

用于 moveSpeed 驱动 Idle / Walk / Run 之间的平滑过渡：

```json
{
    "type": "BlendSpace1D",
    "name": "MovementBlendSpace",
    "parameter": "moveSpeed",
    "points": [
        { "value": 0, "animation": "uuid://待机动画uuid", "speed": 1.0 },
        { "value": 2, "animation": "uuid://行走动画uuid", "speed": 1.0 },
        { "value": 5, "animation": "uuid://奔跑动画uuid", "speed": 1.0 }
    ]
}
```

| 字段 | 说明 |
|------|------|
| `type` | 固定 `"BlendSpace1D"` |
| `parameter` | 驱动参数名（对应 FSM 的 parameters） |
| `points[].value` | 参数值 |
| `points[].animation` | 动画 uuid（推荐 `uuid://...` 格式） |
| `points[].speed` | 播放速度 |

### BlendSpace2D — 双参数混合

用于 direction + moveSpeed 驱动 8 方向移动动画：

```json
{
    "type": "BlendSpace2D",
    "name": "LocomotionPolar",
    "mode": "polar",
    "parameterX": "direction",
    "parameterY": "moveSpeed",
    "points": [
        { "x": 0.0,    "y": 0.0, "animation": "uuid://待机动画uuid",     "speed": 1.0 },
        { "x": 0.0,    "y": 2.0, "animation": "uuid://前行走uuid",       "speed": 1.0 },
        { "x": 0.0,    "y": 5.0, "animation": "uuid://前奔跑uuid",       "speed": 1.0 },
        { "x": 180.0,  "y": 2.0, "animation": "uuid://后行走uuid",       "speed": 1.0 },
        { "x": 180.0,  "y": 5.0, "animation": "uuid://后奔跑uuid",       "speed": 1.0 },
        { "x": -180.0, "y": 2.0, "animation": "uuid://后行走uuid",       "speed": 1.0 },
        { "x": -180.0, "y": 5.0, "animation": "uuid://后奔跑uuid",       "speed": 1.0 },
        { "x": 90.0,   "y": 2.0, "animation": "uuid://右行走uuid",       "speed": 1.0 },
        { "x": 90.0,   "y": 5.0, "animation": "uuid://右奔跑uuid",       "speed": 1.0 },
        { "x": -90.0,  "y": 2.0, "animation": "uuid://左行走uuid",       "speed": 1.0 },
        { "x": -90.0,  "y": 5.0, "animation": "uuid://左奔跑uuid",       "speed": 1.0 }
    ]
}
```

**mode 类型**：

| mode | 说明 | 适用场景 |
|------|------|---------|
| `polar` | 方向（-180~180 度）+ 速度 | 8 方向移动（最常用） |
| `triangulation` | Delaunay 三角剖分；共线点自动退化为 1D 线段插值 | UE 风格任意散点分布（推荐） |
| `gradient` | X/Y 两轴独立计算后合并，采样无精确覆盖时会回退到最近有效点 | 规则十字布局或兼容旧资源 |

**polar 模式 8 方向布点**：

```
              前 (0°)
              Walk(y=2) / Run(y=5)
              |
  左(-90°) ── Idle(0,0) ── 右(90°)
              |
              后 (±180°)
```

> 注意：后方(180°)和(-180°)使用相同动画，需要同时注册两个点。

### BlendSpace 运行语义

- BlendSpace 内部参数变化会平滑调整旧、新采样点权重；共享同一个过渡进度，淡出和淡入期间总权重保持为 1，不会经过 bind pose
- Animation、BlendSpace 之间四种组合都使用状态 `blendTime` / transition `blendTime`：Animation → Animation、Animation → BlendSpace、BlendSpace → Animation、BlendSpace → BlendSpace
- 过渡中再次切换状态时，引擎会保存当前屏幕上实际可见的完整混合结果，再从该结果过渡到新目标，不会退回前一个命名状态重新开始
- 同一 `.ani` 被不同状态或多个 BlendSpace 点复用时，各点由独立运行时身份管理，播放时间、权重和生命周期不会只按资源路径错误合并
- 参数应落在有效采样区域，所有带权重点的动画资源都必须可加载；资源错误会记录日志，不要依赖加载失败时的姿势作为运行逻辑

### syncGroup（循环相位同步）

把动作语义相同、循环起点已经对齐的状态放入同一个 `syncGroup`，可让 Walk/Run、空手/持枪移动等状态切换时继承归一化播放相位：

```json
"UnarmedMove": {
    "blendSpace": "FSM/UnarmedMove.blendspace",
    "loop": true,
    "syncGroup": "Locomotion"
},
"RifleMove": {
    "blendSpace": "FSM/RifleMove.blendspace",
    "loop": true,
    "syncGroup": "Locomotion"
}
```

`syncGroup` 当前只对齐 `normalizedTime`，尚不支持 Sync Marker。它不会自动识别“左脚落地”和“右脚落地”：如果两套动画在相同归一化时间处于相反步态，导出侧必须先把循环语义起点对齐。BlendSpace 中所有可能参与的样本都要满足这一约束。

---

## AimOffset

AimOffset 在各 layer 和状态过渡已经混合完成后，对当前姿势追加上半身瞄准旋转。使用资源驱动 AimOffset 时，角色节点除 `AnimatedModel`、`AnimationStateMachine` 外还要有 `AimOffset` 组件：

```lua
local fsm = node:GetOrCreateComponent("AnimationStateMachine")
node:GetOrCreateComponent("AimOffset")
```

`aimOffset` 可以写在 FSM 顶层、layer 或 state。生效优先级为 **state > layer > 顶层**；状态过渡时前后 AimOffset 配置与权重也会随 transition 一起混合。

```json
{
    "parameters": {
        "AimPitch": { "type": "float", "default": 0.0, "min": -90.0, "max": 90.0 },
        "AimYaw": { "type": "float", "default": 0.0, "min": -90.0, "max": 90.0 }
    },
    "aimOffset": {
        "weight": 1.0,
        "pitchParam": "AimPitch",
        "yawParam": "AimYaw",
        "blendSpace": "FSM/RifleStandAO.blendspace",
        "boneMask": "UpperBody"
    }
}
```

| 字段 | 说明 |
|------|------|
| `weight` | AimOffset 权重，范围 0-1 |
| `pitchParam` / `yawParam` | FSM 中的俯仰/偏航参数名，同时作为 BlendSpace 参数名 |
| `blendSpace` | `AimOffsetBlendSpace1D/2D` 资源路径；为空时走 AimOffset 组件的 procedural 模式 |
| `boneMask` | AimOffset 影响的骨骼范围，通常从 Spine 开始 |
| `parameterBindings` | 可选，`{ "BlendSpace参数": "FSM参数" }`，两边命名不一致时使用 |

以下为 Legacy Rotation Offset（Mesh Space）配置：资源提供**完整 Local Pose**，由引擎在运行时相对全局 Base Pose 计算旋转差。新 SharedSkeletonV1 原生 AimOffset 使用 [animationMetadata 基准](shared-skeleton-animation.md#原生-additive-与-aimoffset)，不要混用：

```json
{
    "type": "AimOffsetBlendSpace2D",
    "name": "RifleStandAO",
    "mode": "triangulation",
    "parameterX": "AimYaw",
    "parameterY": "AimPitch",
    "additiveSettings": {
        "mode": "rotationOffsetMeshSpace",
        "basePoseType": "animationFrame",
        "baseAnimation": "Animations/RifleStandBase.ani",
        "baseFrameIndex": 0
    },
    "points": [
        { "x": 0, "y": 0, "animation": "Animations/RifleAimCenter.ani" },
        { "x": -90, "y": 0, "animation": "Animations/RifleAimLeft.ani" },
        { "x": 90, "y": 0, "animation": "Animations/RifleAimRight.ani" },
        { "x": 0, "y": 90, "animation": "Animations/RifleAimUp.ani" },
        { "x": 0, "y": -90, "animation": "Animations/RifleAimDown.ani" }
    ]
}
```

`rotationOffsetMeshSpace` 只叠加 Component/Mesh Space 旋转，保留当前姿势的位置和缩放。`basePoseType` 支持 `referencePose`、`animationFrame`、`localAnimationFrame`；其中 `animationFrame` 必须同时提供 `baseAnimation` 和非负 `baseFrameIndex`。静态 AimOffset 不支持 `animationScaled`。旧的 `localSpaceDelta` / `meshSpaceDelta` 仍可读取，它们表示导出侧已经生成 delta 的资源。

Lua 每帧只需要更新 FSM 参数：

```lua
fsm:SetFloat("AimPitch", aimPitch)
fsm:SetFloat("AimYaw", aimYaw)
```

---

## Root Motion

Root Motion 分成两个独立决策：状态机决定如何处理动画根骨轨道，移动系统决定是否把提取结果提交给物理。配置只写在 state 上：

```json
"RunStop": {
    "animation": "Animations/RunStop.ani",
    "loop": false,
    "rootMotion": {
        "mode": "Extract",
        "rootBone": "Bip001",
        "channels": ["PositionX", "PositionZ", "Rotation"],
        "lockMode": "AnimationFirstFrame"
    }
}
```

| 字段 | 默认值 | 说明 |
|------|--------|------|
| `mode` | `KeepInPose` | `KeepInPose` 保留动画根骨运动但不输出 delta；`LockRoot` 锁定并丢弃选中通道；`Extract` 锁定选中通道并输出 `RootMotionDelta` |
| `rootBone` | Skeleton Root | 可显式指定 `Hips`、`Bip001` 等实际承载位移的骨骼 |
| `channels` | X、Z、Rotation | `PositionX`、`PositionY`、`PositionZ`、`Rotation` 可逐轴组合；Scale 不属于 Root Motion 通道 |
| `lockMode` | `AnimationFirstFrame` | `AnimationFirstFrame`、`ReferencePose`、`Zero`，决定 `LockRoot` / `Extract` 后骨骼锁到哪里 |

Legacy 的 `rootMotion` 未配置或显式 `mode: "KeepInPose"` 时，动画原有根骨位移会正常保留在姿势中，但状态机不会产生可供物理使用的 delta。共享骨架动画按 UE 分两层：状态 `mode` 只决定是否提取，动画自带的描述决定是否锁根，未配置时同样不提取。共享动画需要提取时写 `"rootMotion":{"mode":"Extract","useAnimationRootPolicy":true}`；只有显式写了 `rootBone`、`channels` 或 `lockMode` 且没有 `useAnimationRootPolicy` 时，才改用上表的状态锁根设置。`Extract` 产生的 delta 与 Pose 使用相同的 Animation/BlendSpace/过渡权重，状态机本身**不会直接移动角色 Node**。

标准 `CharacterComponent` 会兼容其找到的任意一个 `ICharacterController` 实现，包括 KCC 与 VoxelCharacterController。默认不消费 Root Motion；需要时显式开启：

```lua
character.applyRootMotion = true
character.applyRootMotionChannels =
    ROOT_MOTION_POSITION_X | ROOT_MOTION_POSITION_Z | ROOT_MOTION_ROTATION
```

默认不应用 Y，跳跃和重力继续由物理拥有。显式加入 `ROOT_MOTION_POSITION_Y` 后，物理后端会按 Root Motion 覆盖权重混合垂直目标速度，而不是在淡入淡出期间整步关闭重力。

自定义移动系统应在物理固定步中消费状态机队列，并把代码移动与 Root Motion 合成为**一次**控制器移动请求：

```lua
if fsm:HasRootMotionDelta() then
    local preview = fsm:PeekRootMotionDelta(fixedTimeStep)   -- 只读，不移除队列
    local delta = fsm:ConsumeRootMotionDelta(fixedTimeStep) -- 按时长消费
    -- delta.translation / delta.rotation 已包含动画贡献权重
    -- delta.positionWeights / delta.rotationWeight 表示各通道覆盖率
end

fsm:ClearRootMotionDeltas() -- 重置、传送或切换移动所有者时清队列
```

不要在 `Update` 中把 delta 直接叠到角色 Node：这会绕过 KCC/Voxel 碰撞查询，角色撞墙时可能先穿入再被物理推出。

---

## 后处理骨骼挂点

AimOffset 等通过 `AnimationPostProcess` 执行的动画后处理可能只把最终修正保存在 `Bone` 的后处理数据中，蒙皮会使用它，但 `bone.node.worldTransform` 仍是后处理前的 Node 变换。枪械、特效、命中点等普通 Node 如果只作为骨骼 Node 的子节点，就可能比皮肤晚一帧、没有贴手或没有跟随瞄准旋转。

此时使用 `Bone:GetFinalWorldTransform()`。它返回：

- 当前骨骼 Node 的世界变换
- 叠加本帧 AimOffset 等 `AnimationPostProcess` 后处理变换
- **不包含 inverse bind / `offsetMatrix`**，因此可以直接作为 socket/attachment 的世界变换基准
- 该骨骼没有后处理时，结果等同于普通骨骼 Node 的世界变换

普通 `Update` 发生在本帧动画和 worker 后处理提交之前，读取会落后一帧。对于状态机使用的 `rotationOffsetMeshSpace` AimOffset，后处理在 `AnimatedModel::Update()` 中准备完成，因此应在 `SceneDrawableUpdateFinished` 中读取：

> **Procedural AimOffset 的时序约束**：procedural 模式的 `AimOffset` 组件也在 `SceneDrawableUpdateFinished` 中应用修正，而同一事件的 handler 按订阅顺序执行。挂点 handler 必须在 `AimOffset` 组件进入 Scene 之后注册；如果之后才添加 AimOffset，或组件离开并重新进入 Scene，必须重新订阅挂点 handler，确保它排在 AimOffset 后面。否则仍可能读取到上一帧姿势。`rotationOffsetMeshSpace` BlendSpace 路径不受此订阅顺序影响。

```lua
---@type AnimatedModel|nil
local animatedModel
---@type Node|nil
local weaponNode
local weaponBoneName = "p_weapon_r"
local weaponAttachmentOffset = Matrix3x4.IDENTITY

local function ResolveWeaponBone()
    if animatedModel == nil then return nil end
    local bone = animatedModel:GetSkeleton():GetBone(weaponBoneName)
    if bone == nil or bone.node == nil then return nil end
    return bone
end

---@param modelNode Node
---@param attachedWeaponNode Node
function SetupWeaponAttachment(modelNode, attachedWeaponNode)
    animatedModel = modelNode:GetComponent("AnimatedModel")
    weaponNode = attachedWeaponNode
    if animatedModel == nil or weaponNode == nil then return end

    local weaponBone = ResolveWeaponBone()
    if weaponBone == nil or weaponBone.node == nil then return end

    -- 武器作为骨骼子节点时，保存美术配置好的局部挂点偏移。
    weaponAttachmentOffset = weaponNode:GetTransform()
    SubscribeToEvent(modelNode:GetScene(), "SceneDrawableUpdateFinished",
        "HandleWeaponAttachmentAfterAnimation")
end

function HandleWeaponAttachmentAfterAnimation(eventType, eventData)
    if weaponNode == nil then return end

    -- 每帧重新解析，避免模型替换或 Skeleton 热重载后持有悬垂的 Bone 引用。
    local weaponBone = ResolveWeaponBone()
    if weaponBone == nil then return end

    local finalTransform = weaponBone:GetFinalWorldTransform() * weaponAttachmentOffset

    -- Lua 的 Node:SetWorldTransform 没有 Matrix3x4 重载，需要拆成三个参数。
    weaponNode:SetWorldTransform(
        finalTransform:Translation(),
        finalTransform:Rotation(),
        finalTransform:Scale())
end
```

如果武器初始不是目标骨骼的直接子节点，可在正确摆放后计算一次偏移：

```lua
local weaponBone = ResolveWeaponBone()
if weaponBone ~= nil then
    weaponAttachmentOffset =
        weaponBone:GetFinalWorldTransform():Inverse() * weaponNode:GetWorldTransform()
end
```

不要跨帧缓存 `Bone`。`Skeleton:GetBone()` 返回 Skeleton 内部骨骼数组元素的裸指针；模型或 Skeleton 被替换、清空、移动或热重载后，旧引用会成为悬垂指针，继续调用可能造成 use-after-free 和崩溃。上面的 handler 因此每帧按名称重新获取 Bone。模型替换后还要重新计算 attachment offset；如果整个 `AnimatedModel` 组件被替换，则重新执行 `SetupWeaponAttachment()`。

不要把 `Bone.offsetMatrix` 当挂点矩阵：它是蒙皮 inverse bind 数据，会把物体变换到错误空间。

---

## Lua API

> **最佳实践**：通过 `.fsm` 配置文件定义状态和过渡，Lua 代码只负责加载 FSM 和喂参数。不建议在 Lua 中用 `AddStateFromPath`/`AddTransition` 等 API 动态构建状态机——配置文件更直观、易维护，也便于复用。

### 加载和启动

```lua
-- 节点已有 AnimatedModel；状态机不依赖 AnimationController
local fsm = node:GetOrCreateComponent("AnimationStateMachine")

-- 从文件加载
local jsonFile = cache:GetResource("JSONFile", "FSM/Character.fsm")
fsm:LoadFromJSONFile(jsonFile)

-- 启动（进入默认状态）
fsm:Start()
```

### 每帧更新参数

```lua
function HandleUpdate(eventType, eventData)
    fsm:SetFloat("moveSpeed", character:GetMoveSpeed())
    fsm:SetBool("isGrounded", character:IsOnGround())

    -- trigger 只在需要时调用（会自动重置）
    if jumpPressed then
        fsm:SetTrigger("jump")
    end
end
```

### 查询状态

```lua
fsm:GetCurrentState(0)          -- 层 0 当前状态名
fsm:IsInState("Locomotion", 0)  -- 是否在某状态
fsm:IsAnimationFinished(0)      -- 当前动画是否播完
fsm:GetStateTime(0)             -- 当前状态已播放秒数
fsm:GetNormalizedTime(0)        -- 归一化时间 0-1
fsm:IsTransitioning(0)          -- 是否正在过渡
fsm:ForceState("Locomotion", 0) -- 强制切换（跳过过渡）
```

### 层权重控制

```lua
fsm:SetLayerWeight(2, 0.5)   -- 按层索引设置权重（层索引从 0 开始）
```

---

## 进阶：多层 FSM

多层 FSM 让不同身体部位同时播放不同动画。

典型架构（参考 `examples/22-third-person-shooter`）：

| 层 | 名称 | boneMask | 用途 |
|----|------|----------|------|
| 0 | Base | 无（全身） | 移动、跳跃 |
| 1 | LowerBody | LowerBody | 持枪时下半身跳跃 |
| 2 | UpperBody | UpperBody | 射击、换弹、近战 |
| 3 | FullBody | 无（全身） | 表情、死亡（最高优先级） |

**关键设计**：
- 不需要播放动画的层用 `"empty": true` 空状态作为默认
- FullBody 层的 die 过渡用 `"from": "*"` + 最高 priority，确保任何状态都能触发
- UpperBody 层切换武器类型时，通过条件表达式 `weaponType == 1` 选择对应动画
- layer 按数组顺序合成；上层通过 `boneMask` 限定影响范围，`blendMode: "additive"` 用于叠加式后坐力等动画
- 攻击、换弹等临时动作也应建成独立 layer/state，不要绕过 FSM 调用 `AnimationController:Play()`

---

## 官方模板

`engine-docs/recipes/templates/fsm/` 目录下提供了开箱即用的模板：

| 文件 | 说明 |
|------|------|
| `StandardLocomotion_Template.fsm` | FSM 模板，将 `$PLACEHOLDER$` 替换为实际动画 uuid |
| `MovementBlendSpace1D_Template.blendspace` | 1D 混合空间模板（前后移动） |
| `MovementBlendSpace2D_Polar_Template.blendspace` | 2D Polar 混合空间模板（8 方向移动） |

---

## 常见问题

| 问题 | 解决方案 |
|------|---------|
| 状态不切换 | 检查 condition 表达式是否正确，确认参数每帧更新 |
| 动画不播放 | 确认同一节点或子节点有 AnimatedModel、已调用 `fsm:Start()`，并检查动画/BlendSpace 资源加载日志；FSM 不要求 AnimationController |
| 多层动画冲突 | 检查 boneMask 是否正确配置，检查层 weight |
| trigger 不触发 | trigger 触发后自动重置，确保在正确时机调用 SetTrigger |
| BlendSpace 动画抖动 | 检查参数值范围是否与 points 的 value/x/y 匹配 |
| BlendSpace 切状态后从头迈步 | 给语义相同且循环起点一致的状态配置相同 `syncGroup` |
| 同组动画左右脚仍相反 | 当前没有 Sync Marker；导出侧必须对齐循环语义起点和所有 BlendSpace 样本 |
| AimOffset 不生效 | 确认节点有 AimOffset 组件，参数名、boneMask、BlendSpace 和 Base Pose 配置正确 |
| 枪械没有贴手或比 AimOffset 慢一帧 | 在 `SceneDrawableUpdateFinished` 用 `Bone:GetFinalWorldTransform()` 驱动挂点，不要只读取骨骼 Node transform；procedural AimOffset 还要保证挂点 handler 后订阅 |
| 配了 Extract 但角色不移动 | 状态机只输出 delta；启用 `CharacterComponent.applyRootMotion`，或在自定义物理固定步中消费 delta |
