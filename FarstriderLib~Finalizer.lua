-- FarstriderLib~Finalizer.lua
-- local _, FarstriderLib = ...

if not FarstriderLib.Internal then return end

FarstriderLib.Internal = nil

---@type FarstriderLibAPI
local lib = FarstriderLib_API
if lib and lib.Internal then lib.Internal = nil end
lib.DATA = FarstriderLib.Data
lib.Rebuild = FarstriderLib.Pathfinding.Rebuild
lib.FindTrail = FarstriderLib.FindTrail
lib.FindTrailTo = FarstriderLib.FindTrailTo

-- legacy support for direct access, will be removed in a future update
_G.FarstriderLib = FarstriderLib
