GM.Name = "Axis"
GM.Author = "whosgotch"

DeriveGamemode("sandbox")

axis = axis or {}
axis.loader = axis.loader or {}

--- Load order matters: libs provide CAMI, core provides the registries, and the
--- content directories reference each other by id (classes -> factions + ranks),
--- so they must land in dependency order rather than whatever file.Find returns.
axis.loader.order = {
    "libs",
    "core",
    "factions",
    "ranks",
    "classes",
    "commands",
}

---@param msg string
function axis.Log(msg, ...)
    MsgC(Color(120, 180, 255), "[Axis] ", color_white, string.format(msg, ...), "\n")
end

---@param msg string
function axis.LogError(msg, ...)
    MsgC(Color(255, 90, 90), "[Axis] ", color_white, string.format(msg, ...), "\n")
end

---@param path string
function axis.Include(path)
    local filename = string.match(path, "[^/]+$") or path
    local prefix = string.sub(filename, 1, 3)

    -- factions/ and other content files without prefix are treated as shared
    local isShared = prefix == "sh_"
    local isServer = prefix == "sv_"
    local isClient = prefix == "cl_"
    local noPrefix = not isShared and not isServer and not isClient

    if SERVER then
        if isServer then
            include(path)
        elseif isClient then
            AddCSLuaFile(path)
        elseif isShared or noPrefix then
            AddCSLuaFile(path)
            include(path)
        end
    else -- CLIENT
        if isShared or isClient or noPrefix then
            include(path)
        end
    end
end

--- Shared files load before realm files within a directory: cl_ and sv_ code
--- routinely reads tables that a sh_ file creates at its top level, and
--- file.Find returns plain alphabetical order, which puts cl_ first.
---@param dir string
function axis.IncludeDir(dir)
    local searchPath = "axis/gamemode/" .. dir
    local files, folders = file.Find(searchPath .. "/*", "LUA")

    local lua = {}

    for _, f in ipairs(files or {}) do
        if string.sub(f, -4) == ".lua" then lua[#lua + 1] = f end
    end

    table.sort(lua, function(a, b)
        local aShared = string.sub(a, 1, 3) == "sh_"
        local bShared = string.sub(b, 1, 3) == "sh_"

        if aShared ~= bShared then return aShared end

        return a < b
    end)

    for _, f in ipairs(lua) do
        axis.Include(dir .. "/" .. f)
    end

    for _, folder in ipairs(folders or {}) do
        axis.IncludeDir(dir .. "/" .. folder)
    end
end

function axis.LoadAll()
    for _, dir in ipairs(axis.loader.order) do
        axis.IncludeDir(dir)
    end

    axis.Validate()
end

--- Runs after every registry is populated. Content files reference each other by
--- string id, which cannot be checked at registration time because the target may
--- not have loaded yet, so every cross-reference is verified here instead.
function axis.Validate()
    local problems = {}

    local function fail(fmt, ...)
        problems[#problems + 1] = string.format(fmt, ...)
    end

    for id, faction in pairs(axis.faction.GetAll()) do
        local class = faction.defaultClass and axis.class.Get(faction.defaultClass)

        if not faction.defaultClass then
            fail("faction '%s' has no defaultClass", id)
        elseif not class then
            fail("faction '%s' defaultClass '%s' does not exist", id, faction.defaultClass)
        elseif class.faction ~= id then
            fail("faction '%s' defaultClass '%s' belongs to faction '%s'", id, faction.defaultClass, class.faction)
        end

        local rank = faction.defaultRank and axis.rank.Get(faction.defaultRank)

        if not faction.defaultRank then
            fail("faction '%s' has no defaultRank", id)
        elseif not rank then
            fail("faction '%s' defaultRank '%s' does not exist", id, faction.defaultRank)
        elseif rank.faction ~= id then
            fail("faction '%s' defaultRank '%s' belongs to faction '%s'", id, faction.defaultRank, rank.faction)
        end
    end

    for id, class in pairs(axis.class.GetAll()) do
        if not axis.faction.Get(class.faction) then
            fail("class '%s' references unknown faction '%s'", id, tostring(class.faction))
        end

        if class.minRank then
            local rank = axis.rank.Get(class.minRank)

            if not rank then
                fail("class '%s' minRank '%s' does not exist", id, class.minRank)
            elseif rank.faction ~= class.faction then
                fail("class '%s' minRank '%s' belongs to faction '%s'", id, class.minRank, rank.faction)
            end
        end
    end

    local levels = {}

    for id, rank in pairs(axis.rank.GetAll()) do
        if not axis.faction.Get(rank.faction) then
            fail("rank '%s' references unknown faction '%s'", id, tostring(rank.faction))
        end

        levels[rank.faction] = levels[rank.faction] or {}

        local clash = levels[rank.faction][rank.level]
        if clash then
            fail("ranks '%s' and '%s' share level %d in faction '%s'", clash, id, rank.level, rank.faction)
        else
            levels[rank.faction][rank.level] = id
        end
    end

    for _, problem in ipairs(problems) do
        axis.LogError("content error: %s", problem)
    end

    if #problems > 0 then
        axis.LogError("%d content error(s) found - see above", #problems)
    else
        axis.Log("loaded %d faction(s), %d class(es), %d rank(s)",
            table.Count(axis.faction.GetAll()),
            table.Count(axis.class.GetAll()),
            table.Count(axis.rank.GetAll()))
    end

    return #problems == 0
end
