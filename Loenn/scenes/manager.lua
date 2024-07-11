--[[
    -Viv was here-
    Welcome! You've reached hell.

    DO NOT DO ANYTHING YOU ARE ABOUT TO SEE HERE IN ANY OTHER MODS -
    This is exlicitly not endorsed by anyone on the Loenn team and is so dangerous for the codebase that it needs to be actively managed by me
    If you need *any* features in this, contact @vividescence on discord, so I can add it myself to LoennExtended.



















    This is the thing that allows all mods to hook into things *after* "everything else" has been loaded. Hooks *need* to come after all code is loaded.
    This, unfortunately, means that some things cannot be trivially hooked into working out-of-the-box, simply because there's no way to guarantee load order if we didn't.

    Format for hookManager table:

    hookManager = {
        hooks = {
            [sourceDef] = {
                old = [function pointer to original function],
                new = [function pointer to replacement method],
                sources = {
                    
                    [floating-point priority] = [wrapper function as pointer]
                }
            }
        },
        localhooks = list of : {
                [0] = [ftnptr old]
                [1] = string
                [2] = [ftnptr new]
            }
        }
    }
    

    [source definition] is defined as [require path]|[table named path to function]

    Wrapper format:
    
    return one or a list of: {
        [function pointer to original method] = {new = [wrapper function], priority = [number]}
    }
    example:
    return {
        [require('triggers').getDrawable] = {
            priority = 0,
            new = function(orig, name, handler, room, trigger, viewport),
            version = "0.7.10"
        }
    }
]]

-- this entire section is dummy code to shut up Loenn
local modHandler = require('mods')
local le_utils = modHandler.requireFromPlugin('libraries.utils')
local utils = require('utils')
local loadedState = require('loaded_state')
local HOOKMANAGERNAME = le_utils.hookManagerName
local DELIMITER = le_utils.Delimiter
local eventsAPI = modHandler.requireFromPlugin('libraries.api.events')

local sceneHandler = require('scene_handler')
local fakeScene = { name = HOOKMANAGERNAME, __type = "scene" }
function fakeScene:loaded() 
    -- remove this from the list of active scenes
    sceneHandler.scenes[HOOKMANAGERNAME] = nil
end

-- This nil check is required here to prevent double instancing
local fonts = require('fonts')
if fonts[HOOKMANAGERNAME] then
    return fakeScene
end
local hookManager = {
    hooks = {}
}
fonts[HOOKMANAGERNAME] = hookManager

-- prevent editing hookManager table without raw access
setmetatable(fonts, {
    __index = function(table, key)
        if key == HOOKMANAGERNAME then
            local fs = debug.getinfo(2, "S")
            if not (fs and fs:match(le_utils.hookManagerFolderNameMatch)) then 
                return false
            end
        end
        return rawget(table, key)
    end, 
    __newindex = function(table, key, value)
        if key ~= HOOKMANAGERNAME then 
            rawset(table, key, value)
        end
    end
})

local bannedHooks = {
    "scene_handler|draw",
    "ui.ui_device|initializeDevice",
    "scenes.editor|firstEnter"
}

local EPSILON = 0.1
local justBelow = 2147483646

local logging = require('logging')
local configs = require('configs')
local ui_device = require('ui.ui_device')
local debugUtils = require('debug_utils')
local triggers = require('triggers')
local pluginLoader = require('plugin_loader')
local meta = require('meta')
local hotkeyHandler = require('hotkey_handler')
local version = require('utils.version_parser')

local function sortByKeys(entries)
    local entryKeys = {} ; local entryValues = {}
    for k, v in pairs(entries) do entryKeys[#entryKeys+1] = k end
    table.sort(entryKeys)
    for _, k in ipairs(entryKeys) do entryValues[#entryValues+1] = entries[k] end
    return entryValues, entryKeys
end

local _, sortedModsList = sortByKeys(modHandler.loadedMods)

local function getsetManual(str, value)
    local st = string.split(str, DELIMITER)._tbl
    local result = require(st[1]) -- require(st[1])    
    for i = 2, #st, 1 do 
        local name 
        if type(result) == "function" then
            local _type, index, name = st[i]:match("^%$%$(%a+)(%d+):(%a+)")
            local idx = tonumber(index)
            if _type and idx then 
                if _type == "local" then
                    if i == #st then 
                        if value then 
                            debug.setlocal(result, b, value)
                            return
                        else
                            return debug.getlocal(result, b)
                        end
                    else
                        name, result = debug.getlocal(result, b)
                    end
                elseif _type == "up" then
                    if i == #st then 
                        if value then 
                            debug.setupvalue(result, b, value)
                            return
                        else
                            return debug.getupvalue(result, b)
                        end
                    else
                        name, result = debug.getupvalue(result, b)
                    end
                else 
                    error("Broke " .. str .. " at " .. st[i] .. ": a was not local or up")
                end
            else error("Broke " .. str .. " at " .. st[i]) end
        elseif type(result) == "table" then 
            result = result[st[i]]
        else
            error("Broke " .. str .. " at " .. st[i])
        end
    end
end

-- this is an internal function so it's *only* going to run for LoennExtended
local function produceManual(tbl, _hookManager)
    local lHooks = _hookManager.localhooks or {}
    if tbl[1] == "table" then
        for _, _v in ipairs(tbl) do 
            local v = utils.deepcopy(_v)
            local _, q = getsetManual(_hookManager, v[1])
            v[0] = q
            lHooks[#lHooks+1] = v
        end
    else
        local _tbl = utils.deepcopy(tbl)
        local _, q = getsetManual(_hookManager, _tbl[1]) -- gets 
        _tbl[0] = q
        lHooks[#lHooks+1] = _tbl
    end
    _hookManager.localhooks = lHooks
end


local function decomposeFromPackage(sourceDef, errorcheck) 
    st = string.split(sourceDef, DELIMITER)._tbl
    local req = package.loaded[st[1]] or require(st[1]) -- hard reference
    local temp = req -- weak reference
    local a
    if errorcheck then
        local set = ""
        local s = string.split(st[2], '.')._tbl
        if #s == 1 then 
            a = s[1]
        else
            for i = 0, #s - 1, 1 do
                temp = temp[s[i]]
                a = s[i+1]
                set = set .. "." .. s[i]
                if not temp then
                    errorcheck = errorcheck .. "\nHook handler failed to validate source definition: `require('" .. st[1] .. "')" .. set .. "` could not be found."
                    return nil
                end
            end
        end
    else
        local s = string.split(st[2], '.')._tbl
        if #s == 1 then 
            a = s[1]
        else
            for i = 0, #s - 1, 1 do
                temp = temp[s[i]]
                a = s[i+1]
                set = set .. "." .. s[i]
                if not temp then
                    errorcheck = errorcheck .. "\nHook handler failed to validate source definition: `require('" .. st[1] .. "')" .. set .. "` could not be found."
                    return nil
                end
            end
        end
    end
    return temp[a], temp, a
end

local function validateSource(_hookManager, sourceDef, errorcheck, func)
    local ret = decomposeFromPackage(sourceDef)
    if type(ret) ~= "function" then
        return false
    end
    if func then func = ret end
    return true
end

local function validateSingle(_hookManager, k, v, errorcheck, source, internal)
    -- We now have a "handler" equivalent to an entity handler as a table. the Table format is very specific, so if someone messes it up here, we go bitch at them
    if type(v) ~= "table" then
        errorcheck = errorcheck .. "\nHook handler did not return as a table."
        return false
    else
        if not v.version or version(v.version) < meta.version then
            errorcheck = errorcheck .. "\nHook handler has version " .. v.version .. ", which is not up-to-date compared to Loenn version " .. tostring(meta.version)
            return false
        end
        if not (r or (v.priority and utils.isInteger(v.priority))) then
            errorcheck = errorcheck .. "\nHook handler did not have a valid priority. Priority should be an integer. (use 0 as default)"
            return false
        end
    end
    if internal and k == "$$manual" then
        local errorlog = produceManual(v, _hookManager)
        if errorlog then
            errorcheck = errorcheck .. errorlog
            return false
        else
            return true
        end

    elseif type(k) == "function" then
        local status, q = le_utils.getSourceFromFunction(k, _hookManager)
        
        if status then 
            if validateSource(_hookManager, q, errorcheck) then
                local s = source[q] or {}
                s[0] = k
                s[#s+1] = v
                source[q] = s
                return true
            end
        else 
            errorcheck = errorcheck .. "\nHook handler failed to get source from function: " .. q
            return false
        end
    elseif type(k) == "string" then
        local f = function() end
        if validateSource(_hookManager, k, errorcheck, f) then
            local s = source[k] or {}
            s[0] = f
            s[#s+1] = v
            source[k] = s
            return true
        end
    else 
        errorcheck = errorcheck .. "\nHook handler does not have a key corresponding to the replaced function, or the source definition"
        return false
    end
    return false
end

local function validate(_hookManager, handler, fileRef, source, internal)
    source = source or {}
    local errorcheck = HOOKMANAGERNAME .. ": A number of issues were spotted with hook handler at " .. fileRef .. ":"
    local baseerr = errorcheck

    for k, v in pairs(handler) do
        if not validateSingle(_hookManager, k,v, errorcheck, source, internal) then break end
    end
    if errorcheck ~= baseerr then
        if isZip then
            logging.error(errorcheck)
        else
            error(errorcheck)
        end
        return false
    end
    return true
end

--[[
    source format:
    source = {
        sourceDef = {
            [0] = origMethod
            [1] = wrapper or replacer data
            [2] = wrapper or replacer data
            ...
        },
        sourceDef2 = {
            ...
        }
    }
]]
local function indexOf(tbl, value)
    for i, v in ipairs(tbl) do
        if v == value then
            return i
        end
    end
end


local function handleWrapper(wrappers, _data, modName, filename, sourceDef)
    for _, data in ipairs(_data) do
        local new = data.new
        if type(data.priority) == "string" then
            if data.priority == "instant" then
                data.priority = 0
            elseif data.priority == "early" then
                data.priority = 100
            elseif data.priority == "middle" then
                data.priority = 10000
            elseif data.priority == "late" then
                data.priority = 1000000
            end
        end
        if data.priority > justBelow then
            data.priority = justBelow
            while wrappers[data.priority] do
                data.priority = data.priority - 1 -- this is the dp-epsilon at 2147483647
            end
        elseif not (modName == HOOKMANAGERNAME and data.priority < 1) then 
            if data.priority < 1 then data.priority = 1 + (indexOf(sortedModsList, modName) / #sortedModsList)
            else data.priority = data.priority + (indexOf(sortedModsList, modName) / #sortedModsList) end
            -- priority 0 is reserved for LoennExtended only, since it *has* to be the lowest on the stack
            while wrappers[data.priority] do
                data.priority = data.priority + EPSILON
            end
        end
        wrappers[data.priority] = data.new
        logging.info(string.format("Loenn Hook Manager - Registered wrapper for %s with table in %s", sourceDef, filename))
    end
end

local function fileToHook(_hookManager, filename, internal)
    -- Basic plugin loading shenanigans
    print(filename)
    local modName = filename:match('^$([^/\\?%%*:|"<>%s]+)$/Loenn/hooks/.+')
    local isZip = modName:match("^(.+)_zip$")
    if isZip then
        modName = isZip
    end
    local pathNoExt = utils.stripExtension(filename)
    local handler = utils.rerequire(pathNoExt)
    if type(handler) == "nil" or handler == true then 
        logging.info(string.format("Loenn Hook Manager: hooks @ %s did not load because it returned `nil` or `true`.", filename))
        return
    end

    local source = {}
    -- ??? Test if the handler is a "list" of handlers.
    if #handler > 0 then
        for i, h in ipairs(handler) do
            local fileRef = filename .. " index " .. tostring(i)
            if not validate(_hookManager, h, fileRef, source, internal) then return end
        end
    elseif not validate(_hookManager, handler, filename, source, internal) then return end
    for sourceDef,data in pairs(source) do
        if utils.contains(sourceDef, bannedHooks) then error("Unhookable method attempted to be hooked!") end
        if not _hookManager.hooks[sourceDef] then
            _hookManager.hooks[sourceDef] = {
                old = data[0], -- gets function pointer early
                sources = {}
            }
        end
        handleWrapper(_hookManager.hooks[sourceDef].sources, data, modName, filename, sourceDef)
    end
end

-- coroutine.yield is stinky apparently.
function hookManager:loadHooks()
    local internal, external = le_utils.findPluginsYieldSafe(nil, "hooks")
    for _, filename in ipairs(internal) do
        fileToHook(self, filename, true)
    end
    for _, filename in ipairs(external) do
        fileToHook(self, filename, false)
    end
end

function hookManager:unloadHooks()
    for sourceDef, hooks in pairs(self.hooks) do
        if sourceDef:match("^[^|]+|[^%.]+$") then
            local st = string.split(sourceDef, DELIMITER)._tbl
            package.loaded[st[1]][st[2]] = hooks.old
        else
            local ret = decomposeFromPackage(sourceDef)
            ret = hooks.old
        end
    end
    self.hooks = {}
    if self.localhooks then
        for _, set in ipairs(self.localhooks) do
            getsetManual(self, set[1], set[0]) -- reset to old function
        end
    end
    -- we don't actually reset hookManager.requires since it would be too costly to rerequire and would break other mods
    le_utils.sourceCache = {}
end

local serialize = modHandler.requireFromPlugin("libraries.serialize")

local function doHook(_self, sourceDef, hook)
    if not hook.new then
        local _, target, name = decomposeFromPackage(sourceDef)
        local wrappers = sortByKeys(hook.sources)
        hook.old = target[name]
        hook.callStack = {
            [0] = hook.old
        }
        for i = 1, #wrappers, 1 do
            hook.callStack[i] = function(...)
                return wrappers[i](hook.callStack[i-1], ...)
            end
        end
        -- incredibly sad. i was going to xpcall this to handle errors so that the Hook Manager has good error handling
        -- but that wasted 8 hours of my life trying to debug luaJIT
        hook.new = hook.callStack[#wrappers]
        target[name] = hook.new
    end
end

local orig = ui_device.initializeDevice
function hookManager:applyHooks()
    logging.info("Loenn Hook Manager: applying hooks")
    if self.localhooks then
        for _, set in ipairs(self.localhooks) do
            getsetManual(self, set[1], set[2]) -- set to new function
        end
    end
    for sourceDef, hook in pairs(self.hooks) do
        doHook(self, sourceDef, hook)
    end
    if orig then 
        ui_device.initializeDevice = orig
        orig = nil
    end
    -- edge case
    if self.hooks["ui.windows.selection_context_window|createContextMenu"] then 
        debug.setupvalue(require('ui.windows').windows["selection_context_window"].editorSelectionContextMenu, 1, require('ui.windows.selection_context_window'))
    end    
end
local customHotkeys = modHandler.requireFromPlugin('libraries.hotkeys')

local drawing = require('utils.drawing')
-- rather than applying the hooks manually, we'll just add the implementations ourselves immediately
function hookManager:applyInternalHooks()

    local function loadInternalHook(hm, key, prio, old, func)
        if hm.hooks[key] then hm.hooks[key].sources[prio] = func
        else
            hm.hooks[key] = {
                old = old,
                sources = { [prio] = func }
            }
        end
        doHook(hm, key, hm.hooks[key])
    end
    -- the max value for a hook priority (latest) is used for wrappers, and the min value for a hook priority (earliest) is used for replacers
    loadInternalHook(self, "debug_utils|reloadEverything", justBelow + 1, debugUtils.reloadEverything, function(orig)
        logging.info("Loenn Hook Manager - Unloading hooks")
        self:unloadHooks()
        orig()
        logging.info("Loenn Hook Manager - Reloading hooks")
        self:loadHooks()
        self:applyHooks()
        customHotkeys:reloadHotkeys()
    end)

    loadInternalHook(self, "scene_handler|sendEvent", -1, sceneHandler.sendEvent, function(orig, event, ...)
        local scene = sceneHandler.getCurrentScene()

        if not scene then
            return false
        else 
            if not scene[event] then
                return false
            end
        end

        return true, scene[event](scene, ...)
    end)

    local decalStruct = require('structs.decal')
    loadInternalHook(self, "structs.decal|decode", 10, decalStruct.decode, function(orig, data)
        local decal = orig(data)

        decal._editorLayer = data._editorLayer

        return decal
    end)
    loadInternalHook(self, "structs.decal|encode", 10, decalStruct.encode, function(orig, decal)
        local res = orig(decal)

        local layer = decal._editorLayer
        if layer and layer ~= 0 then
            res._editorLayer = layer
        end

        return res
    end)


    local orig_updater_startupUpdateCheck = updater.startupUpdateCheck
    updater.startupUpdateCheck = function()
        eventsAPI.triggerEvent("firstLoad")
        orig_updater_startupUpdateCheck()
        updater.startupUpdateCheck = orig_updater_startupUpdateCheck
    end
end

function debugUtils.reloadHooks()
    fonts[HOOKMANAGERNAME]:unloadHooks()
    fonts[HOOKMANAGERNAME]:loadHooks()
    fonts[HOOKMANAGERNAME]:applyInternalHooks()
    fonts[HOOKMANAGERNAME]:applyHooks()
end

function hookManager:loadUtilities()
    local internal, external = le_utils.findPluginsYieldSafe(nil, "extended")
    local modName = HOOKMANAGERNAME
    for _, filename in ipairs(internal) do
        local pathNoExt = utils.stripExtension(filename)
        if pathNoExt:match("reload_persistent_data$") then
            local valid, table = le_utils.tryRequireWithReload(pathNoExt)
            if valid then
                self.persistentTable[HOOKMANAGERNAME] = table
            else
                logging.error(string.format("LoennExtended - persistent table for mod `%s` failed to load!", modName))
            end
        elseif pathNoExt:match("hotkeys$") then
            local valid, table = le_utils.tryRequireWithReload(pathNoExt)
            if valid then 
                customHotkeys:loadHotkey(table, modName)
            else
                logging.error(string.format("LoennExtended - hotkeys for mod `%s` failed to load!", modName))
            end
        end
    end
    for _, filename in ipairs(external) do
        local pathNoExt = utils.stripExtension(filename)
        if pathNoExt:match("reload_persistent_data$") then
            local valid, table = le_utils.tryRequireWithReload(pathNoExt)
            if valid then
                self.persistentTable[HOOKMANAGERNAME] = table
            else
                logging.error(string.format("LoennExtended - persistent table for mod `%s` failed to load!", modName))
            end    
        elseif pathNoExt:match("hotkeys$") then
            modName = filename:match("^$(.+)$/Loenn/.+")
            if modName and modHandler.modMetadata[modName].Name then
                modName = modHandler.modMetadata[modName].Name
                local valid, table = le_utils.tryRequireWithReload(pathNoExt)
                if valid then 
                    customHotkeys:loadHotkey(table, modName)
                else
                    logging.error(string.format("LoennExtended - hotkeys for mod `%s` failed to load!", modName))
                end
            else
                logging.error(string.format("LoennExtended - attempted to load hotkeys at file `%s` but mod name was not findable.", filename))
            end
        end
    end
end


logging.info("Loenn Hook Manager - Loading hooks")
fonts[HOOKMANAGERNAME].persistentTable = {} -- this needs to go first, just in case.
fonts[HOOKMANAGERNAME]:loadHooks()
--fonts[HOOKMANAGERNAME]:applyInternalHooks()
--fonts[HOOKMANAGERNAME]:loadUtilities()
local orig_ui_device_initializeDevice = ui_device.initializeDevice
ui_device.initializeDevice = function()
    orig_ui_device_initializeDevice()
    fonts[HOOKMANAGERNAME]:applyHooks()
    local flagTrigger = triggers.registeredTriggers["everest/flagTrigger"]
    flagTrigger.triggerText = function (room, trigger)
        if trigger.state then
            return trigger.flag
        else
            return "!" .. trigger.flag
        end
    end
end


return fakeScene