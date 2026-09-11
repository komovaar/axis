axis.rank = axis.rank or {}
axis.rank.stored = axis.rank.stored or {}

--- Ranks form a per-faction ladder. `level` orders them and drives AtLeast
--- comparisons; `permissions` is the in-character authority a rank carries and is
--- unrelated to CAMI staff privileges (core/sh_privilege.lua).
---@param id string
---@param data table
---@return table
function axis.rank.Register(id, data)
    data.id = id
    data.name = data.name or id
    data.abbreviation = data.abbreviation or string.upper(string.sub(data.name, 1, 3))
    data.level = data.level or 1
    data.permissions = data.permissions or {}

    axis.rank.stored[id] = data

    return data
end

---@param id string
---@return table|nil
function axis.rank.Get(id)
    return axis.rank.stored[id]
end

---@return table<string, table>
function axis.rank.GetAll()
    return axis.rank.stored
end

--- Resolves whichever rank a player currently holds, or nil without a character.
---@param ply Player
---@return table|nil
function axis.rank.GetPlayerRank(ply)
    local char = IsValid(ply) and ply:GetCharacter()
    if not char then return nil end

    return axis.rank.Get(char:GetRank())
end

---@param ply Player
---@param permission string
---@return boolean
function axis.rank.HasPermission(ply, permission)
    local rank = axis.rank.GetPlayerRank(ply)
    if not rank then return false end

    return rank.permissions[permission] == true
end

--- True when the player's rank sits at or above `rankID` within the same faction.
--- Cross-faction comparisons are meaningless and always fail.
---@param ply Player
---@param rankID string
---@return boolean
function axis.rank.AtLeast(ply, rankID)
    local rank = axis.rank.GetPlayerRank(ply)
    local target = axis.rank.Get(rankID)

    if not rank or not target then return false end
    if rank.faction ~= target.faction then return false end

    return rank.level >= target.level
end
