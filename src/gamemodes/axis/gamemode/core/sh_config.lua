axis.config = axis.config or {}

--- Credentials are read from garrysmod/data/axis/db.json, written by the
--- container entrypoint from environment variables. They deliberately do not
--- travel as "+convar value" on the srcds command line: that executes before the
--- gamemode's Lua has created the convars, so the values are silently dropped.
--- The convars below remain for bare-metal servers with no entrypoint, and any
--- convar explicitly changed from its default wins over the file.
if SERVER then
    local function DBConVar(name, default)
        return CreateConVar("axis_db_" .. name, default, { FCVAR_PROTECTED },
            "MariaDB " .. name .. ", overriding data/axis/db.json when set.")
    end

    local convars = {
        host = DBConVar("host", "127.0.0.1"),
        port = DBConVar("port", "3306"),
        name = DBConVar("name", "axis"),
        user = DBConVar("user", "axis"),
        pass = DBConVar("pass", ""),
    }

    axis.config.dbFile = "axis/db.json"

    ---@return table|nil
    local function ReadDatabaseFile()
        local raw = file.Read(axis.config.dbFile, "DATA")
        if not raw then return nil end

        local parsed = util.JSONToTable(raw)

        if not parsed then
            axis.LogError("data/%s is not valid JSON - ignoring it", axis.config.dbFile)
            return nil
        end

        return parsed
    end

    --- Resolved credentials, file first and explicitly-set convars on top.
    ---@return table
    function axis.config.GetDatabase()
        local fromFile = ReadDatabaseFile() or {}

        local resolved = {
            host = fromFile.host or convars.host:GetDefault(),
            port = tonumber(fromFile.port) or tonumber(convars.port:GetDefault()),
            name = fromFile.name or convars.name:GetDefault(),
            user = fromFile.user or convars.user:GetDefault(),
            pass = fromFile.pass or convars.pass:GetDefault(),
            source = fromFile.host and ("data/" .. axis.config.dbFile) or "convars",
        }

        for key, convar in pairs(convars) do
            local value = convar:GetString()

            if value ~= convar:GetDefault() then
                resolved[key] = key == "port" and tonumber(value) or value
                resolved.source = "convars"
            end
        end

        resolved.port = resolved.port or 3306

        return resolved
    end
end

--- Faction every new character is created into. Players do not choose a faction
--- at creation; staff move them afterwards with /setfaction. Validated at boot
--- by axis.Validate, which also checks it is joinable.
axis.config.defaultFaction = "republic"

--- Maximum characters a single SteamID may own.
axis.config.maxCharacters = 5

--- Character names are validated against these before creation.
axis.config.nameMinLength = 3
axis.config.nameMaxLength = 32

--- How often (seconds) dirty characters are flushed to the database.
axis.config.saveInterval = 300

--- Radii (units) for the radius-based in-character chat classes.
axis.config.chatRadius = {
    ic = 250,
    me = 300,
    it = 300,
    whisper = 90,
    yell = 600,
}

--- Seconds a player must wait between /ooc messages.
axis.config.oocCooldown = 10

--- Distance within which /spawnremove will delete a spawnpoint.
axis.config.spawnRemoveRadius = 128

axis.config.color = {
    info = Color(120, 180, 255),
    success = Color(120, 220, 130),
    error = Color(255, 90, 90),
    ooc = Color(190, 130, 255),
    radio = Color(120, 220, 130),
    me = Color(200, 160, 255),
    whisper = Color(160, 160, 170),
    yell = Color(255, 200, 120),
    default = Color(230, 230, 230),
}
