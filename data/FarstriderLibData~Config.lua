-- FarstriderLibData~Config.lua
-- local _, FarstriderLibData = ...

if not FarstriderLibData.Internal then return end

local Config = {}
FarstriderLibData.Config = Config

-- Elevation overrides: mapId -> z coordinate
Config.ElevationOverrides = {
    -- Shadowlands
    [1525] = 4275, -- Revendreth
    [1688] = 4275, -- Revendreth

    [1533] = 6534, -- Bastion

    [1536] = 3307, -- Maldraxxus
    [1689] = 3307, -- Maldraxxus

    [1543] = 4870, -- The Maw
    [1648] = 4870, -- The Maw
    [1911] = 4870, -- Torghast - Entrance
    [1960] = 4870, -- The Maw
    [1961] = 4870, -- Korthia

    [1550] = 5270, -- Shadowlands

    [1565] = 5581, -- Ardenweald
    [1603] = 5581, -- Ardenweald
    [1709] = 5581, -- Ardenweald
    [2005] = 5581, -- Ardenweald

    [1670] = 5270, -- Ring of Fates
    [1671] = 5450, -- Ring of Transference
    [1672] = 5250, -- The Broker's Den
    [1673] = 5630, -- The Crucible

    [2016] = 4789, -- Tazavesh, the Veiled Market

    -- Dragonflight
    [2023] = 200, -- Ohn'ahran Plains
    [2024] = 446, -- The Azure Span
    [2025] = 888, -- Thaldraszus
    [2112] = 888, -- Valdrakken
}

-- Map type overrides: mapId -> { mapType = Enum.UIMapType.* }
Config.MapTypeOverrides = {
    [125] = { mapType = 3 },  -- Dalaran: Northrend (Zone)
    [627] = { mapType = 3 },  -- Dalaran: Broken Isles (Zone)
    [1670] = { mapType = 3 }, -- Oribos (Zone)
    [1671] = { mapType = 3 }, -- Oribos (Zone)
    [1672] = { mapType = 3 }, -- Oribos (Zone)
    [1673] = { mapType = 3 }, -- Oribos (Zone)
    [2305] = { mapType = 3 }, -- Dalaran (Zone)
    [2351] = { mapType = 4 }, -- Player Housing: Razorwind Shores (isolated)
    [2352] = { mapType = 4 }, -- Player Housing: Founder's Point (isolated)
}

-- Isolated area groups: mapId -> groupId (same groupId = same isolated area)
Config.IsolatedAreas = {
    -- Eastern Kingdom
    [201] = 0, -- Kelp'thar Forest
    [203] = 0, -- Vashj'ir
    [204] = 0, -- Abyssal Depths
    [205] = 0, -- Shimmering Expanse

    [244] = 1, -- Tol Barad
    [245] = 1, -- Tol Barad Peninsula

    -- Pandaria
    [504] = -2, -- Isle of Thunder

    -- Kul Tiras / Zandalar
    [1355] = -1, -- Nazjatar

    -- Shadowlands
    [1525] = 2, -- Revendreth
    [1688] = 2, -- Revendreth

    [1533] = 3, -- Bastion

    [1536] = 4, -- Maldraxxus
    [1689] = 4, -- Maldraxxus

    [1543] = 5, -- The Maw
    [1648] = 5, -- The Maw
    [1911] = 5, -- Torghast - Entrance
    [1960] = 5, -- The Maw
    [1961] = 5, -- Korthia

    [1565] = 6, -- Ardenweald
    [1603] = 6, -- Ardenweald
    [1709] = 6, -- Ardenweald
    [2005] = 6, -- Ardenweald

    [1670] = 7, -- Ring of Fates
    [1671] = 7, -- Ring of Transference
    [1672] = 7, -- The Broker's Den
    [1673] = 7, -- The Crucible

    [1970] = 8, -- Zereth Mortis

    [2016] = 9, -- Tazavesh, the Veiled Market

    -- Dragonflight
    [2133] = 10, -- Zaralek Cavern

    [2200] = 11, -- Emerald Dream
}

-- Maps to skip entirely during graph construction
Config.IgnoredMaps = {
    [2311] = true,
}

-- Maps where navigation should not try to auto-connect to nearby zones
Config.IsolatedZones = {
    [2248] = true, -- Dornogol
    [2346] = true, -- Undermine
}
