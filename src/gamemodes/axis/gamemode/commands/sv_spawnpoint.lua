local PRIVILEGE = "Axis - Edit Spawnpoints"

--- Points are placed where the caller stands, facing the way they face, which is
--- the only sane authoring gesture in a first-person editor.
local function PlaceAt(ply)
    return ply:GetPos(), Angle(0, ply:EyeAngles().y, 0)
end

axis.command.Register("spawnadd", {
    description = "Place a faction spawnpoint where you are standing.",
    privilege = PRIVILEGE,
    arguments = {
        { name = "faction", type = "faction" },
        { name = "class", type = "class", optional = true },
    },
    OnRun = function(ply, faction, class)
        if class and class.faction ~= faction.id then
            axis.chat.Notify(ply, "error",
                class.name .. " belongs to " .. class.faction .. ", not " .. faction.id .. ".")
            return
        end

        local pos, ang = PlaceAt(ply)

        axis.spawn.Add(faction.id, class and class.id, axis.spawn.KIND_SPAWN, pos, ang, function(point, err)
            if not IsValid(ply) then return end

            if not point then
                axis.chat.Notify(ply, "error", "Could not save that spawnpoint: " .. tostring(err))
                return
            end

            axis.chat.Notify(ply, "success", string.format("Placed spawnpoint #%d for %s%s.",
                point.id, faction.name, class and (" / " .. class.name) or ""))
        end)
    end,
})

axis.command.Register("jailadd", {
    description = "Place a jail cell for a faction where you are standing.",
    privilege = PRIVILEGE,
    arguments = {
        { name = "faction", type = "faction" },
    },
    OnRun = function(ply, faction)
        local pos, ang = PlaceAt(ply)

        axis.spawn.Add(faction.id, nil, axis.spawn.KIND_JAIL, pos, ang, function(point, err)
            if not IsValid(ply) then return end

            if not point then
                axis.chat.Notify(ply, "error", "Could not save that jail cell: " .. tostring(err))
                return
            end

            axis.chat.Notify(ply, "success",
                string.format("Placed jail cell #%d for %s.", point.id, faction.name))
        end)
    end,
})

axis.command.Register("spawnremove", {
    description = "Delete the nearest spawnpoint, or one by id.",
    aliases = { "spawndel" },
    privilege = PRIVILEGE,
    arguments = {
        { name = "id", type = "number", optional = true },
    },
    OnRun = function(ply, id)
        local point = id and axis.spawn.Get(id)
            or axis.spawn.FindNearest(ply:GetPos(), axis.config.spawnRemoveRadius)

        if not point then
            axis.chat.Notify(ply, "error", id
                and ("No spawnpoint with id " .. id .. ".")
                or "No spawnpoint within range - stand closer, or pass an id.")
            return
        end

        axis.spawn.Remove(point.id, function(success)
            if not IsValid(ply) then return end

            if success then
                axis.chat.Notify(ply, "success", "Removed spawnpoint #" .. point.id .. ".")
            else
                axis.chat.Notify(ply, "error", "Could not remove spawnpoint #" .. point.id .. ".")
            end
        end)
    end,
})

axis.command.Register("spawnlist", {
    description = "List the spawnpoints configured on this map.",
    privilege = PRIVILEGE,
    arguments = {},
    OnRun = function(ply)
        local points = axis.spawn.GetAll()

        if table.IsEmpty(points) then
            axis.chat.Notify(ply, "info", "No spawnpoints configured on " .. game.GetMap() .. ".")
            return
        end

        axis.chat.Notify(ply, "info", "Spawnpoints on " .. game.GetMap() .. ":")

        for _, point in SortedPairsByMemberValue(points, "id") do
            axis.chat.Send(ply, axis.config.color.info, string.format("  #%d  ", point.id),
                color_white, string.format("%s%s  (%s)  %s",
                    point.faction,
                    point.class and (" / " .. point.class) or "",
                    point.kind,
                    tostring(point.pos)))
        end

        axis.chat.Notify(ply, "info", "Use axis_spawnmarkers in console to see them in the world.")
    end,
})
