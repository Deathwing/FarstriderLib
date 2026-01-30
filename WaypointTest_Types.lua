-- WaypointTest_Types.lua
-- local _, WPT = ...

---@class WaypointConnection
---@field from NavNode
---@field to NavNode
---@field bidirectional boolean

---@class NavLocation
---@field mapId MapId
---@field pos Vec3
---@field isUI boolean

---@class NavEdge
---@field to NavNode
---@field cost number
---@field flag number
---@field locaId number?
---@field locaArgs? table
---@field condition? fun(): boolean
---@field actionOptions? ActionOption[]
---@field type number
---@field important boolean

---@alias MapId number
---@alias UIMapId number
---@alias NavKey string
