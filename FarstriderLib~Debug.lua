-- FarstriderLib~Debug.lua
-- Debug-only world-map pin rendering and interactive testing tools.
-- Entire file is stripped by MRP_REMOVE_LINE in production.
-- local _, FarstriderLib = ...

if not FarstriderLib.Internal then return end

local hbdp = LibStub("HereBeDragons-Pins-2.0")
local pool = {} ---@type table[]  Recycled pin frame objects
local activePoints = {} ---@type table[]  Currently displayed pin objects
local idx = 0

--- Master toggle for map dot rendering.
local SHOW_MAP_DOTS = false

local media = FarstriderLib.media_path

--- Place a waypoint pin on the world map (or forward to TomTom).
--- Registered as the implementation for FarstriderLib.SetWaypoint.
---@param waypoint Location
---@param texture string  Path to a .blp or .tga texture
---@param options? table  { useTomTom?, index?, text?, edges?, name? }
local function SetWaypointImpl(waypoint, texture, options)
    if not SHOW_MAP_DOTS then return end
    if not options then return end

    if options.useTomTom and TomTom then
        local point = {}
        point.m = waypoint.mapId
        point.x = waypoint.pos.x
        point.y = waypoint.pos.y

        local info = C_Map.GetMapInfo(waypoint.mapId)
        if info and info.mapType ~= Enum.UIMapType.Zone then
            local continentID, worldPosition = C_Map.GetWorldPosFromMapPos(waypoint.mapId,
                CreateVector2D(waypoint.pos.x, waypoint.pos.y))
            if continentID and worldPosition then
                local subZoneInfo = C_Map.GetMapInfoAtPosition(waypoint.mapId, waypoint.pos.x, waypoint.pos.y)
                if subZoneInfo then
                    local uiMapID, mapPosition = C_Map.GetMapPosFromWorldPos(continentID, worldPosition,
                        subZoneInfo.mapID)
                    if uiMapID and mapPosition then
                        point.m = uiMapID
                        point.x = mapPosition.x
                        point.y = mapPosition.y
                    end
                end
            end
        end

        print("#" ..
            (options.index + 1) ..
            " " .. options.text .. " at " .. C_Map.GetMapInfo(point.m).name .. " (" .. point.x .. ", " .. point.y .. ")")
        TomTom:AddWaypoint(point.m, point.x, point.y, {
            title = "[#" .. (options.index + 1) .. "] " .. options.text,
            source = "FarstriderLib",
            persistent = false,
            minimap = true,
            world = true,
            silent = true,
        })
        return
    end

    -- Acquire a frame from the pool
    local point = table.remove(pool)

    if not point then
        idx = idx + 1

        if not FarstriderLibMapOverlay then
            local overlay = CreateFrame("Frame", "FarstriderLibMapOverlay", WorldMapFrame.BorderFrame)
            overlay:SetFrameStrata("HIGH")
            overlay:SetFrameLevel(9000)
            overlay:SetAllPoints()
        end

        local worldmap = CreateFrame("Button", nil, FarstriderLibMapOverlay)
        worldmap.icon = worldmap:CreateTexture(nil, "OVERLAY")
        worldmap.icon:SetAllPoints()
        worldmap.icon:SetBlendMode("BLEND")

        local name = ""
        if options.edges then
            for _, edge in ipairs(options.edges) do
                if edge.locaId and edge.locaId ~= FarstriderLib.EdgeType.TRAVEL then
                    local loca = FarstriderLib.Pathfinding:GetNodeLoca(edge.locaId, edge.locaArgs)
                    if loca then
                        name = name .. loca .. " | "
                    end
                end
            end
        end

        if name ~= "" then
            name = name:sub(1, -3)
        end

        if name == "" then
            name = options.name or "Waypoint"
        end

        worldmap:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(name, 1, 1, 1)
            GameTooltip:AddLine("Waypoint " .. (options.index or -1))
            GameTooltip:AddLine("World: " .. options.text)
            GameTooltip:AddLine("Local: " ..
                FarstriderLib.NavNode.makeNavKey(point.m, { x = point.x, y = point.y, z = 0 }))
            GameTooltip:Show()
        end)
        worldmap:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
        worldmap:SetScript("OnClick", function()
            if not FarstriderLib._debugStartLocation then
                FarstriderLib._debugStartLocation = {
                    mapId = point.m,
                    pos = { x = point.x, y = point.y, z = point.z },
                    isUI =
                        point.isUI
                }
                FarstriderLib._debugStartButton = worldmap
                FarstriderLib._debugStartButton.icon:SetVertexColor(1, 0, 0)
            elseif not FarstriderLib._debugGoalLocation then
                if FarstriderLib._debugStartButton == worldmap then
                    FarstriderLib._debugStartLocation = nil
                    FarstriderLib._debugStartButton.icon:SetVertexColor(1, 1, 1)
                    FarstriderLib._debugStartButton = nil
                    return
                end

                FarstriderLib._debugGoalLocation = {
                    mapId = point.m,
                    pos = { x = point.x, y = point.y, z = point.z },
                    isUI =
                        point.isUI
                }
                FarstriderLib._debugGoalButton = worldmap
                FarstriderLib._debugGoalButton.icon:SetVertexColor(0, 1, 0)

                FarstriderLib.Debug.DistanceTest()
                FarstriderLib.Debug.NavigationTest()

                FarstriderLib._debugStartButton.icon:SetVertexColor(1, 1, 1)
                FarstriderLib._debugStartButton = nil
                FarstriderLib._debugGoalButton.icon:SetVertexColor(1, 1, 1)
                FarstriderLib._debugGoalButton = nil
                FarstriderLib._debugStartLocation = nil
                FarstriderLib._debugGoalLocation = nil
            end
        end)

        point = { worldmap = worldmap }
    end

    point.m = waypoint.mapId
    point.x = waypoint.pos.x
    point.y = waypoint.pos.y
    point.z = waypoint.pos.z
    point.isUI = waypoint.isUI

    local info = C_Map.GetMapInfo(waypoint.mapId)
    if info and info.mapType ~= Enum.UIMapType.Zone then
        local continentID, worldPosition = C_Map.GetWorldPosFromMapPos(waypoint.mapId,
            CreateVector2D(waypoint.pos.x, waypoint.pos.y))
        if continentID and worldPosition then
            local subZoneInfo = C_Map.GetMapInfoAtPosition(waypoint.mapId, waypoint.pos.x, waypoint.pos.y)
            if subZoneInfo then
                local uiMapID, mapPosition = C_Map.GetMapPosFromWorldPos(continentID, worldPosition, subZoneInfo.mapID)
                if uiMapID and mapPosition then
                    point.m = uiMapID
                    point.x = mapPosition.x
                    point.y = mapPosition.y
                end
            end
        end
    end

    point.worldmap.icon:SetTexture(texture)
    point.worldmap:SetHeight(16)
    point.worldmap:SetWidth(16)
    point.worldmap.point = point
    point.waypoint = waypoint

    hbdp:AddWorldMapIconMap("FarstriderLib", point.worldmap, point.m, point.x, point.y, 3)
    table.insert(activePoints, point)
end

--- Return all active pin frames to the pool and remove their map icons.
local function ClearAllWaypoints()
    hbdp:RemoveAllWorldMapIcons("FarstriderLib")
    for _, point in ipairs(activePoints) do
        point.worldmap:Hide()
        point.worldmap.icon:SetVertexColor(1, 1, 1)
        table.insert(pool, point)
    end
    activePoints = {}
end

FarstriderLib._setWaypointImpl = SetWaypointImpl
FarstriderLib._clearWaypointsImpl = ClearAllWaypoints

---------------------------------------------------------------------------
-- Debug utilities
---------------------------------------------------------------------------
FarstriderLib.Debug = FarstriderLib.Debug or {}

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

--- Print map metadata to the logger.
---@param mapID number
function FarstriderLib.Debug.PrintMapInfo(mapID)
    local info = C_Map.GetMapInfo(mapID)
    if not info then
        FarstriderLib.Logger:Error("Map ID", mapID, "not found.")
        return
    end
    local typeName = mapTypeNames[info.mapType] or "Unknown"
    FarstriderLib.Logger:Info("Map Info for ID:", mapID)
    FarstriderLib.Logger:Info("  Name:       " .. (info.name or "unknown"))
    FarstriderLib.Logger:Info("  Map Type:   " .. info.mapType .. " (" .. typeName .. ")")
    FarstriderLib.Logger:Info("  Parent ID:  " .. info.parentMapID)
    FarstriderLib.Logger:Info("  Flags:      " .. (info.flags or "none"))
end

--- Print the player's current UI-map position to the logger.
function FarstriderLib.Debug.PrintPlayerPosition()
    local mapId = C_Map.GetBestMapForUnit("player")
    if not mapId then
        FarstriderLib.Logger:Error("No map found for the player.")
        return
    end
    local position = C_Map.GetPlayerMapPosition(mapId, "player")
    if not position then
        FarstriderLib.Logger:Error("No player position found on the map.")
        return
    end
    FarstriderLib.Logger:Info(string.format("Current player position on map %d: (%.2f, %.2f)", mapId, position.x,
        position.y))
end

--- Dump a NavNode's edges to the logger.
---@param navKey NavKey
function FarstriderLib.Debug.InspectNavNode(navKey)
    local navNode = FarstriderLib.Pathfinding.allNodes[navKey]
    if not navNode then
        FarstriderLib.Logger:Error("Invalid NavNode.")
        return
    end
    local loc = navNode:getLocation()
    FarstriderLib.Logger:Info("Inspecting NavNode:")
    FarstriderLib.Logger:Info("  Map ID: " .. (loc.mapId or "unknown"))
    FarstriderLib.Logger:Info("  Position: (" .. (loc.pos.x or 0) .. ", " .. (loc.pos.y or 0) .. ")")
    FarstriderLib.Logger:Info("  Edges: " .. (#navNode.edges or 0))
    for _, edge in ipairs(navNode.edges or {}) do
        FarstriderLib.Logger:Info(string.format("    Edge to Map ID %d with cost %.2f", edge.to:getLocation().mapId,
            edge.cost or 0))
    end
end

--- Compute and print the world distance between the two debug-selected pins.
function FarstriderLib.Debug.DistanceTest()
    local sLoc = FarstriderLib._debugStartLocation
    local gLoc = FarstriderLib._debugGoalLocation
    if not sLoc or not gLoc then return end

    print("Start Location:", sLoc.mapId, sLoc.pos.x, sLoc.pos.y, sLoc.pos.z, sLoc.isUI)
    print("Goal Location:", gLoc.mapId, gLoc.pos.x, gLoc.pos.y, gLoc.pos.z, gLoc.isUI)

    local _, worldA = C_Map.GetWorldPosFromMapPos(sLoc.mapId, CreateVector2D(sLoc.pos.x, sLoc.pos.y))
    local _, worldB = C_Map.GetWorldPosFromMapPos(gLoc.mapId, CreateVector2D(gLoc.pos.x, gLoc.pos.y))
    if worldA and worldB then
        local dist = math.sqrt((worldA.x - worldB.x) ^ 2 + (worldA.y - worldB.y) ^ 2 + (sLoc.pos.z - gLoc.pos.z) ^ 2)
        FarstriderLib.Logger:Info("Distance between start and goal locations: " .. dist)
        print("Distance between start and goal locations: " .. dist)
    end
end

--- Run pathfinding between the two debug-selected pins and log the result.
function FarstriderLib.Debug.NavigationTest()
    local sLoc = FarstriderLib._debugStartLocation
    local gLoc = FarstriderLib._debugGoalLocation
    if not sLoc or not gLoc then return end

    print("Start Location:", sLoc.mapId, sLoc.pos.x, sLoc.pos.y, sLoc.pos.z)
    print("Goal Location:", gLoc.mapId, gLoc.pos.x, gLoc.pos.y, gLoc.pos.z)

    local optimizedPath, path = FarstriderLib.Pathfinding:FindPathBetweenLocations2(
        { mapId = sLoc.mapId, pos = { x = sLoc.pos.x, y = sLoc.pos.y, z = sLoc.pos.z }, isUI = sLoc.isUI },
        { mapId = gLoc.mapId, pos = { x = gLoc.pos.x, y = gLoc.pos.y, z = gLoc.pos.z }, isUI = gLoc.isUI }
    )
    if not path or #path == 0 then
        FarstriderLib.Logger:Error("No path found between the specified locations.")
        return
    end
    for i, navLocation in ipairs(path) do
        local loc = navLocation:getLocation()
        FarstriderLib.Logger:Info(string.format("Waypoint %d: Map ID %d at (%.2f, %.2f, %.2f)", i, loc.mapId, loc.pos.x,
            loc.pos.y, loc.pos.z))
    end
end

-- Debug-only PLAYER_LOGIN: render all nav nodes on the world map
local df = CreateFrame("Frame")
df:RegisterEvent("PLAYER_LOGIN")
df:SetScript("OnEvent", function()
    for _, navLocation in pairs(FarstriderLib.Pathfinding.allNodes) do
        if not navLocation.isDynamic then
            local valid = #navLocation.edges == 0 or not navLocation.edges[1].condition or
                navLocation.edges[1].condition()
            FarstriderLib.PlaceFlare(
                navLocation:getLocation(),
                valid and (media .. "Media\\GoldGreenDot") or (media .. "Media\\GoldRedDot")
            )
        end
    end
end)
