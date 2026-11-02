---@meta

--- Auto-generated from Network/Transport

---@alias TransportProtocol
---| integer # TransportProtocol enum values

---@type TransportProtocol
TRANSPORT_SLIKENET = TRANSPORT_SLIKENET
---@type TransportProtocol
TRANSPORT_WEBSOCKET = TRANSPORT_WEBSOCKET
---@type TransportProtocol
TRANSPORT_KCP = TRANSPORT_KCP

-- Global functions
---@param protocol TransportProtocol
---@return boolean
function TransportIsSupported(protocol) end
