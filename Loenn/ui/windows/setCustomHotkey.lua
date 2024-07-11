local uiElements = require("ui.elements")
local uiUtils = require('ui.utils')
local languageRegistry = require("language_registry")
local utils = require("utils")
local widgetUtils = require("ui.widgets.utils")
local form = require("ui.forms.form")
local extSettings = require("mods").requireFromPlugin("libraries.settings")
local captureHotkey = require('ui.forms.fields.keyboard_hotkey')
local stringField
-- this code allows for eof override without a goto
if true then 
    return {}
end
-- TO-DO: Finish code, support other languages

local myWindow = {}

local activeWindows = {}
local windowPreviousX = 0
local windowPreviousY = 0

local contextGroup

local function contextWindowUpdate(orig, self, dt)
    orig(self, dt)
    windowPreviousX = self.x
    windowPreviousY = self.y
end
local function removeWindow(window)
    for i, w in ipairs(activeWindows) do
        if w == window then
            table.remove(activeWindows, i)
            widgetUtils.focusMainEditor()

            break
        end
    end

    window:removeSelf()
end

local activeAction = nil

local fieldOrderGroups = {
    {
        title = "Editor",
        fieldOrder = {
            "Action", "E1", "E2"
        }
    },{
        title = "Stylegrounds"
    }
}

local function openAction(toOpen)
    activeAction = toOpen or false
    local startRow = uiElements.row({ uiElements.column({
        captureHotkey.getElement("Keybind", activeAction.keybind or "").elements
    }), uiElements.column({
        stringField.getElement("Name (ID)", activeAction.name or "").elements
        uiElements.label("Name ID"),
        uiElements.field(activeAction.name or "", function(element, new, old)
            activeAction.name = new
        end)
    })})


    
    contextGroup.__window.inner[2] = column
    contextGroup.__window:reflow()
end

local function saveAction()
    -- do shit
    activeAction = nil
end

function myWindow.createContextMenu()
    local window
    local windowX = windowPreviousX
    local windowY = windowPreviousY
    local language = languageRegistry.getLanguage()

    -- Don't stack windows on top of each other
    if #activeWindows > 0 then
        windowX, windowY = 0, 0
    end

    local windowTitle = "Editing Quick Actions"
    
    local quickActions = extSettings.getPersistence().quickActions
    local existingActions = {}
    for k,v in pairs(quickActions) do 
        if not v.keybind then v.keybind = k end
        existingActions[#existingActions+1] = {v.name or (k .. " (unnamed)"), v}
    end
    local dropdown = uiElements.dropdown(existingActions, function(element, selected)
        openAction(selected)
    end):with({minWidth = 160, maxWidth = 160})

    local buttonRow = uiElements.row({
        uiElements.button("New Action", openAction),
        dropdown,
        uiElements.button("Save Changes", saveAction)
    }):with(uiUtils.topbound):with(uiUtils.fillWidth)
    local selectionForm = uiElements.column({
        buttonRow,
        uiElements.column({})
    })


    window = uiElements.window(windowTitle, selectionForm):with({
        x = windowX,
        y = windowY,
        minWidth = 520

        updateHidden = true
    }):hook({
        update = contextWindowUpdate
    })
    table.insert(activeWindows, window)

    windowPersister.trackWindow("custom_hotkey_window", window)
    contextGroup.parent:addChild(window)
    contextGroup.__window = window
    widgetUtils.addWindowCloseButton(window)

    return window
end

function myWindow.getWindow()
    contextGroup = uiElements.group({})
    return contextGroup
end