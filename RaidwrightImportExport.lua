local AddonName, RaidwrightNS = ...

local C = RaidwrightNS.C
local L = LibStub("AceLocale-3.0"):GetLocale(AddonName)

local RaidwrightImportExport = {}
RaidwrightNS.RaidwrightImportExport = RaidwrightImportExport

local window

local function Import()
   local list = RaidwrightNS.RaidwrightData:GetSelectedList()
   if not list then
      return
   end
   local imported, skipped = RaidwrightNS.RaidwrightData:ImportConsumables(window.EditBox:GetText(), window.ReplaceCheck:GetChecked())
   if imported == 0 then
      RaidwrightNS:Print(L["ImportNothing"])
      return
   end
   RaidwrightNS:Print(L["ImportDone"]:format(imported, list.name))
   if skipped > 0 then
      RaidwrightNS:Print(L["ImportSkipped"]:format(skipped))
   end
   window:Hide()
   if window.onDone then
      window.onDone()
   end
end

local function CreateWindow()
   window = CreateFrame("Frame", "RaidwrightImportExportFrame", UIParent, "BasicFrameTemplateWithInset")
   window:SetSize(480, 380)
   window:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
   window:SetFrameStrata("DIALOG")
   window:SetToplevel(true)
   window:SetClampedToScreen(true)
   window:EnableMouse(true)
   window:SetMovable(true)
   window:RegisterForDrag("LeftButton")
   window:SetScript("OnDragStart", window.StartMoving)
   window:SetScript("OnDragStop", window.StopMovingOrSizing)

   window.TitleBg:SetHeight(30)
   window.Title = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
   window.Title:SetPoint("CENTER", window.TitleBg, "CENTER", 0, 6)

   window.Hint = window:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
   window.Hint:SetPoint("TOPLEFT", 16, -34)
   window.Hint:SetPoint("RIGHT", window, "RIGHT", -16, 0)
   window.Hint:SetJustifyH("LEFT")
   window.Hint:SetText(L["ImportExportHint"])

   local scrollFrame = CreateFrame("ScrollFrame", nil, window, "UIPanelScrollFrameTemplate")
   scrollFrame:SetPoint("TOPLEFT", 16, -70)
   scrollFrame:SetPoint("BOTTOMRIGHT", -34, 72)
   local background = scrollFrame:CreateTexture(nil, "BACKGROUND")
   background:SetPoint("TOPLEFT", -4, 4)
   background:SetPoint("BOTTOMRIGHT", 4, -4)
   background:SetColorTexture(0, 0, 0, 0.5)

   window.EditBox = CreateFrame("EditBox", nil, scrollFrame)
   window.EditBox:SetMultiLine(true)
   window.EditBox:SetAutoFocus(false)
   window.EditBox:SetMaxLetters(0)
   window.EditBox:SetFontObject(ChatFontNormal)
   window.EditBox:SetWidth(424)
   window.EditBox:SetScript("OnEscapePressed", window.EditBox.ClearFocus)
   window.EditBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
   if ScrollingEdit_OnCursorChanged then
      window.EditBox:SetScript("OnCursorChanged", ScrollingEdit_OnCursorChanged)
      window.EditBox:SetScript("OnUpdate", function(self, elapsed) ScrollingEdit_OnUpdate(self, elapsed, scrollFrame) end)
   end
   scrollFrame:SetScrollChild(window.EditBox)
   -- clicking below the text should still put the cursor in the box
   scrollFrame:EnableMouse(true)
   scrollFrame:SetScript("OnMouseDown", function() window.EditBox:SetFocus() end)

   window.ReplaceCheck = CreateFrame("CheckButton", nil, window, "UICheckButtonTemplate")
   window.ReplaceCheck:SetSize(24, 24)
   window.ReplaceCheck:SetPoint("BOTTOMLEFT", 14, 40)
   window.ReplaceLabel = window:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
   window.ReplaceLabel:SetPoint("LEFT", window.ReplaceCheck, "RIGHT", 4, 0)
   window.ReplaceLabel:SetText(L["ImportReplace"])
   RaidwrightNS:SetSimpleTooltip(window.ReplaceCheck, L["ImportReplace"], L["ImportReplaceTooltip"])

   window.ImportButton = RaidwrightNS:CreateButton(window, L["Import"], 90)
   window.ImportButton:SetPoint("BOTTOMRIGHT", window, "BOTTOM", -4, 14)
   window.ImportButton:SetScript("OnClick", Import)

   window.CloseButton2 = RaidwrightNS:CreateButton(window, L["Close"], 90)
   window.CloseButton2:SetPoint("BOTTOMLEFT", window, "BOTTOM", 4, 14)
   window.CloseButton2:SetScript("OnClick", function() window:Hide() end)

   tinsert(UISpecialFrames, "RaidwrightImportExportFrame")
   window:Hide()
end

-- shows the selected list as text, onDone runs after an import
function RaidwrightImportExport:Open(onDone)
   local list = RaidwrightNS.RaidwrightData:GetSelectedList()
   if not list then
      return
   end
   if not window then
      CreateWindow()
   end
   window.onDone = onDone
   window.Title:SetText(L["ImportExport"] .. " - " .. list.name)
   window.ReplaceCheck:SetChecked(false)
   window.EditBox:SetText(RaidwrightNS.RaidwrightData:ExportConsumables())
   window:Show()
   window.EditBox:SetFocus()
   window.EditBox:HighlightText()
end

function RaidwrightImportExport:Hide()
   if window then
      window:Hide()
   end
end
