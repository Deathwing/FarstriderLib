-- FarstriderLib~Finalizer.lua
-- local _, FarstriderLib = ...

if not FarstriderLib.Internal then return end

FarstriderLib.Internal = nil

---@type FarstriderLibAPI
local lib = FarstriderLib_API
if lib and lib.Internal then lib.Internal = nil end
lib.DATA = FarstriderLib.Data
lib.Rebuild = function() FarstriderLib.Pathfinding:Rebuild() end
lib.FindTrail = FarstriderLib.FindTrail
lib.FindTrailTo = FarstriderLib.FindTrailTo

-- Kept in State so registrations survive a handover to a newer copy
lib.State.rebuildCallbacks = lib.State.rebuildCallbacks or {}
lib.RegisterRebuildCallback = function(callback)
    table.insert(lib.State.rebuildCallbacks, callback)
end

-- legacy support for direct access, will be removed in a future update
_G.FarstriderLib = FarstriderLib
