GM.Name = "Axis"
GM.Author = "whosgotch"

DeriveGamemode("sandbox")

axis = axis or {}

function GM:Initialize()
    -- Do stuff
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
        print(path .. " loaded")
    else -- CLIENT
        if isShared or isClient or noPrefix then
            include(path)
            print(path .. " loaded")
        end
    end
end

---@param dir string
function axis.IncludeDir(dir)
    local searchPath = "axis/gamemode/" .. dir
    local files, folders = file.Find(searchPath .. "/*", "LUA")

    for _, f in ipairs(files) do
        if string.sub(f, -4) == ".lua" then
            axis.Include(dir .. "/" .. f)
        end
    end

    for _, folder in ipairs(folders or {}) do
        axis.IncludeDir(dir .. "/" .. folder)
    end
end