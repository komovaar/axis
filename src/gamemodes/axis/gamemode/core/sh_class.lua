axis.class = axis.class or {}
axis.class.stored = axis.class.stored or {}

--- A class is a role (Medic, Pilot, B1 Droid) - it owns the model, loadout and
--- attributes. It is not a rank and it is not a team index.
---@param id string
---@param data table
---@return table
function axis.class.Register(id, data)
    data.id = id
    data.name = data.name or id
    data.models = data.models or {}
    data.weapons = data.weapons or {}
    data.health = data.health or 100
    data.armor = data.armor or 0
    data.limit = data.limit or 0 -- 0 = unlimited
    data.whitelist = data.whitelist or false

    axis.class.stored[id] = data

    return data
end

---@param id string
---@return table|nil
function axis.class.Get(id)
    return axis.class.stored[id]
end

---@return table<string, table>
function axis.class.GetAll()
    return axis.class.stored
end

---@param ply Player
---@return table|nil
function axis.class.GetPlayerClass(ply)
    local char = IsValid(ply) and ply:GetCharacter()
    if not char then return nil end

    return axis.class.Get(char:GetClass())
end

--- How many connected players currently hold this class.
---@param id string
---@return number
function axis.class.GetCount(id)
    local count = 0

    for _, ply in ipairs(player.GetAll()) do
        local char = ply:GetCharacter()
        if char and char:GetClass() == id then count = count + 1 end
    end

    return count
end

--- Every gate a player must clear to hold a class, in one place so the character
--- select menu and the /class command agree on the answer.
---@param ply Player
---@param id string
---@return boolean, string? reason
function axis.class.CanSwitchTo(ply, id)
    local class = axis.class.Get(id)
    if not class then return false, "That class does not exist." end

    if not IsValid(ply) then return false, "That player is not connected." end

    local char = ply:GetCharacter()
    if not char then return false, "You have no active character." end

    if char:GetFaction() ~= class.faction then
        return false, "That class belongs to another faction."
    end

    if char:GetClass() == id then
        return false, "You already hold that class."
    end

    if class.minRank and not axis.rank.AtLeast(ply, class.minRank) then
        local rank = axis.rank.Get(class.minRank)
        return false, "That class requires the rank of " .. (rank and rank.name or class.minRank) .. "."
    end

    if class.limit > 0 and axis.class.GetCount(id) >= class.limit then
        return false, "That class is full."
    end

    if class.whitelist and not char:GetData("whitelist_" .. id, false) then
        return false, "You are not whitelisted for that class."
    end

    if class.CanSwitchTo then
        local ok, reason = class.CanSwitchTo(class, ply)
        if ok == false then return false, reason or "You cannot take that class." end
    end

    return true
end
