-- FarstriderLib: checks for Preflight (/preflight FarstriderLib), when it's loaded.
-- The client map and timer APIs the pathfinder uses.
-- local _, FarstriderLib = ...

local P = rawget(_G, "Preflight")
if type(P) ~= "table" or type(P.Register) ~= "function" then return end

P:DeclareAPI("FarstriderLib", {
    "CreateFrame", "CreateVector2D", "GetTime", "GetSubZoneText", "IsLoggedIn",
    "hooksecurefunc", "C_Timer.After", "C_Timer.NewTicker", "C_Timer.NewTimer",
    "C_Map.GetBestMapForUnit", "C_Map.GetPlayerMapPosition", "C_Map.GetMapInfo",
    "C_Map.GetMapInfoAtPosition", "C_Map.GetWorldPosFromMapPos", "C_Map.GetMapPosFromWorldPos",
    "C_Map.GetAreaInfo", "Enum.UIMapType.Continent", "Enum.UIMapType.Dungeon", "Enum.UIMapType.Zone",
    "EJ_GetInstanceForMap?", "C_EncounterJournal.GetDungeonEntrancesForMap?",
})

-- FindTrailTo needs the player's map and a position on it.
P:Register("FarstriderLib", "Player map position", function()
    if type(C_Map) ~= "table" or type(C_Map.GetBestMapForUnit) ~= "function" then
        return false, "C_Map.GetBestMapForUnit missing"
    end
    local mapID = C_Map.GetBestMapForUnit("player")
    if type(mapID) ~= "number" then return false, "no map for player: " .. tostring(mapID) end
    if type(C_Map.GetPlayerMapPosition) ~= "function" then
        return false, "C_Map.GetPlayerMapPosition missing"
    end
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return false, "no player position on map " .. mapID end
    local x, y = pos.GetXY and pos:GetXY() or pos.x, pos.y
    if type(x) ~= "number" or type(y) ~= "number" then
        return false, "position not numeric on map " .. mapID
    end
    return true, ("map %d at %.2f, %.2f"):format(mapID, x, y)
end)
