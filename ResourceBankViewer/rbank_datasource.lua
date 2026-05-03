RBV = RBV or {}

RBV.PRESET_ITEM_IDS = RBV.PRESET_ITEM_IDS or {}

RBV.SCRAPE_MAX_LINES = 500

local wipe = wipe or function(t)
  for k in pairs(t) do t[k] = nil end
end

RBV._bankCountsArena = RBV._bankCountsArena or {}
RBV._sortArena = RBV._sortArena or {}
RBV._entryPool = RBV._entryPool or {}
RBV._sortArenaLen = 0

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
  local now = GetTime()
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
  if not itemId then return nil end
  local v = GetCustomGameData(13, itemId)
  if v == nil then return nil end
  return math.floor(v + 0.5)
end

function RBV.NotifyWithdraw(itemId)
  if not itemId or itemId == 0 then return end
  pcall(NotifyServer, 2, 7, itemId)
  RBV.InvalidateBankCache()
end

function RBV.NotifyDeposit(itemId)
  if not itemId or itemId == 0 then return end
  pcall(NotifyServer, 2, 8, itemId)
  RBV.InvalidateBankCache()
end

function RBV.NotifyDepositAll()
  pcall(NotifyServer, 2, 9, "")
  RBV.InvalidateBankCache()
end

function RBV.ResolveItemDisplay(itemId)
  local name, _, quality = GetItemInfo(itemId)
  quality = quality or 0
  if (not name or name == "") and GetItemInfoCustom then
    name = GetItemInfoCustom(itemId)
  end
  if not name or name == "" then name = "Item " .. itemId end
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
    if id then set[id] = true end
  end
  if RBVDB and RBVDB.extraIds then
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
  local out = RBV._bankCountsArena
  wipe(out)
  local n = GetCustomGameDataCount(13) or 0
  for i = 1, n do
    local itemId = GetCustomGameDataIndex(13, i)
    if itemId and itemId ~= 0 then
      local c = RBV.GetResourceBankCount(itemId)
      out[itemId] = (c ~= nil) and c or 0
    end
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
  if not RBVDB or not newIds then return 0 end
  RBVDB.extraIds = RBVDB.extraIds or {}
  local presetSet = {}
  for _, id in ipairs(RBV.PRESET_ITEM_IDS or {}) do presetSet[id] = true end
  local have = {}
  for _, id in ipairs(RBVDB.extraIds) do have[id] = true end
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
  if not fn then return end
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
      if n > 0 then RBV.Print(("scrape add: saved %d new id(s) to extraIds."):format(n))
      else RBV.Print("scrape add: nothing new on frame vs your list.") end
    else
      if #missing == 0 then
        RBV.Print("scrape: no ids on RBankFrame outside preset/extraIds.")
      else
        RBV.Print(("scrape: %d id(s) not in preset/extraIds — /rbv scrape add to save to extraIds:"):format(#missing))
        local chunk = 12
        for i = 1, #missing, chunk do
          local last = math.min(i + chunk - 1, #missing)
          local parts = {}
          for j = i, last do parts[#parts + 1] = tostring(missing[j]) end
          RBV.Print(table.concat(parts, ", "))
        end
        RBV.Print("Lua: RBV.PRESET_ITEM_IDS = { " .. table.concat(missing, ", ") .. " }")
      end
    end
    RBV.InvalidateBankCache()
    if RBV.UI and RBV.UI.Update then RBV.UI.Update(true) end
  end)
end

function RBV._EntrySortCmp(a, b)
  if not a or not b then return false end
  local sortKey = RBV._sortCmpKey
  local asc = RBV._sortCmpAsc
  local av = (sortKey == "gained") and (a.gained or 0) or (a.count or 0)
  local bv = (sortKey == "gained") and (b.gained or 0) or (b.count or 0)
  if av ~= bv then
    if asc then return av < bv end
    return av > bv
  end
  return (a.id or 0) < (b.id or 0)
end

function RBV.GetSortedEntries()
  local counts = RBV.GetBankDataCached()
  local arr = RBV._sortArena
  local pool = RBV._entryPool
  local q = tostring((RBVDB and RBVDB.filter) or ""):lower()

  local n = 0
  for itemId, cnt in pairs(counts) do
    if RBV.EntryMatchesFilter(itemId, q) then
      local base = (RBVDB and RBVDB.baseline and RBVDB.baseline[itemId]) or 0
      local gained = cnt - base
      if gained < 0 then gained = 0 end
      n = n + 1
      local e = pool[n]
      if not e then
        e = {}
        pool[n] = e
      end
      e.id = itemId
      e.count = cnt
      e.gained = gained
      arr[n] = e
    end
  end

  local oldLen = RBV._sortArenaLen or 0
  RBV._sortArenaLen = n
  if n < oldLen then
    for j = n + 1, oldLen do
      arr[j] = nil
    end
  end

  RBV._sortCmpKey = (RBVDB and RBVDB.sort and RBVDB.sort.key) or "count"
  RBV._sortCmpAsc = (RBVDB and RBVDB.sort and RBVDB.sort.asc) or false
  if n > 1 then
    table.sort(arr, RBV._EntrySortCmp)
  end

  return arr
end

function RBV.ResetBaseline(printMsg)
  if not RBVDB then return end
  RBV.InvalidateBankCache()
  local now = RBV.BuildBankCounts()
  RBV._bankCache = now
  RBV._bankCacheAt = GetTime()
  RBVDB.baseline = RBVDB.baseline or {}
  wipe(RBVDB.baseline)
  for itemId, cnt in pairs(now) do
    RBVDB.baseline[itemId] = cnt
  end
  if printMsg then RBV.Print("Session counters reset.") end
  if RBV.UI and RBV.UI.Update then RBV.UI.Update(true) end
end

local _refreshFrame
function RBV.TryBackgroundRefresh()
  local f = _G["RBankFrame"]
  if not f then return false end

  local onShow = f:GetScript("OnShow")
  if onShow then pcall(onShow, f) end
  if f.cele and f.cele.upLeft then pcall(f.cele.upLeft) end

  if f:IsShown() then return true end

  if not _refreshFrame then _refreshFrame = CreateFrame("Frame") end

  local oldAlpha = f:GetAlpha()
  local oldScale = f:GetScale()
  local oldPoint = { f:GetPoint(1) }

  f:ClearAllPoints(); f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -2000, 2000)
  f:SetScale(0.01)
  f:SetAlpha(1)
  f:Show()

  _refreshFrame.elapsed = 0
  _refreshFrame:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    if self.elapsed > 0.25 then
      f:Hide()
      f:SetAlpha(oldAlpha)
      f:SetScale(oldScale)
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
  for _, id in ipairs(RBV.PRESET_ITEM_IDS or {}) do presetSet[id] = true end

  local set = {}
  if RBVDB.extraIds then
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
  if legacy then
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
