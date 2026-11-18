-- Regression: 12.1.7 drops [Game]/[Family] TOC expansion; data TOC must use
-- explicit [AllowLoadGameType ...] lines, and both TOCs list interface 120107.
local root = arg[0]:match("^(.*)/tests/[^/]+$") or "."
local failures = 0

local function fail(msg)
    failures = failures + 1
    print("FAIL: " .. msg)
end

local function read(path)
    local f = assert(io.open(path, "r"))
    local s = f:read("*a")
    f:close()
    return s
end

local games = {
    { file = "FarstriderLibData_Standard.xml", tag = "standard" },
    { file = "FarstriderLibData_Camelot.xml", tag = "camelot" },
    { file = "FarstriderLibData_Mists.xml", tag = "mists" },
    { file = "FarstriderLibData_Cata.xml", tag = "cata" },
    { file = "FarstriderLibData_Wrath.xml", tag = "wrath" },
    { file = "FarstriderLibData_TBC.xml", tag = "tbc" },
    { file = "FarstriderLibData_Vanilla.xml", tag = "vanilla" },
}

local dataToc = read(root .. "/Data/FarstriderLibData.toc")
local libToc = read(root .. "/FarstriderLib.toc")

if dataToc:find("%[Game%]") or dataToc:find("%[Family%]") then
    fail("Data TOC still uses [Game] or [Family] expansion")
end
if dataToc:find("FarstriderLibData_%[Game%]%.xml") then
    fail("Data TOC still loads FarstriderLibData_[Game].xml")
end

for _, g in ipairs(games) do
    local needle = g.file:gsub("%.", "%%.") .. "%s*%[AllowLoadGameType%s+" .. g.tag .. "%]"
    if not dataToc:find(needle) then
        fail("missing " .. g.file .. " [AllowLoadGameType " .. g.tag .. "]")
    end
end

if not libToc:match("## Interface:.-120107") then
    fail("FarstriderLib.toc Interface missing 120107")
end
if not dataToc:match("## Interface:.-120107") then
    fail("FarstriderLibData.toc Interface missing 120107")
end

if failures == 0 then
    io.stdout:write("PASS\n")
    os.exit(0)
end
os.exit(1)
