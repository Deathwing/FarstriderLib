-- WaypointTest_Logger.lua
-- local _, WPT = ...

local Logger         = {}
WPT.Logger           = Logger

-- internal state
Logger.frame         = nil
Logger.scrollFrame   = nil
Logger.editBox       = nil
Logger.messageQueue  = {}
Logger.linesPerFrame = 50
Logger.lineCount     = 0

-- helper: RGB → hex
local function rgbToHex(r, g, b)
  return string.format("%02x%02x%02x",
    math.floor(r * 255 + 0.5),
    math.floor(g * 255 + 0.5),
    math.floor(b * 255 + 0.5)
  )
end

-- helper: concatenate varargs (uses spaces)
local function concatArgs(sep, ...)
  local n, t = select("#", ...), {}
  for i = 1, n do
    t[i] = tostring(select(i, ...))
  end
  return table.concat(t, sep)
end

function Logger:CreateLogWindow()
  if self.frame then return end

  -- Main draggable / resizable frame
  local f = CreateFrame("Frame", "WaypointTestLoggerFrame", UIParent)
  f:SetSize(500, 300)
  f:SetPoint("CENTER")
  f:EnableMouse(true); f:SetMovable(true); f:SetResizable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

  -- Dark translucent background
  local bg = f:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(f)
  bg:SetColorTexture(0, 0, 0, 0.8)

  -- ScrollFrame + built‑in scrollbar
  local scroll = CreateFrame(
    "ScrollFrame",
    "WaypointTestLoggerScrollFrame",
    f,
    "UIPanelScrollFrameTemplate"
  )
  scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -40)
  scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -30, 10)

  -- EditBox for selectable, read‑only text
  local edit = CreateFrame("EditBox", "WaypointTestLoggerEditBox", scroll)
  edit:SetMultiLine(true)
  edit:SetFontObject(GameFontNormal)
  edit:EnableMouse(true)
  edit:SetAutoFocus(false)
  edit:EnableKeyboard(true)              -- allow Ctrl‑C
  if edit.SetPropagateKeyboardInput then
    edit:SetPropagateKeyboardInput(true) -- movement keys still pass through
  end
  scroll:SetScrollChild(edit)

  -- OnSizeChanged handler (clamp & resize children)
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

  -- Drag‑resize grip
  local grip = CreateFrame("Button", "WaypointTestLoggerResizer", f)
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

  -- Copy All button
  local copyBtn = CreateFrame("Button", "WaypointTestLoggerCopyAll", f, "UIPanelButtonTemplate")
  copyBtn:SetSize(70, 20)
  copyBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -10)
  copyBtn:SetText("Copy All")
  copyBtn:SetScript("OnClick", function()
    edit:HighlightText() -- highlight all
    edit:SetFocus()      -- so Ctrl‑C will copy it
  end)

  -- Clear All button
  local clearBtn = CreateFrame("Button", "WaypointTestLoggerClearAll", f, "UIPanelButtonTemplate")
  clearBtn:SetSize(70, 20)
  clearBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -90, -10)
  clearBtn:SetText("Clear All")
  clearBtn:SetScript("OnClick", function()
    edit:SetText("")
  end)

  function ClearLogs()
    edit:SetText("")
    self.lineCount = 0
    self.messageQueue = {}
  end

  -- OnUpdate flushes queued lines
  f:SetScript("OnUpdate", function() Logger:FlushQueue() end)

  -- show right away
  -- f:Show()
  f:Hide()

  -- store refs
  self.frame       = f
  self.scrollFrame = scroll
  self.editBox     = edit
end

function Logger:EnsureWindow()
  if not self.frame then
    self:CreateLogWindow()
  end
end

function Logger:EnqueueLine(text, r, g, b)
  self:EnsureWindow()
  -- if not self.frame:IsShown() then
  --   self.frame:Show()
  -- end
  table.insert(self.messageQueue, { text = text, r = r, g = g, b = b })
end

function Logger:FlushQueue()
  if #self.messageQueue == 0 then return end
  self:EnsureWindow()

  local scroll, edit = self.scrollFrame, self.editBox

  for i = 1, self.linesPerFrame do
    local entry = table.remove(self.messageQueue, 1)
    if not entry then break end

    self.lineCount = self.lineCount + 1
    local numbered = string.format("%4d: %s", self.lineCount, entry.text)
    -- build a format string like "%04d: %s" (zero‑padded) or "%   4d: %s" (space‑padded)
    local w        = Logger.numberWidth
    -- zero‑pad to width w:
    local fmt      = string.format("%%%dd: %%s", w)
    local numbered = string.format(fmt, self.lineCount, entry.text)

    local hex      = rgbToHex(entry.r, entry.g, entry.b)
    local colored  = ("|cff%s%s|r\n"):format(hex, numbered)

    edit:SetText((edit:GetText() or "") .. colored)
    scroll:SetVerticalScroll(scroll:GetVerticalScrollRange())
  end
end

-- Public API
function Logger:Log(...) self:EnqueueLine(concatArgs(" ", ...), 1, 1, 1) end

function Logger:Info(...) self:EnqueueLine(concatArgs(" ", ...), 0.2, 0.6, 1) end

function Logger:InfoGreen(...) self:EnqueueLine(concatArgs(" ", ...), 0.2, 1, 0.2) end

function Logger:Warning(...) self:EnqueueLine(concatArgs(" ", ...), 1, 0.6, 0) end

function Logger:Error(...) self:EnqueueLine(concatArgs(" ", ...), 1, 0.2, 0.2) end

-- Slash command to toggle
SLASH_MYLOGGER1 = "/mylog"
SlashCmdList.MYLOGGER = function()
  if not Logger.frame then
    Logger:CreateLogWindow()
  elseif Logger.frame:IsShown() then
    Logger.frame:Hide()
  else
    Logger.frame:Show()
  end
end
