axis.char.list = axis.char.list or {}

net.Receive("axisCharSync", function()
    local id = net.ReadUInt(32)

    local char = axis.char.loaded[id] or axis.char.New({ id = id })

    char.steamid64 = net.ReadString()
    char.name = net.ReadString()
    char.faction = net.ReadString()
    char.class = net.ReadString()
    char.rank = net.ReadString()
    char.model = net.ReadString()

    axis.char.loaded[id] = char
end)

net.Receive("axisCharData", function()
    local id = net.ReadUInt(32)
    local data = util.JSONToTable(net.ReadString()) or {}

    local char = axis.char.loaded[id]
    if char then char.data = data end
end)

net.Receive("axisCharList", function()
    local count = net.ReadUInt(8)
    local characters = {}

    for _ = 1, count do
        local char = axis.char.New({
            id = net.ReadUInt(32),
            name = net.ReadString(),
            faction = net.ReadString(),
            class = net.ReadString(),
            rank = net.ReadString(),
            model = net.ReadString(),
        })

        characters[#characters + 1] = char
        axis.char.loaded[char.id] = char
    end

    axis.char.list = characters

    if IsValid(axis.char.menu) then
        axis.char.menu:Rebuild()
    elseif not LocalPlayer():HasCharacter() then
        axis.char.OpenMenu()
    end
end)

local function StyledButton(parent, text, colour, onClick)
    local button = parent:Add("DButton")
    button:SetText(text)
    button:SetTextColor(color_white)
    button:SetFont("DermaDefaultBold")
    button.DoClick = onClick
    button.Paint = function(self, w, h)
        local shade = self:IsHovered() and 30 or 0
        surface.SetDrawColor(colour.r + shade, colour.g + shade, colour.b + shade, 255)
        surface.DrawRect(0, 0, w, h)
    end

    return button
end

function axis.char.OpenMenu()
    if IsValid(axis.char.menu) then axis.char.menu:Remove() end

    local frame = vgui.Create("DFrame")
    axis.char.menu = frame

    frame:SetSize(math.min(ScrW() - 120, 900), math.min(ScrH() - 120, 560))
    frame:Center()
    frame:SetTitle("")
    frame:MakePopup()
    frame.Paint = function(_, w, h)
        surface.SetDrawColor(22, 24, 30, 245)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(40, 44, 54, 255)
        surface.DrawRect(0, 0, w, 40)

        draw.SimpleText("AXIS", "DermaLarge", 16, 20, axis.config.color.info, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Select a character", "DermaDefaultBold", 96, 20,
            Color(150, 155, 165), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    -- Closing without a character would leave the player stuck spectating.
    frame.OnClose = function()
        if not LocalPlayer():HasCharacter() then
            timer.Simple(0.1, function()
                if not LocalPlayer():HasCharacter() then axis.char.OpenMenu() end
            end)
        end
    end

    local body = frame:Add("DPanel")
    body:Dock(FILL)
    body:DockMargin(12, 48, 12, 12)
    body.Paint = nil

    local preview = body:Add("DModelPanel")
    preview:Dock(RIGHT)
    preview:SetWide(280)
    preview:SetFOV(38)
    preview:SetModel("models/player/kleiner.mdl")
    preview:SetCamPos(Vector(70, 0, 62))
    preview:SetLookAt(Vector(0, 0, 60))
    preview.LayoutEntity = function(_, ent) ent:SetAngles(Angle(0, RealTime() * 25 % 360, 0)) end

    local scroll = body:Add("DScrollPanel")
    scroll:Dock(FILL)
    scroll:DockMargin(0, 0, 12, 0)

    local footer = frame:Add("DPanel")
    footer:Dock(BOTTOM)
    footer:SetTall(0)
    footer.Paint = nil

    function frame:Rebuild()
        scroll:Clear()

        for _, char in ipairs(axis.char.list) do
            local faction = axis.faction.Get(char.faction)
            local class = axis.class.Get(char.class)
            local rank = axis.rank.Get(char.rank)

            local row = scroll:Add("DPanel")
            row:Dock(TOP)
            row:DockMargin(0, 0, 0, 8)
            row:SetTall(64)
            row.Paint = function(self, w, h)
                surface.SetDrawColor(34, 37, 46, 255)
                surface.DrawRect(0, 0, w, h)

                local colour = faction and faction.color or axis.config.color.default
                surface.SetDrawColor(colour.r, colour.g, colour.b, 255)
                surface.DrawRect(0, 0, 4, h)

                draw.SimpleText(char:GetDisplayName(), "DermaDefaultBold", 16, 16,
                    color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(
                    string.format("%s  ·  %s  ·  %s",
                        faction and faction.name or char.faction,
                        class and class.name or char.class,
                        rank and rank.name or char.rank),
                    "DermaDefault", 16, 40, Color(150, 155, 165), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end

            row.OnCursorEntered = function()
                if char.model ~= "" then preview:SetModel(char.model) end
            end

            local del = StyledButton(row, "Delete", Color(120, 45, 50), function()
                Derma_Query("Delete " .. char:GetName() .. " permanently?", "Axis",
                    "Delete", function()
                        net.Start("axisCharDelete")
                            net.WriteUInt(char.id, 32)
                        net.SendToServer()
                    end,
                    "Cancel", function() end)
            end)
            del:Dock(RIGHT)
            del:DockMargin(8, 14, 12, 14)
            del:SetWide(80)

            local play = StyledButton(row, "Play", Color(45, 95, 150), function()
                net.Start("axisCharSelect")
                    net.WriteUInt(char.id, 32)
                net.SendToServer()

                frame.selected = true
                frame:Remove()
            end)
            play:Dock(RIGHT)
            play:DockMargin(8, 14, 0, 14)
            play:SetWide(80)
        end

        if #axis.char.list < axis.config.maxCharacters then
            local create = StyledButton(scroll, "Create a new character", Color(40, 44, 54), function()
                axis.char.OpenCreateMenu()
            end)
            create:Dock(TOP)
            create:SetTall(44)
        end
    end

    frame:Rebuild()
end

--- No faction picker: the server puts every new character in
--- axis.config.defaultFaction. The label below is display only, so a client
--- editing it changes nothing.
function axis.char.OpenCreateMenu()
    local frame = vgui.Create("DFrame")
    frame:SetSize(360, 170)
    frame:Center()
    frame:SetTitle("Create a character")
    frame:MakePopup()

    local name = frame:Add("DTextEntry")
    name:Dock(TOP)
    name:DockMargin(8, 8, 8, 4)
    name:SetTall(28)
    name:SetPlaceholderText("Character name")

    local faction = axis.faction.Get(axis.config.defaultFaction)

    local blurb = frame:Add("DLabel")
    blurb:Dock(TOP)
    blurb:DockMargin(8, 4, 8, 8)
    blurb:SetTall(20)
    blurb:SetTextColor(axis.config.color.info)
    blurb:SetText(faction and ("You will enlist in the " .. faction.name .. ".") or "")

    local confirm = StyledButton(frame, "Create", Color(45, 95, 150), function()
        net.Start("axisCharCreate")
            net.WriteString(name:GetValue())
        net.SendToServer()

        frame:Remove()
    end)
    confirm:Dock(BOTTOM)
    confirm:DockMargin(8, 4, 8, 8)
    confirm:SetTall(32)
end

hook.Add("InitPostEntity", "AxisCharacterReady", function()
    net.Start("axisCharReady")
    net.SendToServer()
end)

concommand.Add("axis_characters", function()
    axis.char.OpenMenu()
end, nil, "Open the Axis character menu.")
