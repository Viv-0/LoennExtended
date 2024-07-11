local utils = require('utils')
local fileLocations = require("file_locations")
local mods = require('mods')
local logging = require('logging')
local loadedState = require('loaded_state')
local celesteRender = require('celeste_render')

local leutils = {}
leutils.hookManagerName = "LoennExtended"
leutils.Delimiter = "|"

local function getModName()
    local info = debug.getinfo(1, "S").source
    local modName = info:match("^$(.+)$/Loenn/.+")
    return modName, "^$" .. modName .. "$/Loenn/.+$"
end
leutils.modFolderName, leutils.hookManagerFolderNameMatch = getModName()


function leutils.roomRedraw()
    local room = loadedState.getSelectedRoom()
    celesteRender.invalidateRoomCache(room)
    celesteRender.forceRoomBatchRender(room, loadedState)
end

function leutils.readOnly (tbl)
    local proxy = {}
    setmetatable(proxy, {       -- create metatable
      __index = tbl,
      __newindex = function (t,k,v)
        error("attempt to update a read-only table", 2)
      end
    })
    return proxy
end

---@param func function(path) -> table{any}
---@param ... folders
--- outputs table where table[modName] = returnValue or nil
function leutils.findPluginsYieldSafe(predicate, ...)
    local internals = {}
    local externals = {}
    for _, folderName in ipairs(mods.pluginFolderNames) do
        local outputTable = {}
        for modFolderName, _ in pairs(mods.loadedMods) do
            local path = utils.convertToUnixPath(utils.joinpath(
                string.format(mods.specificModContent, modFolderName),
                folderName,
                ...
            ))
            local filenames = (modFolderName == "LoennExtended" or modFolderName == "LoennExtended_zip") and internals or externals
            utils.getFilenames(path, true, filenames, predicate or function(filename)
                return utils.fileExtension(filename) == "lua"
            end, false)
        end
    end
    return internals, externals
end

local serialize = mods.requireFromPlugin('libraries.serialize')
leutils.dumpToFile = serialize.dumpToFile
leutils.serializeWithIgnore = serialize.serializeWithIgnore

-- PLEASE don't use any of the stuff below unless you know exactly what you're doing

function leutils.tryRequireWithReload(lib, verbose)
    if package.loaded[lib] then package.loaded[lib] = nil end
    return utils.tryrequire(lib, verbose)
end


local function traverseTableToMatchFunc(table, func, q)
    local b = not q
    q = q or ""
    for key, value in pairs(table) do
        if type(value) == "table" then
            local bool, ret = traverseTableToMatchFunc(value, func, key .. ".")
            if bool then
                return ret
            end
        elseif type(value) == "function" then
            if func == value then
                if b then
                    return true, key
                else 
                    return true, q .. "." .. key 
                end
            end
        end
    end
    return false, ""
end

leutils.sourceCache = {}
function leutils.getSourceFromFunction(func, _hookManager)
    -- stinky unoptimal stinky 
    if leutils.sourceCache[func] then return true, leutils.sourceCache[func] end
    local info = debug.getinfo(func, "S")
    if not info.source then
        error("A mod is hooking this function without using Loenn Hook Manager! Please contact Vividescence about this.")
    end
    local req
    local ret = utils.stripExtension(info.source)
    local modFolderName, secondaryPath = ret:match("^$(.+)$/Loenn/(.+)$")
    if _hookManager and _hookManager.requires[ret] then
        req = _hookManager.requires[ret]
    elseif modFolderName and modFolderName ~= leutils.modFolderName then
        secondaryPath = secondaryPath:gsub("/",".")
        -- This segment operates on the fact that the tables *need* to be loaded for modded files in order for us to run this function in the first place
        local pluginInfo = mods.modMetadata[modFolderName]
        local modFilePoint = pluginInfo._mountPointLoenn .. "." .. secondaryPath
        local result = mods.knownPluginRequires[modFilePoint]
        if result then 
            req = result
            _hookManager.requires[ret] = result -- technically, should be handled by package.loaded but I am not about to rewrite require
        else
            return false, "File " .. secondaryPath .. " from mod " .. pluginInfo[1].Name .. " was not previously loaded. Make sure you requireFromPlugin to a local variable in your hook file."
        end
    else
        req = require(ret)
        if req then if _hookManager then _hookManager.requires[ret] = req end
        else return false, "Could not find Source Function from `require('" .. ret .. "')`" end
    end
    if type(req) ~= "table" then 
        return false, "Could not find Source Function as `require('" .. ret .. "')` is not a table."
    end
    print("func: " .. tostring(func))
    local _, trav = traverseTableToMatchFunc(req, func)
    if trav then 
        if trav[1] == "." then
            trav = trav:sub(2)
        end
        local ret2 = ret:gsub("/", ".") .. leutils.Delimiter .. trav:gsub("^.", "")
        if not leutils.sourceCache[func] then leutils.sourceCache[func] = ret2 end
        return true, ret2
    else 
        return false, "Could not find source Function. This is most likely because you attempted to grab a function from somewhere other than its definition. source definition should be in " .. ret .. "."
    end
end

leutils.startFunctionFinder = serialize.startFunctionFinderPrompt

mods.requireFromPlugin('libraries.api.audio') -- do this here so we can thread the loading of modded audio banks = not slow later

return leutils