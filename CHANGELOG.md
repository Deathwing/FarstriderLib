# Changelog

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
