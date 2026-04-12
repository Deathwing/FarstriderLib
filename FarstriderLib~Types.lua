-- FarstriderLib~Types.lua
-- local _, FarstriderLib = ...

if not FarstriderLib.Internal then return end

---@class FarstriderLibAPI
---@field VERSION number the version of the API
---@field DATA FarstriderLibDataAPI access to the data API, which may be incomplete until the library is fully initialized
---@field Rebuild fun() clears the pathfinding cache and re-initializes. Call this after updating any data.
---@field FindTrail fun(startMapId: number, startX: number, startY: number, startZ: number, goalMapId: number, endX: number, endY: number, endZ: number): table[]?, NavNode[]?, NavEdge[]? finds a path between two points and returns the optimized path, full path, and edges
---@field FindTrailTo fun(goalMapId: number, endX: number, endY: number, endZ: number): table[]?, NavNode[]?, NavEdge[]? finds a path from the player's current location to a goal point and returns the optimized path, full path, and edges

---------------------------------------------------------------------------
-- Navigation graph structures (runtime)
---------------------------------------------------------------------------

--- A position within the navigation graph (always UI-space).
---@class NavLocation : Location
---@field mapId MapId
---@field pos Vec3
---@field isUI boolean

--- A directed edge in the navigation graph.
---@class NavEdge
---@field to NavNode              Target node
---@field cost number             Estimated travel time in seconds
---@field flag number             WaypointLocation flags copy
---@field locaId number?          Edge type constant (EdgeType enum value)
---@field locaArgs? fun(): any[]  Lazy arguments for the localized string
---@field condition? fun(): boolean
---@field actionOptions? ActionOption[]
---@field type number
---@field important boolean

---------------------------------------------------------------------------
-- Aliases
---------------------------------------------------------------------------

---@alias UIMapId number -- UI-space map ID
---@alias NavKey string  -- Deterministic node key: "mapId:x:y:z"
