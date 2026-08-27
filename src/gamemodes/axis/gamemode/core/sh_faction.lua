axis.faction = axis.faction or {}
axis.faction.stored = axis.faction.stored or {}

---@param id string
---@param data table
function axis.faction.Register(id, data)
    data.id = id
    axis.faction.stored[id] = data
end

---@param id string
---@return table|nil
function axis.faction.Get(id)
    return axis.faction.stored[id]
end

---comment
---@return table
function axis.faction.GetAll()
    return axis.faction.stored
end