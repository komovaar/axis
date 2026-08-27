axis.team = axis.team or {}
axis.team.stored = axis.team.stored or {}
axis.team.numericMap = axis.team.numericMap or {}
axis.team.defaultIndex = axis.team.defaultIndex or 1

local teamIndex = 1

---@param id string
---@param data table
function axis.team.Register(id, data)
    data.id = id
    data.index = teamIndex

    axis.team.stored[id] = data
    local color = data.color or Color(150, 150, 150)
    team.SetUp(data.index, data.name or "Unknown Team", color)

    teamIndex = teamIndex + 1
end

---@param id string
---@return table|nil
function axis.team.Get(id)
    return axis.team.stored[id]
end

---@param index number
---@return table|nil
function axis.team.GetByIndex(index)
    local id = axis.team.numericMap[index]
    if not id then return nil end
    return axis.team.stored[id]
end

---@param id string
function axis.team.SetDefault(id)
    local data = axis.team.Get(id)
    if data then
        axis.team.defaultIndex = data.index
    end
end
