local submenuHelper = require('mods').requireFromPlugin('libraries.api.submenu')

local submenuWidget = {}

-- In practice, the hidden Fields we receive from this should be turned into a grid of elements from formFields via forms.getFormBodyGrid except we ignore the hidden attribute
-- They also get correct updating procedures, since the formFields are actually in the group of formFields just not rendered by the form Body
function submenuWidget.getWidget(formFields, bodyConstructionOptions, parentFieldOptions)
    return submenuHelper.getFormFieldsGrid(formFields, bodyConstructionOptions)
end