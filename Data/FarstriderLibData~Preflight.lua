-- FarstriderLib Data: checks for Preflight (/preflight FarstriderLibData), when it's loaded.
-- The client APIs the travel graph and holiday helper use.
-- local _, FarstriderLibData = ...

local P = rawget(_G, "Preflight")
if type(P) ~= "table" or type(P.Register) ~= "function" then return end

P:DeclareAPI("FarstriderLibData", {
    "CreateFrame", "GetExpansionLevel", "GetBindLocation", "GetLocale?",
    "InCombatLockdown", "IsIndoors", "PlayerHasToy", "UnitFactionGroup", "UnitLevel", "UnitRace?",
    "Item.CreateFromItemID?", "Spell.CreateFromSpellID?",
    "C_Timer.After", "C_Timer.NewTicker", "C_Timer.NewTimer",
    "C_Map.GetBestMapForUnit", "C_Map.GetPlayerMapPosition", "C_Map.GetMapInfo", "C_Map.GetAreaInfo",
    "C_SpellBook.IsSpellInSpellBook", "C_Spell.GetSpellCharges", "C_Spell.GetSpellCooldown",
    "C_Item.GetItemCount", "C_Item.IsUsableItem", "C_Item.GetItemSpell",
    "C_Item.GetItemCooldown?", "C_Container.GetItemCooldown?",
    "C_ToyBox.IsToyUsable?", "C_QuestLog.IsQuestFlaggedCompleted",
    "C_DateAndTime.GetCurrentCalendarTime",
    "C_Calendar.GetMonthInfo?", "C_Calendar.GetNumDayEvents?", "C_Calendar.GetDayEvent?",
    "EJ_GetInstanceForMap?", "C_EncounterJournal.GetDungeonEntrancesForMap?",
    "C_Housing?",
})

-- Anniversary portals need today's calendar time (and prefer holiday titles when loaded).
P:Register("FarstriderLibData", "Calendar time readable", function()
    local D = rawget(_G, "C_DateAndTime")
    if type(D) ~= "table" or type(D.GetCurrentCalendarTime) ~= "function" then
        return false, "C_DateAndTime.GetCurrentCalendarTime missing"
    end
    local t = D.GetCurrentCalendarTime()
    if type(t) ~= "table" or type(t.year) ~= "number" then
        return false, "calendar time not a table with year"
    end
    return true, ("%04d-%02d-%02d"):format(t.year or 0, t.month or 0, t.monthDay or 0)
end)
