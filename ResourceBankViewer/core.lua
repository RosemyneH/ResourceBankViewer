local ADDON = ...

RBVDB = RBVDB or {}

local defaults = {
  enabled = true,
  pos = { point = "CENTER", relPoint = "CENTER", x = 0, y = 0 },
  baseline = {},
  extraIds = {},
  debug = false,
  updateInterval = 2.0,
  refreshInterval = 10.0,
  ui = { w = 360, h = 250, fontSize = 11 },
  sort = { key = "count", asc = false },
  filter = "",
}

local function CopyDefaults(src, dst)
  if type(dst) ~= "table" then dst = {} end
  for k, v in pairs(src) do
    if type(v) == "table" then
      dst[k] = CopyDefaults(v, dst[k])
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
  return dst
end

RBVDB = CopyDefaults(defaults, RBVDB)

local function Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00RBV|r: " .. tostring(msg))
end

RBV = RBV or {}
RBV.Print = Print

SLASH_RBV1 = "/rbv"
SlashCmdList["RBV"] = function(msg)
  msg = msg or ""
  local cmd, arg = msg:match("^(%S+)%s*(.-)%s*$")
  cmd = (cmd or ""):lower()
  arg = (arg or "")

  if cmd == "on" then
    RBVDB.enabled = true
    Print("Enabled")
  elseif cmd == "off" then
    RBVDB.enabled = false
    if RBV.UI and RBV.UI.frame then
      if RBV.InvalidateBankCache then RBV.InvalidateBankCache() end
      RBV.UI.frame:Hide()
    end
    Print("Disabled")
  elseif cmd == "reset" then
    if RBV.ResetBaseline then RBV.ResetBaseline(true) end
    if RBV.UI and RBV.UI.Update then RBV.UI.Update(true) end
  elseif cmd == "font" and arg ~= "" then
    local n = tonumber(arg)
    if n then
      RBVDB.ui.fontSize = math.max(8, math.min(18, math.floor(n + 0.5)))
      if RBV.UI and RBV.UI.ApplySettings then RBV.UI.ApplySettings() end
      Print("Font size = " .. tostring(RBVDB.ui.fontSize))
    end
  elseif cmd == "refresh" then
    if RBV.TryBackgroundRefresh then RBV.TryBackgroundRefresh() end
    if RBV.InvalidateBankCache then RBV.InvalidateBankCache() end
    if RBV.UI and RBV.UI.Update then RBV.UI.Update(false) end
  elseif cmd == "scrape" then
    if RBV.DoScrapeCommand then RBV.DoScrapeCommand(arg) end
  elseif cmd == "ids" then
    Print(("Bank (custom game data 13): %d unique item slot(s)."):format(GetCustomGameDataCount(13) or 0))
  else
    if RBV.UI and RBV.UI.Toggle then RBV.UI.Toggle() end
  end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    if not RBVDB.enabled then return end
    if RBV.UI and RBV.UI.Create then RBV.UI.Create() end
    RBV._loginPending = true
    Print("Loaded. /rbv to toggle.")
  end
end)

RBV._poller = CreateFrame("Frame")
RBV._poller.elapsed = 0
RBV._poller:SetScript("OnUpdate", function(self, elapsed)
  if not (RBVDB and RBVDB.enabled) then return end
  if RBV._loginPending then
    RBV._loginPending = nil
    if RBV.ResetBaseline then RBV.ResetBaseline(false) end
    if RBV.UI and RBV.UI.Update then RBV.UI.Update(true) end
  end
  self.elapsed = self.elapsed + elapsed
  local interval = (RBVDB and RBVDB.refreshInterval) or 10.0
  if self.elapsed >= interval then
    self.elapsed = 0
    if RBV.InvalidateBankCache then RBV.InvalidateBankCache() end
    if RBV.UI and RBV.UI.Update then RBV.UI.Update(false) end
  end
end)
