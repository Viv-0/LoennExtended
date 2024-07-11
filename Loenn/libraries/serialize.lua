local ser = {}
local utils = require('utils')
local serialize = require('utils.serialize')
local mods = require('mods')
local fileLocations = require('file_locations')

local metamethods = {
    "*__add", "*__sub", "*__mul", "*__div", "*__unm", "*__mod", "*__pow", "*__idiv",
    "*__eq", "*__le", "*__lt", "*__concat", "*__len",
    "*__index", "*__newindex", "*__call"
}


local function insertIfNotEmpty(t, s)
    if s and s ~= "" then
        t[#t+1] = s
    end
end

function ser.dumpToFile(node, ignoredStrings, outputFile)
    if not outputFile then error("Output file was nil") end
    local cache, stack, output = {},{},{}
    local depth = 1
    local output_str = "{\n"

    while true do
        local size = 0
        for k,v in pairs(node) do
            if k ~= "requires" then
                size = size + 1
            end
        end

        local cur_index = 1
        for k,v in pairs(node) do
            if not utils.contains(k, ignoredStrings) then
                if (cache[node] == nil) or (cur_index >= cache[node]) then

                    if (string.find(output_str,"}",output_str:len())) then
                        output_str = output_str .. ",\n"
                    elseif not (string.find(output_str,"\n",output_str:len())) then
                        output_str = output_str .. "\n"
                    end

                    -- This is necessary for working with HUGE tables otherwise we run out of memory using concat on huge strings
                    table.insert(output,output_str)
                    output_str = ""

                    local key
                    if (type(k) == "number" or type(k) == "boolean") then
                        key = "["..tostring(k).."]"
                    else
                        key = "['"..tostring(k).."']"
                    end

                    if (type(v) == "number" or type(v) == "boolean") then
                        output_str = output_str .. string.rep('\t ',depth) .. key .. " = "..tostring(v)
                    elseif (type(v) == "table") then
                        output_str = output_str .. string.rep('\t ',depth) .. key .. " = {\n"
                        table.insert(stack,node)
                        table.insert(stack,v)
                        cache[node] = cur_index+1
                        break
                    else
                        output_str = output_str .. string.rep('\t',depth) .. key .. " = '"..tostring(v).."'"
                    end

                    if (cur_index == size) then
                        output_str = output_str .. "\n" .. string.rep('\t ',depth-1) .. "}"
                    else
                        output_str = output_str .. ","
                    end
                else
                    -- close the table
                    if (cur_index == size) then
                        output_str = output_str .. "\n" .. string.rep('\t ',depth-1) .. "}"
                    end
                end

                cur_index = cur_index + 1
            end
        end

        if (size == 0) then
            output_str = output_str .. "\n" .. string.rep('\t ',depth-1) .. "}"
        end

        if (#stack > 0) then
            node = stack[#stack]
            stack[#stack] = nil
            depth = cache[node] == nil and depth + 1 or depth - 1
        else
            break
        end
    end

    -- This is necessary for working with HUGE tables otherwise we run out of memory using concat on huge strings
    table.insert(output,output_str)
    output_str = table.concat(output)

    local file = io.open(utils.joinpath(fileLocations.getCelesteDir(), outputFile), "w")
    file:write(output_str)
    file:close()
end

-- this is only useful for loennextended so why use this lmao
function ser.startFunctionFinderPrompt()
    io.write("Name the file, or type `mod` to get file from modded source.\n")
    local inp = io.read()
    local resultString = inp
    if utils.trim(inp) == "mod" then 
        local str = "Here are the list of mounted mods:\n"
        for modFolderName, metadata in pairs(mods.modMetadata) do
            for _, info in ipairs(metadata) do
                str = str .. info.Name .. "\n"
            end
        end
        io.write(str .. "Pick a mod to grab files from. ")
        local modInfo, pluginInfo, folderName
        while true do
            inp = io.read()
            modInfo, pluginInfo, folder = findLoadedMod(inp)
            if modInfo then break end
        
            io.write("Try again. ")
        end
        local modName = inp
        local filenames = {}
        utils.getFilenames(pluginInfo._mountPointLoenn, true, filenames, function(filename)
            return utils.fileExtension(filename) == "lua"
        end, false)
        str = "Here are the list of plugins for " .. inp .. ":\n"
        for _,v in ipairs(filenames) do str = str .. v .. "\n" end
        io.write(str .. "Pick a file to pull from. ")
        while true do
            inp = io.read()
            if utils.contains(inp, filenames) then 
                resultString = inp
                break
            end 
            io.write("Try again. ")
        end
    end
    local temp = resultString
    local result = require(resultString)
    --[[
    io.write("Debug file itself? y/n \t")
    inp = io.read()
    if #inp > 0 and inp[1] == "y" then 

    end]]
    if type(result) ~= "table" then io.write("file failed to load a table.") ; return end
    local funcs = {}

    io.write("At this point, the loop will begin. Input an empty string to exit.\n")
    while true do 
        local out = false
        if type(result) == "function" then 
            local l = 1 ; local u = 1 ; local i = 1
            io.write("Select something from this function:" .. tostring(result) .. "\n")
            while true do 
                local lName, lValue = debug.getlocal(result, i)
                local uName, uValue = debug.getupvalue(result, i) 
                if lValue then 
                    if uValue then u = u+1 end
                    l = l+1
                elseif uValue then u = u+1
                else break end
                io.write(string.format("index: %s\nlocal `%s` -> %s\nupvalue `%s` -> %s\n", i, lName or "nil", tostring(lValue or "nil"), uName or "nil", tostring(uValue or "nil")))
                i = i+1
            end
            io.write("Type in a string of the form `local|up #` (examples: `local 1`, `up 3`)\n")
            while true do
                inp = utils.trim(io.read())
                if not inp or #inp == 0 then out = true ; break end
                local a, b = inp:match("^(%a+) (%d+)$")
                local c = tonumber(b)
                if a and c and c > 0 and c <= i then 
                    if a == "local" and c <= l then 
                        temp, result = debug.getlocal(result, c)
                        temp = "local " .. temp
                        resultString = resultString .. "|$$local" .. b
                        break
                    elseif (a == "up" or a == "upvalue") and c <= u then 
                        temp, result = debug.getupvalue(result, c)
                        temp = "local " .. temp
                        resultString = resultString .. "|$$up" .. b
                        break
                    end
                end
                io.write("Try again.\t")
            end                
        elseif type(result) == "table" then 
            io.write("Select a key from `" .. temp .. "`:\n")
            for k, v in pairs(result) do 
                io.write(k .. ": " .. tostring(v) .. "\n")
            end
            io.write("Type in a key in " .. temp .. ". For integers, precede the string with a `$`\n")
            while true do
                inp = utils.trim(io.read())
                if not inp or #inp == 0 or inp:match("(%s+)") == inp then out = true ; break end
                local _num = inp:match("^$(%d+)$")
                if _num then 
                    print("number found")
                    local num = tonumber(_num)
                    if num and num >= 1 and math.abs((num - 1) % 1) < 0.01 and result[_num] then
                        temp = temp .. "[".. _num .. "]"
                        resultString = resultString .. "|" .. inp
                        result = result[num]
                        break
                    end
                elseif utils.contains(inp, metamethods) then
                    local resultMt = getmetatable(result)
                    if resultMt and resultMt[inp] then 
                        temp = temp .. "|" .. inp.sub(2)
                        resultString = resultString .. "|" .. inp.sub(2)
                        result = resultMt[inp]
                        break
                    else io.write("Metatable was nil or did not have the appropriate metamethod - ") end
                elseif result[inp] then
                    temp = temp .. "[" .. inp .. "]"
                    resultString = resultString .. "|" .. inp
                    result = result[inp]
                    break
                else
                    io.write("table key " .. inp .. "was not found - ")
                end
                io.write("Try again.\t")
            end
        else error("Exited on a nonfunction nontable") end
        if out then break end
    end

    io.write("Evaluated to:\n" .. resultString .. "\n")
end

function ser.serializeFunctionData(result) 
    local l = 1 ; local u = 1 ; local i = 1
    print("serializing debug data for " .. tostring(result))
    while true do 
        local lName, lValue = debug.getlocal(result, i)
        local uName, uValue = debug.getupvalue(result, i) 
        if lValue then 
            if uValue then u = u+1 end
            l = l+1
        elseif uValue then u = u+1
        else break end
        print(string.format("index: %s\nlocal `%s` -> %s\nupvalue `%s` -> %s\n", i, lName or "nil", tostring(lValue or "nil"), uName or "nil", tostring(uValue or "nil")))
        i = i+1
    end
end

return ser