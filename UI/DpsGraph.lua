local DC = DamageCalculation

DC.dpsGraph = {
    name = "DamageCalculationDpsGraph",
    miniBarCount = 48,
    largeBarCount = 120,
    miniHeight = 12,
    miniGap = 4,
    minVisualRange = 1500,
    windowRefreshIntervalMs = 250,
    miniRefreshIntervalMs = 250,
    lastWindowRefreshAt = 0,
    lastMiniRefreshAt = 0,
}

function DC.dpsGraph:GetSettings()
    return DC.storage:GetSettings()
end

function DC.dpsGraph:GetMiniHeight()
    return self.miniHeight
end

function DC.dpsGraph:GetMiniGap()
    return self.miniGap
end

function DC.dpsGraph:GetWindowWidth()
    if DC.hud and DC.hud.GetHudWidth then
        return math.max(360, math.floor(DC.hud:GetHudWidth() * 1.12))
    end

    return 380
end

function DC.dpsGraph:GetWindowHeight()
    return 214
end

function DC.dpsGraph:GetGraphCanvasHeight()
    return 92
end

function DC.dpsGraph:IsAutoShowEnabled()
    return self:GetSettings().dpsGraphAutoShowInCombat == true
end

function DC.dpsGraph:GetSelectedDisplayMode()
    return DC.storage:GetDisplayMode()
end

function DC.dpsGraph:GetDisplayModeLabel(mode)
    if mode == DC.displayModes.SESSION then
        return DC:GetString("displayModeSession")
    end

    return DC:GetString("displayModeTotal")
end

function DC.dpsGraph:CreateBars(parent, barCount)
    local bars = {}

    for index = 1, math.max(1, math.floor(tonumber(barCount) or 1)) do
        local bar = WINDOW_MANAGER:CreateControl(nil, parent, CT_BACKDROP)
        bar:SetMouseEnabled(false)
        bar:SetEdgeColor(0, 0, 0, 0)
        bar:SetCenterColor(1, 1, 1, 0.2)
        bars[index] = bar
    end

    return bars
end

function DC.dpsGraph:AttachMiniSparkline(row)
    if row == nil or row.sparkline ~= nil then
        return
    end

    row.sparkline = WINDOW_MANAGER:CreateControl(nil, row.valuePulse, CT_CONTROL)
    row.sparkline:SetMouseEnabled(false)
    row.sparkline.backdrop = WINDOW_MANAGER:CreateControl(nil, row.sparkline, CT_BACKDROP)
    row.sparkline.backdrop:SetAnchorFill(row.sparkline)
    row.sparkline.backdrop:SetCenterColor(0.04, 0.04, 0.04, 0.12)
    row.sparkline.backdrop:SetEdgeColor(0, 0, 0, 0)
    row.sparkline.bars = self:CreateBars(row.sparkline, self.miniBarCount)
end

function DC.dpsGraph:CreateControl()
    local control = WINDOW_MANAGER:CreateTopLevelWindow(self.name)
    control:SetHidden(true)
    control:SetMouseEnabled(true)
    control:SetMovable(false)
    control:SetClampedToScreen(true)
    control:SetDrawLayer(DL_OVERLAY)
    control:SetDrawTier(DT_HIGH)

    control.backdrop = WINDOW_MANAGER:CreateControl(nil, control, CT_BACKDROP)
    control.backdrop:SetAnchorFill(control)
    control.backdrop:SetCenterColor(0.02, 0.02, 0.02, 0.92)
    control.backdrop:SetEdgeColor(0.18, 0.18, 0.18, 0.95)
    control.backdrop:SetEdgeTexture("", 2, 1, 1)
    control.backdrop:SetInsets(0, 0, -1, -1)

    control.titleLabel = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
    control.titleLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    control.titleLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    control.modeLabel = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
    control.modeLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    control.modeLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    control.summaryPrimaryLabel = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
    control.summaryPrimaryLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    control.summaryPrimaryLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    control.summarySecondaryLabel = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
    control.summarySecondaryLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    control.summarySecondaryLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    control.graphCanvas = WINDOW_MANAGER:CreateControl(nil, control, CT_CONTROL)
    control.graphCanvas:SetMouseEnabled(false)

    control.graphCanvas.backdrop = WINDOW_MANAGER:CreateControl(nil, control.graphCanvas, CT_BACKDROP)
    control.graphCanvas.backdrop:SetAnchorFill(control.graphCanvas)
    control.graphCanvas.backdrop:SetCenterColor(0.05, 0.05, 0.05, 0.28)
    control.graphCanvas.backdrop:SetEdgeColor(0, 0, 0, 0)

    control.graphCanvas.midline = WINDOW_MANAGER:CreateControl(nil, control.graphCanvas, CT_BACKDROP)
    control.graphCanvas.midline:SetMouseEnabled(false)
    control.graphCanvas.midline:SetCenterColor(1, 1, 1, 0.07)
    control.graphCanvas.midline:SetEdgeColor(0, 0, 0, 0)

    control.graphBars = self:CreateBars(control.graphCanvas, self.largeBarCount)

    control.footerLabel = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
    control.footerLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    control.footerLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    self.control = control
end

function DC.dpsGraph:GetPlacement()
    local row = DC.hud and DC.hud.metricRows and DC.hud.metricRows.dps or nil
    local desiredWidth = self:GetWindowWidth()
    local scale = tonumber(self:GetSettings().scale) or 1.0
    local screenWidth = GuiRoot and GuiRoot.GetWidth and GuiRoot:GetWidth() or 0
    local rowLeft = row and row.GetLeft and row:GetLeft() or 0
    local rowRight = row and row.GetRight and row:GetRight() or rowLeft
    local gap = math.max(10, math.floor(12 * scale))
    local leftSpace = math.max(0, rowLeft)
    local rightSpace = math.max(0, screenWidth - rowRight)
    local scaledWidth = desiredWidth * scale
    local minWidth = 240
    local side = "right"
    local finalWidth = desiredWidth

    if rightSpace >= (scaledWidth + gap) then
        side = "right"
    elseif leftSpace >= (scaledWidth + gap) then
        side = "left"
    elseif leftSpace > rightSpace then
        side = "left"
        finalWidth = math.max(minWidth, math.floor((leftSpace / scale) - gap))
    else
        side = "right"
        finalWidth = math.max(minWidth, math.floor((rightSpace / scale) - gap))
    end

    return side, finalWidth, gap
end

function DC.dpsGraph:GetPrimaryValuesFromSample(sample, dpsMode)
    if sample == nil or not DC.dps or not DC.dps.SelectSnapshotDps then
        return 0, nil, nil, "hudDpsAverageShort"
    end

    return DC.dps:SelectSnapshotDps(sample, dpsMode)
end

function DC.dpsGraph:BuildCompressedBuckets(mode, targetCount)
    local samples = DC.dps and DC.dps.GetGraphSamples and DC.dps:GetGraphSamples(mode) or {}
    local dpsMode = DC.dps and DC.dps.GetSelectedDpsMode and DC.dps:GetSelectedDpsMode() or DC.dpsModes.COMPATIBLE
    local sampleCount = #samples
    local barCount = math.max(1, math.floor(tonumber(targetCount) or 1))
    local buckets = {}
    local minValue = nil
    local maxValue = 0
    local lastValue = 0

    if sampleCount <= 0 then
        return buckets, 0, 0, sampleCount, lastValue
    end

    if sampleCount <= barCount then
        for index = 1, sampleCount do
            local playerDps = self:GetPrimaryValuesFromSample(samples[index], dpsMode)
            local safeValue = math.max(0, math.floor(tonumber(playerDps) or 0))

            buckets[index] = {
                minValue = safeValue,
                maxValue = safeValue,
                lastValue = safeValue,
            }

            if minValue == nil or safeValue < minValue then
                minValue = safeValue
            end

            maxValue = math.max(maxValue, safeValue)
            lastValue = safeValue
        end

        return buckets, minValue or 0, maxValue, sampleCount, lastValue
    end

    local bucketSize = sampleCount / barCount

    for bucketIndex = 1, barCount do
        local startIndex = math.floor((bucketIndex - 1) * bucketSize) + 1
        local endIndex = math.min(sampleCount, math.max(startIndex, math.floor(bucketIndex * bucketSize)))
        local bucketMin = nil
        local bucketMax = 0
        local bucketLast = 0

        for sampleIndex = startIndex, endIndex do
            local playerDps = self:GetPrimaryValuesFromSample(samples[sampleIndex], dpsMode)
            local safeValue = math.max(0, math.floor(tonumber(playerDps) or 0))

            if bucketMin == nil or safeValue < bucketMin then
                bucketMin = safeValue
            end

            bucketMax = math.max(bucketMax, safeValue)
            bucketLast = safeValue
        end

        buckets[bucketIndex] = {
            minValue = bucketMin or 0,
            maxValue = bucketMax,
            lastValue = bucketLast,
        }

        if minValue == nil or (bucketMin ~= nil and bucketMin < minValue) then
            minValue = bucketMin
        end

        maxValue = math.max(maxValue, bucketMax)
        lastValue = bucketLast
    end

    return buckets, minValue or 0, maxValue, sampleCount, lastValue
end

function DC.dpsGraph:GetVisualRange(minValue, maxValue)
    local safeMin = math.max(0, math.floor(tonumber(minValue) or 0))
    local safeMax = math.max(safeMin, math.floor(tonumber(maxValue) or 0))
    local currentRange = safeMax - safeMin

    if currentRange >= self.minVisualRange then
        return safeMin, safeMax
    end

    local midpoint = safeMin + (currentRange * 0.5)
    local halfRange = self.minVisualRange * 0.5
    local visualMin = math.max(0, math.floor(midpoint - halfRange))
    local visualMax = math.max(visualMin + 1, math.floor(midpoint + halfRange))

    return visualMin, visualMax
end

function DC.dpsGraph:ComputeSeriesStats(mode)
    local buckets, minValue, maxValue, sampleCount, lastValue = self:BuildCompressedBuckets(mode, self.largeBarCount)
    local peakValue = 0
    local lowValue = nil
    local previousValue = nil

    for _, bucket in ipairs(buckets) do
        peakValue = math.max(peakValue, math.max(0, math.floor(tonumber(bucket.maxValue) or 0)))

        local bucketLow = math.max(0, math.floor(tonumber(bucket.minValue) or 0))
        if lowValue == nil or bucketLow < lowValue then
            lowValue = bucketLow
        end

        previousValue = bucket.lastValue or previousValue
    end

    return {
        minValue = minValue,
        maxValue = maxValue,
        peakValue = peakValue,
        lowValue = lowValue or 0,
        sampleCount = sampleCount,
        lastValue = lastValue or 0,
        previousValue = previousValue or 0,
    }
end

function DC.dpsGraph:UpdateReferenceLine(container, minValue, maxValue, referenceValue)
    if container == nil or container.midline == nil then
        return
    end

    local height = math.max(1, math.floor(container:GetHeight() or 1))
    local visualMin, visualMax = self:GetVisualRange(minValue, maxValue)
    local range = math.max(1, visualMax - visualMin)
    local safeReference = math.max(visualMin, math.min(visualMax, math.floor(tonumber(referenceValue) or 0)))
    local normalized = (safeReference - visualMin) / range
    local bottomOffset = math.max(0, math.min(height - 1, math.floor((height - 1) * normalized + 0.5)))

    container.midline:ClearAnchors()
    container.midline:SetAnchor(BOTTOMLEFT, container, BOTTOMLEFT, 0, -bottomOffset)
    container.midline:SetAnchor(BOTTOMRIGHT, container, BOTTOMRIGHT, 0, -bottomOffset)
    container.midline:SetHeight(1)
end

function DC.dpsGraph:DrawBars(container, bars, buckets, minValue, maxValue)
    if container == nil or bars == nil then
        return
    end

    local totalBars = #bars
    local width = math.max(1, math.floor(container:GetWidth() or 1))
    local height = math.max(1, math.floor(container:GetHeight() or 1))
    local labelColorR, labelColorG, labelColorB = 1, 1, 1
    local valueColorR, valueColorG, valueColorB = 1, 1, 1

    if DC.hud and DC.hud.GetLabelColor then
        labelColorR, labelColorG, labelColorB = DC.hud:GetLabelColor()
    end

    if DC.hud and DC.hud.GetValueColor then
        valueColorR, valueColorG, valueColorB = DC.hud:GetValueColor()
    end

    local activeCount = math.min(#buckets, totalBars)
    local visibleCount = math.max(1, activeCount)
    local barWidth = width / visibleCount
    local visualMin, visualMax = self:GetVisualRange(minValue, maxValue)
    local valueRange = math.max(1, visualMax - visualMin)

    for barIndex = 1, totalBars do
        local bar = bars[barIndex]

        bar:ClearAnchors()

        if barIndex <= activeCount then
            local bucket = buckets[barIndex]
            local bucketMin = math.max(0, math.floor(tonumber(bucket and bucket.minValue) or 0))
            local bucketMax = math.max(bucketMin, math.floor(tonumber(bucket and bucket.maxValue) or 0))
            local bucketLast = math.max(bucketMin, math.floor(tonumber(bucket and bucket.lastValue) or 0))
            local normalizedMin = (math.max(visualMin, math.min(visualMax, bucketMin)) - visualMin) / valueRange
            local normalizedMax = (math.max(visualMin, math.min(visualMax, bucketMax)) - visualMin) / valueRange
            local normalizedLast = (math.max(visualMin, math.min(visualMax, bucketLast)) - visualMin) / valueRange
            local bottomOffset = math.max(0, math.floor((height - 2) * normalizedMin))
            local topOffset = math.max(bottomOffset + 2, math.floor((height - 2) * normalizedMax))
            local barHeight = math.max(2, topOffset - bottomOffset)
            local ageT = activeCount > 1 and ((barIndex - 1) / (activeCount - 1)) or 1
            local lastBias = math.max(0.15, normalizedLast)
            local alpha = 0.20 + (ageT * 0.62)
            local mix = math.max(0.30, math.min(1.0, (0.35 + (ageT * 0.45)) + (lastBias * 0.2)))
            local red = (labelColorR * (1 - mix)) + (valueColorR * mix)
            local green = (labelColorG * (1 - mix)) + (valueColorG * mix)
            local blue = (labelColorB * (1 - mix)) + (valueColorB * mix)
            local leftOffset = math.floor((barIndex - 1) * barWidth)
            local rightOffset = math.floor(barIndex * barWidth)
            local finalWidth = math.max(1, rightOffset - leftOffset - 1)

            bar:SetAnchor(BOTTOMLEFT, container, BOTTOMLEFT, leftOffset, -bottomOffset)
            bar:SetDimensions(finalWidth, barHeight)
            bar:SetCenterColor(red, green, blue, alpha)
            bar:SetHidden(false)
        else
            bar:SetHidden(true)
        end
    end
end

function DC.dpsGraph:RefreshMiniSparkline(now)
    if not DC.hud or not DC.hud.metricRows then
        return
    end

    local row = DC.hud.metricRows.dps

    if row == nil or row.sparkline == nil or row:IsHidden() then
        return
    end

    local currentNow = math.max(0, math.floor(tonumber(now) or (GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0)))

    if self.lastMiniRefreshAt > 0 and (currentNow - self.lastMiniRefreshAt) < self.miniRefreshIntervalMs then
        return
    end

    local buckets, minValue, maxValue = self:BuildCompressedBuckets(self:GetSelectedDisplayMode(), self.miniBarCount)
    self:DrawBars(row.sparkline, row.sparkline.bars, buckets, minValue, maxValue)
    self.lastMiniRefreshAt = currentNow
end

function DC.dpsGraph:ApplyFonts()
    if self.control == nil or not DC.hud or not DC.hud.BuildFont then
        return
    end

    local settings = self:GetSettings()

    self.control.titleLabel:SetFont(DC.hud:BuildFont(settings.labelFontFace, math.max(13, (settings.tooltipFontSize or 15) + 1)))
    self.control.modeLabel:SetFont(DC.hud:BuildFont(settings.labelFontFace, math.max(12, settings.tooltipFontSize or 15)))
    self.control.summaryPrimaryLabel:SetFont(DC.hud:BuildFont(settings.valueFontFace, math.max(12, settings.tooltipFontSize or 15)))
    self.control.summarySecondaryLabel:SetFont(DC.hud:BuildFont(settings.valueFontFace, math.max(11, (settings.tooltipFontSize or 15) - 1)))
    self.control.footerLabel:SetFont(DC.hud:BuildFont(settings.labelFontFace, math.max(11, (settings.tooltipFontSize or 15) - 2)))
end

function DC.dpsGraph:ApplyColors()
    if self.control == nil then
        return
    end

    local labelColorR, labelColorG, labelColorB, labelColorA = 1, 1, 1, 1
    local valueColorR, valueColorG, valueColorB, valueColorA = 1, 1, 1, 1

    if DC.hud and DC.hud.GetLabelColor then
        labelColorR, labelColorG, labelColorB, labelColorA = DC.hud:GetLabelColor()
    end

    if DC.hud and DC.hud.GetValueColor then
        valueColorR, valueColorG, valueColorB, valueColorA = DC.hud:GetValueColor()
    end

    self.control.titleLabel:SetColor(labelColorR, labelColorG, labelColorB, labelColorA)
    self.control.modeLabel:SetColor(labelColorR, labelColorG, labelColorB, labelColorA)
    self.control.summaryPrimaryLabel:SetColor(valueColorR, valueColorG, valueColorB, valueColorA)
    self.control.summarySecondaryLabel:SetColor(labelColorR, labelColorG, labelColorB, labelColorA)
    self.control.footerLabel:SetColor(labelColorR, labelColorG, labelColorB, labelColorA)
    self.control.graphCanvas.midline:SetCenterColor(labelColorR, labelColorG, labelColorB, 0.10)
end

function DC.dpsGraph:ApplyLayout()
    if self.control == nil or not DC.hud or not DC.hud.metricRows or DC.hud.metricRows.dps == nil then
        return
    end

    local side, width, gap = self:GetPlacement()
    local graphHeight = self:GetGraphCanvasHeight()
    local controlHeight = self:GetWindowHeight()
    local row = DC.hud.metricRows.dps

    self.control:SetDimensions(width, controlHeight)
    self.control:SetScale(self:GetSettings().scale or 1.0)
    self.control:ClearAnchors()

    if side == "left" then
        self.control:SetAnchor(TOPRIGHT, row, TOPLEFT, -gap, -2)
    else
        self.control:SetAnchor(TOPLEFT, row, TOPRIGHT, gap, -2)
    end

    self.control.titleLabel:ClearAnchors()
    self.control.titleLabel:SetAnchor(TOPLEFT, self.control, TOPLEFT, 12, 10)
    self.control.titleLabel:SetAnchor(TOPRIGHT, self.control, TOPRIGHT, -12, 10)
    self.control.titleLabel:SetHeight(18)

    self.control.modeLabel:ClearAnchors()
    self.control.modeLabel:SetAnchor(TOPLEFT, self.control.titleLabel, BOTTOMLEFT, 0, 4)
    self.control.modeLabel:SetAnchor(TOPRIGHT, self.control.titleLabel, BOTTOMRIGHT, 0, 4)
    self.control.modeLabel:SetHeight(16)

    self.control.summaryPrimaryLabel:ClearAnchors()
    self.control.summaryPrimaryLabel:SetAnchor(TOPLEFT, self.control.modeLabel, BOTTOMLEFT, 0, 6)
    self.control.summaryPrimaryLabel:SetAnchor(TOPRIGHT, self.control.modeLabel, BOTTOMRIGHT, 0, 6)
    self.control.summaryPrimaryLabel:SetHeight(18)

    self.control.summarySecondaryLabel:ClearAnchors()
    self.control.summarySecondaryLabel:SetAnchor(TOPLEFT, self.control.summaryPrimaryLabel, BOTTOMLEFT, 0, 2)
    self.control.summarySecondaryLabel:SetAnchor(TOPRIGHT, self.control.summaryPrimaryLabel, BOTTOMRIGHT, 0, 2)
    self.control.summarySecondaryLabel:SetHeight(16)

    self.control.graphCanvas:ClearAnchors()
    self.control.graphCanvas:SetAnchor(TOPLEFT, self.control.summarySecondaryLabel, BOTTOMLEFT, 0, 8)
    self.control.graphCanvas:SetAnchor(TOPRIGHT, self.control.summarySecondaryLabel, BOTTOMRIGHT, 0, 8)
    self.control.graphCanvas:SetHeight(graphHeight)

    self.control.footerLabel:ClearAnchors()
    self.control.footerLabel:SetAnchor(TOPLEFT, self.control.graphCanvas, BOTTOMLEFT, 0, 8)
    self.control.footerLabel:SetAnchor(TOPRIGHT, self.control.graphCanvas, BOTTOMRIGHT, 0, 8)
    self.control.footerLabel:SetHeight(16)
end

function DC.dpsGraph:UpdateWindowText(now)
    if self.control == nil or not DC.dps or not DC.dps.BuildDisplaySnapshot then
        return
    end

    local mode = self:GetSelectedDisplayMode()
    local snapshot = DC.dps:BuildDisplaySnapshot(mode, now)
    local playerText = DC.formatter:FormatFull(snapshot.playerDps or 0)
    local secondaryText = snapshot.secondaryPlayerDps ~= nil and DC.formatter:FormatFull(snapshot.secondaryPlayerDps) or nil
    local combatTimeText = DC.hud and DC.hud.FormatCombatTime and DC.hud:FormatCombatTime(snapshot.combatDurationMs or 0) or "00:00.000"
    local primaryParts = {
        string.format("%s: %s", DC:GetString("hudDpsLabel"), playerText),
    }
    local secondaryParts = {}
    local samples = DC.dps:GetGraphSamples(mode)
    local seriesStats = self:ComputeSeriesStats(mode)

    self.control.titleLabel:SetText(DC:GetString("dpsGraphTitle"))
    self.control.modeLabel:SetText(self:GetDisplayModeLabel(mode))

    if secondaryText ~= nil then
        table.insert(primaryParts, string.format("%s %s", DC:GetString(snapshot.secondaryLabelKey or "hudDpsAverageShort"), secondaryText))
    end

    if snapshot.groupDps ~= nil then
        table.insert(secondaryParts, string.format("%s: %s", DC:GetString("hudDpsGroupLabel"), DC.formatter:FormatFull(snapshot.groupDps)))
    end

    if snapshot.sharePercent ~= nil then
        table.insert(secondaryParts, string.format("%s: %d%%", DC:GetString("dpsGraphShareLabel"), snapshot.sharePercent))
    end

    table.insert(secondaryParts, string.format("%s: %s", DC:GetString("dpsGraphPeakLabel"), DC.formatter:FormatFull(seriesStats.peakValue or 0)))
    table.insert(secondaryParts, string.format("%s: %s", DC:GetString("dpsGraphLowLabel"), DC.formatter:FormatFull(seriesStats.lowValue or 0)))

    self.control.summaryPrimaryLabel:SetText(table.concat(primaryParts, " | "))
    self.control.summarySecondaryLabel:SetText(table.concat(secondaryParts, " | "))
    self.control.summarySecondaryLabel:SetHidden(#secondaryParts == 0)

    if #samples <= 0 then
        self.control.footerLabel:SetText(DC:GetString("dpsGraphNoData"))
        return
    end

    self.control.footerLabel:SetText(string.format("%s: %s | %s | %s: %s-%s",
        DC:GetString("hudCombatTimeLabel"),
        combatTimeText,
        DC:GetString("dpsGraphSamplesLabel", #samples),
        DC:GetString("dpsGraphRangeLabel"),
        DC.formatter:FormatFull(seriesStats.lowValue or 0),
        DC.formatter:FormatFull(seriesStats.peakValue or 0)
    ))
end

function DC.dpsGraph:UpdateWindowGraph()
    if self.control == nil then
        return
    end

    local mode = self:GetSelectedDisplayMode()
    local buckets, minValue, maxValue, _, lastValue = self:BuildCompressedBuckets(mode, self.largeBarCount)
    self:DrawBars(self.control.graphCanvas, self.control.graphBars, buckets, minValue, maxValue)
    self:UpdateReferenceLine(self.control.graphCanvas, minValue, maxValue, lastValue)
end

function DC.dpsGraph:RefreshWindow(now)
    if self.control == nil then
        return
    end

    local currentNow = math.max(0, math.floor(tonumber(now) or (GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0)))

    if self.lastWindowRefreshAt > 0 and (currentNow - self.lastWindowRefreshAt) < self.windowRefreshIntervalMs then
        return
    end

    self:ApplyLayout()
    self:ApplyFonts()
    self:ApplyColors()
    self:UpdateWindowText(currentNow)
    self:UpdateWindowGraph()
    self.lastWindowRefreshAt = currentNow
end

function DC.dpsGraph:IsVisible()
    return self.control ~= nil and not self.control:IsHidden()
end

function DC.dpsGraph:IsHoverActive()
    local row = DC.hud and DC.hud.metricRows and DC.hud.metricRows.dps or nil

    if row ~= nil and MouseIsOver and MouseIsOver(row, 0, 0, 0, 0) then
        return true
    end

    if self.control ~= nil and MouseIsOver and MouseIsOver(self.control, 0, 0, 0, 0) then
        return true
    end

    return false
end

function DC.dpsGraph:ShouldSuppressStatsTooltip()
    return self:IsHoverActive()
end

function DC.dpsGraph:ShouldBeVisible()
    if self.control == nil or not DC.hud or DC.hud.control == nil then
        return false
    end

    if not self:GetSettings().showHud or DC.hud.control:IsHidden() then
        return false
    end

    if DC.hud.metricRows == nil or DC.hud.metricRows.dps == nil or DC.hud.metricRows.dps:IsHidden() then
        return false
    end

    if self:IsHoverActive() then
        return true
    end

    return self:IsAutoShowEnabled() and DC.dps and DC.dps.IsEncounterLive and DC.dps:IsEncounterLive()
end

function DC.dpsGraph:Show(now)
    if self.control == nil then
        return
    end

    self.control:SetHidden(false)
    self.lastWindowRefreshAt = 0
    self:RefreshWindow(now)
end

function DC.dpsGraph:Hide()
    if self.control == nil then
        return
    end

    self.control:SetHidden(true)
end

function DC.dpsGraph:RefreshVisibility(now)
    if self:ShouldBeVisible() then
        if not self:IsVisible() then
            self:Show(now)
        else
            self:RefreshWindow(now)
        end
    elseif self:IsVisible() then
        self:Hide()
    end
end

function DC.dpsGraph:Refresh()
    self.lastMiniRefreshAt = 0
    self.lastWindowRefreshAt = 0
    self:RefreshMiniSparkline(GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0)

    if self:IsVisible() then
        self:RefreshWindow(GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0)
    else
        self:RefreshVisibility(GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0)
    end
end

function DC.dpsGraph:OnCombatStateChanged(isActive)
    local now = GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0

    self.lastWindowRefreshAt = 0
    self.lastMiniRefreshAt = 0

    if isActive and self:IsAutoShowEnabled() then
        self:Show(now)
        return
    end

    self:RefreshVisibility(now)
end

function DC.dpsGraph:OnUpdate(now)
    local currentNow = math.max(0, math.floor(tonumber(now) or (GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0)))

    if DC.dps and DC.dps.UpdateGraphHistories then
        DC.dps:UpdateGraphHistories(currentNow, false)
    end

    self:RefreshMiniSparkline(currentNow)
    self:RefreshVisibility(currentNow)
end

function DC.dpsGraph:Initialize()
    self.lastMiniRefreshAt = 0
    self.lastWindowRefreshAt = 0
    self:CreateControl()
end
