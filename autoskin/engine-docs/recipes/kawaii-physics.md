# 次级骨骼运动 KawaiiPhysics（预览版）

`KawaiiPhysics` 组件移植自 [KawaiiPhysics](https://github.com/pafuhana1213/KawaiiPhysics) v1.21.0，让头发、尾巴、胸臀、飘带、骨骼裙摆产生惯性和回弹。用法与上游一致：方法使用相同API命名，具体类型和枚举额外附加 `KawaiiPhysics` 前缀。单位米，Y 向上。

**AI心智**：本文没写到的参数含义、默认值和行为（Alpha、子步、预热、瞬移阈值、取值范围等）都与上游 KawaiiPhysics 一致，只换算成米；属性存取、启用禁用与普通 Urho 组件一致。本文只写 UrhoX 里不同或需要配合的地方。

把它加到 **`AnimatedModel`、`AnimationController` 所在节点** 自动运行。

完整签名、枚举、字段、序列化属性名见 [KawaiiPhysics.d.lua](../../.emmylua/KawaiiPhysics.d.lua) 和 [FloatCurve.d.lua](../../.emmylua/FloatCurve.d.lua)。本文说明如何搭配使用。完整示例见 [嗒啦啦角色展示](../../examples/33-tarara-character-studio/README.md)。角色动画与挂件时序见 [动画状态机](state-machine.md)。

## 先跑一条尾巴

```lua
-- characterNode owns an AnimatedModel and an AnimationController.
local physics = characterNode:CreateComponent("KawaiiPhysics")
physics:SetRootBoneName("TailRoot") -- a bone of the skeleton

local settings = physics:GetPhysicsSettings()
settings.damping = 0.12
settings.stiffness = 0.12
settings.worldDampingLocation = 0.35
settings.radius = 0.035
settings.limitAngle = 65
physics:SetPhysicsSettings(settings) -- getters return copies; set them back
physics:SetGravity(Vector3(0, -2.5, 0))

local stiffness = FloatCurve()
stiffness:AddKey(FloatCurveKey(0, 1.0, FLOAT_CURVE_CUBIC))
stiffness:AddKey(FloatCurveKey(1, 0.25, FLOAT_CURVE_CUBIC))
physics:SetStiffnessCurveData(stiffness)
```

调校起点（米制）：

| 部位 | damping / stiffness | 半径 | limitAngle | 世界重力 | 空间 |
|---|---|---|---|---|---|
| 约 1 米、6 骨头发 | 0.14 / 0.06 | 0.025 | 75° | `(0,-9.81,0)` | World |
| 胸臀，约 0.22 米骨段 | 0.18 / 0.30 | 0.015 | 25° | `(0,-0.6,0)` | BaseBone |
| 约 1 米、6 骨尾巴 | 0.12 / 0.12 | 0.035 | 65° | `(0,-2.5,0)` | Component |

## 模拟空间和多个根

```lua
physics:SetSimulationSpace(KAWAII_PHYSICS_SIMULATION_BASE_BONE_SPACE)
physics:SetSimulationBaseBoneName("Chest")

-- Extra roots share this component's settings, curves and limits.
local right = KawaiiPhysicsRootBoneSetting()
right.rootBone = "Breast_R"
physics:AddAdditionalRootBone(right)
```

需要不同参数的骨链，就各建一个组件。

## 碰撞体

```lua
local sphere = KawaiiPhysicsSphericalLimit()
sphere.drivingBone = "Chest"
sphere.offsetLocation = Vector3(0, 0.05, 0)
sphere.radius = 0.18
physics:AddSphericalLimit(sphere)

local capsule = KawaiiPhysicsCapsuleLimit()
capsule.drivingBone = "Chest"
capsule.offsetRotation = Quaternion(Vector3.FORWARD, Vector3.UP) -- capsule axis is local Z
capsule.radius = 0.12
capsule.length = 0.3
physics:AddCapsuleLimit(capsule)

local box = KawaiiPhysicsBoxLimit()
box.drivingBone = "Pelvis"
box.extent = Vector3(0.15, 0.1, 0.12) -- half size
physics:AddBoxLimit(box)

local ground = KawaiiPhysicsPlanarLimit() -- empty drivingBone: component-space ground
physics:AddPlanarLimit(ground)
```

胶囊轴和平面法线都是局部 Z。它们只挡本组件的骨骼，不和场景 `RigidBody` 碰撞。

## 骨骼裙摆：细分、约束、SyncBone

```lua
physics:SetBoneSubdivisionCount(2) -- dummy bones between bones, so limits cannot slip through

local c = KawaiiPhysicsModifyBoneConstraint() -- keep two chains together
c.bone1 = "Skirt_F_2"
c.bone2 = "Skirt_L_2"
physics:AddBoneConstraint(c)
physics:SetBoneConstraintGlobalComplianceType(KAWAII_PHYSICS_XPBD_COMPLIANCE_LEATHER)
physics:SetBoneConstraintSubdivisionCount(2) -- dummy bones between the two chains

-- Push the skirt with the thigh so the leg does not pass through.
local target = KawaiiPhysicsSyncTargetRoot()
target.bone = "Skirt_F_1"
target.includeChildBones = true
local sync = KawaiiPhysicsSyncBone()
sync.bone = "Thigh_L"
sync.applyDirectionZ = KAWAII_PHYSICS_SYNC_BONE_DIRECTION_POSITIVE
sync:AddTargetRoot(target)
physics:AddSyncBone(sync)
```

假骨只用来挡碰撞，不写进骨架。

## 曲线和外力

```lua
local curve = physics:GetStiffnessCurveData()
local key = curve:GetKey(0) -- zero-based
key.tangentMode = FLOAT_CURVE_TANGENT_BREAK
key.leaveTangent = -0.5
assert(curve:SetKey(0, key))
physics:SetStiffnessCurveData(curve)

physics:SetSimpleExternalForce(Vector3(0.3, 0, 0)) -- m/s, world space by default
```

曲线横轴是根到骨骼的长度比例（0～1），纵轴是基础参数的倍率。

## 序列化

属性名和顺序同上游节点属性，对照见 .d.lua 注释里的 `Serialized as "属性名"`。组件不参与网络同步。

配置可以两种方式产出：

- 手写：不碰代码，直接按下面的格式在 Prefab 或场景 XML 里写 `<component type="KawaiiPhysics">`。
- 代码配好再存：已有配置代码时，用 `UrhoXRuntime` 在本地单独跑一段脚本，建好节点后存成 Prefab。脚本写法见 [程序化 / 离线 Lua](procedural-lua-headless.md)。

```lua
-- Run once offline: build the node with the existing setup code, then save it.
local file = File(node:GetContext(), path, FILE_WRITE)
assert(node:SaveXML(file))
file:Close()
```

和上游不同的地方：

- 上游的 `PhysicsSettings` 结构拆成 `Damping`、`Stiffness`、`World Damping Location`、`World Damping Rotation`、`Radius`、`Limit Angle` 六个属性。
- `Use Fixed Substepping`、`Max Substeps` 是本引擎新增，排在最后。
- 曲线直接存关键点，没有上游 `FRuntimeFloatCurve` 的 `EditorCurveData` 一层；`Tension` 是本引擎新增。

```xml
<component type="KawaiiPhysics">
  <attribute name="Root Bone" value="hair_a_01" />
  <attribute name="Bone Forward Axis" value="X_Negative" />
  <attribute name="Stiffness" value="0.3" />
  <attribute name="Stiffness Curve Data" type="FloatCurve">
    <attribute name="Keys">
      <variant type="FloatCurveKey">
        <attribute name="Value" value="1" />
        <attribute name="Interp Mode" value="Cubic" />
      </variant>
      <variant type="FloatCurveKey">
        <attribute name="Time" value="1" />
        <attribute name="Value" value="0.2" />
        <attribute name="Interp Mode" value="Cubic" />
      </variant>
    </attribute>
  </attribute>
  <attribute name="Spherical Limits">
    <variant type="KawaiiPhysicsSphericalLimit">
      <attribute name="Driving Bone" value="Head" />
      <attribute name="Radius" value="0.1" />
    </variant>
  </attribute>
</component>
```

易错点：XML 里枚举写存盘名，不是 Lua 常量名。例如 `FLOAT_CURVE_CUBIC` 存为 `Cubic`，`KAWAII_PHYSICS_BONE_FORWARD_X_NEGATIVE` 存为 `X_Negative`；每个枚举值的存盘名见 .d.lua 注释里的 `Serialized as`。

## 读取结果和排查

- 模拟只改最终蒙皮姿态，骨骼 `Node` 保持动画姿态，挂在骨骼节点上的物体不会跟着甩。要读模拟后的位置，用 `Bone:GetFinalWorldTransform()`，在 `PostRenderUpdate` 里读。
- 包围盒按动画姿态算，不含模拟偏移。长飘带甩出去后可能被提前裁掉；需要时放大对应 `Bone` 的 `boundingBox` 或 `radius`。
- 没效果时先看 `GetDiagnostic()`：它会写出找不到的根骨骼、互相重叠的根、找不到的驱动骨，以及还在等模型加载。
