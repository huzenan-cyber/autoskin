---@meta

---Server-side IAP API. Available only in UrhoXServer game scripts.
---Backed by the IAP subsystem (game/src/Engine/IAP).
---Both functions are plain table fields: call them with a dot, no self.
---@class ServerShop
Shop = {}

---@class ShopUserOrdersCursor
---@field createdAt string Database timestamp returned by the previous page; pass it back unchanged
---@field orderId string Order ID returned by the previous page

---@class ShopUserOrdersOptions
---@field startTime? integer Inclusive created-at Unix timestamp in seconds; must be paired with endTime
---@field endTime? integer Exclusive created-at Unix timestamp in seconds; must be paired with startTime
---@field pageSize? integer Page size from 1 to 100; defaults to 20
---@field cursor? ShopUserOrdersCursor Cursor returned by the previous page

---@alias ShopDeliveryStatus
---| "pending_delivery" # Waiting for delivery
---| "delivered" # Delivery completed
---| "retrying" # Delivery retry in progress
---| "failed" # Delivery failed

---@class ShopUserOrder
---@field orderId string Platform Maker order ID
---@field productId string Merchant SKU ID; use this stable field to identify the product
---@field product table|nil Product snapshot captured when the order was created; its shape follows the historical product configuration and may contain id, name, price, tag, and delivery. Numeric values larger than Lua's exact integer range should be stored as strings by the producer.
---@field amount string Paid amount in CNY yuan, represented as an exact decimal string such as "6.00"
---@field deliveryStatus ShopDeliveryStatus|nil Delivery state
---@field createdAt number Order creation Unix timestamp in seconds
---@field deliveredAt number|nil Delivery completion Unix timestamp in seconds; nil before delivery

---@class ShopUserOrdersResult
---@field ok boolean Whether the query succeeded
---@field totalAmount? string Total paid amount in CNY yuan for the complete query range
---@field orderCount? string Total verified order count for the complete query range
---@field currency? string Currency code; currently CNY
---@field orders? ShopUserOrder[] Current page of orders
---@field nextCursor? ShopUserOrdersCursor Cursor for the next page; nil on the last page
---@field error? string Stable error code when ok is false
---@field message? string Error description when ok is false
---@field httpStatus? integer Payment-service HTTP status, or 0 for a network error
---@field retryable? boolean Whether retrying the query may succeed

---Query verified orders for a player in the current game and environment.
---The callback runs asynchronously on the server main thread.
---@param userId integer Maker user ID
---@param options ShopUserOrdersOptions|nil
---@param callback fun(result: ShopUserOrdersResult)
---@overload fun(userId: integer, callback: fun(result: ShopUserOrdersResult))
function Shop.getUserOrders(userId, options, callback) end

---@class ShopDeliveryContext
---@field orderId string Platform order ID
---@field userId integer Maker user ID
---@field productId string Merchant SKU ID
---@field productJson string Product snapshot JSON
---@field conn Connection|nil Current player connection

---Register the server-side delivery handler.
---@param callback fun(context: ShopDeliveryContext)
function Shop.onDeliver(callback) end
