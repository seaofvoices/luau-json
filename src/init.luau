local interface = require('./interface')

type JSON = interface.JSON
export type EncodeOptions = interface.EncodeOptions

local impl: JSON = nil

if _G.LUAU_JSON_USE_LUAU then
    impl = require('./default')
elseif _G.LUA_ENV == 'roblox' then
    impl = require('./runtimes/roblox') :: any
elseif _G.LUA_ENV == 'lune' then
    impl = require('./runtimes/lune') :: any
end

if impl == nil then
    impl = require('./default')
end

return impl
