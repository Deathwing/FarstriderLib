# Changelog

## 1.6.0

### New Features
- Classic Era, WoW Forever and TBC Classic: routes use flight paths. Flight masters, routes and flight times come from the game build (within a second or two of real flights), and connecting flights are chained automatically
- Flight paths are only used between flight masters your character knows. The game does not report them at login, so they are learned whenever you open a flight master's map and remembered per character; until then routes do not use flight paths. With FarstriderLib 1.4.x, newly learned flights are used after the next login
- `FarstriderLibData_API.HasFlightData(uiMapId)`: false while this character has no flight data for the continent of uiMapId (until a flight master's map there has been opened), true when the data is available or not needed
- Dungeon and raid entrances for every game version: `FarstriderLibData_API.GetInstanceEntrance(instanceMapId)` returns the entrance of the instance with that map ID (the one `GetInstanceInfo()` reports) in continent world coordinates, with `uiMapHint` naming the zone map it is on where the game data tells, or nil. Instances with an entrance per faction, such as Siege of Boralus, return the one of your faction. They come from the game data: the entrance pins of the dungeon journal and world map, or the spot outside the instance where the game moves your corpse where there is no pin near it, and on Classic clients, which have no corpse positions, WoW Forever's (before Cataclysm) or retail's. Naxxramas on Classic Era and WoW Forever uses its teleporter in the Plaguewood. WoW Forever's own dungeons, which the game data has no entrance for, use the entrances measured by Questie and Conquest Capped on their zone maps; Manor Mistmantle and the Season of Discovery instances have no entrance yet. FarstriderLib 1.5.0 plans routes out of the instance you are in from them; older FarstriderLib versions are unaffected

### Fixes
- Classic Era, WoW Forever, TBC and Wrath: the Undercity zeppelin docks at the zeppelin tower outside Orgrimmar in Durotar instead of the Cataclysm tower inside the city, and Horde gets the zeppelin from that tower to Grom'gol Base Camp. On Wrath Classic the zeppelins to Thunder Bluff and to Warsong Hold in Borean Tundra leave from the tower west of Orgrimmar
- Classic Era, WoW Forever, TBC and Wrath: Teldrassil and Darnassus can no longer be reached on foot from Darkshore. Routes take the Auberdine–Rut'theran Village boat, which now uses the pre-Cataclysm piers, and the Rut'theran Village–Darnassus teleporter, which was missing
- Wrath and Cataclysm Classic: routes no longer tell you to walk up into Dalaran. They use the Violet Stand teleport crystals (the one up to Dalaran needs "Learning to Leave and Return: the Magical Way") or the city's portals; on Cataclysm Classic from level 60 you can still fly in
- TBC Classic: the capital portals to the Blasted Lands are no longer suggested; they arrived with patch 3.2.0. TBC, Wrath, Cataclysm and Mists Classic: removed the Stair of Destiny portals in Hellfire Peninsula, which only exist since Warlords of Draenor. On TBC, Horde routes from Undercity to Orgrimmar take the zeppelin again
- Cataclysm and Mists Classic: removed the Shattrath and Dalaran portals to Ironforge, Darnassus, the Exodar, Undercity, Thunder Bluff and Silvermoon, which patch 4.0.3a removed, and a Stormwind–Darnassus portal that only exists on retail. Alliance routes use the Shattrath and Dalaran portals to Stormwind again; they were silently dropped
- TBC and Wrath Classic: the Shattrath and Dalaran portals to Stormwind arrive in the Mage Quarter, as there is no Wizard's Sanctum portal room before Cataclysm
- Classic Era, WoW Forever, TBC, Wrath, Cataclysm and Mists Classic: mages are no longer told to use Create a portal to Darnassus, which used retail's landing spot in north Darkshore; Teleport: Darnassus is still suggested
- Classic Era, WoW Forever, TBC, Wrath and Cataclysm Classic: mage teleports cost 30 seconds more for their Rune of Teleportation, so routes only use them, or Create a portal, when they save real time
- Mages who know a teleport, such as Teleport: Thunder Bluff, are told to cast it instead of Create a portal to the same city. Create a portal is only suggested when you know just the portal
- Cataclysm and Mists Classic: Teleport: Tol Barad lands at your faction's base camp instead of the middle of Tol Barad Peninsula
- Hearthstones, Astral Recall and teleport items with a cooldown of 15 minutes or more are only used when they save more than about a minute, so a long cooldown is not spent on a few seconds. On Cataclysm and Mists Classic, for example, Razor Hill to Orgrimmar now rides instead of using a Hearthstone set in Orgrimmar
- Classic Era, WoW Forever, TBC and Wrath: routes can use your Hearthstone and Astral Recall when you are bound at Valley of Trials, Shadowglen, Thunderbrew Distillery, Craftsmen's Terrace, Grom'gol Base Camp (Classic Era and WoW Forever) or Ammen Vale (TBC and Wrath), and at the inns of Goldshire, Kharanos, Brill, Dolanaar, Razor Hill, Bloodhoof Village, The Crossroads, Feathermoon Stronghold and Darnassus, plus Azure Watch and Falconwing Square on TBC and Wrath. These bind points had no location before
- A new character's starting bind point counts as landing nearby, so routes can use the Hearthstone before you set it at an inn: Northshire Valley counts as Northshire Abbey, and Deathknell, Camp Narache, Coldridge Valley or Anvilmar, or Sunstrider Isle from TBC Classic on, as the nearest town (Brill, Bloodhoof Village, Kharanos or Falconwing Square)
- More inns work with the Hearthstone: Fairbreeze Village on TBC and Wrath Classic; Cenarion Refuge from TBC Classic on, which counts as Swamprat Post, the nearest flight master; the Lower City inn in Shattrath from TBC Classic on; the inns of New Agamand and Vengeance Landing from Wrath Classic on; The Commons in Ironforge, Talonbranch Glade and the Northwatch Expedition Base Camp inn on Cataclysm Classic, Mists Classic and retail; the Sri-La Inn on Mists Classic and retail; on retail the Salty Sailor, Scarlet Raven, Pig and Whistle and Broken Keel taverns, World's End Tavern in Shattrath, The Exobar, Nighthaven Inn, The Cat and the Shaman in Thunder Bluff, The Keggary in the Shrine of Two Moons, The Wyvern's Tail in Orgrimmar, the Stormwind Embassy (not on French clients, where it has the same name as the Orgrimmar Embassy), Throm'var, the Weaver's Lair, the Howling Ridge and the Bronze Enclave in Valdrakken
- Bind points that counted as another town now count as their own: from Wrath Classic on Valgarde and Westguard Inn (were Kamagua), Moa'ki Harbor (Stars' Rest) and Westfall Brigade Encampment; on Cataclysm Classic, Mists Classic and retail Lion's Pride Inn (Northshire Abbey instead of Goldshire), The Farstrider Lodge (Thelsamar), Falconwing Inn (Fairbreeze Village), Fallowmere Inn (Sun Rock Retreat instead of Windshear Hold), Nordrassil Inn (Grove of Aessina), Speedbarge Bar (Westreach Summit) and Schnottz's Hostel (Ramkahen); on Mists Classic and retail Paw'don Village and The Drunken Hozen (Tian Monastery) and Valiant Rest (Amber Ledge instead of Valiance Keep); on retail Stormshield (Warspear), Fort Wrynn, Vol'mar Hold, Greywatch Barracks, Prepfoot Compound, Zul'jan Ruins, Seekers' Vista and Har'alnor Den
- A Hearthstone set at Theramore Isle no longer counts as landing at Brackenwall Village. From TBC Classic on, Grom'gol Base Camp no longer counts as Rebel Camp, and on Cataclysm Classic, Mists Classic and retail Feathermoon Stronghold no longer counts as Camp Mojache
- A bind point without location data no longer causes a Lua error; routes leave the Hearthstone out
- Classic clients no longer load the retail-only Void Elf portals
- Retail: connections into and inside Stormwind's Wizard's Sanctum work again (the generated data used an area ID as the map hint, so they were dropped). Routes use the Sanctum portals (Boralus, Valdrakken, Silvermoon, the Exodar, Shattrath, the Jade Forest, Azsuna, Dornogal and more), and walks inside the Sanctum are no longer shown as steps
- Retail: the boats between Stormwind and Boralus and the boats and zeppelins to the Waking Shores keep the game's own travel times instead of counting as fast as a portal. The Wizard's Sanctum portal to Boralus is only suggested when your character can use it (Battle for Azeroth intro, Kul Tiran, or level 40 and up), the Sanctum of the Sages portals back after the intro or from level 50, and the Sanctum of the Sages portal to Silithus only during the Heart of Azeroth intro
- WoW Forever and retail: checking whether a teleport spell, Hearthstone or toy is ready no longer causes a Lua error where the game hides cooldowns from addons (dungeons, raids, Mythic+). Spells still count as ready when the game shows them off cooldown; an item whose cooldown or charges are hidden counts as not ready until they show again
- Retail: the Dark Portal to Stormshield and the portal to the Fel Hammer, which need a buff, use what was known while the game hides your buffs (combat, encounters, Mythic+, PvP). After a login or reload there, the Fel Hammer portal is added back to routes as soon as your buffs show again instead of missing until the next login
- The Deeprun Tram between Stormwind and Ironforge says "Take the Deeprun Tram to …" instead of "Take the portal to …"

## 1.5.5

### Fixes
- Added the guild cloaks (Wrap of Unity, Shroud of Cooperation, Cloak of Coordination) on Cataclysm Classic; like the other 1.5.4 connections, they were defined with retail map IDs and never loaded there

## 1.5.4

### Fixes
- Added connections that were defined with retail map IDs and never loaded on Classic clients that use the original zone maps (Classic Era, TBC, Wrath and Cataclysm Classic):
  - All four: the Deeprun Tram, mage teleports, the Everlook and Gadgetzan Dimensional Ripper and Ultrasafe Transporter, Atiesh, Teleport: Moonglade, the Lunar Festival Invitation and the Menethil Harbor–Theramore boat
  - TBC and later: the Blasted Lands, Shattrath and Exodar–Darnassus portals, the Orb of Translocation to Silvermoon, the Blessed Medallion of Karabor and the Area 52 and Toshley's Station Ripper and Transporter
  - Wrath and Cataclysm Classic: Death Gate, the Dalaran portals, the Menethil Harbor–Valgarde and Stormwind–Borean Tundra boats, the Shattered Sun Staging Area flight paths and the Sholazar Basin–Un'Goro Crater portal, plus Boots of the Bay on Wrath
  - Cataclysm Classic: the Booty Bay–Ratchet boat and the Orgrimmar zeppelins
- French translations now load; the French locale file was missing from the data file lists ([#3](https://github.com/Deathwing/FarstriderLib/pull/3), thanks @Neogeekmo)

### Changes
- Added support for Interface 120105 (Patch 12.1.5)
- Added support for World of Warcraft: Forever (Interface 16001) with Forever area and waypoint data from the live 1.60.1.70862 game build, the Powderfuse Port boat and the faction skycutters to Zephras Isle; as on retail, teleport spells are not suggested in combat there, and being inside a dungeon no longer causes an error
- When more than one copy from this release or later is installed, the newest one is used; copies from before this release still take precedence

## 1.5.3

### Changes
- Added support for Interface 120100 (Patch 12.1.0) and updated all data to the 12.1.0 game build

## 1.5.2

### Fixes
- Added the "Seat of Ramkahen" (Uldum) hearthstone bind location in all locales

### Changes
- Added support for Interface 11509

## 1.5.1

### Fixes
- Restored faction restrictions on waypoint connections that were silently dropped by a 12.0.7 data format change; Alliance characters are no longer routed through Horde-only transports (#1)

### Changes
- Added support for Interface 20506
- Updated data sources

## 1.5.0

### Added
- Added a Silvermoon City portal connection to the Stormwind portal room for Alliance characters

### Fixes
- Item travel connections now defer to the game's own toy usability check (`C_ToyBox.IsToyUsable`), so engineering-gated toys (Wormhole Generators, Dimensional Rippers, Ultrasafe Transporters) are no longer suggested to characters lacking the required profession or specialization

### Changes
- Updated data sources

## 1.4.3

### Changes
- Added support for Interface 120007

## 1.4.2

### Changes
- Added support for Interface 50504

## 1.4.1

### Changes
- Updated for TBC Phase 2

## 1.4.0

### Fixes
- Resolved several issues around Quel'Thalas (Old) in Midnight

### Added
- Added isolated area groups for Eversong Woods, Ghostlands, Silvermoon City, Azuremyst Isle, The Exodar, Bloodmyst Isle, and Isle of Quel'Danas (covering both Pandaria+ and Cataclysm-era map IDs)
- Added `IsolatedContinents` config: Khaz Algar (2274) is now flagged as an isolated continent, requiring subzone-level matching for direct fly-path checks instead of continent-level matching
- Added `ContinentMapOverrides` config: Quel'Thalas (2537) is now remapped to Eastern Kingdoms for pathfinding
- Added Quel'Thalas (2537) to `MapTypeOverrides` as Zone type
- Added boat connection: Auberdine → Valaar's Berth (Azuremyst Isle) for TBC and later
- Added Ruins of Lordaeron Orb of Translocation → Silvermoon City portal connection for Horde

### Changes
- `IsolatedAreas` group IDs are now auto-generated negative integers (via `_I()`/`_i()` helpers) so new groups never clash with hardcoded values
- Renamed `IsolatedZones` to `IsolatedContinents`; existing entry for Dornogol and Undermine removed; Khaz Algar (2274) added
- Removed `IgnoredMaps` (map 2311) in favor of isolated area and continent map override configs
- Removed Player Housing maps from `MapTypeOverrides`; they are now handled via `IsolatedAreas`

## 1.3.0

### Changes
- Updated for build 12.0.5

### Improvements
- GetPlayerLocation now returns the player's last known position when the player is in an instance without a valid map position, improving pathfinding reliability in certain dungeons and raids

## 1.2.0

### Fixes
- Hub transit destination nodes (e.g. Oribos portal exits) now have `NoAutoconnect` flag set, forcing routes through explicit flightpath edges instead of direct TRAVEL connections
- Hub transit edges marked `skipOptimized` so bare hub names no longer appear as waypoint instructions
- Player housing maps (Razorwind Shores, Founder's Point) are now marked as isolated, preventing invalid direct fly-path routing from housing plots

## 1.1.0

### Changes
- Introduced `FarstriderLibData_API` as a stable, versioned public API surface
- Moved version guard check from `_G.FarstriderLibData` to `FarstriderLibData_API`
- Exposed `GetLocalizedString`, `IsBindLocationSupported`, `GetHousingData`, `UpdateHousingExitLocation`, and `GetHelpfulItems` through the API
- Absorbed the player housing event handler (`PLAYER_HOUSE_LIST_UPDATED`) from the main addon
- Added `FarstriderLibData~Types.lua` containing waypoint, location, connection, and config type definitions previously located in FarstriderLib~Types.lua
- Added `Util.IsBindLocationSupported` helper

## 1.0.2

### Initial release
