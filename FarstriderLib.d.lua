-- FarstriderLib.d.lua

---@class FarstriderLib
---@field Internal _fl
---@field VERSION number
---@field media_path string Addon media root, e.g. "Interface\\AddOns\\FarstriderLib\\"
---@field EdgeType table<string, number>
---@field Pathfinding Pathfinding
---@field NavNode NavNode
---@field Logger Logger
---@field Debug table
---@field _debugStartLocation? Location
---@field _debugGoalLocation? Location
---@field _debugStartButton? any
---@field _debugGoalButton? any
---@field _setWaypointImpl? fun(waypoint: Location, texture: string, options?: table)
FarstriderLib = {}

local _fl = FarstriderLib.Internal ---@class _fl
