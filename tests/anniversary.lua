-- Regression: Orgrimmar / Stormwind <-> Caverns of Time anniversary portals
-- (calendar event 1808 / Nov 17–Dec 8 2026) and Util.IsWowAnniversaryActive.
local root = arg[0]:match("^(.*)/tests/[^/]+$") or "."
local failures, passes = 0, 0

local function check(cond, what)
    if cond then
        passes = passes + 1
    else
        failures = failures + 1
        print("FAIL: " .. what)
    end
end

local function read(path)
    local f = assert(io.open(path, "r"))
    local s = f:read("*a")
    f:close()
    return s
end

-- Source: retail-only edges with wiki coords and anniversary condition.
local connections = read(root .. "/Data/FarstriderLibData~Connections.lua")
check(connections:find("IsWowAnniversaryActive", 1, true), "Connections uses IsWowAnniversaryActive")
check(connections:find("Stormwind <-> Caverns of Time (Anniversary)", 1, true),
    "Alliance SW <-> CoT anniversary portal present")
check(connections:find("Orgrimmar <-> Caverns of Time (Anniversary)", 1, true),
    "Horde Org <-> CoT anniversary portal present")
check(connections:find("84, { x = 0.4370, y = 0.8540", 1, true),
    "Stormwind Wizard's Sanctum coords 43.7,85.4 (map 84)")
check(connections:find("85, { x = 0.5640, y = 0.9250", 1, true),
    "Orgrimmar Pathfinder's Den coords 56.4,92.5 (map 85)")
check(connections:find("-- Stormwind <-> Caverns of Time (Anniversary)", 1, true)
    and connections:find("74, { x = 0.5460, y = 0.2830, z = 0 }, true, 2300, 10, anniversary)", 1, true),
    "Caverns of Time landing map 74 / area 2300 on anniversary edges")

-- Unit-test the holiday helper against a mock calendar / date API.
-- Define the mock first, then Preflight's strict_api (when STRICT_CLIENT is set),
-- then load the helper — so the mock cannot provide an API the live client lacks.
FarstriderLibData = { Internal = {}, L = {} }

local calTime = { year = 2026, month = 11, monthDay = 20 }
local dayEvents = {}
C_DateAndTime = { GetCurrentCalendarTime = function() return calTime end }
C_Calendar = {
    GetMonthInfo = function() return { month = calTime.month, year = calTime.year } end,
    GetNumDayEvents = function() return #dayEvents end,
    GetDayEvent = function(_, _, i) return dayEvents[i] end,
}

local strictAudit
do
    local chunk = loadfile(root .. "/tests/strict.lua")
    if chunk then
        local audit = chunk()
        if type(audit) == "function" then strictAudit = audit end
    end
end

assert(loadfile(root .. "/Data/FarstriderLibData~Util.lua"))()
local U = FarstriderLibData.Util

dayEvents = { { calendarType = "HOLIDAY", title = "WoW's 22nd Anniversary" } }
check(U.IsWowAnniversaryActive() == true, "calendar holiday titled Anniversary is active")

dayEvents = { { calendarType = "HOLIDAY", title = "Brewfest" } }
check(U.IsWowAnniversaryActive() == false, "other holidays do not count as Anniversary")

dayEvents = {}
calTime = { year = 2026, month = 11, monthDay = 17 }
check(U.IsWowAnniversaryActive() == true, "2026-11-17 date fallback when calendar empty")

calTime = { year = 2026, month = 12, monthDay = 8 }
check(U.IsWowAnniversaryActive() == true, "2026-12-08 date fallback when calendar empty")

calTime = { year = 2026, month = 12, monthDay = 9 }
check(U.IsWowAnniversaryActive() == false, "after Dec 8 2026 the fallback is off")

calTime = { year = 2027, month = 11, monthDay = 20 }
check(U.IsWowAnniversaryActive() == false, "non-2026 years need a calendar holiday")

dayEvents = { { calendarType = "HOLIDAY", title = "WoW's Anniversary" } }
check(U.IsWowAnniversaryActive() == true, "later years work via calendar title match")

if strictAudit then
    local bad = strictAudit()
    if type(bad) == "table" and #bad > 0 then
        failures = failures + 1
        print("FAIL: strict audit: " .. table.concat(bad, ", "))
    end
end

if failures == 0 then
    io.stdout:write("PASS (" .. passes .. ")\n")
    os.exit(0)
end
os.exit(1)
