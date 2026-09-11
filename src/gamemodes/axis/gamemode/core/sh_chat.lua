axis.chat = axis.chat or {}
axis.chat.classes = axis.chat.classes or {}
axis.chat.defaultClass = "ic"

--- Segment types used on the wire. Sending a Player rather than a string lets the
--- client colour the name from live character data instead of a baked-in colour.
axis.chat.SEG_TEXT = 1
axis.chat.SEG_COLOR = 2
axis.chat.SEG_PLAYER = 3

--- A chat class is how a line of speech is routed and rendered.
--- `prefix` (optional) registers a matching command, so /me and /ooc go through
--- the same dispatcher as every other command.
---@param id string
---@param data table
---@return table
function axis.chat.RegisterClass(id, data)
    data.id = id
    data.radius = data.radius or 0 -- 0 = global

    axis.chat.classes[id] = data

    if SERVER and data.prefix then
        axis.command.Register(data.prefix, {
            description = data.description or ("Speak in the " .. id .. " channel."),
            aliases = data.aliases,
            arguments = { { name = "message", type = "rest" } },
            OnRun = function(ply, message)
                axis.chat.Route(ply, id, message)
            end,
        })
    end

    return data
end

---@param id string
---@return table|nil
function axis.chat.GetClass(id)
    return axis.chat.classes[id]
end

--- Default hearing rule: everyone when radius is 0, otherwise players inside it.
---@param class table
---@param speaker Player
---@param listener Player
---@return boolean
function axis.chat.DefaultCanHear(class, speaker, listener)
    if class.radius <= 0 then return true end

    return speaker:GetPos():DistToSqr(listener:GetPos()) <= class.radius * class.radius
end
