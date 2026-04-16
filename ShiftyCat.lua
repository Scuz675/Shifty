-- Shifty Cat module

function SH_Cat_GetPredictedSpellName()
	HS_EnsureSettings()
	local energy = UnitMana("player") or 0
	local comboPoints = HSGetComboPoints()
	local stealthed = HSBuffChk("Ability_Ambush")

	-- HARD AOE OVERRIDE: keep all Cat AOE ownership here and out of Core.
	if HSMode == "aoe" or ShiftyMode == "aoe" then
		if stealthed == true then
			if HSBuffChk('Ability_Mount_JungleTiger') == false and not IsSpellOnCD("Tiger's Fury") then return "Tiger's Fury" end
			if CheckInteractDistance('target',3) == 1 and not IsSpellOnCD("Ravage") then return "Ravage" end
		end
		if ShiftySettings.cat.useTiger == 1 and HSTigerUse == 1 and stealthed == false and HSBuffChk('Ability_Mount_JungleTiger') == false and (not IsSpellOnCD("Tiger's Fury")) and energy <= 40 and comboPoints < 4 then
			return "Tiger's Fury"
		end
		if HSAutoFF == 1 and stealthed == false and UnitExists("target") and CheckInteractDistance('target',3) == 1 and IsTDebuff('target', 'Spell_Nature_FaerieFire') == false and (not IsSpellOnCD("Faerie Fire (Feral)")) and comboPoints <= HS_FF_REFRESH_MAX_CP then
			return "Faerie Fire (Feral)"
		end
		if comboPoints >= 4 then
			if energy >= 35 or HSBuffChk("Spell_Shadow_ManaBurn") == true then
				if IsUse(FindActionSlot("Ability_Druid_FerociousBite")) == 1 and not IsSpellOnCD("Ferocious Bite") then return "Ferocious Bite" end
			end
			return nil
		end
		if energy >= 45 or HSBuffChk("Spell_Shadow_ManaBurn") == true then
			if not IsSpellOnCD("Claw") then return "Claw" end
		end
		return nil
	end

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
	if GetInventoryItemLink('player',18) ~= nil and string.find(GetInventoryItemLink('player',18), 'Idol of Ferocity') then
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
	if (type(ShiftySettings) ~= "table" or type(ShiftySettings.cat) ~= "table" or ShiftySettings.cat.useRake == 1) and stealthed == false and CheckInteractDistance('target',3) == 1 and comboPoints < fbthresh and canRake and IsTDebuff('target', 'Ability_Druid_Disembowel') == false and IsUse(FindActionSlot("Ability_Druid_Rake")) == 1 and (not IsSpellOnCD("Rake")) and (HSBuffChk("Spell_Shadow_ManaBurn") == true or energy >= rakeCost) then
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
				SH_Cat_ExecuteRotation("Auto",stealthed,romactive,romcooldown)
			end
		else
			if partynum > 2 then
				if(not IsSpellOnCD("Cower")) and HSCowerUse == 1 and ShiftySettings.cat.useCower == 1 then
					HSCast("Cower")
				else
					SH_Cat_ExecuteRotation("Auto",stealthed,romactive,romcooldown)
				end
			else
				SH_Cat_ExecuteRotation("Auto",stealthed,romactive,romcooldown)
			end
		end
	else
		SH_Cat_ExecuteRotation("Auto",stealthed,romactive,romcooldown)
	end
end


function SH_Cat_GetSecondSpell(nextSpell, mode, cp)
	if nextSpell == nil or nextSpell == "" then return nil end
	mode = mode or HSMode or ShiftyMode or "single"
	cp = cp or HSGetComboPoints() or 0
	local fbthresh = 5
	if mode == "aoe" then fbthresh = 4 end

	if nextSpell == "Rake" then
		if cp + 1 >= fbthresh then
			if mode ~= "aoe" then return "Rip" end
			return "Ferocious Bite"
		end
		if BehindTarget ~= nil and BehindTarget() == true and mode ~= "aoe" then return "Shred" end
		return "Claw"
	elseif nextSpell == "Shred" or nextSpell == "Claw" then
		if cp + 1 >= fbthresh then
			if mode ~= "aoe" then return "Rip" end
			return "Ferocious Bite"
		end
		if nextSpell == "Shred" then return "Shred" end
		return "Claw"
	elseif nextSpell == "Rip" or nextSpell == "Ferocious Bite" then
		if mode == "aoe" then return "Claw" end
		return "Rake"
	elseif nextSpell == "Faerie Fire (Feral)" then
		if BehindTarget ~= nil and BehindTarget() == true and mode ~= "aoe" then return "Shred" end
		return "Claw"
	elseif nextSpell == "Tiger's Fury" then
		if mode == "aoe" then return "Claw" end
		return "Rake"
	end

	return nil
end


function SH_Cat_ExecuteRotation(CorS,stealthyn,romyn,romcd)
	HS_EnsureSettings()
	StAttack(1)
	local comboPoints = HSGetComboPoints()
	local canRake = not HSIsDebuffImmune("rake")
	local canFF = not HSIsDebuffImmune("ff")
	local canRip = not HSIsDebuffImmune("rip")
	local ferocity = SpecCheck(2,1)
	local idolofferocity = 0
	local shth = 15
	local rakeCost = 40 - ferocity
	local impshred = SpecCheck(2,9)
	local shredtext = "Spell_Shadow_VampiricAura"
	local clawtext = "Ability_Druid_Rake"
	local shredCost = 100 - (40 + impshred*6 + 20)
	local clawCost = 100 - (55 + ferocity + 20 + idolofferocity)
	local builderSpell = "Claw"
	local builderTexture = clawtext
	local builderCost = clawCost
	local builderSlot = 0
	local kotscd,kotseq,kotsbag,kotsslot = ItemInfo('Kiss of the Spider')
	local escd,eseq,esbag,esslot = ItemInfo('Earthstrike')
	local zhmcd,zhmeq,zhmbag,zhmslot = ItemInfo('Zandalarian Hero Medallion')
	local fbthresh = 5
	if ShiftyMode == "aoe" then fbthresh = 4 end
	if(romyn == true) then shth = 30 end

	if GetInventoryItemLink('player',18) ~= nil then
		if(string.find(GetInventoryItemLink('player',18), 'Idol of Ferocity')) then
			idolofferocity = 3
			clawCost = 100 - (55 + ferocity + 20 + idolofferocity)
			builderCost = clawCost
		end
	end
	if UnitLevel('target') == -1 then
		PopSkeleton()
		if HSMCPUse == 1 then Pummel() end
		if UnitAffectingCombat('Player') and kotseq ~= -1 and kotscd == 0 and UnitName('target') ~= "Razorgore the Untamed" and (CheckInteractDistance('target',3) == 1 or MobTooFar() == true) then UseItemByName("Kiss of the Spider") end
		if UnitAffectingCombat('Player') and eseq ~= -1 and escd == 0 and UnitName('target') ~= "Razorgore the Untamed" and (CheckInteractDistance('target',3) == 1 or MobTooFar() == true) then UseItemByName("Earthstrike") end
		if UnitAffectingCombat('Player') and zhmeq ~= -1 and zhmcd == 0 and UnitName('target') ~= "Razorgore the Untamed" and (CheckInteractDistance('target',3) == 1 or MobTooFar() == true) then UseItemByName("Zandalarian Hero Medallion") end
	end
	if BehindTarget() == true and UnitMana('Player') >= HS_SHRED_ENERGY_THRESHOLD and ShiftyMode ~= "aoe" then
		builderSpell = "Shred"
		builderTexture = shredtext
		builderCost = shredCost
	end
	builderSlot = FindActionSlot(builderTexture)
	if builderSpell == "Shred" and builderSlot == 0 then
		builderSpell = "Claw"
		builderTexture = clawtext
		builderCost = clawCost
		builderSlot = FindActionSlot(builderTexture)
		HSDebugTrace("BUILDER_FALLBACK", "Shred slot missing; fallback to Claw")
	end
	HSDebugTrace("ATK_THRESHOLDS", "mode="..tostring(ShiftyMode).." CorS="..tostring(CorS).." builder="..builderSpell.." bcost="..tostring(builderCost).." fbthresh="..tostring(fbthresh).." shth="..tostring(shth))
	if UnitIsDead('target') then doclaw = 0 HSDebugTrace("TARGET_DEAD", "") return end

	if ShiftySettings.cat.useTiger == 1 and HSTigerUse == 1 and stealthyn == false and HSBuffChk('Ability_Mount_JungleTiger') == false and (not IsSpellOnCD("Tiger's Fury")) and UnitMana('Player') >= 30 and comboPoints < 4 and (CheckInteractDistance('target',3) == 1 or MobTooFar() == true) then
		HSDebugTrace("CAST", "Tiger's Fury")
		HSCast("Tiger's Fury(Rank 4)")
		return
	end

	if ShiftySettings.cat.useRake == 1 and stealthyn == false and CheckInteractDistance('target',3) == 1 and comboPoints < fbthresh and canRake and IsTDebuff('target', 'Ability_Druid_Disembowel') == false and IsUse(FindActionSlot("Ability_Druid_Rake")) == 1 and (not IsSpellOnCD("Rake")) and (HSBuffChk("Spell_Shadow_ManaBurn") == true or UnitMana('Player') >= rakeCost) then
		HSDebugTrace("CAST", "Rake (missing)")
		HSCast("Rake")
		return
	end

	if HSAutoFF == 1 and stealthyn == false and UnitExists("target") and CheckInteractDistance('target',3) == 1 and canFF and IsTDebuff('target', 'Spell_Nature_FaerieFire') == false and (not IsSpellOnCD("Faerie Fire (Feral)")) and comboPoints <= HS_FF_REFRESH_MAX_CP then
		HSDebugTrace("CAST", "Faerie Fire (missing close)")
		HSCast("Faerie Fire (Feral)(Rank 4)")
		return
	end

	if CheckInteractDistance('target',3) ~= 1 and MobTooFar() == false then
		if UnitExists("target") and HSAutoFF == 1 and canFF and IsTDebuff('target', 'Spell_Nature_FaerieFire') == false and stealthyn == false and (not IsSpellOnCD("Faerie Fire (Feral)")) then
			HSDebugTrace("CAST", "Faerie Fire (out of range)")
			HSCast("Faerie Fire (Feral)(Rank 4)")
		end
	end

	if(comboPoints<fbthresh) then
		HSDebugTrace("BUILDER_PHASE", "comboPoints<fbthresh")
		if UnitMana('Player')>=builderCost or HSBuffChk("Spell_Shadow_ManaBurn") == true then
			if builderSlot ~= 0 and IsUse(builderSlot) == 1 then
				if not IsSpellOnCD(builderSpell) then
					if builderSpell == "Shred" and BehindTarget() ~= true then
						HSDebugTrace("BUILDER_GUARD", "Shred blocked by behind check; fallback to Claw")
						builderSpell = "Claw"
						builderTexture = clawtext
						builderCost = clawCost
						builderSlot = FindActionSlot(builderTexture)
					end
					if builderSlot == 0 or IsUse(builderSlot) ~= 1 then HSDebugTrace("BUILDER_UNAVAILABLE", builderSpell.." fallback unusable") return end
					HSDebugTrace("CAST", builderSpell.." (builder)")
					HSCast(builderSpell)
				end
			elseif builderSlot == 0 then
				HSDebugTrace("BUILDER_UNAVAILABLE", builderSpell.." action slot not found")
			end
		else
			HSDebugTrace("LOW_ENERGY", "builder mana low; attempting FF/shift")
			if UnitAffectingCombat('Player') and UnitExists("target") then
				if ShiftySettings.cat.useShift == 1 and CanShift() == true then
					if HSTryShift("builder low energy") == true then return end
				end
				if comboPoints <= HS_FF_REFRESH_MAX_CP and IsTDebuff('target', 'Spell_Nature_FaerieFire') == false and stealthyn == false and (not IsSpellOnCD("Faerie Fire (Feral)")) and HSAutoFF == 1 and canFF then
					HSDebugTrace("CAST", "Faerie Fire (energy gap)")
					HSCast("Faerie Fire (Feral)(Rank 4)")
				end
			end
		end
	else
		HSDebugTrace("FINISHER_PHASE", "comboPoints>=fbthresh")
		local finisherEnergy = shth
		local shouldRip = comboPoints == 5 and HasRip() == false and canRip and ShiftyMode ~= "aoe"
		if shouldRip then finisherEnergy = 30 end
		if UnitMana('Player')>=finisherEnergy or HSBuffChk("Spell_Shadow_ManaBurn") == true then
			if shouldRip then
				if not IsSpellOnCD("Rip") then
					HSDebugTrace("CAST", "Rip (opener @5cp)")
					HSCast("Rip")
				end
			else
				if IsUse(FindActionSlot("Ability_Druid_FerociousBite")) == 1 then
					if not IsSpellOnCD("Ferocious Bite") then
						HSDebugTrace("CAST", "Ferocious Bite")
						HSCast("Ferocious Bite")
					end
				end
			end
		else
			HSDebugTrace("LOW_ENERGY", "finisher mana low; attempting FF/shift")
			if UnitAffectingCombat('Player') and UnitExists("target") then
				if ShiftySettings.cat.useShift == 1 and CanShift() == true then
					if HSTryShift("finisher low energy") == true then return end
				end
				if comboPoints <= HS_FF_REFRESH_MAX_CP and IsTDebuff('target', 'Spell_Nature_FaerieFire') == false and stealthyn == false and (not IsSpellOnCD("Faerie Fire (Feral)")) and HSAutoFF == 1 and canFF then
					HSDebugTrace("CAST", "Faerie Fire (finisher energy gap)")
					HSCast("Faerie Fire (Feral)(Rank 4)")
				end
			end
		end
	end
end
