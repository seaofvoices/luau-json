local default = require('../default')
local interface = require('../interface')

type JSON = interface.JSON
type EncodeOptions = interface.EncodeOptions

local HttpService = game:GetService('HttpService')

local getIndentation = interface.getIndentation

local json = {}

function json.encode(data: unknown, options: EncodeOptions?): string
    local indentation = getIndentation(options)

    if indentation ~= 0 then
        return default.encode(data, options)
    end

    return HttpService:JSONEncode(data)
end

function json.decode(jsonString: string): unknown
    return HttpService:JSONDecode(jsonString)
end

return json
