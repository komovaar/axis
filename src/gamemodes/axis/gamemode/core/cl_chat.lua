--- Renders the typed segments built by core/sv_chat.lua. Player segments are
--- resolved here so a name always carries the sender's current rank colour, even
--- if it changed between the message being sent and displayed.
net.Receive("axisChat", function()
    net.ReadUInt(8) -- reserved

    local count = net.ReadUInt(8)
    local parts = {}

    for _ = 1, count do
        local kind = net.ReadUInt(3)

        if kind == axis.chat.SEG_COLOR then
            parts[#parts + 1] = net.ReadColor(false)
        elseif kind == axis.chat.SEG_PLAYER then
            local ply = net.ReadEntity()

            if IsValid(ply) then
                parts[#parts + 1] = ply:GetDisplayColor()
                parts[#parts + 1] = ply:GetDisplayName()
            else
                parts[#parts + 1] = Color(150, 150, 150)
                parts[#parts + 1] = "Someone"
            end
        else
            parts[#parts + 1] = net.ReadString()
        end
    end

    chat.AddText(unpack(parts))
end)

--- Sandbox draws Steam names above players; swap in the character identity.
hook.Add("HUDDrawTargetID", "AxisTargetID", function()
    local target = LocalPlayer():GetEyeTrace().Entity

    if not IsValid(target) or not target:IsPlayer() then return end
    if LocalPlayer():GetPos():DistToSqr(target:GetPos()) > 400 * 400 then return end

    local char = target:GetCharacter()
    if not char then return end

    local class = char:GetClassTable()
    local screen = (target:GetPos() + Vector(0, 0, 80)):ToScreen()

    draw.SimpleTextOutlined(char:GetDisplayName(), "TargetID", screen.x, screen.y,
        char:GetColor(), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)

    if class then
        draw.SimpleTextOutlined(class.name, "DermaDefaultBold", screen.x, screen.y + 18,
            Color(200, 200, 210), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
    end

    return true
end)
