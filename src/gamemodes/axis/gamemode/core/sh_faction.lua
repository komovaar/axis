axis.faction = axis.faction or {}
axis.faction.stored = axis.faction.stored or {}
axis.faction.numericMap = axis.faction.numericMap or {}

--- A faction is the one layer that maps onto GMod's native team system, so
--- friendly fire, scoreboard grouping and anything else reading ply:Team() work
--- without a lookup. Class and rank live on the character instead.
---@param id string
---@param data table
---@return table
function axis.faction.Register(id, data)
    data.id = id
    data.name = data.name or id
    data.color = data.color or Color(150, 150, 150)

    -- Derived from the stored table rather than an upvalue counter, so a Lua
    -- refresh reuses the same index instead of colliding with the live map.
    local existing = axis.faction.stored[id]
    data.index = existing and existing.index or (table.Count(axis.faction.stored) + 1)

    axis.faction.stored[id] = data
    axis.faction.numericMap[data.index] = id

    team.SetUp(data.index, data.name, data.color)

    return data
end

---@param id string
---@return table|nil
function axis.faction.Get(id)
    return axis.faction.stored[id]
end

---@param index number
---@return table|nil
function axis.faction.GetByIndex(index)
    local id = axis.faction.numericMap[index]
    if not id then return nil end

    return axis.faction.stored[id]
end

---@return table<string, table>
function axis.faction.GetAll()
    return axis.faction.stored
end

--- Classes belonging to this faction, in registration order.
---@param id string
---@return table[]
function axis.faction.GetClasses(id)
    local out = {}

    for _, class in SortedPairs(axis.class.GetAll()) do
        if class.faction == id then out[#out + 1] = class end
    end

    return out
end

--- Ranks belonging to this faction, ordered low to high.
---@param id string
---@return table[]
function axis.faction.GetRanks(id)
    local out = {}

    for _, rank in pairs(axis.rank.GetAll()) do
        if rank.faction == id then out[#out + 1] = rank end
    end

    table.sort(out, function(a, b) return a.level < b.level end)

    return out
end
