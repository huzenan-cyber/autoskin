# Graphics Module

## Classes

`Graphics` · `Renderer` · `Camera` · `Light` · `Zone` · `Skybox` · `StaticModel` · `AnimatedModel` · `Skeleton` · `Bone` · `StaticModelGroup` · `Model` · `Material` · `Technique` · `Texture` · `Texture2D` · `TextureCube` · `Drawable` · `Octree` · `Viewport` · `RenderPath` · `BillboardSet` · `CustomGeometry` · `DecalSet` · `RibbonTrail` · `Terrain` · `VideoPlayer` 等

详细 API 见 `.emmylua/Camera.d.lua`、`.emmylua/Light.d.lua`、`.emmylua/StaticModel.d.lua` 等。

## ComputeDispatch / ComputeBuffer / ComputeReadback

GPU 计算使用 `ComputeDispatch` 调度 `shader_type compute` 的 `.shader`；通过 `ComputeBuffer`
共享数组数据，通过 `ComputeReadback` 异步读取快照。完整 shader/Lua 示例、接口与设备限制见
[Compute addon](../recipes/surface-shader-addons/compute.md)，
类型签名见 `.emmylua/ComputeDispatch.d.lua`。

## AnimatedModel / Skeleton / Bone

```lua
local model = node:GetComponent("AnimatedModel")
local bone = model:GetSkeleton():GetBone("p_weapon_r")
local finalBoneWorld = bone:GetFinalWorldTransform()
```

`Bone:GetFinalWorldTransform()` 包含本帧 `AnimationPostProcess` 修正，但不包含蒙皮 inverse bind 矩阵，适合驱动武器、特效等骨骼挂点。需要读取同帧最终结果时，应在 `SceneDrawableUpdateFinished` 事件中调用；procedural AimOffset 还要求挂点 handler 在 AimOffset handler 之后订阅。不要跨模型替换缓存 `Bone` 裸指针。完整时序约束、生命周期、offset 计算和 `Node:SetWorldTransform` 示例见 [动画状态机指南：后处理骨骼挂点](../recipes/state-machine.md#后处理骨骼挂点)。
