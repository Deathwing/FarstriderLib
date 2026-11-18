-- FarstriderLib~Pathfinding.lua
-- Dijkstra shortest-path engine over the waypoint navigation graph.
-- local _, FarstriderLib = ...

if not FarstriderLib.Internal then return end

--- Navigation edge categories.
---@enum EdgeType
FarstriderLib.EdgeType = {
    TRAVEL     = 1000, -- Direct overland / dragonriding travel
    FLIGHTPATH = 1001, -- Flight master route
    PORTAL     = 1002, -- Portal (mage portal, world portal, housing)
    BOAT       = 1003, -- Boat transport
    ZEPPELIN   = 1004, -- Zeppelin transport
    ITEM       = 1005, -- Consumable item (hearthstone, wormhole, etc.)
    SPELL      = 1006, -- Player spell (teleport, astral recall, etc.)
    LEAVE_INSTANCE = 1007, -- Walk out of the dungeon or raid the player is in
    TRAM       = 1008, -- Deeprun Tram
}

-- Seconds to walk back out of a dungeon or raid to its entrance
local LEAVE_INSTANCE_COST = 60

---@class Pathfinding
---@field allNodes table<NavKey, NavNode>  The full navigation graph
local Pathfinding = {}
FarstriderLib.Pathfinding = Pathfinding

Pathfinding.allNodes = {} ---@type table<NavKey, NavNode>

-- Cached valid travel nodes (invalidated when conditions might change)
Pathfinding._validTravelNodesCache = nil ---@type table<NavKey, NavNode>?
Pathfinding._validTravelNodesCacheTime = 0

--- Invalidate the valid-travel-nodes cache and the map lookup caches.
function Pathfinding:InvalidateCache()
    self._validTravelNodesCache = nil
    self._validTravelNodesCacheTime = 0
    self._continentCache = {}
    self._isolatedMapCache = {}
    self._subZoneCache = {}
    self._worldPosCache = {}
    self._zoneRectCache = {}
end

-- Initialize map lookup caches
Pathfinding._continentCache = {}
Pathfinding._zoneRectCache = {} ---@type table<number, table[]>
Pathfinding._isolatedMapCache = {} ---@type table<number, boolean>
Pathfinding._subZoneCache = {} ---@type table<string, number|false>
Pathfinding._worldPosCache = {} ---@type table<string, table|false>
-- Graph-node positions are kept until the next rebuild, a query's own positions only for that query
Pathfinding._storePositions = false
Pathfinding._queryCache = nil ---@type { worldPos: table<string, table|false>, subZone: table<string, number|false> }?

--- World position of a UI map position; graph-node positions are cached until the next rebuild.
---@param uiMapID number
---@param x number
---@param y number
---@return number? continentID, Vector2DMixin? worldPos
function Pathfinding:GetWorldPosFromMapPos(uiMapID, x, y)
    local key = uiMapID .. ":" .. x .. ":" .. y
    local query = self._queryCache
    local cached = self._worldPosCache[key]
    if cached == nil and query then
        cached = query.worldPos[key]
    end
    if cached == nil then
        local continentID, worldPos = C_Map.GetWorldPosFromMapPos(uiMapID, CreateVector2D(x, y))
        cached = continentID and worldPos and { continentID, worldPos } or false
        if self._storePositions then
            self._worldPosCache[key] = cached
        elseif query then
            query.worldPos[key] = cached
        end
    end
    if cached then
        return cached[1], cached[2]
    end
    return nil, nil
end

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

--- Average overland speed in yards per second (run speed is 7) and whether it is a flying speed.
---@return number speed, boolean isFlying
local function GetTravelSpeed()
    if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then return 55, true end       -- avg dragonriding speed
    if WOW_PROJECT_ID == WOW_PROJECT_MISTS_CLASSIC then return 31, true end -- avg 280% flying speed

    local level = UnitLevel("player") or 1
    local expansion = WOW_PROJECT_ID == WOW_PROJECT_CAMELOT and 0 or GetExpansionLevel()
    if expansion >= 3 then
        if level >= 70 then return 26.6, true end
        if level >= 60 then return 17.5, true end
        return level >= 40 and 14 or level >= 20 and 11.2 or 7, false
    end
    if expansion == 2 then return level >= 40 and 14 or level >= 20 and 11.2 or 7, false end
    if expansion == 1 then return level >= 60 and 14 or level >= 30 and 11.2 or 7, false end
    return level >= 60 and 14 or level >= 40 and 11.2 or 7, false
end

-- Ground routes bend around terrain; Classic flight paths run 1.27-1.39x their straight-line distance (median)
local GROUND_DETOUR_FACTOR = 1.3

local travelCostOverride ---@type number?
local TRAVEL_COST_MULTIPLIER, DIRECT_TRAVEL_COST_MULTIPLIER ---@type number, number
local IS_FLYING ---@type boolean

--- Recompute the travel cost multipliers from the player's travel speed.
---@return boolean changed
function Pathfinding:UpdateTravelCostMultiplier()
    local speed, isFlying = GetTravelSpeed()
    local multiplier = travelCostOverride or (isFlying and 1 / speed or GROUND_DETOUR_FACTOR / speed)
    local direct = isFlying and multiplier * 0.8 or multiplier
    if multiplier == TRAVEL_COST_MULTIPLIER and direct == DIRECT_TRAVEL_COST_MULTIPLIER and isFlying == IS_FLYING then
        return false
    end

    TRAVEL_COST_MULTIPLIER, DIRECT_TRAVEL_COST_MULTIPLIER, IS_FLYING = multiplier, direct, isFlying
    return true
end

Pathfinding:UpdateTravelCostMultiplier()

-- Taxis fly 30 yd/s and Classic mounts at most 14, so riding a known flight's route takes over twice as long
local KNOWN_FLIGHT_GROUND_FACTOR = 2
local NEAR_FLIGHT_MASTER_RANGE = 600 -- yards; covers a city or town around its flight master

Pathfinding._groundFlights = nil ---@type table<NavKey, table<NavKey, number>>?

--- Known direct flights by departure and arrival node, collected only while travelling on the ground.
---@return table<NavKey, table<NavKey, number>>?
function Pathfinding:CollectGroundFlights()
    if IS_FLYING then
        return nil
    end

    local flights
    for key, navNode in pairs(self.allNodes) do
        for _, edge in ipairs(navNode.edges) do
            if edge.locaId == FarstriderLib.EdgeType.FLIGHTPATH and (not edge.condition or edge.condition()) then
                flights = flights or {}
                flights[key] = flights[key] or {}
                flights[key][edge.to.key] = math.min(flights[key][edge.to.key] or math.huge, edge.cost or math.huge)
            end
        end
    end
    return flights
end

--- The flight master within range of a location, from its connections sorted by cost.
---@param connections { navNode: NavNode, cost: number }[]
---@return NavKey?
function Pathfinding:GetNearFlightMaster(connections)
    local flights = self._groundFlights
    if not flights then
        return nil
    end

    for _, connection in ipairs(connections) do
        if connection.cost > NEAR_FLIGHT_MASTER_RANGE * TRAVEL_COST_MULTIPLIER then
            return nil
        end
        if flights[connection.navNode.key] then
            return connection.navNode.key
        end
    end
    return nil
end

--- Ground travel between two flight masters' surroundings costs at least riding their known flight's route.
---@param fromFlightMaster NavKey?
---@param toFlightMaster NavKey?
---@param cost number
---@return number
function Pathfinding:GetGroundTravelCost(fromFlightMaster, toFlightMaster, cost)
    local flights = fromFlightMaster and toFlightMaster and self._groundFlights and self._groundFlights[fromFlightMaster]
    local flightCost = flights and flights[toFlightMaster]
    if flightCost then
        return math.max(cost, flightCost * KNOWN_FLIGHT_GROUND_FACTOR)
    end
    return cost
end

local WIZARDS_SANCTUM_AREA_ID = 10523
local WIZARDS_SANCTUM_NAME

local function GetWizardsSanctumName()
    if WIZARDS_SANCTUM_NAME == nil then
        WIZARDS_SANCTUM_NAME = C_Map.GetAreaInfo(WIZARDS_SANCTUM_AREA_ID) or false
    end
    return WIZARDS_SANCTUM_NAME
end

---@param loc Location|NavLocation
---@return number? comparableZ
local function getComparableZ(loc)
    if not loc or not loc.pos then
        return nil
    end

    if loc.pos.z ~= 0 then
        return loc.pos.z
    end

    local overrideZ = FarstriderLib.Data.CONFIG.ElevationOverrides[loc.mapId]
    if overrideZ then
        return overrideZ
    end

    if loc.isUI then
        return nil
    end

    return loc.pos.z
end

--- Count entries in a hash table.
---@param t table
---@return number
function Pathfinding:len(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

---@param mapID number
---@return boolean
function Pathfinding:IsMapIsolated(mapID)
    local cached = self._isolatedMapCache[mapID]
    if cached ~= nil then
        return cached
    end

    local mapInfo = C_Map.GetMapInfo(mapID)
    if not mapInfo then
        FarstriderLib.Logger:Error("Map information not available for ID:", mapID)
        return false
    end

    local mapTypeOverride = FarstriderLib.Data.CONFIG.MapTypeOverrides[mapID]
    if mapTypeOverride then
        mapInfo.mapType = mapTypeOverride.mapType
    end

    local isolated = mapInfo.mapType == Enum.UIMapType.Dungeon or mapInfo.parentMapID == 0
    self._isolatedMapCache[mapID] = isolated
    return isolated
end

--- Compute world distance between two nav locations.
--- Uses the Z component only when both elevations are trustworthy.
--- Returns `math.huge` if they are on disconnected continents.
---@param navLocationA Location|NavLocation
---@param navLocationB Location|NavLocation
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
        local _, posA = self:GetWorldPosFromMapPos(navLocationA.mapId, navLocationA.pos.x, navLocationA.pos.y)
        local _, posB = self:GetWorldPosFromMapPos(navLocationB.mapId, navLocationB.pos.x, navLocationB.pos.y)

        if posA and posB then
            local comparableZA = getComparableZ(navLocationA)
            local comparableZB = getComparableZ(navLocationB)
            local deltaZ = (comparableZA and comparableZB) and (comparableZA - comparableZB) or 0
            return math.sqrt((posA.x - posB.x) ^ 2 + (posA.y - posB.y) ^ 2 + deltaZ ^ 2)
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
    local key = parentMapID .. ":" .. pos.x .. ":" .. pos.y
    local query = self._queryCache
    local cached = self._subZoneCache[key]
    if cached == nil and query then
        cached = query.subZone[key]
    end
    if cached ~= nil then
        return cached or nil
    end

    local mapInfo = C_Map.GetMapInfoAtPosition(parentMapID, pos.x, pos.y)
    if not mapInfo then
        -- Nested city/instance maps can fail position lookup; climb their ancestry instead.
        mapInfo = C_Map.GetMapInfo(parentMapID)
    end

    local parentMapInfo = mapInfo and mapInfo.parentMapID and C_Map.GetMapInfo(mapInfo.parentMapID)
    while parentMapInfo and parentMapInfo.mapType > Enum.UIMapType.Continent do
        mapInfo = parentMapInfo
        parentMapInfo = mapInfo.parentMapID and C_Map.GetMapInfo(mapInfo.parentMapID)
    end
    local subZone = mapInfo and mapInfo.mapID or nil
    if self._storePositions then
        self._subZoneCache[key] = subZone or false
    elseif query then
        query.subZone[key] = subZone or false
    end
    return subZone
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

    if mapInfo then
        local continentMapOverride = FarstriderLib.Data.CONFIG.ContinentMapOverrides[mapInfo.mapID]
        if continentMapOverride then
            mapInfo = C_Map.GetMapInfo(continentMapOverride)
        end
    end

    self._continentCache[uiMapID] = mapInfo or false
    return mapInfo
end

---@param loc Location|NavLocation
---@return number? groupId
local function GetIsolatedRegion(loc)
    local regions = FarstriderLib.Data.CONFIG.IsolatedRegions
    if not regions or #regions == 0 then
        return nil
    end

    local continentID, worldPos = loc.mapId, loc.pos
    if loc.isUI then
        continentID, worldPos = Pathfinding:GetWorldPosFromMapPos(loc.mapId, loc.pos.x, loc.pos.y)
    end
    if not continentID or not worldPos then
        return nil
    end

    for _, region in ipairs(regions) do
        if region.mapId == continentID and not (region.flyable and IS_FLYING) and (worldPos.x - region.x) ^ 2 + (worldPos.y - region.y) ^ 2 <= region.radius ^ 2 then
            return region.group
        end
    end
    return nil
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
        local region1, region2 = GetIsolatedRegion(loc1), GetIsolatedRegion(loc2)
        if region1 or region2 then
            return region1 == region2
        end

        local isolatedContinents = FarstriderLib.Data.CONFIG.IsolatedContinents
        if isolatedContinents[continentInfoMap1.mapID] then
            local subzone1 = self:GetMostTopLevelSubZoneAtPosition(uiMapID1, loc1.pos) or uiMapID1
            local subzone2 = self:GetMostTopLevelSubZoneAtPosition(uiMapID2, loc2.pos) or uiMapID2
            return subzone1 == subzone2
        end

        local subzone1 = self:GetMostTopLevelSubZoneAtPosition(uiMapID1, loc1.pos) or uiMapID1
        local subzone2 = self:GetMostTopLevelSubZoneAtPosition(uiMapID2, loc2.pos) or uiMapID2
        local isolatedAreas = FarstriderLib.Data.CONFIG.IsolatedAreas
        return isolatedAreas[subzone1] == isolatedAreas[subzone2]
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

--- Re-project a continent-level UI location or a world location onto the zone map at that position.
---@param loc Location?
---@return Location?
function Pathfinding:GetZoneLocation(loc)
    if not loc or not loc.pos then
        return loc
    end

    local continentID, worldPos, uiMapId, uiPos
    if loc.isUI then
        local mapInfo = C_Map.GetMapInfo(loc.mapId)
        if not mapInfo or mapInfo.mapType ~= Enum.UIMapType.Continent then
            return loc
        end
        uiMapId, uiPos = loc.mapId, loc.pos
        continentID, worldPos = C_Map.GetWorldPosFromMapPos(uiMapId, CreateVector2D(uiPos.x, uiPos.y))
    else
        continentID, worldPos = loc.mapId, CreateVector2D(loc.pos.x, loc.pos.y)
        uiMapId, uiPos = C_Map.GetMapPosFromWorldPos(continentID, worldPos)
    end
    if not continentID or not worldPos or not uiMapId or not uiPos then
        return loc
    end

    local zoneMapId = self:GetMostTopLevelSubZoneAtPosition(uiMapId, uiPos)
    local zoneInfo = zoneMapId and zoneMapId ~= uiMapId and C_Map.GetMapInfo(zoneMapId)
    if zoneInfo and zoneInfo.mapType == Enum.UIMapType.Zone then
        local zoneId, zonePos = C_Map.GetMapPosFromWorldPos(continentID, worldPos, zoneMapId)
        if zoneId and zonePos and zonePos.x >= 0 and zonePos.x <= 1 and zonePos.y >= 0 and zonePos.y <= 1 then
            return { mapId = zoneId, pos = { x = zonePos.x, y = zonePos.y, z = loc.pos.z }, isUI = true }
        end
    end

    if loc.isUI then
        return loc
    end
    return { mapId = uiMapId, pos = { x = uiPos.x, y = uiPos.y, z = loc.pos.z }, isUI = true }
end

--- Zone or city map of a UI map, climbing from dungeon, micro and orphan maps; a dungeon map under a continent is a city (Dalaran).
---@param uiMapId number?
---@return number? zoneMapId, number? continentMapId
function Pathfinding:GetZoneMapId(uiMapId)
    local info = uiMapId and C_Map.GetMapInfo(uiMapId)
    local parent = info and info.parentMapID and info.parentMapID ~= 0 and C_Map.GetMapInfo(info.parentMapID)
    while info and info.mapType > Enum.UIMapType.Zone and parent and parent.mapType >= Enum.UIMapType.Zone do
        info = parent
        parent = info.parentMapID and info.parentMapID ~= 0 and C_Map.GetMapInfo(info.parentMapID)
    end
    if not info or (info.mapType ~= Enum.UIMapType.Zone and info.mapType ~= Enum.UIMapType.Dungeon) then
        return nil
    end
    while parent and parent.mapType > Enum.UIMapType.Continent do
        parent = parent.parentMapID and parent.parentMapID ~= 0 and C_Map.GetMapInfo(parent.parentMapID)
    end
    return info.mapID, parent and parent.mapType == Enum.UIMapType.Continent and parent.mapID or nil
end

--- World rectangles of the zone and city maps on a continent, smallest first.
---@param continentMapId number
---@return { mapId: number, instance: number, minX: number, maxX: number, minY: number, maxY: number, area: number }[]
function Pathfinding:GetZoneRects(continentMapId)
    local rects = self._zoneRectCache[continentMapId]
    if rects then
        return rects
    end

    rects = {}
    local seen = {}
    for _, child in ipairs(C_Map.GetMapChildrenInfo and C_Map.GetMapChildrenInfo(continentMapId, nil, true) or {}) do
        local zoneMapId = self:GetZoneMapId(child.mapID)
        if zoneMapId and not seen[zoneMapId] then
            seen[zoneMapId] = true
            -- The far corner mirrors the origin through the centre, as in HereBeDragons
            local instance, origin = C_Map.GetWorldPosFromMapPos(zoneMapId, CreateVector2D(0, 0))
            local _, centre = C_Map.GetWorldPosFromMapPos(zoneMapId, CreateVector2D(0.5, 0.5))
            if instance and origin and centre then
                local farX, farY = 2 * centre.x - origin.x, 2 * centre.y - origin.y
                table.insert(rects, {
                    mapId = zoneMapId,
                    instance = instance,
                    minX = math.min(origin.x, farX),
                    maxX = math.max(origin.x, farX),
                    minY = math.min(origin.y, farY),
                    maxY = math.max(origin.y, farY),
                    area = math.abs((farX - origin.x) * (farY - origin.y)),
                })
            end
        end
    end
    table.sort(rects, function(a, b)
        if a.area ~= b.area then return a.area < b.area end
        return a.mapId < b.mapId
    end)
    self._zoneRectCache[continentMapId] = rects
    return rects
end

--- Zone or city map at a world position by the client's map hit test, descending into zone maps nested in a zone (Boralus).
---@param instance number
---@param worldPos Vec3|Vector2DMixin
---@param continentMapId number
---@return number? zoneMapId
function Pathfinding:GetZoneMapAtPosition(instance, worldPos, continentMapId)
    local world = CreateVector2D(worldPos.x, worldPos.y)
    local hitMapId
    local mapId, pos = C_Map.GetMapPosFromWorldPos(instance, world, continentMapId)
    for _ = 1, 4 do
        local child = mapId and pos and C_Map.GetMapInfoAtPosition(mapId, pos.x, pos.y)
        if not child or child.mapID == mapId then
            break
        end
        local childId, childPos = C_Map.GetMapPosFromWorldPos(instance, world, child.mapID)
        if not childPos or childPos.x < 0 or childPos.x > 1 or childPos.y < 0 or childPos.y > 1 then
            break
        end
        hitMapId = child.mapID
        if child.mapType ~= Enum.UIMapType.Zone then
            break
        end
        mapId, pos = childId, childPos
    end
    return hitMapId and self:GetZoneMapId(hitMapId) or nil
end

--- Whether a location lies in the given zone or city map; map rectangles overlap, so the client's hit test must agree.
---@param loc Location
---@param zoneMapId number
---@param continentMapId number
---@return boolean
function Pathfinding:IsInZoneMap(loc, zoneMapId, continentMapId)
    local instance, worldPos
    if loc.isUI then
        instance, worldPos = self:GetWorldPosFromMapPos(loc.mapId, loc.pos.x, loc.pos.y)
    else
        instance, worldPos = loc.mapId, loc.pos
    end
    if not instance or not worldPos then
        return false
    end

    for _, rect in ipairs(self:GetZoneRects(continentMapId)) do
        if rect.instance == instance and worldPos.x >= rect.minX and worldPos.x <= rect.maxX and worldPos.y >= rect.minY and worldPos.y <= rect.maxY then
            return rect.mapId == zoneMapId and self:GetZoneMapAtPosition(instance, worldPos, continentMapId) == zoneMapId
        end
    end
    return false
end

--- Resolve a world location to the UI map position that graph nodes are built on.
---@param loc Location
---@param uiMapHint? number
---@return number? uiMapId, Vector2DMixin|Vec3? pos
function Pathfinding:GetNavMapPosFromWorldPos(loc, uiMapHint)
    if uiMapHint or WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
        return C_Map.GetMapPosFromWorldPos(loc.mapId, CreateVector2D(loc.pos.x, loc.pos.y), uiMapHint)
    end

    -- Without a hint the client answers on the continent map, where Classic zone rectangles overlap
    local zoneLoc = self:GetZoneLocation(loc)
    if zoneLoc and zoneLoc.isUI then
        return zoneLoc.mapId, zoneLoc.pos
    end
    return nil, nil
end

--- Convert a WaypointLocation (world or UI coords) into a NavNode,
--- reusing an existing node from the graph when the key matches.
---@param waypointLocation WaypointLocation
---@param graph table<NavKey, NavNode>
---@param suffix string  Key suffix for dynamic nodes ("from" / "to:<index>")
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

    local uiMapId, localPos = self:GetNavMapPosFromWorldPos(waypointLocation.loc, waypointLocation.uiMapHint)

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
---@param isWizardsSanctum? boolean  Source is inside the Wizard's Sanctum
---@return { navNode: NavNode, cost: number }[] connections
function Pathfinding:FindClosestNavConnections(location, nodes, isWizardsSanctum)
    local connections = {}
    FarstriderLib.Logger:Info(string.format("Finding closest nav connections from map %d at position (%.2f, %.2f, %.2f)",
        location.mapId, location.pos.x, location.pos.y, location.pos.z))

    for _, navNode in pairs(nodes) do
        if not navNode.isDynamic and not navNode.noAutoconnect then
            -- Wizard's Sanctum isolation: WS nodes connect only to other WS
            -- nodes and vice-versa.  Mismatched pairs are skipped.
            if (isWizardsSanctum or false) ~= (navNode.wizardsSanctum or false) then
                -- skip
            elseif self:HasDirectFlyPath(location, navNode:getLocation()) then
                local navNodeLoc = navNode:getLocation()
                local dist = self:GetWorldDistanceBetween(location, navNodeLoc)
                if dist and dist ~= math.huge then
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

    local loca = FarstriderLib.Data.GetLocalizedString(locaId)
    if not loca then
        return "Unknown Location (locaId " .. locaId .. ")"
    end

    return loca
end

--- Create a virtual NavNode at the specified location with edges to the closest NavNodes
---@param location NavLocation
---@param nodes table<NavKey, NavNode>
---@param isWizardsSanctum? boolean  True when the location is inside the Wizard's Sanctum
---@return NavNode
function Pathfinding:CreateVirtualNavNode(location, nodes, isWizardsSanctum)
    local ET = FarstriderLib.EdgeType
    local virtualNode = FarstriderLib.NavNode.create(location.mapId, location.pos, true, {})
    -- A graph node on the same spot must keep its own key, or its transport edges are never expanded
    virtualNode.key = "virtual:" .. virtualNode.key
    local connections = self:FindClosestNavConnections(location, nodes, isWizardsSanctum)
    virtualNode.nearFlightMaster = self:GetNearFlightMaster(connections)
    local navEdge ---@type NavEdge
    for _, connection in ipairs(connections) do
        local other = connection.navNode.nearFlightMaster
        navEdge = { from = virtualNode, to = connection.navNode, cost = self:GetGroundTravelCost(virtualNode.nearFlightMaster, other, connection.cost), flag = 0, locaId = ET.TRAVEL, type = 0, important = false }
        table.insert(virtualNode.edges, navEdge)
        navEdge = { from = connection.navNode, to = virtualNode, cost = self:GetGroundTravelCost(other, virtualNode.nearFlightMaster, connection.cost), flag = 0, locaId = ET.TRAVEL, type = 0, important = false }
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

--- Hearthstones, teleport items and teleport spells also work inside a dungeon or raid.
---@param edge NavEdge
---@return boolean
local function IsItemOrSpellTeleport(edge)
    local option = edge.actionOptions and edge.actionOptions[1]
    return option ~= nil and (option.type == "item" or option.type == "spell")
end

--- Find the shortest path and return both the nodes and the edges to traverse
---@param startLocation NavLocation
---@param goalLocation NavLocation
---@param leaveInstance? { instanceMapId: number, name: string } the player is inside this instance and startLocation is its entrance
---@return table[] optimizedPath, NavNode[] path, NavEdge[] edges
function Pathfinding:FindPathBetweenLocations2(startLocation, goalLocation, leaveInstance)
    self:CleanupTempEdges()
    self._queryCache = { worldPos = {}, subZone = {} }

    local ET = FarstriderLib.EdgeType

    FarstriderLib.Logger:Info("=== Starting pathfinding ===")
    FarstriderLib.Logger:Info(string.format("Start: map %d (%.2f, %.2f, %.2f)", startLocation.mapId, startLocation.pos.x,
        startLocation.pos.y, startLocation.pos.z))
    FarstriderLib.Logger:Info(string.format("Goal : map %d (%.2f, %.2f, %.2f)", goalLocation.mapId, goalLocation.pos.x,
        goalLocation.pos.y, goalLocation.pos.z))

    ---@type table<NavKey, NavNode>
    local validTravelNodes = self:GetValidTravelNodes()

    -- Check if the player is inside the Wizard's Sanctum (area 10523).
    -- Virtual start nodes in the sanctum may only auto-connect to other
    -- sanctum-interior nodes, mirroring the graph-time isolation.
    local playerInWizardsSanctum = GetSubZoneText() == GetWizardsSanctumName()

    -- Create virtual NavNodes for start and goal locations
    local startNavNode = self:CreateVirtualNavNode(startLocation, validTravelNodes, playerInWizardsSanctum)
    if DevTool then                                       -- REMOVE_LINE
        DevTool:AddData(startNavNode, "Start NavNode")    -- REMOVE_LINE
        local nodesByLocaId = {}                          -- REMOVE_LINE
        for _, navNode in pairs(self.allNodes) do         -- REMOVE_LINE
            for _, edge in ipairs(navNode.edges) do       -- REMOVE_LINE
                if edge.locaId and edge.locaId > 0 then   -- REMOVE_LINE
                    nodesByLocaId[edge.locaId] = navNode  -- REMOVE_LINE
                    break                                 -- REMOVE_LINE
                end                                       -- REMOVE_LINE
            end                                           -- REMOVE_LINE
        end                                               -- REMOVE_LINE
        DevTool:AddData(nodesByLocaId, "Nodes By LocaId") -- REMOVE_LINE
    end                                                   -- REMOVE_LINE

    local goalNavNode = self:CreateVirtualNavNode(goalLocation, validTravelNodes)
    if DevTool then                                  -- REMOVE_LINE
        DevTool:AddData(goalNavNode, "Goal NavNode") -- REMOVE_LINE
    end                                              -- REMOVE_LINE
    local goalLoc = goalNavNode:getLocation()

    local originNode = startNavNode
    if leaveInstance then
        originNode = FarstriderLib.NavNode.create(startLocation.mapId, startLocation.pos, true, {})
        originNode.key = "instance:" .. leaveInstance.instanceMapId
        table.insert(originNode.edges, {
            from = originNode,
            to = startNavNode,
            cost = LEAVE_INSTANCE_COST,
            flag = 0,
            locaId = ET.LEAVE_INSTANCE,
            locaArgs = function() return { leaveInstance.name } end,
            actionOptions = { { type = "leave_instance", data = leaveInstance.instanceMapId } },
            type = 0,
            important = false,
        })
    end

    local dynamicFromNode = self.allNodes["dynamic:from"]
    if dynamicFromNode then
        local linked = {} ---@type table<NavKey, boolean>
        -- Inside an instance startLocation is its entrance, so this is the entrance's zone
        local startZoneMapId, startContinentMapId = self:GetZoneMapId(startLocation.mapId)
        for _, edge in ipairs(dynamicFromNode.edges) do
            local dynamicNode = edge.to
            local usable = not edge.condition or edge.condition()
            -- Teleports into the zone or city you are in are never offered
            if usable and startContinentMapId then
                local arrival = dynamicNode:getLocation()
                usable = not (arrival and arrival.pos and self:IsInZoneMap(arrival, startZoneMapId, startContinentMapId))
            end
            if usable then
                table.insert(startNavNode.tempEdges, edge)
                if originNode ~= startNavNode and IsItemOrSpellTeleport(edge) then
                    table.insert(originNode.edges, edge)
                end
            end
            if usable and dynamicNode.isDynamic and not linked[dynamicNode.key] then
                linked[dynamicNode.key] = true
                local loc = dynamicNode:getLocation()

                local uiMapId, localPos
                if loc and loc.isUI then
                    uiMapId = loc.mapId
                    localPos = CreateVector2D(loc.pos.x, loc.pos.y)
                elseif loc then
                    uiMapId, localPos = self:GetNavMapPosFromWorldPos(loc)
                end

                if uiMapId and localPos then
                    local arrivalLoc = { mapId = uiMapId, pos = { x = localPos.x, y = localPos.y, z = loc.pos.z }, isUI = true }
                    local connections = self:FindClosestNavConnections(arrivalLoc, self.allNodes)
                    dynamicNode.nearFlightMaster = self:GetNearFlightMaster(connections)
                    for _, connection in ipairs(connections) do
                        local cost = self:GetGroundTravelCost(dynamicNode.nearFlightMaster, connection.navNode.nearFlightMaster, connection.cost)
                        local navEdge = { from = dynamicNode, to = connection.navNode, cost = cost, flag = 0, locaId = ET.TRAVEL, type = 0 }
                        table.insert(dynamicNode.tempEdges, navEdge)
                    end

                    -- Like the start node, an arrival near the goal travels there directly instead of via a graph node
                    if self:HasDirectFlyPath(arrivalLoc, goalLoc) then
                        local dist = self:GetWorldDistanceBetween(arrivalLoc, goalLoc)
                        if dist and dist ~= math.huge then
                            local cost = self:GetGroundTravelCost(dynamicNode.nearFlightMaster, goalNavNode.nearFlightMaster, dist * DIRECT_TRAVEL_COST_MULTIPLIER)
                            table.insert(dynamicNode.tempEdges, { from = dynamicNode, to = goalNavNode, cost = cost, flag = 0, locaId = ET.TRAVEL, type = 0 })
                        end
                    end
                end
            end
        end
    end

    local startLoc = startNavNode:getLocation()
    if not playerInWizardsSanctum and self:HasDirectFlyPath(startLoc, goalLoc) then
        local dist = self:GetWorldDistanceBetween(startLoc, goalLoc)
        if dist and dist ~= math.huge then
            local cost = dist * DIRECT_TRAVEL_COST_MULTIPLIER
            table.insert(startNavNode.edges,
                { from = startNavNode, to = goalNavNode, cost = self:GetGroundTravelCost(startNavNode.nearFlightMaster, goalNavNode.nearFlightMaster, cost), locaId = ET.TRAVEL })
            table.insert(goalNavNode.edges,
                { from = goalNavNode, to = startNavNode, cost = self:GetGroundTravelCost(goalNavNode.nearFlightMaster, startNavNode.nearFlightMaster, cost), locaId = ET.TRAVEL })
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

    if DevTool then                                                -- REMOVE_LINE
        DevTool:AddData(heap, "Heap")                              -- REMOVE_LINE
        DevTool:AddData(navCostTable, "Nav Cost Table")            -- REMOVE_LINE
        DevTool:AddData(cameFromTable, "Came From Table")          -- REMOVE_LINE
        DevTool:AddData(cameFromEdgeTable, "Came From Edge Table") -- REMOVE_LINE
    end                                                            -- REMOVE_LINE

    navCostTable[originNode.key] = 0
    heapPush(originNode)

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
        self._queryCache = nil
        return {}, {}, {}
    end

    FarstriderLib.Logger:Info(string.format("Path found: %d nodes, %d edges", #path, #edges))

    local virtualGoalKey = goalNavNode.key
    local optimizedPath = {}

    local function isFlightpathEdge(edge)
        return edge.locaId == ET.FLIGHTPATH
    end

    local function shouldSkipOptimizedEdge(index)
        local edge = edges[index]
        if index == #edges or edge.to.key == virtualGoalKey then
            return false
        end

        if edge.skipOptimized then
            return true
        end

        if edge.locaId == ET.TRAVEL then
            return true
        end

        -- Chained taxi hops are still a single player action: pick the final
        -- destination once and let the route transfer automatically.
        return isFlightpathEdge(edge) and index + 1 < #edges and isFlightpathEdge(edges[index + 1])
    end

    local function getOptimizedStepLocation(index)
        -- A chained taxi step starts at the first flight master of the chain
        while isFlightpathEdge(edges[index]) and index > 1 and isFlightpathEdge(edges[index - 1]) and shouldSkipOptimizedEdge(index - 1) do
            index = index - 1
        end

        local edge = edges[index]
        if edge.important and edge.from then
            return self:GetZoneLocation(edge.from:getLocation())
        end

        return self:GetZoneLocation(edge.to:getLocation())
    end

    local function getOptimizedStepCompletionLocation(index)
        return self:GetZoneLocation(edges[index].to:getLocation())
    end

    for i = 1, #edges do
        local edge = edges[i]

        if not shouldSkipOptimizedEdge(i) then
            table.insert(optimizedPath, {
                id = edge.to.key,
                loc = getOptimizedStepLocation(i),
                completionLoc = getOptimizedStepCompletionLocation(i),
                loca = self:GetNodeLoca(edge.locaId, edge.locaArgs),
                actionOptions = edge.actionOptions,
                checkDistance = i ~= #edges
            })
        else
            FarstriderLib.Logger:Info("Skipping intermediate travel-to edge to " .. edge.to.key)
        end
    end

    self._queryCache = nil
    return optimizedPath, path, edges
end

---@param waypoints Waypoint[]
---@return table<NavKey, NavNode> graph
function Pathfinding:CreateWaypointGraph(waypoints)
    local graph = {} ---@type table<NavKey, NavNode>
    local navEdge ---@type NavEdge

    for index, waypoint in ipairs(waypoints) do
        local valid = not waypoint.condition or waypoint.condition()

        if valid and waypoint.from and waypoint.to then
            local fromNav = self:ConvertWaypointLocationToNavLocation(waypoint.from, graph, "from")
            -- Each dynamic arrival resolves its own location (bind point, housing exit)
            local toNav = self:ConvertWaypointLocationToNavLocation(waypoint.to, graph, "to:" .. index)

            if fromNav and toNav then
                graph[fromNav.key] = fromNav
                graph[toNav.key] = toNav

                -- Tag nodes that should not receive auto-generated TRAVEL edges.
                -- Only use Blizzard's explicit NoAutoconnect flag (bit 2).
                -- Do NOT include portal exits (type 2) here — they need TRAVEL
                -- edges so the player can continue after arriving via portal.
                if bit.band(waypoint.from.flags, 2) > 0 then
                    fromNav.noAutoconnect = true
                end
                if bit.band(waypoint.to.flags, 2) > 0 then
                    toNav.noAutoconnect = true
                end

                -- Wizard's Sanctum interior nodes carry flag 0x40.  They form
                -- an isolated sub-graph that only auto-connects internally.
                if bit.band(waypoint.from.flags, 64) > 0 then
                    fromNav.wizardsSanctum = true
                end
                if bit.band(waypoint.to.flags, 64) > 0 then
                    toNav.wizardsSanctum = true
                end

                navEdge = {
                    from = fromNav,
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
                    important = waypoint.from.important,
                    skipOptimized = waypoint.skipOptimized
                }
                table.insert(fromNav.edges, navEdge)
                if waypoint.bidirectional then
                    navEdge = {
                        from = toNav,
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
                        important = waypoint.to.important,
                        skipOptimized = waypoint.skipOptimized
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

    if TomTom then                                             -- REMOVE_LINE
        TomTom.waydb:ResetProfile()                            -- REMOVE_LINE
        TomTom:ReloadWaypoints()                               -- REMOVE_LINE
    end                                                        -- REMOVE_LINE

    if DevTool then                                            -- REMOVE_LINE
        DevTool:AddData(path, "Path Nodes")                    -- REMOVE_LINE
        DevTool:AddData(edges, "Path Edges")                   -- REMOVE_LINE
        DevTool:AddData(optimizedPath, "Optimized Path Edges") -- REMOVE_LINE
    end                                                        -- REMOVE_LINE

    local media = FarstriderLib.media_path

    FarstriderLib.ClearFlares() -- REMOVE_LINE

    for i, edge in ipairs(optimizedPath) do
        local loc = edge.loc or edge.checkpoint or edge.enter
        if loc then
            FarstriderLib.Logger:Info("Instruction: " .. edge.loca)

            FarstriderLib.PlaceFlare(loc, media .. "Media\\GoldGreenDot", {
                index = i - 1,
                text = self:GetNodeLoca(edge.locaId, edge.locaArgs),
            })
        else
            FarstriderLib.Logger:Error("No location found for edge " .. i)
        end
    end
end

--- Build the navigation graph from data and connect nearby nodes.
function Pathfinding:Initialize()
    local ET = FarstriderLib.EdgeType
    self:UpdateTravelCostMultiplier()
    self._storePositions = true
    self.allNodes = self:CreateWaypointGraph(FarstriderLib.Data.WAYPOINTS)
    self._groundFlights = self:CollectGroundFlights()

    local function addTravelEdges(navNode, connections)
        for _, connection in ipairs(connections) do
            if connection.navNode.key ~= navNode.key and not connection.navNode.noAutoconnect then
                local cost = self:GetGroundTravelCost(navNode.nearFlightMaster, connection.navNode.nearFlightMaster, connection.cost)
                table.insert(navNode.edges, { from = navNode, to = connection.navNode, cost = cost, flag = 0, locaId = ET.TRAVEL, type = 0, important = false })
            end
        end
    end

    -- Connect the nav nodes that are directly reachable with each other by creating edges
    local deferred = {} ---@type table<NavKey, { navNode: NavNode, cost: number }[]>
    for key, navNode in pairs(self.allNodes) do
        if not navNode.isDynamic and not navNode.noAutoconnect then
            local loc = navNode:getLocation()
            if not self:IsMapIsolated(loc.mapId) then
                local connections = self:FindClosestNavConnections({ mapId = loc.mapId, pos = loc.pos, isUI = loc.isUI },
                    self.allNodes, navNode.wizardsSanctum)
                if self._groundFlights then
                    -- Pricing an edge needs the nearby flight masters of both ends
                    navNode.nearFlightMaster = self:GetNearFlightMaster(connections)
                    deferred[key] = connections
                else
                    addTravelEdges(navNode, connections)
                end
            end
        end
    end
    for key, connections in pairs(deferred) do
        addTravelEdges(self.allNodes[key], connections)
    end

    self._storePositions = false
    FarstriderLib.Logger:Info("Pathfinding initialized with", self:len(self.allNodes), "nodes.")
end

--- Clear the pathfinding cache and re-initialize. Call this after updating any data.
function Pathfinding:Rebuild()
    self:InvalidateCache()
    self:Initialize()

    for _, callback in ipairs(FarstriderLib_API.State.rebuildCallbacks or {}) do
        xpcall(callback, geterrorhandler())
    end
end

--- Override the travel cost multiplier and rebuild the graph.
---@param newMultiplier number? nil restores the speed-based multiplier
function Pathfinding:ChangeTravelCostMultiplier(newMultiplier)
    travelCostOverride = newMultiplier
    FarstriderLib.Logger:Info("Travel cost multiplier changed to:", newMultiplier)
    self:Rebuild()
end
