local DC = DamageCalculation

DC.tooltip = {
    name = "DamageCalculationTooltip",
    modeMetricKeys = {
        "damage",
        "received",
        "blocked",
        "healed",
    },
}

function DC.tooltip:GetSettings()
    return DC.storage:GetSettings()
end

function DC.tooltip:GetFontSize()
    return math.max(12, math.floor(tonumber(self:GetSettings().tooltipFontSize) or 15))
end

function DC.tooltip:GetWidth()
    if DC.hud and DC.hud.GetHudWidth then
        return math.max(220, DC.hud:GetHudWidth())
    end

    return 260
end

function DC.tooltip:GetPlacement()
    local settings = self:GetSettings()
    local desiredWidth = self:GetWidth()
    local scale = tonumber(settings.scale) or 1.0
    local screenWidth = GuiRoot and GuiRoot.GetWidth and GuiRoot:GetWidth() or 0
    local hudLeft = 0
    local hudRight = 0
    local gap = math.max(8, math.floor(10 * scale))

    if DC.hud and DC.hud.control then
        hudLeft = DC.hud.control:GetLeft() or 0
        hudRight = DC.hud.control:GetRight() or hudLeft
    end

    local leftSpace = math.max(0, hudLeft)
    local rightSpace = math.max(0, screenWidth - hudRight)
    local scaledDesiredWidth = desiredWidth * scale
    local minWidth = 180
    local side = "right"
    local finalWidth = desiredWidth

    if rightSpace >= (scaledDesiredWidth + gap) then
        side = "right"
    elseif leftSpace >= (scaledDesiredWidth + gap) then
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

function DC.tooltip:GetLineHeight()
    return self:GetFontSize() + 8
end

function DC.tooltip:ComputeHeight()
    local lineHeight = self:GetLineHeight()
    return (lineHeight * 11) + 44
end

function DC.tooltip:GetLabelColor()
    if DC.hud and DC.hud.GetLabelColor then
        return DC.hud:GetLabelColor()
    end

    local settings = self:GetSettings()
    return tonumber(settings.labelColorR) or 1.0,
        tonumber(settings.labelColorG) or 1.0,
        tonumber(settings.labelColorB) or 1.0,
        tonumber(settings.labelColorA) or 1.0
end

function DC.tooltip:GetValueColor()
    if DC.hud and DC.hud.GetValueColor then
        return DC.hud:GetValueColor()
    end

    local settings = self:GetSettings()
    return tonumber(settings.valueColorR) or 1.0,
        tonumber(settings.valueColorG) or 1.0,
        tonumber(settings.valueColorB) or 1.0,
        tonumber(settings.valueColorA) or 1.0
end

function DC.tooltip:BuildLabelFont(size)
    if DC.hud and DC.hud.BuildFont then
        return DC.hud:BuildFont(self:GetSettings().labelFontFace, size)
    end

    return string.format("%s|%d|%s", "$(BOLD_FONT)", math.floor(tonumber(size) or 15), DC.fontStyles.SOFT_SHADOW_THICK)
end

function DC.tooltip:BuildValueFont(size)
    if DC.hud and DC.hud.BuildFont then
        return DC.hud:BuildFont(self:GetSettings().valueFontFace, size)
    end

    return string.format("%s|%d|%s", "$(BOLD_FONT)", math.floor(tonumber(size) or 15), DC.fontStyles.SOFT_SHADOW_THICK)
end

function DC.tooltip:CreateValueRow(parent)
    local row = WINDOW_MANAGER:CreateControl(nil, parent, CT_CONTROL)

    row.caption = WINDOW_MANAGER:CreateControl(nil, row, CT_LABEL)
    row.caption:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    row.caption:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    row.value = WINDOW_MANAGER:CreateControl(nil, row, CT_LABEL)
    row.value:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    row.value:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    return row
end

function DC.tooltip:CreateModeRows(parent)
    local rows = {}

    for _, metricKey in ipairs(self.modeMetricKeys) do
        rows[metricKey] = self:CreateValueRow(parent)
    end

    return rows
end

function DC.tooltip:ApplyRowLayout(row, anchorTarget, offsetY, captionWidth, lineHeight)
    row:ClearAnchors()
    row:SetAnchor(TOPLEFT, anchorTarget, BOTTOMLEFT, 0, offsetY)
    row:SetAnchor(TOPRIGHT, anchorTarget, BOTTOMRIGHT, 0, offsetY)
    row:SetHeight(lineHeight)

    row.caption:ClearAnchors()
    row.caption:SetAnchor(TOPLEFT, row, TOPLEFT, 0, 0)
    row.caption:SetDimensions(captionWidth, lineHeight)

    row.value:ClearAnchors()
    row.value:SetAnchor(TOPLEFT, row, TOPLEFT, captionWidth, 0)
    row.value:SetAnchor(TOPRIGHT, row, TOPRIGHT, 0, 0)
    row.value:SetHeight(lineHeight)
end

function DC.tooltip:GetModeSectionHeaderText()
    if DC.storage:GetTooltipMode() == DC.displayModes.SESSION then
        return DC:GetString("tooltipSectionCurrentFight")
    end

    return DC:GetString("tooltipSectionOverall")
end

function DC.tooltip:GetMetricCaption(metricKey)
    local definition = DC.metricDefinitions[metricKey] or DC.metricDefinitions.damage
    return DC:GetString(definition.labelKey or "hudDamageLabel")
end

function DC.tooltip:CreateControl()
    local control = WINDOW_MANAGER:CreateTopLevelWindow(self.name)
    control:SetHidden(true)
    control:SetClampedToScreen(true)
    control:SetMouseEnabled(false)
    control:SetDrawLayer(DL_OVERLAY)
    control:SetDrawTier(DT_HIGH)

    control.backdrop = WINDOW_MANAGER:CreateControl(nil, control, CT_BACKDROP)
    control.backdrop:SetAnchorFill(control)
    control.backdrop:SetCenterColor(0.02, 0.02, 0.02, 0.88)
    control.backdrop:SetEdgeColor(0.12, 0.12, 0.12, 0.95)
    control.backdrop:SetEdgeTexture("", 2, 1, 1)
    control.backdrop:SetInsets(0, 0, -1, -1)

    control.titleLabel = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
    control.titleLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    control.titleLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    control.modeHeaderLabel = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
    control.modeHeaderLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    control.modeHeaderLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    control.modeRows = self:CreateModeRows(control)

    control.pveHeaderLabel = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
    control.pveHeaderLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    control.pveHeaderLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    control.pveKillsRow = self:CreateValueRow(control)
    control.pveBossKillsRow = self:CreateValueRow(control)

    control.pvpHeaderLabel = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
    control.pvpHeaderLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    control.pvpHeaderLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    control.pvpKillsRow = self:CreateValueRow(control)

    self.control = control
end

function DC.tooltip:ApplyFonts()
    if self.control == nil then
        return
    end

    local fontSize = self:GetFontSize()

    self.control.titleLabel:SetFont(self:BuildLabelFont(fontSize + 1))
    self.control.modeHeaderLabel:SetFont(self:BuildLabelFont(fontSize))

    for _, metricKey in ipairs(self.modeMetricKeys) do
        local row = self.control.modeRows[metricKey]
        row.caption:SetFont(self:BuildLabelFont(fontSize))
        row.value:SetFont(self:BuildValueFont(fontSize))
    end

    self.control.pveHeaderLabel:SetFont(self:BuildLabelFont(fontSize))
    self.control.pveKillsRow.caption:SetFont(self:BuildLabelFont(fontSize))
    self.control.pveKillsRow.value:SetFont(self:BuildValueFont(fontSize))
    self.control.pveBossKillsRow.caption:SetFont(self:BuildLabelFont(fontSize))
    self.control.pveBossKillsRow.value:SetFont(self:BuildValueFont(fontSize))
    self.control.pvpHeaderLabel:SetFont(self:BuildLabelFont(fontSize))
    self.control.pvpKillsRow.caption:SetFont(self:BuildLabelFont(fontSize))
    self.control.pvpKillsRow.value:SetFont(self:BuildValueFont(fontSize))
end

function DC.tooltip:ApplyColors()
    if self.control == nil then
        return
    end

    local labelColorR, labelColorG, labelColorB, labelColorA = self:GetLabelColor()
    local valueColorR, valueColorG, valueColorB, valueColorA = self:GetValueColor()

    self.control.titleLabel:SetColor(labelColorR, labelColorG, labelColorB, labelColorA)
    self.control.modeHeaderLabel:SetColor(labelColorR, labelColorG, labelColorB, labelColorA)

    for _, metricKey in ipairs(self.modeMetricKeys) do
        local row = self.control.modeRows[metricKey]
        row.caption:SetColor(labelColorR, labelColorG, labelColorB, labelColorA)
        row.value:SetColor(valueColorR, valueColorG, valueColorB, valueColorA)
    end

    self.control.pveHeaderLabel:SetColor(labelColorR, labelColorG, labelColorB, labelColorA)
    self.control.pveKillsRow.caption:SetColor(labelColorR, labelColorG, labelColorB, labelColorA)
    self.control.pveKillsRow.value:SetColor(valueColorR, valueColorG, valueColorB, valueColorA)
    self.control.pveBossKillsRow.caption:SetColor(labelColorR, labelColorG, labelColorB, labelColorA)
    self.control.pveBossKillsRow.value:SetColor(valueColorR, valueColorG, valueColorB, valueColorA)
    self.control.pvpHeaderLabel:SetColor(labelColorR, labelColorG, labelColorB, labelColorA)
    self.control.pvpKillsRow.caption:SetColor(labelColorR, labelColorG, labelColorB, labelColorA)
    self.control.pvpKillsRow.value:SetColor(valueColorR, valueColorG, valueColorB, valueColorA)
end

function DC.tooltip:ApplyLayout()
    if self.control == nil or DC.hud == nil or DC.hud.control == nil then
        return
    end

    local side, width, gap = self:GetPlacement()
    local lineHeight = self:GetLineHeight()
    local contentWidth = width - 24
    local captionWidth = math.floor(contentWidth * 0.58)
    local previousAnchor = nil

    self.control:SetDimensions(width, self:ComputeHeight())
    self.control:SetScale(self:GetSettings().scale or 1.0)
    self.control:ClearAnchors()
    if side == "left" then
        self.control:SetAnchor(TOPRIGHT, DC.hud.control, TOPLEFT, -gap, 0)
    else
        self.control:SetAnchor(TOPLEFT, DC.hud.control, TOPRIGHT, gap, 0)
    end

    self.control.titleLabel:ClearAnchors()
    self.control.titleLabel:SetAnchor(TOPLEFT, self.control, TOPLEFT, 12, 10)
    self.control.titleLabel:SetAnchor(TOPRIGHT, self.control, TOPRIGHT, -12, 10)
    self.control.titleLabel:SetHeight(lineHeight)

    self.control.modeHeaderLabel:ClearAnchors()
    self.control.modeHeaderLabel:SetAnchor(TOPLEFT, self.control.titleLabel, BOTTOMLEFT, 0, 6)
    self.control.modeHeaderLabel:SetAnchor(TOPRIGHT, self.control.titleLabel, BOTTOMRIGHT, 0, 6)
    self.control.modeHeaderLabel:SetHeight(lineHeight)
    previousAnchor = self.control.modeHeaderLabel

    for _, metricKey in ipairs(self.modeMetricKeys) do
        local row = self.control.modeRows[metricKey]
        self:ApplyRowLayout(row, previousAnchor, 2, captionWidth, lineHeight)
        previousAnchor = row
    end

    self.control.pveHeaderLabel:ClearAnchors()
    self.control.pveHeaderLabel:SetAnchor(TOPLEFT, previousAnchor, BOTTOMLEFT, 0, 8)
    self.control.pveHeaderLabel:SetAnchor(TOPRIGHT, previousAnchor, BOTTOMRIGHT, 0, 8)
    self.control.pveHeaderLabel:SetHeight(lineHeight)

    self:ApplyRowLayout(self.control.pveKillsRow, self.control.pveHeaderLabel, 2, captionWidth, lineHeight)
    self:ApplyRowLayout(self.control.pveBossKillsRow, self.control.pveKillsRow, 2, captionWidth, lineHeight)

    self.control.pvpHeaderLabel:ClearAnchors()
    self.control.pvpHeaderLabel:SetAnchor(TOPLEFT, self.control.pveBossKillsRow, BOTTOMLEFT, 0, 6)
    self.control.pvpHeaderLabel:SetAnchor(TOPRIGHT, self.control.pveBossKillsRow, BOTTOMRIGHT, 0, 6)
    self.control.pvpHeaderLabel:SetHeight(lineHeight)

    self:ApplyRowLayout(self.control.pvpKillsRow, self.control.pvpHeaderLabel, 2, captionWidth, lineHeight)
end

function DC.tooltip:UpdateText()
    if self.control == nil then
        return
    end

    local tooltipMode = DC.storage:GetTooltipMode()

    self.control.titleLabel:SetText(DC:GetString("tooltipHeaderTitle"))
    self.control.modeHeaderLabel:SetText(self:GetModeSectionHeaderText())

    for _, metricKey in ipairs(self.modeMetricKeys) do
        local row = self.control.modeRows[metricKey]
        row.caption:SetText(self:GetMetricCaption(metricKey))
        row.value:SetText(DC.formatter:Format(DC.storage:GetMetricTotalForMode(metricKey, tooltipMode)))
    end

    self.control.pveHeaderLabel:SetText(DC:GetString("tooltipSectionPve"))
    self.control.pveKillsRow.caption:SetText(DC:GetString("tooltipPveKillsLabel"))
    self.control.pveKillsRow.value:SetText(DC.formatter:FormatFull(DC.storage:GetTotalPveKills()))
    self.control.pveBossKillsRow.caption:SetText(DC:GetString("tooltipPveBossKillsLabel"))
    self.control.pveBossKillsRow.value:SetText(DC.formatter:FormatFull(DC.storage:GetTotalPveBossKills()))
    self.control.pvpHeaderLabel:SetText(DC:GetString("tooltipSectionPvp"))
    self.control.pvpKillsRow.caption:SetText(DC:GetString("tooltipPvpKillsLabel"))
    self.control.pvpKillsRow.value:SetText(DC.formatter:FormatFull(DC.storage:GetTotalPvpKills()))
end

function DC.tooltip:IsVisible()
    return self.control ~= nil and not self.control:IsHidden()
end

function DC.tooltip:Show()
    if self.control == nil or DC.hud == nil or DC.hud.control == nil then
        return
    end

    if not self:GetSettings().showHud or DC.hud.control:IsHidden() then
        return
    end

    self:Refresh()
    self.control:SetHidden(false)
end

function DC.tooltip:Hide()
    if self.control == nil then
        return
    end

    self.control:SetHidden(true)
end

function DC.tooltip:UpdateHover()
    if self.control == nil or DC.hud == nil or DC.hud.control == nil then
        return
    end

    local suppressForDpsGraph = DC.dpsGraph and DC.dpsGraph.ShouldSuppressStatsTooltip and DC.dpsGraph:ShouldSuppressStatsTooltip() or false

    if not self:GetSettings().showHud or DC.hud.control:IsHidden() then
        if self:IsVisible() then
            self:Hide()
        end

        return
    end

    if suppressForDpsGraph then
        if self:IsVisible() then
            self:Hide()
        end

        return
    end

    if MouseIsOver and MouseIsOver(DC.hud.control, 0, 0, 0, 0) then
        if not self:IsVisible() then
            self:Show()
        end
    elseif self:IsVisible() then
        self:Hide()
    end
end

function DC.tooltip:Refresh()
    if self.control == nil then
        return
    end

    if not self:GetSettings().showHud then
        self:Hide()
        return
    end

    self:ApplyLayout()
    self:ApplyFonts()
    self:ApplyColors()
    self:UpdateText()
end

function DC.tooltip:AttachHandlers()
    if DC.hud == nil or DC.hud.control == nil then
        return
    end

    DC.hud.control:SetHandler("OnMouseEnter", function()
        self:UpdateHover()
    end)

    DC.hud.control:SetHandler("OnMouseExit", function()
        self:Hide()
    end)
end

function DC.tooltip:OnMetricAdded()
    if self:IsVisible() then
        self:Refresh()
    end
end

function DC.tooltip:OnKillAdded()
    if self:IsVisible() then
        self:Refresh()
    end
end

function DC.tooltip:Initialize()
    self:CreateControl()
    self:AttachHandlers()
end
