# Changelog

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
