local DC = DamageCalculation

DC.dpsGraph = {
    name = "DamageCalculationDpsGraph",
    miniBarCount = 60,
    miniHeight = 12,
    miniGap = 4,
    minVisualRange = 1500,
    miniPaddingX = 6,
    graphPaddingX = 10,
    graphTopSpacing = 30,
    graphWarmupFloorMs = 1000,
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

function DC.dpsGraph:ClampColor(value)
    return math.max(0, math.min(1, tonumber(value) or 0))
end

function DC.dpsGraph:ClampPointCount(value, minCount, maxCount, fallback)
    local safeMin = math.max(1, math.floor(tonumber(minCount) or 1))
    local safeMax = math.max(safeMin, math.floor(tonumber(maxCount) or safeMin))
    local safeFallback = math.max(safeMin, math.min(safeMax, math.floor(tonumber(fallback) or safeMin)))

    return math.max(safeMin, math.min(safeMax, math.floor(tonumber(value) or safeFallback)))
end

function DC.dpsGraph:IsMiniGraphEnabled()
    return self:GetSettings().showMiniDpsGraph ~= false
end

function DC.dpsGraph:IsLargeGraphEnabled()
    return self:GetSettings().showLargeDpsGraph ~= false
end

function DC.dpsGraph:GetLargePointCount()
    return DC:GetDpsGraphPointCount()
end

function DC.dpsGraph:GetMiniPointCount()
    local configuredPointCount = self:GetLargePointCount()
    return math.max(18, math.min(self.miniBarCount, math.floor((configuredPointCount * 0.5) + 0.5)))
end

function DC.dpsGraph:GetWindowWidth()
    if DC.hud and DC.hud.GetHudWidth then
        return math.max(360, math.floor(DC.hud:GetHudWidth() * 1.12))
    end

    return 380
end

function DC.dpsGraph:GetWindowHeight()
    return 250
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

function DC.dpsGraph:GetSelectedGraphMode()
    local configuredMode = self:GetSettings().dpsGraphMode

    if configuredMode == DC.graphModes.BURST then
        return DC.graphModes.BURST
    end

    if configuredMode == DC.graphModes.ROLLING then
        return DC.graphModes.ROLLING
    end

    return DC.graphModes.TREND
end

function DC.dpsGraph:GetDisplayModeLabel(mode)
    if mode == DC.displayModes.SESSION then
        return DC:GetString("displayModeSession")
    end

    return DC:GetString("displayModeTotal")
end

function DC.dpsGraph:GetGraphModeLabel(mode)
    if mode == DC.graphModes.BURST then
        return DC:GetString("graphModeBurst")
    end

    if mode == DC.graphModes.ROLLING then
        return DC:GetString("graphModeRolling")
    end

    return DC:GetString("graphModeTrend")
end

function DC.dpsGraph:CreateColumns(parent, barCount, includeSecondary)
    local columns = {}

    for index = 1, math.max(1, math.floor(tonumber(barCount) or 1)) do
        local column = {}

        column.fill = WINDOW_MANAGER:CreateControl(nil, parent, CT_BACKDROP)
        column.fill:SetMouseEnabled(false)
        column.fill:SetEdgeColor(0, 0, 0, 0)
        column.fill:SetCenterColor(1, 1, 1, 0.22)
        column.fill:SetHidden(true)

        column.primaryCap = WINDOW_MANAGER:CreateControl(nil, parent, CT_BACKDROP)
        column.primaryCap:SetMouseEnabled(false)
        column.primaryCap:SetEdgeColor(0, 0, 0, 0)
        column.primaryCap:SetCenterColor(1, 1, 1, 0.75)
        column.primaryCap:SetHidden(true)

        if includeSecondary then
            column.secondaryMarker = WINDOW_MANAGER:CreateControl(nil, parent, CT_BACKDROP)
            column.secondaryMarker:SetMouseEnabled(false)
            column.secondaryMarker:SetEdgeColor(0, 0, 0, 0)
            column.secondaryMarker:SetCenterColor(1, 1, 1, 0.85)
            column.secondaryMarker:SetHidden(true)
        end

        columns[index] = column
    end

    return columns
end

function DC.dpsGraph:HideColumns(columns)
    if columns == nil then
        return
    end

    for _, column in ipairs(columns) do
        if column.fill ~= nil then
            column.fill:SetHidden(true)
        end

        if column.primaryCap ~= nil then
            column.primaryCap:SetHidden(true)
        end

        if column.secondaryMarker ~= nil then
            column.secondaryMarker:SetHidden(true)
        end
    end
end

function DC.dpsGraph:EnsureMiniColumns(row, targetCount)
    if row == nil or row.sparkline == nil then
        return
    end

    local desiredCount = self:ClampPointCount(targetCount, 1, self.miniBarCount, self:GetMiniPointCount())
    local currentColumns = row.sparkline.columns or {}

    if #currentColumns == desiredCount then
        return
    end

    self:HideColumns(currentColumns)
    row.sparkline.columns = self:CreateColumns(row.sparkline, desiredCount, true)
end

function DC.dpsGraph:EnsureLargeColumns(targetCount)
    if self.control == nil or self.control.graphCanvas == nil then
        return
    end

    local desiredCount = self:ClampPointCount(targetCount, DC.dpsGraphPointLimits.min, DC.dpsGraphPointLimits.max, self:GetLargePointCount())
    local currentColumns = self.control.graphColumns or {}

    if #currentColumns == desiredCount then
        return
    end

    self:HideColumns(currentColumns)
    self.control.graphColumns = self:CreateColumns(self.control.graphCanvas, desiredCount, true)
end

function DC.dpsGraph:AttachMiniSparkline(row)
    if row == nil or row.sparkline ~= nil then
        return
    end

    row.sparkline = WINDOW_MANAGER:CreateControl(nil, row, CT_CONTROL)
    row.sparkline:SetMouseEnabled(false)
    row.sparkline.backdrop = WINDOW_MANAGER:CreateControl(nil, row.sparkline, CT_BACKDROP)
    row.sparkline.backdrop:SetAnchorFill(row.sparkline)
    row.sparkline.backdrop:SetCenterColor(0.04, 0.04, 0.04, 0.12)
    row.sparkline.backdrop:SetEdgeColor(0, 0, 0, 0)
    row.sparkline.columns = self:CreateColumns(row.sparkline, self:GetMiniPointCount(), true)
    row.sparkline.innerPaddingX = self.miniPaddingX
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

    control.graphCanvas.innerPaddingX = self.graphPaddingX
    control.graphColumns = self:CreateColumns(control.graphCanvas, self:GetLargePointCount(), true)

    control.graphCanvas.peakMarker = WINDOW_MANAGER:CreateControl(nil, control.graphCanvas, CT_BACKDROP)
    control.graphCanvas.peakMarker:SetMouseEnabled(false)
    control.graphCanvas.peakMarker:SetEdgeColor(0, 0, 0, 0)
    control.graphCanvas.peakMarker:SetCenterColor(1.0, 0.95, 0.65, 0.95)
    control.graphCanvas.peakMarker:SetHidden(true)

    control.graphCanvas.peakLabel = WINDOW_MANAGER:CreateControl(nil, control.graphCanvas, CT_LABEL)
    control.graphCanvas.peakLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    control.graphCanvas.peakLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    control.graphCanvas.peakLabel:SetHidden(true)

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

function DC.dpsGraph:GetTrendValuesFromSample(sample)
    if sample == nil then
        return 0, 0, "hudDpsActiveShort", "hudDpsAverageShort"
    end

    local dpsMode = DC.dps and DC.dps.GetSelectedDpsMode and DC.dps:GetSelectedDpsMode() or DC.dpsModes.COMPATIBLE

    if dpsMode == DC.dpsModes.AVERAGE then
        return sample.averagePlayerDps or 0, sample.activePlayerDps or 0, "hudDpsAverageShort", "hudDpsActiveShort"
    end

    return sample.activePlayerDps or 0, sample.averagePlayerDps or 0, "hudDpsActiveShort", "hudDpsAverageShort"
end

function DC.dpsGraph:GetWarmupCappedValue(sample, value)
    if sample == nil then
        return math.max(0, math.floor(tonumber(value) or 0))
    end

    local safeValue = math.max(0, math.floor(tonumber(value) or 0))
    local totalDamage = math.max(0, math.floor(tonumber(sample.encounterPlayerDamage) or tonumber(sample.playerDamage) or 0))
    local combatDurationMs = math.max(0, math.floor(tonumber(sample.encounterDurationMs) or tonumber(sample.combatDurationMs) or 0))
    local cappedDurationMs = math.max(self.graphWarmupFloorMs, combatDurationMs)

    if totalDamage <= 0 or cappedDurationMs <= 0 then
        return safeValue
    end

    local capValue = math.max(0, math.floor(totalDamage / (cappedDurationMs / 1000)))
    return math.min(safeValue, capValue)
end

function DC.dpsGraph:ShouldIncludeSample(sample)
    if sample == nil then
        return false
    end

    local encounterDamage = math.max(0, math.floor(tonumber(sample.encounterPlayerDamage) or 0))
    local encounterDurationMs = math.max(0, math.floor(tonumber(sample.encounterDurationMs) or 0))

    if encounterDamage <= 0 then
        return false
    end

    if encounterDurationMs < self.graphWarmupFloorMs then
        return false
    end

    return true
end

function DC.dpsGraph:CalculatePointDps(damageDelta, timeDeltaMs)
    local safeDamageDelta = math.max(0, math.floor(tonumber(damageDelta) or 0))
    local safeTimeDeltaMs = math.max(0, math.floor(tonumber(timeDeltaMs) or 0))

    if safeDamageDelta <= 0 or safeTimeDeltaMs <= 0 then
        return 0
    end

    return math.max(0, math.floor(safeDamageDelta / (safeTimeDeltaMs / 1000)))
end

function DC.dpsGraph:CalculateRollingFiveSecondValue(samples, sampleIndex)
    local sample = samples[sampleIndex]

    if sample == nil then
        return 0
    end

    local currentTimestamp = math.max(0, math.floor(tonumber(sample.timestamp) or 0))
    local currentDamage = math.max(0, math.floor(tonumber(sample.playerDamage) or 0))
    local windowStart = currentTimestamp - 5000
    local anchorIndex = sampleIndex

    while anchorIndex > 1 and (tonumber(samples[anchorIndex - 1].timestamp) or 0) >= windowStart do
        anchorIndex = anchorIndex - 1
    end

    local anchorSample = samples[anchorIndex]
    local anchorTimestamp = math.max(0, math.floor(tonumber(anchorSample and anchorSample.timestamp) or currentTimestamp))
    local anchorDamage = math.max(0, math.floor(tonumber(anchorSample and anchorSample.playerDamage) or currentDamage))

    return self:CalculatePointDps(currentDamage - anchorDamage, currentTimestamp - anchorTimestamp)
end

function DC.dpsGraph:CalculateBurstDisplayValue(samples, sampleIndex)
    local sample = samples[sampleIndex]

    if sample == nil then
        return 0
    end

    local currentTimestamp = math.max(0, math.floor(tonumber(sample.timestamp) or 0))
    local peakBurst = 0

    for previousIndex = math.max(2, sampleIndex - 3), sampleIndex do
        local currentSample = samples[previousIndex]
        local previousSample = samples[previousIndex - 1]

        if currentSample ~= nil and previousSample ~= nil then
            local currentPointTimestamp = math.max(0, math.floor(tonumber(currentSample.timestamp) or currentTimestamp))

            if (currentTimestamp - currentPointTimestamp) <= 1000 then
                local damageDelta = (currentSample.playerDamage or 0) - (previousSample.playerDamage or currentSample.playerDamage or 0)
                local timeDeltaMs = (currentSample.timestamp or 0) - (previousSample.timestamp or currentSample.timestamp or 0)
                peakBurst = math.max(peakBurst, self:CalculatePointDps(damageDelta, timeDeltaMs))
            end
        end
    end

    return peakBurst
end

function DC.dpsGraph:CalculateTrendDisplayValue(samples, sampleIndex, baseTrendValue)
    local safeBaseTrend = math.max(0, math.floor(tonumber(baseTrendValue) or 0))

    if safeBaseTrend <= 0 then
        return 0
    end

    local burstValue = self:CalculateBurstDisplayValue(samples, sampleIndex)
    local rollingValue = self:CalculateRollingFiveSecondValue(samples, sampleIndex)
    local reactiveValue = math.floor((burstValue * 0.62) + (rollingValue * 0.38) + 0.5)

    if reactiveValue <= safeBaseTrend then
        return math.max(0, math.floor((safeBaseTrend * 0.28) + (reactiveValue * 0.72) + 0.5))
    end

    return math.max(0, math.floor((safeBaseTrend * 0.60) + (reactiveValue * 0.40) + 0.5))
end

function DC.dpsGraph:BuildRawSeries(mode)
    local samples = DC.dps and DC.dps.GetGraphSamples and DC.dps:GetGraphSamples(mode) or {}
    local graphMode = self:GetSelectedGraphMode()
    local rawSeries = {}
    local meta = {
        graphMode = graphMode,
        primaryLabel = self:GetGraphModeLabel(graphMode),
        secondaryLabel = "",
        secondaryLabelKey = "",
    }

    for sampleIndex, sample in ipairs(samples) do
        if self:ShouldIncludeSample(sample) then
            local trendPrimary, trendSecondary, trendPrimaryKey, trendSecondaryKey = self:GetTrendValuesFromSample(sample)
            local primaryValue = trendPrimary
            local secondaryValue = trendSecondary

            if graphMode == DC.graphModes.BURST then
                primaryValue = self:CalculateBurstDisplayValue(samples, sampleIndex)
                secondaryValue = trendSecondary
                meta.secondaryLabel = DC:GetString(trendSecondaryKey)
                meta.secondaryLabelKey = trendSecondaryKey
            elseif graphMode == DC.graphModes.ROLLING then
                primaryValue = self:CalculateRollingFiveSecondValue(samples, sampleIndex)
                secondaryValue = trendSecondary
                meta.secondaryLabel = DC:GetString(trendSecondaryKey)
                meta.secondaryLabelKey = trendSecondaryKey
            else
                primaryValue = self:CalculateTrendDisplayValue(samples, sampleIndex, trendPrimary)
                secondaryValue = trendSecondary
                meta.primaryLabel = DC:GetString(trendPrimaryKey)
                meta.secondaryLabel = DC:GetString(trendSecondaryKey)
                meta.secondaryLabelKey = trendSecondaryKey
            end

            primaryValue = self:GetWarmupCappedValue(sample, primaryValue)
            secondaryValue = self:GetWarmupCappedValue(sample, secondaryValue)

            table.insert(rawSeries, {
                timestamp = math.max(0, math.floor(tonumber(sample.timestamp) or 0)),
                primaryValue = math.max(0, math.floor(tonumber(primaryValue) or 0)),
                secondaryValue = math.max(0, math.floor(tonumber(secondaryValue) or 0)),
            })
        end
    end

    if graphMode ~= DC.graphModes.TREND and meta.secondaryLabel == "" then
        meta.secondaryLabel = DC:GetString("hudDpsAverageShort")
        meta.secondaryLabelKey = "hudDpsAverageShort"
    end

    return rawSeries, meta
end

function DC.dpsGraph:BuildCompressedBuckets(mode, targetCount)
    local rawSeries, meta = self:BuildRawSeries(mode)
    local sampleCount = #rawSeries
    local bucketCount = self:ClampPointCount(targetCount, 1, DC.dpsGraphPointLimits.max, 1)
    local buckets = {}
    local primaryMin = nil
    local primaryMax = 0
    local secondaryMin = nil
    local secondaryMax = 0
    local peakIndex = 1
    local lastValue = 0
    local previousValue = 0
    local lastSecondaryValue = 0

    if sampleCount <= 0 then
        return {
            buckets = buckets,
            meta = meta,
            pointCount = 0,
            sampleCount = 0,
            primaryMin = 0,
            primaryMax = 0,
            secondaryMin = 0,
            secondaryMax = 0,
            lowValue = 0,
            peakValue = 0,
            peakIndex = 1,
            bucketCount = 0,
            lastValue = 0,
            previousValue = 0,
            lastSecondaryValue = 0,
        }
    end

    local function absorbPoint(point)
        if point == nil then
            return
        end

        local pointPrimary = math.max(0, math.floor(tonumber(point.primaryValue) or 0))
        local pointSecondary = math.max(0, math.floor(tonumber(point.secondaryValue) or 0))

        if primaryMin == nil or pointPrimary < primaryMin then
            primaryMin = pointPrimary
        end

        if secondaryMin == nil or pointSecondary < secondaryMin then
            secondaryMin = pointSecondary
        end

        primaryMax = math.max(primaryMax, pointPrimary)
        secondaryMax = math.max(secondaryMax, pointSecondary)
    end

    for pointIndex, point in ipairs(rawSeries) do
        absorbPoint(point)

        if (point.primaryValue or 0) >= primaryMax then
            peakIndex = pointIndex
        end
    end

    lastValue = rawSeries[sampleCount].primaryValue or 0
    lastSecondaryValue = rawSeries[sampleCount].secondaryValue or 0
    previousValue = sampleCount > 1 and (rawSeries[sampleCount - 1].primaryValue or lastValue) or lastValue

    if sampleCount == 1 then
        local singlePoint = rawSeries[1]
        local singlePrimary = math.max(0, math.floor(tonumber(singlePoint and singlePoint.primaryValue) or 0))
        local singleSecondary = math.max(0, math.floor(tonumber(singlePoint and singlePoint.secondaryValue) or 0))

        for bucketIndex = 1, bucketCount do
            buckets[bucketIndex] = {
                primaryMin = singlePrimary,
                primaryMax = singlePrimary,
                primaryLast = singlePrimary,
                secondaryLast = singleSecondary,
            }
        end
    elseif sampleCount < bucketCount then
        for bucketIndex = 1, bucketCount do
            local progress = (bucketIndex - 1) / math.max(1, bucketCount - 1)
            local samplePosition = 1 + ((sampleCount - 1) * progress)
            local leftIndex = math.max(1, math.min(sampleCount, math.floor(samplePosition)))
            local rightIndex = math.max(leftIndex, math.min(sampleCount, math.ceil(samplePosition)))
            local lerpT = samplePosition - leftIndex
            local leftPoint = rawSeries[leftIndex]
            local rightPoint = rawSeries[rightIndex]
            local leftPrimary = math.max(0, math.floor(tonumber(leftPoint and leftPoint.primaryValue) or 0))
            local rightPrimary = math.max(0, math.floor(tonumber(rightPoint and rightPoint.primaryValue) or leftPrimary))
            local leftSecondary = math.max(0, math.floor(tonumber(leftPoint and leftPoint.secondaryValue) or 0))
            local rightSecondary = math.max(0, math.floor(tonumber(rightPoint and rightPoint.secondaryValue) or leftSecondary))
            local interpolatedPrimary = math.floor(leftPrimary + ((rightPrimary - leftPrimary) * lerpT) + 0.5)
            local interpolatedSecondary = math.floor(leftSecondary + ((rightSecondary - leftSecondary) * lerpT) + 0.5)

            buckets[bucketIndex] = {
                primaryMin = math.min(leftPrimary, rightPrimary, interpolatedPrimary),
                primaryMax = math.max(leftPrimary, rightPrimary, interpolatedPrimary),
                primaryLast = interpolatedPrimary,
                secondaryLast = interpolatedSecondary,
            }
        end
    else
        local bucketSize = sampleCount / bucketCount

        for bucketIndex = 1, bucketCount do
            local startIndex = math.floor((bucketIndex - 1) * bucketSize) + 1
            local endIndex = math.max(startIndex, math.floor(bucketIndex * bucketSize))
            local bucketPrimaryMin = nil
            local bucketPrimaryMax = 0
            local bucketPrimaryLast = 0
            local bucketSecondaryLast = 0

            startIndex = math.max(1, math.min(sampleCount, startIndex))
            endIndex = math.max(startIndex, math.min(sampleCount, endIndex))

            for pointIndex = startIndex, endIndex do
                local point = rawSeries[pointIndex]
                local pointPrimary = math.max(0, math.floor(tonumber(point and point.primaryValue) or 0))
                local pointSecondary = math.max(0, math.floor(tonumber(point and point.secondaryValue) or 0))

                if bucketPrimaryMin == nil or pointPrimary < bucketPrimaryMin then
                    bucketPrimaryMin = pointPrimary
                end

                bucketPrimaryMax = math.max(bucketPrimaryMax, pointPrimary)
                bucketPrimaryLast = pointPrimary
                bucketSecondaryLast = pointSecondary
            end

            buckets[bucketIndex] = {
                primaryMin = bucketPrimaryMin or 0,
                primaryMax = bucketPrimaryMax,
                primaryLast = bucketPrimaryLast,
                secondaryLast = bucketSecondaryLast,
            }
        end
    end

    if sampleCount > 1 then
        local scaledPeakIndex = math.ceil((peakIndex / sampleCount) * #buckets)
        peakIndex = math.max(1, math.min(#buckets, scaledPeakIndex))
    else
        peakIndex = 1
    end

    return {
        buckets = buckets,
        meta = meta,
        pointCount = #buckets,
        sampleCount = sampleCount,
        primaryMin = primaryMin or 0,
        primaryMax = primaryMax,
        secondaryMin = secondaryMin or 0,
        secondaryMax = secondaryMax,
        lowValue = primaryMin or 0,
        peakValue = primaryMax,
        peakIndex = peakIndex,
        bucketCount = #buckets,
        lastValue = lastValue,
        previousValue = previousValue,
        lastSecondaryValue = lastSecondaryValue,
    }
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

function DC.dpsGraph:LerpColorChannel(fromValue, toValue, progress)
    local t = self:ClampColor(progress)
    return fromValue + ((toValue - fromValue) * t)
end

function DC.dpsGraph:BlendRgb(fromColor, toColor, progress)
    return {
        self:ClampColor(self:LerpColorChannel(fromColor[1], toColor[1], progress)),
        self:ClampColor(self:LerpColorChannel(fromColor[2], toColor[2], progress)),
        self:ClampColor(self:LerpColorChannel(fromColor[3], toColor[3], progress)),
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

function DC.dpsGraph:UpdatePeakMarker(container, dataset, width, height, visualMin, visualMax)
    if container == nil or container.peakMarker == nil or container.peakLabel == nil then
        return
    end

    local buckets = dataset and dataset.buckets or nil

    if buckets == nil or #buckets <= 0 then
        container.peakMarker:SetHidden(true)
        container.peakLabel:SetHidden(true)
        return
    end

    if math.max(0, math.floor(tonumber(dataset.sampleCount) or 0)) < 3 then
        container.peakMarker:SetHidden(true)
        container.peakLabel:SetHidden(true)
        return
    end

    local peakIndex = math.max(1, math.min(#buckets, math.floor(tonumber(dataset.peakIndex) or 1)))
    local peakValue = math.max(0, math.floor(tonumber(dataset.peakValue) or 0))
    local range = math.max(1, visualMax - visualMin)
    local normalizedPeak = (math.max(visualMin, math.min(visualMax, peakValue)) - visualMin) / range
    local paddingX = math.max(0, math.floor(tonumber(container.innerPaddingX) or 0))
    local usableWidth = math.max(1, width - (paddingX * 2))
    local xWidth = usableWidth / math.max(1, #buckets)
    local leftOffset = paddingX + math.floor(((peakIndex - 1) * xWidth) + 0.5)
    local rightOffset = paddingX + math.floor((peakIndex * xWidth) + 0.5)
    local centerOffset = leftOffset + math.max(1, math.floor((rightOffset - leftOffset) * 0.5))
    local bottomOffset = math.max(0, math.min(height - 1, math.floor((height - 2) * normalizedPeak + 0.5)))

    container.peakMarker:ClearAnchors()
    container.peakMarker:SetAnchor(BOTTOMLEFT, container, BOTTOMLEFT, centerOffset - 3, -bottomOffset - 3)
    container.peakMarker:SetDimensions(6, 6)
    container.peakMarker:SetHidden(false)

    container.peakLabel:ClearAnchors()
    container.peakLabel:SetAnchor(BOTTOMLEFT, container.peakMarker, TOPLEFT, -10, -2)
    container.peakLabel:SetText(DC.formatter:FormatFull(peakValue))
    container.peakLabel:SetHidden(false)
end

function DC.dpsGraph:DrawBars(container, columns, dataset)
    if container == nil or columns == nil or dataset == nil then
        return
    end

    local totalColumns = #columns
    local width = math.max(1, math.floor(container:GetWidth() or 1))
    local height = math.max(1, math.floor(container:GetHeight() or 1))
    local paddingX = math.max(0, math.floor(tonumber(container.innerPaddingX) or 0))
    local usableWidth = math.max(1, width - (paddingX * 2))
    local labelColorR, labelColorG, labelColorB = 1, 1, 1
    local valueColorR, valueColorG, valueColorB = 1, 1, 1

    if DC.hud and DC.hud.GetLabelColor then
        labelColorR, labelColorG, labelColorB = DC.hud:GetLabelColor()
    end

    if DC.hud and DC.hud.GetValueColor then
        valueColorR, valueColorG, valueColorB = DC.hud:GetValueColor()
    end

    local buckets = dataset.buckets or {}
    local activeCount = math.min(#buckets, totalColumns)
    local visibleCount = math.max(1, activeCount)
    local barWidth = usableWidth / visibleCount
    local combinedMin = math.min(dataset.primaryMin or 0, dataset.secondaryMin or 0)
    local combinedMax = math.max(dataset.primaryMax or 0, dataset.secondaryMax or 0)
    local visualMin, visualMax = self:GetVisualRange(combinedMin, combinedMax)
    local valueRange = math.max(1, visualMax - visualMin)
    local previousPrimaryValue = nil
    local peakValue = math.max(0, math.floor(tonumber(dataset.peakValue) or 0))
    local lowValue = math.max(0, math.floor(tonumber(dataset.lowValue) or 0))
    local peakIndex = math.max(1, math.floor(tonumber(dataset.peakIndex) or 1))
    local spreadValue = math.max(1, peakValue - lowValue)
    local slumpThreshold = lowValue + math.max(250, math.floor(spreadValue * 0.16))
    local nearPeakThreshold = math.max(peakValue - math.max(250, math.floor(spreadValue * 0.05)), math.floor(peakValue * 0.96))

    self:UpdateReferenceLine(container, combinedMin, combinedMax, dataset.lastValue or 0)

    for barIndex = 1, totalColumns do
        local column = columns[barIndex]

        if barIndex <= activeCount then
            local bucket = buckets[barIndex]
            local primaryLast = math.max(0, math.floor(tonumber(bucket and bucket.primaryLast) or 0))
            local primaryMax = math.max(primaryLast, math.floor(tonumber(bucket and bucket.primaryMax) or 0))
            local primaryMin = math.max(0, math.floor(tonumber(bucket and bucket.primaryMin) or 0))
            local secondaryLast = math.max(0, math.floor(tonumber(bucket and bucket.secondaryLast) or 0))
            local normalizedPrimary = (math.max(visualMin, math.min(visualMax, primaryLast)) - visualMin) / valueRange
            local normalizedSecondary = (math.max(visualMin, math.min(visualMax, secondaryLast)) - visualMin) / valueRange
            local burstFactor = (math.max(visualMin, math.min(visualMax, primaryMax)) - math.max(visualMin, math.min(visualMax, primaryMin))) / valueRange
            local fillHeight = math.max(2, math.floor((height - 2) * normalizedPrimary))
            local secondaryOffset = math.max(0, math.floor((height - 2) * normalizedSecondary))
            local ageT = activeCount > 1 and ((barIndex - 1) / (activeCount - 1)) or 1
            local directionDelta = previousPrimaryValue == nil and 0 or (primaryLast - previousPrimaryValue)
            local directionTint = 0

            if directionDelta > 0 then
                directionTint = math.min(1.0, math.abs(directionDelta) / math.max(1, primaryLast))
            elseif directionDelta < 0 then
                directionTint = -math.min(1.0, math.abs(directionDelta) / math.max(1, math.max(previousPrimaryValue or 1, primaryLast)))
            end

            local alpha = 0.24 + (ageT * 0.44) + math.min(0.12, burstFactor * 0.16)
            local leftOffset = paddingX + math.floor((((barIndex - 1) * barWidth)) + 0.5)
            local rightOffset = paddingX + math.floor(((barIndex * barWidth)) + 0.5)

            if barIndex == 1 then
                leftOffset = paddingX
            end

            if barIndex == activeCount then
                rightOffset = width - paddingX
            end

            local finalWidth = math.max(1, rightOffset - leftOffset)
            local fillRed = valueColorR
            local fillGreen = valueColorG
            local fillBlue = valueColorB
            local capRed = math.min(1.0, valueColorR + 0.10)
            local capGreen = math.min(1.0, valueColorG + 0.10)
            local capBlue = math.min(1.0, valueColorB + 0.10)
            local warmColor = { 0.95, 0.36, 0.28 }
            local highColor = { 0.36, 0.90, 0.46 }
            local peakColor = { 0.30, 0.98, 0.52 }
            local baseColor = { valueColorR, valueColorG, valueColorB }
            local isPeakBar = peakValue > 0 and (barIndex == peakIndex or primaryLast >= nearPeakThreshold)
            local isLowBar = spreadValue > 0 and primaryLast <= slumpThreshold
            local blendedBase = self:BlendRgb(warmColor, highColor, normalizedPrimary)

            fillRed = blendedBase[1]
            fillGreen = blendedBase[2]
            fillBlue = blendedBase[3]

            capRed = self:ClampColor(fillRed + 0.10)
            capGreen = self:ClampColor(fillGreen + 0.10)
            capBlue = self:ClampColor(fillBlue + 0.10)

            if directionTint > 0 then
                fillRed = self:ClampColor(fillRed * (1 - (directionTint * 0.18)) + (0.22 * directionTint))
                fillGreen = self:ClampColor(fillGreen * (1 - (directionTint * 0.18)) + (1.00 * directionTint * 0.18))
                fillBlue = self:ClampColor(fillBlue * (1 - (directionTint * 0.18)) + (0.42 * directionTint * 0.18))
            elseif directionTint < 0 then
                local dropTint = math.abs(directionTint)
                fillRed = self:ClampColor(fillRed * (1 - (dropTint * 0.18)) + (1.00 * dropTint * 0.18))
                fillGreen = self:ClampColor(fillGreen * (1 - (dropTint * 0.18)) + (0.28 * dropTint * 0.18))
                fillBlue = self:ClampColor(fillBlue * (1 - (dropTint * 0.18)) + (0.26 * dropTint * 0.18))
            end

            if isPeakBar then
                local peakBlend = self:BlendRgb(baseColor, peakColor, 0.88)
                fillRed = peakBlend[1]
                fillGreen = peakBlend[2]
                fillBlue = peakBlend[3]
                capRed = 1.0
                capGreen = 0.95
                capBlue = 0.62
                alpha = math.min(0.96, alpha + 0.20)
            elseif isLowBar then
                local lowBlend = self:BlendRgb(baseColor, warmColor, 0.90)
                fillRed = lowBlend[1]
                fillGreen = lowBlend[2]
                fillBlue = lowBlend[3]
                capRed = 1.0
                capGreen = 0.58
                capBlue = 0.48
                alpha = math.min(0.90, alpha + 0.10)
            else
                local baseMixStrength = 0.16 + (normalizedPrimary * 0.18)
                local baseMix = self:BlendRgb(baseColor, { fillRed, fillGreen, fillBlue }, baseMixStrength)
                fillRed = baseMix[1]
                fillGreen = baseMix[2]
                fillBlue = baseMix[3]
            end

            column.fill:ClearAnchors()
            column.fill:SetAnchor(BOTTOMLEFT, container, BOTTOMLEFT, leftOffset, 0)
            column.fill:SetDimensions(finalWidth, fillHeight)
            column.fill:SetCenterColor(fillRed, fillGreen, fillBlue, alpha)
            column.fill:SetHidden(false)

            column.primaryCap:ClearAnchors()
            column.primaryCap:SetAnchor(BOTTOMLEFT, container, BOTTOMLEFT, leftOffset, -math.max(0, fillHeight - 2))
            column.primaryCap:SetDimensions(finalWidth, isPeakBar and 3 or 2)
            column.primaryCap:SetCenterColor(capRed, capGreen, capBlue, 0.96)
            column.primaryCap:SetHidden(false)

            if column.secondaryMarker ~= nil then
                column.secondaryMarker:ClearAnchors()
                column.secondaryMarker:SetAnchor(BOTTOMLEFT, container, BOTTOMLEFT, leftOffset, -secondaryOffset)
                column.secondaryMarker:SetDimensions(finalWidth, 2)
                column.secondaryMarker:SetCenterColor(labelColorR, labelColorG, labelColorB, 0.85)
                column.secondaryMarker:SetHidden(false)
            end

            previousPrimaryValue = primaryLast
        else
            column.fill:SetHidden(true)
            column.primaryCap:SetHidden(true)
            if column.secondaryMarker ~= nil then
                column.secondaryMarker:SetHidden(true)
            end
        end
    end

    self:UpdatePeakMarker(container, dataset, width, height, visualMin, visualMax)
end

function DC.dpsGraph:RefreshMiniSparkline(now)
    if not self:IsMiniGraphEnabled() or not DC.hud or not DC.hud.metricRows then
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

    local targetCount = self:GetMiniPointCount()
    self:EnsureMiniColumns(row, targetCount)
    local dataset = self:BuildCompressedBuckets(self:GetSelectedDisplayMode(), targetCount)
    self:DrawBars(row.sparkline, row.sparkline.columns, dataset)
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
    self.control.graphCanvas.peakLabel:SetFont(DC.hud:BuildFont(settings.labelFontFace, math.max(11, (settings.tooltipFontSize or 15) - 2)))
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
    self.control.graphCanvas.peakLabel:SetColor(labelColorR, labelColorG, labelColorB, labelColorA)
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
    self.control.graphCanvas:SetAnchor(TOPLEFT, self.control.summarySecondaryLabel, BOTTOMLEFT, 12, self.graphTopSpacing)
    self.control.graphCanvas:SetAnchor(TOPRIGHT, self.control.summarySecondaryLabel, BOTTOMRIGHT, -12, self.graphTopSpacing)
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
    local dataset = self:BuildCompressedBuckets(mode, self:GetLargePointCount())
    local playerText = DC.formatter:FormatFull(dataset.lastValue or 0)
    local secondaryText = DC.formatter:FormatFull(dataset.lastSecondaryValue or 0)
    local combatTimeText = DC.hud and DC.hud.FormatCombatTime and DC.hud:FormatCombatTime(snapshot.combatDurationMs or 0) or "00:00.000"
    local primaryParts = {
        string.format("%s: %s", tostring(dataset.meta and dataset.meta.primaryLabel or DC:GetString("hudDpsLabel")), playerText),
    }
    local secondaryParts = {}
    local deltaBaseValue = math.max(0, math.floor(tonumber(dataset.previousValue) or 0))
    local deltaPercent = 0
    local deltaPrefix = "+"

    if deltaBaseValue > 0 then
        deltaPercent = (((dataset.lastValue or 0) - deltaBaseValue) / deltaBaseValue) * 100
    elseif (dataset.lastValue or 0) <= 0 then
        deltaPrefix = ""
    end

    if deltaPercent < 0 then
        deltaPrefix = ""
    end

    self.control.titleLabel:SetText(DC:GetString("dpsGraphTitle"))
    self.control.modeLabel:SetText(string.format("%s | %s | %s: %s",
        self:GetDisplayModeLabel(mode),
        self:GetGraphModeLabel(self:GetSelectedGraphMode()),
        DC:GetString("dpsGraphOverlayLabel"),
        tostring(dataset.meta and dataset.meta.secondaryLabel or DC:GetString("hudDpsAverageShort"))
    ))
    table.insert(primaryParts, string.format("%s: %s",
        tostring(dataset.meta and dataset.meta.secondaryLabel or DC:GetString("hudDpsAverageShort")),
        secondaryText
    ))

    if snapshot.groupDps ~= nil then
        table.insert(secondaryParts, string.format("%s: %s", DC:GetString("hudDpsGroupLabel"), DC.formatter:FormatFull(snapshot.groupDps)))
    end

    if snapshot.sharePercent ~= nil then
        table.insert(secondaryParts, string.format("%s: %d%%", DC:GetString("dpsGraphShareLabel"), snapshot.sharePercent))
    end

    table.insert(secondaryParts, string.format("%s: %s", DC:GetString("dpsGraphPeakLabel"), DC.formatter:FormatFull(dataset.peakValue or 0)))
    table.insert(secondaryParts, string.format("%s: %s", DC:GetString("dpsGraphLowLabel"), DC.formatter:FormatFull(dataset.lowValue or 0)))
    table.insert(secondaryParts, string.format("%s: %s%.1f%%", DC:GetString("dpsGraphDeltaLabel"), deltaPrefix, deltaPercent))

    self.control.summaryPrimaryLabel:SetText(table.concat(primaryParts, " | "))
    self.control.summarySecondaryLabel:SetText(table.concat(secondaryParts, " | "))
    self.control.summarySecondaryLabel:SetHidden(#secondaryParts == 0)

    if (dataset.pointCount or 0) <= 0 then
        self.control.footerLabel:SetText(DC:GetString("dpsGraphNoData"))
        return
    end

    self.control.footerLabel:SetText(string.format("%s: %s | %s | %s: %s-%s",
        DC:GetString("hudCombatTimeLabel"),
        combatTimeText,
        DC:GetString("dpsGraphSamplesLabel", dataset.pointCount or 0),
        DC:GetString("dpsGraphRangeLabel"),
        DC.formatter:FormatFull(dataset.lowValue or 0),
        DC.formatter:FormatFull(dataset.peakValue or 0)
    ))
end

function DC.dpsGraph:UpdateWindowGraph()
    if self.control == nil then
        return
    end

    local mode = self:GetSelectedDisplayMode()
    local targetCount = self:GetLargePointCount()
    self:EnsureLargeColumns(targetCount)
    local dataset = self:BuildCompressedBuckets(mode, targetCount)
    self:DrawBars(self.control.graphCanvas, self.control.graphColumns, dataset)
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
    return self:IsLargeGraphEnabled() and self:IsHoverActive()
end

function DC.dpsGraph:ShouldBeVisible()
    if self.control == nil or not DC.hud or DC.hud.control == nil then
        return false
    end

    if not self:IsLargeGraphEnabled() then
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
    local now = GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0

    if self:IsMiniGraphEnabled() then
        self:RefreshMiniSparkline(now)
    elseif DC.hud and DC.hud.metricRows and DC.hud.metricRows.dps and DC.hud.metricRows.dps.sparkline then
        DC.hud.metricRows.dps.sparkline:SetHidden(true)
    end

    if self:IsVisible() then
        self:RefreshWindow(now)
    else
        self:RefreshVisibility(now)
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
