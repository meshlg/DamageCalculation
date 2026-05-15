local DC = DamageCalculation

DC.integrity = {}
DC.integrity.parameterCache = {}

local HASH_MOD_A = 2147483629
local HASH_MOD_B = 2147483587

function DC.integrity:Checksum(text)
    local source = tostring(text or "")
    local hashA = 17
    local hashB = 29

    for index = 1, #source do
        local byte = string.byte(source, index)
        hashA = (hashA * 131 + byte + index) % HASH_MOD_A
        hashB = (hashB * 137 + (byte * (index + 7))) % HASH_MOD_B
    end

    return string.format("%08x%08x", hashA, hashB)
end

function DC.integrity:GenerateSalt()
    local parts = {
        tostring(GetDisplayName and GetDisplayName() or ""),
        tostring(GetUnitName and GetUnitName("player") or ""),
        tostring(GetWorldName and GetWorldName() or ""),
        tostring(GetTimeStamp and GetTimeStamp() or 0),
        tostring(GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0),
    }

    local rawSalt = table.concat(parts, "|")
    return self:Checksum(rawSalt):sub(1, 16)
end

function DC.integrity:DeriveParameters(salt, channel)
    local cacheKey = string.format("%s|%s", tostring(salt or ""), tostring(channel or ""))
    local cached = self.parameterCache[cacheKey]

    if cached ~= nil then
        return cached.offset, cached.factor
    end

    local seed = self:Checksum(cacheKey)
    local numericSeed = tonumber(seed:sub(1, 8), 16) or 0
    local offset = (numericSeed % 5000003) + 9973
    local factor = (numericSeed % 83) + 17

    self.parameterCache[cacheKey] = {
        offset = offset,
        factor = factor,
    }

    return offset, factor
end

function DC.integrity:EncodeNumber(value, salt, channel)
    local number = math.max(0, math.floor(tonumber(value) or 0))
    local offset, factor = self:DeriveParameters(salt, channel)
    local encodedValue = (number + offset) * factor

    return tostring(encodedValue)
end

function DC.integrity:DecodeNumber(encodedValue, salt, channel)
    local numericValue = tonumber(encodedValue)

    if numericValue == nil then
        return nil
    end

    local offset, factor = self:DeriveParameters(salt, channel)

    if numericValue % factor ~= 0 then
        return nil
    end

    local decodedValue = (numericValue / factor) - offset

    if decodedValue < 0 or decodedValue ~= math.floor(decodedValue) then
        return nil
    end

    return decodedValue
end
