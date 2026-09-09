util.AddNetworkString("axisChat")

--- Writes a mixed list of strings, Colors and Players as typed segments. Avoids
--- net.WriteTable, which would send type tags for every field of a Color.
local function WriteSegments(segments)
    net.WriteUInt(#segments, 8)

    for _, segment in ipairs(segments) do
        if IsColor(segment) then
            net.WriteUInt(axis.chat.SEG_COLOR, 3)
            net.WriteColor(segment, false)
        elseif type(segment) == "Player" or (isentity(segment) and segment:IsPlayer()) then
            net.WriteUInt(axis.chat.SEG_PLAYER, 3)
            net.WriteEntity(segment)
        else
            net.WriteUInt(axis.chat.SEG_TEXT, 3)
            net.WriteString(tostring(segment))
        end
    end
end

--- axis.chat.Send(recipients, "text", Color(...), player, ...)
--- `recipients` may be a player, a table of players, or nil for everyone.
---@param recipients Player|Player[]|nil
function axis.chat.Send(recipients, ...)
    local segments = { ... }
    if #segments == 0 then return end

    net.Start("axisChat")
        net.WriteUInt(0, 8) -- reserved: 0 = raw segments, no class formatting
        WriteSegments(segments)

    if recipients == nil then
        net.Broadcast()
    else
        net.Send(recipients)
    end
end

---@param recipients Player|Player[]|nil
---@param kind string "info" | "success" | "error"
---@param text string
function axis.chat.Notify(recipients, kind, text)
    local colour = axis.config.color[kind] or axis.config.color.info

    axis.chat.Send(recipients, axis.config.color.info, "[Axis] ", colour, text)
end

--- Who can hear this line, honouring the class's own CanHear override.
---@param class table
---@param speaker Player
---@return Player[]
function axis.chat.GetListeners(class, speaker)
    local listeners = {}

    for _, ply in ipairs(player.GetAll()) do
        local canHear

        if class.CanHear then
            canHear = class.CanHear(class, speaker, ply)
        else
            canHear = axis.chat.DefaultCanHear(class, speaker, ply)
        end

        if canHear then listeners[#listeners + 1] = ply end
    end

    return listeners
end

--- Single entry point for every spoken line, whatever prefix produced it.
---@param speaker Player
---@param classID string
---@param message string
function axis.chat.Route(speaker, classID, message)
    local class = axis.chat.GetClass(classID)
    if not class then return end

    message = string.Trim(message or "")
    if message == "" then return end

    if not speaker:HasCharacter() then
        axis.chat.Notify(speaker, "error", "You need an active character to speak.")
        return
    end

    if class.CanSpeak then
        local ok, reason = class.CanSpeak(class, speaker)

        if not ok then
            axis.chat.Notify(speaker, "error", reason or "You cannot use that channel.")
            return
        end
    end

    local filtered = hook.Run("AxisPlayerChat", speaker, classID, message)
    if filtered == false then return end
    if isstring(filtered) then message = filtered end

    local listeners = axis.chat.GetListeners(class, speaker)
    if #listeners == 0 then return end

    local segments = class.OnFormat(class, speaker, message)

    net.Start("axisChat")
        net.WriteUInt(0, 8)
        WriteSegments(segments)
    net.Send(listeners)

    axis.Log("(%s) %s: %s", classID, speaker:GetDisplayName(), message)
end

--- Everything typed in chat funnels through here. Anything starting with the
--- prefix is a command lookup; anything else is the default chat class.
hook.Add("PlayerSay", "AxisChatDispatch", function(ply, text)
    text = string.Trim(text)
    if text == "" then return "" end

    if string.sub(text, 1, #axis.command.prefix) ~= axis.command.prefix then
        axis.chat.Route(ply, axis.chat.defaultClass, text)
        return ""
    end

    local body = string.sub(text, #axis.command.prefix + 1)
    local name = string.match(body, "^(%S+)") or ""
    local arguments = string.Trim(string.sub(body, #name + 1))

    local command = axis.command.Get(name)

    if not command then
        axis.chat.Notify(ply, "error", "Unknown command '" .. axis.command.prefix .. name .. "'.")
        return ""
    end

    axis.command.Run(ply, command, arguments)

    return ""
end)
