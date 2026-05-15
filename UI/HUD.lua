local DC = DamageCalculation

DC.hud = {
    name = "DamageCalculationHUD",
    displayValues = {},
    targetValues = {},
    renderedValues = {},
    counterAnimations = {},
    metricRows = {},
    killPopupCount = 0,
    killPopupExpireAt = 0,
    dpsRefreshIntervalMs = 250,
    lastDpsRefreshAt = 0,
    combatTimeRefreshIntervalMs = 33,
    lastCombatTimeRefreshAt = 0,
    combatTimeStopValueDurationMs = 170,
    combatTimeStopPulseDurationMs = 270,
    combatTimeColorFadeDurationMs = 400,
    combatTimeStopAnimation = nil,
    combatTimeColorFade = nil,
}

function DC.hud:GetSettings()
    return DC.storage:GetSettings()
end

function DC.hud:GetMetricDefinition(metricKey)
    return DC.metricDefinitions[metricKey] or DC.metricDefinitions.damage
end

function DC.hud:IsMetricVisible(metricKey)
    local settings = self:GetSettings()
    local definition = self:GetMetricDefinition(metricKey)

    if definition.settingKey == nil then
        return true
    end

    return settings[definition.settingKey] ~= false
end

function DC.hud:GetVisibleMetricKeys()
    local visibleMetricKeys = {}

    for _, metricKey in ipairs(DC.metricKeys) do
        if self:IsMetricVisible(metricKey) then
            table.insert(visibleMetricKeys, metricKey)
        end
    end

    return visibleMetricKeys
end

function DC.hud:BuildFont(faceKey, size)
    local settings = self:GetSettings()
    local fontFace = DC.fontFacePaths[faceKey] or DC.fontFacePaths[DC.fontFaces.BOLD]
    local fontSize = math.floor(tonumber(size) or 18)
    local fontStyle = settings.fontStyle or DC.fontStyles.SOFT_SHADOW_THICK

    if fontStyle == DC.fontStyles.NONE then
        return string.format("%s|%d", fontFace, fontSize)
    end

    return string.format("%s|%d|%s", fontFace, fontSize, fontStyle)
end

function DC.hud:GetLabelColor()
    local settings = self:GetSettings()

    return tonumber(settings.labelColorR) or 0.95,
        tonumber(settings.labelColorG) or 0.92,
        tonumber(settings.labelColorB) or 0.78,
        tonumber(settings.labelColorA) or 1.0
end

function DC.hud:GetValueColor()
    local settings = self:GetSettings()

    return tonumber(settings.valueColorR) or 1.0,
        tonumber(settings.valueColorG) or 0.87,
        tonumber(settings.valueColorB) or 0.28,
        tonumber(settings.valueColorA) or 1.0
end

function DC.hud:IsCombatTimerActive()
    return DC.combatTracker ~= nil
        and DC.combatTracker.encounterActive == true
        and DC.combatTracker.combatStartedAtMs ~= nil
end

function DC.hud:GetCombatTimerAccentColors()
    local _, _, _, labelAlpha = self:GetLabelColor()
    local _, _, _, valueAlpha = self:GetValueColor()

    return {
        caption = { 1.0, 0.30, 0.30, labelAlpha },
        value = { 1.0, 0.38, 0.38, valueAlpha },
    }
end

function DC.hud:Clamp01(value)
    return math.max(0, math.min(1, tonumber(value) or 0))
end

function DC.hud:LerpScalar(fromValue, toValue, progress)
    return fromValue + ((toValue - fromValue) * self:Clamp01(progress))
end

function DC.hud:LerpColor(fromColor, toColor, progress)
    local t = self:Clamp01(progress)

    return {
        self:LerpScalar(fromColor[1], toColor[1], t),
        self:LerpScalar(fromColor[2], toColor[2], t),
        self:LerpScalar(fromColor[3], toColor[3], t),
        self:LerpScalar(fromColor[4], toColor[4], t),
    }
end

function DC.hud:EaseOutCubic(progress)
    local t = 1 - self:Clamp01(progress)
    return 1 - (t * t * t)
end

function DC.hud:EaseInOutQuad(progress)
    local t = self:Clamp01(progress)

    if t < 0.5 then
        return 2 * t * t
    end

    return 1 - math.pow(-2 * t + 2, 2) / 2
end

function DC.hud:GetLineHeight()
    local settings = self:GetSettings()
    return math.max(settings.labelFontSize or 20, settings.valueFontSize or 28) + 8
end

function DC.hud:GetMetricRowHeight(metricKey)
    local baseHeight = self:GetLineHeight()

    if metricKey == "dps" and DC.dpsGraph and DC.dpsGraph.GetMiniHeight and DC.dpsGraph.GetMiniGap then
        return baseHeight + DC.dpsGraph:GetMiniGap() + DC.dpsGraph:GetMiniHeight()
    end

    return baseHeight
end

function DC.hud:GetMetricsHeight()
    local visibleMetricKeys = self:GetVisibleMetricKeys()
    local totalHeight = 0

    for _, metricKey in ipairs(visibleMetricKeys) do
        totalHeight = totalHeight + self:GetMetricRowHeight(metricKey)
    end

    return math.max(self:GetLineHeight(), totalHeight)
end

function DC.hud:GetTopBlockHeight()
    return self:GetMetricsHeight() + 14
end

function DC.hud:ComputeHeight()
    local settings = self:GetSettings()
    local topBlockHeight = self:GetTopBlockHeight()

    if settings.showIntegrity then
        return topBlockHeight + (settings.statusFontSize or 15) + 14
    end

    return topBlockHeight
end

function DC.hud:GetHudWidth()
    local settings = self:GetSettings()
    return math.max(260, math.floor(tonumber(settings.hudWidth) or 560))
end

function DC.hud:GetPopupHorizontalAlignment()
    local anchor = self:GetSettings().popupAnchor

    if anchor == "left" then
        return TEXT_ALIGN_LEFT
    end

    if anchor == "center" then
        return TEXT_ALIGN_CENTER
    end

    return TEXT_ALIGN_RIGHT
end

function DC.hud:GetPopupWidth()
    local settings = self:GetSettings()
    local hudWidth = self:GetHudWidth()
    local padding = math.max(0, math.floor(tonumber(settings.contentPaddingX) or 14))
    local usableWidth = hudWidth - (padding * 2)

    return math.max(140, usableWidth)
end

function DC.hud:IsInlineValueLayout()
    return self:GetSettings().valueLayoutMode == "inlineRight"
end

function DC.hud:GetEffectiveValueLayoutMode()
    local settings = self:GetSettings()

    if not settings.showLabel then
        return "separate"
    end

    return settings.valueLayoutMode or "separate"
end

function DC.hud:IsInlineValueLayoutActive()
    return self:GetEffectiveValueLayoutMode() == "inlineRight"
end

function DC.hud:GetCaptionText(metricKey)
    local settings = self:GetSettings()
    local definition = self:GetMetricDefinition(metricKey)
    local captionText = DC:GetString(definition.labelKey or "hudDamageLabel")

    if settings.showLabel and self:IsInlineValueLayoutActive() then
        captionText = captionText .. ":"
    end

    return captionText
end

function DC.hud:FormatCombatTime(milliseconds)
    local totalMs = math.max(0, math.floor(tonumber(milliseconds) or 0))
    local totalSeconds = math.floor(totalMs / 1000)
    local minutes = math.floor(totalSeconds / 60)
    local seconds = totalSeconds % 60
    local ms = totalMs % 1000

    return string.format("%02d:%02d.%03d", minutes, seconds, ms)
end

function DC.hud:GetColorHex(r, g, b)
    local red = math.max(0, math.min(255, math.floor(((tonumber(r) or 1) * 255) + 0.5)))
    local green = math.max(0, math.min(255, math.floor(((tonumber(g) or 1) * 255) + 0.5)))
    local blue = math.max(0, math.min(255, math.floor(((tonumber(b) or 1) * 255) + 0.5)))

    return string.format("%02X%02X%02X", red, green, blue)
end

function DC.hud:ColorizeText(text, colorHex)
    return string.format("|c%s%s|r", tostring(colorHex or "FFFFFF"), tostring(text or ""))
end

function DC.hud:GetDpsValueText()
    local settings = self:GetSettings()
    local currentNow = GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0
    local snapshot = DC.dps and DC.dps.BuildDisplaySnapshot and DC.dps:BuildDisplaySnapshot(DC.storage:GetDisplayMode(), currentNow) or nil
    local playerDps = snapshot and snapshot.playerDps or 0
    local groupDps = snapshot and snapshot.groupDps or nil
    local secondaryPlayerDps = snapshot and snapshot.secondaryPlayerDps or nil
    local secondaryLabelKey = snapshot and snapshot.secondaryLabelKey or nil
    local sharePercent = snapshot and snapshot.sharePercent or nil
    local playerText = DC.formatter:FormatFull(playerDps)
    local labelColorHex = self:GetColorHex(self:GetLabelColor())
    local valueColorHex = self:GetColorHex(self:GetValueColor())
    local parts = {}

    if settings.showLabel ~= true then
        table.insert(parts, self:ColorizeText(DC:GetString("hudDpsLabel") .. ": ", labelColorHex))
    end

    table.insert(parts, self:ColorizeText(playerText, valueColorHex))

    if secondaryPlayerDps ~= nil then
        local secondaryText = string.format(" (%s %s)", DC:GetString(secondaryLabelKey or "hudDpsAverageShort"), DC.formatter:FormatFull(secondaryPlayerDps))
        table.insert(parts, self:ColorizeText(secondaryText, labelColorHex))
    end

    if sharePercent ~= nil then
        table.insert(parts, self:ColorizeText(string.format(" (%d%%)", sharePercent), labelColorHex))
    end

    if groupDps ~= nil then
        local groupText = DC.formatter:FormatFull(groupDps)
        table.insert(parts, self:ColorizeText(" | " .. DC:GetString("hudDpsGroupLabel") .. ": ", labelColorHex))
        table.insert(parts, self:ColorizeText(groupText, valueColorHex))
    end

    return table.concat(parts, "")
end

function DC.hud:UpdateDpsDisplay(now)
    if self.control == nil or self.metricRows.dps == nil then
        return
    end

    local currentNow = now or (GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0)
    local dpsIsLive = DC.dps and DC.dps.IsEncounterLive and DC.dps:IsEncounterLive() or false

    if dpsIsLive and self.lastDpsRefreshAt ~= nil and (currentNow - self.lastDpsRefreshAt) < self.dpsRefreshIntervalMs then
        return
    end

    self.lastDpsRefreshAt = currentNow
    self:UpdateMetricValueText("dps")
end

function DC.hud:CreateMetricRow(parent, metricKey)
    local row = WINDOW_MANAGER:CreateControl(nil, parent, CT_CONTROL)

    row.captionLabel = WINDOW_MANAGER:CreateControl(nil, row, CT_LABEL)
    row.captionLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    row.captionLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    row.captionLabel:SetColor(self:GetLabelColor())

    row.valuePulse = WINDOW_MANAGER:CreateControl(nil, row, CT_CONTROL)

    row.valueLabel = WINDOW_MANAGER:CreateControl(nil, row.valuePulse, CT_LABEL)
    row.valueLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    row.valueLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    row.valueLabel:SetColor(self:GetValueColor())
    row.valueLabel:SetAnchor(TOPLEFT, row.valuePulse, TOPLEFT, 0, 0)
    row.valueLabel:SetAnchor(BOTTOMRIGHT, row.valuePulse, BOTTOMRIGHT, 0, 0)

    row.metricKey = metricKey
    row.pulseTimeline = nil

    if metricKey == "dps" and DC.dpsGraph and DC.dpsGraph.AttachMiniSparkline then
        DC.dpsGraph:AttachMiniSparkline(row)
    end

    self.metricRows[metricKey] = row
end

function DC.hud:UpdateCombatTimeAccent(now)
    local row = self.metricRows.combatTime

    if row == nil then
        return
    end

    local labelColorR, labelColorG, labelColorB, labelColorA = self:GetLabelColor()
    local valueColorR, valueColorG, valueColorB, valueColorA = self:GetValueColor()
    local userLabelColor = { labelColorR, labelColorG, labelColorB, labelColorA }
    local userValueColor = { valueColorR, valueColorG, valueColorB, valueColorA }

    if not self:IsCombatTimerActive() then
        local colorFade = self.combatTimeColorFade

        if colorFade ~= nil then
            ---@cast colorFade -nil
            local currentNow = now or (GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0)
            local elapsed = math.max(0, currentNow - colorFade.startTime)
            local progress = self:Clamp01(elapsed / colorFade.duration)
            local easedProgress = self:EaseOutCubic(progress)
            local currentLabelColor = self:LerpColor(colorFade.fromLabelColor, userLabelColor, easedProgress)
            local currentValueColor = self:LerpColor(colorFade.fromValueColor, userValueColor, easedProgress)

            row.captionLabel:SetColor(unpack(currentLabelColor))
            row.valueLabel:SetColor(unpack(currentValueColor))

            if progress >= 1 then
                self.combatTimeColorFade = nil
            end
        else
            row.captionLabel:SetColor(unpack(userLabelColor))
            row.valueLabel:SetColor(unpack(userValueColor))
        end

        row.captionLabel:SetScale(1)
        row.captionLabel:SetAlpha(1)
        row.valueLabel:SetScale(1)
        row.valueLabel:SetAlpha(1)
        return
    end

    local currentNow = now or (GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0)
    local wave = (math.sin(currentNow / 170) + 1) * 0.5
    local scale = 1.0 + (wave * 0.06)
    local alpha = 0.88 + (wave * 0.12)
    local accentColors = self:GetCombatTimerAccentColors()

    row.captionLabel:SetColor(unpack(accentColors.caption))
    row.valueLabel:SetColor(unpack(accentColors.value))
    row.captionLabel:SetScale(1)
    row.captionLabel:SetAlpha(1)
    row.valueLabel:SetScale(1)
    row.valueLabel:SetAlpha(1)
    row.valuePulse:SetScale(scale)
    row.valuePulse:SetAlpha(alpha)
    self.combatTimeColorFade = nil
end

function DC.hud:UpdateCombatTimeStopAnimation(now)
    local row = self.metricRows.combatTime

    if row == nil then
        return
    end

    local animation = self.combatTimeStopAnimation

    if animation == nil then
        return
    end
    ---@cast animation -nil

    local currentNow = now or (GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0)
    local pulseElapsed = math.max(0, currentNow - animation.startTime)
    local pulseProgress = self:Clamp01(pulseElapsed / animation.pulseDuration)
    local pulseScale = 1

    if pulseProgress < 0.42 then
        local growProgress = self:EaseOutCubic(pulseProgress / 0.42)
        pulseScale = self:LerpScalar(animation.startScale, animation.peakScale, growProgress)
    else
        local settleProgress = self:EaseInOutQuad((pulseProgress - 0.42) / 0.58)
        pulseScale = self:LerpScalar(animation.peakScale, 1.0, settleProgress)
    end

    local alphaProgress = self:EaseOutCubic(pulseProgress)
    local pulseAlpha = self:LerpScalar(animation.startAlpha, 1.0, alphaProgress)

    row.valuePulse:SetScale(pulseScale)
    row.valuePulse:SetAlpha(pulseAlpha)

    local valueElapsed = math.max(0, currentNow - animation.startTime)
    local valueProgress = self:Clamp01(valueElapsed / animation.valueDuration)
    local valueEasedProgress = self:EaseOutCubic(valueProgress)

    self.displayValues.combatTime = math.floor(self:LerpScalar(animation.fromValue, animation.toValue, valueEasedProgress) + 0.5)
    self.targetValues.combatTime = animation.toValue
    self:UpdateMetricValueText("combatTime")

    if pulseProgress >= 1 and valueProgress >= 1 then
        self.displayValues.combatTime = animation.toValue
        self.targetValues.combatTime = animation.toValue
        row.valuePulse:SetScale(1)
        row.valuePulse:SetAlpha(1)
        self:UpdateMetricValueText("combatTime")
        self.combatTimeStopAnimation = nil
    end
end

function DC.hud:CreateControl()
    local control = WINDOW_MANAGER:CreateTopLevelWindow(self.name)
    control:SetDimensions(self:GetHudWidth(), self:ComputeHeight())
    control:SetClampedToScreen(true)
    control:SetDrawLayer(DL_OVERLAY)
    control:SetDrawTier(DT_HIGH)
    control:SetMovable(true)
    control:SetMouseEnabled(true)
    control:ClearAnchors()
    control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, self:GetSettings().positionX, self:GetSettings().positionY)

    control.backdrop = WINDOW_MANAGER:CreateControl(nil, control, CT_BACKDROP)
    control.backdrop:SetAnchorFill(control)
    control.backdrop:SetCenterColor(0.02, 0.02, 0.02, 0.45)
    control.backdrop:SetEdgeColor(0.8, 0.62, 0.18, 0.75)
    control.backdrop:SetEdgeTexture("", 8, 1, 1.5)
    control.backdrop:SetInsets(0, 0, -1, -1)

    control.metricsContainer = WINDOW_MANAGER:CreateControl(nil, control, CT_CONTROL)
    control.metricsContainer:SetAnchor(TOPLEFT, control, TOPLEFT, self:GetSettings().contentPaddingX, self:GetSettings().contentPaddingY)
    control.metricsContainer:SetAnchor(TOPRIGHT, control, TOPRIGHT, -self:GetSettings().contentPaddingX, self:GetSettings().contentPaddingY)
    control.metricsContainer:SetHeight(self:GetMetricsHeight())

    for _, metricKey in ipairs(DC.metricKeys) do
        self:CreateMetricRow(control.metricsContainer, metricKey)
    end

    control.statusLabel = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
    control.statusLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    control.statusLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    control.popupLabel = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
    control.popupLabel:SetDimensions(self:GetPopupWidth(), 36)
    control.popupLabel:SetHorizontalAlignment(self:GetPopupHorizontalAlignment())
    control.popupLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    control.popupLabel:SetAlpha(0)

    control:SetHandler("OnMouseDown", function(window, button)
        if button == MOUSE_BUTTON_INDEX_RIGHT and not self:GetSettings().lockWindow then
            window:StartMoving()
        end
    end)

    control:SetHandler("OnMouseUp", function(window)
        window:StopMovingOrResizing()
    end)

    control:SetHandler("OnMoveStop", function(window)
        local left = window:GetLeft()
        local top = window:GetTop()

        if left ~= nil and top ~= nil then
            DC.storage:SavePosition(left, top)
        end
    end)

    control:SetHandler("OnUpdate", function(_, timeMs)
        self:OnUpdate(timeMs)
    end)

    self.control = control
    self.fragment = ZO_HUDFadeSceneFragment:New(control)
    self.popupTimeline = nil
    self.popupTimelineDuration = 0

    HUD_SCENE:AddFragment(self.fragment)
    HUD_UI_SCENE:AddFragment(self.fragment)
end

function DC.hud:CreatePopupTimeline(duration)
    local popup = self.control.popupLabel
    local existingPopupTimeline = self.popupTimeline

    if existingPopupTimeline ~= nil then
        existingPopupTimeline:Stop()
    end

    self.popupTimeline = ANIMATION_MANAGER:CreateTimeline()
    self.popupTimelineDuration = duration
    local popupTimeline = self.popupTimeline

    if popupTimeline == nil then
        return
    end

    self.popupScaleAnimation = popupTimeline:InsertAnimation(ANIMATION_SCALE, popup, 0)
    self.popupScaleDownAnimation = popupTimeline:InsertAnimation(ANIMATION_SCALE, popup, math.floor(duration * 0.35))
    self.popupMoveAnimation = popupTimeline:InsertAnimation(ANIMATION_TRANSLATE, popup, 0)
    self.popupFadeInAnimation = popupTimeline:InsertAnimation(ANIMATION_ALPHA, popup, 0)
    self.popupFadeOutAnimation = popupTimeline:InsertAnimation(ANIMATION_ALPHA, popup, math.floor(duration * 0.45))
end

function DC.hud:CreateMetricPulseTimeline(row)
    local existingPulseTimeline = row.pulseTimeline

    if existingPulseTimeline ~= nil then
        existingPulseTimeline:Stop()
    end

    row.pulseTimeline = ANIMATION_MANAGER:CreateTimeline()
    local pulseTimeline = row.pulseTimeline

    if pulseTimeline == nil then
        return
    end

    row.pulseGrowAnimation = pulseTimeline:InsertAnimation(ANIMATION_SCALE, row.valuePulse, 0)
    row.pulseSettleAnimation = pulseTimeline:InsertAnimation(ANIMATION_SCALE, row.valuePulse, 110)
end

function DC.hud:ApplyFonts()
    local settings = self:GetSettings()

    for _, metricKey in ipairs(DC.metricKeys) do
        local row = self.metricRows[metricKey]
        row.captionLabel:SetFont(self:BuildFont(settings.labelFontFace, settings.labelFontSize))
        row.valueLabel:SetFont(self:BuildFont(settings.valueFontFace, settings.valueFontSize))
    end

    self.control.statusLabel:SetFont(self:BuildFont(settings.labelFontFace, settings.statusFontSize))
    self.control.popupLabel:SetFont(self:BuildFont(settings.popupFontFace, settings.hitFontSize))
end

function DC.hud:ApplyColors()
    local labelColorR, labelColorG, labelColorB, labelColorA = self:GetLabelColor()
    local valueColorR, valueColorG, valueColorB, valueColorA = self:GetValueColor()

    for _, metricKey in ipairs(DC.metricKeys) do
        local row = self.metricRows[metricKey]
        row.captionLabel:SetColor(labelColorR, labelColorG, labelColorB, labelColorA)
        row.valueLabel:SetColor(valueColorR, valueColorG, valueColorB, valueColorA)
    end

    self:UpdateCombatTimeAccent()
end

function DC.hud:ApplyMetricRowLayout(row, metricKey, offsetY, lineHeight)
    local settings = self:GetSettings()
    local showLabel = settings.showLabel
    local inlineLayout = self:IsInlineValueLayoutActive()
    local captionWidth = 0
    local rowHeight = self:GetMetricRowHeight(metricKey)
    local hasSparkline = metricKey == "dps" and row.sparkline ~= nil

    row:SetHidden(false)
    row:ClearAnchors()
    row:SetAnchor(TOPLEFT, self.control.metricsContainer, TOPLEFT, 0, offsetY)
    row:SetAnchor(TOPRIGHT, self.control.metricsContainer, TOPRIGHT, 0, offsetY)
    row:SetHeight(rowHeight)

    row.captionLabel:ClearAnchors()
    row.captionLabel:SetAnchor(TOPLEFT, row, TOPLEFT, 0, 0)
    row.captionLabel:SetDimensions(0, lineHeight)
    row.captionLabel:SetText(self:GetCaptionText(metricKey))
    row.captionLabel:SetHidden(not showLabel)

    row.valueLabel:ClearAnchors()
    row.valueLabel:SetAnchor(TOPLEFT, row.valuePulse, TOPLEFT, 0, 0)
    row.valueLabel:SetAnchor(TOPRIGHT, row.valuePulse, TOPRIGHT, 0, 0)
    row.valueLabel:SetHeight(lineHeight)

    row.valuePulse:ClearAnchors()
    if showLabel then
        if inlineLayout then
            captionWidth = row.captionLabel:GetTextWidth() + 8
            row.valueLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        else
            captionWidth = math.max(40, math.floor(tonumber(settings.labelAreaWidth) or 150))
            row.valueLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        end
    else
        row.valueLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    end

    row.captionLabel:SetDimensions(captionWidth, lineHeight)
    row.valuePulse:SetAnchor(TOPLEFT, row, TOPLEFT, captionWidth, 0)
    row.valuePulse:SetAnchor(BOTTOMRIGHT, row, BOTTOMRIGHT, 0, 0)

    if hasSparkline then
        row.sparkline:SetHidden(false)
        row.sparkline:ClearAnchors()
        row.sparkline:SetAnchor(BOTTOMLEFT, row.valuePulse, BOTTOMLEFT, 0, 0)
        row.sparkline:SetAnchor(BOTTOMRIGHT, row.valuePulse, BOTTOMRIGHT, 0, 0)
        row.sparkline:SetHeight(DC.dpsGraph:GetMiniHeight())
    elseif row.sparkline ~= nil then
        row.sparkline:SetHidden(true)
    end
end

function DC.hud:ApplyLayout()
    local settings = self:GetSettings()
    local height = self:ComputeHeight()
    local hudWidth = self:GetHudWidth()
    local lineHeight = self:GetLineHeight()
    local visibleMetricKeys = self:GetVisibleMetricKeys()
    local metricsHeight = self:GetMetricsHeight()

    self.control:SetDimensions(hudWidth, height)
    self.control:SetScale(settings.scale or 1.0)
    self.control:ClearAnchors()
    self.control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, settings.positionX, settings.positionY)
    self.control:SetHidden(not settings.showHud)
    self.control:SetMouseEnabled(settings.showHud == true and not settings.lockWindow)

    if settings.showBackground then
        self.control.backdrop:SetCenterColor(0.02, 0.02, 0.02, 0.45)
    else
        self.control.backdrop:SetCenterColor(0, 0, 0, 0)
    end

    if settings.showBorder then
        if DC.storage:IsModified() then
            self.control.backdrop:SetEdgeColor(0.95, 0.25, 0.25, 0.85)
        else
            self.control.backdrop:SetEdgeColor(0.8, 0.62, 0.18, 0.75)
        end
    else
        self.control.backdrop:SetEdgeColor(0, 0, 0, 0)
    end

    self:ApplyFonts()
    self:ApplyColors()

    self.control.metricsContainer:ClearAnchors()
    self.control.metricsContainer:SetAnchor(TOPLEFT, self.control, TOPLEFT, settings.contentPaddingX, settings.contentPaddingY)
    self.control.metricsContainer:SetAnchor(TOPRIGHT, self.control, TOPRIGHT, -settings.contentPaddingX, settings.contentPaddingY)
    self.control.metricsContainer:SetHeight(metricsHeight)

    local visibleIndexByMetric = {}
    for index, metricKey in ipairs(visibleMetricKeys) do
        visibleIndexByMetric[metricKey] = index
    end

    local offsetY = 0
    for _, metricKey in ipairs(DC.metricKeys) do
        local row = self.metricRows[metricKey]
        local visibleIndex = visibleIndexByMetric[metricKey]

        if visibleIndex == nil then
            row:SetHidden(true)
        else
            self:ApplyMetricRowLayout(row, metricKey, offsetY, lineHeight)
            offsetY = offsetY + self:GetMetricRowHeight(metricKey)
        end
    end

    self.control.statusLabel:SetHidden(not settings.showIntegrity)
    self.control.statusLabel:ClearAnchors()
    self.control.statusLabel:SetAnchor(TOPLEFT, self.control.metricsContainer, BOTTOMLEFT, 0, 6)
    self.control.statusLabel:SetAnchor(TOPRIGHT, self.control.metricsContainer, BOTTOMRIGHT, 0, 6)

    self.control.popupLabel:ClearAnchors()
    self.control.popupLabel:SetWidth(self:GetPopupWidth())
    self.control.popupLabel:SetHorizontalAlignment(self:GetPopupHorizontalAlignment())
    if settings.popupAnchor == "left" then
        self.control.popupLabel:SetAnchor(BOTTOMLEFT, self.control.metricsContainer, TOPLEFT, 0, settings.popupOffsetY)
    elseif settings.popupAnchor == "center" then
        self.control.popupLabel:SetAnchor(BOTTOM, self.control.metricsContainer, TOP, 0, settings.popupOffsetY)
    else
        self.control.popupLabel:SetAnchor(BOTTOMRIGHT, self.control.metricsContainer, TOPRIGHT, 0, settings.popupOffsetY)
    end
end

function DC.hud:UpdateMetricValueText(metricKey)
    if metricKey == "dps" then
        local dpsText = self:GetDpsValueText()

        if self.renderedValues[metricKey] == dpsText then
            return
        end

        self.renderedValues[metricKey] = dpsText
        self.metricRows[metricKey].valueLabel:SetText(dpsText)
        return
    end

    if metricKey == "combatTime" then
        local timeValue = math.max(0, math.floor(tonumber(self.displayValues[metricKey]) or 0))

        if self.renderedValues[metricKey] == timeValue then
            return
        end

        self.renderedValues[metricKey] = timeValue
        self.metricRows[metricKey].valueLabel:SetText(self:FormatCombatTime(timeValue))
        return
    end

    local numericValue = math.max(0, math.floor(tonumber(self.displayValues[metricKey]) or 0))

    if self.renderedValues[metricKey] == numericValue then
        return
    end

    self.renderedValues[metricKey] = numericValue
    self.metricRows[metricKey].valueLabel:SetText(DC.formatter:Format(numericValue))
end

function DC.hud:UpdateCombatTimeDisplay(now)
    if self.control == nil or self.metricRows.combatTime == nil then
        return
    end

    if self.combatTimeStopAnimation ~= nil then
        return
    end

    local currentNow = now or (GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0)

    if self.lastCombatTimeRefreshAt ~= nil and (currentNow - self.lastCombatTimeRefreshAt) < self.combatTimeRefreshIntervalMs then
        return
    end

    self.lastCombatTimeRefreshAt = currentNow

    local combatTimeMs = 0
    if DC.combatTracker and DC.combatTracker.GetCombatDurationMs then
        combatTimeMs = DC.combatTracker:GetCombatDurationMs(currentNow)
    end

    self.displayValues.combatTime = combatTimeMs
    self.targetValues.combatTime = combatTimeMs
    self.counterAnimations.combatTime = nil
    self:UpdateMetricValueText("combatTime")
end

function DC.hud:InvalidateValueText(metricKey)
    if metricKey == nil then
        self.renderedValues = {}
        return
    end

    self.renderedValues[metricKey] = nil
end

function DC.hud:SetMetricDisplayTarget(metricKey, totalValue, immediate)
    local settings = self:GetSettings()
    local safeTarget = math.max(0, math.floor(tonumber(totalValue) or 0))

    self.targetValues[metricKey] = safeTarget

    if immediate or not settings.animateCounter then
        self.displayValues[metricKey] = safeTarget
        self.counterAnimations[metricKey] = nil
        self:UpdateMetricValueText(metricKey)
        return
    end

    if self.displayValues[metricKey] == nil then
        self.displayValues[metricKey] = safeTarget
        self:UpdateMetricValueText(metricKey)
        return
    end

    self.counterAnimations[metricKey] = {
        fromValue = self.displayValues[metricKey],
        toValue = safeTarget,
        startTime = GetGameTimeMilliseconds(),
        duration = math.max(80, settings.counterAnimationMs or 350),
    }
end

function DC.hud:UpdateCounterAnimation(now)
    for metricKey, animation in pairs(self.counterAnimations) do
        if animation ~= nil then
            ---@cast animation -nil
            local elapsed = math.max(0, now - animation.startTime)
            local progress = math.min(1, elapsed / animation.duration)
            local eased = 1 - ((1 - progress) * (1 - progress))
            local interpolated = animation.fromValue + ((animation.toValue - animation.fromValue) * eased)

            self.displayValues[metricKey] = math.floor(interpolated + 0.5)
            self:UpdateMetricValueText(metricKey)

            if progress >= 1 then
                self.displayValues[metricKey] = animation.toValue
                self.counterAnimations[metricKey] = nil
                self:UpdateMetricValueText(metricKey)
            end
        end
    end
end

function DC.hud:ConfigurePopupAnimation(scaleMultiplier)
    local settings = self:GetSettings()
    local duration = settings.popupDurationMs or 900

    if self.popupTimeline == nil or self.popupTimelineDuration ~= duration then
        self:CreatePopupTimeline(duration)
    end

    local popupTimeline = self.popupTimeline
    local popupScaleAnimation = self.popupScaleAnimation
    local popupScaleDownAnimation = self.popupScaleDownAnimation
    local popupMoveAnimation = self.popupMoveAnimation
    local popupFadeInAnimation = self.popupFadeInAnimation
    local popupFadeOutAnimation = self.popupFadeOutAnimation

    if popupTimeline == nil
        or popupScaleAnimation == nil
        or popupScaleDownAnimation == nil
        or popupMoveAnimation == nil
        or popupFadeInAnimation == nil
        or popupFadeOutAnimation == nil then
        return
    end

    popupTimeline:Stop()

    popupScaleAnimation:SetScaleValues(0.85, scaleMultiplier)
    popupScaleAnimation:SetDuration(math.floor(duration * 0.35))
    popupScaleAnimation:SetEasingFunction(ZO_EaseOutQuadratic)

    popupScaleDownAnimation:SetScaleValues(scaleMultiplier, 1)
    popupScaleDownAnimation:SetDuration(math.floor(duration * 0.65))
    popupScaleDownAnimation:SetEasingFunction(ZO_EaseInQuadratic)

    popupMoveAnimation:SetTranslateOffsets(0, 0, 0, -38)
    popupMoveAnimation:SetDuration(duration)
    popupMoveAnimation:SetEasingFunction(ZO_EaseOutQuadratic)

    popupFadeInAnimation:SetAlphaValues(0.05, 1)
    popupFadeInAnimation:SetDuration(math.floor(duration * 0.2))
    popupFadeInAnimation:SetEasingFunction(ZO_EaseOutQuadratic)

    popupFadeOutAnimation:SetAlphaValues(1, 0)
    popupFadeOutAnimation:SetDuration(math.floor(duration * 0.55))
    popupFadeOutAnimation:SetEasingFunction(ZO_EaseInQuadratic)
end

function DC.hud:PlayMetricPulse(metricKey, scaleMultiplier)
    local row = self.metricRows[metricKey]

    if row == nil then
        return
    end

    if row.pulseTimeline == nil then
        self:CreateMetricPulseTimeline(row)
    end

    local pulseTimeline = row.pulseTimeline
    local pulseGrowAnimation = row.pulseGrowAnimation
    local pulseSettleAnimation = row.pulseSettleAnimation

    if pulseTimeline == nil or pulseGrowAnimation == nil or pulseSettleAnimation == nil then
        return
    end

    pulseTimeline:Stop()

    pulseGrowAnimation:SetScaleValues(1, scaleMultiplier)
    pulseGrowAnimation:SetDuration(110)
    pulseGrowAnimation:SetEasingFunction(ZO_EaseOutQuadratic)

    pulseSettleAnimation:SetScaleValues(scaleMultiplier, 1)
    pulseSettleAnimation:SetDuration(180)
    pulseSettleAnimation:SetEasingFunction(ZO_EaseInQuadratic)

    pulseTimeline:PlayFromStart()
end

function DC.hud:GetPopupStyle(amount, isCritical)
    local settings = self:GetSettings()
    local baseFontSize = settings.hitFontSize or 24
    local scaleMultiplier = 1.02
    local color = { 0.97, 0.97, 0.97, 1.0 }

    if amount >= 100000 then
        scaleMultiplier = 1.35
        color = { 1.0, 0.74, 0.26, 1.0 }
    elseif amount >= 30000 then
        scaleMultiplier = 1.18
        color = { 0.98, 0.88, 0.46, 1.0 }
    end

    if isCritical then
        scaleMultiplier = math.max(scaleMultiplier, 1.45)
        color = { 1.0, 0.35, 0.24, 1.0 }
    end

    return {
        scaleMultiplier = scaleMultiplier,
        fontSize = math.floor(baseFontSize * math.max(1.0, scaleMultiplier * 0.95)),
        color = color,
    }
end

function DC.hud:GetKillPopupStyle(killCount)
    local settings = self:GetSettings()
    local baseFontSize = settings.hitFontSize or 24
    local valueColorR, valueColorG, valueColorB, valueColorA = self:GetValueColor()
    local color = { valueColorR, valueColorG, valueColorB, valueColorA }
    local scaleMultiplier = 1.16
    local numericKillCount = math.max(1, math.floor(tonumber(killCount) or 1))

    if numericKillCount >= 2 then
        scaleMultiplier = math.min(1.32, scaleMultiplier + ((numericKillCount - 1) * 0.04))
    end

    return {
        scaleMultiplier = scaleMultiplier,
        fontSize = math.floor(baseFontSize * scaleMultiplier),
        color = color,
    }
end

function DC.hud:BuildKillPopupText(killCount)
    local numericKillCount = math.max(1, math.floor(tonumber(killCount) or 1))

    if numericKillCount == 1 then
        return "+ " .. DC:GetString("hudPopupKillSingle", numericKillCount)
    end

    return "+ " .. DC:GetString("hudPopupKillMultiple", numericKillCount)
end

function DC.hud:GetMetricPulseScale(metricKey, eventInfo)
    local amount = math.max(0, math.floor(tonumber(eventInfo and eventInfo.amount) or 0))
    local scaleMultiplier = 1.04

    if metricKey == "damage" then
        return math.min(1.14, self:GetPopupStyle(amount, eventInfo.isCritical == true).scaleMultiplier)
    end

    if metricKey == "blocked" then
        if amount >= 60000 then
            return 1.12
        end

        if amount >= 20000 then
            return 1.08
        end

        return 1.05
    end

    if eventInfo and eventInfo.isCritical then
        return 1.10
    end

    if amount >= 40000 then
        return 1.08
    end

    return scaleMultiplier
end

function DC.hud:OnMetricAdded(metricKey, eventInfo)
    if self.control == nil or metricKey == nil or eventInfo == nil then
        return
    end

    local settings = self:GetSettings()
    local definition = self:GetMetricDefinition(metricKey)
    local amount = math.max(0, math.floor(tonumber(eventInfo.amount) or 0))
    local isCritical = eventInfo.isCritical == true

    self:SetMetricDisplayTarget(metricKey, DC.storage:GetMetricTotal(metricKey), not settings.animateCounter)
    self:PlayMetricPulse(metricKey, self:GetMetricPulseScale(metricKey, eventInfo))

    if definition.allowsSound then
        DC.sound:PlayForHit(eventInfo)
    end

    if not definition.allowsPopup or not settings.showHitPopup then
        return
    end

    if settings.popupOnlyCrit and not isCritical then
        return
    end

    local popupStyle = self:GetPopupStyle(amount, isCritical)
    local popupText = "+ " .. DC.formatter:FormatFull(amount)

    if isCritical then
        popupText = popupText .. "  " .. DC:GetString("hudPopupCritical")
    end

    self.control.popupLabel:SetText(popupText)
    self.control.popupLabel:SetColor(unpack(popupStyle.color))
    self.control.popupLabel:SetFont(self:BuildFont(settings.popupFontFace, popupStyle.fontSize))

    self:ConfigurePopupAnimation(popupStyle.scaleMultiplier)
    local popupTimeline = self.popupTimeline

    if popupTimeline == nil then
        return
    end

    popupTimeline:PlayFromStart()
end

function DC.hud:OnKillAdded(killInfo)
    if self.control == nil or killInfo == nil then
        return
    end

    local settings = self:GetSettings()
    local now = GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0

    if not settings.showHitPopup then
        return
    end

    if now <= (self.killPopupExpireAt or 0) then
        self.killPopupCount = math.max(1, math.floor(tonumber(self.killPopupCount) or 0) + 1)
    else
        self.killPopupCount = 1
    end

    self.killPopupExpireAt = now + (settings.popupDurationMs or 900)

    local popupStyle = self:GetKillPopupStyle(self.killPopupCount)

    self.control.popupLabel:SetText(self:BuildKillPopupText(self.killPopupCount))
    self.control.popupLabel:SetColor(unpack(popupStyle.color))
    self.control.popupLabel:SetFont(self:BuildFont(settings.popupFontFace, popupStyle.fontSize))

    self:ConfigurePopupAnimation(popupStyle.scaleMultiplier)
    local popupTimeline = self.popupTimeline

    if popupTimeline == nil then
        return
    end

    popupTimeline:PlayFromStart()
end

function DC.hud:OnCombatTimerStateChanged(isActive)
    if self.control == nil then
        return
    end

    local now = GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0
    self.lastDpsRefreshAt = 0
    self.lastCombatTimeRefreshAt = 0

    if isActive then
        self.combatTimeStopAnimation = nil
        self.combatTimeColorFade = nil
        self:UpdateCombatTimeDisplay(now)
        self:UpdateCombatTimeAccent(now)
        self:PlayMetricPulse("combatTime", 1.10)
        if DC.dpsGraph and DC.dpsGraph.OnCombatStateChanged then
            DC.dpsGraph:OnCombatStateChanged(true)
        end
        return
    end

    local row = self.metricRows.combatTime
    local accentColors = self:GetCombatTimerAccentColors()
    local finalCombatTimeMs = DC.combatTracker and DC.combatTracker.GetCombatDurationMs and DC.combatTracker:GetCombatDurationMs(now) or 0

    self.combatTimeStopAnimation = {
        startTime = now,
        pulseDuration = self.combatTimeStopPulseDurationMs,
        valueDuration = self.combatTimeStopValueDurationMs,
        fromValue = math.max(0, math.floor(tonumber(self.displayValues.combatTime) or finalCombatTimeMs)),
        toValue = math.max(0, math.floor(tonumber(finalCombatTimeMs) or 0)),
        startScale = row and row.valuePulse and row.valuePulse.GetScale and row.valuePulse:GetScale() or 1.0,
        startAlpha = row and row.valuePulse and row.valuePulse.GetAlpha and row.valuePulse:GetAlpha() or 1.0,
        peakScale = 1.14,
    }

    self.combatTimeColorFade = {
        startTime = now,
        duration = self.combatTimeColorFadeDurationMs,
        fromLabelColor = accentColors.caption,
        fromValueColor = accentColors.value,
    }

    self:UpdateCombatTimeStopAnimation(now)
    self:UpdateCombatTimeAccent(now)

    if DC.dpsGraph and DC.dpsGraph.OnCombatStateChanged then
        DC.dpsGraph:OnCombatStateChanged(false)
    end
end

function DC.hud:OnUpdate(timeMs)
    local now = GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0
    self:UpdateCounterAnimation(now)
    self:UpdateDpsDisplay(now)
    self:UpdateCombatTimeStopAnimation(now)
    self:UpdateCombatTimeDisplay(now)
    self:UpdateCombatTimeAccent(now)

    if DC.dpsGraph and DC.dpsGraph.OnUpdate then
        DC.dpsGraph:OnUpdate(now)
    end

    if DC.tooltip and DC.tooltip.UpdateHover then
        DC.tooltip:UpdateHover()
    end
end

function DC.hud:Refresh()
    if self.control == nil then
        return
    end

    local integrityState = DC.storage:GetIntegrityStatusText()
    local settings = self:GetSettings()

    self:ApplyLayout()
    self:InvalidateValueText()
    self.lastDpsRefreshAt = 0

    for _, metricKey in ipairs(DC.metricKeys) do
        if metricKey == "dps" then
            self.displayValues[metricKey] = 0
            self.targetValues[metricKey] = 0
            self.counterAnimations[metricKey] = nil
            self:UpdateMetricValueText(metricKey)
        elseif metricKey == "combatTime" then
            local combatTimeMs = DC.combatTracker and DC.combatTracker.GetCombatDurationMs and DC.combatTracker:GetCombatDurationMs() or 0
            self.displayValues[metricKey] = combatTimeMs
            self.targetValues[metricKey] = combatTimeMs
            self.counterAnimations[metricKey] = nil
            self:UpdateMetricValueText(metricKey)
        else
            self:SetMetricDisplayTarget(metricKey, DC.storage:GetMetricTotal(metricKey), not settings.animateCounter)
        end
    end

    if DC.storage:IsModified() then
        self.control.statusLabel:SetText(DC:GetString("hudIntegrityWarning"))
        self.control.statusLabel:SetColor(1.0, 0.35, 0.35, 1.0)
    else
        self.control.statusLabel:SetText(DC:GetString("hudIntegrityLabel", integrityState))
        self.control.statusLabel:SetColor(0.56, 0.92, 0.65, 1.0)
    end

    if not settings.animateCounter then
        for _, metricKey in ipairs(DC.metricKeys) do
            if metricKey == "dps" then
                self.displayValues[metricKey] = 0
            elseif metricKey == "combatTime" then
                self.displayValues[metricKey] = DC.combatTracker and DC.combatTracker.GetCombatDurationMs and DC.combatTracker:GetCombatDurationMs() or 0
            else
                self.displayValues[metricKey] = DC.storage:GetMetricTotal(metricKey)
            end
            self:UpdateMetricValueText(metricKey)
        end
    else
        for _, metricKey in ipairs(DC.metricKeys) do
            if self.counterAnimations[metricKey] == nil then
                self:UpdateMetricValueText(metricKey)
            end
        end
    end
end

function DC.hud:Initialize()
    for _, metricKey in ipairs(DC.metricKeys) do
        if metricKey == "dps" then
            self.displayValues[metricKey] = 0
        elseif metricKey == "combatTime" then
            self.displayValues[metricKey] = DC.combatTracker and DC.combatTracker.GetCombatDurationMs and DC.combatTracker:GetCombatDurationMs() or 0
        else
            self.displayValues[metricKey] = DC.storage:GetMetricTotal(metricKey)
        end
        self.targetValues[metricKey] = self.displayValues[metricKey]
    end

    self.renderedValues = {}
    self.counterAnimations = {}
    self.metricRows = {}
    self.killPopupCount = 0
    self.killPopupExpireAt = 0
    self.lastDpsRefreshAt = 0
    self.lastCombatTimeRefreshAt = 0
    self.combatTimeStopAnimation = nil
    self.combatTimeColorFade = nil
    self:CreateControl()
end
