DamageCalculation = DamageCalculation or {}

local DC = DamageCalculation

DC.name = "DamageCalculation"
DC.displayName = "Damage Calculation"
DC.version = "1.0.0"
DC.savedVariableName = "DamageCalculationSavedVariables"
DC.savedVariableVersion = 1

DC.languageModes = {
    AUTO = "auto",
    EN = "en",
    RU = "ru",
}

DC.formatModes = {
    FULL = "full",
    SCIENTIFIC = "scientific",
    SHORT = "short",
}

DC.displayModes = {
    TOTAL = "total",
    SESSION = "session",
}

DC.dpsModes = {
    COMPATIBLE = "compatible",
    AVERAGE = "average",
}

DC.fontFaces = {
    MEDIUM = "medium",
    BOLD = "bold",
    CHAT = "chat",
    ANTIQUE = "antique",
    TRAJAN = "trajan",
    HANDWRITTEN = "handwritten",
    GAMEPAD = "gamepad",
    GAMEPAD_BOLD = "gamepadBold",
}

DC.fontFacePaths = {
    [DC.fontFaces.MEDIUM] = "$(MEDIUM_FONT)",
    [DC.fontFaces.BOLD] = "$(BOLD_FONT)",
    [DC.fontFaces.CHAT] = "$(CHAT_FONT)",
    [DC.fontFaces.ANTIQUE] = "EsoUI/Common/Fonts/ProseAntiquePSMT.otf",
    [DC.fontFaces.TRAJAN] = "EsoUI/Common/Fonts/TrajanPro-Regular.otf",
    [DC.fontFaces.HANDWRITTEN] = "EsoUI/Common/Fonts/Handwritten_Bold.otf",
    [DC.fontFaces.GAMEPAD] = "EsoUI/Common/Fonts/FTN57.otf",
    [DC.fontFaces.GAMEPAD_BOLD] = "EsoUI/Common/Fonts/FTN87.otf",
}

DC.fontStyles = {
    NONE = "none",
    SHADOW = "shadow",
    SOFT_SHADOW = "soft-shadow-thin",
    SOFT_SHADOW_THICK = "soft-shadow-thick",
    OUTLINE = "outline",
    THICK_OUTLINE = "thick-outline",
}

DC.integrityStates = {
    VERIFIED = "verified",
    MODIFIED = "modified",
}

DC.metricKeys = {
    "damage",
    "received",
    "blocked",
    "healed",
    "dps",
    "combatTime",
}

DC.metricDefinitions = {
    damage = {
        labelKey = "hudDamageLabel",
        settingKey = "showDamageMetric",
        allowsPopup = true,
        allowsSound = true,
    },
    blocked = {
        labelKey = "hudBlockedLabel",
        settingKey = "showBlockedMetric",
        allowsPopup = false,
        allowsSound = false,
    },
    healed = {
        labelKey = "hudHealedLabel",
        settingKey = "showHealedMetric",
        allowsPopup = false,
        allowsSound = false,
    },
    received = {
        labelKey = "hudReceivedLabel",
        settingKey = "showReceivedMetric",
        allowsPopup = false,
        allowsSound = false,
    },
    dps = {
        labelKey = "hudDpsLabel",
        allowsPopup = false,
        allowsSound = false,
        isCompositeMetric = true,
    },
    combatTime = {
        labelKey = "hudCombatTimeLabel",
        allowsPopup = false,
        allowsSound = false,
        isTimeMetric = true,
    },
}

DC.damageResults = {
    ACTION_RESULT_DAMAGE,
    ACTION_RESULT_CRITICAL_DAMAGE,
    ACTION_RESULT_DOT_TICK,
    ACTION_RESULT_DOT_TICK_CRITICAL,
    ACTION_RESULT_BLOCKED_DAMAGE,
}

DC.healResults = {
    ACTION_RESULT_HEAL,
    ACTION_RESULT_CRITICAL_HEAL,
    ACTION_RESULT_HOT_TICK,
    ACTION_RESULT_HOT_TICK_CRITICAL,
}

DC.killResults = {
    ACTION_RESULT_KILLING_BLOW,
    ACTION_RESULT_DIED,
    ACTION_RESULT_DIED_XP,
}

DC.combatResults = {
    ACTION_RESULT_DAMAGE,
    ACTION_RESULT_CRITICAL_DAMAGE,
    ACTION_RESULT_DOT_TICK,
    ACTION_RESULT_DOT_TICK_CRITICAL,
    ACTION_RESULT_BLOCKED_DAMAGE,
    ACTION_RESULT_HEAL,
    ACTION_RESULT_CRITICAL_HEAL,
    ACTION_RESULT_HOT_TICK,
    ACTION_RESULT_HOT_TICK_CRITICAL,
    ACTION_RESULT_KILLING_BLOW,
    ACTION_RESULT_DIED,
    ACTION_RESULT_DIED_XP,
}

function DC:GetClientLanguage()
    local rawLanguage = ""

    if type(GetCVar) == "function" then
        rawLanguage = string.lower(GetCVar("language.2") or "")
    end

    if rawLanguage == self.languageModes.RU then
        return self.languageModes.RU
    end

    return self.languageModes.EN
end

function DC:GetLanguageCode()
    local preferredLanguage = self.languageModes.AUTO

    if self.storage and self.storage.GetSettings then
        preferredLanguage = self.storage:GetSettings().language or self.languageModes.AUTO
    end

    if preferredLanguage == self.languageModes.EN or preferredLanguage == self.languageModes.RU then
        return preferredLanguage
    end

    return self:GetClientLanguage()
end

function DC:GetString(key, ...)
    if not self.localization or not self.localization.GetString then
        return key
    end

    return self.localization:GetString(key, ...)
end

function DC:Print(message)
    if message == nil or message == "" then
        return
    end

    local formattedMessage = string.format("|cF6C453[%s]|r %s", self.displayName, tostring(message))

    if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
        CHAT_ROUTER:AddSystemMessage(formattedMessage)
        return
    end

    if d then
        d(formattedMessage)
    end
end

function DC:RefreshDisplay()
    if self.hud and self.hud.Refresh then
        self.hud:Refresh()
    end

    if self.tooltip and self.tooltip.Refresh then
        self.tooltip:Refresh()
    end
end

function DC:OnMetricAdded(metricKey, eventInfo)
    if self.hud and self.hud.OnMetricAdded then
        self.hud:OnMetricAdded(metricKey, eventInfo)
    end

    if self.tooltip and self.tooltip.OnMetricAdded then
        self.tooltip:OnMetricAdded(metricKey, eventInfo)
    end
end

function DC:OnDamageAdded(hitInfo)
    self:OnMetricAdded("damage", hitInfo)
end

function DC:OnKillAdded(killInfo)
    if self.hud and self.hud.OnKillAdded then
        self.hud:OnKillAdded(killInfo)
    end

    if self.tooltip and self.tooltip.OnKillAdded then
        self.tooltip:OnKillAdded(killInfo)
    end
end

function DC:RefreshSettings()
    if self.settings and self.settings.RefreshPanel then
        self.settings:RefreshPanel()
    end
end

function DC:RefreshAll()
    self:RefreshDisplay()
    self:RefreshSettings()
end

function DC:InitializeSlashCommands()
    local function handleSlashCommand(text)
        local command = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
        command = string.lower(command)

        if command == "" or command == "help" then
            self:Print(self:GetString("chatHelp"))
            return
        end

        if command == "settings" then
            if self.settings and self.settings.OpenPanel then
                self.settings:OpenPanel()
            end
            return
        end

        if command == "reset" then
            self.storage:ResetTotal(true)
            self:RefreshAll()
            self:Print(self:GetString("chatResetDone"))
            return
        end

        if command == "lock" then
            self.storage:SetSetting("lockWindow", true)
            self:RefreshAll()
            self:Print(self:GetString("chatWindowLocked"))
            return
        end

        if command == "unlock" then
            self.storage:SetSetting("lockWindow", false)
            self:RefreshAll()
            self:Print(self:GetString("chatWindowUnlocked"))
            return
        end

        if command == "status" then
            local damageValue = self.storage:GetMetricTotal("damage")
            local receivedValue = self.storage:GetMetricTotal("received")
            local blockedValue = self.storage:GetMetricTotal("blocked")
            local healedValue = self.storage:GetMetricTotal("healed")
            local formattedDamage = self.formatter:Format(damageValue)
            local formattedReceived = self.formatter:Format(receivedValue)
            local formattedBlocked = self.formatter:Format(blockedValue)
            local formattedHealed = self.formatter:Format(healedValue)
            local integrityText = self.storage:GetIntegrityStatusText()

            self:Print(self:GetString("chatStatus", formattedDamage, formattedReceived, formattedBlocked, formattedHealed, integrityText))
            return
        end

        self:Print(self:GetString("chatUnknownCommand"))
    end

    SLASH_COMMANDS["/damagecalc"] = handleSlashCommand
    SLASH_COMMANDS["/dcalc"] = handleSlashCommand
end

function DC:Initialize()
    self.storage:Initialize()
    self.dps:Initialize()
    self.hud:Initialize()
    self.tooltip:Initialize()
    self.settings:Initialize()
    self.combatTracker:Initialize()
    self:InitializeSlashCommands()
    self:RefreshAll()

    if self.storage:IsModified() then
        self:Print(self:GetString("chatIntegrityWarning"))
    end

    self:Print(self:GetString("chatLoaded"))
end

local function OnAddonLoaded(_, addonName)
    if addonName ~= DC.name then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(DC.name, EVENT_ADD_ON_LOADED)
    DC:Initialize()
end

EVENT_MANAGER:RegisterForEvent(DC.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)
