util.AddNetworkString("axisCharSync")
util.AddNetworkString("axisCharData")
util.AddNetworkString("axisCharList")
util.AddNetworkString("axisCharSelect")
util.AddNetworkString("axisCharCreate")
util.AddNetworkString("axisCharDelete")
util.AddNetworkString("axisCharReady")

local CHAR = axis.char.meta

--- Public fields go to everyone so chat, scoreboard and nameplates can render a
--- character without asking the server; `data` is private and only the owner
--- receives it.
---@param receiver Player?
function CHAR:Sync(receiver)
    net.Start("axisCharSync")
        net.WriteUInt(self.id, 32)
        net.WriteString(self.steamid64)
        net.WriteString(self.name)
        net.WriteString(self.faction or "")
        net.WriteString(self.class or "")
        net.WriteString(self.rank or "")
        net.WriteString(self.model or "")

    if receiver then net.Send(receiver) else net.Broadcast() end
end

function CHAR:SyncData()
    local ply = self:GetPlayer()
    if not IsValid(ply) then return end

    net.Start("axisCharData")
        net.WriteUInt(self.id, 32)
        net.WriteString(util.TableToJSON(self.data))
    net.Send(ply)
end

---@param callback fun(success: boolean)?
function CHAR:Save(callback)
    if self.id == 0 then
        if callback then callback(false) end
        return
    end

    self.dirty = false

    local sql = string.format(
        "UPDATE axis_characters SET name=%s, faction=%s, class=%s, `rank`=%s, model=%s, data=%s, " ..
        "jail_until=%s, jail_reason=%s, last_played=%s WHERE id=%d;",
        axis.db.Value(self.name),
        axis.db.Value(self.faction),
        axis.db.Value(self.class),
        axis.db.Value(self.rank),
        axis.db.Value(self.model),
        axis.db.Value(util.TableToJSON(self.data)),
        axis.db.Value(self.jailUntil),
        axis.db.Value(self.jailReason),
        axis.db.Value(os.time()),
        self.id
    )

    axis.db.Query(sql, function()
        if callback then callback(true) end
    end, function()
        -- Keep the character dirty so the next flush retries it.
        self.dirty = true
        if callback then callback(false) end
    end)
end

--- Applies the character to its owner: team from faction, then a respawn so the
--- class loadout, model and attributes are built by GM:PlayerSpawn.
---@param ply Player
function CHAR:Apply(ply)
    self.player = ply
    ply.axisChar = self
    ply.axisCharID = self.id
    ply:SetNW2Int("axisCharID", self.id)

    local faction = self:GetFactionTable()
    ply:SetTeam(faction and faction.index or 0)

    axis.char.loaded[self.id] = self

    self:Sync()
    self:SyncData()

    ply:Spawn()

    local class = self:GetClassTable()
    if class and class.OnJoin then class.OnJoin(class, ply) end

    hook.Run("AxisCharacterLoaded", ply, self)
end

---@param row table
---@return table
local function CharacterFromRow(row)
    return axis.char.New({
        id = row.id,
        steamid64 = row.steamid64,
        name = row.name,
        faction = row.faction,
        class = row.class,
        rank = row.rank,
        model = row.model,
        data = row.data and util.JSONToTable(row.data) or {},
        jailUntil = row.jail_until,
        jailReason = row.jail_reason,
        created = row.created,
        lastPlayed = row.last_played,
    })
end

--- Loads every character a SteamID owns into ply.axisCharacters, then hands the
--- list to the client so the select menu can be shown.
---@param ply Player
---@param callback fun(characters: table[])?
function axis.char.LoadFor(ply, callback)
    local steamID = ply:SteamID64()

    axis.db.Query("SELECT * FROM axis_characters WHERE steamid64 = " .. axis.db.Value(steamID) .. ";", function(rows)
        if not IsValid(ply) then return end

        local characters = {}

        for _, row in ipairs(rows) do
            local char = CharacterFromRow(row)
            characters[#characters + 1] = char
            axis.char.loaded[char.id] = char
        end

        ply.axisCharacters = characters

        -- The client may not have finished loading yet; the ready handshake
        -- below sends the list again once it has.
        if ply.axisReady then axis.char.SendList(ply) end

        if callback then callback(characters) end
    end, function(err)
        if IsValid(ply) then
            ply:Kick("Axis: could not load your characters (" .. tostring(err) .. ")")
        end
    end)
end

---@param ply Player
function axis.char.SendList(ply)
    local characters = ply.axisCharacters or {}

    net.Start("axisCharList")
        net.WriteUInt(#characters, 8)

        for _, char in ipairs(characters) do
            net.WriteUInt(char.id, 32)
            net.WriteString(char.name)
            net.WriteString(char.faction or "")
            net.WriteString(char.class or "")
            net.WriteString(char.rank or "")
            net.WriteString(char.model or "")
        end
    net.Send(ply)
end

---@param name string
---@return boolean, string? reason
function axis.char.ValidateName(name)
    name = string.Trim(name or "")

    if #name < axis.config.nameMinLength then
        return false, "Names must be at least " .. axis.config.nameMinLength .. " characters."
    end

    if #name > axis.config.nameMaxLength then
        return false, "Names must be at most " .. axis.config.nameMaxLength .. " characters."
    end

    if not string.match(name, "^[%a][%a%d%s'%-%.]*$") then
        return false, "Names may only contain letters, digits, spaces, apostrophes, hyphens and periods."
    end

    return true
end

--- Every character starts in axis.config.defaultFaction with that faction's
--- default class and rank. The faction is deliberately not client input: the
--- creation menu offers no choice, and staff reassign afterwards with
--- /setfaction. axis.Validate checks the configured faction exists at boot.
---@param ply Player
---@param name string
---@param callback fun(char: table?, err: string?)?
function axis.char.Create(ply, name, callback)
    local factionID = axis.config.defaultFaction
    local faction = axis.faction.Get(factionID)

    if not faction then
        if callback then
            callback(nil, "The default faction is misconfigured - tell an administrator.")
        end

        return
    end

    local valid, reason = axis.char.ValidateName(name)
    if not valid then
        if callback then callback(nil, reason) end
        return
    end

    if #(ply.axisCharacters or {}) >= axis.config.maxCharacters then
        if callback then callback(nil, "You already have the maximum number of characters.") end
        return
    end

    name = string.Trim(name)

    local class = axis.class.Get(faction.defaultClass)
    local model = class and class.models[1] or "models/player/kleiner.mdl"
    local now = os.time()

    local sql = string.format(
        "INSERT INTO axis_characters (steamid64, name, faction, class, `rank`, model, data, created, last_played) " ..
        "VALUES (%s, %s, %s, %s, %s, %s, %s, %d, %d);",
        axis.db.Value(ply:SteamID64()),
        axis.db.Value(name),
        axis.db.Value(factionID),
        axis.db.Value(faction.defaultClass),
        axis.db.Value(faction.defaultRank),
        axis.db.Value(model),
        axis.db.Value("{}"),
        now, now
    )

    axis.db.Query(sql, function(_, lastInsert)
        if not IsValid(ply) then return end

        local char = axis.char.New({
            id = lastInsert,
            steamid64 = ply:SteamID64(),
            name = name,
            faction = factionID,
            class = faction.defaultClass,
            rank = faction.defaultRank,
            model = model,
            created = now,
        })

        ply.axisCharacters = ply.axisCharacters or {}
        ply.axisCharacters[#ply.axisCharacters + 1] = char
        axis.char.loaded[char.id] = char

        axis.char.SendList(ply)

        if callback then callback(char) end
    end, function(err)
        if callback then callback(nil, err) end
    end)
end

---@param ply Player
---@param id number
---@return table|nil
function axis.char.GetOwned(ply, id)
    for _, char in ipairs(ply.axisCharacters or {}) do
        if char.id == id then return char end
    end

    return nil
end

net.Receive("axisCharSelect", function(_, ply)
    local id = net.ReadUInt(32)
    local char = axis.char.GetOwned(ply, id)

    if not char then
        axis.chat.Notify(ply, "error", "That character does not belong to you.")
        return
    end

    if ply.axisChar == char then return end

    -- Persist whatever the previous character was doing before swapping away.
    if ply.axisChar then ply.axisChar:Save() end

    char:Apply(ply)
end)

net.Receive("axisCharCreate", function(_, ply)
    local name = net.ReadString()

    axis.char.Create(ply, name, function(char, err)
        if not IsValid(ply) then return end

        if not char then
            axis.chat.Notify(ply, "error", err or "Could not create that character.")
            return
        end

        axis.chat.Notify(ply, "success", "Created " .. char:GetName() .. ".")
    end)
end)

net.Receive("axisCharDelete", function(_, ply)
    local id = net.ReadUInt(32)
    local char = axis.char.GetOwned(ply, id)

    if not char then return end

    if ply.axisChar == char then
        axis.chat.Notify(ply, "error", "You cannot delete the character you are playing.")
        return
    end

    axis.db.Query("DELETE FROM axis_characters WHERE id = " .. char.id .. ";", function()
        if not IsValid(ply) then return end

        axis.char.loaded[char.id] = nil

        for i, other in ipairs(ply.axisCharacters or {}) do
            if other.id == char.id then
                table.remove(ply.axisCharacters, i)
                break
            end
        end

        axis.char.SendList(ply)
        axis.chat.Notify(ply, "success", "Deleted " .. char:GetName() .. ".")
    end)
end)

hook.Add("PlayerInitialSpawn", "AxisCharacterLoad", function(ply)
    ply.axisReady = false
    axis.char.LoadFor(ply)
end)

--- Net messages sent during PlayerInitialSpawn are unreliable - the client is
--- still loading. It tells us when it is ready, and everything initial is sent
--- from here instead of a guessed delay.
net.Receive("axisCharReady", function(_, ply)
    if ply.axisReady then return end
    ply.axisReady = true

    for _, other in ipairs(player.GetAll()) do
        if other.axisChar then other.axisChar:Sync(ply) end
    end

    axis.spawn.Sync(ply)

    if ply.axisCharacters then axis.char.SendList(ply) end
end)

hook.Add("PlayerDisconnected", "AxisCharacterSave", function(ply)
    if ply.axisChar then
        ply.axisChar:Save()
        axis.char.loaded[ply.axisChar.id] = nil
    end

    for _, char in ipairs(ply.axisCharacters or {}) do
        axis.char.loaded[char.id] = nil
    end
end)

hook.Add("ShutDown", "AxisCharacterSaveAll", function()
    for _, ply in ipairs(player.GetAll()) do
        if ply.axisChar then ply.axisChar:Save() end
    end
end)

timer.Create("AxisCharacterFlush", axis.config.saveInterval, 0, function()
    for _, ply in ipairs(player.GetAll()) do
        if ply.axisChar and ply.axisChar.dirty then ply.axisChar:Save() end
    end
end)
