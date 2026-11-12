local AddonName, RaidwrightNS = ...

local C = RaidwrightNS.C
local L = LibStub("AceLocale-3.0"):GetLocale(AddonName)

local RaidwrightMacrosFrame = {}
RaidwrightNS.RaidwrightMacrosFrame = RaidwrightMacrosFrame

local Macros = RaidwrightNS.RaidwrightMacros

local _PADDING = 5
local _MACRO_LIST_WIDTH = 170
local _MACRO_ROW_HEIGHT = 22
local _EDITOR_X = _PADDING + _MACRO_LIST_WIDTH + 15
local _LABEL_WIDTH = 160
local _BOX_WIDTH = C["Width"] - _EDITOR_X - _LABEL_WIDTH - 60
local _MIN_BOX_HEIGHT = 34
local _ROW_GAP = 6

-- rows are stacked under each other, their height follows the text in their box
local function Layout(content)
   local y = 0
   for _, row in ipairs(content.Rows or {}) do
      if row:IsShown() then
         local height = math.max(_MIN_BOX_HEIGHT, row.EditBox:GetHeight() + 10)
         row.Box:SetHeight(height)
         row:SetHeight(height)
         row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
         y = y + height + _ROW_GAP
      end
   end
   content:SetHeight(math.max(1, y))
end

local function UpdateRowCounter(row)
   local length = strlenutf8(row.EditBox:GetText())
   row.Counter:SetText(("%d/%d"):format(length, C["MacroMaxLength"]))
   row.Placeholder:SetShown(length == 0)
end

local function CreateRaidRow(content)
   local row = CreateFrame("Frame", nil, content)
   row:SetWidth(_LABEL_WIDTH + _BOX_WIDTH + 10)

   row.Label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
   row.Label:SetPoint("TOPLEFT", row, "TOPLEFT", _PADDING, -6)
   row.Label:SetWidth(_LABEL_WIDTH - 10)
   row.Label:SetJustifyH("LEFT")
   row.Label:SetWordWrap(false)

   row.Counter = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
   row.Counter:SetPoint("TOPLEFT", row.Label, "BOTTOMLEFT", 0, -3)

   row.Box = CreateFrame("Button", nil, row, "BackdropTemplate")
   row.Box:SetPoint("TOPLEFT", row, "TOPLEFT", _LABEL_WIDTH, 0)
   row.Box:SetWidth(_BOX_WIDTH)
   row.Box:SetBackdrop({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 12,
      insets = { left = 3, right = 3, top = 3, bottom = 3 },
   })
   row.Box:SetBackdropColor(0, 0, 0, 0.6)
   row.Box:SetBackdropBorderColor(0.5, 0.5, 0.5)

   local editBox = CreateFrame("EditBox", nil, row.Box)
   editBox:SetMultiLine(true)
   editBox:SetAutoFocus(false)
   editBox:SetFontObject(ChatFontNormal)
   editBox:SetMaxLetters(C["MacroMaxLength"])
   editBox:SetWidth(_BOX_WIDTH - 14)
   editBox:SetPoint("TOPLEFT", row.Box, "TOPLEFT", 7, -5)
   editBox:SetScript("OnEscapePressed", editBox.ClearFocus)
   editBox:SetScript("OnTextChanged", function(self, userInput)
      UpdateRowCounter(row)
      if userInput and row.macro then
         Macros:SetBody(row.macro, row.list, self:GetText())
      end
   end)
   -- a multi line box grows with its text, the rows below move along
   editBox:SetScript("OnSizeChanged", function()
      Layout(content)
   end)
   row.EditBox = editBox
   row.Box:SetScript("OnClick", function() editBox:SetFocus() end)

   row.Placeholder = editBox:CreateFontString(nil, "ARTWORK", "GameFontDisable")
   row.Placeholder:SetPoint("TOPLEFT", editBox, "TOPLEFT", 0, 0)
   return row
end

local function CreateMacroButton(parent, owner)
   local button = CreateFrame("Button", nil, parent)
   button:SetSize(_MACRO_LIST_WIDTH, _MACRO_ROW_HEIGHT)
   button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
   button.Selected = button:CreateTexture(nil, "BACKGROUND")
   button.Selected:SetTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight")
   button.Selected:SetBlendMode("ADD")
   button.Selected:SetVertexColor(1, 0.82, 0)
   button.Selected:SetAllPoints()
   button.Text = button:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
   button.Text:SetPoint("LEFT", 8, 0)
   button.Text:SetPoint("RIGHT", -8, 0)
   button.Text:SetJustifyH("LEFT")
   button:SetScript("OnClick", function(self)
      Macros:SelectMacro(self.macroIndex)
      RaidwrightMacrosFrame:Initialize(owner)
   end)
   return button
end

local function SaveName(editBox)
   local owner = editBox.owner
   local macro = Macros:GetSelectedMacro()
   if not macro then
      return
   end
   local name = strtrim(editBox:GetText() or "")
   if name ~= macro.name then
      if name == "" then
         editBox:SetText(macro.name)
      elseif Macros:IsNameTaken(name, macro) then
         RaidwrightNS:Print(L["MacroNameTaken"]:format(name))
         editBox:SetText(macro.name)
      elseif not Macros:RenameMacro(macro, name) then
         editBox:SetText(macro.name)
      end
   end
   RaidwrightMacrosFrame:Initialize(owner)
end

local function CreateTopBar(self)
   local refresh = function() RaidwrightNS.RaidwrightAddon:RefreshFrame() end
   self.ListSelector = RaidwrightNS:CreateListSelector(self, refresh)

   self.NewMacroButton = RaidwrightNS:CreateButton(self, L["NewMacro"], 110)
   self.NewMacroButton:SetPoint("TOPRIGHT", self, "TOPRIGHT", -26, -6)
   self.NewMacroButton:SetScript("OnClick", function()
      StaticPopup_Show("RAIDWRIGHT_NEW_MACRO", nil, nil, { onDone = refresh })
   end)

   self.MacroListHeader = self:CreateFontString(nil, "ARTWORK", "GameFontNormal")
   self.MacroListHeader:SetPoint("TOPLEFT", _PADDING, -44)
   self.MacroListHeader:SetText(L["Macros"])

   self.Message = self:CreateFontString(nil, "ARTWORK", "GameFontDisable")
   self.Message:SetPoint("TOPLEFT", _EDITOR_X, -44)
   self.Message:SetWidth(C["Width"] - _EDITOR_X - 40)
   self.Message:SetJustifyH("LEFT")

   -- editor for the selected macro
   local editor = CreateFrame("Frame", nil, self)
   editor:SetPoint("TOPLEFT", self, "TOPLEFT", _EDITOR_X, -40)
   editor:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 0)
   self.Editor = editor

   editor.NameLabel = editor:CreateFontString(nil, "ARTWORK", "GameFontNormal")
   editor.NameLabel:SetPoint("TOPLEFT", _PADDING, -4)
   editor.NameLabel:SetText(L["MacroName"])

   editor.NameBox = CreateFrame("EditBox", nil, editor, "InputBoxTemplate")
   editor.NameBox:SetSize(150, 20)
   editor.NameBox:SetPoint("LEFT", editor.NameLabel, "RIGHT", 10, 0)
   editor.NameBox:SetAutoFocus(false)
   editor.NameBox:SetMaxLetters(C["MacroNameMaxLength"])
   editor.NameBox.owner = self
   editor.NameBox:SetScript("OnEnterPressed", function(box) box:ClearFocus() end)
   editor.NameBox:SetScript("OnEscapePressed", function(box)
      local macro = Macros:GetSelectedMacro()
      box:SetText(macro and macro.name or "")
      box:ClearFocus()
   end)
   editor.NameBox:SetScript("OnEditFocusLost", SaveName)

   editor.PickupButton = RaidwrightNS:CreateButton(editor, L["MacroPickup"], 90)
   editor.PickupButton:SetPoint("LEFT", editor.NameBox, "RIGHT", 10, 0)
   editor.PickupButton:SetScript("OnClick", function()
      local macro = Macros:GetSelectedMacro()
      if macro then
         Macros:PickupMacro(macro)
      end
   end)
   RaidwrightNS:SetSimpleTooltip(editor.PickupButton, L["MacroPickup"], L["MacroPickupTooltip"])

   editor.DeleteButton = RaidwrightNS:CreateButton(editor, L["Remove"], 80)
   editor.DeleteButton:SetPoint("LEFT", editor.PickupButton, "RIGHT", 4, 0)
   editor.DeleteButton:SetScript("OnClick", function()
      local macro = Macros:GetSelectedMacro()
      if macro then
         StaticPopup_Show("RAIDWRIGHT_DELETE_MACRO", macro.name, nil, { macro = macro, onDone = refresh })
      end
   end)

   editor.Hint = editor:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
   editor.Hint:SetPoint("TOPLEFT", editor.NameLabel, "BOTTOMLEFT", 0, -12)
   editor.Hint:SetWidth(C["Width"] - _EDITOR_X - 40)
   editor.Hint:SetJustifyH("LEFT")
   editor.Hint:SetText(L["MacrosHint"])

   local scrollFrame = RaidwrightNS:CreateScrollFrame(editor, 0, -62, -22, 20)
   scrollFrame.content:SetWidth(_LABEL_WIDTH + _BOX_WIDTH + 10)
end

local function ShowRow(content, index, macro, list, label, placeholder, active)
   content.Rows = content.Rows or {}
   local row = content.Rows[index] or CreateRaidRow(content)
   content.Rows[index] = row
   row.macro = macro
   row.list = list
   row.Label:SetText(label)
   if active then
      row.Label:SetTextColor(1, 0.82, 0)
      row.Box:SetBackdropBorderColor(1, 0.82, 0)
   else
      row.Label:SetTextColor(list and 1 or 0.7, list and 1 or 0.7, list and 1 or 0.7)
      row.Box:SetBackdropBorderColor(0.5, 0.5, 0.5)
   end
   row.Placeholder:SetText(placeholder)
   -- don't reset the text under the cursor when a bag update redraws the tab
   if not row.EditBox:HasFocus() then
      local text
      if list then
         text = list.macros and list.macros[macro.id] or ""
      else
         text = macro.default or ""
      end
      row.EditBox:SetText(text)
   end
   UpdateRowCounter(row)
   row:Show()
   row.Box:Show()
end

function RaidwrightMacrosFrame:Initialize(self)
   if not self.ListSelector then
      CreateTopBar(self)
   end
   self.ListSelector:Refresh()

   local macros = Macros:GetMacros()
   local selectedMacro, selectedIndex = Macros:GetSelectedMacro()

   -- macro list on the left
   self.MacroButtons = self.MacroButtons or {}
   for _, button in ipairs(self.MacroButtons) do
      button:Hide()
   end
   for i, macro in ipairs(macros) do
      local button = self.MacroButtons[i] or CreateMacroButton(self, self)
      self.MacroButtons[i] = button
      button:SetPoint("TOPLEFT", self, "TOPLEFT", _PADDING, -62 - (i - 1) * _MACRO_ROW_HEIGHT)
      button.macroIndex = i
      button.Text:SetText(macro.name)
      button.Selected:SetShown(i == selectedIndex)
      button:Show()
   end

   if not selectedMacro then
      self.Editor:Hide()
      self.Message:SetText(L["NoMacros"])
      return
   end
   self.Message:SetText("")
   self.Editor:Show()

   local editor = self.Editor
   if not editor.NameBox:HasFocus() then
      editor.NameBox:SetText(selectedMacro.name)
   end

   local content = editor.ScrollFrame.content
   for _, row in ipairs(content.Rows or {}) do
      row:Hide()
   end
   local selectedList = RaidwrightNS.RaidwrightData:GetSelectedList()
   ShowRow(content, 1, selectedMacro, nil, L["MacroDefault"], L["MacroDefaultPlaceholder"], false)
   for i, list in ipairs(RaidwrightNS.RaidwrightData:GetLists()) do
      local active = list == selectedList
      local label = active and (list.name .. " " .. L["MacroActive"]) or list.name
      ShowRow(content, i + 1, selectedMacro, list, label, L["MacroUsesDefault"], active)
   end
   Layout(content)
end

local function GetPopupEditBox(popup)
   return popup.editBox or popup.EditBox or (popup.GetEditBox and popup:GetEditBox())
end

local function AcceptOnEnter(editBox)
   local popup = editBox:GetParent()
   StaticPopupDialogs[popup.which].OnAccept(popup, popup.data)
   popup:Hide()
end

StaticPopupDialogs["RAIDWRIGHT_NEW_MACRO"] = {
   text = L["NewMacroPrompt"],
   button1 = ACCEPT,
   button2 = CANCEL,
   hasEditBox = true,
   maxLetters = C["MacroNameMaxLength"],
   OnAccept = function(self, data)
      local name = strtrim(GetPopupEditBox(self):GetText() or "")
      if name == "" then
         return
      end
      if Macros:IsNameTaken(name) then
         RaidwrightNS:Print(L["MacroNameTaken"]:format(name))
         return
      end
      if InCombatLockdown() then
         RaidwrightNS:Print(L["MacroInCombat"])
         return
      end
      Macros:AddMacro(name)
      data.onDone()
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

StaticPopupDialogs["RAIDWRIGHT_DELETE_MACRO"] = {
   text = L["DeleteMacroPrompt"],
   button1 = YES,
   button2 = NO,
   OnAccept = function(self, data)
      Macros:DeleteMacro(data.macro)
      data.onDone()
   end,
   timeout = 0,
   whileDead = true,
   hideOnEscape = true,
   showAlert = true,
   preferredIndex = 3,
}
