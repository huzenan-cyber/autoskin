# 用现有引擎类型写 Editor Script

不新增 TimeOfDay / RoadSpline / EditorTerrain。玩法绑定里已有的类型，Editor Script 同一套都能用。缺的是 Undo / Handles / 资源字段，不是再包一层 C++。

示例在 [examples/](../examples/)。复制到工程 `Editor/` 即可。

| 文件 | 做什么 |
|---|---|
| [AtmosphereTool.lua](../examples/AtmosphereTool.lua) | 窗口改平行光方向/亮度、`Zone` 雾。Apply 一次 Undo |
| [TerrainHeightNudge.lua](../examples/TerrainHeightNudge.lua) | `GetHeightMap` → `Image:GetSubimage` 克隆 → 改一列像素 → `SetHeightMap` / `ApplyHeightMap` |
| [SplinePathHandles.lua](../examples/SplinePathHandles.lua) | 创建 `SplinePath` 子节点控制点，`duringSceneGui` 画折线并使用 `PositionHandle` |

## Light / Zone

```lua
light:SetBrightness(2)
light:GetNode():SetRotation(Quaternion(pitch, yaw, 0))
zone:SetFogColor(Color(0.5, 0.6, 0.7, 1))
zone:SetDepthFogStart(50)
zone:SetDepthFogEnd(200)
```

先 `Editor.Undo.Record(light 或 zone 或 node)`。体积雾等 Inspector 属性用 `Record(component)` 再 `SetAttribute`。

## Terrain

`GetHeight(worldPos)`、`GetHeightMap()`、`Image:GetPixel` / `SetPixel`、`SetHeightMap`、`ApplyHeightMap` 都已绑定。

不要原地改当前 Height Map 再 Record：ResourceRef 没变，Undo 恢复不了像素。应克隆 Image（`GetSubimage` 整张），改克隆，再 `SetHeightMap(clone)`，让属性引用变化。

## SplinePath

`AddControlPoint` / `GetPoint` 已绑定。控制点就是普通 Node：放在样条子节点上，用
`Editor.Handles.PositionHandle` 拖世界坐标。`GetPoint(0~1)` 画折线。Create Demo 把样条放在相机前方，
并用 `CATMULL_ROM_FULL_CURVE` 让曲线穿过控制点。

多个脚本分别订阅 `Editor.SceneView.duringSceneGui`，按订阅顺序执行，不需要保存或串接前一个回调。
