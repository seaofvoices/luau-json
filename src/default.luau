local interface = require('./interface')
local rxijson = require('./rxi-json')

type JSON = interface.JSON
type EncodeOptions = interface.EncodeOptions

local getIndentation = interface.getIndentation

local json: JSON = {} :: any

function json.encode(data: unknown, options: EncodeOptions?): string
    local indentation = getIndentation(options)

    local result =
        rxijson.encode(data, if indentation == 0 then nil else string.rep(' ', indentation))

    return result
end

function json.decode(data: string): unknown
    local result = rxijson.decode(data)
    return result
end

return json
