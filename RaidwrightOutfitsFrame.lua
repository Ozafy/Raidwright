local AddonName, RaidwrightNS = ...

local C = RaidwrightNS.C
local L = LibStub("AceLocale-3.0"):GetLocale(AddonName)

local RaidwrightOutfitsFrame = {}
RaidwrightNS.RaidwrightOutfitsFrame = RaidwrightOutfitsFrame

local _PADDING = 5
local _ROW_HEIGHT = 40
local _ICON_SIZE = 28
local _ICON_PADDING = 4
local _ICONS_X = 230
local _HIDE_X = _ICONS_X + 19 * (_ICON_SIZE + _ICON_PADDING) + 2

local STATE_COLORS = {
   have = { 0.1, 0.9, 0.1 },
   bank = { 1, 0.82, 0 },
   missing = { 1, 0.1, 0.1 },
}
local STATE_TEXT = {
   have = L["ItemEquipped"],
   bank = L["ItemInBank"],
   missing = L["ItemMissing"],
}

local function CreateRow(content, owner)
   local row = CreateFrame("Frame", nil, content)
   row:SetSize(C["Width"] - 42, _ROW_HEIGHT)

   row.Check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
   row.Check:SetSize(26, 26)
   row.Check:SetPoint("LEFT", row, "LEFT", _PADDING, 0)
   row.Check:SetScript("OnClick", function(self)
      local list = RaidwrightNS.RaidwrightData:GetSelectedList()
      if list then
         list.outfits = list.outfits or {}
         list.outfits[row.outfitName] = self:GetChecked() or nil
         RaidwrightOutfitsFrame:Initialize(owner)
      end
   end)

   row.Name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
   row.Name:SetPoint("TOPLEFT", row, "TOPLEFT", 36, -6)
   row.Name:SetWidth(_ICONS_X - 112)
   row.Name:SetJustifyH("LEFT")
   row.Name:SetWordWrap(false)

   row.Status = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
   row.Status:SetPoint("TOPLEFT", row.Name, "BOTTOMLEFT", 0, -3)
   row.Status:SetJustifyH("LEFT")

   row.StoreButton = RaidwrightNS:CreateButton(row, L["StoreOutfit"], 60)
   row.StoreButton:SetPoint("RIGHT", row, "LEFT", _ICONS_X - 8, 0)
   row.StoreButton:SetScript("OnClick", function()
      RaidwrightNS.RaidwrightBank:StoreOutfitInBank(row.outfitName)
   end)
   RaidwrightNS:SetSimpleTooltip(row.StoreButton, L["StoreOutfit"] .. " " .. L["Bank"], L["StoreOutfitTooltip"])

   -- one fixed column per equipment slot, like the character sheet
   row.Items = {}
   for slotID = 1, C["EquipmentSlots"] do
      local button = CreateFrame("Button", nil, row)
      button:SetSize(_ICON_SIZE, _ICON_SIZE)
      button:SetPoint("LEFT", row, "LEFT", _ICONS_X + (slotID - 1) * (_ICON_SIZE + _ICON_PADDING), 0)
      button.Texture = button:CreateTexture(nil, "BACKGROUND")
      button.Texture:SetAllPoints()
      button:RegisterForClicks("AnyUp")
      button:SetScript("OnClick", function(self)
         if self.TooltipItemLink then
            RaidwrightNS:ItemOnClick(self)
         end
      end)
      button:SetScript("OnEnter", function(self)
         if self.TooltipItemLink then
            RaidwrightNS:ItemOnEnter(self)
         else
            RaidwrightNS.RaidwrightTooltip:SetOwner(self, "ANCHOR_CURSOR")
            RaidwrightNS.RaidwrightTooltip:SetText(L["EquipmentSlots"][slotID])
            RaidwrightNS.RaidwrightTooltip:AddLine(L["EmptySlot"], 0.5, 0.5, 0.5)
            RaidwrightNS.RaidwrightTooltip:Show()
         end
      end)
      button:SetScript("OnLeave", function(self)
         if self.TooltipItemLink then
            RaidwrightNS:ItemOnLeave(self)
         else
            RaidwrightNS.RaidwrightTooltip:Hide()
         end
      end)
      row.Items[slotID] = button
   end

   -- hides the outfit from this tab, or shows it again while hidden outfits are listed
   row.HideButton = CreateFrame("Button", nil, row)
   row.HideButton:SetSize(18, 18)
   row.HideButton:SetPoint("LEFT", row, "LEFT", _HIDE_X, 0)
   row.HideButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
   row.HideButton:SetScript("OnClick", function()
      RaidwrightNS.RaidwrightData:SetOutfitHidden(row.outfitName, not row.hidden)
      RaidwrightOutfitsFrame:Initialize(owner)
   end)
   row.HideButton:SetScript("OnEnter", function(self)
      RaidwrightNS.RaidwrightTooltip:SetOwner(self, "ANCHOR_RIGHT")
      RaidwrightNS.RaidwrightTooltip:SetText(row.hidden and L["UnhideOutfit"] or L["HideOutfit"], 1, 1, 1)
      RaidwrightNS.RaidwrightTooltip:AddLine(row.hidden and L["UnhideOutfitTooltip"] or L["HideOutfitTooltip"], nil, nil, nil, true)
      RaidwrightNS.RaidwrightTooltip:Show()
   end)
   row.HideButton:SetScript("OnLeave", function() RaidwrightNS.RaidwrightTooltip:Hide() end)
   return row
end

local function CreateTopBar(self)
   local refresh = function() RaidwrightNS.RaidwrightAddon:RefreshFrame() end
   self.ListSelector = RaidwrightNS:CreateListSelector(self, refresh)

   self.GrabButton = RaidwrightNS:CreateButton(self, L["GetFromBank"], 110)
   self.GrabButton:SetPoint("TOPRIGHT", self, "TOPRIGHT", -26, -6)
   self.GrabButton:SetScript("OnClick", function() RaidwrightNS.RaidwrightBank:GrabFromBank(true) end)
   RaidwrightNS:SetSimpleTooltip(self.GrabButton, L["GetFromBank"], L["GetFromBankOutfitsTooltip"])

   self.ShowHidden = CreateFrame("CheckButton", nil, self, "UICheckButtonTemplate")
   self.ShowHidden:SetSize(24, 24)
   self.ShowHidden:SetPoint("RIGHT", self.GrabButton, "LEFT", -140, 0)
   self.ShowHidden.Label = self.ShowHidden:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
   self.ShowHidden.Label:SetPoint("LEFT", self.ShowHidden, "RIGHT", 2, 0)
   self.ShowHidden:SetScript("OnClick", function() RaidwrightOutfitsFrame:Initialize(self) end)
   RaidwrightNS:SetSimpleTooltip(self.ShowHidden, L["ShowHiddenOutfits"], L["ShowHiddenOutfitsTooltip"])

   self.Hint = self:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
   self.Hint:SetPoint("TOPLEFT", _PADDING, -44)
   self.Hint:SetText(L["OutfitsHint"])

   self.Message = self:CreateFontString(nil, "ARTWORK", "GameFontDisable")
   self.Message:SetPoint("BOTTOMLEFT", _PADDING, 4)
end

function RaidwrightOutfitsFrame:Initialize(self)
   if not self.ListSelector then
      CreateTopBar(self)
   end
   self.ListSelector:Refresh()

   RaidwrightNS.RaidwrightData:SnapshotOutfits()
   local state = RaidwrightNS.RaidwrightData:GetOutfitterState()
   local allOutfits = RaidwrightNS.RaidwrightData:GetOutfits()
   local showHidden = self.ShowHidden:GetChecked()
   local outfits, hiddenCount = {}, 0
   for _, outfit in ipairs(allOutfits) do
      local hidden = RaidwrightNS.RaidwrightData:IsOutfitHidden(outfit.name)
      if hidden then
         hiddenCount = hiddenCount + 1
      end
      if showHidden or not hidden then
         table.insert(outfits, outfit)
      end
   end
   self.ShowHidden.Label:SetText(L["ShowHiddenOutfitsCount"]:format(hiddenCount))
   if state == "missing" then
      self.Message:SetText(L["OutfitterMissing"])
   elseif state == "loading" then
      self.Message:SetText(L["OutfitterNotReady"])
   elseif #allOutfits == 0 then
      self.Message:SetText(L["NoOutfits"])
   elseif #outfits == 0 then
      self.Message:SetText(L["AllOutfitsHidden"])
   else
      self.Message:SetText("")
   end

   local list = RaidwrightNS.RaidwrightData:GetSelectedList()
   self.GrabButton:SetEnabled(list ~= nil and RaidwrightNS.RaidwrightBank:IsBankOpen())

   local scrollFrame = self.ScrollFrame or RaidwrightNS:CreateScrollFrame(self, 0, -62, -22, 20)
   local content = scrollFrame.content
   RaidwrightNS:HideRowWidgets(content)
   content.Rows = content.Rows or {}

   local bagCounts = RaidwrightNS.RaidwrightData:GetBagCounts()
   local equippedCounts = RaidwrightNS.RaidwrightData:GetEquippedCounts()
   local total = 0
   if list then
      for i, outfit in ipairs(outfits) do
         local row = content.Rows[i] or CreateRow(content, self)
         content.Rows[i] = row
         row.outfitName = outfit.name
         row.hidden = RaidwrightNS.RaidwrightData:IsOutfitHidden(outfit.name)
         row:SetAlpha(row.hidden and 0.5 or 1)
         row.HideButton:SetNormalTexture(row.hidden and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-GroupLoot-Pass-Up")
         row.HideButton:Show()
         row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -_ROW_HEIGHT * (i - 1))
         row:Show()

         local selected = list.outfits and list.outfits[outfit.name] or false
         row.Check:SetChecked(selected)
         row.Name:SetText(row.hidden and (outfit.name .. " " .. L["OutfitHiddenSuffix"]) or outfit.name)
         row.StoreButton:SetEnabled(RaidwrightNS.RaidwrightBank:IsBankOpen() and RaidwrightNS.RaidwrightBank:HasOutfitItemsToStore(outfit.name))

         local status = RaidwrightNS.RaidwrightData:GetOutfitStatus(outfit, bagCounts, equippedCounts)
         local bySlot = {}
         for _, item in ipairs(status.items) do
            if item.slotID then
               bySlot[item.slotID] = item
            end
         end
         for slotID, button in ipairs(row.Items) do
            local item = bySlot[slotID]
            if item then
               local _, icon, link = RaidwrightNS:GetItemNameAndIcon(item.itemID)
               button.Texture:SetTexture(icon)
               button.TooltipItemLink = link or ("item:" .. item.itemID)
               button.ExtraTooltipLines = { STATE_TEXT[item.state] }
               local color = STATE_COLORS[item.state]
               RaidwrightNS:SetBorderColor(button, color[1], color[2], color[3])
            else
               button.Texture:SetTexture(C:GetEquipmentSlotIcon(slotID))
               button.TooltipItemLink = nil
               button.ExtraTooltipLines = nil
               RaidwrightNS:CreateInnerBorder(button, -1)
            end
            button:SetAlpha(selected and 1 or 0.4)
            button:Show()
         end

         if not selected then
            row.Name:SetTextColor(0.5, 0.5, 0.5)
            row.Status:SetText("")
         else
            row.Name:SetTextColor(1, 0.82, 0)
            local parts = {}
            if status.inBank > 0 then
               table.insert(parts, "|cffffd100" .. L["OutfitInBank"]:format(status.inBank) .. "|r")
            end
            if status.missing > 0 then
               table.insert(parts, "|cffff1a1a" .. L["OutfitMissing"]:format(status.missing) .. "|r")
            end
            if #parts == 0 then
               table.insert(parts, "|cff1ae61a" .. L["OutfitAllPresent"] .. "|r")
            end
            row.Status:SetText(table.concat(parts, ", "))
         end
         total = total + 1
      end
   end
   content:SetSize(C["Width"] - 42, math.max(1, _ROW_HEIGHT * total))
end
