local DC = DamageCalculation

DC.settings = {
    panelId = DC.name .. "Options",
}

function DC.settings:RefreshPanel()
    if self.panel and self.panel.RefreshPanel then
        self.panel:RefreshPanel()
    end
end

function DC.settings:OpenPanel()
    if not self.panel or not LibAddonMenu2 or not LibAddonMenu2.OpenToPanel then
        return
    end

    SCENE_MANAGER:Show("gameMenuInGame")
    LibAddonMenu2:OpenToPanel(self.panel)
    LibAddonMenu2:OpenToPanel(self.panel)
end

function DC.settings:Initialize()
    local LAM = LibAddonMenu2
    local defaults = DC.storage.defaults.settings

    if not LAM then
        DC:Print(DC:GetString("chatLamMissing"))
        return
    end

    local panelData = {
        type = "panel",
        name = DC:GetString("menuPanelName"),
        displayName = DC:GetString("menuPanelName"),
        author = DC:GetString("menuPanelAuthor"),
        version = DC.version,
        slashCommand = "/damagecalcsettings",
        registerForRefresh = true,
        registerForDefaults = false,
    }

    local formatChoices = {
        DC:GetString("formatFull"),
        DC:GetString("formatScientific"),
        DC:GetString("formatShort"),
    }

    local formatValues = {
        DC.formatModes.FULL,
        DC.formatModes.SCIENTIFIC,
        DC.formatModes.SHORT,
    }

    local languageChoices = {
        DC:GetString("languageAuto"),
        DC:GetString("languageEnglish"),
        DC:GetString("languageRussian"),
    }

    local languageValues = {
        DC.languageModes.AUTO,
        DC.languageModes.EN,
        DC.languageModes.RU,
    }

    local fontFaceChoices = {
        DC:GetString("fontFaceMedium"),
        DC:GetString("fontFaceBold"),
        DC:GetString("fontFaceChat"),
        DC:GetString("fontFaceAntique"),
        DC:GetString("fontFaceTrajan"),
        DC:GetString("fontFaceHandwritten"),
        DC:GetString("fontFaceGamepad"),
        DC:GetString("fontFaceGamepadBold"),
    }

    local fontFaceValues = {
        DC.fontFaces.MEDIUM,
        DC.fontFaces.BOLD,
        DC.fontFaces.CHAT,
        DC.fontFaces.ANTIQUE,
        DC.fontFaces.TRAJAN,
        DC.fontFaces.HANDWRITTEN,
        DC.fontFaces.GAMEPAD,
        DC.fontFaces.GAMEPAD_BOLD,
    }

    local fontStyleChoices = {
        DC:GetString("fontStyleNone"),
        DC:GetString("fontStyleShadow"),
        DC:GetString("fontStyleSoftShadow"),
        DC:GetString("fontStyleSoftShadowThick"),
        DC:GetString("fontStyleOutline"),
        DC:GetString("fontStyleThickOutline"),
    }

    local fontStyleValues = {
        DC.fontStyles.NONE,
        DC.fontStyles.SHADOW,
        DC.fontStyles.SOFT_SHADOW,
        DC.fontStyles.SOFT_SHADOW_THICK,
        DC.fontStyles.OUTLINE,
        DC.fontStyles.THICK_OUTLINE,
    }

    local popupAnchorChoices = {
        DC:GetString("popupAnchorLeft"),
        DC:GetString("popupAnchorCenter"),
        DC:GetString("popupAnchorRight"),
    }

    local popupAnchorValues = {
        "left",
        "center",
        "right",
    }

    local valueLayoutChoices = {
        DC:GetString("valueLayoutSeparate"),
        DC:GetString("valueLayoutInlineRight"),
    }

    local valueLayoutValues = {
        "separate",
        "inlineRight",
    }

    local displayModeChoices = {
        DC:GetString("displayModeTotal"),
        DC:GetString("displayModeSession"),
    }

    local displayModeValues = {
        DC.displayModes.TOTAL,
        DC.displayModes.SESSION,
    }

    local dpsModeChoices = {
        DC:GetString("dpsModeCompatible"),
        DC:GetString("dpsModeAverage"),
    }

    local dpsModeValues = {
        DC.dpsModes.COMPATIBLE,
        DC.dpsModes.AVERAGE,
    }

    local graphModeChoices = {
        DC:GetString("graphModeTrend"),
        DC:GetString("graphModeBurst"),
        DC:GetString("graphModeRolling"),
    }

    local graphModeValues = {
        DC.graphModes.TREND,
        DC.graphModes.BURST,
        DC.graphModes.ROLLING,
    }

    local soundChoiceLabels = DC.sound:GetChoiceLabels()
    local soundChoiceValues = DC.sound:GetChoiceValues()

    local optionsTable = {
        {
            type = "header",
            name = function()
                return DC:GetString("menuHeaderDisplay")
            end,
            width = "full",
        },
        {
            type = "checkbox",
            name = function()
                return DC:GetString("menuShowHudName")
            end,
            tooltip = function()
                return DC:GetString("menuShowHudTooltip")
            end,
            getFunc = function()
                return DC.storage:GetSettings().showHud
            end,
            setFunc = function(value)
                DC.storage:SetSetting("showHud", value)
                DC:RefreshAll()
            end,
            default = defaults.showHud,
            width = "full",
        },
        {
            type = "dropdown",
            name = function()
                return DC:GetString("menuDisplayModeName")
            end,
            tooltip = function()
                return DC:GetString("menuDisplayModeTooltip")
            end,
            choices = displayModeChoices,
            choicesValues = displayModeValues,
            getFunc = function()
                return DC.storage:GetSettings().displayMode
            end,
            setFunc = function(value)
                DC.storage:SetSetting("displayMode", value)
                DC:RefreshAll()
            end,
            default = defaults.displayMode,
            width = "full",
        },
        {
            type = "description",
            text = function()
                return DC:GetString("menuDisplayModeDescription")
            end,
            width = "full",
        },
        {
            type = "dropdown",
            name = function()
                return DC:GetString("menuDpsModeName")
            end,
            tooltip = function()
                return DC:GetString("menuDpsModeTooltip")
            end,
            choices = dpsModeChoices,
            choicesValues = dpsModeValues,
            getFunc = function()
                return DC.storage:GetSettings().dpsMode
            end,
            setFunc = function(value)
                DC.storage:SetSetting("dpsMode", value)
                DC:RefreshAll()
            end,
            default = defaults.dpsMode,
            width = "full",
        },
        {
            type = "checkbox",
            name = function()
                return DC:GetString("menuDpsGraphAutoShowName")
            end,
            tooltip = function()
                return DC:GetString("menuDpsGraphAutoShowTooltip")
            end,
            getFunc = function()
                return DC.storage:GetSettings().dpsGraphAutoShowInCombat
            end,
            setFunc = function(value)
                local allowAutoShow = DC.storage:GetSettings().showLargeDpsGraph ~= false
                DC.storage:SetSetting("dpsGraphAutoShowInCombat", allowAutoShow and value or false)
                DC:RefreshAll()
            end,
            default = defaults.dpsGraphAutoShowInCombat,
            width = "full",
            disabled = function()
                return DC.storage:GetSettings().showLargeDpsGraph == false
            end,
        },
        {
            type = "checkbox",
            name = function()
                return DC:GetString("menuShowMiniDpsGraphName")
            end,
            tooltip = function()
                return DC:GetString("menuShowMiniDpsGraphTooltip")
            end,
            getFunc = function()
                return DC.storage:GetSettings().showMiniDpsGraph
            end,
            setFunc = function(value)
                DC.storage:SetSetting("showMiniDpsGraph", value)
                DC:RefreshAll()
            end,
            default = defaults.showMiniDpsGraph,
            width = "full",
        },
        {
            type = "checkbox",
            name = function()
                return DC:GetString("menuShowLargeDpsGraphName")
            end,
            tooltip = function()
                return DC:GetString("menuShowLargeDpsGraphTooltip")
            end,
            getFunc = function()
                return DC.storage:GetSettings().showLargeDpsGraph
            end,
            setFunc = function(value)
                DC.storage:SetSetting("showLargeDpsGraph", value)
                if not value then
                    DC.storage:SetSetting("dpsGraphAutoShowInCombat", false)
                end
                DC:RefreshAll()
            end,
            default = defaults.showLargeDpsGraph,
            width = "full",
        },
        {
            type = "dropdown",
            name = function()
                return DC:GetString("menuDpsGraphModeName")
            end,
            tooltip = function()
                return DC:GetString("menuDpsGraphModeTooltip")
            end,
            choices = graphModeChoices,
            choicesValues = graphModeValues,
            getFunc = function()
                return DC.storage:GetSettings().dpsGraphMode
            end,
            setFunc = function(value)
                DC.storage:SetSetting("dpsGraphMode", value)
                DC:RefreshAll()
            end,
            default = defaults.dpsGraphMode,
            width = "full",
        },
        {
            type = "slider",
            name = function()
                return DC:GetString("menuDpsGraphPointCountName")
            end,
            tooltip = function()
                return DC:GetString("menuDpsGraphPointCountTooltip")
            end,
            min = DC.dpsGraphPointLimits.min,
            max = DC.dpsGraphPointLimits.max,
            step = 10,
            getFunc = function()
                return DC:GetDpsGraphPointCount()
            end,
            setFunc = function(value)
                DC.storage:SetSetting("dpsGraphPointCount", DC:ClampDpsGraphPointCount(value))

                if DC.dps and DC.dps.TrimAllGraphHistories then
                    DC.dps:TrimAllGraphHistories()
                end

                DC:RefreshAll()
            end,
            default = defaults.dpsGraphPointCount,
            width = "full",
        },
        {
            type = "checkbox",
            name = function()
                return DC:GetString("menuShowLabelName")
            end,
            tooltip = function()
                return DC:GetString("menuShowLabelTooltip")
            end,
            getFunc = function()
                return DC.storage:GetSettings().showLabel
            end,
            setFunc = function(value)
                DC.storage:SetSetting("showLabel", value)
                DC:RefreshAll()
            end,
            default = defaults.showLabel,
            width = "full",
        },
        {
            type = "checkbox",
            name = function()
                return DC:GetString("menuShowDamageMetricName")
            end,
            tooltip = function()
                return DC:GetString("menuShowDamageMetricTooltip")
            end,
            getFunc = function()
                return DC.storage:GetSettings().showDamageMetric
            end,
            setFunc = function(value)
                DC.storage:SetSetting("showDamageMetric", value)
                DC:RefreshAll()
            end,
            default = defaults.showDamageMetric,
            width = "half",
        },
        {
            type = "checkbox",
            name = function()
                return DC:GetString("menuShowReceivedMetricName")
            end,
            tooltip = function()
                return DC:GetString("menuShowReceivedMetricTooltip")
            end,
            getFunc = function()
                return DC.storage:GetSettings().showReceivedMetric
            end,
            setFunc = function(value)
                DC.storage:SetSetting("showReceivedMetric", value)
                DC:RefreshAll()
            end,
            default = defaults.showReceivedMetric,
            width = "half",
        },
        {
            type = "checkbox",
            name = function()
                return DC:GetString("menuShowBlockedMetricName")
            end,
            tooltip = function()
                return DC:GetString("menuShowBlockedMetricTooltip")
            end,
            getFunc = function()
                return DC.storage:GetSettings().showBlockedMetric
            end,
            setFunc = function(value)
                DC.storage:SetSetting("showBlockedMetric", value)
                DC:RefreshAll()
            end,
            default = defaults.showBlockedMetric,
            width = "half",
        },
        {
            type = "checkbox",
            name = function()
                return DC:GetString("menuShowHealedMetricName")
            end,
            tooltip = function()
                return DC:GetString("menuShowHealedMetricTooltip")
            end,
            getFunc = function()
                return DC.storage:GetSettings().showHealedMetric
            end,
            setFunc = function(value)
                DC.storage:SetSetting("showHealedMetric", value)
                DC:RefreshAll()
            end,
            default = defaults.showHealedMetric,
            width = "half",
        },
        {
            type = "dropdown",
            name = function()
                return DC:GetString("menuValueLayoutName")
            end,
            tooltip = function()
                return DC:GetString("menuValueLayoutTooltip")
            end,
            choices = valueLayoutChoices,
            choicesValues = valueLayoutValues,
            getFunc = function()
                return DC.storage:GetSettings().valueLayoutMode
            end,
            setFunc = function(value)
                DC.storage:SetSetting("valueLayoutMode", value)
                DC:RefreshAll()
            end,
            default = defaults.valueLayoutMode,
            width = "full",
            disabled = function()
                return not DC.storage:GetSettings().showLabel
            end,
        },
        {
            type = "checkbox",
            name = function()
                return DC:GetString("menuLockWindowName")
            end,
            tooltip = function()
                return DC:GetString("menuLockWindowTooltip")
            end,
            getFunc = function()
                return DC.storage:GetSettings().lockWindow
            end,
            setFunc = function(value)
                DC.storage:SetSetting("lockWindow", value)
                DC:RefreshAll()
            end,
            default = defaults.lockWindow,
            width = "full",
        },
        {
            type = "description",
            text = function()
                return DC:GetString("menuMoveHint")
            end,
            width = "full",
        },
        {
            type = "slider",
            name = function()
                return DC:GetString("menuHudWidthName")
            end,
            tooltip = function()
                return DC:GetString("menuHudWidthTooltip")
            end,
            min = 250,
            max = 400,
            step = 10,
            getFunc = function()
                return DC.storage:GetSettings().hudWidth
            end,
            setFunc = function(value)
                DC.storage:SetSetting("hudWidth", value)
                DC:RefreshAll()
            end,
            default = defaults.hudWidth,
            width = "full",
        },
        {
            type = "slider",
            name = function()
                return DC:GetString("menuScaleName")
            end,
            tooltip = function()
                return DC:GetString("menuScaleTooltip")
            end,
            min = 0.5,
            max = 1.5,
            step = 0.05,
            getFunc = function()
                return DC.storage:GetSettings().scale
            end,
            setFunc = function(value)
                DC.storage:SetSetting("scale", value)
                DC:RefreshAll()
            end,
            default = defaults.scale,
            width = "full",
        },
        {
            type = "slider",
            name = function()
                return DC:GetString("menuLabelWidthName")
            end,
            tooltip = function()
                return DC:GetString("menuLabelWidthTooltip")
            end,
            min = 40,
            max = 400,
            step = 5,
            getFunc = function()
                return DC.storage:GetSettings().labelAreaWidth
            end,
            setFunc = function(value)
                DC.storage:SetSetting("labelAreaWidth", value)
                DC:RefreshAll()
            end,
            default = defaults.labelAreaWidth,
            width = "half",
            disabled = function()
                local settings = DC.storage:GetSettings()
                return not settings.showLabel or settings.valueLayoutMode ~= "separate"
            end,
        },
        {
            type = "checkbox",
            name = function()
                return DC:GetString("menuShowBackgroundName")
            end,
            tooltip = function()
                return DC:GetString("menuShowBackgroundTooltip")
            end,
            getFunc = function()
                return DC.storage:GetSettings().showBackground
            end,
            setFunc = function(value)
                DC.storage:SetSetting("showBackground", value)
                DC:RefreshAll()
            end,
            default = defaults.showBackground,
            width = "half",
        },
        {
            type = "checkbox",
            name = function()
                return DC:GetString("menuShowBorderName")
            end,
            tooltip = function()
                return DC:GetString("menuShowBorderTooltip")
            end,
            getFunc = function()
                return DC.storage:GetSettings().showBorder
            end,
            setFunc = function(value)
                DC.storage:SetSetting("showBorder", value)
                DC:RefreshAll()
            end,
            default = defaults.showBorder,
            width = "half",
        },
        {
            type = "dropdown",
            name = function()
                return DC:GetString("menuFormatName")
            end,
            tooltip = function()
                return DC:GetString("menuFormatTooltip")
            end,
            choices = formatChoices,
            choicesValues = formatValues,
            getFunc = function()
                return DC.storage:GetSettings().formatMode
            end,
            setFunc = function(value)
                DC.storage:SetSetting("formatMode", value)
                DC:RefreshAll()
            end,
            default = defaults.formatMode,
            width = "full",
        },
        {
            type = "dropdown",
            name = function()
                return DC:GetString("menuLanguageName")
            end,
            tooltip = function()
                return DC:GetString("menuLanguageTooltip")
            end,
            choices = languageChoices,
            choicesValues = languageValues,
            getFunc = function()
                return DC.storage:GetSettings().language
            end,
            setFunc = function(value)
                DC.storage:SetSetting("language", value)
                DC:RefreshAll()
            end,
            default = defaults.language,
            width = "full",
        },
        {
            type = "header",
            name = function()
                return DC:GetString("menuHeaderFonts")
            end,
            width = "full",
        },
        {
            type = "dropdown",
            name = function()
                return DC:GetString("menuFontStyleName")
            end,
            tooltip = function()
                return DC:GetString("menuFontStyleTooltip")
            end,
            choices = fontStyleChoices,
            choicesValues = fontStyleValues,
            getFunc = function()
                return DC.storage:GetSettings().fontStyle
            end,
            setFunc = function(value)
                DC.storage:SetSetting("fontStyle", value)
                DC:RefreshAll()
            end,
            default = defaults.fontStyle,
            width = "full",
        },
        {
            type = "dropdown",
            name = function()
                return DC:GetString("menuLabelFontName")
            end,
            tooltip = function()
                return DC:GetString("menuLabelFontTooltip")
            end,
            choices = fontFaceChoices,
            choicesValues = fontFaceValues,
            getFunc = function()
                return DC.storage:GetSettings().labelFontFace
            end,
            setFunc = function(value)
                DC.storage:SetSetting("labelFontFace", value)
                DC:RefreshAll()
            end,
            default = defaults.labelFontFace,
            width = "half",
        },
        {
            type = "dropdown",
            name = function()
                return DC:GetString("menuValueFontName")
            end,
            tooltip = function()
                return DC:GetString("menuValueFontTooltip")
            end,
            choices = fontFaceChoices,
            choicesValues = fontFaceValues,
            getFunc = function()
                return DC.storage:GetSettings().valueFontFace
            end,
            setFunc = function(value)
                DC.storage:SetSetting("valueFontFace", value)
                DC:RefreshAll()
            end,
            default = defaults.valueFontFace,
            width = "half",
        },
        {
            type = "slider",
            name = function()
                return DC:GetString("menuLabelSizeName")
            end,
            tooltip = function()
                return DC:GetString("menuLabelSizeTooltip")
            end,
            min = 12,
            max = 22,
            step = 1,
            getFunc = function()
                return DC.storage:GetSettings().labelFontSize
            end,
            setFunc = function(value)
                DC.storage:SetSetting("labelFontSize", value)
                DC:RefreshAll()
            end,
            default = defaults.labelFontSize,
            width = "half",
        },
        {
            type = "slider",
            name = function()
                return DC:GetString("menuValueSizeName")
            end,
            tooltip = function()
                return DC:GetString("menuValueSizeTooltip")
            end,
            min = 14,
            max = 22,
            step = 1,
            getFunc = function()
                return DC.storage:GetSettings().valueFontSize
            end,
            setFunc = function(value)
                DC.storage:SetSetting("valueFontSize", value)
                DC:RefreshAll()
            end,
            default = defaults.valueFontSize,
            width = "half",
        },
        {
            type = "colorpicker",
            name = function()
                return DC:GetString("menuLabelColorName")
            end,
            tooltip = function()
                return DC:GetString("menuLabelColorTooltip")
            end,
            getFunc = function()
                local settings = DC.storage:GetSettings()
                return settings.labelColorR, settings.labelColorG, settings.labelColorB, settings.labelColorA
            end,
            setFunc = function(r, g, b, a)
                DC.storage:SetSetting("labelColorR", r)
                DC.storage:SetSetting("labelColorG", g)
                DC.storage:SetSetting("labelColorB", b)
                DC.storage:SetSetting("labelColorA", a)
                DC:RefreshAll()
            end,
            default = { defaults.labelColorR, defaults.labelColorG, defaults.labelColorB, defaults.labelColorA },
            width = "half",
        },
        {
            type = "colorpicker",
            name = function()
                return DC:GetString("menuValueColorName")
            end,
            tooltip = function()
                return DC:GetString("menuValueColorTooltip")
            end,
            getFunc = function()
                local settings = DC.storage:GetSettings()
                return settings.valueColorR, settings.valueColorG, settings.valueColorB, settings.valueColorA
            end,
            setFunc = function(r, g, b, a)
                DC.storage:SetSetting("valueColorR", r)
                DC.storage:SetSetting("valueColorG", g)
                DC.storage:SetSetting("valueColorB", b)
                DC.storage:SetSetting("valueColorA", a)
                DC:RefreshAll()
            end,
            default = { defaults.valueColorR, defaults.valueColorG, defaults.valueColorB, defaults.valueColorA },
            width = "half",
        },
        {
            type = "slider",
            name = function()
                return DC:GetString("menuStatusSizeName")
            end,
            tooltip = function()
                return DC:GetString("menuStatusSizeTooltip")
            end,
            min = 12,
            max = 16,
            step = 1,
            getFunc = function()
                return DC.storage:GetSettings().statusFontSize
            end,
            setFunc = function(value)
                DC.storage:SetSetting("statusFontSize", value)
                DC:RefreshAll()
            end,
            default = defaults.statusFontSize,
            width = "half",
        },
        {
            type = "slider",
            name = function()
                return DC:GetString("menuTooltipSizeName")
            end,
            tooltip = function()
                return DC:GetString("menuTooltipSizeTooltip")
            end,
            min = 12,
            max = 22,
            step = 1,
            getFunc = function()
                return DC.storage:GetSettings().tooltipFontSize
            end,
            setFunc = function(value)
                DC.storage:SetSetting("tooltipFontSize", value)
                DC:RefreshAll()
            end,
            default = defaults.tooltipFontSize,
            width = "half",
        },
        {
            type = "dropdown",
            name = function()
                return DC:GetString("menuPopupFontName")
            end,
            tooltip = function()
                return DC:GetString("menuPopupFontTooltip")
            end,
            choices = fontFaceChoices,
            choicesValues = fontFaceValues,
            getFunc = function()
                return DC.storage:GetSettings().popupFontFace
            end,
            setFunc = function(value)
                DC.storage:SetSetting("popupFontFace", value)
                DC:RefreshAll()
            end,
            default = defaults.popupFontFace,
            width = "half",
        },
        {
            type = "slider",
            name = function()
                return DC:GetString("menuHitFontSizeName")
            end,
            tooltip = function()
                return DC:GetString("menuHitFontSizeTooltip")
            end,
            min = 14,
            max = 22,
            step = 1,
            getFunc = function()
                return DC.storage:GetSettings().hitFontSize
            end,
            setFunc = function(value)
                DC.storage:SetSetting("hitFontSize", value)
                DC:RefreshAll()
            end,
            default = defaults.hitFontSize,
            width = "half",
        },
        {
            type = "header",
            name = function()
                return DC:GetString("menuHeaderEffects")
            end,
            width = "full",
        },
        {
            type = "checkbox",
            name = function()
                return DC:GetString("menuAnimateCounterName")
            end,
            tooltip = function()
                return DC:GetString("menuAnimateCounterTooltip")
            end,
            getFunc = function()
                return DC.storage:GetSettings().animateCounter
            end,
            setFunc = function(value)
                DC.storage:SetSetting("animateCounter", value)
                DC:RefreshAll()
            end,
            default = defaults.animateCounter,
            width = "full",
        },
        {
            type = "slider",
            name = function()
                return DC:GetString("menuCounterDurationName")
            end,
            tooltip = function()
                return DC:GetString("menuCounterDurationTooltip")
            end,
            min = 80,
            max = 1200,
            step = 10,
            getFunc = function()
                return DC.storage:GetSettings().counterAnimationMs
            end,
            setFunc = function(value)
                DC.storage:SetSetting("counterAnimationMs", value)
            end,
            default = defaults.counterAnimationMs,
            width = "full",
            disabled = function()
                return not DC.storage:GetSettings().animateCounter
            end,
        },
        {
            type = "checkbox",
            name = function()
                return DC:GetString("menuShowHitPopupName")
            end,
            tooltip = function()
                return DC:GetString("menuShowHitPopupTooltip")
            end,
            getFunc = function()
                return DC.storage:GetSettings().showHitPopup
            end,
            setFunc = function(value)
                DC.storage:SetSetting("showHitPopup", value)
            end,
            default = defaults.showHitPopup,
            width = "full",
        },
        {
            type = "checkbox",
            name = function()
                return DC:GetString("menuEnableHitSoundsName")
            end,
            tooltip = function()
                return DC:GetString("menuEnableHitSoundsTooltip")
            end,
            getFunc = function()
                return DC.storage:GetSettings().enableHitSounds
            end,
            setFunc = function(value)
                DC.storage:SetSetting("enableHitSounds", value)
            end,
            default = defaults.enableHitSounds,
            width = "full",
        },
        {
            type = "dropdown",
            name = function()
                return DC:GetString("menuNormalHitSoundName")
            end,
            tooltip = function()
                return DC:GetString("menuNormalHitSoundTooltip")
            end,
            choices = soundChoiceLabels,
            choicesValues = soundChoiceValues,
            getFunc = function()
                return DC.storage:GetSettings().normalHitSoundId
            end,
            setFunc = function(value)
                DC.storage:SetSetting("normalHitSoundId", value)
                DC.sound:PreviewSoundId(value)
            end,
            default = defaults.normalHitSoundId,
            width = "half",
            disabled = function()
                return not DC.storage:GetSettings().enableHitSounds
            end,
        },
        {
            type = "dropdown",
            name = function()
                return DC:GetString("menuBigHitSoundName")
            end,
            tooltip = function()
                return DC:GetString("menuBigHitSoundTooltip")
            end,
            choices = soundChoiceLabels,
            choicesValues = soundChoiceValues,
            getFunc = function()
                return DC.storage:GetSettings().bigHitSoundId
            end,
            setFunc = function(value)
                DC.storage:SetSetting("bigHitSoundId", value)
                DC.sound:PreviewSoundId(value)
            end,
            default = defaults.bigHitSoundId,
            width = "half",
            disabled = function()
                return not DC.storage:GetSettings().enableHitSounds
            end,
        },
        {
            type = "dropdown",
            name = function()
                return DC:GetString("menuCritHitSoundName")
            end,
            tooltip = function()
                return DC:GetString("menuCritHitSoundTooltip")
            end,
            choices = soundChoiceLabels,
            choicesValues = soundChoiceValues,
            getFunc = function()
                return DC.storage:GetSettings().critHitSoundId
            end,
            setFunc = function(value)
                DC.storage:SetSetting("critHitSoundId", value)
                DC.sound:PreviewSoundId(value)
            end,
            default = defaults.critHitSoundId,
            width = "half",
            disabled = function()
                return not DC.storage:GetSettings().enableHitSounds
            end,
        },
        {
            type = "button",
            name = function()
                return DC:GetString("menuPreviewSoundsName")
            end,
            tooltip = function()
                return DC:GetString("menuPreviewSoundsTooltip")
            end,
            func = function()
                DC.sound:PreviewSequence()
            end,
            width = "half",
            disabled = function()
                return not DC.storage:GetSettings().enableHitSounds
            end,
        },
        {
            type = "slider",
            name = function()
                return DC:GetString("menuBigHitThresholdName")
            end,
            tooltip = function()
                return DC:GetString("menuBigHitThresholdTooltip")
            end,
            min = 10000,
            max = DC.hitThresholds.huge,
            step = 1000,
            getFunc = function()
                return DC.storage:GetSettings().bigHitSoundThreshold
            end,
            setFunc = function(value)
                DC.storage:SetSetting("bigHitSoundThreshold", value)
            end,
            default = defaults.bigHitSoundThreshold,
            width = "full",
            disabled = function()
                return not DC.storage:GetSettings().enableHitSounds
            end,
        },
        {
            type = "slider",
            name = function()
                return DC:GetString("menuSoundThrottleName")
            end,
            tooltip = function()
                return DC:GetString("menuSoundThrottleTooltip")
            end,
            min = 0,
            max = 300,
            step = 10,
            getFunc = function()
                return DC.storage:GetSettings().soundThrottleMs
            end,
            setFunc = function(value)
                DC.storage:SetSetting("soundThrottleMs", value)
            end,
            default = defaults.soundThrottleMs,
            width = "full",
            disabled = function()
                return not DC.storage:GetSettings().enableHitSounds
            end,
        },
        {
            type = "dropdown",
            name = function()
                return DC:GetString("menuPopupAnchorName")
            end,
            tooltip = function()
                return DC:GetString("menuPopupAnchorTooltip")
            end,
            choices = popupAnchorChoices,
            choicesValues = popupAnchorValues,
            getFunc = function()
                return DC.storage:GetSettings().popupAnchor
            end,
            setFunc = function(value)
                DC.storage:SetSetting("popupAnchor", value)
                DC:RefreshAll()
            end,
            default = defaults.popupAnchor,
            width = "half",
            disabled = function()
                return not DC.storage:GetSettings().showHitPopup
            end,
        },
        {
            type = "checkbox",
            name = function()
                return DC:GetString("menuPopupOnlyCritName")
            end,
            tooltip = function()
                return DC:GetString("menuPopupOnlyCritTooltip")
            end,
            getFunc = function()
                return DC.storage:GetSettings().popupOnlyCrit
            end,
            setFunc = function(value)
                DC.storage:SetSetting("popupOnlyCrit", value)
            end,
            default = defaults.popupOnlyCrit,
            width = "full",
            disabled = function()
                return not DC.storage:GetSettings().showHitPopup
            end,
        },
        {
            type = "slider",
            name = function()
                return DC:GetString("menuPopupDurationName")
            end,
            tooltip = function()
                return DC:GetString("menuPopupDurationTooltip")
            end,
            min = 300,
            max = 1000,
            step = 50,
            getFunc = function()
                return DC.storage:GetSettings().popupDurationMs
            end,
            setFunc = function(value)
                DC.storage:SetSetting("popupDurationMs", value)
            end,
            default = defaults.popupDurationMs,
            width = "full",
            disabled = function()
                return not DC.storage:GetSettings().showHitPopup
            end,
        },
        {
            type = "header",
            name = function()
                return DC:GetString("menuHeaderTracking")
            end,
            width = "full",
        },
        {
            type = "checkbox",
            name = function()
                return DC:GetString("menuIncludePetsName")
            end,
            tooltip = function()
                return DC:GetString("menuIncludePetsTooltip")
            end,
            getFunc = function()
                return DC.storage:GetSettings().includePetDamage
            end,
            setFunc = function(value)
                DC.storage:SetSetting("includePetDamage", value)
            end,
            default = defaults.includePetDamage,
            width = "full",
        },
        {
            type = "header",
            name = function()
                return DC:GetString("menuHeaderIntegrity")
            end,
            width = "full",
        },
        {
            type = "checkbox",
            name = function()
                return DC:GetString("menuShowVerifiedName")
            end,
            tooltip = function()
                return DC:GetString("menuShowVerifiedTooltip")
            end,
            getFunc = function()
                return DC.storage:GetSettings().showIntegrity
            end,
            setFunc = function(value)
                DC.storage:SetSetting("showIntegrity", value)
                DC:RefreshAll()
            end,
            default = defaults.showIntegrity,
            width = "full",
        },
        {
            type = "description",
            text = function()
                return DC:GetString("menuStatusDescription", DC.storage:GetIntegrityStatusText())
            end,
            width = "full",
        },
        {
            type = "header",
            name = function()
                return DC:GetString("menuHeaderActions")
            end,
            width = "full",
        },
        {
            type = "button",
            name = function()
                return DC:GetString("menuResetSettingsName")
            end,
            tooltip = function()
                return DC:GetString("menuResetSettingsTooltip")
            end,
            warning = function()
                return DC:GetString("menuResetSettingsWarning")
            end,
            isDangerous = true,
            func = function()
                DC.storage:ResetSettings()
                DC:RefreshAll()
                DC:Print(DC:GetString("chatSettingsReset"))
            end,
            width = "half",
        },
        {
            type = "button",
            name = function()
                return DC:GetString("menuResetTotalName")
            end,
            tooltip = function()
                return DC:GetString("menuResetTotalTooltip")
            end,
            warning = function()
                return DC:GetString("menuResetTotalWarning")
            end,
            isDangerous = true,
            func = function()
                DC.storage:ResetTotal(true)
                DC:RefreshAll()
                DC:Print(DC:GetString("chatResetDone"))
            end,
            width = "half",
        },
        {
            type = "button",
            name = function()
                return DC:GetString("menuResetPositionName")
            end,
            tooltip = function()
                return DC:GetString("menuResetPositionTooltip")
            end,
            func = function()
                DC.storage:ResetPosition()
                DC:RefreshAll()
                DC:Print(DC:GetString("chatPositionReset"))
            end,
            width = "full",
        },
    }

    self.panel = LAM:RegisterAddonPanel(self.panelId, panelData)
    LAM:RegisterOptionControls(self.panelId, optionsTable)

    SLASH_COMMANDS["/damagecalcsettings"] = function()
        self:OpenPanel()
    end
end
