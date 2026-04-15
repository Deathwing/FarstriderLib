# Changelog

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
