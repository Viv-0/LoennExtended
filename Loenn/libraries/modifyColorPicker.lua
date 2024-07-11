local filesystem = require('utils.filesystem')
local checkerboard = love.graphics.newImage(string.format("%s/Graphics/Editor/checkerboard.png", require('mods').commonModContent))
local uiElements = require("ui.elements")
local uiUtils = require("ui.utils")
local utils = require("utils")
local formHelper = require("ui.forms.form")

local alphaShader = love.graphics.newShader[[
    vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc)
    {
        return mix(vec4(Texel(tex, tc).rgb, 1), color, tc[0]);
    }
]]

local function alphaInteraction(interactionData)
    return function(widget,x,y)
        local areaSize = interactionData.areaSize
        local formFields = interactionData.formFields

        local innerX = utils.clamp(x - widget.screenX, 0, areaSize)
        local alpha = innerX / areaSize
        local data = formHelper.getFormData(formFields)

        data.alpha = math.floor(alpha * 255)
        interactionData.forceFieldUpdate = true
        formHelper.setFormData(formFields,data)
    end
end

local function alphaSliderDraw(interactionData)
    return function(orig, widget)
        local previousShader = love.graphics.getShader()
        local pr,pg,pb,pa = love.graphics.getColor()
        love.graphics.setShader(alphaShader)
        local formData = formHelper.getFormData(interactionData.formFields)
        local r, g, b = formData.r or 0, formData.g or 0, formData.b or 0
        love.graphics.setColor(r/255,g/255,b/255,1)
        orig(widget)
        love.graphics.setColor(pr,pg,pb,pa)
        love.graphics.setShader(previousShader)

        local formData = formHelper.getFormData(interactionData.formFields)
        local areaSize = interactionData.areaSize
        local sliderHeight = interactionData.sliderWidth
        local x = utils.round((formData.alpha or 0) / 255 * areaSize)
        local widgetX, widgetY = widget.screenX, widget.screenY
        local sliderX = widgetX + x
        local width, height = widget.width, widget.height
        pr, pg, pb, pa = love.graphics.getColor()
        local previousLineWidth = love.graphics.getLineWidth()

        love.graphics.setLineWidth(1)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.rectangle("fill", sliderX - 1,widgetY, 3, sliderHeight)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", sliderX, widgetY + 1, 1, sliderHeight - 2)
        love.graphics.setLineWidth(previousLineWidth)
        love.graphics.setColor(pr, pg, pb, pa)
    end
end

return function(orig, hexColor, options) 
    local pickerRow = orig(hexColor, options)
    if not options.showAlpha and not options.useAlpha then return pickerRow end
    

    local areaElement = pickerRow.children[1]

    local _, interactionData = debug.getupvalue(areaElement.onClick, 1) -- nasty
    
    local alphaSlider = uiElements.image("ui:icons/drop"):with({
        interactive = 1,
        onDrag = alphaInteraction(interactionData),
        onClick = alphaInteraction(interactionData)
    }):hook({
        draw = alphaSliderDraw(interactionData)
    })
    alphaSlider._image = checkerboard
    alphaSlider.quad = love.graphics.newQuad(0,0,interactionData.areaSize, interactionData.sliderWidth, checkerboard:getPixelWidth() / 2, checkerboard:getPixelHeight() / 2)


    pickerRow.children[1] = uiElements.column({
        areaElement,
        alphaSlider 
    }):with({
        cacheable = false
    })

    return pickerRow
end
