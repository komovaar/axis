axis.spawn.showMarkers = axis.spawn.showMarkers or false

--- Read order must mirror axis.spawn.Sync in core/sv_spawnpoint.lua.
net.Receive("axisSpawnSync", function()
    local count = net.ReadUInt(16)
    axis.spawn.points = {}

    for _ = 1, count do
        local id = net.ReadUInt(32)

        axis.spawn.points[id] = {
            id = id,
            faction = net.ReadString(),
            class = net.ReadString(),
            kind = net.ReadString(),
            pos = net.ReadVector(),
            ang = net.ReadAngle(),
        }
    end
end)

hook.Add("PostDrawTranslucentRenderables", "AxisSpawnMarkers", function(_, skybox)
    if skybox or not axis.spawn.showMarkers then return end

    local eye = EyePos()

    for _, point in pairs(axis.spawn.points) do
        if eye:DistToSqr(point.pos) > 4000 * 4000 then continue end

        local faction = axis.faction.Get(point.faction)
        local colour = point.kind == axis.spawn.KIND_JAIL
            and Color(255, 140, 60)
            or (faction and faction.color or color_white)

        render.SetColorMaterial()
        render.DrawWireframeBox(point.pos, point.ang, Vector(-16, -16, 0), Vector(16, 16, 72), colour, true)

        local label = string.format("#%d %s%s", point.id, point.faction,
            point.class ~= "" and (" / " .. point.class) or "")

        cam.Start3D2D(point.pos + Vector(0, 0, 78), Angle(0, EyeAngles().y - 90, 90), 0.2)
            draw.SimpleText(label, "DermaLarge", 0, 0, colour, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText(string.upper(point.kind), "DermaDefaultBold", 0, 34,
                colour, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        cam.End3D2D()
    end
end)

concommand.Add("axis_spawnmarkers", function()
    axis.spawn.showMarkers = not axis.spawn.showMarkers
    chat.AddText(axis.config.color.info, "[Axis] ", color_white,
        "Spawnpoint markers " .. (axis.spawn.showMarkers and "shown." or "hidden."))
end, nil, "Toggle the Axis spawnpoint overlay.")
