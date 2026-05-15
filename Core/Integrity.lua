local DC = DamageCalculation

DC.integrity = {}
-- Public placeholder only. The real parameter cache is kept in a local upvalue.
DC.integrity.parameterCache = {}

local UINT32 = 4294967296
local BYTE_MOD = 256
local WORD_MOD = 65536
local FNV_OFFSET = 2166136261
local FNV_PRIME = 16777619
local ALT_OFFSET = 3359699934
local function WordConst(highWord, lowWord)
    return (highWord * WORD_MOD) + lowWord
end

local SEED_CONST_A = WordConst(4951, 39903)
local SEED_CONST_B = WordConst(9320, 44256)
local SEED_CONST_C = WordConst(12609, 22823)
local SEED_CONST_D = WordConst(4128, 12352)

local floor = math.floor
local max = math.max
local tonumber = tonumber
local tostring = tostring
local stringByte = string.byte
local stringChar = string.char
local stringFormat = string.format
local stringReverse = string.reverse
local nativeBitXor = type(BitXor) == "function" and BitXor or nil
local nativeBitLShift = type(BitLShift) == "function" and BitLShift or nil
local nativeBitRShift = type(BitRShift) == "function" and BitRShift or nil

local runtimeSeedA = 0
local runtimeSeedB = 0
local runtimeSeedReady = false
local parameterCache = {}

local function NormalizeUint32(value)
    local number = floor(tonumber(value) or 0)

    if number >= 0 and number < UINT32 then
        return number
    end

    return number % UINT32
end

local function Add32Fast(valueA, valueB)
    local result = valueA + valueB

    if result >= UINT32 then
        return result - UINT32
    end

    return result
end

local function XorByteSlow(a, b)
    local valueA = a % BYTE_MOD
    local valueB = b % BYTE_MOD
    local result = 0
    local bitValue = 1

    for _ = 1, 8 do
        local bitA = valueA % 2
        local bitB = valueB % 2

        if bitA ~= bitB then
            result = result + bitValue
        end

        valueA = floor(valueA / 2)
        valueB = floor(valueB / 2)
        bitValue = bitValue * 2
    end

    return result
end

local function Xor32Fast(valueA, valueB)

    if nativeBitXor then
        return NormalizeUint32(nativeBitXor(valueA, valueB))
    end

    local result = 0
    local multiplier = 1

    for _ = 1, 4 do
        local byteA = valueA % BYTE_MOD
        local byteB = valueB % BYTE_MOD
        result = result + (XorByteSlow(byteA, byteB) * multiplier)
        valueA = floor(valueA / BYTE_MOD)
        valueB = floor(valueB / BYTE_MOD)
        multiplier = multiplier * BYTE_MOD
    end

    return result
end

local function Mul32Fast(valueA, valueB)
    local lowA = valueA % WORD_MOD
    local highA = floor(valueA / WORD_MOD)
    local lowB = valueB % WORD_MOD
    local highB = floor(valueB / WORD_MOD)
    local lowPart = lowA * lowB
    local crossPart = (highA * lowB) + (lowA * highB)

    return NormalizeUint32(lowPart + ((crossPart % WORD_MOD) * WORD_MOD))
end

local function Mul32(a, b)
    return Mul32Fast(NormalizeUint32(a), NormalizeUint32(b))
end

local function Add32(a, b)
    return Add32Fast(NormalizeUint32(a), NormalizeUint32(b))
end

local function Rol32(value, shift)
    local normalizedValue = NormalizeUint32(value)
    local normalizedShift = floor(tonumber(shift) or 0) % 32

    if normalizedShift == 0 then
        return normalizedValue
    end

    if nativeBitLShift and nativeBitRShift then
        local leftPart = NormalizeUint32(nativeBitLShift(normalizedValue, normalizedShift))
        local rightPart = NormalizeUint32(nativeBitRShift(normalizedValue, 32 - normalizedShift))
        return Add32Fast(leftPart, rightPart)
    end

    local leftPart = normalizedValue

    for _ = 1, normalizedShift do
        leftPart = (leftPart * 2) % UINT32
    end

    local rightPart = floor(normalizedValue / (2 ^ (32 - normalizedShift)))
    return NormalizeUint32(leftPart + rightPart)
end

local function Ror32(value, shift)
    local normalizedShift = floor(tonumber(shift) or 0) % 32

    if normalizedShift == 0 then
        return NormalizeUint32(value)
    end

    return Rol32(value, 32 - normalizedShift)
end

local function Fnv1a32(text, seed)
    local source = tostring(text or "")
    local hash = NormalizeUint32(seed or FNV_OFFSET)

    for index = 1, #source do
        hash = Xor32Fast(hash, stringByte(source, index))
        hash = Mul32Fast(hash, FNV_PRIME)
    end

    return hash
end

function DC.integrity:Checksum(text)
    local source = tostring(text or "")
    local forwardHash = Fnv1a32(source, FNV_OFFSET)
    local reverseHash = Fnv1a32(stringReverse(source), ALT_OFFSET)

    return stringFormat("%08x%08x", forwardHash, reverseHash)
end

function DC.integrity:GenerateSeedParts()
    local parts = {
        tostring(GetDisplayName and GetDisplayName() or ""),
        tostring(GetUnitName and GetUnitName("player") or ""),
        tostring(GetWorldName and GetWorldName() or ""),
        tostring(GetTimeStamp and GetTimeStamp() or 0),
        tostring(GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0),
    }
    local source = table.concat(parts, "|")
    local seedA = Fnv1a32(source, Add32(FNV_OFFSET, SEED_CONST_A))
    local seedB = Fnv1a32(stringReverse(source), Add32(ALT_OFFSET, SEED_CONST_B))

    return tostring(seedA), tostring(seedB)
end

function DC.integrity:GenerateSalt()
    local partA, partB = self:GenerateSeedParts()
    return stringFormat("%s:%s", tostring(partA), tostring(partB))
end

function DC.integrity:InitializeRuntimeSeed(partA, partB)
    runtimeSeedA = NormalizeUint32(partA)
    runtimeSeedB = NormalizeUint32(partB)
    runtimeSeedReady = true
    parameterCache = {}
    self.parameterCache = {}
end

function DC.integrity:IsRuntimeSeedReady()
    return runtimeSeedReady == true
end

function DC.integrity:ChecksumToUint32(text, useTail)
    local checksum = self:Checksum(text)
    local slice = useTail and checksum:sub(9, 16) or checksum:sub(1, 8)

    return NormalizeUint32(tonumber(slice, 16) or 0)
end

function DC.integrity:DeriveParameters(seedOrChannel, maybeChannel)
    local channel = maybeChannel or seedOrChannel
    local cacheKey = tostring(channel or "")
    local cached = parameterCache[cacheKey]

    if cached ~= nil then
        return cached
    end

    if not runtimeSeedReady then
        error("DamageCalculation integrity seed was not initialized before encoding.", 2)
    end

    local channelText = tostring(channel or "")
    local channelSeedA = Fnv1a32(channelText .. "|A", Xor32Fast(runtimeSeedA, SEED_CONST_A))
    local channelSeedB = Fnv1a32(channelText .. "|B", Xor32Fast(runtimeSeedB, SEED_CONST_B))
    local channelSeedC = Fnv1a32(channelText .. "|C", Xor32Fast(runtimeSeedA, SEED_CONST_C))
    local channelSeedD = Fnv1a32(channelText .. "|D", Xor32Fast(runtimeSeedB, SEED_CONST_D))
    local parameters = {
        addA = channelSeedA,
        maskA = channelSeedB,
        maskB = channelSeedC,
        addB = channelSeedD,
        rotateA = (channelSeedA % 29) + 3,
        rotateB = (channelSeedB % 23) + 5,
    }

    parameterCache[cacheKey] = parameters
    return parameters
end

function DC.integrity:EncodeNumberRaw(value, seedOrChannel, maybeChannel)
    local channel = maybeChannel or seedOrChannel
    local number = NormalizeUint32(max(0, floor(tonumber(value) or 0)))
    local parameters = self:DeriveParameters(channel)
    local encodedValue = Add32Fast(number, parameters.addA)
    encodedValue = Xor32Fast(encodedValue, parameters.maskA)
    encodedValue = Rol32(encodedValue, parameters.rotateA)
    encodedValue = Add32Fast(encodedValue, parameters.addB)
    encodedValue = Xor32Fast(encodedValue, parameters.maskB)
    encodedValue = Rol32(encodedValue, parameters.rotateB)

    return encodedValue
end

function DC.integrity:EncodeNumber(value, seedOrChannel, maybeChannel)
    local encodedValue = self:EncodeNumberRaw(value, seedOrChannel, maybeChannel)

    return tostring(encodedValue)
end

function DC.integrity:DecodeNumber(encodedValue, seedOrChannel, maybeChannel)
    local numericValue = tonumber(encodedValue)

    if numericValue == nil then
        return nil
    end

    local channel = maybeChannel or seedOrChannel
    local parameters = self:DeriveParameters(channel)
    local decodedValue = NormalizeUint32(numericValue)
    decodedValue = Ror32(decodedValue, parameters.rotateB)
    decodedValue = Xor32Fast(decodedValue, parameters.maskB)
    decodedValue = Add32Fast(decodedValue, UINT32 - parameters.addB)
    decodedValue = Ror32(decodedValue, parameters.rotateA)
    decodedValue = Xor32Fast(decodedValue, parameters.maskA)
    decodedValue = Add32Fast(decodedValue, UINT32 - parameters.addA)

    return decodedValue
end

function DC.integrity:SelfTest()
    local savedSeedA = runtimeSeedA
    local savedSeedB = runtimeSeedB
    local savedSeedReady = runtimeSeedReady
    local savedCache = parameterCache
    local checksPassed = true

    self:InitializeRuntimeSeed(Fnv1a32(stringChar(115, 101, 108, 102, 65), SEED_CONST_A), Fnv1a32(stringChar(115, 101, 108, 102, 66), SEED_CONST_B))

    local channels = {
        stringChar(100, 97, 109, 97, 103, 101),
        stringChar(115, 101, 115, 115, 105, 111, 110, 68, 97, 109, 97, 103, 101),
        stringChar(105, 110, 116, 101, 103, 114, 105, 116, 121, 67, 97, 110, 97, 114, 121),
    }

    for index, channel in ipairs(channels) do
        local value = Add32Fast(Mul32Fast(index * 7919, SEED_CONST_C), index * 97)
        local encodedValue = self:EncodeNumberRaw(value, channel)
        local decodedValue = self:DecodeNumber(encodedValue, channel)

        if decodedValue ~= value then
            checksPassed = false
            break
        end
    end

    if checksPassed then
        local checksumA = self:Checksum(stringChar(68, 67, 58, 58, 83, 101, 108, 102, 84, 101, 115, 116))
        local checksumB = self:Checksum(stringChar(68, 67, 58, 58, 83, 101, 108, 102, 84, 101, 115, 117))
        checksPassed = #checksumA == 16 and checksumA ~= checksumB
    end

    runtimeSeedA = savedSeedA
    runtimeSeedB = savedSeedB
    runtimeSeedReady = savedSeedReady
    parameterCache = savedCache or {}
    self.parameterCache = {}

    return checksPassed
end
