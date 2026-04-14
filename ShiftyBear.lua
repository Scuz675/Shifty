-- Shifty Bear module

function SH_Bear_GetPredictedSpellName()
	local energy = UnitMana("player") or 0
	if HSAutoFF == 1 and IsTDebuff('target', 'Spell_Nature_FaerieFire') == false and not IsSpellOnCD("Faerie Fire (Feral)") then
		return "Faerie Fire (Feral)"
	end
	if HSMode == "aoe" then
		if (type(ShiftySettings) ~= "table" or type(ShiftySettings.bear) ~= "table" or ShiftySettings.bear.useSwipe == 1) and energy >= 15 and not IsSpellOnCD("Swipe") then return "Swipe" end
		if energy >= 10 and not IsSpellOnCD("Demoralizing Roar") then return "Demoralizing Roar" end
		if (type(ShiftySettings) ~= "table" or type(ShiftySettings.bear) ~= "table" or ShiftySettings.bear.useMaul == 1) and energy >= 15 and not IsSpellOnCD("Maul") then return "Maul" end
	else
		if energy >= 20 and not IsSpellOnCD("Demoralizing Roar") and IsTDebuff('target', 'Ability_Druid_DemoralizingRoar') == false then return "Demoralizing Roar" end
		if (type(ShiftySettings) ~= "table" or type(ShiftySettings.bear) ~= "table" or ShiftySettings.bear.useMaul == 1) and energy >= 15 and not IsSpellOnCD("Maul") then return "Maul" end
	end
	return nil
end

function SH_Bear_Run()
	if HSMode == "aoe" then
		HSBearAOE()
	else
		HSBearSingle()
	end
end
