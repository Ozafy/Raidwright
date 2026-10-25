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

-- moves (part of) one stack, returns "moved", "nothing" or "full"
local function MoveOne(toMove, sourceBags, targetBags)
   for itemID, amount in pairs(toMove) do
      if amount > 0 then
         for _, bag in ipairs(sourceBags) do
            for slot = 1, C_Container.GetContainerNumSlots(bag) do
               local info = C_Container.GetContainerItemInfo(bag, slot)
               if info and info.itemID == itemID then
                  local targetBag, targetSlot = FindEmptySlot(targetBags)
                  if not targetBag then
                     return "full"
                  end
                  if info.stackCount <= amount then
                     C_Container.UseContainerItem(bag, slot)
                     return "moved"
                  end
                  ClearCursor()
                  C_Container.SplitContainerItem(bag, slot, amount)
                  C_Container.PickupContainerItem(targetBag, targetSlot)
                  return "moved"
               end
            end
         end
      end
   end
   return "nothing"
end

-- what should go from the bank to the bags for the selected list
local function GetItemsToGrab()
   local list = RaidwrightNS.RaidwrightData:GetSelectedList()
   local toMove = {}
   if not list then
      return toMove
   end
   local bagCounts = RaidwrightNS.RaidwrightData:GetBagCounts()
   local equipped = RaidwrightNS.RaidwrightData:GetEquippedCounts()
   local consumables, gear = RaidwrightNS.RaidwrightData:GetListRequirements(list)
   for itemID, need in pairs(consumables) do
      toMove[itemID] = math.max(0, need - (bagCounts[itemID] or 0))
   end
   for itemID, need in pairs(gear) do
      local missing = need - (bagCounts[itemID] or 0) - (equipped[itemID] or 0)
      toMove[itemID] = math.max(toMove[itemID] or 0, missing)
   end
   return toMove
end

-- tracked items in the bags beyond what the selected list needs
local function GetItemsToStore()
   local list = RaidwrightNS.RaidwrightData:GetSelectedList()
   local consumables, gear = {}, {}
   if list then
      consumables, gear = RaidwrightNS.RaidwrightData:GetListRequirements(list)
   end
   local bagCounts = RaidwrightNS.RaidwrightData:GetBagCounts()
   local equipped = RaidwrightNS.RaidwrightData:GetEquippedCounts()
   local toMove = {}
   for itemID in pairs(RaidwrightNS.RaidwrightData:GetAllTrackedItems()) do
      local keep = math.max(consumables[itemID] or 0, (gear[itemID] or 0) - (equipped[itemID] or 0))
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

local function Run(getItems, sourceBags, targetBags)
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
      local result = MoveOne(getItems(), sourceBags, targetBags)
      if result == "full" then
         RaidwrightBank:Stop(L["BankTransferBagsFull"])
      elseif result == "nothing" then
         RaidwrightBank:Stop(L["BankTransferDone"])
      end
   end)
end

function RaidwrightBank:GrabFromBank()
   Run(GetItemsToGrab, RaidwrightNS.RaidwrightData:GetBankBagIDs(), RaidwrightNS.RaidwrightData:GetBagIDs())
end

function RaidwrightBank:StoreInBank()
   Run(GetItemsToStore, RaidwrightNS.RaidwrightData:GetBagIDs(), RaidwrightNS.RaidwrightData:GetBankBagIDs())
end

function RaidwrightBank:StoreOutfitInBank(outfitName)
   Run(function() return GetOutfitItemsToStore(outfitName) end, RaidwrightNS.RaidwrightData:GetBagIDs(), RaidwrightNS.RaidwrightData:GetBankBagIDs())
end
