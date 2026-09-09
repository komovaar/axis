local colors = axis.config.color
local radius = axis.config.chatRadius

--- The default class: no prefix, so anything not starting with "/" lands here.
axis.chat.RegisterClass("ic", {
    radius = radius.ic,
    OnFormat = function(_, speaker, message)
        return { speaker, color_white, ": " .. message }
    end,
})

axis.chat.RegisterClass("me", {
    prefix = "me",
    aliases = { "action" },
    radius = radius.me,
    description = "Describe an action your character performs.",
    OnFormat = function(_, speaker, message)
        return { colors.me, "* ", speaker, colors.me, " " .. message }
    end,
})

axis.chat.RegisterClass("it", {
    prefix = "it",
    radius = radius.it,
    description = "Describe something happening around you.",
    OnFormat = function(_, _, message)
        return { colors.me, "** " .. message }
    end,
})

axis.chat.RegisterClass("whisper", {
    prefix = "w",
    aliases = { "whisper" },
    radius = radius.whisper,
    description = "Speak quietly to those very close by.",
    OnFormat = function(_, speaker, message)
        return { colors.whisper, "[whisper] ", speaker, colors.whisper, ": " .. message }
    end,
})

axis.chat.RegisterClass("yell", {
    prefix = "y",
    aliases = { "yell", "shout" },
    radius = radius.yell,
    description = "Shout so a wide area can hear you.",
    OnFormat = function(_, speaker, message)
        return { colors.yell, "[yell] ", speaker, colors.yell, ": " .. string.upper(message) }
    end,
})

axis.chat.RegisterClass("ooc", {
    prefix = "ooc",
    radius = 0,
    description = "Speak out of character to the whole server.",
    CanSpeak = function(_, speaker)
        local nextOOC = speaker.axisNextOOC or 0

        if CurTime() < nextOOC then
            return false, string.format("Wait %.0fs before using OOC again.", nextOOC - CurTime())
        end

        speaker.axisNextOOC = CurTime() + axis.config.oocCooldown

        return true
    end,
    OnFormat = function(_, speaker, message)
        return { colors.ooc, "(OOC) ", speaker, color_white, ": " .. message }
    end,
})

axis.chat.RegisterClass("faction", {
    prefix = "f",
    aliases = { "faction" },
    radius = 0,
    description = "Speak to everyone in your faction.",
    CanHear = function(_, speaker, listener)
        local a, b = speaker:GetFaction(), listener:GetFaction()

        return a ~= nil and a == b
    end,
    OnFormat = function(_, speaker, message)
        local faction = speaker:GetFactionTable()

        return {
            faction and faction.color or colors.info,
            "[" .. (faction and faction.name or "Faction") .. "] ",
            speaker, color_white, ": " .. message,
        }
    end,
})

--- Radio reaches the whole faction regardless of distance, so it is gated: a
--- class can carry a radio outright, or a rank can grant the permission.
axis.chat.RegisterClass("radio", {
    prefix = "r",
    aliases = { "radio" },
    radius = 0,
    description = "Transmit to everyone in your faction carrying a radio.",
    CanSpeak = function(_, speaker)
        local class = axis.class.GetPlayerClass(speaker)

        if (class and class.radio) or speaker:HasPermission("radio") then return true end

        return false, "You are not carrying a radio."
    end,
    CanHear = function(_, speaker, listener)
        if speaker:GetFaction() ~= listener:GetFaction() then return false end

        local class = axis.class.GetPlayerClass(listener)

        return (class and class.radio) or listener:HasPermission("radio") or false
    end,
    OnFormat = function(_, speaker, message)
        return { colors.radio, "[radio] ", speaker, colors.radio, ": " .. message }
    end,
})
