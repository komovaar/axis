axis.faction = axis.faction or {}
axis.faction.stored = axis.faction.stored or {}

---@param id string
---@param data table
function axis.faction.Register(id, data)
    data.id = id
    prop.faction.stored[id] = data
end

---@param id string
---@return table|nil
function axis.faction.Get(id)
    return prop.faction.stored[id]
end

---comment
---@return table
function axis.faction.GetAll()
    return prop.faction.stored
end