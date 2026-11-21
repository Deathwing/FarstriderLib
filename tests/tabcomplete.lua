-- Tab completion for /fslog: every slash command FarstriderLib registers is queued in
-- GildedTabComplete (all aliases), with a hint. Gilded's engine is used when its checkout is
-- next to this one (GILDED_DIR, or ../Gilded); /fslog takes no words, so it has no subcommands.
-- luajit tests/tabcomplete.lua
local root = arg[0]:match("^(.*)/tests/[^/]+$") or "."
local failures = 0
local function check(cond, what) if not cond then failures = failures + 1; print("FAIL: " .. what) end end

SlashCmdList = {}
FarstriderLib = { Internal = {} }
assert(loadfile(root .. "/FarstriderLib~Logger.lua"))("FarstriderLib", FarstriderLib)

-- Every SLASH_<KEY><n> the file registers is in a queued entry.
local registered = {}
for k, v in pairs(_G) do
    if type(k) == "string" and k:match("^SLASH_") and type(v) == "string" then registered[v:lower()] = true end
end
check(next(registered), "Logger registers a slash command")
local queued = {}
for _, e in ipairs(GildedTabComplete or {}) do
    check(e.addon == "FarstriderLib", "entry names its add-on")
    check(type(e.tree) == "table" and type(e.tree.hint) == "string" and e.tree.hint ~= "", "entry has a hint")
    for _, s in ipairs(type(e.slash) == "table" and e.slash or { e.slash }) do queued[s:lower()] = e end
end
for s in pairs(registered) do check(queued[s], s .. " is queued for Tab completion") end
for s in pairs(queued) do check(registered[s], s .. " queued but not registered") end
check(queued["/fslog"] and not queued["/fslog"].tree.sub, "/fslog has no subcommands")

-- Through the real engine, when it is there.
local dir = os.getenv("GILDED_DIR") or (root .. "/../Gilded")
local f = io.open(dir .. "/Core/TabComplete.lua")
if f then
    f:close()
    GildedKit = { features = {}, Chat = function() return setmetatable({}, { __index = function() return function() end end }) end }
    Gilded = { Commands = {} }
    CreateFrame = function() return setmetatable({}, { __index = function() return function() end end }) end
    local ok, err = pcall(function() assert(loadfile(dir .. "/Core/TabComplete.lua"))("Gilded", {}) end)
    check(ok, "Gilded engine loads: " .. tostring(err))
    if ok and GildedKit.Tab and GildedKit.Tab.Resolve then
        for _, e in ipairs(GildedTabComplete) do GildedKit.Tab.Register(e.addon, e.slash, e.tree) end
        local r = GildedKit.Tab.Resolve("/fslog ")
        check(r and #(r.matches or {}) == 0, "/fslog offers no words")
        check(r and r.hint and r.hint:find("/fslog", 1, true), "/fslog prints its hint")
    end
end

if failures > 0 then os.exit(1) end
print("tabcomplete: ok")
