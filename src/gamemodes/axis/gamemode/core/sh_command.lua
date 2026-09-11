axis.command = axis.command or {}
axis.command.stored = axis.command.stored or {}
axis.command.aliases = axis.command.aliases or {}

--- Commands and prefixed chat classes share one registry keyed by the word after
--- the slash, so a chat prefix can never silently collide with a command name.
axis.command.prefix = "/"

axis.command.types = {}

---@param name string
---@param resolver fun(ply: Player, token: string, rest: string): any, string?
function axis.command.RegisterType(name, resolver)
    axis.command.types[name] = resolver
end

axis.command.RegisterType("string", function(_, token)
    return token
end)

axis.command.RegisterType("rest", function(_, _, rest)
    return rest
end)

axis.command.RegisterType("number", function(_, token)
    local value = tonumber(token)
    if not value then return nil, "'" .. token .. "' is not a number." end

    return value
end)

axis.command.RegisterType("bool", function(_, token)
    local lowered = string.lower(token)

    if lowered == "1" or lowered == "true" or lowered == "yes" or lowered == "on" then return true end
    if lowered == "0" or lowered == "false" or lowered == "no" or lowered == "off" then return false end

    return nil, "'" .. token .. "' is not a yes/no value."
end)

--- Accepts "90" (seconds), "10m", "1h30m", "2d12h". Returns seconds.
axis.command.RegisterType("time", function(_, token)
    local plain = tonumber(token)
    if plain then return math.max(0, math.floor(plain)) end

    local total, matched = 0, false
    local units = { s = 1, m = 60, h = 3600, d = 86400, w = 604800 }

    for amount, unit in string.gmatch(string.lower(token), "(%d+)%s*([smhdw])") do
        total = total + tonumber(amount) * units[unit]
        matched = true
    end

    if not matched then
        return nil, "'" .. token .. "' is not a duration (try 30s, 10m, 1h30m)."
    end

    return total
end)

--- Matches SteamID, SteamID64 or a case-insensitive partial name, and refuses to
--- guess when a partial name matches more than one person.
axis.command.RegisterType("player", function(_, token)
    local lowered = string.lower(token)
    local matches = {}

    for _, ply in ipairs(player.GetAll()) do
        if ply:SteamID() == token or ply:SteamID64() == token then return ply end

        if string.find(string.lower(ply:Nick()), lowered, 1, true)
            or string.find(string.lower(ply:GetDisplayName()), lowered, 1, true) then
            matches[#matches + 1] = ply
        end
    end

    if #matches == 0 then return nil, "No player matching '" .. token .. "'." end

    if #matches > 1 then
        local names = {}
        for _, ply in ipairs(matches) do names[#names + 1] = ply:Nick() end

        return nil, "'" .. token .. "' matches " .. #matches .. " players: " .. table.concat(names, ", ")
    end

    return matches[1]
end)

local function RegistryType(name, registry, label)
    axis.command.RegisterType(name, function(_, token)
        local lowered = string.lower(token)
        local partial = nil

        for id, data in pairs(registry()) do
            if string.lower(id) == lowered or string.lower(data.name or "") == lowered then
                return data
            end
            if not partial and string.find(string.lower(data.name or id), lowered, 1, true) then
                partial = data
            end
        end

        if partial then return partial end

        return nil, "No " .. label .. " matching '" .. token .. "'."
    end)
end

RegistryType("faction", function() return axis.faction.GetAll() end, "faction")
RegistryType("class", function() return axis.class.GetAll() end, "class")
RegistryType("rank", function() return axis.rank.GetAll() end, "rank")

--- Splits on whitespace but keeps quoted runs together, and records where each
--- token started so a `rest` argument can grab the untouched remainder.
---@param text string
---@return string[] tokens, number[] offsets
function axis.command.Tokenize(text)
    local tokens, offsets = {}, {}
    local i, len = 1, #text

    while i <= len do
        local char = string.sub(text, i, i)

        if char == " " or char == "\t" then
            i = i + 1
        elseif char == '"' or char == "'" then
            local closing = string.find(text, char, i + 1, true) or (len + 1)

            tokens[#tokens + 1] = string.sub(text, i + 1, closing - 1)
            offsets[#offsets + 1] = i
            i = closing + 1
        else
            local nextSpace = string.find(text, "%s", i) or (len + 1)

            tokens[#tokens + 1] = string.sub(text, i, nextSpace - 1)
            offsets[#offsets + 1] = i
            i = nextSpace
        end
    end

    return tokens, offsets
end

---@param name string
---@param data table
---@return table
function axis.command.Register(name, data)
    name = string.lower(name)

    data.name = name
    data.arguments = data.arguments or {}
    data.description = data.description or ""

    axis.command.stored[name] = data
    axis.command.aliases[name] = name

    for _, alias in ipairs(data.aliases or {}) do
        axis.command.aliases[string.lower(alias)] = name
    end

    return data
end

---@param name string
---@return table|nil
function axis.command.Get(name)
    local resolved = axis.command.aliases[string.lower(name or "")]
    if not resolved then return nil end

    return axis.command.stored[resolved]
end

---@param command table
---@return string
function axis.command.GetUsage(command)
    local parts = { axis.command.prefix .. command.name }

    for _, argument in ipairs(command.arguments) do
        parts[#parts + 1] = argument.optional
            and ("[" .. argument.name .. "]")
            or ("<" .. argument.name .. ">")
    end

    return table.concat(parts, " ")
end

--- Turns the raw argument string into the values a command's OnRun expects.
---@param ply Player
---@param command table
---@param text string
---@return table? values, string? err
function axis.command.ParseArguments(ply, command, text)
    local tokens, offsets = axis.command.Tokenize(text)
    local values = {}

    for index, argument in ipairs(command.arguments) do
        local token = tokens[index]

        if token == nil or token == "" then
            if not argument.optional then
                return nil, "Missing " .. argument.name .. ". Usage: " .. axis.command.GetUsage(command)
            end

            values[index] = argument.default
        else
            local resolver = axis.command.types[argument.type or "string"]

            if not resolver then
                return nil, "Command '" .. command.name .. "' uses unknown argument type '" ..
                    tostring(argument.type) .. "'."
            end

            local rest = string.sub(text, offsets[index])
            local value, err = resolver(ply, token, rest)

            if value == nil then
                return nil, err or ("Invalid value for " .. argument.name .. ".")
            end

            values[index] = value
        end
    end

    return values
end
