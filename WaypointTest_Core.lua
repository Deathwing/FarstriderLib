-- WaypointTest_Core.lua
-- local _, WPT = ...

local locale = GetLocale() -- e.g., "enUS", "deDE", etc.

local isolatedZones = {
    [2248] = true, -- Dornogol
    [2346] = true, -- Undermine
}

local mapTypeNames = {
    [0] = "Cosmic",
    [1] = "World",
    [2] = "Continent",
    [3] = "Zone",
    [4] = "Dungeon",
    [5] = "MicroDungeon",
    [6] = "Orphan",
    [7] = "Scenario",
    [8] = "UI",
}

function PrintMapInfo(mapID)
    local info = C_Map.GetMapInfo(mapID)
    if not info then
        WPT.Logger:Error("Map ID", mapID, "not found.")
        return
    end

    local typeName = mapTypeNames[info.mapType] or "Unknown"

    WPT.Logger:Info("Map Info for ID:", mapID)
    WPT.Logger:Info("  Name:       " .. (info.name or "unknown"))
    WPT.Logger:Info("  Map Type:   " .. info.mapType .. " (" .. typeName .. ")")
    WPT.Logger:Info("  Parent ID:  " .. info.parentMapID)
    WPT.Logger:Info("  Flags:      " .. (info.flags or "none"))
end

local function PrintPlayerPosition()
    local mapId = C_Map.GetBestMapForUnit("player")
    if not mapId then
        WPT.Logger:Error("No map found for the player.")
        return
    end

    local position = C_Map.GetPlayerMapPosition(mapId, "player")
    if not position then
        WPT.Logger:Error("No player position found on the map.")
        return
    end

    WPT.Logger:Info(string.format("Current player position on map %d: (%.2f, %.2f)", mapId, position.x, position.y))
end

---@param waypointLocation WaypointLocation
---@return number? uiMapID
---@return vector2? mapPosition
local function GetUIMapIdAndLocalCoordsFromWaypoint(waypointLocation)
    if not waypointLocation then
        WPT.Logger:Error("Invalid waypoint data.")
        return nil
    end 

    return C_Map.GetMapPosFromWorldPos(waypointLocation.loc.mapId, CreateVector2D(waypointLocation.loc.pos.x, waypointLocation.loc.pos.y))
end

---@param prefix string
---@param waypointLocation WaypointLocation
local function PrintWaypoint(prefix, waypointLocation)
    local Id = waypointLocation.locaId
    if not waypointLocation.loc then
        WPT.Logger:Warning(string.format("WaypointLocation with locaId %d does not provide any location data", Id))
        return
    end

    -- Get UIMapId from the continent and its position on the continent map 
    local uiMapId, mapPosition = C_Map.GetMapPosFromWorldPos(waypointLocation.loc.mapId, CreateVector2D(waypointLocation.loc.pos.x, waypointLocation.loc.pos.y))
    if not uiMapId or not mapPosition then
        WPT.Logger:Error(string.format("No UIMapId found for locaId %d with mapId %d at position (%.2f, %.2f)", waypointLocation.locaId, waypointLocation.loc.mapId, waypointLocation.loc.pos.x, waypointLocation.loc.pos.y))
        return
    end

    -- We need to differ between maps with child id's available and those that not have it.
    -- Convert Continent map data to local zone data based on position
    local mapInfo = C_Map.GetMapInfoAtPosition(uiMapId, mapPosition.x, mapPosition.y)
    if not mapInfo then
        -- print(string.format("Convert to Local failed for locaId %d with uiMapId %d at %.2f, %.2f", waypointLocation.locaId, uiMapId, mapPosition.x, mapPosition.y))
        -- This map does not have a child info so the above uiMapId and mapPosition are the ones we want to use
        -- print("Using original UIMapId and mapPosition without conversion.")
        SetWaypoint({
            mapId = uiMapId,
            pos = {
                x = mapPosition.x,
                y = mapPosition.y,
                z = 0
            },
            isUI = true
        }, "Interface\\AddOns\\WaypointTest\\Images\\GoldRedDot")
        return
    end

    local localUIMapId, localMapPos = C_Map.GetMapPosFromWorldPos(waypointLocation.loc.mapId, CreateVector2D(waypointLocation.loc.pos.x, waypointLocation.loc.pos.y), mapInfo.mapID)
    if not localUIMapId or not localMapPos then
        WPT.Logger:Error(string.format("Failed to convert to local map for locaId %d with uiMapId %d at %.2f, %.2f at mapInfo %d", waypointLocation.locaId, uiMapId, mapPosition.x, mapPosition.y, mapInfo.mapID))
        return
    end

    SetWaypoint({
        mapId = localUIMapId,
        pos = {
            x = localMapPos.x,
            y = localMapPos.y,
            z = 0
        },
        isUI = true
    }, "Interface\\AddOns\\WaypointTest\\Images\\GoldRedDot")

    -- local mapInfo = C_Map.GetMapInfo(uiMapId) -- Ensure the map is loaded
    -- if mapInfo then
    --     print(string.format("Map Name: %s, Map ID: %d", mapInfo.name, mapInfo.mapID))
    -- else
    --     print("Map information not available.")
    -- end
end

---@param waypoint Waypoint
local function PrintWaypointData(waypoint)
    if not waypoint or not waypoint.from or not waypoint.to then
        WPT.Logger:Error("Invalid waypoint data.")
        return
    end

    PrintWaypoint("From:", waypoint.from)
    PrintWaypoint("To:", waypoint.to)
end

TEST = {}

---@param locaId number
function TEST:PrintWaypoint(locaId)
    for index, waypoint in ipairs(MRP.Waypoints) do
        if waypoint.from.locaId == locaId then
            PrintWaypointData(waypoint)
            return
        elseif waypoint.to.locaId == locaId then
            PrintWaypointData(waypoint)
            return
        end
    end
end

function GetMapName(uiMapId)
    local mapInfo = C_Map.GetMapInfo(uiMapId)
    if mapInfo then
        return mapInfo.name
    else
        return "Unknown Map"
    end
end

local specialZs = {
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

local function GetZ(mapId)
    return specialZs[mapId] or 0
end

---@param startMapId MapId
---@param startX number
---@param startY number
---@param startZ number
---@param goalMapId MapId
---@param endX number
---@param endY number
---@param endZ number
function Navigate(startMapId, startX, startY, startZ, goalMapId, endX, endY, endZ)
    local startLocation = { mapId = startMapId, pos = { x = startX, y = startY, z = startZ == 0 and GetZ(startMapId) or startZ }, isUI = true } ---@type NavLocation, NavLocation
    local goalLocation = { mapId = goalMapId, pos = { x = endX, y = endY, z = endZ == 0 and GetZ(goalMapId) or endZ }, isUI = true } ---@type NavLocation, NavLocation
    local optimizedPath, path, edges = WPT.Pathfinding:FindPathBetweenLocations2(startLocation, goalLocation)
    
    WPT.Pathfinding:PrintPath(optimizedPath, path, edges) -- MRP_REMOVE_LINE

    return optimizedPath, path, edges
end

--- This function will start from the player position and navigate to the specified goal position.
--- @param goalMapId MapId
--- @param endX number
--- @param endY number
--- @param endZ number
function NavigateTo(goalMapId, endX, endY, endZ)
    local playerMapId = C_Map.GetBestMapForUnit("player")
    if not playerMapId then
        WPT.Logger:Error("No map found for the player.")
        return
    end

    local playerPosition = C_Map.GetPlayerMapPosition(playerMapId, "player")
    if not playerPosition then
        local parentMapId = C_Map.GetMapInfo(playerMapId).parentMapID
        if parentMapId then
            playerMapId = parentMapId
            local instanceId = EJ_GetInstanceForMap(playerMapId)
            local dungeonEntrances = C_EncounterJournal.GetDungeonEntrancesForMap(parentMapId)
            for _, entrance in ipairs(dungeonEntrances) do
                if entrance.journalInstanceID == instanceId then
                    playerPosition = entrance.position
                end
            end
        end

        if not playerPosition then
            playerPosition = { x = 0.5, y = 0.5 }
        end
    end

    local startLocation = { mapId = playerMapId, pos = { x = playerPosition.x, y = playerPosition.y, z = 0 } }
    local goalLocation = { mapId = goalMapId, pos = { x = endX, y = endY, z = endZ } }

    return Navigate(startLocation.mapId, startLocation.pos.x, startLocation.pos.y, startLocation.pos.z, goalLocation.mapId, goalLocation.pos.x, goalLocation.pos.y, goalLocation.pos.z)
end

---@param navKey NavKey
function InspectNavNode(navKey)
    local navNode = WPT.Pathfinding.allNodes[navKey]
    if not navNode then
        WPT.Logger:Error("Invalid NavNode.")
        return
    end

    local loc = navNode:getLocation()

    WPT.Logger:Info("Inspecting NavNode:")
    WPT.Logger:Info("  Map ID: " .. (loc.mapId or "unknown"))
    WPT.Logger:Info("  Position: (" .. (loc.pos.x or 0) .. ", " .. (loc.pos.y or 0) .. ")")
    WPT.Logger:Info("  Edges: " .. (#navNode.edges or 0))
    for _, edge in ipairs(navNode.edges or {}) do
        WPT.Logger:Info(string.format("    Edge to Map ID %d with cost %.2f", edge.to:getLocation().mapId, edge.cost or 0))
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    -- TEST:PrintWaypoint(1)
    -- /dump TEST:PrintWaypoint(1)

    -- for index, waypoint in ipairs(MRP.Waypoints) do
        -- print(string.format("Waypoint %d:", index))
        -- PrintWaypointData(waypoint)
        -- print("--------------------------------------------------")
    -- end

    WPT.Pathfinding:Initialize()
    for _, navLocation in pairs(WPT.Pathfinding.allNodes) do -- MRP_REMOVE_LINE
        if not navLocation.isDynamic then  -- MRP_REMOVE_LINE
            -- Draw the waypoint pin on the map -- MRP_REMOVE_LINE

            local valid = #navLocation.edges == 0 or not navLocation.edges[1].condition or navLocation.edges[1].condition() -- MRP_REMOVE_LINE
            SetWaypoint( -- MRP_REMOVE_LINE
                navLocation:getLocation(),  -- MRP_REMOVE_LINE
                valid and "Interface\\AddOns\\WaypointTest\\Images\\GoldRedDot" or "Interface\\AddOns\\WaypointTest\\Images\\GoldRedDot" -- MRP_REMOVE_LINE
                -- ,{ text = navLocation.key, edges = navLocation.edges } -- MRP_REMOVE_LINE
            ) -- MRP_REMOVE_LINE
        end -- MRP_REMOVE_LINE
    end -- MRP_REMOVE_LINE

    if DevTool then -- MRP_REMOVE_LINE
        DevTool:AddData(MRP.Waypoints, "Waypoints") -- MRP_REMOVE_LINE
        DevTool:AddData(WPT, "WaypointTest") -- MRP_REMOVE_LINE
    end -- MRP_REMOVE_LINE
end)