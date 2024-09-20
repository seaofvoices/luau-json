export type EncodeOptions = number | { indentation: number? }

export type JSON = {
    encode: (data: unknown, options: EncodeOptions?) -> string,
    decode: (jsonString: string) -> unknown,
}

local function getIndentation(options: EncodeOptions?): number
    return if options == nil
        then 0
        elseif type(options) == 'number' then math.max(0, options)
        else math.max(0, options.indentation or 0)
end

return {
    getIndentation = getIndentation,
}
