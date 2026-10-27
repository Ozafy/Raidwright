local AddonName, RaidwrightNS = ...

local C = RaidwrightNS.C
local L = LibStub("AceLocale-3.0"):GetLocale(AddonName)

local RaidwrightData = {}
RaidwrightNS.RaidwrightData = RaidwrightData

local function CharDB()
   return RaidwrightNS.RaidwrightDB.char
end

-- characters & lists

function RaidwrightData:SavePlayerDataLogin()
   local name, realm = UnitFullName("player")
   realm = realm or GetNormalizedRealmName()
   local key = name .. "-" .. realm
   local char = RaidwrightNS.RaidwrightDB.global.characters[key] or {}
   char.Name = name
   char.Realm = realm
   char.Faction = UnitFactionGroup("player")
   local className, classFile = UnitClass("player")
   char.Class = { Name = className, File = classFile }
   char.WorldBuffs = char.WorldBuffs or {}
   RaidwrightNS.RaidwrightDB.global.characters[key] = char
   RaidwrightNS.RaidwrightAddon.CurrentCharacter = char
   RaidwrightNS.RaidwrightAddon.CurrentCharacterKey = key

   local db = CharDB()
   if not db.lists then
      db.lists = {}
      for _, listName in ipairs(L["DefaultLists"]) do
         table.insert(db.lists, { name = listName, consumables = {}, outfits = {} })
      end
      db.selectedList = 1
      db.listsVersion = 2
   end
   RaidwrightData:MigrateLists(db)
end

local function CopyTable(source)
   local copy = {}
   for key, value in pairs(source) do
      copy[key] = type(value) == "table" and CopyTable(value) or value
   end
   return copy
end

-- version 2 splits Ahn'Qiraj into Ruins and Temple, both start with what the old list had
function RaidwrightData:MigrateLists(db)
   if (db.listsVersion or 1) < 2 then
      for i, list in ipairs(db.lists) do
         if list.name == L["OldAhnQiraj"] then
            local ruins = CopyTable(list)
            ruins.name = L["RuinsOfAhnQiraj"]
            list.name = L["TempleOfAhnQiraj"]
            table.insert(db.lists, i, ruins)
            if (db.selectedList or 1) > i then
               db.selectedList = db.selectedList + 1
            end
            break
         end
      end
      db.listsVersion = 2
   end
end

function RaidwrightData:GetLists()
   return CharDB().lists or {}
end

function RaidwrightData:GetSelectedIndex()
   local db = CharDB()
   local lists = self:GetLists()
   if #lists == 0 then
      return nil
   end
   if not db.selectedList or db.selectedList > #lists then
      db.selectedList = 1
   end
   return db.selectedList
end

function RaidwrightData:GetSelectedList()
   local index = self:GetSelectedIndex()
   return index and self:GetLists()[index]
end

function RaidwrightData:SelectList(index)
   CharDB().selectedList = index
end

function RaidwrightData:AddList(name)
   local lists = CharDB().lists
   table.insert(lists, { name = name, consumables = {}, outfits = {} })
   CharDB().selectedList = #lists
end

function RaidwrightData:RenameSelectedList(name)
   local list = self:GetSelectedList()
   if list then
      list.name = name
   end
end

function RaidwrightData:DeleteSelectedList()
   local index = self:GetSelectedIndex()
   if index then
      table.remove(CharDB().lists, index)
      CharDB().selectedList = math.max(1, index - 1)
   end
end

function RaidwrightData:SaveConsumable(index, itemID, count)
   local list = self:GetSelectedList()
   if not list then
      return
   end
   if index then
      list.consumables[index].itemID = itemID
      list.consumables[index].count = count
      return
   end
   -- adding an item that's already listed just updates its count
   for _, entry in ipairs(list.consumables) do
      if entry.itemID == itemID then
         entry.count = count
         return
      end
   end
   table.insert(list.consumables, { itemID = itemID, count = count })
end

-- adds the consumables of another list, items already in the selected list keep their count
function RaidwrightData:CopyConsumablesFrom(index)
   local list = self:GetSelectedList()
   local source = self:GetLists()[index]
   if not list or not source or list == source then
      return 0
   end
   local existing = {}
   for _, entry in ipairs(list.consumables) do
      existing[entry.itemID] = true
   end
   local added = 0
   for _, entry in ipairs(source.consumables) do
      if not existing[entry.itemID] then
         table.insert(list.consumables, { itemID = entry.itemID, count = entry.count })
         existing[entry.itemID] = true
         added = added + 1
      end
   end
   return added
end

-- swaps the consumable with its neighbour, delta is -1 (up) or 1 (down)
function RaidwrightData:MoveConsumable(index, delta)
   local list = self:GetSelectedList()
   local target = index + delta
   if not list or target < 1 or target > #list.consumables then
      return
   end
   list.consumables[index], list.consumables[target] = list.consumables[target], list.consumables[index]
end

function RaidwrightData:RemoveConsumable(index)
   local list = self:GetSelectedList()
   if list then
      table.remove(list.consumables, index)
   end
end

-- item counts

function RaidwrightData:GetBagIDs()
   local bags = {}
   for bag = 0, C["NumBagSlots"] do
      table.insert(bags, bag)
   end
   return bags
end

function RaidwrightData:GetBankBagIDs()
   local bags = { C["BankContainer"] }
   for bag = C["NumBagSlots"] + 1, C["NumBagSlots"] + C["NumBankBagSlots"] do
      table.insert(bags, bag)
   end
   return bags
end

local function CountContainers(bagIDs)
   local counts = {}
   for _, bag in ipairs(bagIDs) do
      for slot = 1, C_Container.GetContainerNumSlots(bag) do
         local info = C_Container.GetContainerItemInfo(bag, slot)
         if info and info.itemID then
            counts[info.itemID] = (counts[info.itemID] or 0) + info.stackCount
         end
      end
   end
   return counts
end

function RaidwrightData:GetBagCounts()
   return CountContainers(self:GetBagIDs())
end

function RaidwrightData:GetEquippedCounts()
   local counts = {}
   for slot = 1, C["EquipmentSlots"] do
      local itemID = GetInventoryItemID("player", slot)
      if itemID then
         counts[itemID] = (counts[itemID] or 0) + 1
      end
   end
   return counts
end

function RaidwrightData:ScanBank()
   CharDB().bank = CountContainers(RaidwrightData:GetBankBagIDs())
   CharDB().bankScanned = time()
   RaidwrightNS.RaidwrightAddon:RefreshFrame()
end

function RaidwrightData:ScanMail()
   local counts = {}
   for i = 1, GetInboxNumItems() do
      for j = 1, C["MaxMailAttachments"] do
         local name, itemID, texture, count = GetInboxItem(i, j)
         if itemID then
            counts[itemID] = (counts[itemID] or 0) + (count or 1)
         end
      end
   end
   CharDB().mail = counts
   CharDB().mailScanned = time()
   RaidwrightNS.RaidwrightAddon:RefreshFrame()
end

function RaidwrightData:IsSyndicatorReady()
   return Syndicator and Syndicator.API and Syndicator.API.IsReady and Syndicator.API.IsReady()
end

local function GetSyndicatorInfo(itemID)
   if not RaidwrightData:IsSyndicatorReady() then
      return nil
   end
   local ok, info = pcall(Syndicator.API.GetInventoryInfoByItemID, itemID, true, true)
   if ok and type(info) == "table" and type(info.characters) == "table" then
      return info.characters
   end
   return nil
end

-- returns where the current character has the item, plus what alts on the same realm and faction have
-- bags are always live, bank and mail come from our own scan and fall back to Syndicator's data
function RaidwrightData:GetItemCounts(itemID, bagCounts)
   bagCounts = bagCounts or self:GetBagCounts()
   local db = CharDB()
   local counts = {
      bags = bagCounts[itemID] or 0,
      bank = db.bank and db.bank[itemID] or 0,
      mail = db.mail and db.mail[itemID] or 0,
      alts = 0,
      altDetails = {},
      bankKnown = db.bank ~= nil,
   }
   local playerName = UnitName("player")
   local realm = GetNormalizedRealmName()
   local characters = GetSyndicatorInfo(itemID)
   if characters then
      for _, charInfo in ipairs(characters) do
         if charInfo.character == playerName and (charInfo.realmNormalized == nil or charInfo.realmNormalized == realm) then
            if not db.bank then
               counts.bank = charInfo.bank or 0
               counts.bankKnown = true
            end
            if not db.mail then
               counts.mail = charInfo.mail or 0
            end
         else
            local total = (charInfo.bags or 0) + (charInfo.bank or 0) + (charInfo.mail or 0)
            if total > 0 then
               counts.alts = counts.alts + total
               table.insert(counts.altDetails, {
                  name = charInfo.character,
                  classFile = charInfo.className,
                  bags = charInfo.bags or 0,
                  bank = charInfo.bank or 0,
                  mail = charInfo.mail or 0,
               })
            end
         end
      end
   end
   return counts
end

-- consumables

function RaidwrightData:GetConsumableStatus(entry, counts)
   local need = entry.count or 0
   local status = { short = 0 }
   if counts.bags >= need then
      status.text = L["StatusOK"]
      status.r, status.g, status.b = 0, 1, 0
      return status
   end
   local short = need - counts.bags
   status.short = short
   local parts = { L["StatusShort"]:format(short) }
   local remaining = short
   if counts.bank > 0 then
      table.insert(parts, L["StatusInBank"]:format(math.min(counts.bank, remaining)))
      remaining = remaining - math.min(counts.bank, remaining)
   end
   if remaining > 0 and counts.mail > 0 then
      table.insert(parts, L["StatusInMail"]:format(math.min(counts.mail, remaining)))
      remaining = remaining - math.min(counts.mail, remaining)
   end
   if remaining > 0 and counts.alts > 0 then
      table.insert(parts, L["StatusOnAlts"]:format(math.min(counts.alts, remaining)))
      remaining = remaining - math.min(counts.alts, remaining)
   end
   status.text = table.concat(parts, ", ")
   if remaining == 0 and counts.bags + counts.bank + counts.mail >= need then
      status.state = "bank"
      status.r, status.g, status.b = 1, 0.82, 0 -- you have it, just not in your bags
   elseif remaining == 0 then
      status.state = "alts"
      status.r, status.g, status.b = 1, 0.5, 0 -- an alt can send it
   else
      status.state = "missing"
      status.r, status.g, status.b = 1, 0.1, 0.1
   end
   return status
end

function RaidwrightData:GetShortConsumables(list)
   local result = {}
   local bagCounts = self:GetBagCounts()
   for _, entry in ipairs(list.consumables) do
      local counts = self:GetItemCounts(entry.itemID, bagCounts)
      local status = self:GetConsumableStatus(entry, counts)
      if status.short > 0 then
         table.insert(result, { itemID = entry.itemID, status = status, counts = counts })
      end
   end
   return result
end

-- readiness of a list per category, states from good to bad:
-- "none" (nothing to check), "ready", "bank" (bank or mail), "alts", "missing"
local STATE_SEVERITY = { none = 0, ready = 1, bank = 2, alts = 3, missing = 4 }

local function WorseState(a, b)
   return STATE_SEVERITY[b] > STATE_SEVERITY[a] and b or a
end
RaidwrightData.WorseState = WorseState

function RaidwrightData:GetListReadiness(list, bagCounts, equippedCounts)
   bagCounts = bagCounts or self:GetBagCounts()
   equippedCounts = equippedCounts or self:GetEquippedCounts()

   local consumables = { state = "none", total = #list.consumables, short = {} }
   if #list.consumables > 0 then
      consumables.state = "ready"
   end
   for _, entry in ipairs(list.consumables) do
      local status = self:GetConsumableStatus(entry, self:GetItemCounts(entry.itemID, bagCounts))
      if status.short > 0 then
         table.insert(consumables.short, { itemID = entry.itemID, status = status })
         consumables.state = WorseState(consumables.state, status.state)
      end
   end

   local outfits = { state = "none", total = 0, inBank = 0, missing = 0, names = {} }
   for outfitName in pairs(list.outfits or {}) do
      local outfit = self:GetOutfitByName(outfitName)
      if outfit then
         local status = self:GetOutfitStatus(outfit, bagCounts, equippedCounts)
         local state = "ready"
         if status.missing > 0 then
            state = "missing"
         elseif status.inBank > 0 then
            state = "bank"
         end
         table.insert(outfits.names, { name = outfitName, state = state, inBank = status.inBank, missing = status.missing })
         outfits.total = outfits.total + 1
         outfits.inBank = outfits.inBank + status.inBank
         outfits.missing = outfits.missing + status.missing
         outfits.state = WorseState(outfits.state == "none" and "ready" or outfits.state, state)
      end
   end
   table.sort(outfits.names, function(a, b) return a.name < b.name end)

   return {
      consumables = consumables,
      outfits = outfits,
      state = WorseState(consumables.state, outfits.state),
   }
end

-- outfits (Outfitter keeps its outfits per character, so we keep a snapshot for when it isn't loaded)

function RaidwrightData:GetOutfitterState()
   if not Outfitter or not Outfitter.Settings then
      return "missing"
   end
   if Outfitter.IsInitialized and not Outfitter:IsInitialized() then
      return "loading"
   end
   return "ready"
end

-- Outfitter slot name (e.g. "Finger0Slot") to inventory slot id, nil when unknown
function RaidwrightData:GetSlotID(slotName)
   local ok, slotID = pcall(GetInventorySlotInfo, slotName)
   return ok and slotID or nil
end

function RaidwrightData:SnapshotOutfits()
   if self:GetOutfitterState() ~= "ready" or not Outfitter.Settings.Outfits then
      return
   end
   local outfits = {}
   local categoryOrder = Outfitter.GetCategoryOrder and Outfitter:GetCategoryOrder() or {}
   local seen = {}
   local function AddCategory(categoryID)
      if seen[categoryID] then
         return
      end
      seen[categoryID] = true
      for _, outfit in ipairs(Outfitter.Settings.Outfits[categoryID] or {}) do
         if outfit.Name and outfit.Items then
            local items = {}
            for slotName, item in pairs(outfit.Items) do
               local itemID = tonumber(item.Code)
               if itemID and itemID > 0 then
                  table.insert(items, { slot = slotName, slotID = self:GetSlotID(slotName), itemID = itemID })
               end
            end
            -- character sheet order, so outfits are easy to compare
            table.sort(items, function(a, b)
               return (a.slotID or 99) < (b.slotID or 99)
            end)
            table.insert(outfits, { name = outfit.Name, items = items })
         end
      end
   end
   for _, categoryID in ipairs(categoryOrder) do
      AddCategory(categoryID)
   end
   for categoryID in pairs(Outfitter.Settings.Outfits) do
      AddCategory(categoryID)
   end
   CharDB().outfits = outfits
end

function RaidwrightData:GetOutfits()
   return CharDB().outfits or {}
end

function RaidwrightData:GetOutfitByName(name)
   for _, outfit in ipairs(self:GetOutfits()) do
      if outfit.name == name then
         return outfit
      end
   end
end

-- states per item: "have" (equipped or in bags), "bank" or "missing"
function RaidwrightData:GetOutfitStatus(outfit, bagCounts, equippedCounts)
   bagCounts = bagCounts or self:GetBagCounts()
   equippedCounts = equippedCounts or self:GetEquippedCounts()
   local db = CharDB()
   local needed = {}
   for _, item in ipairs(outfit.items) do
      needed[item.itemID] = (needed[item.itemID] or 0) + 1
   end
   local result = { items = {}, inBank = 0, missing = 0 }
   local used = {}
   for _, item in ipairs(outfit.items) do
      used[item.itemID] = (used[item.itemID] or 0) + 1
      local have = (bagCounts[item.itemID] or 0) + (equippedCounts[item.itemID] or 0)
      local bank = db.bank and db.bank[item.itemID] or 0
      local state = "have"
      if used[item.itemID] > have then
         if used[item.itemID] <= have + bank then
            state = "bank"
            result.inBank = result.inBank + 1
         else
            state = "missing"
            result.missing = result.missing + 1
         end
      end
      table.insert(result.items, { itemID = item.itemID, slot = item.slot, slotID = item.slotID or self:GetSlotID(item.slot), state = state })
   end
   return result
end

-- the amount of each item the list wants to have on the character (bags, or equipped for gear)
-- excludeOutfit leaves that outfit out of the gear, even when it's ticked
function RaidwrightData:GetListRequirements(list, excludeOutfit)
   local consumables = {}
   for _, entry in ipairs(list.consumables) do
      consumables[entry.itemID] = math.max(consumables[entry.itemID] or 0, entry.count or 0)
   end
   local gear = {}
   for outfitName in pairs(list.outfits or {}) do
      local outfit = outfitName ~= excludeOutfit and self:GetOutfitByName(outfitName)
      if outfit then
         local perOutfit = {}
         for _, item in ipairs(outfit.items) do
            perOutfit[item.itemID] = (perOutfit[item.itemID] or 0) + 1
         end
         for itemID, count in pairs(perOutfit) do
            gear[itemID] = math.max(gear[itemID] or 0, count)
         end
      end
   end
   return consumables, gear
end

-- every item any of the lists tracks, used when storing the leftovers in the bank
function RaidwrightData:GetAllTrackedItems()
   local tracked = {}
   for _, list in ipairs(self:GetLists()) do
      local consumables, gear = self:GetListRequirements(list)
      for itemID in pairs(consumables) do
         tracked[itemID] = true
      end
      for itemID in pairs(gear) do
         tracked[itemID] = true
      end
   end
   return tracked
end

-- world buffs

local worldBuffColumns
local function GetSpellColumnMap()
   if not worldBuffColumns then
      worldBuffColumns = {}
      for _, column in ipairs(C["WorldBuffs"]) do
         for _, spellId in ipairs(column.spells) do
            worldBuffColumns[spellId] = column.key
         end
      end
   end
   return worldBuffColumns
end

local chronoboonNames
local function IsChronoboon(spellId, name)
   if not chronoboonNames then
      chronoboonNames = {}
      for _, id in ipairs(C["ChronoboonSpells"]) do
         local spellName = RaidwrightNS.GetSpellInfo(id)
         if spellName then
            chronoboonNames[spellName] = true
         end
      end
   end
   for _, id in ipairs(C["ChronoboonSpells"]) do
      if id == spellId then
         return true
      end
   end
   return name ~= nil and chronoboonNames[name] == true
end

function RaidwrightData:IsSeasonal()
   return C_Seasons and C_Seasons.HasActiveSeason and C_Seasons.HasActiveSeason() or false
end

function RaidwrightData:GetWorldBuffColumns()
   local columns = {}
   local seasonal = self:IsSeasonal()
   for _, column in ipairs(C["WorldBuffs"]) do
      if seasonal or not column.seasonal then
         local spellId = column.spells[1]
         local name, _, icon = RaidwrightNS.GetSpellInfo(spellId)
         table.insert(columns, { key = column.key, name = name or column.key, icon = icon or 134400, spellId = spellId })
      end
   end
   return columns
end

local scanTooltip

-- the repair cost of an equipped item is only available as a return value of GameTooltip:SetInventoryItem
local function GetRepairCost(slot)
   if not scanTooltip then
      scanTooltip = CreateFrame("GameTooltip", "RaidwrightScanTooltip", nil, "GameTooltipTemplate")
   end
   scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
   local _, _, repairCost = scanTooltip:SetInventoryItem("player", slot)
   scanTooltip:Hide()
   return type(repairCost) == "number" and repairCost or 0
end

-- live durability of the current character's equipped items
-- Percent is the overall durability, Lowest the durability of the most damaged item
function RaidwrightData:GetDurability()
   local current, maximum, lowest, repairCost = 0, 0, 1, 0
   for slot = 1, C["EquipmentSlots"] do
      local cur, max = GetInventoryItemDurability(slot)
      if cur and max and max > 0 then
         current = current + cur
         maximum = maximum + max
         lowest = math.min(lowest, cur / max)
         if cur < max then
            repairCost = repairCost + GetRepairCost(slot)
         end
      end
   end
   return {
      Percent = maximum > 0 and current / maximum or 1,
      Lowest = lowest,
      RepairCost = repairCost,
   }
end

-- live world buffs on the current character
function RaidwrightData:GetCurrentWorldBuffs()
   local map = GetSpellColumnMap()
   local buffs = {}
   local now = GetTime()
   for i = 1, 40 do
      local name, icon, count, debuffType, duration, expirationTime, source, isStealable, nameplateShowPersonal, spellId = UnitBuff("player", i)
      if not name then
         break
      end
      if map[spellId] then
         table.insert(buffs, {
            key = map[spellId],
            name = name,
            icon = icon,
            spellId = spellId,
            remaining = (expirationTime and expirationTime > 0) and (expirationTime - now) or 0,
         })
      end
   end
   return buffs
end

function RaidwrightData:HasChronoboon()
   for i = 1, 40 do
      local name, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", i)
      if not name then
         break
      end
      if IsChronoboon(spellId, name) then
         return true
      end
   end
   return false
end

function RaidwrightData:SaveWorldBuffs()
   local char = RaidwrightNS.RaidwrightAddon.CurrentCharacter
   if not char or not char.Name then
      return
   end
   local saved = {}
   for _, buff in ipairs(RaidwrightData:GetCurrentWorldBuffs()) do
      saved[buff.key] = { remaining = buff.remaining, icon = buff.icon, name = buff.name, spellId = buff.spellId }
   end
   char.WorldBuffs = saved
   char.Chronoboon = RaidwrightData:HasChronoboon()
   char.WorldBuffsSaved = time()
end

-- the buffs are gone once the cast succeeds, so take the snapshot when it starts
local pendingBoonedBuffs

function RaidwrightData:SpellCastStart(unit, spellId)
   if unit == "player" and C["ChronoboonStoreSpells"][spellId] then
      local buffs = {}
      for _, buff in ipairs(RaidwrightData:GetCurrentWorldBuffs()) do
         buffs[buff.key] = { remaining = buff.remaining, icon = buff.icon, name = buff.name, spellId = buff.spellId }
      end
      pendingBoonedBuffs = buffs
   end
end

function RaidwrightData:SpellCastSucceeded(unit, spellId)
   local char = RaidwrightNS.RaidwrightAddon.CurrentCharacter
   if unit ~= "player" or not char.Name then
      return
   end
   if C["ChronoboonStoreSpells"][spellId] and pendingBoonedBuffs then
      char.BoonedBuffs = pendingBoonedBuffs
      char.Chronoboon = true
      pendingBoonedBuffs = nil
   elseif spellId == C["ChronoboonReleaseSpell"] then
      char.BoonedBuffs = nil
      char.Chronoboon = false
   end
   RaidwrightNS.RaidwrightAddon:RefreshFrame()
end

-- buffs of the logged in character are live, buffs of other characters are paused while they're offline
-- booned buffs are nil when the character has a Chronoboon we didn't see being filled
function RaidwrightData:GetCharacterWorldBuffs(key)
   local char = key and RaidwrightNS.RaidwrightDB.global.characters[key]
   if not char then
      return {}, false, false, nil
   end
   if key == RaidwrightNS.RaidwrightAddon.CurrentCharacterKey then
      local buffs = {}
      for _, buff in ipairs(self:GetCurrentWorldBuffs()) do
         buffs[buff.key] = buff
      end
      local hasBoon = self:HasChronoboon()
      return buffs, hasBoon, true, hasBoon and char.BoonedBuffs or nil
   end
   -- timers kept running between the last save and logging out
   local played = 0
   if char.LastLogout and char.WorldBuffsSaved and char.LastLogout > char.WorldBuffsSaved then
      played = char.LastLogout - char.WorldBuffsSaved
   end
   local buffs = {}
   for buffKey, buff in pairs(char.WorldBuffs or {}) do
      local remaining = (buff.remaining or 0) - played
      if remaining > 0 then
         buffs[buffKey] = setmetatable({ remaining = remaining }, { __index = buff })
      end
   end
   return buffs, char.Chronoboon, false, char.Chronoboon and char.BoonedBuffs or nil
end

function RaidwrightData:NotifyOnLogin()
   if RaidwrightNS.RaidwrightDB.profile.settings.hideLoginAlert then
      return
   end
   local list = RaidwrightData:GetSelectedList()
   if not list or #list.consumables == 0 then
      return
   end
   local short = RaidwrightData:GetShortConsumables(list)
   if #short == 0 then
      return
   end
   local names = {}
   for _, entry in ipairs(short) do
      local name, _, link = RaidwrightNS:GetItemNameAndIcon(entry.itemID)
      table.insert(names, (link or name) .. " x" .. entry.status.short)
   end
   RaidwrightNS:Print(L["LoginShortAlert"]:format(list.name, table.concat(names, ", ")))
end
