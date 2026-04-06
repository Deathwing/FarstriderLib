-- FarstriderLib~Util.lua
-- Utility functions owned by FarstriderLib so data files are self-contained.

FarstriderLib.Util = FarstriderLib.Util or {}
FarstriderLib.UI = FarstriderLib.UI or {}

---@class FarstriderLibUtil
local Util = FarstriderLib.Util

---@class FarstriderLibUI
local UI = FarstriderLib.UI

--- Returns the player's current location as a NavLocation.
---@return NavLocation
function Util.GetPlayerLocation()
    local mapId = C_Map.GetBestMapForUnit("player")
    if not mapId then
        return { mapId = 0, pos = { x = 0.5, y = 0.5, z = 0 }, isUI = true }
    end

    local position = C_Map.GetPlayerMapPosition(mapId, "player")
    if not position then
        return { mapId = mapId, pos = { x = 0.5, y = 0.5, z = 0 }, isUI = true }
    end

    return { mapId = mapId, pos = { x = position.x, y = position.y, z = 0 }, isUI = true }
end

--- Returns the player's hearthstone bind location as a NavLocation, or nil.
---@return NavLocation?
function Util.GetBindingLocation()
    local bindLocation = GetBindLocation()
    if not bindLocation then return nil end

    -- AreaL lookup: try to resolve the area name to a map location
    if FarstriderData and FarstriderData.AreaL then
        local areaInfo = FarstriderData.AreaL[bindLocation]
        if areaInfo then
            return areaInfo
        end
    end

    return nil
end

--- Safe wrapper for GetSpellInfo that never returns nil.
---@param spellId number
---@return string
function Util.GetSpellNameSafe(spellId)
    local info = C_Spell.GetSpellInfo(spellId)
    if info and info.name then
        return info.name
    end
    return "Unknown Spell (" .. spellId .. ")"
end

--- Safe wrapper for C_Item.GetItemNameByID that never returns nil.
---@param itemId number
---@return string
function Util.GetItemNameSafe(itemId)
    local name = C_Item.GetItemNameByID(itemId)
    if name then
        return name
    end
    return "Unknown Item (" .. itemId .. ")"
end

--- Returns whether the player can currently use a given spell.
---@param spellId number
---@return boolean
function UI.CanUseSpell(spellId)
    if not C_Spell.IsPlayerSpell(spellId) then
        return false
    end
    local start, duration = GetSpellCooldown(spellId)
    if start and start > 0 and duration > 1.5 then
        return false
    end
    return true
end

--- Returns whether the player can currently use a given item.
---@param itemId number
---@return boolean
function UI.CanUseItem(itemId)
    local count = C_Item.GetItemCount(itemId, true)
    if count == 0 then
        return false
    end
    local start, duration = C_Item.GetItemCooldown(itemId)
    if start and start > 0 and duration > 1.5 then
        return false
    end
    return true
end
