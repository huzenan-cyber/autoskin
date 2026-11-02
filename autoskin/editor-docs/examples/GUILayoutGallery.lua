-- Canonical GUILayout, image, and layout-container gallery.
-- Copy into any Editor/ directory, then open Tools -> Examples -> GUILayout Gallery.

local window = Editor.Window("GUILayout Gallery", "examples.guilayout_gallery", {
    width = 760,
    height = 560,
})
window.page = 1
window.selectedCard = false
window.texturePath = "Textures/LogoLarge.png"
window.clicks = 0
window.lifecycle = "not opened yet"

function window:OnEnable()
    self.lifecycle = "OnEnable called"
    Editor.Log("GUILayout Gallery enabled")
end

function window:OnDisable()
    Editor.Log("GUILayout Gallery disabled")
end

local function DrawLayouts(self)
    GUILayout.Label("Horizontal / vertical / flexible layout")
    GUILayout.BeginHorizontal()
    if GUILayout.Button("Left", { width = 80, tooltip = "Fixed width button" }) then
        self.clicks = self.clicks + 1
    end
    GUILayout.FlexibleSpace()
    GUILayout.Box("Flexible space is on the left", { width = 190, height = 28 })
    GUILayout.EndHorizontal()

    GUILayout.Separator()
    GUILayout.BeginGroup()
    GUILayout.BeginVertical()
    GUILayout.Label("BeginGroup + BeginVertical")
    if GUILayout.Selectable("Selectable row", self.selectedCard, { tooltip = "Click to select" }) then
        self.selectedCard = not self.selectedCard
    end
    GUILayout.Space(8)
    GUILayout.Label("Button clicks: " .. tostring(self.clicks))
    GUILayout.Label("Lifecycle: " .. self.lifecycle)
    GUILayout.EndVertical()
    GUILayout.EndGroup()
end

local function DrawImages(self)
    self.texturePath = EditorGUILayout.ObjectField("Texture", self.texturePath, "Texture2D")
    EditorGUILayout.HelpBox(
        "Image accepts a project/package path, Texture2D, or nil. ImageButton needs a stable id.",
        EditorGUI.MessageType.Info)

    GUILayout.BeginHorizontal()
    GUILayout.BeginVertical()
    GUILayout.Label("ScaleToFit")
    GUILayout.Image(self.texturePath, {
        width = 150,
        height = 100,
        scaleMode = "ScaleToFit",
        tint = Color(1, 1, 1, 1),
        tooltip = "Aspect ratio preserved",
    })
    GUILayout.EndVertical()

    GUILayout.BeginVertical()
    GUILayout.Label("ScaleAndCrop")
    if GUILayout.ImageButton("guilayout_gallery.preview", self.texturePath, {
            width = 150,
            height = 100,
            scaleMode = "ScaleAndCrop",
            uv0 = Vector2(0, 0),
            uv1 = Vector2(1, 1),
            selected = self.selectedCard,
            tooltip = "Click the image",
        }) then
        self.clicks = self.clicks + 1
        self.selectedCard = not self.selectedCard
    end
    GUILayout.EndVertical()
    GUILayout.EndHorizontal()

    GUILayout.Label("Stretch")
    GUILayout.Image(self.texturePath, {
        width = 306,
        height = 50,
        scaleMode = "Stretch",
        tint = Color(0.7, 0.9, 1.0, 1.0),
    })
end

function window:OnGUI()
    self.page = GUILayout.Toolbar(self.page, { "Layouts", "Images" })
    GUILayout.BeginScrollView("guilayout_gallery.scroll", { expandWidth = true, height = 440 })
    if self.page == 1 then
        DrawLayouts(self)
    else
        DrawImages(self)
    end
    GUILayout.EndScrollView()

    GUILayout.Separator()
    GUILayout.BeginHorizontal()
    GUILayout.FlexibleSpace()
    if GUILayout.Button("Close", { width = 90 }) then
        self:Close()
    end
    GUILayout.EndHorizontal()
end

Editor.MenuItem("Tools/Examples/GUILayout Gallery", function()
    if not window:IsOpen() then
        window:Show()
    end
end, {
    description = "Open a gallery covering canonical GUILayout and image controls",
})
