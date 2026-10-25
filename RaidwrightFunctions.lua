local AddonName, RaidwrightNS = ...

local C = RaidwrightNS.C
local L = LibStub("AceLocale-3.0"):GetLocale(AddonName)

function RaidwrightNS:Print(msg)
   print("|cff33ff99" .. AddonName .. "|r: " .. msg)
end

function RaidwrightNS:GetRealmCharactersSorted()
   local characterNames = {}
   local realm = GetNormalizedRealmName()
   for key, char in pairs(self.RaidwrightDB.global.characters) do
      if char.Realm == realm then
         table.insert(characterNames, key)
      end
   end
   table.sort(characterNames)
   return characterNames
end

function RaidwrightNS:GetItemIDFromLink(link)
   if not link then
      return nil
   end
   return tonumber(link:match("item:(%d+)"))
end

-- item names aren't always cached, so this returns a placeholder and calls onLoad once the item is known
function RaidwrightNS:GetItemNameAndIcon(itemID, onLoad)
   local name, link, quality, _, _, _, _, _, _, icon = GetItemInfo(itemID)
   if not name then
      if onLoad then
         Item:CreateFromItemID(itemID):ContinueOnItemLoad(onLoad)
      end
      return "item:" .. itemID, GetItemIcon(itemID), nil, -1
   end
   return name, icon, link, quality
end

function RaidwrightNS:TimeSpanToString(span)
   span = math.max(0, math.floor(span))
   local hours = math.floor(span / 3600)
   local minutes = math.floor((span % 3600) / 60)
   local seconds = span % 60
   if hours > 0 then
      return ("%d\124cnADVENTURES_COMBAT_LOG_YELLOW:%s\124r %02d\124cnADVENTURES_COMBAT_LOG_YELLOW:%s\124r"):format(hours, L["HoursShort"], minutes, L["MinutesShort"])
   end
   if minutes > 0 then
      return ("%d\124cnADVENTURES_COMBAT_LOG_YELLOW:%s\124r %02d\124cnADVENTURES_COMBAT_LOG_YELLOW:%s\124r"):format(minutes, L["MinutesShort"], seconds, L["SecondsShort"])
   end
   return ("%d\124cnADVENTURES_COMBAT_LOG_YELLOW:%s\124r"):format(seconds, L["SecondsShort"])
end

function RaidwrightNS:CreateInnerBorder(frame, itemQuality)
   local iborder = frame.iborder or CreateFrame("Frame", nil, frame, "BackdropTemplate")
   frame.iborder = iborder
   frame.iborder:SetPoint("TOPLEFT", 1, -1)
   frame.iborder:SetPoint("BOTTOMRIGHT", -1, 1)
   frame.iborder:SetFrameLevel(frame:GetFrameLevel())
   frame.iborder:SetBackdrop({
      edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1,
      insets = { left = -1, right = -1, top = -1, bottom = -1}
   })
   local r, g, b, alpha = 0, 0, 0, 0
   if itemQuality and itemQuality > -1 then
      r, g, b, _ = C_Item.GetItemQualityColor(itemQuality)
      alpha = 1
   end
   frame.iborder:SetBackdropBorderColor(r, g, b, alpha)
	return frame.iborder
end

function RaidwrightNS:SetBorderColor(frame, r, g, b)
   RaidwrightNS:CreateInnerBorder(frame, -1)
   frame.iborder:SetBackdropBorderColor(r, g, b, 1)
end

function RaidwrightNS:CreateCharacterName(contentFrame, charIndex, char, anchor, OffsetX, baseOffsetY, iconSize)
   contentFrame.ClassIcons[charIndex] = contentFrame.ClassIcons[charIndex] or contentFrame:CreateTexture(nil, "BACKGROUND")
   contentFrame.ClassIcons[charIndex]:Show()
   contentFrame.ClassIcons[charIndex]:SetSize(iconSize, iconSize)
   contentFrame.ClassIcons[charIndex]:SetPoint("TOPLEFT", anchor, "TOPLEFT", OffsetX, baseOffsetY * -1 * (charIndex-1))
   contentFrame.ClassIcons[charIndex]:SetTexture("Interface\\ICONS\\classicon_" .. char.Class.File)

   contentFrame.CharNames[charIndex] = contentFrame.CharNames[charIndex] or contentFrame:CreateFontString(nil,"ARTWORK","GameFontHighlight")
   contentFrame.CharNames[charIndex]:Show()
   contentFrame.CharNames[charIndex]:SetPoint("LEFT", contentFrame.ClassIcons[charIndex], "LEFT", iconSize + 5, 0)
   contentFrame.CharNames[charIndex]:SetText(char.Name)
   local cr, cg, cb = GetClassColor(char.Class.File)
   contentFrame.CharNames[charIndex]:SetTextColor(cr, cg, cb)
end

local function HidePooledWidgets(pool)
   for _, value in pairs(pool) do
      if type(value) == "table" then
         if value.GetObjectType then
            value:Hide()
         else
            HidePooledWidgets(value)
         end
      end
   end
end

-- hide all reused row widgets before a redraw, so rows that are no longer listed don't linger
function RaidwrightNS:HideRowWidgets(contentFrame)
   for key, value in pairs(contentFrame) do
      if type(value) == "table" and not value.GetObjectType then
         HidePooledWidgets(value)
      end
   end
end

function RaidwrightNS:CreateScrollFrame(parent, topX, topY, bottomX, bottomY)

   if not topX then topX = 0 end
   if not topY then topY = -32 end
   if not bottomX then bottomX = -22 end
   if not bottomY then bottomY = 0 end

   parent.ScrollFrame = parent.ScrollFrame or CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
   parent.ScrollFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", topX, topY)
   parent.ScrollFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", bottomX, bottomY)
   parent.ScrollFrame:SetScript("OnMouseWheel", function(self, delta)
      RaidwrightNS:ScrollFrame_OnMouseWheel(self, delta)
   end)
   parent.ScrollFrame:EnableMouse(true)

   parent.ScrollFrame.content = parent.ScrollFrame.content or CreateFrame("Frame", nil, parent.ScrollFrame)
   parent.ScrollFrame.content:SetSize(C["Width"] - 42, 1)

   parent.ScrollFrame:SetScrollChild(parent.ScrollFrame.content);
   return parent.ScrollFrame
end

function RaidwrightNS:ScrollFrame_OnMouseWheel(self, delta)
   local newValue = self:GetVerticalScroll() - (delta * 20)
   if (newValue < 0) then
      newValue = 0
   elseif (newValue > self:GetVerticalScrollRange()) then
      newValue = self:GetVerticalScrollRange()
   end
   self:SetVerticalScroll(newValue)
end

function RaidwrightNS:CreateButton(parent, text, width)
   local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
   button:SetSize(width or 90, 22)
   button:SetText(text)
   return button
end

function RaidwrightNS:SetSimpleTooltip(frame, title, text)
   frame:SetScript("OnEnter", function(self)
      RaidwrightNS.RaidwrightTooltip:SetOwner(self, "ANCHOR_RIGHT")
      RaidwrightNS.RaidwrightTooltip:SetText(title, 1, 1, 1)
      if text then
         RaidwrightNS.RaidwrightTooltip:AddLine(text, nil, nil, nil, true)
      end
      RaidwrightNS.RaidwrightTooltip:Show()
   end)
   frame:SetScript("OnLeave", function(self)
      RaidwrightNS.RaidwrightTooltip:Hide()
   end)
end

function RaidwrightNS:ItemOnClick(item)
   if not item.TooltipItemLink then
      return
   end
   if IsShiftKeyDown() and ChatFrame1EditBox and ChatFrame1EditBox:IsVisible() then
      ChatFrame1EditBox:Insert(item.TooltipItemLink)
   end
   if IsControlKeyDown() then
      DressUpItemLink(item.TooltipItemLink)
   end
end

function RaidwrightNS:ItemOnEnter(item)
   RaidwrightNS.RaidwrightTooltip:SetOwner(item, "ANCHOR_BOTTOMRIGHT")
   if item.TooltipItemLink then
      RaidwrightNS.RaidwrightTooltip:SetHyperlink(item.TooltipItemLink)
   end
   if item.ExtraTooltipLines then
      RaidwrightNS.RaidwrightTooltip:AddLine(" ")
      for _, line in ipairs(item.ExtraTooltipLines) do
         RaidwrightNS.RaidwrightTooltip:AddLine(line, 1, 1, 1)
      end
   end
   RaidwrightNS.RaidwrightTooltip:Show()
end

function RaidwrightNS:ItemOnLeave(item)
   RaidwrightNS.RaidwrightTooltip:Hide()
end

-- menu with the lists below owner, skipping excludeIndex, marking the selected list when showChecks is set
-- uses the Menu system when the client has it, the old UIDropDownMenu otherwise
local dropDownCount = 0
function RaidwrightNS:ShowListMenu(owner, onSelect, excludeIndex, showChecks)
   local lists = RaidwrightNS.RaidwrightData:GetLists()
   local function IsSelected(i)
      return showChecks and RaidwrightNS.RaidwrightData:GetSelectedIndex() == i
   end
   if MenuUtil and MenuUtil.CreateContextMenu then
      MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
         for i, list in ipairs(lists) do
            if i ~= excludeIndex then
               if showChecks then
                  rootDescription:CreateRadio(list.name, function() return IsSelected(i) end, function() onSelect(i) end)
               else
                  rootDescription:CreateButton(list.name, function() onSelect(i) end)
               end
            end
         end
      end)
   else
      if not owner.DropDown then
         dropDownCount = dropDownCount + 1
         owner.DropDown = CreateFrame("Frame", "RaidwrightListDropDown" .. dropDownCount, owner, "UIDropDownMenuTemplate")
      end
      UIDropDownMenu_Initialize(owner.DropDown, function(dropDown, level)
         for i, list in ipairs(lists) do
            if i ~= excludeIndex then
               local info = UIDropDownMenu_CreateInfo()
               info.text = list.name
               info.checked = IsSelected(i)
               info.notCheckable = not showChecks
               info.func = function() onSelect(i) end
               UIDropDownMenu_AddButton(info, level)
            end
         end
      end, "MENU")
      ToggleDropDownMenu(1, nil, owner.DropDown, owner, 0, 0)
   end
end

-- list selector shared by the consumables and outfits tabs
function RaidwrightNS:CreateListSelector(parent, onChanged)
   local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
   label:SetPoint("TOPLEFT", 5, -12)
   label:SetText(L["List"])

   local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
   button:SetSize(170, 22)
   button:SetPoint("LEFT", label, "RIGHT", 8, 0)

   button:SetScript("OnClick", function(self)
      RaidwrightNS:ShowListMenu(self, function(index)
         RaidwrightNS.RaidwrightData:SelectList(index)
         onChanged()
      end, nil, true)
   end)

   function button:Refresh()
      local list = RaidwrightNS.RaidwrightData:GetSelectedList()
      self:SetText((list and list.name or L["NoLists"]) .. "  |TInterface\\ChatFrame\\ChatFrameExpandArrow:0|t")
   end

   local newButton = RaidwrightNS:CreateButton(parent, L["NewList"], 70)
   newButton:SetPoint("LEFT", button, "RIGHT", 6, 0)
   newButton:SetScript("OnClick", function()
      StaticPopup_Show("RAIDWRIGHT_NEW_LIST", nil, nil, { onDone = onChanged })
   end)

   local renameButton = RaidwrightNS:CreateButton(parent, L["RenameList"], 70)
   renameButton:SetPoint("LEFT", newButton, "RIGHT", 2, 0)
   renameButton:SetScript("OnClick", function()
      local list = RaidwrightNS.RaidwrightData:GetSelectedList()
      if list then
         StaticPopup_Show("RAIDWRIGHT_RENAME_LIST", list.name, nil, { onDone = onChanged })
      end
   end)

   local deleteButton = RaidwrightNS:CreateButton(parent, L["DeleteList"], 70)
   deleteButton:SetPoint("LEFT", renameButton, "RIGHT", 2, 0)
   deleteButton:SetScript("OnClick", function()
      local list = RaidwrightNS.RaidwrightData:GetSelectedList()
      if list then
         StaticPopup_Show("RAIDWRIGHT_DELETE_LIST", list.name, nil, { onDone = onChanged })
      end
   end)

   return button
end

local function GetPopupEditBox(popup)
   return popup.editBox or popup.EditBox or (popup.GetEditBox and popup:GetEditBox())
end

local function AcceptOnEnter(editBox)
   local popup = editBox:GetParent()
   local dialog = StaticPopupDialogs[popup.which]
   dialog.OnAccept(popup, popup.data)
   popup:Hide()
end

StaticPopupDialogs["RAIDWRIGHT_NEW_LIST"] = {
   text = L["NewListPrompt"],
   button1 = ACCEPT,
   button2 = CANCEL,
   hasEditBox = true,
   maxLetters = 40,
   OnAccept = function(self, data)
      local name = strtrim(GetPopupEditBox(self):GetText() or "")
      if name ~= "" then
         RaidwrightNS.RaidwrightData:AddList(name)
         data.onDone()
      end
   end,
   EditBoxOnEnterPressed = AcceptOnEnter,
   EditBoxOnEscapePressed = function(self)
      self:GetParent():Hide()
   end,
   timeout = 0,
   whileDead = true,
   hideOnEscape = true,
   preferredIndex = 3,
}

StaticPopupDialogs["RAIDWRIGHT_RENAME_LIST"] = {
   text = L["RenameListPrompt"],
   button1 = ACCEPT,
   button2 = CANCEL,
   hasEditBox = true,
   maxLetters = 40,
   OnShow = function(self)
      local list = RaidwrightNS.RaidwrightData:GetSelectedList()
      GetPopupEditBox(self):SetText(list and list.name or "")
      GetPopupEditBox(self):HighlightText()
   end,
   OnAccept = function(self, data)
      local name = strtrim(GetPopupEditBox(self):GetText() or "")
      if name ~= "" then
         RaidwrightNS.RaidwrightData:RenameSelectedList(name)
         data.onDone()
      end
   end,
   EditBoxOnEnterPressed = AcceptOnEnter,
   EditBoxOnEscapePressed = function(self)
      self:GetParent():Hide()
   end,
   timeout = 0,
   whileDead = true,
   hideOnEscape = true,
   preferredIndex = 3,
}

StaticPopupDialogs["RAIDWRIGHT_DELETE_LIST"] = {
   text = L["DeleteListPrompt"],
   button1 = YES,
   button2 = NO,
   OnAccept = function(self, data)
      RaidwrightNS.RaidwrightData:DeleteSelectedList()
      data.onDone()
   end,
   timeout = 0,
   whileDead = true,
   hideOnEscape = true,
   showAlert = true,
   preferredIndex = 3,
}

StaticPopupDialogs["RAIDWRIGHT_DELETE_ITEM"] = {
   text = L["DeleteItemPrompt"],
   button1 = YES,
   button2 = NO,
   OnAccept = function(self, data)
      RaidwrightNS.RaidwrightData:RemoveConsumable(data.index)
      data.onDone()
   end,
   timeout = 0,
   whileDead = true,
   hideOnEscape = true,
   preferredIndex = 3,
}
