# Editor.Selection

```lua
Editor.Selection.GetNodes()          -- { Node, ... }，不含场景根
Editor.Selection.GetActiveNode()     -- Node | nil
Editor.Selection.GetComponent()      -- Component | nil
Editor.Selection.SetNodes({ Node, ... })
Editor.Selection.SetActiveNode(node)
```

返回的是当前 `scene_generation` 下的活对象。不要把 `Node` 存过重载；存
`node:GetID()`，再用 `Editor.Scene.FindNode(id)`。

选择变化不进 Undo。
