---@class Vec3
---@field x number
---@field y number
---@field z number

---@class Location
---@field mapId number
---@field pos Vec3
---@field isUI boolean

---@class ActionOption
---@field type string
---@field data any

---@class WaypointLocation
---@field locaId number
---@field locaArgs? table
---@field flags number
---@field loc? Location
---@field dynLoc? fun(): Location
---@field type number
---@field unknown1 number
---@field condition? fun(): boolean
---@field actionOptions? ActionOption[]
---@field important? boolean

---@class Waypoint
---@field id number
---@field from WaypointLocation
---@field to WaypointLocation
---@field bidirectional boolean
---@field cost number
---@field condition? fun(): boolean
