local AddonName, RaidwrightNS = ...

local C = setmetatable({ }, {__index = function(t, k)
	local v = tostring(k)
	rawset(t, k, v)
	return v
end})

RaidwrightNS.C = C

C["MajorDBVersion"] = 1
C["Width"] = 900
C["Height"] = 540
C["Icon"] = "Interface\\Icons\\inv_potion_62"

C["BankContainer"] = (Enum.BagIndex and Enum.BagIndex.Bank) or BANK_CONTAINER or -1
C["NumBagSlots"] = NUM_BAG_SLOTS or 4
C["NumBankBagSlots"] = NUM_BANKBAGSLOTS or 6
C["MaxMailAttachments"] = ATTACHMENTS_MAX_RECEIVE or 12
C["EquipmentSlots"] = 19
-- empty slot backgrounds of the character sheet, by inventory slot id
C["EquipmentSlotIcons"] = {
	"Head", "Neck", "Shoulder", "Shirt", "Chest", "Waist", "Legs", "Feet", "Wrists", "Hands",
	"Finger", "Finger", "Trinket", "Trinket", "Chest", "MainHand", "SecondaryHand", "Ranged", "Tabard",
}

function C:GetEquipmentSlotIcon(index)
	if index and C["EquipmentSlotIcons"][index] then
		return "Interface\\PaperDoll\\UI-PaperDoll-Slot-" .. C["EquipmentSlotIcons"][index]
	end
end

-- each entry is one column, a column can match multiple spells (e.g. all Sayge's fortunes)
C["WorldBuffs"] = {
	{ key = "Onyxia", spells = { 22888, 355363 } }, -- Rallying Cry of the Dragonslayer (normal, released from a Chronoboon)
	{ key = "Rend", spells = { 16609, 355366 } }, -- Warchief's Blessing
	{ key = "ZG", spells = { 24425, 355365 } }, -- Spirit of Zandalar
	{ key = "Songflower", spells = { 15366 } }, -- Songflower Serenade
	{ key = "DMF", spells = { 23768, 23769, 23767, 23738, 23766, 23737, 23735, 23736 } }, -- Sayge's Dark Fortune of ...
	{ key = "Fengus", spells = { 22817 } }, -- Fengus' Ferocity
	{ key = "Moldar", spells = { 22818 } }, -- Mol'dar's Moxie
	{ key = "Slipkik", spells = { 22820 } }, -- Slip'kik's Savvy
	{ key = "BFD", spells = { 430947 }, seasonal = true }, -- Boon of Blackfathom
	{ key = "Ashenvale", spells = { 430352 }, seasonal = true }, -- Spark of Inspiration
	{ key = "Sunken", spells = { 446695 }, seasonal = true }, -- Fervor of the Temple Explorer
}
-- "World effect suspended", the aura that holds world buffs while a Chronoboon is filled
-- newer displacers can use another id for it, so the aura is matched by name as well
C["ChronoboonSpells"] = { 349981 }
-- casting a displacer stores the active world buffs, the release spell gives them back
C["ChronoboonStoreSpells"] = { [349858] = true, [1223679] = true }
C["ChronoboonReleaseSpell"] = 349863

-- GetSpellInfo is deprecated on newer clients
function RaidwrightNS.GetSpellInfo(spellId)
	if GetSpellInfo then
		return GetSpellInfo(spellId)
	end
	local info = C_Spell and C_Spell.GetSpellInfo(spellId)
	if info then
		return info.name, nil, info.iconID
	end
end
