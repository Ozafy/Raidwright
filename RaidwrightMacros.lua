local AddonName, RaidwrightNS = ...

local C = RaidwrightNS.C
local L = LibStub("AceLocale-3.0"):GetLocale(AddonName)

-- raid macros: one WoW character macro per entry, its text follows the selected list
-- the text per raid lives on the list (list.macros[id]), so it goes along with renames and deletes
local RaidwrightMacros = {}
RaidwrightNS.RaidwrightMacros = RaidwrightMacros

local pendingApply = false

local function CharDB()
   return RaidwrightNS.RaidwrightDB.char
end

-- the macro UI is load on demand, so its constants may not exist yet
local function MaxAccountMacros()
   return MAX_ACCOUNT_MACROS or 120
end

local function MaxCharacterMacros()
   return MAX_CHARACTER_MACROS or 18
end

function RaidwrightMacros:GetMacros()
   local db = CharDB()
   db.macros = db.macros or {}
   return db.macros
end

function RaidwrightMacros:GetMacroById(id)
   for _, macro in ipairs(self:GetMacros()) do
      if macro.id == id then
         return macro
      end
   end
end

function RaidwrightMacros:GetSelectedMacro()
   local db = CharDB()
   local macros = self:GetMacros()
   if #macros == 0 then
      return nil
   end
   if not db.selectedMacro or db.selectedMacro > #macros then
      db.selectedMacro = 1
   end
   return macros[db.selectedMacro], db.selectedMacro
end

function RaidwrightMacros:SelectMacro(index)
   CharDB().selectedMacro = index
end

function RaidwrightMacros:IsNameTaken(name, exceptMacro)
   for _, macro in ipairs(self:GetMacros()) do
      if macro ~= exceptMacro and macro.name:lower() == name:lower() then
         return true
      end
   end
   return false
end

-- index of this character's macro with the given name, account macros with the same name are left alone
local function FindCharacterMacro(name)
   local _, numCharacter = GetNumMacros()
   for i = MaxAccountMacros() + 1, MaxAccountMacros() + numCharacter do
      if GetMacroInfo(i) == name then
         return i
      end
   end
end

function RaidwrightMacros:GetMacroIndex(macro)
   return macro and FindCharacterMacro(macro.name)
end

-- the text the macro has for a list, the default when that raid has nothing of its own
function RaidwrightMacros:GetBody(macro, list)
   local body = list and list.macros and list.macros[macro.id]
   if body and strtrim(body) ~= "" then
      return body
   end
   return macro.default or ""
end

function RaidwrightMacros:SetBody(macro, list, body)
   if list then
      list.macros = list.macros or {}
      list.macros[macro.id] = body ~= "" and body or nil
   else
      macro.default = body
   end
   self:ScheduleApply()
end

local function RefreshMacroFrame()
   if MacroFrame and MacroFrame:IsShown() and MacroFrame_Update then
      MacroFrame_Update()
   end
end

-- writes the text for the selected raid into the WoW macros, creating the ones that don't exist
function RaidwrightMacros:Apply()
   if not RaidwrightNS.RaidwrightAddon.CurrentCharacter.Name then
      return
   end
   if InCombatLockdown() then
      pendingApply = true
      return
   end
   pendingApply = false
   local list = RaidwrightNS.RaidwrightData:GetSelectedList()
   local changed = false
   for _, macro in ipairs(self:GetMacros()) do
      local body = self:GetBody(macro, list)
      local index = FindCharacterMacro(macro.name)
      if index then
         -- GetMacroInfo gives the icon on display, for a question mark macro that's the item it uses
         -- writing that back would pin it, so the question mark is always written instead
         local name, _, current = GetMacroInfo(index)
         if current ~= body then
            EditMacro(index, name, C["MacroIcon"], body)
            changed = true
         end
      else
         local _, numCharacter = GetNumMacros()
         if numCharacter >= MaxCharacterMacros() then
            RaidwrightNS:Print(L["MacroLimitReached"]:format(macro.name))
         else
            CreateMacro(macro.name, C["MacroIcon"], body, true)
            changed = true
         end
      end
   end
   if changed then
      RefreshMacroFrame()
   end
end

local applyTimer
-- typing fires a change per key, write the macro once it settles
function RaidwrightMacros:ScheduleApply()
   if applyTimer then
      RaidwrightNS.RaidwrightAddon:CancelTimer(applyTimer)
   end
   applyTimer = RaidwrightNS.RaidwrightAddon:ScheduleTimer(function()
      applyTimer = nil
      RaidwrightMacros:Apply()
   end, 0.5)
end

function RaidwrightMacros:OnCombatEnded()
   if pendingApply then
      self:Apply()
   end
end

function RaidwrightMacros:AddMacro(name)
   local db = CharDB()
   db.nextMacroId = (db.nextMacroId or 0) + 1
   -- an existing character macro with this name is taken over, its text becomes the default
   local existing = FindCharacterMacro(name)
   local default = existing and select(3, GetMacroInfo(existing)) or ""
   table.insert(self:GetMacros(), { id = db.nextMacroId, name = name, default = default })
   db.selectedMacro = #self:GetMacros()
   self:Apply()
end

function RaidwrightMacros:RenameMacro(macro, name)
   if InCombatLockdown() then
      RaidwrightNS:Print(L["MacroInCombat"])
      return false
   end
   local index = FindCharacterMacro(macro.name)
   macro.name = name
   if index then
      local _, _, body = GetMacroInfo(index)
      EditMacro(index, name, C["MacroIcon"], body)
      RefreshMacroFrame()
   end
   self:Apply()
   return true
end

-- removes the entry, its text on every list and the WoW macro (which also takes it off the action bars)
function RaidwrightMacros:DeleteMacro(macro)
   if InCombatLockdown() then
      RaidwrightNS:Print(L["MacroInCombat"])
      return
   end
   local index = FindCharacterMacro(macro.name)
   if index then
      DeleteMacro(index)
      RefreshMacroFrame()
   end
   for _, list in ipairs(RaidwrightNS.RaidwrightData:GetLists()) do
      if list.macros then
         list.macros[macro.id] = nil
      end
   end
   local macros = self:GetMacros()
   for i, entry in ipairs(macros) do
      if entry == macro then
         table.remove(macros, i)
         CharDB().selectedMacro = math.max(1, i - 1)
         break
      end
   end
end

function RaidwrightMacros:PickupMacro(macro)
   if InCombatLockdown() then
      RaidwrightNS:Print(L["MacroInCombat"])
      return
   end
   local index = FindCharacterMacro(macro.name)
   if not index then
      self:Apply()
      index = FindCharacterMacro(macro.name)
   end
   if index then
      PickupMacro(index)
   end
end
