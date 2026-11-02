# Editor Script 常见问题

## 1. 点了菜单好像没反应

`Editor.Log` 只写 Console，前缀 `[EditorScript]`。打开底部 Console，确认 Info 没被滤掉。
要看得见的反馈用 `Editor.Dialog.Info` 或改场景。

## 2. 用错了 Lua 环境

`GetLuaEnvironment() == 2`（`Editor`）是场景玩法脚本的检查 VM，不跑生命周期。
编辑器脚本是 `4`（`EditorScript`）。不要往检查 VM 里挂菜单。

## 3. 和 Plugin.Agent / Maker 插件搞混

`Plugin.Agent` 在编辑器脚本里不存在。`plugins/` 是 Maker Web iframe，不是这条 API。

## 4. 忘了 Undo

菜单回调里直接 `SetName` 通常仍能 Ctrl+Z（隐式组）。加载顶层改场景会报
`EDITOR_SCRIPT_MUTATION_OUTSIDE_CALLBACK` 或没有 Undo。养成 Begin/Record/End。

## 5. 热加载后窗口字段丢了 / Node 失效

只恢复窗口开关。`Node` userdata 不要跨重载保存，用 id。宿主推出去的 Node/Component
会带 scene generation；切场景后再传回来会变成 `nil` / `EDITOR_SCRIPT_STALE_OBJECT`。
引擎绑定自己返回的对象（如 `node:GetChild`）没有这层戳，仍不要跨场景存。

## 6. Editor/ 进了玩家包

不要把运行时资源放进 `Editor/`。玩法 `require` 带 `Editor` 段时，
`EDITOR_SCRIPT_NOT_IN_RUNTIME` 目前只在 `URHOX_EDITOR` 构建生效；玩家 Runtime 先不拦。
发布扫描跳过 `Editor/` 会后补。

## 7. 往 File 菜单挂项

返回 `EDITOR_SCRIPT_MENU_FORBIDDEN`。用 `Tools/...` 或自定义顶栏。

## 8. 在 OnGUI 外调 Editor UI

`EDITOR_SCRIPT_GUI_OUTSIDE_ONGUI`。

## 9. 在 OnSceneGUI 外调 Handles

`EDITOR_SCRIPT_HANDLE_OUTSIDE_ONSCENEGUI`。`DrawLine` / `PositionHandle` / `RotationHandle` /
`ScaleHandle` / `Button` 只能写在 `CustomEditor.OnSceneGUI` 或 `SceneView.duringSceneGui` listener 里。
多个 listener 会按订阅顺序执行。

视口里只靠 DebugRenderer 的 1px 线很容易看不见（网格能看见不代表短线段能看见）。`DrawLine` / `DrawPolyline` 同时走屏幕 overlay。

## 10. Undo.Record 要传对类型

`Record(node)` 拍名字 / enabled / TRS。`Record(component)` 拍组件属性。不要把 Node 当 Component 传；宿主会按类型分派。

## 11. 材质烘焙取色、透明度与预览

[`Editor.MaterialBaking`](../api/material-baking.md) 先入队，后续 Update 才调用完成回调。
不要把 `accepted == true` 当作烘焙成功；不要在回调中直接调用 `GUILayout`。
结果是 `Image`，`GUILayout.Image` 接受 `Texture2D` 或资源路径，内存预览先用
`Texture2D:SetData(image)` 上传一次，后续 OnGUI 复用。

取色前应用 `uvRect`。`albedo.a` 是覆盖率，透明度要读 `opacity.r`；法线不是切线空间贴图。
默认严格模式失败时先查 Console 的 shader/UV 错误，不要通过开启降级把失败变成颜色不准的“成功”。

烘焙回调可能在 Handle 拖动等外部 Undo 事务尚未结束时执行。宿主处理回调异常时只应取消
自己创建的隐式事务；仅凭“当前有打开的事务”就取消，会回滚其他编辑操作。外部事务的
提交或取消由原调用方负责。

## 12. 不要把资产加载的多返回值直接传给引擎绑定

`AssetDatabase.LoadAssetAtPath` 返回 `resource, err`，`assert(...)` 会保留这些返回值。
`component:SetModel(assert(AssetDatabase.LoadAssetAtPath(...)))` 会多传一个 `nil`，
tolua 可能报 `argument #3 is 'nil'; '[no object]' expected`。先赋给局部变量：
`local model = assert(AssetDatabase.LoadAssetAtPath("Model", "Models/Wall.mdl"))`，再 `component:SetModel(model)`。
