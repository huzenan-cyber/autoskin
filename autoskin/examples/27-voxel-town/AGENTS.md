# VoxelTown — 官方体素物理脚手架

**这是什么**:一个完整可玩的可破坏小镇沙盒,展示体素物理系统的全部玩法能力,
同时是新体素游戏项目的**起点模板**(复制本目录即开工)。

**This is** the official voxel-physics scaffold: a playable destructible town sandbox
exercising every gameplay capability, meant to be copied as the starting point of a new
voxel game project.

## 运行

```
UrhoXRuntime.exe main.lua -deferred -tapcode_dir=C:\Workspace\SCE\UrhoX_Workspace2\engine\bin\Data\LuaScripts\Hand-picked\VoxelTown -editor_debug=C:\Workspace\SCE\UrhoXRes -skip_login
```

运行示例中的 `-deferred` 由玩家按需选择。样例沿用当前渲染管线,水坑效果需要支持 GBuffer 后处理的延迟渲染管线。
English: Players choose the rendering pipeline; add `-deferred` to enable the deferred path needed by puddles.

## 玩法

- `N`:昼夜切换——白天(TownDay 光组+晴空渐变天)/ 夜晚(TownNight 光组:
  月光 CSM + 夜空 + 八盏路灯暖色点光注入体积雾)。两套光组均为项目本地 XML,
  程序化渐变天空来自 urhox-libs SkyUtils(地平线色==雾色,零接缝)
- `P`:街道水坑开关,默认开启,昼夜切换后保持状态。出生点前方的十字街道可直接对照:
  水坑应随相机移动保持原位,路面变暗并产生光滑反射,墙面与屋顶不受影响。
  实现为 Zone 注册的 `assets/Shaders/BLGL/Puddles.shader` GBuffer 后处理,
  仅按世界高度/法线/街道范围筛选,不是额外水面几何。`config.lua` 可调覆盖率、尺寸和粗糙度。
  `RAIN_EXPOSURE` 当前固定为 1,尚无屋檐遮雨或随时间积水;路面炸掉后不补出悬空水面。
  English: P toggles world-space street puddles; the state survives day/night changes. Rain occlusion is not implemented.
- 步行:**第三人称**,WASD + Shift 跑 + Space 跳,鼠标环绕;`Q` 循环实际工具,
  工具同步驱动统一武器 FSM,`C` 蹲伏,`R` 换弹;靠近载具按 `F` 上车
  (驾驶时使用第三人称追尾相机)
- 载具:皮卡(前轮转向)、推土机(前轮转向+硬化铲刀)、挖掘机(滑移转向 +
  Q/E 转舱、Z/X 大臂、C/V 斗杆、G 挖掘,关节带真限位)
- **Assembly 解体车**:底盘、前后保险杠、左右车门和车顶笼是六个独立
  `VoxelVolume`,装配后共用一个刚体;高速撞上路口黄黑防撞墙会通过 member
  stress 自动撞掉直接命中的覆盖件。焊点仅由 `breakForce` / `breakTorque`
  参数控制；Lua 不监听碰撞、不注入补偿载荷，普通路面冲击由承力底盘吸收。
  可正常靠近按 `F` 驾驶,也可随时按 `B` 以 13m/s 发射,用于确定性演示
  `VoxelAssembly` façade、compound member 接触冲量归属、断裂阈值、脱离
  事件和脱离后的独立物理。
- **Assembly 实体轮车**:车身由多个 `VoxelVolume` 合成 Assembly，四个轮胎
  是带 Cylinder 代理和 `VoxelRollingContact` 的真实动态体；左右前轮各自挂在
  Y 轴铰链转向节上，四轮由 Z 轴铰链速度马达驱动；每个轮端先通过独立的垂直
  Slider 线性弹簧连接底盘，吸收崎岖路面的行程。它不使用 `VoxelVehicle` 射线轮，
  完整展示“单轮悬挂 + 独立转向节 + 驱动轮轴 + 轮胎”的 gameplay 组装路径。
- **Assembly 直升机**:机身、座舱、尾梁、尾翼、双滑橇和旋翼桅杆是独立
  `VoxelVolume` member，共享一个机身刚体并按应力脱落；主旋翼保持为第二个
  动态体，通过 `VoxelConstraint` 铰链马达真实旋转，尾旋翼挂在可脱落尾翼上。
  飞行力统一作用于机身 Assembly，主旋翼受损会按剩余体素比例失去升力。
- 工具(步行时数字键选择,左键使用):`1` 炸药(掷出+引信+冲量)
  `2` 散弹枪(8 线小坑) `3` 喷漆(染色体素) `4` 喷枪(持续挖掘);
  三种枪类工具均切换步枪姿态并同步射击动画
- 右键按住:枪类工具瞄准;炸药状态拖拽动态物体(引擎抓取约束)
- 街边的车、消防栓、垃圾桶、雕像都是动态可破坏物;房子炸塌会分裂成碎块;
  街道硬度 6(炸药炸得开坑,散弹枪啃不动);两座土堆什么都挖得动
- **海湾**(东三分之一,x>30):引擎全局水面(浮力按密度自动:木浮石沉)。
  栈桥边小艇、湾心大游艇,`F` 登船,W/S 桨推 A/D 尾舵(通过 VoxelVolume
  `ApplyForce` 脚本推进,浮力引擎托底);**游艇被炸破船体会进水下沉**(完好度→浮力衰减,
  vehicles.UpdateAll),沉船机制的参考实现
- 光照/雾:`assets/LightGroup/TownDay.xml`(CSM 阴影、UE 曝光/泛光、距离雾、
  全局体积雾 Absorption=0);天空盒 `assets/Materials/TownSky.xml`。教训:
  LocalFogVolume 雾团别摆在主视线走廊上,50m 宽的雾团在中景 = 远处灰蒙蒙

## 结构(tapcode_dir 布局)

```
scripts/
├── main.lua       入口:环境、世界、装配、主循环、HUD
├── config.lua     调色板槽位/硬度、手感参数(改数值先来这)
├── town.lua       地面 + 摆放表(加建筑/道具改这里的表即可)
├── vehicles.lua   可驾驶载具 + VoxelAssembly 解体车/直升机参考实现
├── player.lua     CharacterComponent + VoxelCharacterController + 统一 FSM + 第三人称相机
├── game/           角色统一状态机管理
├── FSM/            武器/蹲伏/方向移动状态机与 BlendSpace
└── tools.lua      玩法配方工具箱(炸药/散弹/喷漆/挖掘/拖拽)
assets/models/     mmmm 社区模型(见 ATTRIBUTION.md)
```

## 接手须知

- 系统设计文档:`docs/design/voxel-physics/`(架构/载具/关节/数据层/API);
  路线与待办:`docs/plans/voxel-physics/README.md`
- 调色板纪律:`config.ApplyPalette` 必须先于任何 `.vox` 导入执行
  (导入自动认领空槽);手建体积用 1-19,导入模型的槽位自动分配
- `scripts/FSM/` 保存统一 FSM 与 BlendSpace 配置;其中动画使用 UUID 引用,
  本地调试必须通过 `-editor_debug=C:\Workspace\SCE\UrhoXRes` 提供动画资源
- 悬挂三铁律、马达符号约定等见 `docs/design/voxel-physics/vehicle-system.md`
  ——都是实测定的,别按直觉改
- 加新载具:抄 `vehicles.lua` 的现成结构;加新武器:抄 `tools.lua` 的配方
- mmmm 模型库还有 450+ 个模型可选(建筑变体/更多道具/角色),下载即用:
  `https://raw.githubusercontent.com/mikelovesrobots/mmmm/master/vox/<name>.vox`
