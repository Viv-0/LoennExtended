
local forms = require('ui.forms.form')
local leutils = require('mods').requireFromPlugin('libraries.utils')
local gridElement = require("ui.widgets.grid")

if not forms.registeredSubmenus then 
    forms.registeredSubmenus = {}
end

local submenuHelper = {}

--- Registers a submenu with the submenu database
--- See the Wiki for more info on submenus
---@param fieldType string # unique string id for your fieldType
---@param getWidget function(fieldForms, bodyConstructionOptions, parentFieldOptions) -> widget # the function that constructs the widget from the information in the dummyData
---                                                 Not tied to a form field, since this is itself a "mini form"
function submenuHelper.registerSubmenu(fieldType, getWidget)
    forms.registeredSubmenus[fieldType] = getWidget
end

function submenuHelper.getFormFieldsGrid(formFields, bodyConstructionOptions)
    local columnCount = options.columns or 4
    local elements = {}
    local column = 1
    local rows = 0

    for _, field in ipairs(formFields) do
        local fieldWidth = field.width or 1
        -- we already have the filtered formfields passed to this function, so there's no need to use the hidden attribute
        if column + fieldWidth - 1 > columnCount then
            -- False gives us a blank grid cell
            for i = column, columnCount do
                table.insert(elements, false)
            end

            column = 1
            rows += 1
        end

        for _, element in ipairs(field.elements) do
            table.insert(elements, element)

            column += 1
        end
    end
    
    return gridElement.getGrid(elements, columnCount)
end

submenuHelper.getFormBodyGroups = forms.getFormBodyGroups

return submenuHelper