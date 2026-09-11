surface.CreateFont("AxisJailTimer", { font = "Roboto", size = 34, weight = 700 })
surface.CreateFont("AxisJailLabel", { font = "Roboto", size = 18, weight = 500 })

hook.Add("HUDPaint", "AxisJailHUD", function()
    local ply = LocalPlayer()
    local remaining = axis.jail.GetRemaining(ply)

    if remaining <= 0 then return end

    local w, h = 240, 76
    local x, y = ScrW() * 0.5 - w * 0.5, 24

    draw.RoundedBox(6, x, y, w, h, Color(20, 20, 26, 220))
    draw.RoundedBox(6, x, y, w, 3, axis.config.color.error)

    draw.SimpleText(axis.jail.FormatTime(remaining), "AxisJailTimer", x + w * 0.5, y + 30,
        color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    local reason = axis.jail.GetReason(ply)

    draw.SimpleText(reason ~= "" and reason or "Detained", "AxisJailLabel", x + w * 0.5, y + 56,
        Color(190, 190, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

--- Nothing in the spawn menu is usable from a cell.
hook.Add("SpawnMenuOpen", "AxisJailNoSpawnMenu", function()
    if axis.jail.IsJailed(LocalPlayer()) then return false end
end)
