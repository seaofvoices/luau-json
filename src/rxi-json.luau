-- upstream: https://github.com/rxi/json.lua/blob/11077824d7cfcd28a4b2f152518036b295e7e4ce/json.lua

local Disk = require('@pkg/luau-disk')

local Array = Disk.Array
local Map = Disk.Map
local Set = Disk.Set

--
-- json.lua
--
-- Copyright (c) 2020 rxi
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy of
-- this software and associated documentation files (the "Software"), to deal in
-- the Software without restriction, including without limitation the rights to
-- use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
-- of the Software, and to permit persons to whom the Software is furnished to do
-- so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
--

local json = { _version = '0.1.2' }

-------------------------------------------------------------------------------
-- Encode
-------------------------------------------------------------------------------

local encode

local escapeCharMap = {
    ['\\'] = '\\',
    ['"'] = '"',
    ['\b'] = 'b',
    ['\f'] = 'f',
    ['\n'] = 'n',
    ['\r'] = 'r',
    ['\t'] = 't',
}

local escapeCharMapInv = Map.merge({ ['/'] = '/' }, Map.invert(escapeCharMap))

local function escapeChar(c)
    return '\\' .. (escapeCharMap[c] or string.format('u%04x', string.byte(c)))
end

local function encodeNil(_val: nil, state: EncodeState)
    table.insert(state.output, 'null')
end

local function isArray(val: { [unknown]: unknown }): (boolean, number)
    local largestIndex = 0
    for key in val do
        if type(key) ~= 'number' then
            return false, 0
        elseif key < 0 or key ~= key or key % 1 ~= 0 then
            return false, 0
        end
        if key > largestIndex then
            largestIndex = key
        end
    end
    return true, largestIndex
end

local function encodeTable(val, state: EncodeState)
    local stack
    local seenStackCreated = false
    if state.seen == nil then
        stack = {}
        state.seen = stack
        seenStackCreated = true
    else
        stack = state.seen
    end

    -- Circular reference?
    if stack[val] then
        error('circular reference')
    end

    stack[val] = true

    local indentation = state.indentation

    local valueIsArray, lastIndex = isArray(val)
    if valueIsArray then
        -- Treat as array -- check keys are valid and it is not sparse
        if lastIndex == 0 then
            table.insert(state.output, '[]')
        else
            table.insert(state.output, '[')
            state.depth += 1
            if indentation then
                table.insert(state.output, '\n')
                table.insert(state.output, string.rep(indentation, state.depth))
            end
            local addComma = false
            for i = 1, lastIndex do
                if addComma then
                    if indentation then
                        table.insert(state.output, ',\n')
                        table.insert(state.output, string.rep(indentation, state.depth))
                    else
                        table.insert(state.output, ',')
                    end
                else
                    addComma = true
                end
                encode(val[i], state)
            end
            state.depth -= 1
            if indentation then
                table.insert(state.output, '\n')
                table.insert(state.output, string.rep(indentation, state.depth))
            end
            table.insert(state.output, ']')
            stack[val] = nil
        end
    else
        -- Treat as an object
        if next(val) == nil then
            table.insert(state.output, '{}')
        else
            table.insert(state.output, '{')
            state.depth += 1
            if indentation then
                table.insert(state.output, '\n')
                table.insert(state.output, string.rep(indentation, state.depth))
            end
            local addComma = false
            for k, v in val do
                if type(k) ~= 'string' then
                    error('invalid table: mixed or invalid key types')
                end
                if addComma then
                    if indentation then
                        table.insert(state.output, ',\n')
                        table.insert(state.output, string.rep(indentation, state.depth))
                    else
                        table.insert(state.output, ',')
                    end
                else
                    addComma = true
                end

                encode(k, state)
                if indentation then
                    table.insert(state.output, ': ')
                else
                    table.insert(state.output, ':')
                end
                encode(v, state)
            end
            state.depth -= 1
            if indentation then
                table.insert(state.output, '\n')
                table.insert(state.output, string.rep(indentation, state.depth))
            end
            table.insert(state.output, '}')
            stack[val] = nil
        end
    end

    if seenStackCreated then
        state.seen = nil
    end
end

local function encodeString(val: string, state: EncodeState)
    table.insert(state.output, '"')
    local str = string.gsub(val, '[%z\1-\31\\"]', escapeChar)
    table.insert(state.output, str)
    table.insert(state.output, '"')
end

local function encodeNumber(val: number, state: EncodeState)
    -- Check for NaN, -inf and inf
    if val ~= val or val <= -math.huge or val >= math.huge then
        error(`unexpected number value '{val}'`)
    end
    table.insert(state.output, string.format('%.14g', val))
end

local function encodeBoolean(val: boolean, state: EncodeState)
    if val then
        table.insert(state.output, 'true')
    else
        table.insert(state.output, 'false')
    end
end

local typeFunctionMap = {
    ['nil'] = encodeNil,
    ['table'] = encodeTable,
    ['string'] = encodeString,
    ['number'] = encodeNumber,
    ['boolean'] = encodeBoolean,
}

function encode(val: unknown, state: EncodeState)
    local t = type(val)
    local f = typeFunctionMap[t]
    if f then
        return f(val, state)
    end
    error(`unexpected type '{t}'`)
end

type EncodeState = {
    seen: { [any]: true }?,
    output: { string },
    indentation: string?,
    depth: number,
}

function json.encode(val: unknown, indentation: string?)
    local state: EncodeState = {
        seen = nil,
        output = {},
        indentation = indentation,
        depth = 0,
    }
    encode(val, state)
    return table.concat(state.output, '')
end

-------------------------------------------------------------------------------
-- Decode
-------------------------------------------------------------------------------

local parse

local notSpaceChars = '[^ \t\r\n]'
local delimChars = '[ \t\r\n%]},]'
local escapeChars = Set.fromArray({ '\\', '/', '"', 'b', 'f', 'n', 'r', 't', 'u' })
local literals = Set.fromArray({ 'true', 'false', 'null' })

local function nextChar(str: string, idx: number, characterClass: string)
    local index = string.find(str, characterClass, idx)
    return index or (#str + 1)
end

local function decodeError(str: string, idx: number, msg: string): never
    local line_count = 1
    local col_count = 1
    for i = 1, idx - 1 do
        col_count = col_count + 1
        if string.sub(str, i, i) == '\n' then
            line_count = line_count + 1
            col_count = 1
        end
    end
    error(`{msg} at line {line_count} column {col_count}`)
end

local function codepointToUtf8(n: number): string
    -- http://scripts.sil.org/cms/scripts/page.php?site_id=nrsi&id=iws-appendixa
    local f = math.floor
    if n <= 0x7f then
        return string.char(n)
    elseif n <= 0x7ff then
        return string.char(f(n / 64) + 192, n % 64 + 128)
    elseif n <= 0xffff then
        return string.char(f(n / 4096) + 224, f(n % 4096 / 64) + 128, n % 64 + 128)
    elseif n <= 0x10ffff then
        return string.char(
            f(n / 262144) + 240,
            f(n % 262144 / 4096) + 128,
            f(n % 4096 / 64) + 128,
            n % 64 + 128
        )
    end
    error(string.format("invalid unicode codepoint '%x'", n))
end

local function parseUnicodeEscape(s: string)
    local n1 = tonumber(string.sub(s, 1, 4), 16) :: number
    local n2 = tonumber(string.sub(s, 7, 10), 16)
    -- Surrogate pair?
    if n2 then
        return codepointToUtf8((n1 - 0xd800) * 0x400 + (n2 - 0xdc00) + 0x10000)
    else
        return codepointToUtf8(n1)
    end
end

local function parseString(str: string, i: number): (string, number)
    local res = {}
    local j = i + 1
    local k = j

    while j <= #str do
        local x = string.byte(str, j)

        if x < 32 then
            decodeError(str, j, 'control character in string')
        elseif x == 92 then -- `\`: Escape
            table.insert(res, string.sub(str, k, j - 1))
            j = j + 1
            local c = string.sub(str, j, j)
            if c == 'u' then
                local hex = string.match(str, '^[dD][89aAbB]%x%x\\u%x%x%x%x', j + 1)
                    or string.match(str, '^%x%x%x%x', j + 1)
                    or decodeError(str, j - 1, 'invalid unicode escape in string')
                table.insert(res, parseUnicodeEscape(hex))
                j = j + #hex
            else
                if not escapeChars[c] then
                    decodeError(str, j - 1, `invalid escape char '{c}' in string`)
                end
                table.insert(res, escapeCharMapInv[c])
            end
            k = j + 1
        elseif x == 34 then -- `"`: End of string
            table.insert(res, string.sub(str, k, j - 1))
            return table.concat(res, ''), j + 1
        end

        j = j + 1
    end

    decodeError(str, i, 'expected closing quote for string')
    error('unreachable')
end

local integerPatterns = {
    '%-?%d',
    '%-?[1-9]%d+',
}
local fractionPattern = '%.%d+'
local exponentPattern = '[eE][%+%-]?%d+'

local numberPatterns = Array.flatMap(
    { '', fractionPattern, exponentPattern, fractionPattern .. exponentPattern },
    function(suffix)
        return Array.map(integerPatterns, function(pattern)
            return `^{pattern}{suffix}$`
        end)
    end
)

local function validateNumber(s: string): boolean
    for _, pattern in numberPatterns do
        if string.match(s, pattern) then
            return true
        end
    end
    return false
end

local function parseNumber(str: string, i: number): (number, number)
    local x = nextChar(str, i, delimChars)
    local s = string.sub(str, i, x - 1)

    local n = tonumber(s)
    if n == nil or not validateNumber(s) then
        decodeError(str, i, `invalid number '{s}'`)
    end
    return n :: number, x
end

local literalMap = {
    ['true'] = true,
    ['false'] = false,
    ['null'] = nil,
}

local function parseLiteral(str: string, i: number): (boolean?, number)
    local x = nextChar(str, i, delimChars)
    local word = string.sub(str, i, x - 1)
    if not literals[word] then
        decodeError(str, i, `invalid literal '{word}'`)
    end
    return literalMap[word], x
end

local function parseArray(str: string, i: number): ({ unknown }, number)
    local res = {}
    local n = 1
    i = i + 1
    while true do
        local x
        i = nextChar(str, i, notSpaceChars)
        -- Empty / end of array?
        if n == 1 and string.sub(str, i, i) == ']' then
            i = i + 1
            break
        end
        -- Read token
        x, i = parse(str, i)
        res[n] = x
        n = n + 1
        -- Next token
        i = nextChar(str, i, notSpaceChars)
        local chr = string.sub(str, i, i)
        i = i + 1
        if chr == ']' then
            break
        end
        if chr ~= ',' then
            decodeError(str, i, "expected ']' or ','")
        end
    end
    return res, i
end

local function parseObject(str: string, i: number): ({ [string]: unknown }, number)
    local res = {}
    i = i + 1
    local n = 0
    while true do
        local key, val
        i = nextChar(str, i, notSpaceChars)
        -- Empty / end of object?
        if n == 0 and string.sub(str, i, i) == '}' then
            i = i + 1
            break
        end
        n += 1
        -- Read key
        if string.sub(str, i, i) ~= '"' then
            decodeError(str, i, 'expected string for key')
        end
        key, i = parse(str, i)
        -- Read ':' delimiter
        i = nextChar(str, i, notSpaceChars)
        if string.sub(str, i, i) ~= ':' then
            decodeError(str, i, "expected ':' after key")
        end
        i = nextChar(str, i + 1, notSpaceChars)
        -- Read value
        val, i = parse(str, i)
        -- Set
        res[key] = val
        -- Next token
        i = nextChar(str, i, notSpaceChars)
        local chr = string.sub(str, i, i)
        i = i + 1
        if chr == '}' then
            break
        end
        if chr ~= ',' then
            decodeError(str, i, "expected '}' or ','")
        end
    end
    return res, i
end

local char_func_map = {
    ['"'] = parseString,
    ['0'] = parseNumber,
    ['1'] = parseNumber,
    ['2'] = parseNumber,
    ['3'] = parseNumber,
    ['4'] = parseNumber,
    ['5'] = parseNumber,
    ['6'] = parseNumber,
    ['7'] = parseNumber,
    ['8'] = parseNumber,
    ['9'] = parseNumber,
    ['-'] = parseNumber,
    ['t'] = parseLiteral,
    ['f'] = parseLiteral,
    ['n'] = parseLiteral,
    ['['] = parseArray,
    ['{'] = parseObject,
}

parse = function(str: string, idx: number)
    local chr = string.sub(str, idx, idx)
    local f = char_func_map[chr]
    if f then
        return f(str, idx)
    end
    decodeError(str, idx, "unexpected character '" .. chr .. "'")
end

function json.decode(str)
    if type(str) ~= 'string' then
        error('expected argument of type string, got ' .. type(str))
    end
    local res, idx = parse(str, nextChar(str, 1, notSpaceChars))
    idx = nextChar(str, idx, notSpaceChars)
    if idx <= #str then
        decodeError(str, idx, 'trailing garbage')
    end
    return res
end

return json
