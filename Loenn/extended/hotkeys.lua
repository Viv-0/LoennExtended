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

    in this file, i use the { {activator, callback} } format
]]
local mods = require('mods')
local utils = require("utils")
local extSettings = mods.requireFromPlugin("libraries.settings")
local leUtils = mods.requireFromPlugin("libraries.utils")
local entityHandler = require("entities")
local decalHandler = require("decals")
local toolHandler = require("tools")
local hotkeyHandler = require("hotkey_handler")
local celesteRender = require("celeste_render")
local loadedState = require("loaded_state")
local selectionUtils = require("selections")
local placementUtils = require("placement_utils")
local decalStruct = require("structs.decal")

local layersAPI = mods.requireFromPlugin("libraries.api.layers")
local customHotkeys = mods.requireFromPlugin('libraries.hotkeys')

local placementAddWindow = require("mods").requireFromPlugin("ui.windows.quickActionPlacementAdd")
local chooseHotkeyWindow = require("mods").requireFromPlugin("ui.windows.quickActionChooseHotkey")
local notifications = require("ui.notification")

if not extSettings.enabled() then
    return {}
end

local hotkeys = {}

if extSettings.get("_enabled", true, "quickActions") then 
    local quickActionData = {}

    local actions = extSettings.getPersistence("quickActions", {})
    for key, value in pairs(actions) do
        if type(key) == "number" then
            actions[key] = nil
            actions[tostring(key)] = value
        end
    end

    function quickActionData.doAction(index)
        local action = actions[index]
        if action then
            toolHandler.selectTool(action.tool)
            toolHandler.setLayer(action.layer, action.tool)
            toolHandler.setMaterial(action.material, action.tool)
        end
    end
    local function getHotkeyHandler(index)
        return function()
            quickActionData.doAction(index)
        end
    end
    
    -- Attempt to prevent arbitrary code execution - from tools/selection.lua 
    local function validateClipboard(text)
        if not text or text:sub(1, 1) ~= "{" or text:sub(-1, -1) ~= "}" then
            return false
        end
    
        return true
    end
    
    local function guessPlacementType(item)
        return (item.width or item.height) and "rectangle" or "point"
    end

    local function addHotkey(key)
        if utils.isInteger(key) then 
            table.insert(hotkeys, activator = string.format("ctrl + %s", key), callback(getHotkeyHandler(key)))
        else
            table.insert(hotkeys, {activator = tostring(key), callback = getHotkeyHandler(key)})
        end
    end

    local function removeHotkey(index)
        customHotkeys:unloadHotkey(string.format("ctrl + %s", i))
    
        local persistence = extSettings.getPersistence()
        persistence.quickActions = persistence.quickActions or {}
        if persistence.quickActions[index] then
            persistence.quickActions[index] = nil
            extSettings.savePersistence()
            notifications.notify(string.format("Removed Quick Action %s", index))
        else
            notifications.notify(string.format("Quick Action %s already doesn't exist!", index))
        end
    end
    
    local function finalizeAddingHotkeyStep2(index, action)
        -- Register the hotkey if it's not yet registered
        if not actions[index] then
            addHotkey(index)
        end
    
        actions[index] = action
    
        notifications.notify(string.format("Added Quick Action %s", index))
    
        local persistence = extSettings.getPersistence()
        persistence.quickActions = persistence.quickActions or {}
        persistence.quickActions[index] = action
        extSettings.savePersistence()
    end
    
    local function finalizeAddingHotkey(index, action)
        if index == 0 then -- Ctrl+0 now allows you to pick any arbitrary key for the quick action.
            chooseHotkeyWindow.createContextMenu(index, function(hotkey, shouldRemove)
                hotkey = string.gsub(hotkey, " ", "") -- remove spaces
    
                if shouldRemove then
                    removeHotkey(hotkey)
                    return
                end
    
                finalizeAddingHotkeyStep2(hotkey, action)
            end)
            return
        end
    
        finalizeAddingHotkeyStep2(index, action)
    end
    
    local function getHotkeyCreationHandler(index)
        return function ()
            local toolName = toolHandler.currentToolName
            local action = {
                tool = toolName,
                layer = toolHandler.getLayer(toolName),
                material = toolHandler.getMaterial(toolName),
            }
    
            if toolName == "placement" or toolName == "selection" then
                -- placement and selection tools require special handling because of selection info/placement templates being local :(
                placementAddWindow.createContextMenu(index, function(fromClipboard)
                    if fromClipboard then
                        local clipboard = love.system.getClipboardText()
    
                        if validateClipboard(clipboard) then
                            local success, fromClipboard = utils.unserialize(clipboard, true, 3)
    
                            if success then
                                --print(utils.serialize(fromClipboard))
    
                                local placement = fromClipboard[1]
    
                                action.tool = "placement"
                                action.layer = placement.layer
                                action.material = {
                                    itemTemplate = placement.item,
                                    displayName = "<quickActionItem>",
                                    name = "<quickActionItem>",
                                    placementType = guessPlacementType(placement.item)
                                }
                            end
                        end
                    end
    
                    finalizeAddingHotkey(index, action)
                end)
            else
                finalizeAddingHotkey(index, action)
            end
        end
    end
end

if extSettings.get("_enabled", true, "layers") then 
    local layerData = mods.requireFromPlugin("libraries.api.reloadPersistence").getReloadPersistentTable().layers

    table.insert(hotkeys, {
        activator = extSettings.get("hotkeys_previousLayer", "shift + left", "layers"),
        callback = function() layerData.nextLayer(-1) end
    })
    table.insert(hotkeys, {
        activator = extSettings.get("hotkeys_nextLayer", "shift + right", "layers"),
        callback = function() layerData.nextLayer(1) end
    })
    table.insert(hotkeys, {
        activator = extSettings.get("hotkeys_viewAllLayers", "shift + down", "layers"),
        callback = function() layerData.nextLayer(nil) end
    })
end

return hotkeys

