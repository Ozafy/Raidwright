local AddonName, RaidwrightNS = ...

local C = RaidwrightNS.C
local L = LibStub("AceLocale-3.0"):GetLocale(AddonName)

local RaidwrightBank = {}
RaidwrightNS.RaidwrightBank = RaidwrightBank

local MAX_STEPS = 200
local STEP_DELAY = 0.3

local ticker
local bankOpen = false

function RaidwrightBank:SetBankOpen(open)
   bankOpen = open
   if not open then
      RaidwrightBank:Stop()
   end
end

function RaidwrightBank:IsBankOpen()
   return bankOpen
end

function RaidwrightBank:Stop(message)
   if ticker then
      ticker:Cancel()
      ticker = nil
      if message then
         RaidwrightNS:Print(message)
      end
      RaidwrightNS.RaidwrightAddon:RefreshFrame()
   end
end

local function AnyItemLocked(bagIDs)
   for _, bag in ipairs(bagIDs) do
      for slot = 1, C_Container.GetContainerNumSlots(bag) do
         local info = C_Container.GetContainerItemInfo(bag, slot)
         if info and info.isLocked then
            return true
         end
      end
   end
   return false
end

-- only regular bags, so a split stack doesn't try to go into a quiver or soul bag
local function FindEmptySlot(bagIDs)
   for _, bag in ipairs(bagIDs) do
      local free, bagFamily = C_Container.GetContainerNumFreeSlots(bag)
      if free and free > 0 and (bagFamily == nil or bagFamily == 0) then
         for slot = 1, C_Container.GetContainerNumSlots(bag) do
            if not C_Container.GetContainerItemInfo(bag, slot) then
               return bag, slot
            end
         end
      end
   end
end

-- stacks are never split, every move takes a whole stack

-- storing: the smallest stack that fits within the amount to move, so as many bag slots as possible get cleared
local function FindStackToStore(toMove, sourceBags)
   local bestBag, bestSlot, bestCount
   for _, bag in ipairs(sourceBags) do
      for slot = 1, C_Container.GetContainerNumSlots(bag) do
         local info = C_Container.GetContainerItemInfo(bag, slot)
         local amount = info and toMove[info.itemID]
         if amount and info.stackCount <= amount and (not bestCount or info.stackCount < bestCount) then
            bestBag, bestSlot, bestCount = bag, slot, info.stackCount
         end
      end
   end
   return bestBag, bestSlot
end

-- getting: the smallest stack that covers what's missing, or else the biggest one, so it takes as few bag slots as possible
local function FindStackToGrab(toMove, sourceBags)
   for itemID, amount in pairs(toMove) do
      if amount > 0 then
         local bestBag, bestSlot, bestCount, covers
         for _, bag in ipairs(sourceBags) do
            for slot = 1, C_Container.GetContainerNumSlots(bag) do
               local info = C_Container.GetContainerItemInfo(bag, slot)
               if info and info.itemID == itemID then
                  local count = info.stackCount
                  if count >= amount then
                     if not covers or count < bestCount then
                        bestBag, bestSlot, bestCount, covers = bag, slot, count, true
                     end
                  elseif not covers and (not bestCount or count > bestCount) then
                     bestBag, bestSlot, bestCount = bag, slot, count
                  end
               end
            end
         end
         if bestBag then
            return bestBag, bestSlot
         end
      end
   end
end

-- moves one stack, returns "moved", "nothing" or "full"
local function MoveOne(toMove, findStack, sourceBags, targetBags)
   local bag, slot = findStack(toMove, sourceBags)
   if not bag then
      return "nothing"
   end
   if not FindEmptySlot(targetBags) then
      return "full"
   end
   C_Container.UseContainerItem(bag, slot)
   return "moved"
end

-- what should go from the bank to the bags for the selected list, consumables or outfit gear
local function GetItemsToGrab(forGear)
   local list = RaidwrightNS.RaidwrightData:GetSelectedList()
   local toMove = {}
   if not list then
      return toMove
   end
   local bagCounts = RaidwrightNS.RaidwrightData:GetBagCounts()
   local equipped = RaidwrightNS.RaidwrightData:GetEquippedCounts()
   local consumables, gear = RaidwrightNS.RaidwrightData:GetListRequirements(list)
   if forGear then
      for itemID, need in pairs(gear) do
         toMove[itemID] = math.max(0, need - (bagCounts[itemID] or 0) - (equipped[itemID] or 0))
      end
   else
      for itemID, need in pairs(consumables) do
         toMove[itemID] = math.max(0, need - (bagCounts[itemID] or 0) - (equipped[itemID] or 0))
      end
   end
   return toMove
end

-- consumables of any list in the bags beyond what the selected list needs, gear the list needs stays too
local function GetItemsToStore()
   local list = RaidwrightNS.RaidwrightData:GetSelectedList()
   local consumables, gear = {}, {}
   if list then
      consumables, gear = RaidwrightNS.RaidwrightData:GetListRequirements(list)
   end
   local bagCounts = RaidwrightNS.RaidwrightData:GetBagCounts()
   local equipped = RaidwrightNS.RaidwrightData:GetEquippedCounts()
   local toMove = {}
   for itemID in pairs(RaidwrightNS.RaidwrightData:GetAllTrackedConsumables()) do
      -- what's equipped counts towards both
      local keep = math.max(consumables[itemID] or 0, gear[itemID] or 0) - (equipped[itemID] or 0)
      local extra = (bagCounts[itemID] or 0) - keep
      if extra > 0 then
         toMove[itemID] = extra
      end
   end
   return toMove
end

-- the items of one outfit that are in the bags, except what other ticked outfits of the selected list still need
local function GetOutfitItemsToStore(outfitName)
   local outfit = RaidwrightNS.RaidwrightData:GetOutfitByName(outfitName)
   local toMove = {}
   if not outfit then
      return toMove
   end
   local list = RaidwrightNS.RaidwrightData:GetSelectedList()
   local gear = {}
   if list then
      gear = select(2, RaidwrightNS.RaidwrightData:GetListRequirements(list, outfitName))
   end
   local bagCounts = RaidwrightNS.RaidwrightData:GetBagCounts()
   local equipped = RaidwrightNS.RaidwrightData:GetEquippedCounts()
   for _, item in ipairs(outfit.items) do
      local itemID = item.itemID
      if not toMove[itemID] then
         local keep = math.max(0, (gear[itemID] or 0) - (equipped[itemID] or 0))
         toMove[itemID] = math.max(0, (bagCounts[itemID] or 0) - keep)
      end
   end
   return toMove
end

function RaidwrightBank:HasOutfitItemsToStore(outfitName)
   for _, amount in pairs(GetOutfitItemsToStore(outfitName)) do
      if amount > 0 then
         return true
      end
   end
   return false
end

local function Run(getItems, findStack, sourceBags, targetBags)
   if not bankOpen then
      RaidwrightNS:Print(L["BankNotOpen"])
      return
   end
   if ticker then
      RaidwrightNS:Print(L["BankTransferBusy"])
      return
   end
   local steps = 0
   ticker = C_Timer.NewTicker(STEP_DELAY, function()
      steps = steps + 1
      if not bankOpen or steps > MAX_STEPS then
         RaidwrightBank:Stop()
         return
      end
      -- counts are only correct once the previous move has gone through
      if GetCursorInfo() or AnyItemLocked(sourceBags) or AnyItemLocked(targetBags) then
         return
      end
      local result = MoveOne(getItems(), findStack, sourceBags, targetBags)
      if result == "full" then
         RaidwrightBank:Stop(L["BankTransferBagsFull"])
      elseif result == "nothing" then
         RaidwrightBank:Stop(L["BankTransferDone"])
      end
   end)
end

function RaidwrightBank:GrabFromBank(forGear)
   Run(function() return GetItemsToGrab(forGear) end, FindStackToGrab, RaidwrightNS.RaidwrightData:GetBankBagIDs(), RaidwrightNS.RaidwrightData:GetBagIDs())
end

function RaidwrightBank:StoreInBank()
   Run(GetItemsToStore, FindStackToStore, RaidwrightNS.RaidwrightData:GetBagIDs(), RaidwrightNS.RaidwrightData:GetBankBagIDs())
end

function RaidwrightBank:StoreOutfitInBank(outfitName)
   Run(function() return GetOutfitItemsToStore(outfitName) end, FindStackToStore, RaidwrightNS.RaidwrightData:GetBagIDs(), RaidwrightNS.RaidwrightData:GetBankBagIDs())
end
