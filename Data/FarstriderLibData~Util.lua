-- FarstriderLibData~Data.lua
-- local _, FarstriderLibData = ...

if not FarstriderLibData.Internal then return end

local _fld = FarstriderLibData.Internal
local L = FarstriderLibData.L

local MIN_REBUILD_LIB_VERSION = 10500 -- older API.Rebuild needs self
local MIN_INSTANCE_LIB_VERSION = 10500

local Util = {}
FarstriderLibData.Util = Util

local lastPlayerLocation = nil

---@param value any
---@return boolean
local function IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value)
end

--- House interiors and neighbourhoods are only left by teleport, so their own map is a good enough start.
---@return boolean
local function IsInHousing()
    local instanceType = select(2, GetInstanceInfo())
    return instanceType == "interior" or instanceType == "neighborhood"
end

--- Entrance of a dungeon or raid on its continent; faction-specific entrances resolve to the player's faction.
---@param instanceMapId number
---@return Location? entrance nil when the instance has no known entrance
function Util.GetInstanceEntrance(instanceMapId)
    local entrance = FarstriderLibData.Instances and FarstriderLibData.Instances[instanceMapId]
    entrance = entrance and (entrance.mapId and entrance or entrance[UnitFactionGroup("player")])
    if not entrance then return nil end
    return { mapId = entrance.mapId, pos = { x = entrance.pos.x, y = entrance.pos.y, z = entrance.pos.z }, isUI = false, uiMapHint = entrance.uiMapHint }
end

--- Entrance of the dungeon or raid the player is in, on its zone map where known, which older FarstriderLib cores do not route from.
---@return Location?
local function GetPlayerInstanceEntrance()
    local api = FarstriderLib_API
    if not (api and (api.VERSION or 0) >= MIN_INSTANCE_LIB_VERSION and IsInInstance()) then return nil end
    local entrance = Util.GetInstanceEntrance((select(8, GetInstanceInfo())))
    if not (entrance and entrance.uiMapHint) then return entrance end

    local uiMapId, pos = C_Map.GetMapPosFromWorldPos(entrance.mapId, CreateVector2D(entrance.pos.x, entrance.pos.y), entrance.uiMapHint)
    if not (uiMapId and pos) then return entrance end
    return { mapId = uiMapId, pos = { x = pos.x, y = pos.y, z = entrance.pos.z }, isUI = true }
end

---@return Location playerLocation
function Util.GetPlayerLocation()
    local uiMapId = C_Map.GetBestMapForUnit("player")
    local uiMapCoords = uiMapId and C_Map.GetPlayerMapPosition(uiMapId, "player")
    if not uiMapCoords then
        local entrance = GetPlayerInstanceEntrance()
        if entrance then
            lastPlayerLocation = entrance
            return entrance
        end
    end

    if not uiMapId then
        return lastPlayerLocation or { mapId = 0, pos = { x = 0.5, y = 0.5, z = 0 }, isUI = true }
    end

    if not uiMapCoords then
        if not IsInHousing() then
            local mapInfo = C_Map.GetMapInfo(uiMapId)
            uiMapId = mapInfo and mapInfo.parentMapID or uiMapId
        end
        uiMapCoords = { x = 0.5, y = 0.5 }
    end

    lastPlayerLocation = { mapId = uiMapId, pos = { x = uiMapCoords.x, y = uiMapCoords.y, z = 0 }, isUI = true }
    return lastPlayerLocation
end

---@return Location?
local function GetBindArea()
    local areaId = FarstriderLibData.AreaL[GetBindLocation()]
    return areaId and FarstriderLibData.Areas[areaId]
end

---@return Location? bindLocation nil when the bind location has no area data
function Util.GetBindingLocation()
    local loc = GetBindArea()
    if not loc then return nil end
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

    if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE or FarstriderLibData.IS_FOREVER then
        if InCombatLockdown() then return false end
    end

    if not C_SpellBook.IsSpellInSpellBook(spellId) then return false end

    local chargeInfo = C_Spell.GetSpellCharges(spellId)
    if chargeInfo and not IsSecret(chargeInfo.currentCharges) and chargeInfo.currentCharges > 0 then return true end

    local cooldown = C_Spell.GetSpellCooldown(spellId)
    if IsSecret(cooldown.duration) then return cooldown.isActive == false end
    return cooldown.duration <= 0
end

--- Returns whether the player has a learned toy AND can actually use it.
--- `PlayerHasToy` only reports ownership, not usability — engineering-gated toys
--- (wormhole generators, dimensional rippers, etc.) report `PlayerHasToy = true`
--- regardless of profession/specialization. `C_ToyBox.IsToyUsable` reflects the
--- game's own requirement check (profession, specialization, skill level, class,
--- faction), so we defer to it when available.
---@param itemId number
---@return boolean
local function HasUsableToy(itemId)
    if not PlayerHasToy(itemId) then return false end
    if C_ToyBox and C_ToyBox.IsToyUsable then
        local usable = C_ToyBox.IsToyUsable(itemId)
        -- IsToyUsable returns nil while toy data is still loading; treat nil as
        -- usable so a transient load state doesn't drop a valid travel option.
        if usable == false then return false end
    end
    return true
end

--- Returns whether the player can currently use a given item.
---@param itemId number
---@return boolean
function Util.CanUseItem(itemId)
    if not itemId then return false end
    if not (HasUsableToy(itemId) or (C_Item.GetItemCount(itemId) > 0 and C_Item.IsUsableItem(itemId))) then return false end

    local duration
    if C_Item.GetItemCooldown then
        duration = select(2, C_Item.GetItemCooldown(itemId))
    elseif C_Container then
        duration = select(2, C_Container.GetItemCooldown(itemId))
    end
    if not IsSecret(duration) and duration and duration <= 0 then return true end

    local chargeInfo = C_Spell.GetSpellCharges(C_Item.GetItemSpell(itemId))
    if chargeInfo and not IsSecret(chargeInfo.currentCharges) and chargeInfo.currentCharges > 0 then return true end

    return false
end

---@type table<number, boolean>
local knownPlayerAuras = {}
---@type table<number, true>
local hiddenPlayerAuras = {}
local auraWatcher = _fld.createFrame("Frame")

---@param spellId number
---@return boolean
local function IsAuraSecret(spellId)
    return C_Secrets ~= nil and C_Secrets.ShouldSpellAuraBeSecret(spellId)
end

--- Returns whether the player has an aura; while the game hides it, the last known answer or false.
---@param spellId number
---@return boolean
function Util.HasPlayerAura(spellId)
    if IsAuraSecret(spellId) then
        if knownPlayerAuras[spellId] == nil and not hiddenPlayerAuras[spellId] then
            hiddenPlayerAuras[spellId] = true
            auraWatcher:RegisterEvent("ENCOUNTER_END")
            auraWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
            auraWatcher:RegisterEvent("ZONE_CHANGED_NEW_AREA")
            if C_EventUtils and C_EventUtils.IsEventValid("ADDON_RESTRICTION_STATE_CHANGED") then
                auraWatcher:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
            end
        end
        return knownPlayerAuras[spellId] or false
    end

    local hasAura = C_UnitAuras.GetPlayerAuraBySpellID(spellId) ~= nil
    knownPlayerAuras[spellId] = hasAura
    return hasAura
end

-- Waypoint conditions read while hidden stay false until the travel graph is rebuilt.
auraWatcher:SetScript("OnEvent", function(self)
    if InCombatLockdown() then return end

    local found = false
    for spellId in pairs(hiddenPlayerAuras) do
        if not IsAuraSecret(spellId) then
            hiddenPlayerAuras[spellId] = nil
            found = Util.HasPlayerAura(spellId) or found
        end
    end
    if next(hiddenPlayerAuras) == nil then
        self:UnregisterAllEvents()
    end

    local api = FarstriderLib_API
    if found and api and api.Rebuild and (api.VERSION or 0) >= MIN_REBUILD_LIB_VERSION then
        api.Rebuild()
    end
end)

---Returns true if the player's current bind location is supported, false otherwise
---@return boolean
function Util.IsBindLocationSupported()
    return GetBindArea() ~= nil
end
