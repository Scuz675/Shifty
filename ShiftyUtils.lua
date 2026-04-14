-- Shifty shared utilities

function SH_EnsureDebugStore()
	if type(ShiftyDebugLog) ~= "table" then
		ShiftyDebugLog = {}
	end
	if type(ShiftyDebugLog.session) ~= "table" then
		ShiftyDebugLog.session = {}
	end
	if type(ShiftyDebugLog._persist) ~= "table" then
		ShiftyDebugLog._persist = {}
	end
	if ShiftyDebugLog._persist_enabled == nil then
		ShiftyDebugLog._persist_enabled = 1
	end
	if type(ShiftyDebugLog._overlay) ~= "table" then
		ShiftyDebugLog._overlay = {}
	end
	if ShiftyDebugLog._overlay.x == nil then ShiftyDebugLog._overlay.x = 0 end
	if ShiftyDebugLog._overlay.y == nil then ShiftyDebugLog._overlay.y = 160 end
	if ShiftyDebugLog._overlay.point == nil then ShiftyDebugLog._overlay.point = "CENTER" end
	if ShiftyDebugLog._overlay.relativePoint == nil then ShiftyDebugLog._overlay.relativePoint = "CENTER" end
	if ShiftyDebugLog._overlay.locked == nil then ShiftyDebugLog._overlay.locked = 0 end
	if ShiftyDebugLog._overlay.debug_quiet == nil then ShiftyDebugLog._overlay.debug_quiet = 1 end
	return ShiftyDebugLog
end

function SH_GetSessionLogStore()
	return SH_EnsureDebugStore().session
end

function SH_GetPersistentLogStore()
	return SH_EnsureDebugStore()._persist
end

function SH_ClearTable(t)
	if type(t) ~= "table" then return end
	while table.getn(t) > 0 do
		table.remove(t, 1)
	end
end

function SH_ClearSessionLog()
	SH_ClearTable(SH_GetSessionLogStore())
end

function SH_ClearPersistentLog()
	SH_ClearTable(SH_GetPersistentLogStore())
end

function SH_ClearAllLogs()
	SH_ClearSessionLog()
	SH_ClearPersistentLog()
end

function SH_GetOverlayStore()
	return SH_EnsureDebugStore()._overlay
end

function SH_InitBalanceState()
	if type(SH_BalanceState) ~= "table" then
		SH_BalanceState = {}
	end
	if type(SH_BalanceState.state) ~= "table" then
		SH_BalanceState.state = { phase = "fish_arcane", arcaneUntil = 0, natureUntil = 0, lastEclipse = "" }
	end
	if type(SH_BalanceState.dotAttempted) ~= "table" then
		SH_BalanceState.dotAttempted = { ["Moonfire"] = false, ["Insect Swarm"] = false }
	end
	if type(SH_BalanceState.dotAppliedAt) ~= "table" then
		SH_BalanceState.dotAppliedAt = { ["Moonfire"] = 0, ["Insect Swarm"] = 0 }
	end
	if type(SH_BalanceState.dotPendingUntil) ~= "table" then
		SH_BalanceState.dotPendingUntil = { ["Moonfire"] = 0, ["Insect Swarm"] = 0 }
	end
	if type(SH_BalanceState.dotLockUntil) ~= "table" then
		SH_BalanceState.dotLockUntil = { ["Moonfire"] = 0, ["Insect Swarm"] = 0 }
	end
	if SH_BalanceState.dotLockTarget == nil then SH_BalanceState.dotLockTarget = "" end
	if SH_BalanceState.openerTarget == nil then SH_BalanceState.openerTarget = "" end
	if SH_BalanceState.openedWithMoonfire == nil then SH_BalanceState.openedWithMoonfire = false end
	if SH_BalanceState.openedWithInsectSwarm == nil then SH_BalanceState.openedWithInsectSwarm = false end
	if SH_BalanceState.counters == nil then SH_BalanceState.counters = { wrath = 0, starfire = 0 } end
	if SH_BalanceState.timers == nil then SH_BalanceState.timers = { clearcastingUntil = 0, astralBoonUntil = 0, naturalBoonUntil = 0, arcaneChainUntil = 0, lastPredictedAt = 0 } end
	if SH_BalanceState.runtime == nil then SH_BalanceState.runtime = { lastPredictedSpell = nil, lastProcLine = "", lastProcReason = nil, openerPendingSpell = nil, openerPendingUntil = 0 } end
	return SH_BalanceState
end

function SH_ResetBalanceTransientState()
	local st = SH_InitBalanceState()
	st.state.phase = "fish_arcane"
	st.state.arcaneUntil = 0
	st.state.natureUntil = 0
	st.state.lastEclipse = ""
	st.dotAttempted["Moonfire"] = false
	st.dotAttempted["Insect Swarm"] = false
	st.dotAppliedAt["Moonfire"] = 0
	st.dotAppliedAt["Insect Swarm"] = 0
	st.dotPendingUntil["Moonfire"] = 0
	st.dotPendingUntil["Insect Swarm"] = 0
	st.dotLockUntil["Moonfire"] = 0
	st.dotLockUntil["Insect Swarm"] = 0
	st.dotLockTarget = ""
	st.openerTarget = ""
	st.openedWithMoonfire = false
	st.openedWithInsectSwarm = false
end

function SH_GetOverlayPhaseText()
	if type(HS_IsBalanceMode) == "function" and HS_IsBalanceMode() == true then
		if type(HS_BALANCE_STATE) == "table" then
			local phase = tostring(HS_BALANCE_STATE.phase or "")
			if phase == "arcane_eclipse" then return "Arcane" end
			if phase == "nature_eclipse" then return "Nature" end
			if phase == "snapshot" then return "Snapshot" end
			if phase == "fish_arcane" then return "Fish Arcane" end
		end
		return "Moonkin"
	end
	local formId = 0
	if type(GetActiveForm) == "function" then
		formId = GetActiveForm() or 0
	end
	if formId == 1 then return "Bear" end
	if type(UnitPowerType) == "function" and UnitPowerType("player") == 3 then
		return "Cat"
	end
	return "Caster"
end

function SH_GetSpellTextureSafe(spellName)
	if spellName == nil or spellName == "" then
		return "Interface\\Icons\\INV_Misc_QuestionMark"
	end
	if type(HSCanUseSpellTexture) == "function" then
		local texture = HSCanUseSpellTexture(spellName)
		if texture ~= nil and texture ~= "" then return texture end
	end
	return "Interface\\Icons\\INV_Misc_QuestionMark"
end
