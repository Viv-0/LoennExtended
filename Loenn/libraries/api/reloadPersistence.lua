local le_utils = require('mods').requireFromPlugin('libraries.utils')
local utils = require('utils')
local fonts = require('fonts')
local modHandler = require('mods')

local reloadPersistence = {}


--- gets a mods' reload-persistent table. Use this to store data you don't want to get reset between f5/reload calls
--- data will be lost on closing application, use modPersistence in Loenn for storage between Loenn instances
--- if getReloadPersistentTable does not yet exist, returns set and sets `set` to the persistent table
---@return table
function reloadPersistence.getReloadPersistentTable()
    local fileSource = debug.getinfo(2,'S').source
    if not fileSource then error("attempted to get reload-persistent table from a method without a known file.") end
    local modName = fileSource:match('^$([^/\\?%%*:|"<>%s]+)$/Loenn/.+')
    if not modName then error("attempted to get reload-persistent table from file " .. fileSource .. " which falls outside of the Loenn scope") end
    modName = modHandler.modMetadata[modName].Name
    if not modName then error("attempted to get reload-persistent table from file " .. fileSource .. " which is not part of a loaded mod (or the mod has no everest.yaml)") end
    print(modName)
    local hm = rawget(fonts, le_utils.hookManagerName)
    if not hm.persistentTable[modName] then hm.persistentTable[modName] = {} end
    return hm.persistentTable[modName]
end

--- gets a readonly copy of another mods' reload-persistent table dependent on modName
---@param modName string # should be the everest.yaml name, not the mod folder name
---@return table # a readonly copy of the reload-persistent table for modName
function reloadPersistence.getReloadPersistentTableForMod(modName)
    local hm = rawget(fonts, le_utils.hookManagerName)
    local tbl = hm.persistentTable[modName]
    if not tbl then return nil end
    return le_utils.readonly(tbl)
end


return reloadPersistence