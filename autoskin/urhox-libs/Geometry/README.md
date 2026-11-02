# Geometry 库（已弃用）

> ## ⚠️ 新代码请勿使用
>
> 引擎已内置 **three.js 兼容的程序化几何体 API**（C++ 侧生成顶点，28 种形体），
> 覆盖了本库的**全部形状**，且单个形体内部的绕序与正面朝向不用操心 —— 那是本库最容易踩的坑。
>
> 但**不是全部用途**：新 API 不产生顶点色，也给不了本库的几种封口（半球的 Y=0 切面、圆锥的
> 混合 cap、扇形的两端径向面）。**朝向也仍要操心**：一部分目标 API 在 XY 平面，需要旋转。
> 迁移前请读完 `Primitives.lua` 头部的必查差异清单。
>
> **→ `engine-docs/recipes/procedural-geometry.md`**
>
> 本库保留只为不破坏线上已发布的游戏：`urhox-libs` 由 engine-res 动态下发，老游戏快照的是
> 引用而非资源本体，删除会让它们运行时 `require` 失败。真正移除的前提是 urhox-libs 支持
> 多版本共存（P3，见 `docs/guides/technical-debt.md`）。
> `require` 时会打一条 `LOG_WARNING`，便于从线上日志发现仍在使用的项目。

## 迁移映射

⚠️ **迁移不是文本替换，且差异不止一类。**

**完整的目标 API 与差异清单在 [`Primitives.lua`](Primitives.lua) 头部注释里，那里是唯一真源，
本文不复述、也不给摘要。**

之所以连摘要都不留：本 PR 的 review 里，这份映射连续四轮出问题（行号漂移 → 前置条件写反 →
封口语义丢失 → 类别计数三处互不一致），每一轮的成因都是「同一口径存在多份拷贝」。它与
`Primitives.lua` 的实现细节强耦合（`height` 默认值、cap 是否独立、切面是否生成、有无顶点色），
只有放在实现旁边才不会各自腐烂。

## 维护既有代码时

本库默认材质是 `DiffVCol.xml`（顶点颜色 + 漫反射光照）。换 PBR 走 `technique` 选项，
着色器参数得拿到 material 自己设：

```lua
local geom = Primitives.Hemisphere(node, {
    radius = 0.5,
    technique = "Techniques/PBR/PBRNoTextureVCol.xml",
})

local mat = geom:GetMaterial()
mat:SetShaderParameter("Metallic", Variant(0.5))
mat:SetShaderParameter("Roughness", Variant(0.3))
```

各函数的完整选项表见 `Primitives.lua` 的 `---@param` 标注（那里是真源，本文不再复述）。

## 相关资源

- `engine-docs/recipes/procedural-geometry.md` - 替代方案
- `engine-docs/recipes/built-in-models.md` - 内置模型列表
