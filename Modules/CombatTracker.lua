local DC = DamageCalculation

DC.combatTracker = {
    namespace = DC.name .. "Combat",
    combatStateNamespace = DC.name .. "CombatState",
    bossNamespace = DC.name .. "Bosses",
    listening = false,
    combatStateTracking = false,
    bossTracking = false,
    inCombat = false,
    encounterActive = false,
    pendingSessionReset = true,
    storedCombatDurationMs = 0,
    combatStartedAtMs = nil,
    recentKillEvents = {},
    recentKillWindowMs = 1500,
    bossUnitsById = {},
    bossNames = {},
    maxBossUnitTags = 6,
}

function DC.combatTracker:IsValidSource(sourceType)
    if sourceType == COMBAT_UNIT_TYPE_PLAYER then
        return true
    end

    if sourceType == COMBAT_UNIT_TYPE_PLAYER_PET then
        return DC.storage:GetSettings().includePetDamage
    end

    return false
end

function DC.combatTracker:IsValidTarget(targetType)
    return targetType ~= COMBAT_UNIT_TYPE_PLAYER and targetType ~= COMBAT_UNIT_TYPE_PLAYER_PET
end

function DC.combatTracker:IsPlayerTarget(targetType)
    return targetType == COMBAT_UNIT_TYPE_PLAYER
end

function DC.combatTracker:IsCriticalResult(result)
    return result == ACTION_RESULT_CRITICAL_DAMAGE
        or result == ACTION_RESULT_DOT_TICK_CRITICAL
        or result == ACTION_RESULT_CRITICAL_HEAL
        or result == ACTION_RESULT_HOT_TICK_CRITICAL
end

function DC.combatTracker:IsOutgoingDamageEvent(result, sourceType, targetType)
    if not self:IsValidSource(sourceType) or not self:IsValidTarget(targetType) then
        return false
    end

    for _, damageResult in ipairs(DC.damageResults) do
        if result == damageResult then
            return true
        end
    end

    return false
end

function DC.combatTracker:IsBlockedEvent(result, sourceType, targetType)
    return result == ACTION_RESULT_BLOCKED_DAMAGE
        and self:IsPlayerTarget(targetType)
        and sourceType ~= COMBAT_UNIT_TYPE_PLAYER
        and sourceType ~= COMBAT_UNIT_TYPE_PLAYER_PET
end

function DC.combatTracker:IsIncomingDamageEvent(result, sourceType, targetType)
    if not self:IsPlayerTarget(targetType) then
        return false
    end

    if sourceType == COMBAT_UNIT_TYPE_PLAYER or sourceType == COMBAT_UNIT_TYPE_PLAYER_PET then
        return false
    end

    return result == ACTION_RESULT_DAMAGE
        or result == ACTION_RESULT_CRITICAL_DAMAGE
        or result == ACTION_RESULT_DOT_TICK
        or result == ACTION_RESULT_DOT_TICK_CRITICAL
end

function DC.combatTracker:IsSelfHealEvent(result, sourceType, targetType)
    if not self:IsPlayerTarget(targetType) or not self:IsValidSource(sourceType) then
        return false
    end

    for _, healResult in ipairs(DC.healResults) do
        if result == healResult then
            return true
        end
    end

    return false
end

function DC.combatTracker:IsKillResult(result)
    for _, killResult in ipairs(DC.killResults) do
        if result == killResult then
            return true
        end
    end

    return false
end

function DC.combatTracker:GetKillCategory(targetType)
    if targetType == COMBAT_UNIT_TYPE_PLAYER then
        return "pvp"
    end

    if targetType == COMBAT_UNIT_TYPE_PLAYER_PET then
        return nil
    end

    return "pve"
end

function DC.combatTracker:BuildKillKey(targetUnitId, targetName, targetType)
    if targetUnitId ~= nil and targetUnitId ~= 0 then
        return tostring(targetUnitId)
    end

    local normalizedTargetName = tostring(targetName or "")

    if zo_strformat and normalizedTargetName ~= "" then
        normalizedTargetName = zo_strformat("<<!aC:1>>", normalizedTargetName)
    end

    return string.format("%s|%s", tostring(targetType or 0), normalizedTargetName)
end

function DC.combatTracker:IsDuplicateKillEvent(killKey)
    local now = GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0
    local lastSeenAt = self.recentKillEvents[killKey]

    self.recentKillEvents[killKey] = now

    if lastSeenAt == nil then
        return false
    end

    return (now - lastSeenAt) <= self.recentKillWindowMs
end

function DC.combatTracker:NormalizeUnitName(unitName)
    local normalizedName = tostring(unitName or "")

    if zo_strformat and normalizedName ~= "" then
        normalizedName = zo_strformat("<<!aC:1>>", normalizedName)
    end

    return normalizedName
end

function DC.combatTracker:RefreshBossTargets()
    self.bossUnitsById = {}
    self.bossNames = {}

    for bossIndex = 1, self.maxBossUnitTags do
        local unitTag = "boss" .. bossIndex

        if DoesUnitExist and DoesUnitExist(unitTag) then
            local bossUnitId = GetUnitId and GetUnitId(unitTag) or nil
            local bossName = self:NormalizeUnitName(GetUnitName and GetUnitName(unitTag) or "")

            if bossUnitId ~= nil and bossUnitId ~= 0 then
                self.bossUnitsById[tostring(bossUnitId)] = true
            end

            if bossName ~= "" then
                self.bossNames[bossName] = true
            end
        end
    end
end

function DC.combatTracker:IsBossTarget(targetUnitId, targetName)
    if targetUnitId ~= nil and targetUnitId ~= 0 and self.bossUnitsById[tostring(targetUnitId)] then
        return true
    end

    local normalizedTargetName = self:NormalizeUnitName(targetName)

    return normalizedTargetName ~= "" and self.bossNames[normalizedTargetName] == true
end

function DC.combatTracker:OnBossesChanged()
    self:RefreshBossTargets()
end

function DC.combatTracker:IsCombatLive()
    if self.inCombat then
        return true
    end

    if IsUnitInCombat then
        return IsUnitInCombat("player") == true
    end

    return false
end

function DC.combatTracker:GetNowMs()
    return GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0
end

function DC.combatTracker:ResetCombatTimer()
    self.storedCombatDurationMs = 0

    if self.encounterActive or self.inCombat then
        self.combatStartedAtMs = self:GetNowMs()
    else
        self.combatStartedAtMs = nil
    end
end

function DC.combatTracker:GetCombatDurationMs(now)
    local totalDuration = math.max(0, math.floor(tonumber(self.storedCombatDurationMs) or 0))

    if self.encounterActive and self.combatStartedAtMs ~= nil then
        local currentNow = now or self:GetNowMs()
        totalDuration = totalDuration + math.max(0, currentNow - self.combatStartedAtMs)
    end

    return totalDuration
end

function DC.combatTracker:BeginTrackedEncounter()
    local shouldResetSession = self.pendingSessionReset == true

    self.encounterActive = true
    self:ResetCombatTimer()

    if self.combatStartedAtMs == nil then
        self.combatStartedAtMs = self:GetNowMs()
    end

    self.pendingSessionReset = false

    if shouldResetSession then
        DC.storage:BeginCombatSession()
        if DC.dps and DC.dps.ResetLiveSession then
            DC.dps:ResetLiveSession()
        end
        DC:RefreshDisplay()
    end

    if DC.dps and DC.dps.BeginEncounter then
        DC.dps:BeginEncounter()
    end

    if DC.hud and DC.hud.OnCombatTimerStateChanged then
        DC.hud:OnCombatTimerStateChanged(true)
    end
end

function DC.combatTracker:ShouldIncludeInSession(metricKey)
    if metricKey ~= "healed" then
        if not self.encounterActive then
            self:BeginTrackedEncounter()
        end

        return true
    end

    if self.encounterActive then
        return true
    end

    if not self:IsCombatLive() then
        return false
    end

    self:BeginTrackedEncounter()
    return true
end

function DC.combatTracker:ShouldNotifyMetric(includeSession)
    if includeSession then
        return true
    end

    return DC.storage:GetDisplayMode() == DC.displayModes.TOTAL
end

function DC.combatTracker:NotifyMetric(metricKey, eventInfo, includeSession)
    if self:ShouldNotifyMetric(includeSession) then
        DC:OnMetricAdded(metricKey, eventInfo)
        return
    end

    if DC.tooltip and DC.tooltip.OnMetricAdded then
        DC.tooltip:OnMetricAdded(metricKey, eventInfo)
    end
end

function DC.combatTracker:OnPlayerCombatState(_, inCombat)
    local wasInCombat = self.inCombat == true
    self.inCombat = inCombat == true

    if self.inCombat and not wasInCombat and not self.encounterActive then
        self:BeginTrackedEncounter()
        return
    end

    if not self.inCombat then
        if self.encounterActive and self.combatStartedAtMs ~= nil then
            self.storedCombatDurationMs = self:GetCombatDurationMs(self:GetNowMs())
            self.combatStartedAtMs = nil
        end

        if self.encounterActive and DC.dps and DC.dps.EndEncounter then
            DC.dps:EndEncounter(self.storedCombatDurationMs or 0)
            DC:RefreshDisplay()
        end

        self.encounterActive = false
        self.pendingSessionReset = true

        if DC.hud and DC.hud.OnCombatTimerStateChanged then
            DC.hud:OnCombatTimerStateChanged(false)
        end
    end
end

function DC.combatTracker:TryHandleKillEvent(result, sourceType, targetType, sourceName, targetName, targetUnitId, abilityId)
    if not self:IsKillResult(result) or not self:IsValidSource(sourceType) then
        return false
    end

    local killCategory = self:GetKillCategory(targetType)

    if killCategory == nil then
        return false
    end

    local killKey = self:BuildKillKey(targetUnitId, targetName, targetType)

    if self:IsDuplicateKillEvent(killKey) then
        return true
    end

    local isBossKill = killCategory == "pve" and self:IsBossTarget(targetUnitId, targetName)

    if killCategory == "pvp" then
        DC.storage:AddPvpKill()
    else
        DC.storage:AddPveKill()

        if isBossKill then
            DC.storage:AddPveBossKill()
        end
    end

    DC:OnKillAdded({
        category = killCategory,
        isBossKill = isBossKill,
        result = result,
        sourceName = sourceName,
        targetName = targetName,
        targetType = targetType,
        targetUnitId = targetUnitId,
        abilityId = abilityId,
    })

    return true
end

function DC.combatTracker:OnCombatEvent(_, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId)
    if isError then
        return
    end

    if self:TryHandleKillEvent(result, sourceType, targetType, sourceName, targetName, targetUnitId, abilityId) then
        return
    end

    if hitValue == nil or hitValue <= 0 then
        return
    end

    if DC.dps and DC.dps.IsDamageResult and DC.dps:IsDamageResult(result) and not self.encounterActive then
        self:BeginTrackedEncounter()
    end

    if DC.dps and DC.dps.TrackCombatEvent then
        DC.dps:TrackCombatEvent(result, sourceType, sourceUnitId, hitValue)
    end

    local eventInfo = {
        amount = hitValue,
        isCritical = self:IsCriticalResult(result),
        result = result,
        abilityId = abilityId,
        abilityName = abilityName,
        targetName = targetName,
        sourceName = sourceName,
    }

    if self:IsOutgoingDamageEvent(result, sourceType, targetType) then
        local includeSession = self:ShouldIncludeInSession("damage")
        DC.storage:AddDamage(hitValue, includeSession)
        self:NotifyMetric("damage", eventInfo, includeSession)
        return
    end

    if self:IsBlockedEvent(result, sourceType, targetType) then
        local includeSession = self:ShouldIncludeInSession("blocked")
        DC.storage:AddBlocked(hitValue, includeSession)
        self:NotifyMetric("blocked", eventInfo, includeSession)
        return
    end

    if self:IsIncomingDamageEvent(result, sourceType, targetType) then
        local includeSession = self:ShouldIncludeInSession("received")
        DC.storage:AddReceived(hitValue, includeSession)
        self:NotifyMetric("received", eventInfo, includeSession)
        return
    end

    if self:IsSelfHealEvent(result, sourceType, targetType) then
        local includeSession = self:ShouldIncludeInSession("healed")
        DC.storage:AddHealed(hitValue, includeSession)
        self:NotifyMetric("healed", eventInfo, includeSession)
    end
end

function DC.combatTracker:StartListening()
    if self.listening then
        return
    end

    self.listening = true

    for index, result in ipairs(DC.combatResults) do
        local eventName = string.format("%s_%d", self.namespace, index)

        EVENT_MANAGER:RegisterForEvent(eventName, EVENT_COMBAT_EVENT, function(...)
            self:OnCombatEvent(...)
        end)
        EVENT_MANAGER:AddFilterForEvent(eventName, EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, result, REGISTER_FILTER_IS_ERROR, false)
    end
end

function DC.combatTracker:StartCombatStateTracking()
    if self.combatStateTracking then
        return
    end

    self.combatStateTracking = true
    self.inCombat = IsUnitInCombat and IsUnitInCombat("player") == true or false

    EVENT_MANAGER:RegisterForEvent(self.combatStateNamespace, EVENT_PLAYER_COMBAT_STATE, function(...)
        self:OnPlayerCombatState(...)
    end)
end

function DC.combatTracker:StartBossTracking()
    if self.bossTracking then
        return
    end

    self.bossTracking = true
    self:RefreshBossTargets()

    EVENT_MANAGER:RegisterForEvent(self.bossNamespace, EVENT_BOSSES_CHANGED, function()
        self:OnBossesChanged()
    end)
end

function DC.combatTracker:Initialize()
    self:ResetCombatTimer()
    self:StartCombatStateTracking()
    self:StartBossTracking()
    self:StartListening()
end
