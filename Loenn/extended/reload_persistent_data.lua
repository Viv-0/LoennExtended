local mods = require('mods')
local le_utils = mods.requireFromPlugin('libraries.utils')
local loennExtended_reloadPersistence = mods.requireFromPlugin('libraries.api.reloadPersistence')
local sceneHandler = require('scene_handler')
local input_device = require('input_device')

local layers = {
    layer = 0,
    any = true,
    layerDisplayAdded = false  
}
function layers:nextLayer(self, by)
    if not by then
        self.any = not self.any
    else
        self.any = false
        self.layer = self.layer + by
    end

    -- TODO: move somewhere more sane...
    if not self.layerDisplayAdded and sceneHandler and sceneHandler.currentScene == "Editor" then

        input_device.newInputDevice(
            sceneHandler.getCurrentScene().inputDevices,
            mods.requireFromPlugin("input_devices.layerDisplay")
        )
        self.layerDisplayAdded = true
    end
    -- replaces legacy: hotkeyRedraw
    le_utils.roomRedraw()
end

return {
    layers = layers
}