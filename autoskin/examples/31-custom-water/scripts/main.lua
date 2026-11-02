local Demo = require("WaterDemo")
local UI = require("urhox-libs/UI")
---@type table?
local demo = nil
---@type Label?
local status = nil
local elapsed, accumulator, hudTimer, yaw, pitch = 0.0, 0.0, 0.0, 0.0, 0.0
local paused, halfRate = false, false

function Start()
    graphics.windowTitle = "Custom Water / Three FFT Snapshots"
    demo = Demo.Create()
    yaw, pitch = demo.camera.node.rotation:YawAngle(), demo.camera.node.rotation:PitchAngle()
    UI.Init({
        scale = UI.Scale.DEFAULT
    })
    status = UI.Label {
        text = "Preparing water queries...",
        fontSize = 13
    }
    UI.SetRoot(UI.Panel {
        width = "100%",
        height = "100%",
        pointerEvents = "box-none",
        children = {
            UI.Panel {
                position = "absolute",
                left = 16,
                top = 16,
                width = 370,
                padding = 16,
                gap = 10,
                backgroundColor = {12, 34, 39, 228},
                borderRadius = 6,
                children = {
                    UI.Label {
                        text = "CUSTOM WATER / THREE SNAPSHOTS",
                        fontSize = 18
                    }, UI.Label {
                        text = "4-band JONSWAP | Wind 8 m/s | Fetch 30 km",
                        fontSize = 12
                    }, UI.Label {
                        text = "RMB look / WASD move / Q-E descend-ascend",
                        fontSize = 12
                    }, UI.Toggle {
                        label = "Pause simulation",
                        onChange = function(_, value) paused = value end
                    }, UI.Toggle {
                        label = "30 Hz simulation",
                        onChange = function(_, value) halfRate = value end
                    }, status
                }
            }
        }
    })
    SubscribeToEvent("Update", "WaterExampleUpdate")
    SubscribeToEvent("ComputeDispatchFailed", function(_, data) error(data:GetString("Error")) end)
end

---@param _eventType string
---@param eventData UpdateEventData
function WaterExampleUpdate(_eventType, eventData)
    if not demo or not status then return end
    local dt = math.min(eventData:GetFloat("TimeStep"), 0.1)
    local node = demo.camera.node
    if input:GetMouseButtonDown(MOUSEB_RIGHT) then
        yaw = yaw + input.mouseMoveX * 0.12
        pitch = Clamp(pitch + input.mouseMoveY * 0.12, -85, 85)
        node.rotation = Quaternion(pitch, yaw, 0)
    end
    local step = dt * (input:GetKeyDown(KEY_SHIFT) and 12 or 4)
    if input:GetKeyDown(KEY_W) then node:Translate(Vector3(0, 0, step)) end
    if input:GetKeyDown(KEY_S) then node:Translate(Vector3(0, 0, -step)) end
    if input:GetKeyDown(KEY_A) then node:Translate(Vector3(-step, 0, 0)) end
    if input:GetKeyDown(KEY_D) then node:Translate(Vector3(step, 0, 0)) end
    if input:GetKeyDown(KEY_Q) then node:Translate(Vector3(0, -step, 0), TS_WORLD) end
    if input:GetKeyDown(KEY_E) then node:Translate(Vector3(0, step, 0), TS_WORLD) end
    local simulationTime = nil
    if not paused then
        elapsed, accumulator = elapsed + dt, accumulator + dt
        if not halfRate or accumulator >= 1 / 30 then simulationTime, accumulator = elapsed, 0 end
    end
    demo.ocean:Advance(simulationTime)
    hudTimer = hudTimer + dt
    if hudTimer > 0.25 then
        hudTimer = 0
        local snapshot, state = demo.ocean:Snapshot(), demo.viewport:GetWaterState()
        status:SetText(string.format("%s | previous %d / display %d / query %d\n%s | result age %d frames / %d ms",
                                     "FFT", snapshot.previous, snapshot.display,
                                     snapshot.query, state and
                                         (state:IsValid() and (state:IsUnderwater() and "Underwater" or "Above water") or
                                             "Unknown") or "Pending", state and state:GetLatencyFrames() or 0,
                                     state and state:GetLatencyMSec() or 0))
    end
end

function Stop()
    UI.Shutdown()
    demo = nil
end
