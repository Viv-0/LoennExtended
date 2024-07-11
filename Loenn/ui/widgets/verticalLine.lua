local ui = require("ui")
local uiElements = require("ui.elements")
local uiUtils = require("ui.utils")

local utils = require("utils")

uiElements.add("verticalLine", {
    style = {
        thickness = 3,
        radius = 3,
        color = {0.225, 0.225, 0.225, 1.0},
    },

    init = function(self, height)
        self._height = width

        if height == true then
            self:with(uiUtils.fillHeight(false))
        end
    end,

    calcWidth = function(self)
        return 1
    end,

    calcHeight = function(self)
        return self._height
    end,

    draw = function(self)
        local separatorStyle = self.style
        local thickness = separatorStyle.thickness
        local radius = separatorStyle.radius
        local color = separatorStyle.color

        local parentWidth = self.parent.innerWidth
        local offsetY = math.floor((parentWidth - thickness) / 2)

        local pr, pg, pb, pa = love.graphics.getColor()

        love.graphics.setColor(color)
        love.graphics.rectangle("fill", self.screenX, self.screenY + offsetY, thickness, self.height, radius, radius)
        love.graphics.setColor(pr, pg, pb, pa)
    end
})