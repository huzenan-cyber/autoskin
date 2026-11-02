---@meta

--- Auto-generated from Graphics/ProceduralSky

---@class ProceduralSky : Component
---@field skyTopColor Color
---@field skyHorizonColor Color
---@field skyCurve number
---@field skyEnergy number
---@field groundBottomColor Color
---@field groundHorizonColor Color
---@field groundCurve number
---@field groundEnergy number
---@field sunAngleMax number
---@field sunCurve number
---@field sunDiskSize number
---@field sunEnergy number
---@field exposure number
---@field sunLight Light
---@field skybox Skybox
---@field material Material
ProceduralSky = {}

---@param color Color Zenith color (sRGB)
---@return nil
function ProceduralSky:SetSkyTopColor(color) end

---@param color Color Sky color at the horizon (sRGB)
---@return nil
function ProceduralSky:SetSkyHorizonColor(color) end

---@param curve number Horizon-to-top blend curve, > 0 (default 0.15)
---@return nil
function ProceduralSky:SetSkyCurve(curve) end

---@param energy number Multiplier of the sky colors (default 1)
---@return nil
function ProceduralSky:SetSkyEnergy(energy) end

---@param color Color Color straight down (sRGB)
---@return nil
function ProceduralSky:SetGroundBottomColor(color) end

---@param color Color Ground color at the horizon (sRGB)
---@return nil
function ProceduralSky:SetGroundHorizonColor(color) end

---@param curve number Horizon-to-bottom blend curve, > 0 (default 0.02)
---@return nil
function ProceduralSky:SetGroundCurve(curve) end

---@param energy number Multiplier of the ground colors (default 1)
---@return nil
function ProceduralSky:SetGroundEnergy(energy) end

---@param degrees number Angular radius where the sun glow ends (default 30)
---@return nil
function ProceduralSky:SetSunAngleMax(degrees) end

---@param curve number Sun glow falloff curve, > 0 (default 0.15)
---@return nil
function ProceduralSky:SetSunCurve(curve) end

---@param degrees number Apparent sun disc diameter (default 0.5)
---@return nil
function ProceduralSky:SetSunDiskSize(degrees) end

---@param energy number Sun radiance relative to the light's color * brightness (default 1)
---@return nil
function ProceduralSky:SetSunEnergy(energy) end

---@param exposure number Multiplier of the final sky color (default 1)
---@return nil
function ProceduralSky:SetExposure(exposure) end

--- Follow this directional light's direction, color and brightness as the sun; nil draws no sun.
---@param light Light|nil Directional light
---@return nil
function ProceduralSky:SetSunLight(light) end

---@return Color
function ProceduralSky:GetSkyTopColor() end

---@return Color
function ProceduralSky:GetSkyHorizonColor() end

---@return number
function ProceduralSky:GetSkyCurve() end

---@return number
function ProceduralSky:GetSkyEnergy() end

---@return Color
function ProceduralSky:GetGroundBottomColor() end

---@return Color
function ProceduralSky:GetGroundHorizonColor() end

---@return number
function ProceduralSky:GetGroundCurve() end

---@return number
function ProceduralSky:GetGroundEnergy() end

---@return number
function ProceduralSky:GetSunAngleMax() end

---@return number
function ProceduralSky:GetSunCurve() end

---@return number
function ProceduralSky:GetSunDiskSize() end

---@return number
function ProceduralSky:GetSunEnergy() end

---@return number
function ProceduralSky:GetExposure() end

---@return Light
function ProceduralSky:GetSunLight() end

--- Skybox this component renders through.
---@return Skybox
function ProceduralSky:GetSkybox() end

--- Built-in sky material; tweak other uniforms here only if you know the shader.
---@return Material
function ProceduralSky:GetMaterial() end

