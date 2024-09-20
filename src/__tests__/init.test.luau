local Disk = require('@pkg/luau-disk')
local jestGlobals = require('@pkg/@jsdotlua/jest-globals')

local testCases: { [string]: string } = require('./test_parsing_content') :: any
local testCasesExpectation: { [string]: unknown } = require('./test_parsing_expect') :: any

local json = require('../init')

local expect = jestGlobals.expect
local it = jestGlobals.it

local skipTests = Disk.Set.fromArray({ 'n_structure_100000_opening_arrays' })
local expectedSuccess = Disk.Set.fromArray({
    'i_number_double_huge_neg_exp',
    'i_number_huge_exp',
    'i_number_neg_int_huge_exp',
    'i_number_pos_double_huge_exp',
    'i_number_real_pos_overflow',
    'i_number_real_neg_overflow',
    'i_number_real_underflow',
    'i_number_too_big_neg_int',
    'i_number_too_big_pos_int',
    'i_number_very_big_negative_int',
    'i_object_key_lone_2nd_surrogate',
    'i_string_1st_surrogate_but_2nd_missing',
    'i_string_1st_valid_surrogate_2nd_invalid',
    'i_string_incomplete_surrogate_and_escape_valid',
    'i_string_invalid_lonely_surrogate',
    'i_string_inverted_surrogates_U+1D11E',
    'i_string_incomplete_surrogate_pair',
    'i_string_lone_second_surrogate',
    'i_string_incomplete_surrogates_escape_valid',
    'i_string_invalid_surrogate',
    'i_structure_500_nested_arrays',
})

local skipMatcher = Disk.Set.fromArray({
    'y_number_negative_zero',
    'y_string_nbsp_uescaped',
    'y_number_minus_zero',
    'y_string_u+2029_par_sep',
    'y_string_u+2028_line_sep',
    'y_string_unicode_U+10FFFE_nonchar',
    'y_string_last_surrogates_1_and_2',
})

for name, case in testCases do
    if skipTests[name] then
        continue
    end
    local firstChar = string.sub(name, 1, 1)

    if firstChar == 'i' then
        local test: any = if expectedSuccess[name] then it else it.failing
        test(`may parse (or not) '{name}'`, function()
            json.decode(case)
        end)
    elseif firstChar == 'n' then
        it.failing(`does not parse test case '{name}'`, function()
            json.decode(case)
        end)
    elseif firstChar == 'y' then
        it(`parses test case '{name}'`, function()
            json.decode(case)
        end)

        local itOrSkip: any = if skipMatcher[name] then it.skip else it
        itOrSkip(`parses test case and match expectation'{name}'`, function()
            expect(json.decode(case)).toEqual(testCasesExpectation[name])
        end)

        local function decodeAndEncode(options: json.EncodeOptions?)
            local value = json.decode(case)

            local jsonString = json.encode(value, options)

            local decoded
            local s, err = pcall(function()
                decoded = json.decode(jsonString)
            end)

            if not s then
                error(`unable to parse "{jsonString}": {err}`)
            end

            expect(decoded).toEqual(value)
        end

        it(`parses test case '{name}', encode it and parse it back`, function()
            decodeAndEncode()
        end)

        it(`parses test case '{name}', encode it and parse it back`, function()
            decodeAndEncode(2)
        end)
    else
        warn(`unexpected test case '{name}'`)
    end
end
