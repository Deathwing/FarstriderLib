-- FarstriderLibData~Taxi.lua
-- local _, FarstriderLibData = ...

if not FarstriderLibData.Internal or not FarstriderLibData.TaxiNodes then return end

local _fld = FarstriderLibData.Internal

local FLIGHTPATH_LOCA_ID = 1001
local WAYPOINT_ID_BASE = 100000
local REBUILD_DELAY = 0.5
local MIN_LIB_VERSION = 10500 -- older API.Rebuild needs self; their next login rebuild covers the change

local FACTION_MASKS = { Alliance = 1, Horde = 2 }

local nodes = FarstriderLibData.TaxiNodes
local paths = FarstriderLibData.TaxiPaths
local factionMask = FACTION_MASKS[UnitFactionGroup("player")] or 0

local Taxi = {}
FarstriderLibData.Taxi = Taxi

local names = {} ---@type table<number, string>

---@param nodeId number
---@return boolean
local function IsOwnFaction(nodeId)
    local node = nodes[nodeId]
    return node ~= nil and bit.band(node[5], factionMask) > 0
end

---@return table<number, boolean>
local function GetScannedNodes()
    if not FarstriderLibData_CharacterSettings then
        FarstriderLibData_CharacterSettings = {}
    end
    if not FarstriderLibData_CharacterSettings.knownTaxiNodes then
        FarstriderLibData_CharacterSettings.knownTaxiNodes = {}
    end
    return FarstriderLibData_CharacterSettings.knownTaxiNodes
end

--- Whether the character can fly to and from a flight master; the game reports known flight paths only on an open flight map.
---@param nodeId number
---@return boolean
function Taxi.IsNodeKnown(nodeId)
    local scanned = FarstriderLibData_CharacterSettings and FarstriderLibData_CharacterSettings.knownTaxiNodes
    return scanned ~= nil and scanned[nodeId] == true
end

---@param nodeId number
---@return string
function Taxi.GetNodeName(nodeId)
    return names[nodeId] or nodes[nodeId][6]
end

---@return string
local function GetKnownNodesKey()
    local known = {}
    for nodeId in pairs(nodes) do
        if IsOwnFaction(nodeId) and Taxi.IsNodeKnown(nodeId) then
            known[#known + 1] = nodeId
        end
    end
    table.sort(known)
    return table.concat(known, ",")
end

local eventFrame = _fld.createFrame("Frame")
local rebuildTimer
local rebuildPending = false

local function Rebuild()
    if InCombatLockdown() then
        rebuildPending = true
        eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end

    rebuildPending = false
    local api = FarstriderLib_API
    if api and api.Rebuild and (api.VERSION or 0) >= MIN_LIB_VERSION then
        api.Rebuild()
    end
end

local function ScheduleRebuild()
    if rebuildTimer then
        rebuildTimer:Cancel()
    end
    rebuildTimer = _fld.newTimer(REBUILD_DELAY, function()
        rebuildTimer = nil
        Rebuild()
    end)
end

---@param uiMapId number?
---@return number?
local function GetContinentMapId(uiMapId)
    local info = uiMapId and C_Map.GetMapInfo(uiMapId)
    while info and info.mapType > Enum.UIMapType.Continent and info.parentMapID and info.parentMapID ~= 0 do
        info = C_Map.GetMapInfo(info.parentMapID)
    end
    return info and info.mapType == Enum.UIMapType.Continent and info.mapID or nil
end

local continentNodes ---@type table<number, number[]>? continent -> own-faction nodes
local mapContinents = {} ---@type table<number, number|false>

---@return table<number, number[]>
local function GetContinentNodes()
    if not continentNodes then
        continentNodes = {}
        for nodeId, node in pairs(nodes) do
            if IsOwnFaction(nodeId) then
                local continentId = GetContinentMapId((C_Map.GetMapPosFromWorldPos(node[1], CreateVector2D(node[2], node[3]))))
                if continentId then
                    continentNodes[continentId] = continentNodes[continentId] or {}
                    table.insert(continentNodes[continentId], nodeId)
                end
            end
        end
    end
    return continentNodes
end

--- False while routes on the continent of uiMapId cannot use flight paths because this character has no flight data there yet.
---@param uiMapId number?
---@return boolean
function Taxi.HasFlightData(uiMapId)
    if not uiMapId then return true end
    local continentId = mapContinents[uiMapId]
    if continentId == nil then
        continentId = GetContinentMapId(uiMapId) or false
        mapContinents[uiMapId] = continentId
    end
    local ownNodes = continentId and GetContinentNodes()[continentId]
    if not ownNodes then return true end

    local scanned = FarstriderLibData_CharacterSettings and FarstriderLibData_CharacterSettings.knownTaxiNodes
    if scanned then
        for _, nodeId in ipairs(ownNodes) do
            if scanned[nodeId] ~= nil then return true end
        end
    end
    return false
end

-- Flight map contents are only available between TAXIMAP_OPENED and TAXIMAP_CLOSED
local function ScanFlightMap()
    if not (C_TaxiMap and C_TaxiMap.GetAllTaxiNodes) then return end

    local playerMapId = C_Map.GetBestMapForUnit("player")
    local unreachable = Enum.FlightPathState and Enum.FlightPathState.Unreachable or 2
    local listed = {}
    for _, mapId in ipairs({ GetTaxiMapID and GetTaxiMapID() or false, GetContinentMapId(playerMapId) or false, playerMapId or false }) do
        if mapId then
            for _, info in ipairs(C_TaxiMap.GetAllTaxiNodes(mapId) or {}) do
                if IsOwnFaction(info.nodeID) then
                    names[info.nodeID] = info.name
                    listed[info.nodeID] = listed[info.nodeID] or info.state ~= unreachable
                end
            end
        end
    end
    if not next(listed) then return end

    -- Unlisted nodes stay untouched: one instance spans several taxi maps, and some nodes are never listed
    local before = GetKnownNodesKey()
    local scanned = GetScannedNodes()
    for nodeId, reachable in pairs(listed) do
        if reachable then
            scanned[nodeId] = true
        elseif not Taxi.IsNodeKnown(nodeId) then
            scanned[nodeId] = false
        end
    end

    if GetKnownNodesKey() ~= before then
        ScheduleRebuild()
    end
end

eventFrame:RegisterEvent("TAXIMAP_OPENED")
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "TAXIMAP_OPENED" then
        ScanFlightMap()
    elseif event == "PLAYER_REGEN_ENABLED" then
        eventFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
        if rebuildPending then
            ScheduleRebuild()
        end
    end
end)

---@param node table
---@return Location
local function CreateLocation(node)
    return { mapId = node[1], pos = { x = node[2], y = node[3], z = node[4] }, isUI = false }
end

local pathIds = {}
for pathId in pairs(paths) do
    pathIds[#pathIds + 1] = pathId
end
table.sort(pathIds)

local locations = {} ---@type table<number, Location>
for _, pathId in ipairs(pathIds) do
    local fromId, toId, seconds = paths[pathId][1], paths[pathId][2], paths[pathId][3]
    if IsOwnFaction(fromId) and IsOwnFaction(toId) then
        locations[fromId] = locations[fromId] or CreateLocation(nodes[fromId])
        locations[toId] = locations[toId] or CreateLocation(nodes[toId])

        local from = { unknown1 = 0, flags = 0, loc = locations[fromId], type = 1, important = true, locaId = FLIGHTPATH_LOCA_ID, locaArgs = function() return { Taxi.GetNodeName(toId) } end } ---@type WaypointLocation
        local to = { unknown1 = 0, flags = 0, loc = locations[toId], type = 1, important = true, locaId = FLIGHTPATH_LOCA_ID } ---@type WaypointLocation
        table.insert(FarstriderLibData.Waypoints, { id = WAYPOINT_ID_BASE + pathId, from = from, to = to, bidirectional = false, cost = seconds, condition = function() return Taxi.IsNodeKnown(fromId) and Taxi.IsNodeKnown(toId) end }) ---@type Waypoint
    end
end
