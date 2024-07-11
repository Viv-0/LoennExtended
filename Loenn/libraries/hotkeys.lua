--[[
    Format:
    return hotkey 
    return {
        activator = "ctrl + v",
        callback = function() do stuff in here
    }
    return {
        hotkey or {activator, callback},
        hotkey2 or {activator, callback}
        ...
    }
]]

local mods = require('mods')
local utils = require('utils')
local hotkeyStruct = require('structs.hotkey')
local hotkeyHandler = require('hotkey_handler')
local standard_hotkeys = require('standard_hotkeys')
local sceneHandler = require('scene_handler')
local le_utils = mods.requireFromPlugin('libraries.utils')
local notifications = require("ui.notification")

local hotkeys = {
    keys = {}
}

local singleHotkeyKeys = {"activator", "callback"}

function hotkeys:loadHotkey(file, modName)
    if not file then return end
    local typ = utils.typeof(file)
    if typ == "hotkey" then
        self.keys[modName] = file
    elseif typ == "table" then
        if utils.countKeys(typ) < 1 then
            return
        elseif utils.equals(table.sort(table.keys(file)), singleHotkeyKeys) then
            self.keys[modName] = hotkeyStruct.createHotkey(file[activator], file[callback])
        else
            for k,v in pairs(file) do
                local hotkey 
                if type(v) == "table" and v[activator] and v[callback] then
                    hotkey = hotkeyStruct.createHotkey(v[activator], v[callback])
                elseif utils.typeof(v) == "hotkey" then
                    hotkey = v
                end
                local key = modName .. le_utils.Delimiter .. tostring(k)
                self.keys[key] = hotkey
            end
        end
    end   
end

function hotkeys:unloadHotkey(hotkey)
    if utils.typeof(hotkey) == "hotkey" then
        for k,v in pairs(self.keys) do 
            if v.activator == hotkey.activator then 
                self.keys[k] = nil
                notifications.notify("Unloaded hotkey with keybind " .. hotkey.activator)
                return
            end
        end
        notifications.notify("Failed to unload hotkey with keybind " .. hotkey.activator)
    elseif type(hotkey) == "table" and type(hotkey.activator) == "string" then
        local activator = hotkeyStruct.sanitize(hotkey.activator)
        for k,v in pairs(self.keys) do 
            if v.activator == activator then 
                self.keys[k] = nil
                notifications.notify("Unloaded hotkey with keybind " .. activator)
                return
            end
        end
        notifications.notify("Failed to unload hotkey with keybind " .. activator)    
    elseif type(hotkey) == "string" then
        local activator = hotkeyStruct.sanitize(hotkey)
        for k,v in pairs(self.keys) do 
            if v.activator == activator then 
                self.keys[k] = nil
                notifications.notify("Unloaded hotkey with keybind " .. activator)
                return
            end
        end
        notifications.notify("Failed to unload hotkey with keybind " .. activator)    
    else
        notifications.notify("Failed to unload hotkey - invalid hotkey provided")
    end
end

function hotkeys.unloadHotkeys()
    hotkeys.keys = {}
end

function hotkeys:applyHotkeys()
    if sceneHandler and sceneHandler.currentScene and sceneHandler.currentScene.name == "Editor" then 
        -- hotkeyHandler.createHotkeyDevice is hooked to add custom hotkeys
        local devices = sceneHandler.currentScene.inputDevices
        for i = 0, #devices, 1 do
            if devices[i]._isHotkeyDevice then 
                devices[i].hotkeys = hotkeyHandler.createHotkeyDevice(standard_hotkeys)
                return
            end
        end
    end
    -- if sceneHandler is not Editor, there's no hotkeys and the scene will eventually *be* Editor when the hotkeys will be instantiated.
end

function hotkeys:reloadHotkey(hotkey)
    if utils.typeof(hotkey) == "hotkey" then
        for k,v in pairs(self.keys) do 
            if v.activator == hotkey.activator then 
                self.keys[k] = hotkey
                notifications.notify("Reloaded hotkey with keybind " .. hotkey.activator)
                return
            end
        end
        notifications.notify("Failed to reload hotkey with keybind " .. hotkey.activator)
    elseif type(hotkey) == "table" and type(hotkey.activator) == "string" then
        local activator = hotkeyStruct.sanitize(hotkey.activator)
        for k,v in pairs(self.keys) do 
            if v.activator == activator then 
                self.keys[k] = hotkeyHandler.createHotkey(hotkey.activator, hotkey.callback)
                notifications.notify("Reloaded hotkey with keybind " .. activator)
                return
            end
        end
        notifications.notify("Failed to reload hotkey with keybind " .. activator)    
    else
        notifications.notify("Failed to reload hotkey - invalid hotkey provided")
    end
end

function hotkeys:reloadHotkeys()
    logging.info("Loenn Extended - Reloading custom Hotkey processor")
    -- unloads hotkeys
    self.keys = {}
    -- loads hotkeys
    local internal, external = le_utils.findPluginsYieldSafe(function(filename) return filename:match('^$(.+)$/Loenn/extended/hotkeys.lua$') end, "extended")
    local modName = "LoennExtended"
    for _, filename in ipairs(internal) do
        local pathNoExt = utils.stripExtension(filename)
        local valid, table = le_utils.tryRequireWithReload(pathNoExt)
        if valid then 
            self:loadHook(table, modName)
        else
            logging.error(string.format("LoennExtended - hotkeys for mod `%s` failed to load!", modName))
        end
    end
    for _, filename in ipairs(external) do
        modName = filename:match("^$(.+)$/Loenn/.+")
        if modName and modHandler.modMetadata[modName].Name then
            modName = modHandler.modMetadata[modName].Name
            local pathNoExt = utils.stripExtension(filename)
            local valid, table = le_utils.tryRequireWithReload(pathNoExt)
            if valid then 
                self:loadHook(table, modName)
            else
                logging.error(string.format("LoennExtended - hotkeys for mod `%s` failed to load!", modName))
            end
        end
    end

    self:applyHotkeys()
end

return hotkeys