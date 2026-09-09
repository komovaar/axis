local MANAGE = "Axis - Manage Characters"

axis.command.Register("characters", {
    description = "Open the character menu.",
    aliases = { "chars", "charmenu" },
    arguments = {},
    OnRun = function(ply)
        ply:ConCommand("axis_characters")
    end,
})

axis.command.Register("classes", {
    description = "List the classes available to your faction.",
    arguments = {},
    OnRun = function(ply)
        local factionID = ply:GetFaction()

        if not factionID then
            axis.chat.Notify(ply, "error", "You have no active character.")
            return
        end

        local classes = axis.faction.GetClasses(factionID)

        if #classes == 0 then
            axis.chat.Notify(ply, "info", "Your faction has no classes configured.")
            return
        end

        axis.chat.Notify(ply, "info", "Classes available to you:")

        for _, class in ipairs(classes) do
            local ok, reason = axis.class.CanSwitchTo(ply, class.id)
            local held = ply:GetCharClass() == class.id

            local suffix = held and "  (current)"
                or (ok and "" or ("  - " .. reason))

            axis.chat.Send(ply,
                ok and axis.config.color.success or Color(140, 140, 150),
                "  " .. class.name,
                Color(120, 120, 130),
                string.format("  [%s]%s",
                    class.limit > 0 and (axis.class.GetCount(class.id) .. "/" .. class.limit) or "open",
                    suffix))
        end
    end,
})

axis.command.Register("class", {
    description = "Change to another class in your faction.",
    arguments = {
        { name = "class", type = "class" },
    },
    OnRun = function(ply, class)
        local char = ply:GetCharacter()

        if not char then
            axis.chat.Notify(ply, "error", "You have no active character.")
            return
        end

        local ok, reason = char:SetClass(class.id)

        if not ok then
            axis.chat.Notify(ply, "error", reason)
            return
        end

        axis.chat.Notify(ply, "success", "You are now a " .. class.name .. ".")
    end,
})

--- Staff overrides. These bypass the class gates deliberately - that is the whole
--- point of a staff command - so they are CAMI-gated with no rank fallback.
axis.command.Register("setclass", {
    description = "Force a player into a class.",
    privilege = MANAGE,
    arguments = {
        { name = "player", type = "player" },
        { name = "class", type = "class" },
    },
    OnRun = function(ply, target, class)
        local char = target:GetCharacter()

        if not char then
            axis.chat.Notify(ply, "error", "That player has no active character.")
            return
        end

        if char:GetFaction() ~= class.faction then
            axis.chat.Notify(ply, "error", class.name .. " belongs to another faction.")
            return
        end

        char:SetClass(class.id, true)

        axis.chat.Notify(ply, "success", target:GetDisplayName() .. " is now a " .. class.name .. ".")
        axis.chat.Notify(target, "info", "You are now a " .. class.name .. ".")
    end,
})

axis.command.Register("setrank", {
    description = "Set a player's rank.",
    privilege = MANAGE,
    arguments = {
        { name = "player", type = "player" },
        { name = "rank", type = "rank" },
    },
    OnRun = function(ply, target, rank)
        local char = target:GetCharacter()

        if not char then
            axis.chat.Notify(ply, "error", "That player has no active character.")
            return
        end

        if char:GetFaction() ~= rank.faction then
            axis.chat.Notify(ply, "error", rank.name .. " belongs to another faction.")
            return
        end

        char:SetRank(rank.id)

        axis.chat.Notify(ply, "success", target:GetDisplayName() .. " is now " .. rank.name .. ".")
        axis.chat.Notify(target, "info", "You have been made " .. rank.name .. ".")
    end,
})

axis.command.Register("setfaction", {
    description = "Move a player's character to another faction.",
    privilege = MANAGE,
    arguments = {
        { name = "player", type = "player" },
        { name = "faction", type = "faction" },
    },
    OnRun = function(ply, target, faction)
        local char = target:GetCharacter()

        if not char then
            axis.chat.Notify(ply, "error", "That player has no active character.")
            return
        end

        char:SetFaction(faction.id)

        axis.chat.Notify(ply, "success",
            target:GetDisplayName() .. " has been moved to " .. faction.name .. ".")
        axis.chat.Notify(target, "info", "You have been moved to " .. faction.name .. ".")
    end,
})

axis.command.Register("whois", {
    description = "Show a player's character, class and rank.",
    arguments = {
        { name = "player", type = "player" },
    },
    OnRun = function(ply, target)
        local char = target:GetCharacter()

        if not char then
            axis.chat.Notify(ply, "info", target:Nick() .. " has no active character.")
            return
        end

        local faction = char:GetFactionTable()
        local class = char:GetClassTable()
        local rank = char:GetRankTable()

        axis.chat.Send(ply,
            axis.config.color.info, "[Axis] ",
            char:GetColor(), char:GetDisplayName(),
            color_white, string.format(" - %s, %s, %s",
                faction and faction.name or "?",
                class and class.name or "?",
                rank and rank.name or "?"))
    end,
})
