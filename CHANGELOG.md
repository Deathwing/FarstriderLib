# Changelog

## 1.5.0

### New Features
- `FarstriderLib_API.RegisterRebuildCallback(callback)`: addons are notified after every rebuild of the travel graph, for example after learning a flight path or levelling up
- Isolated regions: the data package can mark circular areas in world coordinates that are only reachable through their connections, optionally only while you are not flying
- `FindTrailTo` inside a dungeon or raid where the game hides your position starts with a "Leave <instance name>" step (`EdgeType.LEAVE_INSTANCE`, costed at a minute, with the action option `leave_instance` and the instance map ID) and continues from the instance's entrance, as if you stood there. The instance is the one `GetInstanceInfo()` reports and its entrance comes from FarstriderLibData 1.6.0 or later, so this works on every game version, including Classic Era and WoW Forever, which have no map inside instances, and TBC Classic, which has no Encounter Journal. Hearthstones, Astral Recall, teleport spells and teleport items can also start the route right inside the instance, with the same conditions and costs, whenever that is quicker than walking out; such a step is placed at the entrance, and teleports into the entrance's zone are left out as in the open world. The housing teleports are only planned from the entrance. Without entrance data the route starts as before
- `EdgeType.TRAM` (1008) for the Deeprun Tram, with the fallback text "Take the Deeprun Tram to %s"

### Changes
- On Classic Era, WoW Forever, TBC, Wrath and Cataclysm Classic, travel times use running and mount speeds for your level (and flying speeds on Cataclysm Classic from level 60) instead of retail skyriding speed, and update when you level up. Ground travel is costed at 1.3 times the straight-line distance, and on Classic Era, WoW Forever and TBC riding between flight masters (or the towns around them, also right after a Hearthstone) that a known flight connects costs at least twice that flight, so routes fly instead of riding over mountains. Retail and Mists Classic are unchanged. TBC and Wrath still use ground speeds where your character can fly in Outland or Northrend
- Route steps use zone map coordinates instead of continent coordinates, so TomTom arrows and map pins land on the right spot
- Building the travel graph needs far fewer map lookups, so rebuilds stay quick on every game version

### Fixes
- A trip made of several connecting flights points you at the flight master you depart from, not at a stop along the way
- Routes no longer skip a portal, boat or zeppelin when you are standing right on its departure point
- `FarstriderLib_API.Rebuild()` no longer throws an error
- The Hearthstone and Astral Recall are costed from where they land straight to your destination. Before, they were only linked to the nearest portal, boat or known flight master, so a bind point with none of those nearby looked far slower than it is. A Horde character in Orgrimmar bound to Cenarion Hold now hearths there to reach the Temple of Ahn'Qiraj instead of taking the long way
- Teleport spells, mage portals and teleport items, including the Hearthstone, are no longer offered when they land in the zone or city map the route starts in. Both the map's bounds and the game's own map lookup must place the landing there, so a Hearthstone into a neighbouring zone whose map overlaps yours is still offered. A mage in Orgrimmar was told to cast Teleport: Orgrimmar to reach a vendor in Orgrimmar
- Teleports whose destination depends on your character each use their own landing spot. On retail, the return from your house plot was planned as if it landed at your Hearthstone location
- Inside a house on retail, `FindTrailTo` starts in the neighbourhood instead of the middle of the continent, so routes begin with the return from your plot

## 1.4.4

### Changes
- Added support for Interface 120105 (Patch 12.1.5)
- Added support for World of Warcraft: Forever (Interface 16001); being inside a dungeon there no longer causes an error, as Forever has no Encounter Journal
- The travel graph is also built when FarstriderLib is loaded after login, so it can be loaded on demand
- When more than one copy from this release or later is installed, the newest one is used; copies from before this release still take precedence

## 1.4.3

### Changes
- Added support for Interface 120100 (Patch 12.1.0)

## 1.4.2

### Changes
- Added support for Interface 11509 (Classic Era 1.15.9)

## 1.4.1

### Fixes
- Restored faction restrictions on travel connections: a 12.0.7 data format change (PlayerCondition `RaceMask` split into `RaceMasks_0/1`) silently dropped all faction gates from the generated waypoint graph, routing Alliance characters through Horde-only transports such as the Grom'gol/Undercity zeppelins (#1)
- Horde-only portals whose faction requirement is only expressed via ModifierTree data (Ruins of Lordaeron and Tirisfal Glades portal networks) are now correctly gated as well (#1)

### Changes
- Added support for Interface 20506

## 1.4.0

### Added
- Added a Silvermoon City portal connection to the Stormwind portal room for Alliance characters

### Fixes
- Item travel connections now defer to the game's own toy usability check (`C_ToyBox.IsToyUsable`), so engineering-gated toys (Wormhole Generators, Dimensional Rippers, Ultrasafe Transporters) are no longer suggested to characters lacking the required profession or specialization
- The Mobile Telemancy Beacon item connection is now restricted to Suramar, where the item can actually be used, so it is no longer suggested elsewhere

### Changes
- Added 12.0.7 entries

## 1.3.3

### Changes
- Added support for Interface 120007

## 1.3.2

### Changes
- Added support for Interface 50504

## 1.3.1

### Changes
- Updated for TBC Phase 2

## 1.3.0

### Added
- Added `ContinentMapOverrides` config: allows remapping a zone's detected continent root to a different continent for pathfinding purposes (e.g. Quel'Thalas → Eastern Kingdoms)

### Changes
- Replaced `IgnoredMaps` default config entry with `ContinentMapOverrides`
- Replaced `IsolatedZones` default config entry with `IsolatedContinents`
- `HasDirectFlyPath` now uses `IsolatedContinents` config instead of a hardcoded Khaz Algar map ID check

## 1.2.1

### Improvements
- Better handling of Wizard's Sanctum check

## 1.2.0

### Fixes
- `FindClosestNavConnections` now respects `noAutoconnect` on target nodes, preventing virtual start/goal nodes from creating TRAVEL edges to isolated portal exits
- Flightpath step pins now point to the departure flightmaster instead of the destination
- Wizard's Sanctum interior nodes (flag 0x40) are now isolated in the nav graph, preventing incorrect auto-connections to exterior Stormwind nodes
- Direct fly-path shortcut is suppressed when the player is inside the Wizard's Sanctum, forcing the pathfinder to route through the exit door

## 1.1.0

### Changes
- Introduced `FarstriderLib_API` as a stable, versioned public API surface
- Added `FarstriderLib~Data.lua` proxy layer with metatable-based access to `FarstriderLibData_API` and safe defaults when data is absent
- Replaced all direct `FarstriderLibData` global access in pathfinding and core with `FarstriderLib.Data.CONFIG.*`
- Moved version guard check from `_G.FarstriderLib` to `FarstriderLib_API`
- Removed named global frame identifiers from the logger UI

### Improvements
- Added `Pathfinding:Rebuild()` for cache-clearing re-initialization after data updates

## 1.0.3

### Initial release
