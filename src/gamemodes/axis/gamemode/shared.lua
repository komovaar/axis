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

    if SERVER then
        if prefix == "sv_" then
            include(path)
        elseif  prefix == "cl_" then
            AddCSLuaFile(path)
        elseif prefix == "sh_" then
            AddCSLuaFile(path)
            include(path)
        end
        print(path .. " loaded")
    else -- CLIENT
        if prefix == "cl_" or prefix == "sh_" then
            include(path)
            print(path .. " loaded")

        end
    end
end

---@param dir string
function axis.IncludeDir(dir)
    local serachPath = "axis/gamemode/" .. dir
    local files, folders = file.Find(serachPath .. "/*", "LUA")

    for _, f in ipairs(files) do
        if string.sub(f, -4) == ".lua" then
            axis.Include(dir .. "/" .. f)
        end
    end

    for _, folder in ipairs(folders or {}) do
        axis.IncludeDir(dir .. "/" .. folder)
    end
end