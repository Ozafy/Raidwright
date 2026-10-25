local AddonName, RaidwrightNS = ...

local C = RaidwrightNS.C
local L = LibStub("AceLocale-3.0"):GetLocale(AddonName)

local RaidwrightOverviewFrame = {}
RaidwrightNS.RaidwrightOverviewFrame = RaidwrightOverviewFrame

local _PADDING = 5
local _ROW_HEIGHT = 30
local _COLUMNS = { Raid = 5, Consumables = 260, Outfits = 480, Overall = 680 }
local _CELL_WIDTHS = { Raid = 245, Consumables = 210, Outfits = 190, Overall = 160 }
local _TAB_CONSUMABLES = 2
local _TAB_OUTFITS = 3

local STATE_COLORS = {
   none = "808080",
   ready = "1ae61a",
   bank = "ffd100",
   alts = "ff8000",
   missing = "ff1a1a",
}
local STATE_ICONS = {
   ready = "Interface\\RaidFrame\\ReadyCheck-Ready",
   bank = "Interface\\RaidFrame\\ReadyCheck-Waiting",
   alts = "Interface\\RaidFrame\\ReadyCheck-Waiting",
   missing = "Interface\\RaidFrame\\ReadyCheck-NotReady",
}

local function Colored(state, text)
   return "|cff" .. STATE_COLORS[state] .. text .. "|r"
end

local function StateText(state, text)
   local icon = STATE_ICONS[state]
   return (icon and ("|T" .. icon .. ":16|t ") or "") .. Colored(state, text)
end

local function CreateCell(row, column, onClick)
   local cell = CreateFrame("Button", nil, row)
   cell:SetSize(_CELL_WIDTHS[column], _ROW_HEIGHT)
   cell:SetPoint("LEFT", row, "LEFT", _COLUMNS[column], 0)
   cell.Text = cell:CreateFontString(nil, "ARTWORK", column == "Raid" and "GameFontNormal" or "GameFontHighlight")
   cell.Text:SetAllPoints()
   cell.Text:SetJustifyH("LEFT")
   cell.Text:SetWordWrap(false)
   cell:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
   cell:GetHighlightTexture():SetAlpha(0.4)
   cell:SetScript("OnClick", onClick)
   cell:SetScript("OnEnter", function(self)
      if self.ShowTooltip then
         RaidwrightNS.RaidwrightTooltip:SetOwner(self, "ANCHOR_RIGHT")
         self:ShowTooltip(RaidwrightNS.RaidwrightTooltip)
         RaidwrightNS.RaidwrightTooltip:Show()
      end
   end)
   cell:SetScript("OnLeave", function() RaidwrightNS.RaidwrightTooltip:Hide() end)
   return cell
end

local function SelectAndOpen(row, tabIndex)
   RaidwrightNS.RaidwrightData:SelectList(row.listIndex)
   if tabIndex then
      RaidwrightNS.RaidwrightAddon:SelectTab(tabIndex)
   else
      RaidwrightNS.RaidwrightAddon:RefreshFrame()
   end
end

local function CreateRow(content)
   local row = CreateFrame("Frame", nil, content)
   row:SetSize(C["Width"] - 50, _ROW_HEIGHT)
   row.Raid = CreateCell(row, "Raid", function() SelectAndOpen(row) end)
   row.Consumables = CreateCell(row, "Consumables", function() SelectAndOpen(row, _TAB_CONSUMABLES) end)
   row.Outfits = CreateCell(row, "Outfits", function() SelectAndOpen(row, _TAB_OUTFITS) end)
   row.Overall = CreateCell(row, "Overall", function() SelectAndOpen(row) end)
   row.Separator = row:CreateTexture(nil, "BACKGROUND")
   row.Separator:SetColorTexture(1, 1, 1, 0.08)
   row.Separator:SetHeight(1)
   row.Separator:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
   row.Separator:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
   return row
end

local function ConsumablesTooltip(readiness)
   return function(_, tooltip)
      tooltip:SetText(L["Consumables"], 1, 1, 1)
      local consumables = readiness.consumables
      if consumables.total == 0 then
         tooltip:AddLine(L["NoConsumables"], 0.5, 0.5, 0.5, true)
      elseif #consumables.short == 0 then
         tooltip:AddLine(L["ReadyState"].ready, 0.1, 0.9, 0.1)
      end
      for _, entry in ipairs(consumables.short) do
         local name, icon = RaidwrightNS:GetItemNameAndIcon(entry.itemID)
         local status = entry.status
         tooltip:AddDoubleLine("|T" .. (icon or "") .. ":0|t " .. name, status.text, 1, 0.82, 0, status.r, status.g, status.b)
      end
   end
end

local function OutfitsTooltip(readiness)
   return function(_, tooltip)
      tooltip:SetText(L["Outfits"], 1, 1, 1)
      local outfits = readiness.outfits
      if outfits.total == 0 then
         tooltip:AddLine(L["NoneTracked"], 0.5, 0.5, 0.5)
      end
      for _, outfit in ipairs(outfits.names) do
         local text = L["OutfitAllPresent"]
         if outfit.missing > 0 then
            text = L["OutfitMissing"]:format(outfit.missing)
         elseif outfit.inBank > 0 then
            text = L["OutfitInBank"]:format(outfit.inBank)
         end
         tooltip:AddDoubleLine(outfit.name, Colored(outfit.state, text), 1, 0.82, 0)
      end
   end
end

local function ConsumablesText(consumables)
   if consumables.state == "none" then
      return Colored("none", L["NoneTracked"])
   end
   if #consumables.short == 0 then
      return StateText("ready", L["ConsumablesReady"]:format(consumables.total, consumables.total))
   end
   return StateText(consumables.state, L["ConsumablesShort"]:format(#consumables.short, consumables.total))
end

local function OutfitsText(outfits)
   if outfits.state == "none" then
      return Colored("none", L["NoneTracked"])
   end
   if outfits.state == "ready" then
      return StateText("ready", L["OutfitsReady"]:format(outfits.total))
   end
   return StateText(outfits.state, L["OutfitsNotReady"]:format(outfits.inBank, outfits.missing))
end

local function CreateHeader(self)
   self.Headers = {}
   for column, title in pairs({ Raid = L["Raid"], Consumables = L["Consumables"], Outfits = L["Outfits"], Overall = L["Status"] }) do
      local header = self:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
      header:SetPoint("TOPLEFT", self, "TOPLEFT", _COLUMNS[column], -10)
      header:SetText(title)
      self.Headers[column] = header
   end

   self.Hint = self:CreateFontString(nil, "ARTWORK", "GameFontDisable")
   self.Hint:SetPoint("BOTTOMLEFT", _PADDING, 30)
   self.Hint:SetText(L["OverviewHint"])

   self.WorldBuffs = self:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
   self.WorldBuffs:SetPoint("BOTTOMLEFT", _PADDING, 8)
   self.WorldBuffs:SetPoint("BOTTOMRIGHT", -_PADDING, 8)
   self.WorldBuffs:SetJustifyH("LEFT")
   self.WorldBuffs:SetWordWrap(false)

   -- buff timers tick, the rest only changes on events
   self.elapsed = 0
   self:SetScript("OnUpdate", function(frame, elapsed)
      frame.elapsed = frame.elapsed + elapsed
      if frame.elapsed >= 1 then
         frame.elapsed = 0
         RaidwrightOverviewFrame:UpdateWorldBuffs(frame)
      end
   end)
end

function RaidwrightOverviewFrame:UpdateWorldBuffs(self)
   local parts = {}
   for _, buff in ipairs(RaidwrightNS.RaidwrightData:GetCurrentWorldBuffs()) do
      table.insert(parts, "|T" .. buff.icon .. ":16|t " .. RaidwrightNS:TimeSpanToString(buff.remaining))
   end
   if #parts == 0 then
      table.insert(parts, "|cff808080" .. L["NoWorldBuffs"] .. "|r")
   end
   local _, hasBoon, _, boonedBuffs = RaidwrightNS.RaidwrightData:GetCharacterWorldBuffs(RaidwrightNS.RaidwrightAddon.CurrentCharacterKey)
   if hasBoon then
      local count = 0
      for _ in pairs(boonedBuffs or {}) do
         count = count + 1
      end
      table.insert(parts, "|cff40c0ff" .. L["Chronoboon"] .. (boonedBuffs and (" (" .. count .. ")") or "") .. "|r")
   end
   self.WorldBuffs:SetText(L["WorldBuffs"] .. ":  " .. table.concat(parts, "   "))
end

function RaidwrightOverviewFrame:Initialize(self)
   if not self.Headers then
      CreateHeader(self)
   end

   RaidwrightNS.RaidwrightData:SnapshotOutfits()
   local scrollFrame = self.ScrollFrame or RaidwrightNS:CreateScrollFrame(self, 0, -30, -22, 48)
   local content = scrollFrame.content
   content.Rows = content.Rows or {}

   local lists = RaidwrightNS.RaidwrightData:GetLists()
   local selectedIndex = RaidwrightNS.RaidwrightData:GetSelectedIndex()
   local bagCounts = RaidwrightNS.RaidwrightData:GetBagCounts()
   local equippedCounts = RaidwrightNS.RaidwrightData:GetEquippedCounts()
   for i, list in ipairs(lists) do
      local row = content.Rows[i] or CreateRow(content)
      content.Rows[i] = row
      row.listIndex = i
      row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -_ROW_HEIGHT * (i - 1))
      row:Show()

      local readiness = RaidwrightNS.RaidwrightData:GetListReadiness(list, bagCounts, equippedCounts)
      if i == selectedIndex then
         row.Raid.Text:SetText("|TInterface\\ChatFrame\\ChatFrameExpandArrow:12|t " .. list.name)
         row.Raid.ShowTooltip = function(_, tooltip) tooltip:SetText(L["OverviewCurrentList"], 1, 1, 1) end
      else
         row.Raid.Text:SetText("     " .. list.name)
         row.Raid.ShowTooltip = nil
      end
      row.Consumables.Text:SetText(ConsumablesText(readiness.consumables))
      row.Consumables.ShowTooltip = ConsumablesTooltip(readiness)
      row.Outfits.Text:SetText(OutfitsText(readiness.outfits))
      row.Outfits.ShowTooltip = OutfitsTooltip(readiness)
      row.Overall.Text:SetText(StateText(readiness.state, L["ReadyState"][readiness.state]))
      row.Overall.ShowTooltip = nil
   end
   for i = #lists + 1, #content.Rows do
      content.Rows[i]:Hide()
   end
   content:SetSize(C["Width"] - 42, math.max(1, _ROW_HEIGHT * #lists))

   RaidwrightOverviewFrame:UpdateWorldBuffs(self)
end
