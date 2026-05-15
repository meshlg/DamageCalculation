local DC = DamageCalculation

DC.sound = {
    lastPlayAt = 0,
    choices = {
        { value = "", labelKey = "soundChoiceOff" },
        { value = "Click", labelKey = "soundChoiceClick" },
        { value = "Click_Positive", labelKey = "soundChoicePositive" },
        { value = "Ability_Picked_Up", labelKey = "soundChoicePickup" },
        { value = "weapon_swap_fail", labelKey = "soundChoiceSwapFail" },
        { value = "AdventureZone_OverviewClosed", labelKey = "soundChoiceOverviewOff" },
        { value = "AdventureZone_OverviewOpened", labelKey = "soundChoiceOverviewOn" },
        { value = "AlliancePoint_Transact", labelKey = "soundChoiceAlliance" },
        { value = "Antiquities_Digging_Fragments_Found_All", labelKey = "soundChoiceFanfare" },
        { value = "Armory_Expanded", labelKey = "soundChoiceArmory" },
        { value = "BG_MB_BallTaken_OtherTeam", labelKey = "soundChoiceEnemyBall" },
        { value = "BG_MB_BallTaken_OwnTeam", labelKey = "soundChoiceAllyBall" },
        { value = "BG_Scoreboard_Next_Round", labelKey = "soundChoiceNextRound" },
        { value = "BG_Scoreboard_Previous_Round", labelKey = "soundChoicePrevRound" },
        { value = "Click_AllianceButton", labelKey = "soundChoiceAllianceBtn" },
        { value = "Click_CreateButton", labelKey = "soundChoiceCreate" },
        { value = "Lock_Value", labelKey = "soundChoiceLock" },
        { value = "Click_RandomizeButton", labelKey = "soundChoiceRandom" },
        { value = "Champion_PendingPointsCleared", labelKey = "soundChoiceClearPoints" },
        { value = "Champion_RespecToggled", labelKey = "soundChoiceRespec" },
        { value = "Champion_StarPickedUp", labelKey = "soundChoiceStar" },
    },
}

function DC.sound:GetSettings()
    return DC.storage:GetSettings()
end

function DC.sound:GetChoiceLabels()
    local labels = {}

    for _, entry in ipairs(self.choices) do
        table.insert(labels, DC:GetString(entry.labelKey or "soundChoiceOff"))
    end

    return labels
end

function DC.sound:GetChoiceValues()
    local values = {}

    for _, entry in ipairs(self.choices) do
        table.insert(values, entry.value)
    end

    return values
end

function DC.sound:GetSoundThrottle(hitInfo)
    local settings = self:GetSettings()
    local throttleMs = math.max(0, math.floor(tonumber(settings.soundThrottleMs) or 0))

    if hitInfo and hitInfo.isCritical then
        return math.max(0, math.floor(throttleMs * 0.5))
    end

    if hitInfo and (tonumber(hitInfo.amount) or 0) >= (settings.bigHitSoundThreshold or 30000) then
        return math.max(0, math.floor(throttleMs * 0.75))
    end

    return throttleMs
end

function DC.sound:CanPlay(hitInfo)
    local now = GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0
    local throttleMs = self:GetSoundThrottle(hitInfo)

    if throttleMs <= 0 or self.lastPlayAt <= 0 or (now - self.lastPlayAt) >= throttleMs then
        self.lastPlayAt = now
        return true
    end

    return false
end

function DC.sound:GetSoundIdForHit(hitInfo)
    local settings = self:GetSettings()
    local amount = math.max(0, math.floor(tonumber(hitInfo and hitInfo.amount) or 0))

    if hitInfo and hitInfo.isCritical then
        return settings.critHitSoundId or ""
    end

    if amount >= (settings.bigHitSoundThreshold or 30000) then
        return settings.bigHitSoundId or ""
    end

    return settings.normalHitSoundId or ""
end

function DC.sound:PlaySoundId(soundId)
    if soundId == nil or soundId == "" or type(PlaySound) ~= "function" then
        return
    end

    PlaySound(soundId)
end

function DC.sound:PreviewSoundId(soundId)
    self:PlaySoundId(soundId)
end

function DC.sound:PlayForHit(hitInfo)
    local settings = self:GetSettings()

    if not settings.enableHitSounds or hitInfo == nil then
        return
    end

    if not self:CanPlay(hitInfo) then
        return
    end

    self:PlaySoundId(self:GetSoundIdForHit(hitInfo))
end

function DC.sound:PreviewSequence()
    local settings = self:GetSettings()

    self:PlaySoundId(settings.normalHitSoundId)

    if type(zo_callLater) == "function" then
        zo_callLater(function()
            self:PlaySoundId(settings.bigHitSoundId)
        end, 180)

        zo_callLater(function()
            self:PlaySoundId(settings.critHitSoundId)
        end, 360)
    end
end
