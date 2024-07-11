local utils = require("utils")
local mods = require("mods")

local layersApi = {}

local extSettings = mods.requireFromPlugin("libraries.settings")
local le_utils = mods.requireFromPlugin('libraries.utils')
local entities = require("entities")
local reloadPersistence = mods.requireFromPlugin('libraries.api.reloadPersistence')

local function layersData(NIL) 
    if not (extSettings and extSettings.enabled() and extSettings.get("_enabled", true, "layers")) then 
        if NIL then return nil else return {} end 
    else 
        return reloadPersistence.getReloadPersistentTable().layers
    end
end


---Gets the currently active layer
---@return number
function layersApi.getCurrentLayer()
    return layersData().layer or 0
end

---Returns whether all layers are currently visible
---@return boolean
function layersApi.isEveryLayerVisible()
    return layersData().any or true
end

---Checks whether this item is in the currently active layer, by checking the input table's _editorLayer value.
---@param item table
---@return boolean
function layersApi.isInCurrentLayer(item)

    if item._id == 0 then return true end
    return layersApi.isEveryLayerVisible() or (item._editorLayer or 0) == layersApi.getCurrentLayer()
end

---Gets the layer of the given table, or nil if the layer is not specified.
---@param item table
---@return number|nil
function layersApi.getLayer(item)
    return item._editorLayer
end

---Sets the layer of the given table to the value of the 2nd argument, or the current layer if the 2nd argument is not provided
---@param item table
---@param layer number|nil
function layersApi.setLayer(item, layer)
    item._editorLayer = layer or layersApi.getCurrentLayer()
end

---Alpha value that's used for tinting sprites from hidden layers
layersApi.hiddenLayerAlpha = layersData(true) and extSettings.get("hiddenLayerAlpha", 0.1, "layers") or 1

return layersApi