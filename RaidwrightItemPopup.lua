local AddonName, RaidwrightNS = ...

local C = RaidwrightNS.C
local L = LibStub("AceLocale-3.0"):GetLocale(AddonName)

local RaidwrightItemPopup = {}
RaidwrightNS.RaidwrightItemPopup = RaidwrightItemPopup

local popup

local function SetItem(itemID)
   popup.itemID = itemID
   if not itemID then
      popup.ItemButton.Texture:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
      popup.ItemButton.TooltipItemLink = nil
      RaidwrightNS:CreateInnerBorder(popup.ItemButton, -1)
      popup.ItemName:SetText(L["ItemPopupNoItem"])
      popup.ItemName:SetTextColor(0.5, 0.5, 0.5)
      popup.SaveButton:Disable()
      return
   end
   local name, icon, link, quality = RaidwrightNS:GetItemNameAndIcon(itemID, function()
      if popup:IsShown() and popup.itemID == itemID then
         SetItem(itemID)
      end
   end)
   popup.ItemButton.Texture:SetTexture(icon)
   popup.ItemButton.TooltipItemLink = link or ("item:" .. itemID)
   RaidwrightNS:CreateInnerBorder(popup.ItemButton, quality)
   popup.ItemName:SetText(name)
   if quality and quality > -1 then
      local r, g, b = C_Item.GetItemQualityColor(quality)
      popup.ItemName:SetTextColor(r, g, b)
   else
      popup.ItemName:SetTextColor(1, 1, 1)
   end
   popup.SaveButton:Enable()
end

local function TakeCursorItem()
   local infoType, itemID, link = GetCursorInfo()
   if infoType == "item" then
      SetItem(itemID or RaidwrightNS:GetItemIDFromLink(link))
      ClearCursor()
      return true
   end
   return false
end

local function Save()
   local count = tonumber(popup.CountBox:GetText())
   if not popup.itemID or not count or count < 1 then
      return
   end
   RaidwrightNS.RaidwrightData:SaveConsumable(popup.entryIndex, popup.itemID, count)
   popup:Hide()
   if popup.onDone then
      popup.onDone()
   end
end

local function CreatePopup()
   popup = CreateFrame("Frame", "RaidwrightItemPopupFrame", UIParent, "BasicFrameTemplateWithInset")
   popup:SetSize(320, 175)
   popup:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
   popup:SetFrameStrata("DIALOG")
   popup:SetToplevel(true)
   popup:SetClampedToScreen(true)
   popup:EnableMouse(true)
   popup:SetMovable(true)
   popup:RegisterForDrag("LeftButton")
   popup:SetScript("OnDragStart", popup.StartMoving)
   popup:SetScript("OnDragStop", popup.StopMovingOrSizing)

   popup.TitleBg:SetHeight(30)
   popup.Title = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
   popup.Title:SetPoint("CENTER", popup.TitleBg, "CENTER", 0, 6)

   popup.ItemButton = CreateFrame("Button", nil, popup)
   popup.ItemButton:SetSize(40, 40)
   popup.ItemButton:SetPoint("TOPLEFT", 18, -38)
   popup.ItemButton.Texture = popup.ItemButton:CreateTexture(nil, "BACKGROUND")
   popup.ItemButton.Texture:SetAllPoints()
   popup.ItemButton:RegisterForClicks("AnyUp")
   popup.ItemButton:SetScript("OnReceiveDrag", TakeCursorItem)
   popup.ItemButton:SetScript("OnClick", function(self)
      if not TakeCursorItem() then
         RaidwrightNS:ItemOnClick(self)
      end
   end)
   popup.ItemButton:SetScript("OnEnter", function(self)
      if self.TooltipItemLink then
         RaidwrightNS:ItemOnEnter(self)
      end
   end)
   popup.ItemButton:SetScript("OnLeave", function(self)
      RaidwrightNS:ItemOnLeave(self)
   end)

   popup.ItemName = popup:CreateFontString(nil, "ARTWORK", "GameFontNormal")
   popup.ItemName:SetPoint("TOPLEFT", popup.ItemButton, "TOPRIGHT", 10, -4)
   popup.ItemName:SetPoint("RIGHT", popup, "RIGHT", -16, 0)
   popup.ItemName:SetJustifyH("LEFT")

   popup.Hint = popup:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
   popup.Hint:SetPoint("TOPLEFT", popup.ItemName, "BOTTOMLEFT", 0, -6)
   popup.Hint:SetPoint("RIGHT", popup, "RIGHT", -16, 0)
   popup.Hint:SetJustifyH("LEFT")
   popup.Hint:SetText(L["ItemPopupHint"])

   popup.CountLabel = popup:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
   popup.CountLabel:SetPoint("TOPLEFT", popup.ItemButton, "BOTTOMLEFT", 0, -18)
   popup.CountLabel:SetText(L["Count"])

   popup.CountBox = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
   popup.CountBox:SetSize(60, 20)
   popup.CountBox:SetPoint("LEFT", popup.CountLabel, "RIGHT", 12, 0)
   popup.CountBox:SetAutoFocus(false)
   popup.CountBox:SetNumeric(true)
   popup.CountBox:SetMaxLetters(5)
   popup.CountBox:SetScript("OnEnterPressed", Save)
   popup.CountBox:SetScript("OnEscapePressed", function() popup:Hide() end)

   popup.SaveButton = RaidwrightNS:CreateButton(popup, L["Save"], 90)
   popup.SaveButton:SetPoint("BOTTOMRIGHT", popup, "BOTTOM", -4, 14)
   popup.SaveButton:SetScript("OnClick", Save)

   popup.CancelButton = RaidwrightNS:CreateButton(popup, L["Cancel"], 90)
   popup.CancelButton:SetPoint("BOTTOMLEFT", popup, "BOTTOM", 4, 14)
   popup.CancelButton:SetScript("OnClick", function() popup:Hide() end)

   -- shift clicking an item anywhere ends up in one of these, use that to pick up the item
   local function OnLinkClicked(link)
      if popup:IsShown() and type(link) == "string" then
         local itemID = RaidwrightNS:GetItemIDFromLink(link)
         if itemID then
            SetItem(itemID)
         end
      end
   end
   if ChatEdit_InsertLink then
      hooksecurefunc("ChatEdit_InsertLink", OnLinkClicked)
   end
   if HandleModifiedItemClick then
      hooksecurefunc("HandleModifiedItemClick", function(link)
         if IsModifiedClick("CHATLINK") then
            OnLinkClicked(link)
         end
      end)
   end

   tinsert(UISpecialFrames, "RaidwrightItemPopupFrame")
   popup:Hide()
end

-- entryIndex is nil when adding a new item
function RaidwrightItemPopup:Open(entryIndex, onDone)
   if not popup then
      CreatePopup()
   end
   local list = RaidwrightNS.RaidwrightData:GetSelectedList()
   if not list then
      return
   end
   popup.entryIndex = entryIndex
   popup.onDone = onDone
   local entry = entryIndex and list.consumables[entryIndex]
   popup.Title:SetText((entry and L["EditItem"] or L["AddItem"]) .. " - " .. list.name)
   SetItem(entry and entry.itemID)
   popup.CountBox:SetText(entry and entry.count or 1)
   popup:Show()
   popup.CountBox:SetFocus()
   popup.CountBox:HighlightText()
end

function RaidwrightItemPopup:Hide()
   if popup then
      popup:Hide()
   end
end
