-- FarstriderData~Init.lua
-- Versioned global initialization for the navigation dataset.
-- Provides configuration tables and a builder API for connections.

local VERSION = 1

if FarstriderData and (FarstriderData.VERSION or 0) >= VERSION then return end

---@class FarstriderData
FarstriderData = FarstriderData or {}
FarstriderData.VERSION = VERSION

--- Waypoint array populated by data files (Waypoints.lua, Connections.lua).
---@type Waypoint[]
FarstriderData.Waypoints = FarstriderData.Waypoints or {}

--- Runtime metadata attached to connections.
FarstriderData.Connections = FarstriderData.Connections or {
    helpfulItems = {} ---@type number[]  Item IDs the player might benefit from owning
}

--- General localization strings, keyed by "Category_id".
FarstriderData.L = FarstriderData.L or {}
--- Area name -> resolved NavLocation lookup (for hearthstone bind matching).
FarstriderData.AreaL = FarstriderData.AreaL or {}
--- locaId -> localized format string (e.g. "Take flight to %s").
FarstriderData.WaypointL = FarstriderData.WaypointL or {}

--- Pathfinding configuration consumed by FarstriderLib.Pathfinding.
---@type FarstriderDataConfig
FarstriderData.Config = FarstriderData.Config or {}

-- Elevation overrides: mapId -> z coordinate
FarstriderData.Config.ElevationOverrides = {
    -- Shadowlands
    [1525] = 4275, -- Revendreth
    [1688] = 4275, -- Revendreth

    [1533] = 6534, -- Bastion

    [1536] = 3307, -- Maldraxxus
    [1689] = 3307, -- Maldraxxus

    [1543] = 4870, -- The Maw
    [1648] = 4870, -- The Maw
    [1911] = 4870, -- Torghast - Entrance
    [1960] = 4870, -- The Maw
    [1961] = 4870, -- Korthia

    [1550] = 5270, -- Shadowlands

    [1565] = 5581, -- Ardenweald
    [1603] = 5581, -- Ardenweald
    [1709] = 5581, -- Ardenweald
    [2005] = 5581, -- Ardenweald

    [1670] = 5270, -- Ring of Fates
    [1671] = 5450, -- Ring of Transference
    [1672] = 5250, -- The Broker's Den
    [1673] = 5630, -- The Crucible

    [2016] = 4789, -- Tazavesh, the Veiled Market

    -- Dragonflight
    [2023] = 200, -- Ohn'ahran Plains
    [2024] = 446, -- The Azure Span
    [2025] = 888, -- Thaldraszus
    [2112] = 888, -- Valdrakken
}

-- Map type overrides: mapId -> { mapType = Enum.UIMapType.* }
FarstriderData.Config.MapTypeOverrides = {
    [125] = { mapType = 3 },  -- Dalaran: Northrend (Zone)
    [627] = { mapType = 3 },  -- Dalaran: Broken Isles (Zone)
    [1670] = { mapType = 3 }, -- Oribos (Zone)
    [1671] = { mapType = 3 }, -- Oribos (Zone)
    [1672] = { mapType = 3 }, -- Oribos (Zone)
    [1673] = { mapType = 3 }, -- Oribos (Zone)
    [2305] = { mapType = 3 }, -- Dalaran (Zone)
}

-- Isolated area groups: mapId -> groupId (same groupId = same isolated area)
FarstriderData.Config.IsolatedAreas = {
    -- Eastern Kingdom
    [201] = 0, -- Kelp'thar Forest
    [203] = 0, -- Vashj'ir
    [204] = 0, -- Abyssal Depths
    [205] = 0, -- Shimmering Expanse

    [244] = 1, -- Tol Barad
    [245] = 1, -- Tol Barad Peninsula

    -- Pandaria
    [504] = -2, -- Isle of Thunder

    -- Kul Tiras / Zandalar
    [1355] = -1, -- Nazjatar

    -- Shadowlands
    [1525] = 2, -- Revendreth
    [1688] = 2, -- Revendreth

    [1533] = 3, -- Bastion

    [1536] = 4, -- Maldraxxus
    [1689] = 4, -- Maldraxxus

    [1543] = 5, -- The Maw
    [1648] = 5, -- The Maw
    [1911] = 5, -- Torghast - Entrance
    [1960] = 5, -- The Maw
    [1961] = 5, -- Korthia

    [1565] = 6, -- Ardenweald
    [1603] = 6, -- Ardenweald
    [1709] = 6, -- Ardenweald
    [2005] = 6, -- Ardenweald

    [1670] = 7, -- Ring of Fates
    [1671] = 7, -- Ring of Transference
    [1672] = 7, -- The Broker's Den
    [1673] = 7, -- The Crucible

    [1970] = 8, -- Zereth Mortis

    [2016] = 9, -- Tazavesh, the Veiled Market

    -- Dragonflight
    [2133] = 10, -- Zaralek Cavern

    [2200] = 11, -- Emerald Dream
}

-- Maps to skip entirely during graph construction
FarstriderData.Config.IgnoredMaps = {
    [2311] = true,
}

-- Maps where navigation should not try to auto-connect to nearby zones
FarstriderData.Config.IsolatedZones = {
    [2248] = true, -- Dornogol
    [2346] = true, -- Undermine
}

---------------------------------------------------------------------------
-- Builder API
-- High-level helpers that construct WaypointLocation pairs and insert them
-- into FarstriderData.Waypoints.  Each category uses a separate counter
-- so waypoint IDs are deterministic within their range:
--   1000+ flightpaths, 2000+ boats, 3000+ zeppelins,
--   4000+ portals, 5000+ items, 6000+ spells.
---------------------------------------------------------------------------
local Lib = FarstriderLib
local ET = Lib.EdgeType
local Data = FarstriderData

local entryCount = 0

--- Insert a raw waypoint entry into the Waypoints array.
---@param id number
---@param from WaypointLocation
---@param to WaypointLocation
---@param bidirectional boolean
---@param cost number
local function addEntry(id, from, to, bidirectional, cost)
    local entry = { id = id, from = from, to = to, bidirectional = bidirectional, cost = cost } ---@type Waypoint
    table.insert(Data.Waypoints, entry)
    entryCount = entryCount + 1
end

local flightpathCount = 0

--- Register a bidirectional flight-master route.
---@param fromMapId number
---@param fromPos Vec3|table  World or UI position
---@param fromIsUI boolean
---@param fromAreaId number   AreaID for localization
---@param toMapId number
---@param toPos Vec3|table
---@param toIsUI boolean
---@param toAreaId number
---@param cost number         Estimated flight time in seconds
---@param condition? fun(): boolean
function FarstriderData.AddFlightpath(fromMapId, fromPos, fromIsUI, fromAreaId, toMapId, toPos, toIsUI, toAreaId, cost,
                                      condition)
    local L = Data.L
    local from = { unknown1 = 0, flags = 0, loc = { mapId = fromMapId, pos = fromPos, isUI = fromIsUI }, condition =
    condition, type = 1, important = true, locaId = ET.FLIGHTPATH, locaArgs = function() return { C_Map.GetAreaInfo(
        toAreaId) or L["Area_" .. toAreaId] or ("Area " .. toAreaId) } end }
    local to = { unknown1 = 0, flags = 0, loc = { mapId = toMapId, pos = toPos, isUI = toIsUI }, condition = condition, type = 1, important = true, locaId =
    ET.FLIGHTPATH, locaArgs = function() return { C_Map.GetAreaInfo(fromAreaId) or L["Area_" .. fromAreaId] or
        ("Area " .. fromAreaId) } end }
    addEntry(1000 + flightpathCount, from, to, true, cost)
    flightpathCount = flightpathCount + 1
end

local boatCount = 0

--- Register a bidirectional boat route.
---@param fromMapId number
---@param fromPos Vec3|table
---@param fromIsUI boolean
---@param fromAreaId number
---@param toMapId number
---@param toPos Vec3|table
---@param toIsUI boolean
---@param toAreaId number
---@param cost number
---@param condition? fun(): boolean
function FarstriderData.AddBoat(fromMapId, fromPos, fromIsUI, fromAreaId, toMapId, toPos, toIsUI, toAreaId, cost,
                                condition)
    local L = Data.L
    local from = { unknown1 = 0, flags = 0, loc = { mapId = fromMapId, pos = fromPos, isUI = fromIsUI }, condition =
    condition, type = 1, important = true, locaId = ET.BOAT, locaArgs = function() return { C_Map.GetAreaInfo(fromAreaId) or
        L["Area_" .. fromAreaId] or ("Area " .. fromAreaId), C_Map.GetAreaInfo(toAreaId) or L["Area_" .. toAreaId] or
        ("Area " .. toAreaId) } end }
    local to = { unknown1 = 0, flags = 0, loc = { mapId = toMapId, pos = toPos, isUI = toIsUI }, condition = condition, type = 1, important = true, locaId =
    ET.BOAT, locaArgs = function() return { C_Map.GetAreaInfo(toAreaId) or L["Area_" .. toAreaId] or
        ("Area " .. toAreaId), C_Map.GetAreaInfo(fromAreaId) or L["Area_" .. fromAreaId] or ("Area " .. fromAreaId) } end }
    addEntry(2000 + boatCount, from, to, true, cost)
    boatCount = boatCount + 1
end

local zeppelinCount = 0

--- Register a bidirectional zeppelin route.
---@param fromMapId number
---@param fromPos Vec3|table
---@param fromIsUI boolean
---@param fromAreaId number
---@param toMapId number
---@param toPos Vec3|table
---@param toIsUI boolean
---@param toAreaId number
---@param cost number
---@param condition? fun(): boolean
function FarstriderData.AddZeppelin(fromMapId, fromPos, fromIsUI, fromAreaId, toMapId, toPos, toIsUI, toAreaId, cost,
                                    condition)
    local L = Data.L
    local from = { unknown1 = 0, flags = 0, loc = { mapId = fromMapId, pos = fromPos, isUI = fromIsUI }, condition =
    condition, type = 1, important = true, locaId = ET.ZEPPELIN, locaArgs = function() return { C_Map.GetAreaInfo(
        fromAreaId) or L["Area_" .. fromAreaId] or ("Area " .. fromAreaId), C_Map.GetAreaInfo(toAreaId) or
        L["Area_" .. toAreaId] or ("Area " .. toAreaId) } end }
    local to = { unknown1 = 0, flags = 0, loc = { mapId = toMapId, pos = toPos, isUI = toIsUI }, condition = condition, type = 1, important = true, locaId =
    ET.ZEPPELIN, locaArgs = function() return { C_Map.GetAreaInfo(toAreaId) or L["Area_" .. toAreaId] or
        ("Area " .. toAreaId), C_Map.GetAreaInfo(fromAreaId) or L["Area_" .. fromAreaId] or ("Area " .. fromAreaId) } end }
    addEntry(3000 + zeppelinCount, from, to, true, cost)
    zeppelinCount = zeppelinCount + 1
end

local portalCount = 0

--- Register a portal connection (optionally bidirectional).
---@param bidirectional boolean
---@param fromMapId number
---@param fromPos Vec3|table
---@param fromIsUI boolean
---@param fromAreaId number
---@param toMapId number
---@param toPos Vec3|table
---@param toIsUI boolean
---@param toAreaId number
---@param cost number
---@param condition? fun(): boolean
function FarstriderData.AddPortal(bidirectional, fromMapId, fromPos, fromIsUI, fromAreaId, toMapId, toPos, toIsUI,
                                  toAreaId, cost, condition)
    local L = Data.L
    local from = { unknown1 = 0, flags = 0, loc = { mapId = fromMapId, pos = fromPos, isUI = fromIsUI }, condition =
    condition, type = 1, important = true, locaId = ET.PORTAL, locaArgs = function() return { C_Map.GetAreaInfo(toAreaId) or
        L["Area_" .. toAreaId] or ("Area " .. toAreaId) } end }
    local to = { unknown1 = 0, flags = 0, loc = { mapId = toMapId, pos = toPos, isUI = toIsUI }, condition =
    bidirectional and condition or nil, type = 1, important = true, locaId = ET.PORTAL, locaArgs = function() return {
            C_Map.GetAreaInfo(fromAreaId) or L["Area_" .. fromAreaId] or ("Area " .. fromAreaId) } end }
    addEntry(4000 + portalCount, from, to, bidirectional, cost)
    portalCount = portalCount + 1
end

--- Returns the next auto-incrementing portal-range ID (4000+) and advances the counter.
---@return number
function FarstriderData.NextPortalId()
    local id = 4000 + portalCount
    portalCount = portalCount + 1
    return id
end

local itemCount = 0
local helpfulItemsSeen = {} ---@type table<number, boolean>

--- Register a usable item that teleports the player to a fixed location.
---@param itemId number
---@param toMapId number
---@param toPos Vec3|table
---@param toIsUI boolean
---@param toAreaId number
---@param cost number
---@param condition? fun(): boolean
function FarstriderData.AddItem(itemId, toMapId, toPos, toIsUI, toAreaId, cost, condition)
    local L = Data.L
    local Util = Lib.Util
    local UI = Lib.UI
    local from = { actionOptions = { { type = "item", data = itemId } }, condition = function() return (not condition or condition()) and
        UI.CanUseItem(itemId) end, unknown1 = 0, dynLoc = function() return Util.GetPlayerLocation() end, flags = 8, type = 1, important = true, locaId =
    ET.ITEM, locaArgs = function() return { Util.GetItemNameSafe(itemId), C_Map.GetAreaInfo(toAreaId) or
        L["Area_" .. toAreaId] or ("Area " .. toAreaId) } end }
    local to = { unknown1 = 0, flags = 0, loc = { mapId = toMapId, pos = toPos, isUI = toIsUI }, type = 2, locaId = ET
    .ITEM, locaArgs = function() return { Util.GetItemNameSafe(itemId), C_Map.GetAreaInfo(toAreaId) } end }
    addEntry(5000 + itemCount, from, to, false, cost)
    itemCount = itemCount + 1
    if not helpfulItemsSeen[itemId] then
        helpfulItemsSeen[itemId] = true
        table.insert(Data.Connections.helpfulItems, itemId)
    end
end

--- Register a group of interchangeable items that all teleport to the same
--- dynamic destination (e.g. hearthstone skins all go to the bind location).
---@param itemIds number[]
---@param dynLoc fun(): NavLocation?  Dynamic destination resolver
---@param dynLocaId fun(): string?    Dynamic area name for localization
---@param cost number
---@param condition? fun(): boolean
function FarstriderData.AddDynamicItemWithMultipleIds(itemIds, dynLoc, dynLocaId, cost, condition)
    local L = Data.L
    local Util = Lib.Util
    local UI = Lib.UI

    local finalActionOptions = {}
    for _, itemId in ipairs(itemIds) do
        table.insert(finalActionOptions, { type = "item", data = itemId, allowAny = true })
    end

    local finalCondition = function()
        if condition and not condition() then
            return false
        end
        for _, itemId in ipairs(itemIds) do
            if UI.CanUseItem(itemId) then
                return true
            end
        end
        return false
    end

    local from = { actionOptions = finalActionOptions, condition = finalCondition, unknown1 = 0, dynLoc = function() return
        Util.GetPlayerLocation() end, flags = 8, type = 1, important = true, locaId = ET.ITEM, locaArgs = function() return {
            Util.GetItemNameSafe(itemIds[1]), dynLocaId() or L["Unknown Location"] or "Unknown Location" } end }
    local to = { unknown1 = 0, flags = 0, dynLoc = dynLoc, type = 2, locaId = ET.ITEM, locaArgs = function() return {
            Util.GetItemNameSafe(itemIds[1]), dynLocaId() or L["Unknown Location"] or "Unknown Location" } end }
    addEntry(5000 + itemCount, from, to, false, cost)
    itemCount = itemCount + 1

    for _, itemId in ipairs(itemIds) do
        if not helpfulItemsSeen[itemId] then
            helpfulItemsSeen[itemId] = true
            table.insert(Data.Connections.helpfulItems, itemId)
        end
    end
end

local spellCount = 0

--- Register a player spell that teleports to a fixed location.
---@param spellId number
---@param toMapId number
---@param toPos Vec3|table
---@param toIsUI boolean
---@param toAreaId number
---@param cost number
---@param condition? fun(): boolean
function FarstriderData.AddSpell(spellId, toMapId, toPos, toIsUI, toAreaId, cost, condition)
    local L = Data.L
    local Util = Lib.Util
    local UI = Lib.UI
    local from = { actionOptions = { { type = "spell", data = spellId } }, condition = function() return (not condition or condition()) and
        UI.CanUseSpell(spellId) end, unknown1 = 0, dynLoc = function() return Util.GetPlayerLocation() end, flags = 8, type = 1, important = true, locaId =
    ET.SPELL, locaArgs = function() return { Util.GetSpellNameSafe(spellId), C_Map.GetAreaInfo(toAreaId) or
        L["Area_" .. toAreaId] or ("Area " .. toAreaId) } end }
    local to = { unknown1 = 0, flags = 0, loc = { mapId = toMapId, pos = toPos, isUI = toIsUI }, type = 2, locaId = ET
    .SPELL, locaArgs = function() return { Util.GetSpellNameSafe(spellId), C_Map.GetAreaInfo(toAreaId) } end }
    addEntry(6000 + spellCount, from, to, false, cost)
    spellCount = spellCount + 1
end

--- Returns the next auto-incrementing spell-range ID (6000+) and advances the counter.
---@return number
function FarstriderData.NextSpellId()
    local id = 6000 + spellCount
    spellCount = spellCount + 1
    return id
end

--- Adds a raw waypoint entry directly.
---@param id number
---@param from WaypointLocation
---@param to WaypointLocation
---@param bidirectional boolean
---@param cost number
function FarstriderData.AddEntry(id, from, to, bidirectional, cost)
    addEntry(id, from, to, bidirectional, cost)
end
