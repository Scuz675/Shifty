-- Shifty Bear module

if HSAutoFF == nil then HSAutoFF = 1 end
if HSBearUseDemo == nil then HSBearUseDemo = 0 end
if HSBearUseMaul == nil then HSBearUseMaul = 1 end
if HSBearUseSavageBite == nil then HSBearUseSavageBite = 1 end
if HSBearUseOOCShift == nil then HSBearUseOOCShift = 1 end
if hsBearLastPredictedMaulAt == nil then hsBearLastPredictedMaulAt = 0 end
if hsBearLastPredictedDemoAt == nil then hsBearLastPredictedDemoAt = 0 end
if hsBearLastPredictedFFAt == nil then hsBearLastPredictedFFAt = 0 end
if hsBearLastPredictedSavageBiteAt == nil then hsBearLastPredictedSavageBiteAt = 0 end

local function HS_BearCanSuggestMaul(rage)
	local now = GetTime()
	if rage < 15 then return false end
	if IsSpellOnCD("Maul") then return false end
	if (now - (hsBearLastPredictedMaulAt or 0)) < 1.20 then return false end
	hsBearLastPredictedMaulAt = now
	return true
end

local function HS_BearCanSuggestDemo(rage)
	local now = GetTime()
	if HSBearUseDemo ~= 1 then return false end
	if rage < 10 then return false end
	if IsSpellOnCD("Demoralizing Roar") then return false end
	if IsTDebuff('target', 'Ability_Druid_DemoralizingRoar') then return false end
	if (now - (hsBearLastPredictedDemoAt or 0)) < 6.0 then return false end
	hsBearLastPredictedDemoAt = now
	return true
end

local function HS_BearCanSuggestFF()
	local now = GetTime()
	if HSAutoFF ~= 1 then return false end
	if IsTDebuff('target', 'Spell_Nature_FaerieFire') then return false end
	if IsSpellOnCD("Faerie Fire (Feral)") then return false end
	if (now - (hsBearLastPredictedFFAt or 0)) < 3.0 then return false end
	hsBearLastPredictedFFAt = now
	return true
end

local function HS_BearCanSuggestSavageBite(rage)
	local now = GetTime()
	if HSBearUseSavageBite ~= 1 then return false end
	if type(ShiftySettings) == "table" and type(ShiftySettings.bear) == "table" and ShiftySettings.bear.useSavageBite ~= 1 then return false end
	if rage < 40 then return false end
	if IsSpellOnCD("Savage Bite") then return false end
	if (now - (hsBearLastPredictedSavageBiteAt or 0)) < 1.20 then return false end
	hsBearLastPredictedSavageBiteAt = now
	return true
end

function SH_Bear_GetPredictedSpellName()
	local rage = UnitMana("player") or 0
	HS_EnsureSettings()

	if HS_BearCanSuggestFF() then
		return "Faerie Fire (Feral)"
	end

	if HSMode == "aoe" then
		if ShiftySettings.bear.useSwipe == 1 and rage >= 15 and not IsSpellOnCD("Swipe") then
			return "Swipe"
		end
		if HS_BearCanSuggestDemo(rage) then
			return "Demoralizing Roar"
		end
		if HS_BearCanSuggestSavageBite(rage) then
			return "Savage Bite"
		end
		if ShiftySettings.bear.useMaul == 1 and HSBearUseMaul == 1 and HS_BearCanSuggestMaul(rage) then
			return "Maul"
		end
	else
		if HS_BearCanSuggestDemo(rage) then
			return "Demoralizing Roar"
		end
		if HS_BearCanSuggestSavageBite(rage) then
			return "Savage Bite"
		end
		if ShiftySettings.bear.useMaul == 1 and HSBearUseMaul == 1 and HS_BearCanSuggestMaul(rage) then
			return "Maul"
		end
	end

	return nil
end

function SH_Bear_Run()
	if HSMode == "aoe" then HSBearAOE() else HSBearSingle() end
end
