-- Canonical EditorGUILayout / EditorGUI control gallery.
-- Copy into any Editor/ directory, then open Tools -> Examples -> EditorGUILayout Gallery.

local window = Editor.Window("EditorGUILayout Gallery", "examples.editor_guilayout_gallery", {
    width = 1000,
    height = 760,
})

window.text = "Agent-friendly editor tools"
window.multiline = "Line one\nLine two"
window.password = "secret"
window.delayedText = "commits on Enter or focus loss"
window.delayedInt = 8
window.delayedFloat = 0.25
window.count = 3
window.speed = 1.5
window.ratio = 0.5
window.quality = 2
window.rangeMin = 0.2
window.rangeMax = 0.8
window.enabled = true
window.experimental = false
window.mode = 1
window.enumMode = 2
window.layerMask = 3
window.vector2 = Vector2(1, 2)
window.vector3 = Vector3(1, 2, 3)
window.vector4 = Vector4(1, 2, 3, 4)
window.rect = Rect(0, 0, 128, 64)
window.bounds = BoundingBox(Vector3(-1, -1, -1), Vector3(1, 1, 1))
window.tint = Color(0.3, 0.7, 1.0, 1.0)
window.texturePath = ""
window.targetNode = nil
window.detailsOpen = true
window.showMixed = false
window.status = "Change a field to exercise BeginChangeCheck."

local modes = { "Fast", "Balanced", "Precise" }
local layers = { "World", "Characters", "Effects", "UI" }

function window:OnGUI()
    GUILayout.BeginScrollView("editor_guilayout_gallery.scroll", {
        expandWidth = true,
        expandHeight = true,
    })

    EditorGUILayout.LabelField("EditorGUILayout", "Every field returns its current value")
    EditorGUILayout.SelectableLabel("Copyable", "Project-relative paths work in any project directory")
    EditorGUILayout.HelpBox(self.status, EditorGUI.MessageType.Info)
    EditorGUILayout.Space(6)

    EditorGUI.BeginChangeCheck()
    EditorGUI.PushLabelWidth(150)

    self.text = EditorGUILayout.TextField("Text", self.text)
    self.multiline = EditorGUILayout.TextArea("Text Area", self.multiline)
    self.password = EditorGUILayout.PasswordField("Password", self.password)
    self.delayedText = EditorGUILayout.DelayedTextField("Delayed Text", self.delayedText)
    self.delayedInt = EditorGUILayout.DelayedIntField("Delayed Int", self.delayedInt)
    self.delayedFloat = EditorGUILayout.DelayedFloatField("Delayed Float", self.delayedFloat)

    self.count = EditorGUILayout.IntField("Count", self.count)
    self.speed = EditorGUILayout.FloatField("Speed", self.speed)
    self.ratio = EditorGUILayout.Slider("Ratio", self.ratio, 0, 1)
    self.quality = EditorGUILayout.IntSlider("Quality", self.quality, 1, 5)
    self.rangeMin, self.rangeMax = EditorGUILayout.MinMaxSlider(
        "Visible Range", self.rangeMin, self.rangeMax, 0, 1)

    self.enabled = EditorGUILayout.Toggle("Enabled", self.enabled)
    self.experimental = EditorGUILayout.ToggleLeft("Experimental", self.experimental)
    self.mode = EditorGUILayout.Popup("Popup", self.mode, modes)
    self.enumMode = EditorGUILayout.EnumPopup("Enum Popup", self.enumMode, modes)
    self.layerMask = EditorGUILayout.MaskField("Layer Mask", self.layerMask, layers)

    self.vector2 = EditorGUILayout.Vector2Field("Vector2", self.vector2)
    self.vector3 = EditorGUILayout.Vector3Field("Vector3", self.vector3)
    self.vector4 = EditorGUILayout.Vector4Field("Vector4", self.vector4)
    self.rect = EditorGUILayout.RectField("Rect", self.rect)
    self.bounds = EditorGUILayout.BoundsField("Bounds", self.bounds)
    self.tint = EditorGUILayout.ColorField("Tint", self.tint)

    self.texturePath = EditorGUILayout.ObjectField("Texture", self.texturePath, "Texture2D")
    self.targetNode = EditorGUILayout.ObjectField("Scene Node", self.targetNode, "Node")

    EditorGUI.PopLabelWidth()
    if EditorGUI.EndChangeCheck() then
        self.status = "At least one field changed this frame."
    end

    self.detailsOpen = EditorGUILayout.Foldout("EditorGUI scopes", self.detailsOpen)
    if self.detailsOpen then
        EditorGUI.PushIndent(1)
        EditorGUILayout.LabelField("Indent", "This row is indented")

        self.showMixed = EditorGUILayout.Toggle("Show Mixed Value", self.showMixed)
        EditorGUI.PushMixedValue(self.showMixed)
        self.speed = EditorGUILayout.FloatField("Mixed-capable Speed", self.speed)
        EditorGUI.PopMixedValue()

        EditorGUI.BeginDisabledGroup(not self.enabled)
        if GUILayout.Button("Only enabled when Enabled is checked") then
            self.status = "The enabled button was clicked."
        end
        EditorGUI.EndDisabledGroup()
        EditorGUI.PopIndent()
    end

    EditorGUILayout.HelpBox("Informational message", EditorGUI.MessageType.Info)
    EditorGUILayout.HelpBox("Warning message", EditorGUI.MessageType.Warning)
    EditorGUILayout.HelpBox("Error message", EditorGUI.MessageType.Error)
    EditorGUILayout.HelpBox("Neutral message", EditorGUI.MessageType.None)

    GUILayout.EndScrollView()
end

Editor.MenuItem("Tools/Examples/EditorGUILayout Gallery", function()
    window:Show()
end, {
    description = "Open a gallery covering canonical EditorGUILayout and EditorGUI controls",
})
