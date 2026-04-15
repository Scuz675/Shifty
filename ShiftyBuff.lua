-- ShiftyBuff.lua
-- Standalone reference-style buff module so it cannot interfere with ShiftyCore slash/rotation logic.

if type(ShiftyBuffSettings) ~= "table" then ShiftyBuffSettings = {} end
if ShiftyBuffSettings.useMark == nil then ShiftyBuffSettings.useMark = 1 end
if ShiftyBuffSettings.useThorns == nil then ShiftyBuffSettings.useThorns = 1 end

local SHBUFF_IsCasting = false
local SHBUFF_DelayUntil = 0

local SHBUFF_Frame = CreateFrame("Frame", "ShiftyBuffFrame", UIParent)
SHBUFF_Frame:Hide()

local function SHBUFF_Debug(msg)
	if type(HSDebugTrace) == "function" and ShiftyDebugEnabled == 1 then
		HSDebugTrace("BUFF", tostring(msg))
	end
end

local function SHBUFF_HasPlayerBuff(texture)
	local i, buff
	for i = 1, 10 do
		buff = UnitBuff("player", i)
		if buff == texture then
			return true
		end
	end
	return false
end

local function SHBUFF_IsMountedOrShifted()
	local i, buff
	for i = 1, 10 do
		buff = UnitBuff("player", i)
		if buff and string.find(buff, "Mount_") then return true end
		if buff and string.find(buff, "Ability_Druid_CatForm") then return true end
		if buff and string.find(buff, "earForm") then return true end
		if buff and string.find(buff, "Ability_Druid_AquaticForm") then return true end
		if buff and string.find(buff, "Ability_Druid_TravelForm") then return true end
	end
	return false
end

local function SHBUFF_FindSpellIndex(spellName)
	local i, name = 1, nil
	while true do
		name = GetSpellName(i, BOOKTYPE_SPELL)
		if not name then break end
		if name == spellName then return i end
		i = i + 1
	end
	return nil
end

local function SHBUFF_CastReference(spellName)
	local id = SHBUFF_FindSpellIndex(spellName)
	if not id then
		SHBUFF_Debug("missing spell " .. tostring(spellName))
		return false
	end

	if UnitIsFriend("player", "target") then
		TargetUnit("player")
		CastSpell(id, BOOKTYPE_SPELL)
		TargetLastTarget()
	else
		CastSpell(id, BOOKTYPE_SPELL)
		SpellTargetUnit("player")
	end

	SHBUFF_IsCasting = true
	SHBUFF_DelayUntil = GetTime() + 2
	SHBUFF_Frame:Show()
	SHBUFF_Debug("cast " .. tostring(spellName))
	return true
end

function SH_Buff_CheckAndCast()
	if SHBUFF_IsCasting then return false end
	if UnitClass("player") ~= "Druid" then return false end
	if type(ShiftyBuffSettings) ~= "table" then return false end
	if UnitIsDead("player") or UnitIsGhost("player") then return false end
	if SHBUFF_IsMountedOrShifted() then return false end

	local hasThorns = SHBUFF_HasPlayerBuff("Interface\\Icons\\Spell_Nature_Thorns")
	local hasMark = SHBUFF_HasPlayerBuff("Interface\\Icons\\Spell_Nature_Regeneration")

	if ShiftyBuffSettings.useThorns == 1 and not hasThorns then
		return SHBUFF_CastReference("Thorns")
	elseif ShiftyBuffSettings.useMark == 1 and not hasMark then
		return SHBUFF_CastReference("Mark of the Wild")
	end

	return false
end

function SH_Buff_DebugStatus()
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("Shifty Buff status useMark="..tostring(ShiftyBuffSettings and ShiftyBuffSettings.useMark)
			.." useThorns="..tostring(ShiftyBuffSettings and ShiftyBuffSettings.useThorns)
			.." hasMark="..tostring(SHBUFF_HasPlayerBuff("Interface\\Icons\\Spell_Nature_Regeneration"))
			.." hasThorns="..tostring(SHBUFF_HasPlayerBuff("Interface\\Icons\\Spell_Nature_Thorns"))
			.." isCasting="..tostring(SHBUFF_IsCasting))
	end
end

local function SHBUFF_OnEvent()
	if not SHBUFF_IsCasting then
		SH_Buff_CheckAndCast()
	end
end

SHBUFF_Frame:SetScript("OnEvent", function()
	SHBUFF_OnEvent()
end)

SHBUFF_Frame:SetScript("OnUpdate", function()
	if not SHBUFF_Frame:IsVisible() then return end
	if (SHBUFF_DelayUntil - GetTime()) > 0 then return end
	SHBUFF_IsCasting = false
	SHBUFF_Frame:Hide()
end)

SHBUFF_Frame:RegisterEvent("PLAYER_ENTERING_WORLD")
SHBUFF_Frame:RegisterEvent("PLAYER_TARGET_CHANGED")
