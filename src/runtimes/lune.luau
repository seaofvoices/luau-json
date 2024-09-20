local serde = (require)('@lune/serde')

local interface = require('../interface')

type JSON = interface.JSON
type EncodeOptions = interface.EncodeOptions

local getIndentation = interface.getIndentation

local json = {}

function json.encode(data: unknown, options: EncodeOptions?): string
    local indentation = getIndentation(options)
    local pretty = indentation ~= 0
    local result = serde.encode('json', data, pretty)
    return result
end

function json.decode(data: string): unknown
    local content = serde.decode('json', data)
    return content
end

return json
