local AddonName, RaidwrightNS = ...

local C = RaidwrightNS.C
local L = LibStub("AceLocale-3.0"):GetLocale(AddonName)

local RaidwrightConsumablesFrame = {}
RaidwrightNS.RaidwrightConsumablesFrame = RaidwrightConsumablesFrame

local _PADDING = 5
local _ROW_HEIGHT = 26
local _ICON_SIZE = 22
local _COLUMNS = {
   Item = 5,
   Needed = 240,
   Bags = 305,
   Bank = 360,
   Mail = 415,
   Alts = 470,
   Status = 525,
   Up = 724,
   Down = 746,
   Edit = 772,
   Remove = 820,
}

local function CreateHeader(frame, key, text)
   frame[key .. "Header"] = frame[key .. "Header"] or frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
   frame[key .. "Header"]:SetPoint("TOPLEFT", _COLUMNS[key], -44)
   frame[key .. "Header"]:SetText(text)
end

local function CreateCountText(row, key)
   row[key] = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
   row[key]:SetPoint("LEFT", row, "LEFT", _COLUMNS[key], 0)
   row[key]:SetWidth(50)
   row[key]:SetJustifyH("LEFT")
end

local function SaveInlineCount(editBox)
   local row = editBox:GetParent()
   local count = tonumber(editBox:GetText())
   local list = RaidwrightNS.RaidwrightData:GetSelectedList()
   local entry = list and list.consumables[row.entryIndex]
   if entry and count and count > 0 and count ~= entry.count then
      RaidwrightNS.RaidwrightData:SaveConsumable(row.entryIndex, entry.itemID, count)
      RaidwrightConsumablesFrame:Initialize(row.owner)
   elseif entry then
      editBox:SetText(entry.count)
   end
end

local function CreateMoveButton(row, direction, delta, owner)
   local button = CreateFrame("Button", nil, row)
   button:SetSize(22, 22)
   button:SetPoint("LEFT", row, "LEFT", _COLUMNS[direction], 0)
   button:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-Scroll" .. direction .. "-Up")
   button:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-Scroll" .. direction .. "-Down")
   button:SetDisabledTexture("Interface\\ChatFrame\\UI-ChatIcon-Scroll" .. direction .. "-Disabled")
   button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
   button:SetScript("OnClick", function()
      RaidwrightNS.RaidwrightData:MoveConsumable(row.entryIndex, delta)
      RaidwrightConsumablesFrame:Initialize(owner)
   end)
   return button
end

local function CreateRow(content, owner)
   local row = CreateFrame("Frame", nil, content)
   row:SetSize(C["Width"] - 50, _ROW_HEIGHT)
   row.owner = owner

   row.ItemButton = CreateFrame("Button", nil, row)
   row.ItemButton:SetSize(_ICON_SIZE, _ICON_SIZE)
   row.ItemButton:SetPoint("LEFT", row, "LEFT", _COLUMNS.Item, 0)
   row.ItemButton.Texture = row.ItemButton:CreateTexture(nil, "BACKGROUND")
   row.ItemButton.Texture:SetAllPoints()
   row.ItemButton:RegisterForClicks("AnyUp")
   row.ItemButton:SetScript("OnClick", function(self) RaidwrightNS:ItemOnClick(self) end)
   row.ItemButton:SetScript("OnEnter", function(self) RaidwrightNS:ItemOnEnter(self) end)
   row.ItemButton:SetScript("OnLeave", function(self) RaidwrightNS:ItemOnLeave(self) end)

   row.Name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
   row.Name:SetPoint("LEFT", row.ItemButton, "RIGHT", 6, 0)
   row.Name:SetWidth(_COLUMNS.Needed - _COLUMNS.Item - _ICON_SIZE - 16)
   row.Name:SetJustifyH("LEFT")
   row.Name:SetWordWrap(false)

   row.Needed = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
   row.Needed:SetSize(40, 20)
   row.Needed:SetPoint("LEFT", row, "LEFT", _COLUMNS.Needed + 6, 0)
   row.Needed:SetAutoFocus(false)
   row.Needed:SetNumeric(true)
   row.Needed:SetMaxLetters(5)
   row.Needed:SetScript("OnEnterPressed", function(self)
      self:ClearFocus()
   end)
   row.Needed:SetScript("OnEscapePressed", function(self)
      self:ClearFocus()
   end)
   row.Needed:SetScript("OnEditFocusLost", SaveInlineCount)

   CreateCountText(row, "Bags")
   CreateCountText(row, "Bank")
   CreateCountText(row, "Mail")

   row.AltsFrame = CreateFrame("Frame", nil, row)
   row.AltsFrame:SetSize(50, _ROW_HEIGHT)
   row.AltsFrame:SetPoint("LEFT", row, "LEFT", _COLUMNS.Alts, 0)
   row.Alts = row.AltsFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
   row.Alts:SetPoint("LEFT")
   row.AltsFrame:SetScript("OnEnter", function(self)
      if not self.details or #self.details == 0 then
         return
      end
      RaidwrightNS.RaidwrightTooltip:SetOwner(self, "ANCHOR_RIGHT")
      RaidwrightNS.RaidwrightTooltip:SetText(L["Alts"], 1, 1, 1)
      for _, alt in ipairs(self.details) do
         local cr, cg, cb = 1, 1, 1
         if alt.classFile then
            cr, cg, cb = GetClassColor(alt.classFile)
         end
         RaidwrightNS.RaidwrightTooltip:AddDoubleLine(alt.name, ("%s %d  %s %d  %s %d"):format(L["Bags"], alt.bags, L["Bank"], alt.bank, L["Mail"], alt.mail), cr, cg, cb, 1, 1, 1)
      end
      RaidwrightNS.RaidwrightTooltip:Show()
   end)
   row.AltsFrame:SetScript("OnLeave", function() RaidwrightNS.RaidwrightTooltip:Hide() end)

   row.Status = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
   row.Status:SetPoint("LEFT", row, "LEFT", _COLUMNS.Status, 0)
   row.Status:SetWidth(_COLUMNS.Up - _COLUMNS.Status - 8)

   row.UpButton = CreateMoveButton(row, "Up", -1, owner)
   row.DownButton = CreateMoveButton(row, "Down", 1, owner)
   row.Status:SetJustifyH("LEFT")
   row.Status:SetWordWrap(false)

   row.EditButton = RaidwrightNS:CreateButton(row, L["Edit"], 46)
   row.EditButton:SetPoint("LEFT", row, "LEFT", _COLUMNS.Edit, 0)
   row.EditButton:SetScript("OnClick", function(self)
      RaidwrightNS.RaidwrightItemPopup:Open(row.entryIndex, function() RaidwrightConsumablesFrame:Initialize(owner) end)
   end)

   row.RemoveButton = CreateFrame("Button", nil, row, "UIPanelCloseButton")
   row.RemoveButton:SetSize(24, 24)
   row.RemoveButton:SetPoint("LEFT", row, "LEFT", _COLUMNS.Remove, 0)
   RaidwrightNS:SetSimpleTooltip(row.RemoveButton, L["Remove"])
   row.RemoveButton:SetScript("OnClick", function(self)
      local list = RaidwrightNS.RaidwrightData:GetSelectedList()
      local entry = list and list.consumables[row.entryIndex]
      if entry then
         local name = RaidwrightNS:GetItemNameAndIcon(entry.itemID)
         StaticPopup_Show("RAIDWRIGHT_DELETE_ITEM", name, list.name, { index = row.entryIndex, onDone = function() RaidwrightConsumablesFrame:Initialize(owner) end })
      end
   end)

   return row
end

local function SetCount(fontString, value, known)
   if not known then
      fontString:SetText("?")
      fontString:SetTextColor(0.5, 0.5, 0.5)
   elseif value > 0 then
      fontString:SetText(value)
      fontString:SetTextColor(1, 1, 1)
   else
      fontString:SetText("0")
      fontString:SetTextColor(0.5, 0.5, 0.5)
   end
end

local function CreateTopBar(self)
   local refresh = function() RaidwrightNS.RaidwrightAddon:RefreshFrame() end
   self.ListSelector = RaidwrightNS:CreateListSelector(self, refresh)

   self.StoreButton = RaidwrightNS:CreateButton(self, L["StoreInBank"], 110)
   self.StoreButton:SetPoint("TOPRIGHT", self, "TOPRIGHT", -26, -6)
   self.StoreButton:SetScript("OnClick", function() RaidwrightNS.RaidwrightBank:StoreInBank() end)
   RaidwrightNS:SetSimpleTooltip(self.StoreButton, L["StoreInBank"], L["StoreInBankTooltip"])

   self.GrabButton = RaidwrightNS:CreateButton(self, L["GetFromBank"], 110)
   self.GrabButton:SetPoint("RIGHT", self.StoreButton, "LEFT", -4, 0)
   self.GrabButton:SetScript("OnClick", function() RaidwrightNS.RaidwrightBank:GrabFromBank() end)
   RaidwrightNS:SetSimpleTooltip(self.GrabButton, L["GetFromBank"], L["GetFromBankTooltip"])

   self.AddButton = RaidwrightNS:CreateButton(self, L["AddItem"], 90)
   self.AddButton:SetPoint("RIGHT", self.GrabButton, "LEFT", -12, 0)
   self.AddButton:SetScript("OnClick", function()
      RaidwrightNS.RaidwrightItemPopup:Open(nil, function() RaidwrightConsumablesFrame:Initialize(self) end)
   end)

   self.CopyButton = RaidwrightNS:CreateButton(self, L["CopyFrom"], 80)
   self.CopyButton:SetPoint("RIGHT", self.AddButton, "LEFT", -4, 0)
   RaidwrightNS:SetSimpleTooltip(self.CopyButton, L["CopyFrom"], L["CopyFromTooltip"])
   self.CopyButton:SetScript("OnClick", function(button)
      RaidwrightNS:ShowListMenu(button, function(index)
         local source = RaidwrightNS.RaidwrightData:GetLists()[index]
         local added = RaidwrightNS.RaidwrightData:CopyConsumablesFrom(index)
         RaidwrightNS:Print(L["CopyDone"]:format(added, source.name))
         RaidwrightConsumablesFrame:Initialize(self)
      end, RaidwrightNS.RaidwrightData:GetSelectedIndex())
   end)

   CreateHeader(self, "Item", L["Item"])
   CreateHeader(self, "Needed", L["Needed"])
   CreateHeader(self, "Bags", L["Bags"])
   CreateHeader(self, "Bank", L["Bank"])
   CreateHeader(self, "Mail", L["Mail"])
   CreateHeader(self, "Alts", L["Alts"])
   CreateHeader(self, "Status", L["Status"])

   self.Footer = self:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
   self.Footer:SetPoint("BOTTOMLEFT", _PADDING, 4)
end

function RaidwrightConsumablesFrame:Initialize(self)
   if not self.ListSelector then
      CreateTopBar(self)
   end
   self.ListSelector:Refresh()

   local list = RaidwrightNS.RaidwrightData:GetSelectedList()
   local hasBank = RaidwrightNS.RaidwrightBank:IsBankOpen()
   self.AddButton:SetEnabled(list ~= nil)
   self.CopyButton:SetEnabled(list ~= nil and #RaidwrightNS.RaidwrightData:GetLists() > 1)
   self.GrabButton:SetEnabled(list ~= nil and hasBank)
   self.StoreButton:SetEnabled(list ~= nil and hasBank)

   local scrollFrame = self.ScrollFrame or RaidwrightNS:CreateScrollFrame(self, 0, -62, -22, 20)
   local content = scrollFrame.content
   content.Rows = content.Rows or {}

   self.EmptyText = self.EmptyText or content:CreateFontString(nil, "ARTWORK", "GameFontDisable")
   self.EmptyText:SetPoint("TOPLEFT", _PADDING, -10)
   self.EmptyText:SetText(L["NoConsumables"])
   self.EmptyText:SetShown(list ~= nil and #list.consumables == 0)

   if RaidwrightNS.RaidwrightData:IsSyndicatorReady() then
      self.Footer:SetText("")
   else
      self.Footer:SetText(L["Syndicator_Not_Ready"])
   end

   local total = 0
   if list then
      local bagCounts = RaidwrightNS.RaidwrightData:GetBagCounts()
      for i, entry in ipairs(list.consumables) do
         local row = content.Rows[i] or CreateRow(content, self)
         content.Rows[i] = row
         row.entryIndex = i
         row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -_ROW_HEIGHT * (i - 1))
         row:Show()
         row.UpButton:SetEnabled(i > 1)
         row.DownButton:SetEnabled(i < #list.consumables)

         local name, icon, link, quality = RaidwrightNS:GetItemNameAndIcon(entry.itemID, function()
            if self:IsVisible() then
               RaidwrightConsumablesFrame:Initialize(self)
            end
         end)
         row.ItemButton.Texture:SetTexture(icon)
         row.ItemButton.TooltipItemLink = link or ("item:" .. entry.itemID)
         RaidwrightNS:CreateInnerBorder(row.ItemButton, quality)
         row.Name:SetText(name)
         if quality and quality > -1 then
            local r, g, b = C_Item.GetItemQualityColor(quality)
            row.Name:SetTextColor(r, g, b)
         else
            row.Name:SetTextColor(1, 1, 1)
         end
         if not row.Needed:HasFocus() then
            row.Needed:SetText(entry.count)
         end

         local counts = RaidwrightNS.RaidwrightData:GetItemCounts(entry.itemID, bagCounts)
         SetCount(row.Bags, counts.bags, true)
         SetCount(row.Bank, counts.bank, counts.bankKnown)
         SetCount(row.Mail, counts.mail, true)
         SetCount(row.Alts, counts.alts, RaidwrightNS.RaidwrightData:IsSyndicatorReady())
         row.AltsFrame.details = counts.altDetails

         local status = RaidwrightNS.RaidwrightData:GetConsumableStatus(entry, counts)
         row.Status:SetText(status.text)
         row.Status:SetTextColor(status.r, status.g, status.b)
         total = total + 1
      end
   end
   -- rows are only hidden when unused, hiding a row would take the focus from its count box while typing
   for i = total + 1, #content.Rows do
      content.Rows[i]:Hide()
   end
   content:SetSize(C["Width"] - 42, math.max(1, _ROW_HEIGHT * total))
end
