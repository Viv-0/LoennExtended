local events = {}
local utils = require('utils')
local le_utils = require('mods').requireFromPlugin('libraries.utils')

local eventsAPI = {}
-- functions for other mods to use

function eventsAPI.linkEvent(eventName, func, id, priority)
    id = id or ""
    priority = priority or 0
    if not events[eventName] then return false end
    events[eventName].addEvent()
    table.insert(events[eventName], func)
end

function eventsAPI.triggerEvent(eventName, ...)
    local event = events[eventName]
    if event._outputType then
        local outputTable = {}
        for _,v in ipairs(event) do 
            local ret = v(...)
            if ret then table.insert(outputTable, ret) end
        end
        return outputManager(event._outputType, outputTable)
    else
        for _,v in ipairs(event) do 
            v(...)
        end
        return
    end
end

-- make eventsAPI pseudo-readonly
setmetatable(eventsAPI, {
    __index = function(table, key)
        if key == "events" or key == "triggerEvent" then 
            local fs = debug.getinfo(2, "S")
            if not (fs and fs:match(le_utils.hookManagerFolderNameMatch)) then 
                return nil
            end
        end
        return rawget(table, key)
    end, 
    __newindex = function(table, key, value)
        if key == "events" or key == "triggerEvent" then 
            return 
        end
        rawset(table, key, value)
    end
})

--- LOENNEXTENDED SPECIFIC CONTENT

--[[      EventHandler markup
eventHandler = {
    _type,    ---@type string   # always "eventHandler"
    linkName, ---@type string   # the name of the event. eventHandler is stored as eventsAPI.events[linkName], but because of metatables that's unaccessible to the end user
    _events,  ---@type table    # the list of functions managed by the event
    ...                         # additional data, usually necessary for the call action
}
pairs(eventHandler)             # list of methods added to event, technically pairs(eventHandler._events)
eventHandler(...)               # calls an externally referenced function used as part of the definition of the eventHandler which should call the functions in eventHandler._events
]]
-- this is just a reference for LoennExtended devs, please ignore this one
---@param linkName string # the name that the API links to
---@param func function(handler, ...) -> boolean # the function that handles the event calls
---@param addlData table # the other data that the eventHandler should contain:
---@param deepcopy boolean # whether addlData should be deepcopied (true) or referenced (false|nil)
--- For scene-called events:
--- addlData.eventName = the name of the event as called by scene_handler.sendEvent
--- addlData.timing = whether or not this calls before or after the event is called by the scene, string|function(handler) -> string returning "beforeScene", "beforeProp", or "after"
---"beforeScene" -> runs before the event is passed to the scene. Return false on the handler to stop the event from being passed to the scene
---"beforeProp"  -> runs during scene:propagateEvent, which is before `inputDevices.sendEvent` is called. If scene:eventName is nil, does not run.
---                 Return false on the handler to stop the event from being passed to `inputDevices.sendEvent`
---                 NOTE: InputHandler also passes information to things like tools or windows, so this functionally stops the event from going past the scene itself.
--- "after"      -> runs after event completes its pass to the scene.
---                 Returning true or false on the handler makes scene_handler.sendEvent return true or false, returning nil will return scene_handler.sendEvent's normal return
local function createEventHandler(linkName, func, addlData, deepcopy)
    if eventsAPI[linkName] then
        error("Event cannot be named `" .. linkName .. "`.")
    elseif events[linkName] then
        error("Event `" .. linkName .. "` already registered!")
    end
    local eventHandler = deepcopy and utils.deepcopy(addlData) or addlData or {}
    eventHandler._type = "eventHandler"
    eventHandler.linkName = linkName
    eventHandler._events = {}
    eventHandler._eventOrder = {}
    function eventHandler:addEvent(fun, id, priority)
        for i = 1, i < #self._eventOrder, 1 do 
            if self._eventOrder[i].priority > priority then 
                self._events[id] = fun
                table.insert(self._eventOrder, i, {id = id, priority = priority})
                return
            end
        end
    end
    function eventHandler:foreach(func, ...)
        for i = 1, i < #self._eventOrder, 1 do 
            func(self._events[self._eventOrder[i].id], ...)            
        end
    end

    setmetatable(eventHandler, {
        __call = function(self, ...) return func(self, ...) end
    })
    events[linkName] = eventHandler
    return eventHandler
end
-- this handler is special because firstLoad needs to do some fancy stuff to run correctly
createEventHandler("firstLoad", function(handler)
    handler:foreach(function(v) v() end)
    return nil
end)

createEventHandler("mapClose", function(handler)
    handler:foreach(function(v) v() end)
    return nil
end)

createEventHandler("mapLoad", function(handler, filename)
    local outputBoolean = true
    handler:foreach(function(v, ...) 
        local bool = v(...)
        if type(bool) == "boolean" then outputBoolean = outputBoolean and bool end
    end, filename)
    return outputBoolean
end, {eventName = "editorMapLoaded", timing = "beforeProp"})

createEventHandler("placeItem", function(handler, room, layer, item, itemHandler)
    local outputBoolean = true
    handler:foreach(function(v, ...)
        local bool = v(...)
        if type(bool) == "boolean" then outputBoolean = outputBoolean and bool end
    end, room, layer, item, itemHandler)
    return outputBoolean
end)

createEventHandler("saveChanges", function(handler, ...)
    local outputBoolean = true
    handler:foreach(function(v, ...) 
        local bool = v(...)
        if type(bool) == "boolean" then outputBoolean = outputBoolean and bool end
    end, ...)
    return outputBoolean
end)


return eventsAPI