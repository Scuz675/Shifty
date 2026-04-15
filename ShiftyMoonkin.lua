-- Shifty Moonkin module

hsBalanceOpenerTarget = hsBalanceOpenerTarget or ""
hsBalanceOpenedWithMoonfire = hsBalanceOpenedWithMoonfire or false
hsBalanceOpenedWithInsectSwarm = hsBalanceOpenedWithInsectSwarm or false
hsBalanceDotAttemptedOnTarget = hsBalanceDotAttemptedOnTarget or { ["Moonfire"] = false, ["Insect Swarm"] = false }
hsBalanceQueueLockUntil = hsBalanceQueueLockUntil or 0
hsBalanceQueuedSpell = hsBalanceQueuedSpell or nil
hsBalanceQueuedPhase = hsBalanceQueuedPhase or nil
hsBalanceLastIssuedCastAt = hsBalanceLastIssuedCastAt or 0
hsBalanceIssuedThisFrameAt = hsBalanceIssuedThisFrameAt or 0
hsBalanceArcaneEntryLockUntil = hsBalanceArcaneEntryLockUntil or 0
hsBalanceArcaneFlushUntil = hsBalanceArcaneFlushUntil or 0
hsBalancePreArcaneHoldUntil = hsBalancePreArcaneHoldUntil or 0
hsBalanceDotLockUntil = hsBalanceDotLockUntil or { ["Moonfire"] = 0, ["Insect Swarm"] = 0 }
hsBalanceDotLockTarget = hsBalanceDotLockTarget or ""

HS_BALANCE_AOE_PRECASTS = 0
HS_BALANCE_STATE = {
	phase = "fish_arcane",
	arcaneUntil = 0,
	natureUntil = 0,
	lastEclipse = ""
}
hsBalanceLastPredictedSpell = nil
hsBalanceLastPredictedAt = 0
HS_BALANCE_PREDICTION_HOLD = 0.9
hsBalanceDotAppliedAt = { ["Moonfire"] = 0, ["Insect Swarm"] = 0 }
hsBalanceDotPendingUntil = { ["Moonfire"] = 0, ["Insect Swarm"] = 0 }
HS_BALANCE_MOONFIRE_GRACE = 9
HS_BALANCE_INSECT_SWARM_GRACE = 12
HS_BALANCE_MOONFIRE_DURATION = 12
HS_BALANCE_INSECT_SWARM_DURATION = 12
hsBalanceClearcastingUntil = 0
hsBalanceLastProcLine = ""
			hsBalanceLastProcReason = nil
			hsBalanceWrathStreak = 0
			hsBalanceArcaneChainUntil = 0
		hsBalanceWrathStreak = 0
hsBalanceWrathStreak = 0
hsBalanceForcedStarfireEvery = 4
hsBalanceArcaneChainUntil = 0
		hsBalanceLastProcReason = nil
hsBalanceAstralBoonUntil = 0
hsBalanceNaturalBoonUntil = 0
hsBalanceLastProcReason = nil
hsBalanceLoopWrathCount = 0
hsBalanceLoopStarfireCount = 0
hsBalanceArcaneTarget = 3
hsBalanceNatureTarget = 4
hsBalanceFishWrathTarget = 4

function HSBalanceSetPhase(phase)
	HS_BALANCE_STATE.phase = phase
end

function HSBalanceHasBuffText(msg, textToFind)
	local lower = string.lower(tostring(msg or ""))
	return strfind(lower, string.lower(textToFind)) ~= nil
end

function HSBalanceGetSpellTexture(spellName)
	return HSCanUseSpellTexture(spellName)
end

function HSBalanceTargetHasSpellDebuff(spellName)
	local texture = HSBalanceGetSpellTexture(spellName)
	if texture == nil or texture == "" then return false end
	for i = 1, 40 do
		local debuffTexture = UnitDebuff("target", i)
		if debuffTexture ~= nil and strfind(tostring(debuffTexture), tostring(texture)) then
			return true
		end
	end
	return false
end

function HSBalanceCanCast(spellName)
	if HS_CanAct(spellName) ~= true then return false end
	if HS_HasRecentCastLock(spellName) == true then return false end
	local slotTexture = HSBalanceGetSpellTexture(spellName)
	local actionSlot = 0
	if slotTexture ~= nil then
		actionSlot = FindActionSlot(slotTexture)
	end
	if actionSlot ~= 0 and IsUse(actionSlot) ~= 1 then
		return false
	end
	if IsSpellOnCD(spellName) then return false end
	if UnitExists("target") == 1 and UnitCanAttack("player", "target") then
		if HS_IsSpellInRangeSafe(spellName, "target") ~= true then return false end
		if HS_InLineOfSightSafe("player", "target") ~= true then return false end
	end
	return true
end

function HSBalanceArcaneActive()
	return HS_BALANCE_STATE.arcaneUntil ~= nil and HS_BALANCE_STATE.arcaneUntil > GetTime()
end

function HSBalanceNatureActive()
	return HS_BALANCE_STATE.natureUntil ~= nil and HS_BALANCE_STATE.natureUntil > GetTime()
end

function HSBalanceRefreshPhase()
	if HS_BALANCE_STATE.phase == nil or HS_BALANCE_STATE.phase == "" then
		HSBalanceSetPhase("fish_arcane")
	end
	if HS_BALANCE_STATE.phase == "arcane_eclipse" and hsBalanceLoopStarfireCount >= hsBalanceArcaneTarget then
		HSBalanceSetPhase("snapshot")
	end
	if HS_BALANCE_STATE.phase == "nature_eclipse" and hsBalanceLoopWrathCount >= hsBalanceNatureTarget then
		hsBalanceLoopWrathCount = 0
		hsBalanceLoopStarfireCount = 0
		HSBalanceSetPhase("fish_arcane")
		HS_BALANCE_AOE_PRECASTS = 0
	end
end

function HSBalanceRememberPrediction(spellName)
	if spellName == nil or spellName == "" then return end
	hsBalanceLastPredictedSpell = spellName
	hsBalanceLastPredictedAt = GetTime()
end

function HSBalanceGetHeldPrediction()
	if hsBalanceLastPredictedSpell == nil or hsBalanceLastPredictedSpell == "" then return nil end
	if (GetTime() - (hsBalanceLastPredictedAt or 0)) > HS_BALANCE_PREDICTION_HOLD then return nil end
	return hsBalanceLastPredictedSpell
end

function HSBalanceResetOpenerState()
	hsBalanceOpenerTarget = UnitName("target") or ""
	hsBalanceOpenedWithMoonfire = false
	hsBalanceOpenedWithInsectSwarm = false
	hsBalanceDotAttemptedOnTarget["Moonfire"] = false
	hsBalanceDotAttemptedOnTarget["Insect Swarm"] = false
end

function HSBalanceEnsureOpenerTarget()
	local currentTarget = UnitName("target") or ""
	if hsBalanceOpenerTarget ~= currentTarget then
		HSBalanceResetOpenerState()
	end
end

function HSBalanceMarkOpenerDotAttempt(spellName)
	HSBalanceEnsureOpenerTarget()
	hsBalanceDotAttemptedOnTarget[spellName] = true
	if spellName == "Moonfire" then
		hsBalanceOpenedWithMoonfire = true
	elseif spellName == "Insect Swarm" then
		hsBalanceOpenedWithInsectSwarm = true
	end
end

function HSBalancePreconsumeExecutionSpell(spellName, phase)
	HSBalanceEnsureOpenerTarget()
	if phase == "fish_arcane" then
		if spellName == "Moonfire" or spellName == "Insect Swarm" then
			hsBalanceDotAttemptedOnTarget[spellName] = true
			if spellName == "Moonfire" then
				hsBalanceOpenedWithMoonfire = true
			elseif spellName == "Insect Swarm" then
				hsBalanceOpenedWithInsectSwarm = true
			end
		end
	end
end

function HSBalanceClearQueueLock()
	hsBalanceQueueLockUntil = 0
	hsBalanceQueuedSpell = nil
	hsBalanceQueuedPhase = nil
end

function HSBalanceIsQueueLocked()
	return false
end

function HSBalanceGetQueueLockDuration(spellName)
	return 0
end

function HSBalanceFlushQueuedCast()
	return
end

function HSBalanceClientReadyToIssue()
	local now = GetTime()

	-- one issued cast decision per frame/tick window
	if hsBalanceIssuedThisFrameAt ~= nil and (now - hsBalanceIssuedThisFrameAt) < 0.05 then
		return false
	end

	-- very short settle window after issuing any spell
	if hsBalanceLastIssuedCastAt ~= nil and (now - hsBalanceLastIssuedCastAt) < 0.34 then
		return false
	end

	-- Nampower cast-state gate
	if type(GetCastInfo) == "function" then
		local ok, a, b = pcall(GetCastInfo)
		if ok == true then
			if type(a) == "table" then
				local n = a.name or a.spell or a.cast
				local remaining = a.remaining
				if (n ~= nil and n ~= "") or (type(remaining) == "number" and remaining > 0.05) then
					return false
				end
			elseif type(a) == "string" and a ~= "" then
				return false
			elseif type(b) == "number" and b > 0.05 then
				return false
			end
		end
	end

	-- Vanilla/API fallback
	if type(UnitCastingInfo) == "function" then
		local ok, castName = pcall(UnitCastingInfo, "player")
		if ok == true and castName ~= nil and castName ~= "" then
			return false
		end
	end

	return true
end

function HSBalanceMarkIssuedCast()
	local now = GetTime()
	hsBalanceLastIssuedCastAt = now
	hsBalanceIssuedThisFrameAt = now
end

function HSBalanceStartPreArcaneHold()
	hsBalancePreArcaneHoldUntil = GetTime() + 0.55
end

function HSBalanceClearPreArcaneHold()
	hsBalancePreArcaneHoldUntil = 0
end

function HSBalanceIsPreArcaneHoldActive()
	return type(hsBalancePreArcaneHoldUntil) == "number" and hsBalancePreArcaneHoldUntil > GetTime()
end

function HSBalanceShouldSuppressFinalWrath()
	if tostring(HS_BALANCE_STATE.phase or "") ~= "fish_arcane" then
		return false
	end
	local target = tonumber(hsBalanceFishWrathTarget or 4) or 4
	local count = tonumber(hsBalanceLoopWrathCount or 0) or 0
	-- Start suppressing the next Wrath one cast early so Arcane can begin cleanly.
	return count >= math.max(0, target - 1)
end

function HSBalanceStartArcaneFlush()
	hsBalanceArcaneFlushUntil = GetTime() + 0.35
end

function HSBalanceIsArcaneFlushActive()
	return type(hsBalanceArcaneFlushUntil) == "number" and hsBalanceArcaneFlushUntil > GetTime()
end

function HSBalanceStartArcaneEntryLock()
	hsBalanceArcaneEntryLockUntil = GetTime() + 0.90
end

function HSBalanceIsArcaneEntryLocked()
	return type(hsBalanceArcaneEntryLockUntil) == "number" and hsBalanceArcaneEntryLockUntil > GetTime()
end

function HSBalanceExecutionAllowsSpell(spellName, phase)
	phase = tostring(phase or HS_BALANCE_STATE.phase or "")
	if HSBalanceIsPreArcaneHoldActive() == true and spellName == "Wrath" then
		return false
	end
	if HSBalanceIsArcaneEntryLocked() == true then
		return spellName == "Starfire"
	end
	if phase == "arcane_eclipse" then
		return spellName == "Starfire"
	elseif phase == "nature_eclipse" then
		return spellName == "Wrath" or spellName == "Moonfire" or spellName == "Insect Swarm"
	elseif phase == "fish_arcane" then
		if spellName == "Insect Swarm" then
			return hsBalanceOpenedWithInsectSwarm ~= true
		elseif spellName == "Moonfire" then
			return hsBalanceOpenedWithMoonfire ~= true
		else
			return spellName == "Wrath" or spellName == "Starfire"
		end
	elseif phase == "snapshot" then
		return spellName == "Moonfire" or spellName == "Insect Swarm"
	end
	return true
end

function HSBalanceCanUseOpenerDot(spellName)
	HSBalanceEnsureOpenerTarget()
	if hsBalanceDotAttemptedOnTarget[spellName] == true then
		return false
	end
	if spellName == "Moonfire" then
		return hsBalanceOpenedWithMoonfire ~= true
	elseif spellName == "Insect Swarm" then
		return hsBalanceOpenedWithInsectSwarm ~= true
	end
	return true
end

function HSBalanceResetDotLocks()
	hsBalanceDotLockUntil["Moonfire"] = 0
	hsBalanceDotLockUntil["Insect Swarm"] = 0
	hsBalanceDotLockTarget = UnitName("target") or ""
end

function HSBalanceEnsureDotLockTarget()
	local currentTarget = UnitName("target") or ""
	if hsBalanceDotLockTarget ~= currentTarget then
		HSBalanceResetDotLocks()
	end
end

function HSBalanceCanAttemptDot(spellName)
	HSBalanceEnsureDotLockTarget()
	local untilAt = hsBalanceDotLockUntil[spellName] or 0
	return untilAt <= GetTime()
end

function HSBalanceLockDotOnAttempt(spellName)
	HSBalanceEnsureDotLockTarget()
	local duration = 10
	if spellName == "Moonfire" then
		duration = 12
	elseif spellName == "Insect Swarm" then
		duration = 12
	end
	local buffer = 1.0
	hsBalanceDotLockUntil[spellName] = GetTime() + math.max(8, duration - buffer)
end

function HSBalanceDotDuration(spellName)
	if spellName == "Moonfire" then
		return HS_BALANCE_MOONFIRE_DURATION
	elseif spellName == "Insect Swarm" then
		return HS_BALANCE_INSECT_SWARM_DURATION
	end
	return 0
end

function HSBalanceDotIsActive(spellName)
	local pendingUntil = hsBalanceDotPendingUntil[spellName]
	if type(pendingUntil) == "number" and pendingUntil > GetTime() then
		return true
	end
	local auraRemaining = HS_GetAuraDurationSafe("target", spellName)
	if type(auraRemaining) == "number" and auraRemaining > 0.4 then
		return true
	end
	local duration = HSBalanceDotDuration(spellName)
	local appliedAt = hsBalanceDotAppliedAt[spellName]
	if type(appliedAt) == "number" and appliedAt > 0 and duration > 0 then
		if (GetTime() - appliedAt) < duration then
			return true
		end
	end
	if HSBalanceTargetHasSpellDebuff(spellName) == true then
		return true
	end
	return false
end

function HSBalanceMarkDotPending(spellName)
	if hsBalanceDotPendingUntil[spellName] ~= nil then
		hsBalanceDotPendingUntil[spellName] = GetTime() + 1.8
		HSBalanceLog("dot_pending="..tostring(spellName).." t="..tostring(math.floor(GetTime())))
	end
end

function HSBalanceConfirmDotApplied(spellName)
	if hsBalanceDotAppliedAt[spellName] ~= nil then
		hsBalanceDotAppliedAt[spellName] = GetTime()
	end
	if hsBalanceDotPendingUntil[spellName] ~= nil then
		hsBalanceDotPendingUntil[spellName] = 0
	end
	HSBalanceLog("dot_applied="..tostring(spellName).." t="..tostring(math.floor(GetTime())))
end

function HSBalanceHasClearcasting()
	return hsBalanceClearcastingUntil ~= nil and hsBalanceClearcastingUntil > GetTime()
end

function HSBalanceHasAstralBoon()
	return hsBalanceAstralBoonUntil ~= nil and hsBalanceAstralBoonUntil > GetTime()
end

function HSBalanceHasNaturalBoon()
	return hsBalanceNaturalBoonUntil ~= nil and hsBalanceNaturalBoonUntil > GetTime()
end

function HSBalanceSetProcReason(reason)
	hsBalanceLastProcReason = reason
end

function HSBalanceGetProcReasonForSpell(spellName)
	if HSBalanceHasClearcasting() == true and spellName == "Starfire" then
		return "Clearcasting"
	end
	if HSBalanceHasAstralBoon() == true and spellName == "Starfire" then
		return "Astral Boon"
	end
	if HSBalanceHasNaturalBoon() == true and (spellName == "Wrath" or spellName == "Hurricane") then
		return "Natural Boon"
	end
	return nil
end

function HSBalanceConsumeProcForSpell(spellName)
	if spellName == "Starfire" then
		if HSBalanceHasClearcasting() == true then
			hsBalanceClearcastingUntil = 0
		end
		if HSBalanceHasAstralBoon() == true then
			hsBalanceAstralBoonUntil = 0
		end
	elseif spellName == "Wrath" or spellName == "Hurricane" then
		if HSBalanceHasNaturalBoon() == true then
			hsBalanceNaturalBoonUntil = 0
		end
	end
end

function HSBalanceRegisterCast(spellName)
	if spellName == "Wrath" then
		hsBalanceWrathStreak = (hsBalanceWrathStreak or 0) + 1
	else
		hsBalanceWrathStreak = 0
	end
end

function HSBalanceArcaneChainActive()
	return hsBalanceArcaneChainUntil ~= nil and hsBalanceArcaneChainUntil > GetTime()
end

function HSBalanceStartArcaneChain(seconds)
	hsBalanceArcaneChainUntil = GetTime() + (seconds or 0)
	HSBalanceSetPhase("arcane_chain")
end



function HSBalancePrintProc(line)
	if HS_IsOverlayDebugEnabled() ~= true then return end
	if line == nil or line == "" then return end
	if hsBalanceLastProcLine == line then return end
	hsBalanceLastProcLine = line
	HSLog(line)
end

function HSBalanceDebugProc(msg)
	local lower = string.lower(tostring(msg or ""))
	if lower == "" then return end

	if strfind(lower, "clearcasting fades") or strfind(lower, "omen of clarity fades") then
		hsBalanceClearcastingUntil = 0
		HSBalancePrintProc("|cffd08524Shifty |cff888888PROC: Clearcasting faded")
		return
	end

	if strfind(lower, "clearcasting") or strfind(lower, "omen of clarity") then
		hsBalanceClearcastingUntil = GetTime() + 3
		HSBalancePrintProc("|cffd08524Shifty |cff00ffffPROC: Clearcasting active")
		return
	end

	if strfind(lower, "arcane eclipse") then
		HS_BALANCE_STATE.arcaneUntil = GetTime() + 15
		HS_BALANCE_STATE.natureUntil = 0
		HS_BALANCE_STATE.lastEclipse = "arcane"
		HSBalanceSetPhase("arcane_eclipse")
		HSBalanceLog("event=Arcane Eclipse detected msg="..tostring(msg))
		HSBalancePrintProc("|cffd08524Shifty |cff66ccffPROC: Arcane Eclipse active")
		return
	end

	if strfind(lower, "nature eclipse") then
		HS_BALANCE_STATE.natureUntil = GetTime() + 15
		HS_BALANCE_STATE.arcaneUntil = 0
		HS_BALANCE_STATE.lastEclipse = "nature"
		HSBalanceSetPhase("nature_eclipse")
		HSBalanceLog("event=Nature Eclipse detected msg="..tostring(msg))
		HSBalancePrintProc("|cffd08524Shifty |cff66ff66PROC: Nature Eclipse active")
		return
	end

	if strfind(lower, "astral boon fades") then
		hsBalanceAstralBoonUntil = 0
		HSBalancePrintProc("|cffd08524Shifty |cff888888PROC: Astral Boon faded")
		return
	end

	if strfind(lower, "natural boon fades") then
		hsBalanceNaturalBoonUntil = 0
		HSBalancePrintProc("|cffd08524Shifty |cff888888PROC: Natural Boon faded")
		return
	end

	if strfind(lower, "astral boon") then
		hsBalanceAstralBoonUntil = GetTime() + 4
		HSBalanceLog("event=Astral Boon detected msg="..tostring(msg))
		HSBalancePrintProc("|cffd08524Shifty |cffffff66PROC: Astral Boon active")
		return
	end

	if strfind(lower, "natural boon") then
		hsBalanceNaturalBoonUntil = GetTime() + 4
		HSBalanceLog("event=Natural Boon detected msg="..tostring(msg))
		HSBalancePrintProc("|cffd08524Shifty |cffffff66PROC: Natural Boon active")
		return
	end
end

function HS_IsBalanceMode()
	local formId = GetActiveForm()
	if formId == 1 then return false end
	if UnitPowerType("player") == 3 then return false end
	return true
end

function HS_GetBalancePredictedSpellName()
	if UnitExists("target") ~= 1 or UnitIsDead("target") then return nil end
	HSBalanceRefreshPhase()
	if HSBalanceIsArcaneFlushActive() == true then return nil end

	local canCastOnTarget = UnitCanAttack("player", "target")
	local moonfireUp = HSBalanceDotIsActive("Moonfire")
	local insectUp = HSBalanceDotIsActive("Insect Swarm")
	local predicted = nil
	local phase = HS_BALANCE_STATE.phase or "fish_arcane"

	HSBalanceLog("strict_state phase="..tostring(phase).." moonfire="..(moonfireUp == true and "1" or "0").." insect="..(insectUp == true and "1" or "0").." wcnt="..tostring(hsBalanceLoopWrathCount or 0).." scnt="..tostring(hsBalanceLoopStarfireCount or 0))
	HSBalanceSetProcReason(nil)

	if HSMode == "aoe" then
		local wantIS = insectUp ~= true and HS_HasRecentCastLock("Insect Swarm") ~= true and HSBalanceCanCast("Insect Swarm") and canCastOnTarget
		local wantMF = moonfireUp ~= true and HS_HasRecentCastLock("Moonfire") ~= true and HSBalanceCanCast("Moonfire") and canCastOnTarget

		if wantIS then
			predicted = "Insect Swarm"
		elseif wantMF then
			predicted = "Moonfire"
		elseif HSBalanceHasNaturalBoon() == true or HSBalanceHasClearcasting() == true then
			if HSBalanceCanCast("Hurricane") and canCastOnTarget then
				predicted = "Hurricane"
			end
		elseif HSBalanceCanCast("Wrath") and canCastOnTarget then
			predicted = "Wrath"
		end
		if predicted ~= nil then
			HSBalanceRememberPrediction(predicted)
			return predicted
		end
		return HSBalanceGetHeldPrediction()
	end

	if phase == "snapshot" then
		if insectUp ~= true and HS_HasRecentCastLock("Insect Swarm") ~= true and HSBalanceCanCast("Insect Swarm") and canCastOnTarget then
			HSBalanceLog("refresh_is=snapshot_missing")
			predicted = "Insect Swarm"
		elseif moonfireUp ~= true and HS_HasRecentCastLock("Moonfire") ~= true and HSBalanceCanCast("Moonfire") and canCastOnTarget then
			HSBalanceLog("refresh_mf=snapshot_missing")
			predicted = "Moonfire"
		else
			hsBalanceLoopWrathCount = 0
			hsBalanceLoopStarfireCount = 0
			HSBalanceSetPhase("nature_eclipse")
			phase = "nature_eclipse"
		end
	end

	if predicted == nil and phase == "arcane_eclipse" then
		if HSBalanceCanCast("Starfire") and canCastOnTarget then
			predicted = "Starfire"
		else
			return nil
		end
	elseif predicted == nil and phase == "nature_eclipse" then
		if insectUp ~= true and HS_HasRecentCastLock("Insect Swarm") ~= true and HSBalanceCanCast("Insect Swarm") and canCastOnTarget then
			HSBalanceLog("refresh_is=nature_missing")
			predicted = "Insect Swarm"
		elseif moonfireUp ~= true and HS_HasRecentCastLock("Moonfire") ~= true and HSBalanceCanCast("Moonfire") and canCastOnTarget then
			HSBalanceLog("refresh_mf=nature_missing")
			predicted = "Moonfire"
		elseif HSBalanceCanCast("Wrath") and canCastOnTarget then
			predicted = "Wrath"
		else
			return nil
		end
	elseif predicted == nil and phase == "fish_arcane" then
		HSBalanceEnsureOpenerTarget()

		local needIS = (hsBalanceOpenedWithInsectSwarm ~= true and insectUp ~= true and HS_HasRecentCastLock("Insect Swarm") ~= true and HSBalanceCanCast("Insect Swarm") and canCastOnTarget)
		local needMF = (hsBalanceOpenedWithMoonfire ~= true and moonfireUp ~= true and HS_HasRecentCastLock("Moonfire") ~= true and HSBalanceCanCast("Moonfire") and canCastOnTarget)

		if needIS then
			predicted = "Insect Swarm"
		elseif needMF then
			predicted = "Moonfire"
		else
			if HSBalanceShouldSuppressFinalWrath() == true then
				HSBalanceStartPreArcaneHold()
				HSBalanceSetPhase("arcane_eclipse")
				HSBalanceStartArcaneEntryLock()
				HSBalanceStartArcaneFlush()
				phase = "arcane_eclipse"
				if HSBalanceCanCast("Starfire") and canCastOnTarget then
					predicted = "Starfire"
				end
			elseif (hsBalanceLoopWrathCount or 0) >= hsBalanceFishWrathTarget then
				HSBalanceSetPhase("arcane_eclipse")
				HSBalanceStartArcaneEntryLock()
				HSBalanceStartArcaneFlush()
				phase = "arcane_eclipse"
				if HSBalanceCanCast("Starfire") and canCastOnTarget then
					predicted = "Starfire"
				end
			else
				if HSBalanceCanCast("Wrath") and canCastOnTarget then
					predicted = "Wrath"
				end
			end
		end
	end

	if predicted ~= nil then
		HSBalanceRememberPrediction(predicted)
		return predicted
	end
	return nil
end

function HSBalanceCastRotation()
	if HS_IsRotationLocked() == true then
		return false
	end
	if HS_IsAnySpellCastInProgress() == true then
		return false
	end
	if HSBalanceIsArcaneFlushActive() == true then
		return false
	end

	local spellName = HS_GetBalancePredictedSpellName()
	local phase = HS_BALANCE_STATE.phase or ""
	if spellName == nil then
		return false
	end
	if HSBalanceIsPreArcaneHoldActive() == true and spellName == "Wrath" then
		return false
	end
	if HSBalanceIsArcaneEntryLocked() == true and spellName ~= "Starfire" then
		return false
	end
	if HSBalanceExecutionAllowsSpell(spellName, phase) ~= true then
		return false
	end

	if HS_ShouldEmitBalanceDecision(spellName, phase) then
		HS_LogBalanceCastDecision(tostring(spellName).." phase="..tostring(phase))
	end

	HSBalanceRememberPrediction(spellName)
	if spellName == "Moonfire" or spellName == "Insect Swarm" then
		HSBalanceMarkDotPending(spellName)
	end

	if spellName == "Hurricane" then
		HSBalanceRememberPrediction(spellName)
		return false
	end

	local didCast = HSCast(spellName)
	if didCast == true then
		HS_SetRotationLock(spellName)
		HSBalanceConsumeProcForSpell(spellName)
		HSBalanceRegisterCast(spellName)
		return true
	end
	return false
end




function SH_Moonkin_ResetState()
	hsLastBalanceDecisionSpell = nil
	hsLastBalanceDecisionPhase = nil
	hsLastBalanceDecisionAt = 0
	hsLastRotationLockUntil = 0
	hsLastRotationLockSpell = nil
	hsBalanceArcaneEntryLockUntil = 0
	hsBalanceArcaneFlushUntil = 0
	hsBalancePreArcaneHoldUntil = 0
	HSBalanceClearQueueLock()
	HSBalanceResetDotLocks()
	HSBalanceResetOpenerState()
end

function SH_Moonkin_Run()
	return HSBalanceCastRotation()
end

SH_Moonkin_IsActive = HS_IsBalanceMode
SH_Moonkin_GetPredictedSpellName = HS_GetBalancePredictedSpellName
SH_BalanceCastRotation = HSBalanceCastRotation
