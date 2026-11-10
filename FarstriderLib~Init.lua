-- FarstriderLib~Init.lua
-- local _, FarstriderLib = ...

local VERSION = 10404

local lib = FarstriderLib_API
if lib and lib.VERSION and (lib.VERSION >= VERSION or not lib.Shutdown) then return end
if lib and lib.Shutdown then
    lib.Shutdown()
end
lib = lib or {}
FarstriderLib_API = lib

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

FarstriderLib.VERSION = VERSION
FarstriderLib.Internal = internal

-- ── Auto-detect the Interface path to this library folder ────────────
-- debugstack() returns "path/to/file.lua:line: ..." when the chunk loads.
-- We strip the filename to get the directory, which lets media references
-- work regardless of which addon embeds FL.
do
    local stack = debugstack(1, 1, 0) or ""
    local dir = stack:match("^(.+[/\\])FarstriderLib~Init%.lua") or ""
    -- Normalise to backslash (WoW media paths use backslashes)
    dir = dir:gsub("/", "\\")
    -- Strip everything before "Interface\" — PlaySoundFile / SetFont
    -- require paths rooted at "Interface\\" not the full disk path.
    dir = dir:gsub("^.*(Interface\\)", "%1")
    --- Base Interface path to this FarstriderLib folder (trailing backslash).
    --- Example: "Interface\\AddOns\\FarstriderLib\\"
    ---@type string
    FarstriderLib.media_path = dir
end
