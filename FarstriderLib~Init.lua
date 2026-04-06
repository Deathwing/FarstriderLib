-- FarstriderLib~Init.lua
-- Versioned global initialization (DNL pattern).
-- Higher-versioned copies silently replace lower ones.

---@class FarstriderLib
---@field VERSION number
---@field media_path string Addon media root, e.g. "Interface\\AddOns\\WaypointTest\\"
---@field EdgeType table<string, number>
---@field Pathfinding Pathfinding
---@field NavNode NavNode
---@field Logger Logger
---@field Util FarstriderLibUtil
---@field UI FarstriderLibUI
---@field Debug table
---@field _debugStartLocation? Location
---@field _debugGoalLocation? Location
---@field _debugStartButton? any
---@field _debugGoalButton? any
---@field _setWaypointImpl? fun(waypoint: Location, texture: string, options?: table)

local VERSION = 1

if FarstriderLib and (FarstriderLib.VERSION or 0) >= VERSION then return end

---@class FarstriderLib
FarstriderLib = FarstriderLib or {}
FarstriderLib.VERSION = VERSION

--- Auto-detect media path from this file's location via `debugstack`.
FarstriderLib.media_path = string.match(debugstack(1, 1, 0), "AddOns\\(.-)\\") or "WaypointTest"
FarstriderLib.media_path = "Interface\\AddOns\\" .. FarstriderLib.media_path .. "\\"

--- Navigation edge categories.
---@enum EdgeType
FarstriderLib.EdgeType = {
    TRAVEL     = 1, -- Direct overland / dragonriding travel
    FLIGHTPATH = 2, -- Flight master route
    BOAT       = 3, -- Boat transport
    ZEPPELIN   = 4, -- Zeppelin transport
    PORTAL     = 5, -- Portal (mage portal, world portal, housing)
    ITEM       = 6, -- Consumable item (hearthstone, wormhole, etc.)
    SPELL      = 7, -- Player spell (teleport, astral recall, etc.)
}
