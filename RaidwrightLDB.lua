local AddonName, RaidwrightNS = ...

local C = RaidwrightNS.C
local L = LibStub("AceLocale-3.0"):GetLocale(AddonName)

local RaidwrightLDB = LibStub("LibDataBroker-1.1"):NewDataObject(AddonName, {
	type = "data source",
	text = AddonName,
	icon = C["Icon"],
	OnClick = function(self, button)
		if button == "RightButton" then
			Settings.OpenToCategory(RaidwrightNS.RaidwrightOptions.Category:GetID())
		else
			RaidwrightNS.RaidwrightAddon.ToggleFrame()
		end
	end,
})
RaidwrightNS.RaidwrightLDB = RaidwrightLDB

function RaidwrightLDB:OnTooltipShow(tooltip)
   self:AddLine(AddonName, 1, 1, 1)
   self:AddLine(" ")
   local list = RaidwrightNS.RaidwrightData:GetSelectedList()
   if list then
      local short = RaidwrightNS.RaidwrightData:GetShortConsumables(list)
      if #short > 0 then
         self:AddLine(L["ShortHeader"]:format(list.name) .. ":")
         for _, entry in ipairs(short) do
            local name, icon = RaidwrightNS:GetItemNameAndIcon(entry.itemID)
            self:AddDoubleLine("|T" .. (icon or "") .. ":0|t " .. name, entry.status.text, 1, 0.82, 0)
         end
      else
         self:AddLine(L["AllReady"]:format(list.name), 0, 1, 0)
      end
      self:AddLine(" ")
   end

   local durability = RaidwrightNS.RaidwrightData:GetDurability()
   self:AddDoubleLine(L["Repair"] .. ":", RaidwrightNS:DurabilityText(durability), 1, 1, 1)
   RaidwrightNS:AddDurabilityLines(self, durability)
   self:AddLine(" ")

   local buffs = RaidwrightNS.RaidwrightData:GetCurrentWorldBuffs()
   self:AddLine(L["WorldBuffs"] .. ":")
   if #buffs == 0 then
      self:AddLine(L["NoWorldBuffs"], 0.5, 0.5, 0.5)
   end
   for _, buff in ipairs(buffs) do
      self:AddDoubleLine("|T" .. buff.icon .. ":0|t " .. buff.name, RaidwrightNS:TimeSpanToString(buff.remaining), 1, 1, 1, 1, 1, 1)
   end

   local _, hasBoon, _, boonedBuffs = RaidwrightNS.RaidwrightData:GetCharacterWorldBuffs(RaidwrightNS.RaidwrightAddon.CurrentCharacterKey)
   if hasBoon then
      self:AddLine(" ")
      self:AddLine(L["ChronoboonStored"] .. ":")
      if not boonedBuffs then
         self:AddLine(L["ChronoboonUnknown"], 0.5, 0.5, 0.5, true)
      end
      for _, buff in pairs(boonedBuffs or {}) do
         self:AddDoubleLine("|T" .. (buff.icon or "") .. ":0|t " .. (buff.name or ""), RaidwrightNS:TimeSpanToString(buff.remaining or 0), 0.25, 0.75, 1, 0.25, 0.75, 1)
      end
   end
end

function RaidwrightLDB:OnEnter()
	GameTooltip:SetOwner(self, "ANCHOR_NONE")
	GameTooltip:SetPoint("TOPLEFT", self, "BOTTOMLEFT")
	GameTooltip:ClearLines()
	GameTooltip:Show()
end

function RaidwrightLDB:OnLeave()
	GameTooltip:Hide()
end
