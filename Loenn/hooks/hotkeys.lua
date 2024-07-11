
local mods = require('mods')
local utils = require('utils')
local hotkeyStruct = require('structs.hotkey')
-- Loenn Extended references
local customHotkeys = mods.requireFromPlugin("libraries.hotkeys")

local hook = {
    ["hotkey_handler|createHotkeyDevice"] = {
        priority = 2147483647,
        version = "0.7.10",
        new = function(orig, hotkeys)
            local device = orig(hotkeys)
            device._isHotkeyDevice = true -- ensures that the device is a hotkey device, just incase someone makes a second hotkey device but surely noone wo- oh dear god someone did
            for _,hotkey in pairs(customHotkeys.keys) do 
                table.insert(device.hotkeys, hotkey)
            end
            return device
        end
    }
}