---@meta

--- Auto-generated from Graphics/ComputeDispatch

---@class ComputeReadback : Object
ComputeReadback = {}

--- Return whether data or an error is available without waiting for the GPU.
---@return boolean
function ComputeReadback:IsReady() end

--- Return whether the request failed or was cancelled.
---@return boolean
function ComputeReadback:HasError() end

--- Return the failure diagnostic, or an empty string.
---@return string
function ComputeReadback:GetError() end

--- Return a copy of the completed snapshot, or an empty buffer before success.
---@return VectorBuffer
function ComputeReadback:GetData() end


---@class ComputeBuffer : Object
---@overload fun(): ComputeBuffer
ComputeBuffer = {}

---@return ComputeBuffer
function ComputeBuffer.new() end

--- Allocate zero-initialized storage with 1..2^24 elements; failure preserves previous storage.
---@param elementType string
---@param count integer
---@return boolean
function ComputeBuffer:SetSize(elementType, count) end

--- Allocate storage initialized with exactly count * stride bytes.
---@param elementType string
---@param count integer
---@param data VectorBuffer
---@return boolean
function ComputeBuffer:SetSize(elementType, count, data) end

--- Release storage and invalidate queued bindings.
---@return nil
function ComputeBuffer:Release() end

--- Return the element spelling used by shader buffer declarations.
---@return string
function ComputeBuffer:GetElementType() end

--- Return the allocated element count.
---@return integer
function ComputeBuffer:GetCount() end

--- Return the element size in bytes.
---@return integer
function ComputeBuffer:GetStride() end

--- Queue an asynchronous snapshot at this point in the compute queue.
--- Lua retains the returned request after completion, rejection or cancellation.
---@return ComputeReadback
function ComputeBuffer:RequestReadback() end

--- Return the most recent allocation error; readback requests carry their own diagnostics.
---@return string
function ComputeBuffer:GetLastError() end


---@class ComputeDispatch : Object
---@overload fun(): ComputeDispatch
ComputeDispatch = {}

---@return ComputeDispatch
function ComputeDispatch.new() end

--- Load and prepare a compute .shader for the active device; failure preserves previous state.
---@param resourceName string
---@return boolean
function ComputeDispatch:SetShader(resourceName) end

--- Bind a compute resource, resetting parameters and bindings after successful preparation.
---@param shader SurfaceShader
---@return boolean
function ComputeDispatch:SetShader(shader) end

--- Set a uniform by source name; dense Lua tables represent vectors, matrices or uniform arrays.
---@param value number|boolean|Vector2|Vector3|Vector4|Color|IntVector2|IntVector3|Matrix3|Matrix4|table|VectorBuffer|Variant
---@param name string
---@return boolean
function ComputeDispatch:SetShaderParameter(name, value) end

--- Bind a single-sample Texture2D sampler input, or nil to clear it.
---@param name string
---@param texture Texture
---@return boolean
function ComputeDispatch:SetTexture(name, texture) end

--- Bind a linear storage image with matching format, mip and compute-write capability.
---@param name string
---@param texture Texture
---@param mip? integer
---@return boolean
function ComputeDispatch:SetImage(name, texture, mip) end

--- Bind independently created storage with matching element type, or nil to clear it.
---@param name string
---@param buffer ComputeBuffer
---@return boolean
function ComputeDispatch:SetBuffer(name, buffer) end

--- Create and bind a writable single-mip texture using the declared image format.
--- Lua retains the texture after unbinding or resetting the shader; failure returns nil.
---@param name string
---@param width integer
---@param height integer
---@return Texture2D
function ComputeDispatch:CreateImage2D(name, width, height) end

--- Create and bind zero-initialized storage using the declared element type.
--- Lua retains the buffer after unbinding or resetting the shader; failure returns nil.
---@param name string
---@param count integer
---@return ComputeBuffer
function ComputeDispatch:CreateBuffer(name, count) end

--- Create and bind storage initialized with exactly count * stride bytes.
--- Lua retains the buffer after unbinding or resetting the shader; failure returns nil.
---@param name string
---@param count integer
---@param data VectorBuffer
---@return ComputeBuffer
function ComputeDispatch:CreateBuffer(name, count, data) end

--- Return the declared local workgroup dimensions, or zero before successful preparation.
---@return IntVector3
function ComputeDispatch:GetWorkgroupSize() end

--- Queue logical threads; padded invocations are masked. Axes must be nonnegative integers.
---@param x number
---@param y? number
---@param z? number
---@return boolean
function ComputeDispatch:DispatchThreads(x, y, z) end

--- Queue complete workgroups; the shader must guard its own data bounds.
---@param x number
---@param y? number
---@param z? number
---@return boolean
function ComputeDispatch:DispatchGroups(x, y, z) end

--- Return the most recent preparation, binding or submission error.
---@return string
function ComputeDispatch:GetLastError() end

