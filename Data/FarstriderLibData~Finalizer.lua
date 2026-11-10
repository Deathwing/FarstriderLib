-- FarstriderLibData~Finalizer.lua
-- local _, FarstriderLibData = ...

if not FarstriderLibData.Internal then return end

FarstriderLibData.Internal = nil

---@type FarstriderLibDataAPI
local lib = FarstriderLibData_API
if lib and lib.Internal then lib.Internal = nil end
lib.WAYPOINTS = FarstriderLibData.Waypoints
lib.CONFIG = FarstriderLibData.Config
lib.GetLocalizedString = function(locaId)
    return FarstriderLibData.WaypointL[locaId] or FarstriderLibData.L["Waypoint_" .. locaId]
end
lib.IsBindLocationSupported = function()
    return FarstriderLibData.AreaL[GetBindLocation()] ~= nil
end
lib.GetHousingData = function()
    return FarstriderLibData.HousingData
end
lib.UpdateHousingExitLocation = function()
    if not FarstriderLibData_CharacterSettings then
        FarstriderLibData_CharacterSettings = {}
    end

    FarstriderLibData_CharacterSettings.housingExitLocation = FarstriderLibData.Util.GetPlayerLocation()
end
lib.GetHelpfulItems = function()
    return FarstriderLibData.Connections.helpfulItems
end

-- legacy support for direct access, will be removed in a future update
_G.FarstriderLibData = FarstriderLibData
