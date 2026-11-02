-- Example: inspect / sample / extract / merge .ani files.
-- Copy into the game project's Editor/ folder, then Tools → Reload Editor Scripts.
-- Paths are project-relative. Pick a source .ani that exists in this project.

local window = Editor.Window("Animation Clip")
window.srcPath = ""
window.trackName = "Root"
window.sampleTime = 0
window.startTime = 0
window.endTime = 0.5
window.extractPath = "assets/Anims/Extracted.ani"
window.mergeB = ""
window.mergePath = "assets/Anims/Merged.ani"
window.status = "Pick a .ani, then Inspect."

local function VecStr(v)
    if not v then
        return "?"
    end
    local x = v.x or v.x_ or 0
    local y = v.y or v.y_ or 0
    local z = v.z or v.z_ or 0
    return string.format("%.3f, %.3f, %.3f", x, y, z)
end

function window:Serialize()
    return {
        srcPath = self.srcPath or "",
        trackName = self.trackName or "Root",
        sampleTime = self.sampleTime or 0,
        startTime = self.startTime or 0,
        endTime = self.endTime or 0.5,
        extractPath = self.extractPath or "",
        mergeB = self.mergeB or "",
        mergePath = self.mergePath or "",
    }
end

function window:Restore(state)
    if not state then
        return
    end
    self.srcPath = state.srcPath or ""
    self.trackName = state.trackName or "Root"
    self.sampleTime = state.sampleTime or 0
    self.startTime = state.startTime or 0
    self.endTime = state.endTime or 0.5
    self.extractPath = state.extractPath or self.extractPath
    self.mergeB = state.mergeB or ""
    self.mergePath = state.mergePath or self.mergePath
end

function window:OnGUI()
    GUILayout.Label("Load a project .ani, inspect tracks, sample a bone, extract a window, or merge two clips.")
    self.srcPath = EditorGUILayout.ObjectField("Source", self.srcPath or "", "Animation")
    self.trackName = EditorGUILayout.TextField("Track", self.trackName or "Root")
    self.sampleTime = EditorGUILayout.FloatField("Sample Time", self.sampleTime or 0)
    GUILayout.Label(self.status or "")

    if GUILayout.Button("Inspect") then
        local info, err = Editor.Animation.Info(self.srcPath)
        if not info then
            self.status = err or "Info failed"
        else
            local n = info.tracks and #info.tracks or 0
            local extra = ""
            if n > 0 then
                extra = string.format(" first=%s keys=%d", info.tracks[1].name, info.tracks[1].keyCount or 0)
            end
            self.status = string.format("length=%.3fs tracks=%d compressed=%s%s",
                info.length or 0, n, info.compressed and "yes" or "no", extra)
        end
    end

    if GUILayout.Button("Sample") then
        local pos, rot, scale, mask, err = Editor.Animation.Sample(self.srcPath, self.trackName, self.sampleTime)
        if not pos then
            self.status = err or "Sample failed (missing track?)"
        else
            self.status = string.format("t=%.3f pos=(%s) scl=(%s) mask=%s",
                self.sampleTime, VecStr(pos), VecStr(scale), tostring(mask))
        end
    end

    GUILayout.Separator()
    self.startTime = EditorGUILayout.FloatField("Start Time", self.startTime or 0)
    self.endTime = EditorGUILayout.FloatField("End Time", self.endTime or 0.5)
    self.extractPath = EditorGUILayout.TextField("Extract To", self.extractPath or "")
    if GUILayout.Button("Extract") then
        local ok, err = Editor.Animation.Extract(self.srcPath, self.extractPath, {
            startTime = self.startTime,
            endTime = self.endTime,
            overwrite = true,
        })
        self.status = ok and ("Wrote " .. self.extractPath) or (err or "Extract failed")
    end

    GUILayout.Separator()
    self.mergeB = EditorGUILayout.ObjectField("Merge With", self.mergeB or "", "Animation")
    self.mergePath = EditorGUILayout.TextField("Merge To", self.mergePath or "")
    if GUILayout.Button("Merge Source + Merge With") then
        local merged, err = Editor.Animation.Merge({
            { path = self.srcPath },
            { path = self.mergeB },
        })
        if not merged then
            self.status = err or "Merge failed"
        else
            local ok, writeErr = Editor.Animation.Write(merged, self.mergePath, true)
            self.status = ok and ("Wrote " .. self.mergePath) or (writeErr or "Write failed")
        end
    end
end

Editor.MenuItem("Tools/Animation Clip Tool", function()
    window:Show()
end, {
    description = "Inspect, sample, extract, and merge .ani files",
})
