axis.char = axis.char or {}
axis.char.loaded = axis.char.loaded or {}

--- Characters get their own metatable rather than methods bolted onto Player.
--- Entity already defines GetClass/SetClass, and shadowing those on the Player
--- meta would break every engine caller that expects the entity classname.
local CHAR = axis.char.meta or {}
CHAR.__index = CHAR
CHAR.__tostring = function(self) return "character[" .. tostring(self.id) .. "][" .. tostring(self.name) .. "]" end
axis.char.meta = CHAR

---@param vars table
---@return table
function axis.char.New(vars)
    local char = setmetatable({}, CHAR)

    char.id = tonumber(vars.id) or 0
    char.steamid64 = tostring(vars.steamid64 or "")
    char.name = vars.name or "Unnamed"
    char.faction = vars.faction
    char.class = vars.class
    char.rank = vars.rank
    char.model = vars.model
    char.data = vars.data or {}
    char.jailUntil = tonumber(vars.jailUntil) or 0
    char.jailReason = vars.jailReason
    char.created = tonumber(vars.created) or os.time()
    char.lastPlayed = tonumber(vars.lastPlayed) or 0

    return char
end

---@param id number
---@return table|nil
function axis.char.Get(id)
    return axis.char.loaded[id]
end

function CHAR:GetID() return self.id end
function CHAR:GetSteamID64() return self.steamid64 end
function CHAR:GetName() return self.name end
function CHAR:GetFaction() return self.faction end
function CHAR:GetClass() return self.class end
function CHAR:GetRank() return self.rank end
function CHAR:GetModel() return self.model end
function CHAR:GetJailUntil() return self.jailUntil end
function CHAR:GetJailReason() return self.jailReason end

---@return table|nil
function CHAR:GetFactionTable() return axis.faction.Get(self.faction) end

---@return table|nil
function CHAR:GetClassTable() return axis.class.Get(self.class) end

---@return table|nil
function CHAR:GetRankTable() return axis.rank.Get(self.rank) end

--- The colour a character's name renders in - rank overrides faction, so a
--- Commander reads differently from a Private in chat and on the scoreboard.
---@return table
function CHAR:GetColor()
    local rank = self:GetRankTable()
    if rank and rank.color then return rank.color end

    local faction = self:GetFactionTable()
    if faction and faction.color then return faction.color end

    return axis.config.color.default
end

--- "CPT Rex" - the name as it should appear in chat and on the scoreboard.
---@return string
function CHAR:GetDisplayName()
    local rank = self:GetRankTable()
    if rank and rank.abbreviation ~= "" then
        return rank.abbreviation .. " " .. self.name
    end

    return self.name
end

---@return Player|nil
function CHAR:GetPlayer()
    if IsValid(self.player) then return self.player end

    for _, ply in ipairs(player.GetAll()) do
        if ply:SteamID64() == self.steamid64 and ply.axisCharID == self.id then
            self.player = ply
            return ply
        end
    end

    return nil
end

---@param key string
---@param default any
---@return any
function CHAR:GetData(key, default)
    local value = self.data[key]
    if value == nil then return default end

    return value
end

if not SERVER then return end

---@param key string
---@param value any
function CHAR:SetData(key, value)
    self.data[key] = value
    self:MarkDirty()
end

function CHAR:MarkDirty()
    self.dirty = true
end

---@param name string
function CHAR:SetName(name)
    self.name = name
    self:MarkDirty()
    self:Sync()
end

---@param model string
function CHAR:SetModel(model)
    self.model = model
    self:MarkDirty()
    self:Sync()

    local ply = self:GetPlayer()
    if IsValid(ply) then ply:SetModel(model) end
end

--- Moves the character to another faction, resetting class and rank to that
--- faction's defaults because the old ones belong to the old side.
---@param id string
---@return boolean
function CHAR:SetFaction(id)
    local faction = axis.faction.Get(id)
    if not faction then return false end

    self.faction = id
    self:SetRank(faction.defaultRank, true)
    self:SetClass(faction.defaultClass, true)

    local ply = self:GetPlayer()
    if IsValid(ply) then ply:SetTeam(faction.index) end

    self:MarkDirty()
    self:Sync()

    return true
end

--- `force` skips the eligibility gates - used when applying faction defaults and
--- by staff commands, never by a player switching class themselves.
---@param id string
---@param force boolean?
---@return boolean, string? reason
function CHAR:SetClass(id, force)
    local class = axis.class.Get(id)
    if not class then return false, "That class does not exist." end

    local ply = self:GetPlayer()

    if not force then
        local ok, reason = axis.class.CanSwitchTo(ply, id)
        if not ok then return false, reason end
    end

    local previous = axis.class.Get(self.class)

    if previous and previous.OnLeave and IsValid(ply) then
        previous.OnLeave(previous, ply)
    end

    self.class = id

    -- A class change usually means a new body, so drop any per-character model
    -- override that belonged to the old class.
    if not self.model or (previous and table.HasValue(previous.models, self.model)) then
        self.model = class.models[1]
    end

    self:MarkDirty()
    self:Sync()

    if IsValid(ply) then
        ply:Spawn()

        if class.OnJoin then class.OnJoin(class, ply) end
    end

    return true
end

---@param id string
---@param silent boolean?
---@return boolean
function CHAR:SetRank(id, silent)
    local rank = axis.rank.Get(id)
    if not rank then return false end

    self.rank = id
    self:MarkDirty()
    self:Sync()

    local ply = self:GetPlayer()

    if IsValid(ply) then
        -- Ranks can grant loadout and model overrides, so refresh the body.
        if not silent then ply:Spawn() end
        if rank.OnAssigned then rank.OnAssigned(rank, ply) end
    end

    return true
end
