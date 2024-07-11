--[[
    Handles Color coding triggers, font size and text color, and preserves legacy custom display text
    handles the "getDrawable" case, used in rendering the trigger for placementUtils (aka before you place the trigger)
]]

local version = require('utils.version_parser')
local triggers = require('triggers')
local utils = require('utils')
local colors = require("consts.colors")
local drawableFunction = require('structs.drawable_function')
local drawing = require('utils.drawing')
local layerHandlers = require('layer_handlers')
local form = require('ui.forms.form')
local selectionContextWindow = require('ui.windows.selection_context_window')

-- Loenn Extended references
local mods = require('mods')
local loennExtended_settings = mods.requireFromPlugin("libraries.settings")
local loennExtended_layerAPI = mods.requireFromPlugin("libraries.api.layers")
local loennExtended_triggerAPI = mods.requireFromPlugin("libraries.api.triggerRendering")
local loennExtended_textAPI = mods.requireFromPlugin("libraries.api.textRendering")
local colorPickerModifier = mods.requireFromPlugin('libraries.modifyColorPicker')

local editorColorFieldInfo = {
    fieldType = "color",
    allowXNAColors = true,
    displayName = "Editor Color",
    tooltipText = "The color to use when rendering this trigger in-editor.\nAdded by Loenn Extended"
}

local editorLayerFieldInfo = {
    fieldType = "integer",
    displayName = "Editor Layer",
    tooltipText = "The layer in which this entity is in-editor.\nAdded by Loenn Extended"
}

local testFieldInfo = {
    fieldType = "test_submenu",
    displayName = "Test",
    affectedFields = {"test2"}
}

local hooks = {
    ["triggers|getDrawable"] = {
        version = "0.7.10",
        priority = 0,
        new = function(orig, name, _handler, room, trigger, viewport)
            handler = triggers.registeredTriggers[trigger._name]
            local bg = loennExtended_triggerAPI.getTriggerDrawableBg(trigger, room, handler)

            local bgFunc = bg.func
            bg.func = function ()
                bgFunc()
                local x = trigger.x or 0
                local y = trigger.y or 0

                local width = trigger.width or 16
                local height = trigger.height or 16
                
                local displayName = loennExtended_triggerAPI.getDisplayText(trigger, room, handler)
                local fontSize = loennExtended_triggerAPI.getFontSize(trigger, room, handler)
                local textColor = loennExtended_triggerAPI.getTextColor(trigger, room, handler, false)

                loennExtended_textAPI.printCenteredText(displayName, x, y, width, height, font, fontSize, textColor)
            end

            return bg, 0
        end
    },
    ["triggers|addDrawables"] = {
        version = "0.7.10",
        priority = 0,
        new = function(orig, batch, room, targets, viewport, yieldRate)
            local font = love.graphics.getFont()

            -- Add rectangles first, then batch draw all text

            for i, trigger in ipairs(targets) do
                batch:addFromDrawable(loennExtended_triggerAPI.getTriggerDrawableBg(trigger, room))

                if i % yieldRate == 0 then
                    coroutine.yield(batch)
                end
            end

            local textBatch = love.graphics.newText(font)

            for i, trigger in ipairs(targets) do
                local handler = triggers.registeredTriggers[trigger._name]
                local displayName = loennExtended_triggerAPI.getDisplayText(trigger, room, handler)
                local fontSize =  loennExtended_triggerAPI.getFontSize(trigger, room, handler)

                local x = trigger.x or 0
                local y = trigger.y or 0

                local width = trigger.width or 16
                local height = trigger.height or 16

                local color = loennExtended_triggerAPI.getTextColor(trigger, room, handler)
                loennExtended_textAPI.addCenteredText(textBatch, displayName, x, y, width, height, font, fontSize, nil, color)
            end

            local function func()
                drawing.callKeepOriginalColor(function()
                    love.graphics.setColor(colors.triggerTextColor)
                    love.graphics.draw(textBatch)
                end)
            end

            batch:addFromDrawable(drawableFunction.fromFunction(func))

            return batch
        end
    },
    ["ui.widgets.color_picker|getColorPicker"] = {
        version = "0.7.10",
        priority = 2147483647,
        new = colorPickerModifier
    }
}

-- replaced the hook of prepareFormData with this extension because we unwrapped the one use case that hook had further down

local injectData
if require("mods").requireFromPlugin("libraries.settings").enabled() then
    injectData = function(dummyData, fieldInformation, fieldOrder)
        local hiddenFields = {}
        local buttons = {}
        if fieldOrder and fieldInformation and form.registeredSubmenus then 
            for k,v in pairs(fieldInformation) do
                if form.registeredSubmenus[v.fieldType] then 
                    for _,w in ipairs(utils.callIfFunction(v.affectedFields, data)) do 
                        hiddenFields[#hiddenFields+1] = w
                    end
                    if v.bottomButton then 
                        buttons[#buttons+1] = utils.callIfFunction(v.bottomButton, data)
                        hiddenFields[#hiddenFields+1] = v
                    end
                    v.trueFieldType = v.fieldType
                    v.fieldType = "lonnExt_submenu"
                end
            end
        else
            fieldOrder = fieldOrder or {}
            fieldInformation = fieldInformation or {}
        end
        local insertIndex = 3
        if dummyData.width then insertIndex += 1 end
        if dummyData.height then insertIndex += 1 end
    
        if dummyData._editorLayer then
            table.insert(fieldOrder, insertIndex, "_editorLayer")
            fieldInformation._editorLayer = editorLayerFieldInfo
        end
    
        if dummyData._editorColor then
            table.insert(fieldOrder, insertIndex, "_editorColor")
            fieldInformation._editorColor = editorColorFieldInfo
        end

        table.insert(fieldOrder, insertIndex, "test1")
        fieldInformation.test1 = testFieldInfo
    
        return dummyData, fieldInformation, fieldOrder, hiddenFields, buttons
    end
else
    injectData = function(dummyData, fieldInformation, fieldOrder)
        local hiddenFields = {}
        local buttons = {}
        if fieldOrder and fieldInformation and form.registeredSubmenus then 
            for k,v in pairs(fieldInformation) do
                if form.registeredSubmenus[v.fieldType] then 
                    for _,w in ipairs(utils.callIfFunction(v.affectedFields, data)) do 
                        hiddenFields[#hiddenFields+1] = w
                    end
                    if v.bottomButton then 
                        buttons[#buttons+1] = utils.callIfFunction(v.bottomButton, data)
                        hiddenFields[#hiddenFields+1] = v
                    end
                    v.trueFieldType = v.fieldType
                    v.fieldType = "lonnExt_submenu"
                end
            end
        end
        return dummyData, fieldInformation, fieldOrder, hiddenFields, buttons
    end
end

local _,findCompatSelections = debug.getupvalue(selectionContextWindow.createContextMenu, 2)
local _,getWinTitle = debug.getupvalue(selectionContextWindow.createContextMenu, 6)
local windows = require('ui.windows')
local windowPersister = require("ui.window_position_persister")
local windowPersisterName = "selection_context_window"
local widgetUtils = require("ui.widgets.utils")
local languageRegistry = require('language_registry')
local formUtils = require('ui.utils.forms')
local contextWindow = require('ui.windows.selection_context_window')
local uiElements = require('ui.elements')
-- This is a large number of edits in a short rewrite:
-- first, unroll local function prepareFormData - we need `handler.getHandler` early
hooks['ui.windows.selection_context_window|createContextMenu'] = {
    version = "0.7.10",
    priority = 0,
    new = function(orig, selections, bestSelection)
        local language = languageRegistry.getLanguage()


        -- Filter out selections that would end up making a mess
        selections = findCompatSelections(selections, bestSelection)
    
        if #selections == 0 then
            return
        end
        
        local item = bestSelection.item
        local layer = bestSelection.layer

        local layerhandler = layerHandlers.getHandler(layer)
    
        -- unroll local function prepareFormData
        local options = {}

        -- Decals have a simpler path than the default for entities/trigger
        if layer == "decalsFg" or layer == "decalsBg" then
            options.namePath = {"attribute"}
            options.tooltipPath = {"description"}
        end

        options.multiple = #selections > 1

        local dummyData, fieldInformation, fieldOrder, _hidden, addedButtons = injectData(formUtils.prepareFormData(layerhandler, item, options, {layer, item}))
    
        -- Window would be empty, nothing to show
        if utils.countKeys(dummyData) == 0 then 
            return
        end
    
        local buttons = {
            {
                text = tostring(language.ui.selection_context_window.save_changes),
                formMustBeValid = true,
                callback = contextWindow.saveChangesCallback(selections, dummyData)
            },
        }
        for i = 1, #addedButtons, 1 do 
            local v = addedButtons[i]
            if v.__type == "button" then 
                buttons[1+i] = {text = v.label.text, callback = v.cb} -- the label.text here is just to handle the label length so we don't need to reflow ?
            elseif v.text and v.callback then 
                buttons[1+i] = v 
            end
        end
    
        local windowTitle = getWinTitle(language, selections, bestSelection)
        local selectionForm, formFields = form.getForm(buttons, dummyData, {
            fields = fieldInformation,
            fieldOrder = fieldOrder,
            fieldMetadata = {
                formData = dummyData,
                selections = selections,
            },
            hidden = _hidden
        })
        local hidden = table.flip(_hidden)
        selectionForm.__constructionOptions = formFields._options
        selectionForm.hiddenFields = {}
        for _,field in ipairs(formFields) do 
            if hidden[field.name] then
                selectionForm._hiddenFields[field.name] = field
            else
                field._form = selectionForm
            end
        end

        local window = uiElements.window(windowTitle, selectionForm)
        local windowCloseCallback = windowPersister.getWindowCloseCallback(windowPersisterName)
    
        windowPersister.trackWindow(windowPersisterName, window)
        windows.windows[windowPersisterName].parent:addChild(window)
        widgetUtils.addWindowCloseButton(window, windowCloseCallback)
        form.prepareScrollableWindow(window)
        form.addTitleChangeHandler(window, windowTitle, formFields)
    
        return window
    end
}

return hooks