# Editor.Animation

编辑器脚本里读写 `.ani`。状态机 clip 是运行时窗口；这里产出的是真正的动画资源。

路径必须是当前工程相对路径，不能含 `..`、盘符或 `://`。写出失败码与 `AssetDatabase` 使用相同
工程边界：`EDITOR_SCRIPT_PATH_DENIED`、`NO_PROJECT`、`EDITOR_SCRIPT_STALE_OBJECT`、`OPERATION_FAILED`。
PIE 中不能写。

```lua
local anim, err = Editor.Animation.Load("Anims/Jump.ani")
local info, err = Editor.Animation.Info(anim)           -- 或直接传路径
local pos, rot, scale, mask = Editor.Animation.Sample(anim, "Root", 0.25)

local ok, err = Editor.Animation.Extract(
  "Anims/Jump.ani",
  "Anims/Jump_Land.ani",
  { startFrame = 14, endFrame = 33, frameRate = 30, overwrite = false }
)

local merged, err = Editor.Animation.Merge({
  { path = "Anims/JumpStart.ani" },
  { path = "Anims/JumpAir.ani", startTime = 0, endTime = 0.5 },
  { anim = anim },
})
local ok, err = Editor.Animation.Write(merged, "Anims/JumpFull.ani", false)
```

| API | 说明 |
|---|---|
| `Load(path)` | 加载 `.ani`，返回 `anim, err` |
| `Info(anim 或 path)` | 概况：时长、骨骼、通道、关键帧数量、轨起止时间。**不返回每一帧姿势** |
| `Sample(anim 或 path, trackName, time)` | 某骨某秒的位移、旋转、缩放、通道 mask |
| `Extract(src, dst, opts)` | 按时间或帧窗口切一段，写成新 `.ani`。`ok, err` |
| `Merge(segments)` | 多段按时间接成一份 `Animation`。`anim, err`。存盘再 `Write` |
| `Write(anim, path, overwrite?)` | 把内存里的 `Animation` 存成 `.ani` |

`overwrite` 默认 `false`：目标已存在则失败。写出成功不进 Undo。

## 窗口字段（Extract 的 opts、Merge 的每一段）

帧和秒互斥。用帧必须带 `frameRate > 0`。`.ani` 没有 fps。

| 字段 | 说明 |
|---|---|
| `startTime` / `endTime` | 秒。缺终点表示切到源结尾 |
| `startFrame` / `endFrame` / `frameRate` | `time = frame / frameRate` |
| `tracks` | 可选，只保留这些骨骼名 |
| `overwrite` | 仅 Extract；Merge 的落盘在 Write 上 |

Merge 每一段还要有 `path` 或 `anim`（已 Load 的对象）。

`Info` 的 `tracks[i].keyCount` 在压缩轨上是各通道数量的最大值。不要读 `track.keyFrames`：压缩轨那个表是空的。
