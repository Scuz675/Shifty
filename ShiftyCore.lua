-- Shifty DLL Branch v24 pre-arcane control
-- Shifty DLL Branch v19
-- Shifty DLL Branch v18
-- Shifty DLL Branch v17
-- Shifty DLL Branch v16
-- Shifty DLL Branch v15
-- Shifty DLL Branch v13
doclaw = 0
mobcurhealth = 100--UnitHealth('target')		
drtable = {}
curtime = nil
combstarttime = nil
temptime = nil
numtargets = 0
reportthreshold = 80
playername,_ = UnitName('player')
hsManaLib = nil
hsManaLibChecked = false
hsManaLibFallbackNotice = false
hsSpellKnownCache = {}
hsSpellIndexCache = {}
hsReshiftChecked = false
hsHasReshift = false
hsLastShiftAttempt = 0
HS_SHRED_ENERGY_THRESHOLD = 60
HS_RIP_TEXTURE = "Ability_GhoulFrenzy"
HS_RAKE_TEXTURE = "Ability_Druid_Disembowel"
HS_DEBUG_LOG_MAX = 500
HS_SHIFT_RETRY_GAP = 0.25
HS_NOT_BEHIND_LOCKOUT = 1.0
HS_FF_REFRESH_MAX_CP = 2
hsDebuffImmune = { target = "", rip = false, rake = false, ff = false }
ShiftyMode = "single"
HS_SPELL_IDS = {
	["Shred"] = 5221,
	["Claw"] = 1082,
	["Rake"] = 1822,
	["Rip"] = 1079,
	["Ferocious Bite"] = 22568,
	["Faerie Fire (Feral)"] = 16857,
	["Tiger's Fury"] = 5217,
	["Swipe"] = 779,
	["Maul"] = 6807,
	["Demoralizing Roar"] = 99,
	["Cower"] = 8998,
	["Barkskin"] = 22812,
	["Ravage"] = 6785,
	["Innervate"] = 29166,
	["Wrath"] = 5176,
	["Starfire"] = 2912,
	["Moonfire"] = 8921,
	["Insect Swarm"] = 24974,
	["Hurricane"] = 16914,
	["Faerie Fire"] = 770
}
ShiftyLastSpell = nil
ShiftyLastCastSpell = nil
ShiftyLastDisplaySpell = nil
ShiftyLastSecondDisplaySpell = nil
ShiftyTooltipSpellID = nil
ShiftyOverlayEnabled = 1
ShiftyOverlayScale = 1
hsOverlayFrame = nil
hsOverlayElapsed = 0
hsOverlayLastAnnounced = ""
hsOverlayLastPredicted = nil
HS_LOG_MAX_LINES = 800

local hsHasNampower = type(GetCastInfo) == "function"
local hsHasUnitXP = type(UnitXP) == "function" and pcall(UnitXP, "nop", "nop")
local hsHasSuperWoW = type(SUPERWOW_VERSION) ~= "nil"
local hsLastCastAttemptAt = 0
local hsLastCastAttemptSpell = nil
local hsLastActionAt = 0
local hsLastActionSpell = nil
local HS_AGGRO_GCD_LOCK = 0.25
local HS_AGGRO_INSTANT_LOCK = 1.15
local HS_AGGRO_HARDCAST_LOCK = 0.20
local HS_AGGRO_FALLBACK_CAST_BUFFER = 0.35
local HS_PULL_START_LOCK = 0.30
local hsCastLockUntil = 0
local hsCombatStartAt = 0
local hsBalanceOpened = false
local hsBalanceOpenerPendingSpell = nil
local hsBalanceOpenerPendingUntil = 0
local hsLastBalanceLogText = nil
local hsLastBalanceLogAt = 0
local hsLastBalanceDecisionSpell = nil
local hsLastBalanceDecisionPhase = nil
local hsLastBalanceDecisionAt = 0
local hsLastRotationLockUntil = 0
local hsLastRotationLockSpell = nil
local hsBalanceQueueLockUntil = 0
local hsBalanceQueuedSpell = nil
local hsBalanceQueuedPhase = nil
local hsBalanceLastIssuedCastAt = 0
local hsBalanceIssuedThisFrameAt = 0
local hsBalanceArcaneEntryLockUntil = 0
local hsBalanceArcaneFlushUntil = 0
local hsBalancePreArcaneHoldUntil = 0
local hsBalanceDotLockUntil = { ["Moonfire"] = 0, ["Insect Swarm"] = 0 }
local hsBalanceDotLockTarget = ""
local hsBalanceOpenerTarget = ""
local hsBalanceOpenedWithMoonfire = false
local hsBalanceOpenedWithInsectSwarm = false
local hsBalanceDotAttemptedOnTarget = { ["Moonfire"] = false, ["Insect Swarm"] = false }


function HS_NormalizeDLLSpellName(name)
	local s = tostring(name or "")
	s = string.gsub(s, "%b()", "")
	s = string.gsub(s, "^%s+", "")
	s = string.gsub(s, "%s+$", "")
	return s
end

function HS_GetCastInfoSnapshot()
	if hsHasNampower ~= true or type(GetCastInfo) ~= "function" then return nil end
	local ok, info = pcall(GetCastInfo)
	if ok ~= true or type(info) ~= "table" then return nil end
	return info
end

function HS_GetRemainingCastTime()
	local info = HS_GetCastInfoSnapshot()
	if info == nil then return 0 end
	local castEnd = info.castEndS or info.endTime or info.castEnd or 0
	if type(castEnd) ~= "number" then return 0 end
	local remaining = castEnd - GetTime()
	if remaining < 0 then remaining = 0 end
	return remaining
end

function HS_GetCurrentCastSpellName()
	local info = HS_GetCastInfoSnapshot()
	if info == nil then return nil end
	local name = info.name or info.spellName or info.spell or info.castName
	name = HS_NormalizeDLLSpellName(name)
	if name == "" then return nil end
	return name
end

function HS_IsCastingSpell(spellName)
	local current = HS_GetCurrentCastSpellName()
	if current == nil then return false end
	return string.lower(current) == string.lower(HS_NormalizeDLLSpellName(spellName)) and HS_GetRemainingCastTime() > 0.12
end

function HS_IsAnySpellCastInProgress()
	if HS_GetRemainingCastTime() > 0.12 then return true end
	local current = HS_GetCurrentCastSpellName()
	if current ~= nil and current ~= "" then return true end
	return false
end

function HS_HasRecentCastLock(spellName)
	local now = GetTime()
	if hsLastCastAttemptAt == nil or hsLastCastAttemptAt <= 0 then return false end
	if now < hsLastCastAttemptAt then
		hsLastCastAttemptAt = 0
		hsLastCastAttemptSpell = nil
		return false
	end
	if hsLastCastAttemptSpell ~= nil and string.lower(tostring(hsLastCastAttemptSpell)) == string.lower(tostring(spellName or "")) then
		if (now - hsLastCastAttemptAt) < HS_GetSpellActionLock(spellName) then return true end
	end
	if hsLastActionAt ~= nil and hsLastActionAt > 0 and now >= hsLastActionAt then
		if (now - hsLastActionAt) < HS_AGGRO_HARDCAST_LOCK then return true end
	end
	return false
end

function HS_RegisterCastAttempt(spellName)
	hsLastCastAttemptAt = GetTime()
	hsLastCastAttemptSpell = spellName
	hsLastActionAt = hsLastCastAttemptAt
	hsLastActionSpell = spellName
end


function HS_GetRotationLockDuration(spellName)
	spellName = tostring(spellName or "")
	if spellName == "Moonfire" or spellName == "Insect Swarm" or spellName == "Hurricane" then
		return 0.60
	elseif spellName == "Wrath" then
		return 0.60
	elseif spellName == "Starfire" then
		return 0.75
	end
	return 0.50
end

function HS_IsRotationLocked()
	return type(hsLastRotationLockUntil) == "number" and hsLastRotationLockUntil > GetTime()
end

function HS_SetRotationLock(spellName)
	hsLastRotationLockSpell = spellName
	hsLastRotationLockUntil = GetTime() + HS_GetRotationLockDuration(spellName)
end

function HS_GetSpellHardLock(spellName)
	spellName = tostring(spellName or "")
	if spellName == "Moonfire" or spellName == "Insect Swarm" or spellName == "Hurricane" then
		return HS_AGGRO_INSTANT_LOCK
	end
	return HS_AGGRO_FALLBACK_CAST_BUFFER
end

function HS_IsHardLocked()
	if HS_IsAnySpellCastInProgress() == true then
		return true
	end
	return hsCastLockUntil ~= nil and hsCastLockUntil > GetTime()
end

function HS_GetSpellActionLock(spellName)
	if spellName == "Moonfire" or spellName == "Insect Swarm" or spellName == "Hurricane" then
		return HS_AGGRO_INSTANT_LOCK
	end
	return HS_AGGRO_GCD_LOCK
end

function HS_InPullWindow()
	return hsCombatStartAt ~= nil and hsCombatStartAt > 0 and (GetTime() - hsCombatStartAt) < HS_PULL_START_LOCK
end

function HS_CanAct(spellName)
	local now = GetTime()
	if hsBalanceOpenerPendingSpell ~= nil and hsBalanceOpenerPendingUntil ~= nil and hsBalanceOpenerPendingUntil > now then
		if spellName == hsBalanceOpenerPendingSpell then
			return false
		end
	end
	if HS_InPullWindow() == true then
		return false
	end
	if HS_IsHardLocked() == true then
		return false
	end
	local actionLock = HS_GetSpellActionLock(spellName)
	if hsLastActionAt ~= nil and hsLastActionAt > 0 and now >= hsLastActionAt then
		if (now - hsLastActionAt) < actionLock then
			return false
		end
	end
	if HS_IsAnySpellCastInProgress() == true then
		return false
	end
	return true
end

function HS_IsSpellInRangeSafe(spellName, unit)
	unit = unit or "target"
	if hsHasNampower == true and type(IsSpellInRange) == "function" then
		local ok, result = pcall(IsSpellInRange, spellName, unit)
		if ok == true and result ~= nil then
			if result == 0 then return false end
			if result == 1 then return true end
		end
	end
	return true
end

function HS_InLineOfSightSafe(unit1, unit2)
	if hsHasUnitXP == true then
		local ok, inSight = pcall(UnitXP, "inSight", unit1 or "player", unit2 or "target")
		if ok == true then return inSight and true or false end
	end
	return true
end

function HS_GetAuraDurationSafe(unit, auraName)
	if type(GetPlayerAuraDuration) ~= "function" then return nil end
	local ok, remaining = pcall(GetPlayerAuraDuration, unit, auraName)
	if ok == true and type(remaining) == "number" then return remaining end
	local ok2, remaining2 = pcall(GetPlayerAuraDuration, auraName)
	if ok2 == true and type(remaining2) == "number" then return remaining2 end
	return nil
end

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
	if hsBalanceLastIssuedCastAt ~= nil and (now - hsBalanceLastIssuedCastAt) < 0.30 then
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
		return spellName == "Wrath"
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

	if ShiftyMode == "aoe" then
		if HSBalanceCanCast("Hurricane") and canCastOnTarget then
			predicted = "Hurricane"
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
		if moonfireUp ~= true and HS_HasRecentCastLock("Moonfire") ~= true and HSBalanceCanCast("Moonfire") and canCastOnTarget then
			predicted = "Moonfire"
		elseif insectUp ~= true and HS_HasRecentCastLock("Insect Swarm") ~= true and HSBalanceCanCast("Insect Swarm") and canCastOnTarget then
			predicted = "Insect Swarm"
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
		if HSBalanceCanCast("Wrath") and canCastOnTarget then
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

	local didCast = HSCast(spellName)
	if didCast == true then
		HS_SetRotationLock(spellName)
		HSBalanceConsumeProcForSpell(spellName)
		HSBalanceRegisterCast(spellName)
		return true
	end
	return false
end



function HS_GetLogStore()
	if ShiftyDebugLog == nil or type(ShiftyDebugLog) ~= "table" then
		ShiftyDebugLog = {}
	end
	if ShiftyDebugLog._persist == nil or type(ShiftyDebugLog._persist) ~= "table" then
		ShiftyDebugLog._persist = {}
	end
	if ShiftyDebugLog._persist_enabled == nil then
		ShiftyDebugLog._persist_enabled = 1
	end
	return ShiftyDebugLog._persist
end

function HS_IsPersistentLogEnabled()
	if ShiftyDebugLog == nil or type(ShiftyDebugLog) ~= "table" then return true end
	if ShiftyDebugLog._persist_enabled == nil then return true end
	return ShiftyDebugLog._persist_enabled == 1
end

function HS_SetPersistentLogEnabled(enabled)
	if ShiftyDebugLog == nil or type(ShiftyDebugLog) ~= "table" then
		ShiftyDebugLog = {}
	end
	if enabled == true then
		ShiftyDebugLog._persist_enabled = 1
	else
		ShiftyDebugLog._persist_enabled = 0
	end
end

function HSLog(msg)
	if msg == nil then return end
	if HS_IsPersistentLogEnabled() ~= true then return end
	local store = HS_GetLogStore()
	local ts = date("%H:%M:%S")
	local line = "["..ts.."] "..tostring(msg)
	table.insert(store, line)
	while table.getn(store) > (HS_LOG_MAX_LINES or 800) do
		table.remove(store, 1)
	end
end

function HSLogClear()
	local store = HS_GetLogStore()
	while table.getn(store) > 0 do
		table.remove(store, 1)
	end
end

function HSBalanceLog(msg)
	if msg == nil or msg == "" then return end
	HSLog("|BAL| "..tostring(msg))
end

function HSNormalizeSpellName(spellName)
	local normalized = tostring(spellName or "")
	normalized = string.gsub(normalized, "%b()", "")
	normalized = string.gsub(normalized, "%s+$", "")
	return normalized
end

function HSSetTooltipSpell(spellName)
	local normalized = HSNormalizeSpellName(spellName)
	ShiftyLastSpell = normalized
	ShiftyTooltipSpellID = HS_SPELL_IDS[normalized]
	return ShiftyTooltipSpellID
end

function HSGetTooltipSpellID()
	return ShiftyTooltipSpellID
end

function HS_GetLastSpellID()
	return ShiftyTooltipSpellID
end

function HS_GetLastSpellName()
	return ShiftyLastSpell
end

function HS_RefreshTooltip()
	if ShiftyTooltipSpellID ~= nil and type(RunMacroText) == "function" then
		RunMacroText("/tooltip spell:"..ShiftyTooltipSpellID)
	end
	return ShiftyTooltipSpellID
end

function HSCast(spellName, targetOrOnSelf)
	HSSetTooltipSpell(spellName)
	local balancePhase = HS_BALANCE_STATE.phase or ""
	if HS_IsBalanceMode() == true and HSBalanceExecutionAllowsSpell(spellName, balancePhase) ~= true then
		return false
	end
	if HS_CanAct(spellName) ~= true then
		return false
	end
	if HS_HasRecentCastLock(spellName) == true then
		return false
	end
	if hsLastActionSpell == spellName and hsLastActionAt ~= nil and (GetTime() - hsLastActionAt) < HS_GetSpellActionLock(spellName) then
		return false
	end
	HS_RegisterCastAttempt(spellName)
	if spellName == "Moonfire" or spellName == "Insect Swarm" then
		HSBalancePreconsumeExecutionSpell(spellName, balancePhase)
		HSBalanceLockDotOnAttempt(spellName)
		HSBalanceMarkOpenerDotAttempt(spellName)
	end
	if targetOrOnSelf ~= nil then
		CastSpellByName(spellName, targetOrOnSelf)
	else
		CastSpellByName(spellName)
	end
	ShiftyLastCastSpell = spellName
	local now = GetTime()
	hsCastLockUntil = now + HS_GetSpellHardLock(spellName)
	HS_SetRotationLock(spellName)
	return true
end

function HS_LogBalanceCastDecision(text)
	local now = GetTime()
	if hsLastBalanceLogText == text and (now - (hsLastBalanceLogAt or 0)) < 0.20 then
		return
	end
	hsLastBalanceLogText = text
	hsLastBalanceLogAt = now
	HSDebugTrace("BALANCE_CAST", text)
end

function HS_ShouldEmitBalanceDecision(spellName, phase)
	local now = GetTime()
	spellName = tostring(spellName or "")
	phase = tostring(phase or "")

	if hsLastBalanceDecisionSpell ~= spellName or hsLastBalanceDecisionPhase ~= phase then
		hsLastBalanceDecisionSpell = spellName
		hsLastBalanceDecisionPhase = phase
		hsLastBalanceDecisionAt = now
		return true
	end

	if (now - (hsLastBalanceDecisionAt or 0)) > 0.80 then
		hsLastBalanceDecisionAt = now
		return true
	end

	return false
end

function HSCanUseSpellTexture(spellName)
	local spellId = GetSpellID(spellName)
	if spellId == nil then return nil end
	return GetSpellTexture(spellId, "spell")
end

function HS_GetPredictedSpellName()
	if UnitExists("target") ~= 1 or UnitIsDead("target") then
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
		return nil
	end
	if HS_IsBalanceMode() == true then
		return HS_GetBalancePredictedSpellName()
	end
	local formId = GetActiveForm()
	local energy = UnitMana("player") or 0
	local comboPoints = HSGetComboPoints()
	local stealthed = HSBuffChk("Ability_Ambush")
	if formId == 1 then
		if HSAutoFF == 1 and IsTDebuff('target', 'Spell_Nature_FaerieFire') == false and not IsSpellOnCD("Faerie Fire (Feral)") then
			return "Faerie Fire (Feral)"
		end
		if ShiftyMode == "aoe" then
			if energy >= 15 and not IsSpellOnCD("Swipe") then return "Swipe" end
			if energy >= 10 and not IsSpellOnCD("Demoralizing Roar") then return "Demoralizing Roar" end
			if energy >= 15 and not IsSpellOnCD("Maul") then return "Maul" end
		else
			if energy >= 20 and not IsSpellOnCD("Demoralizing Roar") and IsTDebuff('target', 'Ability_Druid_DemoralizingRoar') == false then return "Demoralizing Roar" end
			if energy >= 15 and not IsSpellOnCD("Maul") then return "Maul" end
		end
		return nil
	end

	if UnitPowerType("player") ~= 3 then
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
	local fbthresh = 5
	if ShiftyMode == "aoe" then fbthresh = 4 end
	if GetInventoryItemLink('player',18) ~= nil and string.find(GetInventoryItemLink('player',18), 'Idol of Ferocity') then
		idolofferocity = 3
		clawCost = 100 - (55 + ferocity + 20 + idolofferocity)
		builderCost = clawCost
	end
	if BehindTarget() == true and energy >= HS_SHRED_ENERGY_THRESHOLD and ShiftyMode ~= "aoe" and FindActionSlot("Spell_Shadow_VampiricAura") ~= 0 then
		builderSpell = "Shred"
		builderCost = shredCost
	end

	if HSTigerUse == 1 and stealthed == false and HSBuffChk('Ability_Mount_JungleTiger') == false and (not IsSpellOnCD("Tiger's Fury")) and energy >= 30 and comboPoints < 4 and (CheckInteractDistance('target',3) == 1 or MobTooFar() == true) then
		return "Tiger's Fury"
	end
	if stealthed == false and CheckInteractDistance('target',3) == 1 and comboPoints < fbthresh and canRake and IsTDebuff('target', 'Ability_Druid_Disembowel') == false and IsUse(FindActionSlot("Ability_Druid_Rake")) == 1 and (not IsSpellOnCD("Rake")) and (HSBuffChk("Spell_Shadow_ManaBurn") == true or energy >= rakeCost) then
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
		local shouldRip = comboPoints == 5 and HasRip() == false and canRip and ShiftyMode ~= "aoe"
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


function HS_GetOverlayStore()
	if ShiftyDebugLog == nil or type(ShiftyDebugLog) ~= "table" then
		ShiftyDebugLog = {}
	end
	if ShiftyDebugLog._overlay == nil or type(ShiftyDebugLog._overlay) ~= "table" then
		ShiftyDebugLog._overlay = {}
	end
	return ShiftyDebugLog._overlay
end

function HS_IsOverlayDebugEnabled()
	local store = HS_GetOverlayStore()
	if store.debug == 1 then return true end
	return false
end

function HS_SetOverlayDebugEnabled(enabled)
	local store = HS_GetOverlayStore()
	if enabled == true then
		store.debug = 1
	else
		store.debug = 0
	end
end

function HS_IsOverlayDebugQuiet()
	local store = HS_GetOverlayStore()
	return store.debug_quiet == 1
end

function HS_SetOverlayDebugQuiet(enabled)
	local store = HS_GetOverlayStore()
	if enabled == true then
		store.debug_quiet = 1
	else
		store.debug_quiet = 0
	end
end

function HS_SaveOverlayPosition()
	if hsOverlayFrame == nil then return end
	local store = HS_GetOverlayStore()
	local point, _, relativePoint, xOfs, yOfs = hsOverlayFrame:GetPoint(1)
	store.point = point or "CENTER"
	store.relativePoint = relativePoint or "CENTER"
	store.x = xOfs or 0
	store.y = yOfs or 160
end

function HS_RestoreOverlayPosition()
	if hsOverlayFrame == nil then return end
	local store = HS_GetOverlayStore()
	hsOverlayFrame:ClearAllPoints()
	if store.x ~= nil and store.y ~= nil then
		hsOverlayFrame:SetPoint(store.point or "CENTER", UIParent, store.relativePoint or "CENTER", store.x, store.y)
	else
		hsOverlayFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 160)
	end
end


function HS_OverlayGetCooldownRemaining(spellName)
	if spellName == nil or spellName == "" then return 0 end
	local spellId = GetSpellID(spellName)
	if spellId == nil then return 0 end
	local start, duration, enabled = GetSpellCooldown(spellId, "spell")
	if start == nil or duration == nil then return 0 end
	if enabled == 0 or duration <= 1.5 or start <= 0 then return 0 end
	local remaining = (start + duration) - GetTime()
	if remaining < 0 then remaining = 0 end
	return remaining
end

function HS_OverlayFormatCooldown(remaining)
	remaining = tonumber(remaining or 0) or 0
	if remaining <= 0 then return "" end
	if remaining >= 10 then
		return tostring(math.floor(remaining + 0.5))
	end
	return string.format("%.1f", remaining)
end

function HS_OverlayGetPhaseInfo()
	local formId = GetActiveForm()
	if HS_IsBalanceMode() == true then
		local phase = tostring((HS_BALANCE_STATE and HS_BALANCE_STATE.phase) or "")
		if HSBalanceArcaneActive() == true or phase == "arcane_eclipse" or phase == "arcane_chain" then
			return "Arcane", 0.70, 0.45, 1.00
		elseif HSBalanceNatureActive() == true or phase == "nature_eclipse" then
			return "Nature", 0.25, 0.95, 0.25
		end
		return "Moonkin", 1.00, 1.00, 1.00
	elseif formId == 1 then
		return "Bear", 1.00, 0.20, 0.20
	elseif UnitPowerType("player") == 3 then
		return "Cat", 1.00, 0.55, 0.10
	end
	return "Caster", 1.00, 1.00, 1.00
end

function HS_OverlaySetIcon(textureObj, spellName, fallbackTexture)
	if textureObj == nil then return end
	if spellName == nil or spellName == "" then
		textureObj:Hide()
		return
	end

	local texture = HSCanUseSpellTexture(spellName)
	if texture ~= nil and texture ~= "" then
		textureObj:SetTexture(texture)
		textureObj:SetVertexColor(1, 1, 1)
		textureObj:Show()
	else
		textureObj:Hide()
	end
end
function HS_PrintOverlayDebug(currentSpell, nextSpell)
	if HS_IsOverlayDebugEnabled() ~= true then return end
	if nextSpell == nil and HS_IsBalanceMode ~= nil and HS_IsBalanceMode() == true then
		nextSpell = HSBalanceGetHeldPrediction()
	end
	local currentText = tostring(currentSpell or "none")
	local nextText = tostring(nextSpell or "none")
	local line = currentText.." -> "..nextText
	if HS_IsOverlayDebugQuiet() == true and hsOverlayLastAnnounced == line then return end
	hsOverlayLastAnnounced = line
	HSLog("Current: "..currentText.."  Next: "..nextText)
end


function SH_GetDisplaySecondSpell(nextSpell)
	if nextSpell == nil or nextSpell == "" then return nil end

	local formId = GetActiveForm()
	local mode = ShiftyMode or HSMode or "single"
	local cp = HSGetComboPoints() or 0

	-- Moonkin / caster lookahead
	if HS_IsBalanceMode ~= nil and HS_IsBalanceMode() == true then
		local phase = ""
		if type(HS_BALANCE_STATE) == "table" then
			phase = tostring(HS_BALANCE_STATE.phase or "")
		end
		local moonfireUp = HSBalanceDotIsActive ~= nil and HSBalanceDotIsActive("Moonfire") == true
		local insectUp = HSBalanceDotIsActive ~= nil and HSBalanceDotIsActive("Insect Swarm") == true
		local wrathCount = tonumber(hsBalanceLoopWrathCount or 0) or 0
		local starCount = tonumber(hsBalanceLoopStarfireCount or 0) or 0
		local fishTarget = tonumber(hsBalanceFishWrathTarget or 4) or 4
		local arcaneTarget = tonumber(hsBalanceArcaneTarget or 3) or 3

		if nextSpell == "Insect Swarm" then
			if moonfireUp ~= true then return "Moonfire" end
			return "Wrath"
		elseif nextSpell == "Moonfire" then
			if insectUp ~= true then return "Insect Swarm" end
			return "Wrath"
		elseif nextSpell == "Wrath" then
			if phase == "nature_eclipse" then
				return "Wrath"
			end
			if phase == "fish_arcane" and (wrathCount + 1) >= fishTarget then
				return "Starfire"
			end
			return "Wrath"
		elseif nextSpell == "Starfire" then
			if phase == "arcane_eclipse" and (starCount + 1) >= arcaneTarget then
				if moonfireUp ~= true then return "Moonfire" end
				if insectUp ~= true then return "Insect Swarm" end
				return "Wrath"
			end
			if phase == "arcane_eclipse" then
				return "Starfire"
			end
			return "Wrath"
		elseif nextSpell == "Hurricane" then
			return "Hurricane"
		end
		return nil
	end

	-- Bear lookahead
	if formId == 1 then
		if mode == "aoe" then
			if nextSpell == "Swipe" then return "Swipe" end
			if nextSpell == "Demoralizing Roar" then return "Swipe" end
			if nextSpell == "Maul" then return "Swipe" end
		else
			if nextSpell == "Demoralizing Roar" then return "Maul" end
			if nextSpell == "Maul" then return "Maul" end
			if nextSpell == "Faerie Fire (Feral)" then return "Maul" end
		end
		return nil
	end

	-- Cat lookahead
	if UnitPowerType("player") == 3 then
		local fbthresh = 5
		if mode == "aoe" then fbthresh = 4 end

		if nextSpell == "Rake" then
			if cp + 1 >= fbthresh then
				if mode ~= "aoe" then return "Rip" end
				return "Ferocious Bite"
			end
			if BehindTarget ~= nil and BehindTarget() == true then return "Shred" end
			return "Claw"
		elseif nextSpell == "Shred" or nextSpell == "Claw" then
			if cp + 1 >= fbthresh then
				if mode ~= "aoe" then return "Rip" end
				return "Ferocious Bite"
			end
			if nextSpell == "Shred" then return "Shred" end
			return "Claw"
		elseif nextSpell == "Rip" or nextSpell == "Ferocious Bite" then
			return "Rake"
		elseif nextSpell == "Faerie Fire (Feral)" then
			if BehindTarget ~= nil and BehindTarget() == true then return "Shred" end
			return "Claw"
		elseif nextSpell == "Tiger's Fury" then
			return "Rake"
		end
	end

	return nil
end


function HS_UpdateOverlay(forceHide)
	if hsOverlayFrame == nil then return end
	if forceHide == true or ShiftyOverlayEnabled ~= 1 then
		hsOverlayFrame:Hide()
		return
	end

	local nextSpell = HS_GetPredictedSpellName()
	local currentSpell = nextSpell
	local secondSpell = SH_GetDisplaySecondSpell(nextSpell)
	local holdingDisplay = false
	if currentSpell ~= nil and currentSpell ~= "" then
		ShiftyLastDisplaySpell = currentSpell
	else
		currentSpell = ShiftyLastDisplaySpell
		holdingDisplay = (currentSpell ~= nil and currentSpell ~= "")
	end
	if secondSpell ~= nil and secondSpell ~= "" then
		ShiftyLastSecondDisplaySpell = secondSpell
	else
		secondSpell = ShiftyLastSecondDisplaySpell
	end
	if nextSpell == nil and HS_IsBalanceMode() == true then
		nextSpell = HSBalanceGetHeldPrediction()
	end
	HS_PrintOverlayDebug(currentSpell, nextSpell)

	local cooldownSpell = nil
	local cooldownRemaining = 0
	if currentSpell ~= nil and currentSpell ~= "" then
		cooldownRemaining = HS_OverlayGetCooldownRemaining(currentSpell)
		if cooldownRemaining > 0 then
			cooldownSpell = currentSpell
		end
	end

	HS_OverlaySetIcon(hsOverlayFrame.currentIcon, currentSpell)
	HS_OverlaySetIcon(hsOverlayFrame.nextIcon, secondSpell)
	if holdingDisplay == true then
		hsOverlayFrame.currentIcon:SetVertexColor(0.70, 0.70, 0.70)
		hsOverlayFrame.currentIcon:SetAlpha(0.65)
	else
		hsOverlayFrame.currentIcon:SetVertexColor(1, 1, 1)
		hsOverlayFrame.currentIcon:SetAlpha(1.0)
	end
	if secondSpell == nil or secondSpell == "" then
		hsOverlayFrame.nextIcon:SetAlpha(0.55)
	else
		hsOverlayFrame.nextIcon:SetAlpha(1.0)
	end
	if cooldownSpell ~= nil then
		HS_OverlaySetIcon(hsOverlayFrame.cooldownIcon, cooldownSpell)
		hsOverlayFrame.cooldownIcon:Show()
		hsOverlayFrame.cooldownText:SetText(HS_OverlayFormatCooldown(cooldownRemaining))
		hsOverlayFrame.cooldownText:Show()
	else
		hsOverlayFrame.cooldownIcon:Hide()
		hsOverlayFrame.cooldownText:SetText("")
		hsOverlayFrame.cooldownText:Hide()
	end

	local currentText = tostring(currentSpell or "")
	local nextText = tostring(secondSpell or "")
	local cooldownText = tostring(cooldownSpell or "")

	hsOverlayFrame.currentLabel:SetText(currentText)
	hsOverlayFrame.currentLabel:SetTextColor(1, 1, 1)

	hsOverlayFrame.nextLabel:SetText(nextText)
	hsOverlayFrame.nextLabel:SetTextColor(0.55, 0.85, 1.00)

	hsOverlayFrame.cooldownLabel:SetText(cooldownText)
	hsOverlayFrame.cooldownLabel:SetTextColor(1, 1, 1)

	local phaseText, pr, pg, pb = HS_OverlayGetPhaseInfo()
    local hasTarget = UnitExists("target") and (not UnitIsDead("target")) and UnitCanAttack("player", "target")
    if hasTarget then
        hsOverlayFrame.phaseText:SetText(phaseText or "")
        hsOverlayFrame.phaseText:SetTextColor(pr, pg, pb)
        if phaseText ~= nil and phaseText ~= "" then
            hsOverlayFrame.phaseText:Show()
        else
            hsOverlayFrame.phaseText:Hide()
        end
    else
        hsOverlayFrame.phaseText:Hide()
    end

    hsOverlayFrame:Show()
end

function HS_SetOverlayScale(scaleValue)
	local newScale = tonumber(scaleValue)
	if newScale == nil then return false end
	if newScale < 0.5 then newScale = 0.5 end
	if newScale > 3 then newScale = 3 end
	ShiftyOverlayScale = newScale
	if hsOverlayFrame ~= nil then
		hsOverlayFrame:SetScale(ShiftyOverlayScale)
		HS_SaveOverlayPosition()
	end
	local store = HS_GetOverlayStore()
	store.scale = ShiftyOverlayScale
	return true
end

function HS_CreateOverlay()
	if hsOverlayFrame ~= nil then
		hsOverlayFrame:SetScale(ShiftyOverlayScale or 1)
		if ShiftyOverlayEnabled == 1 then hsOverlayFrame:Show() end
		return hsOverlayFrame
	end
	local f = CreateFrame("Frame", "ShiftyOverlayFrame", UIParent)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function() this:StartMoving() end)
	f:SetScript("OnDragStop", function() this:StopMovingOrSizing() HS_SaveOverlayPosition() end)
	f:SetClampedToScreen(true)
	f:SetFrameStrata("HIGH")
	f:SetFrameLevel(20)
		f:SetWidth(250)
	f:SetHeight(150)

	f.cooldownLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	f.cooldownLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -12)
	f.cooldownLabel:SetText("COOLDOWN")

	f.currentLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	f.currentLabel:SetPoint("TOP", f, "TOP", 0, -12)
	f.currentLabel:SetText("CURRENT SPELL")

	f.nextLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	f.nextLabel:SetPoint("TOPRIGHT", f, "TOPRIGHT", -20, -12)
	f.nextLabel:SetText("NEXT SPELL")

	f.cooldownText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	f.cooldownText:SetPoint("BOTTOM", f, "CENTER", -75, 18)
	f.cooldownText:SetText("")

	f.cooldownIcon = f:CreateTexture(nil, "ARTWORK")
	f.cooldownIcon:SetWidth(40)
	f.cooldownIcon:SetHeight(40)
	f.cooldownIcon:SetPoint("TOPLEFT", f, "TOPLEFT", 28, -40)

	f.currentIcon = f:CreateTexture(nil, "ARTWORK")
	f.currentIcon:SetWidth(72)
	f.currentIcon:SetHeight(72)
	f.currentIcon:SetPoint("TOP", f, "TOP", 0, -34)

	f.nextIcon = f:CreateTexture(nil, "ARTWORK")
	f.nextIcon:SetWidth(40)
	f.nextIcon:SetHeight(40)
	f.nextIcon:SetPoint("TOPRIGHT", f, "TOPRIGHT", -28, -40)

	f.phaseText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	f.phaseText:SetPoint("BOTTOM", f, "BOTTOM", 0, 12)
	f.phaseText:SetJustifyH("CENTER")
	f.phaseText:SetText("CAT")

	local store = HS_GetOverlayStore()
	if store.scale ~= nil then ShiftyOverlayScale = store.scale end
	f:SetScale(ShiftyOverlayScale or 1)
	hsOverlayFrame = f
	HS_RestoreOverlayPosition()
	f:SetScript("OnUpdate", function()
		hsOverlayElapsed = hsOverlayElapsed + arg1
		if hsOverlayElapsed >= 0.15 then
			hsOverlayElapsed = 0
			HS_UpdateOverlay(false)
		end
	end)
	if ShiftyOverlayEnabled == 1 then
		f:Show()
		HS_UpdateOverlay(false)
	else
		f:Hide()
	end
	return f
end

function HSSetNotBehindLockout(source)
	doclaw = GetTime() + HS_NOT_BEHIND_LOCKOUT
	HSDebugTrace("DOCLAW_SET", tostring(source or ""))
end

function HSGetTargetKey()
	local name = UnitName("target")
	if name == nil then
		return ""
	end
	return tostring(name)
end

function HSResetDebuffImmunity(targetKey)
	hsDebuffImmune.target = targetKey or HSGetTargetKey()
	hsDebuffImmune.rip = false
	hsDebuffImmune.rake = false
	hsDebuffImmune.ff = false
end

function HSIsDebuffImmune(spellKey)
	local targetKey = HSGetTargetKey()
	if hsDebuffImmune.target ~= targetKey then
		HSResetDebuffImmunity(targetKey)
	end
	return hsDebuffImmune[spellKey] == true
end

function HSMarkDebuffImmune(spellKey, sourceMsg)
	local targetKey = HSGetTargetKey()
	if targetKey == "" then
		return
	end
	if hsDebuffImmune.target ~= targetKey then
		HSResetDebuffImmunity(targetKey)
	end
	if hsDebuffImmune[spellKey] ~= true then
		hsDebuffImmune[spellKey] = true
		HSDebugTrace("IMMUNE_SET", spellKey.." target="..targetKey.." msg="..tostring(sourceMsg))
	end
end

function HSHandleSelfCombatMessage(msg)
	local lower = string.lower(tostring(msg or ""))
	if lower == "" then
		return
	end
	if not strfind(lower, "immune") then
		return
	end
	if strfind(lower, "rip") then
		HSMarkDebuffImmune("rip", msg)
	elseif strfind(lower, "rake") then
		HSMarkDebuffImmune("rake", msg)
	elseif strfind(lower, "faerie fire") then
		HSMarkDebuffImmune("ff", msg)
	end
end


function SH_GetMinimapStore()
	if type(ShiftyDebugLog) ~= "table" then ShiftyDebugLog = {} end
	if type(ShiftyDebugLog._minimap) ~= "table" then
		ShiftyDebugLog._minimap = { angle = 225, hide = 0 }
	end
	return ShiftyDebugLog._minimap
end

function SH_UpdateMinimapPosition()
	if ShiftyMinimapButton == nil then return end
	local store = SH_GetMinimapStore()
	local angle = tonumber(store.angle or 225) or 225
	local rad = math.rad(angle)
	local radius = 78
	local x = math.cos(rad) * radius
	local y = math.sin(rad) * radius
	ShiftyMinimapButton:ClearAllPoints()
	ShiftyMinimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function SH_CreateMinimapButton()
	if ShiftyMinimapButton ~= nil then
		SH_UpdateMinimapPosition()
		if SH_GetMinimapStore().hide == 1 then
			ShiftyMinimapButton:Hide()
		else
			ShiftyMinimapButton:Show()
		end
		return ShiftyMinimapButton
	end

	local b = CreateFrame("Button", "ShiftyMinimapButton", Minimap)
	b:SetWidth(32)
	b:SetHeight(32)
	b:SetFrameStrata("MEDIUM")
	b:SetMovable(true)
	b:EnableMouse(true)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:RegisterForDrag("LeftButton")

	b.icon = b:CreateTexture(nil, "BACKGROUND")
	b.icon:SetWidth(20)
	b.icon:SetHeight(20)
	b.icon:SetPoint("CENTER", b, "CENTER", 0, 0)
	b.icon:SetTexture("Interface\\Icons\\Ability_Druid_CatForm")

	b.border = b:CreateTexture(nil, "OVERLAY")
	b.border:SetWidth(52)
	b.border:SetHeight(52)
	b.border:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
	b.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

	b:SetScript("OnDragStart", function() this.dragging = 1 end)
	b:SetScript("OnDragStop", function() this.dragging = nil end)
	b:SetScript("OnUpdate", function()
		if this.dragging then
			local mx, my = GetCursorPosition()
			local scale = Minimap:GetEffectiveScale()
			mx = mx / scale
			my = my / scale
			local cx, cy = Minimap:GetCenter()
			local angle = math.deg(math.atan2(my - cy, mx - cx))
			SH_GetMinimapStore().angle = angle
			SH_UpdateMinimapPosition()
		end
	end)
	b:SetScript("OnClick", function()
		if arg1 == "LeftButton" and IsShiftKeyDown() then
			local store = HS_GetOverlayStore()
			store.point = "CENTER"
			store.relativePoint = "CENTER"
			store.x = 0
			store.y = 160
			HS_RestoreOverlayPosition()
			HS_UpdateOverlay(false)
			HSPrint("|cffd08524Shifty |cffffffffOverlay position |cff24D040Reset")
		elseif arg1 == "LeftButton" then
			if ShiftyOverlayEnabled == 1 then
				ShiftyOverlayEnabled = 0
				HS_UpdateOverlay(true)
				HSPrint("|cffd08524Shifty |cffffffffOverlay |cffD02424Disabled")
			else
				ShiftyOverlayEnabled = 1
				HS_CreateOverlay()
				HS_UpdateOverlay(false)
				HSPrint("|cffd08524Shifty |cffffffffOverlay |cff24D040Enabled")
			end
		elseif arg1 == "RightButton" and IsShiftKeyDown() then
			HS_CreateOverlay()
			HS_UpdateOverlay(false)
			HSPrint("|cffd08524Shifty |cffffffffOverlay |cffecd226Refreshed")
		else
			if type(SH_OpenSettings) == "function" then
				SH_OpenSettings()
			elseif type(Shifty_OpenSettings) == "function" then
				Shifty_OpenSettings()
			elseif type(SH_ToggleSettings) == "function" then
				SH_ToggleSettings()
			elseif type(Shifty_ToggleSettings) == "function" then
				Shifty_ToggleSettings()
			else
				HSPrint("|cffd08524Shifty |cffffffffSettings command: |cffecd226/shifty config")
			end
		end
	end)
	b:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_LEFT")
		GameTooltip:AddLine("Shifty")
		GameTooltip:AddLine("Left-click: Toggle overlay", 1, 1, 1)
		GameTooltip:AddLine("Right-click: Open settings", 1, 1, 1)
		GameTooltip:AddLine("Shift+Left-click: Reset overlay position", 1, 1, 1)
		GameTooltip:AddLine("Shift+Right-click: Refresh overlay", 1, 1, 1)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)

	ShiftyMinimapButton = b
	SH_UpdateMinimapPosition()
	if SH_GetMinimapStore().hide == 1 then
		b:Hide()
	else
		b:Show()
	end
	return b
end



function SH_GetSettingsStore()
	if type(ShiftyDebugLog) ~= "table" then ShiftyDebugLog = {} end
	if type(ShiftyDebugLog._settings) ~= "table" then
		ShiftyDebugLog._settings = {}
	end
	return ShiftyDebugLog._settings
end

function SH_CreateSettingsFrame()
	if ShiftySettingsFrame ~= nil then return ShiftySettingsFrame end

	local f = CreateFrame("Frame", "ShiftySettingsFrame", UIParent)
	f:SetWidth(320)
	f:SetHeight(260)
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	f:SetFrameStrata("DIALOG")
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function() this:StartMoving() end)
	f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
	f:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 }
	})
	f:SetBackdropColor(0, 0, 0, 0.9)
	f:Hide()

	f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	f.title:SetPoint("TOP", f, "TOP", 0, -12)
	f.title:SetText("Shifty Settings")

	f.subtitle = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	f.subtitle:SetPoint("TOP", f.title, "BOTTOM", 0, -6)
	f.subtitle:SetText("Druid rotation and buff helper")

	local function MakeCheckbox(name, label, x, y, checkedFunc, onClickFunc)
		local cb = CreateFrame("CheckButton", name, f, "UICheckButtonTemplate")
		cb:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
		getglobal(name .. "Text"):SetText(label)
		cb:SetScript("OnShow", function()
			if checkedFunc() then this:SetChecked(1) else this:SetChecked(nil) end
		end)
		cb:SetScript("OnClick", function()
			onClickFunc(this:GetChecked() == 1)
		end)
		return cb
	end

	f.overlayCB = MakeCheckbox("ShiftySettingsOverlayCB", "Overlay enabled", 18, -44,
		function() return ShiftyOverlayEnabled == 1 end,
		function(v)
			if v then ShiftyOverlayEnabled = 1 else ShiftyOverlayEnabled = 0 end
			HS_CreateOverlay()
			HS_UpdateOverlay(ShiftyOverlayEnabled ~= 1)
		end
	)

	f.debugCB = MakeCheckbox("ShiftySettingsDebugCB", "Debug enabled", 18, -72,
		function() return ShiftyDebugEnabled == 1 end,
		function(v)
			if v then ShiftyDebugEnabled = 1 else ShiftyDebugEnabled = 0 end
		end
	)

	f.persistCB = MakeCheckbox("ShiftySettingsPersistCB", "Persistent log enabled", 18, -100,
		function() return HS_IsPersistentLogEnabled() == true end,
		function(v)
			HS_SetPersistentLogEnabled(v)
		end
	)

	f.catLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	f.catLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -136)
	f.catLabel:SetText("Quick actions")

	local function MakeButton(name, text, x, y, onClick)
		local b = CreateFrame("Button", name, f, "UIPanelButtonTemplate")
		b:SetWidth(130)
		b:SetHeight(22)
		b:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
		b:SetText(text)
		b:SetScript("OnClick", onClick)
		return b
	end

	f.singleBtn = MakeButton("ShiftySettingsSingleBtn", "Set Single Target", 18, -156, function()
		ShiftyMode = "single"
		HSMode = "single"
		HSPrint("|cffd08524Shifty |cffffffffMode set to |cffecd226single")
	end)

	f.aoeBtn = MakeButton("ShiftySettingsAOEBtn", "Set AOE", 160, -156, function()
		ShiftyMode = "aoe"
		HSMode = "aoe"
		HSPrint("|cffd08524Shifty |cffffffffMode set to |cffecd226aoe")
	end)

	f.resetBtn = MakeButton("ShiftySettingsResetBtn", "Reset Overlay", 18, -186, function()
		local store = HS_GetOverlayStore()
		store.point = "CENTER"
		store.relativePoint = "CENTER"
		store.x = 0
		store.y = 160
		HS_RestoreOverlayPosition()
		HS_UpdateOverlay(false)
		HSPrint("|cffd08524Shifty |cffffffffOverlay position |cff24D040Reset")
	end)

	f.clearBtn = MakeButton("ShiftySettingsClearBtn", "Clear Logs", 160, -186, function()
		SH_AllLogsClear()
		HSPrint("|cffd08524Shifty |cffffffffLogs |cff24D040Cleared")
	end)

	f.closeBtn = MakeButton("ShiftySettingsCloseBtn", "Close", 95, -220, function()
		f:Hide()
	end)
	f.closeBtn:SetWidth(120)

	ShiftySettingsFrame = f
	return f
end

function SH_OpenSettings()
	local f = SH_CreateSettingsFrame()
	f:Show()
end

function SH_ToggleSettings()
	local f = SH_CreateSettingsFrame()
	if f:IsShown() then
		f:Hide()
	else
		f:Show()
	end
end


function Shifty_OnLoad()
    if UnitClass("player") == "Druid" then
        this:RegisterEvent("PLAYER_ENTERING_WORLD")
        this:RegisterEvent("PLAYER_REGEN_ENABLED")
		this:RegisterEvent("PLAYER_REGEN_DISABLED")
        this:RegisterEvent("VARIABLES_LOADED")
        this:RegisterEvent("CHAT_MSG_COMBAT_SELF_MISSES")
        this:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")
        this:RegisterEvent("CHAT_MSG_SPELL_SELF_CAST")
        this:RegisterEvent("CHAT_MSG_SPELL_SELF_BUFF")
        this:RegisterEvent("CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES")
        this:RegisterEvent("CHAT_MSG_MONSTER_YELL")
		this:RegisterEvent("SPELL_FAILED_NOT_BEHIND")
		this:RegisterEvent("UI_ERROR_MESSAGE")
		this:RegisterEvent("PLAYER_TARGET_CHANGED")
    end

	SlashCmdList["SHIFTY"] = Shifty_SlashCommand;
	SLASH_SHIFTY1 = "/shifty";
end

function Shifty_SlashCommand(msg)
	local _,_, command, option = string.find(msg or "", "([%w%p]+)%s*(.*)$")
	command = string.lower(tostring(command or ""))
	option = tostring(option or "")

	if command == "single" then
		ShiftyMode = "single"
		ShiftyAddon()
		return
	elseif command == "aoe" then
		ShiftyMode = "aoe"
		ShiftyAddon()
		return
	elseif command == "debug" then
		local _,_, dbgSub, dbgArg = string.find(option, "([%w%p]+)%s*(.*)$")
		dbgSub = string.lower(tostring(dbgSub or option or ""))
		dbgArg = tostring(dbgArg or "")
		if option == "on" then
			ShiftyDebugEnabled = 1
			HSPrint('|cffd08524Shifty |cffffffffDebug logging |cff24D040Enabled')
		elseif option == "off" then
			ShiftyDebugEnabled = 0
			HSPrint('|cffd08524Shifty |cffffffffDebug logging |cffD02424Disabled')
		elseif option == "clear" then
			ShiftyDebugLog = {}
			HSPrint('|cffd08524Shifty |cffffffffDebug log cleared')
		elseif dbgSub == "show" then
			HSDebugDump(dbgArg)
		elseif option == "status" or option == "" then
			if ShiftyDebugEnabled == 1 then
				HSPrint('|cffd08524Shifty |cffffffffDebug logging: |cff24D040ON')
			else
				HSPrint('|cffd08524Shifty |cffffffffDebug logging: |cffD02424OFF')
			end
			if ShiftyDebugLog == nil then
				ShiftyDebugLog = {}
			end
			HSPrint('|cffd08524Shifty |cffffffffDebug lines stored: |cffecd226'..table.getn(ShiftyDebugLog))
			HSPrint('|cffd08524Shifty |cffffffffUsage: |cffecd226/shifty debug on|off|show 50|clear')
		else
			HSPrint('|cffd08524Shifty |cffffffffDebug usage: |cffecd226/shifty debug on|off|show 50|clear')
		end
		return
	elseif command == "overlay" then
		local _,_, overlaySub, overlayArg = string.find(option, "([%w%p]+)%s*(.*)$")
		overlaySub = string.lower(tostring(overlaySub or option or ""))
		overlayArg = tostring(overlayArg or "")
		if option == "on" then
			ShiftyOverlayEnabled = 1
			HS_CreateOverlay()
			HS_UpdateOverlay(false)
			SH_CreateMinimapButton()
			HSPrint('|cffd08524Shifty |cffffffffOverlay |cff24D040Enabled')
		elseif option == "off" then
			ShiftyOverlayEnabled = 0
			HS_UpdateOverlay(true)
			HSPrint('|cffd08524Shifty |cffffffffOverlay |cffD02424Disabled')
		elseif option == "toggle" then
			if ShiftyOverlayEnabled == 1 then ShiftyOverlayEnabled = 0 else ShiftyOverlayEnabled = 1 end
			HS_CreateOverlay()
			HS_UpdateOverlay(ShiftyOverlayEnabled ~= 1)
			if ShiftyOverlayEnabled == 1 then
				HSPrint('|cffd08524Shifty |cffffffffOverlay |cff24D040Enabled')
			else
				HSPrint('|cffd08524Shifty |cffffffffOverlay |cffD02424Disabled')
			end
		elseif overlaySub == "scale" then
			if HS_SetOverlayScale(overlayArg) then
				HS_CreateOverlay()
				HS_UpdateOverlay(false)
				HSPrint('|cffd08524Shifty |cffffffffOverlay scale set to |cffecd226'..ShiftyOverlayScale)
			else
				HSPrint('|cffd08524Shifty |cffffffffOverlay scale usage: |cffecd226/shifty overlay scale 1.25')
			end
		elseif overlaySub == "debug" then
			if overlayArg == "on" then
				HS_SetOverlayDebugEnabled(true)
				HS_SetOverlayDebugQuiet(true)
				hsOverlayLastAnnounced = nil
				HSPrint('|cffd08524Shifty |cffffffffOverlay debug |cff24D040Enabled')
				HS_PrintOverlayDebug(HS_GetCurrentCastSpellName() or ShiftyLastCastSpell or ShiftyLastSpell, HS_GetPredictedSpellName())
			elseif overlayArg == "off" then
				HS_SetOverlayDebugEnabled(false)
				HSPrint('|cffd08524Shifty |cffffffffOverlay debug |cffD02424Disabled')
			elseif overlayArg == "quiet on" then
				HS_SetOverlayDebugQuiet(true)
				HSPrint('|cffd08524Shifty |cffffffffOverlay debug quiet mode |cff24D040Enabled')
			elseif overlayArg == "quiet off" then
				HS_SetOverlayDebugQuiet(false)
				HSPrint('|cffd08524Shifty |cffffffffOverlay debug quiet mode |cffD02424Disabled')
			elseif overlayArg == "status" or overlayArg == "" then
				if HS_IsOverlayDebugEnabled() == true then
					HSPrint('|cffd08524Shifty |cffffffffOverlay debug: |cff24D040ON')
				else
					HSPrint('|cffd08524Shifty |cffffffffOverlay debug: |cffD02424OFF')
				end
				HSPrint('|cffd08524Shifty |cffffffffOverlay debug quiet: '..(HS_IsOverlayDebugQuiet() == true and '|cff24D040ON' or '|cffD02424OFF'))
				HS_PrintOverlayDebug(HS_GetCurrentCastSpellName() or ShiftyLastCastSpell or ShiftyLastSpell, HS_GetPredictedSpellName())
			else
				HSPrint('|cffd08524Shifty |cffffffffOverlay debug usage: |cffecd226/shifty overlay debug on|off|status|quiet on|quiet off')
			end
		elseif option == "show" or option == "status" or option == "" then
			local predicted = HS_GetPredictedSpellName()
			HS_CreateOverlay()
			HS_UpdateOverlay(false)
			SH_CreateMinimapButton()
			HSPrint('|cffd08524Shifty |cffffffffOverlay status: '..(ShiftyOverlayEnabled == 1 and '|cff24D040ON' or '|cffD02424OFF')..' |cffffffffScale: |cffecd226'..tostring(ShiftyOverlayScale or 1))
			if predicted ~= nil then
				HSPrint('|cffd08524Shifty |cffffffffPredicted spell: |cffecd226'..predicted)
			else
				HSPrint('|cffd08524Shifty |cffffffffPredicted spell: |cffecd226(none)')
			end
		else
			HSPrint('|cffd08524Shifty |cffffffffOverlay usage: |cffecd226/shifty overlay on|off|toggle|show|scale 1.25|debug on|off|status|quiet on|quiet off')
		end
		return
	elseif command == "config" or command == "settings" then
		SH_OpenSettings()
		return
	elseif command == "help" or command == "" then
		HSPrint('---------------------')
		HSPrint('|cffd08524Shifty: |cffffffffUse |cffecd226/shifty single |cfffffffffor single target or |cffecd226/shifty aoe |cfffffffffor aoe.')
		HSPrint('|cffd08524Shifty: |cffffffffUse |cffecd226/shifty overlay on|off|show|scale 1.25|debug on |cfffffffffor the floating next-spell display.')
		HSPrint('|cffd08524Shifty: |cffffffffUse |cffecd226/shifty debug on|off|status|show 50|clear |cfffffffffor debug logging.')
		HSPrint('|cffd08524Shifty: |cffffffffUse |cffecd226/shifty config |cffffffffto open settings.')
		return
	end

	HSPrint('|cffd08524Shifty |cffffffffUnknown command. Use |cffecd226/shifty help')
end

function Shifty_OnEvent(event)
	if event == "PLAYER_ENTERING_WORLD" then
		if ShiftyOverlayEnabled == 1 then
			HS_CreateOverlay()
			HS_UpdateOverlay(false)
		end
		SH_CreateMinimapButton()
	end
	if event == "PLAYER_TARGET_CHANGED" then
		doclaw = 0
		HSResetDebuffImmunity(HSGetTargetKey())
		HS_BALANCE_AOE_PRECASTS = 0
		hsBalanceLastPredictedSpell = nil
		hsBalanceLastPredictedAt = 0
  		hsBalanceDotAppliedAt["Moonfire"] = 0
		hsBalanceDotAppliedAt["Insect Swarm"] = 0
		hsBalanceDotPendingUntil["Moonfire"] = 0
		hsBalanceDotPendingUntil["Insect Swarm"] = 0
		hsBalanceDotPendingUntil["Moonfire"] = 0
		hsBalanceDotPendingUntil["Insect Swarm"] = 0
		hsBalanceClearcastingUntil = 0
		hsBalanceAstralBoonUntil = 0
		hsBalanceNaturalBoonUntil = 0
		hsBalanceLastProcLine = ""
		hsBalanceLastProcReason = nil
		hsBalanceWrathStreak = 0
		hsBalanceArcaneChainUntil = 0
		hsBalanceWrathStreak = 0
		if HSBalanceArcaneActive() ~= true and HSBalanceNatureActive() ~= true then
			HSBalanceSetPhase("fish_arcane")
		end
		if UnitExists("target") ~= 1 then
			hsBalanceOpened = false
			hsBalanceOpenerPendingSpell = nil
			hsBalanceOpenerPendingUntil = 0
		end
		HSBalanceResetOpenerState()
	HSBalanceResetDotLocks()
	HSDebugTrace("TARGET_CHANGED", "")
		HS_UpdateOverlay(false)
	end

	if event == "PLAYER_REGEN_DISABLED" then
		hsCombatStartAt = GetTime()
		hsBalanceOpened = false
		hsBalanceOpenerPendingSpell = nil
		hsBalanceOpenerPendingUntil = 0
		HSDebugTrace("COMBAT_START", "")
		curtime = GetTime()
		combstarttime = GetTime()
		temptime = GetTime()
		mobcurhealth = UnitHealth('target')
	end

	if event == "PLAYER_REGEN_ENABLED" then
		hsCombatStartAt = 0
		hsBalanceOpened = false
		hsBalanceOpenerPendingSpell = nil
		hsBalanceOpenerPendingUntil = 0
		hsBalancePreArcaneHoldUntil = 0
	hsBalanceArcaneEntryLockUntil = 0
	hsBalanceArcaneFlushUntil = 0
	HSDebugTrace("COMBAT_END", "")
		HS_BALANCE_AOE_PRECASTS = 0
		hsBalanceLastPredictedSpell = nil
		hsBalanceLastPredictedAt = 0
  		hsBalanceDotAppliedAt["Moonfire"] = 0
		hsBalanceDotAppliedAt["Insect Swarm"] = 0
		hsBalanceDotPendingUntil["Moonfire"] = 0
		hsBalanceDotPendingUntil["Insect Swarm"] = 0
		hsBalanceDotPendingUntil["Moonfire"] = 0
		hsBalanceDotPendingUntil["Insect Swarm"] = 0
		hsBalanceClearcastingUntil = 0
		hsBalanceAstralBoonUntil = 0
		hsBalanceNaturalBoonUntil = 0
		hsBalanceLastProcLine = ""
		hsBalanceLastProcReason = nil
		hsBalanceWrathStreak = 0
		hsBalanceArcaneChainUntil = 0
		HS_BALANCE_STATE.arcaneUntil = 0
		HS_BALANCE_STATE.natureUntil = 0
		HSBalanceSetPhase("fish_arcane")
		if HSDeathrate == 1 then
			DeathRate()
		end
		if reportthreshold ~= 80 then
			reportthreshold = 80
		end
		if mobcurhealth ~= 100 then
			mobcurhealth = 100
		end 
		if curtime ~= nil then
			curtime = nil
		end
		if temptime ~= nil then
			temptime = nil
		end
		if doclaw ~= 0 then
			doclaw = 0
		end
		HS_UpdateOverlay(false)
	end

	if event == "UI_ERROR_MESSAGE" then
		HSDebugTrace("UI_ERROR", tostring(arg1))
		local uiErr = string.lower(tostring(arg1 or ""))
		if strfind(uiErr, "must be") and strfind(uiErr, "behind") then
			HSSetNotBehindLockout("from UI_ERROR not behind")
		end
		if (strfind(tostring(arg1), "No charges remain")) then
			SwapOutMCP(HSWeapon,HSOffhand)
		end
	end
	if event == "SPELL_FAILED_NOT_BEHIND" then
		HSDebugTrace("SPELL_FAILED_NOT_BEHIND", tostring(arg1))
		HSSetNotBehindLockout("from SPELL_FAILED_NOT_BEHIND")
	end
	if event == "CHAT_MSG_COMBAT_SELF_MISSES" then
		HSDebugTrace("COMBAT_SELF_MISSES", tostring(arg1))
		HSHandleSelfCombatMessage(arg1)
	end
 	if event == "CHAT_MSG_SPELL_SELF_DAMAGE" then
		HSDebugTrace("SPELL_SELF_DAMAGE", tostring(arg1))
		if HS_IsBalanceMode() == true then HSBalanceLog("spell_self_damage="..tostring(arg1)) end
		HSBalanceDebugProc(arg1)
		if strfind(tostring(arg1), "Moonfire") then HSBalanceConfirmDotApplied("Moonfire") end
		if strfind(tostring(arg1), "Insect Swarm") then HSBalanceConfirmDotApplied("Insect Swarm") end
		local dmgmsg = tostring(arg1)
		if strfind(dmgmsg, "Your Moonfire") or strfind(dmgmsg, "Your Insect Swarm") or strfind(dmgmsg, "Your Wrath") or strfind(dmgmsg, "Your Starfire") then
			hsBalanceOpened = true
			hsBalanceOpenerPendingSpell = nil
			hsBalanceOpenerPendingUntil = 0
		end
		local starfireLanded = strfind(dmgmsg, "Your Starfire hits") or strfind(dmgmsg, "Your Starfire crits")
		local wrathLanded = strfind(dmgmsg, "Your Wrath hits") or strfind(dmgmsg, "Your Wrath crits")
		if starfireLanded then
			hsBalanceLoopStarfireCount = (hsBalanceLoopStarfireCount or 0) + 1
			HSDebugTrace("BALANCE_ARCANE_CHAIN", "Starfire landed")
			HSBalanceLog("counter=starfire value="..tostring(hsBalanceLoopStarfireCount))
			if HS_BALANCE_STATE.phase == "arcane_eclipse" and hsBalanceLoopStarfireCount >= hsBalanceArcaneTarget then
				HSBalanceSetPhase("snapshot")
				HSBalanceLog("phase_shift=snapshot reason=starfire_target")
			end
		end
		if wrathLanded then
			hsBalanceLoopWrathCount = (hsBalanceLoopWrathCount or 0) + 1
			HSBalanceLog("counter=wrath value="..tostring(hsBalanceLoopWrathCount))
			if HS_BALANCE_STATE.phase == "nature_eclipse" and hsBalanceLoopWrathCount >= hsBalanceNatureTarget then
				hsBalanceLoopWrathCount = 0
				hsBalanceLoopStarfireCount = 0
				HSBalanceSetPhase("fish_arcane")
				HSBalanceLog("phase_shift=fish_arcane reason=nature_target")
			end
		end
		if strfind(tostring(arg1), "Your Moonfire") then
			HSBalanceConfirmDotApplied("Moonfire")
		elseif strfind(tostring(arg1), "Your Insect Swarm") then
			HSBalanceConfirmDotApplied("Insect Swarm")
		end
		HSHandleSelfCombatMessage(arg1)
		if (strfind(tostring(arg1), "Your Shred")) then
			if doclaw ~= 0 then
				doclaw = 0
				HSDebugTrace("DOCLAW_CLEAR", "successful shred")
			end
		end
	end
	if event == "CHAT_MSG_SPELL_SELF_CAST" then
		if HS_IsBalanceMode() == true then
			HSBalanceLog("spell_self_cast="..tostring(arg1))
			HSBalanceDebugProc(arg1)
		end
	end
	if event == "CHAT_MSG_SPELL_SELF_BUFF" then
		HSDebugTrace("SPELL_SELF_BUFF", tostring(arg1))
		HSBalanceLog("spell_self_buff="..tostring(arg1))
		HSBalanceDebugProc(arg1)
		if strfind(tostring(arg1), "Moonfire") then HSBalanceConfirmDotApplied("Moonfire") end
		if strfind(tostring(arg1), "Insect Swarm") then HSBalanceConfirmDotApplied("Insect Swarm") end
		if strfind(tostring(arg1), "Cat Form") then
			HSDebugTrace("SHIFT_SUCCESS", "Cat Form applied")
		elseif strfind(tostring(arg1), "Reshift") then
			HSDebugTrace("SHIFT_SUCCESS", "Reshift applied")
		elseif strfind(tostring(arg1), "Furor") then
			HSDebugTrace("SHIFT_SUCCESS", "Furor energy gain")
		end
		if HSBalanceHasBuffText(arg1, "Arcane Eclipse") == true then
			HS_BALANCE_STATE.arcaneUntil = GetTime() + 15
			HS_BALANCE_STATE.natureUntil = 0
			HS_BALANCE_STATE.lastEclipse = "arcane"
			HSBalanceSetPhase("arcane_eclipse")
			HSBalanceLog("event=Arcane Eclipse gained")
			HSDebugTrace("BALANCE_ECLIPSE", "Arcane Eclipse gained")
		elseif HSBalanceHasBuffText(arg1, "Nature Eclipse") == true then
			HS_BALANCE_STATE.natureUntil = GetTime() + 15
			HS_BALANCE_STATE.arcaneUntil = 0
			HS_BALANCE_STATE.lastEclipse = "nature"
			HSBalanceSetPhase("nature_eclipse")
			HS_BALANCE_AOE_PRECASTS = 0
			HSBalanceLog("event=Nature Eclipse gained")
			HSDebugTrace("BALANCE_ECLIPSE", "Nature Eclipse gained")
		elseif HSBalanceHasBuffText(arg1, "Astral Boon") == true then
			hsBalanceAstralBoonUntil = GetTime() + 4
			HSBalanceLog("event=Astral Boon gained")
			HSDebugTrace("BALANCE_BOON", "Astral Boon")
		elseif HSBalanceHasBuffText(arg1, "Natural Boon") == true then
			hsBalanceNaturalBoonUntil = GetTime() + 4
			HSBalanceLog("event=Natural Boon gained")
			HSDebugTrace("BALANCE_BOON", "Natural Boon")
		end
		HS_UpdateOverlay(false)
	end

	if event == "VARIABLES_LOADED" then
		HSPrint('|cffd08524Shifty |cffffffffLoaded')
		HSPrint('|cffd08524Shifty: |cffffffffType |cffecd226/shifty |cffffffffto show options')

		if UnitClass("player") == "Druid" then
			hsSpellKnownCache = {}
			hsSpellIndexCache = {}
			hsReshiftChecked = false
			hsHasReshift = false

			if ShiftyDebugLog == nil or type(ShiftyDebugLog) ~= "table" then ShiftyDebugLog = {} end
			if type(ShiftyDebugLog.session) ~= "table" then ShiftyDebugLog.session = {} end
			if type(ShiftyDebugLog._persist) ~= "table" then ShiftyDebugLog._persist = {} end
			if ShiftyDebugLog._persist_enabled == nil then ShiftyDebugLog._persist_enabled = 1 end
			if type(ShiftyDebugLog._overlay) ~= "table" then
				ShiftyDebugLog._overlay = {
					x = 0,
					y = 160,
					point = "CENTER",
					relativePoint = "CENTER",
					locked = 0,
					debug_quiet = 1,
				}
			end

			if ShiftyDebugEnabled == nil then ShiftyDebugEnabled = 1 end
			if ShiftyMode == nil or ShiftyMode == "" then ShiftyMode = "single" end
			if ShiftyOverlayEnabled == nil then ShiftyOverlayEnabled = 1 end
			if ShiftyOverlayScale == nil then ShiftyOverlayScale = 1 end

			HSMode = ShiftyMode
			ShiftyLastSpell = nil
			ShiftyLastCastSpell = nil
			ShiftyLastDisplaySpell = nil
			ShiftyLastSecondDisplaySpell = nil
			ShiftyTooltipSpellID = nil
			HS_BALANCE_AOE_PRECASTS = 0
			hsBalanceLastPredictedSpell = nil
			hsBalanceLastPredictedAt = 0
			hsBalanceDotAppliedAt["Moonfire"] = 0
			hsBalanceDotAppliedAt["Insect Swarm"] = 0
			hsBalanceClearcastingUntil = 0
			hsBalanceAstralBoonUntil = 0
			hsBalanceNaturalBoonUntil = 0
			hsBalanceLastProcLine = ""
			hsBalanceLastProcReason = nil
			hsBalanceWrathStreak = 0
			hsBalanceArcaneChainUntil = 0
			HS_BALANCE_STATE.phase = "fish_arcane"
			HS_BALANCE_STATE.arcaneUntil = 0
			HS_BALANCE_STATE.natureUntil = 0
			HS_BALANCE_STATE.lastEclipse = ""

			HS_CreateOverlay()
			HS_UpdateOverlay(false)
			SH_CreateMinimapButton()
		end
	end
end


function HSPrint(msg)
	if (not DEFAULT_CHAT_FRAME) then return end
	DEFAULT_CHAT_FRAME:AddMessage((msg))
end

function HSGetComboPoints()
	local cp = GetComboPoints("player","target")
	if cp == nil then cp = GetComboPoints() end
	if cp == nil then cp = 0 end
	return cp
end

function HSDebugTrace(tag, detail)
	if ShiftyDebugEnabled ~= 1 then return end
	if ShiftyDebugLog == nil then ShiftyDebugLog = {} end
	local target = UnitName("target")
	if target == nil then target = "none" end
	local energy = UnitMana("player")
	if energy == nil then energy = -1 end
	local cp = HSGetComboPoints()
	local behind = 0
	if BehindTarget ~= nil and BehindTarget() == true then behind = 1 end
	local rip = 0
	if HasRip ~= nil and HasRip() == true then rip = 1 end
	local rake = 0
	if HasRake ~= nil and HasRake() == true then rake = 1 end
	local ts = date("%H:%M:%S")
	local line = "["..ts.."] "..tag.." E="..energy.." CP="..cp.." B="..behind.." Rip="..rip.." Rake="..rake.." doclaw="..tostring(doclaw).." T="..target
	if detail ~= nil and detail ~= "" then line = line.." | "..detail end
	table.insert(ShiftyDebugLog, line)
	while table.getn(ShiftyDebugLog) > HS_DEBUG_LOG_MAX do
		table.remove(ShiftyDebugLog, 1)
	end
end

function HSOverlayDebugPrint(currentSpell, nextSpell)
	if HSOverlayDebug ~= 1 then return end
	if hsOverlayFrame == nil then return end
	local now = GetTime()
	if hsOverlayFrame.lastDebugPrint ~= nil and (now - hsOverlayFrame.lastDebugPrint) < 0.75 then
		return
	end
	hsOverlayFrame.lastDebugPrint = now
	local cur = currentSpell or HS_GetLastSpellName() or "none"
	local nxt = nextSpell or HS_GetNextSpellName() or "none"
	HSPrint("|cffd08524Shifty |cffffffffCurrent: |cffecd226"..tostring(cur).." |cffffffffNext: |cffecd226"..tostring(nxt))
end

function HSDebugDump(limit)
	if ShiftyDebugLog == nil then ShiftyDebugLog = {} end
	local num = tonumber(limit)
	if num == nil or num < 1 then num = 30 end
	if num > HS_DEBUG_LOG_MAX then num = HS_DEBUG_LOG_MAX end
	local total = table.getn(ShiftyDebugLog)
	if total == 0 then
		HSPrint('|cffd08524Shifty |cffffffffDebug log is empty')
		return
	end
	local start = total - num + 1
	if start < 1 then start = 1 end
	HSPrint('|cffd08524Shifty |cffffffffDebug dump ('..start..'-'..total..' of '..total..')')
	for i = start, total do HSPrint(ShiftyDebugLog[i]) end
end

function HSGetDruidMana()
	if hsManaLibChecked == false then
		hsManaLibChecked = true
		if DruidManaLib ~= nil and type(DruidManaLib.GetMana) == "function" then
			hsManaLib = DruidManaLib
		elseif type(AceLibrary) == "function" then
			local ok, lib = pcall(AceLibrary, "DruidManaLib-1.0")
			if ok and lib ~= nil and type(lib.GetMana) == "function" then hsManaLib = lib end
		end
	end
	if hsManaLib ~= nil then
		local ok, currentMana, maxMana = pcall(hsManaLib.GetMana, hsManaLib)
		if ok and type(currentMana) == "number" and type(maxMana) == "number" then
			return currentMana, maxMana, true
		end
	end
	return UnitMana('player'), UnitManaMax('player'), false
end

function EShift()
	local a,c=GetActiveForm()
	if(a==0) then
		CastShapeshiftForm(c)
	elseif(not IsSpellOnCD('Cat Form')) then
		CastShapeshiftForm(a)
		ToggleAutoAttack("off")
	end
end

function HSHasSpell(spellName)
	if hsSpellKnownCache[spellName] ~= nil then return hsSpellKnownCache[spellName] == 1 end
	for i = 1, 400 do
		local name = GetSpellName(i, "spell")
		if name == nil then break end
		if name == spellName then hsSpellKnownCache[spellName] = 1 return true end
	end
	hsSpellKnownCache[spellName] = 0
	return false
end

function HSGetSpellIndex(spellName)
	if hsSpellIndexCache[spellName] ~= nil then
		if hsSpellIndexCache[spellName] > 0 then return hsSpellIndexCache[spellName] end
		return nil
	end
	for i = 1, 400 do
		local name = GetSpellName(i, "spell")
		if name == nil then break end
		if name == spellName then hsSpellIndexCache[spellName] = i return i end
	end
	hsSpellIndexCache[spellName] = -1
	return nil
end

function HSIsSpellReady(spellName)
	local spellIndex = HSGetSpellIndex(spellName)
	if spellIndex == nil then return false end
	local start, duration, _ = GetSpellCooldown(spellIndex, "spell")
	local cdLeft = start + duration - GetTime()
	return cdLeft < 0.1
end

function HSCastSpellByIndex(spellName)
	local spellIndex = HSGetSpellIndex(spellName)
	if spellIndex == nil then return false end
	CastSpell(spellIndex, "spell")
	return true
end

function HSTryShift(contextTag)
	if HSShiftUse ~= 1 then return false end
	if GetTime() - hsLastShiftAttempt < HS_SHIFT_RETRY_GAP then
		HSDebugTrace("SHIFT_SKIP", "throttled "..tostring(contextTag))
		return false
	end
	hsLastShiftAttempt = GetTime()
	if hsReshiftChecked == false then
		hsHasReshift = HSHasSpell("Reshift")
		hsReshiftChecked = true
		if hsHasReshift == true then
			HSDebugTrace("RESHIFT", "detected in spellbook")
		else
			HSDebugTrace("RESHIFT", "not found; fallback to Cat Form shift")
		end
	end
	if hsHasReshift == true then
		if HSIsSpellReady("Reshift") == true then
			HSDebugTrace("SHIFT", "Reshift "..tostring(contextTag))
			HSCastSpellByIndex("Reshift")
			return true
		end
		if IsSpellOnCD("Cat Form") then
			HSDebugTrace("SHIFT_WAIT", "Reshift/Cat cooldown "..tostring(contextTag))
			return false
		end
		HSDebugTrace("SHIFT", "EShift fallback "..tostring(contextTag))
		EShift()
		return true
	else
		if IsSpellOnCD("Cat Form") then
			HSDebugTrace("SHIFT_WAIT", "Cat Form cooldown "..tostring(contextTag))
			return false
		end
		HSDebugTrace("SHIFT", "EShift "..tostring(contextTag))
		EShift()
		return true
	end
end

function QuickShift()
	local a,c=GetActiveForm()
	if(a==0) then
		CastShapeshiftForm(c)
	else
		CastShapeshiftForm(a)
		ToggleAutoAttack("off")
	end
end

function ToggleAutoAttack(switch)
	if(switch == "off") then
		if(FindAttackActionSlot() ~= 0) then AttackTarget() end
	elseif(switch == "on") then
		if(FindAttackActionSlot() == 0) then AttackTarget() end
	end
end

function HSBearSingle()
	if UnitExists("target") ~= 1 or UnitIsDead('target') then return end
	StAttack(1)
	HSDebugTrace("BEAR_SINGLE", "")

	if HSAutoFF == 1
	and IsTDebuff('target', 'Spell_Nature_FaerieFire') == false
	and not IsSpellOnCD("Faerie Fire (Feral)") then
		HSDebugTrace("CAST", "Faerie Fire (bear single)")
		HSCast("Faerie Fire (Feral)(Rank 4)")
		return
	end

	if UnitMana('player') >= 20 and not IsSpellOnCD("Demoralizing Roar") and IsTDebuff('target', 'Ability_Druid_DemoralizingRoar') == false then
		HSDebugTrace("CAST", "Demoralizing Roar")
		HSCast("Demoralizing Roar")
		return
	end

	if UnitMana('player') >= 15 and not IsSpellOnCD("Maul") then
		HSDebugTrace("CAST", "Maul (bear single)")
		HSCast("Maul")
		return
	end
end

function HSBearAOE()
	if UnitExists("target") ~= 1 or UnitIsDead('target') then return end
	StAttack(1)
	HSDebugTrace("BEAR_AOE", "")

	if HSAutoFF == 1
	and IsTDebuff('target', 'Spell_Nature_FaerieFire') == false
	and not IsSpellOnCD("Faerie Fire (Feral)") then
		HSDebugTrace("CAST", "Faerie Fire (bear aoe)")
		HSCast("Faerie Fire (Feral)(Rank 4)")
		return
	end

	if UnitMana('player') >= 15 and not IsSpellOnCD("Swipe") then
		HSDebugTrace("CAST", "Swipe")
		HSCast("Swipe")
		return
	end

	if UnitMana('player') >= 10 and not IsSpellOnCD("Demoralizing Roar") then
		HSDebugTrace("CAST", "Demoralizing Roar (aoe)")
		HSCast("Demoralizing Roar")
		return
	end

	if UnitMana('player') >= 15 and not IsSpellOnCD("Maul") then
		HSDebugTrace("CAST", "Maul (bear aoe)")
		HSCast("Maul")
	end
end

function ShiftyAddon()
	HS_UpdateOverlay(false)
	local formId, catId = GetActiveForm()
	local tot,rot=UnitName("targettarget")
	local romactive = HSBuffChk("INV_Misc_Rune")
	local stealthed = HSBuffChk("Ability_Ambush")
	local partynum = GetNumPartyMembers()
	local romcooldown,romeq,rombag,romslot = ItemInfo('Rune of Metamorphosis')
	local jgcd,jgeq,jgbag,jgslot = ItemInfo('Jom Gabbar')
	local flcd,_,flbag,flslot = ItemInfo('Juju Flurry')
	local lipcd,_,lipbag,lipslot = ItemInfo('Limited Invulnerability Potion')

	if UnitAffectingCombat('player') and HSDeathrate == 1 then
		DeathRate()
	end

	if formId == 1 then
		if ShiftyMode == "aoe" then
			HSBearAOE()
		else
			HSBearSingle()
		end
		return
	end

	if HS_IsBalanceMode() == true then
		if HSBalanceCastRotation() == true then
			HS_UpdateOverlay(false)
		end
		return
	end

	if UnitPowerType("Player") == 3 then
		if stealthed == true then
			if HSBuffChk('Ability_Mount_JungleTiger') == false then
				HSCast("Tiger's Fury(Rank 4)")
			end
			if CheckInteractDistance('target',3) == 1 then
				HSCast("Ravage")
			end
		else
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
						if(not IsSpellOnCD("Cower")) and HSCowerUse == 1 then
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
		return
	end

	if UnitLevel('target') == -1 and UnitAffectingCombat('Player') and UnitInRaid('Player') then
		if tot == playername then
			if UnitName('target') ~= "Eye of C'Thun" and UnitName('target') ~= "Anub'Rekhan" then
				if lipcd == 0 and lipslot ~= 0 then
					UseItemByName("Limited Invulnerability Potion")
				elseif(not IsSpellOnCD("Barkskin")) then
					HSCast("Barkskin")
				end
			end
		else
			if UnitHealth('target') > 10 then
				Restore(romeq,romactive,romcooldown)
			end
		end
		if flcd == 0 and HSFLUse == 1 and (CheckInteractDistance('target',3) == 1 or MobTooFar() == true) then
			UseContainerItem(flbag, flslot)
			if SpellIsTargeting() then SpellTargetUnit("player") end
		end
		if UnitAffectingCombat('Player') and jgeq ~= -1 and jgcd == 0 and UnitName('target') ~= "Razorgore the Untamed" and (CheckInteractDistance('target',3) == 1 or MobTooFar() == true) then
			UseItemByName("Jom Gabbar")
		end
		if UnitName('target') == 'Chromaggus' then BrzRmv() end
	end

	if(not IsSpellOnCD("Cat Form")) then EShift() end
end

function Atk(CorS,stealthyn,romyn,romcd)
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

	if HSTigerUse == 1 and stealthyn == false and HSBuffChk('Ability_Mount_JungleTiger') == false and (not IsSpellOnCD("Tiger's Fury")) and UnitMana('Player') >= 30 and comboPoints < 4 and (CheckInteractDistance('target',3) == 1 or MobTooFar() == true) then
		HSDebugTrace("CAST", "Tiger's Fury")
		HSCast("Tiger's Fury(Rank 4)")
		return
	end

	if stealthyn == false and CheckInteractDistance('target',3) == 1 and comboPoints < fbthresh and canRake and IsTDebuff('target', 'Ability_Druid_Disembowel') == false and IsUse(FindActionSlot("Ability_Druid_Rake")) == 1 and (not IsSpellOnCD("Rake")) and (HSBuffChk("Spell_Shadow_ManaBurn") == true or UnitMana('Player') >= rakeCost) then
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
				if CanShift() == true then
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
				if CanShift() == true then
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

function MobTooFar()
	local toofar = false
	local mobname = UnitName('target')
	local moblist = {"Ragnaros","Eye of C'Thun","Thaddius","Maexxna","Sapphiron"}
	for ind = 1, table.getn(moblist) do if mobname == moblist[ind] then toofar = true break end end
	return toofar
end

function CanShift()
	local canshift = false
	local currentMana, maxMana, hasDruidManaLib = HSGetDruidMana()
	local manathreshold = 90
	local mpcd,_,mpbag,mpslot = ItemInfo('Major Mana Potion')
	local smcd,_,smbag,smslot = ItemInfo('Superior Mana Potion')
	local drcd,_,drbag,drslot = ItemInfo('Demonic Rune')
	local romcooldown,romeq,rombag,romslot = ItemInfo('Rune of Metamorphosis')
	local romactive = HSBuffChk("INV_Misc_Rune")
	if HSShiftUse ~= 1 then return false end
	if hasDruidManaLib == false then
		if hsManaLibFallbackNotice == false then
			hsManaLibFallbackNotice = true
			HSPrint('|cffd08524Shifty: |cffffffffDruidManaLib missing. Using fallback powershift mode.')
		end
		return true
	end
	if (currentMana >= manathreshold or (romcooldown == 0 and romeq ~= -1 and UnitLevel('target') == -1) or (romactive == true and romcooldown > 282 and UnitLevel('target') == -1) or (mpcd == 0 and HSMPUse == 1 and UnitLevel('target') == -1 ) or (drcd == 0 and HSDRUse == 1 and UnitLevel('target') == -1 )) then
		canshift = true
	end
	return canshift
end

function Restore(rom,romyn,romcd)
	local resto = 1500
	local hthresh = 0
	local mpcd,_,mpbag,mpslot = ItemInfo('Major Mana Potion')
	local smcd,_,smbag,smslot = ItemInfo('Superior Mana Potion')
	local drcd,_,drbag,drslot = ItemInfo('Demonic Rune')
	local hscd,_,hsbag,hsslot = ItemInfo('Major Healthstone')
	local nervst, nervdur,_ = GetSpellCooldown(GetSpellID('Innervate'), "spell")
	local nervcd = nervdur - (GetTime() - nervst)
	local mpot = mpslot + smslot
	local curhp = Num_Round((UnitHealth('player')/UnitHealthMax('player')),2)
	if curhp < 0.4 and hsslot ~= 0 and hscd == 0 then UseItemByName("Major Healthstone") end
	if HSBuffChk("INV_Potion_97") == true  then resto = 2800 hthresh = 0 end
	if UnitHealth('target') > hthresh then
		if UnitMana('Player')<resto then
			if(not IsSpellOnCD("Innervate")) and HSInnervateUse == 1 then
				HSCast("Innervate", 1)
			elseif ((HSBuffChk("Spell_Nature_Lightning") == false and nervcd < 340) or UnitMana('Player') < 478) and romyn == false then
				if rom ~= -1 and romcd == 0 then
					if CheckInteractDistance('target',3) == 1 or MobTooFar() == true then UseItemByName("Rune of Metamorphosis") end
				else
					if (mpcd == 0 or smcd == 0) and (drcd == 0 or drcd == -1) and mpot ~= 0 and HSMPUse == 1 then
						if mpslot ~= 0 then UseItemByName("Major Mana Potion") else UseItemByName("Superior Mana Potion") end
					else
						if (mpcd > 0 or smcd > 0 or mpot == 0 or mpcd == -1 or smcd == -1) and drcd == 0 and drslot ~= 0 and HSDRUse == 1 and UnitHealth('player') > 1000 then
							UseItemByName("Demonic Rune")
						elseif (drcd > 0 or drcd == -1) and (mpcd == 0 or smcd == 0) and mpot ~= 0 and HSMPUse == 1 then
							if mpslot ~= 0 then UseItemByName("Major Mana Potion") else UseItemByName("Superior Mana Potion") end
						end
					end
				end
			end
		end
	end
end

function ItemInfo(iname)
	local ItemEquip = -1
	local ItemCdr = -1
	local ContainerBag = nil
	local ContainerSlot = nil
	for slot = 0, 19 do
		if GetInventoryItemLink('player',slot) ~= nil then
			if string.find(GetInventoryItemLink('player',slot),iname) then ItemEquip = slot break end
		end
	end
	if ItemEquip == -1 then
		for bag = 0, 4, 1 do
			for slot = 1, GetContainerNumSlots(bag), 1 do
				local name = GetContainerItemLink(bag,slot)
				if name and string.find(name,iname) then ContainerBag = bag ContainerSlot = slot break end
			end
		end
	end
	if ContainerBag == nil then ContainerBag = 0 end
	if ContainerSlot == nil then ContainerSlot = 0 end
	if ItemEquip ~= -1 then
		icdstart,icddur,_ = GetInventoryItemCooldown('player',ItemEquip)
		ItemCdr = Num_Round(icddur - (GetTime() - icdstart),2)
		if ItemCdr < 0 then ItemCdr = 0 end
	elseif ContainerSlot ~= 0 then
		icdstart, icddur,_ = GetContainerItemCooldown(ContainerBag, ContainerSlot)
		ItemCdr = Num_Round(icddur - (GetTime() - icdstart),2)
		if ItemCdr < 0 then ItemCdr = 0 end
	end
	return ItemCdr,ItemEquip,ContainerBag,ContainerSlot
end

function HSBuffChk(texture)
	local i=0
	local g=GetPlayerBuff
	local isBuffActive = false
	while not(g(i) == -1) do
		if(strfind(GetPlayerBuffTexture(g(i)), texture)) then isBuffActive = true end
		i=i+1
	end
	return isBuffActive
end

function GetSpellID(sn)
	local i,a
	i=0
	while a~=sn do i=i+1 a=GetSpellName(i,"spell") end
	return i
end

function IsSpellOnCD(sn)
	local gameTime = GetTime()
	local start,duration,_ = GetSpellCooldown(GetSpellID(sn), "spell")
	local cdT = start + duration - gameTime
	return (cdT >= 0.1)
end

function GetActiveForm()
	local _, formName, active = nil
	local formId = 0
	local catId = nil
	for i=1,GetNumShapeshiftForms(), 1 do
		_, formName, active = GetShapeshiftFormInfo(i)
		if(string.find(formName, "Cat Form")) then catId = i end
		if(active ~= nil)then formId = i end
	end
	return formId, catId
end

function FindAttackActionSlot()
	for i = 1, 120, 1 do
		if(IsAttackAction(i) == 1 and IsCurrentAction(i) == 1) then return i end
	end
	return 0
end

function FindActionSlot(spellTexture)	
	for i = 1, 120, 1 do
		if(GetActionTexture(i) ~= nil) then
			if(string.find(GetActionTexture(i), spellTexture)) then return i end
		end
	end
	return 0
end

function IsUse(abil)
	isUsable, notEnoughMana = IsUsableAction(abil)
	if isUsable == nil then isUsable = 0 end
	return isUsable
end

function PopSkeleton()
	local ohloc = GetInventoryItemLink("player", 17)
	local ohcd,oheq,ohbag,ohslot = ItemInfo(HSOffhand)
	local offhand = 'Ancient Cornerstone Grimoire'
	if ohloc ~= nil then
		if(string.find(ohloc, offhand)) then
			local acgcdr,acgeq,acgbag,acgslot = ItemInfo(offhand)
			if acgcdr == 0 and (CheckInteractDistance('target',3) == 1 or MobTooFar() == true) then
				UseItemByName('Ancient Cornerstone Grimoire')
			elseif acgcdr > 30 and HSOffhand ~= 'Ancient Cornerstone Grimoire' then
				PickupInventoryItem('17')
				PickupContainerItem(ohbag,ohslot)
			end
		end
	end
end

function Pummel()
	local tloc = GetInventoryItemLink("player", 16)
	local wep = 'Manual Crowd Pummeler'
	local cd,t = 30, GetTime()
	if tloc ~= nil then
		if(string.find(tloc, wep)) then
			local mcpstart, mcpdur, _ = GetInventoryItemCooldown("player", 16)
			local mcpcdr = mcpdur - (GetTime() - mcpstart)
			if mcpcdr < 0 then mcpcdr = 0 end
			if mcpcdr == 0 then
				if t-cd >= (TSSW or 0) and (CheckInteractDistance('target',3) == 1 or MobTooFar() == true) then
					TSSW = t
					UseItemByName('Manual Crowd Pummeler')
				end
			end
		end
	end
end

function SwapOutMCP(weapon,offhand)
	local weploc = GetInventoryItemLink("player", 16)
	local wep = 'Manual Crowd Pummeler'
	local wepcd,wepeq,wepbag,wepslot = ItemInfo(weapon)
	if weploc ~= nil and weapon ~= "none" and weapon ~= "None" then
		if(string.find(weploc, wep)) then
			PickupInventoryItem('16')
			PickupContainerItem(wepbag,wepslot)
		end
	end
	if offhand ~= "none" and offhand ~= "None" and weapon ~= "none" and weapon ~= "None" then
		UseItemByName(offhand)
	end
end

function BrzRmv()
	local debuff = "Bronze"
	for i=1,16 do
		local name = UnitDebuff("player",i)
		if name ~= nil and string.find(name, debuff) then UseItemByName("Hourglass Sand",1) end
	end
end

function Num_Round(number,decimals)
	return math.floor((number*math.pow(10,decimals)+0.5))/math.pow(10,decimals);
end

function StAttack(switch)
	for i = 1, 120, 1 do
		if IsAttackAction(i) == 1 then if IsCurrentAction(i) ~= switch then AttackTarget() end end
	end
end

function IsTDebuff(target, debuff)
	local isDebuff = false
	for i = 1, 40 do if(strfind(tostring(UnitDebuff(target,i)), debuff)) then isDebuff = true end end
	return isDebuff
end

function DebuffRemaining(texture)
	for i = 1, 40 do
		local debuffTexture = UnitDebuff("target", i)
		if(strfind(tostring(debuffTexture), texture)) then
			local _, _, _, _, _, _, expirationTime = UnitDebuff("target", i)
			if type(expirationTime) == "number" and expirationTime > 0 then
				local remaining = expirationTime - GetTime()
				if remaining < 0 then remaining = 0 end
				return remaining
			end
			return 1
		end
	end
	return 0
end

function HasRip() return IsTDebuff("target", HS_RIP_TEXTURE) end
function HasRake() return IsTDebuff("target", HS_RAKE_TEXTURE) end
function RipRemaining() return DebuffRemaining(HS_RIP_TEXTURE) end
function RakeRemaining() return DebuffRemaining(HS_RAKE_TEXTURE) end

function BehindTarget()
	if UnitExists("target") ~= 1 then return false end
	if CheckInteractDistance("target",3) ~= 1 then return false end
	if doclaw ~= 0 and GetTime() <= doclaw then return false end
	return true
end

function DeathRate()
	local totalaverage = 0
	local mobhealth = nil
	local fightlength = 0
	local mobmaxhealth = 100
	if UnitExists('target') then mobhealth = 100 else mobhealth = 0 end
	if GetTime() > Num_Round(combstarttime,2) and combstarttime ~= nil then
		curtime = Num_Round(GetTime(),2)-combstarttime
		if UnitExists('target') then mobmaxhealth = UnitHealthMax('target') else mobmaxhealth = 100 end
		if UnitExists('target') then mobhealth = UnitHealth('target') else mobhealth = 0 end
		if curtime ~= nil then totalaverage = Num_Round((mobmaxhealth - mobhealth)/curtime,2) end
		if totalaverage ~= 0 then fightlength = Num_Round(mobhealth/totalaverage,2) else fightlength = 'infinite' end
	end
	if GetTime() > Num_Round(temptime,2) + 1 and temptime ~= nil then
		if UnitHealth('target') <= reportthreshold then
			if UnitInRaid('player') then
				if UnitLevel('target') == -1 then SendChatMessage('Mob death rate is: '..totalaverage..'% per second',"RAID") end
			else
				HSPrint('---------------')
				HSPrint('Seconds in combat: '..Num_Round(curtime,2))
				HSPrint('Mob death rate is: '..totalaverage..'% per second')
			end
			if UnitAffectingCombat('player') then
				if UnitInRaid('player') then
					if UnitLevel('target') == -1 then
						SendChatMessage('Mob health is: '..mobhealth, "RAID")
						SendChatMessage('Predicted fight time remaining: '..fightlength..' seconds.',"RAID")
					end
				else
					HSPrint('Mob health is: '..mobhealth)
					HSPrint('Predicted fight time remaining: '..fightlength..' seconds.')
				end
			end
			reportthreshold = reportthreshold - 20
		end
		temptime = GetTime()
	end	
end

function SpecCheck(page,spellnum)
	if UnitClass("player") == "Druid" then
		local _, _, _, _, spec = GetTalentInfo(page,spellnum)
		return spec
	else
		return nil
	end
end

function HelmCheck()
	local _,whheq,whhbag,whhslot = ItemInfo('Wolfshead Helm')
	HSPrint(whheq)
end

