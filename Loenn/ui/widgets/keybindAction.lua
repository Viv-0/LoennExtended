local uiElements = require("ui.elements")
local uiUtils = require('ui.utils')
local languageRegistry = require("language_registry")
local utils = require("utils")
local widgetUtils = require("ui.widgets.utils")
local keyboardHelper = require('utils.keyboard')

local keybindActionWidget = {}
local keysPressed = $({})
local resultingKeyString = ""

local function passback(self)

    

    self.parent:removeSelf()
end

local function update(orig, self, dt) 
    orig(self, dt)

    resultingKeyString = ""

    local counter = 0
    for k,v in pairs(keysPressed) do 
        resultingKeyString = 
        v = v - dt 
        if v <= 0 then
            keysPressed[k] = nil
        else
            counter = counter + 1 -- optimization over countKeys
        end
    end

    resultingKeyString = ""

    if not (self.hovering or self.focusing) or 
       (counter > 0 and resultingKeyString) then
        passback(self)
    end
end 

function keybindActionWidget.startKeybind()

    local group = uiElements.group({})
    group.interactive = 1
    group.width, group.height = love.graphics.getDimensions()
    group:hook({update = update})
    function group:draw()
        local pr, pg, pb, pa = love.graphics.getColor()

        love.graphics.setColor(0,0,0,0.6)
        love.graphics.rectangle(0,0, self.width, self.height)
        love.graphics.setColor(1,1,1,1)
        love.graphics.printf("Input a keybind:\n\n" .. resultingKeyString, self.width*0.5, self.height * 0.5, self.width, "center", 0, 5, 5)
    
        love.graphics.setColor(pr, pg, pb, pa)
    end

    group.onKeyPress = function(self, key, scancode, isrepeat) 
        keysPressed[scancode] = 0.08333
    end,
    

    return image
end