-- FarstriderLib~Types.lua
-- local _, FarstriderLib = ...

if not FarstriderLib.Internal then return end

---@meta
-- EmmyLua type definitions for FarstriderLib.
-- Stripped in production via MRP_REMOVE_LINE.

---------------------------------------------------------------------------
-- Primitives
---------------------------------------------------------------------------

--- A 3-component vector used for map positions.
---@class Vec3
---@field x number
---@field y number
---@field z number

--- A resolved map location (UI or world coordinates).
---@class Location
---@field mapId number
---@field pos Vec3
---@field isUI? boolean

---------------------------------------------------------------------------
-- Waypoint data structures
---------------------------------------------------------------------------

--- Describes an action the player can take (item use, spell cast, etc.).
---@class ActionOption
---@field type string  Action category: "item", "spell", "housing", "housing_return"
---@field data any     Payload (e.g. itemId or spellId)
---@field allowAny? boolean  If true, any matching action in the group suffices

--- One end of a waypoint connection — either the source or destination.
---@class WaypointLocation
---@field locaId number             Edge type or localization key
---@field locaArgs? fun(): any[]    Lazy arguments for the localized format string
---@field flags number              Bitfield: 8 = originates from player
---@field loc? Location             Static position (nil for dynamic nodes)
---@field dynLoc? fun(): Location   Dynamic position resolver (e.g. player location)
---@field type number               1 = origin, 2 = destination
---@field unknown1 number           Reserved / unused
---@field condition? fun(): boolean Runtime availability check
---@field actionOptions? ActionOption[]
---@field important? boolean        If true, the step is never collapsed during path optimization

--- A bidirectional or one-way connection between two waypoint locations.
---@class Waypoint
---@field id number
---@field from WaypointLocation
---@field to WaypointLocation
---@field bidirectional boolean
---@field cost number               Travel time estimate in seconds
---@field condition? fun(): boolean Runtime availability check

---@class WaypointConnection
---@field from NavNode
---@field to NavNode
---@field bidirectional boolean

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

---@alias MapId number   -- Continent or instance map ID (world coordinates)
---@alias UIMapId number -- UI-space map ID
---@alias NavKey string  -- Deterministic node key: "mapId:x:y:z"

---------------------------------------------------------------------------
-- Saved variables
---------------------------------------------------------------------------

---@class FarstriderDataCharacterSettings
---@field housingExitLocation? NavLocation

---------------------------------------------------------------------------
-- External globals (third-party addons / WoW constants)
---------------------------------------------------------------------------

---@type table?
DevTool = DevTool

---@type table?
TomTom = TomTom

---@type number?
WOW_PROJECT_MISTS_CLASSIC = WOW_PROJECT_MISTS_CLASSIC

---@type Frame?
FarstriderLibMapOverlay = FarstriderLibMapOverlay
