axis.db = axis.db or {}
axis.db.queue = axis.db.queue or {}
axis.db.state = axis.db.state or "idle" -- idle | connecting | connected | failed
axis.db.error = axis.db.error

local SCHEMA_VERSION = 1

local loaded = pcall(require, "mysqloo")

if not loaded or not mysqloo then
    axis.db.state = "failed"
    axis.db.error = "the gmsv_mysqloo binary module is missing from garrysmod/lua/bin"
end

---@return boolean
function axis.db.Connected()
    return axis.db.state == "connected"
end

---@param str string
---@return string
function axis.db.Escape(str)
    if axis.db.handle and axis.db.state == "connected" then
        return axis.db.handle:escape(tostring(str))
    end

    -- Only reachable before the connection is up; conservative and lossless for
    -- the values we store.
    return (string.gsub(tostring(str), "['\"\\]", "\\%0"))
end

---@param value any
---@return string
function axis.db.Value(value)
    if value == nil then return "NULL" end
    if isbool(value) then return value and "1" or "0" end
    if isnumber(value) then return string.format("%.14g", value) end

    return "'" .. axis.db.Escape(value) .. "'"
end

--- Queries issued before the connection is ready are queued rather than dropped,
--- so callers never have to care whether the handshake has finished.
---@param sql string
---@param onDone fun(rows: table[], lastInsert: number?)?
---@param onError fun(err: string)?
function axis.db.Query(sql, onDone, onError)
    if axis.db.state == "failed" then
        if onError then onError(axis.db.error or "database unavailable") end
        return
    end

    if axis.db.state ~= "connected" then
        axis.db.queue[#axis.db.queue + 1] = { sql, onDone, onError }
        return
    end

    local query = axis.db.handle:query(sql)

    query.onSuccess = function(q, rows)
        if onDone then onDone(rows or {}, q:lastInsert()) end
    end

    query.onError = function(_, err)
        axis.LogError("query failed: %s", err)
        axis.LogError("  sql: %s", sql)

        if onError then onError(err) end
    end

    query:start()
end

--- Runs a list of statements atomically. Used by the migrator and anywhere a
--- half-applied write would leave a character inconsistent.
---@param statements string[]
---@param onDone fun()?
---@param onError fun(err: string)?
function axis.db.Transaction(statements, onDone, onError)
    if axis.db.state ~= "connected" then
        axis.db.queue[#axis.db.queue + 1] = { statements, onDone, onError, true }
        return
    end

    local transaction = axis.db.handle:createTransaction()

    for _, sql in ipairs(statements) do
        transaction:addQuery(axis.db.handle:query(sql))
    end

    transaction.onSuccess = function() if onDone then onDone() end end

    transaction.onError = function(_, err)
        axis.LogError("transaction failed: %s", err)
        if onError then onError(err) end
    end

    transaction:start()
end

local function FlushQueue()
    local queue = axis.db.queue
    axis.db.queue = {}

    for _, entry in ipairs(queue) do
        if entry[4] then
            axis.db.Transaction(entry[1], entry[2], entry[3])
        else
            axis.db.Query(entry[1], entry[2], entry[3])
        end
    end
end

local SCHEMA = {
    [[CREATE TABLE IF NOT EXISTS axis_schema (
        id TINYINT UNSIGNED NOT NULL PRIMARY KEY,
        version INT UNSIGNED NOT NULL
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]],

    [[CREATE TABLE IF NOT EXISTS axis_characters (
        id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
        steamid64 VARCHAR(20) NOT NULL,
        name VARCHAR(64) NOT NULL,
        faction VARCHAR(32) NOT NULL,
        class VARCHAR(32) NOT NULL,
        `rank` VARCHAR(32) NOT NULL,
        model VARCHAR(160) DEFAULT NULL,
        data LONGTEXT DEFAULT NULL,
        jail_until INT UNSIGNED NOT NULL DEFAULT 0,
        jail_reason VARCHAR(160) DEFAULT NULL,
        created INT UNSIGNED NOT NULL,
        last_played INT UNSIGNED NOT NULL DEFAULT 0,
        INDEX idx_steamid (steamid64)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]],

    [[CREATE TABLE IF NOT EXISTS axis_spawnpoints (
        id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
        map VARCHAR(64) NOT NULL,
        faction VARCHAR(32) NOT NULL,
        class VARCHAR(32) DEFAULT NULL,
        kind ENUM('spawn','jail') NOT NULL DEFAULT 'spawn',
        pos_x FLOAT NOT NULL,
        pos_y FLOAT NOT NULL,
        pos_z FLOAT NOT NULL,
        ang_y FLOAT NOT NULL DEFAULT 0,
        INDEX idx_map (map)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]],
}

--- Run in sequence rather than as a transaction: DDL causes an implicit commit
--- in MySQL, so wrapping CREATE TABLE in one buys nothing and hides ordering.
local function Migrate(index)
    index = index or 1

    if index > #SCHEMA then
        axis.db.Query("REPLACE INTO axis_schema (id, version) VALUES (1, " .. SCHEMA_VERSION .. ");", function()
            axis.Log("schema ready (version %d)", SCHEMA_VERSION)
            hook.Run("AxisDatabaseReady")
        end)

        return
    end

    axis.db.Query(SCHEMA[index], function()
        Migrate(index + 1)
    end, function(err)
        axis.db.state = "failed"
        axis.db.error = "schema migration failed: " .. tostring(err)
        axis.LogError(axis.db.error)
    end)
end

function axis.db.Connect()
    if axis.db.state == "failed" and not mysqloo then
        axis.LogError("cannot connect - %s", axis.db.error)
        axis.LogError("players will be refused until this is fixed")
        return
    end

    local cfg = axis.config.GetDatabase()
    axis.db.state = "connecting"

    axis.Log("connecting to MariaDB at %s:%d as '%s' (credentials from %s)",
        cfg.host, cfg.port, cfg.user, cfg.source)

    axis.db.handle = mysqloo.connect(cfg.host, cfg.user, cfg.pass, cfg.name, cfg.port)

    axis.db.handle.onConnected = function()
        axis.db.state = "connected"
        axis.db.error = nil
        axis.Log("connected to MariaDB at %s:%d", cfg.host, cfg.port)

        -- The migrator has to run before anything the queue holds, so it is
        -- issued while the queue is still parked.
        Migrate()
        FlushQueue()
    end

    axis.db.handle.onConnectionFailed = function(_, err)
        axis.db.state = "failed"
        axis.db.error = err
        axis.LogError("connection to MariaDB failed: %s", err)
        axis.LogError("players will be refused until this is fixed")

        local queue = axis.db.queue
        axis.db.queue = {}

        for _, entry in ipairs(queue) do
            if entry[3] then entry[3](err) end
        end
    end

    axis.db.handle:connect()
end

hook.Add("Initialize", "AxisDatabaseConnect", function()
    axis.db.Connect()
end)

--- A dedicated server cannot meaningfully "fail to boot", so an unreachable
--- database is enforced at the door instead: nobody gets in without persistence.
hook.Add("CheckPassword", "AxisDatabaseGate", function()
    if axis.db.state == "failed" then
        return false, "Axis: database unavailable (" .. tostring(axis.db.error) .. ")"
    end
end)
