# Editor.Undo

```lua
Editor.Undo.Begin(label)
Editor.Undo.Record(nodeOrComponent)
Editor.Undo.End()
Editor.Undo.Cancel()
Editor.Undo.CanUndo() -> bool
Editor.Undo.CanRedo() -> bool
```

`Record(node)` 在变异前拍名字、enabled、local TRS。  
`Record(component)` 再拍该组件可编辑属性；改 Light / Zone / Terrain 等必须先 Record 组件。

`CreateChild` / `Remove` / `CreateComponent` / `Remove` 由宿主在当前编辑文档上订阅
`E_NODEADDED` 等自动记账（只在 Begin/End 组内，且只订 `Editor.Scene.Get()` 那份 Scene）。
创建节点的 XML 快照在 `End()` 时拍（`CreateChild(name)` 是先插入再 `SetName`，若在 Added 时拍会变成未命名）。
同场景 `AddChild` 会先 Removed 再 Added，记成 Reparent，不会误成删除+创建。

`End()` 收成一条 Undo，和 Inspector / MCP 共用栈。`Cancel()` 回滚本组已发生的创建/删除/属性。

菜单和窗口 `OnGUI` 若改了场景却没开组，宿主会开隐式组。改属性仍应显式 `Record(component)`。

打开场景 / PIE / 预览 Scene 的增删不会进栈。
