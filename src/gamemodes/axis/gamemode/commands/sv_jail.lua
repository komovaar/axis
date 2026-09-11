axis.command.Register("arrest", {
    description = "Detain a player for a duration.",
    aliases = { "jail" },
    permission = "arrest",
    privilege = "Axis - Jail",
    arguments = {
        { name = "player", type = "player" },
        { name = "duration", type = "time" },
        { name = "reason", type = "rest", optional = true },
    },
    OnRun = function(ply, target, duration, reason)
        if axis.jail.IsJailed(target) then
            axis.chat.Notify(ply, "error", target:GetDisplayName() .. " is already detained.")
            return
        end

        local ok, err = axis.jail.Arrest(target, duration, reason, ply)
        if not ok then axis.chat.Notify(ply, "error", err) end
    end,
})

axis.command.Register("unarrest", {
    description = "Release a detained player.",
    aliases = { "unjail", "release" },
    permission = "arrest",
    privilege = "Axis - Jail",
    arguments = {
        { name = "player", type = "player" },
    },
    OnRun = function(ply, target)
        if not axis.jail.IsJailed(target) then
            axis.chat.Notify(ply, "error", target:GetDisplayName() .. " is not detained.")
            return
        end

        axis.jail.Release(target)
    end,
})

axis.command.Register("sentence", {
    description = "Check how long a player has left to serve.",
    arguments = {
        { name = "player", type = "player", optional = true },
    },
    OnRun = function(ply, target)
        target = target or ply

        local remaining = axis.jail.GetRemaining(target)

        if remaining <= 0 then
            axis.chat.Notify(ply, "info", target:GetDisplayName() .. " is not detained.")
            return
        end

        axis.chat.Notify(ply, "info", string.format("%s has %s left to serve.",
            target:GetDisplayName(), axis.jail.FormatTime(remaining)))
    end,
})
