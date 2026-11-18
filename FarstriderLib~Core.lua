-- FarstriderLib~Core.lua
-- Public navigation API and PLAYER_LOGIN bootstrap.
-- local _, FarstriderLib = ...

if not FarstriderLib.Internal then return end

local _fl = FarstriderLib.Internal

--- Look up a corrected Z elevation from config.
--- Many Shadowlands / Dragonflight maps share a continent but differ in altitude;
--- this table prevents incorrect "direct fly" distance calculations.
---@param mapId number
---@return number
local function GetZ(mapId)
    local overrides = FarstriderLib.Data.CONFIG.ElevationOverrides
    return overrides and overrides[mapId] or 0
end

---@param startMapId MapId
---@param startX number
---@param startY number
---@param startZ number
---@param goalMapId MapId
---@param endX number
---@param endY number
---@param endZ number
---@param leaveInstance? { instanceMapId: number, name: string }
---@return table[] optimizedPath, NavNode[] path, NavEdge[] edges
local function FindTrail(startMapId, startX, startY, startZ, goalMapId, endX, endY, endZ, leaveInstance)
    local startLocation = { mapId = startMapId, pos = { x = startX, y = startY, z = startZ == 0 and GetZ(startMapId) or startZ }, isUI = true } ---@type NavLocation
    local goalLocation = { mapId = goalMapId, pos = { x = endX, y = endY, z = endZ == 0 and GetZ(goalMapId) or endZ }, isUI = true } ---@type NavLocation
    local optimizedPath, path, edges = FarstriderLib.Pathfinding:FindPathBetweenLocations2(startLocation, goalLocation, leaveInstance)

    FarstriderLib.Pathfinding:PrintPath(optimizedPath, path, edges) -- REMOVE_LINE

    return optimizedPath, path, edges
end

--- Find the shortest path between two explicit map positions.
--- Coordinates use UI-map space (0-1 range). Pass z = 0 to auto-resolve
--- elevation from config.ElevationOverrides.
---@param startMapId MapId
---@param startX number
---@param startY number
---@param startZ number
---@param goalMapId MapId
---@param endX number
---@param endY number
---@param endZ number
---@return table[] optimizedPath, NavNode[] path, NavEdge[] edges
function FarstriderLib.FindTrail(startMapId, startX, startY, startZ, goalMapId, endX, endY, endZ)
    return FindTrail(startMapId, startX, startY, startZ, goalMapId, endX, endY, endZ)
end

--- The dungeon or raid the player is in and its entrance, when the data package knows it.
---@return { instanceMapId: number, name: string }? instance
---@return NavLocation? entrance
local function GetInstanceEntrance()
    if not IsInInstance() then return nil end

    local name, _, _, _, _, _, _, instanceMapId = GetInstanceInfo()
    local entrance = instanceMapId and FarstriderLib.Data.GetInstanceEntrance(instanceMapId)
    if not entrance then return nil end

    local uiMapId, pos
    if entrance.uiMapHint then
        uiMapId, pos = C_Map.GetMapPosFromWorldPos(entrance.mapId, CreateVector2D(entrance.pos.x, entrance.pos.y), entrance.uiMapHint)
    end
    local loc = uiMapId and pos and { mapId = uiMapId, pos = { x = pos.x, y = pos.y, z = entrance.pos.z }, isUI = true }
        or FarstriderLib.Pathfinding:GetZoneLocation(entrance)
    if not (loc and loc.isUI) then return nil end
    return { instanceMapId = instanceMapId, name = name }, loc
end

--- House interiors and neighbourhoods are only left by teleport, so their own map is a good enough start.
---@return boolean
local function IsInHousing()
    local instanceType = select(2, GetInstanceInfo())
    return instanceType == "interior" or instanceType == "neighborhood"
end

--- Find the shortest path from the player's current position to a goal.
--- Without a position inside a dungeon or raid, the path starts with a teleport from inside or by leaving through its entrance.
---@param goalMapId MapId
---@param endX number
---@param endY number
---@param endZ number
---@return table[]? optimizedPath, NavNode[]? path, NavEdge[]? edges
function FarstriderLib.FindTrailTo(goalMapId, endX, endY, endZ)
    local playerMapId = C_Map.GetBestMapForUnit("player")
    local playerPosition = playerMapId and C_Map.GetPlayerMapPosition(playerMapId, "player")
    if not playerPosition then
        local instance, entrance = GetInstanceEntrance()
        if entrance then
            return FindTrail(entrance.mapId, entrance.pos.x, entrance.pos.y, entrance.pos.z, goalMapId, endX, endY, endZ, instance)
        end
    end

    if not playerMapId then
        FarstriderLib.Logger:Error("No map found for the player.")
        return
    end

    if not playerPosition then
        if not IsInHousing() then
            local mapInfo = C_Map.GetMapInfo(playerMapId)
            playerMapId = mapInfo and mapInfo.parentMapID or playerMapId
        end
        playerPosition = { x = 0.5, y = 0.5 }
    end

    return FindTrail(playerMapId, playerPosition.x, playerPosition.y, 0, goalMapId, endX, endY, endZ)
end

-- Auto-initialize on PLAYER_LOGIN
local f = _fl.createFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_LEVEL_UP")
f:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LEVEL_UP" then
        -- UnitLevel still returns the old level while this event fires
        _fl.after(1, function()
            if FarstriderLib.Pathfinding:UpdateTravelCostMultiplier() then
                FarstriderLib.Pathfinding:Rebuild()
            end
        end)
        return
    end

    FarstriderLib.Pathfinding:Rebuild()
end)
if IsLoggedIn() then
    _fl.after(0, function() FarstriderLib.Pathfinding:Rebuild() end)
end
