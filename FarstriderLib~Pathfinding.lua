-- FarstriderLib~Pathfinding.lua
-- Dijkstra shortest-path engine over the waypoint navigation graph.

---@class Pathfinding
---@field allNodes table<NavKey, NavNode>  The full navigation graph
---@field ignoredUIMapIds table<number, boolean>
local Pathfinding = {}
FarstriderLib.Pathfinding = Pathfinding

Pathfinding.allNodes = {} ---@type table<NavKey, NavNode>
Pathfinding.ignoredUIMapIds = FarstriderData and FarstriderData.Config.IgnoredMaps or {}

-- Cached valid travel nodes (invalidated when conditions might change)
Pathfinding._validTravelNodesCache = nil ---@type table<NavKey, NavNode>?
Pathfinding._validTravelNodesCacheTime = 0

--- Invalidate the valid-travel-nodes cache and continent lookup cache.
function Pathfinding:InvalidateCache()
    self._validTravelNodesCache = nil
    self._validTravelNodesCacheTime = 0
    self._continentCache = {}
end

-- Initialize continent cache
Pathfinding._continentCache = {}

--- Return all nodes that have at least one active (condition-passing) edge.
--- Results are cached for 2 seconds to avoid redundant re-evaluation.
---@return table<NavKey, NavNode>
function Pathfinding:GetValidTravelNodes()
    local now = GetTime()
    -- Reuse cache if less than 2 seconds old (conditions don't change between rapid step clicks)
    if self._validTravelNodesCache and (now - self._validTravelNodesCacheTime) < 2 then
        return self._validTravelNodesCache
    end

    local validTravelNodes = {} ---@type table<NavKey, NavNode>
    for _, navNode in pairs(self.allNodes) do
        if self:NodeContainsAnyActiveEdge(navNode) then
            validTravelNodes[navNode.key] = navNode
        end
    end
    self._validTravelNodesCache = validTravelNodes
    self._validTravelNodesCacheTime = now
    return validTravelNodes
end

local TRAVEL_COST_MULTIPLIER = 1 / 55 -- avg dragonriding speed
if WOW_PROJECT_ID == WOW_PROJECT_MISTS_CLASSIC then
    TRAVEL_COST_MULTIPLIER = 1 / 31   -- avg 280% flying speed
end

local DIRECT_TRAVEL_COST_MULTIPLIER = TRAVEL_COST_MULTIPLIER * 0.8

--- Count entries in a hash table.
---@param t table
---@return number
function Pathfinding:len(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

local mapTypeOverrides = FarstriderData and FarstriderData.Config.MapTypeOverrides or {}
local isolatedAreaIds = FarstriderData and FarstriderData.Config.IsolatedAreas or {}

---@param mapID number
---@return boolean
function Pathfinding:IsMapIsolated(mapID)
    local mapInfo = C_Map.GetMapInfo(mapID)
    if not mapInfo then
        FarstriderLib.Logger:Error("Map information not available for ID:", mapID)
        return false
    end

    if mapTypeOverrides[mapID] then
        mapInfo.mapType = mapTypeOverrides[mapID].mapType
    end

    if mapInfo.mapType == Enum.UIMapType.Dungeon then
        return true
    end

    return mapInfo.parentMapID == 0
end

--- Compute the 3D world distance between two nav locations.
--- Returns `math.huge` if they are on disconnected continents.
---@param navLocationA NavLocation
---@param navLocationB NavLocation
---@return number?
function Pathfinding:GetWorldDistanceBetween(navLocationA, navLocationB)
    if not navLocationA or not navLocationB then
        FarstriderLib.Logger:Error("GetWorldDistanceBetween called with nil nav locations")
        return nil
    end

    local canTravelDirectly = self:HasDirectFlyPath(navLocationA, navLocationB)
    if not canTravelDirectly then
        return math.huge
    else
        local _, posA = C_Map.GetWorldPosFromMapPos(navLocationA.mapId,
            CreateVector2D(navLocationA.pos.x, navLocationA.pos.y))
        local _, posB = C_Map.GetWorldPosFromMapPos(navLocationB.mapId,
            CreateVector2D(navLocationB.pos.x, navLocationB.pos.y))

        if posA and posB then
            return math.sqrt((posA.x - posB.x) ^ 2 + (posA.y - posB.y) ^ 2 +
                (navLocationA.pos.z - navLocationB.pos.z) ^ 2)
        else
            FarstriderLib.Logger:Warning("GetWorldDistanceBetween could not resolve world positions for nav locations:",
                navLocationA.mapId, navLocationB.mapId)
            return nil
        end
    end
end

---@param parentMapID number
---@param pos Vec3
---@return number? childMapID
function Pathfinding:GetSubZoneAtPosition(parentMapID, pos)
    local mapInfo = C_Map.GetMapInfoAtPosition(parentMapID, pos.x, pos.y)
    if mapInfo then
        return mapInfo.mapID
    end
    return nil
end

---@param parentMapID number
---@param pos Vec3
---@return number? childMapID
function Pathfinding:GetMostTopLevelSubZoneAtPosition(parentMapID, pos)
    local mapInfo = C_Map.GetMapInfoAtPosition(parentMapID, pos.x, pos.y)
    local parentMapInfo = mapInfo and mapInfo.parentMapID and C_Map.GetMapInfo(mapInfo.parentMapID)
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
        FarstriderLib.Logger:Info(string.format("Checking parent map: %s (ID: %d)", mapInfo.name, mapInfo.mapID))
        mapInfo = C_Map.GetMapInfo(mapInfo.parentMapID)
    end
    return mapInfo
end

---@param uiMapID UIMapId
---@return UiMapDetails?
function Pathfinding:GetContinentMapRoot(uiMapID)
    if self._continentCache[uiMapID] ~= nil then
        return self._continentCache[uiMapID] or nil
    end

    local mapInfo = C_Map.GetMapInfo(uiMapID)
    while mapInfo and mapInfo.parentMapID and mapInfo.mapType > Enum.UIMapType.Continent do
        mapInfo = C_Map.GetMapInfo(mapInfo.parentMapID)
    end

    self._continentCache[uiMapID] = mapInfo or false
    return mapInfo
end

--- Checks whether or not two maps can be traveled between without any teleportation.
---@param loc1 Location|NavLocation
---@param loc2 Location|NavLocation
---@return boolean
function Pathfinding:HasDirectFlyPath(loc1, loc2)
    local uiMapID1 = loc1.mapId
    local uiMapID2 = loc2.mapId

    if (self:IsMapIsolated(uiMapID1) or self:IsMapIsolated(uiMapID2)) and uiMapID1 ~= uiMapID2 then
        return false
    end

    local continentInfoMap1 = self:GetContinentMapRoot(uiMapID1)
    local continentInfoMap2 = self:GetContinentMapRoot(uiMapID2)

    if not continentInfoMap1 or not continentInfoMap2 then
        FarstriderLib.Logger:Error("Could not find continent information for map IDs:", uiMapID1, uiMapID2)
        return false
    end

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
        FarstriderLib.Logger:Error("CanTravelBetweenNavs called with nil nav nodes")
        return false
    end

    return self:HasDirectFlyPath(navNode1:getLocation(), navNode2:getLocation())
end

--- Convert a WaypointLocation (world or UI coords) into a NavNode,
--- reusing an existing node from the graph when the key matches.
---@param waypointLocation WaypointLocation
---@param graph table<NavKey, NavNode>
---@param suffix string  Key suffix for dynamic nodes ("from" / "to")
---@return NavNode?
function Pathfinding:ConvertWaypointLocationToNavLocation(waypointLocation, graph, suffix)
    if not waypointLocation.loc then
        local dynamicNode = FarstriderLib.NavNode.createDynamic(waypointLocation.dynLoc, suffix, {})
        return graph[dynamicNode.key] or dynamicNode
    end

    if waypointLocation.loc.isUI then
        local uiNode = FarstriderLib.NavNode.create(waypointLocation.loc.mapId,
            { x = waypointLocation.loc.pos.x, y = waypointLocation.loc.pos.y, z = waypointLocation.loc.pos.z },
            waypointLocation.loc.isUI, {})
        return graph[uiNode.key] or uiNode
    end

    local worldVec = CreateVector2D(waypointLocation.loc.pos.x, waypointLocation.loc.pos.y)
    local uiMapId, localPos = C_Map.GetMapPosFromWorldPos(waypointLocation.loc.mapId, worldVec)

    if not uiMapId or not localPos then
        FarstriderLib.Logger:Error(string.format("Could not resolve UIMapId for locaId %d (continent mapId %d)",
            waypointLocation.locaId, waypointLocation.loc.mapId))
        return nil
    end

    local node = FarstriderLib.NavNode.create(uiMapId, { x = localPos.x, y = localPos.y, z = waypointLocation.loc.pos.z },
        true, {})
    return graph[node.key] or node
end

--- Check whether a node has at least one active (usable) edge.
--- Returns true as soon as any non-travel edge passes its condition,
--- or when a travel edge is encountered (always valid).
---@param node NavNode
---@return boolean
function Pathfinding:NodeContainsAnyActiveEdge(node)
    if not node or not node.edges then
        return false
    end

    local ET = FarstriderLib.EdgeType

    for _, edge in ipairs(node.edges) do
        -- Travel edges are auto-added and always valid
        if edge.locaId == ET.TRAVEL then
            return true
        end
        -- At least one transport edge with a passing (or absent) condition
        if not edge.condition or edge.condition() then
            return true
        end
    end

    return false
end

---@param location NavLocation
---@param nodes table<NavKey, NavNode>
---@return { navNode: NavNode, cost: number }[] connections
function Pathfinding:FindClosestNavConnections(location, nodes)
    local connections = {}
    FarstriderLib.Logger:Info(string.format("Finding closest nav connections from map %d at position (%.2f, %.2f, %.2f)",
        location.mapId, location.pos.x, location.pos.y, location.pos.z))

    for _, navNode in pairs(nodes) do
        if not navNode.isDynamic then
            local navNodeLoc = navNode:getLocation()
            if self:HasDirectFlyPath(location, navNodeLoc) then
                local _, worldA = C_Map.GetWorldPosFromMapPos(location.mapId,
                    CreateVector2D(location.pos.x, location.pos.y))
                local _, worldB = C_Map.GetWorldPosFromMapPos(navNodeLoc.mapId,
                    CreateVector2D(navNodeLoc.pos.x, navNodeLoc.pos.y))
                if worldA and worldB then
                    local dist = math.sqrt((worldA.x - worldB.x) ^ 2 + (worldA.y - worldB.y) ^ 2 +
                        (location.pos.z - navNodeLoc.pos.z) ^ 2)
                    table.insert(connections, { navNode = navNode, cost = dist * TRAVEL_COST_MULTIPLIER })
                else
                    FarstriderLib.Logger:Warning(string.format("  Could not resolve world position for node %d",
                        navNodeLoc.mapId))
                end
            end
        end
    end

    table.sort(connections, function(a, b) return a.cost < b.cost end)
    FarstriderLib.Logger:Info(string.format("  Found %d valid connections", #connections))
    return connections
end

--- Resolve the localized description for a navigation edge.
---@param locaId number   EdgeType constant or custom locaId
---@param locaArgs? fun(): any[]  Lazy format-string arguments
---@return string
function Pathfinding:GetNodeLoca(locaId, locaArgs)
    local loca = self:GetNodeLocaDirect(locaId)
    if locaArgs then
        loca = string.format(loca, unpack(locaArgs()))
    end
    return loca
end

--- Resolve the raw (unformatted) localized string for a locaId.
---@param locaId number?
---@return string
function Pathfinding:GetNodeLocaDirect(locaId)
    if not locaId then
        return "Unknown Location (no locaId provided)"
    end

    local Data = FarstriderData
    if Data then
        local loca = Data.WaypointL and Data.WaypointL[locaId]
        if not loca then
            loca = Data.L and Data.L["Waypoint_" .. locaId]
        end
        if loca then return loca end
    end

    -- Fallback: describe by EdgeType name
    local ET = FarstriderLib.EdgeType
    if locaId == ET.TRAVEL then
        return "Travel to %s"
    elseif locaId == ET.FLIGHTPATH then
        return "Take flight to %s"
    elseif locaId == ET.BOAT then
        return "Take boat from %s to %s"
    elseif locaId == ET.ZEPPELIN then
        return "Take zeppelin from %s to %s"
    elseif locaId == ET.PORTAL then
        return "Take portal to %s"
    elseif locaId == ET.ITEM then
        return "Use %s to go to %s"
    elseif locaId == ET.SPELL then
        return "Cast %s to go to %s"
    end

    return "Unknown Location (locaId " .. locaId .. ")"
end

--- Create a virtual NavNode at the specified location with edges to the closest NavNodes
---@param location NavLocation
---@param nodes table<NavKey, NavNode>
---@return NavNode
function Pathfinding:CreateVirtualNavNode(location, nodes)
    local ET = FarstriderLib.EdgeType
    local virtualNode = FarstriderLib.NavNode.create(location.mapId, location.pos, true, {})
    local connections = self:FindClosestNavConnections(location, nodes)
    local navEdge ---@type NavEdge
    for _, connection in ipairs(connections) do
        navEdge = { to = connection.navNode, cost = connection.cost, flag = 0, locaId = ET.TRAVEL, type = 0, important = false }
        table.insert(virtualNode.edges, navEdge)
        navEdge = { to = virtualNode, cost = connection.cost, flag = 0, locaId = ET.TRAVEL, type = 0, important = false }
        table.insert(connection.navNode.tempEdges, navEdge)
    end

    return virtualNode
end

--- Remove all temporary edges from every node in the graph.
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

    local ET = FarstriderLib.EdgeType

    FarstriderLib.Logger:Info("=== Starting pathfinding ===")
    FarstriderLib.Logger:Info(string.format("Start: map %d (%.2f, %.2f, %.2f)", startLocation.mapId, startLocation.pos.x,
        startLocation.pos.y, startLocation.pos.z))
    FarstriderLib.Logger:Info(string.format("Goal : map %d (%.2f, %.2f, %.2f)", goalLocation.mapId, goalLocation.pos.x,
        goalLocation.pos.y, goalLocation.pos.z))

    ---@type table<NavKey, NavNode>
    local validTravelNodes = self:GetValidTravelNodes()

    -- Create virtual NavNodes for start and goal locations
    local startNavNode = self:CreateVirtualNavNode(startLocation, validTravelNodes)
    if DevTool then                                    -- MRP_REMOVE_LINE
        DevTool:AddData(startNavNode, "Start NavNode") -- MRP_REMOVE_LINE
    end                                                -- MRP_REMOVE_LINE

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

                local connections = self:FindClosestNavConnections(
                    { mapId = uiMapId, pos = { x = localPos.x, y = localPos.y, z = loc.pos.z }, isUI = true },
                    self.allNodes)
                for _, connection in ipairs(connections) do
                    local navEdge = { to = connection.navNode, cost = connection.cost, flag = 0, locaId = ET.TRAVEL, type = 0 }
                    table.insert(edge.to.tempEdges, navEdge)
                end
            end
        end
    end

    local goalNavNode = self:CreateVirtualNavNode(goalLocation, validTravelNodes)
    if DevTool then                                  -- MRP_REMOVE_LINE
        DevTool:AddData(goalNavNode, "Goal NavNode") -- MRP_REMOVE_LINE
    end                                              -- MRP_REMOVE_LINE

    local startLoc = startNavNode:getLocation()
    local goalLoc = goalNavNode:getLocation()
    if self:HasDirectFlyPath(startLoc, goalLoc) then
        local _, worldA = C_Map.GetWorldPosFromMapPos(startLoc.mapId, CreateVector2D(startLoc.pos.x, startLoc.pos.y))
        local _, worldB = C_Map.GetWorldPosFromMapPos(goalLoc.mapId, CreateVector2D(goalLoc.pos.x, goalLoc.pos.y))
        if worldA and worldB then
            local dist = math.sqrt((worldA.x - worldB.x) ^ 2 + (worldA.y - worldB.y) ^ 2 +
                (startLoc.pos.z - goalLoc.pos.z) ^ 2)
            table.insert(startNavNode.edges,
                { to = goalNavNode, cost = dist * DIRECT_TRAVEL_COST_MULTIPLIER, locaId = ET.TRAVEL })
            table.insert(goalNavNode.edges,
                { to = startNavNode, cost = dist * DIRECT_TRAVEL_COST_MULTIPLIER, locaId = ET.TRAVEL })
        end
    end

    -- Dijkstra setup
    local navCostTable = {} ---@type table<NavKey, number>
    local cameFromTable = {} ---@type table<NavKey, NavNode>
    local cameFromEdgeTable = {} ---@type table<NavKey, NavEdge>
    local visited = {} ---@type table<NavKey, boolean>

    -- Binary min-heap helpers (indexed by priority stored in navCostTable)
    local heap = {} ---@type NavNode[]
    local heapSize = 0
    local heapIndex = {} ---@type table<NavKey, number>

    local function heapSwap(i, j)
        heap[i], heap[j] = heap[j], heap[i]
        heapIndex[heap[i].key] = i
        heapIndex[heap[j].key] = j
    end

    local function heapSiftUp(i)
        while i > 1 do
            local parent = math.floor(i / 2)
            if (navCostTable[heap[i].key] or math.huge) < (navCostTable[heap[parent].key] or math.huge) then
                heapSwap(i, parent)
                i = parent
            else
                break
            end
        end
    end

    local function heapSiftDown(i)
        while true do
            local smallest = i
            local left = 2 * i
            local right = 2 * i + 1
            if left <= heapSize and (navCostTable[heap[left].key] or math.huge) < (navCostTable[heap[smallest].key] or math.huge) then
                smallest = left
            end
            if right <= heapSize and (navCostTable[heap[right].key] or math.huge) < (navCostTable[heap[smallest].key] or math.huge) then
                smallest = right
            end
            if smallest ~= i then
                heapSwap(i, smallest)
                i = smallest
            else
                break
            end
        end
    end

    local function heapPush(node)
        heapSize = heapSize + 1
        heap[heapSize] = node
        heapIndex[node.key] = heapSize
        heapSiftUp(heapSize)
    end

    local function heapPop()
        if heapSize == 0 then return nil end
        local top = heap[1]
        heapIndex[top.key] = nil
        heap[1] = heap[heapSize]
        if heapSize > 1 then
            heapIndex[heap[1].key] = 1
        end
        heap[heapSize] = nil
        heapSize = heapSize - 1
        if heapSize > 0 then
            heapSiftDown(1)
        end
        return top
    end

    local function heapDecreaseKey(node)
        local idx = heapIndex[node.key]
        if idx then
            heapSiftUp(idx)
        end
    end

    if DevTool then                                                -- MRP_REMOVE_LINE
        DevTool:AddData(heap, "Heap")                              -- MRP_REMOVE_LINE
        DevTool:AddData(navCostTable, "Nav Cost Table")            -- MRP_REMOVE_LINE
        DevTool:AddData(cameFromTable, "Came From Table")          -- MRP_REMOVE_LINE
        DevTool:AddData(cameFromEdgeTable, "Came From Edge Table") -- MRP_REMOVE_LINE
    end                                                            -- MRP_REMOVE_LINE

    navCostTable[startNavNode.key] = 0
    heapPush(startNavNode)

    -- Explore graph
    while heapSize > 0 do
        local current = heapPop() ---@type NavNode

        if visited[current.key] then
            -- Skip already-settled nodes
        else
            visited[current.key] = true

            if current.key == goalNavNode.key then
                local currentLoc = current:getLocation()
                FarstriderLib.Logger:InfoGreen("Reached goal node ", currentLoc.mapId, "at position (", currentLoc.pos.x,
                    ",", currentLoc.pos.y, ")")
                break
            end

            for edge in FarstriderLib.NavNode.iterateAllEdges(current) do
                if not edge.condition or edge.condition() then
                    local neighbour = edge.to
                    local edgeCost = edge.cost or math.huge
                    local newCost = (navCostTable[current.key] or math.huge) + edgeCost
                    local oldCost = navCostTable[neighbour.key] or math.huge

                    if newCost < oldCost then
                        navCostTable[neighbour.key] = newCost
                        cameFromTable[neighbour.key] = current
                        cameFromEdgeTable[neighbour.key] = edge
                        if heapIndex[neighbour.key] then
                            heapDecreaseKey(neighbour)
                        else
                            heapPush(neighbour)
                        end
                    end
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
        end
        node = cameFromTable[node.key]
    end

    if #path < 2 then
        FarstriderLib.Logger:Error("Path could not be resolved")
        return {}, {}, {}
    end

    FarstriderLib.Logger:Info(string.format("Path found: %d nodes, %d edges", #path, #edges))

    local virtualGoalKey = goalNavNode.key
    local optimizedPath = {}

    for i = 1, #edges do
        local edge = edges[i]

        local isFinalTravelToGoal = edge.to.key == virtualGoalKey
        local isFlightpath = edge.locaId == ET.FLIGHTPATH
        local isIntermediateTravel = not isFinalTravelToGoal and
            (edge.locaId == ET.TRAVEL or (i + 1 < #edges and isFlightpath and edges[i + 1].locaId == ET.FLIGHTPATH))

        -- Skip intermediate travel edges, but keep the final one to the actual goal
        if not isIntermediateTravel or i == #edges then
            table.insert(optimizedPath, {
                id = edge.to.key,
                loc = (edge.important and not isFlightpath and i > 1) and edges[i - 1].to:getLocation() or
                    edge.to:getLocation(),
                loca = self:GetNodeLoca(edge.locaId, edge.locaArgs),
                actionOptions = edge.actionOptions,
                checkDistance = not (i == #edges or edge.important)
            })
        else
            FarstriderLib.Logger:Info("Skipping intermediate travel-to edge to " .. edge.to.key)
        end
    end

    return optimizedPath, path, edges
end

---@param waypoints Waypoint[]
---@return table<NavKey, NavNode> graph
function Pathfinding:CreateWaypointGraph(waypoints)
    local graph = {} ---@type table<NavKey, NavNode>
    local navEdge ---@type NavEdge

    for _, waypoint in ipairs(waypoints) do
        local valid = not waypoint.condition or waypoint.condition()

        if valid and waypoint.from and waypoint.to then
            local fromNav = self:ConvertWaypointLocationToNavLocation(waypoint.from, graph, "from")
            local toNav = self:ConvertWaypointLocationToNavLocation(waypoint.to, graph, "to")

            if fromNav and toNav then
                graph[fromNav.key] = fromNav
                graph[toNav.key] = toNav

                navEdge = {
                    to = toNav,
                    cost = waypoint.cost,
                    locaId = waypoint.from.locaId,
                    locaArgs = waypoint.from
                        .locaArgs,
                    flag = waypoint.from.flags,
                    type = waypoint.from.type,
                    condition = waypoint.from.condition,
                    actionOptions =
                        waypoint.from.actionOptions,
                    important = waypoint.from.important
                }
                table.insert(fromNav.edges, navEdge)
                if waypoint.bidirectional then
                    navEdge = {
                        to = fromNav,
                        cost = waypoint.cost,
                        locaId = waypoint.to.locaId,
                        locaArgs = waypoint.to
                            .locaArgs,
                        flag = waypoint.to.flags,
                        type = waypoint.to.type,
                        condition = waypoint.to.condition,
                        actionOptions =
                            waypoint.to.actionOptions,
                        important = waypoint.to.important
                    }
                    table.insert(toNav.edges, navEdge)
                end

                FarstriderLib.Logger:Info("Adding waypoint ", fromNav.key, " to ", toNav.key, " for id ", waypoint.id,
                    " with locaId ", waypoint.from.locaId, " from edges ", #fromNav.edges, " to edges ", #toNav.edges)
            end
        end
    end

    return graph
end

--- Render the optimized path as waypoint pins on the world map (debug only).
---@param optimizedPath table[]
---@param path NavNode[]
---@param edges NavEdge[]
function Pathfinding:PrintPath(optimizedPath, path, edges)
    if not path or #path == 0 then
        FarstriderLib.Logger:Error("No path found between the specified locations.")
        return
    end

    if TomTom then                                             -- MRP_REMOVE_LINE
        TomTom.waydb:ResetProfile()                            -- MRP_REMOVE_LINE
        TomTom:ReloadWaypoints()                               -- MRP_REMOVE_LINE
    end                                                        -- MRP_REMOVE_LINE

    if DevTool then                                            -- MRP_REMOVE_LINE
        DevTool:AddData(path, "Path Nodes")                    -- MRP_REMOVE_LINE
        DevTool:AddData(edges, "Path Edges")                   -- MRP_REMOVE_LINE
        DevTool:AddData(optimizedPath, "Optimized Path Edges") -- MRP_REMOVE_LINE
    end                                                        -- MRP_REMOVE_LINE

    local media = FarstriderLib.media_path

    FarstriderLib.ClearWaypoints() -- MRP_REMOVE_LINE

    for i, edge in ipairs(optimizedPath) do
        local loc = edge.loc or edge.checkpoint or edge.enter
        if loc then
            FarstriderLib.Logger:Info("Instruction: " .. edge.loca)

            FarstriderLib.SetWaypoint(loc, media .. "Images\\GoldGreenDot", {
                index = i - 1,
                text = self:GetNodeLoca(edge.locaId, edge.locaArgs),
            })
        else
            FarstriderLib.Logger:Error("No location found for edge " .. i)
        end
    end
end

--- Build the navigation graph from FarstriderData and connect nearby nodes.
function Pathfinding:Initialize()
    local ET = FarstriderLib.EdgeType
    local waypoints = FarstriderData and FarstriderData.Waypoints or {}
    self.allNodes = self:CreateWaypointGraph(waypoints)
    local navEdge ---@type NavEdge

    -- Connect the nav nodes that are directly reachable with each other by creating edges
    for _, navNode in pairs(self.allNodes) do
        if not navNode.isDynamic then
            local loc = navNode:getLocation()
            if not self:IsMapIsolated(loc.mapId) then
                local connections = self:FindClosestNavConnections({ mapId = loc.mapId, pos = loc.pos, isUI = loc.isUI },
                    self.allNodes)
                for _, connection in ipairs(connections) do
                    if connection.navNode.key ~= navNode.key then
                        navEdge = { to = connection.navNode, cost = connection.cost, flag = 0, locaId = ET.TRAVEL, type = 0, important = false }
                        table.insert(navNode.edges, navEdge)
                    end
                end
            end
        end
    end

    FarstriderLib.Logger:Info("Pathfinding initialized with", self:len(self.allNodes), "nodes.")
end

--- Override the travel cost multiplier and rebuild the graph.
---@param newMultiplier number
function Pathfinding:ChangeTravelCostMultiplier(newMultiplier)
    TRAVEL_COST_MULTIPLIER = newMultiplier
    FarstriderLib.Logger:Info("Travel cost multiplier changed to:", newMultiplier)
    self:Initialize()
end
