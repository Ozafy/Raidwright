local AddonName, RaidwrightNS = ...

local C = RaidwrightNS.C
local L = LibStub("AceLocale-3.0"):GetLocale(AddonName)

local RaidwrightLDB = RaidwrightNS.RaidwrightLDB

local icon = LibStub("LibDBIcon-1.0")

local RaidwrightFrame

local RaidwrightAddon = LibStub("AceAddon-3.0"):NewAddon(AddonName, "AceEvent-3.0", "AceTimer-3.0")
RaidwrightNS.RaidwrightAddon = RaidwrightAddon

local pendingTimers = {}
-- (re)starts a timer for key, so a burst of events results in a single call
local function ScheduleOnce(key, func, delay)
   if pendingTimers[key] then
      RaidwrightAddon:CancelTimer(pendingTimers[key])
   end
   pendingTimers[key] = RaidwrightAddon:ScheduleTimer(function()
      pendingTimers[key] = nil
      -- events can fire during loading, before the character data is set up
      if RaidwrightAddon.CurrentCharacter.Name then
         func()
      end
   end, delay)
end

local function BagsChanged()
   if RaidwrightNS.RaidwrightBank:IsBankOpen() then
      RaidwrightNS.RaidwrightData:ScanBank()
   else
      RaidwrightAddon:RefreshFrame()
   end
end

SLASH_RAIDWRIGHT1, SLASH_RAIDWRIGHT2 = "/rdw", "/raidwright"

SlashCmdList.RAIDWRIGHT = function(msg, editBox)
   if msg == "options" or msg == "o" then
      Settings.OpenToCategory(RaidwrightNS.RaidwrightOptions.Category:GetID())
   else
      RaidwrightAddon:ToggleFrame()
   end
end

function RaidwrightAddon:OnInitialize()
	local RaidwrightDB = LibStub("AceDB-3.0"):New("RaidwrightDB", {
		profile = {
			minimap = {
				hide = false,
			},
         settings = {
            hideLoginAlert = false,
         }
		},
      global = {
         characters = {},
      }
	})
   RaidwrightNS.RaidwrightDB = RaidwrightDB
	icon:Register(AddonName, RaidwrightLDB, RaidwrightDB.profile.minimap)
   if RaidwrightDB.global.dbversion ~= C["MajorDBVersion"] then
      RaidwrightDB.global.characters = {}
      RaidwrightDB.global.dbversion = C["MajorDBVersion"]
   end
   RaidwrightAddon.CurrentCharacter = {}
   self:RegisterEvent("PLAYER_ENTERING_WORLD")
   self:RegisterEvent("PLAYER_LOGOUT")
   self:RegisterEvent("BANKFRAME_OPENED")
   self:RegisterEvent("BANKFRAME_CLOSED")
   self:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
   self:RegisterEvent("PLAYERBANKBAGSLOTS_CHANGED")
   self:RegisterEvent("BAG_UPDATE_DELAYED")
   self:RegisterEvent("MAIL_INBOX_UPDATE")
   self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
   self:RegisterEvent("UNIT_AURA")
   self:RegisterEvent("UNIT_SPELLCAST_START")
   self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
   RaidwrightNS.RaidwrightOptions:Initialize()
end

function RaidwrightAddon:OnDisable()
   self:UnregisterEvent("PLAYER_ENTERING_WORLD")
   self:UnregisterEvent("PLAYER_LOGOUT")
   self:UnregisterEvent("BANKFRAME_OPENED")
   self:UnregisterEvent("BANKFRAME_CLOSED")
   self:UnregisterEvent("PLAYERBANKSLOTS_CHANGED")
   self:UnregisterEvent("PLAYERBANKBAGSLOTS_CHANGED")
   self:UnregisterEvent("BAG_UPDATE_DELAYED")
   self:UnregisterEvent("MAIL_INBOX_UPDATE")
   self:UnregisterEvent("PLAYER_EQUIPMENT_CHANGED")
   self:UnregisterEvent("UNIT_AURA")
   self:UnregisterEvent("UNIT_SPELLCAST_START")
   self:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
end

function RaidwrightAddon:PLAYER_ENTERING_WORLD(event, isLogin, isReload)
   if isLogin or isReload then
      RaidwrightNS.RaidwrightData:SavePlayerDataLogin()
      -- Outfitter waits a few seconds before it initializes
      RaidwrightAddon:ScheduleTimer(function() RaidwrightNS.RaidwrightData:SnapshotOutfits() end, 10)
   end
   if isLogin then
      RaidwrightAddon:ScheduleTimer(RaidwrightNS.RaidwrightData.NotifyOnLogin, 6)
   end
   ScheduleOnce("worldBuffs", RaidwrightNS.RaidwrightData.SaveWorldBuffs, 2)
end

function RaidwrightAddon:PLAYER_LOGOUT()
   RaidwrightNS.RaidwrightData:SaveWorldBuffs()
end

function RaidwrightAddon:BANKFRAME_OPENED()
   RaidwrightNS.RaidwrightBank:SetBankOpen(true)
   ScheduleOnce("bank", RaidwrightNS.RaidwrightData.ScanBank, 0.5)
end

function RaidwrightAddon:BANKFRAME_CLOSED()
   RaidwrightNS.RaidwrightBank:SetBankOpen(false)
   RaidwrightAddon:RefreshFrame()
end

function RaidwrightAddon:PLAYERBANKSLOTS_CHANGED()
   ScheduleOnce("bags", BagsChanged, 0.3)
end

function RaidwrightAddon:PLAYERBANKBAGSLOTS_CHANGED()
   ScheduleOnce("bags", BagsChanged, 0.3)
end

function RaidwrightAddon:BAG_UPDATE_DELAYED()
   ScheduleOnce("bags", BagsChanged, 0.3)
end

function RaidwrightAddon:MAIL_INBOX_UPDATE()
   ScheduleOnce("mail", RaidwrightNS.RaidwrightData.ScanMail, 0.5)
end

function RaidwrightAddon:PLAYER_EQUIPMENT_CHANGED()
   ScheduleOnce("refresh", RaidwrightAddon.RefreshFrame, 0.3)
end

function RaidwrightAddon:UNIT_AURA(event, unit)
   if unit == "player" then
      ScheduleOnce("worldBuffs", RaidwrightNS.RaidwrightData.SaveWorldBuffs, 1)
   end
end

function RaidwrightAddon:UNIT_SPELLCAST_START(event, unit, castGUID, spellId)
   RaidwrightNS.RaidwrightData:SpellCastStart(unit, spellId)
end

function RaidwrightAddon:UNIT_SPELLCAST_SUCCEEDED(event, unit, castGUID, spellId)
   RaidwrightNS.RaidwrightData:SpellCastSucceeded(unit, spellId)
end

function RaidwrightAddon:GetMainFrame()
   return RaidwrightFrame or RaidwrightAddon:CreateMainFrame()
end

-- redraws the visible tab, if any
function RaidwrightAddon:RefreshFrame()
   if not RaidwrightFrame or not RaidwrightFrame:IsShown() then
      return
   end
   for i = 1, #RaidwrightNS.Tabs do
      local tab = RaidwrightNS.Tabs[i]
      if tab.content:IsShown() and tab.content.Refresh then
         tab.content:Refresh(tab.content)
      end
   end
end

function RaidwrightAddon:ToggleFrame()
   local frame = RaidwrightAddon:GetMainFrame()
   frame:SetShown(not frame:IsShown())
   RaidwrightAddon:RefreshFrame()
end

local function SetTitle(title)
   RaidwrightFrame.Title:SetText(title)
end

local function Tab_OnClick(self)
   PanelTemplates_SetTab(self:GetParent(), self:GetID())

   for i = 1, #RaidwrightNS.Tabs do
      local tab = RaidwrightNS.Tabs[i]
      if tab.content:IsShown() then
         tab.content:Hide()
      end
   end
   SetTitle(AddonName .. " - " .. self.Name)
   self.content:LoadContent(self.content)
   self.content:Show()
end

function RaidwrightAddon:SelectTab(index)
   if RaidwrightNS.Tabs and RaidwrightNS.Tabs[index] then
      Tab_OnClick(RaidwrightNS.Tabs[index])
   end
end

local function CreateTabs(frame,  ...)
   local args = {...}
   RaidwrightNS.Tabs = RaidwrightNS.Tabs or {}
   local frameName = frame:GetName()
   for i, name in ipairs(args) do
      local tab = CreateFrame("Button", frameName.."Tab"..i, frame, "CharacterFrameTabButtonTemplate")
      tab:SetID(i)
      tab:SetText(name)
      tab.Name = name
      tab:SetScript("OnClick", Tab_OnClick)

      tab.content = CreateFrame("Frame", nil, frame)
      tab.content:SetSize(C["Width"], C["Height"])
      tab.content:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -28)
      tab.content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 6)
      tab.content:Hide()

      table.insert(RaidwrightNS.Tabs, tab)

      if(i==1) then
         tab:SetPoint("TOPLEFT", RaidwrightFrame, "BOTTOMLEFT", 0, 2)
      else
         tab:SetPoint("TOPLEFT", RaidwrightNS.Tabs[i-1], "TOPRIGHT", -14, 0)
      end
   end
   frame.numTabs = #RaidwrightNS.Tabs
   return unpack(RaidwrightNS.Tabs)
end

function RaidwrightAddon:CreateMainFrame()
   RaidwrightFrame = CreateFrame("Frame", "RaidwrightFrame", UIParent, "BasicFrameTemplateWithInset")
   RaidwrightFrame:SetSize(C["Width"], C["Height"])
   RaidwrightFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
   RaidwrightFrame:SetToplevel(true)
   RaidwrightFrame:SetClampedToScreen(true)
   RaidwrightFrame:EnableMouse(true)
   RaidwrightFrame:SetMovable(true)
   RaidwrightFrame:RegisterForDrag("LeftButton")
   RaidwrightFrame:SetScript("OnDragStart", function(self)
      RaidwrightFrame:StartMoving()
   end)
   RaidwrightFrame:SetScript("OnDragStop", function(self)
      RaidwrightFrame:StopMovingOrSizing()
   end)

   RaidwrightFrame:SetScript("OnShow", function()
         PlaySound(808)
   end)

   RaidwrightFrame:SetScript("OnHide", function()
         PlaySound(808)
         RaidwrightNS.RaidwrightItemPopup:Hide()
   end)

   RaidwrightNS.RaidwrightTooltip = CreateFrame("GameTooltip", "RaidwrightTooltipFrame", RaidwrightFrame, "GameTooltipTemplate")
   RaidwrightNS.RaidwrightTooltip:SetFrameStrata("TOOLTIP")

   RaidwrightFrame.TitleBg:SetHeight(30)
   RaidwrightFrame.Title = RaidwrightFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
   RaidwrightFrame.Title:SetPoint("CENTER", RaidwrightFrame.TitleBg, "CENTER", 0, 6)
   SetTitle(AddonName)

   RaidwrightFrame.OptionsButton = RaidwrightFrame.OptionsButton or CreateFrame("Button", nil, RaidwrightFrame, "GameMenuButtonTemplate");
   RaidwrightFrame.OptionsButton:SetPoint("TOPRIGHT", RaidwrightFrame, "TOPRIGHT", -23, 2);
   RaidwrightFrame.OptionsButton:SetSize(24, 24);
   RaidwrightFrame.OptionsButton:SetText("|TInterface\\Buttons\\UI-OptionsButton:0|t");
   RaidwrightFrame.OptionsButton:SetNormalFontObject("GameFontNormal");
   RaidwrightFrame.OptionsButton:SetHighlightFontObject("GameFontHighlight");
   RaidwrightFrame.OptionsButton:SetScript("OnClick", function(button)
      Settings.OpenToCategory(RaidwrightNS.RaidwrightOptions.Category:GetID())
   end)

   local overviewView, consumablesView, outfitsView, worldBuffsView = CreateTabs(RaidwrightFrame, L["Overview"], L["Consumables"], L["Outfits"], L["WorldBuffs"])
   overviewView.content.LoadContent = RaidwrightNS.RaidwrightOverviewFrame.Initialize
   overviewView.content.Refresh = RaidwrightNS.RaidwrightOverviewFrame.Initialize
   consumablesView.content.LoadContent = RaidwrightNS.RaidwrightConsumablesFrame.Initialize
   consumablesView.content.Refresh = RaidwrightNS.RaidwrightConsumablesFrame.Initialize
   outfitsView.content.LoadContent = RaidwrightNS.RaidwrightOutfitsFrame.Initialize
   outfitsView.content.Refresh = RaidwrightNS.RaidwrightOutfitsFrame.Initialize
   worldBuffsView.content.LoadContent = RaidwrightNS.RaidwrightWorldBuffsFrame.Initialize
   worldBuffsView.content.Refresh = RaidwrightNS.RaidwrightWorldBuffsFrame.Initialize

   Tab_OnClick(overviewView)
   tinsert(UISpecialFrames, "RaidwrightFrame");
   RaidwrightFrame:Hide()
   return RaidwrightFrame
end
