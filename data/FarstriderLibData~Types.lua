-- FarstriderLibData~Types.lua
-- local _, FarstriderLibData = ...

if not FarstriderLibData.Internal then return end

---@class WaypointLocale
---@field enUS string English US locale
---@field deDE string German locale
---@field esES string Spanish (Spain) locale
---@field esMX string Spanish (Mexico) locale
---@field frFR string French locale
---@field itIT string Italian locale
---@field koKR string Korean locale
---@field ptBR string Portuguese (Brazil) locale
---@field ruRU string Russian locale
---@field zhCN string Chinese (Simplified) locale
---@field zhTW string Chinese (Traditional) locale

--- Describes an action the player can take (item use, spell cast, etc.).
---@class ActionOption
---@field type string  Action category: "item", "spell", "housing", "housing_return"
---@field data any     Payload (e.g. itemId or spellId)
---@field allowAny? boolean  If true, any matching action in the group suffices

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

---@alias MapId number   -- Continent or instance map ID (world coordinates)

---@class Config
---@field ElevationOverrides { [MapId]: number } mapId -> z coordinate
---@field MapTypeOverrides { [MapId]: { mapType: Enum.UIMapType } } mapId -> { mapType = Enum.UIMapType.* }
---@field IsolatedAreas { [MapId]: number } mapId -> groupId (same groupId = same isolated area)
---@field IgnoredMaps { [MapId]: boolean } mapId -> whether the map should be ignored for pathfinding (no paths will go through it)
---@field IsolatedZones { [MapId]: boolean } mapId -> whether the map is an isolated zone (no paths will start or end in it, but paths may go through it if necessary)

---@class FarstriderLibDataAPI
---@field VERSION number the version of the API
---@field WAYPOINTS Waypoint[] a list of all waypoint connections in the world, including localized text and dynamic conditions
---@field CONFIG Config the configuration data
---@field GetLocalizedString fun(locaId: number): string|nil returns the raw (unformatted) localized string for a locaId, or a fallback or nil if not available
---@field IsBindLocationSupported fun(): boolean returns whether the player's current bind location is supported
---@field GetHousingData fun(): HouseInfo|nil returns the housing data of the player, or nil if not available
---@field UpdateHousingExitLocation fun() updates the player's housing exit location to their current location, if housing data is available
---@field GetHelpfulItems fun(): number[] returns a list of helpful item IDs that the player has, or an empty table if not available
