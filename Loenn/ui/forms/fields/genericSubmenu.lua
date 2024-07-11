local forms = require('ui.forms.form')
local utils = require("utils")
local widgetUtils = require("ui.widgets.utils")
local configs = require("configs")

local 

local submenu = {}
local submenu.fieldType = "lonnExt_submenu"

submenu._MT = {}
submenu._MT.__index = {}

local invalidStyle = {
    normalBorder = {0.65, 0.2, 0.2, 0.9, 2.0},
    focusedBorder = {0.9, 0.2, 0.2, 1.0, 2.0}
}
local function defaultShowMenu(customButton)
    return function(self, x, y, button, istouch)
        local menuButton = customButton or configs.editor.contextMenuButton

        return button == menuButton
    end
end


function submenu.getElement(name, value, options)

    local formField = {}

    local language = languageRegistry.getLanguage()
    local buttonText = options.displayButtonText or string.format(language.ui.LoennExtended.submenu.edit)


    local label = uiElements.label(options.displayName or name)
    local buttonElement = uiElements.button(buttonText, function(self, x, y, button) end):hook({
        onRelease = function(orig, self, x, y, button, istouch)
            local shouldShowMenu = options.shouldShowMenu or defaultShowMenu(options.contextButton)
            if shouldShowMenu(self, x, y, button, istouch) then
                if formField._form._hiddenFields then 
                    local hiddenFields = {}
                    for i = 1, #options.affectedFields, 1 do 
                        hiddenFields[i] = formField._form._hiddenFields[options.affectedFields[i]]
                    end
                    local bodyConstructionOptions = utils.deepcopy(formField._form.__constructionOptions)
                    bodyConstructionOptions.hidden = nil
                    local widget
                    if options.trueFieldType then 
                        widget = forms.registeredSubmenus[options.trueFieldType](hiddenFields, bodyConstructionOptions, options)
                    else
                        widget = genericSubmenuWidget.getWidget(hiddenFields, bodyConstructionOptions, options)
                    end
                    options.mode = options.mode or "focused"
                    contextMenuHandler.showContextMenu(widget, options)
                    return
                end
            end
            orig(self, x, y, button, istouch)
        end
    })
    local minWidth = options.minWidth or options.width or 160
    local maxWidth = options.maxWidth or options.width or 160

    buttonElement:with({
        minWidth = minWidth,
        maxWidth = maxWidth
    })
    options.mode = "focused"

    label.centerVertically = true

    formField.label = label
    formField.field = buttonElement
    formField.name = options.passback and name or nil -- nil this so that during savechangescallback, this formField is ignored.
    formField.initialValue = value
    formField.currentValue = value
    formField.width = 2
    formField.elements = {
        label, buttonElement
    }
    return setmetatable(formField, submenu._MT)
end


