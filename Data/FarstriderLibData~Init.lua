-- FarstriderLibData~Init.lua
-- local _, FarstriderLibData = ...

local VERSION = 10505

local lib = FarstriderLibData_API
if lib and lib.VERSION and (lib.VERSION >= VERSION or not lib.Shutdown) then return end
if lib and lib.Shutdown then
    lib.Shutdown()
end
lib = lib or {}
FarstriderLibData_API = lib

local internal = { frames = {}, cleanups = {}, stopped = false }
lib.VERSION = VERSION
lib.State = lib.State or {}
lib.Internal = internal

function lib.Shutdown()
    internal.stopped = true
    for _, cleanup in ipairs(internal.cleanups) do
        cleanup()
    end
    for _, frame in ipairs(internal.frames) do
        frame:UnregisterAllEvents()
        frame:SetScript("OnUpdate", nil)
        frame:Hide()
    end
end

function internal.createFrame(...)
    local frame = CreateFrame(...)
    internal.frames[#internal.frames + 1] = frame
    return frame
end

function internal.after(delay, callback)
    C_Timer.After(delay, function()
        if not internal.stopped then callback() end
    end)
end

function internal.newTicker(interval, callback, iterations)
    return C_Timer.NewTicker(interval, function(ticker)
        if internal.stopped then return ticker:Cancel() end
        callback(ticker)
    end, iterations)
end

function internal.newTimer(delay, callback)
    return C_Timer.NewTimer(delay, function(timer)
        if not internal.stopped then callback(timer) end
    end)
end

function internal.hookSecureFunc(...)
    local args = { ... }
    local callback = args[#args]
    args[#args] = function(...)
        if not internal.stopped then return callback(...) end
    end
    hooksecurefunc(unpack(args))
end

function internal.hookScript(frame, script, callback)
    frame:HookScript(script, function(...)
        if not internal.stopped then return callback(...) end
    end)
end

FarstriderLibData.VERSION = VERSION
FarstriderLibData.Internal = internal

FarstriderLibData.IS_FOREVER = WOW_PROJECT_ID == WOW_PROJECT_CAMELOT
FarstriderLibData.EXPANSION_LEVEL = FarstriderLibData.IS_FOREVER and 0 or GetExpansionLevel()
FarstriderLibData.CLASSIC_WORLD = FarstriderLibData.IS_FOREVER or WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE
FarstriderLibData.CLASSIC_UI_MAPS = FarstriderLibData.CLASSIC_WORLD and FarstriderLibData.EXPANSION_LEVEL < 4
