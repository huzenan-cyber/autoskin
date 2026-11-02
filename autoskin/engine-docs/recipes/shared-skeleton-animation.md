# 多个体型共享动画

同名、同层级骨骼的角色，可以使用一份动画、BlendSpace 和 FSM 配置。每个角色仍拥有自己的播放进度、参数和状态。需要使用支持 `SharedSkeletonV1` 的 Runtime、Editor 和资产工具；旧资产升级引擎后继续按原方式播放，无需重新导出。

## 准备资源

美术或资产工具需要提供一套配套资源：

- 每个角色自己的 `.mdl`，包含自身的参考姿态、蒙皮绑定和共享 Skeleton 关联。
- 一份 `.skeleton`，保存骨骼名称、层级、原始参考姿态、每骨骼平移规则及命名制作来源。
- 带 SharedSkeletonV1 描述的 `.ani`，保存制作来源与原生 Additive 基准；需要外部基准时一并提供其 `.ani`。
- 指向这些动画的 `.blendspace` 和 `.fsm`。消费模型、动画和 Skeleton 必须使用相同坐标表示与 Skeleton 身份。

仅骨名相同不等于已配置共享关联。给旧模型关联 Skeleton 也不会将旧动画自动升级；不要通过手改标签把已经重定向或经过旧 Additive 补偿的数据冒充原生资产。新资产可由 UE 导出器（默认共享模式）生成，由 Editor 导入蒙皮 FBX 时默认生成，或由 UrhoXCLI `import-model` 加 `--shared-skeleton` 生成；当前 glTF 蒙皮导入不可用。

## 播放与换角色

沿用 [动画状态机](state-machine.md) 的流程：为每个角色设置各自的 AnimatedModel，加载同一个 FSM，然后更新各自参数。`.fsm` 和 `.blendspace` 无需为每个体型复制。普通动画也可沿用 AnimationController 的播放方式；不要让 Controller 和 FSM 同时驱动同一个模型。

运行时会在每个动画样本采样后、姿态混合前，根据制作来源与目标模型参考姿态执行骨骼规则。脚本不需要提供来源模型、计算骨长比例或复制关键帧。制作来源模型不是运行时必需资源。

换模型沿用既有播放约定：骨骼布局兼容时保留状态并更新绑定；需要重建骨骼时清除原 AnimationState，直接播放器需要重新发起播放。空骨架不能提前创建播放状态。游戏仍需处理材质、碰撞体、武器挂点等角色差异；不要跨模型切换缓存 `Bone` 指针，挂点方法见 [后处理骨骼挂点](state-machine.md#后处理骨骼挂点)。

不同体型不一定产生不同平移：`Animation` 模式保留动画平移，`Skeleton` 使用目标参考平移，其他模式按规则调整。规则由美术在 Skeleton Editor 中配置，不要在玩法层额外乘一次骨长系数。共享动画也不会自动解决脚滑、步幅、握持点或不同拓扑匹配。

## 原生 Additive 与 AimOffset

原生 Local Additive 应放在 FSM 的 `blendMode: "additive"` 层；直接播放创建原生增量状态时默认使用 Additive。不要强制改成普通覆盖层。动画的绝对样本与基准各自适配目标后，由引擎求差并累加，玩法不再额外减绑定姿态。

原生 AimOffset 继续使用 AimOffset 组件和 FSM 的瞄准参数。对应 BlendSpace 的设置为：

```json
"additiveSettings": {
    "mode": "rotationOffsetMeshSpace",
    "basePoseType": "animationMetadata"
}
```

每个样本的基准由动画描述决定，不再填写一份全局 `baseAnimation` 或 `baseFrameIndex` 覆盖它。模型空间增量使用模型空间旋转，平移和缩放也会按各自增量累加；它与旧的仅旋转 AimOffset 配置不同。

同一 BlendSpace 或状态过渡中的有效样本必须使用相同姿态编码；绝对姿态、Local 增量和模型空间增量不能混在同一个表达式中。旧与新动画可放在不同层，旧配置保留原行为。旧的 `meshSpaceDelta` 资源不能当成新格式的绝对样本再次求差。

瞄准姿态是静态的，引擎在动画第一帧采样样本及其基准，没有外部时间参数。固定帧基准的换算由资源工具负责，不等同于 FSM 的按帧裁剪。

共享动画的根运动分两层：状态 `rootMotion.mode` 决定是否提取，动画自带的描述决定是否锁根。状态不写根配置时等同 `KeepInPose`：不提取，动画要求强制锁根时仍会锁定。需要提取时写 `"rootMotion":{"mode":"Extract","useAnimationRootPolicy":true}`，UE 新导出的状态已经这样写。只有显式写了运动骨骼、轴过滤或锁定模式且不带 `useAnimationRootPolicy` 时，才改用状态自己的锁根设置。直接 Controller 没有根运动消费者，资产 enabled 不会自动移动角色。移动系统仍按 [Root Motion](state-machine.md#root-motion) 消费运动；不要再次按体型缩放提取结果。

## 构建与下载

使用项目正常构建流程。ProjectBuilder 会从模型和动画同名的 `.xml` 收集 Skeleton 和外部基准依赖，无需手工复制制作来源模型。`.skeleton` 按定义资源在脚本启动前预下载，没有空占位；不要把它排除出发布包。启动后才新增的远端骨架，须先通过 `cache:DownloadResource` 确认成功，再加载和绑定。

普通 `.ani` 和外部 Additive 基准动画沿用边玩边下。下载中的动画先按占位数据播放，到达后自动切换为共享播放；外部基准还在下载时，只有用到它的样本暂不生效。Skeleton 与模型属于启动阻塞依赖；骨架加载失败会在加载模型或动画时明确报错，不会等待它稍后出现。修复文件后重新加载对应模型和动画，再重新创建播放状态。已加载 Skeleton 的规则编辑和正常热重载仍会更新绑定。

当前后台替换的进度和失败状态不能完整反馈给播放器。要求首帧正确播放时，先按 [边玩边下](download-while-playing.md) 的预下载流程准备完整模型、动画、Skeleton 和 Additive 基准，确认下载成功后再创建播放器。热重载失败可能继续使用旧数据，不能仅凭播放器状态判断下载或重载是否成功。若一直不能播放，检查下载结果、共享身份、坐标表示和层编码；不要通过手动烘焙掩盖依赖问题。

## 引用与设置（同名 .xml）

共享模型和动画的 Skeleton 引用、命名来源、Additive 基准和根运动设置写在与资源同名的 `.xml` 里，可以直接查看和编辑：

```xml
<animation>
    <sharedskeleton skeleton="uuid://EyVKgWPsr_Zj_gU1UsYGgYIP" retargetsource="">
        <additive type="none" />
        <rootmotion enabled="false" forcerootlock="false" rootlock="referencepose" usenormalizedrootmotionscale="false" />
    </sharedskeleton>
</animation>
```

- `skeleton`、`baseanimation` 可写 `uuid://` 或资源根下的相对路径。导入默认写 `uuid://`，移动或改名 `.skeleton` 时连同 `.meta` 一起移动即可。
- 移动、复制、删除 `.mdl` / `.ani` 时，同名 `.xml` 必须一起处理；共享资源缺少它或其中没有 `<sharedskeleton>` 会加载失败。该 `.xml` 在启动前下载，发布包会自动带上。
- 同一目录下不要让共享模型和共享动画同名（如 `Move.mdl` 与 `Move.ani`）：两者会共用同一个 `.xml`，后保存的一方会覆盖对方的设置，模型随之无法加载。把动画放到单独的目录即可。
- 只在 `.xml` 里加 `<sharedskeleton>` 不能把旧资源变成共享资源。
- 修改后可用 `UrhoXCLI model-info -i <mdl>` 或 `anim-info -i <ani>`（加 `--resource-root <资源根>` 检查引用）确认 `Status: OK`。

## 保留旧用法与迁移

已有 Legacy 资源保持原样，按 Legacy 导入的资源重导入后仍是 Legacy；旧 Play/FSM 调用继续有效。需要旧格式时，Editor 导入取消 Shared Skeleton 选项，UrhoXCLI 默认即为 Legacy，UE 导出选择 Legacy。需要迁移时，先导出到独立目录，保留原资源及引用；在多个体型上验证普通动画、Additive、根运动，再更新场景/FSM 引用。

Editor 的共享 Root/FK 输出仅适用于其明确支持的普通动画；原生 Additive 或启用的资产根策略会被拒绝，应从真实制作数据重新导出。回退需恢复配套模型、动画、图和引用，不能靠删除共享描述恢复原始关键帧。使用 FBX 重导入时同时保留 `.sharedimport` 编辑器记录，运行时打包不需要该记录。
