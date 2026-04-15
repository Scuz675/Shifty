-- Shifty Bear module
-- Bear-only single target and AOE rotation ownership lives here.

if HSAutoFF == nil then HSAutoFF = 1 end
if HSBearUseDemo == nil then HSBearUseDemo = 0 end
if HSBearUseMaul == nil then HSBearUseMaul = 1 end
if HSBearUseSavageBite == nil then HSBearUseSavageBite = 1 end
if HSBearUseOOCShift == nil then HSBearUseOOCShift = 1 end

if hsBearLastPredictedMaulAt == nil then hsBearLastPredictedMaulAt = 0 end
if hsBearLastPredictedDemoAt == nil then hsBearLastPredictedDemoAt = 0 end
if hsBearLastPredictedFFAt == nil then hsBearLastPredictedFFAt = 0 end
if hsBearLastPredictedSavageBiteAt == nil then hsBearLastPredictedSavageBiteAt = 0 end

local function SH_Bear_CanSuggestMaul(rage, minRage)
	local now = GetTime()
	minRage = tonumber(minRage) or 15
	if rage < minRage then return false end
	if IsSpellOnCD("Maul") then return false end
	if (now - (hsBearLastPredictedMaulAt or 0)) < 1.20 then return false end
	hsBearLastPredictedMaulAt = now
	return true
end

local function SH_Bear_CanSuggestDemo(rage)
	local now = GetTime()
	if HSBearUseDemo ~= 1 then return false end
	if rage < 10 then return false end
	if IsSpellOnCD("Demoralizing Roar") then return false end
	if IsTDebuff('target', 'Ability_Druid_DemoralizingRoar') then return false end
	if (now - (hsBearLastPredictedDemoAt or 0)) < 6.0 then return false end
	hsBearLastPredictedDemoAt = now
	return true
end

local function SH_Bear_CanSuggestFF()
	local now = GetTime()
	if HSAutoFF ~= 1 then return false end
	if IsTDebuff('target', 'Spell_Nature_FaerieFire') then return false end
	if IsSpellOnCD("Faerie Fire (Feral)") then return false end
	if (now - (hsBearLastPredictedFFAt or 0)) < 3.0 then return false end
	hsBearLastPredictedFFAt = now
	return true
end

local function SH_Bear_CanSuggestSavageBite(rage, minRage)
	local now = GetTime()
	minRage = tonumber(minRage) or 40
	if HSBearUseSavageBite ~= 1 then return false end
	if type(ShiftySettings) == "table" and type(ShiftySettings.bear) == "table" and ShiftySettings.bear.useSavageBite ~= 1 then return false end
	if rage < minRage then return false end
	if IsSpellOnCD("Savage Bite") then return false end
	if (now - (hsBearLastPredictedSavageBiteAt or 0)) < 1.20 then return false end
	hsBearLastPredictedSavageBiteAt = now
	return true
end

local function SH_Bear_CanOOCShift()
	if HSBearUseOOCShift ~= 1 then return false end
	if type(ShiftySettings) == "table" and type(ShiftySettings.bear) == "table" and ShiftySettings.bear.useOOCShift ~= 1 then return false end
	if UnitAffectingCombat("player") then return false end
	if UnitMana("player") == nil or UnitMana("player") > 9 then return false end
	if type(HS_IsAnySpellCastInProgress) == "function" and HS_IsAnySpellCastInProgress() == true then return false end
	if GetActiveForm() ~= 1 then return false end
	return true
end

function SH_Bear_TryOOCShift()
	if SH_Bear_CanOOCShift() ~= true then return false end
	if type(HSTryShift) == "function" then
		HSTryShift("bear_ooc")
		return true
	end
	return false
end

function SH_Bear_GetPredictedSpellName()
	if UnitExists("target") ~= 1 or UnitIsDead("target") then return nil end
	local rage = UnitMana("player") or 0
	HS_EnsureSettings()

	if SH_Bear_CanSuggestFF() then
		return "Faerie Fire (Feral)"
	end

	if HSMode == "aoe" or ShiftyMode == "aoe" then
		if SH_Bear_CanSuggestDemo(rage) then
			return "Demoralizing Roar"
		end
		if ShiftySettings.bear.useSwipe == 1 and rage >= 15 and not IsSpellOnCD("Swipe") then
			return "Swipe"
		end
		if SH_Bear_CanSuggestSavageBite(rage, 50) then
			return "Savage Bite"
		end
		if ShiftySettings.bear.useMaul == 1 and HSBearUseMaul == 1 and SH_Bear_CanSuggestMaul(rage, 30) then
			return "Maul"
		end
	else
		if SH_Bear_CanSuggestDemo(rage) then
			return "Demoralizing Roar"
		end
		if SH_Bear_CanSuggestSavageBite(rage, 45) then
			return "Savage Bite"
		end
		if ShiftySettings.bear.useMaul == 1 and HSBearUseMaul == 1 and SH_Bear_CanSuggestMaul(rage, 15) then
			return "Maul"
		end
	end

	return nil
end

function SH_Bear_Single()
	if UnitExists("target") ~= 1 or UnitIsDead('target') then return end
	StAttack(1)
	HSDebugTrace("BEAR_SINGLE", "")

	local spellName = SH_Bear_GetPredictedSpellName()
	if spellName == nil then return end
	if spellName == "Faerie Fire (Feral)" then
		HSDebugTrace("CAST", "Faerie Fire (bear single)")
		CastSpellByName("Faerie Fire (Feral)(Rank 4)")
		return
	end
	if spellName == "Demoralizing Roar" then
		HSDebugTrace("CAST", "Demoralizing Roar (bear single)")
		CastSpellByName("Demoralizing Roar")
		return
	end
	if spellName == "Savage Bite" then
		HSDebugTrace("CAST", "Savage Bite (bear single)")
		CastSpellByName("Savage Bite")
		return
	end
	if spellName == "Maul" then
		HSDebugTrace("CAST", "Maul (bear single)")
		CastSpellByName("Maul")
		return
	end
end

function SH_Bear_AOE()
	if UnitExists("target") ~= 1 or UnitIsDead('target') then return end
	StAttack(1)
	HSDebugTrace("BEAR_AOE", "")

	local spellName = SH_Bear_GetPredictedSpellName()
	if spellName == nil then return end
	if spellName == "Faerie Fire (Feral)" then
		HSDebugTrace("CAST", "Faerie Fire (bear aoe)")
		CastSpellByName("Faerie Fire (Feral)(Rank 4)")
		return
	end
	if spellName == "Demoralizing Roar" then
		HSDebugTrace("CAST", "Demoralizing Roar (bear aoe)")
		CastSpellByName("Demoralizing Roar")
		return
	end
	if spellName == "Swipe" then
		HSDebugTrace("CAST", "Swipe")
		CastSpellByName("Swipe")
		return
	end
	if spellName == "Savage Bite" then
		HSDebugTrace("CAST", "Savage Bite (bear aoe)")
		CastSpellByName("Savage Bite")
		return
	end
	if spellName == "Maul" then
		HSDebugTrace("CAST", "Maul (bear aoe)")
		CastSpellByName("Maul")
		return
	end
end

function SH_Bear_Run()
	if SH_Bear_TryOOCShift() == true then return end
	if HSMode == "aoe" or ShiftyMode == "aoe" then
		SH_Bear_AOE()
	else
		SH_Bear_Single()
	end
end
