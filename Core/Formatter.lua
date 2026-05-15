local DC = DamageCalculation

DC.formatter = {}

local shortUnits = {
    en = {
        { value = 1000000000000, suffix = "T" },
        { value = 1000000000, suffix = "B" },
        { value = 1000000, suffix = "M" },
        { value = 1000, suffix = "K" },
    },
    ru = {
        { value = 1000000000000, suffix = "трлн" },
        { value = 1000000000, suffix = "млрд" },
        { value = 1000000, suffix = "млн" },
        { value = 1000, suffix = "тыс." },
    },
}

local function trimTrailingZeroes(text)
    return text:gsub("(%..-)0+(e%d+)$", "%1%2"):gsub("%.e", "e"):gsub("(%..-)0+$", "%1"):gsub("%.$", "")
end

local function trimTrailingZeroesWithComma(text)
    return text:gsub("(,.-)0+$", "%1"):gsub(",$", "")
end

function DC.formatter:FormatFull(value)
    local number = math.max(0, math.floor(tonumber(value) or 0))
    local text = tostring(number)

    while true do
        local replaced, count = text:gsub("^(-?%d+)(%d%d%d)", "%1 %2")
        text = replaced

        if count == 0 then
            break
        end
    end

    return text
end

function DC.formatter:FormatScientific(value)
    local number = math.max(0, tonumber(value) or 0)

    if number == 0 then
        return "0"
    end

    local exponent = math.floor(math.log(number) / math.log(10))
    local mantissa = number / (10 ^ exponent)
    local formatted = string.format("%.1fe%d", mantissa, exponent)

    return trimTrailingZeroes(formatted)
end

function DC.formatter:FormatShort(value)
    local number = math.max(0, tonumber(value) or 0)
    local languageCode = DC:GetLanguageCode()
    local unitSet = shortUnits[languageCode] or shortUnits.en
    local decimalSeparator = languageCode == DC.languageModes.RU and "," or "."

    for _, unit in ipairs(unitSet) do
        if number >= unit.value then
            local shortValue = number / unit.value
            local formatted = string.format("%.1f", shortValue)

            if decimalSeparator == "," then
                formatted = formatted:gsub("%.", ",")
                formatted = trimTrailingZeroesWithComma(formatted)
            else
                formatted = trimTrailingZeroes(formatted)
            end

            return string.format("%s %s", formatted, unit.suffix)
        end
    end

    return self:FormatFull(number)
end

function DC.formatter:Format(value)
    local settings = DC.storage:GetSettings()
    local mode = settings.formatMode or DC.formatModes.FULL

    if mode == DC.formatModes.SCIENTIFIC then
        return self:FormatScientific(value)
    end

    if mode == DC.formatModes.SHORT then
        return self:FormatShort(value)
    end

    return self:FormatFull(value)
end
