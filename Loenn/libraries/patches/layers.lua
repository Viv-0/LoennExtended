--[[
    Adds support for Editor Layers - allows for putting entities/decals/triggers into many seperate layers to ease editing

    NOTE: This file is *extremely* hacky.
]]



local entities = require("entities")
local decals = require("decals")
local utils = require("utils")
local hotkeyHandler = require("hotkey_handler")
local celesteRender = require("celeste_render")
local loadedState = require("loaded_state")
local selectionUtils = require("selections")
local placementUtils = require("placement_utils")
local decalStruct = require("structs.decal")

local layersAPI = require("mods").requireFromPlugin("libraries.api.layers")

local function currentLayer()
    return layersAPI.getCurrentLayer()
end

local function isInCurrentLayer(item)
    --if not item._editorLayer then return true end
    return layersAPI.isInCurrentLayer(item)
end

---tries to set the alpha of a drawable
local function setAlpha(drawable, alpha)
    if drawable.color then
        local c = drawable.color
        drawable.color = {c[1], c[2], c[3], (c[4] or 1) * alpha}
    elseif drawable.setColor then
        drawable:setColor({1, 1, 1, alpha})
    end

    return drawable
end

--[[

-- set layer on place
local _orig_finalizePlacement = placementUtils.finalizePlacement
placementUtils.finalizePlacement = function(room, layer, item)
    _orig_finalizePlacement(room, layer, item)

    if not item._editorLayer then
        item._editorLayer = currentLayer()
    end

end]]

-- hotkeys
local layerHotkeys = { }

-- redraws the currently selected room, used for hotkeys
local function hotkeyRedraw()
    local room = loadedState.getSelectedRoom()
    celesteRender.invalidateRoomCache(room)
    celesteRender.forceRoomBatchRender(room, loadedState)
end

hotkeyHandler.createAndRegisterHotkey(nextLayerHotkey, function ()
    entities.___lonnLayers.nextLayer(1)
end, layerHotkeys)
hotkeyHandler.createAndRegisterHotkey(prevLayerHotkey, function ()
    entities.___lonnLayers.nextLayer(-1)
end, layerHotkeys)
hotkeyHandler.createAndRegisterHotkey(resetLayerHotkey, function ()
    entities.___lonnLayers.nextLayer(nil)
end, layerHotkeys)

-- lönn doesn't have proper mod hotkey support so time for horribleness
local _orig_createHotkeyDevice = hotkeyHandler.createHotkeyDevice
function hotkeyHandler.createHotkeyDevice(hotkeys)
    for index, value in ipairs(layerHotkeys) do
        table.insert(hotkeys, value)
    end
    hotkeyHandler.createHotkeyDevice = _orig_createHotkeyDevice
    return _orig_createHotkeyDevice(hotkeys)
end


return {}