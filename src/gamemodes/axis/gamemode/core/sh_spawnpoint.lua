axis.spawn = axis.spawn or {}
axis.spawn.points = axis.spawn.points or {}

--- Jail cells are spawnpoints with kind = "jail", so both share one table, one
--- editor and one lookup path.
axis.spawn.KIND_SPAWN = "spawn"
axis.spawn.KIND_JAIL = "jail"

---@param id number
---@return table|nil
function axis.spawn.Get(id)
    return axis.spawn.points[id]
end

---@return table<number, table>
function axis.spawn.GetAll()
    return axis.spawn.points
end

--- Points matching a faction, preferring ones bound to the given class. A class
--- with its own points never falls back to the faction-wide pool; a class
--- without any uses it.
---@param factionID string
---@param classID string?
---@param kind string?
---@return table[]
function axis.spawn.Find(factionID, classID, kind)
    kind = kind or axis.spawn.KIND_SPAWN

    local exact, general = {}, {}

    for _, point in pairs(axis.spawn.points) do
        if point.faction == factionID and point.kind == kind then
            if point.class and point.class ~= "" then
                if point.class == classID then exact[#exact + 1] = point end
            else
                general[#general + 1] = point
            end
        end
    end

    return #exact > 0 and exact or general
end

---@param ply Player
---@param kind string?
---@return table|nil
function axis.spawn.PickFor(ply, kind)
    local char = ply:GetCharacter()
    if not char then return nil end

    local points = axis.spawn.Find(char:GetFaction(), char:GetClass(), kind)
    if #points == 0 then return nil end

    return points[math.random(#points)]
end

---@param pos Vector
---@param radius number
---@return table|nil
function axis.spawn.FindNearest(pos, radius)
    local best, bestDist

    for _, point in pairs(axis.spawn.points) do
        local dist = point.pos:DistToSqr(pos)

        if dist <= radius * radius and (not bestDist or dist < bestDist) then
            best, bestDist = point, dist
        end
    end

    return best
end
