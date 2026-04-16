-- Shifty Cat module
-- Cat-only single target and AOE rotation ownership lives here.

function SH_Cat_GetPredictedSpellName()
	HS_EnsureSettings()
	HSDebugTrace("CAT_PREDICT", "mode=" .. tostring(HSMode or ShiftyMode))
	local energy = UnitMana("player") or 0
	local comboPoints = HSGetComboPoints()
	local stealthed = HSBuffChk("Ability_Ambush")

	if stealthed == true then
		if HSBuffChk('Ability_Mount_JungleTiger') == false and not IsSpellOnCD("Tiger's Fury") then return "Tiger's Fury" end
		if CheckInteractDistance('target',3) == 1 and not IsSpellOnCD("Ravage") then return "Ravage" end
	end

	local canRake = not HSIsDebuffImmune("rake")
	local canFF = not HSIsDebuffImmune("ff")
	local canRip = not HSIsDebuffImmune("rip")
	local ferocity = SpecCheck(2,1) or 0
	local idolofferocity = 0
	local impshred = SpecCheck(2,9) or 0
	local rakeCost = 40 - ferocity
	local shredCost = 100 - (40 + impshred*6 + 20)
	local clawCost = 100 - (55 + ferocity + 20 + idolofferocity)
	local builderSpell = "Claw"
	local builderCost = clawCost
	local targetIsBoss = UnitLevel('target') == -1
	local fbthresh = 5
	if HSMode == "aoe" then fbthresh = 4 end
	if HS_PlayerHasIdolOfFerocity() == true then
		idolofferocity = 3
		clawCost = 100 - (55 + ferocity + 20 + idolofferocity)
		builderCost = clawCost
	end
	if ShiftySettings.cat.useShred == 1 and (HSClawAdd ~= 1 or targetIsBoss) and BehindTarget() == true and energy >= HS_SHRED_ENERGY_THRESHOLD and HSMode ~= "aoe" and FindActionSlot("Spell_Shadow_VampiricAura") ~= 0 then
		builderSpell = "Shred"
		builderCost = shredCost
	end

	if ShiftySettings.cat.useTiger == 1 and HSTigerUse == 1 and stealthed == false and HSBuffChk('Ability_Mount_JungleTiger') == false and (not IsSpellOnCD("Tiger's Fury")) and energy >= 30 and comboPoints < 4 and (CheckInteractDistance('target',3) == 1 or MobTooFar() == true) then
		return "Tiger's Fury"
	end
	if HSMode ~= "aoe" and (type(ShiftySettings) ~= "table" or type(ShiftySettings.cat) ~= "table" or ShiftySettings.cat.useRake == 1) and stealthed == false and CheckInteractDistance('target',3) == 1 and comboPoints < fbthresh and canRake and IsTDebuff('target', 'Ability_Druid_Disembowel') == false and IsUse(FindActionSlot("Ability_Druid_Rake")) == 1 and (not IsSpellOnCD("Rake")) and (HSBuffChk("Spell_Shadow_ManaBurn") == true or energy >= rakeCost) then
		return "Rake"
	end
	if HSAutoFF == 1 and stealthed == false and UnitExists("target") and CheckInteractDistance('target',3) == 1 and canFF and IsTDebuff('target', 'Spell_Nature_FaerieFire') == false and (not IsSpellOnCD("Faerie Fire (Feral)")) and comboPoints <= HS_FF_REFRESH_MAX_CP then
		return "Faerie Fire (Feral)"
	end
	if comboPoints < fbthresh then
		if energy >= builderCost or HSBuffChk("Spell_Shadow_ManaBurn") == true then
			if not IsSpellOnCD(builderSpell) then return builderSpell end
		elseif UnitAffectingCombat('player') and UnitExists("target") then
			if comboPoints <= HS_FF_REFRESH_MAX_CP and IsTDebuff('target', 'Spell_Nature_FaerieFire') == false and stealthed == false and (not IsSpellOnCD("Faerie Fire (Feral)")) and HSAutoFF == 1 and canFF then
				return "Faerie Fire (Feral)"
			end
		end
	else
		local shouldRip = comboPoints == 5 and HasRip() == false and canRip and HSMode ~= "aoe"
		local finisherEnergy = 15
		if shouldRip then finisherEnergy = 30 end
		if energy >= finisherEnergy or HSBuffChk("Spell_Shadow_ManaBurn") == true then
			if shouldRip and not IsSpellOnCD("Rip") then return "Rip" end
			if IsUse(FindActionSlot("Ability_Druid_FerociousBite")) == 1 and not IsSpellOnCD("Ferocious Bite") then return "Ferocious Bite" end
		elseif UnitAffectingCombat('player') and UnitExists("target") then
			if comboPoints <= HS_FF_REFRESH_MAX_CP and IsTDebuff('target', 'Spell_Nature_FaerieFire') == false and stealthed == false and (not IsSpellOnCD("Faerie Fire (Feral)")) and HSAutoFF == 1 and canFF then
				return "Faerie Fire (Feral)"
			end
		end
	end
	return nil
end

function SH_Cat_Run(tot, stealthed, romactive, romcooldown, partynum, lipcd, lipslot)
	HSDebugTrace("CAT_RUN", "mode=" .. tostring(HSMode or ShiftyMode) .. " tot=" .. tostring(tot))
	if stealthed == true then
		if ShiftySettings.cat.useTiger == 1 and HSBuffChk('Ability_Mount_JungleTiger') == false then
			HSCast("Tiger's Fury(Rank 4)")
		end
		if CheckInteractDistance('target',3) == 1 then
			HSCast("Ravage")
		end
		return
	end

	if tot == playername then
		if UnitLevel('target') == -1 then
			if lipcd == 0 and lipslot ~= 0 then
				EShift()
			elseif(not IsSpellOnCD("Cower")) then
				HSCast("Cower")
			elseif(not IsSpellOnCD("Barkskin")) then
				EShift()
			else
				Atk("Auto",stealthed,romactive,romcooldown)
			end
		else
			if partynum > 2 then
				if(not IsSpellOnCD("Cower")) and HSCowerUse == 1 and ShiftySettings.cat.useCower == 1 then
					HSCast("Cower")
				else
					Atk("Auto",stealthed,romactive,romcooldown)
				end
			else
				Atk("Auto",stealthed,romactive,romcooldown)
			end
		end
	else
		Atk("Auto",stealthed,romactive,romcooldown)
	end
end
