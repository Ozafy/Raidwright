local AddonName, RaidwrightNS = ...

local C = RaidwrightNS.C
local L = LibStub("AceLocale-3.0"):GetLocale(AddonName)

local RaidwrightWorldBuffsFrame = {}
RaidwrightNS.RaidwrightWorldBuffsFrame = RaidwrightWorldBuffsFrame

local _PADDING = 5
local _ICON_SIZE = 20
local _HEIGHT = 26
local _NAME_WIDTH = 170
local _HEADER_ICON_SIZE = 28

local function GetColumnWidth(columnCount)
   return math.min(80, math.floor((C["Width"] - 50 - _NAME_WIDTH) / columnCount))
end

local function CreateHeaderIcon(self, index, icon, title, text, x)
   self.HeaderIcons = self.HeaderIcons or {}
   local frame = self.HeaderIcons[index] or CreateFrame("Frame", nil, self)
   self.HeaderIcons[index] = frame
   frame:SetSize(_HEADER_ICON_SIZE, _HEADER_ICON_SIZE)
   frame:SetPoint("TOPLEFT", self, "TOPLEFT", x, -8)
   frame.Texture = frame.Texture or frame:CreateTexture(nil, "BACKGROUND")
   frame.Texture:SetAllPoints()
   frame.Texture:SetTexture(icon)
   RaidwrightNS:CreateInnerBorder(frame, 1)
   RaidwrightNS:SetSimpleTooltip(frame, title, text)
   frame:Show()
end

-- booned timers are paused, so they're shown in a different color than active buffs
local function BoonedColor(text)
   return "|cff40c0ff" .. text:gsub("\124r", "\124r\124cff40c0ff") .. "|r"
end

local function UpdateChronoboonCell(content, i, j, columnWidth, chronoboon, boonedBuffs, columns)
   local cell = content.Cells[i][j]
   if not cell then
      cell = CreateFrame("Frame", nil, content)
      cell:SetSize(columnWidth, _HEIGHT)
      cell.Text = cell:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
      cell.Text:SetAllPoints()
      cell.Text:SetJustifyH("CENTER")
      cell:SetScript("OnLeave", function() RaidwrightNS.RaidwrightTooltip:Hide() end)
      content.Cells[i][j] = cell
   end
   cell:Show()
   cell:SetWidth(columnWidth)
   cell:SetPoint("LEFT", content.ClassIcons[i], "LEFT", _NAME_WIDTH - _PADDING + (j - 1) * columnWidth, 0)

   local count = 0
   for _ in pairs(boonedBuffs or {}) do
      count = count + 1
   end
   if not chronoboon then
      cell.Text:SetText("|cff808080-|r")
   elseif boonedBuffs then
      cell.Text:SetText(BoonedColor(tostring(count)))
   else
      cell.Text:SetText("|TInterface\\RaidFrame\\ReadyCheck-Ready:0|t")
   end

   cell:SetScript("OnEnter", function(self)
      if not chronoboon then
         return
      end
      RaidwrightNS.RaidwrightTooltip:SetOwner(self, "ANCHOR_RIGHT")
      RaidwrightNS.RaidwrightTooltip:SetText(L["ChronoboonStored"], 1, 1, 1)
      if not boonedBuffs then
         RaidwrightNS.RaidwrightTooltip:AddLine(L["ChronoboonUnknown"], nil, nil, nil, true)
      elseif count == 0 then
         RaidwrightNS.RaidwrightTooltip:AddLine(L["NoWorldBuffs"], 0.5, 0.5, 0.5)
      else
         -- column order, so the tooltip matches the table
         for _, column in ipairs(columns) do
            local buff = boonedBuffs[column.key]
            if buff then
               RaidwrightNS.RaidwrightTooltip:AddDoubleLine("|T" .. (buff.icon or column.icon) .. ":0|t " .. (buff.name or column.name), RaidwrightNS:TimeSpanToString(buff.remaining or 0), 1, 1, 1, 1, 1, 1)
            end
         end
      end
      RaidwrightNS.RaidwrightTooltip:Show()
   end)
end

function RaidwrightWorldBuffsFrame:Initialize(self)
   local columns = RaidwrightNS.RaidwrightData:GetWorldBuffColumns()
   local columnWidth = GetColumnWidth(#columns + 1)

   self.NameHeader = self.NameHeader or self:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
   self.NameHeader:SetPoint("TOPLEFT", _PADDING, -16)
   self.NameHeader:SetText(L["Characters"])

   for i, column in ipairs(columns) do
      CreateHeaderIcon(self, i, column.icon, column.name, nil, _NAME_WIDTH + (i - 1) * columnWidth + (columnWidth - _HEADER_ICON_SIZE) / 2)
   end
   local chronoboonName, _, chronoboonIcon = RaidwrightNS.GetSpellInfo(C["ChronoboonSpells"][1])
   CreateHeaderIcon(self, #columns + 1, chronoboonIcon or 134400, chronoboonName or L["Chronoboon"], L["ChronoboonStored"], _NAME_WIDTH + #columns * columnWidth + (columnWidth - _HEADER_ICON_SIZE) / 2)

   local scrollFrame = self.ScrollFrame or RaidwrightNS:CreateScrollFrame(self, 0, -44)
   local content = scrollFrame.content
   RaidwrightNS:HideRowWidgets(content)
   content.ClassIcons = content.ClassIcons or {}
   content.CharNames = content.CharNames or {}
   content.Cells = content.Cells or {}

   local characters = RaidwrightNS:GetRealmCharactersSorted()
   for i, key in ipairs(characters) do
      local char = RaidwrightNS.RaidwrightDB.global.characters[key]
      RaidwrightNS:CreateCharacterName(content, i, char, content, _PADDING, _HEIGHT, _ICON_SIZE)

      local buffs, chronoboon, live, boonedBuffs = RaidwrightNS.RaidwrightData:GetCharacterWorldBuffs(key)
      content.Cells[i] = content.Cells[i] or {}
      for j = 1, #columns do
         local cell = content.Cells[i][j] or content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
         content.Cells[i][j] = cell
         cell:Show()
         cell:SetWidth(columnWidth)
         cell:SetJustifyH("CENTER")
         cell:SetPoint("LEFT", content.ClassIcons[i], "LEFT", _NAME_WIDTH - _PADDING + (j - 1) * columnWidth, 0)
         local column = columns[j]
         local buff = buffs[column.key]
         local booned = boonedBuffs and boonedBuffs[column.key]
         if buff then
            if buff.remaining and buff.remaining > 0 then
               cell:SetText(RaidwrightNS:TimeSpanToString(buff.remaining))
            else
               cell:SetText("|TInterface\\RaidFrame\\ReadyCheck-Ready:0|t")
            end
            cell:SetAlpha(live and 1 or 0.75)
         elseif booned then
            cell:SetText(BoonedColor(RaidwrightNS:TimeSpanToString(booned.remaining or 0)))
            cell:SetAlpha(1)
         else
            cell:SetText("|cff808080-|r")
            cell:SetAlpha(1)
         end
      end
      UpdateChronoboonCell(content, i, #columns + 1, columnWidth, chronoboon, boonedBuffs, columns)
   end
   content:SetSize(C["Width"] - 42, math.max(1, _HEIGHT * #characters))

   -- the logged in character's timers tick, refresh once a second while visible
   if not self.Ticker then
      self.Ticker = true
      self.elapsed = 0
      self:SetScript("OnUpdate", function(frame, elapsed)
         frame.elapsed = frame.elapsed + elapsed
         if frame.elapsed >= 1 then
            frame.elapsed = 0
            RaidwrightWorldBuffsFrame:Initialize(frame)
         end
      end)
   end
end
