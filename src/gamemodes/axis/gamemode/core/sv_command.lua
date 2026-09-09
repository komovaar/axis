--- Gates are OR'd: a command declaring both a rank permission and a CAMI
--- privilege lets a Sergeant arrest because of their rank, and lets staff do it
--- regardless of what character they are on.
---@param ply Player
---@param command table
---@param callback fun(allowed: boolean, reason: string?)
function axis.command.CheckAccess(ply, command, callback)
    if not command.permission and not command.privilege then
        callback(true)
        return
    end

    if command.permission and axis.rank.HasPermission(ply, command.permission) then
        callback(true)
        return
    end

    if not command.privilege then
        callback(false, "Your rank does not permit that.")
        return
    end

    axis.HasPrivilege(ply, command.privilege, function(hasAccess)
        if hasAccess then
            callback(true)
        else
            callback(false, "You do not have permission to do that.")
        end
    end)
end

---@param ply Player
---@param command table
---@param argString string
function axis.command.Run(ply, command, argString)
    axis.command.CheckAccess(ply, command, function(allowed, reason)
        if not IsValid(ply) then return end

        if not allowed then
            axis.chat.Notify(ply, "error", reason or "You cannot use that command.")
            return
        end

        local values, err = axis.command.ParseArguments(ply, command, argString or "")

        if not values then
            axis.chat.Notify(ply, "error", err)
            return
        end

        local ok, runErr = pcall(command.OnRun, ply, unpack(values, 1, #command.arguments))

        if not ok then
            axis.LogError("command '%s' errored: %s", command.name, tostring(runErr))
            axis.chat.Notify(ply, "error", "That command failed. The error has been logged.")
        end
    end)
end

axis.command.Register("help", {
    description = "List the commands you can use.",
    aliases = { "commands", "?" },
    arguments = {},
    OnRun = function(ply)
        local names = {}

        for name in pairs(axis.command.stored) do
            names[#names + 1] = name
        end

        table.sort(names)

        axis.chat.Notify(ply, "info", "Commands: " .. axis.command.prefix ..
            table.concat(names, ", " .. axis.command.prefix))
    end,
})
