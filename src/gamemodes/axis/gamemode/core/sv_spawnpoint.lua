util.AddNetworkString("axisSpawnSync")

--- Sends the whole map's points. Small enough to broadcast wholesale, and the
--- client needs them for the editor overlay.
---@param receiver Player?
function axis.spawn.Sync(receiver)
    local points = {}

    for _, point in pairs(axis.spawn.points) do
        points[#points + 1] = point
    end

    net.Start("axisSpawnSync")
        net.WriteUInt(#points, 16)

        for _, point in ipairs(points) do
            net.WriteUInt(point.id, 32)
            net.WriteString(point.faction)
            net.WriteString(point.class or "")
            net.WriteString(point.kind)
            net.WriteVector(point.pos)
            net.WriteAngle(point.ang)
        end

    if receiver then net.Send(receiver) else net.Broadcast() end
end

function axis.spawn.Load()
    local map = game.GetMap()

    axis.db.Query("SELECT * FROM axis_spawnpoints WHERE map = " .. axis.db.Value(map) .. ";", function(rows)
        axis.spawn.points = {}

        for _, row in ipairs(rows) do
            local id = tonumber(row.id)

            axis.spawn.points[id] = {
                id = id,
                map = row.map,
                faction = row.faction,
                class = row.class,
                kind = row.kind,
                pos = Vector(tonumber(row.pos_x), tonumber(row.pos_y), tonumber(row.pos_z)),
                ang = Angle(0, tonumber(row.ang_y), 0),
            }
        end

        axis.Log("loaded %d spawnpoint(s) for %s", table.Count(axis.spawn.points), map)
        axis.spawn.Sync()
    end)
end

---@param factionID string
---@param classID string?
---@param kind string
---@param pos Vector
---@param ang Angle
---@param callback fun(point: table?, err: string?)?
function axis.spawn.Add(factionID, classID, kind, pos, ang, callback)
    local map = game.GetMap()

    local sql = string.format(
        "INSERT INTO axis_spawnpoints (map, faction, class, kind, pos_x, pos_y, pos_z, ang_y) " ..
        "VALUES (%s, %s, %s, %s, %f, %f, %f, %f);",
        axis.db.Value(map),
        axis.db.Value(factionID),
        classID and classID ~= "" and axis.db.Value(classID) or "NULL",
        axis.db.Value(kind),
        pos.x, pos.y, pos.z, ang.y
    )

    axis.db.Query(sql, function(_, lastInsert)
        local point = {
            id = lastInsert,
            map = map,
            faction = factionID,
            class = classID ~= "" and classID or nil,
            kind = kind,
            pos = pos,
            ang = Angle(0, ang.y, 0),
        }

        axis.spawn.points[lastInsert] = point
        axis.spawn.Sync()

        if callback then callback(point) end
    end, function(err)
        if callback then callback(nil, err) end
    end)
end

---@param id number
---@param callback fun(success: boolean)?
function axis.spawn.Remove(id, callback)
    axis.db.Query("DELETE FROM axis_spawnpoints WHERE id = " .. tonumber(id) .. ";", function()
        axis.spawn.points[id] = nil
        axis.spawn.Sync()

        if callback then callback(true) end
    end, function()
        if callback then callback(false) end
    end)
end

--- Places a spawning player. Falls back to the map's own entities so a fresh
--- server with no points configured is still playable.
---@param ply Player
function axis.spawn.Apply(ply)
    if axis.jail.IsJailed(ply) then
        axis.jail.SendToCell(ply)
        return
    end

    local point = axis.spawn.PickFor(ply, axis.spawn.KIND_SPAWN)

    if not point then
        local fallback = ents.FindByClass("info_player_start")

        if #fallback > 0 then
            local ent = fallback[math.random(#fallback)]
            ply:SetPos(ent:GetPos())
            ply:SetEyeAngles(ent:GetAngles())
        end

        return
    end

    ply:SetPos(point.pos)
    ply:SetEyeAngles(point.ang)
end

hook.Add("AxisDatabaseReady", "AxisSpawnLoad", function()
    axis.spawn.Load()
end)
