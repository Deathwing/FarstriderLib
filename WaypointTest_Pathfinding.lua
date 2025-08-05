-- WaypointTest_Pathfinding.lua
-- local _, WPT = ...

local Pathfinding = {}
WPT.Pathfinding = Pathfinding

Pathfinding.allNodes = {} ---@type table<NavKey, NavNode>
Pathfinding.ignoredUIMapIds = {
    [2311] = true
}

TRAVEL_COST_MULTIPLIER = 1 / 55 -- avg dragonriding speed
if WOW_PROJECT_ID == WOW_PROJECT_MISTS_CLASSIC then
    TRAVEL_COST_MULTIPLIER = 1 / 31 -- avg 280% flying speed
end

DIRECT_TRAVEL_COST_MULTIPLIER = TRAVEL_COST_MULTIPLIER * 0.8

function Pathfinding:len(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

local mapTypeOverrides = {
    [125] = { mapType = Enum.UIMapType.Zone }, -- Dalaran: Northrend
    [627] = { mapType = Enum.UIMapType.Zone }, -- Dalaran: Broken Isles
    [1670] = { mapType = Enum.UIMapType.Zone }, -- Oribos
    [1671] = { mapType = Enum.UIMapType.Zone }, -- Oribos
    [1672] = { mapType = Enum.UIMapType.Zone }, -- Oribos
    [1673] = { mapType = Enum.UIMapType.Zone }, -- Oribos
    [2305] = { mapType = Enum.UIMapType.Zone }, -- Dalaran
}

local isolatedAreaIds = {
    -- Eastern Kingdom 
    [201] = 0, -- Kelp'thar Forest
    [203] = 0, -- Vashj'ir
    [204] = 0, -- Abyssal Depths,
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

---@param mapID number
---@return boolean
function Pathfinding:IsMapIsolated(mapID)
    local mapInfo = C_Map.GetMapInfo(mapID)
    if not mapInfo then
        WPT.Logger:Error("Map information not available for ID:", mapID)
        return false
    end

    if mapTypeOverrides[mapID] then
        -- Use the overridden map type if available
        mapInfo.mapType = mapTypeOverrides[mapID].mapType
    end

    -- What about Orphaned maps?
    if mapInfo.mapType == Enum.UIMapType.Dungeon then
        -- Dungeons and scenarios are considered isolated.
        return true
    end

    -- Check if the map has a parent map ID, which indicates it's part of a larger map
    return mapInfo.parentMapID == 0
end

function Pathfinding:GetWorldDistanceBetween(navLocationA, navLocationB)
    if not navLocationA or not navLocationB then
        WPT.Logger:Error("GetWorldDistanceBetween called with nil nav locations")
        return nil
    end

    local canTravelDirectly = self:HasDirectFlyPath(navLocationA, navLocationB)
    if not canTravelDirectly then
        return math.huge
    else
        local _, posA = C_Map.GetWorldPosFromMapPos(navLocationA.mapId, CreateVector2D(navLocationA.pos.x, navLocationA.pos.y))
        local _, posB = C_Map.GetWorldPosFromMapPos(navLocationB.mapId, CreateVector2D(navLocationB.pos.x, navLocationB.pos.y))

        if posA and posB then
            return math.sqrt((posA.x - posB.x)^2 + (posA.y - posB.y)^2 + (navLocationA.pos.z - navLocationB.pos.z)^2)
        else
            WPT.Logger:Warning("GetWorldDistanceBetween could not resolve world positions for nav locations:", navLocationA.mapId, navLocationB.mapId)
            return nil
        end
    end
end

---@param parentMapID number -- e.g., 12 for Eastern Kingdoms
---@param pos Vec3       -- local map coordinates (0.0 to 1.0)
---@return number? childMapID
function Pathfinding:GetSubZoneAtPosition(parentMapID, pos)
    local mapInfo = C_Map.GetMapInfoAtPosition(parentMapID, pos.x, pos.y)
    if mapInfo then
        return mapInfo.mapID
    end
    return nil
end

---@param parentMapID number -- e.g., 12 for Eastern Kingdoms
---@param pos Vec3       -- local map coordinates (0.0 to 1.0)
---@return number? childMapID
function Pathfinding:GetMostTopLevelSubZoneAtPosition(parentMapID, pos)
    local mapInfo = C_Map.GetMapInfoAtPosition(parentMapID, pos.x, pos.y)
    local parentMapInfo = mapInfo and mapInfo.parentMapID and C_Map.GetMapInfo(parentMapID)
    while parentMapInfo and parentMapInfo.mapType > Enum.UIMapType.Continent do
        mapInfo = parentMapInfo
        parentMapInfo = mapInfo.parentMapID and C_Map.GetMapInfo(mapInfo.parentMapID)
    end
    return mapInfo and mapInfo.mapID or nil
end

---@param mapID number
---@return UiMapDetails
function Pathfinding:GetRootMap(mapID)
    local mapInfo = C_Map.GetMapInfo(mapID)
    while mapInfo and mapInfo.parentMapID and mapInfo.parentMapID ~= 0 do
        --- Print some map info for debugging
        WPT.Logger:Info(string.format("Checking parent map: %s (ID: %d, )", mapInfo.name, mapInfo.mapID))
        mapInfo = C_Map.GetMapInfo(mapInfo.parentMapID)
    end
    return mapInfo
end

---@param uiMapID UIMapId
---@return UiMapDetails?
function Pathfinding:GetContinentMapRoot(uiMapID)
    local mapInfo = C_Map.GetMapInfo(uiMapID)
    while mapInfo and mapInfo.parentMapID and mapInfo.mapType > Enum.UIMapType.Continent do
        mapInfo = C_Map.GetMapInfo(mapInfo.parentMapID)
    end

    return mapInfo
end

--- Checks whether or not two maps can be traveled between without any teleportation.
---@param loc1 Location|NavLocation
---@param loc2 Location|NavLocation
---@return boolean
function Pathfinding:HasDirectFlyPath(loc1, loc2)

    local uiMapID1 = loc1.mapId
    local uiMapID2 = loc2.mapId

    -- If either one of the maps is isolated and we are dealing with two different maps it won't be reachable
    if (self:IsMapIsolated(uiMapID1) or self:IsMapIsolated(uiMapID2)) and uiMapID1 ~= uiMapID2 then
        return false
    end

    -- Otherwise query the common continent parent and check if we are dealing with the same continent on both
    local continentInfoMap1 = self:GetContinentMapRoot(uiMapID1)
    local continentInfoMap2 = self:GetContinentMapRoot(uiMapID2)

    if not continentInfoMap1 or not continentInfoMap2 then
        WPT.Logger:Error("Could not find continent information for map IDs:", uiMapID1, uiMapID2)
        return false
    end

    -- We assume same continent is reachable because we check isolated special cases above
    if continentInfoMap1.mapID == continentInfoMap2.mapID then
        if continentInfoMap1.mapID == 2274 then
            local subzone1 = self:GetMostTopLevelSubZoneAtPosition(uiMapID1, loc1.pos) or uiMapID1
            local subzone2 = self:GetMostTopLevelSubZoneAtPosition(uiMapID2, loc2.pos) or uiMapID2

            return subzone1 == subzone2
        end

        local subzone1 = self:GetMostTopLevelSubZoneAtPosition(uiMapID1, loc1.pos) or uiMapID1
        local subzone2 = self:GetMostTopLevelSubZoneAtPosition(uiMapID2, loc2.pos) or uiMapID2

        return isolatedAreaIds[subzone1] == isolatedAreaIds[subzone2]
    end

    return false
end

--- Checks whether or not two NavNodes can be traveled between without any teleportation.
---@param navNode1 NavNode
---@param navNode2 NavNode
---@return boolean
function Pathfinding:HasDirectFlyPathForNavs(navNode1, navNode2)
    if not navNode1 or not navNode2 then
        WPT.Logger:Error("CanTravelBetweenNavs called with nil nav nodes")
        return false
    end

    return self:HasDirectFlyPath(navNode1:getLocation(), navNode2:getLocation())
end

---@param waypointLocation WaypointLocation
---@param graph table<NavKey, NavNode>
---@return NavNode?
function Pathfinding:ConvertWaypointLocationToNavLocation(waypointLocation, graph, suffix)
    if not waypointLocation.loc then
        local dynamicNode = WPT.NavNode.createDynamic(waypointLocation.dynLoc, suffix, {})
        return graph[dynamicNode.key] or dynamicNode
    end

    if waypointLocation.loc.isUI then
        local uiNode = WPT.NavNode.create(waypointLocation.loc.mapId, { x = waypointLocation.loc.pos.x, y = waypointLocation.loc.pos.y, z = waypointLocation.loc.pos.z }, waypointLocation.loc.isUI, {})
        return graph[uiNode.key] or uiNode
    end

    local worldVec = CreateVector2D(waypointLocation.loc.pos.x, waypointLocation.loc.pos.y)

    local uiMapId, localPos = C_Map.GetMapPosFromWorldPos(waypointLocation.loc.mapId, worldVec)


    if not uiMapId or not localPos then
        WPT.Logger:Error(string.format("Could not resolve UIMapId for locaId %d (continent mapId %d)", waypointLocation.locaId, waypointLocation.loc.mapId))
        return nil
    end
    
    -- local continentInfo = self:GetContinentMapRoot(uiMapId)
    -- if not continentInfo then
    --     WPT.Logger:Error(string.format("Could not find continent information for map ID %d", uiMapId))
    --     return nil
    -- end

    -- local continentUiMapId = continentInfo.mapID
    -- if uiMapId ~= continentUiMapId then
    --     print("Warning: The UIMapId does not match the continent map ID. This might lead to incorrect local position calculations.")

    --     -- calculate continentLocalPos
    --     local _, continentLocalPos = C_Map.GetMapPosFromWorldPos(waypointLocation.loc.mapId, worldVec, continentUiMapId)
    --     continentLocalPos = continentLocalPos or { x = -1, y = -1 } -- Fallback if the position could not be resolved
    --     print("Translated ", uiMapId, localPos.x, localPos.y, " to continent local position: ", continentUiMapId, continentLocalPos.x, continentLocalPos.y)
    --     WPT.Logger:Warning(string.format("Translated %d (%.2f, %.2f) to continent local position: %d (%.2f, %.2f)", uiMapId, localPos.x, localPos.y, continentUiMapId, continentLocalPos.x, continentLocalPos.y))
    -- end

    local node = WPT.NavNode.create(uiMapId, { x = localPos.x, y = localPos.y, z = waypointLocation.loc.pos.z }, true, {})
    return graph[node.key] or node
end

---@param node NavNode
function Pathfinding:NodeContainsAnyActiveEdge(node)
    if not node or not node.edges then
        return false
    end

    local valid = true

    for _, edge in ipairs(node.edges) do
        -- once we reach auto added travel edges, we can stop
        if edge.locaId == MRP.SpecialLocaId.TravelTo then
            break
        end

        if edge.condition and not edge.condition() then
            valid = false
            break
        end
    end

    return valid
end

---@param location NavLocation
---@param nodes table<NavKey, NavNode>
---@return { navNode: NavNode, cost: number }[] connections
function Pathfinding:FindClosestNavConnections(location, nodes)
    local connections = {}
    WPT.Logger:Info(string.format("Finding closest nav connections from map %d at position (%.2f, %.2f, %.2f)", location.mapId, location.pos.x, location.pos.y, location.pos.z))

    for _, navNode in pairs(nodes) do
        if not navNode.isDynamic then
            local navNodeLoc = navNode:getLocation()
            if self:HasDirectFlyPath(location, navNodeLoc) then
                local _, worldA = C_Map.GetWorldPosFromMapPos(location.mapId, CreateVector2D(location.pos.x, location.pos.y))
                local _, worldB = C_Map.GetWorldPosFromMapPos(navNodeLoc.mapId, CreateVector2D(navNodeLoc.pos.x, navNodeLoc.pos.y))
                if worldA and worldB then
                    local dist = math.sqrt((worldA.x - worldB.x)^2 + (worldA.y - worldB.y)^2+ (location.pos.z - navNodeLoc.pos.z)^2)
                    table.insert(connections, { navNode = navNode, cost = dist * TRAVEL_COST_MULTIPLIER })
                    
                    -- WPT.Logger:Info(string.format("  ✓ Reachable node %d at (%.2f, %.2f), distance = %.1f", navNodeLoc.mapId, navNodeLoc.pos.x, navNodeLoc.pos.y, dist))
                else
                    WPT.Logger:Warning(string.format("  ✗ Could not resolve world position for node %d", navNodeLoc.mapId))
                end
            end
        end
    end

    table.sort(connections, function(a, b) return a.cost < b.cost end)
    WPT.Logger:Info(string.format("  Found %d valid connections", #connections))
    return connections
end

---@param locaId number
---@param locaArgs? table
function Pathfinding:GetNodeLoca(locaId, locaArgs)
    local loca = self:GetNodeLocaDirect(locaId)
    if locaArgs then
        loca = string.format(loca, unpack(locaArgs()))
    end
    return loca
end
    
function Pathfinding:GetNodeLocaDirect(locaId)
    if not locaId then
        return "Unknown Location (no locaId provided)"
    end

    local loca = MRP.WaypointL[locaId]
    if not loca then
        loca = MRP.L["Waypoint_" .. locaId]
        if not loca then
            loca = "Unknown Location (no loca found for locaId " .. locaId .. ")"
        end
    end

    return loca
end

--- Create a virtual NavNode at the specified location with edges to the closest NavNodes
--- Virtual means it is not part of the main NavNode graph and is used for temporary pathfinding purposes only.
---@param location NavLocation
---@param nodes table<NavKey, NavNode>
---@return NavNode
function Pathfinding:CreateVirtualNavNode(location, nodes)
    local virtualNode = WPT.NavNode.create(location.mapId, location.pos, true, {})
    local connections = self:FindClosestNavConnections(location, nodes)
    local navEdge ---@type NavEdge
    for _, connection in ipairs(connections) do
        navEdge = { to = connection.navNode, cost = connection.cost, flag = 0, locaId = MRP.SpecialLocaId.TravelTo, type = 0, important = false }
        table.insert(virtualNode.edges, navEdge)
        navEdge = { to = virtualNode, cost = connection.cost, flag = 0, locaId = MRP.SpecialLocaId.TravelTo, type = 0, important = false }
        table.insert(connection.navNode.tempEdges, navEdge)
    end

    return virtualNode
end

function Pathfinding:CleanupTempEdges()
    for _, navNode in pairs(self.allNodes) do
        navNode.tempEdges = {}
    end
end

--- Find the shortest path and return both the nodes and the edges to traverse
---@param startLocation NavLocation
---@param goalLocation NavLocation
---@return table[] optimizedPath, NavNode[] path, NavEdge[] edges
function Pathfinding:FindPathBetweenLocations2(startLocation, goalLocation)
    self:CleanupTempEdges()

    WPT.Logger:Info("=== Starting pathfinding ===")
    WPT.Logger:Info(string.format("Start: map %d (%.2f, %.2f, %.2f)", startLocation.mapId, startLocation.pos.x, startLocation.pos.y, startLocation.pos.z))
    WPT.Logger:Info(string.format("Goal : map %d (%.2f, %.2f, %.2f)", goalLocation.mapId, goalLocation.pos.x, goalLocation.pos.y, goalLocation.pos.z))

    ---@type table<NavKey, NavNode>
    local validTravelNodes = {}
    for _, navNode in pairs(self.allNodes) do
        if self:NodeContainsAnyActiveEdge(navNode) then
            validTravelNodes[navNode.key] = navNode
        end
    end

    -- Create virtual NavNodes for start and goal locations
    local startNavNode = self:CreateVirtualNavNode(startLocation, validTravelNodes)
    if DevTool then -- MRP_REMOVE_LINE
        DevTool:AddData(startNavNode, "Start NavNode") -- MRP_REMOVE_LINE
    end -- MRP_REMOVE_LINE

    local dynamicFromNode = self.allNodes["dynamic:from"]
    if dynamicFromNode then
        for _, edge in ipairs(dynamicFromNode.edges) do
            table.insert(startNavNode.tempEdges, edge)
            if (edge.to.key == "dynamic:to" and (not edge.condition or edge.condition())) then
                local loc = edge.to:getLocation()

                local uiMapId, localPos
                if loc.isUI then
                    uiMapId = loc.mapId
                    localPos = CreateVector2D(loc.pos.x, loc.pos.y)
                else
                    uiMapId, localPos = C_Map.GetMapPosFromWorldPos(loc.mapId, CreateVector2D(loc.pos.x, loc.pos.y))
                end

                local connections = self:FindClosestNavConnections({ mapId = uiMapId, pos = { x = localPos.x, y = localPos.y, z = loc.pos.z }, isUI = true }, self.allNodes)
                for _, connection in ipairs(connections) do
                    local navEdge = { to = connection.navNode, cost = connection.cost, flag = 0, locaId = MRP.SpecialLocaId.TravelTo, type = 0 }
                    table.insert(edge.to.tempEdges, navEdge)
                end
            end
        end
    end

    local goalNavNode = self:CreateVirtualNavNode(goalLocation, validTravelNodes)
    if DevTool then -- MRP_REMOVE_LINE
        DevTool:AddData(goalNavNode, "Goal NavNode") -- MRP_REMOVE_LINE
    end -- MRP_REMOVE_LINE

    local startLoc = startNavNode:getLocation()
    local goalLoc = goalNavNode:getLocation()
    if self:HasDirectFlyPath(startLoc, goalLoc) then
        local _, worldA = C_Map.GetWorldPosFromMapPos(startLoc.mapId, CreateVector2D(startLoc.pos.x, startLoc.pos.y))
        local _, worldB = C_Map.GetWorldPosFromMapPos(goalLoc.mapId, CreateVector2D(goalLoc.pos.x, goalLoc.pos.y))
        if worldA and worldB then
            local dist = math.sqrt((worldA.x - worldB.x)^2 + (worldA.y - worldB.y)^2 + (startLoc.pos.z - goalLoc.pos.z)^2)
            table.insert(startNavNode.edges, { to = goalNavNode, cost = dist * DIRECT_TRAVEL_COST_MULTIPLIER, locaId = MRP.SpecialLocaId.TravelTo })
            table.insert(goalNavNode.edges, { to = startNavNode, cost = dist * DIRECT_TRAVEL_COST_MULTIPLIER, locaId = MRP.SpecialLocaId.TravelTo })
        end
    end

    -- Dijkstra setup
    local queue = {} ---@type NavNode[]
    local navCostTable = {} ---@type table<NavKey, number>
    local cameFromTable = {} ---@type table<NavKey, NavNode>
    local cameFromEdgeTable = {} ---@type table<NavKey, NavEdge>
    if DevTool then -- MRP_REMOVE_LINE
        DevTool:AddData(queue, "Queue") -- MRP_REMOVE_LINE
        DevTool:AddData(navCostTable, "Nav Cost Table") -- MRP_REMOVE_LINE
        DevTool:AddData(cameFromTable, "Came From Table") -- MRP_REMOVE_LINE
        DevTool:AddData(cameFromEdgeTable, "Came From Edge Table") -- MRP_REMOVE_LINE
    end -- MRP_REMOVE_LINE

    navCostTable[startNavNode.key] = 0
    table.insert(queue, startNavNode)

    -- Explore graph
    while #queue > 0 do
        -- Use a priority queue based on our navCostTable
        table.sort(queue, function(a,b) return (navCostTable[a.key] or math.huge) < (navCostTable[b.key] or math.huge) end)

        local current = table.remove(queue, 1) ---@type NavNode
        -- WPT.Logger:InfoGreen("Chose node ", current.mapId, "at position (", current.pos.x, ",", current.pos.y, ") with cost", navCostTable[current.key] or 0)
        if current.key == goalNavNode.key then
            local currentLoc = current:getLocation()
            WPT.Logger:InfoGreen("Reached goal node ", currentLoc.mapId, "at position (", currentLoc.pos.x, ",", currentLoc.pos.y, ")")
            break
        end
        
        -- WPT.Logger:Info("Current node has edges:", #current.edges or 0)
        for edge in WPT.NavNode.iterateAllEdges(current) do
            if not edge.condition or edge.condition() then
                -- WPT.Logger:Info("  Checking edge to node ", edge.to.mapId, " with cost ", edge.cost or 0)
                local neighbour = edge.to
                local edgeCost = edge.cost or math.huge
                local newCost = (navCostTable[current.key] or math.huge) + edgeCost
                local oldCost = navCostTable[neighbour.key] or math.huge

                if newCost < oldCost then
                    -- WPT.Logger:Info("  Found better path to node ", neighbour.mapId, " with cost ", newCost, " (old cost was ", oldCost, ")")
                    navCostTable[neighbour.key] = newCost
                    cameFromTable[neighbour.key] = current
                    cameFromEdgeTable[neighbour.key] = edge
                    table.insert(queue, neighbour)
                end
            end
        end
    end

    -- Reconstruct path and edges
    local path, edges = {}, {} ---@type NavNode[], NavEdge[]
    local node = goalNavNode
    while node do
        table.insert(path, 1, node)
        if cameFromEdgeTable[node.key] then
            table.insert(edges, 1, cameFromEdgeTable[node.key])
            -- WPT.Logger:InfoGreen("Reconstructing path: current node", node.mapId, "at position (", node.pos.x, ",", node.pos.y, ")", " in ", self:GetNodeLoca(cameFromEdgeTable[node.key].locaId))
        end
        node = cameFromTable[node.key]
    end

    if #path < 2 then
        WPT.Logger:Error("Path could not be resolved")
        return {}, {}, {}
    end

    -- Collapse redundant steps
    -- path = CollapseRedundantFlyableSteps(path)

    WPT.Logger:Info(string.format("Path found: %d nodes, %d edges", #path, #edges))

    local virtualGoalKey = goalNavNode.key
    local optimizedPath = {}

    for i = 1, #edges do
        local edge = edges[i]

        local isFinalTravelToGoal = edge.to.key == virtualGoalKey
        local isFlightpath = edge.locaId == MRP.SpecialLocaId.FlightpathTo
        local isIntermediateTravel = not isFinalTravelToGoal and (edge.locaId == MRP.SpecialLocaId.TravelTo or (i + 1 < #edges and isFlightpath and edges[i + 1].locaId == MRP.SpecialLocaId.FlightpathTo))

        -- Skip intermediate travel edges, but keep the final one to the actual goal
        if not isIntermediateTravel or i == #edges then
            table.insert(optimizedPath, {
                id = edge.to.key,
                loc = (edge.important and not isFlightpath and i > 1) and edges[i - 1].to:getLocation() or edge.to:getLocation(),
                loca = self:GetNodeLoca(edge.locaId, edge.locaArgs),
                actionOptions = edge.actionOptions,
                checkDistance = not (i == #edges or edge.important)
            })
        else
            WPT.Logger:Info("Skipping intermediate travel-to edge to " .. edge.to.key)
        end
    end

    -- -- skip all skippable notes (except if the last one is skippable)
    -- for i = 1, #edges do
    --     if not edges[i].skippable or i == #edges then
    --         table.insert(optimizedPath, { checkpoint = edges[i].to:getLocation(), loca = self:GetNodeLoca(edges[i].locaId), actionOptions = edges[i].actionOptions, id = edges[i].to.key })
    --     end
    -- end
    
    -- local skip = {}
    -- for i, _ in ipairs(edges) do
    --     skip[i] = false
    -- end

    -- for i, edge in ipairs(edges) do
    --     if not skip[i] then
    --         if edge.locaId == MRP.SpecialLocaId.TravelTo and #edges > i and edges[i + 1].locaId ~= MRP.SpecialLocaId.TravelTo then
    --             local next = edges[i + 1]
    --             table.insert(optimizedPath, { enter = edge.to:getLocation(), exit = next.to:getLocation(), loca = self:GetNodeLoca(next.locaId), actionOptions = next.actionOptions, id = edge.to.key .. next.to.key })
    --             skip[i + 1] = true
    --             if bit.band(next.flag, 4) ~= 0 and #edges > i + 2 and edges[i + 2].locaId ~= 1 then
    --                 WPT.Logger:Warning("Skipping edge " .. i + 2 .. " because it is after a exit edge with flag 4: ",  self:GetNodeLoca(edges[i + 2].locaId))
    --                 skip[i + 2] = true
    --             end
    --         else
    --             table.insert(optimizedPath, { checkpoint = edge.to:getLocation(), loca = self:GetNodeLoca(edge.locaId), actionOptions = edge.actionOptions, id = edge.to.key })
    --         end
    --     end
    -- end

    return optimizedPath, path, edges
end

---@param waypoints Waypoint[]
---@return table<NavKey, NavNode> graph
function Pathfinding:CreateWaypointGraph(waypoints)
    local graph = {} ---@type table<NavKey, NavNode>
    local navEdge ---@type NavEdge

    for _, waypoint in ipairs(waypoints) do
        -- TODO: Check if really true @Savi
        -- It seems all waypoint edges can have a condition, additionally to their waypoint nodes.
        -- Let's evaluate the condition of the edge only once... not accurate maybe... but lets see :D
        local valid = not waypoint.condition or waypoint.condition()

        -- Check if the waypoint is an actual location a to b and not some ability
        -- Simplest way to check is if both from and to do have a location assigned to them
        if valid and waypoint.from and waypoint.to then
            local fromNav = self:ConvertWaypointLocationToNavLocation(waypoint.from, graph, "from")
            local toNav = self:ConvertWaypointLocationToNavLocation(waypoint.to, graph, "to")

            if fromNav and toNav then
                graph[fromNav.key] = fromNav
                graph[toNav.key] = toNav

                navEdge = { to = toNav, cost = waypoint.cost, locaId = waypoint.from.locaId, locaArgs = waypoint.from.locaArgs, flag = waypoint.from.flags, type = waypoint.from.type, condition = waypoint.from.condition, actionOptions = waypoint.from.actionOptions, important = waypoint.from.important }
                table.insert(fromNav.edges, navEdge)
                if waypoint.bidirectional then
                    navEdge = { to = fromNav, cost = waypoint.cost, locaId = waypoint.to.locaId, locaArgs = waypoint.to.locaArgs, flag = waypoint.to.flags, type = waypoint.to.type, condition = waypoint.to.condition, actionOptions = waypoint.to.actionOptions, important = waypoint.to.important }
                    table.insert(toNav.edges, navEdge)
                end
                
                WPT.Logger:Info("Adding waypoint ", fromNav.key, " to ", toNav.key, " for id ", waypoint.id, " with locaId ", waypoint.from.locaId, " from edges ", #fromNav.edges, " to edges ", #toNav.edges)
            end
        end
    end

    return graph
end

---@param optimizedPath table[]
---@param path NavNode[]
---@param edges NavEdge[]
function Pathfinding:PrintPath(optimizedPath, path, edges)
    if not path or #path == 0 then
        WPT.Logger:Error("No path found between the specified locations.")
        return
    end

    if TomTom then -- MRP_REMOVE_LINE
        TomTom.waydb:ResetProfile() -- MRP_REMOVE_LINE
        TomTom:ReloadWaypoints() -- MRP_REMOVE_LINE
    end -- MRP_REMOVE_LINE

    if DevTool then -- MRP_REMOVE_LINE
        DevTool:AddData(path, "Path Nodes") -- MRP_REMOVE_LINE
        DevTool:AddData(edges, "Path Edges") -- MRP_REMOVE_LINE
        DevTool:AddData(optimizedPath, "Optimized Path Edges") -- MRP_REMOVE_LINE
    end -- MRP_REMOVE_LINE

    -- local optimizedPath = {}
    
    -- local skip = {}
    -- for i, _ in ipairs(edges) do
    --     skip[i] = false
    -- end

    -- for i, edge in ipairs(edges) do
    --     if not skip[i] then
    --         if edge.locaId == MRP.SpecialLocaId.TravelTo and #edges > i and edges[i + 1].locaId ~= MRP.SpecialLocaId.TravelTo then
    --             local next = edges[i + 1]
    --             table.insert(optimizedPath, { enter = edge.to:getLocation(), exit = next.to:getLocation(), loca = self:GetNodeLoca(next.locaId), actionOptions = next.actionOptions, id = edge.to.key .. next.to.key })
    --             skip[i + 1] = true
    --             if bit.band(next.flag, 4) ~= 0 and #edges > i + 2 and edges[i + 2].locaId ~= 1 then
    --                 WPT.Logger:Warning("Skipping edge " .. i + 2 .. " because it is after a exit edge with flag 4: ",  self:GetNodeLoca(edges[i + 2].locaId))
    --                 skip[i + 2] = true
    --             end
    --         else
    --             table.insert(optimizedPath, { checkpoint = edge.to:getLocation(), loca = self:GetNodeLoca(edge.locaId), actionOptions = edge.actionOptions, id = edge.to.key })
    --         end
    --     end
    -- end

    -- DevTool:AddData(optimizedPath, "Final Path Edges") -- MRP_REMOVE_LINE

    for i, edge in ipairs(optimizedPath) do
        local loc = edge.loc or edge.checkpoint or edge.enter
        if loc then
            -- WPT.Logger:Info("Waypoint " .. i .. ": " .. getMapName(loc.mapId) .. "(".. loc.mapId ..")" .. " at (" .. loc.pos.x .. ", " .. loc.pos.y .. ", " .. loc.pos.z .. ")")
            WPT.Logger:Info("Instruction: " .. edge.loca)

            SetWaypoint(loc, "Interface\\AddOns\\WaypointTest\\Images\\GoldGreenDot", {
                index = i - 1,
                text = self:GetNodeLoca(edge.locaId, edge.locaArgs),
                -- useTomTom = true
            })
        else
            WPT.Logger:Error("No location found for edge " .. i)
        end
    end

    -- return optimizedPath
end

function Pathfinding:Initialize()
    self.allNodes = self:CreateWaypointGraph(MRP.Waypoints or {})
    local navEdge ---@type NavEdge

    -- Connect the nav nodes that are directly reachable with each other by creating edges
    for _, navNode in pairs(self.allNodes) do
        if not navNode.isDynamic then
            local loc = navNode:getLocation()
            if not self:IsMapIsolated(loc.mapId) then
                local connections = self:FindClosestNavConnections({ mapId = loc.mapId, pos = loc.pos, isUI = loc.isUI }, self.allNodes)
                for _, connection in ipairs(connections) do
                    if connection.navNode.key ~= navNode.key then
                        navEdge = { to = connection.navNode, cost = connection.cost, flag = 0, locaId = MRP.SpecialLocaId.TravelTo, type = 0, important = false }
                        table.insert(navNode.edges, navEdge)
                    end
                end
            end
        end
    end

    -- self.allNodes = self:BreadthFirstSearch(MRP.Waypoints or {})
    WPT.Logger:Info("Pathfinding initialized with", self:len(self.allNodes), "nodes.")
end

function ChangeTravelCostMultiplier(newMultiplier)
    TRAVEL_COST_MULTIPLIER = newMultiplier
    WPT.Logger:Info("Travel cost multiplier changed to:", newMultiplier)
    Pathfinding:Initialize()
end