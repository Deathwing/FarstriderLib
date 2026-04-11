-- FarstriderLibData~Data.lua
-- local _, FarstriderLibData = ...

if not FarstriderLibData.Internal then return end

local L = FarstriderLibData.L

local Util = {}
FarstriderLibData.Util = Util

---@return Location playerLocation
function Util.GetPlayerLocation()
    local uiMapId = C_Map.GetBestMapForUnit("player")
    local uiMapCoords = C_Map.GetPlayerMapPosition(C_Map.GetBestMapForUnit("player"), "player")

    if not uiMapCoords then
        local parentMapId = C_Map.GetMapInfo(uiMapId).parentMapID
        if parentMapId then
            uiMapId = parentMapId

            local instanceId = EJ_GetInstanceForMap(uiMapId)
            local dungeonEntrances = C_EncounterJournal.GetDungeonEntrancesForMap(parentMapId)

            for _, entrance in ipairs(dungeonEntrances) do
                if entrance.journalInstanceID == instanceId then
                    uiMapId = parentMapId
                    uiMapCoords = entrance.position
                    break
                end
            end
        end
    end

    if not uiMapCoords then
        uiMapCoords = { x = 0.5, y = 0.5 }
    end

    return { mapId = uiMapId, pos = { x = uiMapCoords.x, y = uiMapCoords.y, z = 0 }, isUI = true }
end

---@return Location
function Util.GetBindingLocation()
    local loc = FarstriderLibData.Areas[FarstriderLibData.AreaL[GetBindLocation()]]
    return { mapId = loc.mapId, pos = { x = loc.pos.x, y = loc.pos.y, z = loc.pos.z }, isUI = false }
end

---@type table<number, ItemMixin>
local itemCache = {}

---@param itemId number
---@return ItemMixin
function Util.GetItem(itemId)
    if not itemCache[itemId] then
        itemCache[itemId] = Item:CreateFromItemID(itemId)
    end

    return itemCache[itemId]
end

---@param itemId number
---@return string itemName
function Util.GetItemNameSafe(itemId)
    return Util.GetItem(itemId):GetItemName() or L["Item_" .. itemId]
end

---@type table<number, SpellMixin>
local spellCache = {}

function Util.GetSpell(spellId)
    if not spellCache[spellId] then
        spellCache[spellId] = Spell:CreateFromSpellID(spellId)
    end

    return spellCache[spellId]
end

function Util.GetSpellNameSafe(spellId)
    return Util.GetSpell(spellId):GetSpellName() or L["Spell_" .. spellId]
end

--- Returns whether the player can currently use a given spell.
---@param spellId number
---@return boolean
function Util.CanUseSpell(spellId)
    if not spellId then return false end

    if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
        if InCombatLockdown() then return false end
    end

    if not C_SpellBook.IsSpellInSpellBook(spellId) then return false end

    local chargeInfo = C_Spell.GetSpellCharges(spellId)
    if chargeInfo and chargeInfo.currentCharges > 0 then return true end

    return C_Spell.GetSpellCooldown(spellId).duration <= 0
end

--- Returns whether the player can currently use a given item.
---@param itemId number
---@return boolean
function Util.CanUseItem(itemId)
    if not itemId then return false end
    if not (PlayerHasToy(itemId) or (C_Item.GetItemCount(itemId) > 0 and C_Item.IsUsableItem(itemId))) then return false end

    if C_Item.GetItemCooldown then
        if select(2, C_Item.GetItemCooldown(itemId)) <= 0 then return true end
    elseif C_Container then
        if select(2, C_Container.GetItemCooldown(itemId)) <= 0 then return true end
    end

    local chargeInfo = C_Spell.GetSpellCharges(C_Item.GetItemSpell(itemId))
    if chargeInfo and chargeInfo.currentCharges > 0 then return true end

    return false
end
