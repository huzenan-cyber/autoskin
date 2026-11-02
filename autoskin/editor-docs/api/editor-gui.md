# Editor UI

Editor Script 的公开 UI 采用 Unity IMGUI 范式，分为三个 namespace：

- `EditorGUILayout`：带标签、自动布局的编辑字段。
- `GUILayout`：按钮、图片和布局容器。
- `EditorGUI`：ChangeCheck、Disabled、缩进等状态 Scope。

它们只允许在 Window `OnGUI` 或 Custom Editor 的 `OnInspectorGUI` 中调用，否则返回
`EDITOR_SCRIPT_GUI_OUTSIDE_ONGUI`。不要直接调用 ImGui。

## EditorGUILayout

字段统一传入旧值、返回新值：

```lua
self.name = EditorGUILayout.TextField("Name", self.name or "")
self.count = EditorGUILayout.IntField("Count", self.count or 0)
self.speed = EditorGUILayout.Slider("Speed", self.speed or 1, 0, 10)
self.enabled = EditorGUILayout.Toggle("Enabled", self.enabled)
self.tint = EditorGUILayout.ColorField("Tint", self.tint or Color.WHITE)
self.mode = EditorGUILayout.Popup("Mode", self.mode or 1, { "A", "B", "C" })
```

V1 常用字段：`LabelField`、`SelectableLabel`、`TextField`、`TextArea`、`PasswordField`、
`DelayedTextField`、`DelayedIntField`、`DelayedFloatField`、`IntField`、`FloatField`、`Slider`、
`IntSlider`、`MinMaxSlider`、`Toggle`、`ToggleLeft`、`Popup`、`EnumPopup`、`ColorField`、
`MaskField`、`Vector2Field`、`Vector3Field`、`Vector4Field`、`RectField`、`BoundsField`、
`ObjectField`、`PropertyField`、`Foldout`、`HelpBox`、`Space`。`Delayed*Field` 只在回车或失焦时提交。

资源 `ObjectField` 返回 Resource path 字符串；`Node` 返回当前场景 generation 的 Node 或 `nil`：

```lua
path = EditorGUILayout.ObjectField("Albedo", path, "Texture2D")
node = EditorGUILayout.ObjectField("Target", node, "Node")
```

`PropertyField(target, attributeName)` 通过 UrhoX Attribute 元数据选择字段类型，修改时自动记录 Undo：

```lua
EditorGUILayout.PropertyField(self.target, "Brightness Multiplier")
```

## GUILayout

```lua
GUILayout.Label("Preview")
if GUILayout.Button("Apply", { width = 120, tooltip = "Apply changes" }) then
    Apply()
end

GUILayout.Image(texturePath, {
    width = 128,
    height = 128,
    scaleMode = "ScaleToFit",
    tint = Color.WHITE,
    tooltip = "Texture preview",
})
```

`Image` 接受 Resource path、`Texture2D` 或 `nil`。`ImageButton(id, textureOrPath, options?)` 的首个参数
必须是稳定 id。Lua 不接触 GPU handle。其它 V1 API：`Box`、`Selectable`、`Space`、`FlexibleSpace`、
`Separator`、`BeginHorizontal/EndHorizontal`、`BeginVertical/EndVertical`、`BeginGroup/EndGroup`、
`BeginScrollView/EndScrollView`、`Toolbar`。

长表单通常让 ScrollView 占满窗口剩余高度：

```lua
GUILayout.BeginScrollView("properties", {
    expandWidth = true,
    expandHeight = true,
})
-- fields...
GUILayout.EndScrollView()
```

options 使用 lower camelCase；未知 key 返回 `EDITOR_SCRIPT_GUI_INVALID_OPTION`。

## EditorGUI scopes

```lua
EditorGUI.BeginChangeCheck()
self.value = EditorGUILayout.FloatField("Value", self.value or 0)
if EditorGUI.EndChangeCheck() then
    Editor.Log("Value changed")
end

EditorGUI.BeginDisabledGroup(not self.canApply)
GUILayout.Button("Apply")
EditorGUI.EndDisabledGroup()
```

V1 Scope：`BeginChangeCheck/EndChangeCheck`、`BeginDisabledGroup/EndDisabledGroup`、
`PushIndent/PopIndent`、`PushLabelWidth/PopLabelWidth`、`PushMixedValue/PopMixedValue`。
消息类型为 `EditorGUI.MessageType.None/Info/Warning/Error`。
