local DC = DamageCalculation

DC.localization = {
    strings = {
        en = DamageCalculation_Language_EN or {},
        ru = DamageCalculation_Language_RU or {},
    },
}

function DC.localization:GetString(key, ...)
    local languageCode = DC:GetLanguageCode()
    local languageTable = self.strings[languageCode] or self.strings.en or {}
    local fallbackTable = self.strings.en or {}
    local value = languageTable[key] or fallbackTable[key] or key
    local argumentCount = select("#", ...)

    if argumentCount == 0 then
        return value
    end

    local ok, formatted = pcall(string.format, value, ...)
    if ok then
        return formatted
    end

    return value
end
