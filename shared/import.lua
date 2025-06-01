NS = {
    __conf = { debug = false },
    schemas = {},
    types = {},
    states = {},
    statesRef = {},
    statesCallback = {},
    stateId = 0,
}
null = 'NULL'

--- Initializes
setmetatable(NS.states, {
    __index = function(_, key)
        return NS.statesRef[key]
    end,

    __newindex = function(_, key, value)
        if type(NS.statesCallback[key]) == 'function' then
            pcall(function() NS.statesCallback[key](NS.statesRef[key], value) end)
        end

        NS.statesRef[key] = value
    end
})

--- @param schema EventObject | string
--- @param fn EventCallback
--- @param isNet nil | boolean
function NS.onEvent(schema, fn, isNet)
    if type(schema) == 'string' then
        if NS.schemas[schema] then
            schema = NS.schemas[schema]
        end
    end

    if type(schema) ~= 'table' then
        error('Event object schema not valid!')
    end

    if schema.name == nil or schema.paramsSort == nil then
        error('Event object schema does not have property name or paramsSort!')
    end

    local names = schema.name
    local paramsSort = schema.paramsSort

    if type(names) == 'string' then
        names = { names }
    end

    local targetHandlerFn = AddEventHandler
    if isNet == true then
        targetHandlerFn = RegisterNetEvent
    end

    for _, name in ipairs(names) do
        targetHandlerFn(name, function(...)
            local args = { ... }
            local _ = { values = {} }

            _.get = function(index)
                return _.values[index]
            end

            for paramName, paramIndex in pairs(paramsSort) do
                _.values[paramName] = args[paramIndex]
            end

            if isNet and isNet == true and IsDuplicityVersion() then
                local testSource = source

                if testSource ~= nil and (type(testSource) == 'string' or type(testSource) == 'number') then
                    _.values['_source'] = testSource
                end
            end

            fn(_)
        end)
    end
end

--- @param schema EventObject | string
--- @param fn EventCallback
function NS.onLocalEvent(schema, fn)
    NS.onEvent(schema, fn, false)
end

--- @param schema EventObject | string
--- @param fn EventCallback
function NS.onNetEvent(schema, fn)
    NS.onEvent(schema, fn, true)
end

--- @param schema EventObject | string
--- @param isNet boolean
--- @param ... any
function NS.sendEvent(schema, isNet, ...)
    local typesKey

    if type(schema) == 'string' then
        if NS.schemas[schema] then
            typesKey = schema
            schema = NS.schemas[schema]
        end
    end

    if type(schema) ~= 'table' then
        error('Event object schema not valid!')
    end

    if schema.name == nil or schema.paramsSort == nil then
        error('Event object schema does not have property name or paramsSort!')
    end

    local names = schema.name
    local paramsSort = schema.paramsSort
    local paramsCount = 0

    if type(names) == 'string' then
        names = { names }
    end

    local targetTriggerFn = TriggerEvent
    if isNet == true then
        if IsDuplicityVersion() then
            targetTriggerFn = TriggerClientEvent
        else
            targetTriggerFn = TriggerServerEvent
        end
    end

    for _, _ in pairs(paramsSort) do
        paramsCount = paramsCount + 1
    end

    local args = { ... }
    local validParamsLength = #args == paramsCount
    local validParamsType = true

    if typesKey ~= nil then
        if NS.types[typesKey] then
            local typesData = NS.types[typesKey]
            for paramName, paramIndex in pairs(paramsSort) do
                local targetType = typesData[paramName]

                if targetType == nil then
                    validParamsType = false
                    error(('Error cannot find type of param (%s), please check createSchema to call makeTypes'):format(paramName))
                    break
                end

                local currentParamValue = args[paramIndex]
                if type(currentParamValue) ~= targetType then
                    validParamsType = false
                    error(('Error invalid type of param (%s) expected %s got %s'):format(paramName, targetType, type(currentParamValue)))
                    break
                end
            end
        end
    end

    if validParamsLength and validParamsType then
        for _, eventName in ipairs(names) do
            targetTriggerFn(eventName, ...)
        end
    else
        error('Error you must send all of expecting parameters!')
    end
end

--- @param schema EventObject | string
--- @param ... any
function NS.sendLocalEvent(schema, ...)
    NS.sendEvent(schema, false, ...)
end

--- @param schema EventObject | string
--- @param ... any
function NS.sendNetEvent(schema, ...)
    NS.sendEvent(schema, true, ...)
end

--- @param prefix DebugType
--- @param text string
function NS.debug(prefix, text)
    if NS.__conf.debug then
        local color

        if prefix == 'success' then color = '^2'
        elseif prefix == 'info' then color = '^5'
        elseif prefix == 'warn' then color = '^3'
        elseif prefix == 'error' then color = '^1'
        end

        print(('%s[%s]^7 %s^7'):format(color, string.upper(prefix), text))
    end
end

--- @param enabled boolean
function NS.setDebugMode(enabled)
    if type(enabled) ~= 'boolean' then
        error('Error invalid enabled type, need Boolean!')
    end

    NS.__conf.debug = enabled
end

--- @param name EventName
--- @param paramsSort EventParamsSort
--- @return SchemaFallback
function NS.createSchema(name, paramsSort)
    if type(name) ~= 'string' or type(name) == 'table' then
        error('Event (name) object schema not valid!')
    end

    if type(paramsSort) ~= 'table' then
        error('Event (paramsSort) object schema not valid!')
    end

    local names

    if type(name) == 'string' then
        names = { name }
    else
        names = name
    end

    local schema = { name = names, paramsSort = paramsSort }
    local types = {}
    local app = {}
    local hasTypes = false

    --- @param typesList EventParamsType
    --- @return SchemaFallback
    app.makeTypes = function(typesList)
        hasTypes = true

        for prop, targetType in pairs(typesList) do
            if paramsSort[prop] then
                types[prop] = targetType
            end
        end

        return app
    end

    --- @param key string
    --- @return SchemaFallback
    app.registerAs = function(key)
        NS.schemas[key] = schema

        if hasTypes then
            NS.types[key] = types
        end

        return app
    end

    --- @return EventObject
    app.getSchema = function()
        return schema
    end

    return app
end

--- @param key string
--- @return EventObject | null
function NS.getSchema(key)
    if NS.schemas[key] then
        return NS.schemas[key]
    end

    return null
end

--- @param value any
--- @return boolean
function NS.isNULL(value)
    if type(value) ~= 'string' then
        return false
    end

    return value == null
end

--- @param value any
--- @param fn StateCallback
--- @return StateFallbackGet, StateFallbackSet
function NS.createState(value, fn)
    if type(value) == 'nil' or type(fn) ~= 'function' then
        error('Error type of value or function invalid!')
    end

    local id = NS.stateId + 1
    NS.stateId = id

    NS.states[id] = value
    NS.statesCallback[id] = fn

    local getter = function()
        return NS.states[id]
    end

    local setter = function(newValue)
        NS.states[id] = newValue
    end

    return getter, setter
end

--- @param tbl any[]
--- @return ArrayPrototype
function NS.array(tbl)
    if type(tbl) ~= 'table' then
        error('Error type of table invalid!')
    end

    local arr = {}

    for i, v in ipairs(tbl) do
        arr[i] = v
    end

    local arrPrototype = {}

    function arrPrototype:len()
        return #arr
    end

    function arrPrototype:push(value)
        table.insert(arr, value)
    end

    function arrPrototype:pop()
        return table.remove(arr)
    end

    function arrPrototype:shift()
        return table.remove(arr, 1)
    end

    function arrPrototype:unshift(value)
        table.insert(arr, 1, value)
    end

    function arrPrototype:forEach(callback)
        for i, v in ipairs(arr) do
            callback(v, i)
        end
    end

    function arrPrototype:map(callback)
        local result = {}
        for i, v in ipairs(arr) do
            result[i] = callback(v, i)
        end

        return NS.array(result)
    end

    function arrPrototype:filter(callback)
        local result = {}
        for i, v in ipairs(arr) do
            if callback(v, i) then
                table.insert(result, v)
            end
        end

        return NS.array(result)
    end

    function arrPrototype:find(callback)
        for i, v in ipairs(arr) do
            if callback(v, i) then
                return v
            end
        end

        return nil
    end

    function arrPrototype:includes(value)
        for _, v in ipairs(arr) do
            if v == value then
                return true
            end
        end

        return false
    end

    function arrPrototype:indexOf(value)
        for i, v in ipairs(arr) do
            if v == value then
                return i
            end
        end

        return -1
    end

    function arrPrototype:toTable()
        local copy = {}
        for i, v in ipairs(arr) do
            copy[i] = v
        end

        return copy
    end

    function arrPrototype:print()
        for i, v in ipairs(arr) do
            print(i, v)
        end
    end

    local wrapper = {}

    return setmetatable(wrapper, {
        __index = function(_, key)
            if type(key) == 'number' then
                return arr[key]
            elseif arrPrototype[key] then
                return function(_, ...)
                    return arrPrototype[key](arrPrototype, ...)
                end
            end
        end,

        __newindex = function(_, key, value)
            if type(key) == 'number' then
                arr[key] = value
            else
                rawset(wrapper, key, value)
            end
        end,

        __len = function()
            return #arr
        end,

        __tostring = function()
            return '[ ' .. table.concat(arr, ', ') .. ' ]'
        end,

        __pairs = function()
            return pairs(arr)
        end,

        __ipairs = function()
            return ipairs(arr)
        end
    })
end

return NS