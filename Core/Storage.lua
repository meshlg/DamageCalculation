local DC = DamageCalculation

local function IntegrityChannel(...)
    return string.char(...)
end

local INTEGRITY_CHANNELS = {
    damage = IntegrityChannel(100, 97, 109, 97, 103, 101),
    blocked = IntegrityChannel(98, 108, 111, 99, 107, 101, 100),
    healed = IntegrityChannel(104, 101, 97, 108, 101, 100),
    received = IntegrityChannel(114, 101, 99, 101, 105, 118, 101, 100),
    totalPlayerDamage = IntegrityChannel(116, 111, 116, 97, 108, 80, 108, 97, 121, 101, 114, 68, 97, 109, 97, 103, 101),
    totalGroupDamage = IntegrityChannel(116, 111, 116, 97, 108, 71, 114, 111, 117, 112, 68, 97, 109, 97, 103, 101),
    totalCombatDuration = IntegrityChannel(116, 111, 116, 97, 108, 67, 111, 109, 98, 97, 116, 68, 117, 114, 97, 116, 105, 111, 110),
    totalActiveCombatDuration = IntegrityChannel(116, 111, 116, 97, 108, 65, 99, 116, 105, 118, 101, 67, 111, 109, 98, 97, 116, 68, 117, 114, 97, 116, 105, 111, 110),
    sessionDamage = IntegrityChannel(115, 101, 115, 115, 105, 111, 110, 68, 97, 109, 97, 103, 101),
    sessionBlocked = IntegrityChannel(115, 101, 115, 115, 105, 111, 110, 66, 108, 111, 99, 107, 101, 100),
    sessionHealed = IntegrityChannel(115, 101, 115, 115, 105, 111, 110, 72, 101, 97, 108, 101, 100),
    sessionReceived = IntegrityChannel(115, 101, 115, 115, 105, 111, 110, 82, 101, 99, 101, 105, 118, 101, 100),
    sessionPlayerDamage = IntegrityChannel(115, 101, 115, 115, 105, 111, 110, 80, 108, 97, 121, 101, 114, 68, 97, 109, 97, 103, 101),
    sessionGroupDamage = IntegrityChannel(115, 101, 115, 115, 105, 111, 110, 71, 114, 111, 117, 112, 68, 97, 109, 97, 103, 101),
    sessionCombatDuration = IntegrityChannel(115, 101, 115, 115, 105, 111, 110, 67, 111, 109, 98, 97, 116, 68, 117, 114, 97, 116, 105, 111, 110),
    sessionActiveCombatDuration = IntegrityChannel(115, 101, 115, 115, 105, 111, 110, 65, 99, 116, 105, 118, 101, 67, 111, 109, 98, 97, 116, 68, 117, 114, 97, 116, 105, 111, 110),
    pveKills = IntegrityChannel(112, 118, 101, 75, 105, 108, 108, 115),
    pveBossKills = IntegrityChannel(112, 118, 101, 66, 111, 115, 115, 75, 105, 108, 108, 115),
    pvpKills = IntegrityChannel(112, 118, 112, 75, 105, 108, 108, 115),
    hits = IntegrityChannel(104, 105, 116, 115),
    integrityCanary = IntegrityChannel(105, 110, 116, 101, 103, 114, 105, 116, 121, 67, 97, 110, 97, 114, 121),
    integrityShadowTotal = IntegrityChannel(105, 110, 116, 101, 103, 114, 105, 116, 121, 83, 104, 97, 100, 111, 119, 84, 111, 116, 97, 108),
    integrityShadowSession = IntegrityChannel(105, 110, 116, 101, 103, 114, 105, 116, 121, 83, 104, 97, 100, 111, 119, 83, 101, 115, 115, 105, 111, 110),
}

local CURRENT_INTEGRITY_CODEC_VERSION = 1

DC.storage = {
    persistNamespace = DC.name .. "Persist",
    persistThrottleMs = 1000,
    defaults = {
        installId = "",
        integrityCodecVersion = CURRENT_INTEGRITY_CODEC_VERSION,
        integrityKeyA = "",
        integrityKeyB = "",
        integrityChecksum = "",
        integrityChecksumSecondary = "",
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
        integrityCanaryEncoded = "",
        integrityShadowTotalEncoded = "",
        integrityShadowSessionEncoded = "",
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
            dpsGraphMode = DC.graphModes.TREND,
            showMiniDpsGraph = true,
            showLargeDpsGraph = true,
            dpsGraphPointCount = DC.dpsGraphPointLimits.default,
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
            fontStyle = DC.fontStyles.SOFT_SHADOW_THICK,
            labelFontFace = DC.fontFaces.BOLD,
            valueFontFace = DC.fontFaces.BOLD,
            popupFontFace = DC.fontFaces.BOLD,
            labelFontSize = 16,
            valueFontSize = 16,
            labelColorR = 1.0,
            labelColorG = 1.0,
            labelColorB = 1.0,
            labelColorA = 1.0,
            valueColorR = 0.9098,
            valueColorG = 0.9058,
            valueColorB = 0.5568,
            valueColorA = 1.0,
            statusFontSize = 12,
            tooltipFontSize = 16,
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
            bigHitSoundThreshold = DC.hitThresholds.strong,
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
    integritySpotCheckIntervalMs = 4000,
    lastIntegritySpotCheckAt = 0,
    integrityFailureHandled = false,
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

    if self.sv.settings.showLargeDpsGraph == false then
        self.sv.settings.dpsGraphAutoShowInCombat = false
    end

    self.sv.settings.dpsGraphPointCount = DC:ClampDpsGraphPointCount(self.sv.settings.dpsGraphPointCount)
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
        tostring(self.sv.integrityCodecVersion or 0),
        tostring(self.sv.integrityKeyA or ""),
        tostring(self.sv.integrityKeyB or ""),
        tostring(self.sv.integrityCanaryEncoded or ""),
        tostring(self.sv.integrityShadowTotalEncoded or ""),
        tostring(self.sv.integrityShadowSessionEncoded or ""),
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

function DC.storage:BuildIntegritySecondaryPayload()
    local payload = {
        "DamageCalculation::Secondary",
        tostring(DC.savedVariableVersion),
        tostring(self.sv.integrityShadowSessionEncoded or ""),
        tostring(self.sv.sessionActiveCombatDurationEncoded or ""),
        tostring(self.sv.sessionCombatDurationEncoded or ""),
        tostring(self.sv.sessionGroupDamageEncoded or ""),
        tostring(self.sv.sessionPlayerDamageEncoded or ""),
        tostring(self.sv.sessionReceivedEncoded or ""),
        tostring(self.sv.sessionHealedEncoded or ""),
        tostring(self.sv.sessionBlockedEncoded or ""),
        tostring(self.sv.sessionDamageEncoded or ""),
        tostring(self.sv.totalHitsEncoded or ""),
        tostring(self.sv.totalPvpKillsEncoded or ""),
        tostring(self.sv.totalPveBossKillsEncoded or ""),
        tostring(self.sv.totalPveKillsEncoded or ""),
        tostring(self.sv.totalActiveCombatDurationEncoded or ""),
        tostring(self.sv.totalCombatDurationEncoded or ""),
        tostring(self.sv.totalGroupDamageEncoded or ""),
        tostring(self.sv.totalPlayerDamageEncoded or ""),
        tostring(self.sv.totalReceivedEncoded or ""),
        tostring(self.sv.totalHealedEncoded or ""),
        tostring(self.sv.totalBlockedEncoded or ""),
        tostring(self.sv.totalDamageEncoded or ""),
        tostring(self.sv.integrityShadowTotalEncoded or ""),
        tostring(self.sv.integrityCanaryEncoded or ""),
        tostring(self.sv.integrityKeyB or ""),
        tostring(self.sv.installId or ""),
        tostring(self.sv.integrityKeyA or ""),
        tostring(self.sv.integrityCodecVersion or 0),
    }

    return table.concat(payload, "#")
end

function DC.storage:BuildCurrentIntegritySnapshot()
    self:EnsureStatTables()

    return {
        totalDamage = self.totalStats.damage or 0,
        totalBlocked = self.totalStats.blocked or 0,
        totalHealed = self.totalStats.healed or 0,
        totalReceived = self.totalStats.received or 0,
        totalPlayerDamage = self.totalPlayerDamage or 0,
        totalGroupDamage = self.totalGroupDamage or 0,
        totalCombatDurationMs = self.totalCombatDurationMs or 0,
        totalActiveCombatDurationMs = self.totalActiveCombatDurationMs or 0,
        sessionDamage = self.sessionStats.damage or 0,
        sessionBlocked = self.sessionStats.blocked or 0,
        sessionHealed = self.sessionStats.healed or 0,
        sessionReceived = self.sessionStats.received or 0,
        sessionPlayerDamage = self.sessionPlayerDamage or 0,
        sessionGroupDamage = self.sessionGroupDamage or 0,
        sessionCombatDurationMs = self.sessionCombatDurationMs or 0,
        sessionActiveCombatDurationMs = self.sessionActiveCombatDurationMs or 0,
        totalPveKills = self.totalPveKills or 0,
        totalPveBossKills = self.totalPveBossKills or 0,
        totalPvpKills = self.totalPvpKills or 0,
        totalHits = self.totalHits or 0,
    }
end

function DC.storage:BuildShadowPayload(scope, snapshot)
    local payload

    if scope == "session" then
        payload = {
            "session",
            tostring(self.sv.installId or ""),
            tostring(snapshot.sessionDamage or 0),
            tostring(snapshot.sessionBlocked or 0),
            tostring(snapshot.sessionHealed or 0),
            tostring(snapshot.sessionReceived or 0),
            tostring(snapshot.sessionPlayerDamage or 0),
            tostring(snapshot.sessionGroupDamage or 0),
            tostring(snapshot.sessionCombatDurationMs or 0),
            tostring(snapshot.sessionActiveCombatDurationMs or 0),
            tostring(DC.savedVariableVersion),
        }
    else
        payload = {
            "total",
            tostring(self.sv.installId or ""),
            tostring(snapshot.totalDamage or 0),
            tostring(snapshot.totalBlocked or 0),
            tostring(snapshot.totalHealed or 0),
            tostring(snapshot.totalReceived or 0),
            tostring(snapshot.totalPlayerDamage or 0),
            tostring(snapshot.totalGroupDamage or 0),
            tostring(snapshot.totalCombatDurationMs or 0),
            tostring(snapshot.totalActiveCombatDurationMs or 0),
            tostring(snapshot.totalPveKills or 0),
            tostring(snapshot.totalPveBossKills or 0),
            tostring(snapshot.totalPvpKills or 0),
            tostring(snapshot.totalHits or 0),
            tostring(DC.savedVariableVersion),
        }
    end

    return table.concat(payload, "|")
end

function DC.storage:GetExpectedIntegrityCanary()
    local payload = table.concat({
        tostring(self.sv.installId or ""),
        tostring(self.sv.integrityCodecVersion or 0),
        tostring(self.sv.integrityKeyA or ""),
        tostring(self.sv.integrityKeyB or ""),
        tostring(DC.savedVariableVersion),
        "DamageCalculation::Canary",
    }, "|")

    return DC.integrity:ChecksumToUint32(payload, true)
end

function DC.storage:GetExpectedIntegrityShadowTotal(snapshot)
    return DC.integrity:ChecksumToUint32(self:BuildShadowPayload("total", snapshot), false)
end

function DC.storage:GetExpectedIntegrityShadowSession(snapshot)
    return DC.integrity:ChecksumToUint32(self:BuildShadowPayload("session", snapshot), true)
end

function DC.storage:EnsureIntegritySeed()
    local keyA = self.sv.integrityKeyA
    local keyB = self.sv.integrityKeyB

    if keyA == nil or keyA == "" or keyB == nil or keyB == "" then
        keyA, keyB = DC.integrity:GenerateSeedParts()
        self.sv.integrityKeyA = keyA
        self.sv.integrityKeyB = keyB
    end

    self.sv.integrityCodecVersion = CURRENT_INTEGRITY_CODEC_VERSION
    DC.integrity:InitializeRuntimeSeed(self.sv.integrityKeyA, self.sv.integrityKeyB)
end

function DC.storage:RotateIntegritySeed(forceImmediate)
    self.sv.integrityCodecVersion = CURRENT_INTEGRITY_CODEC_VERSION
    self.sv.integrityKeyA, self.sv.integrityKeyB = DC.integrity:GenerateSeedParts()
    self:Persist(forceImmediate == true)
end

function DC.storage:PersistNow()
    self:EnsureIntegritySeed()
    local snapshot = self:BuildCurrentIntegritySnapshot()

    self.sv.totalDamageEncoded = DC.integrity:EncodeNumber(snapshot.totalDamage, INTEGRITY_CHANNELS.damage)
    self.sv.totalBlockedEncoded = DC.integrity:EncodeNumber(snapshot.totalBlocked, INTEGRITY_CHANNELS.blocked)
    self.sv.totalHealedEncoded = DC.integrity:EncodeNumber(snapshot.totalHealed, INTEGRITY_CHANNELS.healed)
    self.sv.totalReceivedEncoded = DC.integrity:EncodeNumber(snapshot.totalReceived, INTEGRITY_CHANNELS.received)
    self.sv.totalPlayerDamageEncoded = DC.integrity:EncodeNumber(snapshot.totalPlayerDamage, INTEGRITY_CHANNELS.totalPlayerDamage)
    self.sv.totalGroupDamageEncoded = DC.integrity:EncodeNumber(snapshot.totalGroupDamage, INTEGRITY_CHANNELS.totalGroupDamage)
    self.sv.totalCombatDurationEncoded = DC.integrity:EncodeNumber(snapshot.totalCombatDurationMs, INTEGRITY_CHANNELS.totalCombatDuration)
    self.sv.totalActiveCombatDurationEncoded = DC.integrity:EncodeNumber(snapshot.totalActiveCombatDurationMs, INTEGRITY_CHANNELS.totalActiveCombatDuration)
    self.sv.sessionDamageEncoded = DC.integrity:EncodeNumber(snapshot.sessionDamage, INTEGRITY_CHANNELS.sessionDamage)
    self.sv.sessionBlockedEncoded = DC.integrity:EncodeNumber(snapshot.sessionBlocked, INTEGRITY_CHANNELS.sessionBlocked)
    self.sv.sessionHealedEncoded = DC.integrity:EncodeNumber(snapshot.sessionHealed, INTEGRITY_CHANNELS.sessionHealed)
    self.sv.sessionReceivedEncoded = DC.integrity:EncodeNumber(snapshot.sessionReceived, INTEGRITY_CHANNELS.sessionReceived)
    self.sv.sessionPlayerDamageEncoded = DC.integrity:EncodeNumber(snapshot.sessionPlayerDamage, INTEGRITY_CHANNELS.sessionPlayerDamage)
    self.sv.sessionGroupDamageEncoded = DC.integrity:EncodeNumber(snapshot.sessionGroupDamage, INTEGRITY_CHANNELS.sessionGroupDamage)
    self.sv.sessionCombatDurationEncoded = DC.integrity:EncodeNumber(snapshot.sessionCombatDurationMs, INTEGRITY_CHANNELS.sessionCombatDuration)
    self.sv.sessionActiveCombatDurationEncoded = DC.integrity:EncodeNumber(snapshot.sessionActiveCombatDurationMs, INTEGRITY_CHANNELS.sessionActiveCombatDuration)
    self.sv.totalPveKillsEncoded = DC.integrity:EncodeNumber(snapshot.totalPveKills, INTEGRITY_CHANNELS.pveKills)
    self.sv.totalPveBossKillsEncoded = DC.integrity:EncodeNumber(snapshot.totalPveBossKills, INTEGRITY_CHANNELS.pveBossKills)
    self.sv.totalPvpKillsEncoded = DC.integrity:EncodeNumber(snapshot.totalPvpKills, INTEGRITY_CHANNELS.pvpKills)
    self.sv.totalHitsEncoded = DC.integrity:EncodeNumber(snapshot.totalHits, INTEGRITY_CHANNELS.hits)
    self.sv.integrityCanaryEncoded = DC.integrity:EncodeNumber(self:GetExpectedIntegrityCanary(), INTEGRITY_CHANNELS.integrityCanary)
    self.sv.integrityShadowTotalEncoded = DC.integrity:EncodeNumber(self:GetExpectedIntegrityShadowTotal(snapshot), INTEGRITY_CHANNELS.integrityShadowTotal)
    self.sv.integrityShadowSessionEncoded = DC.integrity:EncodeNumber(self:GetExpectedIntegrityShadowSession(snapshot), INTEGRITY_CHANNELS.integrityShadowSession)
    self.sv.integrityChecksum = DC.integrity:Checksum(self:BuildIntegrityPayload())
    self.sv.integrityChecksumSecondary = DC.integrity:Checksum(self:BuildIntegritySecondaryPayload())
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

function DC.storage:DecodePersistedIntegritySnapshot()
    return {
        totalDamage = DC.integrity:DecodeNumber(self.sv.totalDamageEncoded, INTEGRITY_CHANNELS.damage),
        totalBlocked = DC.integrity:DecodeNumber(self.sv.totalBlockedEncoded, INTEGRITY_CHANNELS.blocked),
        totalHealed = DC.integrity:DecodeNumber(self.sv.totalHealedEncoded, INTEGRITY_CHANNELS.healed),
        totalReceived = DC.integrity:DecodeNumber(self.sv.totalReceivedEncoded, INTEGRITY_CHANNELS.received),
        totalPlayerDamage = DC.integrity:DecodeNumber(self.sv.totalPlayerDamageEncoded, INTEGRITY_CHANNELS.totalPlayerDamage),
        totalGroupDamage = DC.integrity:DecodeNumber(self.sv.totalGroupDamageEncoded, INTEGRITY_CHANNELS.totalGroupDamage),
        totalCombatDurationMs = DC.integrity:DecodeNumber(self.sv.totalCombatDurationEncoded, INTEGRITY_CHANNELS.totalCombatDuration),
        totalActiveCombatDurationMs = DC.integrity:DecodeNumber(self.sv.totalActiveCombatDurationEncoded, INTEGRITY_CHANNELS.totalActiveCombatDuration),
        sessionDamage = DC.integrity:DecodeNumber(self.sv.sessionDamageEncoded, INTEGRITY_CHANNELS.sessionDamage),
        sessionBlocked = DC.integrity:DecodeNumber(self.sv.sessionBlockedEncoded, INTEGRITY_CHANNELS.sessionBlocked),
        sessionHealed = DC.integrity:DecodeNumber(self.sv.sessionHealedEncoded, INTEGRITY_CHANNELS.sessionHealed),
        sessionReceived = DC.integrity:DecodeNumber(self.sv.sessionReceivedEncoded, INTEGRITY_CHANNELS.sessionReceived),
        sessionPlayerDamage = DC.integrity:DecodeNumber(self.sv.sessionPlayerDamageEncoded, INTEGRITY_CHANNELS.sessionPlayerDamage),
        sessionGroupDamage = DC.integrity:DecodeNumber(self.sv.sessionGroupDamageEncoded, INTEGRITY_CHANNELS.sessionGroupDamage),
        sessionCombatDurationMs = DC.integrity:DecodeNumber(self.sv.sessionCombatDurationEncoded, INTEGRITY_CHANNELS.sessionCombatDuration),
        sessionActiveCombatDurationMs = DC.integrity:DecodeNumber(self.sv.sessionActiveCombatDurationEncoded, INTEGRITY_CHANNELS.sessionActiveCombatDuration),
        totalPveKills = DC.integrity:DecodeNumber(self.sv.totalPveKillsEncoded, INTEGRITY_CHANNELS.pveKills),
        totalPveBossKills = DC.integrity:DecodeNumber(self.sv.totalPveBossKillsEncoded, INTEGRITY_CHANNELS.pveBossKills),
        totalPvpKills = DC.integrity:DecodeNumber(self.sv.totalPvpKillsEncoded, INTEGRITY_CHANNELS.pvpKills),
        totalHits = DC.integrity:DecodeNumber(self.sv.totalHitsEncoded, INTEGRITY_CHANNELS.hits),
        canary = DC.integrity:DecodeNumber(self.sv.integrityCanaryEncoded, INTEGRITY_CHANNELS.integrityCanary),
        shadowTotal = DC.integrity:DecodeNumber(self.sv.integrityShadowTotalEncoded, INTEGRITY_CHANNELS.integrityShadowTotal),
        shadowSession = DC.integrity:DecodeNumber(self.sv.integrityShadowSessionEncoded, INTEGRITY_CHANNELS.integrityShadowSession),
    }
end

function DC.storage:IsDecodedIntegritySnapshotValid(snapshot)
    if snapshot == nil then
        return false
    end

    local requiredKeys = {
        "totalDamage",
        "totalBlocked",
        "totalHealed",
        "totalReceived",
        "totalPlayerDamage",
        "totalGroupDamage",
        "totalCombatDurationMs",
        "totalActiveCombatDurationMs",
        "sessionDamage",
        "sessionBlocked",
        "sessionHealed",
        "sessionReceived",
        "sessionPlayerDamage",
        "sessionGroupDamage",
        "sessionCombatDurationMs",
        "sessionActiveCombatDurationMs",
        "totalPveKills",
        "totalPveBossKills",
        "totalPvpKills",
        "totalHits",
        "canary",
        "shadowTotal",
        "shadowSession",
    }

    for _, key in ipairs(requiredKeys) do
        if snapshot[key] == nil then
            return false
        end
    end

    return true
end

function DC.storage:DoesIntegritySnapshotMatch(snapshot)
    if not self:IsDecodedIntegritySnapshotValid(snapshot) then
        return false
    end

    if snapshot.canary ~= self:GetExpectedIntegrityCanary() then
        return false
    end

    if snapshot.shadowTotal ~= self:GetExpectedIntegrityShadowTotal(snapshot) then
        return false
    end

    if snapshot.shadowSession ~= self:GetExpectedIntegrityShadowSession(snapshot) then
        return false
    end

    return true
end

function DC.storage:ValidatePersistedIntegrityState()
    if not DC.integrity:SelfTest() then
        return false
    end

    if self.sv.integrityChecksum == nil or self.sv.integrityChecksum == "" then
        return false
    end

    if self.sv.integrityChecksumSecondary == nil or self.sv.integrityChecksumSecondary == "" then
        return false
    end

    if self.sv.integrityChecksum ~= DC.integrity:Checksum(self:BuildIntegrityPayload()) then
        return false
    end

    if self.sv.integrityChecksumSecondary ~= DC.integrity:Checksum(self:BuildIntegritySecondaryPayload()) then
        return false
    end

    local snapshot = self:DecodePersistedIntegritySnapshot()

    if not self:DoesIntegritySnapshotMatch(snapshot) then
        return false
    end

    return snapshot
end

function DC.storage:HandleIntegrityFailure()
    if self.integrityFailureHandled then
        return false
    end

    self.integrityFailureHandled = true
    self:MarkModified()
    return false
end

function DC.storage:MaybeRunIntegritySpotCheck(force)
    if self.integrityFailureHandled then
        return false
    end

    local now = GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0

    if not force and self.lastIntegritySpotCheckAt > 0 and (now - self.lastIntegritySpotCheckAt) < self.integritySpotCheckIntervalMs then
        return true
    end

    self.lastIntegritySpotCheckAt = now

    if self:ValidatePersistedIntegrityState() == false then
        return self:HandleIntegrityFailure()
    end

    return true
end

function DC.storage:MarkModified()
    self:ResetAllRuntimeData()
    self.sv.integrityState = DC.integrityStates.MODIFIED
    self.sv.lastIntegrityIssue = GetTimeStamp and GetTimeStamp() or 0
    self.sv.integrityCodecVersion = CURRENT_INTEGRITY_CODEC_VERSION
    self.sv.integrityKeyA, self.sv.integrityKeyB = DC.integrity:GenerateSeedParts()
    self:Persist(true)
end

function DC.storage:ResetTotal(clearModifiedFlag)
    self:ResetAllRuntimeData()
    self.integrityFailureHandled = false
    self.lastIntegritySpotCheckAt = 0
    self.sv.integrityCodecVersion = CURRENT_INTEGRITY_CODEC_VERSION
    self.sv.integrityKeyA, self.sv.integrityKeyB = DC.integrity:GenerateSeedParts()

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
    self:MaybeRunIntegritySpotCheck(false)

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
    self:MaybeRunIntegritySpotCheck(false)

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
    self:MaybeRunIntegritySpotCheck(false)

    if self:IsModified() then
        return DC:GetString("statusModified")
    end

    return DC:GetString("statusVerified")
end

function DC.storage:BuildSessionIntegrityPayload()
    local payload = {
        tostring(self.sv.installId or ""),
        tostring(self.sv.integrityCodecVersion or 0),
        tostring(self.sv.integrityKeyA or ""),
        tostring(self.sv.integrityKeyB or ""),
        tostring((self.sessionStats and self.sessionStats.damage) or 0),
        tostring((self.sessionStats and self.sessionStats.blocked) or 0),
        tostring((self.sessionStats and self.sessionStats.healed) or 0),
        tostring((self.sessionStats and self.sessionStats.received) or 0),
        tostring(self.sessionPlayerDamage or 0),
        tostring(self.sessionGroupDamage or 0),
        tostring(self.sessionCombatDurationMs or 0),
        tostring(self.sessionActiveCombatDurationMs or 0),
        tostring(DC.savedVariableVersion),
    }

    return table.concat(payload, "|")
end

function DC.storage:GetSessionIntegrityHash()
    self:MaybeRunIntegritySpotCheck(false)
    return string.upper(DC.integrity:Checksum(self:BuildSessionIntegrityPayload()))
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
        local installPartA, installPartB = DC.integrity:GenerateSeedParts()
        self.sv.installId = string.format("%s%s", tostring(installPartA), tostring(installPartB))
    end

    if self.sv.integrityCodecVersion ~= CURRENT_INTEGRITY_CODEC_VERSION then
        self.sv.integrityState = DC.integrityStates.VERIFIED
        self.sv.lastIntegrityIssue = 0
        self:ResetTotal(false)
    else
        local requiredValues = {
            self.sv.integrityChecksum,
            self.sv.integrityChecksumSecondary,
            self.sv.integrityCanaryEncoded,
            self.sv.integrityShadowTotalEncoded,
            self.sv.integrityShadowSessionEncoded,
            self.sv.totalDamageEncoded,
            self.sv.totalBlockedEncoded,
            self.sv.totalHealedEncoded,
            self.sv.totalReceivedEncoded,
            self.sv.totalPlayerDamageEncoded,
            self.sv.totalGroupDamageEncoded,
            self.sv.totalCombatDurationEncoded,
            self.sv.totalActiveCombatDurationEncoded,
            self.sv.sessionDamageEncoded,
            self.sv.sessionBlockedEncoded,
            self.sv.sessionHealedEncoded,
            self.sv.sessionReceivedEncoded,
            self.sv.sessionPlayerDamageEncoded,
            self.sv.sessionGroupDamageEncoded,
            self.sv.sessionCombatDurationEncoded,
            self.sv.sessionActiveCombatDurationEncoded,
            self.sv.totalPveKillsEncoded,
            self.sv.totalPveBossKillsEncoded,
            self.sv.totalPvpKillsEncoded,
            self.sv.totalHitsEncoded,
        }
        local hasAllRequiredValues = true

        for _, value in ipairs(requiredValues) do
            if value == nil or value == "" then
                hasAllRequiredValues = false
                break
            end
        end

        if not hasAllRequiredValues then
            self.sv.integrityState = DC.integrityStates.VERIFIED
            self.sv.lastIntegrityIssue = 0
            self:ResetTotal(false)
        else
            self:EnsureIntegritySeed()
            local snapshot = self:ValidatePersistedIntegrityState()

            if type(snapshot) ~= "table" then
                self:HandleIntegrityFailure()
            else
                local validatedSnapshot = snapshot
                self.integrityFailureHandled = false
                self.lastIntegritySpotCheckAt = 0
                self:InitializeDecodedTotalsAndSession(
                    validatedSnapshot.totalDamage,
                    validatedSnapshot.totalBlocked,
                    validatedSnapshot.totalHealed,
                    validatedSnapshot.totalReceived,
                    validatedSnapshot.sessionDamage,
                    validatedSnapshot.sessionBlocked,
                    validatedSnapshot.sessionHealed,
                    validatedSnapshot.sessionReceived,
                    validatedSnapshot.totalPveKills,
                    validatedSnapshot.totalPveBossKills,
                    validatedSnapshot.totalPvpKills,
                    validatedSnapshot.totalHits,
                    validatedSnapshot.totalPlayerDamage,
                    validatedSnapshot.totalGroupDamage,
                    validatedSnapshot.totalCombatDurationMs,
                    validatedSnapshot.totalActiveCombatDurationMs,
                    validatedSnapshot.sessionPlayerDamage,
                    validatedSnapshot.sessionGroupDamage,
                    validatedSnapshot.sessionCombatDurationMs,
                    validatedSnapshot.sessionActiveCombatDurationMs
                )
                self:RotateIntegritySeed(true)
            end
        end
    end

    EVENT_MANAGER:RegisterForEvent(self.persistNamespace, EVENT_PLAYER_DEACTIVATED, function()
        self:FlushPendingPersist()
    end)

    if self.lastPersistAt <= 0 then
        self.lastPersistAt = GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0
    end
end
