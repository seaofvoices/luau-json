<div align="center">

[![checks](https://github.com/seaofvoices/luau-json/actions/workflows/test.yml/badge.svg)](https://github.com/seaofvoices/luau-json/actions/workflows/test.yml)
![version](https://img.shields.io/github/package-json/v/seaofvoices/luau-json)
[![GitHub top language](https://img.shields.io/github/languages/top/seaofvoices/luau-json)](https://github.com/luau-lang/luau)
![license](https://img.shields.io/npm/l/luau-json)
![npm](https://img.shields.io/npm/dt/luau-json)

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/seaofvoices)

</div>

# luau-json

A package to create a standard interface for reading and writing JSON. It follows the [Sea of Voices Luau Package Standard](https://github.com/seaofvoices/luau-package-standard) to select the built-in JSON readers and writers. If none are found, this package also includes a default Luau only implementation that will be used.

- If `_G.LUA_ENV` is set to `"roblox"`, it will use Roblox HttpService JSON utility.
- If `_G.LUA_ENV` is set to `"lune"`, it will use the Lune built-in [serde package](https://lune-org.github.io/docs/api-reference/serde).
- Otherwise, the Luau implementation will be used.

The Luau implementation can be forced if `_G.LUAU_JSON_USE_LUAU` is `true`.

## Installation

Add `luau-json` in your dependencies:

```bash
yarn add luau-json
```

Or if you are using `npm`:

```bash
npm install luau-json
```

## Content

### encode

```lua
function encode(data: unknown, options: EncodeOptions?): string
```

Encodes data into a JSON string. The optional options argument allows customization such as pretty-printing.

### decode

```lua
function decode(jsonString: string): unknown
```

Decodes a JSON string into a value.

### EncodeOptions

```lua
type EncodeOptions = number | { indentation: number? }
```

- indentation: Number of spaces used for indentation when pretty-printing JSON.

## Other Lua Environments Support

If you would like to use this library on a Lua (or Luau) environment where it is currently incompatible, open an issue (or comment on an existing one) to request the appropriate modifications.

The library uses [darklua](https://github.com/seaofvoices/darklua) to process its code.

## Acknowledgement

- The Luau JSON parser is based of the implementation at [rxi/json.lua](https://github.com/rxi/json.lua)
- The test suite was taken from [nst/JSONTestSuite](https://github.com/nst/JSONTestSuite)

## License

This project is available under the MIT license. See [LICENSE.txt](LICENSE.txt) for details.
