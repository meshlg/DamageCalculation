local DC = DamageCalculation
local displayModeList = { DC.displayModes.TOTAL, DC.displayModes.SESSION }
local dpsModeList = { DC.dpsModes.COMPATIBLE, DC.dpsModes.AVERAGE }

DC.dps = {
    refreshIntervalMs = 250,
    graphSampleIntervalMs = 250,
    initialDisplayDurationMs = 1000,
    recentHitWindowMs = 1500,
    softFreezeWindowMs = 3500,
    hardCorrectionIntervalMs = 5000,
    activeGapThresholdMs = 1500,
    trackedGroupUnitIds = {},
    trackedGroupSize = 1,
    liveSessionPlayerDamage = 0,
    liveSessionGroupDamage = 0,
    liveCommittedActiveCombatDurationMs = 0,
    currentActiveSegmentStartedAtMs = nil,
    currentActiveSegmentLastHitAtMs = nil,
    liveGroupAvailable = false,
    lastSessionGroupAvailable = false,
    totalGroupAvailable = false,
    lastDamageAtMs = 0,
    lastDamageGapMs = 0,
    cachedSnapshots = {},
    displayStates = {},
    graphHistories = {},
    graphLastSampleAtMs = 0,
}

function DC.dps:GetSettings()
    return DC.storage:GetSettings()
end

function DC.dps:GetSelectedDpsMode()
    local configuredMode = self:GetSettings().dpsMode

    if configuredMode == DC.dpsModes.AVERAGE then
        return DC.dpsModes.AVERAGE
    end

    return DC.dpsModes.COMPATIBLE
end

function DC.dps:IsDamageResult(result)
    for _, damageResult in ipairs(DC.damageResults) do
        if result == damageResult then
            return true
        end
    end

    return false
end

function DC.dps:IsPersonalSource(sourceType)
    if sourceType == COMBAT_UNIT_TYPE_PLAYER then
        return true
    end

    if sourceType == COMBAT_UNIT_TYPE_PLAYER_PET then
        return DC.storage:GetSettings().includePetDamage
    end

    return false
end

function DC.dps:GetCurrentGroupSize()
    if GetGroupSize == nil then
        return 1
    end

    return math.max(1, math.floor(tonumber(GetGroupSize()) or 1))
end

function DC.dps:RefreshTrackedGroupUnits()
    self.trackedGroupUnitIds = {}
    self.trackedGroupSize = self:GetCurrentGroupSize()

    if GetUnitId ~= nil then
        local playerUnitId = GetUnitId("player")

        if playerUnitId ~= nil and playerUnitId ~= 0 then
            self.trackedGroupUnitIds[tostring(playerUnitId)] = true
        end
    end

    if self.trackedGroupSize <= 1 or GetGroupUnitTagByIndex == nil or GetUnitId == nil then
        return
    end

    for groupIndex = 1, self.trackedGroupSize do
        local groupUnitTag = GetGroupUnitTagByIndex(groupIndex)

        if groupUnitTag ~= nil and groupUnitTag ~= "" then
            local groupUnitId = GetUnitId(groupUnitTag)

            if groupUnitId ~= nil and groupUnitId ~= 0 then
                self.trackedGroupUnitIds[tostring(groupUnitId)] = true
            end
        end
    end
end

function DC.dps:IsTrackedGroupSource(sourceType, sourceUnitId)
    if sourceType ~= COMBAT_UNIT_TYPE_GROUP then
        return false
    end

    local currentGroupSize = self:GetCurrentGroupSize()

    if currentGroupSize ~= self.trackedGroupSize then
        self:RefreshTrackedGroupUnits()
    end

    if sourceUnitId ~= nil and sourceUnitId ~= 0 then
        local sourceKey = tostring(sourceUnitId)

        if next(self.trackedGroupUnitIds) ~= nil and self.trackedGroupUnitIds[sourceKey] == true then
            return true
        end
    end

    return currentGroupSize > 1
end

function DC.dps:InvalidateCache()
    self.cachedSnapshots = {}
end

function DC.dps:ResetDisplayState(key)
    self.displayStates[key] = {
        playerDps = 0,
        groupDps = nil,
        initialized = false,
        lastCorrectionAtMs = 0,
    }
end

function DC.dps:GetDisplayStateKey(mode, dpsMode)
    return string.format("%s|%s", tostring(mode or DC.displayModes.TOTAL), tostring(dpsMode or self:GetSelectedDpsMode()))
end

function DC.dps:ResetDisplayStates()
    self.displayStates = {}

    for _, mode in ipairs(displayModeList) do
        for _, dpsMode in ipairs(dpsModeList) do
            self:ResetDisplayState(self:GetDisplayStateKey(mode, dpsMode))
        end
    end
end

function DC.dps:CreateEmptyGraphHistories()
    return {
        [DC.displayModes.TOTAL] = {},
        [DC.displayModes.SESSION] = {},
    }
end

function DC.dps:ResetGraphHistories()
    self.graphHistories = self:CreateEmptyGraphHistories()
    self.graphLastSampleAtMs = 0
end

function DC.dps:GetGraphHistoryLimit()
    if DC.GetDpsGraphPointCount then
        return DC:GetDpsGraphPointCount()
    end

    return DC.dpsGraphPointLimits.default
end

function DC.dps:TrimGraphHistory(mode)
    local history = self.graphHistories and self.graphHistories[mode] or nil

    if history == nil then
        return
    end

    local overflow = #history - self:GetGraphHistoryLimit()

    if overflow <= 0 then
        return
    end

    for _ = 1, overflow do
        table.remove(history, 1)
    end
end

function DC.dps:TrimAllGraphHistories()
    for _, mode in ipairs(displayModeList) do
        self:TrimGraphHistory(mode)
    end
end

function DC.dps:CaptureGraphSampleForMode(mode, now)
    if self.graphHistories == nil or self.graphHistories[mode] == nil then
        self:ResetGraphHistories()
    end

    local currentNow = math.max(0, math.floor(tonumber(now) or 0))
    local snapshot = self:GetModeSnapshot(mode, currentNow)
    local history = self.graphHistories[mode]
    local encounterDurationMs = DC.combatTracker and DC.combatTracker.GetCombatDurationMs and DC.combatTracker:GetCombatDurationMs(currentNow) or 0
    local encounterActiveCombatDurationMs = self:GetLiveSessionActiveDurationMs()

    table.insert(history, {
        timestamp = currentNow,
        averagePlayerDps = snapshot.averagePlayerDps or 0,
        activePlayerDps = snapshot.activePlayerDps or 0,
        averageGroupDps = snapshot.averageGroupDps,
        activeGroupDps = snapshot.activeGroupDps,
        sharePercent = snapshot.sharePercent,
        playerDamage = snapshot.playerDamage or 0,
        groupDamage = snapshot.groupDamage or 0,
        combatDurationMs = snapshot.combatDurationMs or 0,
        encounterDurationMs = encounterDurationMs,
        encounterActiveCombatDurationMs = encounterActiveCombatDurationMs,
        encounterPlayerDamage = self.liveSessionPlayerDamage or 0,
        encounterGroupDamage = self.liveSessionGroupDamage or 0,
    })

    self:TrimGraphHistory(mode)
end

function DC.dps:UpdateGraphHistories(now, force)
    local currentNow = math.max(0, math.floor(tonumber(now) or (GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0)))

    if not force and not self:IsEncounterLive() then
        return
    end

    if not force and self.graphLastSampleAtMs > 0 and (currentNow - self.graphLastSampleAtMs) < self.graphSampleIntervalMs then
        return
    end

    self:CaptureGraphSampleForMode(DC.displayModes.TOTAL, currentNow)
    self:CaptureGraphSampleForMode(DC.displayModes.SESSION, currentNow)
    self.graphLastSampleAtMs = currentNow
end

function DC.dps:GetGraphSamples(mode)
    if self.graphHistories == nil then
        self:ResetGraphHistories()
    end

    return self.graphHistories[mode or DC.displayModes.TOTAL] or self.graphHistories[DC.displayModes.TOTAL]
end

function DC.dps:ResetLiveSession()
    self.liveSessionPlayerDamage = 0
    self.liveSessionGroupDamage = 0
    self.liveCommittedActiveCombatDurationMs = 0
    self.currentActiveSegmentStartedAtMs = nil
    self.currentActiveSegmentLastHitAtMs = nil
    self.liveGroupAvailable = false
    self.lastDamageAtMs = 0
    self.lastDamageGapMs = 0
    self:RefreshTrackedGroupUnits()
    self:ResetGraphHistories()

    for _, dpsMode in ipairs(dpsModeList) do
        self:ResetDisplayState(self:GetDisplayStateKey(DC.displayModes.SESSION, dpsMode))
    end

    self:InvalidateCache()
end

function DC.dps:ResetAll()
    self.lastSessionGroupAvailable = false
    self.totalGroupAvailable = false
    self:ResetDisplayStates()
    self:ResetLiveSession()
end

function DC.dps:GetDamageContribution(hitValue)
    return math.max(0, math.floor(tonumber(hitValue) or 0))
end

function DC.dps:CommitFinishedActiveSegment()
    if self.currentActiveSegmentStartedAtMs == nil or self.currentActiveSegmentLastHitAtMs == nil then
        return
    end

    self.liveCommittedActiveCombatDurationMs = (self.liveCommittedActiveCombatDurationMs or 0)
        + math.max(0, self.currentActiveSegmentLastHitAtMs - self.currentActiveSegmentStartedAtMs)
    self.currentActiveSegmentStartedAtMs = nil
    self.currentActiveSegmentLastHitAtMs = nil
end

function DC.dps:TrackActiveDuration(now)
    local currentNow = math.max(0, math.floor(tonumber(now) or 0))

    if self.currentActiveSegmentStartedAtMs == nil or self.currentActiveSegmentLastHitAtMs == nil then
        self.currentActiveSegmentStartedAtMs = currentNow
        self.currentActiveSegmentLastHitAtMs = currentNow
        return
    end

    local activeGap = math.max(0, currentNow - self.currentActiveSegmentLastHitAtMs)

    if activeGap > self.activeGapThresholdMs then
        self:CommitFinishedActiveSegment()
        self.currentActiveSegmentStartedAtMs = currentNow
    end

    self.currentActiveSegmentLastHitAtMs = currentNow
end

function DC.dps:GetLiveSessionActiveDurationMs()
    local totalDuration = math.max(0, math.floor(tonumber(self.liveCommittedActiveCombatDurationMs) or 0))

    if self.currentActiveSegmentStartedAtMs ~= nil and self.currentActiveSegmentLastHitAtMs ~= nil then
        totalDuration = totalDuration + math.max(0, self.currentActiveSegmentLastHitAtMs - self.currentActiveSegmentStartedAtMs)
    end

    return totalDuration
end

function DC.dps:TrackCombatEvent(result, sourceType, sourceUnitId, hitValue)
    if not self:IsDamageResult(result) then
        return
    end

    local damageAmount = self:GetDamageContribution(hitValue)

    if damageAmount <= 0 then
        return
    end

    local countsAsPersonal = self:IsPersonalSource(sourceType)
    local currentGroupSize = self:GetCurrentGroupSize()
    local countsAsGroup = currentGroupSize > 1 and (countsAsPersonal or self:IsTrackedGroupSource(sourceType, sourceUnitId))

    if not countsAsPersonal and not countsAsGroup then
        return
    end

    local currentNow = GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0
    local previousDamageAt = tonumber(self.lastDamageAtMs) or 0

    if previousDamageAt > 0 then
        self.lastDamageGapMs = math.max(0, currentNow - previousDamageAt)
    else
        self.lastDamageGapMs = 0
    end

    self.lastDamageAtMs = currentNow
    self:TrackActiveDuration(currentNow)

    if countsAsPersonal then
        self.liveSessionPlayerDamage = (self.liveSessionPlayerDamage or 0) + damageAmount
    end

    if countsAsGroup then
        self.liveSessionGroupDamage = (self.liveSessionGroupDamage or 0) + damageAmount
        self.liveGroupAvailable = true
    end

    self:InvalidateCache()
end

function DC.dps:BeginEncounter()
    self:RefreshTrackedGroupUnits()
    self:ResetGraphHistories()

    for _, dpsMode in ipairs(dpsModeList) do
        self:ResetDisplayState(self:GetDisplayStateKey(DC.displayModes.SESSION, dpsMode))
    end

    self:InvalidateCache()
end

function DC.dps:EndEncounter(combatDurationMs)
    local groupedThisEncounter = self.liveGroupAvailable == true or self:GetCurrentGroupSize() > 1
    local currentNow = GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0
    local activeCombatDurationMs = self:GetLiveSessionActiveDurationMs()

    DC.storage:FinalizeCombatDps(
        self.liveSessionPlayerDamage or 0,
        self.liveSessionGroupDamage or 0,
        combatDurationMs or 0,
        activeCombatDurationMs
    )

    self.lastSessionGroupAvailable = groupedThisEncounter
    self.totalGroupAvailable = self.totalGroupAvailable == true or groupedThisEncounter
    self.lastDamageGapMs = 0
    self.lastDamageAtMs = currentNow
    self.liveCommittedActiveCombatDurationMs = activeCombatDurationMs
    self.currentActiveSegmentStartedAtMs = nil
    self.currentActiveSegmentLastHitAtMs = nil
    self:ApplyFinalSnapshotToState(DC.displayModes.TOTAL, self:GetStoredModeSnapshot(DC.displayModes.TOTAL), currentNow, false)
    self:ApplyFinalSnapshotToState(DC.displayModes.SESSION, self:GetStoredModeSnapshot(DC.displayModes.SESSION), currentNow, true)
    self:InvalidateCache()
    self:UpdateGraphHistories(currentNow, true)
end

function DC.dps:IsEncounterLive()
    return DC.combatTracker ~= nil
        and DC.combatTracker.encounterActive == true
        and DC.combatTracker.combatStartedAtMs ~= nil
end

function DC.dps:CalculateDps(damageAmount, durationMs, minDurationMs)
    local safeDamageAmount = math.max(0, math.floor(tonumber(damageAmount) or 0))
    local safeDurationMs = math.max(0, math.floor(tonumber(durationMs) or 0))

    if safeDamageAmount <= 0 then
        return 0
    end

    if safeDurationMs <= 0 then
        if minDurationMs == nil then
            return 0
        end

        safeDurationMs = minDurationMs
    elseif minDurationMs ~= nil and safeDurationMs < minDurationMs then
        safeDurationMs = minDurationMs
    end

    return math.max(0, math.floor(safeDamageAmount / (safeDurationMs / 1000)))
end

function DC.dps:BuildSnapshot(playerDamage, groupDamage, combatDurationMs, activeCombatDurationMs, groupAvailable)
    local safeCombatDurationMs = math.max(0, math.floor(tonumber(combatDurationMs) or 0))
    local safeActiveCombatDurationMs = math.max(0, math.floor(tonumber(activeCombatDurationMs) or 0))
    local safePlayerDamage = math.max(0, math.floor(tonumber(playerDamage) or 0))
    local safeGroupDamage = math.max(0, math.floor(tonumber(groupDamage) or 0))
    local sharePercent = nil

    if groupAvailable and safeGroupDamage > 0 then
        sharePercent = math.max(0, math.min(100, math.floor(((safePlayerDamage / safeGroupDamage) * 100) + 0.5)))
    end

    return {
        averagePlayerDps = self:CalculateDps(safePlayerDamage, safeCombatDurationMs, nil),
        activePlayerDps = self:CalculateDps(safePlayerDamage, safeActiveCombatDurationMs, self.initialDisplayDurationMs),
        averageGroupDps = groupAvailable and self:CalculateDps(safeGroupDamage, safeCombatDurationMs, nil) or nil,
        activeGroupDps = groupAvailable and self:CalculateDps(safeGroupDamage, safeActiveCombatDurationMs, self.initialDisplayDurationMs) or nil,
        sharePercent = sharePercent,
        playerDamage = safePlayerDamage,
        groupDamage = safeGroupDamage,
        combatDurationMs = safeCombatDurationMs,
        activeCombatDurationMs = safeActiveCombatDurationMs,
    }
end

function DC.dps:GetStoredModeSnapshot(mode)
    local storedSnapshot = DC.storage:GetDpsSnapshotForMode(mode)
    local groupAvailable = false

    if mode == DC.displayModes.SESSION then
        groupAvailable = self.lastSessionGroupAvailable == true or ((storedSnapshot.groupDamage or 0) > (storedSnapshot.playerDamage or 0))
    else
        groupAvailable = self.totalGroupAvailable == true or ((storedSnapshot.groupDamage or 0) > (storedSnapshot.playerDamage or 0))
    end

    return self:BuildSnapshot(
        storedSnapshot.playerDamage or 0,
        storedSnapshot.groupDamage or 0,
        storedSnapshot.combatDurationMs or 0,
        storedSnapshot.activeCombatDurationMs or 0,
        groupAvailable
    )
end

function DC.dps:GetLiveModeSnapshot(mode, now)
    local storedSnapshot = DC.storage:GetDpsSnapshotForMode(mode)
    local currentDurationMs = DC.combatTracker and DC.combatTracker.GetCombatDurationMs and DC.combatTracker:GetCombatDurationMs(now) or 0
    local currentGroupSize = self:GetCurrentGroupSize()
    local livePlayerDamage = self.liveSessionPlayerDamage or 0
    local liveGroupDamage = self.liveSessionGroupDamage or 0
    local liveActiveDurationMs = self:GetLiveSessionActiveDurationMs()

    if mode == DC.displayModes.SESSION then
        return self:BuildSnapshot(
            livePlayerDamage,
            liveGroupDamage,
            currentDurationMs,
            liveActiveDurationMs,
            currentGroupSize > 1 or self.liveGroupAvailable == true
        )
    end

    return self:BuildSnapshot(
        (storedSnapshot.playerDamage or 0) + livePlayerDamage,
        (storedSnapshot.groupDamage or 0) + liveGroupDamage,
        (storedSnapshot.combatDurationMs or 0) + currentDurationMs,
        (storedSnapshot.activeCombatDurationMs or 0) + liveActiveDurationMs,
        currentGroupSize > 1 or self.liveGroupAvailable == true or self.totalGroupAvailable == true or ((storedSnapshot.groupDamage or 0) > (storedSnapshot.playerDamage or 0))
    )
end

function DC.dps:GetModeSnapshot(mode, now)
    if not self:IsEncounterLive() then
        return self:GetStoredModeSnapshot(mode)
    end

    local currentNow = now or (GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0)
    local cacheKey = tostring(mode or DC.displayModes.TOTAL)
    local cachedSnapshot = self.cachedSnapshots[cacheKey]

    if cachedSnapshot ~= nil and (currentNow - cachedSnapshot.updatedAt) < self.refreshIntervalMs then
        return cachedSnapshot.data
    end

    local snapshot = self:GetLiveModeSnapshot(mode, currentNow)
    self.cachedSnapshots[cacheKey] = {
        updatedAt = currentNow,
        data = snapshot,
    }

    return snapshot
end

function DC.dps:GetDisplayTargetDps(realDps, totalDamage, combatDurationMs)
    local safeRealDps = math.max(0, math.floor(tonumber(realDps) or 0))
    local safeTotalDamage = math.max(0, math.floor(tonumber(totalDamage) or 0))
    local safeCombatDurationMs = math.max(0, math.floor(tonumber(combatDurationMs) or 0))

    if safeCombatDurationMs <= 0 then
        return 0
    end

    if safeCombatDurationMs >= self.initialDisplayDurationMs then
        return safeRealDps
    end

    local warmedUpDps = math.max(0, math.floor((safeTotalDamage * 1000) / self.initialDisplayDurationMs))
    return math.min(safeRealDps, warmedUpDps)
end

function DC.dps:LerpDisplayValue(currentValue, targetValue, coefficient)
    local safeCurrent = math.max(0, tonumber(currentValue) or 0)
    local safeTarget = math.max(0, tonumber(targetValue) or 0)
    local t = math.max(0, math.min(1, tonumber(coefficient) or 0))

    return math.max(0, math.floor(safeCurrent + ((safeTarget - safeCurrent) * t) + 0.5))
end

function DC.dps:GetDisplayState(mode, dpsMode)
    local stateKey = self:GetDisplayStateKey(mode, dpsMode)

    if self.displayStates[stateKey] == nil then
        self:ResetDisplayState(stateKey)
    end

    return self.displayStates[stateKey]
end

function DC.dps:SelectSnapshotDps(snapshot, dpsMode)
    if dpsMode == DC.dpsModes.AVERAGE then
        return snapshot.averagePlayerDps, snapshot.averageGroupDps, snapshot.activePlayerDps, "hudDpsActiveShort"
    end

    return snapshot.activePlayerDps, snapshot.activeGroupDps, snapshot.averagePlayerDps, "hudDpsAverageShort"
end

function DC.dps:ApplyFinalSnapshotToState(mode, snapshot, now, preserveCompatiblePeak)
    local currentNow = now or (GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0)

    for _, dpsMode in ipairs(dpsModeList) do
        local state = self:GetDisplayState(mode, dpsMode)
        local playerDps, groupDps = self:SelectSnapshotDps(snapshot, dpsMode)

        if preserveCompatiblePeak == true and dpsMode == DC.dpsModes.COMPATIBLE then
            playerDps = math.max(math.max(0, math.floor(tonumber(playerDps) or 0)), math.max(0, math.floor(tonumber(state.playerDps) or 0)))

            if groupDps ~= nil then
                groupDps = math.max(math.max(0, math.floor(tonumber(groupDps) or 0)), math.max(0, math.floor(tonumber(state.groupDps) or 0)))
            end
        end

        state.playerDps = playerDps
        state.groupDps = groupDps
        state.initialized = true
        state.lastCorrectionAtMs = currentNow
    end
end

function DC.dps:SyncDisplayStatesToReal(now)
    local currentNow = now or (GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0)

    for _, mode in ipairs(displayModeList) do
        local realSnapshot = self:GetStoredModeSnapshot(mode)

        for _, dpsMode in ipairs(dpsModeList) do
            local state = self:GetDisplayState(mode, dpsMode)
            local playerDps, groupDps = self:SelectSnapshotDps(realSnapshot, dpsMode)

            state.playerDps = playerDps
            state.groupDps = groupDps
            state.initialized = true
            state.lastCorrectionAtMs = currentNow
        end
    end
end

function DC.dps:BuildDisplaySnapshot(mode, now)
    local currentNow = now or (GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0)
    local realSnapshot = self:GetModeSnapshot(mode, currentNow)
    local selectedMode = self:GetSelectedDpsMode()
    local state = self:GetDisplayState(mode, selectedMode)
    local primaryPlayerDps, primaryGroupDps, secondaryPlayerDps, secondaryLabelKey = self:SelectSnapshotDps(realSnapshot, selectedMode)
    local timeSinceLastHit = self.lastDamageAtMs > 0 and math.max(0, currentNow - self.lastDamageAtMs) or math.huge
    local targetPlayerDps = selectedMode == DC.dpsModes.AVERAGE
        and self:GetDisplayTargetDps(primaryPlayerDps, realSnapshot.playerDamage, realSnapshot.combatDurationMs)
        or primaryPlayerDps
    local targetGroupDps = primaryGroupDps
    local hasGroupValue = primaryGroupDps ~= nil

    if hasGroupValue and selectedMode == DC.dpsModes.AVERAGE then
        targetGroupDps = self:GetDisplayTargetDps(primaryGroupDps, realSnapshot.groupDamage, realSnapshot.combatDurationMs)
    end

    if not self:IsEncounterLive() then
        local finalPlayerDps = primaryPlayerDps
        local finalGroupDps = primaryGroupDps

        if selectedMode == DC.dpsModes.COMPATIBLE and state.initialized then
            finalPlayerDps = math.max(math.max(0, math.floor(tonumber(primaryPlayerDps) or 0)), math.max(0, math.floor(tonumber(state.playerDps) or 0)))

            if primaryGroupDps ~= nil then
                finalGroupDps = math.max(math.max(0, math.floor(tonumber(primaryGroupDps) or 0)), math.max(0, math.floor(tonumber(state.groupDps) or 0)))
            end
        end

        local finalSnapshot = {
            playerDps = finalPlayerDps,
            groupDps = finalGroupDps,
            secondaryPlayerDps = secondaryPlayerDps,
            secondaryLabelKey = secondaryLabelKey,
            sharePercent = realSnapshot.sharePercent,
            combatDurationMs = realSnapshot.combatDurationMs,
        }

        state.playerDps = finalSnapshot.playerDps
        state.groupDps = finalSnapshot.groupDps
        state.initialized = true
        state.lastCorrectionAtMs = currentNow

        return finalSnapshot
    end

    if not state.initialized then
        state.playerDps = targetPlayerDps
        state.groupDps = targetGroupDps
        state.initialized = true
        state.lastCorrectionAtMs = currentNow
    else
        if targetPlayerDps >= (state.playerDps or 0) then
            state.playerDps = targetPlayerDps
        elseif selectedMode == DC.dpsModes.COMPATIBLE and timeSinceLastHit >= self.recentHitWindowMs then
            state.playerDps = math.max(0, math.floor(tonumber(state.playerDps) or 0))
        elseif timeSinceLastHit < self.recentHitWindowMs then
            state.playerDps = self:LerpDisplayValue(state.playerDps, targetPlayerDps, 0.25)
        elseif timeSinceLastHit < self.softFreezeWindowMs then
            state.playerDps = math.max(0, math.floor((tonumber(state.playerDps) or 0) * 0.9975))
        else
            state.playerDps = self:LerpDisplayValue(state.playerDps, targetPlayerDps, 0.15)
        end

        if hasGroupValue then
            if targetGroupDps ~= nil and targetGroupDps >= (state.groupDps or 0) then
                state.groupDps = targetGroupDps
            elseif selectedMode == DC.dpsModes.COMPATIBLE and timeSinceLastHit >= self.recentHitWindowMs then
                state.groupDps = math.max(0, math.floor(tonumber(state.groupDps) or 0))
            elseif timeSinceLastHit < self.recentHitWindowMs then
                state.groupDps = self:LerpDisplayValue(state.groupDps or targetGroupDps or 0, targetGroupDps or 0, 0.25)
            elseif timeSinceLastHit < self.softFreezeWindowMs then
                state.groupDps = math.max(0, math.floor((tonumber(state.groupDps) or 0) * 0.9975))
            else
                state.groupDps = self:LerpDisplayValue(state.groupDps or targetGroupDps or 0, targetGroupDps or 0, 0.15)
            end
        else
            state.groupDps = nil
        end

        local shouldFreezeCompatibleDisplay = selectedMode == DC.dpsModes.COMPATIBLE and timeSinceLastHit >= self.recentHitWindowMs

        if not shouldFreezeCompatibleDisplay and (currentNow - (state.lastCorrectionAtMs or 0)) >= self.hardCorrectionIntervalMs then
            state.playerDps = self:LerpDisplayValue(state.playerDps, targetPlayerDps, 0.3)

            if hasGroupValue then
                state.groupDps = self:LerpDisplayValue(state.groupDps or targetGroupDps or 0, targetGroupDps or 0, 0.3)
            end

            state.lastCorrectionAtMs = currentNow
        end
    end

    return {
        playerDps = math.max(0, math.floor(tonumber(state.playerDps) or 0)),
        groupDps = hasGroupValue and math.max(0, math.floor(tonumber(state.groupDps) or 0)) or nil,
        secondaryPlayerDps = secondaryPlayerDps,
        secondaryLabelKey = secondaryLabelKey,
        sharePercent = realSnapshot.sharePercent,
        combatDurationMs = realSnapshot.combatDurationMs,
    }
end

function DC.dps:Initialize()
    local totalSnapshot = DC.storage:GetDpsSnapshotForMode(DC.displayModes.TOTAL)
    local sessionSnapshot = DC.storage:GetDpsSnapshotForMode(DC.displayModes.SESSION)

    self.totalGroupAvailable = (totalSnapshot.groupDamage or 0) > (totalSnapshot.playerDamage or 0)
    self.lastSessionGroupAvailable = (sessionSnapshot.groupDamage or 0) > (sessionSnapshot.playerDamage or 0)
    self:ResetDisplayStates()
    self:ResetLiveSession()
    self:SyncDisplayStatesToReal()
end
