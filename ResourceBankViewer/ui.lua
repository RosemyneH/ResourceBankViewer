RBV = RBV or {}
RBV.UI = RBV.UI or {}

local ITEM_QUALITY_COLORS = _G.ITEM_QUALITY_COLORS

local BASE_ROWS = 10
local ROW_HEIGHT = 18

local MIN_W, MIN_H = 300, 210
local MAX_W, MAX_H = 700, 600

local function FormatNumber(n)
  n = tonumber(n) or 0
  if n > 10000 then
    local k = math.floor((n + 500) / 1000)
    return tostring(k) .. "K"
  end
  local s = tostring(math.floor(n + 0.5))
  local out = s
  local k
  while true do
    out, k = out:gsub("^(%-?%d+)(%d%d%d)", "%1,%2")
    if k == 0 then break end
  end
  return out
end

local function Clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function TextColorForQuality(q)
  local qc = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q or 0]
  if qc then return qc.r, qc.g, qc.b end
  return 1, 1, 1
end

local function GetElvUIFont()
  local E = _G.ElvUI
  if type(E) == "table" and type(E.media) == "table" and E.media.normFont then
    return E.media.normFont
  end
  return nil
end

local function ApplyBackdrop(frame)
  frame:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  frame:SetBackdropColor(0.06, 0.06, 0.06, 0.92)
  frame:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
end

local function CreateButton(parent, text)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetText(text)
  b:SetHeight(18)
  return b
end

local function CreateRow(parent)
  local row = CreateFrame("Button", nil, parent)
  row:SetHeight(ROW_HEIGHT)
  row:SetHighlightTexture("Interface/QuestFrame/UI-QuestTitleHighlight")
  row:RegisterForClicks("AnyUp")

  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(16,16)
  row.icon:SetPoint("LEFT", row, "LEFT", 4, 0)
  row.icon:SetTexture("Interface/Icons/INV_Misc_QuestionMark")

  row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
  row.name:SetJustifyH("LEFT")

  row.total = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.total:SetJustifyH("RIGHT")

  row.session = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.session:SetJustifyH("LEFT")

  row:SetScript("OnEnter", function(self)
    if self.itemId then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetHyperlink("item:"..self.itemId)
      GameTooltip:Show()
    end
  end)
  row:SetScript("OnLeave", function() GameTooltip:Hide() end)
  row:SetScript("OnClick", function(self)
    if not self.itemId or not IsAltKeyDown() then return end
    if type(OpenLootDb) == "function" then
      OpenLootDb(self.itemId)
    end
  end)

  return row
end

local function VisibleRowsFromHeight(h)
  local usable = h - 80
  local rows = math.floor(usable / ROW_HEIGHT)
  return Clamp(rows, 5, 25)
end

local function ApplyFonts()
  local ui = RBV.UI
  if not ui.frame then return end
  local fontPath = ui.fontPath
  local size = (RBVDB and RBVDB.ui and RBVDB.ui.fontSize) or 11
  if fontPath then
    ui.title:SetFont(fontPath, size+1, "OUTLINE")
    ui.hItem:SetFont(fontPath, size)
    ui.hTotal:SetFont(fontPath, size)
    ui.hSession:SetFont(fontPath, size)
    ui.emptyText:SetFont(fontPath, size)
    if ui.searchLabel then ui.searchLabel:SetFont(fontPath, size) end
    for _, row in ipairs(ui.rows) do
      row.name:SetFont(fontPath, size)
      row.total:SetFont(fontPath, size)
      row.session:SetFont(fontPath, size)
    end
  end
end

local function UpdateHeaderIndicators()
  local ui = RBV.UI
  local key = (RBVDB and RBVDB.sort and RBVDB.sort.key) or "count"
  local asc = (RBVDB and RBVDB.sort and RBVDB.sort.asc) or false
  local arrow = asc and " ^" or " v"
  ui.hTotal:SetText("Total" .. ((key=="count") and arrow or ""))
  ui.hSession:SetText("Session" .. ((key=="gained") and arrow or ""))
end

local function ApplyLayout()
  local ui = RBV.UI
  local f = ui.frame

  RBVDB.ui = RBVDB.ui or {}
  local w = Clamp(RBVDB.ui.w or 360, MIN_W, MAX_W)
  local h = Clamp(RBVDB.ui.h or 250, MIN_H, MAX_H)
  RBVDB.ui.w, RBVDB.ui.h = w, h

  f:SetSize(w, h)

  local rightPad = 28
  local sessionW = 70
  local totalW = 60
  local gap = 6
  local nameW = w - (rightPad + sessionW + totalW + 40)
  if nameW < 120 then nameW = 120 end

  ui.hItem:ClearAllPoints(); ui.hItem:SetPoint("TOPLEFT", f, "TOPLEFT", 28, -28)
  ui.hItem:SetJustifyH("LEFT")

  ui.hTotal:ClearAllPoints(); ui.hTotal:SetPoint("TOPLEFT", f, "TOPLEFT", w - (rightPad + sessionW + totalW) + 8, -28)
  ui.hTotal:SetJustifyH("LEFT")

  -- Put Session header inside the same fixed-width region used by values
  ui.hSession:ClearAllPoints(); ui.hSession:SetPoint("TOPRIGHT", f, "TOPRIGHT", -rightPad, -28)
  ui.hSession:SetWidth(sessionW)
  ui.hSession:SetJustifyH("LEFT")

  if ui.searchLabel and ui.searchBox and ui.clearBtn then
    ui.searchLabel:ClearAllPoints(); ui.searchLabel:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 10)
    ui.searchBox:ClearAllPoints(); ui.searchBox:SetPoint("LEFT", ui.searchLabel, "RIGHT", 6, 0)
    ui.searchBox:SetHeight(18)
    ui.searchBox:SetWidth(math.min(200, w - 180))
    ui.clearBtn:ClearAllPoints(); ui.clearBtn:SetPoint("LEFT", ui.searchBox, "RIGHT", 6, 0)
    ui.clearBtn:SetWidth(44)
  end

  if ui.btnTotal then
    ui.btnTotal:ClearAllPoints()
    ui.btnTotal:SetPoint("TOPLEFT", ui.hTotal, "TOPLEFT", -2, 2)
    ui.btnTotal:SetPoint("BOTTOMRIGHT", ui.hTotal, "BOTTOMRIGHT", 18, -2)
  end
  if ui.btnSession then
    ui.btnSession:ClearAllPoints()
    ui.btnSession:SetPoint("TOPLEFT", ui.hSession, "TOPLEFT", -2, 2)
    ui.btnSession:SetPoint("BOTTOMRIGHT", ui.hSession, "BOTTOMRIGHT", 18, -2)
  end

  ui.scroll:ClearAllPoints()
  ui.scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -44)
  ui.scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -rightPad, 34)

  ui.visibleRows = VisibleRowsFromHeight(h)

  while #ui.rows < ui.visibleRows do
    table.insert(ui.rows, CreateRow(f))
  end

  for i, row in ipairs(ui.rows) do
    if i == 1 then
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -44)
      row:SetPoint("TOPRIGHT", f, "TOPRIGHT", -rightPad, -44)
    else
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", ui.rows[i-1], "BOTTOMLEFT", 0, 0)
      row:SetPoint("TOPRIGHT", ui.rows[i-1], "BOTTOMRIGHT", 0, 0)
    end

    row.name:SetWidth(nameW)

    row.total:ClearAllPoints(); row.total:SetPoint("RIGHT", row, "RIGHT", -(rightPad + sessionW - gap), 0)
    row.total:SetWidth(totalW)

    -- Session values in same fixed-width region as header
    row.session:ClearAllPoints(); row.session:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.session:SetWidth(sessionW)
    row.session:SetJustifyH("LEFT")

    if i <= ui.visibleRows then row:Show() else row:Hide() end
  end

  UpdateHeaderIndicators()
  ApplyFonts()
end

local function UpdateRows(resetScroll)
  local ui = RBV.UI
  if not ui.frame or not ui.frame:IsShown() then return end

  local entries = RBV.GetSortedEntries()

  local watchedN = (RBV.GetWatchedItemIds and #RBV.GetWatchedItemIds()) or 0
  if watchedN == 0 then
    ui.emptyText:SetText("No item ids — edit preset_itemids.lua or /rbv scrape add (extraIds)")
  else
    ui.emptyText:SetText("No matches")
  end

  local scroll = ui.scroll
  local offset = FauxScrollFrame_GetOffset(scroll)
  local total = #entries
  local visible = ui.visibleRows or BASE_ROWS

  if offset > total then
    scroll:SetVerticalScroll(0)
    FauxScrollFrame_SetOffset(scroll, 0)
    offset = 0
  end

  FauxScrollFrame_Update(scroll, total, visible, ROW_HEIGHT)

  for i = 1, visible do
    local idx = i + offset
    local row = ui.rows[i]
    if idx <= total then
      local e = entries[idx]
      row.itemId = e.id
      local iname, iqual = RBV.ResolveItemDisplay(e.id)
      row.name:SetText(iname)
      row.name:SetTextColor(TextColorForQuality(iqual))
      row.total:SetText(FormatNumber(e.count))
      if e.count > 0 then
        row.total:SetTextColor(0.92, 0.92, 0.78)
      else
        row.total:SetTextColor(0.55, 0.55, 0.55)
      end
      if e.gained > 0 then
        row.session:SetText("+"..FormatNumber(e.gained))
        row.session:SetTextColor(0.2, 1.0, 0.2)
      else
        row.session:SetText(FormatNumber(0))
        row.session:SetTextColor(0.8, 0.8, 0.8)
      end
      local tex = GetItemIcon(e.id)
      row.icon:SetTexture(tex or "Interface/Icons/INV_Misc_QuestionMark")
      row:Show()
    else
      row.itemId = nil
      row:Hide()
    end
  end

  if total == 0 then ui.emptyText:Show() else ui.emptyText:Hide() end
end

function RBV.UI.Update(resetScroll) UpdateRows(resetScroll) end
function RBV.UI.ApplySettings() ApplyLayout(); UpdateRows(false) end

function RBV.UI.Toggle()
  local f = RBV.UI.frame
  if not f then return end
  if f:IsShown() then
    if RBV.InvalidateBankCache then RBV.InvalidateBankCache() end
    f:Hide()
  else
    f:Show()
    RBV.UI.ApplySettings()
    if RBV.UI.searchBox then
      RBV.UI.searchBox:SetFocus()
      RBV.UI.searchBox:HighlightText()
    end
  end
end

local function SetSort(key)
  RBVDB.sort = RBVDB.sort or { key = "count", asc = false }
  if RBVDB.sort.key == key then RBVDB.sort.asc = not RBVDB.sort.asc else RBVDB.sort.key = key; RBVDB.sort.asc = false end
  UpdateHeaderIndicators()
  UpdateRows(true)
end

local function SetFilter(text)
  RBVDB.filter = tostring(text or "")
  UpdateRows(true)
end

function RBV.UI.Create()
  if RBV.UI.frame then return end

  RBVDB.ui = RBVDB.ui or { w = 360, h = 250, fontSize = 11 }
  RBVDB.sort = RBVDB.sort or { key = "count", asc = false }
  RBVDB.filter = RBVDB.filter or ""

  local fontPath = GetElvUIFont()

  local f = CreateFrame("Frame", "RBV_Frame", UIParent)
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self) self:StartMoving() end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint(1)
    RBVDB.pos = { point = point, relPoint = relPoint, x = x, y = y }
  end)

  f:SetResizable(true)
  if f.SetMinResize then f:SetMinResize(MIN_W, MIN_H) end
  if f.SetMaxResize then f:SetMaxResize(MAX_W, MAX_H) end
  f:SetScript("OnSizeChanged", function(self, w, h)
    RBVDB.ui.w = Clamp(w, MIN_W, MAX_W)
    RBVDB.ui.h = Clamp(h, MIN_H, MAX_H)
    RBV.UI.ApplySettings()
  end)

  ApplyBackdrop(f)

  local p = RBVDB and RBVDB.pos
  if p then f:SetPoint(p.point or "CENTER", UIParent, p.relPoint or "CENTER", p.x or 0, p.y or 0) else f:SetPoint("CENTER") end

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -8)
  title:SetText("Resource Bank Viewer")

  local h1 = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  h1:SetText("Item")
  h1:SetJustifyH("LEFT")

  local h2 = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  h2:SetText("Total")
  h2:SetJustifyH("LEFT")

  local h3 = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  h3:SetText("Session")
  h3:SetJustifyH("LEFT")

  local btnTotal = CreateFrame("Button", nil, f)
  btnTotal:EnableMouse(true)
  btnTotal:SetScript("OnClick", function() SetSort("count") end)
  btnTotal:SetHighlightTexture("Interface/QuestFrame/UI-QuestTitleHighlight")

  local btnSession = CreateFrame("Button", nil, f)
  btnSession:EnableMouse(true)
  btnSession:SetScript("OnClick", function() SetSort("gained") end)
  btnSession:SetHighlightTexture("Interface/QuestFrame/UI-QuestTitleHighlight")

  local reset = CreateButton(f, "Reset")
  reset:SetWidth(60)
  reset:SetPoint("TOPRIGHT", f, "TOPRIGHT", -28, -6)
  reset:SetScript("OnClick", function() if RBV.ResetBaseline then RBV.ResetBaseline(true) end end)

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)

  local scroll = CreateFrame("ScrollFrame", "RBV_Scroll", f, "FauxScrollFrameTemplate")
  scroll:SetScript("OnVerticalScroll", function(self, offset)
    FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, function() UpdateRows(false) end)
  end)

  local searchLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  searchLabel:SetText("Search:")

  local searchBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
  searchBox:SetAutoFocus(false)
  searchBox:SetText(RBVDB.filter or "")
  searchBox:SetScript("OnTextChanged", function(self) SetFilter(self:GetText() or "") end)
  searchBox:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus(); SetFilter("") end)
  searchBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

  local clearBtn = CreateButton(f, "Clear")
  clearBtn:SetScript("OnClick", function() searchBox:SetText(""); SetFilter("") end)

  local grip = CreateFrame("Button", nil, f)
  grip:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4, 4)
  grip:SetSize(16, 16)
  grip:SetNormalTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Up")
  grip:SetHighlightTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Highlight")
  grip:SetPushedTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Down")
  grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
  grip:SetScript("OnMouseUp", function() f:StopMovingOrSizing() end)

  local emptyText = f:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  emptyText:SetPoint("CENTER", f, "CENTER", 0, -10)
  emptyText:SetText("No matches")
  emptyText:Hide()

  f.elapsed = 0
  f:SetScript("OnShow", function()
    if RBV.UI and RBV.UI.searchBox then
      RBV.UI.searchBox:SetFocus()
      RBV.UI.searchBox:HighlightText()
    end
  end)
  f:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    local interval = (RBVDB and RBVDB.updateInterval) or 2.0
    if self.elapsed >= interval then
      self.elapsed = 0
      UpdateRows(false)
    end
  end)

  RBV.UI.frame = f
  RBV.UI.scroll = scroll
  RBV.UI.rows = {}
  RBV.UI.emptyText = emptyText
  RBV.UI.fontPath = fontPath
  RBV.UI.title = title
  RBV.UI.hItem = h1
  RBV.UI.hTotal = h2
  RBV.UI.hSession = h3
  RBV.UI.btnTotal = btnTotal
  RBV.UI.btnSession = btnSession
  RBV.UI.searchLabel = searchLabel
  RBV.UI.searchBox = searchBox
  RBV.UI.clearBtn = clearBtn

  ApplyLayout()
  f:Hide()
end
