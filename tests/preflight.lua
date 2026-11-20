-- "Player map position": a skip (nil) in an instance, a fail in the open world.
local root = arg[0]:match("^(.*)/tests/[^/]+$") or "."
local failures = 0
local function check(cond, what) if not cond then failures = failures + 1; print("FAIL: " .. what) end end

local checks = {}
Preflight = { Register = function(_, addon, name, fn) checks[addon .. ":" .. name] = fn end, DeclareAPI = function() end }
local inInstance, instanceType, pos = false, "none", nil
IsInInstance = function() return inInstance, instanceType end
C_Map = {
    GetBestMapForUnit = function() return 731 end,
    GetPlayerMapPosition = function() return pos end,
}
assert(loadfile(root .. "/FarstriderLib~Preflight.lua"))("FarstriderLib", {})
local run = checks["FarstriderLib:Player map position"]
check(run, "check registered")

pos = nil
local ok, detail = run()
check(ok == false and detail:find("no player position on map 731", 1, true), "open world without position fails")

inInstance, instanceType = true, "party"
ok, detail = run()
check(ok == nil and detail:find("instance (party)", 1, true), "in an instance without position skips with reason")

pos = { x = 0.5, y = 0.25 }
ok, detail = run()
check(ok == true and detail:find("map 731 at 0.50, 0.25", 1, true), "position present passes even in an instance")

if failures > 0 then os.exit(1) end
print("preflight: ok")
