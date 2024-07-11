local ui = require("ui")
local uiElements = require("ui.elements")
local uiUtils = require("ui.utils")
local contextMenu = require("ui.context_menu")
local utils = require("utils")
local colorPicker = require("ui.widgets.color_picker")
local configs = require("configs")
local xnaColors = require("consts.xna_colors")

local mods = require('mods')
local reloadSafeTable = mods.requireFromPlugin("libraries.api.reloadPersistence").getReloadPersistentTable()
reloadSafeTable.rainbowButtonCache = reloadSafeTable.rainbowButtonCache or {}

local colorListField = {}

colorListField.fieldType = "lonnExt_colorList"

local function getRainbowButton(length) 
    if reloadSafeTable.rainbowButtonCache[length] then return reloadSafeTable.rainbowButtonCache[length] end
    local canvas = love.graphics.newCanvas(length, length)
    local imageData = canvas:newImageData()

    imageData:mapPixel(function(x,y,r,g,b,a)
        if x == 0 or x == length or y == 0 or y == length then
            return 0,0,0,1
        elseif x == 1 or x == length - 1 or y == 1 or y == length - 1 then
            return 1,1,1,1
        end
        local c = length / 2
        local hue = 57.2957795 * math.atan2(y-c,x-c)
        local cr, cg, cb = utils.hsvToRgb(hue, 1, 1)
        return cr, cg, cb, 1
    end,0,0,length,length)

    local image = love.graphics.newImage(imageData)

    reloadSafeTable.rainbowButtonCache[length] = image

    return image
end

colorListField._MT = {}
colorListField._MT.__index = {}

local fallback = "ffffff"

local invalidStyle = {
    normalBorder = {0.65, 0.2, 0.2, 0.9, 2.0},
    focusedBorder = {0.9, 0.2, 0.2, 1.0, 2.0}
}

function colorListField._MT.__index:setValue(value)
    self.currentValue = value or fallback
    self.field:setText(self.currentValue)
    self.field.index = #self.currentValue
end

function colorListField._MT.__index:getValue()
    return self.currentValue or fallback
end

function colorListField._MT.__index:fieldValid(...)
    local current = self:getValue()

    local fieldEmpty = current == nil or #current == 0

    local colors = string.split(current, ",")._tbl

    local res = true

    for _,col in ipairs(col) do 
        local color = col
        if self.allowSpaces then
            color = utils.trim(col)
        end
        if fieldEmpty then
            res = res and self._allowEmpty
        elseif self._allowXNAColors then 
            local c = utils.getColor(color)
            res = res and (not not c)
        else
            local parsed = utils.parseHexColor(color)
            res = res and parsed
        end
        if not res then 
            return false
        end
    end
    return true
end

-- Return the hex color of the XNA name if allowed
-- Otherwise return the value as it is
local function getXNAColorHex(element, value)
    local fieldEmpty = value == nil or #value == 0

    if fieldEmpty and element._allowEmpty then
        return fallback
    end

    if element._allowXNAColors then
        local xnaColor = utils.getXNAColor(value or "")

        if xnaColor then
            return utils.rgbToHex(unpack(xnaColor))
        end
    end

    return value
end

local function cacheFieldPreviewColor(element, new)
    local parsed, r, g, b = utils.parseHexColor(getXNAColorHex(element, new))

    element._parsed = parsed
    element._r, element._g, element._b = r, g, b

    return parsed, r, g, b
end

local function fieldChanged(formField)
    return function(element, new, old)
        local parsed, r, g, b = cacheFieldPreviewColor(element, new)
        local wasValid = formField:fieldValid()
        local valid = parsed

        formField.currentValue = new

        if wasValid ~= valid then
            if valid then
                -- Reset to default
                formField.field.style = nil

            else
                formField.field.style = invalidStyle
            end

            formField.field:repaint()
        end

        formField:notifyFieldChanged()
    end
end

local function getColorPreviewArea(element)
    local x, y = element.screenX, element.screenY
    local width, height = element.width, element.height
    local padding = element.style:get("padding") or 0
    local previewSize = height - padding * 2
    local drawX, drawY = x + width - previewSize - padding, y + padding

    return drawX, drawY, previewSize
end

local function fieldDrawColorPreview(orig, element)
    orig(element)

    local parsed = element and element._parsed
    local r, g, b, a = element._r or 0, element._g or 0, element._b or 0, parsed and 1 or 0
    local pr, pg, pb, pa = love.graphics.getColor()

    local drawX, drawY, length = getColorPreviewArea(element)

    if not element._buttonImage then 
        element._buttonImage = getRainbowButton(length)
    end
    love.graphics.setColor(1,1,1)
    love.graphics.draw(element._buttonImage, drawX, drawY)
    love.graphics.setColor(pr,pg,pb,pa)
end

local function shouldShowMenu(element, x, y, button)
    local menuButton = configs.editor.contextMenuButton
    local actionButton = configs.editor.toolActionButton

    if button == menuButton then
        return true

    elseif button == actionButton then
        local drawX, drawY, length = getColorPreviewArea(element)

        return utils.aabbCheckInline(x, y, 1, 1, drawX, drawY, length, length)
    end

    return false
end

function colorListField.getElement(name, value, options)
    local formField = {}

    if type(value) == "number" then value = string.format("%06d", value) end

    local minWidth = options.minWidth or options.width or 160
    local maxWidth = options.maxWidth or options.width or 160
    local allowXNAColors = options.allowXNAColors
    local allowEmpty = options.allowEmpty

    local label = uiElements.label(options.displayName or name)
    local field = uiElements.field(value or fallback, fieldChanged(formField)):with({
        minWidth = minWidth,
        maxWidth = maxWidth,
        _allowXNAColors = allowXNAColors,
        _allowEmpty = allowEmpty
    }):hook({
        draw = fieldDrawColorPreview
    })
    local fieldWithContext = contextMenu.addContextMenu(
        field,
        function()
            local pickerOptions = {
                callback = function(data)
                    field:setText(data.resultString)
                    field.index = #data.resultString
                end,
                showAlpha = options.showAlpha or options.useAlpha,
                showHex = options.showHex,
                showHSV = options.showHSV,
                showRGB = options.showRGB,
            }

            local fieldText = getXNAColorHex(field, field:getText() or "")

            return colorListPicker.getColorPicker(fieldText, pickerOptions)
        end,
        {
            shouldShowMenu = shouldShowMenu,
            mode = "focused"
        }
    )

    cacheFieldPreviewColor(field, value or "")
    field:setPlaceholder(value)

    if options.tooltipText then
        label.interactive = 1
        label.tooltipText = options.tooltipText
    end

    label.centerVertically = true

    formField.label = label
    formField.field = field
    formField.name = name
    formField.initialValue = value
    formField.currentValue = value
    formField._allowXNAColors = allowXNAColors
    formField._allowEmpty = allowEmpty
    formField.width = 2
    formField.elements = {
        label, fieldWithContext
    }

    return setmetatable(formField, colorListField._MT)
end

return colorListField