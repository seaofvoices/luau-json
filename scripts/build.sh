#!/bin/sh

set -e

scripts/build-single-file.sh .darklua-bundle.json build/json.luau
scripts/build-single-file.sh .darklua-bundle-dev.json build/debug/json.luau
scripts/build-roblox-model.sh .darklua.json build/json.rbxm
scripts/build-roblox-model.sh .darklua-dev.json build/debug/json.rbxm
