---@meta

--- Auto-generated from Graphics/GrassField

---@alias GrassPlantType
---| integer # GrassPlantType enum values

---@type GrassPlantType
--- Curved grass blades.
GRASS_PLANT_BLADE = 0
---@type GrassPlantType
--- Thin stems carrying a flower head (a cupped fan of petals); three green petals make clover.
GRASS_PLANT_FLOWER = GRASS_PLANT_FLOWER

---@class GrassField : Drawable
---@field material Material
---@field density number
---@field plantType GrassPlantType
---@field petalCount integer
---@field flowerSize number
---@field flowerCup number
---@field bladeHeight Vector2
---@field bladeWidth Vector2
---@field lean number
---@field clumpSize number
---@field clumpHeightVariation number
---@field clumpPointing number
---@field viewDistance number
---@field lodDistance number
---@field farLodDistance number
---@field densityFalloffDistance number
---@field maxSlope number
---@field windDirection Vector2
---@field windStrength number
---@field windSpeed number
---@field gustSize number
---@field flutter number
---@field densityMap Texture2D
---@field densityChannel integer
---@field densityRange Vector2
---@field colorMap Texture2D
---@field controlMap Texture2D
---@field fieldSize Vector2
---@field interactionStrength number
---@field trampleRecoveryTime number
---@field trampleAreaSize number
---@field supported boolean
GrassField = {}

--- Material drawing the blades; its technique must not have a shadow pass. nil restores the built-in material
--- (Materials/GrassField.xml, or Materials/GrassFlowerField.xml for flower fields).
---@param material Material|nil Blade material
---@return nil
function GrassField:SetMaterial(material) end

---@param density number Blades per square meter near the camera (default 200)
---@return nil
function GrassField:SetDensity(density) end

--- Flowers use the stem settings of the blades (height, width, lean, wind) plus petalCount, flowerSize, flowerCup
--- and the flower colors of the material. Several fields on one node make mixed meadows.
---@param type GrassPlantType What the field grows (default GRASS_PLANT_BLADE)
---@return nil
function GrassField:SetPlantType(type) end

---@param count integer Petals per flower head, 3 .. 8 (default 5)
---@return nil
function GrassField:SetPetalCount(count) end

---@param radius number Flower head radius in meters, up to 0.25 (default 0.03)
---@return nil
function GrassField:SetFlowerSize(radius) end

---@param cup number Rise of the petal tips as a fraction of the head radius, 0 .. 0.5 (default 0.35)
---@return nil
function GrassField:SetFlowerCup(cup) end

---@param range Vector2 Blade height range in meters (default 0.35, 0.75)
---@return nil
function GrassField:SetBladeHeight(range) end

---@param range Vector2 Blade root width range in meters (default 0.007, 0.014)
---@return nil
function GrassField:SetBladeWidth(range) end

---@param lean number Rest lean, tip offset over blade height, 0..1 (default 0.5)
---@return nil
function GrassField:SetLean(lean) end

---@param size number Clump cell size in meters (default 0.8)
---@return nil
function GrassField:SetClumpSize(size) end

---@param variation number Height difference between clumps, 0..1 (default 0.35)
---@return nil
function GrassField:SetClumpHeightVariation(variation) end

---@param pointing number How strongly blades lean away from their clump center, 0..1 (default 0.5)
---@return nil
function GrassField:SetClumpPointing(pointing) end

---@param distance number Distance in meters where grass ends, fading over the last 15% (default 120)
---@return nil
function GrassField:SetViewDistance(distance) end

---@param distance number Distance in meters up to which blades use the detailed curved mesh (default 18; x0.55 in the reduced quality tier)
---@return nil
function GrassField:SetLodDistance(distance) end

---@param distance number Distance in meters beyond which blades are single triangles (default 40; in the reduced quality tier density also falls off faster beyond it)
---@return nil
function GrassField:SetFarLodDistance(distance) end

---@param distance number Distance in meters after which density falls off and blades widen (default 5; x0.8 in the reduced quality tier)
---@return nil
function GrassField:SetDensityFalloffDistance(distance) end

---@param degrees number Terrain slope above which no grass grows (default 50)
---@return nil
function GrassField:SetMaxSlope(degrees) end

---@param direction Vector2 Horizontal wind direction (x, z) (default 1, 0.3)
---@return nil
function GrassField:SetWindDirection(direction) end

---@param strength number Average tip offset over blade height, 0 = no wind (default 0.35)
---@return nil
function GrassField:SetWindStrength(strength) end

---@param speed number Speed of gusts traveling downwind in m/s (default 4)
---@return nil
function GrassField:SetWindSpeed(speed) end

---@param size number Typical gust size in meters (default 12)
---@return nil
function GrassField:SetGustSize(size) end

---@param flutter number Per-blade flutter relative to the wind strength (default 0.4)
---@return nil
function GrassField:SetFlutter(flutter) end

--- Grass grows where the density map is high; a Terrain weight map works directly. The field reads the map back
--- (asynchronously) to skip tiles where it grows nothing; painting into the map is picked up automatically.
---@param texture Texture2D|nil Density map covering the field, nil = everywhere
---@return nil
function GrassField:SetDensityMap(texture) end

---@param channel integer Density map channel, 0 = R .. 3 = A (default 0)
---@return nil
function GrassField:SetDensityChannel(channel) end

---@param range Vector2 Density map values meaning no grass and full grass (default 0.2, 0.8)
---@return nil
function GrassField:SetDensityRange(range) end

--- Blade roots take the color of this map, which blends the grass into the ground.
---@param texture Texture2D|nil Color map covering the field, nil = material colors only
---@return nil
function GrassField:SetColorMap(texture) end

--- Varies the grass by area. R scales blade height (1 = bladeHeight range, 0 = no grass), G dries clumps out
--- (0 = material dry share, 1 = every clump dry); B and A are reserved, keep them 0. Same layout as the density map.
---@param texture Texture2D|nil Control map covering the field, nil = uniform grass
---@return nil
function GrassField:SetControlMap(texture) end

---@param size Vector2 Size (x, z) of a flat field without Terrain, in node units (default 100, 100)
---@return nil
function GrassField:SetFieldSize(size) end

--- Blades within radius of position bend away from it; update it every frame for moving characters.
---@param index integer Interactor slot 0 .. MAX_GRASS_INTERACTORS - 1
---@param position Vector3 World position, e.g. a character's feet
---@param radius number Radius in meters; 0 disables the slot
---@return nil
function GrassField:SetInteractor(index, position, radius) end

--- Disable all interactors.
---@return nil
function GrassField:ClearInteractors() end

---@param strength number Tip offset over blade height at an interactor's center (default 1.4)
---@return nil
function GrassField:SetInteractionStrength(strength) end

--- Blades pressed by interactors stand up again over this time after the interactor left, leaving a trail.
---@param seconds number Recovery time in seconds, 0 = no trails (default 6)
---@return nil
function GrassField:SetTrampleRecoveryTime(seconds) end

--- Trails are kept in a square area around the camera, 512 texels wide; larger areas give coarser trails.
---@param size number Side of the trail area in meters (default 64)
---@return nil
function GrassField:SetTrampleAreaSize(size) end

---@return Material
function GrassField:GetMaterial() end

---@return number
function GrassField:GetDensity() end

---@return GrassPlantType
function GrassField:GetPlantType() end

---@return integer
function GrassField:GetPetalCount() end

---@return number
function GrassField:GetFlowerSize() end

---@return number
function GrassField:GetFlowerCup() end

---@return Vector2
function GrassField:GetBladeHeight() end

---@return Vector2
function GrassField:GetBladeWidth() end

---@return number
function GrassField:GetLean() end

---@return number
function GrassField:GetClumpSize() end

---@return number
function GrassField:GetClumpHeightVariation() end

---@return number
function GrassField:GetClumpPointing() end

---@return number
function GrassField:GetViewDistance() end

---@return number
function GrassField:GetLodDistance() end

---@return number
function GrassField:GetFarLodDistance() end

---@return number
function GrassField:GetDensityFalloffDistance() end

---@return number
function GrassField:GetMaxSlope() end

---@return Vector2
function GrassField:GetWindDirection() end

---@return number
function GrassField:GetWindStrength() end

---@return number
function GrassField:GetWindSpeed() end

---@return number
function GrassField:GetGustSize() end

---@return number
function GrassField:GetFlutter() end

---@return Texture2D
function GrassField:GetDensityMap() end

---@return integer
function GrassField:GetDensityChannel() end

---@return Vector2
function GrassField:GetDensityRange() end

---@return Texture2D
function GrassField:GetColorMap() end

---@return Texture2D
function GrassField:GetControlMap() end

---@return Vector2
function GrassField:GetFieldSize() end

---@return number
function GrassField:GetInteractionStrength() end

---@return number
function GrassField:GetTrampleRecoveryTime() end

---@return number
function GrassField:GetTrampleAreaSize() end

--- Whether this device can render grass (compute shaders and draw-indirect).
---@return boolean
function GrassField:IsSupported() end


-- Global variables
---@type integer
MAX_GRASS_INTERACTORS = nil
