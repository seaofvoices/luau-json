local fs = require('@lune/fs')
local process = require('@lune/process')
local task = require('@lune/task')

local Disk = require('@pkg/luau-disk')

local Array = Disk.Array

local FILTER_CASES = Disk.Set.fromArray({
    'i_string_UTF-16LE_with_BOM.json',
    'i_string_UTF-8_invalid_sequence.json',
    'i_string_UTF8_surrogate_U+D800.json',
    'i_string_invalid_utf-8.json',
    'i_string_iso_latin_1.json',
    'i_string_lone_utf8_continuation_byte.json',
    'i_string_not_in_unicode_range.json',
    'i_string_overlong_sequence_2_bytes.json',
    'i_string_overlong_sequence_6_bytes.json',
    'i_string_overlong_sequence_6_bytes_null.json',
    'i_string_truncated-utf-8.json',
    'i_string_utf16BE_no_BOM.json',
    'i_string_utf16LE_no_BOM.json',
    'n_array_a_invalid_utf8.json',
    'n_array_invalid_utf8.json',
    'n_number_invalid-utf-8-in-bigger-int.json',
    'n_number_invalid-utf-8-in-exponent.json',
    'n_number_invalid-utf-8-in-int.json',
    'n_number_real_with_invalid_utf8_after_e.json',
    'n_object_lone_continuation_byte_in_key_and_trailing_comma.json',
    'n_string_invalid-utf-8-in-escape.json',
    'n_string_invalid_utf8_after_escape.json',
    'n_structure_incomplete_UTF8_BOM.json',
    'n_structure_lone-invalid-utf-8.json',
    'n_structure_single_eacute.json',
})

if fs.isDir('src/__tests__/test_parsing_expect') then
    fs.removeDir('src/__tests__/test_parsing_expect')
end
fs.writeDir('src/__tests__/test_parsing_expect')

if fs.isDir('src/__tests__/test_parsing_content') then
    fs.removeDir('src/__tests__/test_parsing_content')
end
fs.writeDir('src/__tests__/test_parsing_content')

type Assertion = 'fail' | 'success' | 'whatever'
type TestCase = {
    name: string,
    jsonPath: string,
    assertion: Assertion,
}

local testCases = Array.map(fs.readDir('test_parsing'), function(jsonFile): TestCase?
    if FILTER_CASES[jsonFile] then
        return nil
    end

    local firstChar = string.sub(jsonFile, 1, 1)
    local assertion: Assertion = if firstChar == 'i'
        then 'whatever'
        elseif firstChar == 'n' then 'fail'
        elseif firstChar == 'y' then 'success'
        else error(`unexpected test case '{jsonFile}'`)

    return {
        name = string.sub(jsonFile, 1, -6),
        jsonPath = `test_parsing/{jsonFile}`,
        assertion = assertion,
    }
end)

local expectationSuccess = {}
local expectationThreads = Array.map(testCases, function(case)
    if case.assertion ~= 'success' then
        return nil
    end
    return task.spawn(function()
        local result = process.spawn('darklua', {
            'convert',
            case.jsonPath,
            `src/__tests__/test_parsing_expect/{case.name}.luau`,
        })
        if result.ok then
            expectationSuccess[case.name] = true
        end
    end)
end)

repeat
    task.wait()
until Array.all(expectationThreads, function(thread)
        return coroutine.status(thread) == 'dead'
    end)

for _, case in testCases do
    local content = fs.readFile(case.jsonPath)

    fs.writeFile(
        `src/__tests__/test_parsing_content/{case.name}.luau`,
        `return {string.format('%q', content)}`
    )
end

local function createImports(path: string, filter: ((TestCase) -> boolean)?)
    local imports = Array.map(
        if filter then Array.filter(testCases, filter) else testCases,
        function(case)
            return `    ['{case.name}'] = require('./{case.name}.luau'),`
        end
    )
    local importAll = `return \{\n{table.concat(imports, '\n')}\n}\n`

    fs.writeFile(path, importAll)
end

createImports('src/__tests__/test_parsing_content/init.luau')
createImports('src/__tests__/test_parsing_expect/init.luau', function(case)
    return case.assertion == 'success' and expectationSuccess[case.name]
end)

print('done!')
