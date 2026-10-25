local AddonName, RaidwrightNS = ...

local C = RaidwrightNS.C
local L = LibStub("AceLocale-3.0"):GetLocale(AddonName)

local Raidwrighticon = LibStub("LibDBIcon-1.0")
local RaidwrightOptionsCategory, RaidwrightOptionsLayout = Settings.RegisterVerticalLayoutCategory(AddonName)

local RaidwrightOptions = {}
RaidwrightNS.RaidwrightOptions = RaidwrightOptions
RaidwrightNS.RaidwrightOptions.Category = RaidwrightOptionsCategory
RaidwrightNS.RaidwrightOptions.Layout = RaidwrightOptionsLayout

local function OnMinimapSettingChanged(setting, value)
   if value then
      Raidwrighticon:Hide(AddonName)
   else
      Raidwrighticon:Show(AddonName)
   end
end

local charToDelete = ""

local function GetCharacterToDelete()
   return charToDelete
end

local function SetCharacterToDelete(value)
   charToDelete = value
end

local function GetAllCharactersSortedByRealmContainer()
   local characterNames = {}
   for key, char in pairs(RaidwrightNS.RaidwrightDB.global.characters) do
      table.insert(characterNames, char.Realm .. "-" .. char.Name)
   end
   table.sort(characterNames)

   local container = Settings.CreateControlTextContainer()
   container:Add("", L["OptionSelectCharacter"])
   for i, char in ipairs(characterNames) do
      container:Add(char, char)
   end
   return container:GetData()
end

local function DeleteCharacter()
   if charToDelete == "" then
      return
   end
   local realm, name = strsplit("-", charToDelete, 2)
   local key = name .. "-" .. realm
   local char = RaidwrightNS.RaidwrightDB.global.characters[key]
   if char then
      local cr, cg, cb, web = GetClassColor(char.Class.File)
      RaidwrightNS:Print("Deleting '\124c" .. web .. name .. "\124r' from realm '" .. realm .. "'.")
      RaidwrightNS.RaidwrightDB.global.characters[key] = nil
   end
   Settings.SetValue("Raidwright_Character_To_Delete", "")
end

local function CreateOptionsCategory()
   local initializer = Settings.CreateSettingInitializer("SettingsListSectionHeaderTemplate", { name = L["OptionsSettingsHeader"] });
   RaidwrightOptionsLayout:AddInitializer(initializer);

	local minimapSetting = Settings.RegisterAddOnSetting(
      RaidwrightOptionsCategory,
      "Raidwright_Minimap_Toggle",
      "hide",
      RaidwrightNS.RaidwrightDB.profile.minimap,
      Settings.VarType.Boolean,
      L["OptionMinimap"],
      Settings.Default.False
   )
	minimapSetting:SetValueChangedCallback(OnMinimapSettingChanged)
	Settings.CreateCheckbox(RaidwrightOptionsCategory, minimapSetting, L["OptionMinimap"])

	local loginAlertSetting = Settings.RegisterAddOnSetting(
      RaidwrightOptionsCategory,
      "Raidwright_LoginAlert_Toggle",
      "hideLoginAlert",
      RaidwrightNS.RaidwrightDB.profile.settings,
      Settings.VarType.Boolean,
      L["OptionLoginAlert"],
      Settings.Default.False
   )
	Settings.CreateCheckbox(RaidwrightOptionsCategory, loginAlertSetting, L["OptionLoginAlertText"])

   initializer = Settings.CreateSettingInitializer("SettingsListSectionHeaderTemplate", { name = L["OptionsDeleteHeader"] });
   RaidwrightOptionsLayout:AddInitializer(initializer);

	local deleteCharacterSetting = Settings.RegisterProxySetting(
		RaidwrightOptionsCategory,
		"Raidwright_Character_To_Delete",
		Settings.VarType.String,
		L["OptionSelectCharacterToDelete"],
		"",
		GetCharacterToDelete,
		SetCharacterToDelete
	)
	Settings.CreateDropdown(RaidwrightOptionsCategory, deleteCharacterSetting, GetAllCharactersSortedByRealmContainer)

	local deleteButtonInitializer = CreateSettingsButtonInitializer(
		L["OptionDeleteSelected"],
		L["OptionDelete"],
		DeleteCharacter,
		L["OptionDeleteTooltip"],
		true,
		nil,
		nil
	)
	RaidwrightOptionsLayout:AddInitializer(deleteButtonInitializer)

   Settings.RegisterAddOnCategory(RaidwrightOptionsCategory)
end

function RaidwrightOptions:Initialize()
   CreateOptionsCategory()
end
