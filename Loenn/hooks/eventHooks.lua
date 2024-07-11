--[[
    This hook handles a number of different finalizer things applied to it.
    1. Enables handler.le_finalizePlacement(trigger, room) to trigger on placeItem if it exists
    2. Enables events to override placement finalization
    3. Does all the hooks previously in LoennExtended
]]

local version = require('utils.version_parser')
local triggers = require('triggers')
local utils = require('utils')
local colors = require("consts.colors")
local drawableFunction = require('structs.drawable_function')
local drawing = require('utils.drawing')
local layerHandlers = require('layer_handlers')
local placementUtils = require('placement_utils')
local form = require('ui.forms.form')
local selectionUtils = require('selections')
local loadedState = require('loaded_state')
local layerHandlers = require('layer_handlers')
-- Loenn Extended references
local mods = require('mods')
local events = mods.requireFromPlugin('libraries.api.events')
local layersAPI = mods.requireFromPlugin('libraries.api.layers')

local LOENNEXTENDED_OVERRIDEHISTORY = false

local hooks = {
--||||||||||||||||||||||||||||||||     Handles placeItem events, and finalizer info        |||||||||||||||||||||||||||||||||||||
    ["placement_utils|placeItem"] = {
        version = "0.7.10",
        priority = 0,
        new = function(orig, room, layer, item)
            local layerHandler = layerHandlers.getHandler(layer)

            if layerHandler and layerHandler.placeItem then
                local itemHandler = layerHandler.getHandler(item)
                local valid = events.triggerEvent("placeItem", room, layer, item, itemHandler) or true
                if not valid then
                    LOENNEXTENDED_OVERRIDEHISTORY = true
                    return
                end
                placementUtils.finalizePlacement(room, layer, item)
                
                if layer == "triggers" and not item._editorColor then
                    item._editorColor = "265B50"
                end
                if not item._editorLayer then
                    item._editorLayer = layersAPI.getCurrentLayer()
                end
                if itemHandler and itemHandler.lonnExt_finalizePlacement then
                    itemHandler.lonnExt_finalizePlacement(room, layer, item)
                end
                return layerHandler.placeItem(room, layer, item)
            end
            print("Failed to place Item")

            return false
        end
    },
    -- handle LOENNEXTENDED_OVERRIDEHISTORY magic
    -- unset the global variable in snapshotUtils
    ["snapshot_utils|roomLayersSnapshot"] = {
        version = "0.7.10",
        priority = 0,
        new = function(orig, callback, room, layer, description)
            if LOENNEXTENDED_OVERRIDEHISTORY then
                LOENNEXTENDED_OVERRIDEHISTORY = false
                return nil
            end
            return orig(callback, room, layer, description)
        end
    },
    -- ensure the nil snapshot isn't added to history
    ["history|addSnapshot"] = {
        version = "0.7.10",
        priority = 0,
        new = function(orig, snapshot)
            LOENNEXTENDED_OVERRIDEHISTORY = false -- we ensure that this only happens 1 time
            if snapshot then 
                orig(snapshot)
            end
        end
    }
}

local function getFormData(formFields) 
    local data = {}
    local fields = {}

    for _, field in ipairs(formFields) do
        if field.name then
            fields[field.name] = field
            local nameParts = form.getNameParts(field.name, formFields._options)

            utils.setPath(data, nameParts, field:getValue(), true)
        end
    end

    return data, fields
end

--  ||||||||||||||||||||||||||||||||     Handles selection context menu callback (saveChanges)       |||||||||||||||||||||||||||||||||||||
hooks["ui.windows.selection_context_window|saveChangesCallback"] = {
    version = "0.7.10",
    priority = 0,
    new = function(orig, selections, dummyData)
        return function(formFields)
            local redraw = {}
            -- edit: rather than using getFormData, we're going to use a homebrewed getFormData that passes back a keyed list of formFields to reduce loop duplication
            local newData, ff = getFormData(formFields)
            local room = loadedState.getSelectedRoom()

            if events.triggerEvent("saveChanges", selections, dummyData, formFields, newData, room) == false then return end
    
            for _, selection in ipairs(selections) do
                local layer = selection.layer
                local item = selection.item
    
                -- Apply nil values from new data
                for k, v in pairs(dummyData) do
                    if newData[k] == nil then
                        if ff[k]._options.lonnExt_onSaveChanges then 
                            ff[k]._options.lonnExt_onSaveChanges(item, k, item[k], nil)
                        end
                        item[k] = nil
                    end
                end
    
                for k, v in pairs(newData) do
                    if ff[k]._options.lonnExt_onSaveChanges then 
                        ff[k]._options.lonnExt_onSaveChanges(item, k, item[k], v)
                    end
                    item[k] = v
                end
            end
    
            if room then
                selectionUtils.updateSelectionRectangles(room, selections)
                selectionUtils.redrawTargetLayers(room, selections)
            end
        end
    end
}

return hooks