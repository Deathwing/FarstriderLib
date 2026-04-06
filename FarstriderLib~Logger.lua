-- FarstriderLib~Logger.lua
-- Scrollable in-game log window for debug builds.
-- Entire file is stripped by MRP_REMOVE_LINE in production.
-- Toggle with /fslog.

---@class Logger
---@field frame Frame?
---@field scrollFrame ScrollFrame?
---@field editBox EditBox?
---@field messageQueue { text: string, r: number, g: number, b: number }[]
---@field linesPerFrame number  Max lines to flush per OnUpdate
---@field lineCount number      Running total of logged lines
---@field numberWidth number    Digit width for line-number padding
local Logger         = {}
FarstriderLib.Logger = Logger

Logger.frame         = nil
Logger.scrollFrame   = nil
Logger.editBox       = nil
Logger.messageQueue  = {}
Logger.linesPerFrame = 50
Logger.lineCount     = 0
Logger.numberWidth   = 4

--- Convert 0-1 RGB floats to a 6-character hex string.
---@param r number
---@param g number
---@param b number
---@return string
local function rgbToHex(r, g, b)
    return string.format("%02x%02x%02x",
        math.floor(r * 255 + 0.5),
        math.floor(g * 255 + 0.5),
        math.floor(b * 255 + 0.5)
    )
end

--- Concatenate varargs into a single string.
---@param sep string
---@param ... any
---@return string
local function concatArgs(sep, ...)
    local n, t = select("#", ...), {}
    for i = 1, n do
        t[i] = tostring(select(i, ...))
    end
    return table.concat(t, sep)
end

--- Create the draggable, resizable log window (lazy; called on first message).
function Logger:CreateLogWindow()
    if self.frame then return end

    local f = CreateFrame("Frame", "FarstriderLibLoggerFrame", UIParent)
    f:SetSize(500, 300)
    f:SetPoint("CENTER")
    f:EnableMouse(true); f:SetMovable(true); f:SetResizable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(f)
    bg:SetColorTexture(0, 0, 0, 0.8)

    local scroll = CreateFrame("ScrollFrame", "FarstriderLibLoggerScrollFrame", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -40)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -30, 10)

    local edit = CreateFrame("EditBox", "FarstriderLibLoggerEditBox", scroll)
    edit:SetMultiLine(true)
    edit:SetFontObject(GameFontNormal)
    edit:EnableMouse(true)
    edit:SetAutoFocus(false)
    edit:EnableKeyboard(true)
    if edit.SetPropagateKeyboardInput then
        edit:SetPropagateKeyboardInput(true)
    end
    scroll:SetScrollChild(edit)

    local function OnSize(self, w, h)
        local minW, minH = 200, 100
        w = math.max(w, minW); h = math.max(h, minH)
        self:SetSize(w, h)
        scroll:SetSize(w - 30, h - 20)
        edit:SetSize(w - 30, h - 20)
    end
    f:SetScript("OnSizeChanged", OnSize)
    do
        local w, h = f:GetSize()
        OnSize(f, w, h)
    end

    local grip = CreateFrame("Button", "FarstriderLibLoggerResizer", f)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", f, -4, 4)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:RegisterForDrag("LeftButton")
    grip:SetScript("OnDragStart", function() f:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        local w, h = f:GetSize()
        OnSize(f, w, h)
    end)

    local copyBtn = CreateFrame("Button", "FarstriderLibLoggerCopyAll", f, "UIPanelButtonTemplate")
    copyBtn:SetSize(70, 20)
    copyBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -10)
    copyBtn:SetText("Copy All")
    copyBtn:SetScript("OnClick", function()
        edit:HighlightText()
        edit:SetFocus()
    end)

    local clearBtn = CreateFrame("Button", "FarstriderLibLoggerClearAll", f, "UIPanelButtonTemplate")
    clearBtn:SetSize(70, 20)
    clearBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -90, -10)
    clearBtn:SetText("Clear All")
    clearBtn:SetScript("OnClick", function()
        edit:SetText("")
        Logger.lineCount = 0
        Logger.messageQueue = {}
    end)

    f:SetScript("OnUpdate", function() Logger:FlushQueue() end)

    f:Hide()

    self.frame       = f
    self.scrollFrame = scroll
    self.editBox     = edit
end

--- Ensure the log window frame exists.
function Logger:EnsureWindow()
    if not self.frame then
        self:CreateLogWindow()
    end
end

--- Queue a colored line for display on the next OnUpdate.
---@param text string
---@param r number  Red   (0-1)
---@param g number  Green (0-1)
---@param b number  Blue  (0-1)
function Logger:EnqueueLine(text, r, g, b)
    self:EnsureWindow()
    table.insert(self.messageQueue, { text = text, r = r, g = g, b = b })
end

--- Flush up to `linesPerFrame` queued messages into the edit box.
function Logger:FlushQueue()
    if #self.messageQueue == 0 then return end
    self:EnsureWindow()

    local scroll, edit = self.scrollFrame, self.editBox

    for i = 1, self.linesPerFrame do
        local entry = table.remove(self.messageQueue, 1)
        if not entry then break end

        self.lineCount = self.lineCount + 1
        local fmt = string.format("%%%dd: %%s", self.numberWidth)
        local numbered = string.format(fmt, self.lineCount, entry.text)
        local hex = rgbToHex(entry.r, entry.g, entry.b)
        local colored = ("|cff%s%s|r\n"):format(hex, numbered)

        if edit then edit:SetText((edit:GetText() or "") .. colored) end
        if scroll then scroll:SetVerticalScroll(scroll:GetVerticalScrollRange()) end
    end
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

--- Log a white message.
function Logger:Log(...) self:EnqueueLine(concatArgs(" ", ...), 1, 1, 1) end

--- Log a blue informational message.
function Logger:Info(...) self:EnqueueLine(concatArgs(" ", ...), 0.2, 0.6, 1) end

--- Log a green informational message.
function Logger:InfoGreen(...) self:EnqueueLine(concatArgs(" ", ...), 0.2, 1, 0.2) end

--- Log an orange warning.
function Logger:Warning(...) self:EnqueueLine(concatArgs(" ", ...), 1, 0.6, 0) end

--- Log a red error.
function Logger:Error(...) self:EnqueueLine(concatArgs(" ", ...), 1, 0.2, 0.2) end

-- Slash command to toggle
SLASH_FARSTRIDERLOG1 = "/fslog"
SlashCmdList.FARSTRIDERLOG = function()
    if not Logger.frame then
        Logger:CreateLogWindow()
    elseif Logger.frame:IsShown() then
        Logger.frame:Hide()
    else
        Logger.frame:Show()
    end
end
