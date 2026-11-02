-- E5: tweak existing Light + Zone. Not a time-of-day system.
-- Copy into the game project's Editor/ folder.

local window = Editor.Window("Atmosphere")
window.pitch = 50
window.yaw = 30
window.brightness = 1
window.fogStart = 50
window.fogEnd = 200

local function ColorChannel(color, name)
    if not color then
        return 1
    end
    return color[name] or color[name .. "_"] or 1
end

local function ComponentsOf(node, typeName)
    local out = {}
    if not node then
        return out
    end
    local list = node:GetComponents(typeName, true)
    if not list then
        return out
    end
    if type(list) == "table" then
        return list
    end
    local count = list.Size and list:Size() or 0
    for i = 0, count - 1 do
        out[#out + 1] = list[i]
    end
    return out
end

local function FindDirectionalLight()
    local scene = Editor.Scene.Get()
    if not scene then
        return nil
    end
    local lights = ComponentsOf(scene, "Light")
    for i = 1, #lights do
        local light = lights[i]
        if light and light:GetLightType() == 0 then
            return light
        end
    end
    return nil
end

local function FindZone()
    local scene = Editor.Scene.Get()
    if not scene then
        return nil
    end
    local zones = ComponentsOf(scene, "Zone")
    return zones[1]
end

function window:Serialize()
    local fog = self.fogColor or Color(0.5, 0.6, 0.7, 1)
    return {
        pitch = self.pitch or 50,
        yaw = self.yaw or 30,
        brightness = self.brightness or 1,
        fogStart = self.fogStart or 50,
        fogEnd = self.fogEnd or 200,
        fogR = ColorChannel(fog, "r"),
        fogG = ColorChannel(fog, "g"),
        fogB = ColorChannel(fog, "b"),
    }
end

function window:Restore(state)
    if not state then
        return
    end
    self.pitch = state.pitch or 50
    self.yaw = state.yaw or 30
    self.brightness = state.brightness or 1
    self.fogStart = state.fogStart or 50
    self.fogEnd = state.fogEnd or 200
    self.fogColor = Color(state.fogR or 0.5, state.fogG or 0.6, state.fogB or 0.7, 1)
end

function window:OnGUI()
    local light = FindDirectionalLight()
    local zone = FindZone()
    if not light then
        EditorGUILayout.HelpBox("No directional Light in the scene.", EditorGUI.MessageType.Warning)
        return
    end

    local node = light:GetNode()
    if node and not self.synced then
        local rot = node:GetRotation()
        self.pitch = rot:PitchAngle()
        self.yaw = rot:YawAngle()
        self.brightness = light:GetBrightness()
        if zone then
            self.fogStart = zone:GetDepthFogStart()
            self.fogEnd = zone:GetDepthFogEnd()
            self.fogColor = zone:GetFogColor()
        end
        self.synced = true
    end

    GUILayout.Label("Uses existing Light / Zone. Not an engine time-of-day.")
    self.pitch = EditorGUILayout.Slider("Sun Pitch", self.pitch or 50, -89, 89)
    self.yaw = EditorGUILayout.Slider("Sun Yaw", self.yaw or 30, -180, 180)
    self.brightness = EditorGUILayout.Slider("Brightness", self.brightness or 1, 0, 20)
    if zone then
        self.fogColor = EditorGUILayout.ColorField("Fog Color", self.fogColor or Color(0.5, 0.6, 0.7, 1))
        self.fogStart = EditorGUILayout.Slider("Fog Start", self.fogStart or 50, 0, 500)
        self.fogEnd = EditorGUILayout.Slider("Fog End", self.fogEnd or 200, 1, 2000)
    else
        EditorGUILayout.HelpBox("No Zone in the scene.", EditorGUI.MessageType.Warning)
    end

    if GUILayout.Button("Apply") then
        Editor.Undo.Begin("Atmosphere")
        if node then
            Editor.Undo.Record(node)
            node:SetRotation(Quaternion(self.pitch, self.yaw, 0))
        end
        Editor.Undo.Record(light)
        light:SetBrightness(self.brightness)
        if zone then
            Editor.Undo.Record(zone)
            zone:SetFogColor(self.fogColor)
            zone:SetDepthFogStart(self.fogStart)
            zone:SetDepthFogEnd(self.fogEnd)
        end
        Editor.Undo.End()
        Editor.Log("Applied atmosphere to Light/Zone")
    end
end

Editor.MenuItem("Tools/Atmosphere Window", function()
    window.synced = false
    window:Show()
end, {
    description = "Edit directional Light and Zone fog with existing engine APIs",
})
