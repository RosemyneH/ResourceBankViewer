RBV = RBV or {}

RBV.SCRAPE_MAX_LINES = 500

RBV._bankCache = nil
RBV._bankCacheAt = 0
RBV._watchedIdsCache = nil

function RBV.InvalidateBankCache()
  RBV._bankCache = nil
  RBV._bankCacheAt = 0
end

function RBV.InvalidateWatchedIdsCache()
  RBV._watchedIdsCache = nil
end

function RBV.GetBankDataCached()
  local now = GetTime and GetTime() or 0
  local ttl = (RBVDB and RBVDB.updateInterval) or 2.0
  if ttl < 0.5 then ttl = 0.5 end
  if RBV._bankCache and (now - RBV._bankCacheAt) < ttl then
    return RBV._bankCache
  end
  RBV._bankCache = RBV.BuildBankCounts()
  RBV._bankCacheAt = now
  return RBV._bankCache
end

function RBV.GetResourceBankCount(itemId)
  if not itemId or type(GetCustomGameData) ~= "function" then return nil end
  local ok, v = pcall(GetCustomGameData, 13, itemId)
  if ok and type(v) == "number" then return math.floor(v + 0.5) end
  return nil
end

function RBV.ResolveItemDisplay(itemId)
  local name, _, quality
  if type(GetItemInfo) == "function" then
    name, _, quality = GetItemInfo(itemId)
  end
  quality = tonumber(quality) or 0
  if (not name or name == "") and type(GetItemInfoCustom) == "function" then
    local ok, n = pcall(GetItemInfoCustom, itemId)
    if ok and type(n) == "string" and n ~= "" then name = n end
  end
  if not name or name == "" then name = "Item " .. tostring(itemId) end
  return name, quality
end

function RBV.EntryMatchesFilter(itemId, q)
  if not q or q == "" then return true end
  local name = select(1, RBV.ResolveItemDisplay(itemId))
  if tostring(name):lower():find(q, 1, true) then return true end
  return tostring(itemId):find(q, 1, true) ~= nil
end

function RBV.GetWatchedIdSet()
  local set = {}
  for _, id in ipairs(RBV.PRESET_ITEM_IDS or {}) do
    id = tonumber(id)
    if id then set[id] = true end
  end
  if RBVDB and type(RBVDB.extraIds) == "table" then
    for _, id in ipairs(RBVDB.extraIds) do
      id = tonumber(id)
      if id then set[id] = true end
    end
  end
  return set
end

function RBV.GetWatchedItemIds()
  if RBV._watchedIdsCache then return RBV._watchedIdsCache end
  local set = RBV.GetWatchedIdSet()
  local arr = {}
  for id in pairs(set) do arr[#arr + 1] = id end
  table.sort(arr)
  RBV._watchedIdsCache = arr
  return arr
end

function RBV.BuildBankCounts()
  local out = {}
  local ids = RBV.GetWatchedItemIds()
  for i = 1, #ids do
    local itemId = ids[i]
    local c = RBV.GetResourceBankCount(itemId)
    out[itemId] = (c ~= nil) and c or 0
  end
  return out
end

function RBV.ScrapeRBankLines(maxLines)
  maxLines = maxLines or RBV.SCRAPE_MAX_LINES
  local seen = {}
  local arr = {}
  for i = 1, maxLines do
    local line = _G["RBankFrame-ILine-" .. i]
    if line and line.ItemId then
      local id = tonumber(line.ItemId)
      if id and not seen[id] then
        seen[id] = true
        arr[#arr + 1] = id
      end
    end
  end
  table.sort(arr)
  return arr
end

function RBV.ExtraIdsAppend(newIds)
  if not RBVDB or type(newIds) ~= "table" then return 0 end
  RBVDB.extraIds = RBVDB.extraIds or {}
  local presetSet = {}
  for _, id in ipairs(RBV.PRESET_ITEM_IDS or {}) do presetSet[tonumber(id)] = true end
  local have = {}
  for _, id in ipairs(RBVDB.extraIds) do have[tonumber(id)] = true end
  local added = 0
  for i = 1, #newIds do
    local id = tonumber(newIds[i])
    if id and not presetSet[id] and not have[id] then
      have[id] = true
      RBVDB.extraIds[#RBVDB.extraIds + 1] = id
      added = added + 1
    end
  end
  table.sort(RBVDB.extraIds)
  RBV.InvalidateWatchedIdsCache()
  return added
end

function RBV.RunNextFrame(fn)
  if type(fn) ~= "function" then return end
  if not RBV._nextFrameFrame then
    RBV._nextFrameFrame = CreateFrame("Frame", nil, UIParent)
    RBV._nextFrameFrame:SetSize(1, 1)
    RBV._nextFrameFrame:Show()
  end
  RBV._nextFrameQueue = RBV._nextFrameQueue or {}
  RBV._nextFrameQueue[#RBV._nextFrameQueue + 1] = fn
  RBV._nextFrameFrame:SetScript("OnUpdate", function(self)
    local q = RBV._nextFrameQueue
    RBV._nextFrameQueue = {}
    self:SetScript("OnUpdate", nil)
    for j = 1, #q do pcall(q[j]) end
  end)
end

function RBV.DoScrapeCommand(sub)
  sub = tostring(sub or ""):lower():match("^(%S*)") or ""
  if RBV.TryBackgroundRefresh then RBV.TryBackgroundRefresh() end
  RBV.RunNextFrame(function()
    if not RBVDB then return end
    local onFrame = RBV.ScrapeRBankLines(RBV.SCRAPE_MAX_LINES)
    local watched = RBV.GetWatchedIdSet()
    local missing = {}
    for i = 1, #onFrame do
      local id = onFrame[i]
      if not watched[id] then missing[#missing + 1] = id end
    end
    table.sort(missing)
    if sub == "add" then
      local n = RBV.ExtraIdsAppend(missing)
      if RBV.Print then
        if n > 0 then RBV.Print(("scrape add: saved %d new id(s) to extraIds."):format(n))
        else RBV.Print("scrape add: nothing new on frame vs your list.") end
      end
    else
      if #missing == 0 then
        if RBV.Print then RBV.Print("scrape: no ids on RBankFrame outside preset/extraIds.") end
      else
        if RBV.Print then
          RBV.Print(("scrape: %d id(s) not in list — /rbv scrape add to save, or add to preset_itemids.lua:"):format(#missing))
        end
        local chunk = 12
        for i = 1, #missing, chunk do
          local last = math.min(i + chunk - 1, #missing)
          local parts = {}
          for j = i, last do parts[#parts + 1] = tostring(missing[j]) end
          if RBV.Print then RBV.Print(table.concat(parts, ", ")) end
        end
        if RBV.Print then RBV.Print("Lua: RBV.PRESET_ITEM_IDS = { " .. table.concat(missing, ", ") .. " }") end
      end
    end
    RBV.InvalidateBankCache()
    if RBV.UI and RBV.UI.Update then RBV.UI.Update(true) end
  end)
end

function RBV.GetSortedEntries()
  local counts = RBV.GetBankDataCached()
  local ids = RBV.GetWatchedItemIds()
  local arr = {}
  local q = tostring((RBVDB and RBVDB.filter) or ""):lower()

  for i = 1, #ids do
    local itemId = ids[i]
    if RBV.EntryMatchesFilter(itemId, q) then
      local cnt = counts[itemId] or 0
      local base = (RBVDB and RBVDB.baseline and RBVDB.baseline[itemId]) or 0
      local gained = cnt - base
      if gained < 0 then gained = 0 end
      arr[#arr + 1] = { id = itemId, count = cnt, gained = gained }
    end
  end

  local sortKey = (RBVDB and RBVDB.sort and RBVDB.sort.key) or "count"
  local asc = (RBVDB and RBVDB.sort and RBVDB.sort.asc) or false

  table.sort(arr, function(a, b)
    if not a or not b then return false end
    local av = (sortKey == "gained") and (a.gained or 0) or (a.count or 0)
    local bv = (sortKey == "gained") and (b.gained or 0) or (b.count or 0)
    if av ~= bv then
      if asc then return av < bv end
      return av > bv
    end
    return (a.id or 0) < (b.id or 0)
  end)

  return arr
end

function RBV.ResetBaseline(printMsg)
  if not RBVDB then return end
  RBV.InvalidateBankCache()
  local now = RBV.BuildBankCounts()
  RBV._bankCache = now
  RBV._bankCacheAt = GetTime and GetTime() or 0
  local newBase = {}
  for itemId, cnt in pairs(now) do
    newBase[itemId] = cnt
  end
  RBVDB.baseline = newBase
  if printMsg and RBV.Print then RBV.Print("Session counters reset.") end
  if RBV.UI and RBV.UI.Update then RBV.UI.Update(true) end
end

local _refreshFrame
function RBV.TryBackgroundRefresh()
  local f = _G["RBankFrame"]
  if not f or type(f.Show) ~= "function" then return false end

  local onShow = f.GetScript and f:GetScript("OnShow")
  if type(onShow) == "function" then pcall(onShow, f) end
  if f.cele and type(f.cele.upLeft) == "function" then pcall(f.cele.upLeft) end

  if f.IsShown and f:IsShown() then return true end

  if not _refreshFrame then _refreshFrame = CreateFrame("Frame") end

  local oldAlpha = f.GetAlpha and f:GetAlpha() or 1
  local oldScale = f.GetScale and f:GetScale() or 1
  local oldPoint = { f:GetPoint(1) }

  f:ClearAllPoints(); f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -2000, 2000)
  if f.SetScale then f:SetScale(0.01) end
  if f.SetAlpha then f:SetAlpha(1) end
  f:Show()

  _refreshFrame.elapsed = 0
  _refreshFrame:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    if self.elapsed > 0.25 then
      if f.Hide then f:Hide() end
      if f.SetAlpha then f:SetAlpha(oldAlpha) end
      if f.SetScale then f:SetScale(oldScale) end
      f:ClearAllPoints()
      if oldPoint[1] then f:SetPoint(unpack(oldPoint)) else f:SetPoint("CENTER") end
      self:SetScript("OnUpdate", nil)
    end
  end)
  return true
end

function RBV.MigrateLegacyStorage()
  if not RBVDB then return end
  local presetSet = {}
  for _, id in ipairs(RBV.PRESET_ITEM_IDS or {}) do presetSet[tonumber(id)] = true end

  local set = {}
  if type(RBVDB.extraIds) == "table" then
    for k, v in pairs(RBVDB.extraIds) do
      if v == true or v == 1 then
        local id = tonumber(k)
        if id then set[id] = true end
      elseif type(v) == "number" then
        local id = tonumber(v)
        if id then set[id] = true end
      end
    end
  end

  local legacy = RBVDB.itemIds
  if type(legacy) == "table" then
    for k, v in pairs(legacy) do
      local id = tonumber(k)
      if id and (v == true or v == 1) then set[id] = true end
    end
    RBVDB.itemIds = nil
  end

  local arr = {}
  for id in pairs(set) do
    if not presetSet[id] then arr[#arr + 1] = id end
  end
  table.sort(arr)
  RBVDB.extraIds = arr
  RBV.InvalidateWatchedIdsCache()
end

RBV.MigrateLegacyStorage()
