--[[
    Handles most of the layer-based hooks, excluding finalizePlacement, as that gets a number of other hooks - see hooks/finalizePlacement.lua
]]
local mods = require('mods')
local utils = require('utils')
local entities = require('entities')
local celesteRender = require('celeste_render')
local loadedState = require('loaded_state')
-- Loenn Extended references
local layersAPI = mods.requireFromPlugin("libraries.api.layers")
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

local hooks = {
    ["decals|getDrawable"] = {
        priority = 1000000,
        version = "0.7.10",
        new = function (orig, texture, handler, room, decal, viewport)
            local drawable = orig(texture, handler, room, decal, viewport)
        
            if drawable and not isInCurrentLayer(decal) then
                setAlpha(drawable, layersAPI.hiddenLayerAlpha)
            end
        
            if drawable and isInCurrentLayer(decal) then
                setAlpha(drawable, 1.5) -- ???
            end
            return drawable
        end
    },
    ["entities|getDrawableUnsafe"] = {
        priority = 1000000,
        version = "0.7.10",
        new = function (orig, name, handler, room, entity, ...)
            local entityDrawable, depth = orig(name, handler, room, entity, ...)

            if not isInCurrentLayer(entity) then
                if utils.typeof(entityDrawable) == "table" then
                    for _, value in ipairs(entityDrawable) do
                        setAlpha(value, layersAPI.hiddenLayerAlpha)
                    end
                else
                    setAlpha(entityDrawable, layersAPI.hiddenLayerAlpha)
                end
            end


            return entityDrawable, depth
        end
    },
    ["selections|getSelectionsForItem"] = {
        priority = 1000000,
        version = "0.7.10",
        new = function(orig, room, layer, item, rectangles)
            if isInCurrentLayer(item) then
                return orig(room, layer, item, rectangles)
            end
        
            return rectangles or {}
        end
    },
    ["structs.decal|decode"] = {
        priority = 10,
        version = "0.7.10",
        new = function(orig, data)
            local decal = orig(data)

            decal._editorLayer = data._editorLayer

            return decal
        end
    },
    ["structs.decal|encode"] = {
        priority = 10,
        version = "0.7.10",
        new = function(orig, decal)
            local res = orig(decal)

            local layer = decal._editorLayer
            if layer and layer ~= 0 then
                res._editorLayer = layer
            end

            return res
        end
    },
    ["loaded_state|selectItem"] = {
        priority = 10,
        version = "0.7.10",
        new = function(orig, item, add, ...)
            orig(item, add, ...)
        
            local itemType = utils.typeof(item)
        
            if itemType == "room" then
                celesteRender.invalidateRoomCache(item)
                celesteRender.forceRoomBatchRender(item, loadedState)
            end
        end
    }
}

return hooks