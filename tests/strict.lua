-- Strict client API for the mock: when STRICT_CLIENT is "retail" or "forever",
-- the mock may not provide, and the code may not touch, an API that client's
-- snapshot (Preflight's api/<client>.json) lacks. STRICT_FALLBACKS=0 checks as
-- a player with loadDeprecationFallbacks off. Does nothing without Preflight
-- (or with STRICT_CLIENT unset), so the suite still runs on its own.
local client = os.getenv("STRICT_CLIENT")
if not client or client == "" then return end
local root = os.getenv("PREFLIGHT") or "/Users/jeffmlr/Projects/firstmate/projects/Preflight"
local f = io.open(root .. "/tools/strict_api.lua")
if not f then
    io.stderr:write("strict: no Preflight at " .. root .. ", skipped\n")
    return
end
f:close()
local Strict = dofile(root .. "/tools/strict_api.lua")
local ALLOW = {
    "^Farstrider", "^SLASH_", "^LibStub$", "^.*DB$", "^Preflight",
    "^TomTom", "^HereBeDragons", "^LibStub", "^[A-Z_]+$",
}
Strict.install(client, { require = true, allow = ALLOW })
return function()
    return Strict.audit(client, { allow = ALLOW })
end
