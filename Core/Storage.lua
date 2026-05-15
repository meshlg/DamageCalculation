local DC = DamageCalculation

DC.storage = {
    persistNamespace = DC.name .. "Persist",
    persistThrottleMs = 1000,
    defaults = {
        installId = "",
        integritySalt = "",
        integrityChecksum = "",
        integrityState = DC.integrityStates.VERIFIED,
        lastIntegrityIssue = 0,
        totalDamageEncoded = "",
        totalBlockedEncoded = "",
        totalHealedEncoded = "",
        totalReceivedEncoded = "",
        totalPlayerDamageEncoded = "",
        totalGroupDamageEncoded = "",
        totalCombatDurationEncoded = "",
        totalActiveCombatDurationEncoded = "",
        sessionDamageEncoded = "",
        sessionBlockedEncoded = "",
        sessionHealedEncoded = "",
        sessionReceivedEncoded = "",
        sessionPlayerDamageEncoded = "",
        sessionGroupDamageEncoded = "",
        sessionCombatDurationEncoded = "",
        sessionActiveCombatDurationEncoded = "",
        totalPveKillsEncoded = "",
        totalPveBossKillsEncoded = "",
        totalPvpKillsEncoded = "",
        totalHitsEncoded = "",
        settings = {
            showHud = true,
            lockWindow = false,
            scale = 1.0,
            formatMode = DC.formatModes.FULL,
            displayMode = DC.displayModes.TOTAL,
            dpsMode = DC.dpsModes.COMPATIBLE,
            dpsGraphAutoShowInCombat = true,
            language = DC.languageModes.AUTO,
            showDamageMetric = true,
            showBlockedMetric = true,
            showHealedMetric = true,
            showReceivedMetric = true,
            showLabel = true,
            valueLayoutMode = "separate",
            showIntegrity = true,
            includePetDamage = true,
            showBackground = true,
            showBorder = false,
            hudWidth = 350,
            contentPaddingX = 14,
            contentPaddingY = 10,
            labelAreaWidth = 150,
            fontStyle = DC.fontStyles.SOFT_SHADOW_THICK,
            labelFontFace = DC.fontFaces.BOLD,
            valueFontFace = DC.fontFaces.BOLD,
            popupFontFace = DC.fontFaces.BOLD,
            labelFontSize = 18,
            valueFontSize = 18,
            labelColorR = 1.0,
            labelColorG = 1.0,
            labelColorB = 1.0,
            labelColorA = 1.0,
            valueColorR = 0.9098,
            valueColorG = 0.9058,
            valueColorB = 0.5568,
            valueColorA = 1.0,
            statusFontSize = 12,
            tooltipFontSize = 15,
            hitFontSize = 14,
            animateCounter = true,
            counterAnimationMs = 350,
            showHitPopup = true,
            popupOnlyCrit = false,
            popupDurationMs = 900,
            enableHitSounds = true,
            normalHitSoundId = "Lock_Value",
            bigHitSoundId = "Click_RandomizeButton",
            critHitSoundId = "weapon_swap_fail",
            bigHitSoundThreshold = 30000,
            soundThrottleMs = 80,
            popupAnchor = "left",
            popupOffsetY = -4,
            positionX = 780,
            positionY = 220,
        },
    },
    totalStats = {
        damage = 0,
        blocked = 0,
        healed = 0,
        received = 0,
    },
    sessionStats = {
        damage = 0,
        blocked = 0,
        healed = 0,
        received = 0,
    },
    totalPlayerDamage = 0,
    totalGroupDamage = 0,
    totalCombatDurationMs = 0,
    totalActiveCombatDurationMs = 0,
    sessionPlayerDamage = 0,
    sessionGroupDamage = 0,
    sessionCombatDurationMs = 0,
    sessionActiveCombatDurationMs = 0,
    totalPveKills = 0,
    totalPveBossKills = 0,
    totalPvpKills = 0,
    totalHits = 0,
    persistQueued = false,
    persistRegistered = false,
    lastPersistAt = 0,
}

function DC.storage:CreateEmptyStats()
    return {
        damage = 0,
        blocked = 0,
        healed = 0,
        received = 0,
    }
end

function DC.storage:EnsureStatTables()
    self.totalStats = self.totalStats or self:CreateEmptyStats()
    self.sessionStats = self.sessionStats or self:CreateEmptyStats()
end

function DC.storage:SetDpsSnapshots(totalPlayerDamage, totalGroupDamage, totalCombatDurationMs, totalActiveCombatDurationMs, sessionPlayerDamage, sessionGroupDamage, sessionCombatDurationMs, sessionActiveCombatDurationMs)
    self.totalPlayerDamage = math.max(0, math.floor(tonumber(totalPlayerDamage) or 0))
    self.totalGroupDamage = math.max(0, math.floor(tonumber(totalGroupDamage) or 0))
    self.totalCombatDurationMs = math.max(0, math.floor(tonumber(totalCombatDurationMs) or 0))
    self.totalActiveCombatDurationMs = math.max(0, math.floor(tonumber(totalActiveCombatDurationMs) or 0))
    self.sessionPlayerDamage = math.max(0, math.floor(tonumber(sessionPlayerDamage) or 0))
    self.sessionGroupDamage = math.max(0, math.floor(tonumber(sessionGroupDamage) or 0))
    self.sessionCombatDurationMs = math.max(0, math.floor(tonumber(sessionCombatDurationMs) or 0))
    self.sessionActiveCombatDurationMs = math.max(0, math.floor(tonumber(sessionActiveCombatDurationMs) or 0))
end

function DC.storage:ResetDpsSnapshots()
    self:SetDpsSnapshots(0, 0, 0, 0, 0, 0, 0, 0)
end

function DC.storage:SetMetricStats(targetStats, damage, blocked, healed, received)
    targetStats.damage = math.max(0, math.floor(tonumber(damage) or 0))
    targetStats.blocked = math.max(0, math.floor(tonumber(blocked) or 0))
    targetStats.healed = math.max(0, math.floor(tonumber(healed) or 0))
    targetStats.received = math.max(0, math.floor(tonumber(received) or 0))
end

function DC.storage:ResetMetricStats(targetStats)
    self:SetMetricStats(targetStats, 0, 0, 0, 0)
end

function DC.storage:EnsureSettings()
    self.sv.settings = self.sv.settings or {}

    for key, value in pairs(self.defaults.settings) do
        if self.sv.settings[key] == nil then
            self.sv.settings[key] = value
        end
    end
end

function DC.storage:GetSettings()
    return self.sv.settings
end

function DC.storage:GetDisplayMode()
    local settings = self:GetSettings()
    local displayMode = settings.displayMode

    if displayMode == DC.displayModes.SESSION then
        return DC.displayModes.SESSION
    end

    return DC.displayModes.TOTAL
end

function DC.storage:GetTooltipMode()
    if self:GetDisplayMode() == DC.displayModes.SESSION then
        return DC.displayModes.TOTAL
    end

    return DC.displayModes.SESSION
end

function DC.storage:GetStatsForMode(mode)
    if mode == DC.displayModes.SESSION then
        return self.sessionStats
    end

    return self.totalStats
end

function DC.storage:BuildIntegrityPayload()
    local payload = {
        tostring(self.sv.installId or ""),
        tostring(self.sv.integritySalt or ""),
        tostring(self.sv.totalDamageEncoded or ""),
        tostring(self.sv.totalBlockedEncoded or ""),
        tostring(self.sv.totalHealedEncoded or ""),
        tostring(self.sv.totalReceivedEncoded or ""),
        tostring(self.sv.totalPlayerDamageEncoded or ""),
        tostring(self.sv.totalGroupDamageEncoded or ""),
        tostring(self.sv.totalCombatDurationEncoded or ""),
        tostring(self.sv.totalActiveCombatDurationEncoded or ""),
        tostring(self.sv.sessionDamageEncoded or ""),
        tostring(self.sv.sessionBlockedEncoded or ""),
        tostring(self.sv.sessionHealedEncoded or ""),
        tostring(self.sv.sessionReceivedEncoded or ""),
        tostring(self.sv.sessionPlayerDamageEncoded or ""),
        tostring(self.sv.sessionGroupDamageEncoded or ""),
        tostring(self.sv.sessionCombatDurationEncoded or ""),
        tostring(self.sv.sessionActiveCombatDurationEncoded or ""),
        tostring(self.sv.totalPveKillsEncoded or ""),
        tostring(self.sv.totalPveBossKillsEncoded or ""),
        tostring(self.sv.totalPvpKillsEncoded or ""),
        tostring(self.sv.totalHitsEncoded or ""),
        tostring(DC.savedVariableVersion),
    }

    return table.concat(payload, "|")
end

function DC.storage:BuildPreSessionIntegrityPayload()
    local payload = {
        tostring(self.sv.installId or ""),
        tostring(self.sv.integritySalt or ""),
        tostring(self.sv.totalDamageEncoded or ""),
        tostring(self.sv.totalBlockedEncoded or ""),
        tostring(self.sv.totalHealedEncoded or ""),
        tostring(self.sv.totalReceivedEncoded or ""),
        tostring(self.sv.totalPveKillsEncoded or ""),
        tostring(self.sv.totalPveBossKillsEncoded or ""),
        tostring(self.sv.totalPvpKillsEncoded or ""),
        tostring(self.sv.totalHitsEncoded or ""),
        tostring(DC.savedVariableVersion),
    }

    return table.concat(payload, "|")
end

function DC.storage:BuildPreDpsIntegrityPayload()
    local payload = {
        tostring(self.sv.installId or ""),
        tostring(self.sv.integritySalt or ""),
        tostring(self.sv.totalDamageEncoded or ""),
        tostring(self.sv.totalBlockedEncoded or ""),
        tostring(self.sv.totalHealedEncoded or ""),
        tostring(self.sv.totalReceivedEncoded or ""),
        tostring(self.sv.sessionDamageEncoded or ""),
        tostring(self.sv.sessionBlockedEncoded or ""),
        tostring(self.sv.sessionHealedEncoded or ""),
        tostring(self.sv.sessionReceivedEncoded or ""),
        tostring(self.sv.totalPveKillsEncoded or ""),
        tostring(self.sv.totalPveBossKillsEncoded or ""),
        tostring(self.sv.totalPvpKillsEncoded or ""),
        tostring(self.sv.totalHitsEncoded or ""),
        tostring(DC.savedVariableVersion),
    }

    return table.concat(payload, "|")
end

function DC.storage:BuildPreActiveDpsIntegrityPayload()
    local payload = {
        tostring(self.sv.installId or ""),
        tostring(self.sv.integritySalt or ""),
        tostring(self.sv.totalDamageEncoded or ""),
        tostring(self.sv.totalBlockedEncoded or ""),
        tostring(self.sv.totalHealedEncoded or ""),
        tostring(self.sv.totalReceivedEncoded or ""),
        tostring(self.sv.totalPlayerDamageEncoded or ""),
        tostring(self.sv.totalGroupDamageEncoded or ""),
        tostring(self.sv.totalCombatDurationEncoded or ""),
        tostring(self.sv.sessionDamageEncoded or ""),
        tostring(self.sv.sessionBlockedEncoded or ""),
        tostring(self.sv.sessionHealedEncoded or ""),
        tostring(self.sv.sessionReceivedEncoded or ""),
        tostring(self.sv.sessionPlayerDamageEncoded or ""),
        tostring(self.sv.sessionGroupDamageEncoded or ""),
        tostring(self.sv.sessionCombatDurationEncoded or ""),
        tostring(self.sv.totalPveKillsEncoded or ""),
        tostring(self.sv.totalPveBossKillsEncoded or ""),
        tostring(self.sv.totalPvpKillsEncoded or ""),
        tostring(self.sv.totalHitsEncoded or ""),
        tostring(DC.savedVariableVersion),
    }

    return table.concat(payload, "|")
end

function DC.storage:BuildLegacyIntegrityPayload()
    local payload = {
        tostring(self.sv.installId or ""),
        tostring(self.sv.integritySalt or ""),
        tostring(self.sv.totalDamageEncoded or ""),
        tostring(self.sv.totalHitsEncoded or ""),
        tostring(DC.savedVariableVersion),
    }

    return table.concat(payload, "|")
end

function DC.storage:BuildThreeMetricIntegrityPayload()
    local payload = {
        tostring(self.sv.installId or ""),
        tostring(self.sv.integritySalt or ""),
        tostring(self.sv.totalDamageEncoded or ""),
        tostring(self.sv.totalBlockedEncoded or ""),
        tostring(self.sv.totalHealedEncoded or ""),
        tostring(self.sv.totalHitsEncoded or ""),
        tostring(DC.savedVariableVersion),
    }

    return table.concat(payload, "|")
end

function DC.storage:BuildFourMetricIntegrityPayload()
    local payload = {
        tostring(self.sv.installId or ""),
        tostring(self.sv.integritySalt or ""),
        tostring(self.sv.totalDamageEncoded or ""),
        tostring(self.sv.totalBlockedEncoded or ""),
        tostring(self.sv.totalHealedEncoded or ""),
        tostring(self.sv.totalReceivedEncoded or ""),
        tostring(self.sv.totalHitsEncoded or ""),
        tostring(DC.savedVariableVersion),
    }

    return table.concat(payload, "|")
end

function DC.storage:BuildKillMetricIntegrityPayload()
    local payload = {
        tostring(self.sv.installId or ""),
        tostring(self.sv.integritySalt or ""),
        tostring(self.sv.totalDamageEncoded or ""),
        tostring(self.sv.totalBlockedEncoded or ""),
        tostring(self.sv.totalHealedEncoded or ""),
        tostring(self.sv.totalReceivedEncoded or ""),
        tostring(self.sv.totalPveKillsEncoded or ""),
        tostring(self.sv.totalPvpKillsEncoded or ""),
        tostring(self.sv.totalHitsEncoded or ""),
        tostring(DC.savedVariableVersion),
    }

    return table.concat(payload, "|")
end

function DC.storage:PersistNow()
    local salt = self.sv.integritySalt

    if salt == nil or salt == "" then
        salt = DC.integrity:GenerateSalt()
        self.sv.integritySalt = salt
    end

    self.sv.totalDamageEncoded = DC.integrity:EncodeNumber(self.totalStats.damage, salt, "damage")
    self.sv.totalBlockedEncoded = DC.integrity:EncodeNumber(self.totalStats.blocked, salt, "blocked")
    self.sv.totalHealedEncoded = DC.integrity:EncodeNumber(self.totalStats.healed, salt, "healed")
    self.sv.totalReceivedEncoded = DC.integrity:EncodeNumber(self.totalStats.received, salt, "received")
    self.sv.totalPlayerDamageEncoded = DC.integrity:EncodeNumber(self.totalPlayerDamage, salt, "totalPlayerDamage")
    self.sv.totalGroupDamageEncoded = DC.integrity:EncodeNumber(self.totalGroupDamage, salt, "totalGroupDamage")
    self.sv.totalCombatDurationEncoded = DC.integrity:EncodeNumber(self.totalCombatDurationMs, salt, "totalCombatDuration")
    self.sv.totalActiveCombatDurationEncoded = DC.integrity:EncodeNumber(self.totalActiveCombatDurationMs, salt, "totalActiveCombatDuration")
    self.sv.sessionDamageEncoded = DC.integrity:EncodeNumber(self.sessionStats.damage, salt, "sessionDamage")
    self.sv.sessionBlockedEncoded = DC.integrity:EncodeNumber(self.sessionStats.blocked, salt, "sessionBlocked")
    self.sv.sessionHealedEncoded = DC.integrity:EncodeNumber(self.sessionStats.healed, salt, "sessionHealed")
    self.sv.sessionReceivedEncoded = DC.integrity:EncodeNumber(self.sessionStats.received, salt, "sessionReceived")
    self.sv.sessionPlayerDamageEncoded = DC.integrity:EncodeNumber(self.sessionPlayerDamage, salt, "sessionPlayerDamage")
    self.sv.sessionGroupDamageEncoded = DC.integrity:EncodeNumber(self.sessionGroupDamage, salt, "sessionGroupDamage")
    self.sv.sessionCombatDurationEncoded = DC.integrity:EncodeNumber(self.sessionCombatDurationMs, salt, "sessionCombatDuration")
    self.sv.sessionActiveCombatDurationEncoded = DC.integrity:EncodeNumber(self.sessionActiveCombatDurationMs, salt, "sessionActiveCombatDuration")
    self.sv.totalPveKillsEncoded = DC.integrity:EncodeNumber(self.totalPveKills, salt, "pveKills")
    self.sv.totalPveBossKillsEncoded = DC.integrity:EncodeNumber(self.totalPveBossKills, salt, "pveBossKills")
    self.sv.totalPvpKillsEncoded = DC.integrity:EncodeNumber(self.totalPvpKills, salt, "pvpKills")
    self.sv.totalHitsEncoded = DC.integrity:EncodeNumber(self.totalHits, salt, "hits")
    self.sv.integrityChecksum = DC.integrity:Checksum(self:BuildIntegrityPayload())
    self.lastPersistAt = GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0
    self.persistQueued = false
end

function DC.storage:CancelPersistUpdate()
    if not self.persistRegistered then
        return
    end

    EVENT_MANAGER:UnregisterForUpdate(self.persistNamespace)
    self.persistRegistered = false
end

function DC.storage:FlushPendingPersist()
    self:CancelPersistUpdate()

    if not self.persistQueued then
        return
    end

    self:PersistNow()
end

function DC.storage:Persist(forceImmediate)
    if forceImmediate then
        self:CancelPersistUpdate()
        self.persistQueued = false
        self:PersistNow()
        return
    end

    self.persistQueued = true

    local now = GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0
    local elapsed = now - (self.lastPersistAt or 0)

    if self.lastPersistAt <= 0 or elapsed >= self.persistThrottleMs then
        self:FlushPendingPersist()
        return
    end

    if self.persistRegistered then
        return
    end

    local delayMs = math.max(50, self.persistThrottleMs - elapsed)
    self.persistRegistered = true

    EVENT_MANAGER:RegisterForUpdate(self.persistNamespace, delayMs, function()
        self:FlushPendingPersist()
    end)
end

function DC.storage:ResetAllRuntimeData()
    self:EnsureStatTables()
    self:ResetMetricStats(self.totalStats)
    self:ResetMetricStats(self.sessionStats)
    self:ResetDpsSnapshots()
    self.totalPveKills = 0
    self.totalPveBossKills = 0
    self.totalPvpKills = 0
    self.totalHits = 0

    if DC.combatTracker and DC.combatTracker.ResetCombatTimer then
        DC.combatTracker:ResetCombatTimer()
    end

    if DC.dps and DC.dps.ResetAll then
        DC.dps:ResetAll()
    end
end

function DC.storage:MarkModified()
    self:ResetAllRuntimeData()
    self.sv.integrityState = DC.integrityStates.MODIFIED
    self.sv.lastIntegrityIssue = GetTimeStamp and GetTimeStamp() or 0
    self.sv.integritySalt = DC.integrity:GenerateSalt()
    self:Persist(true)
end

function DC.storage:ResetTotal(clearModifiedFlag)
    self:ResetAllRuntimeData()
    self.sv.integritySalt = DC.integrity:GenerateSalt()

    if clearModifiedFlag then
        self.sv.integrityState = DC.integrityStates.VERIFIED
        self.sv.lastIntegrityIssue = 0
    end

    self:Persist(true)
end

function DC.storage:ResetSessionCombatStats(forceImmediate)
    self:EnsureStatTables()
    self:ResetMetricStats(self.sessionStats)
    self:Persist(forceImmediate == true)
end

function DC.storage:BeginCombatSession()
    self:ResetSessionCombatStats(false)
end

function DC.storage:GetTotalDamage()
    return self.totalStats.damage or 0
end

function DC.storage:GetTotalBlockedDamage()
    return self.totalStats.blocked or 0
end

function DC.storage:GetTotalHealedSelf()
    return self.totalStats.healed or 0
end

function DC.storage:GetTotalReceivedDamage()
    return self.totalStats.received or 0
end

function DC.storage:GetTotalHits()
    return self.totalHits or 0
end

function DC.storage:GetTotalPveKills()
    return self.totalPveKills or 0
end

function DC.storage:GetTotalPveBossKills()
    return self.totalPveBossKills or 0
end

function DC.storage:GetTotalPvpKills()
    return self.totalPvpKills or 0
end

function DC.storage:GetSessionDamage()
    return self.sessionStats.damage or 0
end

function DC.storage:GetSessionBlockedDamage()
    return self.sessionStats.blocked or 0
end

function DC.storage:GetSessionHealedSelf()
    return self.sessionStats.healed or 0
end

function DC.storage:GetSessionReceivedDamage()
    return self.sessionStats.received or 0
end

function DC.storage:GetDpsSnapshotForMode(mode)
    if mode == DC.displayModes.SESSION then
        return {
            playerDamage = self.sessionPlayerDamage or 0,
            groupDamage = self.sessionGroupDamage or 0,
            combatDurationMs = self.sessionCombatDurationMs or 0,
            activeCombatDurationMs = self.sessionActiveCombatDurationMs or 0,
        }
    end

    return {
        playerDamage = self.totalPlayerDamage or 0,
        groupDamage = self.totalGroupDamage or 0,
        combatDurationMs = self.totalCombatDurationMs or 0,
        activeCombatDurationMs = self.totalActiveCombatDurationMs or 0,
    }
end

function DC.storage:FinalizeCombatDps(playerDamage, groupDamage, combatDurationMs, activeCombatDurationMs)
    local safePlayerDamage = math.max(0, math.floor(tonumber(playerDamage) or 0))
    local safeGroupDamage = math.max(0, math.floor(tonumber(groupDamage) or 0))
    local safeCombatDurationMs = math.max(0, math.floor(tonumber(combatDurationMs) or 0))
    local safeActiveCombatDurationMs = math.max(0, math.floor(tonumber(activeCombatDurationMs) or 0))

    self.totalPlayerDamage = (self.totalPlayerDamage or 0) + safePlayerDamage
    self.totalGroupDamage = (self.totalGroupDamage or 0) + safeGroupDamage
    self.totalCombatDurationMs = (self.totalCombatDurationMs or 0) + safeCombatDurationMs
    self.totalActiveCombatDurationMs = (self.totalActiveCombatDurationMs or 0) + safeActiveCombatDurationMs
    self.sessionPlayerDamage = safePlayerDamage
    self.sessionGroupDamage = safeGroupDamage
    self.sessionCombatDurationMs = safeCombatDurationMs
    self.sessionActiveCombatDurationMs = safeActiveCombatDurationMs
    self:Persist(false)
end

function DC.storage:GetMetricTotalForMode(metricKey, mode)
    local stats = self:GetStatsForMode(mode)

    if stats[metricKey] ~= nil then
        return stats[metricKey]
    end

    return stats.damage or 0
end

function DC.storage:GetMetricTotal(metricKey)
    return self:GetMetricTotalForMode(metricKey, self:GetDisplayMode())
end

function DC.storage:IsModified()
    return self.sv.integrityState == DC.integrityStates.MODIFIED
end

function DC.storage:GetIntegrityStatusText()
    if self:IsModified() then
        return DC:GetString("statusModified")
    end

    return DC:GetString("statusVerified")
end

function DC.storage:AddMetric(metricKey, amount, includeSession, countAsHit)
    local numericAmount = math.floor(tonumber(amount) or 0)

    if numericAmount <= 0 then
        return false
    end

    self:EnsureStatTables()

    if self.totalStats[metricKey] == nil then
        return false
    end

    self.totalStats[metricKey] = self.totalStats[metricKey] + numericAmount

    if includeSession ~= false then
        self.sessionStats[metricKey] = self.sessionStats[metricKey] + numericAmount
    end

    if countAsHit == true then
        self.totalHits = self.totalHits + 1
    end

    self:Persist(false)
    return true
end

function DC.storage:AddDamage(amount, includeSession)
    return self:AddMetric("damage", amount, includeSession, true)
end

function DC.storage:AddBlocked(amount, includeSession)
    return self:AddMetric("blocked", amount, includeSession, false)
end

function DC.storage:AddHealed(amount, includeSession)
    return self:AddMetric("healed", amount, includeSession, false)
end

function DC.storage:AddReceived(amount, includeSession)
    return self:AddMetric("received", amount, includeSession, false)
end

function DC.storage:AddPveKill()
    self.totalPveKills = (self.totalPveKills or 0) + 1
    self:Persist(false)
end

function DC.storage:AddPveBossKill()
    self.totalPveBossKills = (self.totalPveBossKills or 0) + 1
    self:Persist(false)
end

function DC.storage:AddPvpKill()
    self.totalPvpKills = (self.totalPvpKills or 0) + 1
    self:Persist(false)
end

function DC.storage:SetSetting(key, value)
    self.sv.settings[key] = value
end

function DC.storage:ResetSettings()
    self.sv.settings = {}
    self:EnsureSettings()
end

function DC.storage:ResetPosition()
    self.sv.settings.positionX = self.defaults.settings.positionX
    self.sv.settings.positionY = self.defaults.settings.positionY
end

function DC.storage:SavePosition(x, y)
    self.sv.settings.positionX = math.floor(tonumber(x) or self.defaults.settings.positionX)
    self.sv.settings.positionY = math.floor(tonumber(y) or self.defaults.settings.positionY)
end

function DC.storage:InitializeDecodedTotals(decodedDamage, decodedBlocked, decodedHealed, decodedReceived, decodedPveKills, decodedPveBossKills, decodedPvpKills, decodedHits)
    self:EnsureStatTables()
    self:SetMetricStats(self.totalStats, decodedDamage, decodedBlocked, decodedHealed, decodedReceived)
    self:SetMetricStats(self.sessionStats, 0, 0, 0, 0)
    self:ResetDpsSnapshots()
    self.totalPveKills = decodedPveKills or 0
    self.totalPveBossKills = decodedPveBossKills or 0
    self.totalPvpKills = decodedPvpKills or 0
    self.totalHits = decodedHits or 0
end

function DC.storage:InitializeDecodedTotalsAndSession(decodedDamage, decodedBlocked, decodedHealed, decodedReceived, decodedSessionDamage, decodedSessionBlocked, decodedSessionHealed, decodedSessionReceived, decodedPveKills, decodedPveBossKills, decodedPvpKills, decodedHits, decodedTotalPlayerDamage, decodedTotalGroupDamage, decodedTotalCombatDurationMs, decodedTotalActiveCombatDurationMs, decodedSessionPlayerDamage, decodedSessionGroupDamage, decodedSessionCombatDurationMs, decodedSessionActiveCombatDurationMs)
    self:EnsureStatTables()
    self:SetMetricStats(self.totalStats, decodedDamage, decodedBlocked, decodedHealed, decodedReceived)
    self:SetMetricStats(self.sessionStats, decodedSessionDamage, decodedSessionBlocked, decodedSessionHealed, decodedSessionReceived)
    self:SetDpsSnapshots(
        decodedTotalPlayerDamage,
        decodedTotalGroupDamage,
        decodedTotalCombatDurationMs,
        decodedTotalActiveCombatDurationMs,
        decodedSessionPlayerDamage,
        decodedSessionGroupDamage,
        decodedSessionCombatDurationMs,
        decodedSessionActiveCombatDurationMs
    )
    self.totalPveKills = decodedPveKills or 0
    self.totalPveBossKills = decodedPveBossKills or 0
    self.totalPvpKills = decodedPvpKills or 0
    self.totalHits = decodedHits or 0
end

function DC.storage:Initialize()
    self.sv = ZO_SavedVars:NewAccountWide(DC.savedVariableName, DC.savedVariableVersion, nil, self.defaults)

    self:EnsureSettings()
    self:EnsureStatTables()
    self:ResetAllRuntimeData()

    if self.sv.installId == nil or self.sv.installId == "" then
        self.sv.installId = DC.integrity:GenerateSalt()
    end

    if self.sv.integritySalt == nil or self.sv.integritySalt == "" then
        self.sv.integritySalt = DC.integrity:GenerateSalt()
    end

    local expectedChecksum = self.sv.integrityChecksum
    local damageEncoded = self.sv.totalDamageEncoded
    local blockedEncoded = self.sv.totalBlockedEncoded
    local healedEncoded = self.sv.totalHealedEncoded
    local receivedEncoded = self.sv.totalReceivedEncoded
    local totalPlayerDamageEncoded = self.sv.totalPlayerDamageEncoded
    local totalGroupDamageEncoded = self.sv.totalGroupDamageEncoded
    local totalCombatDurationEncoded = self.sv.totalCombatDurationEncoded
    local totalActiveCombatDurationEncoded = self.sv.totalActiveCombatDurationEncoded
    local sessionDamageEncoded = self.sv.sessionDamageEncoded
    local sessionBlockedEncoded = self.sv.sessionBlockedEncoded
    local sessionHealedEncoded = self.sv.sessionHealedEncoded
    local sessionReceivedEncoded = self.sv.sessionReceivedEncoded
    local sessionPlayerDamageEncoded = self.sv.sessionPlayerDamageEncoded
    local sessionGroupDamageEncoded = self.sv.sessionGroupDamageEncoded
    local sessionCombatDurationEncoded = self.sv.sessionCombatDurationEncoded
    local sessionActiveCombatDurationEncoded = self.sv.sessionActiveCombatDurationEncoded
    local pveKillsEncoded = self.sv.totalPveKillsEncoded
    local pveBossKillsEncoded = self.sv.totalPveBossKillsEncoded
    local pvpKillsEncoded = self.sv.totalPvpKillsEncoded
    local hitsEncoded = self.sv.totalHitsEncoded

    if expectedChecksum == nil or expectedChecksum == "" or damageEncoded == nil or damageEncoded == "" or hitsEncoded == nil or hitsEncoded == "" then
        self.sv.integrityState = self.sv.integrityState or DC.integrityStates.VERIFIED
        self:ResetTotal(false)
    elseif blockedEncoded == nil or blockedEncoded == "" or healedEncoded == nil or healedEncoded == "" then
        local legacyChecksum = DC.integrity:Checksum(self:BuildLegacyIntegrityPayload())
        local decodedDamage = DC.integrity:DecodeNumber(damageEncoded, self.sv.integritySalt, "damage")
        local decodedHits = DC.integrity:DecodeNumber(hitsEncoded, self.sv.integritySalt, "hits")

        if legacyChecksum ~= expectedChecksum or decodedDamage == nil or decodedHits == nil then
            self:MarkModified()
        else
            self:InitializeDecodedTotals(decodedDamage, 0, 0, 0, 0, 0, 0, decodedHits)
            self:Persist(true)
        end
    elseif receivedEncoded == nil or receivedEncoded == "" then
        local threeMetricChecksum = DC.integrity:Checksum(self:BuildThreeMetricIntegrityPayload())
        local decodedDamage = DC.integrity:DecodeNumber(damageEncoded, self.sv.integritySalt, "damage")
        local decodedBlocked = DC.integrity:DecodeNumber(blockedEncoded, self.sv.integritySalt, "blocked")
        local decodedHealed = DC.integrity:DecodeNumber(healedEncoded, self.sv.integritySalt, "healed")
        local decodedHits = DC.integrity:DecodeNumber(hitsEncoded, self.sv.integritySalt, "hits")

        if threeMetricChecksum ~= expectedChecksum or decodedDamage == nil or decodedBlocked == nil or decodedHealed == nil or decodedHits == nil then
            self:MarkModified()
        else
            self:InitializeDecodedTotals(decodedDamage, decodedBlocked, decodedHealed, 0, 0, 0, 0, decodedHits)
            self:Persist(true)
        end
    elseif pveKillsEncoded == nil or pveKillsEncoded == "" or pvpKillsEncoded == nil or pvpKillsEncoded == "" then
        local fourMetricChecksum = DC.integrity:Checksum(self:BuildFourMetricIntegrityPayload())
        local decodedDamage = DC.integrity:DecodeNumber(damageEncoded, self.sv.integritySalt, "damage")
        local decodedBlocked = DC.integrity:DecodeNumber(blockedEncoded, self.sv.integritySalt, "blocked")
        local decodedHealed = DC.integrity:DecodeNumber(healedEncoded, self.sv.integritySalt, "healed")
        local decodedReceived = DC.integrity:DecodeNumber(receivedEncoded, self.sv.integritySalt, "received")
        local decodedHits = DC.integrity:DecodeNumber(hitsEncoded, self.sv.integritySalt, "hits")

        if fourMetricChecksum ~= expectedChecksum or decodedDamage == nil or decodedBlocked == nil or decodedHealed == nil or decodedReceived == nil or decodedHits == nil then
            self:MarkModified()
        else
            self:InitializeDecodedTotals(decodedDamage, decodedBlocked, decodedHealed, decodedReceived, 0, 0, 0, decodedHits)
            self:Persist(true)
        end
    elseif pveBossKillsEncoded == nil or pveBossKillsEncoded == "" then
        local killMetricChecksum = DC.integrity:Checksum(self:BuildKillMetricIntegrityPayload())
        local decodedDamage = DC.integrity:DecodeNumber(damageEncoded, self.sv.integritySalt, "damage")
        local decodedBlocked = DC.integrity:DecodeNumber(blockedEncoded, self.sv.integritySalt, "blocked")
        local decodedHealed = DC.integrity:DecodeNumber(healedEncoded, self.sv.integritySalt, "healed")
        local decodedReceived = DC.integrity:DecodeNumber(receivedEncoded, self.sv.integritySalt, "received")
        local decodedPveKills = DC.integrity:DecodeNumber(pveKillsEncoded, self.sv.integritySalt, "pveKills")
        local decodedPvpKills = DC.integrity:DecodeNumber(pvpKillsEncoded, self.sv.integritySalt, "pvpKills")
        local decodedHits = DC.integrity:DecodeNumber(hitsEncoded, self.sv.integritySalt, "hits")

        if killMetricChecksum ~= expectedChecksum or decodedDamage == nil or decodedBlocked == nil or decodedHealed == nil or decodedReceived == nil or decodedPveKills == nil or decodedPvpKills == nil or decodedHits == nil then
            self:MarkModified()
        else
            self:InitializeDecodedTotals(decodedDamage, decodedBlocked, decodedHealed, decodedReceived, decodedPveKills, 0, decodedPvpKills, decodedHits)
            self:Persist(true)
        end
    elseif sessionDamageEncoded == nil or sessionDamageEncoded == ""
        or sessionBlockedEncoded == nil or sessionBlockedEncoded == ""
        or sessionHealedEncoded == nil or sessionHealedEncoded == ""
        or sessionReceivedEncoded == nil or sessionReceivedEncoded == "" then
        local preSessionChecksum = DC.integrity:Checksum(self:BuildPreSessionIntegrityPayload())
        local decodedDamage = DC.integrity:DecodeNumber(damageEncoded, self.sv.integritySalt, "damage")
        local decodedBlocked = DC.integrity:DecodeNumber(blockedEncoded, self.sv.integritySalt, "blocked")
        local decodedHealed = DC.integrity:DecodeNumber(healedEncoded, self.sv.integritySalt, "healed")
        local decodedReceived = DC.integrity:DecodeNumber(receivedEncoded, self.sv.integritySalt, "received")
        local decodedPveKills = DC.integrity:DecodeNumber(pveKillsEncoded, self.sv.integritySalt, "pveKills")
        local decodedPveBossKills = DC.integrity:DecodeNumber(pveBossKillsEncoded, self.sv.integritySalt, "pveBossKills")
        local decodedPvpKills = DC.integrity:DecodeNumber(pvpKillsEncoded, self.sv.integritySalt, "pvpKills")
        local decodedHits = DC.integrity:DecodeNumber(hitsEncoded, self.sv.integritySalt, "hits")

        if preSessionChecksum ~= expectedChecksum
            or decodedDamage == nil
            or decodedBlocked == nil
            or decodedHealed == nil
            or decodedReceived == nil
            or decodedPveKills == nil
            or decodedPveBossKills == nil
            or decodedPvpKills == nil
            or decodedHits == nil then
            self:MarkModified()
        else
            self:InitializeDecodedTotals(decodedDamage, decodedBlocked, decodedHealed, decodedReceived, decodedPveKills, decodedPveBossKills, decodedPvpKills, decodedHits)
            self:Persist(true)
        end
    elseif totalPlayerDamageEncoded == nil or totalPlayerDamageEncoded == ""
        or totalGroupDamageEncoded == nil or totalGroupDamageEncoded == ""
        or totalCombatDurationEncoded == nil or totalCombatDurationEncoded == ""
        or sessionPlayerDamageEncoded == nil or sessionPlayerDamageEncoded == ""
        or sessionGroupDamageEncoded == nil or sessionGroupDamageEncoded == ""
        or sessionCombatDurationEncoded == nil or sessionCombatDurationEncoded == "" then
        local preDpsChecksum = DC.integrity:Checksum(self:BuildPreDpsIntegrityPayload())
        local decodedDamage = DC.integrity:DecodeNumber(damageEncoded, self.sv.integritySalt, "damage")
        local decodedBlocked = DC.integrity:DecodeNumber(blockedEncoded, self.sv.integritySalt, "blocked")
        local decodedHealed = DC.integrity:DecodeNumber(healedEncoded, self.sv.integritySalt, "healed")
        local decodedReceived = DC.integrity:DecodeNumber(receivedEncoded, self.sv.integritySalt, "received")
        local decodedSessionDamage = DC.integrity:DecodeNumber(sessionDamageEncoded, self.sv.integritySalt, "sessionDamage")
        local decodedSessionBlocked = DC.integrity:DecodeNumber(sessionBlockedEncoded, self.sv.integritySalt, "sessionBlocked")
        local decodedSessionHealed = DC.integrity:DecodeNumber(sessionHealedEncoded, self.sv.integritySalt, "sessionHealed")
        local decodedSessionReceived = DC.integrity:DecodeNumber(sessionReceivedEncoded, self.sv.integritySalt, "sessionReceived")
        local decodedPveKills = DC.integrity:DecodeNumber(pveKillsEncoded, self.sv.integritySalt, "pveKills")
        local decodedPveBossKills = DC.integrity:DecodeNumber(pveBossKillsEncoded, self.sv.integritySalt, "pveBossKills")
        local decodedPvpKills = DC.integrity:DecodeNumber(pvpKillsEncoded, self.sv.integritySalt, "pvpKills")
        local decodedHits = DC.integrity:DecodeNumber(hitsEncoded, self.sv.integritySalt, "hits")

        if preDpsChecksum ~= expectedChecksum
            or decodedDamage == nil
            or decodedBlocked == nil
            or decodedHealed == nil
            or decodedReceived == nil
            or decodedSessionDamage == nil
            or decodedSessionBlocked == nil
            or decodedSessionHealed == nil
            or decodedSessionReceived == nil
            or decodedPveKills == nil
            or decodedPveBossKills == nil
            or decodedPvpKills == nil
            or decodedHits == nil then
            self:MarkModified()
        else
            self:InitializeDecodedTotalsAndSession(
                decodedDamage,
                decodedBlocked,
                decodedHealed,
                decodedReceived,
                decodedSessionDamage,
                decodedSessionBlocked,
                decodedSessionHealed,
                decodedSessionReceived,
                decodedPveKills,
                decodedPveBossKills,
                decodedPvpKills,
                decodedHits,
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                0
            )
            self:Persist(true)
        end
    elseif totalActiveCombatDurationEncoded == nil or totalActiveCombatDurationEncoded == ""
        or sessionActiveCombatDurationEncoded == nil or sessionActiveCombatDurationEncoded == "" then
        local preActiveDpsChecksum = DC.integrity:Checksum(self:BuildPreActiveDpsIntegrityPayload())
        local decodedDamage = DC.integrity:DecodeNumber(damageEncoded, self.sv.integritySalt, "damage")
        local decodedBlocked = DC.integrity:DecodeNumber(blockedEncoded, self.sv.integritySalt, "blocked")
        local decodedHealed = DC.integrity:DecodeNumber(healedEncoded, self.sv.integritySalt, "healed")
        local decodedReceived = DC.integrity:DecodeNumber(receivedEncoded, self.sv.integritySalt, "received")
        local decodedTotalPlayerDamage = DC.integrity:DecodeNumber(totalPlayerDamageEncoded, self.sv.integritySalt, "totalPlayerDamage")
        local decodedTotalGroupDamage = DC.integrity:DecodeNumber(totalGroupDamageEncoded, self.sv.integritySalt, "totalGroupDamage")
        local decodedTotalCombatDuration = DC.integrity:DecodeNumber(totalCombatDurationEncoded, self.sv.integritySalt, "totalCombatDuration")
        local decodedSessionDamage = DC.integrity:DecodeNumber(sessionDamageEncoded, self.sv.integritySalt, "sessionDamage")
        local decodedSessionBlocked = DC.integrity:DecodeNumber(sessionBlockedEncoded, self.sv.integritySalt, "sessionBlocked")
        local decodedSessionHealed = DC.integrity:DecodeNumber(sessionHealedEncoded, self.sv.integritySalt, "sessionHealed")
        local decodedSessionReceived = DC.integrity:DecodeNumber(sessionReceivedEncoded, self.sv.integritySalt, "sessionReceived")
        local decodedSessionPlayerDamage = DC.integrity:DecodeNumber(sessionPlayerDamageEncoded, self.sv.integritySalt, "sessionPlayerDamage")
        local decodedSessionGroupDamage = DC.integrity:DecodeNumber(sessionGroupDamageEncoded, self.sv.integritySalt, "sessionGroupDamage")
        local decodedSessionCombatDuration = DC.integrity:DecodeNumber(sessionCombatDurationEncoded, self.sv.integritySalt, "sessionCombatDuration")
        local decodedPveKills = DC.integrity:DecodeNumber(pveKillsEncoded, self.sv.integritySalt, "pveKills")
        local decodedPveBossKills = DC.integrity:DecodeNumber(pveBossKillsEncoded, self.sv.integritySalt, "pveBossKills")
        local decodedPvpKills = DC.integrity:DecodeNumber(pvpKillsEncoded, self.sv.integritySalt, "pvpKills")
        local decodedHits = DC.integrity:DecodeNumber(hitsEncoded, self.sv.integritySalt, "hits")

        if preActiveDpsChecksum ~= expectedChecksum
            or decodedDamage == nil
            or decodedBlocked == nil
            or decodedHealed == nil
            or decodedReceived == nil
            or decodedTotalPlayerDamage == nil
            or decodedTotalGroupDamage == nil
            or decodedTotalCombatDuration == nil
            or decodedSessionDamage == nil
            or decodedSessionBlocked == nil
            or decodedSessionHealed == nil
            or decodedSessionReceived == nil
            or decodedSessionPlayerDamage == nil
            or decodedSessionGroupDamage == nil
            or decodedSessionCombatDuration == nil
            or decodedPveKills == nil
            or decodedPveBossKills == nil
            or decodedPvpKills == nil
            or decodedHits == nil then
            self:MarkModified()
        else
            self:InitializeDecodedTotalsAndSession(
                decodedDamage,
                decodedBlocked,
                decodedHealed,
                decodedReceived,
                decodedSessionDamage,
                decodedSessionBlocked,
                decodedSessionHealed,
                decodedSessionReceived,
                decodedPveKills,
                decodedPveBossKills,
                decodedPvpKills,
                decodedHits,
                decodedTotalPlayerDamage,
                decodedTotalGroupDamage,
                decodedTotalCombatDuration,
                decodedTotalCombatDuration,
                decodedSessionPlayerDamage,
                decodedSessionGroupDamage,
                decodedSessionCombatDuration,
                decodedSessionCombatDuration
            )
            self:Persist(true)
        end
    else
        local actualChecksum = DC.integrity:Checksum(self:BuildIntegrityPayload())
        local decodedDamage = DC.integrity:DecodeNumber(damageEncoded, self.sv.integritySalt, "damage")
        local decodedBlocked = DC.integrity:DecodeNumber(blockedEncoded, self.sv.integritySalt, "blocked")
        local decodedHealed = DC.integrity:DecodeNumber(healedEncoded, self.sv.integritySalt, "healed")
        local decodedReceived = DC.integrity:DecodeNumber(receivedEncoded, self.sv.integritySalt, "received")
        local decodedTotalPlayerDamage = DC.integrity:DecodeNumber(totalPlayerDamageEncoded, self.sv.integritySalt, "totalPlayerDamage")
        local decodedTotalGroupDamage = DC.integrity:DecodeNumber(totalGroupDamageEncoded, self.sv.integritySalt, "totalGroupDamage")
        local decodedTotalCombatDuration = DC.integrity:DecodeNumber(totalCombatDurationEncoded, self.sv.integritySalt, "totalCombatDuration")
        local decodedTotalActiveCombatDuration = DC.integrity:DecodeNumber(totalActiveCombatDurationEncoded, self.sv.integritySalt, "totalActiveCombatDuration")
        local decodedSessionDamage = DC.integrity:DecodeNumber(sessionDamageEncoded, self.sv.integritySalt, "sessionDamage")
        local decodedSessionBlocked = DC.integrity:DecodeNumber(sessionBlockedEncoded, self.sv.integritySalt, "sessionBlocked")
        local decodedSessionHealed = DC.integrity:DecodeNumber(sessionHealedEncoded, self.sv.integritySalt, "sessionHealed")
        local decodedSessionReceived = DC.integrity:DecodeNumber(sessionReceivedEncoded, self.sv.integritySalt, "sessionReceived")
        local decodedSessionPlayerDamage = DC.integrity:DecodeNumber(sessionPlayerDamageEncoded, self.sv.integritySalt, "sessionPlayerDamage")
        local decodedSessionGroupDamage = DC.integrity:DecodeNumber(sessionGroupDamageEncoded, self.sv.integritySalt, "sessionGroupDamage")
        local decodedSessionCombatDuration = DC.integrity:DecodeNumber(sessionCombatDurationEncoded, self.sv.integritySalt, "sessionCombatDuration")
        local decodedSessionActiveCombatDuration = DC.integrity:DecodeNumber(sessionActiveCombatDurationEncoded, self.sv.integritySalt, "sessionActiveCombatDuration")
        local decodedPveKills = DC.integrity:DecodeNumber(pveKillsEncoded, self.sv.integritySalt, "pveKills")
        local decodedPveBossKills = DC.integrity:DecodeNumber(pveBossKillsEncoded, self.sv.integritySalt, "pveBossKills")
        local decodedPvpKills = DC.integrity:DecodeNumber(pvpKillsEncoded, self.sv.integritySalt, "pvpKills")
        local decodedHits = DC.integrity:DecodeNumber(hitsEncoded, self.sv.integritySalt, "hits")

        if actualChecksum ~= expectedChecksum
            or decodedDamage == nil
            or decodedBlocked == nil
            or decodedHealed == nil
            or decodedReceived == nil
            or decodedTotalPlayerDamage == nil
            or decodedTotalGroupDamage == nil
            or decodedTotalCombatDuration == nil
            or decodedTotalActiveCombatDuration == nil
            or decodedSessionDamage == nil
            or decodedSessionBlocked == nil
            or decodedSessionHealed == nil
            or decodedSessionReceived == nil
            or decodedSessionPlayerDamage == nil
            or decodedSessionGroupDamage == nil
            or decodedSessionCombatDuration == nil
            or decodedSessionActiveCombatDuration == nil
            or decodedPveKills == nil
            or decodedPveBossKills == nil
            or decodedPvpKills == nil
            or decodedHits == nil then
            self:MarkModified()
        else
            self:InitializeDecodedTotalsAndSession(
                decodedDamage,
                decodedBlocked,
                decodedHealed,
                decodedReceived,
                decodedSessionDamage,
                decodedSessionBlocked,
                decodedSessionHealed,
                decodedSessionReceived,
                decodedPveKills,
                decodedPveBossKills,
                decodedPvpKills,
                decodedHits,
                decodedTotalPlayerDamage,
                decodedTotalGroupDamage,
                decodedTotalCombatDuration,
                decodedTotalActiveCombatDuration,
                decodedSessionPlayerDamage,
                decodedSessionGroupDamage,
                decodedSessionCombatDuration,
                decodedSessionActiveCombatDuration
            )
        end
    end

    EVENT_MANAGER:RegisterForEvent(self.persistNamespace, EVENT_PLAYER_DEACTIVATED, function()
        self:FlushPendingPersist()
    end)

    if self.lastPersistAt <= 0 then
        self.lastPersistAt = GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0
    end
end
