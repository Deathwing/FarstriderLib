-- WaypointTest_Waypoints.lua
-- local _, WPT = ...

local hbdp = LibStub("HereBeDragons-Pins-2.0")
local pool = {}

local idx = 0

---@param waypoint Location
---@param texture string
function SetWaypoint(waypoint, texture, options)
    if not options then
        return
    end

    if options.useTomTom and TomTom then
        local point = {}

        point.m = waypoint.mapId
        point.x = waypoint.pos.x
        point.y = waypoint.pos.y

        local info = C_Map.GetMapInfo(waypoint.mapId)
        if info and info.mapType ~= Enum.UIMapType.Zone then
            local continentID, worldPosition = C_Map.GetWorldPosFromMapPos(waypoint.mapId, CreateVector2D(waypoint.pos.x, waypoint.pos.y))
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

        print("#" .. (options.index + 1) .. " " .. options.text .. " at " .. C_Map.GetMapInfo(point.m).name .. " (" .. point.x .. ", " .. point.y .. ")")
        TomTom:AddWaypoint(
            point.m,
            point.x,
            point.y,
            {
                title = "[#" .. (options.index + 1) .. "] " .. options.text,
                source = "WaypointTest",
                persistent = false,
                minimap = true,
                world = true,
                silent = true,
            }
        )
        return
    end

    -- Try to acquire a waypoint from the frame pool
    local point = table.remove(pool)

    if not point then
        idx = idx + 1

        if not WayPointTestMapOverlay then
            local overlay = CreateFrame("Frame", "WayPointTestMapOverlay", WorldMapFrame.BorderFrame)
            overlay:SetFrameStrata("HIGH")
            overlay:SetFrameLevel(9000)
---@diagnostic disable-next-line: param-type-mismatch
            overlay:SetAllPoints(true)
        end

        local worldmap = CreateFrame("Button", nil, WaypointTestMapOverlay)
        worldmap.icon = worldmap:CreateTexture(nil, "OVERLAY")
        worldmap.icon:SetAllPoints()
        worldmap.icon:SetBlendMode("BLEND")

        local name = ""
        if options.edges then
            for _, edge in ipairs(options.edges) do
                if edge.locaId and edge.locaId ~= MRP.SpecialLocaId.TravelTo then
                    local loca = WPT.Pathfinding:GetNodeLoca(edge.locaId, edge.locaArgs)
                    if loca then
                        name = name .. loca .. " | "
                    end
                end
            end
        end

        if name ~= "" then
            name = name:sub(1, -3) -- Remove the last " | "
        end

        if name == "" then
            name = options.name or "Waypoint"
        end

        worldmap:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(name)
            GameTooltip:AddLine("Waypoint " .. (options.index or -1))
            GameTooltip:AddLine("World: " .. options.text)
            GameTooltip:AddLine("Local: " .. WPT.NavNode.makeNavKey(point.m, { x = point.x, y = point.y, z = 0 }))
            GameTooltip:Show()
        end)
        worldmap:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
        worldmap:SetScript("OnClick", function()
            DevTool:AddData(WPT.Pathfinding.allNodes[options.text], "Waypoint " .. options.text) -- MRP_REMOVE_LINE
        end)
        worldmap:SetScript("OnClick", function()
            if not StartLocation then
                StartLocation = { mapId = point.m, pos = { x = point.x, y = point.y, z = point.z }, isUI = point.isUI }
                StartLocationButton = worldmap
                StartLocationButton.icon:SetVertexColor(1, 0, 0) -- Red for start
            elseif not GoalLocation then
                if StartLocationButton == worldmap then
                    StartLocation = nil
                    StartLocationButton.icon:SetVertexColor(1, 1, 1) -- Reset start color
                    StartLocationButton = nil
                    return
                end

                GoalLocation = { mapId = point.m, pos = { x = point.x, y = point.y, z = point.z }, isUI = point.isUI }
                GoalLocationButton = worldmap
                GoalLocationButton.icon:SetVertexColor(0, 1, 0) -- Green for goal

                DistanceTestHere()
                NavigationTestHere()

                StartLocationButton.icon:SetVertexColor(1, 1, 1) -- Reset start color
                StartLocationButton = nil
                GoalLocationButton.icon:SetVertexColor(1, 1, 1) -- Reset goal color
                GoalLocationButton = nil
                StartLocation = nil
                GoalLocation = nil
            end
        end)

        point = {
            worldmap = worldmap
        }
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

    point.worldmap.icon:SetTexture(texture)
    point.worldmap:SetHeight(16)
    point.worldmap:SetWidth(16)

    point.worldmap.point = point;
    point.waypoint = waypoint;

    hbdp:AddWorldMapIconMap("WaypointTest", point.worldmap, point.m, point.x, point.y, 3);
end

StartLocation = nil ---@type NavLocation
StartLocationButton = nil ---@type Button
GoalLocation = nil ---@type NavLocation
GoalLocationButton = nil ---@type Button

function DistanceTestHere()
    print("Start Location:", StartLocation.mapId, StartLocation.pos.x, StartLocation.pos.y, StartLocation.pos.z, StartLocation.isUI)
    print("Goal Location:", GoalLocation.mapId, GoalLocation.pos.x, GoalLocation.pos.y, GoalLocation.pos.z, GoalLocation.isUI)
    
    ---@type NavLocation, NavLocation
    local startLocation, goalLocation =
        { mapId = StartLocation.mapId, pos = { x = StartLocation.pos.x, y = StartLocation.pos.y, z = StartLocation.pos.z }, isUI = StartLocation.isUI },
        { mapId = GoalLocation.mapId, pos = { x = GoalLocation.pos.x, y = GoalLocation.pos.y, z = GoalLocation.pos.z }, isUI = GoalLocation.isUI }

        local _, worldA = C_Map.GetWorldPosFromMapPos(startLocation.mapId, CreateVector2D(startLocation.pos.x, startLocation.pos.y))
        local _, worldB = C_Map.GetWorldPosFromMapPos(goalLocation.mapId, CreateVector2D(goalLocation.pos.x, goalLocation.pos.y))
        if worldA and worldB then
            local dist = math.sqrt((worldA.x - worldB.x)^2 + (worldA.y - worldB.y)^2 + (startLocation.pos.z - goalLocation.pos.z)^2)
            WPT.Logger:Info("Distance between start and goal locations: " .. dist)
            print("Distance between start and goal locations: " .. dist)
        end
end

function NavigationTestHere()
    print("Start Location:", StartLocation.mapId, StartLocation.pos.x, StartLocation.pos.y, StartLocation.pos.z)
    print("Goal Location:", GoalLocation.mapId, GoalLocation.pos.x, GoalLocation.pos.y, GoalLocation.pos.z)

    ---@type NavLocation, NavLocation
    local startLocation, goalLocation =
        { mapId = StartLocation.mapId, pos = { x = StartLocation.pos.x, y = StartLocation.pos.y, z = StartLocation.pos.z }, isUI = StartLocation.isUI },
        { mapId = GoalLocation.mapId, pos = { x = GoalLocation.pos.x, y = GoalLocation.pos.y, z = GoalLocation.pos.z }, isUI = GoalLocation.isUI }

    local optimizedPath, path = WPT.Pathfinding:FindPathBetweenLocations2(startLocation, goalLocation)
    if not path or #path == 0 then
        WPT.Logger:Error("No path found between the specified locations.")
        return
    end

    for i, navLocation in ipairs(path) do
        local loc = navLocation:getLocation()
        WPT.Logger:Info(string.format("Waypoint %d: Map ID %d at (%.2f, %.2f, %.2f)", i, loc.mapId, loc.pos.x, loc.pos.y, loc.pos.z))
    end
end
