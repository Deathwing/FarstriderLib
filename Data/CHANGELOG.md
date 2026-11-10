# Changelog

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
