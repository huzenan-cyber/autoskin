---@meta

--- Auto-generated from Scene/SceneArchive

---@class SceneArchive
SceneArchive = {}

--- Return success and an error string. options.data is bounded cmsgpack data.
--- File streams write directly to disk; VectorBuffer explicitly opts into memory output.
---@param destination File|VectorBuffer
---@param scene Scene
---@param options? any
---@return boolean success
---@return string? error
function SceneArchive:Save(scene, destination, options) end

--- Return a new Scene and auxiliary data, or nil and an error string.
---@param source File|VectorBuffer
---@param options? any
---@return Scene? scene
---@return any dataOrError
function SceneArchive:Load(source, options) end


-- Global variables
---@type SceneArchive
sceneArchive = nil
